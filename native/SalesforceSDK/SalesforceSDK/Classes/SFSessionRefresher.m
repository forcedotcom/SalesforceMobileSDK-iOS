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

#import "SFSessionRefresher.h"

#import "RKRequestDelegateWrapper.h"

@interface SFSessionRefresher (Private)

- (void)refreshAccessToken;

/**
 * Ensure that the original OAuth coordinator delegate, if any, is restored.
 */
- (void)restoreOAuthDelegate;

/**
 * Retry all the queued requests that previously self-reported as unauthorized
 */
- (void)replayQueuedRequests;

/**
 * Fail all queued requests with the error provided.
 */
- (void)failQueuedRequestsWithError:(NSError *)error;

@end


@implementation SFSessionRefresher

@synthesize previousOAuthDelegate = _previousOAuthDelegate;
@synthesize isRefreshing = _isRefreshing;

- (id)init {
    self = [super init];
    if (nil != self) {
        self.isRefreshing = NO;
        _queuedRequests = [[NSMutableSet alloc] initWithCapacity:5];
    }
    
    return self;
}

- (void)dealloc {
    [self restoreOAuthDelegate];
    [_queuedRequests release]; _queuedRequests = nil;
    [super dealloc];
}

#pragma mark - Public

- (void)requestFailedUnauthorized:(RKRequestDelegateWrapper*)req {
    [_queuedRequests addObject:req];
    //check whether we're fetching new access token, kickoff if needed
    [self refreshAccessToken];
}


#pragma mark - Private

- (void)restoreOAuthDelegate {
    if (nil != self.previousOAuthDelegate) {
        [SFRestAPI sharedInstance].coordinator.delegate = self.previousOAuthDelegate;
        self.previousOAuthDelegate = nil;
    }
}

- (void)refreshAccessToken {
    if (!self.isRefreshing) {
        self.isRefreshing = YES;
        NSLog(@"Refreshing access token");
        SFOAuthCoordinator *coord = [SFRestAPI sharedInstance].coordinator;

        // let's refresh the token
        // but first, let's save the previous delegate
        self.previousOAuthDelegate = coord.delegate;
        coord.credentials.accessToken = nil;
        coord.delegate = self;
        [coord authenticate];
    }
}


#pragma mark - SFOAuthCoordinatorDelegate



- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:willBeginAuthenticationWithView");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:didBeginAuthenticationWithView");    
    // we are in the token exchange flow so this should never happen
    //TODO we should probably hand back control to the original coordinator delegate at this point,
    //since we don't expect to be able to handle this condition!
    [self restoreOAuthDelegate];
    [coordinator stopAuthentication];
    NSError *newError = [NSError errorWithDomain:kSFOAuthErrorDomain code:kSFRestErrorCode userInfo:nil];
    [self failQueuedRequestsWithError:newError];
    
    // we are creating a temp view here since the oauth library verifies that the view
    // has a subview after calling oauthCoordinator:didBeginAuthenticationWithView:
    UIView *tempView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
    [tempView addSubview:view];    
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator {
    NSLog(@"oauthCoordinatorDidAuthenticate");
    
    // the token exchange worked.
    [self restoreOAuthDelegate];
    [self replayQueuedRequests];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error {
    NSLog(@"oauthCoordinator:didFailWithError: %@", error);
    
    // oauth error
    [self restoreOAuthDelegate];
    [coordinator stopAuthentication];
    NSError *newError = [NSError errorWithDomain:kSFOAuthErrorDomain code:kSFRestErrorCode userInfo:[error userInfo]];
    [self failQueuedRequestsWithError:newError];
}

#pragma mark - Completion

- (void)replayQueuedRequests {
    //replay all the queued requests
    NSArray *allRequests = [_queuedRequests allObjects]; //no ordering preserved
    NSLog(@"replaying %d requests",[allRequests count]);
    
    for (RKRequestDelegateWrapper *req in allRequests) {
        @try {
            [req send];
        }
        @catch (NSException *ex) {
            NSLog(@"unable to replay request: %@ ex: %@",req,ex);
        }
    }
    
    [_queuedRequests removeAllObjects];
    self.isRefreshing = NO;
}

- (void)failQueuedRequestsWithError:(NSError *)error {
    NSArray *allRequests = [_queuedRequests allObjects]; //no ordering preserved
    NSLog(@"failing %d requests",[allRequests count]);
    for (RKRequestDelegateWrapper *req in allRequests) {
        @try {
            [req request:nil didFailLoadWithError:error];
        }
        @catch (NSException *ex) {
            NSLog(@"unable to fail request: %@ ex: %@",req,ex);
        }
    }
    
    [_queuedRequests removeAllObjects];
    self.isRefreshing = NO;
}
@end
