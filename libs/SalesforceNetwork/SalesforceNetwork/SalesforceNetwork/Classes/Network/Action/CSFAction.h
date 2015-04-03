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

@property (nonatomic, assign) BOOL requiresAuthentication;
@property (nonatomic, strong) Class<CSFActionModel> modelClass;
@property (nonatomic, strong) Class authRefreshClass;
@property (nonatomic) NSTimeInterval timeoutInterval;
@property (nonatomic, strong) NSHTTPURLResponse *httpResponse;
@property (nonatomic, readonly) NSUInteger retryCount;
@property (nonatomic) NSUInteger maxRetryCount;

/**
 Indicates if the action should cache the response in the local database.
 */
@property (nonatomic, getter=shouldCacheResponse) BOOL cacheResponse;

@property (nonatomic, strong, readonly) NSError *error;

+ (instancetype)actionWithHTTPMethod:(NSString*)method onURL:(NSURL*)url withResponseBlock:(CSFActionResponseBlock)responseBlock;

- (instancetype)initWithResponseBlock:(CSFActionResponseBlock)responseBlock NS_DESIGNATED_INITIALIZER;

/** Takes an URL and assign it to this action by decomposing its components in the proper
 fields. For example, all the parameters will be added using addParameterWithName:value:.
 @param url The URL to add
 */
- (void)setURL:(NSURL*)url;

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
- (BOOL)overrideRequest:(NSURLRequest*)request withResponseData:(NSData**)data andHTTPResponse:(NSHTTPURLResponse**)response;

@end
