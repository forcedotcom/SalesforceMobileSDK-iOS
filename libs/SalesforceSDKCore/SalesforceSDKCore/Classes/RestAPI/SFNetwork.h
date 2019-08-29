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

NS_SWIFT_NAME(NetworkManaging)
@protocol SFNetworkSessionManaging
- (nonnull NSURLSession *)ephemeralSession:(nonnull NSURLSessionConfiguration *)sessionConfig SFSDK_DEPRECATED(7.3, 8.0, "Use sessionWithIdentifier:sessionConfiguration instead");
- (nonnull NSURLSession *)backgroundSession:(nonnull NSURLSessionConfiguration *)sessionConfig SFSDK_DEPRECATED(7.3, 8.0, "Use sessionWithIdentifier:sessionConfiguration instead");
- (nonnull NSURLSession *)sessionWithIdentifier:(nonnull NSString *)identifier sessionConfiguration:(nonnull NSURLSessionConfiguration *)configuration;
@end

extern NSString * __nonnull const kSFNetworkEphemeralSessionIdentifier NS_SWIFT_NAME(SFNetworkEphemeralSessionIdentifier);
extern NSString * __nonnull const kSFNetworkBackgroundSessionIdentifier NS_SWIFT_NAME(SFNetworkBackgroundSessionIdentifier);

NS_SWIFT_NAME(Network)
@interface SFNetwork : NSObject

typedef void (^SFDataResponseBlock) (NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) NS_SWIFT_NAME(DataResponseBlock);

@property (nonatomic, readonly, strong, nonnull) NSURLSession *activeSession;
@property (class, readonly, nonnull) NSDictionary *sharedSessions;

/**
 * Returns an instance of this class with the default ephemeral session configuration.
 *
 * @return Instance of this class.
 */
+ (nonnull instancetype)defaultEphemeralNetwork;

/**
 * Returns an instance of this class with the default background session configuration.
 *
 * @return Instance of this class.
 */
+ (nonnull instancetype)defaultBackgroundNetwork;

/**
 * Returns an instance of this class with the given session configuration.
 *
 * @param identifier Identifier for the session.
 * @param sessionConfiguration  Configuration to use for the session. Defaults to the ephemeral configuration.
 * @return Instance of this class.
 */
+ (nonnull instancetype)networkWithSessionIdentifier:(nonnull NSString *)identifier sessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration;

/**
 * Initializes this class with an ephemeral session configuration.
 *
 * @return Instance of this class.
 */
- (nonnull instancetype)initWithEphemeralSession SFSDK_DEPRECATED(7.3, 8.0, "Use defaultEphemeralNetwork instead");

/**
 * Initializes this class with a background session configuration.
 *
 * @return Instance of this class.
 */
- (nonnull instancetype)initWithBackgroundSession SFSDK_DEPRECATED(7.3, 8.0, "Use defaultBackgroundNetwork instead");

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
 */
+ (void)setSessionConfiguration:(nonnull NSURLSessionConfiguration *)sessionConfig SFSDK_DEPRECATED(7.3, 8.0, "Use setSessionConfiguration:identifier instead");

/**
 * Sets a session configuration to be used for network requests in Mobile SDK.
 *
 * @param sessionConfig Session configuration to be used.
 * @param identifier Identifier for the session to use this config.
 */
+ (void)setSessionConfiguration:(nonnull NSURLSessionConfiguration *)sessionConfig identifier:(nonnull NSString *)identifier;

/**
 * Delegates the creation of NSURLSession to an external object.
 *
 * @param manager Object that implements the SFNetworkSessionManaging protocol.
 */
+ (void)setSessionManager:(nonnull id<SFNetworkSessionManaging>)manager;

/**
 * Removes the default ephemeral session from `sharedSessions`.
 */
+ (void)removeSharedEphemeralSession;

/**
 * Removes the default background session from `sharedSessions`.
 */
+ (void)removeSharedBackgroundSession;

/**
 * Removes shared session for given identifier.
 *
 * @param identifier Identifier for the session.
 */
+ (void)removeSharedSessionForIdentifier:(nullable NSString *)identifier;

/**
 * Removes all shared sessions.
 */
+ (void)removeAllSharedSessions;

/**
 * Generates a unique session identifier
 */
+ (nonnull NSString *)uniqueSessionIdentifier;


@end
