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

#import "SFAppLockViewControllerTypes.h"
#import "SalesforceSDKConstants.h"

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

/**
 Block typedef for creating the passcode view controller.
 */
typedef UIViewController* _Nullable  (^SFPasscodeViewControllerCreationBlock)(SFAppLockControllerMode mode,SFSDKAppLockViewConfig *viewConfig) SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 Block typedef for displaying and dismissing the passcode view controller.
 */
typedef void (^SFPasscodeViewControllerPresentationBlock)(UIViewController*) SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 Block typedef for displaying and dismissing the passcode view controller.
 */
typedef void (^SFPasscodeViewControllerDismissBlock)(UIViewController*,void(^_Nullable)(void)) SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 Delegate protocol for SFSecurityLockout events and callbacks.
 */
SFSDK_DEPRECATED(8.3, 9.0, "Use notifications or SFLockScreenSuccessCallbackBlock and SFLockScreenFailureCallbackBlock instead")
@protocol SFSecurityLockoutDelegate <NSObject>

@optional

/**
 Called just before the passcode flow begins and the view is displayed.
 @param mode The mode of the passcode or biometric flow, i.e. passcode/biometric creation or verification.
 */
- (void)passcodeFlowWillBegin:(SFAppLockControllerMode)mode;

/**
 Called after the passcode flow has completed.
 @param success Whether or not the passcode or biometric flow was successful, i.e. the passcode/biometric
 was successfully created or verified.
 */
- (void)passcodeFlowDidComplete:(BOOL)success;

@end

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
 Adds a delegate to the list of SFSecurityLockout delegates.
 @param delegate The delegate to add to the list.
 */
+ (void)addDelegate:(id<SFSecurityLockoutDelegate>)delegate SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 Removes a delegate from the list of SFSecurityLockout delegates.
 @param delegate The delegate to remove from the list.
 */
+ (void)removeDelegate:(id<SFSecurityLockoutDelegate>)delegate SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 Get the current lockout time, in seconds
 @return The lockout time limit.
 */
+ (NSUInteger)lockoutTime SFSDK_DEPRECATED(8.3, 9.0, "Will be internal.");

/**
 Gets the configured passcode length.
 @return The passcode length.
 */
+ (NSUInteger)passcodeLength SFSDK_DEPRECATED(8.3, 9.0, "Will be internal.");

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

/**
 Resets the passcode state of the app, *if* there aren't other users with an overriding passcode
 policy.  I.e. passcode state can only be cleared if the current user is the only user who would
 be subject to that policy.
 */
+ (void)clearPasscodeState SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 Resets the passcode state of the app, *if* there aren't other users with an overriding passcode
 policy.  I.e. passcode state can only be cleared if the  user is the only user who would
 be subject to that policy.
 */
+ (void)clearPasscodeState:(SFUserAccount *)userLoggingOut SFSDK_DEPRECATED(8.3, 9.0, "Will be internal.");

/** Initialize the timer
 */
+ (void)setupTimer SFSDK_DEPRECATED(8.3, 9.0, "Will be internal.");

/** Unregister and invalidate the timer
 */
+ (void)removeTimer SFSDK_DEPRECATED(8.3, 9.0, "Will be internal.");

/** Validate the timer upon app entering the foreground
 */
+ (void)validateTimer SFSDK_DEPRECATED(8.3, 9.0, "Will be internal.");

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

/** Unlock the device (e.g a result of a successful passcode/biometric challenge)
 @param action Action that was taken during lockout.
 */
+ (void)unlock:(SFSecurityLockoutAction)action SFSDK_DEPRECATED(8.3, 9.0, "Will be internal.");

/** Wipe the device (e.g. because passcode/biometric challenge failed)
*/
+ (void)wipeState SFSDK_DEPRECATED(8.3, 9.0, "Will be internal.");

/** Toggle the locked state
 @param locked Locks the device if `YES`, otherwise unlocks the device.
 */
