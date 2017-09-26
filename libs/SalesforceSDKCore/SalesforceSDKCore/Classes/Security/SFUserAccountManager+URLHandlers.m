/*
 SFUserAccountManager+URLHandlers.m
 SalesforceSDKCore
 
 Created by Raj Rao on 9/25/17.
 
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

#import "SFUserAccountManager+Internal.h"
#import "SFUserAccountManager+URLHandlers.h"
#import "SFSDKOAuthClientConfig.h"
#import "SFSDKOAuthClientContext.h"

static NSString *const KSFStateParam = @"state";
static NSString *const kSFErrorReasonParam = @"errorReason";
static NSString *const kSFUserHintParam = @"user_hint";
static NSString *const kSFAppNameParam = @"app_name";
static NSString *const kSFAppDescParam = @"app_desc";
static NSString *const kSFCallingAppUrlParam = @"calling_app_url";

@implementation SFUserAccountManager (URLHandlers)

- (BOOL)handleNativeAuthResponse:(NSURL *_Nonnull)appUrlResponse options:(NSDictionary *_Nullable)options {
    //should return the shared instance for advanced auth
    NSString *state = [appUrlResponse valueForParameterName:KSFStateParam];
    NSString *key = [NSString stringWithFormat:@"%@-ADVANCED", state];
    SFSDKOAuthClient *client = [self.oauthClientInstances objectForKey:key];
    return [client handleURLAuthenticationResponse:appUrlResponse];
    
}

- (BOOL)handleIdpAuthError:(NSURL *_Nonnull)url options:(NSDictionary *_Nullable)options {
    
    NSString *reason = [url valueForParameterName:kSFErrorReasonParam];
    if (reason) {
        reason = [reason stringByRemovingPercentEncoding];
    }else {
        reason = @"IDP Authentication failed";
    }
    
    NSString *param = [url valueForParameterName:KSFStateParam];
    
    SFSDKOAuthClient *client = [self.oauthClientInstances objectForKey:param];
    SFOAuthCredentials *creds = nil;
    
    if (!client) {
        creds = [self newClientCredentials];
        client = [self fetchOAuthClient:creds completion:nil failure:nil];
        
    }
    __weak typeof (self) weakSelf = self;
    [client showAlertMessage:reason withCompletion:^{
        [weakSelf disposeOAuthClient:client];
    }];
    
    return YES;
}

- (BOOL)handleIdpInitiatedAuth:(NSURL *_Nonnull)url options:(NSDictionary *_Nullable)options {
    
    NSString *userHint = [url valueForParameterName:kSFUserHintParam];
    if (userHint) {
        SFUserAccountIdentity *identity = [self decodeUserIdentity:userHint];
        SFUserAccount *userAccount = [self userAccountForUserIdentity:identity];
        if (userAccount) {
            [self switchToUser:userAccount];
            return YES;
        }
    }
    
    SFOAuthCredentials *creds = [[SFUserAccountManager sharedInstance] newClientCredentials];
    NSString *key = [self clientKeyForCredentials:creds];
    __weak typeof (self) weakSelf = self;
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:creds  configBlock:^(SFSDKOAuthClientConfig  *config) {
        __strong typeof (self) strongSelf = weakSelf;
        config.loginHost = strongSelf.loginHost;
        config.isIdentityProvider = strongSelf.isIdentityProvider;
        config.scopes = strongSelf.scopes;
        config.oauthCompletionUrl = strongSelf.oauthCompletionUrl;
        config.oauthClientId = strongSelf.oauthClientId;
        config.idpAppUrl = strongSelf.idpAppUrl;
        config.appDisplayName = strongSelf.appDisplayName;
        config.idpEnabled = strongSelf.idpEnabled;
        config.isIDPInitiatedFlow = YES;
        config.scopes = strongSelf.scopes;
        config.loginHost = strongSelf.loginHost;
        config.oauthClientId = strongSelf.oauthClientId;
        config.delegate = strongSelf;
        config.safariViewDelegate = strongSelf;
        config.idpDelegate = strongSelf;
        config.idpLoginFlowSelectionBlock = strongSelf.idpLoginFlowSelectionAction;
        config.idpUserSelectionBlock = strongSelf.idpUserSelectionAction;
    }];
    [self.oauthClientInstances setObject:client forKey:key];
    //TODO : fix setting user hint
    client.context.userHint = userHint;
    return [client refreshCredentials];
}

- (BOOL)handleIdpRequest:(NSURL *_Nonnull)request options:(NSDictionary *_Nullable)options
{
    SFOAuthCredentials *idpAppsCredentials = [self newClientCredentials];
    NSString *userHint = [request valueForParameterName:kSFUserHintParam];
    SFOAuthCredentials *foundUserCredentials = nil;
    
    if (userHint) {
        SFUserAccountIdentity *identity = [self decodeUserIdentity:userHint];
        SFUserAccount *userAccount = [self userAccountForUserIdentity:identity];
        if (userAccount.credentials.accessToken!=nil) {
            foundUserCredentials = userAccount.credentials;
        }
    }
    
    SFSDKIDPAuthClient  *authClient = nil;
    BOOL showSelection = NO;
    
    if (!foundUserCredentials) {
        //kick off login flow
        authClient = [self fetchIDPAuthClient:idpAppsCredentials completion:nil failure:nil];
    } else if (foundUserCredentials) {
        authClient = [self fetchIDPAuthClient:foundUserCredentials completion:nil failure:nil];
    }
    
    if (self.currentUser!=nil && !foundUserCredentials) {
        showSelection = YES;
    }
    
    NSMutableDictionary *spAppOptions = [[NSMutableDictionary alloc] init];
    
    if ([request valueForParameterName:KSFStateParam]) {
        [spAppOptions setValue:[request valueForParameterName:KSFStateParam] forKey:KSFStateParam];
    }
    
    if ([request valueForParameterName:kSFAppNameParam]) {
        [spAppOptions setValue:[request valueForParameterName:kSFAppNameParam] forKey:kSFAppNameParam];
    }
    
    if ([request valueForParameterName:kSFAppDescParam]) {
        [spAppOptions setValue:[request valueForParameterName:kSFAppDescParam] forKey:kSFAppDescParam];
    }
    
    //if ([request valueForParameterName:@"app_desc"]) {
    [spAppOptions setValue:request.absoluteString forKey:kSFCallingAppUrlParam];
    //}
    authClient.config.callingAppOptions = spAppOptions;
    
    if (showSelection) {
        UIViewController<SFSDKUserSelectionView> *controller  = authClient.idpUserSelectionBlock();
        controller.spAppOptions = spAppOptions;
        controller.userSelectionDelegate = self;
        authClient.authWindow.viewController = controller;
        [authClient.authWindow enable];
    } else {
        [authClient refreshCredentials];
    }
    return YES;
}

- (BOOL)handleIdpResponse:(NSURL *_Nonnull)url options:(NSDictionary *_Nullable)options{
    
    NSString *param = [url valueForParameterName:KSFStateParam];
    NSString *key = [NSString stringWithFormat:@"%@-%@",param,@"IDP"];
    SFSDKOAuthClient *client = [self.oauthClientInstances objectForKey:key];
    return [client handleURLAuthenticationResponse:url];
}

@end
