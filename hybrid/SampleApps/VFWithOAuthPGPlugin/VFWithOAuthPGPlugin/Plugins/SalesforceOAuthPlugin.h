//
//  SalesforceOAuthPlugin.h
//  VFWithOAuthPlugin
//
//  Created by Kevin Hawkins on 11/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PhoneGap/PGPlugin.h>
#import "SFOAuthCoordinator.h"

@class SFAuthorizingViewController;
@class AppDelegate;


@interface SalesforceOAuthPlugin : PGPlugin <SFOAuthCoordinatorDelegate, UIAlertViewDelegate> {
    SFOAuthCoordinator *_coordinator;
    SFAuthorizingViewController *_authViewController;
    AppDelegate *_appDelegate;
    NSString *_callbackId;
    BOOL _isAuthenticating;
    NSString *_remoteAccessConsumerKey;
    NSString *_oauthRedirectURI;
    NSString *_oauthLoginDomain;
    NSString *_userAccountIdentifier;
    NSSet *_oauthScopes;
}

/**
 The SFOAuthCoordinator used for managing login/logout.
 */
@property (nonatomic, readonly) SFOAuthCoordinator *coordinator;

/**
 View controller that gives the app some view state while authorizing.
 */
@property (nonatomic, retain) SFAuthorizingViewController *authViewController;

/**
 The Remote Access object consumer key.
 */
@property (nonatomic, copy) NSString *remoteAccessConsumerKey;

/**
 The Remote Access object redirect URI
 */
@property (nonatomic, copy) NSString *oauthRedirectURI;

/**
 The Remote Access object Login Domain
 */
@property (nonatomic, copy) NSString *oauthLoginDomain;

/**
 The set of oauth scopes that should be requested for this app.
 */
@property (nonatomic, retain) NSSet *oauthScopes;

/**
 An account identifier such as most recently used username.
 */
@property (nonatomic, copy) NSString *userAccountIdentifier;

/**
 Forces a logout from the current account.
 This throws out the OAuth refresh token.
 */
- (void)logout;

/**
 This disposes of any current data.
 */
- (void)clearDataModel;

/**
 Kickoff the login process.
 */
- (void)login;

/**
 Sent whenever the use has been logged in using current settings.
 Be sure to call super if you override this.
 */
- (void)loggedIn;

// TODO: Add comments.
- (void)getLoginHost:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)authenticate:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (BOOL)resetAppState;

@end
