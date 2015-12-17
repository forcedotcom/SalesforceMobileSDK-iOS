/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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
#import "SFIdentityCoordinator.h"

@class SFIdentityData;
@class SFOAuthSessionRefresher;

/**
 * Internal interface for the SFIdentityCoordinator.
 */
@interface SFIdentityCoordinator ()

/**
 * Whether or not a request is already in progress.
 */
@property (assign) BOOL retrievingData;

/**
 * The NSURLSession associated with the ID request.
 */
@property (nonatomic, strong) NSURLSession *session;

/**
 * The OAuth sesssion refresher to use if the identity request fails with expired credentials.
 */
@property (nonatomic, strong) SFOAuthSessionRefresher *oauthSessionRefresher;

/**
 * Dictionary mapping error codes to their respective types.
 */
@property (strong, nonatomic, readonly) NSDictionary *typeToCodeDict;

/**
 * Triggers the success notifictation to the delegate.
 */
- (void)notifyDelegateOfSuccess;

/**
 * Triggers the failure notification and error to the delegate.
 */
- (void)notifyDelegateOfFailure:(NSError *)error;

/**
 * Sends the request to the identity service, and processes the response.
 */
- (void)sendRequest;

/**
 * Process a completed response from the service, populating the ID data.
 */
- (void)processResponse:(NSData *)responseData;

/**
 * Cleans up the in-process properties and vars, once a request is completed.
 */
- (void)cleanupData;

/**
 * Creates an NSError instance based on type and description, for notifying the delegate
 * of a failure.
 */
- (NSError *)errorWithType:(NSString *)type description:(NSString *)description;

@end
