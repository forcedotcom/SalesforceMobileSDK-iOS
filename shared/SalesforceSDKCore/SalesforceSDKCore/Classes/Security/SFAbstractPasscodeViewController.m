//
//  SFAbstractPasscodeViewController.m
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 1/13/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SFAbstractPasscodeViewController.h"
#import "SFSecurityLockout.h"
#import "SFPasscodeManager.h"
#import "SFPasscodeManager+Internal.h"
#import <SalesforceCommonUtils/SFInactivityTimerCenter.h>

@interface SFAbstractPasscodeViewController ()

- (void)setupPasscode:(NSString *)passcode;

@end

@implementation SFAbstractPasscodeViewController

@synthesize minPasscodeLength = _minPasscodeLength;
@synthesize mode = _mode;
@synthesize numAttempts = _numAttempts;

- (id)initWithMode:(SFPasscodeControllerMode)mode minPasscodeLength:(NSInteger)minPasscodeLength
{
    self = [super init];
    if (self) {
        _mode = mode;
        _minPasscodeLength = minPasscodeLength;
        
        if (mode == SFPasscodeControllerModeCreate) {
            NSAssert(_minPasscodeLength > 0, @"You must specify a positive pin code length when creating a pin code.");
        } else {
            _numAttempts = [self remainingAttempts];
            if (0 == _numAttempts) {
                _numAttempts = kMaxNumberofAttempts;
                [self setRemainingAttempts:_numAttempts];
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
    _numAttempts -= 1;
    [self setRemainingAttempts:_numAttempts];
    BOOL morePasscodeAttempts = (_numAttempts > 0);
    if (!morePasscodeAttempts) {
        [self validatePasscodeFailed];
    }
    
    return morePasscodeAttempts;
}

- (void)validatePasscodeFailed
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setRemainingAttempts:kMaxNumberofAttempts];
        [[SFPasscodeManager sharedManager] resetPasscode];
        [SFSecurityLockout unlock:NO];
    });
}

- (NSInteger)remainingAttempts
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:kRemainingAttemptsKey];
}

- (void)setRemainingAttempts:(NSUInteger)remainingAttempts
{
    [[NSUserDefaults standardUserDefaults] setInteger:remainingAttempts forKey:kRemainingAttemptsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Private methods

- (void)setupPasscode:(NSString *)passcode
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setRemainingAttempts:kMaxNumberofAttempts];
        [SFSecurityLockout setPasscode:passcode];
        [SFSecurityLockout setupTimer];
        [SFInactivityTimerCenter updateActivityTimestamp];
        [SFSecurityLockout unlock:YES];
    });
}

@end
