//
//  SFOAuthCoordinator+Internal.h
//  SalesforceOAuth
//
//  Created by Michael Nachbaur on 6/30/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import "SFOAuthCoordinator.h"

@interface SFOAuthCoordinator ()

@property (nonatomic, assign) BOOL authenticating;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, assign) BOOL initialRequestLoaded;
@property (nonatomic, retain) NSTimer *userAgentFlowTimer;

- (void)beginUserAgentFlow;
- (void)beginTokenRefreshFlow;
- (void)handleRefreshResponse;
- (void)startUserAgentFlowTimer;
- (void)stopUserAgentFlowTimer;
- (void)userAgentFlowTimerFired:(NSTimer *)timer;

+ (NSDictionary *)parseQueryString:(NSString *)query;
+ (NSError *)errorWithType:(NSString *)type description:(NSString *)description;
+ (NSDate *)timestampStringToDate:(NSString *)timestamp;

@end


