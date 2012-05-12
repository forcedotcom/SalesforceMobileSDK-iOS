/*
 SecurityLockout.h
 Chatter
 Created by Amol Prabhu on 10/6/11.
 Copyright 2011 Salesforce.com. All rights reserved.
 */

#import <Foundation/Foundation.h>

static const NSUInteger kMaxNumberofAttempts = 10;
static NSString * const kRemainingAttemptsKey = @"remainingAttempts"; 
extern NSString * const kKeychainIdentifierPasscode;

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
 */
+ (void)unlock;

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

/** Reset the passcode in the keychain
 */
+ (void)resetPasscode;

/** Get the hashed passcode from the keychain
 */
+ (NSString *)hashedPasscode;

/** Set the passcode
 @param passcode The passcode to set.
 */
+ (void)setPasscode:(NSString *)passcode;

/** Verify the passcode
 @param passcode The passcode to verify.
 */
+ (BOOL)verifyPasscode:(NSString *)passcode;

/** Show the passcode view. Used by unit tests.
 */
+ (void)setCanShowPasscode:(BOOL)showPasscode;

@end


