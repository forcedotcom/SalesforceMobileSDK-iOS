/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
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
#import "SalesforceSDKManager+Internal.h"
#import "SFUserAccount+Internal.h"
#import "SFUserAccountManager+Internal.h"
#import "SFUserAccountIdentity.h"
#import "SFAuthenticationViewHandler.h"
#import "SFAuthErrorHandler.h"
#import "SFAuthErrorHandlerList.h"
#import "SFSecurityLockout.h"
#import "SFIdentityData.h"
#import "SFSDKResourceUtils.h"
#import "SFRootViewManager.h"
#import "SFPasscodeProviderManager.h"
#import "SFPushNotificationManager.h"
#import "SFManagedPreferences.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFOAuthInfo.h"
#import "SFLoginViewController.h"
#import "SFOAuthCoordinator+Internal.h"

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
static NSInteger const kOAuthGenericAlertViewTag           = 444;
static NSInteger const kIdentityAlertViewTag               = 555;
static NSInteger const kConnectedAppVersionMismatchViewTag = 666;
static NSInteger const kAdvancedAuthDialogTag              = 777;

static NSString * const kAlertErrorTitleKey = @"authAlertErrorTitle";
static NSString * const kAlertOkButtonKey = @"authAlertOkButton";
static NSString * const kAlertRetryButtonKey = @"authAlertRetryButton";
static NSString * const kAlertDismissButtonKey = @"authAlertDismissButton";
static NSString * const kAlertConnectionErrorFormatStringKey = @"authAlertConnectionErrorFormatString";
static NSString * const kAlertVersionMismatchErrorKey = @"authAlertVersionMismatchError";
static NSString * const kUserNameCookieKey = @"sfdc_lv2";
static NSString * const kSFUserAccountOAuthRedirectUri = @"SFDCOAuthRedirectUri";
static NSString * const kDeprecatedLoginHostPrefKey = @"login_host_pref";

// Oauth
NSString * const kSFUserAccountOAuthLoginHostDefault = @"login.salesforce.com"; // last resort
NSString * const kSFUserAccountOAuthLoginHost = @"SFDCOAuthLoginHost";

// The key for storing the persisted OAuth scopes.
NSString * const kOAuthScopesKey = @"oauth_scopes";

// The key for storing the persisted OAuth client ID.
NSString * const kOAuthClientIdKey = @"oauth_client_id";

// The key for storing the persisted OAuth redirect URI.
NSString * const kOAuthRedirectUriKey = @"oauth_redirect_uri";

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

@interface SFAuthenticationManager () <SFSDKLoginHostDelegate>
{
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
 The callback block used to notify the OAuth coordinator whether it should proceed with
 the browser authentication flow.
 */
@property (nonatomic, copy) SFOAuthBrowserFlowCallbackBlock authCoordinatorBrowserBlock;

/**
 The list of delegates
 */
@property (nonatomic, strong, nonnull) NSMutableDictionary<NSNumber *, NSHashTable<id<SFAuthenticationManagerDelegate>> *> *delegates;


/** 
 Making certain read-only properties privately read-write
 */
@property (nonatomic, readwrite) SFAuthErrorHandler *invalidCredentialsAuthErrorHandler;
@property (nonatomic, readwrite) SFAuthErrorHandler *genericAuthErrorHandler;
@property (nonatomic, readwrite) SFAuthErrorHandler *networkFailureAuthErrorHandler;
@property (nonatomic, readwrite) SFAuthErrorHandler *connectedAppVersionAuthErrorHandler;


/**
 Dismisses the authentication retry alert box, if present.
 */
- (void)cleanupStatusAlert;

/**
 Method to present the authorizing view controller with the given auth webView.
 @param webView The auth webView to present.
 */
- (void)presentAuthViewController:(WKWebView *)webView;

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

#pragma mark - Singleton initialization / management

static Class InstanceClass = nil;

+ (void)setInstanceClass:(Class)className {
    InstanceClass = className;
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
        self.delegates = [NSMutableDictionary new];
        
        // Default auth web view handler
        __weak typeof(self) weakSelf = self;
        self.authViewHandler = [[SFAuthenticationViewHandler alloc]
                                initWithDisplayBlock:^(SFAuthenticationManager *authManager, WKWebView *authWebView) {
                                    __strong typeof(weakSelf) strongSelf = weakSelf;
                                    if (strongSelf.authViewController == nil)
                                        strongSelf.authViewController = [SFLoginViewController sharedInstance];
                                    [strongSelf.authViewController setOauthView:authWebView];
                                    [[SFRootViewManager sharedManager] pushViewController:strongSelf.authViewController];
                                } dismissBlock:^(SFAuthenticationManager *authViewManager) {
                                    __strong typeof(weakSelf) strongSelf = weakSelf;
                                    [SFLoginViewController sharedInstance].oauthView = nil;
                                    [strongSelf dismissAuthViewControllerIfPresent];
                                }];
        
        [[SFUserAccountManager sharedInstance] addDelegate:self];
        // Set up default auth error handlers.
        self.authErrorHandlerList = [self populateDefaultAuthErrorHandlerList];
        NSString *bundleOAuthCompletionUrl = [[NSBundle mainBundle] objectForInfoDictionaryKey:kSFUserAccountOAuthRedirectUri];
        if (bundleOAuthCompletionUrl != nil) {
            self.oauthCompletionUrl = bundleOAuthCompletionUrl;
        }
    }
    
