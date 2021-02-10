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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <SalesforceSDKCore/SFAppLockViewControllerTypes.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>

NS_ASSUME_NONNULL_BEGIN

/**
 The action that was taken as the result of calling into the security lockout functionality.
 Note: This value should denote the action actually taken, as opposed to an expected action
 going in.  Callbacks will use this value to determine what action took place.
 */
typedef NS_ENUM(NSUInteger, SFSecurityLockoutAction) {
    /**
     No action taken
     */
    SFSecurityLockoutActionNone = 0,
    
    /**
     Passcode creation functionality was called.
     */
    SFSecurityLockoutActionPasscodeCreated,
    
    /**
     Passcode change functionality was called.
     */
    SFSecurityLockoutActionPasscodeChanged,
    
    /**
     Passcode verification functionality was called.
     */
    SFSecurityLockoutActionPasscodeVerified,
    
    /**
     Passcode removal functionality was called.
     */
    SFSecurityLockoutActionPasscodeRemoved,
    
    /**
     Biometric creation functionality was called.
     */
    SFSecurityLockoutActionBiometricEnabled,
    
    /**
     Biometric verification functionality was called.
     */
    SFSecurityLockoutActionBiometricVerified
};

/**
 The state of biometric unlock.
 */
typedef NS_ENUM(NSUInteger, SFBiometricUnlockState) {
    /**
     Biometric unlock was approved by user.
     **/
    SFBiometricUnlockApproved,
    
    /**
     Biometric unlock was declined by user - do not prompt user again.
     **/
    SFBiometricUnlockDeclined,
    
    /**
     Biometric unlock is available - but user has not been prompted to approve it yet.
     **/
    SFBiometricUnlockAvailable,
    
    /**
     Biometric unlock is not available.
     */
    SFBiometricUnlockUnavailable
} NS_SWIFT_NAME(BiometricUnlockState);

@class SFSDKAppLockViewConfig;

/** Notification sent when the passcode or biometric screen will be displayed.
 */
extern NSString * const kSFPasscodeFlowWillBegin;

/** Notification sent when the passcode or biometric flow has completed.
 */
extern NSString * const kSFPasscodeFlowCompleted;

/**
 Block typedef for post-passcode screen success callback.
 */
typedef void (^SFLockScreenSuccessCallbackBlock)(SFSecurityLockoutAction);

/**
 Block typedef for post-passcode screen failure callback.
 */
typedef void (^SFLockScreenFailureCallbackBlock)(void);

@class SFOAuthCredentials;
@class SFUserAccount;
/**
 This class interacts with the inactivity timer.
 It is responsible for locking and unlocking the device by presenting the passcode modal controller when the timer expires.
 */
@interface SFSecurityLockout : NSObject

/**
 Setup passcode view related preferences.
 */
@property (nonatomic,strong,class) SFSDKAppLockViewConfig *passcodeViewConfig;

/**
 The current state of biometric unlock.
 @return biometric unlock state.
 */
+ (SFBiometricUnlockState)biometricState;

/**
 Set the passcode length, lockout time and if biometric is enabled.  This asynchronous method will trigger
 passcode creation or passcode change, and biometric enablement prompt when necessary.
 @param newPasscodeLength The new passcode length to configure.  This can only be greater than or equal
 to the currently configured length, to support the most restrictive passcode policy across users.
 @param newLockoutTime The new lockout time to configure.  This can only be less than the currently
 configured time, to support the most restrictive passcode policy across users.
 @param newBiometricAllowed Wether biometric unlock is enabled in the org.
 */
+ (void)setInactivityConfiguration:(NSUInteger)newPasscodeLength lockoutTime:(NSUInteger)newLockoutTime biometricAllowed:(BOOL)newBiometricAllowed;

/** Check if passcode is enabled.
 @return `YES` if passcode is enabled and required.
 */
+ (BOOL)isLockoutEnabled;

/** Indicates if the inactivity period has expired.
 @return `YES` if the inactivity timeout has expired, otherwise `NO`.
 */
+ (BOOL)inactivityExpired;

/**
 Starts monitoring for user activity, to determine activity expiration and passcode screen display.
 */
+ (void)startActivityMonitoring;

/**
 Stops monitoring for user activity.
 */
+ (void)stopActivityMonitoring;

/** Lock the device immediately.
 */
+ (void)lock;

 /** Whether or not a passcode has been set.
 */
+ (BOOL)isPasscodeSet;

/** Whether screen should be locked or not.
 */
+ (BOOL)shouldLock;

/** Whether the device has the capability to use biometric unlock.
 */
+ (BOOL)deviceHasBiometric;

/**
 Sets the callback block to be called on any action that triggers screen lock, and unlocks
 successfully.  Optional.
 @param block The block to be executed on successful unlock.
 */
+ (void)setLockScreenSuccessCallbackBlock:(SFLockScreenSuccessCallbackBlock _Nullable)block;

/**
 Returns the callback block to be executed on successful screen unlock.
 */
+ (SFLockScreenSuccessCallbackBlock)lockScreenSuccessCallbackBlock;

/**
 Sets the callback block to be called on any action that triggers screen lock, and fails to
 verify the passcode to unlock the screen.  Optional.
 @param block The block to be executed on a failed unlock.
 */
+ (void)setLockScreenFailureCallbackBlock:(nullable SFLockScreenFailureCallbackBlock)block;

/**
 Returns the callback block to be executed on a screen unlock failure.
 */
+ (SFLockScreenFailureCallbackBlock)lockScreenFailureCallbackBlock;

/**
 Presents the biometric enrollment view controller block.
 This can be used to prompt the user to enable biometric unlock if it was denied upon inital login or upgrade.
 @param viewConfig SFSDKPasscodeViewConfig used to create the view controller.  Supply nil to use the current SFSDKPasscodeViewConfig.
 */
+ (void)presentBiometricEnrollment:(nullable SFSDKAppLockViewConfig *)viewConfig;

/**
 * Set the response of the user being prompted to use biometric unlock.
 * @param userAllowedBiometric YES if the user accepted, NO otherwise.
 */
+ (void)userAllowedBiometricUnlock:(BOOL)userAllowedBiometric;

@end

NS_ASSUME_NONNULL_END
