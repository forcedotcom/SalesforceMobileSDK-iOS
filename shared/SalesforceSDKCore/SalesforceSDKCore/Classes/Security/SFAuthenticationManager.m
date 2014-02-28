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
#import <SalesforceOAuth/SFOAuthCredentials.h>
#import <SalesforceOAuth/SFOAuthInfo.h>
#import "SFAccountManager.h"
#import "SFAuthenticationViewHandler.h"
#import "SFAuthErrorHandler.h"
#import "SFAuthErrorHandlerList.h"
#import "SFAuthorizingViewController.h"
#import "SFSecurityLockout.h"
#import "SFIdentityData.h"
#import <SalesforceCommonUtils/NSURL+SFAdditions.h>
#import "SFSDKResourceUtils.h"
#import "SFRootViewManager.h"
#import "SFUserActivityMonitor.h"
#import "SFPasscodeManager.h"
#import "SFPasscodeProviderManager.h"
#import "SFPushNotificationManager.h"
#import <SalesforceCommonUtils/SFInactivityTimerCenter.h>

static SFAuthenticationManager *sharedInstance = nil;

// Public notification name constants

NSString * const kSFLoginHostChangedNotification = @"kSFLoginHostChanged";
NSString * const kSFLoginHostChangedNotificationOriginalHostKey = @"originalLoginHost";
NSString * const kSFLoginHostChangedNotificationUpdatedHostKey = @"updatedLoginHost";
NSString * const kSFUserLogoutNotification = @"kSFUserLogoutOccurred";
NSString * const kSFUserLoggedInNotification = @"kSFUserLoggedIn";

// Auth error handler name constants

static NSString * const kSFInvalidCredentialsAuthErrorHandler = @"InvalidCredentialsErrorHandler";
static NSString * const kSFConnectedAppVersionAuthErrorHandler = @"ConnectedAppVersionErrorHandler";
static NSString * const kSFNetworkFailureAuthErrorHandler = @"NetworkFailureErrorHandler";
static NSString * const kSFGenericFailureAuthErrorHandler = @"GenericFailureErrorHandler";

// Private constants

static NSInteger  const kOAuthGenericAlertViewTag    = 444;
static NSInteger  const kIdentityAlertViewTag = 555;
static NSInteger  const kConnectedAppVersionMismatchViewTag = 666;

static NSString * const kAlertErrorTitleKey = @"authAlertErrorTitle";
static NSString * const kAlertOkButtonKey = @"authAlertOkButton";
static NSString * const kAlertRetryButtonKey = @"authAlertRetryButton";
static NSString * const kAlertConnectionErrorFormatStringKey = @"authAlertConnectionErrorFormatString";
static NSString * const kAlertVersionMismatchErrorKey = @"authAlertVersionMismatchError";

#pragma mark - SFAuthBlockPair

/**
 Data class containing a pair of completion blocks for authentication: one for success,
 and one for failure.
 */
@interface SFAuthBlockPair : NSObject

/**
 The success block of the pair.
 */
@property (nonatomic, copy) SFOAuthFlowSuccessCallbackBlock successBlock;

/**
 The failure block of the pair.
 */
@property (nonatomic, copy) SFOAuthFlowFailureCallbackBlock failureBlock;

/**
 Designated initializer for the data object.
 */
- (id)initWithSuccessBlock:(SFOAuthFlowSuccessCallbackBlock)successBlock
              failureBlock:(SFOAuthFlowFailureCallbackBlock)failureBlock;

@end

@implementation SFAuthBlockPair

@synthesize successBlock = _successBlock, failureBlock = _failureBlock;

- (id)initWithSuccessBlock:(SFOAuthFlowSuccessCallbackBlock)successBlock
              failureBlock:(SFOAuthFlowFailureCallbackBlock)failureBlock
{
    self = [super init];
    if (self) {
        self.successBlock = successBlock;
        self.failureBlock = failureBlock;
    }
    
    return self;
}

//
// Overrides to compare SFAuthBlockPair objects.
//

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[SFAuthBlockPair class]]) {
        return NO;
    }
    
    SFAuthBlockPair *authPairObj = (SFAuthBlockPair *)object;
    return ([self.successBlock isEqual:authPairObj.successBlock] && [self.failureBlock isEqual:authPairObj.failureBlock]);
}

