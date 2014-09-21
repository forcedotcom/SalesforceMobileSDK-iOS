//
//  SFTestSDKManagerFlow.m
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 9/20/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SFTestSDKManagerFlow.h"

static NSTimeInterval const kMaxLaunchWaitTime = 30.0;

@interface SFTestSDKManagerFlow ()

@property (nonatomic, assign) NSTimeInterval stepTimeDelaySecs;

@end

@implementation SFTestSDKManagerFlow

- (id)initWithStepTimeDelaySecs:(NSTimeInterval)timeDelayInSecs
{
    self = [super init];
    if (self) {
        self.stepTimeDelaySecs = timeDelayInSecs;
    }
    return self;
}

#pragma mark - Public methods

- (void)resumeAuth
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, self.stepTimeDelaySecs * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self log:SFLogLevelDebug msg:@"Finishing auth validation."];
        [[SalesforceSDKManager sharedManager] authValidatedToPostAuth:SFSDKLaunchActionAuthenticated];
    });
}

- (BOOL)waitForLaunchCompletion
{
    NSDate *startTime = [NSDate date];
    while ([SalesforceSDKManager sharedManager].isLaunching) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        if (elapsed > kMaxLaunchWaitTime) {
            [self log:SFLogLevelDebug format:@"Launch took too long (> %f secs) to complete.", elapsed];
            return NO;
        }
        
        [self log:SFLogLevelDebug msg:@"## waitForLaunch sleeping..."];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    return YES;
}

#pragma mark - SalesforceSDKManagerFlow

- (void)passcodeValidationAtLaunch
{
    [self log:SFLogLevelDebug msg:@"Entering passcode validation."];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, self.stepTimeDelaySecs * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self log:SFLogLevelDebug msg:@"Finishing passcode validation."];
        [[SalesforceSDKManager sharedManager] passcodeValidatedToAuthValidation];
    });
}

- (void)authValidationAtLaunch
{
    [self log:SFLogLevelDebug msg:@"Entering auth validation."];
    if (!self.pauseInAuth) {
        [self resumeAuth];
    }
}

- (void)handleAppForeground:(NSNotification *)notification
{
    
}

- (void)handleAppBackground:(NSNotification *)notification
{
    
}

- (void)handlePostLogout
{
    
}

- (void)handleAppTerminate:(NSNotification *)notification
{
    
}

- (void)handleAuthCompleted:(NSNotification *)notification
{
    
}

- (void)handleUserSwitch:(SFUserAccount *)fromUser toUser:(SFUserAccount *)toUser
{
    
}

@end
