/*
 SFSDKAuthErrorManager.h
 SalesforceSDKCore
 
 Created by Raj Rao on 10/01/17.
 
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
@class SFAuthErrorHandler;
@class SFAuthErrorHandlerList;
@class SFOAuthInfo;
NS_ASSUME_NONNULL_BEGIN

typedef void (^SFSDKFailureNotificationBlock)(void);
typedef void (^SFSDKErrorHandlerBlock)(NSError *error,SFOAuthInfo *authInfo,NSDictionary *options);

@interface SFSDKAuthErrorManager : NSObject

@property (nonatomic,copy) SFSDKErrorHandlerBlock networkErrorHandlerBlock;

@property (nonatomic,copy) SFSDKErrorHandlerBlock connectedAppVersionMismatchErrorHandlerBlock;

@property (nonatomic,copy) SFSDKErrorHandlerBlock invalidAuthCredentialsErrorHandlerBlock;

@property (nonatomic,copy) SFSDKErrorHandlerBlock hostConnectionErrorHandlerBlock;

@property (nonatomic,copy) SFSDKErrorHandlerBlock genericErrorHandlerBlock;

/**
 Determines whether an error is due to invalid auth credentials.
 @param error The error to process.
 @param info  type of auth.
 @param options addl. execution context related params
 @return YES if the error is handled, NO otherwise.
 */
- (BOOL)processAuthError:(NSError *)error authInfo:(SFOAuthInfo *)info options:(NSDictionary *)options;

/**
 Determines whether an error is due to invalid auth credentials.
 @param error The error to check against an invalid credentials error.
 @return YES if the error is due to invalid credentials, NO otherwise.
 */
+ (BOOL)errorIsInvalidAuthCredentials:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
