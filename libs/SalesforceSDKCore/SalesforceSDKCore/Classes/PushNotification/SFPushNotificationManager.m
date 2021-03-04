/*
 Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.
 
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

#import <SalesforceSDKCommon/SFJsonUtils.h>
#import "NSString+SFAdditions.h"
#import "SFPreferences.h"
#import "SFUserAccountManager.h"
#import "SFPushNotificationManager.h"
#import "SFUserAccountManager.h"
#import "SFApplicationHelper.h"
#import "SFSDKAppFeatureMarkers.h"
#import "SFRestAPI+Blocks.h"
#import "SFSDKPushNotificationEncryptionConstants.h"
#import "SFSDKCryptoUtils.h"

static NSString* const kSFDeviceToken = @"deviceToken";
static NSString* const kSFDeviceSalesforceId = @"deviceSalesforceId";
static NSString* const kSFPushNotificationEndPoint = @"sobjects/MobilePushServiceDevice";
static NSString * const kSFAppFeaturePushNotifications = @"PN";

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

- (id)init {
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onUserLoggedIn:) name:kSFNotificationUserDidLogIn object:nil];
        
        // Watching foreground events (to re-register)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}

+ (SFPushNotificationManager *) sharedInstance {
    static dispatch_once_t pred;
    static SFPushNotificationManager *mgr = nil;
    dispatch_once(&pred, ^{
        mgr = [[super allocWithZone:nil] init];
    });
    return mgr;
}

#pragma mark - APNS registration

- (void)registerForRemoteNotifications {
    if (self.isSimulator)  {  // remote notifications are not supported in the simulator
        [SFSDKCoreLogger i:[self class] format:@"Skipping push notification registration with Apple because push isn't supported on the simulator"];
        return;
    }

    // register with Apple for remote notifications
    [SFSDKCoreLogger i:[self class] format:@"Registering with Apple for remote push notifications"];
    [[SFApplicationHelper sharedApplication] performSelector:@selector(registerForRemoteNotifications)];
}

- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceTokenData {
    [SFSDKCoreLogger i:[self class] format:@"Registration with Apple for remote push notifications succeeded"];
    _deviceToken = [NSString stringWithHexData:deviceTokenData];
    [[SFPreferences currentUserLevelPreferences] setObject:_deviceToken forKey:kSFDeviceToken];
}

#pragma mark - Salesforce registration

- (BOOL)registerSalesforceNotificationsWithCompletionBlock:(void (^)(void))completionBlock failBlock:(nullable void (^)(void))failBlock {
    return [self registerSalesforceNotificationsWithCompletionBlock:[SFUserAccountManager  sharedInstance].currentUser completionBlock:completionBlock failBlock:failBlock];
}

- (BOOL)registerSalesforceNotificationsWithCompletionBlock:(SFUserAccount *)user completionBlock:(void (^)(void))completionBlock failBlock:(nullable void (^)(void))failBlock {
    if (self.isSimulator) {  // remote notifications are not supported in the simulator
        [SFSDKCoreLogger i:[self class] format:@"Skipping Salesforce push notification registration because push isn't supported on the simulator"];
        [self postPushNotificationRegistration: completionBlock];
        return YES;  // "Successful", from this standpoint.
    }
    SFOAuthCredentials *credentials = user.credentials;
    if (!credentials) {
        [SFSDKCoreLogger e:[self class] format:@"Cannot register for notifications with Salesforce: not authenticated"];
        [self postPushNotificationRegistration: failBlock];
        return NO;
    }
    if (!_deviceToken) {
        [SFSDKCoreLogger e:[self class] format:@"Cannot register for notifications with Salesforce: no deviceToken"];
        [self postPushNotificationRegistration: failBlock];
        return NO;
    }
    NSString *path = [NSString stringWithFormat:@"/%@/%@", [SFRestAPI sharedInstance].apiVersion, kSFPushNotificationEndPoint];
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:nil];
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    NSMutableDictionary* bodyDict = [NSMutableDictionary dictionaryWithDictionary:@{@"ConnectionToken":_deviceToken, @"ServiceType":@"Apple", @"ApplicationBundle":bundleId}];
    if (_customPushRegistrationBody != nil) {
        [bodyDict addEntriesFromDictionary: _customPushRegistrationBody];
    }

    // Sends community ID as part of the registration call, to ensure notifications are scoped by community.
    NSString *communityId = user.credentials.communityId;
    if (communityId) {
        bodyDict[@"NetworkId"] = communityId;
    }
    NSString *rsaPublicKey = [self getRSAPublicKey];
    if (rsaPublicKey) {
        bodyDict[@"RsaPublicKey"] = rsaPublicKey;
    }
    [request setCustomRequestBodyDictionary:bodyDict contentType:@"application/json"];
    __weak typeof(self) weakSelf = self;
    [[SFRestAPI sharedInstance] sendRequest:request failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (e != nil) {
            [SFSDKCoreLogger e:[strongSelf class] format:@"Registration for notifications with Salesforce failed with error %@", e];
        }
        [strongSelf postPushNotificationRegistration:failBlock];
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeaturePushNotifications];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) rawResponse;
        NSInteger statusCode = httpResponse.statusCode;
        if (statusCode < 200 || statusCode >= 300) {
            [SFSDKCoreLogger e:[strongSelf class] format:@"Registration for notifications with Salesforce failed with status %ld", statusCode];
            [SFSDKCoreLogger e:[strongSelf class] format:@"Response:%@", response];
            [strongSelf postPushNotificationRegistration:failBlock];
        } else if (![response isKindOfClass:[NSDictionary class]]) {
            [SFSDKCoreLogger e:[strongSelf class] format:@"Registration for notifications with Salesforce failed due to unexpected response: %@", response];
            [strongSelf postPushNotificationRegistration:failBlock];
        } else {
            [SFSDKCoreLogger i:[strongSelf class] format:@"Registration for notifications with Salesforce succeeded"];
            NSDictionary *responseAsJson = (NSDictionary*) response;
            strongSelf->_deviceSalesforceId = (NSString*) responseAsJson[@"id"];
            [[SFPreferences currentUserLevelPreferences] setObject:strongSelf->_deviceSalesforceId forKey:kSFDeviceSalesforceId];
            [SFSDKCoreLogger i:[strongSelf class] format:@"Response:%@", responseAsJson];
            [strongSelf postPushNotificationRegistration:completionBlock];
        }
    }];
    return YES;
}

- (void)postPushNotificationRegistration:(void (^)(void))completionBlock {
    if (completionBlock != nil) {
        completionBlock();
    }
}

- (BOOL)unregisterSalesforceNotificationsWithCompletionBlock:(void (^)(void))completionBlock {
    return [self unregisterSalesforceNotificationsWithCompletionBlock:[SFUserAccountManager sharedInstance].currentUser completionBlock:completionBlock];
}

- (BOOL)unregisterSalesforceNotificationsWithCompletionBlock:(SFUserAccount*)user completionBlock:(void (^)(void))completionBlock {
    if (!_deviceSalesforceId) {
        // Nothing to do - we have not registered for push notifications
        [self postPushNotificationUnregistration:completionBlock];
        return YES;
    }
    
    if (self.isSimulator) {
        [self postPushNotificationUnregistration:completionBlock];
        return YES;  // "Successful".  Simulator does not register/unregister for notifications.
    }
    SFOAuthCredentials *credentials = user.credentials;
    if (!credentials) {
        [SFSDKCoreLogger e:[self class] format:@"Cannot unregister from notifications with Salesforce: not authenticated"];
        [self postPushNotificationUnregistration:completionBlock];
        return NO;
    }
    SFPreferences *pref = [SFPreferences sharedPreferencesForScope:SFUserAccountScopeUser user:user];
    if (!pref) {
        [SFSDKCoreLogger e:[self class] format:@"Cannot unregister from notifications with Salesforce: no user pref"];
        [self postPushNotificationUnregistration:completionBlock];
        return NO;
    }
    if (![pref stringForKey:kSFDeviceSalesforceId]) {
        [SFSDKCoreLogger e:[self class] format:@"Cannot unregister from notifications with Salesforce: no deviceSalesforceId"];
        [self postPushNotificationUnregistration:completionBlock];
        return NO;
    }
    NSString *deviceSFID = [[NSString alloc] initWithString:[pref stringForKey:kSFDeviceSalesforceId]];
    NSString *path = [NSString stringWithFormat:@"/%@/%@/%@", [SFRestAPI sharedInstance].apiVersion, kSFPushNotificationEndPoint, deviceSFID];
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodDELETE path:path queryParams:nil];
    __weak typeof(self) weakSelf = self;
    [[SFRestAPI sharedInstance] sendRequest:request failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (e) {
            [SFSDKCoreLogger e:[strongSelf class] format:@"Push notification unregistration failed %ld %@", (long)[e code], [e localizedDescription]];
        }
        [strongSelf postPushNotificationUnregistration:completionBlock];
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf postPushNotificationUnregistration:completionBlock];
    }];
    [SFSDKCoreLogger i:[self class] format:@"Unregister from notifications with Salesforce sent"];
    return YES;
}

- (void)postPushNotificationUnregistration:(void (^)(void))completionBlock {
    if (completionBlock != nil) {
        completionBlock();
    }
}

- (NSString *)getRSAPublicKey {
    NSString *rsaPublicKey = [SFSDKCryptoUtils getRSAPublicKeyStringWithName:kPNEncryptionKeyName keyLength:kPNEncryptionKeyLength];
    if (rsaPublicKey == nil) {
        [SFSDKCryptoUtils createRSAKeyPairWithName:kPNEncryptionKeyName keyLength:kPNEncryptionKeyLength accessibleAttribute:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly];
        rsaPublicKey = [SFSDKCryptoUtils getRSAPublicKeyStringWithName:kPNEncryptionKeyName keyLength:kPNEncryptionKeyLength];
    }
    return rsaPublicKey;
}

#pragma mark - Events observers
- (void)onUserLoggedIn:(NSNotification *)notification {
    // Registering with Salesforce after login
    if (self.deviceToken) {
        [SFSDKCoreLogger i:[self class] format:@"Registering for Salesforce notification because user just logged in"];
        [self registerSalesforceNotificationsWithCompletionBlock:nil failBlock:nil];
    }
}

- (void)onAppWillEnterForeground:(NSNotification *)notification {
    // Re-registering with Salesforce if we have a device token unless we are logging out
    if (![SFUserAccountManager sharedInstance].logoutSettingEnabled && self.deviceToken) {
        [SFSDKCoreLogger i:[self class] format:@"Re-registering for Salesforce notification because application is being foregrounded"];
        [self registerSalesforceNotificationsWithCompletionBlock:nil failBlock:nil];
    }
}

@end
