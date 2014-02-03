/*
 Copyright (c) 2012-2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFUserAccountManager.h"
#import "SFUserAccount+Internal.h"
#import "SFDirectoryManager.h"

#import "SFAuthenticationManager.h"
#import "SFAuthenticationViewHandler.h"
#import "SFAuthErrorHandlerList.h"
#import "SFIdentityData.h"

#import "SFSmartStore.h"
#import "SFPasscodeManager.h"

#import <SalesforceCommonUtils/SalesforceCommonUtils.h>
#import <SalesforceOAuth/SFOAuthCoordinator.h>
#import <SalesforceOAuth/SFOAuthCredentials.h>

// Notifications
NSString * const SFUserAccountManagerCurrentUserDidChangeNotification   = @"SFUserAccountManagerCurrentUserDidChangeNotification";
NSString * const SFUserAccountManagerDidCreateUserNotification          = @"SFUserAccountManagerDidCreateUserNotification";
NSString * const SFUserAccountManagerDidLoadNotification                = @"SFUserAccountManagerDidLoadNotification";
NSString * const SFUserAccountManagerDidSaveNotification                = @"SFUserAccountManagerDidSaveNotification";
NSString * const SFUserAccountManagerWillOpenLoginViewNotification      = @"SFUserAccountManagerWillOpenLoginViewNotification";
NSString * const SFUserAccountManagerDidLoginNotification               = @"SFUserAccountManagerDidLoginNotification";
NSString * const SFUserAccountManagerWillLogoutNotification             = @"SFUserAccountManagerWillLogoutNotification";
NSString * const SFUserAccountManagerDidLogoutNotification              = @"SFUserAccountManagerDidLogoutNotification";

NSString * const SFUserAccountManagerUserIdKey          = @"userId";
NSString * const SFUserAccountManagerUserAccountKey     = @"account";

NSString * const kSFLoginHostChangedNotification = @"kSFLoginHostChanged";
NSString * const kSFLoginHostChangedNotificationOriginalHostKey = @"originalLoginHost";
NSString * const kSFLoginHostChangedNotificationUpdatedHostKey = @"updatedLoginHost";

// Defaults
#warning TODO mobilesdk
NSString * const kDefaultRedirectUri = @"sfdc:///axm/detect/oauth/done";
NSString * const SFUserAccountManagerDefaultUserAccountId = @"TEMP_USER_ID";

// The key for storing the persisted OAuth scopes.
NSString * const kOAuthScopesKey = @"oauth_scopes";

// Key for whether or not the user has chosen the app setting to logout of the
// app when it is re-opened.
NSString * const kAppSettingsAccountLogout = @"account_logout_pref";


// Persistence Keys
static NSString * const kUserAccountsMapCodingKey  = @"accountsMap";
static NSString * const kUserDefaultsLastUserIdKey = @"LastUserId";

// Oauth
static NSString * const kSFUserAccountOAuthLoginHostDefault = @"login.salesforce.com"; // last resort default OAuth host
static NSString * const kSFUserAccountOAuthLoginHost = @"SFDCOAuthLoginHost";
static NSString * const kSFUserAccountOAuthRedirectUri = @"SFDCOAuthRedirectUri";
static NSString * const kSFUserAccountOAuthClientIdPreference = @"SFDCOAuthClientIdPreference";
static NSString * const kSFUserAccountOAuthClientId = @"SFDCOAuthClientId";
static NSString * const kSFSessionProtocol = @"SFDCSessionProtocol";

// Client ID
#warning TODO mobilesdk
static NSString * const kSFDCOAuthClientIDiOS = @"SfdcMobileChatteriOS";

@interface SFUserAccountManager () <SFAuthenticationManagerDelegate, SFIdentityCoordinatorDelegate> {
    UIWebView *_oauthLoginView;
    NSMutableArray *_delegates;
}

/** A map of user accounts by user ID
 */
@property (nonatomic, retain) NSMutableDictionary *userAccountMap;

/** The current activation code. It is kept in memory only
 and is revoked with the other credentials.
 */
