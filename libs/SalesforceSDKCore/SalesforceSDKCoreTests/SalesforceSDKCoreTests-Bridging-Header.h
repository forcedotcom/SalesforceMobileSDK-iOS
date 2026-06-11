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

// Exposes the private `+clearAllComponents` selector so SFSDKDPoPTests can flush
// cached per-component loggers and force them to re-bind to a freshly installed
// SFLogReceiverFactory. See SFLogger.m.
@interface SFLogger (DPoPTestSupport)
+ (void)clearAllComponents;
@end
