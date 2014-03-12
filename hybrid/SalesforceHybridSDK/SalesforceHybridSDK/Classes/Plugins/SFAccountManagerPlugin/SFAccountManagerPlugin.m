//
//  SFAccountManagerPlugin.m
//  SalesforceHybridSDK
//
//  Created by Kevin Hawkins on 3/12/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SFAccountManagerPlugin.h"
#import "CDVPlugin+SFAdditions.h"
#import "CDVPluginResult.h"
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFUserAccount.h>

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

@interface SFAccountManagerPlugin ()

- (NSDictionary *)dictionaryFromUserAccount:(SFUserAccount *)account;

@end

@implementation SFAccountManagerPlugin

- (void)getUsers:(CDVInvokedUrlCommand *)command
{
    [self log:SFLogLevelDebug format:@"getUsers: arguments: %@", command.arguments];
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"getUsers" withArguments:command.arguments];
    NSMutableArray *userAccountArray = [NSMutableArray array];
    for (SFUserAccount *account in [SFUserAccountManager sharedInstance].allUserAccounts) {
        [userAccountArray addObject:[self dictionaryFromUserAccount:account]];
    }
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:userAccountArray];
    [self writeJavascript:[pluginResult toSuccessCallbackString:callbackId]];
}

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

@end
