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
#import "SFSDKIDPAuthClient.h"
#import "SFSDKOAuthClientConfig.h"
#import "SFSDKLoginFlowSelectionViewController.h"
#import "SFSDKUserSelectionNavViewController.h"
#import "SFOAuthCoordinator+Internal.h"

static NSUInteger const kSFVerifierByteLength          = 128;
static NSString * const kSFVerifierParamName           = @"code_verifier";
static NSString * const kSFChallengeParamName          = @"code_challenge";

@interface SFSDKIDPAuthClient()<SFSDKLoginFlowSelectionViewDelegate>

@property (nonatomic, strong) SFSDKOAuthClientContext *context;
- (SFIDPLoginFlowSelectionCreationBlock)idpLoginFlowSelectionBlock;
- (NSURL *)idpAppURLWithError:(NSError *)error reason:(NSString *)reason;
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

- (SFIDPLoginFlowSelectionCreationBlock)idpLoginFlowSelectionBlock {
    if (!self.config.idpLoginFlowSelectionBlock) {
        return ^SFSDKLoginFlowSelectionViewController * {
            SFSDKLoginFlowSelectionViewController *controller = [[SFSDKLoginFlowSelectionViewController alloc] initWithNibName:nil bundle:nil];
            controller.selectionFlowDelegate = self;
            return controller;

        };
    }
    return self.config.idpLoginFlowSelectionBlock;
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
    
    if (self.config.isIdentityProvider) {
        return [super refreshCredentials];
    }
    
    if (self.credentials.accessToken==nil) {
        if (self.context.userHint==nil) {
            self.authWindow.viewController = self.idpLoginFlowSelectionBlock();
            [self.authWindow enable:YES withCompletion:nil];
        } else {
            [self launchIDPApp];
        }
    } else {
        [super refreshCredentials];
    }

    return YES;
}

- (void)launchSPAppWithError:(NSError *)error reason:(NSString *)reason {
    
    NSURL *url = [self spAppURLWithError:error reason:reason];
    [self.authWindow disable];
    [[SFSDKWindowManager sharedManager].mainWindow enable];
    BOOL launched  = [SFApplicationHelper openURL:url];
    if (launched) {
        if ( [self.config.idpDelegate respondsToSelector:@selector(authClient:didSendRequestForIDPAuth:)]) {
            [self.config.idpDelegate authClient:self didSendRequestForIDPAuth:url];
        }
    }
    
}

#pragma mark - private

- (void)launchIDPApp {
    
//    if (self.context.userHint!=nil && self.config.isIDPInitiatedFlow) {
//        SFUserAccountIdentity *identity = [[SFUserAccountManager sharedInstance] decodeUserIdentity:self.context.userHint];
//        
//        SFUserAccount *userAccount = [[SFUserAccountManager sharedInstance] userAccountForUserIdentity:identity];
//        
//        if (userAccount != nil && userAccount.credentials.accessToken!=nil) {
//            [super refreshCredentials:userAccount.credentials];
//            return;
//        }
//    }
//        } else {
//            // show an alert for the swizzle back to IDP
//            //[self showAlertMessage:];
//            __weak typeof (self) weakSelf = self;
//            [self showAlertMessage:@"There were no local accounts, Will request initial Authorization from the IDP APP" withSuccess:^{
//                __strong typeof (weakSelf) strongSelf = weakSelf;
//                [strongSelf invokeIDPApp];
//            } failure:^{
//                __strong typeof (weakSelf) strongSelf = weakSelf;
//                NSURL *url = [strongSelf idpAppURLWithError:nil reason:@"User Cancelled Authentication"];
//                [SFApplicationHelper openURL:url];
//            }];
//        }
   // } else {
      __weak typeof (self) weakSelf = self;
      dispatch_async(dispatch_get_main_queue(), ^{
          [weakSelf invokeIDPApp];
      });
            
        
   // }
    
}

- (void) invokeIDPApp {
    
    NSURL *url = [self identityProviderURLRequest];
   
    if ( [self.config.idpDelegate respondsToSelector:@selector(authClient:willSendRequestForIDPAuth:)]) {
        [self.config.idpDelegate authClient:self willSendRequestForIDPAuth:url];
    }
    BOOL launched  = [SFApplicationHelper openURL:url];
    if (launched) {
        if ( [self.config.idpDelegate respondsToSelector:@selector(authClient:didSendRequestForIDPAuth:)]) {
            [self.config.idpDelegate authClient:self willSendRequestForIDPAuth:url];
        }
    }
 
}

