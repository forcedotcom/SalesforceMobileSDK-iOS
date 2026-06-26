/*
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.

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

NS_ASSUME_NONNULL_BEGIN

@class SFOAuthCredentials;
@class SFOAuthSessionRefresher;

/**
 * Centralized coordinator that ensures at most one token refresh request is in-flight
 * per credential at any given time. Concurrent callers for the same credential are
 * coalesced: the first triggers the refresh, and subsequent callers wait for the same result.
 *
 * This prevents the "double-spend" race condition when using single-use (rotating) refresh tokens,
 * where concurrent refresh attempts would invalidate each other's tokens.
 */
@interface SFSDKTokenRefreshCoordinator : NSObject

/**
 * Shared singleton instance.
 */
@property (class, nonatomic, readonly) SFSDKTokenRefreshCoordinator *sharedInstance;

/**
 * Request a token refresh for the given credentials.
 *
 * If a refresh is already in-flight for these credentials (keyed by `credentials.identifier`),
 * the callbacks are appended to the waiting list and no new network request is made.
 * When the single in-flight refresh completes, all registered callbacks receive the same result.
 *
 * Completion and error callbacks are dispatched on the main queue.
 *
 * @param credentials The OAuth credentials to refresh.
 * @param completionBlock Called with the updated credentials on successful refresh.
 * @param errorBlock Called with the error if the refresh fails.
 */
- (void)refreshSessionForCredentials:(SFOAuthCredentials *)credentials
                          completion:(void (^)(SFOAuthCredentials *updatedCredentials))completionBlock
                               error:(void (^)(NSError *error))errorBlock;

/**
 * Testing hook: inject a factory block to create mock SFOAuthSessionRefresher instances.
 * When nil (default), the coordinator creates a standard SFOAuthSessionRefresher.
 */
@property (nonatomic, copy, nullable) SFOAuthSessionRefresher * (^refresherFactory)(SFOAuthCredentials *);

@end

NS_ASSUME_NONNULL_END