@property (nonatomic, copy) NSString *activationCode;

@end

@implementation SFUserAccountManager

+ (instancetype)sharedInstance {
    static dispatch_once_t pred;
    static SFUserAccountManager *userAccountManager = nil;
    dispatch_once(&pred, ^{
		userAccountManager = [[self alloc] init];
	});
    return userAccountManager;
}

+ (void)applyCurrentLogLevel:(SFOAuthCredentials*)credentials {
    switch ([SFLogger logLevel]) {
        case SFLogLevelDebug:
            credentials.logLevel = kSFOAuthLogLevelDebug;
            break;
            
        case SFLogLevelInfo:
            credentials.logLevel = kSFOAuthLogLevelInfo;
            break;
            
        case SFLogLevelWarning:
            credentials.logLevel = kSFOAuthLogLevelWarning;
            break;
            
        case SFLogLevelError:
            credentials.logLevel = kSFOAuthLogLevelError;
            break;
    }
}

+ (NSSet *)scopes
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSArray *scopesArray = [defs objectForKey:kOAuthScopesKey];
    return [NSSet setWithArray:scopesArray];
}

+ (void)setScopes:(NSSet *)newScopes
{
    NSArray *scopesArray = [newScopes allObjects];
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:scopesArray forKey:kOAuthScopesKey];
    [defs synchronize];
}

- (id)init {
	self = [super init];
	if (self) {
        _delegates = [[NSMutableArray alloc] init];
        self.oauthClientId = [[self class] defaultClientIdentifier];
        self.oauthCompletionUrl = [[NSBundle mainBundle] objectForInfoDictionaryKey:kSFUserAccountOAuthRedirectUri];
        if (nil == self.oauthCompletionUrl) {
            self.oauthCompletionUrl = kDefaultRedirectUri;
        }
        
        _userAccountMap = [[NSMutableDictionary alloc] init];
        
        [self loadAccounts];
	}
	return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)makeUserIdSafe:(NSString*)aUserId {
    NSInteger userIdLen = [aUserId length];
    NSString *shortUserId = [aUserId substringToIndex:MIN(15,userIdLen)];
    return shortUserId;
}

- (void)setLoginHost:(NSString*)host {
    NSString *oldLoginHost = [self loginHost];
    
    [[NSUserDefaults standardUserDefaults] setObject:host forKey:kSFUserAccountOAuthLoginHost];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[SFAuthenticationManager sharedManager] cancelAuthentication];
    
    NSDictionary *userInfoDict = [NSDictionary dictionaryWithObjectsAndKeys:oldLoginHost, kSFLoginHostChangedNotificationOriginalHostKey, host, kSFLoginHostChangedNotificationUpdatedHostKey, nil];
    NSNotification *loginHostUpdateNotification = [NSNotification notificationWithName:kSFLoginHostChangedNotification object:self userInfo:userInfoDict];
    [[NSNotificationCenter defaultCenter] postNotification:loginHostUpdateNotification];
}

- (NSString *)loginHost {
    NSString *loginHost = [[NSUserDefaults standardUserDefaults] stringForKey:kSFUserAccountOAuthLoginHost];
    if (nil == loginHost || 0 == [loginHost length]) {
        loginHost = [[NSBundle mainBundle] objectForInfoDictionaryKey:kSFUserAccountOAuthLoginHost];
    }
    if (nil == loginHost || 0 == [loginHost length]) {
        loginHost = kSFUserAccountOAuthLoginHostDefault;
    }
    return loginHost;
}

#pragma mark - Delegates

- (void)addDelegate:(id<SFUserAccountManagerDelegate>)delegate {
    @synchronized(self) {
        [_delegates addObject:[NSValue valueWithNonretainedObject:delegate]];
    }
}

- (void)removeDelegate:(id<SFUserAccountManagerDelegate>)delegate {
    @synchronized(self) {
        [_delegates removeObject:[NSValue valueWithNonretainedObject:delegate]];
    }
}