    return self;
}

- (void)dealloc
{
    [self cleanupStatusAlert];
}

#pragma mark - Public methods

- (BOOL)loginWithCompletion:(SFOAuthFlowSuccessCallbackBlock)completionBlock
                    failure:(SFOAuthFlowFailureCallbackBlock)failureBlock
{
    return [self loginWithCompletion:completionBlock failure:failureBlock credentials:[self createOAuthCredentials]];
}


- (BOOL)loginWithCompletion:(SFOAuthFlowSuccessCallbackBlock)completionBlock
                    failure:(SFOAuthFlowFailureCallbackBlock)failureBlock
                    credentials:(SFOAuthCredentials *)credentials
{

    SFAuthBlockPair *blockPair = [[SFAuthBlockPair alloc] initWithSuccessBlock:completionBlock
                                                                  failureBlock:failureBlock];
    @synchronized (self.authBlockList) {
        if (!self.authenticating) {
            // Kick off (async) authentication.
            [self log:SFLogLevelDebug msg:@"No authentication in progress.  Initiating new authentication request."];
            [self.authBlockList addObject:blockPair];
            [self loginWithCredentials:credentials];
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

- (BOOL)loginWithJwtToken:(NSString *)jwtToken
               completion:(SFOAuthFlowSuccessCallbackBlock)completionBlock
                  failure:(SFOAuthFlowFailureCallbackBlock)failureBlock
{
    
    NSAssert(jwtToken.length > 0, @"JWT token value required.");
    SFOAuthCredentials *credentials = [self createOAuthCredentials];
    credentials.jwt = jwtToken;
    return [self loginWithCompletion:completionBlock
                             failure:failureBlock
                             credentials:credentials];
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
    }

    BOOL loggingOutTransitionSucceeded = [user transitionToLoginState:SFUserAccountLoginStateLoggingOut];
    if (!loggingOutTransitionSucceeded) {
        // SFUserAccount already logs the transition failure.
        return;
    }
    
    [self log:SFLogLevelInfo format:@"Logging out user '%@'.", user.userName];
    NSDictionary *userInfo = @{ @"account": user };
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFUserWillLogoutNotification
                                                        object:self
                                                      userInfo:userInfo];
    __weak typeof(self) weakSelf = self;
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManager:willLogoutUser:)]) {
            [delegate authManager:weakSelf willLogoutUser:user];
        }
    }];

    SFUserAccountManager *userAccountManager = [SFUserAccountManager sharedInstance];
    // If it's not the current user, this is really just about clearing the account data and
    // user-specific state for the given account.
    if (![user isEqual:userAccountManager.currentUser]) {
        [[SFPushNotificationManager sharedInstance] unregisterSalesforceNotifications:user];
        [userAccountManager deleteAccountForUser:user error:nil];
        [self revokeRefreshToken:user];
        // NB: There's no real action that can be taken if this login state transition fails.  At any rate,
        // it's an unlikely scenario.
        [user transitionToLoginState:SFUserAccountLoginStateNotLoggedIn];
    }else {
        // Otherwise, the current user is being logged out.  Supply the user account to the
        // "Will Logout" notification before the credentials are revoked.  This will ensure
        // that databases and other resources keyed off of the userID can be destroyed/cleaned up.
        __weak typeof (self) weakSelf = self;
        [self clearAccountState:YES withCompletion:^{
            __weak typeof (weakSelf) strongSelf = weakSelf;
            
            if ([SFPushNotificationManager sharedInstance].deviceSalesforceId) {
                [[SFPushNotificationManager sharedInstance] unregisterSalesforceNotifications];
            }

            [strongSelf cancelAuthentication];
            [strongSelf willChangeValueForKey:@"haveValidSession"];
            [userAccountManager deleteAccountForUser:user error:nil];
            [strongSelf revokeRefreshToken:user];
            userAccountManager.currentUser = nil;
            [strongSelf didChangeValueForKey:@"haveValidSession"];

            NSNotification *logoutNotification = [NSNotification notificationWithName:kSFUserLogoutNotification object:strongSelf];
            [[NSNotificationCenter defaultCenter] postNotification:logoutNotification];
            [strongSelf enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
                if ([delegate respondsToSelector:@selector(authManagerDidLogout:)]) {
                    [delegate authManagerDidLogout:strongSelf];
                }
            }];
            // NB: There's no real action that can be taken if this login state transition fails.  At any rate,
            // it's an unlikely scenario.
            [user transitionToLoginState:SFUserAccountLoginStateNotLoggedIn];
        }];
    }

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
    return SFUserAccountManager.sharedInstance.currentUser != nil && SFUserAccountManager.sharedInstance.currentUser.isSessionValid;
}

