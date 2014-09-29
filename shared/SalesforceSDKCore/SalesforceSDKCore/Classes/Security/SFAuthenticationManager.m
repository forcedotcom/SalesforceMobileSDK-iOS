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
#import "SFAuthenticationManager+Internal.h"
#import "SFUserAccount.h"
#import "SFUserAccountManager.h"
#import "SFUserAccountManagerUpgrade.h"
#import "SFAuthenticationViewHandler.h"
#import "SFAuthErrorHandler.h"
#import "SFAuthErrorHandlerList.h"
#import "SFAuthorizingViewController.h"
#import "SFSecurityLockout.h"
#import "SFIdentityData.h"
#import "SFSDKResourceUtils.h"
#import "SFRootViewManager.h"
#import "SFUserActivityMonitor.h"
#import <SalesforceSecurity/SFPasscodeManager.h>
#import <SalesforceSecurity/SFPasscodeProviderManager.h>
#import "SFPushNotificationManager.h"
#import "SFSmartStore.h"

#import <SalesforceOAuth/SFOAuthCredentials.h>
#import <SalesforceOAuth/SFOAuthInfo.h>
#import <SalesforceCommonUtils/NSURL+SFAdditions.h>
#import <SalesforceCommonUtils/SFInactivityTimerCenter.h>
#import <SalesforceCommonUtils/SFTestContext.h>

static SFAuthenticationManager *sharedInstance = nil;

// Public notification name constants

NSString * const kSFUserWillLogoutNotification = @"kSFUserWillLogoutNotification";
NSString * const kSFUserLogoutNotification = @"kSFUserLogoutOccurred";
NSString * const kSFUserLoggedInNotification = @"kSFUserLoggedIn";
NSString * const kSFAuthenticationManagerFinishedNotification = @"kSFAuthenticationManagerFinishedNotification";

// Auth error handler name constants

static NSString * const kSFInvalidCredentialsAuthErrorHandler = @"InvalidCredentialsErrorHandler";
static NSString * const kSFConnectedAppVersionAuthErrorHandler = @"ConnectedAppVersionErrorHandler";
static NSString * const kSFNetworkFailureAuthErrorHandler = @"NetworkFailureErrorHandler";
static NSString * const kSFGenericFailureAuthErrorHandler = @"GenericFailureErrorHandler";

// Private constants

static NSInteger  const kOAuthGenericAlertViewTag    = 444;
static NSInteger  const kIdentityAlertViewTag = 555;
static NSInteger  const kConnectedAppVersionMismatchViewTag = 666;

// Key for whether or not the user has chosen the app setting to logout of the
// app when it is re-opened.
static NSString * const kAppSettingsAccountLogout = @"account_logout_pref";

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
    NSMutableOrderedSet *_delegates;
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
 Clears the account state associated with the current account.
 @param clearAccountData Whether to also remove all of the account data (e.g. YES for logout)
 */
- (void)clearAccountState:(BOOL)clearAccountData;

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
 @param fromOffline Whether or not the method was called from an offline state.
 */
- (void)loggedIn:(BOOL)fromOffline;

/**
 Called after identity data is retrieved from the service.
 */
- (void)retrievedIdentityData;

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
- (void)revokeRefreshToken:(SFUserAccount *)user;

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

static Class InstanceClass = nil;

+ (void)setInstanceClass:(Class)class {
    InstanceClass = class;
}

+ (instancetype)sharedManager
{
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
        if (InstanceClass) {
            sharedInstance = [[InstanceClass alloc] init];
        } else {
            sharedInstance = [[self alloc] init];
        }
    });
    return sharedInstance;
}

#pragma mark - Init / dealloc / etc.