- (void)launchSPApp {
    NSURL *url = [self spAppURL:self.coordinator.spAppCredentials.authCode];
    if ( [self.config.idpDelegate respondsToSelector:@selector(authClient:willSendResponseForIDPAuth:)]) {
        [self.config.idpDelegate authClient:self willSendResponseForIDPAuth:url];
    }
    
    [self.authWindow disable];
    [[SFSDKWindowManager sharedManager].mainWindow enable];
    BOOL launched  = [SFApplicationHelper openURL:url];
    if (launched) {
        if ( [self.config.idpDelegate respondsToSelector:@selector(authClient:didSendRequestForIDPAuth:)]) {
            [self.config.idpDelegate authClient:self didSendRequestForIDPAuth:url];
        }
    }
    
}

- (NSURL *)identityProviderURLRequest{
    
    self.coordinator.codeVerifier = [[SFSDKCryptoUtils randomByteDataWithLength:kSFVerifierByteLength] msdkBase64UrlString];
   
    NSString *codeChallengeString = [[[self.coordinator.codeVerifier dataUsingEncoding:NSUTF8StringEncoding] msdkSha256Data] msdkBase64UrlString];
    
    if (!self.config.idpAppUrl) return nil;

    NSString *clientId = self.config.oauthClientId;
    
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:self.config.idpAppUrl];

    NSURLComponents *callingAppComponents = [[NSURLComponents alloc] initWithString:self.config.oauthCompletionUrl];

    components.queryItems = @[
                              [[NSURLQueryItem alloc] initWithName:kOAuthClientIdKey value:clientId],
                              [[NSURLQueryItem alloc] initWithName:kOAuthScopesKey
                                                             value:[self encodeScopes]],
                              [[NSURLQueryItem alloc] initWithName:kSFVerifierParamName
                                                             value:codeChallengeString],
                              [[NSURLQueryItem alloc] initWithName:kOAuthRedirectUriKey
                                                             value:callingAppComponents.URL.absoluteString],
                              [[NSURLQueryItem alloc] initWithName:@"state" value:self.credentials.identifier],
                              [[NSURLQueryItem alloc] initWithName:@"app_name" value:self.config.appDisplayName],
                              [[NSURLQueryItem alloc] initWithName:@"user_hint" value:self.context.userHint],
                              [[NSURLQueryItem alloc] initWithName:@"login_host" value:self.config.loginHost]
                              ];
    return  components.URL;
}


- (NSURL *)spAppURL:(NSString *)code {
    
    SFOAuthCredentials *spAppCredentials = [self credentialsFromURLForSPAPP:self.context.callingAppRequestURL];

    NSString *urlString = [NSString stringWithFormat:@"%@?%@=%@&%@=%@",spAppCredentials.redirectUri,@"code",code,@"state",self.config.callingAppState];
    
    return [NSURL URLWithString:urlString];
}