- (void)setAdvancedAuthConfiguration:(SFOAuthAdvancedAuthConfiguration)advancedAuthConfiguration
{
    _advancedAuthConfiguration = advancedAuthConfiguration;
    self.coordinator.advancedAuthConfiguration = advancedAuthConfiguration;
}

- (BOOL)handleAdvancedAuthenticationResponse:(NSURL *)appUrlResponse
{
    return [self.coordinator handleAdvancedAuthenticationResponse:appUrlResponse];
}

#pragma mark - Login Host

- (void)setLoginHost:(NSString*)host {
    NSString *oldLoginHost = [self loginHost];

    if (nil == host) {
        [[NSUserDefaults msdkUserDefaults] removeObjectForKey:kSFUserAccountOAuthLoginHost];
    } else {
        [[NSUserDefaults msdkUserDefaults] setObject:host forKey:kSFUserAccountOAuthLoginHost];
    }

    [[NSUserDefaults msdkUserDefaults] synchronize];

    // Only post the login host change notification if the host actually changed.
    if ((oldLoginHost || host) && ![host isEqualToString:oldLoginHost]) {
        NSDictionary *userInfoDict = @{ kSFLoginHostChangedNotificationOriginalHostKey: (oldLoginHost ?: [NSNull null]),
                kSFLoginHostChangedNotificationUpdatedHostKey: (host ?: [NSNull null]) };
        NSNotification *loginHostUpdateNotification = [NSNotification notificationWithName:kSFLoginHostChangedNotification object:self userInfo:userInfoDict];
        [[NSNotificationCenter defaultCenter] postNotification:loginHostUpdateNotification];
    }
}

- (NSString *)loginHost {
    NSUserDefaults *defaults = [NSUserDefaults msdkUserDefaults];

    // First let's import any previously stored settings, if available.
    NSString *host = [defaults stringForKey:kDeprecatedLoginHostPrefKey];
    if (host) {
        [defaults setObject:host forKey:kSFUserAccountOAuthLoginHost];
        [defaults removeObjectForKey:kDeprecatedLoginHostPrefKey];
        [defaults synchronize];
        return host;
    }

    // Fetch from the standard defaults or bundle.
    NSString *loginHost = [defaults stringForKey:kSFUserAccountOAuthLoginHost];
    if ([loginHost length] > 0) {
        return loginHost;
    }

    // Login host not initialized. Set it up.
    NSString *managedLoginHost = ([SFManagedPreferences sharedPreferences].loginHosts)[0];
    if (managedLoginHost.length > 0) {
        loginHost = managedLoginHost;
    } else {

        /*
         * Do not fall back to default login host if MDM only permits authorized hosts, even if there are no other hosts.
         */
        if (![SFManagedPreferences sharedPreferences].onlyShowAuthorizedHosts) {
            NSString *bundleLoginHost = [[NSBundle mainBundle] objectForInfoDictionaryKey:kSFUserAccountOAuthLoginHost];
            if (bundleLoginHost.length > 0) {
                loginHost = bundleLoginHost;
            } else {
                loginHost = kSFUserAccountOAuthLoginHostDefault;
            }
        }
    }
    [defaults setObject:loginHost forKey:kSFUserAccountOAuthLoginHost];
    [defaults synchronize];
    return loginHost;
}

#pragma mark - Default Values

- (NSSet *)scopes
{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    NSArray *scopesArray = [defs objectForKey:kOAuthScopesKey] ?: [NSArray array];
    return [NSSet setWithArray:scopesArray];
}

- (void)setScopes:(NSSet *)newScopes
{
    NSArray *scopesArray = [newScopes allObjects];
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    [defs setObject:scopesArray forKey:kOAuthScopesKey];
    [defs synchronize];
}

- (NSString *)oauthCompletionUrl
{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    NSString *redirectUri = [defs objectForKey:kOAuthRedirectUriKey];
    return redirectUri;
}

- (void)setOauthCompletionUrl:(NSString *)newRedirectUri
{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    [defs setObject:newRedirectUri forKey:kOAuthRedirectUriKey];
    [defs synchronize];
}

- (NSString *)oauthClientId
{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    NSString *clientId = [defs objectForKey:kOAuthClientIdKey];
    return clientId;
}

- (void)setOauthClientId:(NSString *)newClientId
{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    [defs setObject:newClientId forKey:kOAuthClientIdKey];
    [defs synchronize];
}
+ (void)resetSessionCookie
{
    __weak typeof(self) weakSelf = self;
    [self removeCookiesFromDomains:@[@".salesforce.com", @".force.com", @".cloudforce.com"] withCompletion:^{
        [weakSelf addSidCookieForInstance];
    }];
}

