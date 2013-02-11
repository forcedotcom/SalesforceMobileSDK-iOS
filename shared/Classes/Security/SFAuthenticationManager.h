/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 Author: Kevin Hawkins
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import "SFOAuthCoordinator.h"
#import "SFOAuthInfo.h"
#import "SFIdentityCoordinator.h"

@class SFAuthorizingViewController;

/**
 Callback block definition for OAuth completion callback.
 */
typedef void (^SFOAuthFlowSuccessCallbackBlock)(SFOAuthInfo *);

/**
 Callback block definition for OAuth failure callback.
 */
typedef void (^SFOAuthFlowFailureCallbackBlock)(SFOAuthInfo *, NSError *);

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

/**
 The singleton instance of the SFAuthenticationManager class.
 */
+ (SFAuthenticationManager *)sharedManager;

/**
 Kick off the login process.
 @param presentingViewController The view controller that will be used to display an OAuth view, where
 required.
 @param completionBlock The block of code to execute when the OAuth process completes.
 @param failureBlock The block of code to execute when OAuth fails due to revoked/expired credentials.
 */
- (void)login:(UIViewController *)presentingViewController
   completion:(SFOAuthFlowSuccessCallbackBlock)completionBlock
      failure:(SFOAuthFlowFailureCallbackBlock)failureBlock;

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
 Remove all cookies from the cookie store.
 */
+ (void)removeAllCookies;

/**
 Adds the access (session) token cookie to the web view, for authentication.
 @param domain The domain on which to set the cookie.
 */
+ (void)addSidCookieForDomain:(NSString*)domain;

@end
