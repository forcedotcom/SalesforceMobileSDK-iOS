/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

#import "CSFDefines.h"

@protocol CSFActionModel;
@class CSFParameterStorage;
@class CSFNetwork;
@class CSFAction;

NS_ASSUME_NONNULL_BEGIN
/**
 This is a class that represents an chatter action that the action executer executes
 */
@interface CSFAction : NSOperation

/** Action executor this network operation is working within.
 */
@property (nonatomic, weak, readonly) CSFNetwork *enqueuedNetwork;

/**
 Is the action programmatic or user driven; used for Salesforce1
 */
@property (nonatomic, getter = isProgrammatic) BOOL programmatic;

/**
 * Object reference providing context to which network actions are similar.
 * This can be used to assign a common value to a group of actions that should
 * be cancelled together.
 *
 * For example, a view controller can be assigned to this property to keep track of
 * all actions scheduled from user actions performed within it.  When the controller
 * is dismissed, the pending actions invoked by that view controller may be cancelled,
 * preventing unnecessary network overhead.
 *
 * @see [CSFNetwork cancelAllActionsWithContext:]
 */
@property (nonatomic, weak) id context;

/** YES to have the action enqueued if no network is available,
 NO to have the action be completed with the proper error code
 if no network is available.
 By default this property is YES.
 */
@property (nonatomic) BOOL enqueueIfNoNetwork;

/** The execution cap type
 */
@property (nonatomic) CSFActionExecutionCapType executionCapType;

/** The base URL to use when composing a request for this action.
 
 If `nil`, then the instance URL for the currently assigned user account will be used.
 */
@property (nonatomic, copy) NSURL *baseURL;

/** URL path to use when composing a request for this action.
 */
@property (nonatomic, copy) NSString *verb;

/** HTTP method to use
 */
@property (nonatomic, copy) NSString *method;

/** Dictionary containing headers to set on the request
 */
@property (nonatomic, copy, readonly) NSDictionary *allHTTPHeaderFields;

/** A dictionary containing the parameters for the action.
 
 These values will be used when composing the query string or request body.
 */
@property (nonatomic, strong, readonly) CSFParameterStorage *parameters;

/**
 User data that can be set to anything useful to the user of this class.
 */
@property (nonatomic, copy) NSDictionary *userInfo;

/**
 The parsed response output model for this result.
 */
@property (nonatomic, strong, readonly) NSObject<CSFActionModel> *outputModel;

/**
 The raw output from the request.  This will be the JSON decoded result (e.g. NSArray or NSDictionary), or whatever content is appropriate for this request type.
 */
@property (nonatomic, strong, readonly) id outputContent;

/**
 @brief The original NSData retrieved from the HTTP response.
 @discussion When creating custom subclasses that process non-JSON data (e.g. images, other downloadable resources, etc) this property may be necessary to handle custom processing of the response data.
 */
@property (nonatomic, strong, readonly) NSData *outputData;

/**
 Returns `YES` when this action is a duplicate of another request in the queue.
 */
@property (nonatomic, assign, readonly) BOOL isDuplicateAction;

/**
 If the content was downloaded to a temporary file on disk, this property represents the file URL to that temporary content.
 
 @warning
 The file this URL points to will be deleted after the action is complete, so you must move the file to another location on disk within the completion
 handlers of this action if you want to persist this content.
 */
@property (nonatomic, strong, readonly) NSURL *downloadLocation;

@property (nonatomic, assign) BOOL requiresAuthentication;
@property (nonatomic, strong) Class<CSFActionModel> modelClass;
@property (nonatomic, strong) Class authRefreshClass;
@property (nonatomic) NSTimeInterval timeoutInterval;
@property (nonatomic, strong) NSHTTPURLResponse *httpResponse;
@property (nonatomic, readonly) NSUInteger retryCount;
@property (nonatomic) NSUInteger maxRetryCount;

@property (nullable, nonatomic, strong) NSMutableData *responseData;

/**
 @brief Indicates if this request should be run on a NSURLSession capable of performing background uploads or downloads.
 @discussion Most actions transfer JSON or other informational data and therefore run on the default NSURLSession.  However, if a request is capable of running on a background session (e.g. the request is performing a download that can be performed when the app is not running), settings this value to `YES` will utilize a background session when creating a task for this request.
 */
@property (nonatomic) BOOL requireBackgroundSession NS_AVAILABLE(10_10, 8_0);

/** Takes an URL and assign it to this action by decomposing its components in the proper
 fields. For example, all the parameters will be added using addParameterWithName:value:.
 */
@property (nonatomic, copy) NSURL *url;

/**
 Reports progress information for the current action.
 */
@property (nonatomic, strong, readonly) NSProgress *progress;

/**
 Indicates if the action should cache the response in the local database.
 */
@property (nonatomic, getter=shouldCacheResponse) BOOL cacheResponse;

@property (nonatomic, copy) CSFActionResponseBlock responseBlock;

@property (nonatomic, strong) NSError *error;

+ (instancetype)actionWithHTTPMethod:(NSString*)method onURL:(NSURL*)url withResponseBlock:(CSFActionResponseBlock)responseBlock;

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithResponseBlock:(CSFActionResponseBlock)responseBlock NS_DESIGNATED_INITIALIZER;

