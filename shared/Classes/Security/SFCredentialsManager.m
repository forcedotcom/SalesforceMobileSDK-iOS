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

#import "SFCredentialsManager.h"
#import "SFOAuthCredentials.h"
#import "SalesforceSDKConstants.h"

// ------------------------------------------
// Private constants
// ------------------------------------------

NSString * const kDefaultCredentialsIdentifier = @"Default";

// Key for storing the user's configured login host.
NSString * const kLoginHost = @"login_host_pref";

// Key for the login host as defined in the app settings.
NSString * const kAppSettingsLoginHost = @"primary_login_host_pref";

// Value to use for login host if user never opens the app settings.
NSString * const kDefaultLoginHost = @"login.salesforce.com";

// Value for kAppSettingsLoginHost when a custom host is chosen.
NSString * const kAppSettingsLoginHostIsCustom = @"CUSTOM";

// Key for the custom login host value in the app settings.
NSString * const kAppSettingsLoginHostCustomValue = @"custom_login_host_pref";

// Key for whether or not the user has chosen the app setting to logout of the
// app when it is re-opened.
NSString * const kAppSettingsAccountLogout = @"account_logout_pref";

NSString * const kOAuthClientIdKey = @"oauth_client_id";

@interface SFCredentialsManager ()
{
    NSMutableDictionary *_credentialsDict;
}

@end

@implementation SFCredentialsManager

#pragma mark - init / dealloc / etc.

+ (SFCredentialsManager *)sharedInstance {
    static dispatch_once_t pred;
    static SFCredentialsManager *credentialsManager = nil;
	
    dispatch_once(&pred, ^{
		credentialsManager = [[self alloc] init];
	});
    return credentialsManager;
}

- (id)init
{
    self = [super init];
    if (self) {
        _credentialsDict = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (void)dealloc
{
    SFRelease(_credentialsDict);
    [super dealloc];
}

+ (void)initialize
{
    [self ensureAccountDefaultsExist];
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

- (SFOAuthCredentials *)credentials
{
    return [self credentials:kDefaultCredentialsIdentifier];
}

- (SFOAuthCredentials *)credentials:(NSString *)accountIdentifier
{
    SFOAuthCredentials *returnCreds = [_credentialsDict objectForKey:accountIdentifier];
    if (returnCreds == nil) {
        NSString *oauthClientId = [[self class] clientId];
        if (oauthClientId != nil) {
            NSString *fullIdentifier = [[self class] fullKeychainIdentifier:accountIdentifier];
            returnCreds = [[[SFOAuthCredentials alloc] initWithIdentifier:fullIdentifier clientId:oauthClientId encrypted:YES] autorelease];
            [_credentialsDict setObject:returnCreds forKey:accountIdentifier];
        }
    }
    
    return returnCreds;
}

- (void)setCredentials:(SFOAuthCredentials *)credentials
{
    [self setCredentials:credentials forAccount:kDefaultCredentialsIdentifier];
}

- (void)setCredentials:(SFOAuthCredentials *)credentials forAccount:(NSString *)accountIdentifier
{
    [_credentialsDict setObject:credentials forKey:accountIdentifier];
}

+ (NSString *)fullKeychainIdentifier:(NSString *)accountIdentifier
{
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
    NSString *loginHost = [self loginHost];
    return [NSString stringWithFormat:@"%@-%@-%@", appName, accountIdentifier, loginHost];
}

- (void)clearCredentialsState
{
    [self clearCredentialsState:kDefaultCredentialsIdentifier];
}

- (void)clearCredentialsState:(NSString *)accountIdentifier
{
    [_credentialsDict removeObjectForKey:accountIdentifier];
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:NO forKey:kAppSettingsAccountLogout];
    [defs synchronize];
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

- (BOOL)logoutSettingEnabled
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
    
    // If the app settings host value is nil/empty, it's never been set.  Initialize it to default and return it.
    if (nil == appSettingsLoginHost || [appSettingsLoginHost length] == 0) {
        [defs setValue:kDefaultLoginHost forKey:kAppSettingsLoginHost];
        [defs synchronize];
        return kDefaultLoginHost;
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
                [defs setValue:kDefaultLoginHost forKey:kAppSettingsLoginHost];
                [defs synchronize];
                return kDefaultLoginHost;
            }
        }
    }
    
    // If we got this far, we have a primary host value that exists, and isn't custom.  Return it.
    return appSettingsLoginHost;
}

@end