+ (void)removeCookiesFromDomains:(NSArray *)domainNames withCompletion:(nullable void(^)())completionBlock {
    NSAssert(domainNames != nil && [domainNames count] > 0, @"No domain names given for deleting cookies.");
    WKWebsiteDataStore *dateStore = [WKWebsiteDataStore defaultDataStore];
    NSSet *websiteDataTypes = [NSSet setWithArray:@[ WKWebsiteDataTypeCookies]];
    [dateStore fetchDataRecordsOfTypes:websiteDataTypes
                     completionHandler:^(NSArray<WKWebsiteDataRecord *> *records) {

                         NSMutableArray<WKWebsiteDataRecord *> *deletedRecords = [NSMutableArray new];
                         for ( WKWebsiteDataRecord * record in records) {
                             for(NSString *domainName in domainNames) {
                                 if ([record.displayName containsString:domainName]) {
                                     [deletedRecords addObject:record];
                                 }
                             }
                         }
                         if (deletedRecords.count > 0)
                             [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes
                                                                       forDataRecords:deletedRecords
                                                                    completionHandler:^{
                                                                        if (completionBlock)
                                                                            completionBlock();
                                                                    }];
                     }];

}

+ (void)removeAllCookiesWithCompletion:(void(^)())completionBlock
{
    NSSet *websiteDataTypes = [NSSet setWithArray:@[WKWebsiteDataTypeCookies]];
    NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes
                                               modifiedSince:dateFrom
                                           completionHandler:^{
                                               if (completionBlock) {
                                                   completionBlock();
                                               }
                                           }];
}

+ (void)addSidCookieForInstance
{
    [self addSidCookieForDomain:[[SFUserAccountManager sharedInstance].currentUser.credentials.apiUrl host]];
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
            case NSURLErrorInternationalRoamingOff:
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

- (void)finalizeAuthCompletion
{
    // Apply the credentials that will ensure there is a user and that this
    // current user as the proper credentials.
    SFUserAccount *user = [[SFUserAccountManager sharedInstance] applyCredentials:self.coordinator.credentials
                                                                       withIdData:self.idCoordinator.idData];
    BOOL loginStateTransitionSucceeded = [user transitionToLoginState:SFUserAccountLoginStateLoggedIn];
    if (!loginStateTransitionSucceeded) {
        // We're in an unlikely, but nevertheless bad, state.  Fail this authentication.
        [self log:SFLogLevelError format:@"%@: Unable to transition user to a logged in state.  Login failed.", NSStringFromSelector(_cmd)];
        [self execFailureBlocks];
    } else {
        // Notify the session is ready
        [self willChangeValueForKey:@"haveValidSession"];
        [self didChangeValueForKey:@"haveValidSession"];
        NSDictionary *userInfo = nil;
        if (user) {
            userInfo = @{ @"account" : user };
        }
        [self initAnalyticsManager];
        [[NSNotificationCenter defaultCenter] postNotificationName:kSFAuthenticationManagerFinishedNotification
                                                            object:self
                                                          userInfo:userInfo];
        [self execCompletionBlocksWithUser:user];
    }
}

- (void)initAnalyticsManager
{
    SFUserAccount *user = [SFUserAccountManager sharedInstance].currentUser;
    SFSDKSalesforceAnalyticsManager *analyticsManager = [SFSDKSalesforceAnalyticsManager sharedInstanceWithUser:user];
    [analyticsManager updateLoggingPrefs];
}

- (void)execCompletionBlocksWithUser:(SFUserAccount *) user
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
            copiedBlock(localInfo,user);
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
        NSURLSession* session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
        [[session dataTaskWithRequest:request] resume];
    }
    [user.credentials revoke];
}

- (void)login
{
    [self loginWithCredentials:[self createOAuthCredentials]];
}


- (void)loginWithCredentials:(SFOAuthCredentials *) credentials
{
    NSAssert(credentials != nil, @"Credentials should be set.");

    // Setup the internal logic for the specified user.
    [self setupWithCredentials:credentials];

    // Trigger the login flow.
    if (self.coordinator.isAuthenticating) {
        [self.coordinator stopAuthentication];
    }

    self.coordinator.additionalOAuthParameterKeys = self.additionalOAuthParameterKeys;
    self.coordinator.additionalTokenRefreshParams = self.additionalTokenRefreshParams;

    if ([SalesforceSDKManager sharedManager].userAgentString != NULL) {
        self.coordinator.userAgentForAuth = [SalesforceSDKManager sharedManager].userAgentString(@"");
    }

    // Don't try to authenticate if MDM OnlyShowAuthorizedHosts is configured and there are no hosts.
    SFManagedPreferences *managedPreferences = [SFManagedPreferences sharedPreferences];
    if (managedPreferences.onlyShowAuthorizedHosts && managedPreferences.loginHosts.count == 0) {
        [self log:SFLogLevelDebug msg:@"Invalid MDM Configuration, OnlyShowAuthorizedHosts is enabled, but no hosts are provided"];
        NSString *appName = [[NSBundle mainBundle] infoDictionary][(NSString*)kCFBundleNameKey];
        NSDictionary *dict = @{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@ doesn't have a login page set up yet. Ask your Salesforce admin for help.", appName]};
        NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain code:kSFOAuthErrorInvalidMDMConfiguration userInfo:dict];
        [self oauthCoordinator:self.coordinator didFailWithError:error authInfo:nil];
        return;
    }
    [self.coordinator authenticate];
}

