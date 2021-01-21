/*
SFSDKIDPAuthHelper.m
SalesforceSDKCore

Created by Raj Rao on 10/20/19.

Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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


#import "SFSDKIDPAuthHelper.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFSDKAuthSession.h"
#import "SFSDKCryptoUtils.h"
#import "NSData+SFSDKUtils.h"
#import "SFSDKIDPConstants.h"
#import "SFSDKAuthRequest.h"
#import "SFSDKAuthRequestCommand.h"
#import "SFApplicationHelper.h"
#import "NSString+SFAdditions.h"
#import "SFSDKAuthResponseCommand.h"
#import "SFSDKWindowManager.h"
#import "SFSDKAuthErrorCommand.h"
#import "SFUserAccountManager.h"
@implementation SFSDKIDPAuthHelper

+ (void)invokeIDPApp:(SFSDKAuthSession *)session completion:(void (^)(BOOL))completionBlock {
    
    session.oauthCoordinator.codeVerifier = [[SFSDKCryptoUtils randomByteDataWithLength:kSFVerifierByteLength] msdkBase64UrlString];
     
    NSString *codeChallengeString = [[[session.oauthCoordinator.codeVerifier dataUsingEncoding:NSUTF8StringEncoding] msdkSha256Data] msdkBase64UrlString];

    SFSDKAuthRequestCommand *command = [[SFSDKAuthRequestCommand alloc] init];
    command.scheme = session.oauthRequest.idpAppURIScheme;
    command.spClientId = session.oauthCoordinator.credentials.clientId;
    command.spCodeChallenge = codeChallengeString;
    command.spAppScopes = [self encodeScopes:session.oauthRequest.scopes];
    command.spUserHint = session.oauthRequest.userHint;
    if (!session.oauthRequest.idpInitiatedAuth)
        command.spLoginHost = session.oauthCoordinator.credentials.domain;
    command.spRedirectURI = session.oauthCoordinator.credentials.redirectUri;
    command.spAppName = session.oauthRequest.appDisplayName;
    
    NSURL *url = [command requestURL];
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL launched  = [SFApplicationHelper openURL:url];
        completionBlock(launched);
    });
}

+ (NSString *)encodeScopes:(NSSet <NSString *> *)requestScopes {
    NSMutableSet *scopes = (requestScopes.count > 0 ? [NSMutableSet setWithSet:requestScopes] : [NSMutableSet set]);
    [scopes addObject:kSFRefreshTokenParam];
    NSString *scopeStr = [[[scopes allObjects] componentsJoinedByString:@","] stringByURLEncoding];
    return [NSString stringWithFormat:@"%@", scopeStr];
}

+ (NSSet<NSString *> *)decodeScopes:(NSString *)scopeString {
    
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

+ (void)invokeSPApp:(SFSDKAuthSession *)session completion:(void (^)(BOOL))completionBlock {
    
    SFSDKAuthResponseCommand *responseCommand = [[SFSDKAuthResponseCommand alloc] init];
   
    NSString *spAppRedirectUrl = session.oauthCoordinator.spAppCredentials.redirectUri;
    NSURL *spAppURL = [NSURL URLWithString:spAppRedirectUrl];
    responseCommand.scheme = spAppURL.scheme;
    responseCommand.authCode = session.oauthCoordinator.spAppCredentials.authCode;
    
    NSURL *url = [responseCommand requestURL];
   
    dispatch_async(dispatch_get_main_queue(), ^{
        SFSDKWindowContainer *authWindow = [[SFSDKWindowManager sharedManager] authWindow:nil];
        [authWindow.viewController.presentedViewController dismissViewControllerAnimated:YES  completion:^{
            [authWindow dismissWindow];
            [[[SFSDKWindowManager sharedManager] mainWindow:nil] presentWindow];
        }];
        BOOL launched  = [SFApplicationHelper openURL:url];
        completionBlock(launched);
    });
    
}

+ (void)invokeSPAppWithError:(SFOAuthCredentials *)spAppCredentials error:(NSError *)error reason:(NSString *)reason {
    
    NSString *spAppUrlStr = spAppCredentials.redirectUri;
    NSURL *spAppUrl = [NSURL URLWithString:spAppUrlStr];
    NSURL *url = [self appURLWithError:error reason:reason app:spAppUrl.scheme];
    dispatch_async(dispatch_get_main_queue(), ^{
        SFSDKWindowContainer *authWindow = [[SFSDKWindowManager sharedManager] authWindow:nil];
        [authWindow.viewController.presentedViewController dismissViewControllerAnimated:YES  completion:^{
            [authWindow dismissWindow];
            [[[SFSDKWindowManager sharedManager] mainWindow:nil] presentWindow];
        }];
        BOOL launched  = [SFApplicationHelper openURL:url];
        if (!launched) {
            [SFSDKCoreLogger e:[self class] format:@"Could not launch spAPP to handle error %@",[error description]];
        }
        [[SFUserAccountManager sharedInstance] stopCurrentAuthentication:^(BOOL result) {
            [SFSDKCoreLogger d:[self class] format:@"Completed idp authentication with error, %@",error];
        }];
    });
}

+ (NSURL *)appURLWithError:(NSError *)error reason:(NSString *)reason app:(NSString *)appScheme {

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
  
    return [command requestURL];
}


@end
