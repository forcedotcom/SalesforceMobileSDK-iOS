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
#import <UIKit/UIKit.h>

#import "SFPasscodeViewControllerTypes.h"

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
    SFSecurityLockoutActionPasscodeRemoved
};

/**
 Struct containing passcode configuration data, including passcode length and lockout time.
 This information will generally be passed through the passcode creation/update process, to
 allow the settings to ultimately be persisted once creation/update successfully completes.
 */
typedef struct {
    NSInteger passcodeLength;
    NSUInteger lockoutTime;
} SFPasscodeConfigurationData;

/**
 Special value for an empty SFPasscodeConfigurationData object, used when configuration data
 is not necessary.
 */
extern SFPasscodeConfigurationData const SFPasscodeConfigurationDataNull;

/** Notification sent when the passcode screen will be displayed.
 */
extern NSString * const kSFPasscodeFlowWillBegin;

/** Notification sent when the passcode flow has completed.
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
typedef UIViewController* (^SFPasscodeViewControllerCreationBlock)(SFPasscodeControllerMode mode, SFPasscodeConfigurationData configData);

/**
 Block typedef for displaying and dismissing the passcode view controller.
 */
typedef void (^SFPasscodeViewControllerPresentationBlock)(UIViewController*);

/**
 Delegate protocol for SFSecurityLockout events and callbacks.
 */
@protocol SFSecurityLockoutDelegate <NSObject>

@optional

/**
 Called just before the passcode flow begins and the view is displayed.
 @param mode The mode of the passcode flow, i.e. passcode creation or verification.
 */
- (void)passcodeFlowWillBegin:(SFPasscodeControllerMode)mode;

/**
 Called after the passcode flow has completed.
 @param success Whether or not the passcode flow was successful, i.e. the passcode was successfully
 created or verified.
 */
- (void)passcodeFlowDidComplete:(BOOL)success;

@end

@class SFOAuthCredentials;

/**
 This class interacts with the inactivity timer.
 It is responsible for locking and unlocking the device by presenting the passcode modal controller when the timer expires.
 */
@interface SFSecurityLockout : NSObject

/**
 Adds a delegate to the list of SFSecurityLockout delegates.
 @param delegate The delegate to add to the list.
 */
+ (void)addDelegate:(id<SFSecurityLockoutDelegate>)delegate;

/**
 Removes a delegate from the list of SFSecurityLockout delegates.
 @param delegate The delegate to remove from the list.
 */
+ (void)removeDelegate:(id<SFSecurityLockoutDelegate>)delegate;


/** Get the current lockout time, in seconds
 */
+ (NSUInteger)lockoutTime;

/**
 Gets the configured passcode length.
 @return The minimum passcode length.
 */
+ (NSInteger)passcodeLength;

/**
 Set the passcode length and lockout time.  This asynchronous method will trigger passcode creation
 or passcode change, when necessary.
 @param newPasscodeLength The new passcode length to configure.  This can only be greater than or equal
 to the currently configured length, to support the most restrictive passcode policy across users.
 @param newLockoutTime The new lockout time to configure.  This can only be less than the currently
 configured time, to support the most restrictive passcode policy across users.
 */
+ (void)setPasscodeLength:(NSInteger)newPasscodeLength lockoutTime:(NSUInteger)newLockoutTime;

/**
 Resets the passcode state of the app, *if* there aren't other users with an overriding passcode
 policy.  I.e. passcode state can only be cleared if the current user is the only user who would
 be subject to that policy.
 */
+ (void)clearPasscodeState;

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

/** Unlock the device
 @param success Whether the device is being unlocked as the result of a successful passcode
 challenge, as opposed to unlocking to reset the application to to a failed challenge.
 @param action In a successful challenge, what was the action taken?
 @param configData The round-trip passcode configuration data used to create or update the passcode.
 */
+ (void)unlock:(BOOL)success action:(SFSecurityLockoutAction)action passcodeConfig:(SFPasscodeConfigurationData)configData;

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

/** Check to see if the passcode screen is needed.
 */
+ (BOOL)isPasscodeNeeded;

/** Show the passcode view. Used by unit tests.
 @param showPasscode If YES, passcode view can be displayed.
 */
+ (void)setCanShowPasscode:(BOOL)showPasscode;

/**
 Sets the callback block to be called on any action that triggers screen lock, and unlocks
 successfully.  Optional.
 @param block The block to be executed on successful unlock.
 */
+ (void)setLockScreenSuccessCallbackBlock:(SFLockScreenSuccessCallbackBlock)block;

/**
 Returns the callback block to be executed on successful screen unlock.
 */
+ (SFLockScreenSuccessCallbackBlock)lockScreenSuccessCallbackBlock;

/**
 Sets the callback block to be called on any action that triggers screen lock, and fails to
 verify the passcode to unlock the screen.  Optional.
 @param block The block to be executed on a failed unlock.
 */
+ (void)setLockScreenFailureCallbackBlock:(SFLockScreenFailureCallbackBlock)block;

/**
 Returns the callback block to be executed on a screen unlock failure.
 */
+ (SFLockScreenFailureCallbackBlock)lockScreenFailureCallbackBlock;

/**
 @return The block used to create the passcode view controller
 */
+ (SFPasscodeViewControllerCreationBlock)passcodeViewControllerCreationBlock;

/**
 Sets the block that will create the passcode view controller.
 @param vcBlock The passcode view controller creation block to use.
 */
+ (void)setPasscodeViewControllerCreationBlock:(SFPasscodeViewControllerCreationBlock)vcBlock;

/**
 @return The block used to present the passcode view controller.
 */
+ (SFPasscodeViewControllerPresentationBlock)presentPasscodeViewControllerBlock;

/**
 Sets the block that will present the passcode view controller.
 @param vcBlock The block to use to present the passcode view controller.
 */
+ (void)setPresentPasscodeViewControllerBlock:(SFPasscodeViewControllerPresentationBlock)vcBlock;

/**
 @return The block used to dismiss the passcode view controller.
 */
+ (SFPasscodeViewControllerPresentationBlock)dismissPasscodeViewControllerBlock;

/**
 Set the block that will dismiss the passcode view controller.
 @param vcBlock The block defined to dismiss the passcode view controller.
 */
+ (void)setDismissPasscodeViewControllerBlock:(SFPasscodeViewControllerPresentationBlock)vcBlock;

/**
 * Sets a retained instance of the current passcode view controller that's displayed.
 @param vc The passcode view controller.
 */
+ (void)setPasscodeViewController:(UIViewController *)vc;

/**
 * Returns the currently displayed passcode view controller, or nil if the passcode view controller
 * is not currently displayed.
 */
+ (UIViewController *)passcodeViewController;

/**
 * Whether to force the passcode screen to be displayed, despite sanity conditions for whether passcodes
 * are configured.  This method is only useful for unit test code, and the value should otherwise be left
 * to its default value of NO.
 * @param forceDisplay Whether to force the passcode screen to be displayed.  Default value is NO.
 */
+ (void)setForcePasscodeDisplay:(BOOL)forceDisplay;

/**
 * @return Whether or not the app is configured to force the display of the passcode screen.
 */
+ (BOOL)forcePasscodeDisplay;

/**
 * @return Whether or not to validate the passcode at app startup.
 */
+ (BOOL)validatePasscodeAtStartup;

@end


