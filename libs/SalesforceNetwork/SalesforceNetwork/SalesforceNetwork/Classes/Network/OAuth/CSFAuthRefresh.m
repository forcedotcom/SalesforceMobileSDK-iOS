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

#import "CSFAuthRefresh+Internal.h"
#import "CSFInternalDefines.h"

static NSMutableDictionary *CompletionBlocks = nil;
static NSMutableDictionary *RefreshingClasses = nil;
static NSObject *AuthRefreshLock = nil;

@implementation CSFAuthRefresh

+ (void)initialize {
    if (self == [CSFAuthRefresh class]) {
        CompletionBlocks = [[NSMutableDictionary alloc] init];
        RefreshingClasses = [[NSMutableDictionary alloc] init];
        AuthRefreshLock = [[NSObject alloc] init];
    }
}

- (instancetype)initWithNetwork:(CSFNetwork *)network {
    self = [super init];
    if (self) {
        self.network = network;
    }
    return self;
}

- (void)finishWithOutput:(CSFOutput *)refreshOutput error:(NSError *)error {
    if (error) {
        NetworkDebug(@"Refresh failed: %@", error);
    }

    @synchronized (AuthRefreshLock) {
		// update refreshing flag to NO up front so any request come into the network queue that requires access token does not get blocked 
        RefreshingClasses[(id<NSCopying>)[self class]] = @NO;
        NSMutableArray *classCompletionBlocks = CompletionBlocks[[self class]];
        if (classCompletionBlocks) {
            // make a safe copy so that we don't run into any possibility of array being mutated while
            // enumerating
            NSArray *safeCopy = [classCompletionBlocks copy];
            [classCompletionBlocks removeAllObjects];
            for (CSFAuthRefreshCompletionBlock completionBlock in safeCopy) {
                completionBlock(refreshOutput, error);
            }
        }
    }
}

- (void)refreshAuthWithCompletionBlock:(CSFAuthRefreshCompletionBlock)completionBlock {
    @synchronized (AuthRefreshLock) {
        if (CompletionBlocks[[self class]] == nil) {
            CompletionBlocks[(id<NSCopying>)[self class]] = [[NSMutableArray alloc] init];
        }
        
        NSMutableArray *classCompletionBlocks = CompletionBlocks[[self class]];
        [classCompletionBlocks addObject:[completionBlock copy]];
        if (classCompletionBlocks.count == 1) {
            // First refresh request will fire off the actual refresh.  All subsequent
            // requests have their completion blocks queued for the refresh completion.
            NetworkInfo(@"Initiating auth refresh.");
            RefreshingClasses[(id<NSCopying>)[self class]] = @YES;
            [self refreshAuth];
        }
    }
}

+ (BOOL)isRefreshing {
    BOOL result = NO;
    @synchronized (AuthRefreshLock) {
        NSNumber *value = RefreshingClasses[self];
        if (value && [value boolValue]) {
            result = YES;
        }
    }
    return result;
}

- (void)refreshAuth {
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

@end