- (void)enumerateDelegates:(void(^)(id<SFUserAccountManagerDelegate> delegate))block {
    @synchronized(self) {
        [_delegates enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            id<SFUserAccountManagerDelegate> delegate = [obj nonretainedObjectValue];
            if (delegate) {
                if (block) block(delegate);                
            }
        }];
    }
}

#pragma mark -
#pragma mark Account management

- (NSArray*)allUserIds {
    NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:nil ascending:NO selector:@selector(localizedCompare:)];
    return [[self.userAccountMap allKeys] sortedArrayUsingDescriptors:@[descriptor]];
}

/** Returns all existing account names in the keychain
 */
- (NSSet*)allExistingAccountNames {
    NSMutableDictionary *tokenQuery = [[NSMutableDictionary alloc] init];
    [tokenQuery setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [tokenQuery setObject:(__bridge id)kSecMatchLimitAll        forKey:(__bridge id)kSecMatchLimit];
    [tokenQuery setObject:(id)kCFBooleanTrue           forKey:(__bridge id)kSecReturnAttributes];
    
    CFArrayRef outArr = nil;
    OSStatus result = SecItemCopyMatching((__bridge CFDictionaryRef)[NSDictionary dictionaryWithDictionary:tokenQuery], (CFTypeRef *)&outArr);
    if (noErr == result) {
        NSMutableSet *accounts = [NSMutableSet set];
        for (NSDictionary *info in (__bridge_transfer NSArray *)outArr) {
            NSString *accountName = info[(__bridge NSString*)kSecAttrAccount];
            if (accountName) {
                [accounts addObject:accountName];
            }
        }
        
        return accounts;
    } else {
        [self log:SFLogLevelError format:@"Error querying for all existing accounts in the keychain: %ld", result];
        return nil;
    }
}

/** Returns a unique user account identifier
 */
- (NSString*)uniqueUserAccountIdentifier {
    NSSet *existingAccountNames = [self allExistingAccountNames];
   
    // Make sure to build a unique identifier
    NSString *identifier = nil;
    while (nil == identifier || [existingAccountNames containsObject:identifier]) {
        u_int32_t randomNumber = arc4random();
        identifier = [NSString stringWithFormat:@"%@-%u", [SFUserAccountManager defaultClientIdentifier], randomNumber];
    }

    return identifier;
}

- (SFUserAccount*)createUserAccount {
    SFUserAccount *newAcct = [[SFUserAccount alloc] initWithIdentifier:[self uniqueUserAccountIdentifier]];
    SFOAuthCredentials *creds = newAcct.credentials;
    creds.accessToken = nil;
    // Priority is given to any new activation code
    if (nil != self.activationCode) {
        creds.activationCode = self.activationCode;
    }
    creds.domain = self.loginHost;
    creds.redirectUri = self.oauthCompletionUrl;
    creds.clientId = self.oauthClientId;

    //when creating a fresh user account, always use a default user ID 
    // until the server tells us what the actual user ID is
    creds.userId = SFUserAccountManagerDefaultUserAccountId;

    //add the account to our list of possible accounts, but
    //don't set this as the current user account until somebody
    //asks us to login with this account.
    [self addAccount:newAcct];
    
    return newAcct;
}

- (SFUserAccount*)createUserAccountWithCredentials:(SFOAuthCredentials*)credentials {
    SFUserAccount *newAcct = [[SFUserAccount alloc] initWithIdentifier:[self uniqueUserAccountIdentifier]];
    newAcct.credentials = credentials;
    
    //add the account to our list of possible accounts, but
    //don't set this as the current user account until somebody
    //asks us to login with this account.
    [self addAccount:newAcct];
    
    return newAcct;
}

// called by init
- (void)loadAccounts {
	NSString *directory = [[SFDirectoryManager sharedManager] directoryForUser:self.currentUser type:SFDirectoryTypeDocuments];
    NSString *path = [directory stringByAppendingPathComponent:@"UserAccounts.plist"];
	
    NSMutableDictionary *rootObject = nil;
    @try {
        rootObject = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    }
    @catch (NSException *exception) {
        // If we received an exception when unarchiving this object, remove
        // it from disk and return a nil object
        rootObject = nil;
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        [self log:SFLogLevelError format:@"Error decrypting user accounts %@: %@", path, exception];
    }

    NSDictionary *savedAcctMap =  [rootObject objectForKey:kUserAccountsMapCodingKey];
    if (nil == savedAcctMap) {
        savedAcctMap = [NSDictionary dictionary];
    }
    NSMutableDictionary *mutableMap = [[NSMutableDictionary alloc] initWithDictionary:savedAcctMap];
    self.userAccountMap = mutableMap;
    
    NSString *curUserId = [self activeUserId];
    
    //in case the most recently used account was removed, recover by
    //finding the next available account
    if ((nil == curUserId) && ([self.userAccountMap count] > 0) ) {
        SFUserAccount *userAcct = [[self.userAccountMap allValues] objectAtIndex:0];
        curUserId = userAcct.credentials.userId;
    }
    if (nil == curUserId) {
        [self log:SFLogLevelInfo msg:@"Current active user id is nil"];
    }
    [self setCurrentUser:[self userAccountForUserId:curUserId]];
    
    // update the client ID in case it's changed (via settings, etc)
    [[[self currentUser] credentials] setClientId:[self oauthClientId]];

    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManagerDidUpdateCredentials:)]) {
            [delegate userAccountManagerDidUpdateCredentials:self];
        }
    }];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:SFUserAccountManagerDidLoadNotification
														object:self];
}