- (void)setupWithCredentials:(SFOAuthCredentials*) credentials {

    // re-create the oauth coordinator using credentials
    self.coordinator.delegate = nil;
    self.coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:credentials];
    self.coordinator.advancedAuthConfiguration = self.advancedAuthConfiguration;
    self.coordinator.delegate = self;
    self.coordinator.additionalOAuthParameterKeys = self.additionalOAuthParameterKeys;
    self.coordinator.additionalTokenRefreshParams = self.additionalTokenRefreshParams;
    self.coordinator.scopes =  self.scopes;
    // re-create the identity coordinator using credentials
    self.idCoordinator.delegate = nil;
    self.idCoordinator = [[SFIdentityCoordinator alloc] initWithCredentials:credentials];
    self.idCoordinator.delegate = self;
}

/**
 * Clears the account state of the given account (i.e. clears credentials, coordinator
 * instances, etc.
 * @param clearAccountData Whether to optionally revoke credentials and persisted data associated
 *        with the account.
 */
- (void)clearAccountState:(BOOL)clearAccountData {
    [self clearAccountState:clearAccountData withCompletion:nil];
}

/**
 * Clears the account state of the given account (i.e. clears credentials, coordinator
 * instances, etc.
 * @param clearAccountData Whether to optionally revoke credentials and persisted data associated
 *        with the account.
 */
- (void)clearAccountState:(BOOL)clearAccountData withCompletion:(void(^)())completion {
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self clearAccountState:clearAccountData];
        });
        return;
    }

    if (clearAccountData) {
        [SFSecurityLockout clearPasscodeState];
    }

    if (self.coordinator.view) {
        [self.coordinator.view removeFromSuperview];
    }

    __weak typeof(self) weakSelf = self;
    [SFAuthenticationManager removeAllCookiesWithCompletion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf.coordinator stopAuthentication];
            strongSelf.idCoordinator.idData = nil;
            strongSelf.coordinator.credentials = nil;
            if (completion) {
                completion();
            }
        });

    }];

}

- (void)cleanupStatusAlert
{
   [self.statusAlert dismissViewControllerAnimated:NO completion:nil];
}

- (void)presentAuthViewController:(WKWebView *)webView
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentAuthViewController:webView];
        });
        return;
    }
    
    if (self.authViewController == nil)
        self.authViewController = [[SFLoginViewController alloc] initWithNibName:nil bundle:nil];
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
}

- (void)showRetryAlertForAuthError:(NSError *)error alertTag:(NSInteger)tag
{
    if (self.statusAlert) {
        self.statusAlert = nil;
    }
    [[SalesforceSDKManager sharedManager] dismissSnapshot];
    [self log:SFLogLevelError format:@"Error during authentication: %@", error];
    [self showAlertWithTitle:[SFSDKResourceUtils localizedString:kAlertErrorTitleKey]
                     message:[NSString stringWithFormat:[SFSDKResourceUtils localizedString:kAlertConnectionErrorFormatStringKey], [error localizedDescription]]
            firstButtonTitle:[SFSDKResourceUtils localizedString:kAlertRetryButtonKey]
            secondButtonTitle:[SFSDKResourceUtils localizedString:kAlertDismissButtonKey]
                         tag:tag];
}

- (void)showAlertForConnectedAppVersionMismatchError
{
    [self showAlertWithTitle:[SFSDKResourceUtils localizedString:kAlertErrorTitleKey]
                     message:[SFSDKResourceUtils localizedString:kAlertVersionMismatchErrorKey]
            firstButtonTitle:[SFSDKResourceUtils localizedString:kAlertOkButtonKey]
            secondButtonTitle:[SFSDKResourceUtils localizedString:kAlertDismissButtonKey]
                         tag:kConnectedAppVersionMismatchViewTag];
}

