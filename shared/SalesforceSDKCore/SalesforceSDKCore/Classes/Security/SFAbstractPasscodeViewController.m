/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFAbstractPasscodeViewController.h"
#import "SFSecurityLockout.h"
#import <SalesforceSecurity/SFPasscodeManager.h>
#import <SalesforceSecurity/SFPasscodeManager+Internal.h>
#import <SalesforceCommonUtils/SFInactivityTimerCenter.h>

// Public constants
NSString * const kRemainingAttemptsKey = @"remainingAttempts";
NSUInteger const kMaxNumberofAttempts = 10;

@interface SFAbstractPasscodeViewController ()

/**
 * The number of remaining attempts to validate the passcode.
 */
@property (readwrite) NSInteger remainingAttempts;

/**
 * Stores a new or validated passcode, resets the passcode validation flow data, etc.
 * @param passcode The new or validated passcode to persist.
 */
- (void)setupPasscode:(NSString *)passcode;

@end

@implementation SFAbstractPasscodeViewController

@synthesize minPasscodeLength = _minPasscodeLength;
@synthesize mode = _mode;

- (id)initWithMode:(SFPasscodeControllerMode)mode minPasscodeLength:(NSInteger)minPasscodeLength
{
    self = [super init];
    if (self) {
        _mode = mode;
        _minPasscodeLength = minPasscodeLength;
        if (mode == SFPasscodeControllerModeCreate || mode == SFPasscodeControllerModeChange) {
            NSAssert(_minPasscodeLength > 0, @"You must specify a positive pin code length when creating a pin code.");
        } else {
            if (0 == self.remainingAttempts) {
                self.remainingAttempts = kMaxNumberofAttempts;
            }
        }
    }
    return self;
}

- (void)createPasscodeConfirmed:(NSString *)newPasscode
{
    [self setupPasscode:newPasscode];
}

- (void)validatePasscodeConfirmed:(NSString *)validPasscode
{
    [[SFPasscodeManager sharedManager] setEncryptionKeyForPasscode:validPasscode];
    [self setupPasscode:validPasscode];
}

- (BOOL)decrementPasscodeAttempts
{
    self.remainingAttempts -= 1;
    BOOL morePasscodeAttempts = (self.remainingAttempts > 0);
    if (!morePasscodeAttempts) {
        [self validatePasscodeFailed];
    }
    
    return morePasscodeAttempts;
}

- (void)validatePasscodeFailed
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.remainingAttempts = kMaxNumberofAttempts;
        [[SFPasscodeManager sharedManager] resetPasscode];
        [SFSecurityLockout unlock:NO action:SFSecurityLockoutActionNone];
    });
}

- (NSInteger)remainingAttempts
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:kRemainingAttemptsKey];
}

- (void)setRemainingAttempts:(NSInteger)remainingAttempts
{
    [[NSUserDefaults standardUserDefaults] setInteger:remainingAttempts forKey:kRemainingAttemptsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Private methods

- (void)setupPasscode:(NSString *)passcode
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.remainingAttempts = kMaxNumberofAttempts;
        [[SFPasscodeManager sharedManager] changePasscode:passcode];
        [SFSecurityLockout setupTimer];
        [SFInactivityTimerCenter updateActivityTimestamp];
        SFSecurityLockoutAction action = [self controllerModeToLockoutAction];
        [SFSecurityLockout unlock:YES action:action];
    });
}

- (SFSecurityLockoutAction)controllerModeToLockoutAction
{
    SFSecurityLockoutAction action;
    switch (self.mode) {
        case SFPasscodeControllerModeChange:
            action = SFSecurityLockoutActionPasscodeChanged;
            break;
        case SFPasscodeControllerModeCreate:
            action = SFSecurityLockoutActionPasscodeCreated;
            break;
        case SFPasscodeControllerModeVerify:
            action = SFSecurityLockoutActionPasscodeVerified;
            break;
        default:
            [self log:SFLogLevelError format:@"Unknown passcode controller mode: %d.  No security lockout action will be configured.", self.mode];
            action = SFSecurityLockoutActionNone;
            break;
    }
    
    return action;
}

@end