- (void)saveAccounts {
	NSString *directory = [[SFDirectoryManager sharedManager] directoryForUser:self.currentUser type:SFDirectoryTypeDocuments];
    NSString *path = [directory stringByAppendingPathComponent:@"UserAccounts.plist"];
    
	NSMutableDictionary *rootObject = [NSMutableDictionary dictionary];    
	[rootObject setValue:self.userAccountMap forKey:kUserAccountsMapCodingKey];
    
	BOOL result = [NSKeyedArchiver archiveRootObject:rootObject toFile:path];
    if (!result) {
        [self log:SFLogLevelError format:@"failed to archive user accounts: %@", rootObject];
    }

	[[NSNotificationCenter defaultCenter] postNotificationName:SFUserAccountManagerDidSaveNotification
														object:self];
}

- (SFUserAccount*)userAccountForUserId:(NSString*)userId {
    NSString *safeUserId = [self makeUserIdSafe:userId];
    SFUserAccount *result = [self.userAccountMap objectForKey:safeUserId];
	return result;
}

- (void)deleteAccountForUserId:(NSString*)userId {
    NSString *safeUserId = [self makeUserIdSafe:userId];
    SFUserAccount *acct = [self userAccountForUserId:safeUserId];
    if (nil != acct) {
        [self.userAccountMap removeObjectForKey:safeUserId];
        [self saveAccounts];
    }
}

- (void)addAccount:(SFUserAccount*)acct {
    NSString *safeUserId = [self makeUserIdSafe:acct.credentials.userId];
    [self.userAccountMap setObject:acct forKey:safeUserId];
	[self saveAccounts];
}

- (NSString *)activeUserId {
    NSString *result = [[NSUserDefaults standardUserDefaults] stringForKey:kUserDefaultsLastUserIdKey];
    return result;
}

- (void)setActiveUserId:(NSString*)userId {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults]; 
    if (nil == userId) {
        [defs removeObjectForKey:kUserDefaultsLastUserIdKey];
    } else {
        NSString *safeUserId = [self makeUserIdSafe:userId];
        [defs setValue:safeUserId forKey:kUserDefaultsLastUserIdKey]; 
    }
    [defs synchronize];

    NSDictionary *userInfo = nil;
    SFUserAccount *account = [self userAccountForUserId:userId];
    if (account)
        userInfo = @{ SFUserAccountManagerUserAccountKey : [self userAccountForUserId:userId] };
    
	[[NSNotificationCenter defaultCenter] postNotificationName:SFUserAccountManagerCurrentUserDidChangeNotification
														object:self
                                                      userInfo:userInfo];
}

