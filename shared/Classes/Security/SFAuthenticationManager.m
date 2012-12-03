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

#import "SFApplication.h"
#import "SFAuthenticationManager.h"
#import "SFOAuthCredentials.h"
#import "SFOAuthInfo.h"
#import "SFAccountManager.h"
#import "SalesforceSDKConstants.h"
#import "SFAuthorizingViewController.h"
#import "SFSecurityLockout.h"
#import "SFIdentityData.h"
#import "SFLogger.h"
#import "NSURL+SFAdditions.h"

static SFAuthenticationManager *sharedInstance = nil;

// Private constants

static NSInteger  const kOAuthAlertViewTag    = 444;
static NSInteger  const kIdentityAlertViewTag = 555;

@interface SFAuthenticationManager ()
{
    /**
     Whether this is the initial login to the application (i.e. no previous credentials).
     */
    BOOL _isInitialLogin;
}

/**
 The block to be called when the OAuth process completes.
 */
@property (nonatomic, copy) SFOAuthFlowCallbackBlock completionBlock;

/**
 The block to be called if the OAuth process fails.  Note: failure is currently defined as
 a scenario where there are no valid credentials in the refresh flow.
 */
@property (nonatomic, copy) SFOAuthFlowCallbackBlock failureBlock;

/**
 Dismisses the authentication retry alert box, if present.
 */
- (void)cleanupRetryAlert;

/**
 Method to present the authorizing view controller with the given auth webView.
 @param webView The auth webView to present.
 */
- (void)presentAuthViewController:(UIWebView *)webView;

/**
 Dismisses the auth view controller, taking the dismissal action once the view has
 been dismissed.
 @param postDismissalAction The selector representing the action to take once the view
 has been dismissed.
 */
- (void)dismissAuthViewControllerIfPresent:(SEL)postDismissalAction;

/**
 Called after identity data is retrieved from the service.
 */
- (void)retrievedIdentityData;

/**
 Kick off the login process (post-configuration in the public method).
 */
- (void)login;

/**
 Execute the configured completion block, if in fact configured.
 */
- (void)execCompletionBlock;

/**
 Execute the configured failure block, if in fact configured.
 */
- (void)execFailureBlock;

/**
 Displays an alert in the event of an unknown failure for OAuth or Identity requests, allowing the user
 to retry the process.
 @param tag The tag that identifies the process (OAuth or Identity).
 */
- (void)showRetryAlertForAuthError:(NSError *)error alertTag:(NSInteger)tag;

@end

@implementation SFAuthenticationManager

@synthesize viewController = _viewController;
@synthesize authViewController = _authViewController;
@synthesize statusAlert = _statusAlert;
@synthesize completionBlock = _completionBlock, failureBlock = _failureBlock;

#pragma mark - Singleton initialization / management

+ (SFAuthenticationManager *)sharedManager
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [[self sharedManager] retain];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (NSUInteger)retainCount
{
    return NSUIntegerMax;  //denotes an object that cannot be released
}

- (oneway void)release
{
    //do nothing
}

- (id)autorelease
{
    return self;
}

#pragma mark - Init / dealloc / etc.

- (void)dealloc
{
    [self cleanupRetryAlert];
    SFRelease(_statusAlert);
    SFRelease(_authViewController);
    SFRelease(_viewController);
    SFRelease(_completionBlock);
    SFRelease(_failureBlock);
    [super dealloc];
}

#pragma mark - Public methods

- (void)login:(UIViewController *)presentingViewController
   completion:(SFOAuthFlowCallbackBlock)completionBlock
      failure:(SFOAuthFlowCallbackBlock)failureBlock
{
    NSAssert(presentingViewController != nil, @"Presenting view controller cannot be nil.");
    self.viewController = presentingViewController;
    self.completionBlock = completionBlock;
    self.failureBlock = failureBlock;
    
    // Strictly for internal tracking, assume we've got our initial credentials, until
    // OAuth tells us otherwise.  E.g. we only want to call the identity service after
    // we first authenticate.  If oauthCoordinator:didBeginAuthenticationWithView: isn't
    // called, we can assume we've already gone through initial authentication at some point.
    _isInitialLogin = NO;
    
    // Kick off authentication.
    [self login];
}

