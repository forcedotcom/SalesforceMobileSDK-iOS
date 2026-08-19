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
#import "SFLoginViewController.h"

@interface SFOAuthCoordinator (LightningURLTesting)
- (void)handleResponse:(SFSDKOAuthTokenEndpointResponse *)response;
@end

@interface SFLoginViewController (LoginForAdminTesting)
/// Predicate that controls visibility of the "Login for Admin" entry in the
/// settings menu. Returns NO during phase 1 of Welcome Discovery (a discovery
/// host whose coordinator has not yet observed a custom domain update).
+ (BOOL)shouldShowLoginForAdminForSession:(nullable SFSDKAuthSession *)session;
@end

@interface SFSDKOAuthTokenEndpointResponse (Testing)
- (instancetype)initWithDictionary:(NSDictionary *)nvPairs parseAdditionalFields:(NSArray<NSString *> *)additionalOAuthParameterKeys;
@end
