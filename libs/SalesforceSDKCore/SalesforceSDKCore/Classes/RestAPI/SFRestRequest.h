/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
 
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
#import <SalesforceSDKCore/SalesforceSDKConstants.h>
#import <SalesforceSDKCore/SFUserAccount.h>

/**
 * HTTP methods for requests.
 */
typedef NS_ENUM(NSInteger, SFRestMethod) {
    SFRestMethodGET = 0,
    SFRestMethodPOST,
    SFRestMethodPUT,
    SFRestMethodDELETE,
    SFRestMethodHEAD,
    SFRestMethodPATCH
} NS_SWIFT_NAME(RestRequest.Method);

/**
 * HTTP methods for requests.
 */
typedef NS_ENUM(NSInteger, SFSDKNetworkServiceType) {
    SFNetworkServiceTypeDefault,
    SFNetworkServiceTypeResponsiveData,
    SFNetworkServiceTypeBackground,
   
} NS_SWIFT_NAME(RestRequest.NetWorkServiceType);

/**
 * The type of service host to use for Rest requests.
 */
typedef NS_ENUM(NSUInteger, SFSDKRestServiceHostType) {

    /**
     *  Request uses the login endpoint.
     */
    SFSDKRestServiceHostTypeLogin,
    
    /**
     *  Request uses the instance endpoint.
     */
    SFSDKRestServiceHostTypeInstance,
    
    /**
     *  Request uses a custom endpoint.
     */
    SFSDKRestServiceHostTypeCustom
} NS_SWIFT_NAME(RestRequest.ServiceHostType);

NS_ASSUME_NONNULL_BEGIN

/**
 The default REST endpoint used by requests.
 */
extern NSString * const kSFDefaultRestEndpoint;

// Forward declaration.
@class SFRestRequest;

/**
 * Lifecycle events for REST requests.
 */
NS_SWIFT_NAME(RestRequestDelegate)
@protocol SFRestRequestDelegate <NSObject>
@optional

/**
 * Called when a request was successful.
 *
 * @param request REST request.
 * @param dataResponse The data from the response.  By default, this will be an object
 * containing the parsed JSON response.  However, if the response is not JSON,
 * the data will be contained in a binary `NSData` object.
 * @param rawResponse Raw response returned by the server.
 */
- (void)request:(SFRestRequest *)request didSucceed:(id)dataResponse rawResponse:(NSURLResponse *)rawResponse;

/**
 * Called when a request failed.
 *
 * @param request REST request.
 * @param dataResponse The data from the response.  By default, this will be an object
 * containing the parsed JSON response.  However, if the response is not JSON,
 * the data will be contained in a binary `NSData` object.
 * @param rawResponse Raw response returned by the server.
 * @param error Error received.
*/
- (void)request:(SFRestRequest *)request didFail:(id)dataResponse rawResponse:(NSURLResponse *)rawResponse error:(NSError *)error;

@end

/**
 * Request object used to send a REST request to Salesforce.com
 * @see SFRestAPI
 */
NS_SWIFT_NAME(RestRequest)
@interface SFRestRequest : NSObject

/**
 * The HTTP method of the request. See SFRestMethod.
 */
@property (nonatomic, assign, readwrite) SFRestMethod method;

/**
 * The HTTP method of the request. See SFRestMethod.
 */
@property (nonatomic, assign, readwrite) SFSDKNetworkServiceType networkServiceType;

/**
 * The type of service host for the request (e.g. login or instance).
 */
@property (nonatomic, assign, readwrite) SFSDKRestServiceHostType serviceHostType;

/**
 * The NSURLSesssionDataTask instance associated with the request. This is set only
 * once the request is queued and could be 'nil' before that happens.
 */
@property (nullable, nonatomic, strong, readwrite) NSURLSessionDataTask *sessionDataTask;

