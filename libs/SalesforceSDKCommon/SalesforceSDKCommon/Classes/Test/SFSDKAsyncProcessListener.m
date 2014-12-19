//
//  SFSDKAsyncProcessListener.m
//  SalesforceSDKCommon
//
//  Created by Kevin Hawkins on 12/18/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

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