- (NSUInteger)hash
{
    if (self.successBlock != NULL && self.failureBlock != NULL) {
        return [self.successBlock hash] + [self.failureBlock hash];
    } else {
        return [super hash];
    }
}

@end

#pragma mark - SFAuthenticationManager

@interface SFAuthenticationManager ()
{
    /**
     Will be YES when the app is launching, vs. NO when the app is simply being foregrounded.
     */
    BOOL _isAppLaunch;
    
    NSMutableArray *_delegates;
}

/**
 The auth info that gets sent back from OAuth.  This will be sent back to the login consumer.
 */
@property (nonatomic, strong) SFOAuthInfo *authInfo;

/**
 Any OAuth error information will get populated in this property and sent back to the consumer,
 in the event of an OAuth failure.
 */
@property (nonatomic, strong) NSError *authError;

/**
 The list of blocks that will be associated with a given authentication attempt.  This allows
 more than one authentication workflow to piggy back on an in-progress authentication.
 */
@property (atomic, strong) NSMutableArray *authBlockList;

/**
 View controller that will display the security snapshot view.
 */
@property (nonatomic, strong) UIViewController *snapshotViewController;

/**
 Dismisses the authentication retry alert box, if present.
 */
- (void)cleanupStatusAlert;

/**
 Method to present the authorizing view controller with the given auth webView.
 @param webView The auth webView to present.
 */
- (void)presentAuthViewController:(UIWebView *)webView;

/**
 Dismisses the auth view controller, resetting the UI state back to its original
 presentation.
 */
- (void)dismissAuthViewControllerIfPresent;

/**
 Called after initial authentication has completed.
 */
- (void)loggedIn;

/**
 Called after identity data is retrieved from the service.
 */
- (void)retrievedIdentityData;

/**
 Manages the passcode checking after authentication.
 */
- (void)postAuthenticationToPasscodeProcessing;

/**
 The final method in the auth completion flow, before the configured completion
 block(s) are called.
 */
- (void)finalizeAuthCompletion;

/**
 Kick off the login process (post-configuration in the public method).
 */
- (void)login;

/**
 Execute the configured completion blocks, if in fact configured.
 */
- (void)execCompletionBlocks;

/**
 Execute the configured failure blocks, if in fact configured.
 */
- (void)execFailureBlocks;

/**
 Runs the given block of code against the list of auth manager delegates.
 @param block The block of code to execute for each delegate.
 */
- (void)enumerateDelegates:(void(^)(id<SFAuthenticationManagerDelegate> delegate))block;

/**
 Revoke the existing refresh token, in a fire-and-forget manner, such that
 we don't await a response from the server.
 */
- (void)revokeRefreshToken;

/**
 Displays an alert in the event of an unknown failure for OAuth or Identity requests, allowing the user
 to retry the process.
 @param tag The tag that identifies the process (OAuth or Identity).
 */
- (void)showRetryAlertForAuthError:(NSError *)error alertTag:(NSInteger)tag;

/**
 Displays an alert if the Connected App version on the server does not match the credentials of the client
 app.
 */
- (void)showAlertForConnectedAppVersionMismatchError;

/**
 Handles the data cleanup and login host swap when the host has changed in the app's settings.
 @param result The data associated with the host change.
 */
- (void)processLoginHostChange:(SFLoginHostUpdateResult *)result;

/**
 Sets up the security snapshot view of the screen when the app is backgrounding.
 */
- (void)setupSnapshotView;

/**
 Removes the security snapshot view of the screen when the app is foregrounding.
 */
- (void)removeSnapshotView;

/**
 Creates the default snapshot view (a white opaque view that covers the screen) if the snapshotView
 property has not previously been configured.
 @return The UIView representing the default snapshot view.
 */
- (UIView *)createDefaultSnapshotView;

/**
 Persists the last user activity, for passcode purposes, when the app is backgrounding or terminating.
 */
- (void)savePasscodeActivityInfo;

/**
 Sets up the default error handling chain.
 @return The SFAuthErrorHandlerList instance containing the chain of error handler filters.
 */
