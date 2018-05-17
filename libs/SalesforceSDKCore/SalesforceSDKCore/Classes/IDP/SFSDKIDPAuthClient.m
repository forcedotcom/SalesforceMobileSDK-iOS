/*
 SFSDKIDPAuthClient.m
 SalesforceSDKCore
 
 Created by Raj Rao on 8/28/17.
 
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
#import "SFSDKIDPConstants.h"
#import "SFSDKIDPAuthClient.h"
#import "SFSDKOAuthClientConfig.h"
#import "SFSDKLoginFlowSelectionViewController.h"
#import "SFSDKUserSelectionNavViewController.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFSDKAuthRequestCommand.h"
#import "SFSDKAuthResponseCommand.h"
#import "SFSDKAuthErrorCommand.h"
#import "SFSDKIDPInitCommand.h"

@interface SFSDKIDPAuthClient()
@property (nonatomic, strong) SFSDKOAuthClientContext *context;
@end

@implementation SFSDKIDPAuthClient

@dynamic config;
@dynamic context;
@dynamic loginFlowSelectionController;

- (instancetype) initWithConfig:(SFSDKOAuthClientConfig *)config {
    self = [super initWithConfig:config];
    return self;
}

- (SFSDKWindowContainer *) authWindow {
    return [SFSDKWindowManager sharedManager].authWindow;
}

- (SFIDPLoginFlowSelectionBlock)idpLoginFlowSelectionBlock {
    if (!self.config.idpLoginFlowSelectionBlock) {
        return ^SFSDKLoginFlowSelectionViewController * {
            SFSDKLoginFlowSelectionViewController *controller = [[SFSDKLoginFlowSelectionViewController alloc] initWithNibName:nil bundle:nil];
            return controller;
            
        };
    }
    return self.config.idpLoginFlowSelectionBlock;
}

- (void)setIdpLoginFlowSelectionBlock:(SFIDPLoginFlowSelectionBlock)idpLoginFlowSelectionBlock {
    if (idpLoginFlowSelectionBlock) {
        self.config.idpLoginFlowSelectionBlock = idpLoginFlowSelectionBlock;
    }
}

- (SFIDPUserSelectionBlock)idpUserSelectionBlock {
    if (!self.config.idpUserSelectionBlock) {
        return ^SFSDKUserSelectionNavViewController * {
            SFSDKUserSelectionNavViewController *controller = [[SFSDKUserSelectionNavViewController alloc] initWithNibName:nil bundle:nil];
            return controller;
        };
    }
    return self.config.idpUserSelectionBlock;
}

- (void)setIdpUserSelectionBlock:(SFIDPUserSelectionBlock)userSelectionBlock {
    if (userSelectionBlock) {
        self.config.idpUserSelectionBlock = userSelectionBlock;
    }
}

- (BOOL)refreshCredentials:(void (^) (SFOAuthInfo *, SFUserAccount *))successCallbackBlock failure:(void (^)(SFOAuthInfo *, NSError *))failureBlock {
    self.config.successCallbackBlock = successCallbackBlock;
    self.config.failureCallbackBlock = failureBlock;
    return [self refreshCredentials];
}

- (BOOL)refreshCredentials {
    BOOL result = NO;
    if (self.credentials.accessToken==nil && self.config.idpEnabled) {
        [self.config.idpDelegate authClientDisplayIDPLoginFlowSelection:self];
    } else {
        result = [super refreshCredentials];
    }
    return result;
}

- (BOOL)initiateLocalLoginInSPApp {
    
    if (self.isAuthenticating){
        self.isAuthenticating = NO;
      
       [self.coordinator stopAuthentication];
    }
    self.config.loginViewControllerConfig.showSettingsIcon = NO;
    return [super refreshCredentials];

}

- (void)initiateIDPFlowInSPApp {
    // within SP App triggering the flow to IDP App.
    [self launchIDPApp];
}

- (void)beginIDPInitiatedFlow:(SFSDKIDPInitCommand *)command {
    // If no userHint then show selection dialog else Launch IDP App with the hint
    SFSDKMutableOAuthClientContext *context = [self.context mutableCopy];
    context.userHint = command.userHint;
    self.context = context;
    [self initiateIDPFlowInSPApp];
}

- (void)beginIDPFlow:(SFSDKAuthRequestCommand *)request {
    // Should begin IDP Flow in the IDP App?
    self.config.loginViewControllerConfig.showSettingsIcon = NO;
    SFSDKMutableOAuthClientContext *context = [self.context mutableCopy];
    self.context = context;
    [super refreshCredentials];
}

- (void)beginIDPFlowForNewUser {
    self.config.loginViewControllerConfig.showSettingsIcon = NO;
    [super refreshCredentials];
}

- (void)launchSPAppWithError:(NSError *)error reason:(NSString *)reason {
    
    NSString *spAppUrlStr = self.context.callingAppOptions[kSFOAuthRedirectUrlParam];
    NSURL *spAppUrl = [NSURL URLWithString:spAppUrlStr];
    NSURL *url = [self appURLWithError:error reason:reason app:spAppUrl.scheme];
    
    [[self.authWindow.viewController presentedViewController] dismissViewControllerAnimated:YES  completion:^{
        [self.authWindow dismissWindow];
        [[SFSDKWindowManager sharedManager].mainWindow presentWindow];
    }];
    
    BOOL launched  = [SFApplicationHelper openURL:url];
    
    if (!launched) {
        [SFSDKCoreLogger e:[self class] format:@"Could not launch spAPP to handle error %@",[error description]];
    }
}

- (void)setCallingAppOptionsInContext:(NSDictionary *)values {
    SFSDKMutableOAuthClientContext *context = [self.context mutableCopy];
    context.callingAppOptions = [[NSDictionary alloc] initWithDictionary:values copyItems:YES];
    self.context = context;
}

#pragma mark - private

- (void)launchIDPApp {
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf invokeIDPApp];
    });
}

- (void) invokeIDPApp {
    
    self.coordinator.codeVerifier = [[SFSDKCryptoUtils randomByteDataWithLength:kSFVerifierByteLength] msdkBase64UrlString];
    
    NSString *codeChallengeString = [[[self.coordinator.codeVerifier dataUsingEncoding:NSUTF8StringEncoding] msdkSha256Data] msdkBase64UrlString];
    
    SFSDKAuthRequestCommand *command = [[SFSDKAuthRequestCommand alloc] init];
    command.scheme = self.config.idpAppURIScheme;
    command.spClientId = self.config.oauthClientId;
    command.spCodeChallenge = codeChallengeString;
    command.spUserHint = self.context.userHint;
    command.spLoginHost = self.config.loginHost;
    command.spRedirectURI = self.config.oauthCompletionUrl;
    command.spState = self.credentials.identifier;
    command.spAppName = self.config.appDisplayName;
    
    NSURL *url = [command requestURL];
    
    if ( [self.config.idpDelegate respondsToSelector:@selector(authClient:willSendRequestForIDPAuth:)]) {
        [self.config.idpDelegate authClient:self willSendRequestForIDPAuth:command.allParams];
    }
    [SFSDKCoreLogger d:[self class] format:@"attempting to launch IDP app %@", url];
    BOOL launched  = [SFApplicationHelper openURL:url];
    if (launched) {
        if ( [self.config.idpDelegate respondsToSelector:@selector(authClient:didSendRequestForIDPAuth:)]) {
            [self.config.idpDelegate authClient:self willSendRequestForIDPAuth:command.allParams];
        }
    } else {
        [SFSDKCoreLogger e:[self class] format:@"attempting to launch IDP app %@ failed", url];
        if ( [self.config.idpDelegate  respondsToSelector:@selector(authClient:error:)]) {
            NSError *error = [self errorWithType:@"IDPAppLaunchFailed" description:@"Could not launch the IDP app"];
            [self.config.idpDelegate authClient:self error:error];
        }
    }
    
}

- (void)launchSPApp {
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf invokeSPApp];
    });
}

- (void)invokeSPApp {
    
    SFSDKAuthResponseCommand *responseCommand = [[SFSDKAuthResponseCommand alloc] init];
   
    NSString *spAppRedirectUrl = self.context.callingAppOptions[kSFOAuthRedirectUrlParam];
    NSURL *spAppURL = [NSURL URLWithString:spAppRedirectUrl];
    responseCommand.scheme = spAppURL.scheme;
    responseCommand.authCode = self.coordinator.spAppCredentials.authCode;
    responseCommand.state = self.context.callingAppOptions[kSFStateParam];
    
    NSURL *url = [responseCommand requestURL];
    if ( [self.config.idpDelegate respondsToSelector:@selector(authClient:willSendResponseForIDPAuth:)]) {
        [self.config.idpDelegate authClient:self willSendResponseForIDPAuth:responseCommand.allParams];
    }

    [[self.authWindow.viewController presentedViewController] dismissViewControllerAnimated:YES  completion:^{
        [self.authWindow dismissWindow];
        [[SFSDKWindowManager sharedManager].mainWindow presentWindow];
    }];
    
    BOOL launched  = [SFApplicationHelper openURL:url];
    if (launched) {
        if ( [self.config.idpDelegate respondsToSelector:@selector(authClient:didSendRequestForIDPAuth:)]) {
            [self.config.idpDelegate authClient:self didSendRequestForIDPAuth:responseCommand.allParams];
        }
    } else {
        [SFSDKCoreLogger e:[self class] format:@"attempting to launch SP app %@ failed", url];
        if ( [self.config.idpDelegate respondsToSelector:@selector(authClient:error:)]) {
            NSError *error = [self errorWithType:@"SPAppLaunchFailed" description:@"Could not launch the SP app"];
            [self.config.idpDelegate authClient:self error:error];
        }
    }
    
}

- (NSURL *)appURLWithError:(NSError *)error reason:(NSString *)reason app:(NSString *)appScheme {

    SFSDKAuthErrorCommand *command = [[SFSDKAuthErrorCommand alloc] init];
    command.scheme = appScheme;

    NSString *errorCode = error?[NSString stringWithFormat:@"%d",error.domain.intValue]:@"-999";
    NSString *errorDesc = @"";

    if (error)
        errorDesc = [[error localizedDescription] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
    
    if (!reason)
        reason = errorDesc;
    reason = [reason stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];

    command.errorCode = errorCode;
    command.errorReason = reason;
    command.errorDescription = errorDesc;
    command.state = [self.context.callingAppOptions objectForKey:kSFStateParam];

    return [command requestURL];
}


#pragma - mark SFOAuthCoordinatorDelegate
- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {
    
    // We are in the process of adding an account
    [SFSDKCoreLogger i:[self class] format:@"oauthCoordinatorDidAuthenticate"];
    [SFSDKCoreLogger d:[self class] format:@"oauthCoordinatorDidAuthenticate for userId: %@, auth info: %@", coordinator.credentials.userId, info];
    if ([self.config.delegate respondsToSelector:@selector(authClientDidFinish:)]) {
        [self.config.delegate authClientDidFinish:self];
    }
}

- (void)oauthCoordinatorDidFetchAuthCode:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)authInfo {
    if ([self.config.idpDelegate respondsToSelector:@selector(authClientDidFetchAuthCode:)]) {
        [self.config.idpDelegate authClientDidFetchAuthCode:self];
    }
    [self launchSPApp];
}

- (NSError *)errorWithType:(NSString *)type description:(NSString *)description {
    NSAssert(type, @"error type can't be nil");
    int code = 999;
    NSDictionary *dict = @{@"error": type,
                           @"descpription": description,
                           NSLocalizedDescriptionKey: description};
    NSError *error = [NSError errorWithDomain:kSFIdentityErrorDomain code:code userInfo:dict];
    return error;
}

- (void)continueIDPFlow:(SFOAuthCredentials *)userCredentials {
    
    SFSDKMutableOAuthClientContext *mutableContext = [self.context mutableCopy];
    mutableContext.credentials = userCredentials;
    self.config.loginViewControllerConfig.showSettingsIcon = NO;
    self.context = mutableContext;
    self.coordinator.credentials = userCredentials;
    SFOAuthCredentials *spAppCredentials = [self spAppCredentials];
    
    self.coordinator.credentials = mutableContext.credentials;
    [self.coordinator beginIDPFlow:spAppCredentials];
}

- (SFOAuthCredentials *)spAppCredentials {
    
    NSString *clientId = self.context.callingAppOptions[kSFOAuthClientIdParam];
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:clientId clientId:clientId encrypted:NO];
    creds.redirectUri = self.context.callingAppOptions[kSFOAuthRedirectUrlParam];
    creds.challengeString = self.context.callingAppOptions[kSFChallengeParamName];
    creds.accessToken = nil;
    
    NSString *loginHost = self.context.callingAppOptions[kSFLoginHostParam];
    
    if (loginHost==nil || [loginHost isEmptyOrWhitespaceAndNewlines]){
        loginHost = self.config.loginHost;
    }
    creds.domain = loginHost;
    self.config.scopes = [self decodeScopes:self.context.callingAppOptions[kSFScopesParam]];
    return creds;
}

- (SFOAuthCredentials *)idpAppCredentials {
    
    NSString *clientId = self.context.callingAppOptions[kSFOAuthClientIdParam];
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:clientId clientId:clientId encrypted:NO];
    creds.redirectUri = self.context.callingAppOptions[kSFOAuthRedirectUrlParam];
    creds.challengeString = self.context.callingAppOptions[kSFChallengeParamName];
    creds.accessToken = nil;
    
    NSString *loginHost = self.context.callingAppOptions[kSFLoginHostParam];
    
    if (loginHost==nil || [loginHost isEmptyOrWhitespaceAndNewlines]){
        loginHost = self.config.loginHost;
    }
    creds.domain = loginHost;
    self.config.scopes = [self decodeScopes:self.context.callingAppOptions[kSFScopesParam]];
    return creds;
}


- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info {
    
    [SFSDKCoreLogger d:[self class] format:@"oauthCoordinator:didFailWithError: %@, authInfo: %@", error, self.context.authInfo];
    NSString *state = [self.context.callingAppOptions objectForKey:kSFStateParam];
    if (state!=nil) {
        [self launchSPAppWithError:error reason:nil];
    }else {
        SFSDKMutableOAuthClientContext *mutableOAuthClientContext = [self.context mutableCopy];
        mutableOAuthClientContext.authInfo = info;
        mutableOAuthClientContext.authError = error;
        self.context = mutableOAuthClientContext;
        [self notifyDelegateOfFailure:error];
    }
}

- (BOOL)handleURLAuthenticationResponse:(NSURL *)appUrlResponse {
    [SFSDKCoreLogger d:[self class] format:@"handleAdvancedAuthenticationResponse called"];
    self.coordinator.credentials = self.context.credentials;
    if(self.config.loginHost) {
        self.coordinator.credentials.domain = self.config.loginHost;
    }
    [self.coordinator handleIDPAuthenticationResponse:appUrlResponse];
    return YES;
}

- (NSString *)encodeScopes {
    NSMutableSet *scopes = (self.config.scopes.count > 0 ? [NSMutableSet setWithSet:self.config.scopes] : [NSMutableSet set]);
    [scopes addObject:kSFRefreshTokenParam];
    NSString *scopeStr = [[[scopes allObjects] componentsJoinedByString:@","] stringByURLEncoding];
    return [NSString stringWithFormat:@"&%@=%@", kOAuthScopesKey, scopeStr];
}

- (NSSet<NSString *> *)decodeScopes:(NSString *)scopeString {
    
    NSArray<NSString *> *scopeArray = [scopeString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
    
    NSMutableSet *scopes = [NSMutableSet set];
    if (scopeArray && scopeArray.count > 0) {
        for (NSString * scope in scopeArray) {
            [scopes addObject:scope];
        }
    }
    [scopes addObject:kSFRefreshTokenParam];
    return scopes;
}

@end