+ (void)setIsLocked:(BOOL)locked SFSDK_DEPRECATED(8.3, 9.0, "Will be internal.");

/** Check if device is locked
 */
+ (BOOL)locked SFSDK_DEPRECATED(8.3, 9.0, "Will be internal");

/** Check if the passcode is valid
 */
+ (BOOL)isPasscodeValid SFSDK_DEPRECATED(8.3, 9.0, "Will be internal.");

/** Check to see if the passcode screen is needed.
 */
+ (BOOL)isPasscodeNeeded SFSDK_DEPRECATED(8.3, 9.0, "Use shouldLock instead.");

 /** Whether or not a passcode has been set.
 */
+ (BOOL)isPasscodeSet;

/** Whether screen should be locked or not.
 */
+ (BOOL)shouldLock;

/** Whether the device has the capability to use biometric unlock.
 */
+ (BOOL)deviceHasBiometric;

/** Show the passcode view. Used by unit tests.
 @param showPasscode If YES, passcode view can be displayed.
 */
+ (void)setCanShowPasscode:(BOOL)showPasscode SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

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
 @return The block used to create the passcode view controller
 */
+ (SFPasscodeViewControllerCreationBlock)passcodeViewControllerCreationBlock SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 Sets the block that will create the passcode view controller.
 @param vcBlock The passcode view controller creation block to use.
 */
+ (void)setPasscodeViewControllerCreationBlock:(SFPasscodeViewControllerCreationBlock)vcBlock SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 @return The block used to present the passcode view controller.
 */
+ (SFPasscodeViewControllerPresentationBlock)presentPasscodeViewControllerBlock SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 Sets the block that will present the passcode view controller.
 @param vcBlock The block to use to present the passcode view controller.
 */
+ (void)setPresentPasscodeViewControllerBlock:(SFPasscodeViewControllerPresentationBlock)vcBlock SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 Set the block that will dismiss the passcode view controller.
 @param vcBlock The block defined to dismiss the passcode view controller.
 */
+ (void)setDismissPasscodeViewControllerBlock:(SFPasscodeViewControllerDismissBlock)vcBlock SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 Sets a retained instance of the current passcode view controller that's displayed.
 @param vc The passcode view controller.
 */
+ (void)setPasscodeViewController:(nullable UIViewController *)vc SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 Presents the biometric enrollment view controller block.
 This can be used to prompt the user to enable biometric unlock if it was denied upon inital login or upgrade.
 @param viewConfig SFSDKPasscodeViewConfig used to create the view controller.  Supply nil to use the current SFSDKPasscodeViewConfig.
 */
+ (void)presentBiometricEnrollment:(nullable SFSDKAppLockViewConfig *)viewConfig;

/**
 * Returns the currently displayed passcode view controller, or nil if the passcode view controller
 * is not currently displayed.
 */
+ (UIViewController *)passcodeViewController SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 * Whether to force the passcode screen to be displayed, despite sanity conditions for whether passcodes
 * are configured.  This method is only useful for unit test code, and the value should otherwise be left
 * to its default value of NO.
 * @param forceDisplay Whether to force the passcode screen to be displayed.  Default value is NO.
 */
+ (void)setForcePasscodeDisplay:(BOOL)forceDisplay SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 * @return Whether or not the app is configured to force the display of the passcode screen.
 */
+ (BOOL)forcePasscodeDisplay SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 * @return Whether or not to validate the passcode at app startup.
 */
+ (BOOL)validatePasscodeAtStartup SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 * Set the response of the user being prompted to use biometric unlock.
 * @param userAllowedBiometric YES if the user accepted, NO otherwise.
 */
+ (void)userAllowedBiometricUnlock:(BOOL)userAllowedBiometric;

/**
 * Set the passcode length upon upgrade if it was not previously set.
 * @param length Length of the user's passcode.
 */
+ (void)setUpgradePasscodeLength:(NSUInteger)length SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

@end

NS_ASSUME_NONNULL_END