- (SFAuthErrorHandlerList *)populateDefaultAuthErrorHandlerList;

/**
 Processes an auth error by sending it through the chain of error handlers.
 @param error The auth error object.
 @param info The SFOAuthInfo data associated with authentication.
 */
- (void)processAuthError:(NSError *)error authInfo:(SFOAuthInfo *)info;

/**
 Adds the sid cookie to the cookie store for the current authenticated instance.
 */
+ (void)addSidCookieForInstance;

@end

@implementation SFAuthenticationManager

@synthesize authViewController = _authViewController;
@synthesize statusAlert = _statusAlert;
@synthesize authInfo = _authInfo;
@synthesize authError = _authError;
@synthesize authBlockList = _authBlockList;
@synthesize useSnapshotView = _useSnapshotView;
@synthesize snapshotView = _snapshotView;
@synthesize snapshotViewController = _snapshotViewController;
@synthesize authViewHandler = _authViewHandler;
@synthesize authErrorHandlerList = _authErrorHandlerList;
@synthesize invalidCredentialsAuthErrorHandler = _invalidCredentialsAuthErrorHandler;
@synthesize connectedAppVersionAuthErrorHandler = _connectedAppVersionAuthErrorHandler;
@synthesize networkFailureAuthErrorHandler = _networkFailureAuthErrorHandler;
@synthesize genericAuthErrorHandler = _genericAuthErrorHandler;

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
    return [self sharedManager];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

#pragma mark - Init / dealloc / etc.

- (id)init
{
    self = [super init];
    if (self) {
        self.authBlockList = [NSMutableArray array];
        _delegates = [[NSMutableArray alloc] init];
        self.preferredPasscodeProvider = kSFPasscodeProviderPBKDF2;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidFinishLaunching:) name:UIApplicationDidFinishLaunchingNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
        self.useSnapshotView = YES;
        
        // Default auth web view handler
        __weak SFAuthenticationManager *weakSelf = self;
        self.authViewHandler = [[SFAuthenticationViewHandler alloc]
                                initWithDisplayBlock:^(SFAuthenticationManager *authManager, UIWebView *authWebView) {
                                    if (weakSelf.authViewController == nil)
                                        weakSelf.authViewController = [[SFAuthorizingViewController alloc] initWithNibName:nil bundle:nil];
                                    [weakSelf.authViewController setOauthView:authWebView];
                                    [[SFRootViewManager sharedManager] pushViewController:weakSelf.authViewController];
                                } dismissBlock:^(SFAuthenticationManager *authViewManager) {
                                    [weakSelf dismissAuthViewControllerIfPresent];
                                }];
        
        // Set up default auth error handlers.
        self.authErrorHandlerList = [self populateDefaultAuthErrorHandlerList];
        
        // Make sure the login host settings and dependent data are synced at pre-auth app startup.
        // Note: No event generation necessary here.  This will happen before the first authentication
        // in the app's lifetime, and is merely meant to rationalize the App Settings data with the in-memory
        // app state as an initialization step.
        BOOL logoutAppSettingEnabled = [SFAccountManager logoutSettingEnabled];
        SFLoginHostUpdateResult *result = [SFAccountManager updateLoginHost];
        if (logoutAppSettingEnabled) {
            [[SFAccountManager sharedInstance] clearAccountState:YES];
        } else if (result.loginHostChanged) {
            [[SFAccountManager sharedInstance] clearAccountState:NO];
        }
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidFinishLaunchingNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    [self cleanupStatusAlert];
    SFRelease(_statusAlert);
    SFRelease(_authViewController);
    SFRelease(_authInfo);
    SFRelease(_authError);
    SFRelease(_authBlockList);
    SFRelease(_snapshotView);
    SFRelease(_snapshotViewController);
}

#pragma mark - Public methods

