/*
 SFSDKIDPAuthClient.h
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

#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFSDKOAuthClient.h"
NS_ASSUME_NONNULL_BEGIN
@class SFSDKLoginFlowSelectionViewController;
@class SFSDKIDPAuthClient;
@class SFSDKAuthRequestCommand;
@class SFSDKIDPInitCommand;

@protocol SFSDKIDPAuthClientDelegate <NSObject>
/**
 Called when the Oauth Client requires Delegate to choose the login flow.
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClientDisplayIDPLoginFlowSelection:(SFSDKIDPAuthClient *)client;

@optional
/**
 Called when the Oauth Client is starting the auth process using IDP APP
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClient:(SFSDKIDPAuthClient *_Nonnull)client willSendRequestForIDPAuth:(NSDictionary *)options;

/**
 Called when the Oauth Client is starting the auth process using IDP APP
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClient:(SFSDKIDPAuthClient *_Nonnull)client didSendRequestForIDPAuth:(NSDictionary *)options;


/**
 Called when the Oauth Client is starting the auth process using IDP APP
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClient:(SFSDKIDPAuthClient *_Nonnull)client didReceiveRequestForIDPAuth:(NSURL *) request;


/**
 Called when the Oauth Client is starting the auth process using IDP APP
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClient:(SFSDKIDPAuthClient *_Nonnull)client error:(NSError *) error;

/**
 Called when the Oauth Client is starting the auth process using IDP APP
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClientDidFetchAuthCode:(SFSDKIDPAuthClient *_Nonnull)client;


/**
 Called when the Oauth Client is starting the auth process with an auth view.
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClient:(SFSDKIDPAuthClient *_Nonnull)client didReceiveResponseForIDPAuth:(NSDictionary *)options;

/**
 Called when the Oauth Client is starting the auth process with an auth view.
 @param client The instance of SFSDKOAuthClient making the call.
 */
- (void)authClient:(SFSDKIDPAuthClient *_Nonnull)client willSendResponseForIDPAuth:(NSDictionary *)options;

@end

@interface SFSDKIDPAuthClient : SFSDKOAuthClient

@property (nonatomic,copy,class) SFSDKLoginFlowSelectionViewController *loginFlowSelectionController;

@property (nonatomic, readonly) SFIDPUserSelectionBlock idpUserSelectionBlock;

@property (nonatomic, readonly) SFIDPLoginFlowSelectionBlock idpLoginFlowSelectionBlock;

- (void)setCallingAppOptionsInContext:(NSDictionary *)values;

- (void)launchSPAppWithError:(NSError *_Nullable)error reason:(NSString *_Nullable)reason;

- (void)continueIDPFlow:(SFOAuthCredentials *)userCredentials;

- (void)beginIDPFlow:(SFSDKAuthRequestCommand *)request;

- (void)beginIDPFlowForNewUser;

- (void)beginIDPInitiatedFlow:(SFSDKIDPInitCommand *)command;

- (void)initiateIDPFlowInSPApp;

- (BOOL)initiateLocalLoginInSPApp;

@end

NS_ASSUME_NONNULL_END
