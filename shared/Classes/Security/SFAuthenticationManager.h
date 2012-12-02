//
//  SFOAuthFlowManager.h
//  SalesforceHybridSDK
//
//  Created by Kevin Hawkins on 11/15/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFOAuthCoordinator.h"
#import "SFIdentityCoordinator.h"

@class SFAuthorizingViewController;

/**
 Callback block definition for OAuth completion/failure callbacks.
 */
typedef void (^SFOAuthFlowCallbackBlock)(void);

@interface SFAuthenticationManager : NSObject <SFOAuthCoordinatorDelegate, SFIdentityCoordinatorDelegate>

/**
 The view controller that will be used to "host" an OAuth view, if necessary.
 */
@property (nonatomic, retain) UIViewController *viewController;

/**
 Alert view for displaying auth-related status messages.
 */
@property (nonatomic, retain) UIAlertView *statusAlert;

/**
 The view controller used to present the authentication dialog.
 */
@property (nonatomic, retain) SFAuthorizingViewController *authViewController;

+ (SFAuthenticationManager *)sharedManager;

/**
 Kick off the login process.
 @param presentingViewController The view controller that will be used to display an OAuth view, where
 required.
 @param completionBlock The block of code to execute when the OAuth process completes.
 @param failureBlock The block of code to execute when OAuth fails due to revoked/expired credentials.
 */
- (void)login:(UIViewController *)presentingViewController
   completion:(SFOAuthFlowCallbackBlock)completionBlock
      failure:(SFOAuthFlowCallbackBlock)failureBlock;

/**
 Sent whenever the user has been logged in using current settings.
 Be sure to call super if you override this.
 */
- (void)loggedIn;

/**
 Forces a logout from the current account, redirecting the user to the login process.
 This throws out the OAuth refresh token.
 */
- (void)logout;

/**
 Clears session cookie data from the cookie store, and sets a new session cookie based on the
 OAuth credentials.
 */
+ (void)resetSessionCookie;

/**
 Creates an absolute URL to frontdoor with the given destination URL.
 @param returnUrl The destination URL to hit after going through frontdoor.
 @param isEncoded Whether or not the returnUrl value is URL-encoded.
 @return An NSURL object representing the configured frontdoor URL.
 */
+ (NSURL *)frontDoorUrlWithReturnUrl:(NSString *)returnUrl returnUrlIsEncoded:(BOOL)isEncoded;

/**
 Whether or not the given URL can be identified as a redirect to the login URL, loaded when the
 session expires.
 @param url The URL to evaluate.
 @return YES if the URL matches the login redirect URL pattern, NO otherwise.
 */
+ (BOOL)isLoginRedirectUrl:(NSURL *)url;

/**
 Remove any cookies with the given names from the given domains.
 @param cookieNames The names of the cookies to remove.
 @param domainNames The names of the domains where the cookies are set.
 */
+ (void)removeCookies:(NSArray *)cookieNames fromDomains:(NSArray *)domainNames;

/**
 Adds the access (session) token cookie to the web view, for authentication.
 @param domain The domain on which to set the cookie.
 */
+ (void)addSidCookieForDomain:(NSString*)domain;

@end