- (BOOL)loginWithCompletion:(SFOAuthFlowSuccessCallbackBlock)completionBlock
                    failure:(SFOAuthFlowFailureCallbackBlock)failureBlock
{
    SFAuthBlockPair *blockPair = [[SFAuthBlockPair alloc] initWithSuccessBlock:completionBlock
                                                                  failureBlock:failureBlock];
    @synchronized (self.authBlockList) {
        if (!self.authenticating) {
            // Kick off (async) authentication.
            [self log:SFLogLevelDebug msg:@"No authentication in progress.  Initiating new authentication request."];
            [self.authBlockList addObject:blockPair];
            [self login];
            
            return YES;
        } else {
            // Already authenticating.  Add completion blocks to the list, if they're not there already.
            if (![self.authBlockList containsObject:blockPair]) {
                [self log:SFLogLevelDebug msg:@"Authentication already in progress.  Will run the appropriate block at the end of the in-progress auth."];
                [self.authBlockList addObject:blockPair];
            } else {
                [self log:SFLogLevelDebug msg:@"Authentication already in progress and these completion blocks are already in the queue.  The original blocks will be executed once; these will not be added."];
            }
            return NO;
        }
    }
}

- (void)loggedIn
{
    // If this is the initial login, or there's no persisted identity data, get the data
    // from the service.
    if (self.authInfo.authType == SFOAuthTypeUserAgent || [SFAccountManager sharedInstance].idData == nil) {
        [SFAccountManager sharedInstance].idDelegate = self;
        [[SFAccountManager sharedInstance].idCoordinator initiateIdentityDataRetrieval];
    } else {
        // Identity data should exist.  Validate passcode.
        [self postAuthenticationToPasscodeProcessing];
    }
    NSNotification *loggedInNotification = [NSNotification notificationWithName:kSFUserLoggedInNotification object:self];
    [[NSNotificationCenter defaultCenter] postNotification:loggedInNotification];
}

- (void)logout
{
    [self log:SFLogLevelInfo msg:@"Logout requested.  Logging out the current user."];

    if ([SFPushNotificationManager sharedInstance].deviceSalesforceId) {
        [[SFPushNotificationManager sharedInstance] unregisterSalesforceNotifications];
    }
    [self cancelAuthentication];
    [self revokeRefreshToken];
    [[SFAccountManager sharedInstance] clearAccountState:YES];
    NSNotification *logoutNotification = [NSNotification notificationWithName:kSFUserLogoutNotification object:self];
    [[NSNotificationCenter defaultCenter] postNotification:logoutNotification];
}

- (void)cancelAuthentication
{
    @synchronized (self.authBlockList) {
        [self log:SFLogLevelInfo format:@"Cancel authentication called.  App %@ currently authenticating.", (self.authenticating ? @"is" : @"is not")];
        [[SFAccountManager sharedInstance].coordinator stopAuthentication];
        [self.authBlockList removeAllObjects];
        self.authInfo = nil;
        self.authError = nil;
    }
}

- (void)processLoginHostChange:(SFLoginHostUpdateResult *)result
{
    [self cancelAuthentication];
    [[SFAccountManager sharedInstance] clearAccountState:NO];
    NSDictionary *userInfoDict = [NSDictionary dictionaryWithObjectsAndKeys:result.originalLoginHost, kSFLoginHostChangedNotificationOriginalHostKey, result.updatedLoginHost, kSFLoginHostChangedNotificationUpdatedHostKey, nil];
    NSNotification *loginHostUpdateNotification = [NSNotification notificationWithName:kSFLoginHostChangedNotification object:self userInfo:userInfoDict];
    [[NSNotificationCenter defaultCenter] postNotification:loginHostUpdateNotification];
}

- (BOOL)authenticating
{
    return ([self.authBlockList count] > 0);
}

- (NSString *)preferredPasscodeProvider
{
    return [SFPasscodeManager sharedManager].preferredPasscodeProvider;
}

- (void)setPreferredPasscodeProvider:(NSString *)preferredPasscodeProvider
{
    [SFPasscodeManager sharedManager].preferredPasscodeProvider = preferredPasscodeProvider;
}

- (void)appDidFinishLaunching:(NSNotification *)notification
{
    _isAppLaunch = YES;
}

