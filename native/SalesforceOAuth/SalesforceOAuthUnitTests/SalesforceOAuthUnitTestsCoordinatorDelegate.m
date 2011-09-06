//
//  SalesforceOAuthUnitTestsCoordinatorDelegate.m
//  SalesforceOAuth
//
//  Created by Steve Holly on 7/19/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import "SFOAuthCoordinator.h"
#import "SalesforceOAuthUnitTestsCoordinatorDelegate.h"

@implementation SalesforceOAuthUnitTestsCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view {
    // we should never be called here as the test sets a refresh token in the credentials, 
    // therefore we do the refresh flow instead of the user agent flow
    STFail(@"user agent authentication flow should not begin");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view {
    // we should never be called here as the test sets a refresh token in the credentials, 
    // therefore we do the refresh flow instead of the user agent flow
    STFail(@"user agent authentication flow should not begin");
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator {
    // authentication is performed against localhost (which presumably has no oauth process listening) 
    // and authentication is immediately cancelled after being started, so the authentication should 
    // never succeed.
    STFail(@"coordinator test should not be able to authenticate");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error {
    // authentication is cancelled before a timeout can occur, so the test should not fail
    STFail(@"user agent authentication flow should not fail");
}

@end
