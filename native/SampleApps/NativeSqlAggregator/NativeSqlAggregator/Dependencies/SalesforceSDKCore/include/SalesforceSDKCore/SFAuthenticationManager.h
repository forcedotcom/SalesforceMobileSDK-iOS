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

/**
 Identifies the notification for the login host changing in the app's settings.
 */
extern NSString * const kSFLoginHostChangedNotification;

/**
 The key for the original host in a login host change notification.
 */
extern NSString * const kSFLoginHostChangedNotificationOriginalHostKey;

/**
 The key for the updated host in a login host change notification.
 */
extern NSString * const kSFLoginHostChangedNotificationUpdatedHostKey;

/**
 Identifies the notification for the user being logged out of the application.
 */
extern NSString * const kSFUserLogoutNotification;

@interface SFAuthenticationManager : NSObject <SFOAuthCoordinatorDelegate, SFIdentityCoordinatorDelegate>

/**
 Alert view for displaying auth-related status messages.
 */
@property (nonatomic, strong) UIAlertView *statusAlert;

/**
 The view controller used to present the authentication dialog.
 */
@property (nonatomic, strong) SFAuthorizingViewController *authViewController;

/**
 Whether or not the application is currently in the process of authenticating.
 */
@property (nonatomic, readonly) BOOL authenticating;

/**
 If this property is set, the authentication manager will swap a "blank" view in place
 of the currently displayed view when the app goes into the background, to protect sensitive displayed
 data from being captured in an image file by iOS.  This view will be swapped out for the original
 view when the app enters the foreground.  This property is set to YES by default.
 
 @see snapshotView
 */
@property (nonatomic, assign) BOOL useSnapshotView;

/**
 A view to be swapped in for the currently displayed view when the app enters the background, to prevent
 iOS from capturing sensitive data into an image file.  By default, this will be an opaque white screen,
 but you can set this property to any UIView, prior to app backgrounding, to use that view instead.
 
 @see useSnapshotView which toggles this behavior.
 */
@property (nonatomic, strong) UIView *snapshotView;

/**
 The preferred passcode provider to use.  In this release, In this release, defaults to
 kSFPasscodeProviderPBKDF2.  See SFPasscodeProviderManager.
 NOTE: If you wanted to set your own provider, you could do the following:
         id<SFPasscodeProvider> *myProvider = [[MyProvider alloc] initWithProviderName:myProviderName];
         [SFPasscodeProviderManager addPasscodeProvider:myProvider];
         [SFAuthenticationManager sharedManager].preferredPasscodeProvider = myProviderName;
 */
@property (nonatomic, copy) NSString *preferredPasscodeProvider;

/**
 The singleton instance of the SFAuthenticationManager class.
 */
+ (SFAuthenticationManager *)sharedManager;

/**
 Kick off the login process.
 @param completionBlock The block of code to execute when the authentication process successfully completes.
 @param failureBlock The block of code to execute when the authentication process has a fatal failure.
 @return YES if this call kicks off the authentication process.  NO if an authentication process has already
 started, in which case subsequent requests are queued up to have their completion or failure blocks executed
 in succession.
 */
- (BOOL)loginWithCompletion:(SFOAuthFlowSuccessCallbackBlock)completionBlock
                    failure:(SFOAuthFlowFailureCallbackBlock)failureBlock;

/**
 Forces a logout from the current account, redirecting the user to the login process.
 This throws out the OAuth refresh token.
 */
- (void)logout;

/**
 Cancels an in-progress authentication.  In-progress authentication state will be cleared.
 */
- (void)cancelAuthentication;

- (void)appDidFinishLaunching:(NSNotification *)notification;

/**
 Notification handler for when the app enters the foreground.
 @param notification The notification data associated with the event.
 */
- (void)appWillEnterForeground:(NSNotification *)notification;

/**
 Notification handler for when the app enters the background.
 @param notification The notification data associated with the event.
 */
- (void)appDidEnterBackground:(NSNotification *)notification;

/**
 Notification handler for when the app will be terminated.
 @param notification The notification data associated with the event.
 */
- (void)appWillTerminate:(NSNotification *)notification;

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