- (void)replaceOldUser:(NSString*)oldUserId withUser:(SFUserAccount*)newUser {
    NSString *newUserId = [self makeUserIdSafe:newUser.credentials.userId];

    [self.userAccountMap removeObjectForKey:oldUserId];
    [self.userAccountMap setObject:newUser forKey:newUserId];
    
    NSString *defUserId = [self activeUserId];
    if (!defUserId || [defUserId isEqualToString:oldUserId]) {
        [self setActiveUserId:newUserId];
    }
    [self saveAccounts]; //persist the data
}

- (void)setCurrentUser:(SFUserAccount*)user {    
    if (![_currentUser isEqual:user]) {
        NSString *userId = [self makeUserIdSafe:user.credentials.userId];
        [self setActiveUserId:userId];
        
        [self willChangeValueForKey:@"currentUser"];
        _currentUser = user;
        [self didChangeValueForKey:@"currentUser"];
    }
}

// property accessor
- (NSString *)currentUserId {
    NSString *uid = self.currentUser.credentials.userId;
    if ([uid length]) {
        return [self makeUserIdSafe:uid];
    }
    return nil;
}

- (void)clearAccountState:(BOOL)clearAccountData {
    if (clearAccountData) {
        [self.coordinator revokeAuthentication];
        [SFSmartStore removeAllStores];
        [[SFPasscodeManager sharedManager] resetPasscode];
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

- (BOOL)mobilePinPolicyConfigured {
    return (self.idCoordinator.idData != nil
            && self.idCoordinator.idData.mobilePoliciesConfigured
            && self.idCoordinator.idData.mobileAppPinLength > 0
            && self.idCoordinator.idData.mobileAppScreenLockTimeout > 0);
}

#pragma mark - Login/Logout

- (void)login {
    SFUserAccount *currentAccount = [self currentUser];
	if (nil == currentAccount) {
        [self log:SFLogLevelInfo format:@"no current user account so creating a new one"];
        currentAccount = [self createUserAccount];
	}
    [self loginWithAccount:currentAccount];
}

- (void)loginWithAccount:(SFUserAccount*)account {
    // as soon as someone asks us to login with an account set that account as the current account
    self.currentUser = account;
    
    // update the host if necessary and revoke the credentials if the host has changed
    NSString *loginHost = [self loginHost];
    if (![loginHost isEqualToString:account.credentials.domain]) {
#warning TODO ignore that when the domain is actually a community falling under the previous domain or should we simply not revek anything here but let the client do it (like it does now on logout)?
//        account.credentials.domain = loginHost;
//        [account.credentials revoke];   // we're on a new host, clear previous tokens
    }
    
    // if the account doesn't specify any scopes, let's use the ones
    // defined in this account manager
    if (nil == account.accessScopes) {
        account.accessScopes = [[self class] scopes];
    }

    // re-create the oauth coordinator for this account
    self.coordinator.delegate = nil;
    self.coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:account.credentials];
    self.coordinator.scopes = account.accessScopes;
    self.coordinator.delegate = self;

    // re-create the identity coordinator for this account
    self.idCoordinator.delegate = nil;
    self.idCoordinator = [[SFIdentityCoordinator alloc] initWithCredentials:account.credentials];
    self.idCoordinator.delegate = self;

    // we always 'authenticate' explictly whether we have a refresh token (in which case we'll do session refresh) or not
    // so that we trigger an SFUserAccountManagerDidLoginNotification in order to fetch the user org settings and perform
    // any other login related activities
    SFAuthenticationManager *authManager = [SFAuthenticationManager sharedManager];
    [authManager addDelegate:self];
    authManager.authViewHandler = [[SFAuthenticationViewHandler alloc]
                                   initWithDisplayBlock:^(SFAuthenticationManager *authManager, UIWebView *authWebView) {
                                       if (_oauthLoginView != authWebView) {
                                           [_oauthLoginView removeFromSuperview];
                                           _oauthLoginView = authWebView;
                                       }
                                       
                                       [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
                                           if ([delegate respondsToSelector:@selector(userAccountManager:shouldDisplayWebView:)]) {
                                               [delegate userAccountManager:self shouldDisplayWebView:authWebView];
                                           }
                                       }];
                                   }
                                   dismissBlock:^(SFAuthenticationManager *authViewManager) {
                                       // No action here.  Login workflow will take care of view dismissal.
                                   }];
    
#warning TODO what to do with that? Is this application specific?
    // Remove default error completion blocks to let our app handle error routing.
    [authManager.authErrorHandlerList removeAuthErrorHandler:authManager.invalidCredentialsAuthErrorHandler];
    [authManager.authErrorHandlerList removeAuthErrorHandler:authManager.connectedAppVersionAuthErrorHandler];
    [authManager.authErrorHandlerList removeAuthErrorHandler:authManager.networkFailureAuthErrorHandler];
    [authManager.authErrorHandlerList removeAuthErrorHandler:authManager.genericAuthErrorHandler];

    [authManager
     loginWithCompletion:^(SFOAuthInfo *info) {
         [self handleAuthCompletion:self.currentUser.credentials info:info];
     }
     failure:^(SFOAuthInfo *info, NSError *error) {
         [self handleAuthFailure:error info:info];
     }];
}