- (void)loggedIn
{
    // If this is the initial login, or there's no persisted identity data, get the data
    // from the service.
    if (_isInitialLogin || [SFAccountManager sharedInstance].idData == nil) {
        [SFAccountManager sharedInstance].idDelegate = self;
        [[SFAccountManager sharedInstance].idCoordinator initiateIdentityDataRetrieval];
    } else {
        // Just go directly to the post-processing step.
        [self execCompletionBlock];
    }
}

- (void)logout
{
    id<UIApplicationDelegate> appDelegate = [[UIApplication sharedApplication] delegate];
    if ([appDelegate conformsToProtocol:@protocol(SFSDKAppDelegate)]) {
        id<SFSDKAppDelegate> sdkAppDelegate = (id<SFSDKAppDelegate>)appDelegate;
        [sdkAppDelegate logout];
    } else {
        [self log:SFLogLevelWarning msg:@"[SFAuthenticationManager logout]: App delegate does NOT implement SFSDKAppDelegate protocol.  No action taken.  Implement SFSDKAppDelegate if you wish to use this functionality."];
    }
}

+ (void)resetSessionCookie
{
    [self removeCookies:[NSArray arrayWithObjects:@"sid", nil]
            fromDomains:[NSArray arrayWithObjects:@".salesforce.com", @".force.com", nil]];
    [self addSidCookieForDomain:@".salesforce.com"];
}

+ (void)removeCookies:(NSArray *)cookieNames fromDomains:(NSArray *)domainNames
{
    NSAssert(cookieNames != nil && [cookieNames count] > 0, @"No cookie names given to delete.");
    NSAssert(domainNames != nil && [domainNames count] > 0, @"No domain names given for deleting cookies.");
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *fullCookieList = [NSArray arrayWithArray:[cookieStorage cookies]];
    for (NSHTTPCookie *cookie in fullCookieList) {
        for (NSString *cookieToRemoveName in cookieNames) {
            if ([[[cookie name] lowercaseString] isEqualToString:[cookieToRemoveName lowercaseString]]) {
                for (NSString *domainToRemoveName in domainNames) {
                    if ([[[cookie domain] lowercaseString] hasSuffix:[domainToRemoveName lowercaseString]])
                    {
                        [cookieStorage deleteCookie:cookie];
                    }
                }
            }
        }
    }
}

+ (void)addSidCookieForDomain:(NSString*)domain
{
    NSAssert(domain != nil && [domain length] > 0, @"addSidCookieForDomain: domain cannot be empty");
    [self log:SFLogLevelDebug format:@"addSidCookieForDomain: %@", domain];
    
    // Set the session ID cookie to be used by the web view.
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    [cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    
    NSMutableDictionary *newSidCookieProperties = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                   domain, NSHTTPCookieDomain,
                                                   @"/", NSHTTPCookiePath,
                                                   [SFAccountManager sharedInstance].coordinator.credentials.accessToken, NSHTTPCookieValue,
                                                   @"sid", NSHTTPCookieName,
                                                   @"TRUE", NSHTTPCookieDiscard,
                                                   nil];
    if ([[SFAccountManager sharedInstance].coordinator.credentials.protocol isEqualToString:@"https"]) {
        [newSidCookieProperties setObject:@"TRUE" forKey:NSHTTPCookieSecure];
    }
    
    NSHTTPCookie *sidCookie0 = [NSHTTPCookie cookieWithProperties:newSidCookieProperties];
    [cookieStorage setCookie:sidCookie0];
}

