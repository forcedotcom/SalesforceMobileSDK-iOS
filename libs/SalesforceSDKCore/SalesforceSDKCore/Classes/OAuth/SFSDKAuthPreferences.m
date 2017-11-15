/*
 SFSDKAuthPreferences.m
 SalesforceSDKCore
 
 Created by Raj Rao on 7/25/17.
 
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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


#import "SFSDKAuthPreferences.h"
#import "SFManagedPreferences.h"
#import <SalesforceAnalytics/NSUserDefaults+SFAdditions.h>

NSString * const kSFLoginHostChangedNotification = @"kSFLoginHostChanged";
NSString * const kSFLoginHostChangedNotificationOriginalHostKey = @"originalLoginHost";
NSString * const kSFLoginHostChangedNotificationUpdatedHostKey = @"updatedLoginHost";

static NSString * const kDeprecatedLoginHostPrefKey = @"login_host_pref";

NSString * const kSFUserAccountOAuthLoginHostDefault = @"login.salesforce.com"; // last resort
NSString * const kSFUserAccountOAuthLoginHost = @"SFDCOAuthLoginHost";

// The key for storing the persisted OAuth scopes.
NSString * const kOAuthScopesKey = @"oauth_scopes";

// The key for storing the persisted OAuth client ID.
NSString * const kOAuthClientIdKey = @"oauth_client_id";

// The key for storing the persisted OAuth redirect URI.
NSString * const kOAuthRedirectUriKey = @"oauth_redirect_uri";

// The key for storing the persisted IDP app identifier
NSString * const kSFIDPKey = @"SFDCIdp";

// The key for storing the IDP Provider Enabled flag
NSString * const kSFIDPProviderKey = @"SFIDPProvider";

// The key for storing the persisted OAuth scopes.
NSString * const kOAuthAppName = @"oauth_app_name";

NSString * const kSFLegacyAuthIndicatorKey = @"SFDCUseLegacyAuth";

@implementation SFSDKAuthPreferences

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

#pragma mark - persistent properties
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

- (NSString *)idpAppURIScheme
{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    return [defs stringForKey:kSFIDPKey];
}

- (void)setIdpAppURIScheme:(NSString *)appIdentifier
{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    [defs setObject:appIdentifier forKey:kSFIDPKey];
    [defs synchronize];
}

- (BOOL)idpEnabled
{
    return self.idpAppURIScheme && self.idpAppURIScheme.length > 0;
}

- (BOOL)isIdentityProvider
{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    return [defs boolForKey:kSFIDPProviderKey];
}

- (void)setIsIdentityProvider:(BOOL)isIdentityProvider
{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    [defs setBool:isIdentityProvider forKey:kSFIDPProviderKey];
    [defs synchronize];
}

- (NSString *)appDisplayName
{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    return [defs stringForKey:kOAuthAppName];
}

- (void)setAppDisplayName:(NSString *)appDisplayName
{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    [defs setObject:appDisplayName forKey:kOAuthAppName];
    [defs synchronize];
}

- (BOOL)useLegacyAuthenticationManager{
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    return [defs stringForKey:kSFLegacyAuthIndicatorKey];

}

- (void)setUseLegacyAuthenticationManager:(BOOL)enabled {
    NSUserDefaults *defs = [NSUserDefaults msdkUserDefaults];
    [defs setBool:enabled forKey:kSFLegacyAuthIndicatorKey];
    [defs synchronize];
}


@end
