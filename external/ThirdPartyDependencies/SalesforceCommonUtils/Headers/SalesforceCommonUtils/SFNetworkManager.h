//
//  SFNetworkManager.h
//  SalesforceSDK
//
//  Created by Michael Nachbaur on 2/23/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFReachability.h"

extern NSString * const SFNetworkManagerAvailabilityChangedNotification;
extern NSString * const SFNetworkManagerMonitoringHostname;

@interface SFNetworkManager : NSObject {
	NSString *_targetHostName;
	BOOL _networkAvailable;
}

@property (nonatomic, strong, readonly) SFReachability *reachability;

+ (instancetype)networkManagerForUserWithOrgId:(NSString *)orgId userId:(NSString *)userId communityId:(NSString *)communityId apiURl:(NSURL *)apiURL;

- (BOOL)isNetworkAvailable;
- (BOOL)isHostReachable;
- (void)startNetworkMonitoring;
- (void)stopNetworkMonitoring;
- (NetworkStatus)currentReachabilityStatus;

@end
