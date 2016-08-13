/*
 Copyright (c) 2012-2016, salesforce.com, inc. All rights reserved.
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
#import "SalesforceSDKManager.h"
#import "SFUserAccount.h"
#import "SFUserAccountManager.h"
#import "SFUserAccountIdentity.h"
#import "SFUserAccountManagerUpgrade.h"
#import "SFAuthenticationViewHandler.h"
#import "SFAuthErrorHandler.h"
#import "SFAuthErrorHandlerList.h"
#import "SFSecurityLockout.h"
#import "SFIdentityData.h"
#import "SFSDKResourceUtils.h"
#import "SFRootViewManager.h"
#import "SFUserActivityMonitor.h"
#import "SFPasscodeManager.h"
#import "SFPasscodeProviderManager.h"
#import "SFPushNotificationManager.h"
#import "SFManagedPreferences.h"
#import "SFOAuthCredentials.h"
#import "SFOAuthInfo.h"
#import "NSURL+SFAdditions.h"
#import "SFInactivityTimerCenter.h"
#import "SFTestContext.h"
#import "SFLoginViewController.h"
#import <WebKit/WKWebView.h>

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

@interface SFAuthenticationManager ()
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
@property (nonatomic, strong, nonnull) NSHashTable<id<SFAuthenticationManagerDelegate>> *delegates;


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
        self.delegates = [NSHashTable weakObjectsHashTable];
        
        // Default auth web view handler
        __weak SFAuthenticationManager *weakSelf = self;
        self.authViewHandler = [[SFAuthenticationViewHandler alloc]
                                initWithDisplayBlock:^(SFAuthenticationManager *authManager, WKWebView *authWebView) {
                                    if (weakSelf.authViewController == nil)
                                        weakSelf.authViewController = [SFLoginViewController sharedInstance];
                                    [weakSelf.authViewController setOauthView:authWebView];
                                    [[SFRootViewManager sharedManager] pushViewController:weakSelf.authViewController];
                                } dismissBlock:^(SFAuthenticationManager *authViewManager) {
                                    [SFLoginViewController sharedInstance].oauthView = nil;
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
    }

    // No-op if the user is anonymous.
    if (user == [SFUserAccountManager sharedInstance].anonymousUser) {
        [self log:SFLogLevelDebug msg:@"logoutUser: user is anonymous.  No action taken."];
        return;
    }
    [self log:SFLogLevelInfo format:@"Logging out user '%@'.", user.userName];
    NSDictionary *userInfo = @{ @"account": user };
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFUserWillLogoutNotification
                                                        object:self
                                                      userInfo:userInfo];
    __weak SFAuthenticationManager *weakSelf = self;
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
        return;
    }
    
    // Otherwise, the current user is being logged out.  Supply the user account to the
    // "Will Logout" notification before the credentials are revoked.  This will ensure
    // that databases and other resources keyed off of the userID can be destroyed/cleaned up.
    if ([SFPushNotificationManager sharedInstance].deviceSalesforceId) {
        [[SFPushNotificationManager sharedInstance] unregisterSalesforceNotifications];
    }
    
    [self cancelAuthentication];
    [self clearAccountState:YES];
    
    [self willChangeValueForKey:@"haveValidSession"];
    [userAccountManager deleteAccountForUser:user error:nil];
    [userAccountManager saveAccounts:nil];
    [self revokeRefreshToken:user];
    userAccountManager.currentUser = nil;
    [self didChangeValueForKey:@"haveValidSession"];
    
    NSNotification *logoutNotification = [NSNotification notificationWithName:kSFUserLogoutNotification object:self];
    [[NSNotificationCenter defaultCenter] postNotification:logoutNotification];
    [self enumerateDelegates:^(id<SFAuthenticationManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(authManagerDidLogout:)]) {
            [delegate authManagerDidLogout:weakSelf];
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
    SFUserAccountIdentity *userIdentity = [SFUserAccountManager sharedInstance].currentUserIdentity;
    if (nil == userIdentity || [userIdentity isEqual:[SFUserAccountManager sharedInstance].temporaryUserIdentity]) {
        return NO;
    }
    
    // Check that the current user itself has a valid session
    SFUserAccount *userAcct = [[SFUserAccountManager sharedInstance] currentUser];
    return [userAcct isSessionValid];
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
            if ([[cookie.name lowercaseString] isEqualToString:[cookieToRemoveName lowercaseString]]) {
                for (NSString *domainToRemoveName in domainNames) {
                    if ([[cookie.domain lowercaseString] hasSuffix:[domainToRemoveName lowercaseString]]) {
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
        if (![[cookie.name lowercaseString] isEqualToString:kUserNameCookieKey]) {
            [cookieStorage deleteCookie:cookie];
        }
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
    // Apply the credentials that will ensure there is a current user and that this
    // current user as the proper credentials.
    [[SFUserAccountManager sharedInstance] applyCredentials:self.coordinator.credentials];
    
    // Assign the identity data to the current user
    NSAssert([SFUserAccountManager sharedInstance].currentUser != nil, @"Current user should not be nil at this point.");
    [[SFUserAccountManager sharedInstance] applyIdData:self.idCoordinator.idData];

    // Save the accounts
    [[SFUserAccountManager sharedInstance] saveAccounts:nil];

    // Notify the session is ready
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
        NSURLSession* session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
        [[session dataTaskWithRequest:request] resume];
    }
    [user.credentials revoke];
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

    // Setup the internal logic for the specified user.
    [self setupWithUser:account];

    // Trigger the login flow.
    if (self.coordinator.isAuthenticating) {
        [self.coordinator stopAuthentication];        
    }

    self.coordinator.additionalOAuthParameterKeys = self.additionalOAuthParameterKeys;

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
    self.coordinator.advancedAuthConfiguration = self.advancedAuthConfiguration;
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
        [SFSecurityLockout clearPasscodeState];
    }
    
    if (self.coordinator.view) {
        [self.coordinator.view removeFromSuperview];
    }
    
    [SFAuthenticationManager removeAllCookies];
    [self.coordinator stopAuthentication];
    self.idCoordinator.idData = nil;
    self.coordinator.credentials = nil;
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
        __weak SFAuthenticationManager *weakSelf = self;
        self.statusAlert = [UIAlertController alertControllerWithTitle:title
                                                           message:message
                                                    preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:firstButtonTitle
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action) {
                                       if (tag == kOAuthGenericAlertViewTag) {
                                           [weakSelf dismissAuthViewControllerIfPresent];
                                           [weakSelf login];
                                       } else if (tag == kIdentityAlertViewTag) {
                                           [weakSelf.idCoordinator initiateIdentityDataRetrieval];
                                       } else if (tag == kConnectedAppVersionMismatchViewTag) {

                                           // The OAuth failure block should be followed, after acknowledging the version mismatch.
                                           [weakSelf execFailureBlocks];
                                       } else if (tag == kAdvancedAuthDialogTag) {
                                           [weakSelf delegateDidProceedWithBrowserFlow];
                                           
                                           // Let the OAuth coordinator know whether to proceed or not.
                                           if (weakSelf.authCoordinatorBrowserBlock) {
                                               weakSelf.authCoordinatorBrowserBlock(YES);
                                           }
                                       }
                                   }];
        [self.statusAlert addAction:okAction];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:secondButtonTitle
                                        style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *action) {
                                            if(tag == kAdvancedAuthDialogTag) {
                                                [weakSelf cancelAuthentication];
                                                [weakSelf delegateDidCancelBrowserFlow];
                                           
                                                // Let the OAuth coordinator know whether to proceed or not.
                                                if (weakSelf.authCoordinatorBrowserBlock) {
                                                    weakSelf.authCoordinatorBrowserBlock(NO);
                                                }
                                            } else if (tag == kOAuthGenericAlertViewTag){
                                                // Let the delegate know about the cancellation
                                                [weakSelf delegateDidCancelGenericFlow];
                                            }
                                        }];
        
        [self.statusAlert addAction:cancelAction];
        [[SFRootViewManager sharedManager] pushViewController:self.statusAlert];
    }
}

#pragma mark - Auth error handler methods

- (SFAuthErrorHandlerList *)populateDefaultAuthErrorHandlerList
{
    __weak SFAuthenticationManager *weakSelf = self;
    SFAuthErrorHandlerList *authHandlerList = [[SFAuthErrorHandlerList alloc] init];
    
    // Invalid credentials handler
    
    self.invalidCredentialsAuthErrorHandler = [[SFAuthErrorHandler alloc]
                                           initWithName:kSFInvalidCredentialsAuthErrorHandler
                                           evalBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo) {
                                               if ([[weakSelf class] errorIsInvalidAuthCredentials:error]) {
                                                   [weakSelf log:SFLogLevelWarning format:@"OAuth refresh failed due to invalid grant.  Error code: %ld", (long)error.code];
                                                   [weakSelf execFailureBlocks];
                                                   return YES;
                                               }
                                               if (error.code == kSFOAuthErrorJWTInvalidGrant) {
                                                   [weakSelf log:SFLogLevelWarning format:@"JWT swap failed due to invalid grant.  Error code: %ld", (long)error.code];
                                                   [weakSelf execFailureBlocks];
                                                   return YES;
                                               }
                                               return NO;
                                           }];
    [authHandlerList addAuthErrorHandler:self.invalidCredentialsAuthErrorHandler];
    
    // Connected app version mismatch handler
    
    self.connectedAppVersionAuthErrorHandler = [[SFAuthErrorHandler alloc]
                                            initWithName:kSFConnectedAppVersionAuthErrorHandler
                                            evalBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo) {
                                                if (error.code == kSFOAuthErrorWrongVersion) {
                                                    [weakSelf log:SFLogLevelWarning format:@"OAuth refresh failed due to Connected App version mismatch.  Error code: %ld", (long)error.code];
                                                    [weakSelf showAlertForConnectedAppVersionMismatchError];
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
    @synchronized(self) {
        if (delegate) {
            [self.delegates addObject:delegate];
        }
    }
}

- (void)removeDelegate:(id<SFAuthenticationManagerDelegate>)delegate
{
    @synchronized(self) {
        if (delegate) {
            [self.delegates removeObject:delegate];
        }
    }
}

- (void)enumerateDelegates:(void (^)(id<SFAuthenticationManagerDelegate>))block
{
    @synchronized(self) {
        NSHashTable<id<SFAuthenticationManagerDelegate>> *safeCopy = [self.delegates copy];
        for (id<SFAuthenticationManagerDelegate> delegate in safeCopy) {
            if (block) block(delegate);
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
    
    // TODO: Determine if this is the correct approach. If so, then SFAuthenticationManager probably needs to conform to SFSDKLoginHostDelegate.
    if (!handledByDelegate) {
        SFSDKLoginHostListViewController *hostListViewController = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
        [[SFRootViewManager sharedManager] pushViewController:hostListViewController];
    }
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
        [self revokeRefreshToken:[SFUserAccountManager sharedInstance].currentUser];
        self.authError = error;
        [self execFailureBlocks];
    } else {
        [self showRetryAlertForAuthError:error alertTag:kIdentityAlertViewTag];
    }
}

@end
