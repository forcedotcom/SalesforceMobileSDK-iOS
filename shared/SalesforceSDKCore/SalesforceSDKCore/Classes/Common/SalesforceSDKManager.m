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

// Error constants
NSString * const kSalesforceSDKManagerErrorDomain     = @"com.salesforce.sdkmanager.error";
NSString * const kSalesforceSDKManagerErrorDetailsKey = @"SalesforceSDKManagerErrorDetails";

static SFSDKPostLaunchCallbackBlock sPostLaunchAction;
static SFSDKLaunchErrorCallbackBlock sLaunchErrorAction;
static SFSDKLogoutCallbackBlock sPostLogoutAction;
static BOOL sIsLaunching = NO;

@implementation SalesforceSDKManager

+ (BOOL)isLaunching
{
    return sIsLaunching;
}

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

+ (SFSDKLogoutCallbackBlock)postLogoutAction
{
    return sPostLogoutAction;
}

+ (void)setPostLogoutAction:(SFSDKLogoutCallbackBlock)postLogoutAction
{
    sPostLogoutAction = postLogoutAction;
}

+ (void)launch
{
    NSError *launchStateError = nil;
    if (![self validateLaunchState:&launchStateError]) {
        [SFLogger log:[self class] level:SFLogLevelError msg:@"Please correct errors and try again."];
        sIsLaunching = NO;
        if ([self launchErrorAction]) {
            [self launchErrorAction](launchStateError, SFSDKLaunchActionNone);
        }
        return;
    }
    
    if (sIsLaunching) {
        NSError *alreadyLaunchingError = [[NSError alloc] initWithDomain:kSalesforceSDKManagerErrorDomain
                                                                    code:kSalesforceSDKManagerErrorLaunchAlreadyInProgress
                                                                userInfo:@{ NSLocalizedDescriptionKey : @"Launch already in progress" }];
        sIsLaunching = NO;
        if ([self launchErrorAction]) {
            [self launchErrorAction](alreadyLaunchingError, SFSDKLaunchActionNone);
        }
        return;
    }
    
    // If there's a passcode configured, we validate that first.
    [self passcodeValidationAtLaunch];
}

#pragma mark - Private methods

+ (BOOL)validateLaunchState:(NSError **)launchStateError
{
    BOOL validInputs = YES;
    NSMutableArray *launchStateErrorMessages = [NSMutableArray array];
    
    if ([[UIApplication sharedApplication] delegate].window == nil) {
        NSString *noWindowError = [NSString stringWithFormat:@"%@ cannot perform launch before the UIApplication delegate's window property has been initialized.  Cannot continue.", [self class]];
        [SFLogger log:[self class] level:SFLogLevelError msg:noWindowError];
        [launchStateErrorMessages addObject:noWindowError];
        validInputs = NO;
    }
    if ([[self connectedAppId] length] == 0) {
        NSString *noConnectedAppIdError = @"No value for Connected App ID.  Cannot continue.";
        [SFLogger log:[self class] level:SFLogLevelError msg:noConnectedAppIdError];
        [launchStateErrorMessages addObject:noConnectedAppIdError];
        validInputs = NO;
    }
    if ([[self connectedAppCallbackUri] length] == 0) {
        NSString *noCallbackUriError = @"No value for Connected App Callback URI.  Cannot continue.";
        [SFLogger log:[self class] level:SFLogLevelError msg:noCallbackUriError];
        [launchStateErrorMessages addObject:noCallbackUriError];
        validInputs = NO;
    }
    if ([[self authScopes] count] == 0) {
        NSString *noAuthScopesError = @"No auth scopes set.  Cannot continue.";
        [SFLogger log:[self class] level:SFLogLevelError msg:noAuthScopesError];
        [launchStateErrorMessages addObject:noAuthScopesError];
        validInputs = NO;
    }
    if (![self postLaunchAction]) {
        [SFLogger log:[self class] level:SFLogLevelWarning msg:@"No post-launch action set.  Nowhere to go after launch completes."];
    }
    if (![self launchErrorAction]) {
        [SFLogger log:[self class] level:SFLogLevelWarning msg:@"No launch error action set.  Nowhere to go if an error occurs during launch."];
    }
    
    if (!validInputs && launchStateError) {
        *launchStateError = [[NSError alloc] initWithDomain:kSalesforceSDKManagerErrorDomain
                                                       code:kSalesforceSDKManagerErrorInvalidLaunchParameters
                                                   userInfo:@{
                                                              NSLocalizedDescriptionKey : @"Invalid launch parameters",
                                                              kSalesforceSDKManagerErrorDetailsKey : launchStateErrorMessages
                                                              }];
    }
    
    return validInputs;
}

+ (void)passcodeValidationAtLaunch
{
    
}

@end