- (void)appWillEnterForeground:(NSNotification *)notification
{
    _isAppLaunch = NO;
    
    [self removeSnapshotView];
    
    BOOL shouldLogout = [SFAccountManager logoutSettingEnabled];
    SFLoginHostUpdateResult *result = [SFAccountManager updateLoginHost];
    if (shouldLogout) {
        [self log:SFLogLevelInfo msg:@"Logout setting triggered.  Logging out of the application."];
        [self logout];
    } else if (result.loginHostChanged) {
        [self log:SFLogLevelInfo format:@"Login host changed ('%@' to '%@').  Switching to new login host.", result.originalLoginHost, result.updatedLoginHost];
        [self processLoginHostChange:result];
        
    } else {
        // Check to display pin code screen.
        [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
            [self logout];
        }];
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:NULL];
        [SFSecurityLockout validateTimer];
    }
}

- (void)appDidEnterBackground:(NSNotification *)notification
{
    [self log:SFLogLevelDebug msg:@"App is entering the background."];
    
    [self savePasscodeActivityInfo];
    
    // Set up snapshot security view, if it's configured.
    [self setupSnapshotView];
}

- (void)appWillTerminate:(NSNotification *)notification
{
    [self savePasscodeActivityInfo];
}

+ (void)resetSessionCookie
{
    [self removeCookies:[NSArray arrayWithObjects:@"sid", nil]
            fromDomains:[NSArray arrayWithObjects:@".salesforce.com", @".force.com", @".cloudforce.com", nil]];
    [self addSidCookieForInstance];
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

+ (void)removeAllCookies
{
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *fullCookieList = [NSArray arrayWithArray:[cookieStorage cookies]];
    for (NSHTTPCookie *cookie in fullCookieList) {
        [cookieStorage deleteCookie:cookie];
    }
}

+ (void)addSidCookieForInstance
{
    [self addSidCookieForDomain:[[SFAccountManager sharedInstance].credentials.instanceUrl host]];
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

+ (BOOL)errorIsInvalidAuthCredentials:(NSError *)error
{
    BOOL errorIsInvalidCreds = NO;
    if (error.domain == kSFOAuthErrorDomain) {
        if (error.code == kSFOAuthErrorInvalidGrant) {
            errorIsInvalidCreds = YES;
        }
    }
    return errorIsInvalidCreds;
}

#pragma mark - Private methods

- (void)setupSnapshotView
{
    if (self.useSnapshotView) {
        if (self.snapshotView == nil) {
            self.snapshotView = [self createDefaultSnapshotView];
        }
        
        if (self.snapshotViewController == nil) {
            self.snapshotViewController = [[UIViewController alloc] initWithNibName:nil bundle:nil];
            [self.snapshotViewController.view addSubview:self.snapshotView];
        }
        [[SFRootViewManager sharedManager] pushViewController:self.snapshotViewController];
    }
}

- (void)removeSnapshotView
{
    if (self.useSnapshotView) {
        [[SFRootViewManager sharedManager] popViewController:self.snapshotViewController];
    }
}

- (UIView *)createDefaultSnapshotView
{
    UIView *opaqueView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    opaqueView.backgroundColor = [UIColor whiteColor];
    opaqueView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    return opaqueView;
}

- (void)savePasscodeActivityInfo
{
    [SFSecurityLockout removeTimer];
    if ([SFAccountManager sharedInstance].credentials != nil) {
		[SFInactivityTimerCenter saveActivityTimestamp];
	}
}

- (void)postAuthenticationToPasscodeProcessing
{
    if ([[SFAccountManager sharedInstance] mobilePinPolicyConfigured]) {
        // Auth checks are subject to an inactivity check.
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:^{
            [self finalizeAuthCompletion];
        }];
        [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
            [self logout];
        }];
        
        // If the is app startup, we always lock "the first time".  Otherwise, pin code screen
        // display depends on inactivity.
        if (_isAppLaunch) {
            [SFSecurityLockout lock];
        } else {
            [SFSecurityLockout validateTimer];
        }
    } else {
        [self finalizeAuthCompletion];
    }
}

- (void)finalizeAuthCompletion
{
    if ([[SFAccountManager sharedInstance] mobilePinPolicyConfigured]) {
        [[SFUserActivityMonitor sharedInstance] startMonitoring];
    }
    [self execCompletionBlocks];
}

