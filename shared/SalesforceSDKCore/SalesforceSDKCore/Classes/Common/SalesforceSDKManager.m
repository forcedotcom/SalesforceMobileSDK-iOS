//
//  SalesforceSDKManager.m
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 9/8/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SalesforceSDKManager.h"
#import "SFUserAccountManager.h"

@implementation SalesforceSDKManager

+ (NSString *)connectedAppId
{
    return [SFUserAccountManager sharedInstance].oauthClientId;
}

+ (void)setConnectedAppId:(NSString *)connectedAppId
{
    [SFUserAccountManager sharedInstance].oauthClientId = connectedAppId;
}

+ (NSString *)connectedAppCallbackUri
{
    return [SFUserAccountManager sharedInstance].oauthCompletionUrl;
}

+ (void)setConnectedAppCallbackUri:(NSString *)connectedAppCallbackUri
{
    [SFUserAccountManager sharedInstance].oauthCompletionUrl = connectedAppCallbackUri;
}

+ (NSArray *)authScopes
{
    return [[SFUserAccountManager sharedInstance].scopes allObjects];
}

+ (void)setAuthScopes:(NSArray *)authScopes
{
    [SFUserAccountManager sharedInstance].scopes = [NSSet setWithArray:authScopes];
}



@end
