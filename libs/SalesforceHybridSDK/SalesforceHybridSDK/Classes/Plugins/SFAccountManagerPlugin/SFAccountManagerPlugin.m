/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFAccountManagerPlugin.h"
#import "CDVPlugin+SFAdditions.h"
#import <Cordova/CDVPluginResult.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFUserAccount.h>
#import <SalesforceSDKCore/SFDefaultUserManagementViewController.h>
#import <SalesforceSDKCore/NSDictionary+SFAdditions.h>

// Public constants
NSString * const kUserAccountAuthTokenDictKey      = @"authToken";
NSString * const kUserAccountRefreshTokenDictKey   = @"refreshToken";
NSString * const kUserAccountLoginServerDictKey    = @"loginServer";
NSString * const kUserAccountIdentityUrlDictKey    = @"idUrl";
NSString * const kUserAccountInstanceServerDictKey = @"instanceServer";
NSString * const kUserAccountOrgIdDictKey          = @"orgId";
NSString * const kUserAccountUserIdDictKey         = @"userId";
NSString * const kUserAccountUsernameDictKey       = @"username";
NSString * const kUserAccountClientIdDictKey       = @"clientId";
SFSDK_USE_DEPRECATED_BEGIN
@interface SFAccountManagerPlugin ()

/**
 * Creates an NSDictionary from the given user account data.
 * @param account The SFUserAccount instance to create the dictionary from.
 * @return The NSDictionary representation of the user account.
 */
- (NSDictionary *)dictionaryFromUserAccount:(SFUserAccount *)account;

@end

@implementation SFAccountManagerPlugin

#pragma mark - Plugin methods