- (id)init
{
    self = [super init];
    if (self) {
        self.authBlockList = [NSMutableArray array];
        _delegates = [[NSMutableOrderedSet alloc] init];
        self.preferredPasscodeProvider = kSFPasscodeProviderPBKDF2;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidFinishLaunching:) name:UIApplicationDidFinishLaunchingNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
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
        
        [[SFUserAccountManager sharedInstance] addDelegate:self];
        
        // Set up default auth error handlers.
        self.authErrorHandlerList = [self populateDefaultAuthErrorHandlerList];
        
        // Set up the current user, if available
        SFUserAccount *user = [SFUserAccountManager sharedInstance].currentUser;
        if (user) {
            [self setupWithUser:user];
        }
        
        // Make sure the login host settings and dependent data are synced at pre-auth app startup.
        // Note: No event generation necessary here.  This will happen before the first authentication
        // in the app's lifetime, and is merely meant to rationalize the App Settings data with the in-memory
        // app state as an initialization step.
        BOOL logoutAppSettingEnabled = [self logoutSettingEnabled];
        SFLoginHostUpdateResult *result = [[SFUserAccountManager sharedInstance] updateLoginHost];
        if (logoutAppSettingEnabled) {
            [self clearAccountState:YES];
        } else if (result.loginHostChanged) {
            // Authentication hasn't started yet.  Just reset the current user.
            [SFUserAccountManager sharedInstance].currentUser = nil;
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
    return [self loginWithCompletion:completionBlock failure:failureBlock account:nil];
}

- (BOOL)loginWithCompletion:(SFOAuthFlowSuccessCallbackBlock)completionBlock
                    failure:(SFOAuthFlowFailureCallbackBlock)failureBlock
                    account:(SFUserAccount *)account
{
    if (account == nil) {
        account = [SFUserAccountManager sharedInstance].currentUser;
        if (account == nil) {
            // Create the current user out of legacy account data, if it exists.
            account = [SFUserAccountManagerUpgrade createUserFromLegacyAccountData];
            if (account == nil) {
                [self log:SFLogLevelInfo format:@"No current user account, so creating a new one."];
                account = [[SFUserAccountManager sharedInstance] createUserAccount];
            }
            [[SFUserAccountManager sharedInstance] saveAccounts:nil];
        }
    }
    
    SFAuthBlockPair *blockPair = [[SFAuthBlockPair alloc] initWithSuccessBlock:completionBlock
                                                                  failureBlock:failureBlock];
    @synchronized (self.authBlockList) {
        if (!self.authenticating) {
            // Kick off (async) authentication.
            [self log:SFLogLevelDebug msg:@"No authentication in progress.  Initiating new authentication request."];
            [self.authBlockList addObject:blockPair];
            [self loginWithUser:account];
            
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

- (void)loggedIn:(BOOL)fromOffline
{
    if (!fromOffline) {
    [self.idCoordinator initiateIdentityDataRetrieval];
    } else {
        [self retrievedIdentityData];
    }
    
    NSNotification *loggedInNotification = [NSNotification notificationWithName:kSFUserLoggedInNotification object:self];
    [[NSNotificationCenter defaultCenter] postNotification:loggedInNotification];
}

- (void)logoutAllUsers
{
    // Log out all other users, then the current user.
    NSArray *userAccounts = [[SFUserAccountManager sharedInstance] allUserAccounts];
    for (SFUserAccount *account in userAccounts) {
        if (account != [SFUserAccountManager sharedInstance].currentUser) {
            [self logoutUser:account];
        }
    }
    [self logoutUser:[SFUserAccountManager sharedInstance].currentUser];
}

- (void)logout
{
    [self logoutUser:[SFUserAccountManager sharedInstance].currentUser];
}

- (void)logoutUser:(SFUserAccount *)user
{
    // No-op, if the user is not valid.
    if (user == nil) {
        [self log:SFLogLevelInfo msg:@"logoutUser: user is nil.  No action taken."];
        return;
    } else if (user == [SFUserAccountManager sharedInstance].temporaryUser) {
        [self log:SFLogLevelInfo msg:@"logoutUser: user is the temporary account.  No action taken."];
        return;
    }
    
    [self log:SFLogLevelInfo format:@"Logging out user '%@'.", user.userName];
    
    SFUserAccountManager *userAccountManager = [SFUserAccountManager sharedInstance];
    
    [self revokeRefreshToken:user];
    
    // If it's not the current user, this is really just about clearing the account data and
    // user-specific state for the given account.
    if (![user isEqual:userAccountManager.currentUser]) {
        // NB: SmartStores need to be cleared before user account info is removed.
        [SFSmartStore removeAllStoresForUser:user];
        [userAccountManager deleteAccountForUserId:user.credentials.userId error:nil];
        [user.credentials revoke];
        [[SFPushNotificationManager sharedInstance] unregisterSalesforceNotifications:user];
        return;
    }
    
    // Otherwise, the current user is being logged out.  Supply the user account to the
    // "Will Logout" notification before the credentials are revoked.  This will ensure
    // that databases and other resources keyed off of the userID can be destroyed/cleaned up.
    SFUserAccount *userAccount = user;

    // Also keep the userId around until the end of the process so we can safely refer to it
    NSString *userId = userAccount.credentials.userId;

	NSDictionary *userInfo = nil;
    if (userAccount) {
        userInfo = @{ @"account": userAccount };
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFUserWillLogoutNotification
														object:self
													  userInfo:userInfo];
    
    if ([SFPushNotificationManager sharedInstance].deviceSalesforceId) {
        [[SFPushNotificationManager sharedInstance] unregisterSalesforceNotifications];
    }
    
    [self cancelAuthentication];
    [self clearAccountState:YES];
    
    [self willChangeValueForKey:@"haveValidSession"];
    [userAccountManager deleteAccountForUserId:userId error:nil];
    [userAccountManager saveAccounts:nil];
    [userAccount.credentials revoke];
    userAccountManager.currentUser = nil;
    [self didChangeValueForKey:@"haveValidSession"];
    
    NSNotification *logoutNotification = [NSNotification notificationWithName:kSFUserLogoutNotification object:self];
    [[NSNotificationCenter defaultCenter] postNotification:logoutNotification];
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerDidLogout:)]) {
            [delegate authManagerDidLogout:self];
        }
    }];
}

