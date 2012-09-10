/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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
#import "SFOAuthCoordinator.h"
#import "SFOAuthInfo.h"
#import "SFRestAPI.h"

@class RKRequestDelegateWrapper;

@interface SFSessionRefresher : NSObject <SFOAuthCoordinatorDelegate> {
    id<SFOAuthCoordinatorDelegate> _previousOAuthDelegate;
    NSMutableSet *_queuedRequests;
    NSLock *_refreshLock;
    BOOL    _isRefreshing;
}

@property (nonatomic, assign) id<SFOAuthCoordinatorDelegate> previousOAuthDelegate;

@property (nonatomic, assign) BOOL isRefreshing;

/**
 * Tell the session refresher that this request failed due to oauth failure--
 * this will kickoff a refresh of the access token if needed, and cause the
 * request to be replayed when a new valid access token is available.
 */
- (void)requestFailedUnauthorized:(RKRequestDelegateWrapper*)req;

@end
