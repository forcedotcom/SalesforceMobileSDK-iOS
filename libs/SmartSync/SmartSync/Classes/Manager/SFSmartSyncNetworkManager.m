/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFSmartSyncNetworkManager.h"
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFUserAccount.h>
#import <SalesforceNetworkSDK/SFNetworkEngine.h>
#import <SalesforceNetworkSDK/SFNetworkUtils.h>

@interface SFSmartSyncNetworkManager () <SFAuthenticationManagerDelegate>

@property (nonatomic, strong) SFUserAccount *user;
@property (nonatomic, strong) NSURL *serverRootUrl;

@end

@implementation SFSmartSyncNetworkManager

#pragma mark - SFSmartSyncNetworkManager

static NSMutableDictionary *networkMgrList = nil;

+ (id)sharedInstance:(SFUserAccount *)user {
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        networkMgrList = [[NSMutableDictionary alloc] init];
	});
    @synchronized([SFSmartSyncNetworkManager class]) {
        if (user) {
            NSString *key = SFKeyForUserAndScope(user, SFUserAccountScopeCommunity);
            id networkMgr = [networkMgrList objectForKey:key];
            if (!networkMgr) {
                networkMgr = [[SFSmartSyncNetworkManager alloc] initWithUser:user];
                [networkMgrList setObject:networkMgr forKey:key];
            }
            return networkMgr;
        } else {
            return nil;
        }
    }
}

+ (void)removeSharedInstance:(SFUserAccount*)user {
    @synchronized([SFSmartSyncNetworkManager class]) {
        if (user) {
            NSString *key = SFKeyForUserAndScope(user, SFUserAccountScopeCommunity);
            [networkMgrList removeObjectForKey:key];
        }
    }
}

- (id)initWithUser:(SFUserAccount *)user {
    self = [super init];
    if (self) {
        self.user = user;
        [[SFAuthenticationManager sharedManager] addDelegate:self];
    }
    return self;
}

- (void)dealloc {
    [[SFAuthenticationManager sharedManager] removeDelegate:self];
}

- (NSString *)accessToken {
    return [self.user credentials].accessToken;
}

- (BOOL)isNetworkError:(NSError *)error {
    SFNetworkOperationErrorType typeOfError = [SFNetworkUtils typeOfError:error];
    return (typeOfError == SFNetworkOperationErrorTypeNetworkError);
}

- (NSOperation *)remoteRequest:(BOOL)isGetMethod path:(NSString *)path params:(NSDictionary *)params postData:(NSString *)postData postDataContentType:(NSString *)postDataContentType requestHeaders:(NSDictionary *)requestHeaders completion:(void (^)(id responseData, NSInteger statusCode))completionBlock error:(void (^)(NSError *))errorBlock {
    return [self remoteRequest:isGetMethod path:path params:params postData:postData contentType:postDataContentType requestHeaders:requestHeaders convertToJSON:NO autoRetryOnNetworkError:NO  completion:completionBlock error:errorBlock];
}

- (NSOperation *)remoteJSONGetRequest:(NSString *)path params:(NSDictionary *)params requestHeaders:(NSDictionary *)requestHeaders completion:(void(^)(id responseAsJson, NSInteger statusCode))completionBlock error:(void(^)(NSError *error))errorBlock {
    return [self remoteRequest:YES path:path params:params postData:nil contentType:nil requestHeaders:requestHeaders convertToJSON:YES autoRetryOnNetworkError:NO completion:completionBlock error:errorBlock];
}

- (NSOperation *)remoteJSONGetRequest:(NSString *)path params:(NSDictionary *)params autoRetryOnNetworkError:(BOOL)autoRetryOnNetworkError requestHeaders:(NSDictionary *)requestHeaders completion:(void(^)(id responseAsJson, NSInteger statusCode))completionBlock error:(void(^)(NSError *error))errorBlock {
    return [self remoteRequest:YES path:path params:params postData:nil contentType:nil requestHeaders:requestHeaders convertToJSON:YES autoRetryOnNetworkError:autoRetryOnNetworkError completion:completionBlock error:errorBlock];
}

#pragma mark - Private Method

- (NSOperation *)remoteRequest:(BOOL)isGetMethod path:(NSString *)path params:(NSDictionary *)params postData:(NSString *)postData contentType:(NSString *)postDataContentType requestHeaders:(NSDictionary *)requestHeaders convertToJSON:(BOOL)convertToJSON autoRetryOnNetworkError:(BOOL)autoRetryOnNetworkError completion:(void (^)(id responseData, NSInteger statusCode))completionBlock error:(void (^)(NSError *))errorBlock {
    SFNetworkEngine *networkEngine = [SFNetworkEngine sharedInstance];

    // Creates corresponding request operation.
    NSString *requestMethod = isGetMethod ? SFNetworkOperationGetMethod : SFNetworkOperationPostMethod;
    SFNetworkOperation *operation = [networkEngine operationWithUrl:path params:params httpMethod:requestMethod];
    operation.requiresAccessToken = YES;
    operation.retryOnNetworkError = autoRetryOnNetworkError;
    if ([requestMethod isEqualToString:SFNetworkOperationPostMethod] && postData) {
        SFNetworkOperationEncodingBlock dataEncodingBlock = ^NSString *(NSDictionary *postDataDict) {
            return postData;
        };
        [operation setCustomPostDataEncodingHandler:dataEncodingBlock forType:postDataContentType];
    }

    // Populates request headers.
    [operation setHeaderValue:@"false" forKey:@"X-Chatter-Entity-Encoding"];
    if (requestHeaders) {
        for (NSString *key in requestHeaders) {
            [operation setHeaderValue:requestHeaders[key] forKey:key];
        }
        operation.customHeaders = requestHeaders;
    }

    // Adds completion and error blocks.
    [operation addCompletionBlock:^(SFNetworkOperation *operation) {
        if (completionBlock) {
            if (convertToJSON) {
                completionBlock(operation.responseAsJSON, operation.statusCode);
            } else {
                completionBlock(operation.responseAsData, operation.statusCode);
            }
        }
    } errorBlock:^(NSError *error) {
        if (errorBlock) {
            errorBlock(error);
        }
    }];

    // Enqueues operation now.
    [networkEngine enqueueOperation:operation];
    return  operation;
}

#pragma mark - SFAuthenticationManagerDelegate

- (void)authManager:(SFAuthenticationManager *)manager willLogoutUser:(SFUserAccount *)user {
    [[self class] removeSharedInstance:user];
}

@end