- (void)showAlertWithTitle:(nullable NSString *)title message:(nullable NSString *)message firstButtonTitle:(nullable NSString *)firstButtonTitle secondButtonTitle:(nullable NSString *)secondButtonTitle tag:(NSInteger)tag
{
    if (nil == self.statusAlert) {
        __weak typeof(self) weakSelf = self;
        self.statusAlert = [UIAlertController alertControllerWithTitle:title
                                                           message:message
                                                    preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:firstButtonTitle
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action) {
                                       __strong typeof(weakSelf) strongSelf = weakSelf;
                                       if (tag == kOAuthGenericAlertViewTag) {
                                           [strongSelf dismissAuthViewControllerIfPresent];
                                           [strongSelf login];
                                       } else if (tag == kIdentityAlertViewTag) {
                                           [strongSelf.idCoordinator initiateIdentityDataRetrieval];
                                       } else if (tag == kConnectedAppVersionMismatchViewTag) {

                                           // The OAuth failure block should be followed, after acknowledging the version mismatch.
                                           [strongSelf execFailureBlocks];
                                       } else if (tag == kAdvancedAuthDialogTag) {
                                           [strongSelf delegateDidProceedWithBrowserFlow];
                                           
                                           // Let the OAuth coordinator know whether to proceed or not.
                                           if (strongSelf.authCoordinatorBrowserBlock) {
                                               strongSelf.authCoordinatorBrowserBlock(YES);
                                           }
                                       }
                                   }];
        [self.statusAlert addAction:okAction];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:secondButtonTitle
                                        style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *action) {
                                            __strong typeof(weakSelf) strongSelf = weakSelf;
                                            if(tag == kAdvancedAuthDialogTag) {
                                                [strongSelf cancelAuthentication];
                                                [strongSelf delegateDidCancelBrowserFlow];
                                           
                                                // Let the OAuth coordinator know whether to proceed or not.
                                                if (strongSelf.authCoordinatorBrowserBlock) {
                                                    strongSelf.authCoordinatorBrowserBlock(NO);
                                                }
                                            } else if (tag == kOAuthGenericAlertViewTag){
                                                // Let the delegate know about the cancellation
                                                [strongSelf delegateDidCancelGenericFlow];
                                            }
                                        }];
        
        [self.statusAlert addAction:cancelAction];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[SFRootViewManager sharedManager] pushViewController:weakSelf.statusAlert];
        });

    }
}

#pragma mark - Auth error handler methods

- (SFAuthErrorHandlerList *)populateDefaultAuthErrorHandlerList
{
    __weak typeof(self) weakSelf = self;
    SFAuthErrorHandlerList *authHandlerList = [[SFAuthErrorHandlerList alloc] init];
    
    // Invalid credentials handler
    
    self.invalidCredentialsAuthErrorHandler = [[SFAuthErrorHandler alloc]
                                           initWithName:kSFInvalidCredentialsAuthErrorHandler
                                           evalBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo) {
                                               __strong typeof(weakSelf) strongSelf = weakSelf;
                                               if ([[strongSelf class] errorIsInvalidAuthCredentials:error]) {
                                                   [strongSelf log:SFLogLevelWarning format:@"OAuth refresh failed due to invalid grant.  Error code: %ld", (long)error.code];
                                                   [strongSelf execFailureBlocks];
                                                   return YES;
                                               }
                                               return NO;
                                           }];
    [authHandlerList addAuthErrorHandler:self.invalidCredentialsAuthErrorHandler];
    
    // Connected app version mismatch handler
    
    self.connectedAppVersionAuthErrorHandler = [[SFAuthErrorHandler alloc]
                                            initWithName:kSFConnectedAppVersionAuthErrorHandler
                                            evalBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo) {
                                                __strong typeof(weakSelf) strongSelf = weakSelf;
                                                if (error.code == kSFOAuthErrorWrongVersion) {
                                                    [strongSelf log:SFLogLevelWarning format:@"OAuth refresh failed due to Connected App version mismatch.  Error code: %ld", (long)error.code];
                                                    [strongSelf showAlertForConnectedAppVersionMismatchError];
                                                    return YES;
                                                }
                                                return NO;
                                            }];
    [authHandlerList addAuthErrorHandler:self.connectedAppVersionAuthErrorHandler];
    
    // Network failure handler
    
    self.networkFailureAuthErrorHandler = [[SFAuthErrorHandler alloc]
                                                 initWithName:kSFNetworkFailureAuthErrorHandler
                                                 evalBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo) {
                                                     if ([[weakSelf class] errorIsNetworkFailure:error]) {
                                                         [weakSelf log:SFLogLevelWarning format:@"Auth token refresh couldn't connect to server: %@", [error localizedDescription]];
                                                         
                                                         if (authInfo.authType != SFOAuthTypeRefresh) {
                                                             [weakSelf log:SFLogLevelError format:@"Network failure for non-Refresh OAuth flow (%@) is a fatal error.", authInfo.authTypeDescription];
                                                             return NO;  // Default error handler will show the error.
                                                         } else if ([SFUserAccountManager sharedInstance].currentUser.credentials.accessToken == nil) {
                                                             [weakSelf log:SFLogLevelWarning msg:@"Network unreachable for access token refresh, and no access token is configured.  Cannot continue."];
                                                             return NO;
                                                         } else {
                                                             [weakSelf log:SFLogLevelInfo msg:@"Network failure for OAuth Refresh flow (existing credentials)  Try to continue."];
                                                             [weakSelf loggedIn:YES];
                                                             return YES;
                                                         }
                                                     }
                                                     return NO;
                                                 }];
    [authHandlerList addAuthErrorHandler:self.networkFailureAuthErrorHandler];

    // Generic failure handler
    self.genericAuthErrorHandler = [[SFAuthErrorHandler alloc]
                                                 initWithName:kSFGenericFailureAuthErrorHandler
                                                 evalBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo) {
                                                     [weakSelf clearAccountState:NO];
                                                     [weakSelf showRetryAlertForAuthError:error alertTag:kOAuthGenericAlertViewTag];
                                                     return YES;
                                                 }];
    [authHandlerList addAuthErrorHandler:self.genericAuthErrorHandler];
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
    [self addDelegate:delegate withPriority:SFAuthenticationManagerDelegatePriorityDefault];
}

