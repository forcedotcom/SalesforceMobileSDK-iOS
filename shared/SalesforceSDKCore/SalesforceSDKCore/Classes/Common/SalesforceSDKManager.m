//
//  SalesforceSDKManager.m
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 9/8/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SalesforceSDKManager.h"
#import "SFUserAccountManager.h"
#import "SFAuthenticationManager.h"

static SFSDKPostLaunchCallbackBlock sPostLaunchAction;
static SFSDKLaunchErrorCallbackBlock sLaunchErrorAction;

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

+ (SFSDKPostLaunchCallbackBlock)postLaunchAction
{
    return sPostLaunchAction;
}

+ (void)setPostLaunchAction:(SFSDKPostLaunchCallbackBlock)postLaunchAction
{
    sPostLaunchAction = postLaunchAction;
}

+ (SFSDKLaunchErrorCallbackBlock)launchErrorAction
{
    return sLaunchErrorAction;
}

+ (void)setLaunchErrorAction:(SFSDKLaunchErrorCallbackBlock)launchErrorAction
{
    sLaunchErrorAction = launchErrorAction;
}

+ (void)launch
{
    if (![self validateLaunchState]) {
        [SFLogger log:[self class] level:SFLogLevelError msg:@"Please correct errors and try again."];
        return;
    }
    
    // If there's a passcode configured, we validate that first.
    
}

#pragma mark - Private methods

+ (BOOL)validateLaunchState
{
    BOOL validInputs = YES;
    
    if ([[UIApplication sharedApplication] delegate].window == nil) {
        [SFLogger log:[self class] level:SFLogLevelError format:@"%@ cannot perform launch before the UIApplication delegate's window property has been initialized.  Cannot continue.", [self class]];
        validInputs = NO;
    }
    if ([[self connectedAppId] length] == 0) {
        [SFLogger log:[self class] level:SFLogLevelError msg:@"No value for Connected App ID.  Cannot continue."];
        validInputs = NO;
    }
    if ([[self connectedAppCallbackUri] length] == 0) {
        [SFLogger log:[self class] level:SFLogLevelError msg:@"No value for Connected App Callback URI.  Cannot continue."];
        validInputs = NO;
    }
    if ([[self authScopes] count] == 0) {
        [SFLogger log:[self class] level:SFLogLevelError msg:@"No auth scopes set.  Cannot continue."];
        validInputs = NO;
    }
    if (![self postLaunchAction]) {
        [SFLogger log:[self class] level:SFLogLevelWarning msg:@"No post-launch action set.  Nowhere to go after launch completes."];
    }
    if (![self launchErrorAction]) {
        [SFLogger log:[self class] level:SFLogLevelWarning msg:@"No launch error action set.  Nowhere to go if an error occurs during launch."];
    }
    
    return validInputs;
}

@end