/**
 * The base URL of the request, to be prepended to the value of the `path` property.
 * By default, this will be the API URL associated with the current user's account.
 * One use would be when in a community setting and you want to send a request against the base API URL.
 */
@property (nullable, nonatomic, strong, readwrite) NSString *baseURL;

/**
 * The path of the request or the full URL to be used. If a full URL is passed in, the endpoint ceases to matter.
 * For instance, "" (empty string), "v22.0/recent", "v22.0/query".
 * Note that the path doesn't have to start with a '/'. For instance, passing "v22.0/recent" is the same as passing "/v22.0/recent".
 * @warning Do not pass URL encoded query parameters in the path. Use the `queryParams` property instead.
 */
@property (nonnull, nonatomic, strong, readwrite) NSString *path;

/**
 * Used to specify if the response should be parsed. YES by default.
 */
@property (nonatomic, assign) BOOL parseResponse;

/**
 * The query parameters of the request (could be nil).
 * Note that URL encoding of the parameters will automatically happen when the request is sent.
 */
@property (nullable, nonatomic, strong, readwrite) NSMutableDictionary<NSString*, id> *queryParams;

/**
 * Dictionary of any custom HTTP headers you wish to add to your request.  You can also use
 * `setHeaderValue:forHeaderName:` to add headers to this property.
 */
@property (nullable, nonatomic, strong, readwrite) NSMutableDictionary<NSString*, NSString*> *customHeaders;

/**
 * The delegate for this request. Notified of request status.
 */
@property (nullable, nonatomic, weak) id<SFRestRequestDelegate> requestDelegate;

/**
 * Typically kSFDefaultRestEndpoint but you may use eg custom Apex endpoints
 */
@property (nonnull, nonatomic, strong, readwrite) NSString *endpoint;

/**
 * Whether or not this request requires authentication.  If YES, the credentials will be added to
 * the request headers before sending the request.  If NO, they will not.
 */
@property (nonatomic, assign) BOOL requiresAuthentication;

/**
 * Assigns the timeout interval allowed for this request.
 */
@property (nonatomic, assign, readwrite) NSTimeInterval timeoutInterval;

/**
 * Prepares the request before sending it out.
 *
 * @param user User account.
 * @return NSURLRequest instance.
 */
- (nullable NSURLRequest *)prepareRequestForSend:(nonnull SFUserAccount *)user;

/**
 * Sets the value for the specified HTTP header.
 * @param value The header value. If value is `nil`, this method will remove the HTTP header
 * from the collection of headers.
 * @param name The name of the HTTP header to set.
 */
- (void)setHeaderValue:(nullable NSString *)value forHeaderName:(NSString *)name;

/**
 * Cancels this request if it is running.
 */
- (void)cancel;

/**
 * Add file to upload
 * @param fileData Value of this POST parameter
 * @param paramName Name of the POST parameter
 * @param fileName Name of the file
 * @param mimeType MIME type of the file
 * @param params File properties (e.g. title, desc, contentSize)
 */
- (void)addPostFileData:(NSData *)fileData paramName:(NSString *)paramName fileName:(NSString *)fileName mimeType:(NSString *)mimeType params:(nullable NSDictionary *)params;

/**
 * Sets a custom request body based on an NSString representation.
 * @param bodyString The NSString object representing the request body.
 * @param contentType The content type associated with this request.
 */
- (void)setCustomRequestBodyString:(NSString *)bodyString contentType:(NSString *)contentType;

/**
 * Sets a custom request body based on an NSDictionary representation.
 * @param bodyDictionary The NSDictionary object representing the request body.
 * @param contentType The content type associated with this request.
 */
- (void)setCustomRequestBodyDictionary:(NSDictionary *)bodyDictionary contentType:(NSString *)contentType;

/**
 * Sets a custom request body based on an NSData representation.
 * @param bodyData The NSData object representing the request body.
 * @param contentType The content type associated with this request.
 */
