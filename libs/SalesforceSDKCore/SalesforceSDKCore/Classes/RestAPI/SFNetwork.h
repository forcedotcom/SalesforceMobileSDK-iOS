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
#import <SalesforceSDKCore/SalesforceSDKConstants.h>

extern NSString * __nonnull const kSFNetworkEphemeralInstanceIdentifier NS_SWIFT_NAME(NetworkEphemeralInstanceIdentifier);
extern NSString * __nonnull const kSFNetworkBackgroundInstanceIdentifier NS_SWIFT_NAME(NetworkBackgroundInstanceIdentifier);

NS_SWIFT_NAME(Network)
@interface SFNetwork : NSObject

typedef void (^SFDataResponseBlock) (NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) NS_SWIFT_NAME(DataResponseBlock);

typedef void (^SFSDKMetricsCollectedBlock)(NSURLSession * _Nonnull session, NSURLSessionTask * _Nonnull task, NSURLSessionTaskMetrics * _Nonnull metrics);

@property (nonatomic, readonly, strong, nonnull) NSURLSession *activeSession;

/**
 The block to execute to execeute when metrics are collected on URL session task, if provided.
 */
@property (class, nonatomic, copy, nullable) SFSDKMetricsCollectedBlock metricsCollectedAction;

/**
 * Returns an instance of this class with the default ephemeral session configuration.
 *
 * @return Instance of this class.
 */
+ (nonnull instancetype)sharedEphemeralInstance;

/**
 * Returns an instance of this class with the default background session configuration.
 *
 * @return Instance of this class.
 */
+ (nonnull instancetype)sharedBackgroundInstance;

/**
 * Returns instance of this class for the given identifier with the default ephemeral session configuration.
 *
 * @return Instance of this class.
 */
+ (nonnull instancetype)sharedEphemeralInstanceWithIdentifier:(nonnull NSString *)identifier;

/**
 * Returns instance of this class for the given identifier with the default background session configuration.
 *
 * @return Instance of this class.
 */
+ (nonnull instancetype)sharedBackgroundInstanceWithIdentifier:(nonnull NSString *)identifier;

/**
 * Returns an instance of this class with the given session configuration.
 *
 * @param identifier Identifier for the instance
 * @param sessionConfiguration Configuration to use for the session.
 * @return Instance of this class.
 */
+ (nonnull instancetype)sharedInstanceWithIdentifier:(nonnull NSString *)identifier sessionConfiguration:(nonnull NSURLSessionConfiguration *)sessionConfiguration;

/**
 * Sends a REST request and calls the appropriate completion block.
 *
 * @param urlRequest NSURLRequest instance.
 * @param dataResponseBlock Network response block.
 * @return NSURLSessionDataTask instance.
 */
- (nonnull NSURLSessionDataTask *)sendRequest:(nonnull NSURLRequest *)urlRequest dataResponseBlock:(nullable SFDataResponseBlock)dataResponseBlock;

/**
 * Sets a session configuration to be used for network requests in Mobile SDK.
 *
 * @param sessionConfig Session configuration to be used.
 * @param identifier Identifier for the instance to use this config.
 */
+ (void)setSessionConfiguration:(nonnull NSURLSessionConfiguration *)sessionConfig identifier:(nonnull NSString *)identifier;

/**
 * Removes shared instance for the default ephemeral identifier.
 */
+ (void)removeSharedEphemeralInstance;

/**
 * Removes shared instance for the default background identifier.
 */
+ (void)removeSharedBackgroundInstance;

/**
 * Removes shared instance for given identifier.
 *
 * @param identifier Identifier for the session.
 */
+ (void)removeSharedInstanceForIdentifier:(nullable NSString *)identifier;

/**
 * Removes all shared instances.
 */
+ (void)removeAllSharedInstances;

/**
 * Returns list of identifiers for all shared instances.
 * @return Array of identifiers.
 */
+ (nullable NSArray *)sharedInstanceIdentifiers;

/**
 * Generates a unique instance identifier.
 */
+ (nonnull NSString *)uniqueInstanceIdentifier;


@end