/** Takes an URL and assign it to this action by decomposing its components in the proper
 fields. For example, all the parameters will be added using addParameterWithName:value:.
 @param url The URL to add
 */
- (void)setURL:(NSURL*)url __deprecated_msg("Use the url property instead.");

/**
 Returns the value for the indicated HTTP header field.

 @param field Field name

 @return Value of the header.
 */
- (NSString *)valueForHTTPHeaderField:(NSString *)field;

/**
 Sets the outgoing HTTP header for the given field name.
 
 @param value Value to set.
 @param field The name of the HTTP header.
 */
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;

/**
 Removes the outgoing HTTP header for the given field name.

 @param field The name of the HTTP header.
 */
- (void)removeValueForHTTPHeaderField:(NSString *)field;

/**
 Returns YES if the specified action is equal to this action meaning they same identical request URL's and bodies; NO otherwise;
 @param action Action to compare
 */
- (BOOL)isEqualToAction:(CSFAction *)action;

- (BOOL)shouldRetryWithError:(NSError*)error;

/** Subclassable method that will be called when the action is about to call responseBlock.
 
 @discussion
 This can be used by subclasses to perform extra tasks before action calls responseBlock to finish processing data.
 Subclass needs to make sure it calls `[super completeOperationWithError:error]` after it's done with performing 
 extra logic so responseBlock is properly invoked with response data.
 @param error Action error if avaiable.
 */
- (void)completeOperationWithError:(nullable NSError*)error;

/** Returns an instance of NSURLSessionTask to process the specified request 

@param request URL request to send
@param session Associated for this request
*/
- (NSURLSessionTask*)sessionTaskToProcessRequest:(NSURLRequest*)request session:(NSURLSession*)session;

/**
 Returns a dictionary of the headers that will be returned for this request.
 
 @discussion
 This method provides an override point for subclasses to inject their own headers into the response.
 
 @return Dictionary of HTTP headers.
 */
- (NSDictionary *)headersForAction;

/**
 Subclassable method that processes the information coming from the HTTP response in order to consume it within the action response.
 
 The default implementation uses NSJSONSerialization to consume the data as JSON data.  Subclasses may override this if an action needs to perform some other custom logic.
 
 @param data     NSData instance containing the HTTP response body.
 @param response The HTTP response to process.
 @param error    Pointer to an error if one occurs. This parameter is guaranteed to be a valid pointer.
 
 @return The data to populate outputContent with, otherwise `nil` if nothing is appropriate.
 */
- (id)contentFromData:(NSData*)data fromResponse:(NSHTTPURLResponse*)response error:(NSError**)error;

/**
 Method that can override the HTTP request process, and can allow a subclass to forcibly inject explicit response data without performing a network request.
 
 @discussion
 This can be used by subclasses to mock network responses for the purposes of testing, prototyping, or evaluating networking options before an available API is written.
 
 @param data     Pointer to an NSData variable.
 @param response Pointer to an NSHTTPURLResponse variable.
 
 @return `YES` if the network request should be overridden, otherwise `NO`.
 */
- (BOOL)overrideRequest:(NSURLRequest*)request withResponseData:(NSData* _Nullable * _Nonnull)data andHTTPResponse:(NSHTTPURLResponse* _Nullable * _Nonnull)response;

/**
 @brief Overridable method that permits subclasses to opt-out of contributing its progress to the parent CSFNetwork instance.
 @discussion The default implementation will return `YES`, but for requests that shouldn't propagate progress to the network, this method can be overridden to return `NO`.
 */
- (BOOL)shouldReportProgressToParent;

- (void)sessionDataTask:(NSURLSessionDataTask*)task didReceiveData:(NSData*)data;
- (void)sessionTask:(NSURLSessionTask*)task didCompleteWithError:(NSError*)error;

@end

typedef NSString*const CSFActionTiming NS_STRING_ENUM;

CSF_EXTERN CSFActionTiming kCSFActionTimingTotalTimeKey;
CSF_EXTERN CSFActionTiming kCSFActionTimingNetworkTimeKey;
CSF_EXTERN CSFActionTiming kCSFActionTimingStartDelayKey;
CSF_EXTERN CSFActionTiming kCSFActionTimingPostProcessingKey;

@interface CSFAction (Timing)

/**
 Returns timing information for this request based on the supplied option.
 
 @discussion
 Different keys supplied can permit the caller to choose what time-range within the request to use.
 * kCSFActionTimingTotalTimeKey -- Returns the total end-to-end time for the request from when it was initially enqueued, and when it returned.
 * kCSFActionTimingNetworkTimeKey -- Returns the time the network request itself took.
 * kCSFActionTimingStartDelayKey -- Returns the time delay until the action was able to begin communicating on the network.
 * kCSFActionTimingPostProcessingKey -- Returns the time any post-processing actions took, including response processing and any caching operations that occurred.
 
 If not enough information has been gathered, for example if the request has not yet completed, then the timing result will include the timing up until now.
 
 @param key Key for the timing option to return, or `nil` to return the total action time.
 
 @return The time interval for the requested key, or `0` if the key is invalid or if the request hasn't gathered enough information to supply that value yet.
 */
- (NSTimeInterval)intervalForTimingKey:(CSFActionTiming)key;

@end

NS_ASSUME_NONNULL_END
