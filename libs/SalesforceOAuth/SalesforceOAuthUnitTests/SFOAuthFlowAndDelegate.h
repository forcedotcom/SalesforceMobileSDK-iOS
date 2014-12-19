//
//  SFOAuthFlowAndDelegate.h
//  SalesforceOAuth
//
//  Created by Kevin Hawkins on 12/16/14.
//  Copyright (c) 2014 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFOAuthCoordinator+Internal.h"

@class SFOAuthOrgAuthConfiguration;
@class SFOAuthInfo;

@interface SFOAuthFlowAndDelegate : NSObject <SFOAuthCoordinatorDelegate, SFOAuthCoordinatorFlow>

@property (nonatomic, assign) BOOL beginUserAgentFlowCalled;
@property (nonatomic, assign) BOOL beginTokenEndpointFlowCalled;
@property (nonatomic, assign) BOOL beginNativeBrowserFlowCalled;
@property (nonatomic, assign) SFOAuthTokenEndpointFlow tokenEndpointFlowType;
@property (nonatomic, assign) BOOL handleTokenEndpointResponseCalled;
@property (nonatomic, assign) BOOL willBeginAuthenticationCalled;
@property (nonatomic, assign) BOOL didAuthenticateCalled;
@property (nonatomic, assign) BOOL didFailWithErrorCalled;
@property (nonatomic, assign) BOOL isNetworkAvailableCalled;
@property (nonatomic, strong) SFOAuthInfo *authInfo;
@property (nonatomic, strong) NSError *didFailWithError;

@property (nonatomic, assign) BOOL isNetworkAvailable;
@property (nonatomic, assign) NSTimeInterval timeBeforeUserAgentCompletion;
@property (nonatomic, assign) BOOL userAgentFlowIsSuccessful;

- (id)initWithCoordinator:(SFOAuthCoordinator *)coordinator;
- (void)setRetrieveOrgAuthConfigurationData:(SFOAuthOrgAuthConfiguration *)config error:(NSError *)error;

@end
