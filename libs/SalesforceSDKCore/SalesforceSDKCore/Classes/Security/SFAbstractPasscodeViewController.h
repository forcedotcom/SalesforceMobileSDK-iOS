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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SFSecurityLockout.h"
#import "SFPasscodeViewControllerTypes.h"

/**
 * Key associated with the storage and retrieval of remaining passcode validation attempts.
 */
extern NSString * const kRemainingAttemptsKey;

/**
 * The maximum number of allowed passcode validation attempts.
 */
extern const NSUInteger kMaxNumberofAttempts;

/**
 * Base class for passcode screen view controllers.
 */
@interface SFAbstractPasscodeViewController : UIViewController

/**
 * The configuration data used to create or update the passcode.
 */
@property (readonly) SFPasscodeConfigurationData configData;

/**
 * The minimum passcode length, which this view controller will enforce.
 */
@property (readonly) NSInteger minPasscodeLength;

/**
 * Whether or not this controller is in a passcode creation or verification mode.
 */
@property (readonly) SFPasscodeControllerMode mode;

/**
 * The number of attempts left to successfully verify the passcode, before the user is logged out.
 */
@property (readonly) NSInteger remainingAttempts;

/**
 * Designated initializer for SFAbstractPasscodeViewController.
 * @param mode The mode of the passcode screen, either passcode creation or passcode verification.
 * @param configData The passcode configuration data used to create or update the passcode.
 */
- (id)initWithMode:(SFPasscodeControllerMode)mode passcodeConfig:(SFPasscodeConfigurationData)configData;

/**
 * Method to be called after the creation of the passcode is confirmed to be successful.
 * @param newPasscode The created passcode, which will be stored and managed by the SDK.
 */
- (void)createPasscodeConfirmed:(NSString *)newPasscode;

/**
 * Method to be called after passcode validation is confirmed to be successful.  This will reset the
 * passcode logic, unlock the screen, and send the app into its subsequent unlocked behavior.
 * @param validPasscode The successfully validated passcode.
 */
- (void)validatePasscodeConfirmed:(NSString *)validPasscode;

/**
 * Method to be called after an attempt to validate the passcode has failed, decrementing the number
 * of attempts, and initiating the ultimate failure logic of validatePasscodeFailed if no attempts
 * remain.
 * @return YES if there are remaining attempts available to validate the passcode.  NO otherwise.
 */
- (BOOL)decrementPasscodeAttempts;

/**
 * Method to be called if all allowed attempts to validate the passcode have failed.  The method
 * decrementPasscodeAttempts will call this method automatically, so inheriting classes do not
 * need to do so.
 */
- (void)validatePasscodeFailed;

/**
 * Method returns touch id can be shown
 * Touch id can only be shown on device that supports it and the passcode has been entered manually since app was launched
 */
- (BOOL) canShowTouchId;

/**
 * Method to bring up touch id to authenticate device owner
 * If successful, the app will be unlocked
 * Will do nothing if touch id is supported on the device or the passcode has never been entered manually since app was launched
 */
- (void) showTouchId;

@end
