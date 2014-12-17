//
//  SFOAuthFlowAndDelegate.m
//  SalesforceOAuth
//
//  Created by Kevin Hawkins on 12/16/14.
//  Copyright (c) 2014 Salesforce.com. All rights reserved.
//

#import "SFOAuthFlowAndDelegate.h"
#import "SFOAuthOrgAuthConfiguration.h"

@interface SFOAuthFlowAndDelegate ()

@property (nonatomic, strong) SFOAuthOrgAuthConfiguration *retOrgConf;
@property (nonatomic, strong) NSError *retOrgConfError;

@end

@implementation SFOAuthFlowAndDelegate

- (void)setRetrieveOrgAuthConfigurationData:(SFOAuthOrgAuthConfiguration *)config error:(NSError *)error {
    self.retOrgConf = config;
    self.retOrgConfError = error;
}

#pragma mark - SFOAuthCoordinatorFlow

- (void)beginUserAgentFlow {
    self.beginUserAgentFlowCalled = YES;
}

- (void)beginTokenEndpointFlow:(SFOAuthTokenEndpointFlow)flowType {
    self.beginUserAgentFlowCalled = YES;
    self.tokenEndpointFlowType = flowType;
}

- (void)beginNativeBrowserFlow {
    self.beginNativeBrowserFlowCalled = YES;
}

- (void)retrieveOrgAuthConfiguration:(void (^)(SFOAuthOrgAuthConfiguration *orgAuthConfig, NSError *error))retrievedAuthConfigBlock {
    if (retrievedAuthConfigBlock) {
        retrievedAuthConfigBlock(self.retOrgConf, self.retOrgConfError);
    }
}

- (void)handleTokenEndpointResponse {
    self.handleTokenEndpointResponseCalled = YES;
}

- (void)handleUserAgentResponse:(NSURL *)requestUrl {
    self.handleUserAgentResponseCalled = YES;
}

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view {
    self.didBeginAuthenticationWithViewCalled = YES;
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view {
    self.willBeginAuthenticationWithViewCalled = YES;
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didStartLoad:(UIWebView *)view {
    self.didStartLoadCalled = YES;
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFinishLoad:(UIWebView *)view error:(NSError*)errorOrNil {
    self.didFinishLoadCalled = YES;
}

- (void)oauthCoordinatorWillBeginAuthentication:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {
    self.willBeginAuthenticationCalled = YES;
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {
    self.didAuthenticateCalled = YES;
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info {
    self.didFailWithErrorCalled = YES;
}

- (BOOL)oauthCoordinatorIsNetworkAvailable:(SFOAuthCoordinator*)coordinator {
    self.isNetworkAvailableCalled = YES;
    return self.isNetworkAvailable;
}

@end
