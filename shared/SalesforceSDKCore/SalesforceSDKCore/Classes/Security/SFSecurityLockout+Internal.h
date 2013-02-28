#import "SFSecurityLockout.h"
#import "SFPasscodeViewController.h"

@interface SFSecurityLockout ()

/**
 * Called when the user activity timer expires.
 */
+ (void)timerExpired:(NSTimer *)theTimer;

/**
 * Presents the passcode controller when it's time to create or verify the passcode.
 */
+ (void)presentPasscodeController:(SFPasscodeControllerMode)modeValue;

/**
 * Sets a retained instance of the current passcode view controller that's displayed.
 */
+ (void)setPasscodeViewController:(UIViewController *)vc;

/**
 * Returns the currently displayed passcode view controller, or nil if the passcode view controller
 * is not currently displayed.
 */
+ (UIViewController *)passcodeViewController;

/**
 * Whether or not the passcode screen is currently displayed.
 */
+ (BOOL)passcodeScreenIsPresent;

/**
 * Whether or not the app currently has a valid authenticated session.
 */
+ (BOOL)hasValidSession;

/**
 * Runs in the event of a successful passcode unlock.
 */
+ (void)unlockSuccessPostProcessing;

/**
 * Runs in the event that a passcode unlock attempt failed.
 */
+ (void)unlockFailurePostProcessing;

/**
 * Generate the notification for the beginning of the passcode flow.
 * @param mode The controller mode (create vs. verify) associated with the passcode flow.
 */
+ (void)sendPasscodeFlowWillBeginNotification:(SFPasscodeControllerMode)mode;

/**
 * Generate the notification for the completion of the passcode flow.
 * @param validationSuccess Whether the passcode validation was successful or not.
 */
+ (void)sendPasscodeFlowCompletedNotification:(BOOL)validationSuccess;

/**
 * FOR UNIT TESTS ONLY: Sets the lockout time directly, without accompanying business logic.
 * @param seconds The number of seconds for the lockout time.
 */
+ (void)setLockoutTimeInternal:(NSUInteger)seconds;

@end
