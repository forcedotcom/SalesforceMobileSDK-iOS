/*
 SFSDKOAuthClientContext.h
 SalesforceSDKCore
 
 Created by Raj Rao on 7/25/17.
 
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

#import <Foundation/Foundation.h>
#import "SFOAuthCoordinator.h"

NS_ASSUME_NONNULL_BEGIN

@class SFOAuthCoordinator;
@class SFIdentityCoordinator;
@class SFOAuthInfo;
@class SFUserAccount;
@class SFSDKOAuthClientContext;
@class SFSDKOAuthClient;
@class SFAuthErrorHandlerList;
@class SFAuthErrorHandler;
@class SFSDKOAuthViewHandler;
@class SFSDKMutableOAuthClientContext;
@protocol SFSDKOAuthClientDelegate;
@protocol SFSDKOAuthClientWebViewDelegate;
@protocol SFSDKOAuthClientSafariViewDelegate;

/**
 Callback block definition for OAuth completion callback.
 */
typedef void (^SFAuthenticationSuccessCallbackBlock)(SFOAuthInfo *, SFUserAccount *);

/**
 Callback block definition for OAuth failure callback.
 */
typedef void (^SFAuthenticationFailureCallbackBlock)(SFOAuthInfo *, NSError *);


/**
 Callback block definition for Identity retrieval success callback.
 */
typedef void (^SFIdentitySuccessCallbackBlock)(SFSDKOAuthClient *client);
/**
 Callback block definition for Identity retrieval failure callback.
 */
typedef void (^SFIdentityFailureCallbackBlock)(SFSDKOAuthClient *,NSError *);

/** Object representing state of a current authentication context. Provides a means to isolate individual authentication requests
 */
@interface SFSDKOAuthClientContext : NSObject

@property (nonatomic, strong, readonly) SFOAuthCredentials *credentials;
@property (nonatomic, strong, readonly) SFOAuthInfo *authInfo;
@property (nonatomic, strong, readonly) NSError *authError;

- (SFSDKMutableOAuthClientContext *)mutableCopy;

@end

@interface SFSDKMutableOAuthClientContext : SFSDKOAuthClientContext
@property (nonatomic, weak,readwrite,nullable) SFOAuthCredentials *credentials;
@property (nonatomic, strong, readwrite,nullable) SFOAuthInfo *authInfo;
@property (nonatomic, strong, readwrite,nullable) NSError *authError;
@end

NS_ASSUME_NONNULL_END