- (void)addDelegate:(id<SFAuthenticationManagerDelegate>)delegate withPriority:(SFAuthenticationManagerDelegatePriority)priority
{
    @synchronized(self) {
        if (delegate) {
            if (!_delegates[@(priority)]) {
                NSHashTable *delegateList = [NSHashTable weakObjectsHashTable];
                [delegateList addObject:delegate];
                _delegates[@(priority)] = delegateList;
            } else {
                NSHashTable *delegateList = _delegates[@(priority)];
                [delegateList addObject:delegate];
            }
        }
    }
}

- (void)removeDelegate:(id<SFAuthenticationManagerDelegate>)delegate
{
    @synchronized(self) {
        if (delegate) {
            for (NSUInteger priority = SFAuthenticationManagerDelegatePriorityMax; priority <= SFAuthenticationManagerDelegatePriorityDefault; priority++) {
                if (_delegates[@(priority)]) {
                    [_delegates[@(priority)] removeObject:delegate];
                }
            }
        }
    }
}

- (void)enumerateDelegates:(void (^)(id<SFAuthenticationManagerDelegate>))block
{
    @synchronized(self) {
        for (NSUInteger priority = SFAuthenticationManagerDelegatePriorityMax; priority <= SFAuthenticationManagerDelegatePriorityDefault; priority++) {
            NSHashTable<id<SFAuthenticationManagerDelegate>> *safeCopy = [self.delegates[@(priority)] copy];
            for (id<SFAuthenticationManagerDelegate> delegate in safeCopy) {
                if (block) block(delegate);
            }
        }
    }
}

#pragma mark - Delegate Wrapper Methods

- (void)delegateDidProceedWithBrowserFlow {
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerDidProceedWithBrowserFlow:)]) {
            [delegate authManagerDidProceedWithBrowserFlow:self];
        }
    }];
}

- (void)delegateDidCancelBrowserFlow {
    __block BOOL handledByDelegate = NO;
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerDidCancelBrowserFlow:)]) {
            handledByDelegate = YES;
            [delegate authManagerDidCancelBrowserFlow:self];
        }
    }];
    
    // If no delegates implement authManagerDidCancelBrowserFlow, display Login Host List
    if (!handledByDelegate) {
        SFSDKLoginHostListViewController *hostListViewController = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
        hostListViewController.delegate = self;
        [[SFRootViewManager sharedManager] pushViewController:hostListViewController];
    }
}

- (void)delegateDidCancelGenericFlow {
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerDidCancelGenericFlow:)]) {
            [delegate authManagerDidCancelGenericFlow:self];
        }
    }];
}

#pragma mark - SFSDKLoginHostDelegate

- (void)hostListViewControllerDidSelectLoginHost:(SFSDKLoginHostListViewController *)hostListViewController {
    [hostListViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - SFUserAccountManagerDelegate

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
        willSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser
{
    [self clearAccountState:NO];
}

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(WKWebView *)view
{
    [self log:SFLogLevelDebug msg:@"oauthCoordinator:willBeginAuthenticationWithView:"];
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerWillBeginAuthWithView:)]) {
            [delegate authManagerWillBeginAuthWithView:self];
        }
    }];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didStartLoad:(WKWebView *)view
{
    [self log:SFLogLevelDebug msg:@"oauthCoordinator:didStartLoad:"];
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerDidStartAuthWebViewLoad:)]) {
            [delegate authManagerDidStartAuthWebViewLoad:self];
        }
    }];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFinishLoad:(WKWebView *)view error:(NSError *)errorOrNil
{
    [self log:SFLogLevelDebug msg:@"oauthCoordinator:didFinishLoad:error:"];
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerDidFinishAuthWebViewLoad:)]) {
            [delegate authManagerDidFinishAuthWebViewLoad:self];
        }
    }];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(WKWebView *)view
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