- (void)cancelAuthentication
{
    @synchronized (self.authBlockList) {
        [self log:SFLogLevelInfo format:@"Cancel authentication called.  App %@ currently authenticating.", (self.authenticating ? @"is" : @"is not")];
        [self.coordinator stopAuthentication];
        [self.authBlockList removeAllObjects];
        self.authInfo = nil;
        self.authError = nil;
    }
}

- (BOOL)authenticating
{
    return ([self.authBlockList count] > 0);
}

- (BOOL)haveValidSession {
    // Check that we have a valid current user
    NSString *userId = [[SFUserAccountManager sharedInstance] currentUserId];
    if (nil == userId || [userId isEqualToString:SFUserAccountManagerTemporaryUserAccountId]) {
        return NO;
    }
    
    // Check that the current user itself has a valid session
    SFUserAccount *userAcct = [[SFUserAccountManager sharedInstance] currentUser];
    if ([userAcct isSessionValid]) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)logoutSettingEnabled {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults synchronize];
	BOOL logoutSettingEnabled =  [userDefaults boolForKey:kAppSettingsAccountLogout];
    [self log:SFLogLevelDebug format:@"userLogoutSettingEnabled: %d", logoutSettingEnabled];
    return logoutSettingEnabled;
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
    [SFSecurityLockout setValidatePasscodeAtStartup:YES];
}

- (void)appWillEnterForeground:(NSNotification *)notification
{
    [self log:SFLogLevelDebug msg:@"App is entering the foreground."];
    
    [self removeSnapshotView];
    
    BOOL shouldLogout = [self logoutSettingEnabled];
    SFLoginHostUpdateResult *result = [[SFUserAccountManager sharedInstance] updateLoginHost];
    if (shouldLogout) {
        [self log:SFLogLevelInfo msg:@"Logout setting triggered.  Logging out of the application."];
        [self logout];
    } else if (result.loginHostChanged) {
        [self log:SFLogLevelInfo format:@"Login host changed ('%@' to '%@').  Switching to new login host.", result.originalLoginHost, result.updatedLoginHost];
        [self cancelAuthentication];
        [[SFUserAccountManager sharedInstance] switchToNewUser];
    } else {
        // Check to display pin code screen.
        [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
            [self logout];
        }];
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:NULL];
        [SFSecurityLockout validateTimer];
    }
}

- (void)appWillResignActive:(NSNotification *)notification
{
    [self log:SFLogLevelDebug msg:@"App is resigning active state."];
    
    // Set up snapshot security view, if it's configured.
    [self setupSnapshotView];
}

