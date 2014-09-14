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
#import "SFSecurityLockout.h"
#import <SalesforceOAuth/SFOAuthInfo.h>

// Error constants
NSString * const kSalesforceSDKManagerErrorDomain     = @"com.salesforce.sdkmanager.error";
NSString * const kSalesforceSDKManagerErrorDetailsKey = @"SalesforceSDKManagerErrorDetails";

// Helper class to handle user account and auth delegate calls.  Implementation at the end.
@interface SFSDKManagerDelegateHandler : NSObject <SFUserAccountManagerDelegate, SFAuthenticationManagerDelegate>

@end

static SFSDKPostLaunchCallbackBlock sPostLaunchAction;
static SFSDKLaunchErrorCallbackBlock sLaunchErrorAction;
static SFSDKLogoutCallbackBlock sPostLogoutAction;
static SFSDKSwitchUserCallbackBlock sSwitchUserAction;
static SFSDKLaunchAction sLaunchActions;
static BOOL sIsLaunching = NO;
static SFSDKManagerDelegateHandler *sDelegateHandler;

@implementation SalesforceSDKManager

+ (void)initialize
{
    sDelegateHandler = [[SFSDKManagerDelegateHandler alloc] init];
    [[SFUserAccountManager sharedInstance] addDelegate:sDelegateHandler];
    [[SFAuthenticationManager sharedManager] addDelegate:sDelegateHandler];
}

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

+ (SFSDKSwitchUserCallbackBlock)switchUserAction
{
    return sSwitchUserAction;
}

+ (void)setSwitchUserAction:(SFSDKSwitchUserCallbackBlock)switchUserAction
{
    sSwitchUserAction = switchUserAction;
}

+ (void)launch
{
    sLaunchActions = SFSDKLaunchActionNone;
    NSError *launchStateError = nil;
    if (![self validateLaunchState:&launchStateError]) {
        [SFLogger log:[self class] level:SFLogLevelError msg:@"Please correct errors and try again."];
        [self sendLaunchError:launchStateError];
        return;
    }
    
    if (sIsLaunching) {
        NSString * alreadyLaunchingMessage = @"Launch already in progress.";
        [SFLogger log:[self class] level:SFLogLevelError msg:alreadyLaunchingMessage];
        NSError *alreadyLaunchingError = [[NSError alloc] initWithDomain:kSalesforceSDKManagerErrorDomain
                                                                    code:kSalesforceSDKManagerErrorLaunchAlreadyInProgress
                                                                userInfo:@{ NSLocalizedDescriptionKey : alreadyLaunchingMessage }];
        [self sendLaunchError:alreadyLaunchingError];
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
    if (![self postLogoutAction]) {
        [SFLogger log:[self class] level:SFLogLevelWarning msg:@"No post-logout action set.  Nowhere to go when the user is logged out."];
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

+ (void)sendLaunchError:(NSError *)theLaunchError
{
    sIsLaunching = NO;
    if ([self launchErrorAction]) {
        [self launchErrorAction](theLaunchError, sLaunchActions);
    }
}

+ (void)sendPostLogout
{
    if ([self postLogoutAction]) {
        [self postLogoutAction]();
    }
}

+ (void)sendPostLaunch
{
    sIsLaunching = NO;
    if ([self postLaunchAction]) {
        [self postLaunchAction](sLaunchActions);
    }
}

+ (void)sendUserAccountSwitch:(SFUserAccount *)fromUser toUser:(SFUserAccount *)toUser
{
    if ([self switchUserAction]) {
        [self switchUserAction](fromUser, toUser);
    }
}

+ (void)passcodeValidationAtLaunch
{
    [SFSecurityLockout setLockScreenSuccessCallbackBlock:^(SFSecurityLockoutAction action) {
        [SFLogger log:[self class] level:SFLogLevelInfo msg:@"Passcode verified.  Proceeding with authentication validation."];
        sLaunchActions |= SFSDKLaunchActionPasscodeVerified;
        [self authValidationAtLaunch];
    }];
    [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
        // Note: Failed passcode verification automatically logs out users, which the logout
        // delegate handler will catch and pass on.  We just log the error and reset launch
        // state here.
        [SFLogger log:[self class] level:SFLogLevelError msg:@"Passcode validation failed.  Logging the user out."];
        sIsLaunching = NO;
    }];
    [SFSecurityLockout lock];
}

+ (void)authValidationAtLaunch
{
    if (![SFUserAccountManager sharedInstance].currentUser.credentials.accessToken) {
        // Works equally well for any of the above being nil, which are all conditions to
        // (re-)authenticate.
        [SFLogger log:[self class] level:SFLogLevelInfo msg:@"No valid credentials found.  Proceeding with authentication."];
        [[SFAuthenticationManager sharedManager] loginWithCompletion:^(SFOAuthInfo *authInfo) {
            [SFLogger log:[self class] level:SFLogLevelInfo format:@"Authentication (%@) succeeded.  Launch completed.", (authInfo.authType == SFOAuthTypeUserAgent ? @"User Agent" : @"Refresh")];
            sLaunchActions |= SFSDKLaunchActionAuthenticated;
            [self postLaunchAction];
        } failure:^(SFOAuthInfo *authInfo, NSError *authError) {
            [SFLogger log:[self class] level:SFLogLevelError format:@"Authentication (%@) failed: %@.", (authInfo.authType == SFOAuthTypeUserAgent ? @"User Agent" : @"Refresh"), [authError localizedDescription]];
            [self sendLaunchError:authError];
        }];
    } else {
        // If credentials already exist, we won't try to refresh them.
        [SFLogger log:[self class] level:SFLogLevelInfo msg:@"Credentials already present.  Will not attempt to authenticate."];
        sLaunchActions |= SFSDKLaunchActionAlreadyAuthenticated;
        [self postLaunchAction];
    }
}

@end

@implementation SFSDKManagerDelegateHandler

#pragma mark - SFAuthenticationManagerDelegate

- (void)authManagerDidLogout:(SFAuthenticationManager *)manager
{
    [SalesforceSDKManager sendPostLogout];
}

#pragma mark - SFUserAccountManagerDelegate

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         didSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser
{
    [SalesforceSDKManager sendUserAccountSwitch:fromUser toUser:toUser];
}

@end