+ (NSURL *)frontDoorUrlWithReturnUrl:(NSString *)returnUrl returnUrlIsEncoded:(BOOL)isEncoded
{
    NSString *encodedUrl = (isEncoded ? returnUrl : [returnUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]);
    SFOAuthCredentials *creds = [SFAccountManager sharedInstance].credentials;
    NSMutableString *frontDoorUrl = [NSMutableString stringWithString:[creds.instanceUrl absoluteString]];
    if (![frontDoorUrl hasSuffix:@"/"])
        [frontDoorUrl appendString:@"/"];
    NSString *encodedSidValue = [creds.accessToken stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [frontDoorUrl appendFormat:@"secur/frontdoor.jsp?sid=%@&retURL=%@&display=touch", encodedSidValue, encodedUrl];
    
    return [NSURL URLWithString:frontDoorUrl];
}

+ (BOOL)isLoginRedirectUrl:(NSURL *)url
{
    if (url == nil || [url absoluteString] == nil || [[url absoluteString] length] == 0)
        return NO;
    
    BOOL urlMatchesLoginRedirectPattern = NO;
    if ([[[url scheme] lowercaseString] hasPrefix:@"http"]
        && [[url path] isEqualToString:@"/"]
        && [url query] != nil) {
        
        NSString *startUrlValue = [url valueForParameterName:@"startURL"];
        NSString *ecValue = [url valueForParameterName:@"ec"];
        BOOL foundStartURL = (startUrlValue != nil);
        BOOL foundValidEcValue = ([ecValue isEqualToString:@"301"] || [ecValue isEqualToString:@"302"]);
        
        urlMatchesLoginRedirectPattern = (foundStartURL && foundValidEcValue);
    }
    
    return urlMatchesLoginRedirectPattern;
    
}

#pragma mark - Private methods

- (void)execCompletionBlock
{
    if (self.completionBlock) {
        SFOAuthFlowCallbackBlock copiedBlock = [[self.completionBlock copy] autorelease];
        copiedBlock();
    }
}

- (void)execFailureBlock
{
    if (self.failureBlock) {
        SFOAuthFlowCallbackBlock copiedBlock = [[self.failureBlock copy] autorelease];
        copiedBlock();
    }
}

- (void)login
{
    [SFAccountManager sharedInstance].oauthDelegate = self;
    [[SFAccountManager sharedInstance].coordinator authenticate];
}

- (void)cleanupRetryAlert
{
    [_statusAlert dismissWithClickedButtonIndex:-666 animated:NO];
    [_statusAlert setDelegate:nil];
    SFRelease(_statusAlert);
}

- (void)presentAuthViewController:(UIWebView *)webView
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentAuthViewController:webView];
        });
        return;
    }
    
    // TODO: This is another NIB file that's delivered as part of the app templates, and should be
    // moved into a bundle (along with the root vc NIB file mentioned above.
    [self log:SFLogLevelDebug msg:@"SFOAuthFlowManager: Presenting auth view controller."];
    self.authViewController = [[[SFAuthorizingViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    [self.authViewController setOauthView:webView];
    [self.viewController presentViewController:self.authViewController animated:YES completion:NULL];
}

- (void)dismissAuthViewControllerIfPresent:(SEL)postDismissalAction
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissAuthViewControllerIfPresent:postDismissalAction];
        });
        return;
    }
    
    if (self.authViewController != nil) {
        [self log:SFLogLevelDebug msg:@"Dismissing the auth view controller."];
        [self.authViewController.presentingViewController dismissViewControllerAnimated:YES
                                                                             completion:^{
                                                                                 self.authViewController = nil;
                                                                                 [self performSelector:postDismissalAction];
                                                                             }];
    } else {
        [self performSelector:postDismissalAction];
    }
}