- (void)appDidBecomeActive:(NSNotification *)notification
{
    [self log:SFLogLevelDebug msg:@"App is resuming active state."];
    
    [self removeSnapshotView];
}

- (void)appDidEnterBackground:(NSNotification *)notification
{
    [self log:SFLogLevelDebug msg:@"App is entering the background."];
    
    [self savePasscodeActivityInfo];
}

- (void)appWillTerminate:(NSNotification *)notification
{
    [self savePasscodeActivityInfo];
}

+ (void)resetSessionCookie
{
    [self removeCookies:@[@"sid"]
            fromDomains:@[@".salesforce.com", @".force.com", @".cloudforce.com"]];
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
    [self addSidCookieForDomain:[[SFUserAccountManager sharedInstance].currentUser.credentials.instanceUrl host]];
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
                                                   [SFAuthenticationManager sharedManager].coordinator.credentials.accessToken, NSHTTPCookieValue,
                                                   @"sid", NSHTTPCookieName,
                                                   @"TRUE", NSHTTPCookieDiscard,
                                                   nil];
    if ([[SFAuthenticationManager sharedManager].coordinator.credentials.protocol isEqualToString:@"https"]) {
        newSidCookieProperties[NSHTTPCookieSecure] = @"TRUE";
    }
    
    NSHTTPCookie *sidCookie0 = [NSHTTPCookie cookieWithProperties:newSidCookieProperties];
    [cookieStorage setCookie:sidCookie0];
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

/**
 * Evaluates an NSError object to see if it represents a network failure during
 * an attempted connection.
 * @param error The NSError to evaluate.
 * @return YES if the error represents a network failure, NO otherwise.
 */
+ (BOOL)errorIsNetworkFailure:(NSError *)error
{
    BOOL isNetworkFailure = NO;
    
    if (error == nil || error.domain == nil)
        return isNetworkFailure;
    
    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        switch (error.code) {
            case NSURLErrorTimedOut:
            case NSURLErrorCannotConnectToHost:
            case NSURLErrorNetworkConnectionLost:
            case NSURLErrorNotConnectedToInternet:
                isNetworkFailure = YES;
                break;
            default:
                break;
        }
    } else if ([error.domain isEqualToString:kSFOAuthErrorDomain]) {
        switch (error.code) {
            case kSFOAuthErrorTimeout:
                isNetworkFailure = YES;
                break;
            default:
                break;
        }
    }
    
    return isNetworkFailure;
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
    opaqueView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    opaqueView.backgroundColor = [UIColor whiteColor];
    return opaqueView;
}

- (void)savePasscodeActivityInfo
{
    [SFSecurityLockout removeTimer];
    if (self.coordinator.credentials != nil) {
		[SFInactivityTimerCenter saveActivityTimestamp];
	}
}

- (void)finalizeAuthCompletion
{
    [SFSecurityLockout setValidatePasscodeAtStartup:NO];
    [SFSecurityLockout startActivityMonitoring];
    
    // Apply the credentials that will ensure there is a current user and that this
    // current user as the proper credentials.
    [[SFUserAccountManager sharedInstance] applyCredentials:self.coordinator.credentials];
    
    // Assign the identity data to the current user
    NSAssert([SFUserAccountManager sharedInstance].currentUser != nil, @"Current user should not be nil at this point.");
    [SFUserAccountManager sharedInstance].currentUser.idData = self.idCoordinator.idData;
    
    // Save the accounts
    [[SFUserAccountManager sharedInstance] saveAccounts:nil];

    // Notify the session is ready
    [self willChangeValueForKey:@"currentUser"];
    [self didChangeValueForKey:@"currentUser"];
    
    [self willChangeValueForKey:@"haveValidSession"];
    [self didChangeValueForKey:@"haveValidSession"];
    
    NSDictionary *userInfo = nil;
    SFUserAccount *user = [SFUserAccountManager sharedInstance].currentUser;
    if (user) {
        userInfo = @{ @"account" : user };
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFAuthenticationManagerFinishedNotification
                                                        object:self
                                                      userInfo:userInfo];

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
    
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerDidFinish:info:)]) {
            [delegate authManagerDidFinish:self info:localInfo];
        }
    }];
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
    
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerDidFail:error:info:)]) {
            [delegate authManagerDidFail:self error:localError info:localInfo];
        }
    }];
}

