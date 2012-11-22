/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

#import "SFPushNotification.h"
#import "NSString+SFAdditions.h"

@interface SFPushNotification()
/**
 * This method is used to assert the minimum required API for using the SFDC Push Notification Framework.
 * The minimum required API version is v27.0
 */
- (void)assertMinimumApi;
@end

@implementation SFPushNotification

static NSString* const kApplicationName = @"SFDCConnectedAppName";
static NSString* const kNamespacePrefix = @"SFDCConnectedAppNamespacePrefix";

@synthesize PNSToken;
@synthesize pushObjectEntity;

+ (SFPushNotification *) sharedInstance {
    static dispatch_once_t _singletonPredicate;
    static SFPushNotification *_singleton = nil;
    dispatch_once(&_singletonPredicate, ^{
        _singleton = [[super allocWithZone:nil] init];
    });
    return _singleton;
}

- (void)registerForRemoteNotificationTypes:(UIRemoteNotificationType)types {
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:types];
}

- (BOOL)registerForSFDCNotifications {
    [self assertMinimumApi];
    NSString* applicationName = [[NSBundle mainBundle] objectForInfoDictionaryKey:kApplicationName];
    NSLog(@"Connected App name is %@", applicationName);
    NSString* namespacePrefix = [[NSBundle mainBundle] objectForInfoDictionaryKey:kNamespacePrefix];
    NSLog(@"Connected App Namespace Prefix is %@", namespacePrefix);
    NSAssert(applicationName != nil && !([applicationName isEmptyOrWhitespaceAndNewlines]), @"SFDCConnectedAppName name cannot be nil. This should be set in the info.plist");
    NSAssert(namespacePrefix != nil && !([namespacePrefix isEmptyOrWhitespaceAndNewlines]), @"SFDCConnectedAppNamespacePrefix name cannot be nil. This should be set in the info.plist");
    if ([SFPushNotification sharedInstance].PNSToken != nil) {
        NSString *tokenString = [NSString stringWithHexData:[SFPushNotification sharedInstance].PNSToken];
        NSLog(@"tokenstring is %@", tokenString);
        NSArray* propertiesArray = [[NSArray alloc]initWithObjects:@"ApplicationName", @"ConnectionToken", @"NamespacePrefix", @"Vendor", nil];
        NSArray* valuesArray = [[NSArray alloc]initWithObjects:applicationName, tokenString,
                                namespacePrefix, @"Apple", nil];
        NSDictionary* requestDictionary = [[NSDictionary alloc] initWithObjects:valuesArray forKeys:propertiesArray];
        NSLog(@"Registering with SFDC with token : %@", tokenString);
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:@"MobilePushServiceDevice" fields:requestDictionary];
        [[SFRestAPI sharedInstance] send:request delegate:self];
        [propertiesArray release];
        [valuesArray release];
        [requestDictionary release];
        return YES;
    } else {
        NSLog(@"PNS Token is nil");
    }
    return NO;
}

- (BOOL)unregisterSFDCNotifications {
    if ([SFPushNotification sharedInstance].pushObjectEntity != nil) {
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"MobilePushServiceDevice"
                                                                                    objectId:[SFPushNotification sharedInstance].pushObjectEntity];
        [[SFRestAPI sharedInstance] send:request delegate:nil];
        return YES;
    }
    return NO;
}

- (void)assertMinimumApi {
    NSString* api = [[SFRestAPI sharedInstance].apiVersion substringFromIndex:1];
    int version = [api integerValue];
    NSLog(@"REST API Version value is : %d", version);
    NSAssert(version >= 27, @"For push notifications to work, API version must be minimum of v27.0");
}
#pragma mark - SFRequestDelegate

- (void)request:(SFRestRequest *)request didLoadResponse:(id)jsonResponse {
    if (jsonResponse != nil) {
        NSString* id = [jsonResponse objectForKey:@"id"];
        [SFPushNotification sharedInstance].pushObjectEntity = id;
        NSLog(@"saved id : %@", id);
    } else {
        NSLog(@"Empty response");
    }
}

- (void)request:(SFRestRequest*)request didFailLoadWithError:(NSError*)error {
    NSLog([error description]);
}

- (void)requestDidCancelLoad:(SFRestRequest *)request {
    NSLog(@"Request was cancelled");
}

- (void)requestDidTimeout:(SFRestRequest *)request {
    NSLog(@"Request timedout");
}


@end