- (void)retrievedIdentityData
{
    // NB: This method is assumed to run after identity data has been refreshed from the service.
    NSAssert([SFAccountManager sharedInstance].idData != nil, @"Identity data should not be nil/empty at this point.");
    
    if ([[SFAccountManager sharedInstance] mobilePinPolicyConfigured]) {
        // Set the callback actions for post-passcode entry/configuration.
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:^{
            [self execCompletionBlock];
        }];
        [SFSecurityLockout setLockScreenFailureCallbackBlock:^{  // Don't know how this would happen, but if it does....
            [self execFailureBlock];
        }];
        
        // setLockoutTime triggers passcode creation.  We could consider a more explicit call for visibility here?
        [SFSecurityLockout setPasscodeLength:[SFAccountManager sharedInstance].idData.mobileAppPinLength];
        [SFSecurityLockout setLockoutTime:([SFAccountManager sharedInstance].idData.mobileAppScreenLockTimeout * 60)];
    } else {
        // No additional mobile policies.  So no passcode.
        [self execCompletionBlock];
    }
}

- (void)showRetryAlertForAuthError:(NSError *)error alertTag:(NSInteger)tag
{
    if (nil == _statusAlert) {
        // show alert and allow retry
        _statusAlert = [[UIAlertView alloc] initWithTitle:@"Salesforce Error"
                                                  message:[NSString stringWithFormat:@"Can't connect to salesforce: %@", error]
                                                 delegate:self
                                        cancelButtonTitle:@"Retry"
                                        otherButtonTitles: nil];
        _statusAlert.tag = tag;
        [_statusAlert show];
    }
}

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view
{
    [self log:SFLogLevelDebug msg:@"SFOAuthFlowManager: oauthCoordinator:willBeginAuthenticationWithView"];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view
{
    [self log:SFLogLevelDebug msg:@"SFOAuthFlowManager: oauthCoordinator:didBeginAuthenticationWithView"];
    _isInitialLogin = YES;
    [self presentAuthViewController:view];
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info
{
    [self log:SFLogLevelDebug format:@"SFOAuthFlowManager: oauthCoordinatorDidAuthenticate for userId: %@, auth info: %@", coordinator.credentials.userId, info];
    [self dismissAuthViewControllerIfPresent:@selector(loggedIn)];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info
{
    [self log:SFLogLevelDebug format:@"SFOAuthFlowManager: oauthCoordinator:didFailWithError: %@, authInfo: %@", error, info];
    
    BOOL showAlert = YES;
    if (info.authType == SFOAuthTypeRefresh) {
        if (error.code == kSFOAuthErrorInvalidGrant) {  //invalid cached refresh token
            // Restart the login process asynchronously.
            showAlert = NO;
            [self log:SFLogLevelWarning format:@"OAuth refresh failed due to invalid grant.  Error code: %d", error.code];
            [self execFailureBlock];
        } else if ([SFAccountManager errorIsNetworkFailure:error]) {
            // Couldn't connect to server to refresh.  Assume valid credentials until the next attempt.
            showAlert = NO;
            [self log:SFLogLevelWarning format:@"Auth token refresh couldn't connect to server: %@", [error localizedDescription]];
            
            [self loggedIn];
        }
    }
    
    if (showAlert) {
        // show alert and retry
        [[SFAccountManager sharedInstance] clearAccountState:NO];
        [self showRetryAlertForAuthError:error alertTag:kOAuthAlertViewTag];
    }
}

#pragma mark - SFIdentityCoordinatorDelegate

- (void)identityCoordinatorRetrievedData:(SFIdentityCoordinator *)coordinator
{
    [self retrievedIdentityData];
}

- (void)identityCoordinator:(SFIdentityCoordinator *)coordinator didFailWithError:(NSError *)error
{
    [self showRetryAlertForAuthError:error alertTag:kIdentityAlertViewTag];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView == _statusAlert) {
        [self log:SFLogLevelDebug format:@"clickedButtonAtIndex: %d", buttonIndex];
        if (alertView.tag == kOAuthAlertViewTag) {
            [self dismissAuthViewControllerIfPresent:@selector(login)];
        } else if (alertView.tag == kIdentityAlertViewTag) {
            [[SFAccountManager sharedInstance].idCoordinator initiateIdentityDataRetrieval];
        }
    }
}

@end
