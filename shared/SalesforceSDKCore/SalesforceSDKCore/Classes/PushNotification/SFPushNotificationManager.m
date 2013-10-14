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

#import <SalesforceCommonUtils/NSString+SFAdditions.h>
#import "SFPushNotificationManager.h"
#import "SFAuthenticationManager.h"
#import "SFAccountManager.h"
#import "SFJsonUtils.h"

static NSString* const kSFPushNotificationEndPoint = @"services/data/v29.0/sobjects/MobilePushServiceDevice";
static UIRemoteNotificationType const kRemoteNotificationTypes = UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert;


@interface SFPushNotificationManager ()

@property (nonatomic, strong) NSOperationQueue* queue;

- (void)onLogout:(NSNotification *)notification;

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
        // Queue for requests
        _queue = [[NSOperationQueue alloc] init];
        
        // Need to unregister on logout
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onLogout:)
                                                     name:kSFUserLogoutNotification
                                                   object:nil];
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
#if TARGET_IPHONE_SIMULATOR // remote notifications are not supported in the simulator
    [self log:SFLogLevelInfo msg:@"Skipping push notification registration with Apple because push isn't supported on the simulator"];
#else
    // register with Apple for remote notifications
    [self log:SFLogLevelInfo msg:@"Registering with Apple for remote push notifications"];
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:kRemoteNotificationTypes];
#endif
}

- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
    _deviceToken = deviceToken;
}

#pragma mark - Salesforce registration

- (BOOL)registerForSalesforceNotifications
{
    SFOAuthCredentials *credentials = [SFAccountManager sharedInstance].coordinator.credentials;
    if (!credentials) {
        [self log:SFLogLevelError msg:@"not authenticated: cannot register for notifications with Salesforce"];
        return NO;
    }
    
    if (!_deviceToken) {
        [self log:SFLogLevelError msg:@"APNS device token not set: did you call SFPushNotificationManager's registerForRemoteNotifications and didRegisterForRemoteNotificationsWithDeviceToken methods"];
        return NO;
    }
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    // URL and method
    [request setURL:[NSURL URLWithString:kSFPushNotificationEndPoint relativeToURL:credentials.instanceUrl]];
    [request setHTTPMethod:@"POST"];
    
    // Headers
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", credentials.accessToken] forHTTPHeaderField:@"Authorization"];

    // Body
    NSString* tokenString = [NSString stringWithHexData:_deviceToken];
    NSDictionary* bodyDict = @{@"ConnectionToken":tokenString, @"ServiceType":@"Apple"};
    [request setHTTPBody:[SFJsonUtils JSONDataRepresentation:bodyDict]];
    
    // Send
    [NSURLConnection sendAsynchronousRequest:request queue:self.queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
    {
        if (error != nil) {
            [self log:SFLogLevelError format:@"create MobilePushServiceDevice failed with error %@", error];
        }
        else {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
            NSInteger statusCode = httpResponse.statusCode;
            if (statusCode != 200) {
                [self log:SFLogLevelError format:@"create MobilePushServiceDevice failed with status %d", statusCode];
            }
            else {
                [self log:SFLogLevelInfo msg:@"create MobilePushServiceDevice succeeded"];
                NSDictionary *responseAsJson = (NSDictionary*) [SFJsonUtils objectFromJSONData:data];
                _deviceSalesforceId = (NSString*) [responseAsJson objectForKey:@"id"];
            }
        }
    }];
    
    return YES;
}

- (BOOL)unregisterSalesforceNotifications
{
    SFOAuthCredentials *credentials = [SFAccountManager sharedInstance].coordinator.credentials;
    if (!credentials) {
        [self log:SFLogLevelError msg:@"not authenticated: cannot register for notifications with Salesforce"];
        return NO;
    }

    if (!_deviceSalesforceId) {
        [self log:SFLogLevelInfo msg:@"Device not registered with Salesforce"];
        return NO;
    }

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    // URL and method
    [request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", kSFPushNotificationEndPoint, _deviceSalesforceId] relativeToURL:credentials.instanceUrl]];
    [request setHTTPMethod:@"DELETE"];
    
    // Headers
    [request setValue:[NSString stringWithFormat:@"Bearer %@", credentials.accessToken] forHTTPHeaderField:@"Authorization"];
    
    // Send
    [NSURLConnection sendAsynchronousRequest:request queue:self.queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
     {
         if (error != nil) {
             [self log:SFLogLevelError format:@"delete MobilePushServiceDevice failed with error %@", error];
         }
         else {
             NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
             NSInteger statusCode = httpResponse.statusCode;
             if (statusCode != 204) {
                 [self log:SFLogLevelError format:@"delete MobilePushServiceDevice failed with status %d", statusCode];
             }
             else {
                 [self log:SFLogLevelInfo msg:@"delete MobilePushServiceDevice succeeded"];
                 _deviceSalesforceId = nil;
             }
         }
     }];
    
    return YES;
}

# pragma mark - logout handler

- (void)onLogout:(NSNotification *)notification
{
    [self unregisterSalesforceNotifications];
}
@end