- (void)logout {
    [self logout:SFUserAccountLogoutFlagNone];
}

- (void)logout:(SFUserAccountLogoutFlags)flags {
    // Supply the user account to the "Will Logout" notification before the credentials
    // are revoked.  This will ensure that databases and other resources keyed off of
    // the userID can be destroyed/cleaned up.
    SFUserAccount *userAccount = [self currentUser];
	NSDictionary *userInfo = nil;
    if (userAccount) {
        userInfo = @{ @"account": userAccount };
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SFUserAccountManagerWillLogoutNotification
														object:self
													  userInfo:userInfo];
    
    [[SFAuthenticationManager sharedManager] logout];
    
    [self willChangeValueForKey:@"haveValidSession"];
    [userAccount.credentials revoke];
    if (!(flags & SFUserAccountLogoutFlagPreserveActivationCode)) {
        self.activationCode = nil;
        [userAccount.credentials revokeActivationCode];
    }
    self.currentUser = nil;
    [self didChangeValueForKey:@"haveValidSession"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SFUserAccountManagerDidLogoutNotification
														object:self
													  userInfo:userInfo];
}

#pragma mark - Session

- (void)requestSessionRefresh {
    if (![SFTestContext isRunningTests]) {
        [self log:SFLogLevelInfo format:@"requestSessionRefresh"];
        
        //notify everybody that's listening on the session that the session is being invalidated
        [self willChangeValueForKey:@"haveValidSession"];
        SFUserAccount *account = [self currentUser];
        [account.credentials revokeAccessToken];
        [self saveAccounts];
        [self didChangeValueForKey:@"haveValidSession"];
        
        [self login];
    }
}

- (void)expireAuthenticationInfo {
    SFUserAccount *userAcct = [self currentUser];
    [userAcct.credentials revoke];
}

- (void)expireSession {
    SFUserAccount *userAcct = [self currentUser];
    [userAcct.credentials revokeAccessToken];
    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManagerDidUpdateCredentials:)]) {
            [delegate userAccountManagerDidUpdateCredentials:self];
        }
    }];
}

- (void)applyActivationCode:(NSString*)activationCode {
    self.activationCode = activationCode;
    [self currentUser].credentials.activationCode = activationCode;
}

- (BOOL)haveValidSession {
    SFUserAccount *userAcct = [self currentUser];
    BOOL result = [userAcct isSessionValid];
    return result;
}

#pragma mark -
#pragma mark Private methods

/**
 Starting with version 2 and Mocha 176, the default identifier is SfdcMobileChatteriOS.
 */
+ (NSString *)defaultClientIdentifier {
    return kSFDCOAuthClientIDiOS;
}

#pragma mark - OAuth support

