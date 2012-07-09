/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

#import "SFAccountManager.h"
#import "SFOAuthCoordinator.h"
#import "SFOAuthCredentials.h"
#import "SFIdentityCoordinator.h"
#import "SFIdentityData.h"
#import "SalesforceSDKConstants.h"
#import "SFSecurityLockout.h"

// ------------------------------------------
// Private constants
// ------------------------------------------

NSString * const kDefaultAccountIdentifier = @"Default";

// Key for storing the user's configured login host.
NSString * const kLoginHost = @"login_host_pref";

// Key for the login host as defined in the app settings.
NSString * const kAppSettingsLoginHost = @"primary_login_host_pref";

// Points to the key to use in the main bundle for the login host, if the user
// never opens the app settings.
NSString * const kDefaultLoginHost = @"SFDCOAuthLoginHost";

// Value for kAppSettingsLoginHost when a custom host is chosen.
NSString * const kAppSettingsLoginHostIsCustom = @"CUSTOM";

// Key for the custom login host value in the app settings.
NSString * const kAppSettingsLoginHostCustomValue = @"custom_login_host_pref";

// Key for whether or not the user has chosen the app setting to logout of the
// app when it is re-opened.
NSString * const kAppSettingsAccountLogout = @"account_logout_pref";

// The key for storing the persisted OAuth client ID.
NSString * const kOAuthClientIdKey = @"oauth_client_id";

// The key for storing the persisted OAuth redirect URI.
NSString * const kOAuthRedirectUriKey = @"oauth_redirect_uri";

// The key for storing the persisted OAuth scopes.
NSString * const kOAuthScopesKey = @"oauth_scopes";

// The key prefix for storing the Identity data of the account.  Will be combined with
// account-specific information to ensure uniqueness across accounts.
NSString * const kOAuthIdentityDataKeyPrefix = @"oauth_identity_data";

static NSMutableDictionary *AccountManagerDict;

@interface SFAccountManager ()
{

}

/**
 * Initializes an instance of the account manager with the given account ID.
 * @param accountIdentifier The account ID associated with this account manager.
 */
- (id)initWithAccount:(NSString *)accountIdentifier;

/**
 * Builds the key to store and retrieve the identity data, based on the account ID.
 */
- (NSString *)idDataKey;

@end

@implementation SFAccountManager

@synthesize accountIdentifier = _accountIdentifier;
@synthesize credentials = _credentials;
@synthesize coordinator = _coordinator;
@synthesize idCoordinator = _idCoordinator;

#pragma mark - init / dealloc / etc.

+ (SFAccountManager *)sharedInstance
{
    return [self sharedInstanceForAccount:kDefaultAccountIdentifier];
}

+ (SFAccountManager *)sharedInstanceForAccount:(NSString *)accountIdentifier
{
    SFAccountManager *accountMgr = [AccountManagerDict objectForKey:accountIdentifier];
    if (accountMgr == nil) {
        @synchronized (AccountManagerDict) {
            // Check again, if this thread didn't beat the lock.
            accountMgr = [AccountManagerDict objectForKey:accountIdentifier];
            if (accountMgr == nil) {
                accountMgr = [[[SFAccountManager alloc] initWithAccount:accountIdentifier] autorelease];
                [AccountManagerDict setObject:accountMgr forKey:accountIdentifier];
            }
        }
    }
    
    return accountMgr;
}

- (id)initWithAccount:(NSString *)accountIdentifier
{
    self = [super init];
    if (self) {
        _accountIdentifier = [accountIdentifier copy];
    }
    
    return self;
}

- (void)dealloc
{
    SFRelease(_coordinator);
    SFRelease(_idCoordinator);
    SFRelease(_credentials);
    SFRelease(_accountIdentifier);
    [super dealloc];
}

+ (void)initialize
{
    [self ensureAccountDefaultsExist];
    AccountManagerDict = [[NSMutableDictionary alloc] init];
}

#pragma mark - Credentials management methods