- (void)oauthCoordinatorWillBeginAuthentication:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerWillBeginAuthentication:authInfo:)]) {
            [delegate authManagerWillBeginAuthentication:self authInfo:info];
        }
    }];
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info
{
    [self log:SFLogLevelDebug format:@"oauthCoordinatorDidAuthenticate for userId: %@, auth info: %@", coordinator.credentials.userId, info];
    self.authInfo = info;

    // Logging event for token refresh flow.
    SFUserAccount *userAccount = [[SFUserAccountManager sharedInstance] accountForCredentials:self.coordinator.credentials];
    if (self.authInfo.authType == SFOAuthTypeRefresh) {
        [SFSDKEventBuilderHelper createAndStoreEvent:@"tokenRefresh" userAccount:userAccount className:NSStringFromClass([self class]) attributes:nil];
    } else {

        // Logging events for add user and number of servers.
        NSArray *accounts = [SFUserAccountManager sharedInstance].allUserAccounts;
        NSMutableDictionary *userAttributes = [[NSMutableDictionary alloc] init];
        userAttributes[@"numUsers"] = [NSNumber numberWithInteger:(accounts ? accounts.count : 0)];
        [SFSDKEventBuilderHelper createAndStoreEvent:@"addUser" userAccount:userAccount  className:NSStringFromClass([self class]) attributes:userAttributes];
        NSInteger numHosts = [SFSDKLoginHostStorage sharedInstance].numberOfLoginHosts;
        NSMutableArray<NSString *> *hosts = [[NSMutableArray alloc] init];
        for (int i = 0; i < numHosts; i++) {
            SFSDKLoginHost *host = [[SFSDKLoginHostStorage sharedInstance] loginHostAtIndex:i];
            if (host) {
                [hosts addObject:host.host];
            }
        }
        NSMutableDictionary *serverAttributes = [[NSMutableDictionary alloc] init];
        serverAttributes[@"numLoginServers"] = [NSNumber numberWithInteger:numHosts];
        serverAttributes[@"loginServers"] = hosts;
        [SFSDKEventBuilderHelper createAndStoreEvent:@"addUser" userAccount:nil className:NSStringFromClass([self class]) attributes:serverAttributes];
    }
    
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

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginBrowserAuthentication:(SFOAuthBrowserFlowCallbackBlock)callbackBlock {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self oauthCoordinator:coordinator willBeginBrowserAuthentication:callbackBlock];
        });
        return;
    }
    
    self.authCoordinatorBrowserBlock = callbackBlock;
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];;
    NSString *alertMessage = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"authAlertBrowserFlowMessage"], coordinator.credentials.domain, appName];
    
    if (self.statusAlert) {
        self.statusAlert = nil;
    }
    [self showAlertWithTitle:[SFSDKResourceUtils localizedString:@"authAlertBrowserFlowTitle"]
                     message:alertMessage
            firstButtonTitle:[SFSDKResourceUtils localizedString:@"authAlertOkButton"]
           secondButtonTitle:[SFSDKResourceUtils localizedString:@"authAlertCancelButton"]
                         tag:kAdvancedAuthDialogTag];
}

- (void)oauthCoordinatorDidCancelBrowserFlow:(SFOAuthCoordinator *)coordinator {
    __block BOOL handledByDelegate = NO;
    
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerDidCancelBrowserFlow:)]) {
            [delegate authManagerDidCancelBrowserFlow:self];
            handledByDelegate = YES;
        }
    }];
    
    if (!handledByDelegate) {
        SFSDKLoginHostListViewController *hostListViewController = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
        hostListViewController.delegate = self;
        [[SFRootViewManager sharedManager] pushViewController:hostListViewController];
    }
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator displayAlertMessage:(NSString *)message completion:(dispatch_block_t)completion {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@""
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:[SFSDKResourceUtils localizedString:@"authAlertOkButton"] style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              if (completion) completion();
                                                          }];
    
    [alert addAction:defaultAction];
    [[SFRootViewManager sharedManager] pushViewController:alert];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator displayConfirmationMessage:(NSString *)message completion:(void (^)(BOOL))completion {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@""
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:[SFSDKResourceUtils localizedString:@"authAlertOkButton"] style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              if (completion) completion(YES);
                                                          }];
    [alert addAction:defaultAction];
    
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:[SFSDKResourceUtils localizedString:@"authAlertCancelButton"] style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              if (completion) completion(NO);
                                                          }];
    [alert addAction:cancelAction];

    [[SFRootViewManager sharedManager] pushViewController:alert];
}

#pragma mark - SFIdentityCoordinatorDelegate

- (void)identityCoordinatorRetrievedData:(SFIdentityCoordinator *)coordinator
{
    [self retrievedIdentityData];
}

- (void)identityCoordinator:(SFIdentityCoordinator *)coordinator didFailWithError:(NSError *)error
{
    if (error.code == kSFIdentityErrorMissingParameters) {

        // No retry, as missing parameters are fatal
        [self log:SFLogLevelError format:@"Missing parameters attempting to retrieve identity data.  Error domain: %@, code: %ld, description: %@", [error domain], [error code], [error localizedDescription]];
        SFUserAccount *userAccount = [[SFUserAccountManager sharedInstance] accountForCredentials:coordinator.credentials];
        [self revokeRefreshToken:userAccount];
        self.authError = error;
        [self execFailureBlocks];
    } else {
        [self showRetryAlertForAuthError:error alertTag:kIdentityAlertViewTag];
    }
}

- (SFOAuthCredentials *)createOAuthCredentials {
    NSString *identifier = [[SFUserAccountManager sharedInstance] uniqueUserAccountIdentifier:self.oauthClientId];
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:identifier clientId:self.oauthClientId encrypted:YES];
    creds.redirectUri = self.oauthCompletionUrl;
    creds.domain = self.loginHost;
    creds.accessToken = nil;
    creds.clientId = self.oauthClientId;
    return creds;
}

@end