- (void)execCompletionBlocks
{
    NSMutableArray *authBlockListCopy = [NSMutableArray array];
    SFOAuthInfo *localInfo;
    @synchronized (self.authBlockList) {
        for (SFAuthBlockPair *pair in self.authBlockList) {
            [authBlockListCopy addObject:pair];
        }
        localInfo = self.authInfo;
        
        [self.authBlockList removeAllObjects];
        self.authInfo = nil;
        self.authError = nil;
    }
    
    for (SFAuthBlockPair *pair in authBlockListCopy) {
        if (pair.successBlock) {
            SFOAuthFlowSuccessCallbackBlock copiedBlock = [pair.successBlock copy];
            copiedBlock(localInfo);
        }
    }
}

- (void)execFailureBlocks
{
    NSMutableArray *authBlockListCopy = [NSMutableArray array];
    SFOAuthInfo *localInfo;
    NSError *localError;
    @synchronized (self.authBlockList) {
        for (SFAuthBlockPair *pair in self.authBlockList) {
            [authBlockListCopy addObject:pair];
        }
        localInfo = self.authInfo;
        localError = self.authError;
        
        [self.authBlockList removeAllObjects];
        self.authInfo = nil;
        self.authError = nil;
    }
    
    for (SFAuthBlockPair *pair in authBlockListCopy) {
        if (pair.failureBlock) {
            SFOAuthFlowFailureCallbackBlock copiedBlock = [pair.failureBlock copy];
            copiedBlock(localInfo, localError);
        }
    }
}

- (void)revokeRefreshToken
{
    SFOAuthCredentials *creds = [[SFAccountManager sharedInstance] credentials];
    NSString *refreshToken = [creds refreshToken];
    if (refreshToken != nil) {
        [self log:SFLogLevelInfo msg:@"Revoking user's credentials."];
        NSMutableString *host = [NSMutableString stringWithString:[[creds instanceUrl] absoluteString]];
        [host appendString:@"/services/oauth2/revoke?token="];
        [host appendString:refreshToken];
        NSURL *url = [NSURL URLWithString:host];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
        [request setHTTPMethod:@"GET"];
        [request setHTTPShouldHandleCookies:NO];
        NSURLConnection *urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:nil];
        [urlConnection start];
    }
}

- (void)login
{
    [SFAccountManager sharedInstance].oauthDelegate = self;
    [[SFAccountManager sharedInstance].coordinator authenticate];
}

- (void)cleanupStatusAlert
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
    
    if (self.authViewController == nil)
        self.authViewController = [[SFAuthorizingViewController alloc] initWithNibName:nil bundle:nil];
    [self.authViewController setOauthView:webView];
    [[SFRootViewManager sharedManager] pushViewController:self.authViewController];
}

- (void)dismissAuthViewControllerIfPresent
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissAuthViewControllerIfPresent];
        });
        return;
    }
    
    [[SFRootViewManager sharedManager] popViewController:self.authViewController];
}

- (void)retrievedIdentityData
{
    // NB: This method is assumed to run after identity data has been refreshed from the service.
    NSAssert([SFAccountManager sharedInstance].idData != nil, @"Identity data should not be nil/empty at this point.");
    
    if ([[SFAccountManager sharedInstance] mobilePinPolicyConfigured]) {
        // Set the callback actions for post-passcode entry/configuration.
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:^{
            [self finalizeAuthCompletion];
        }];
        [SFSecurityLockout setLockScreenFailureCallbackBlock:^{  // Don't know how this would happen, but if it does....
            [self execFailureBlocks];
        }];
        
        // setLockoutTime triggers passcode creation.  We could consider a more explicit call for visibility here?
        [SFSecurityLockout setPasscodeLength:[SFAccountManager sharedInstance].idData.mobileAppPinLength];
        [SFSecurityLockout setLockoutTime:([SFAccountManager sharedInstance].idData.mobileAppScreenLockTimeout * 60)];
    } else {
        // No additional mobile policies.  So no passcode.
        [self finalizeAuthCompletion];
    }
}

