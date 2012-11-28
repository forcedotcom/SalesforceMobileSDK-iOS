//
//  SFOAuthFlowManager.m
//  SalesforceHybridSDK
//
//  Created by Kevin Hawkins on 11/15/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import "SFOAuthFlowManager.h"
#import "SFOAuthInfo.h"
#import "SFAccountManager.h"
#import "SalesforceSDKConstants.h"
#import "SFAuthorizingViewController.h"
#import "SFSecurityLockout.h"
#import "SFIdentityData.h"

// Private constants

static NSInteger  const kOAuthAlertViewTag    = 444;
static NSInteger  const kIdentityAlertViewTag = 555;

@interface SFOAuthFlowManager ()
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

@implementation SFOAuthFlowManager

@synthesize viewController = _viewController;
@synthesize authViewController = _authViewController;
@synthesize statusAlert = _statusAlert;
@synthesize completionBlock = _completionBlock, failureBlock = _failureBlock;

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
    NSLog(@"SFOAuthFlowManager: Presenting auth view controller.");
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
        NSLog(@"Dismissing the auth view controller.");
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
    NSLog(@"SFOAuthFlowManager: oauthCoordinator:willBeginAuthenticationWithView");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view
{
    NSLog(@"SFOAuthFlowManager: oauthCoordinator:didBeginAuthenticationWithView");
    _isInitialLogin = YES;
    [self presentAuthViewController:view];
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info
{
    NSLog(@"SFOAuthFlowManager: oauthCoordinatorDidAuthenticate for userId: %@, auth info: %@", coordinator.credentials.userId, info);
    [self dismissAuthViewControllerIfPresent:@selector(loggedIn)];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info
{
    NSLog(@"SFOAuthFlowManager: oauthCoordinator:didFailWithError: %@, authInfo: %@", error, info);
    
    BOOL showAlert = YES;
    if (info.authType == SFOAuthTypeRefresh) {
        if (error.code == kSFOAuthErrorInvalidGrant) {  //invalid cached refresh token
            // Restart the login process asynchronously.
            showAlert = NO;
            NSLog(@"OAuth refresh failed with error code: %d", error.code);
            [self execFailureBlock];
        } else if ([SFAccountManager errorIsNetworkFailure:error]) {
            // Couldn't connect to server to refresh.  Assume valid credentials until the next attempt.
            showAlert = NO;
            NSLog(@"Auth token refresh couldn't connect to server: %@", [error localizedDescription]);
            
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
        NSLog(@"clickedButtonAtIndex: %d",buttonIndex);
        if (alertView.tag == kOAuthAlertViewTag) {
            [self dismissAuthViewControllerIfPresent:@selector(login)];
        } else if (alertView.tag == kIdentityAlertViewTag) {
            [[SFAccountManager sharedInstance].idCoordinator initiateIdentityDataRetrieval];
        }
    }
}

@end