- (void)notifySessionReady {
	[self willChangeValueForKey:@"currentUser"];
    [self didChangeValueForKey:@"currentUser"];
    
    [self willChangeValueForKey:@"haveValidSession"];
    [self didChangeValueForKey:@"haveValidSession"];

    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManagerDidUpdateCredentials:)]) {
            [delegate userAccountManagerDidUpdateCredentials:self];
        }
    }];

    NSDictionary *userInfo = nil;
    if (self.currentUser) {
        userInfo = @{ @"account" : self.currentUser };
    }
	[[NSNotificationCenter defaultCenter] postNotificationName:SFUserAccountManagerDidLoginNotification
														object:self
													  userInfo:userInfo];
}

- (void)handleAuthFailure:(NSError *)error info:(SFOAuthInfo *)authInfo {
    [self log:SFLogLevelWarning format:@"Error authenticating: %@", error];
    
    if (error.code != NSURLErrorNotConnectedToInternet) {
        // For a network down error, simply don't do anything except making sure the delegate
        // is notified about it.
        if (error.code == kSFOAuthErrorAccessDenied ||
            error.code == kSFOAuthErrorInvalidGrant ||
            error.code == kSFOAuthErrorInvalidClientCredentials) {     //access denied, expired/invalid credentials
            
            // log the tokens
            // the original reason for logging these tokens is to ensure we are sending the right things prior to receiving
            // an 'invalid_grant : expired access/refresh token' error
            // we're about to throw these tokens away, so it's reasonable to log them
            [self log:SFLogLevelDebug format:@"refreshToken=%@ accessToken=%@",
             self.currentUser.credentials.refreshToken, self.currentUser.credentials.accessToken];
            
            [self expireAuthenticationInfo]; // revoke access and refresh tokens for the current user
            [self requestSessionRefresh]; // restart the authentication process
        } else {
            // Don't do anything on network down and let the delegate handle that
            if (error.code == kSFOAuthErrorMalformed) {
                [self log:SFLogLevelError format:@"received malformed oauth response"];
            }
            [self expireSession]; // revoke the access token for the current user
            
            // don't refresh the session as this leads to an infinite loop when net is down.
        }
    }
    [self notifyLoginCompletedWithError:error];
}

- (void)handleAuthCompletion:(SFOAuthCredentials*)credentials info:(SFOAuthInfo *)info {
    // If the user is nil, create a new one with the specified credentials
    // otherwise update the current user credentials.
    if (nil == self.currentUser) {
        self.currentUser = [self createUserAccountWithCredentials:credentials];
        
        // Post a notification when a new user is being created
        [[NSNotificationCenter defaultCenter] postNotificationName:SFUserAccountManagerDidCreateUserNotification
                                                            object:self
                                                          userInfo:@{SFUserAccountManagerUserIdKey:self.currentUserId}];
    } else {
        self.currentUser.credentials = credentials;
    }
    
    [self saveAccounts];
    
    //if our default user id is currently the temporary user id,
    //we need to update it with the latest known good user id
    if ([[self activeUserId] isEqualToString:SFUserAccountManagerDefaultUserAccountId]) {
        [self log:SFLogLevelInfo format:@"Replacing temp user ID with %@",self.currentUser];
        [self replaceOldUser:SFUserAccountManagerDefaultUserAccountId withUser:self.currentUser];
    }
    //update currentUser and haveValidSession keys, post SFUserAccountManagerDidLoginNotification
    [self notifySessionReady];
    
    [self notifyLoginCompletedWithError:nil];
}

#pragma mark - Delegate methods

- (void)notifyWillOpenLoginView {
    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManagerWillBeginLogin:)]) {
            [delegate userAccountManagerWillBeginLogin:self];
        }
    }];    
}

- (void)notifyLoginCompletedWithError:(NSError*)errorOrNil {
	SEL method = @selector(userAccountManagerHandleLoginCompletion:withError:);
    
    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:method]) {
            [delegate userAccountManagerHandleLoginCompletion:self withError:errorOrNil];
        }        
    }];
}

#pragma mark - SFIdentityCoordinatorDelegate

