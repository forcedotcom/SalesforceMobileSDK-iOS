/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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
        [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"Finishing auth."];
        [[SalesforceSDKManager sharedManager] authValidatedToPostAuth:SFSDKLaunchActionAuthenticated];
    });
}

- (void)resumeAuthBypass
{
    SFSDKLaunchAction launchAction = ([SalesforceSDKManager sharedManager].authenticateAtLaunch
                                      ? SFSDKLaunchActionAlreadyAuthenticated
                                      : SFSDKLaunchActionAuthBypassed);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, self.stepTimeDelaySecs * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"Finishing auth bypass."];
        [[SalesforceSDKManager sharedManager] authValidatedToPostAuth:launchAction];
    });
}

- (BOOL)waitForLaunchCompletion
{
    NSDate *startTime = [NSDate date];
    while ([SalesforceSDKManager sharedManager].isLaunching) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        if (elapsed > kMaxLaunchWaitTime) {
            [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"Launch took too long (> %f secs) to complete.", elapsed];
            return NO;
        }
        
        [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"## waitForLaunch sleeping..."];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    return YES;
}

#pragma mark - SalesforceSDKManagerFlow

- (void)passcodeValidationAtLaunch
{
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"Entering passcode validation."];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, self.stepTimeDelaySecs * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"Finishing passcode validation."];
        [[SalesforceSDKManager sharedManager] passcodeValidatedToAuthValidation];
    });
}

- (void)authAtLaunch
{
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"Entering auth at launch."];
    if (!self.pauseInAuth) {
        [self resumeAuth];
    }
}

- (void)authBypassAtLaunch
{
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"Entering auth at launch."];
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