- (void)setCustomRequestBodyData:(NSData *)bodyData contentType:(NSString *)contentType;

/**
 * Sets a custom request body based on an NSInputStream representation.
 * @param bodyStreamBlock The block that will return an NSInputStream object representing the request body.
 * @param contentType The content type associated with this request.
 */
- (void)setCustomRequestBodyStream:(NSInputStream* (^)(void))bodyStreamBlock contentType:(NSString *)contentType;

/** Indicates whether the error code of the given error specifies a network error.
 * @param error The error object to check
 * @return YES if the error code of the given error specifies a network error
 */
+ (BOOL)isNetworkError:(NSError *)error;

/**
 * Return HTTP method as string for SFRestMethod
 * @param restMethod The SFRestMethod
 * @return the HTTP string for the given SFRestMethod
 */
+ (NSString *)httpMethodFromSFRestMethod:(SFRestMethod)restMethod;

/**
 * Return SFRestMethod from string
 @param httpMethod An HTTP method; for example, "get" or "post"
 @return The SFRestMethod enumerator for the given HTTP method
 */
+ (SFRestMethod)sfRestMethodFromHTTPMethod:(NSString *)httpMethod;

/**
 * Creates an `SFRestRequest` object. See SFRestMethod. If you need to set body on the request, use one of the 'setCustomRequestBody...' methods to do so with the instance returned by this method.
 * @param method the HTTP method
 * @param path the request path
 * @param queryParams the parameters of the request (could be nil)
 */
+ (instancetype)requestWithMethod:(SFRestMethod)method path:(NSString *)path queryParams:(nullable NSDictionary<NSString*, id> *)queryParams;

/**
 * Creates an `SFRestRequest` object. See SFRestMethod. If you need to set body on the request, use one of the 'setCustomRequestBody...' methods to do so with the instance returned by this method.
 * @param method the HTTP method
 * @param hostType the type of service host for the request. 
 * @param path the request path
 * @param queryParams the parameters of the request (could be nil)
 */
+ (instancetype)requestWithMethod:(SFRestMethod)method serviceHostType:(SFSDKRestServiceHostType)hostType path:(NSString *)path queryParams:(nullable NSDictionary<NSString*, id> *)queryParams;

/**
 * Creates an `SFRestRequest` object. To set the body of the request, use one of the `setCustomRequestBody...` methods on the returned instance.
 * @param method HTTP method
 * @param baseURL Request URL
 * @param path Request path
 * @param queryParams Parameters of the request (can be nil)
 * @see SFRestMethod. 
 */
+ (instancetype)requestWithMethod:(SFRestMethod)method baseURL:(NSString *)baseURL path:(NSString *)path queryParams:(nullable NSDictionary<NSString*, id> *)queryParams;

/**
 * Creates an `SFRestRequest` object to be used with non-Salesforce endpoints. To set body on the request, use one of the 'setCustomRequestBody...' methods on the returned instance.
 * @param method the HTTP method
 * @param baseURL the request URL
 * @param path the request path
 * @param queryParams the parameters of the request (could be nil)
 * @see SFRestMethod. 
 */
+ (instancetype)customUrlRequestWithMethod:(SFRestMethod)method baseURL:(NSString *)baseURL path:(NSString *)path queryParams:(nullable NSDictionary<NSString*, id> *)queryParams;

/**
 * Creates an `SFRestRequest` object to be used with custom Salesforce endpoints. See SFRestMethod. If you need to set body on the request, use one of the 'setCustomRequestBody...' methods to do so with the instance returned by this method.
 * @param method the HTTP method
 * @param path the request path
 * @param queryParams the parameters of the request (could be nil)
 */

+ (instancetype)customEndPointRequestWithMethod:(SFRestMethod)method endPoint:(NSString *)endPoint path:(NSString *)path queryParams:(nullable NSDictionary<NSString*, id> *)queryParams;

@end

NS_ASSUME_NONNULL_END