- (NSURL *)spAppURLWithError:(NSError *)error reason:(NSString *)reason {
    
    SFOAuthCredentials *spAppCredentials = [self credentialsFromURLForSPAPP:self.context.callingAppRequestURL];
    NSString *errorCode = error?[NSString stringWithFormat:@"%d",error.domain.intValue]:@"-999";
    NSString *errorDesc = @"";

    if (error)
        errorDesc = [[error localizedDescription] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
    
    if (!reason)
        reason = errorDesc;

    reason = [reason stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
    
    NSString *urlString =
                          [NSString stringWithFormat:@"%@?%@=%@&%@=%@&%@=%@&%@=%@",
                           spAppCredentials.redirectUri,
                           @"errorReason",reason,
                           @"errorCode",errorCode,
                           @"errorDescription",errorDesc,
                           @"state",self.config.callingAppState];
    
    return [NSURL URLWithString:urlString];
}


- (NSURL *)idpAppURLWithError:(NSError *)error reason:(NSString *)reason {
    
//    SFOAuthCredentials *spAppCredentials = [SFSDKIDPAuthClient credentialsFromURL:[SFSDKAuthPreferences id] identifier:@"someid"];
    NSString *appUri  = self.config.idpAppUrl;
    NSString *errorCode = error?[NSString stringWithFormat:@"%d",error.domain.intValue]:@"-999";
    NSString *errorDesc = @"";
    
    
    if (error)
        errorDesc = [[error localizedDescription] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
    
    if (!reason)
        reason = errorDesc;
    reason = [reason stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
    
    NSString *urlString = [NSString stringWithFormat:@"%@?%@=%@&%@=%@&%@=%@&%@=%@",
                                                     appUri,
                                                     @"errorReason",reason,
                                                     @"errorCode",errorCode,
                                                     @"errorDescription",errorDesc,
                                                     @"state",self.config.callingAppState];
    
    return [NSURL URLWithString:urlString];
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


#pragma mark - SFSDKLoginFlowSelectionViewControllerDelegate
-(void)loginFlowSelectionIDPSelected:(SFSDKLoginFlowSelectionViewController *)controller {
    [self launchIDPApp];
}

-(void)loginFlowSelectionLocalLoginSelected:(SFSDKLoginFlowSelectionViewController *)controller {
    [super refreshCredentials];
}

-(void)loginFlowSelectionCancelSelected:(SFSDKLoginFlowSelectionViewController *)controller {
    [super cancelAuthentication];
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
    self.context = mutableContext;
    self.coordinator.credentials = userCredentials;

    SFOAuthCredentials *spAppCredentials = [self credentialsFromURLForIDPApp:self.context.callingAppRequestURL];
    
    self.coordinator.credentials = mutableContext.credentials;
    [self.coordinator beginIDPFlow:spAppCredentials];
}



- (SFOAuthCredentials *)credentialsFromURLForIDPApp:(NSURL *)appUrlRequest {

    NSString *clientId = [appUrlRequest valueForParameterName:kOAuthClientIdKey];
    NSString *redirectUri = [appUrlRequest valueForParameterName:kOAuthRedirectUriKey];
    NSString *verifier = [appUrlRequest valueForParameterName:kSFVerifierParamName];
    NSString *scopeString = [appUrlRequest valueForParameterName:kOAuthScopesKey];
    NSString *loginHost = [appUrlRequest valueForParameterName:kSFUserAccountOAuthLoginHost];
    
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:clientId clientId:clientId encrypted:NO];
    creds.redirectUri = redirectUri;
    creds.accessToken = nil;
    creds.clientId = clientId;
    creds.domain = loginHost;
    creds.accessToken = nil;
    creds.challengeString = verifier;
    self.config.loginHost = loginHost;
    self.config.scopes = [self decodeScopes:scopeString];

    return creds;
}


- (SFOAuthCredentials *)credentialsFromURLForSPAPP:(NSURL *)appUrlRequest {

    NSString *clientId = [appUrlRequest valueForParameterName:kOAuthClientIdKey];
    NSString *redirectUri = [appUrlRequest valueForParameterName:kOAuthRedirectUriKey];
    NSString *verifier = [appUrlRequest valueForParameterName:kSFVerifierParamName];

    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:clientId clientId:clientId encrypted:NO];
    creds.redirectUri = redirectUri;
    creds.accessToken = nil;
    creds.clientId = clientId;
    creds.domain = self.config.loginHost;
    creds.accessToken = nil;
    creds.challengeString = verifier;
    return creds;
}


- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info {

    [SFSDKCoreLogger d:[self class] format:@"oauthCoordinator:didFailWithError: %@, authInfo: %@", error, self.context.authInfo];
    if (self.config.callingAppState!=nil) {
        [self launchSPAppWithError:error reason:nil];
    }else {
        SFSDKMutableOAuthClientContext *mutableOAuthClientContext = [self.context mutableCopy];
        mutableOAuthClientContext.authInfo = info;
        mutableOAuthClientContext.authError = error;
        self.context = mutableOAuthClientContext;
        [super processAuthError:error];
    }
  
}

- (BOOL)handleURLAuthenticationResponse:(NSURL *)appUrlResponse {
    
    [SFSDKCoreLogger i:[self class] format:@"handleAdvancedAuthenticationResponse"];
    self.coordinator.credentials = self.context.credentials;
    [self.coordinator handleIDPAuthenticationResponse:appUrlResponse];
    return YES;
}

- (NSString *)encodeScopes {
    NSMutableSet *scopes = (self.config.scopes.count > 0 ? [NSMutableSet setWithSet:self.config.scopes] : [NSMutableSet set]);
    [scopes addObject:@"refresh_token"];
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
    [scopes addObject:@"refresh_token"];
    return scopes;
}

@end
