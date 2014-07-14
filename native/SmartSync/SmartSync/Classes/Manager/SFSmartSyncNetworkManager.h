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

#import <Foundation/Foundation.h>

/** This class uses SalesforceNetworkSDK to send and process remote service calls.
 */
@interface SFSmartSyncNetworkManager : NSObject

/** Singleton method for accessing an instance of this class.
 */
+ (id)sharedInstance;

- (void)setServerRootUrl:(NSURL *)serverRootUrl;

- (NSURL *)serverRootUrl;

/** Execute remote request, returning NSOperation so that caller can cancel the request if needed.
 * @param path the request path
 * @param params the parameters of the request (could be nil)
 * @param postData Data to be posted, used with POST method only
 * @param postDataContentType Content type for the postData
 * @param requestHeaders NSDicitionary object that contains additional request headers that should be included as part of this network request
 * @param completionBlock Block to invoke after remote call is done. It will return response as string
 * @param errorBlock Block to remote call failed
 */
- (NSOperation *)remoteRequest:(BOOL)isGetMethod path:(NSString *)path params:(NSDictionary *)params postData:(NSString *)postData postDataContentType:(NSString *)postDataContentType requestHeaders:(NSDictionary *)requestHeaders completion:(void(^)(id responseData, NSInteger statusCode))completionBlock error:(void(^)(NSError *error))errorBlock;

/** Execute remote GET request that returns JSON object, returning NSOperation so that caller can cancel the request if needed.
 * @param path the request path
 * @param params the parameters of the request (could be nil)
 * @param completionBlock Block to invoke after remote call is done. It will return response as JSON object, it could be single JSON object or an array
 * @param errorBlock Block to remote call failed
 */
- (NSOperation *)remoteJSONGetRequest:(NSString *)path params:(NSDictionary *)params requestHeaders:(NSDictionary *)requestHeaders completion:(void(^)(id responseAsJson, NSInteger statusCode))completionBlock error:(void(^)(NSError *error))errorBlock;

/** Execute remote GET request that returns JSON object, returning NSOperation so that caller can cancel the request if needed.
 * @param path the request path
 * @param params the parameters of the request (could be nil)
 * @param completionBlock Block to invoke after remote call is done. It will return response as JSON object, it could be single JSON object or an array
 * @param errorBlock Block to remote call failed
 */
- (NSOperation *)remoteJSONGetRequest:(NSString *)path params:(NSDictionary *)params autoRetryOnNetworkError:(BOOL)autoRetryOnNetworkError requestHeaders:(NSDictionary *)requestHeaders completion:(void(^)(id responseAsJson, NSInteger statusCode))completionBlock error:(void(^)(NSError *error))errorBlock;

/** Return access token to use for remote call. */
- (NSString *)accessToken;

/** Return YES if error is caused by network connectivity error.
 @param error NSError object
 */
- (BOOL)isNetworkError:(NSError *)error;

@end
