/*
 SFSDKAuthErrorManager.m
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

#import "SFSDKAuthErrorManager.h"
#import "SFAuthErrorHandlerList.h"
#import "SFAuthErrorHandler.h"
#import "SFOAuthCoordinator.h"
#include "SFOAuthInfo.h"
#include "SFSDKResourceUtils.h"
#include "SFUserAccountManager.h"
// Auth error handler name constants
static NSString * const kSFInvalidCredentialsAuthErrorHandler = @"InvalidCredentialsErrorHandler";
static NSString * const kSFConnectedAppVersionAuthErrorHandler = @"ConnectedAppVersionErrorHandler";
static NSString * const kSFNetworkFailureAuthErrorHandler = @"NetworkFailureErrorHandler";
static NSString * const kSFHostConnectionErrorHandler = @"HostConnectionErrorHandler";
static NSString * const kSFGenericFailureAuthErrorHandler = @"GenericFailureErrorHandler";

@interface SFSDKAuthErrorManager()
@property (nonatomic, strong) SFAuthErrorHandlerList *authErrorHandlerList;
@property (nonatomic, readwrite) SFAuthErrorHandler *invalidCredentialsAuthErrorHandler;
@property (nonatomic, readwrite) SFAuthErrorHandler *genericAuthErrorHandler;
@property (nonatomic, readwrite) SFAuthErrorHandler *networkFailureAuthErrorHandler;
@property (nonatomic, readwrite) SFAuthErrorHandler *connectedAppVersionAuthErrorHandler;
@property (nonatomic, readwrite) SFAuthErrorHandler *hostConnectionErrorHandler;
@end

@implementation SFSDKAuthErrorManager

- (instancetype) init {
    self = [super init];
    if (self) {
         _authErrorHandlerList = [self populateDefaultAuthErrorHandlerList];
    }
    return self;
}

- (SFAuthErrorHandlerList *)populateDefaultAuthErrorHandlerList
{
    __weak typeof(self) weakSelf = self;
    SFAuthErrorHandlerList *authHandlerList = [[SFAuthErrorHandlerList alloc] init];
    
    // Invalid credentials handler
    self.invalidCredentialsAuthErrorHandler = [[SFAuthErrorHandler alloc]
                                               initWithName:kSFInvalidCredentialsAuthErrorHandler
                                               evalOptionsBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo, NSDictionary *options) {
                                                   __strong typeof(weakSelf) strongSelf = weakSelf;
                                                   if ([[strongSelf class] errorIsInvalidAuthCredentials:error]) {
                                                       if (self.invalidAuthCredentialsErrorHandlerBlock) {
                                                           self.invalidAuthCredentialsErrorHandlerBlock(error, authInfo, options);
                                                           return YES;
                                                       }
                                                   }
                                                   return NO;
                                               }];
    [authHandlerList addAuthErrorHandler:self.invalidCredentialsAuthErrorHandler];
    
    // Connected app version mismatch handler
    
    self.connectedAppVersionAuthErrorHandler = [[SFAuthErrorHandler alloc]
                                                initWithName:kSFConnectedAppVersionAuthErrorHandler
                                                evalOptionsBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo, NSDictionary *options) {
                                                    if (error.code == kSFOAuthErrorWrongVersion) {
                                                        if (self.connectedAppVersionMismatchErrorHandlerBlock) {
                                                            self.connectedAppVersionMismatchErrorHandlerBlock(error, authInfo, options);
                                                            return YES;
                                                        }
                                                    }
                                                    return NO;
                                                }];
    [authHandlerList addAuthErrorHandler:self.connectedAppVersionAuthErrorHandler];
    
    // Network failure handler
    self.networkFailureAuthErrorHandler = [[SFAuthErrorHandler alloc]
                                           initWithName:kSFNetworkFailureAuthErrorHandler
                                           evalOptionsBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo, NSDictionary *options) {
                                               BOOL result = NO;
                                               if ([[weakSelf class] errorIsNetworkFailure:error]) {
                                                   if (authInfo.authType != SFOAuthTypeRefresh) {
                                                       [SFSDKCoreLogger e:[weakSelf class] format:@"Network failure for non-Refresh OAuth flow (%@) is a fatal error.", authInfo.authTypeDescription];
                                                   } else if ([SFUserAccountManager sharedInstance].currentUser.credentials.accessToken == nil) {
                                                       [SFSDKCoreLogger w:[weakSelf class] format:@"Network unreachable for access token refresh, and no access token is configured.  Cannot continue."];
                                                   } else {
                                                       [SFSDKCoreLogger i:[weakSelf class]  format:@"Network failure for OAuth Refresh flow (existing credentials)  Try to continue."];
                                                        if (self.networkErrorHandlerBlock) {
                                                            self.networkErrorHandlerBlock(error, authInfo, options);
                                                            result = YES;
                                                        }
                                                   }
                                               }
                                               return result;
                                           }];
    [authHandlerList addAuthErrorHandler:self.networkFailureAuthErrorHandler];
    
    // Generic failure handler
    self.hostConnectionErrorHandler = [[SFAuthErrorHandler alloc]
                                    initWithName:kSFHostConnectionErrorHandler
                                    evalOptionsBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo, NSDictionary *options) {
                                        if (error.userInfo[@"_kCFStreamErrorCodeKey"] && error.userInfo[@"_kCFStreamErrorDomainKey"] ) {
                                            if (self.hostConnectionErrorHandlerBlock) {
                                                self.hostConnectionErrorHandlerBlock(error, authInfo, options);
                                                 return YES;
                                            }
                                        }
                                        return NO;
                                    }];
    
    [authHandlerList addAuthErrorHandler:self.hostConnectionErrorHandler];
    // Generic failure handler
    self.genericAuthErrorHandler = [[SFAuthErrorHandler alloc]
                                    initWithName:kSFGenericFailureAuthErrorHandler
                                    evalOptionsBlock:^BOOL(NSError *error, SFOAuthInfo *authInfo, NSDictionary *options) {
                                        if (self.genericErrorHandlerBlock) {
                                            self.genericErrorHandlerBlock(error, authInfo, options);
                                            return YES;
                                        }
                                        return NO;
                                    }];
    [authHandlerList addAuthErrorHandler:self.genericAuthErrorHandler];
    return authHandlerList;
}

- (BOOL)processAuthError:(NSError *)error authInfo:(SFOAuthInfo *)info options:(NSDictionary *)options
{
    NSInteger i = 0;
    BOOL errorHandled = NO;
    NSArray *authHandlerArray = self.authErrorHandlerList.authHandlerArray;
    while (i < [authHandlerArray count] && !errorHandled) {
        SFAuthErrorHandler *currentHandler = (self.authErrorHandlerList.authHandlerArray)[i];
        errorHandled = currentHandler.evalOptionsBlock(error, info,options);
        i++;
    }
    return errorHandled;
}

+ (BOOL)errorIsInvalidAuthCredentials:(NSError *)error
{
    BOOL errorIsInvalidCreds = NO;
    if (error.domain == kSFOAuthErrorDomain) {
        if (error.code == kSFOAuthErrorInvalidGrant) {
            errorIsInvalidCreds = YES;
        }
    }
    return errorIsInvalidCreds;
}

/**
 * Evaluates an NSError object to see if it represents a network failure during
 * an attempted connection.
 * @param error The NSError to evaluate.
 * @return YES if the error represents a network failure, NO otherwise.
 */
+ (BOOL)errorIsNetworkFailure:(NSError *)error
{
    BOOL isNetworkFailure = NO;
    
    if (error == nil || error.domain == nil)
        return isNetworkFailure;
    
    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        switch (error.code) {
            case NSURLErrorTimedOut:
            case NSURLErrorCannotConnectToHost:
            case NSURLErrorNetworkConnectionLost:
            case NSURLErrorNotConnectedToInternet:
            case NSURLErrorInternationalRoamingOff:
                isNetworkFailure = YES;
                break;
            default:
                break;
        }
    } else if ([error.domain isEqualToString:kSFOAuthErrorDomain]) {
        switch (error.code) {
            case kSFOAuthErrorTimeout:
                isNetworkFailure = YES;
                break;
            default:
                break;
        }
    }
    
    return isNetworkFailure;
}

@end
