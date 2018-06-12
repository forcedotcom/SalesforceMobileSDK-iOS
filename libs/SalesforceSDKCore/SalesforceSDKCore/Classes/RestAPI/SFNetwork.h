/*
 SFNetwork.h
 SalesforceSDKCore
 
 Created by Bharath Hariharan on 2/15/17.
 
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
#import "SalesforceSDKConstants.h"

@interface SFNetwork : NSObject

typedef void (^SFDataResponseBlock) (NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

@property (nonatomic, readonly, assign) BOOL useBackground;
@property (nonatomic, readonly, strong, nonnull) NSURLSession *activeSession;

/**
 * Initializes this class with an ephemeral session configuration.
 *
 * @return Instance of this class.
 */
- (nonnull instancetype)initWithEphemeralSession;

/**
 * Initializes this class with a background session configuration.
 *
 * @return Instance of this class.
 */
- (nonnull instancetype)initWithBackgroundSession;

/**
 * Sends a REST request and calls the appropriate completion block.
 *
 * @param urlRequest NSURLRequest instance.
 * @param dataResponseBlock Network response block.
 * @return NSURLSessionDataTask instance.
 */
- (nonnull NSURLSessionDataTask *)sendRequest:(nonnull NSURLRequest *)urlRequest dataResponseBlock:(nullable SFDataResponseBlock)dataResponseBlock;

/**
 * Sets a session configuration to be used for network requests in the Mobile SDK.
 *
 * @param sessionConfig Session configuration to be used.
 * @param isBackgroundSession YES - if it is a background session configuration, NO - otherwise.
 */
+ (void)setSessionConfiguration:(nonnull NSURLSessionConfiguration *)sessionConfig isBackgroundSession:(BOOL)isBackgroundSession SFSDK_DEPRECATED(6.2, 7.0, "Use 'setSessionConfiguration:' instead.");

/**
 * Sets a session configuration to be used for network requests in the Mobile SDK.
 *
 * @param sessionConfig Session configuration to be used.
 */
+ (void)setSessionConfiguration:(nonnull NSURLSessionConfiguration *)sessionConfig;

@end
