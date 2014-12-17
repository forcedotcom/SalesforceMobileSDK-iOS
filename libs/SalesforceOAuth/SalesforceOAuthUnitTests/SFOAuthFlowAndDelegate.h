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

@interface SFOAuthFlowAndDelegate : NSObject <SFOAuthCoordinatorDelegate, SFOAuthCoordinatorFlow>

@property (nonatomic, assign) BOOL beginUserAgentFlowCalled;
@property (nonatomic, assign) BOOL beginTokenEndpointFlowCalled;
@property (nonatomic, assign) BOOL beginNativeBrowserFlowCalled;
@property (nonatomic, assign) SFOAuthTokenEndpointFlow tokenEndpointFlowType;
@property (nonatomic, assign) BOOL handleTokenEndpointResponseCalled;
@property (nonatomic, assign) BOOL handleUserAgentResponseCalled;
@property (nonatomic, assign) BOOL didBeginAuthenticationWithViewCalled;
@property (nonatomic, assign) BOOL willBeginAuthenticationWithViewCalled;
@property (nonatomic, assign) BOOL didStartLoadCalled;
@property (nonatomic, assign) BOOL didFinishLoadCalled;
@property (nonatomic, assign) BOOL willBeginAuthenticationCalled;
@property (nonatomic, assign) BOOL didAuthenticateCalled;
@property (nonatomic, assign) BOOL didFailWithErrorCalled;
@property (nonatomic, assign) BOOL isNetworkAvailableCalled;

@property (nonatomic, assign) BOOL isNetworkAvailable;

- (void)setRetrieveOrgAuthConfigurationData:(SFOAuthOrgAuthConfiguration *)config error:(NSError *)error;

@end
