//
//  SFSDKSPUserTracking.m
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 4/22/23.
//  Copyright (c) 2023-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "SFSDKSPUserTracking.h"
#import "SalesforceSDKManager.h"
#import "SFUserAccountManager.h"
#import "SFUserAccountManager+Internal.h"
#import "SFSDKAppConfig.h"
#import "SFSDKIDPConstants.h"
#import <SalesforceSDKCommon/SalesforceSDKCommon-Swift.h>

@implementation SFSDKSPUserTracking

+ (void)userLoggedIn:(SFUserAccount *)user {
    if ([SalesforceSDKManager sharedManager].idpKeychainGroup && ![[SalesforceSDKManager sharedManager] isIdentityProvider]) {
        // Configured for IDP as the SP
        NSString *redirectURI = [[[SalesforceSDKManager sharedManager] appConfig] oauthRedirectURI];
        NSString *scheme = [NSURL URLWithString:redirectURI].scheme;
        if (scheme) {
            NSString *keyName = [NSString stringWithFormat:kUserLoggedInKeyFormat, scheme];
            NSString *accountIdentifier = [[SFUserAccountManager sharedInstance] encodeUserIdentity:[user accountIdentity]];
            SFSDKKeychainResult *result = [SFSDKKeychainHelper createIfNotPresentWithService:keyName account:accountIdentifier accessGroup:[[SalesforceSDKManager sharedManager] idpKeychainGroup] cacheMode: CacheModeDisabled];
            
            if (!result.success) {
                [SFSDKCoreLogger e:[self class] format:@"Couldn't write user status to keychain: %@", [result.error description]];
            }
        }
    }
}

+ (void)userLoggedOut:(SFUserAccount *)user {
    if ([SalesforceSDKManager sharedManager].idpKeychainGroup && ![[SalesforceSDKManager sharedManager] isIdentityProvider]) {
        // Configured for IDP as the SP
        NSString *redirectURI = [[[SalesforceSDKManager sharedManager] appConfig] oauthRedirectURI];
        NSString *scheme = [NSURL URLWithString:redirectURI].scheme;
        if (scheme) {
            NSString *keyName = [NSString stringWithFormat:kUserLoggedInKeyFormat, scheme];
            NSString *accountIdentifier =  [[SFUserAccountManager sharedInstance] encodeUserIdentity:[user accountIdentity]];
            SFSDKKeychainResult *result = [SFSDKKeychainHelper removeWithService:keyName account:accountIdentifier accessGroup:[SalesforceSDKManager sharedManager].idpKeychainGroup cacheMode:CacheModeDisabled];
            if (!result.success) {
                [SFSDKCoreLogger e:[self class] format:@"Couldn't write user status to keychain: %@", [result.error description]];
            }
        }
    }
}

// Clears out old keys that could exist in the keychain if the app was deleted / reinstalled
+ (void)reset:(NSString *)keychainGroup {
    NSString *redirectURI = [[SFUserAccountManager sharedInstance] oauthCompletionUrl];
    NSString *scheme = [NSURL URLWithString:redirectURI].scheme;

    // If no users are logged in, get rid of any existing keys
    if (scheme && [SFUserAccountManager sharedInstance].allUserAccounts.count == 0) {
        NSString *keyName = [NSString stringWithFormat:kUserLoggedInKeyFormat, scheme];
        [SFSDKKeychainHelper removeWithService:keyName account:nil accessGroup:keychainGroup cacheMode:CacheModeDisabled];
    }
}

@end
