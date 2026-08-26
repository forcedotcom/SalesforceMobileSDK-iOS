//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SalesforceSDKCommon/SFLogger.h>
#import "SFSDKLogoutBlocker.h"
#import "SFSDKAuthRequest.h"
#import "SFSDKAuthSession.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFUserAccountManager+Internal.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFSDKOAuth2.h"
#import "SFLoginViewController.h"

// Exposes the private `+clearAllComponents` selector so SFSDKDPoPTests can flush
// cached per-component loggers and force them to re-bind to a freshly installed
// SFLogReceiverFactory. See SFLogger.m.
@interface SFLogger (DPoPTestSupport)
+ (void)clearAllComponents;
@end

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

/// Exposes private browser-login telemetry helpers for unit testing.
@interface SFUserAccountManager (BrowserLoginTelemetryTesting)
- (nullable NSString *)computeBMarkerForAuthSession:(nonnull SFSDKAuthSession *)authSession completedAuthType:(SFOAuthType)completedAuthType;
- (nullable NSString *)computeLMarkerForDomain:(nullable NSString *)domain usedWelcomeDiscovery:(BOOL)usedWelcomeDiscovery;
@end