- (void)revokeRefreshToken:(SFUserAccount *)user
{
    if (user.credentials.refreshToken != nil) {
        [self log:SFLogLevelInfo format:@"Revoking credentials on the server for '%@'.", user.userName];
        NSMutableString *host = [NSMutableString stringWithFormat:@"%@://", user.credentials.protocol];
        [host appendString:user.credentials.domain];
        [host appendString:@"/services/oauth2/revoke?token="];
        [host appendString:user.credentials.refreshToken];
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
    SFUserAccount *account = [SFUserAccountManager sharedInstance].currentUser;
	if (nil == account) {
        [self log:SFLogLevelInfo format:@"no current user account so creating a new one"];
        account = [[SFUserAccountManager sharedInstance] createUserAccount];
        [[SFUserAccountManager sharedInstance] saveAccounts:nil];
	}
    
    [self loginWithUser:account];
}

- (void)loginWithUser:(SFUserAccount*)account {
    NSAssert(account != nil, @"Account should be set at this point.");
    [SFUserAccountManager sharedInstance].currentUser = account;
    
    // Setup the internal logic for the specified user
    [self setupWithUser:account];
    
    // Trigger the login flow
    if (self.coordinator.isAuthenticating) {
        [self.coordinator stopAuthentication];        
    }
    [self.coordinator authenticate];
}

- (void)setupWithUser:(SFUserAccount*)account {
    // sets the domain if it not set already
    if (nil == account.credentials.domain) {
        account.credentials.domain = [[SFUserAccountManager sharedInstance] loginHost];
    }
    
    // if the user doesn't specify any scopes, let's use the ones
    // defined in this account manager
    if (nil == account.accessScopes) {
        account.accessScopes = [SFUserAccountManager sharedInstance].scopes;
    }
    
    // re-create the oauth coordinator for the current user
    self.coordinator.delegate = nil;
    self.coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:account.credentials];
    self.coordinator.scopes = account.accessScopes;
    self.coordinator.delegate = self;
    
    // re-create the identity coordinator for the current user
    self.idCoordinator.delegate = nil;
    self.idCoordinator = [[SFIdentityCoordinator alloc] initWithCredentials:account.credentials];
    self.idCoordinator.idData = account.idData;
    self.idCoordinator.delegate = self;
}

/**
 * Clears the account state of the given account (i.e. clears credentials, coordinator
 * instances, etc.
 * @param clearAccountData Whether to optionally revoke credentials and persisted data associated
 *        with the account.
 */
- (void)clearAccountState:(BOOL)clearAccountData {
    if (clearAccountData) {
        [SFSmartStore removeAllStores];
        [SFSecurityLockout clearPasscodeState];
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setBool:NO forKey:kAppSettingsAccountLogout];
        [defs synchronize];
    }
    
    if (self.coordinator.view) {
        [self.coordinator.view removeFromSuperview];
    }
    
    [SFAuthenticationManager removeAllCookies];
    [self.coordinator stopAuthentication];
    self.coordinator.delegate = nil;
    self.idCoordinator.delegate = nil;
    SFRelease(_idCoordinator);
    SFRelease(_coordinator);
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
    // NB: This method is assumed to run after identity data has been refreshed from the service, or otherwise
    // already exists.
    NSAssert(self.idCoordinator.idData != nil, @"Identity data should not be nil/empty at this point.");
    
    // Post-passcode verification callbacks, where we'll check for passcode creation/update.  Passcode verification section is below.
    [SFSecurityLockout setLockScreenSuccessCallbackBlock:^(SFSecurityLockoutAction action) {
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:^(SFSecurityLockoutAction action) {
            [self finalizeAuthCompletion];
        }];
        [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
            [self execFailureBlocks];
        }];
        
        // Check to see if a passcode needs to be created or updated, based on passcode policy data from the
        // identity service.
        [SFSecurityLockout setPasscodeLength:self.idCoordinator.idData.mobileAppPinLength
                                 lockoutTime:(self.idCoordinator.idData.mobileAppScreenLockTimeout * 60)];
    }];
    [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
        [self execFailureBlocks];
    }];
    
    // If we're in app startup, we always lock "the first time". Otherwise, pin code screen display depends on inactivity.
    if ([SFSecurityLockout validatePasscodeAtStartup]) {
        [SFSecurityLockout lock];
    } else {
        [SFSecurityLockout validateTimer];
    }
}

