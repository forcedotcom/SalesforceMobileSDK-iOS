//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SFSDKLogoutBlocker.h"
#import "SFSDKAuthRequest.h"
#import "SFSDKAuthSession.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFUserAccountManager+Internal.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFSDKOAuth2.h"

@interface SFOAuthCoordinator (LightningURLTesting)
- (void)handleResponse:(SFSDKOAuthTokenEndpointResponse *)response;
@end

@interface SFSDKOAuthTokenEndpointResponse (Testing)
- (instancetype)initWithDictionary:(NSDictionary *)nvPairs parseAdditionalFields:(NSArray<NSString *> *)additionalOAuthParameterKeys;
@end
