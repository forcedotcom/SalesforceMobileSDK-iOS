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

#import "SFRestAPI+Internal.h"
#import "SFRestAPI+Blocks.h"
#import "SFRestAPI+Files.h"
#import "SFSDKCompositeRequest.h"
#import "SFSDKBatchRequest.h"
#import "SFSDKBatchResponse+Internal.h"
#import "SFSDKCompositeResponse+Internal.h"

@implementation SFRestAPI (Blocks)

#pragma mark - error handling

+ (NSError *)errorWithDescription:(NSString *)description {    
    NSArray *objArray = @[description, @""];
    NSArray *keyArray = @[NSLocalizedDescriptionKey, NSFilePathErrorKey];
    NSDictionary *eDict = [NSDictionary dictionaryWithObjects:objArray
                                                      forKeys:keyArray];
    NSError *err = [[NSError alloc] initWithDomain:@"API Error"
                                              code:42 // life, the universe, and everything
                                          userInfo:eDict];
    return err;
}

#pragma mark - sending requests

- (void) sendRequest:(SFRestRequest *)request
        failureBlock:(SFRestRequestFailBlock)failureBlock
        successBlock:(SFRestResponseBlock)successBlock {
    [self send:request failureBlock:failureBlock successBlock:successBlock];
}

- (void) sendCompositeRequest:(SFSDKCompositeRequest *)request
                 failureBlock:(SFRestRequestFailBlock)failureBlock
                 successBlock:(SFRestCompositeResponseBlock)successBlock {
    [self sendRequest:request failureBlock:failureBlock successBlock:^(id response, NSURLResponse * rawResponse) {
        @try {
            SFSDKCompositeResponse *compositeResponse = [[SFSDKCompositeResponse alloc] initWith:response];
            successBlock(compositeResponse, rawResponse);
        } @catch (NSException *exception) {
            NSDictionary *userInfo = @{ @"Exception": exception.name, @"NSDebugDescription": exception.reason };
            NSError *error = [[NSError alloc] initWithDomain: kSFRestErrorDomain
                                                        code: kSFRestErrorCode
                                                    userInfo:userInfo];
            failureBlock(response, error, rawResponse);
        }
    }];
}

- (void) sendBatchRequest:(SFSDKBatchRequest *)request
             failureBlock:(SFRestRequestFailBlock)failureBlock
             successBlock:(SFRestBatchResponseBlock)successBlock {
    [self sendRequest:request failureBlock:failureBlock successBlock:^(id response, NSURLResponse * rawResponse) {
        @try {
            SFSDKBatchResponse *compositeResponse = [[SFSDKBatchResponse alloc] initWith:response];
            successBlock(compositeResponse, rawResponse);
        } @catch (NSException *exception) {
            
            NSDictionary *userInfo = @{ @"Exception": exception.name, @"NSDebugDescription": exception.reason };
            NSError *error = [[NSError alloc] initWithDomain: kSFRestErrorDomain
                                                        code: kSFRestErrorCode
                                                    userInfo:userInfo];
            failureBlock(response, error, rawResponse);
        }
    }];
}
@end