- (void)showRetryAlertForAuthError:(NSError *)error alertTag:(NSInteger)tag
{
    if (nil == _statusAlert) {
        // show alert and allow retry
        _statusAlert = [[UIAlertView alloc] initWithTitle:[SFSDKResourceUtils localizedString:kAlertErrorTitleKey]
                                                  message:[NSString stringWithFormat:[SFSDKResourceUtils localizedString:kAlertConnectionErrorFormatStringKey], error]
                                                 delegate:self
                                        cancelButtonTitle:[SFSDKResourceUtils localizedString:kAlertRetryButtonKey]
                                        otherButtonTitles: nil];
        _statusAlert.tag = tag;
        [_statusAlert show];
    }
}

- (void)showAlertForConnectedAppVersionMismatchError
{
    if (nil == _statusAlert) {
        // Show alert and execute failure block.
        _statusAlert = [[UIAlertView alloc] initWithTitle:[SFSDKResourceUtils localizedString:kAlertErrorTitleKey]
                                                  message:[SFSDKResourceUtils localizedString:kAlertVersionMismatchErrorKey]
                                                 delegate:self
                                        cancelButtonTitle:[SFSDKResourceUtils localizedString:kAlertOkButtonKey]
                                        otherButtonTitles: nil];
        _statusAlert.tag = kConnectedAppVersionMismatchViewTag;
        [_statusAlert show];
    }
}

#pragma mark - Auth error handler methods

- (SFAuthErrorHandlerList *)populateDefaultAuthErrorHandlerList
{
    __weak SFAuthenticationManager *weakSelf = self;
    SFAuthErrorHandlerList *authHandlerList = [[SFAuthErrorHandlerList alloc] init];
    
    // Invalid credentials handler
    
    _invalidCredentialsAuthErrorHandler = [[SFAuthErrorHandler alloc]
                                           initWithName:kSFInvalidCredentialsAuthErrorHandler
                                           evalBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo) {
                                               if ([[weakSelf class] errorIsInvalidAuthCredentials:error]) {
                                                   [weakSelf log:SFLogLevelWarning format:@"OAuth refresh failed due to invalid grant.  Error code: %d", error.code];
                                                   [weakSelf execFailureBlocks];
                                                   return YES;
                                               }
                                               return NO;
                                           }];
    [authHandlerList addAuthErrorHandler:_invalidCredentialsAuthErrorHandler];
    
    // Connected app version mismatch handler
    
    _connectedAppVersionAuthErrorHandler = [[SFAuthErrorHandler alloc]
                                            initWithName:kSFConnectedAppVersionAuthErrorHandler
                                            evalBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo) {
                                                if (error.code == kSFOAuthErrorWrongVersion) {
                                                    [weakSelf log:SFLogLevelWarning format:@"OAuth refresh failed due to Connected App version mismatch.  Error code: %d", error.code];
                                                    [weakSelf showAlertForConnectedAppVersionMismatchError];
                                                    return YES;
                                                }
                                                return NO;
                                            }];
    [authHandlerList addAuthErrorHandler:_connectedAppVersionAuthErrorHandler];
    
    // Network failure handler
    
    _networkFailureAuthErrorHandler = [[SFAuthErrorHandler alloc]
                                       initWithName:kSFNetworkFailureAuthErrorHandler
                                       evalBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo) {
                                           if ([SFAccountManager errorIsNetworkFailure:error]) {
                                               [weakSelf log:SFLogLevelWarning format:@"Auth token refresh couldn't connect to server: %@", [error localizedDescription]];
                                               [weakSelf loggedIn];
                                               return YES;
                                           }
                                           return NO;
                                       }];
    [authHandlerList addAuthErrorHandler:_networkFailureAuthErrorHandler];
    
    // Generic failure handler
    
    _genericAuthErrorHandler = [[SFAuthErrorHandler alloc]
                                initWithName:kSFGenericFailureAuthErrorHandler
                                evalBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo) {
                                    [[SFAccountManager sharedInstance] clearAccountState:NO];
                                    [weakSelf showRetryAlertForAuthError:error alertTag:kOAuthGenericAlertViewTag];
                                    return YES;
                                }];
    [authHandlerList addAuthErrorHandler:_genericAuthErrorHandler];
    
    return authHandlerList;
}

