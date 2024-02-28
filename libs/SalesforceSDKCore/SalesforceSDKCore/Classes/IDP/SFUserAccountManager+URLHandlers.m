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
#import "SFSDKWindowManager+Internal.h"
#import "SFUserAccountManager+URLHandlers.h"
#import "SFSDKSPLoginRequestCommand.h"
#import "SFSDKIDPConstants.h"
#import "SFSDKSPLoginResponseCommand.h"
#import "SFSDKAuthErrorCommand.h"
#import "SFSDKIDPLoginRequestCommand.h"
#import "SFSDKIDPAuthCodeLoginRequestCommand.h"
#import "SFSDKAlertMessage.h"
#import "SFSDKAlertMessageBuilder.h"
#import "SFSDKStartURLHandler.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFSDKUserSelectionView.h"
#import "SFSDKLoginFlowSelectionView.h"
#import "SFSDKLoginFlowSelectionViewController.h"
#import "SFSDKAuthRequest.h"

@implementation SFUserAccountManager (URLHandlers)

- (BOOL)handleIdpAuthError:(SFSDKAuthErrorCommand *)command {
    SFSDKAlertMessage *messageObject = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder) {
        builder.actionOneTitle = [SFSDKResourceUtils localizedString:@"authAlertOkButton"];
        builder.alertTitle = @"Authentication Failed";
        builder.alertMessage = command.errorReason;
    }];
   
    dispatch_async(dispatch_get_main_queue(), ^{
        self.alertDisplayBlock(messageObject, [[SFSDKWindowManager sharedManager] authWindow:nil]);
        [self stopCurrentAuthentication:nil];
    });
    return YES;
}

- (BOOL)handleIdpInitiatedAuth:(SFSDKIDPLoginRequestCommand *)command {
    
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
    
    SFSDKAuthRequest *request = [self defaultAuthRequest];
    request.userHint = userHint;
    request.idpInitiatedAuth = YES;
    [self authenticateUsingIDP:request completion:^(SFOAuthInfo *authInfo, SFUserAccount *user) {
        
    } failure:^(SFOAuthInfo *authInfo, NSError *error) {
        
    }];
    return YES;
}

- (BOOL)handleAuthRequestFromSPApp:(SFSDKSPLoginRequestCommand *)request {
    NSString *userHint = request.spUserHint;
    [SFSDKCoreLogger d:[self class] format:@"handleAuthRequestFromSPApp for %@", [request.allParams description]];
    
    NSDictionary *userInfo = @{kSFUserInfoAddlOptionsKey : request.allParams};
    [[NSNotificationCenter defaultCenter]  postNotificationName:kSFNotificationUserDidReceiveIDPRequest
                                                         object:self
                                                       userInfo:userInfo];
    
    if (userHint) {
        SFUserAccountIdentity *identity = [self decodeUserIdentity:userHint];
        SFUserAccount *userAccount = [self userAccountForUserIdentity:identity];
        if (userAccount.credentials.accessToken != nil) {
            [SFSDKCoreLogger d:[self class] format:@"handleAuthRequestFromSPApp userAccount found for userHint"];
        }
        [self selectedUser:userAccount spAppContext:request.allParams];
        return YES;
    }
    
    BOOL showSelection = NO;
    NSString *domain = request.allParams[kSFLoginHostParam]?:self.loginHost;
    
    if (self.currentUser != nil) {
        NSArray *domainUsers = [self userAccountsForDomain:domain];
        showSelection = ([domainUsers count] > 0);
    }

    if (showSelection) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController<SFSDKUserSelectionView> *controller = self.idpUserSelectionAction();
            controller.spAppOptions = request.allParams;
            controller.userSelectionDelegate = self;
            controller.modalPresentationStyle = UIModalPresentationFullScreen;
            SFSDKWindowContainer *authWindow = [[SFSDKWindowManager sharedManager] authWindow:nil];
            [authWindow presentWindowAnimated:NO withCompletion:^{
                [authWindow.viewController presentViewController:controller animated:NO completion:nil];
           }];
        });
    } else {
        [self createNewUser:request.allParams];
    }
    return YES;
}

- (BOOL)handleIdpResponse:(SFSDKSPLoginResponseCommand *)response sceneId:(NSString *)sceneId {
    if (!sceneId) {
        sceneId = [[SFSDKWindowManager sharedManager] defaultScene].session.persistentIdentifier;
    }
    if (self.authSessions[sceneId]) {
        [self.authSessions[sceneId].oauthCoordinator handleIDPAuthenticationResponse:[response requestURL]];
    } else {
        SFSDKAlertMessage *messageObject = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder) {
            builder.actionOneTitle = [SFSDKResourceUtils localizedString:@"authAlertCancelButton"];
            builder.alertTitle = @"Authentication Failed";
            builder.alertMessage = @"Authentication session for sp app was evicted. Try again." ;
         }];
        
         dispatch_async(dispatch_get_main_queue(), ^{
             self.alertDisplayBlock(messageObject, [[SFSDKWindowManager sharedManager] authWindow:self.authSessions[sceneId].oauthRequest.scene]);
         });
    }
    return YES;
}

- (BOOL)handleIdpRequest:(SFSDKIDPAuthCodeLoginRequestCommand *_Nonnull)response sceneId:(nullable NSString *)sceneId completion:(nullable SFUserAccountManagerSuccessCallbackBlock)completionBlock
                 failure:(nullable SFUserAccountManagerFailureCallbackBlock)failureBlock {
    [SFSDKCoreLogger d:[self class] format:@"handleIdpRequest for %@", [response.allParams description]];


    if (!sceneId) {
        sceneId = [[SFSDKWindowManager sharedManager] defaultScene].session.persistentIdentifier;
    }
    
    if (self.authSessions[sceneId]) {
           [self.authSessions[sceneId].oauthCoordinator handleIDPAuthenticationResponse:[response requestURL]];
    } else if (response.keychainReference) {
        // IDP - SP: Need to create auth session
        NSString *userHint = response.userHint;
        if (userHint) {
            SFUserAccountIdentity *identity = [self decodeUserIdentity:userHint];
            SFUserAccount *userAccount = [self userAccountForUserIdentity:identity];
            if (userAccount.credentials.accessToken != nil) {
                // We already have that user - let's select it and discard the code
                [SFSDKCoreLogger d:[self class] format:@"handleIdpRequest userAccount found for userHint"];
                [self switchToUser:userAccount];
                SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeIDP];
                completionBlock(authInfo, userAccount);
                return YES;
            }
        }
        // We don't have that user - let's create a auth session to login using the code
        SFSDKAuthRequest *request = [self defaultAuthRequest];
        request.idpInitiatedAuth = YES;
        SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
        authSession.authFailureCallback = failureBlock;
        authSession.authSuccessCallback = completionBlock;
        self.authSessions[sceneId] = authSession;
        [self.authSessions[sceneId].oauthCoordinator handleIDPAuthenticationResponse:[response requestURL]];
        authSession.isAuthenticating = YES;
        authSession.oauthCoordinator.delegate = self;
    }
    return YES;
}

@end