- (void)identityCoordinator:(SFIdentityCoordinator *)coordinator didFailWithError:(NSError *)error
{
    // No action by SFAccountManager here.  Just pass it along.
    if (self.idDelegate != nil && [self.idDelegate respondsToSelector:@selector(identityCoordinator:didFailWithError:)]) {
        [self.idDelegate identityCoordinator:coordinator didFailWithError:error];
    }
}

- (void)identityCoordinatorRetrievedData:(SFIdentityCoordinator *)coordinator
{
    // Save the accounts (and credentials) when the identity information
    // changes so we have the latest stored on disk.
    [self saveAccounts];
    
    if (self.idDelegate != nil && [self.idDelegate respondsToSelector:@selector(identityCoordinatorRetrievedData:)]) {
        [self.idDelegate identityCoordinatorRetrievedData:coordinator];
    }
}

#pragma mark - SFOAuthCoordinatorDelegate methods

// NOTE: The deprecated delegate methods are intentionally not supported here.

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view
{
    // No action by SFAccountManager here.  Just pass it along.
    if (self.oauthDelegate != nil && [self.oauthDelegate respondsToSelector:@selector(oauthCoordinator:didBeginAuthenticationWithView:)]) {
        [self.oauthDelegate oauthCoordinator:coordinator didBeginAuthenticationWithView:view];
    }
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info
{
    // No action by SFAccountManager here.  Just pass it along.
    if (self.oauthDelegate != nil && [self.oauthDelegate respondsToSelector:@selector(oauthCoordinator:didFailWithError:authInfo:)]) {
        [self.oauthDelegate oauthCoordinator:coordinator didFailWithError:error authInfo:info];
    }
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFinishLoad:(UIWebView *)view error:(NSError *)errorOrNil
{
    // No action by SFAccountManager here.  Just pass it along.
    if (self.oauthDelegate != nil && [self.oauthDelegate respondsToSelector:@selector(oauthCoordinator:didFinishLoad:error:)]) {
        [self.oauthDelegate oauthCoordinator:coordinator didFinishLoad:view error:errorOrNil];
    }
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didStartLoad:(UIWebView *)view
{
    // No action by SFAccountManager here.  Just pass it along.
    if (self.oauthDelegate != nil && [self.oauthDelegate respondsToSelector:@selector(oauthCoordinator:didStartLoad:)]) {
        [self.oauthDelegate oauthCoordinator:coordinator didStartLoad:view];
    }
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view
{
    // No action by SFAccountManager here.  Just pass it along.
    if (self.oauthDelegate != nil && [self.oauthDelegate respondsToSelector:@selector(oauthCoordinator:willBeginAuthenticationWithView:)]) {
        [self.oauthDelegate oauthCoordinator:coordinator willBeginAuthenticationWithView:view];
    }
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info
{
    if (self.oauthDelegate != nil && [self.oauthDelegate respondsToSelector:@selector(oauthCoordinatorDidAuthenticate:authInfo:)]) {
        [self.oauthDelegate oauthCoordinatorDidAuthenticate:coordinator authInfo:info];
    }
}

- (BOOL)oauthCoordinatorIsNetworkAvailable:(SFOAuthCoordinator *)coordinator {
    __block BOOL result = NO;
    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManagerIsNetworkAvailable:)]) {
            result = [delegate userAccountManagerIsNetworkAvailable:self];
        }
    }];
    return result;
}

#pragma mark - SFAuthenticationManagerDelegate

- (void)authManagerWillBeginAuthWithView:(SFAuthenticationManager *)manager {
    [self notifyWillOpenLoginView];
}

- (void)authManagerDidStartAuthWebViewLoad:(SFAuthenticationManager *)authManager {
    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManagerDidStartLoad:)]) {
            [delegate userAccountManagerDidStartLoad:self];
        }
    }];
}

- (void)authManagerDidFinishAuthWebViewLoad:(SFAuthenticationManager *)manager {
    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManagerDidFinishLoad:)]) {
            [delegate userAccountManagerDidFinishLoad:self];
        }
    }];
}

#pragma mark - Utility methods

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

@end
