//
//  SFTestSDKManagerFlow.m
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 9/20/14.
//  Copyright (c) 2014-present, salesforce.com. All rights reserved.
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
        [self log:SFLogLevelDebug msg:@"Finishing auth."];
        [[SalesforceSDKManager sharedManager] authValidatedToPostAuth:SFSDKLaunchActionAuthenticated];
    });
}

- (void)resumeAuthBypass
{
    SFSDKLaunchAction launchAction = ([SalesforceSDKManager sharedManager].authenticateAtLaunch
                                      ? SFSDKLaunchActionAlreadyAuthenticated
                                      : SFSDKLaunchActionAuthBypassed);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, self.stepTimeDelaySecs * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self log:SFLogLevelDebug msg:@"Finishing auth bypass."];
        [[SalesforceSDKManager sharedManager] authValidatedToPostAuth:launchAction];
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

- (void)authAtLaunch
{
    [self log:SFLogLevelDebug msg:@"Entering auth at launch."];
    if (!self.pauseInAuth) {
        [self resumeAuth];
    }
}

- (void)authBypassAtLaunch
{
    [self log:SFLogLevelDebug msg:@"Entering auth at launch."];
    if (!self.pauseInAuth) {
        [self resumeAuthBypass];
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

- (void)handleAppDidBecomeActive:(NSNotification *)notification
{
    
}

- (void)handleAppWillResignActive:(NSNotification *)notification
{
    
}

- (void)handleAuthCompleted:(NSNotification *)notification
{
    
}

- (void)handleUserSwitch:(SFUserAccount *)fromUser toUser:(SFUserAccount *)toUser
{
    
}

@end