+ (NSString *)clientId
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *clientId = [defs objectForKey:kOAuthClientIdKey];
    return clientId;
}

+ (void)setClientId:(NSString *)newClientId
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:newClientId forKey:kOAuthClientIdKey];
    [defs synchronize];
}

+ (NSString *)redirectUri
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *redirectUri = [defs objectForKey:kOAuthRedirectUriKey];
    return redirectUri;
}

+ (void)setRedirectUri:(NSString *)newRedirectUri
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:newRedirectUri forKey:kOAuthRedirectUriKey];
    [defs synchronize];
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

- (SFOAuthCoordinator *)coordinator
{
    if (_coordinator == nil) {
        SFOAuthCredentials *creds = self.credentials;
        if (creds != nil) {
            _coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
            _coordinator.scopes = [[self class] scopes];
        }
    }
    
    return _coordinator;
}

- (SFIdentityCoordinator *)idCoordinator
{
    if (_idCoordinator == nil) {
        SFOAuthCredentials *creds = self.credentials;
        _idCoordinator = [[SFIdentityCoordinator alloc] initWithCredentials:creds];
    }
    
    return _idCoordinator;
}

- (SFOAuthCredentials *)credentials
{
    if (_credentials == nil) {
        NSString *oauthClientId = [[self class] clientId];
        if (oauthClientId != nil) {
            NSString *fullIdentifier = [[self class] fullKeychainIdentifier:_accountIdentifier];
            _credentials = [[SFOAuthCredentials alloc] initWithIdentifier:fullIdentifier clientId:oauthClientId encrypted:YES];
            _credentials.domain = [[self class] loginHost];
            _credentials.redirectUri = [[self class] redirectUri];
        }
    }
    
    return _credentials;
}

- (SFIdentityData *)idData
{
    NSString *dataKey = [self idDataKey];
    NSData *encodedIdData = [[NSUserDefaults standardUserDefaults] objectForKey:dataKey];
    if (encodedIdData == nil)
        return nil;
    return [NSKeyedUnarchiver unarchiveObjectWithData:encodedIdData];
}

- (void)setIdData:(SFIdentityData *)idData
{
    NSString *dataKey = [self idDataKey];
    if (idData == nil || idData.dictRepresentation == nil) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self idDataKey]];
    } else {
        NSData *encodedData = [NSKeyedArchiver archivedDataWithRootObject:idData];
        [[NSUserDefaults standardUserDefaults] setObject:encodedData forKey:dataKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)idDataKey
{
    return [NSString stringWithFormat:@"%@-%@-%@", kOAuthIdentityDataKeyPrefix, [[self class] loginHost], self.accountIdentifier];
}

+ (NSString *)fullKeychainIdentifier:(NSString *)accountIdentifier
{
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
    NSString *loginHost = [self loginHost];
    return [NSString stringWithFormat:@"%@-%@-%@", appName, accountIdentifier, loginHost];
}

- (void)clearAccountState:(BOOL)clearAccountData
{
    if (clearAccountData) {
        [self.coordinator revokeAuthentication];
        self.idData = nil;
        [SFSecurityLockout resetPasscode];
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setBool:NO forKey:kAppSettingsAccountLogout];
        [defs synchronize];
    }
    
    if (self.coordinator.view) {
        [self.coordinator.view removeFromSuperview];
    }
    [_coordinator setDelegate:nil];
    [_idCoordinator setDelegate:nil];
    SFRelease(_idCoordinator);
    SFRelease(_coordinator);
    SFRelease(_credentials);
}

- (BOOL)mobilePinPolicyConfigured
{
    return (self.idData != nil
            && self.idData.mobilePoliciesConfigured
            && self.idData.mobileAppPinLength > 0
            && self.idData.mobileAppScreenLockTimeout > 0);
}

#pragma mark - Login host settings methods

