/* 
 * Copyright (c) 2011-present, salesforce.com, inc.
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided 
 * that the following conditions are met:
 * 
 *    Redistributions of source code must retain the above copyright notice, this list of conditions and the 
 *    following disclaimer.
 *  
 *    Redistributions in binary form must reproduce the above copyright notice, this list of conditions and 
 *    the following disclaimer in the documentation and/or other materials provided with the distribution. 
 *    
 *    Neither the name of salesforce.com, inc. nor the names of its contributors may be used to endorse or 
 *    promote products derived from this software without specific prior written permission.
 *  
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED 
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR 
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import <SalesforceSDKCore/SFRestAPI.h>

NS_ASSUME_NONNULL_BEGIN
@class SFSDKCompositeResponse;
@class SFSDKBatchResponse;
@class SFSDKCompositeRequest;
@class SFSDKBatchRequest;

@interface SFRestAPI (Blocks) <SFRestRequestDelegate>

// Block types
typedef void (^SFRestRequestFailBlock) (id _Nullable response, NSError * _Nullable e, NSURLResponse * _Nullable rawResponse) NS_SWIFT_NAME(RestRequestFailBlock);
typedef void (^SFRestDictionaryResponseBlock) (NSDictionary * _Nullable dict, NSURLResponse * _Nullable rawResponse)  NS_SWIFT_NAME(RestDictionaryResponseBlock);
typedef void (^SFRestArrayResponseBlock) (NSArray * _Nullable arr, NSURLResponse * _Nullable rawResponse) NS_SWIFT_NAME(RestArrayResponseBlock);
typedef void (^SFRestDataResponseBlock) (NSData* _Nullable data, NSURLResponse * _Nullable rawResponse) NS_SWIFT_NAME(RestDataResponseBlock);
typedef void (^SFRestResponseBlock) (id _Nullable response, NSURLResponse * _Nullable rawResponse) NS_SWIFT_NAME(RestResponseBlock);
typedef void (^SFRestCompositeResponseBlock) (SFSDKCompositeResponse *response, NSURLResponse * _Nullable rawResponse) NS_SWIFT_NAME(RestCompositeResponseBlock);
typedef void (^SFRestBatchResponseBlock) (SFSDKBatchResponse *response, NSURLResponse * _Nullable rawResponse) NS_SWIFT_NAME(RestBatchResponseBlock);

/** Creates an error object with the given description.
 @param description Description
 */
+ (NSError *)errorWithDescription:(NSString *)description;

/**
 * Sends a request you've already built, using blocks to return status.
 *
 * @param request SFRestRequest to be sent.
 * @param failureBlock Block to be executed when the request fails (timeout, cancel, or error).
 * @param successBlock Block to be executed when the request successfully completes.
 */
- (void) sendRequest:(SFRestRequest *)request failureBlock:(SFRestRequestFailBlock)failureBlock successBlock:(SFRestResponseBlock)successBlock NS_REFINED_FOR_SWIFT;

/**
 * Sends a request you've already built, using blocks to return status.
 *
 * @param request Composite request to be sent.
 * @param failureBlock Block to be executed when the request fails (timeout, cancel, or error).
 * @param successBlock Block to be executed when the request successfully completes.
 */
- (void) sendCompositeRequest:(SFSDKCompositeRequest *)request failureBlock:(SFRestRequestFailBlock)failureBlock successBlock:(SFRestCompositeResponseBlock)successBlock NS_REFINED_FOR_SWIFT;

/**
 * Sends a request you've already built, using blocks to return status.
 *
 * @param request Batch request to be sent.
 * @param failureBlock Block to be executed when the request fails (timeout, cancel, or error).
 * @param successBlock Block to be executed when the request successfully completes.
 */
- (void) sendBatchRequest:(SFSDKBatchRequest *)request failureBlock:(SFRestRequestFailBlock)failureBlock successBlock:(SFRestBatchResponseBlock)successBlock NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END
