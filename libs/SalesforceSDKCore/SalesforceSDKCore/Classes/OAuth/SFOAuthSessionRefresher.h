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

@class SFOAuthCredentials;

/**
 * Error codes for refresh failures.
 */
typedef NS_ENUM(NSUInteger, SFOAuthSessionRefreshErrorCode) {
    SFOAuthSessionRefreshErrorCodeInvalidCredentials = 766,
};

/** This class refreshes stale OAuth sessions, if possible.
 */
@interface SFOAuthSessionRefresher : NSObject

/**
 * Initializes the object with the given credentials.
 * @param credentials The OAuth credentials used to refresh the session.
 */
- (instancetype)initWithCredentials:(SFOAuthCredentials *)credentials NS_DESIGNATED_INITIALIZER;

/**
 * Refreshes the expired session, with the given completion and error handler blocks.
 * @param completionBlock Called once the session has been refreshed.
 * @param errorBlock Called if there was an error refreshing the session.
 */
- (void)refreshSessionWithCompletion:(void (^) (SFOAuthCredentials *))completionBlock error:(void (^) (NSError *))errorBlock;

@end