+ (void)ensureAccountDefaultsExist
{
    
    // Getting the app settings login host will always initialize it to a proper value if it isn't already
    // set.
	NSString *appSettingsHostValue = [self appSettingsLoginHost];
    
    // Make sure we initialize the user-defined app setting as well, if it's not already.
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs synchronize];
    NSString *userDefinedLoginHost = [defs objectForKey:kLoginHost];
    if (nil == userDefinedLoginHost || [userDefinedLoginHost length] == 0) {
        [defs setValue:appSettingsHostValue forKey:kLoginHost];
        [defs synchronize];
    }
}

+ (NSString *)loginHost
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSString *loginHost = [defs objectForKey:kLoginHost];
    
    return loginHost;
}

+ (void)setLoginHost:(NSString *)newLoginHost
{
    [[NSUserDefaults standardUserDefaults] setObject:newLoginHost forKey:kLoginHost];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)updateLoginHost
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs synchronize];
    
	NSString *previousLoginHost = [defs objectForKey:kLoginHost];
	NSString *currentLoginHost = [[self class] appSettingsLoginHost];
    
    // Update the previous app settings value to current.
	[defs setValue:currentLoginHost forKey:kLoginHost];
    [defs synchronize];
    
	BOOL hostnameChanged = (nil != previousLoginHost && ![previousLoginHost isEqualToString:currentLoginHost]);
	if (hostnameChanged) {
		NSLog(@"updateLoginHost detected a host change in the app settings, from %@ to %@.", previousLoginHost, currentLoginHost);
	}
	
	return hostnameChanged;
}

+ (BOOL)logoutSettingEnabled
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults synchronize];
	BOOL logoutSettingEnabled =  [userDefaults boolForKey:kAppSettingsAccountLogout];
    NSLog(@"userLogoutSettingEnabled: %d", logoutSettingEnabled);
    
    return logoutSettingEnabled;
}

+ (NSString *)appSettingsLoginHost
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs synchronize];
    NSString *appSettingsLoginHost = [defs objectForKey:kAppSettingsLoginHost];
    
    NSString *defaultLoginHostFromBundle = [[NSBundle mainBundle] objectForInfoDictionaryKey:kDefaultLoginHost];
    if (nil == defaultLoginHostFromBundle || [defaultLoginHostFromBundle length] == 0) {
        defaultLoginHostFromBundle = @"login.salesforce.com";
    }
    
    // If the app settings host value is nil/empty, it's never been set.  Initialize it to default and return it.
    if (nil == appSettingsLoginHost || [appSettingsLoginHost length] == 0) {
        [defs setValue:defaultLoginHostFromBundle forKey:kAppSettingsLoginHost];
        [defs synchronize];
        return defaultLoginHostFromBundle;
    }
    
    // If a custom login host value was chosen and configured, return it.  If a custom value is
    // chosen but the value is *not* configured, reset the app settings login host to a sane
    // value and return that.
    if ([appSettingsLoginHost isEqualToString:kAppSettingsLoginHostIsCustom]) {  // User specified to use a custom host.
        NSString *customLoginHost = [defs objectForKey:kAppSettingsLoginHostCustomValue];
        if (nil != customLoginHost && [customLoginHost length] > 0) {
            // Custom value is set.  Return that.
            return customLoginHost;
        } else {
            // The custom host value is empty.  We'll try to set a previous user-defined
            // value for the primary first, and if we can't set that, we'll just set it to the default host.
            NSString *prevUserDefinedLoginHost = [defs objectForKey:kLoginHost];
            if (nil != prevUserDefinedLoginHost && [prevUserDefinedLoginHost length] > 0) {
                // We found a previously user-defined value.  Use that.
                [defs setValue:prevUserDefinedLoginHost forKey:kAppSettingsLoginHost];
                [defs synchronize];
                return prevUserDefinedLoginHost;
            } else {
                // No previously user-defined value either.  Use the default.
                [defs setValue:defaultLoginHostFromBundle forKey:kAppSettingsLoginHost];
                [defs synchronize];
                return defaultLoginHostFromBundle;
            }
        }
    }
    
    // If we got this far, we have a primary host value that exists, and isn't custom.  Return it.
    return appSettingsLoginHost;
}

@end
