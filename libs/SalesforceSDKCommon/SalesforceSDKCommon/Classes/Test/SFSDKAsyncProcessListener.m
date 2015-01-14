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

#import "SFSDKAsyncProcessListener.h"

static NSTimeInterval const kDefaultWaitTimeout = 5.0;

@interface SFSDKAsyncProcessListener ()

@property (nonatomic, strong) id exectedStatus;
@property (nonatomic, copy) id (^actualStatusBlock)(void);
@property (nonatomic, assign) NSTimeInterval timeout;

@end

@implementation SFSDKAsyncProcessListener

@synthesize exectedStatus = _exectedStatus;
@synthesize actualStatusBlock = _actualStatusBlock;
@synthesize timeout = _timeout;

- (id)initWithExpectedStatus:(id)expectedStatus actualStatusBlock:(id (^)(void))actualStatusBlock timeout:(NSTimeInterval)timeout {
    self = [super init];
    if (self) {
        NSAssert(expectedStatus != nil, @"expectedStatus value should be non-nil");
        NSAssert(actualStatusBlock != NULL, @"Must specify a block to return the actual status.");
        self.exectedStatus = expectedStatus;
        self.actualStatusBlock = actualStatusBlock;
        self.timeout = (timeout > 0 ? timeout : kDefaultWaitTimeout);
    }
    return self;
}

- (id)waitForCompletion {
    NSDate *startTime = [NSDate date];
    id actualStatus = self.actualStatusBlock();
    while (![self.exectedStatus isEqual:actualStatus]) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        if (elapsed > self.timeout) {
            NSLog(@"%@|%@: Async process took too long (> %f secs) to complete.", NSStringFromClass([self class]), NSStringFromSelector(_cmd), elapsed);
            return actualStatus;
        }
        
        NSLog(@"%@|%@: Expected %@, got %@.  ## sleeping...", NSStringFromClass([self class]), NSStringFromSelector(_cmd), self.exectedStatus, actualStatus);
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        actualStatus = self.actualStatusBlock();
    }
    
    return actualStatus;
}

@end
