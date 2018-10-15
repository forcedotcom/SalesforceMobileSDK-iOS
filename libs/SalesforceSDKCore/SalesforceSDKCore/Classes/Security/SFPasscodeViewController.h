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

#import <UIKit/UIKit.h>
#import "SFAbstractPasscodeViewController.h"
//#import "SFSDKPasscodeViewControllerConfig.h"

@class SFPasscodeViewController;
@class SFSDKPasscodeViewControllerConfig;

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for the owner of SFPasscodeViewController.
 */
NS_SWIFT_NAME(PasscodeViewControllerDelegate)
@protocol SFPasscodeViewControllerDelegate <NSObject>

@optional

/**
 * Warning - only use this setting if the app has always enforced a passcode of the exact length of
 *           the connected app setting (not longer).  This setting is used to force a cleaner UI,
 *           but users will be unable to unlock the app if their pin is longer than the specified
 *           length.
 * @param passcodeGuaranteedMinLength Has the user ever been allowed to create a passcode longer
 *                                    than the minimum length.  
 */
- (void)forcePasscodeIsMinLength:(BOOL)passcodeGuaranteedMinLength;

@end

/**
 * The view controller for managing the passcode screen.
 */
NS_SWIFT_NAME(PasscodeViewController)
@interface SFPasscodeViewController : SFAbstractPasscodeViewController <UITextFieldDelegate>

/**
 * Initializes the controller for verifying an existing passcode.
 */
- (id)initForPasscodeVerification;

/**
 * Initializes the controller for creating a new passcode.
 * @param configData Configuration for the new passcode.
 */
- (id)initForPasscodeCreation:(SFPasscodeConfigurationData)configData;

/**
 * Initializes the controller for changing the existing passcode.
 * @param configData Configuration for the new passcode.
 */
- (id)initForPasscodeChange:(SFPasscodeConfigurationData)configData;

/**
 * Initializes the controller for verifying a existing biometric signature.
 */
- (id)initForBiometricVerification;

/**
 * Initializes the controller for displaying the biometric option to the user.
 */
- (id)initForBiometricEnablement;

/**
 * Method returns biometric can be shown
 * Biometric can only be shown on device that supports it, with org setting not disabled and valid
 * passcode set.
 * @return YES if biometric prompt can be show.  NO otherwise.
 */
- (BOOL) canShowBiometricEnrollmentScreen;

@end

NS_ASSUME_NONNULL_END
