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

#import "SFPushNotificationManager.h"
#import "SFAuthenticationManager.h"
#import "SFAccountManager.h"
#import "SFJsonUtils.h"

static NSString* const kSFPushNotificationEndPoint = @"services/data/v29.0/MobilePushServiceDevice";
static UIRemoteNotificationType const kRemoteNotificationTypes = UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert;


@interface SFPushNotificationManager ()

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData*)data;

- (void)onLogout:(NSNotification *)notification;
+(NSString*) stringWithHexData:(NSData*) data;

@end

@implementation SFPushNotificationManager

@synthesize deviceToken = _deviceToken;
@synthesize deviceSalesforceId = _deviceSalesforceId;

#pragma mark - Initialization
- (id)init
{
    self = [super init];
    if (self) {
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
    NSString* tokenString = [SFPushNotificationManager stringWithHexData:_deviceToken];
    NSDictionary* bodyDict = @{@"ConnectionToken":tokenString, @"ServiceType":@"Apple"};
    [request setHTTPBody:[SFJsonUtils JSONDataRepresentation:bodyDict]];
    
    // Send
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    return (connection != nil);
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
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:nil];
    return (connection != nil);
}

# pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
    NSInteger statusCode = httpResponse.statusCode;
    NSString* logMsg = [NSString stringWithFormat:@"Request to %@ returned with status %d", response.URL, statusCode];
    [self log:(statusCode == 200 || statusCode == 204 ? SFLogLevelInfo : SFLogLevelError) msg:logMsg];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData*)data
{
    NSDictionary *responseAsJson = (NSDictionary*) [SFJsonUtils objectFromJSONData:data];
    if (responseAsJson) {
        _deviceSalesforceId = (NSString*) [responseAsJson objectForKey:@"id"];
        [self log:SFLogLevelInfo msg:[NSString stringWithFormat:@"Salesforce device id is %@", _deviceSalesforceId]];
    }
    else {
        // FIXME we don't want to lose it if we got a 401
        _deviceSalesforceId = nil;
    }
}

# pragma mark - logout handler

- (void)onLogout:(NSNotification *)notification
{
    [self unregisterSalesforceNotifications];
}

# pragma mark - misc


+ (NSString *)stringWithHexData:(NSData *)data
{
    if (nil == data) return nil;
    NSMutableString *stringBuffer = [NSMutableString stringWithCapacity:([data length] * 2)];
	const unsigned char *dataBuffer = [data bytes];
	for (int i = 0; i < [data length]; ++i) {
		[stringBuffer appendFormat:@"%02lx", (unsigned long)dataBuffer[ i ]];
    }
    return [NSString stringWithString:stringBuffer];
}


@end
