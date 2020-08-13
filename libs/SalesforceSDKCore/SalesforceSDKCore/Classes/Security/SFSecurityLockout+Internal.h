#import "SFSecurityLockout.h"

NS_ASSUME_NONNULL_BEGIN

static NSUInteger const kDefaultLockoutTime        = 0;
static NSUInteger const kDefaultPasscodeLength     = 0;
static NSString * _Nullable const kSecurityTimeoutLegacyKey  = @"security.timeout";
static NSString * _Nullable const kSecurityIsLockedLegacyKey = @"security.islocked";
static NSString * const kBiometricUnlockAllowedKey           = @"security.biometric.allowed"; // Enabled in the Org
static NSString * const kBiometricStateKey                   = @"secuirty.biometric.state";

SFSDK_DEPRECATED(8.3, 9.0, "Will be internal.")
@interface SFSecurityLockout ()

/**
 * Called when the user activity timer expires.
 */
+ (void)timerExpired:(NSTimer *_Nullable)theTimer;

/**
 * Presents the passcode controller when it's time to create or verify the passcode.
 */
+ (void)presentPasscodeController:(SFAppLockControllerMode)modeValue;

/**
 * Sets a retained instance of the current passcode view controller that's displayed.
 */
+ (void)setPasscodeViewController:(UIViewController *_Nullable)vc;

/**
 * Returns the currently displayed passcode view controller, or nil if the passcode view controller
 * is not currently displayed.
 */
+ (nullable UIViewController *)passcodeViewController;

/**
 * Whether or not the passcode screen is currently displayed.
 */
+ (BOOL)passcodeScreenIsPresent;

/**
 * Closes/dismisses the passcode screen, if it's visible.
 */
+ (void)cancelPasscodeScreen;

/**
 * Whether or not the app currently has a valid authenticated session.
 */
+ (BOOL)hasValidSession;

/**
 * Runs in the event of a successful passcode unlock.
 * @param action The action taken, if any.
 */
+ (void)unlockSuccessPostProcessing:(SFSecurityLockoutAction)action;

/**
 * Runs in the event that a passcode unlock attempt failed.
 */
+ (void)unlockFailurePostProcessing;

/**
 * Generate the notification for the beginning of the passcode flow.
 * @param mode The controller mode (create vs. verify) associated with the passcode or biometric flow.
 */
+ (void)sendPasscodeFlowWillBeginNotification:(SFAppLockControllerMode)mode;

/**
 * Generate the notification for the completion of the passcode flow.
 * @param validationSuccess Whether the passcode or biometric validation was successful or not.
 */
+ (void)sendPasscodeFlowCompletedNotification:(BOOL)validationSuccess;

/**
 * FOR UNIT TESTS ONLY: Sets the lockout time directly, without accompanying business logic.
 * @param seconds The number of seconds for the lockout time.
 */
+ (void)setLockoutTimeInternal:(NSUInteger)seconds;

/**
 * Retrieves the lockout time value from the keychain.
 * @return NSNumber wrapping the NSUInteger value for lockout time, or `nil` if not set.
 */
+ (NSNumber *_Nullable)readLockoutTimeFromKeychain;

/**
 * Writes the lockout time to the keychain.
 * @param lockoutTime The NSNumber wrapping the NSUInteger value to be written to the keychain.
 */
+ (void)writeLockoutTimeToKeychain:(NSNumber *_Nullable)lockoutTime;

/**
 * Retrieves the passcode length value from the keychain.
 * @return NSNumber wrapping the NSUInteger value for passcode length, or `nil` if not set.
 */
+ (NSNumber *)readPasscodeLengthFromKeychain;

/**
 * Writes the passcode length to the keychain.
 * @param passcodeLength The NSNumber wrapping the NSUInteger value to be written to the keychain.
 */
+ (void)writePasscodeLengthToKeychain:(NSNumber *_Nullable)passcodeLength;

/**
 * Retreives the "is locked" setting from the keychain.
 * @return The NSNumber wrapping the BOOL value for "is locked", or `nil` if not set.
 */
+ (NSNumber *_Nullable)readIsLockedFromKeychain;

/**
 * Writes the "is locked" value to the keychain.
 * @param locked The NSNumber wrapping the BOOL value for "is locked".
 */
+ (void)writeIsLockedToKeychain:(NSNumber *_Nullable)locked;

/**
 * Upgrades settings as part of SFSecurityLockout initialization.
 */
+ (void)upgradeSettings;

/**
 Runs the given block of code against the list of security lockout delegates.
 @param block The block of code to execute for each delegate.
 */
+ (void)enumerateDelegates:(void(^)(id <SFSecurityLockoutDelegate> delegate))block;

@end

NS_ASSUME_NONNULL_END