- (void)getUsers:(CDVInvokedUrlCommand *)command
{
    [SFSDKHybridLogger d:[self class] format:@"getUsers: arguments: %@", command.arguments];
    NSString* callbackId = command.callbackId;
    [self getVersion:@"getUsers" withArguments:command.arguments];
    NSMutableArray *userAccountArray = [NSMutableArray array];
    for (SFUserAccount *account in [SFUserAccountManager sharedInstance].allUserAccounts) {
        [userAccountArray addObject:[self dictionaryFromUserAccount:account]];
    }
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:userAccountArray];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (void)getCurrentUser:(CDVInvokedUrlCommand *)command
{
    [SFSDKHybridLogger d:[self class] format:@"getCurrentUser: arguments: %@", command.arguments];
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"getCurrentUser" withArguments:command.arguments];
    
    SFUserAccount *currentAccount = [SFUserAccountManager sharedInstance].currentUser;
    NSDictionary *currentAccountDict = (currentAccount == nil
            ? nil
            : [self dictionaryFromUserAccount:currentAccount]
    );
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:currentAccountDict];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (void)switchToUser:(CDVInvokedUrlCommand *)command
{
    [SFSDKHybridLogger d:[self class] format:@"switchToUser: arguments: %@", command.arguments];
    [self getVersion:@"switchToUser" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    if (argsDict == nil) {
        // With no user data, assume automatic management of user switching.
        NSArray *userAccounts = [SFUserAccountManager sharedInstance].allUserAccounts;
        if ([userAccounts count] == 1) {
            // Single account configured.  Switch to new user.
            [self loginWithCompletion:^(SFOAuthInfo * authInfo, SFUserAccount * newAccount) {
                [[SFUserAccountManager sharedInstance] switchToUser:newAccount];
            } failure:^(SFOAuthInfo * info, NSError * error) {
                [SFSDKHybridLogger e:[self class] format:@"switchToNewUser: Failed Switching to user account: %@", error.localizedDescription ];
            }];
        } else if ([userAccounts count] > 1) {
            // Already more than one account.  Let the user choose the account to switch to.
            SFDefaultUserManagementViewController *umvc = [[SFDefaultUserManagementViewController alloc] initWithCompletionBlock:^(SFUserManagementAction action) {
                [self.viewController dismissViewControllerAnimated:YES completion:NULL];
            }];
            [self.viewController presentViewController:umvc animated:YES completion:NULL];
        } else {
            // Zero accounts configured?  Logout, I guess.
            [self logout];
        }
    } else {
        // User data was passed in.  Assume API-level user switching.
        NSString *userId = [argsDict nonNullObjectForKey:kUserAccountUserIdDictKey];
        NSString *orgId = [argsDict nonNullObjectForKey:kUserAccountOrgIdDictKey];
        SFUserAccountIdentity *accountIdentity = [SFUserAccountIdentity identityWithUserId:userId orgId:orgId];
        SFUserAccount *account = [[SFUserAccountManager sharedInstance] userAccountForUserIdentity:accountIdentity];
        [SFSDKHybridLogger d:[self class] format:@"switchToUser: Switching to user account: %@", account];
        [[SFUserAccountManager sharedInstance] switchToUser:account];
    }
}

- (void)logout:(CDVInvokedUrlCommand *)command;
{
    [SFSDKHybridLogger d:[self class] format:@"logout: arguments: %@", command.arguments];
    NSString *callbackId = command.callbackId;
    [self getVersion:@"logout" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    NSString *userId = [argsDict nonNullObjectForKey:kUserAccountUserIdDictKey];
    NSString *orgId = [argsDict nonNullObjectForKey:kUserAccountOrgIdDictKey];
    SFUserAccountIdentity *accountIdentity = [SFUserAccountIdentity identityWithUserId:userId orgId:orgId];
    SFUserAccount *account = [[SFUserAccountManager sharedInstance] userAccountForUserIdentity:accountIdentity];
    if (account == nil || account == [SFUserAccountManager sharedInstance].currentUser) {
        [SFSDKHybridLogger d:[self class] message:@"logout: Logging out current user.  App state will reset."];
        [self logout];
    } else {
        [SFSDKHybridLogger d:[self class] format:@"logout: Logging out user account: %@", account];
        [self logoutUser:account];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
    }
}

#pragma mark - Private methods

- (NSDictionary *)dictionaryFromUserAccount:(SFUserAccount *)account
{
    NSDictionary *accountDict = @{ kUserAccountAuthTokenDictKey : account.credentials.accessToken,
                                   kUserAccountRefreshTokenDictKey : account.credentials.refreshToken,
                                   kUserAccountLoginServerDictKey : [NSString stringWithFormat:@"%@://%@", account.credentials.protocol, account.credentials.domain],
                                   kUserAccountIdentityUrlDictKey : [account.credentials.identityUrl absoluteString],
                                   kUserAccountInstanceServerDictKey : [account.credentials.instanceUrl absoluteString],
                                   kUserAccountOrgIdDictKey : account.credentials.organizationId,
                                   kUserAccountUserIdDictKey : account.credentials.userId,
                                   kUserAccountUsernameDictKey : account.userName,
                                   kUserAccountClientIdDictKey : account.credentials.clientId
                                   };
    return accountDict;
}

- (void)logout {
    [self logoutUser:[SFUserAccountManager sharedInstance].currentUser];
}

- (void)logoutUser:(SFUserAccount *)user {
    if ([SFUserAccountManager sharedInstance].useLegacyAuthenticationManager) {
        [[SFAuthenticationManager sharedManager] logout];
    } else {
        [[SFUserAccountManager sharedInstance] logout];
    }
}

- (void)loginWithCompletion:(SFOAuthFlowSuccessCallbackBlock)completionBlock failure:(SFOAuthFlowFailureCallbackBlock)failureBlock {
  if ([SFUserAccountManager sharedInstance].useLegacyAuthenticationManager) {
      [[SFAuthenticationManager sharedManager] loginWithCompletion:completionBlock failure:failureBlock];
  } else {
      [[SFUserAccountManager sharedInstance] loginWithCompletion:completionBlock failure:failureBlock];
  }
}

@end
SFSDK_USE_DEPRECATED_END
