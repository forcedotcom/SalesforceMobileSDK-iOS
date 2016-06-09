/*
 Copyright (c) 2013, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSString+SFAdditions.h"
#import "SFPreferences.h"
#import "SFPushNotificationManager.h"
#import "SFAuthenticationManager.h"
#import "SFUserAccountManager.h"
#import "SFJsonUtils.h"
#import "SFApplicationHelper.h"

static NSString* const kSFDeviceToken = @"deviceToken";
static NSString* const kSFDeviceSalesforceId = @"deviceSalesforceId";
static NSString* const kSFPushNotificationEndPoint = @"services/data/v36.0/sobjects/MobilePushServiceDevice";

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-const-variable"

//
// >= iOS 8 notification types have to be NSUInteger, for backward compatibility with < iOS 8 build environments.
//
// UIUserNotificationTypes:
//   UIUserNotificationTypeNone    = 0,      // the application may not present any UI upon a notification being received
//   UIUserNotificationTypeBadge   = 1 << 0, // the application may badge its icon upon a notification being received
//   UIUserNotificationTypeSound   = 1 << 1, // the application may play a sound upon a notification being received
//   UIUserNotificationTypeAlert   = 1 << 2, // the application may display an alert upon a notification being received

// Default: kiOS8UserNotificationTypes = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert
static NSUInteger const kiOS8UserNotificationTypes = ((1 << 0) | (1 << 1) | (1 << 2));

#pragma clang diagnostic pop

@interface SFPushNotificationManager ()

@property (nonatomic, strong) NSOperationQueue* queue;
@property (nonatomic, assign) BOOL isSimulator;

- (void)onUserLoggedIn:(NSNotification *)notification;
- (void)onAppWillEnterForeground:(NSNotification *)notification;

@end

@implementation SFPushNotificationManager

@synthesize queue = _queue;
@synthesize deviceToken = _deviceToken;
@synthesize deviceSalesforceId = _deviceSalesforceId;

#pragma mark - Initialization
- (id)init
{
    self = [super init];
    if (self) {
#if TARGET_IPHONE_SIMULATOR
        self.isSimulator = YES;
#else
        self.isSimulator = NO;
#endif
        // Queue for requests
        _queue = [[NSOperationQueue alloc] init];
        
        // Restore device token from user defaults if available
        _deviceToken = [[SFPreferences currentUserLevelPreferences] stringForKey:kSFDeviceToken];
        
        // Restore device Salesforce ID from user defaults if available
        _deviceSalesforceId = [[SFPreferences currentUserLevelPreferences] stringForKey:kSFDeviceSalesforceId];
        
        // Watching logged in events (to register)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onUserLoggedIn:) name:kSFUserLoggedInNotification object:nil];
        
        // Watching foreground events (to re-register)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}


+ (SFPushNotificationManager *) sharedInstance
{
    static dispatch_once_t pred;
    static SFPushNotificationManager *mgr = nil;
    dispatch_once(&pred, ^{
        mgr = [[super allocWithZone:nil] init];
    });
    return mgr;
}

#pragma mark - APNS registration

- (void)registerForRemoteNotifications
{
    if (self.isSimulator)  {  // remote notifications are not supported in the simulator
        [self log:SFLogLevelInfo msg:@"Skipping push notification registration with Apple because push isn't supported on the simulator"];
        return;
    }
    
    // register with Apple for remote notifications
    [self log:SFLogLevelInfo msg:@"Registering with Apple for remote push notifications"];
    [self registerNotifications];
}

- (void)registerNotifications
{
    // This is necessary to build libraries with the iOS 7 runtime, that can execute iOS 8 methods.  When
    // we switch to building libraries with Xcode 6, this can go away.
    NSSet *categories = nil;
    NSUInteger notificationTypes = kiOS8UserNotificationTypes;
    
    Class userNotificationSettings = NSClassFromString(@"UIUserNotificationSettings");
    NSMethodSignature *settingsForTypesSig = [userNotificationSettings methodSignatureForSelector:@selector(settingsForTypes:categories:)];
    NSInvocation *settingsForTypesInv = [NSInvocation invocationWithMethodSignature:settingsForTypesSig];
    [settingsForTypesInv setTarget:userNotificationSettings];
    [settingsForTypesInv setSelector:@selector(settingsForTypes:categories:)];
    [settingsForTypesInv setArgument:&notificationTypes atIndex:2];
    [settingsForTypesInv setArgument:&categories atIndex:3];
    [settingsForTypesInv invoke];
    
    CFTypeRef settingsForTypesRetVal;
    [settingsForTypesInv getReturnValue:&settingsForTypesRetVal];
    if (settingsForTypesRetVal)
        CFRetain(settingsForTypesRetVal);
    
    [[SFApplicationHelper sharedApplication] performSelector:@selector(registerUserNotificationSettings:) withObject:(__bridge_transfer id)settingsForTypesRetVal];
    [[SFApplicationHelper sharedApplication] performSelector:@selector(registerForRemoteNotifications)];
}

- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceTokenData
{
    [self log:SFLogLevelInfo msg:@"Registration with Apple for remote push notifications succeeded"];
    _deviceToken = [NSString stringWithHexData:deviceTokenData];
    [[SFPreferences currentUserLevelPreferences] setObject:_deviceToken forKey:kSFDeviceToken];
}

#pragma mark - Salesforce registration

- (BOOL)registerForSalesforceNotifications
{
    if (self.isSimulator) {  // remote notifications are not supported in the simulator
        [self log:SFLogLevelInfo msg:@"Skipping Salesforce push notification registration because push isn't supported on the simulator"];
        return YES;  // "Successful", from this standpoint.
    }
    
    SFOAuthCredentials *credentials = [SFAuthenticationManager sharedManager].coordinator.credentials;
    if (!credentials) {
        [self log:SFLogLevelError msg:@"Cannot register for notifications with Salesforce: not authenticated"];
        return NO;
    }
    
    if (!_deviceToken) {
        [self log:SFLogLevelError msg:@"Cannot register for notifications with Salesforce: no deviceToken"];
        return NO;
    }
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    // URL and method
    [request setURL:[NSURL URLWithString:kSFPushNotificationEndPoint relativeToURL:credentials.instanceUrl]];
    [request setHTTPMethod:@"POST"];
    
    // Headers
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", credentials.accessToken] forHTTPHeaderField:@"Authorization"];
    [request setHTTPShouldHandleCookies:NO];
    
    // Body
    NSDictionary* bodyDict = @{@"ConnectionToken":_deviceToken, @"ServiceType":@"Apple"};
    [request setHTTPBody:[SFJsonUtils JSONDataRepresentation:bodyDict]];
    
    // Send
    NSURLSession* session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error != nil) {
            [self log:SFLogLevelError format:@"Registration for notifications with Salesforce failed with error %@", error];
        }
        else {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
            NSInteger statusCode = httpResponse.statusCode;
            if (statusCode < 200 || statusCode >= 300) {
                [self log:SFLogLevelError format:@"Registration for notifications with Salesforce failed with status %ld", statusCode];
                [self log:SFLogLevelError format:@"Response:%@", [SFJsonUtils objectFromJSONData:data]];
            }
            else {
                [self log:SFLogLevelInfo msg:@"Registration for notifications with Salesforce succeeded"];
                NSDictionary *responseAsJson = (NSDictionary*) [SFJsonUtils objectFromJSONData:data];
                self->_deviceSalesforceId = (NSString*) responseAsJson[@"id"];
                [[SFPreferences currentUserLevelPreferences] setObject:self->_deviceSalesforceId forKey:kSFDeviceSalesforceId];
                [self log:SFLogLevelInfo format:@"Response:%@", responseAsJson];
            }
        }
    }] resume];
    
    return YES;
}

- (BOOL)unregisterSalesforceNotifications
{
    if (self.isSimulator) {
        return YES;  // "Successful".  Simulator does not register/unregister for notifications.
    } else {
        return [self unregisterSalesforceNotifications:[SFUserAccountManager sharedInstance].currentUser];
    }
}

- (BOOL)unregisterSalesforceNotifications:(SFUserAccount*)user
{
    if (self.isSimulator) {
        return YES;  // "Successful".  Simulator does not register/unregister for notifications.
    }
    
    SFOAuthCredentials *credentials = user.credentials;
    if (!credentials) {
        [self log:SFLogLevelError msg:@"Cannot unregister from notifications with Salesforce: not authenticated"];
        return NO;
    }
    SFPreferences *pref = [SFPreferences sharedPreferencesForScope:SFUserAccountScopeUser user:user];
    if (!pref) {
        [self log:SFLogLevelError msg:@"Cannot unregister from notifications with Salesforce: no user pref"];
        return NO;
    }

    if (![pref stringForKey:kSFDeviceSalesforceId]) {
        [self log:SFLogLevelError msg:@"Cannot unregister from notifications with Salesforce: no deviceSalesforceId"];
        return NO;
    }
    NSString *deviceSFID = [[NSString alloc] initWithString:[pref stringForKey:kSFDeviceSalesforceId]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    // URL and method
    [request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", kSFPushNotificationEndPoint, deviceSFID] relativeToURL:credentials.instanceUrl]];
    [request setHTTPMethod:@"DELETE"];
    
    // Headers
    [request setValue:[NSString stringWithFormat:@"Bearer %@", credentials.accessToken] forHTTPHeaderField:@"Authorization"];
    [request setHTTPShouldHandleCookies:NO];
    
    // Send (fire and forget)
    NSURLSession* session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    [[session dataTaskWithRequest:request] resume];
    [self log:SFLogLevelInfo msg:@"Unregister from notifications with Salesforce sent"];
    return YES;
}

#pragma mark - Events observers
- (void)onUserLoggedIn:(NSNotification *)notification
{
    // Registering with Salesforce after login
    if (self.deviceToken) {
        [self log:SFLogLevelInfo msg:@"Registering for Salesforce notification because user just logged in"];
        [self registerForSalesforceNotifications];
    }
}


- (void)onAppWillEnterForeground:(NSNotification *)notification
{
    // Re-registering with Salesforce if we have a device token unless we are logging out
    if (![SFAuthenticationManager sharedManager].logoutSettingEnabled && self.deviceToken) {
        [self log:SFLogLevelInfo msg:@"Re-registering for Salesforce notification because application is being foregrounded"];
        [self registerForSalesforceNotifications];
    }
}

@end
