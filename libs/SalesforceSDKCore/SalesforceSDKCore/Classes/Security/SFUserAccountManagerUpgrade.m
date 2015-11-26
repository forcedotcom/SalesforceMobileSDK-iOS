/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFUserAccountManagerUpgrade.h"
#import "SFUserAccountManager+Internal.h"
#import "SFUserAccountIdentity.h"

static NSString * const kOAuthCredentialsDataKeyPrefix  = @"oauth_credentials_data";
static NSString * const kLegacyDefaultAccountIdentifier = @"Default";
static NSString * const kLegacyUserDefaultsLastUserIdKey = @"LastUserId";

@implementation SFUserAccountManagerUpgrade

+ (SFUserAccount *)createUserFromLegacyAccountData
{
    NSString *legacyCredentialsDataKey = [SFUserAccountManagerUpgrade legacyCredentialsDataKey];
    NSData *encodedCredentialsData = [[NSUserDefaults standardUserDefaults] objectForKey:legacyCredentialsDataKey];
    if (encodedCredentialsData == nil) {
        // No legacy data.
        return nil;
    }
    
    [SFLogger log:[SFUserAccountManagerUpgrade class] level:SFLogLevelInfo msg:@"Found legacy account data.  Creating SFUserAccount based on that data."];
    SFOAuthCredentials *legacyCredentials = [NSKeyedUnarchiver unarchiveObjectWithData:encodedCredentialsData];
    SFUserAccount *accountFromLegacy = [[SFUserAccountManager sharedInstance] createUserAccountWithCredentials:legacyCredentials];
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:legacyCredentialsDataKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return accountFromLegacy;
}

+ (void)updateToActiveUserIdentity:(SFUserAccountManager *)accountManager
{
    NSString *legacyActiveUserId = [[NSUserDefaults standardUserDefaults] stringForKey:kLegacyUserDefaultsLastUserIdKey];
    if (legacyActiveUserId == nil)
        return;
    
    // Special case the temporary user, since no account manager "all accounts" methods return it.
    if ([legacyActiveUserId isEqualToString:accountManager.temporaryUserIdentity.userId]) {
        [SFLogger log:[SFUserAccountManagerUpgrade class] level:SFLogLevelDebug msg:@"Updating legacy active user (temporary user)."];
        accountManager.activeUserIdentity = accountManager.temporaryUserIdentity;
    } else {
        // Find the first user account that could match the user ID, and set it as the user identity.
        for (SFUserAccountIdentity *identity in [accountManager allUserIdentities]) {
            if ([identity.userId isEqualToString:legacyActiveUserId]) {
                [SFLogger log:[SFUserAccountManagerUpgrade class] level:SFLogLevelDebug msg:@"Updating legacy active user."];
                accountManager.activeUserIdentity = identity;
                break;
            }
        }
    }
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLegacyUserDefaultsLastUserIdKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Private methods

+ (NSString *)legacyCredentialsDataKey
{
    return [NSString stringWithFormat:@"%@-%@-%@", kOAuthCredentialsDataKeyPrefix, [SFUserAccountManager sharedInstance].loginHost, kLegacyDefaultAccountIdentifier];
}

@end