- (void)processAuthError:(NSError *)error authInfo:(SFOAuthInfo *)info
{
    NSInteger i = 0;
    BOOL errorHandled = NO;
    NSArray *authHandlerArray = self.authErrorHandlerList.authHandlerArray;
    while (i < [authHandlerArray count] && !errorHandled) {
        SFAuthErrorHandler *currentHandler = [self.authErrorHandlerList.authHandlerArray objectAtIndex:i];
        errorHandled = currentHandler.evalBlock(error, info);
        i++;
    }
    
    if (!errorHandled) {
        // No error handlers could handle the error.  Pass through to the error blocks.
        if (info.authType == SFOAuthTypeUserAgent)
            self.authViewHandler.authViewDismissBlock(self);
        [self execFailureBlocks];
    }
}

#pragma mark - Delegate management methods

- (void)addDelegate:(id<SFAuthenticationManagerDelegate>)delegate
{
    @synchronized(self) {
        [_delegates addObject:[NSValue valueWithNonretainedObject:delegate]];
    }
}

- (void)removeDelegate:(id<SFAuthenticationManagerDelegate>)delegate
{
    @synchronized(self) {
        [_delegates removeObject:[NSValue valueWithNonretainedObject:delegate]];
    }
}

- (void)enumerateDelegates:(void (^)(id<SFAuthenticationManagerDelegate>))block
{
    @synchronized(self) {
        [_delegates enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            id<SFAuthenticationManagerDelegate> delegate = [obj nonretainedObjectValue];
            if (delegate) {
                if (block) block(delegate);
            }
        }];
    }
}

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view
{
    [self log:SFLogLevelDebug msg:@"oauthCoordinator:willBeginAuthenticationWithView:"];
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerWillBeginAuthWithView:)]) {
            [delegate authManagerWillBeginAuthWithView:self];
        }
    }];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didStartLoad:(UIWebView *)view
{
    [self log:SFLogLevelDebug msg:@"oauthCoordinator:didStartLoad:"];
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerDidStartAuthWebViewLoad:)]) {
            [delegate authManagerDidStartAuthWebViewLoad:self];
        }
    }];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFinishLoad:(UIWebView *)view error:(NSError *)errorOrNil
{
    [self log:SFLogLevelDebug msg:@"oauthCoordinator:didFinishLoad:error:"];
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerDidFinishAuthWebViewLoad:)]) {
            [delegate authManagerDidFinishAuthWebViewLoad:self];
        }
    }];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view
{
    [self log:SFLogLevelDebug msg:@"oauthCoordinator:didBeginAuthenticationWithView"];
    
    // Ensure this runs on the main thread.  Has to be sync, because the coordinator expects the auth view
    // to be added to a superview by the end of this method.
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.authViewHandler.authViewDisplayBlock(self, view);
        });
    } else {
        self.authViewHandler.authViewDisplayBlock(self, view);
    }
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info
{
    [self log:SFLogLevelDebug format:@"oauthCoordinatorDidAuthenticate for userId: %@, auth info: %@", coordinator.credentials.userId, info];
    self.authInfo = info;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.authViewHandler.authViewDismissBlock(self);
    });
    
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerDidAuthenticate:credentials:authInfo:)]) {
            [delegate authManagerDidAuthenticate:self credentials:coordinator.credentials authInfo:info];
        }
    }];
    
    [self loggedIn];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info
{
    [self log:SFLogLevelDebug format:@"oauthCoordinator:didFailWithError: %@, authInfo: %@", error, info];
    self.authInfo = info;
    self.authError = error;
    
    [self processAuthError:error authInfo:info];
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
        if (alertView.tag == kOAuthGenericAlertViewTag) {
            [self dismissAuthViewControllerIfPresent];
            [self login];
        } else if (alertView.tag == kIdentityAlertViewTag) {
            [[SFAccountManager sharedInstance].idCoordinator initiateIdentityDataRetrieval];
        } else if (alertView.tag == kConnectedAppVersionMismatchViewTag) {
            // The OAuth failure block should be followed, after acknowledging the version mismatch.
            [self execFailureBlocks];
        }
        
        SFRelease(_statusAlert);
    }
}

@end
