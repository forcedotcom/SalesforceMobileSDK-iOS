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
#import "SFSDKOAuthClientCache.h"
#import "SFSDKAuthRequestCommand.h"
#import "SFSDKIDPConstants.h"
#import "SFSDKAuthResponseCommand.h"
#import "SFSDKAuthErrorCommand.h"
#import "SFSDKIDPInitCommand.h"
#import "SFSDKAlertMessage.h"
#import "SFSDKAlertMessageBuilder.h"
#import "SFSDKStartURLHandler.h"
@implementation SFUserAccountManager (URLHandlers)

- (BOOL)handleNativeAuthResponse:(NSURL *_Nonnull)appUrlResponse options:(NSDictionary *_Nullable)options {
    //should return the shared instance for advanced auth
    [SFSDKCoreLogger d:[self class] format:@"handle handleNativeAuthResponse for %@", appUrlResponse];
    NSString *state = [appUrlResponse valueForParameterName:kSFStateParam];
    NSString *key = [SFSDKOAuthClientCache keyFromIdentifierPrefixWithType:state type:SFOAuthClientKeyTypeAdvanced];
    SFSDKOAuthClient *client = [[SFSDKOAuthClientCache sharedInstance] clientForKey:key];
    return [client handleURLAuthenticationResponse:appUrlResponse];
    
}

- (BOOL)handleIdpAuthError:(SFSDKAuthErrorCommand *)command {

    NSString *param = command.state;
    NSString *key = [SFSDKOAuthClientCache keyFromIdentifierPrefixWithType:param type:SFOAuthClientKeyTypeIDP];
    SFSDKOAuthClient *client = [[SFSDKOAuthClientCache sharedInstance] clientForKey:key];
    SFOAuthCredentials *creds = nil;
    [SFSDKCoreLogger e:[self class] format:@"handleIdpAuthError for %@", [command.allParams description]];
    if (!client) {
        creds = [self newClientCredentials];
        client = [self fetchOAuthClient:creds completion:nil failure:nil];
        
    }
    SFSDKAlertMessage *messageObject = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder) {
        builder.actionOneTitle = [SFSDKResourceUtils localizedString:@"authAlertOkButton"];
        builder.alertTitle = @"";
        builder.alertMessage = command.errorReason;
    }];
   
    dispatch_async(dispatch_get_main_queue(), ^{
        self.alertDisplayBlock(messageObject,client.authWindow);
    });
    
    return YES;
}

- (BOOL)handleIdpInitiatedAuth:(SFSDKIDPInitCommand *)command {
    
    NSString *userHint = command.userHint;
    [SFSDKCoreLogger d:[self class] format:@"handle handleIdpInitiatedAuth for %@", [command.allParams description]];
    if (userHint) {
        SFUserAccountIdentity *identity = [self decodeUserIdentity:userHint];
        SFUserAccount *userAccount = [self userAccountForUserIdentity:identity];
        if (userAccount) {
            [self switchToUser:userAccount];
            if (command.startURL) {
                [SFSDKCoreLogger d:[self class] format:@"Attempting to launch %@", command.startURL];
                SFSDKStartURLHandler *handler = [[SFSDKStartURLHandler alloc] init];
                [handler processRequest:[NSURL URLWithString:command.startURL]  options:nil];
            }
            return YES;
        }
    }
    SFOAuthCredentials *creds = [[SFUserAccountManager sharedInstance] newClientCredentials];
    SFSDKIDPAuthClient *client = [self fetchIDPAuthClient:creds completion:nil failure:nil];
    client.config.isIDPInitiatedFlow = YES;
    if (command.domain) {
        client.config.loginHost = command.domain;
    }
    [client beginIDPInitiatedFlow:command];
    return YES;
}

- (BOOL)handleIdpRequest:(SFSDKAuthRequestCommand *)request
{
    SFOAuthCredentials *idpAppsCredentials = [self newClientCredentials];
    NSString *userHint = request.spUserHint;
    SFOAuthCredentials *foundUserCredentials = nil;
    [SFSDKCoreLogger d:[self class] format:@"handleIdpRequest for %@", [request.allParams description]];
    if (userHint) {
        SFUserAccountIdentity *identity = [self decodeUserIdentity:userHint];
        SFUserAccount *userAccount = [self userAccountForUserIdentity:identity];
        if (userAccount.credentials.accessToken!=nil) {
            [SFSDKCoreLogger d:[self class] format:@"handleIdpRequest userAccount found for userHint"];
            foundUserCredentials = userAccount.credentials;
        }
    }
    
    NSDictionary *userInfo = @{kSFUserInfoAddlOptionsKey : request.allParams};
    [[NSNotificationCenter defaultCenter]  postNotificationName:kSFNotificationUserDidReceiveIDPRequest
                                                         object:self
                                                       userInfo:userInfo];
    SFSDKIDPAuthClient  *authClient = nil;
    BOOL showSelection = NO;
    NSString *domain = request.allParams[kSFLoginHostParam]?:idpAppsCredentials.domain;
    SFOAuthCredentials *credentials = foundUserCredentials?:idpAppsCredentials;
    authClient = [self fetchIDPAuthClient:credentials completion:nil failure:nil];
    authClient.config.loginHost = domain;
    if (self.currentUser!=nil && !foundUserCredentials) {
        NSArray *domainUsers = [self userAccountsForDomain:request.spLoginHost];
        showSelection = ([domainUsers count] > 0);
    }

    if (showSelection) {
        [SFSDKCoreLogger d:[self class] format:@"handleIdpRequest userAccount will show user selection"];
        UIViewController<SFSDKUserSelectionView> *controller  = authClient.idpUserSelectionBlock();
        controller.spAppOptions = request.allParams;
        controller.userSelectionDelegate = self;
        [authClient.authWindow presentWindowAnimated:NO withCompletion:^{
            [authClient.authWindow.viewController presentViewController:controller animated:NO  completion:nil];
        }];
    } else {
        [authClient setCallingAppOptionsInContext:request.allParams];
        [authClient beginIDPFlow:request]; 
    }
    return YES;
}

- (BOOL)handleIdpResponse:(SFSDKAuthResponseCommand *)response
{
    NSString *key = [SFSDKOAuthClientCache keyFromIdentifierPrefixWithType:response.state type:SFOAuthClientKeyTypeIDP];
    SFSDKOAuthClient *client =  [[SFSDKOAuthClientCache sharedInstance] clientForKey:key];
    [SFSDKCoreLogger d:[self class] format:@"handleIdpResponse did receive reponse %@", [response.allParams description]];
    if (response.domain)
        client.credentials.domain = response.domain;
    
    NSDictionary *userInfo = @{
                               kSFNotificationUserInfoCredentialsKey : client.credentials,
                               kSFUserInfoAddlOptionsKey : response.allParams
                                };
    [[NSNotificationCenter defaultCenter]  postNotificationName:kSFNotificationUserDidReceiveIDPResponse
                                                         object:self
                                                       userInfo:userInfo];
    
    return [client handleURLAuthenticationResponse:[response requestURL]];
}

@end
