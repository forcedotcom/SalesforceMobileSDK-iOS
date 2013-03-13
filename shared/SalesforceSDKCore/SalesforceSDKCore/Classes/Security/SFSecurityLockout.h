/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

static const NSUInteger kMaxNumberofAttempts = 10;
static NSString * const kRemainingAttemptsKey = @"remainingAttempts";

/** Notification sent when the passcode screen will be displayed.
 */
extern NSString * const kSFPasscodeFlowWillBegin;

/** Notification sent when the passcode flow has completed.
 */
extern NSString * const kSFPasscodeFlowCompleted;

typedef void (^SFLockScreenCallbackBlock)(void);

@class SFOAuthCredentials;

/**
 This class interacts with the inactivity timer.
 It is responsible for locking and unlocking the device by presenting the passcode modal controller when the timer expires.
 */
@interface SFSecurityLockout : NSObject 

/** Get the current lockout time, in seconds
 */
+ (NSUInteger)lockoutTime;

/** Set the lockout timer.
 @param seconds The number of seconds for the timer to wait before locking.
 */
+ (void)setLockoutTime:(NSUInteger)seconds;

/** Initialize the timer
 */
+ (void)setupTimer;

/** Unregister and invalidate the timer
 */
+ (void)removeTimer; 

/** Validate the timer upon app entering the foreground
 */
+ (void)validateTimer;

/** Check if passcode is enabled.
 @return `YES` if passcode is enabled and required.
 */
+ (BOOL)isLockoutEnabled;

/** Indicates if the inactivity period has expired.
 @return `YES` if the inactivity timeout has expired, otherwise `NO`.
 */
+ (BOOL)inactivityExpired;

/** Lock the device immediately.
 */
+ (void)lock;

/** Unlock the device
 @param success Whether the device is being unlocked as the result of a successful passcode
 challenge, as opposed to unlocking to reset the application to to a failed challenge.
 */
+ (void)unlock:(BOOL)success;

/** Toggle the locked state
 @param locked Locks the device if `YES`, otherwise unlocks the device.
 */
+ (void)setIsLocked:(BOOL)locked;

/** Check if device is locked
 */
+ (BOOL)locked;

/** Check if the passcode is valid
 */
+ (BOOL)isPasscodeValid;

/** Set the passcode
 @param passcode The passcode to set.
 */
+ (void)setPasscode:(NSString *)passcode;

/** Set the required length of the passcode.
 @param passcodeLength The required length of the passcode.
 */
+ (void)setPasscodeLength:(NSInteger)passcodeLength;

/** Show the passcode view. Used by unit tests.
 */
+ (void)setCanShowPasscode:(BOOL)showPasscode;

/**
 Sets the callback block to be called on any action that triggers screen lock, and unlocks
 successfully.  Optional.
 @param block The block to be executed on successful unlock.
 */
+ (void)setLockScreenSuccessCallbackBlock:(SFLockScreenCallbackBlock)block;

/**
 Returns the callback block to be executed on successful screen unlock.
 */
+ (SFLockScreenCallbackBlock)lockScreenSuccessCallbackBlock;

/**
 Sets the callback block to be called on any action that triggers screen lock, and fails to
 verify the passcode to unlock the screen.  Optional.
 @param block The block to be executed on a failed unlock.
 */
+ (void)setLockScreenFailureCallbackBlock:(SFLockScreenCallbackBlock)block;

/**
 Returns the callback block to be executed on a screen unlock failure.
 */
+ (SFLockScreenCallbackBlock)lockScreenFailureCallbackBlock;

@end


