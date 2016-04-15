/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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

@class SFRestAPISalesforceAction;


/**
 * HTTP methods for requests
 */
typedef NS_ENUM(NSInteger, SFRestMethod) {
    SFRestMethodGET = 0,
    SFRestMethodPOST,
    SFRestMethodPUT,
    SFRestMethodDELETE,
    SFRestMethodHEAD,
    SFRestMethodPATCH,
};

NS_ASSUME_NONNULL_BEGIN

/**
 The default REST endpoint used by requests.
 */
extern NSString * const kSFDefaultRestEndpoint;


//forward declaration
@class SFRestRequest;

/**
 * Lifecycle events for SFRestRequests.
 */
@protocol SFRestDelegate <NSObject>
@optional

/**
 * Sent when a request has finished loading.
 * @param request The request that was loaded.
 * @param dataResponse The data from the response.  By default, this will be an object
 * containing the parsed JSON response.  However, if `request.parseResponse` was set
 * to `NO`, the data will be contained in a binary `NSData` object.
 */
- (void)request:(SFRestRequest *)request didLoadResponse:(id)dataResponse;

/**
 * Sent when a request has failed due to an error.
 * This includes HTTP network errors, as well as Salesforce errors
 * (for example, passing an invalid SOQL string when doing a query).
 * @param request The attempted request.
 * @param error The error associated with the failed request.
 */
- (void)request:(SFRestRequest *)request didFailLoadWithError:(NSError*)error;

/**
 * Sent to the delegate when a request was cancelled.
 * @param request The canceled request.
 */
- (void)requestDidCancelLoad:(SFRestRequest *)request;

/**
 * Sent to the delegate when a request has timed out. This is sent when a
 * backgrounded request expired before completion.
 * @param request The request that timed out.
 */
- (void)requestDidTimeout:(SFRestRequest *)request;

@end

/**
 * Request object used to send a REST request to Salesforce.com
 * @see SFRestAPI
 */
@interface SFRestRequest : NSObject

/**
 * The HTTP method of the request.  See SFRestMethod.
 */
@property (nonatomic, assign) SFRestMethod method;

/**
 * The path of the request.
 * For instance, "" (empty string), "v22.0/recent", "v22.0/query".
 * Note that the path doesn't have to start with a '/'. For instance, passing "v22.0/recent" is the same as passing "/v22.0/recent".
 * @warning Do not pass URL encoded query parameters in the path. Use the `queryParams` property instead.
 */
@property (nonatomic, strong) NSString *path;

/**
 * The query parameters of the request (could be nil).
 * Note that URL encoding of the parameters will automatically happen when the request is sent.
 */
@property (nullable, nonatomic, strong) NSDictionary<NSString*, NSObject*> *queryParams;

/**
 * Dictionary of any custom HTTP headers you wish to add to your request.  You can also use
 * `setHeaderValue:forHeaderName:` to add headers to this property.
 */
@property (nonatomic, strong) NSDictionary<NSString*, NSString*> *customHeaders;

/**
 * Underlying SFRestAPISalesforceAction through which the network call is carried out
 */
@property (nonatomic, strong) SFRestAPISalesforceAction *action;

/**
 * The delegate for this request. Notified of request status.
 */
@property (nullable, nonatomic, weak) id<SFRestDelegate> delegate;


/**
 * Typically kSFDefaultRestEndpoint but you may use eg custom Apex endpoints
 */
@property (nonatomic, strong) NSString *endpoint;

/**
 * Whether or not this request requires authentication.  If YES, the credentials will be added to
 * the request headers before sending the request.  If NO, they will not.
 */
@property (nonatomic, assign) BOOL requiresAuthentication;

/**
 * Whether or not to parse the response data as structured JSON data.  Defaults to `YES`. If
 * set to `NO`, response data will be returned as binary data in an `NSData` object.
 */
@property (nonatomic, assign) BOOL parseResponse;

/**
 * Override this method to implement any request preparations immediately prior to the request
 * being sent.  Note: You should not call this method directly.  And make sure to call the
 * super implementation within your own implementation.
 */
- (void)prepareRequestForSend;

/**
 * Sets the value for the specified HTTP header.
 * @param value The header value. If value is `nil`, this method will remove the HTTP header
 * from the collection of headers.
 * @param name The name of the HTTP header to set.
 */
- (void)setHeaderValue:(nullable NSString *)value forHeaderName:(NSString *)name;

/**
 * Cancels this request if it is running
 */
- (void) cancel;

/**
 * Add file to upload.
 * @param fileData Value of this POST parameter
 * @param paramName Name of the POST parameter
 * @param fileName Name of the file
 * @param mimeType MIME type of the file
 */
- (void)addPostFileData:(NSData *)fileData paramName:(NSString *)paramName fileName:(NSString *)fileName mimeType:(NSString *)mimeType;

/**
 * Sets a custom request body based on an NSString representation.
 * @param bodyString The NSString object representing the request body.
 * @param contentType The content type associated with this request.
 */
- (void)setCustomRequestBodyString:(NSString *)bodyString contentType:(NSString *)contentType;

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
 * Return SFRestMethod from string
 @param httpMethod An HTTP method; for example, "get" or "post"
 @return The SFRestMethod enumerator for the given HTTP method
 */
+ (SFRestMethod)sfRestMethodFromHTTPMethod:(NSString *)httpMethod;


///---------------------------------------------------------------------------------------
/// @name Initialization
///---------------------------------------------------------------------------------------

/**
 * Creates an `SFRestRequest` object. See SFRestMethod.
 * @param method the HTTP method
 * @param path the request path
 * @param queryParams the parameters of the request (could be nil)
 */
+ (instancetype)requestWithMethod:(SFRestMethod)method path:(NSString *)path queryParams:(nullable NSDictionary<NSString*, NSString*> *)queryParams;

@end

NS_ASSUME_NONNULL_END