- (void)showRetryAlertForAuthError:(NSError *)error alertTag:(NSInteger)tag
{
    if (nil == _statusAlert) {
        // show alert and allow retry
        [self log:SFLogLevelError format:@"Error during authentication: %@", error];
        _statusAlert = [[UIAlertView alloc] initWithTitle:[SFSDKResourceUtils localizedString:kAlertErrorTitleKey]
                                                  message:[NSString stringWithFormat:[SFSDKResourceUtils localizedString:kAlertConnectionErrorFormatStringKey], [error localizedDescription]]
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
                                                     if ([[weakSelf class] errorIsNetworkFailure:error]) {
                                                         [weakSelf log:SFLogLevelWarning format:@"Auth token refresh couldn't connect to server: %@", [error localizedDescription]];
                                                         
                                                         if (authInfo.authType == SFOAuthTypeUserAgent) {
                                                             [weakSelf log:SFLogLevelError msg:@"Network failure for OAuth User Agent flow is a fatal error."];
                                                             return NO;  // Default error handler will show the error.
                                                         } else {
                                                             [weakSelf log:SFLogLevelInfo msg:@"Network failure for OAuth Refresh flow (existing credentials)  Try to continue."];
                                                             [weakSelf loggedIn:YES];
                                                             return YES;
                                                         }
                                                     }
                                                     return NO;
                                                 }];
    [authHandlerList addAuthErrorHandler:_networkFailureAuthErrorHandler];
    
    // Generic failure handler
    
    _genericAuthErrorHandler = [[SFAuthErrorHandler alloc]
                                                 initWithName:kSFGenericFailureAuthErrorHandler
                                                 evalBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo) {
                                                     [weakSelf clearAccountState:NO];
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
        SFAuthErrorHandler *currentHandler = (self.authErrorHandlerList.authHandlerArray)[i];
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
        if (delegate) {
            NSValue *nonretainedDelegate = [NSValue valueWithNonretainedObject:delegate];
            [_delegates addObject:nonretainedDelegate];
        }
    }
}

- (void)removeDelegate:(id<SFAuthenticationManagerDelegate>)delegate
{
    @synchronized(self) {
        if (delegate) {
            NSValue *nonretainedDelegate = [NSValue valueWithNonretainedObject:delegate];
            [_delegates removeObject:nonretainedDelegate];
        }
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

#pragma mark - SFUserAccountManagerDelegate

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
        willSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser
{
    [self clearAccountState:NO];
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
    
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManager:willDisplayAuthWebView:)]) {
            [delegate authManager:self willDisplayAuthWebView:view];
        }
    }];
    
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
    
    [self loggedIn:NO];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info
{
    [self log:SFLogLevelDebug format:@"oauthCoordinator:didFailWithError: %@, authInfo: %@", error, info];
    self.authInfo = info;
    self.authError = error;
    
    [self processAuthError:error authInfo:info];
}

- (BOOL)oauthCoordinatorIsNetworkAvailable:(SFOAuthCoordinator *)coordinator {
    __block BOOL result = YES;
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerIsNetworkAvailable:)]) {
            result = [delegate authManagerIsNetworkAvailable:self];
        }
    }];
    
    return result;
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
        _statusAlert = nil;
        [self log:SFLogLevelDebug format:@"clickedButtonAtIndex: %d", buttonIndex];
        if (alertView.tag == kOAuthGenericAlertViewTag) {
            [self dismissAuthViewControllerIfPresent];
            [self login];
        } else if (alertView.tag == kIdentityAlertViewTag) {
            [self.idCoordinator initiateIdentityDataRetrieval];
        } else if (alertView.tag == kConnectedAppVersionMismatchViewTag) {
            // The OAuth failure block should be followed, after acknowledging the version mismatch.
            [self execFailureBlocks];
        }
    }
}

@end
