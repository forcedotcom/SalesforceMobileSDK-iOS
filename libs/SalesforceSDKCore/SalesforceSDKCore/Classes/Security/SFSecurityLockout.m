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

#import "SFSecurityLockout.h"
#import "SFSecurityLockout+Internal.h"
#import "SFInactivityTimerCenter.h"
#import "SFCrypto.h"
#import "SFOAuthCredentials.h"
#import "SFUserAccountManager.h"
#import "SFSDKWindowManager.h"
#import "SFPreferences.h"
#import "SFUserActivityMonitor.h"
#import "SFIdentityData.h"
#import "SFApplicationHelper.h"
#import "SFApplication.h"
#import "SFSDKEventBuilderHelper.h"
#import "SalesforceSDKManager+Internal.h"
#import "SFSDKNavigationController.h"
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import <SalesforceSDKCommon/SalesforceSDKCommon-Swift.h>
#import "SFSDKAppLockViewController.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "SFSDKPasscodeCreateController.h"
#import "SFSDKPasscodeVerifyController.h"
#import "SFSDKBiometricViewController+Internal.h"
#import "SalesforceSDKConstants.h"
#import "SFSDKCryptoUtils.h"
#import "SFPBKDFData.h"
#import "NSData+SFAdditions.h"

// Private constants

static NSString * const kTimerSecurity                       = @"security.timer";
static NSString * const kKeychainIdentifierPasscodeLengthKey = @"com.salesforce.security.passcode.length";
static NSString * const kPasscodeScreenAlreadyPresentMessage = @"A passcode screen is already present.";
static NSString * const kKeychainIdentifierLockoutTime       = @"com.salesforce.security.lockoutTime";
static NSString * const kKeychainIdentifierIsLocked          = @"com.salesforce.security.isLocked";
static NSString * const kKeychainIdentifierPasscodeVerify    = @"com.salesforce.security.passcode.pbkdf2.verify";
static NSString * const kPBKDFArchiveDataKey                 = @"pbkdfDataArchive";

// Public constants

NSString * const kSFPasscodeFlowWillBegin                         = @"SFPasscodeFlowWillBegin";
NSString * const kSFPasscodeFlowCompleted                         = @"SFPasscodeFlowCompleted";

// Static vars

static NSUInteger              securityLockoutTime;
static NSUInteger              passcodeLength;
static UIViewController        *sPasscodeViewController        = nil;
static SFLockScreenSuccessCallbackBlock sLockScreenSuccessCallbackBlock = NULL;
static SFLockScreenFailureCallbackBlock sLockScreenFailureCallbackBlock = NULL;
static SFSDKAppLockViewConfig *_passcodeViewConfig = nil;

typedef NS_OPTIONS(NSUInteger, SFPasscodePolicy) {
    SFPasscodePolicyNone = 0,
    SFPasscodePolicyPasscodeLengthIsMoreRestrictive = 1 << 0,
    SFPasscodePolicySetupNewPasscode = 1 << 1,
    SFPasscodePolicyTimeoutIsMoreRestrictive = 1 << 2,
    SFPasscodePolicySetupNewTimeout = 1 << 3
};

@implementation SFSecurityLockout

+ (void)initialize
{
    if (self == [SFSecurityLockout class]) {
        [SFSecurityLockout upgradeSettings];  // Ensures a lockout time value in the keychain.
        
        // If this is the first time the passcode functionality has been run in the lifetime of the app install,
        // reset passcode data, since keychain data can persist between app installs.
        if (![SFCrypto baseAppIdentifierIsConfigured] || [SFCrypto baseAppIdentifierConfiguredThisLaunch]) {
            [SFSecurityLockout setSecurityLockoutTime:kDefaultLockoutTime];
            [SFSecurityLockout setPasscodeLength:kDefaultPasscodeLength];
            [SFSecurityLockout setBiometricState:SFBiometricUnlockUnavailable];
        } else {
            securityLockoutTime = [[SFSecurityLockout readLockoutTimeFromKeychain] unsignedIntegerValue];
            passcodeLength = [[SFSecurityLockout readPasscodeLengthFromKeychain] unsignedIntegerValue];
        }
    }
}

+ (void)upgradeSettings
{
    // Lockout time
    NSNumber *lockoutTime = [SFSecurityLockout readLockoutTimeFromKeychain];
	if (lockoutTime == nil) {
        [SFSecurityLockout writeLockoutTimeToKeychain:@(kDefaultLockoutTime)];
    }
    
    BOOL biometricAllowedExists = [[SFPreferences globalPreferences] keyExists:kBiometricUnlockAllowedKey];
    if (!biometricAllowedExists) {
        [self setBiometricAllowed:YES];
    }
    BOOL biometricModeExists = [[SFPreferences globalPreferences] keyExists:kBiometricStateKey];
    if (!biometricModeExists) {
        [self setBiometricState:SFBiometricUnlockAvailable];
    }
}

+ (void)validateTimer
{
    if ([SFSecurityLockout isPasscodeValid]) {
        if ([SFSecurityLockout inactivityExpired] || [SFSecurityLockout locked]) {
            [SFSDKCoreLogger i:[self class] format:@"Timer expired."];
            [SFSecurityLockout lock];
        } 
        else {
            [SFSecurityLockout setupTimer];
            [SFSecurityLockout unlockSuccessPostProcessing:SFSecurityLockoutActionNone];  // "Unlock" was successful, as locking wasn't required.
        }
    } else {
        [SFSecurityLockout unlockSuccessPostProcessing:SFSecurityLockoutActionNone];  // "Unlock" was successful, as locking wasn't required.
    }
}

+ (BOOL)needsPasscodeFlow:(NSUInteger)newLockoutTime {
    return newLockoutTime !=0 || [self usersHavePasscodePolicy];
}

+ (BOOL)policy:(SFPasscodePolicy)current equals:(SFPasscodePolicy)change {
    return (current & change) == change;
}

+ (SFPasscodePolicy)getChangesInPasscodePolicy:(NSUInteger)newLockoutTime passcodeLength:(NSUInteger)newPasscodeLength {
    SFPasscodePolicy result = SFPasscodePolicyNone;
    if (securityLockoutTime == 0) {
        result |= SFPasscodePolicySetupNewTimeout;
    } else if (newLockoutTime !=0 && newLockoutTime < securityLockoutTime){
        result |= SFPasscodePolicyTimeoutIsMoreRestrictive;
    }
    
    if ([self passcodeLength] == kDefaultPasscodeLength) {
         result |= SFPasscodePolicySetupNewPasscode;
    } else if (newPasscodeLength > [self passcodeLength]) {
        result |= SFPasscodePolicyPasscodeLengthIsMoreRestrictive;
    }
    
    return result;
}

+ (void)setBiometricPolicy:(BOOL)newBiometricAllowed {
    if (newBiometricAllowed != [self biometricUnlockAllowed] && [self biometricState] != SFBiometricUnlockDeclined) {
        // Biometric off -> on.
        if (newBiometricAllowed) {
            [SFSDKCoreLogger i:[SFSecurityLockout class] format:@"Biometric unlock is allowed."];
            [self setBiometricAllowed:YES];
            [self setBiometricState:SFBiometricUnlockAvailable];
        } else {
            // Biometric on -> off.
            [SFSDKCoreLogger i:[SFSecurityLockout class] format:@"Biometric unlock is not not allowed."];
            [self setBiometricAllowed:NO];
            [self setBiometricState:SFBiometricUnlockUnavailable];
        }
    }
}

+ (void)setInactivityConfiguration:(NSUInteger)newPasscodeLength lockoutTime:(NSUInteger)newLockoutTime biometricAllowed:(BOOL)newBiometricAllowed
{
    
    if (![self needsPasscodeFlow:newLockoutTime]) {
        // No Passcode Requirements for this new user or any other logged in users
        [SFSecurityLockout clearAllPasscodeState];
        [SFSecurityLockout unlockSuccessPostProcessing:SFSecurityLockoutActionNone];
        return;
    }
    
    [self setBiometricPolicy:newBiometricAllowed];
    
    bool shouldShowView = false;
    SFPasscodePolicy newPolicy = [self getChangesInPasscodePolicy:newLockoutTime passcodeLength:newPasscodeLength];
    SFAppLockControllerMode mode = SFAppLockControllerModeCreatePasscode;
    
    if ([self policy:newPolicy equals:SFPasscodePolicySetupNewPasscode]) {
        mode = SFAppLockControllerModeCreatePasscode;
        [SFSecurityLockout setPasscodeLength:newPasscodeLength];
        SFSDKAppLockViewConfig *config = [self passcodeViewConfig];
        [self setPasscodeViewConfig:config];
        shouldShowView = true;
    }
    
    if ([self policy:newPolicy equals:SFPasscodePolicySetupNewTimeout]) {
         mode = SFAppLockControllerModeCreatePasscode;
         [SFSecurityLockout setSecurityLockoutTime:newLockoutTime];
         shouldShowView = true;
    }
    
    if ([self policy:newPolicy equals:SFPasscodePolicyTimeoutIsMoreRestrictive]) {
        [SFSDKCoreLogger i:[SFSecurityLockout class] format:@"Setting lockout time to %lu seconds.", (unsigned long) newLockoutTime];
        [SFSecurityLockout setSecurityLockoutTime:newLockoutTime];
        [SFInactivityTimerCenter removeTimer:kTimerSecurity];
    }
    
    if ([self policy:newPolicy equals:SFPasscodePolicyPasscodeLengthIsMoreRestrictive]) {
        mode = SFAppLockControllerModeChangePasscode;
        [SFSecurityLockout setPasscodeLength:newPasscodeLength];
        shouldShowView = true;
    }
    
    if (shouldShowView) {
       [SFSecurityLockout presentPasscodeController:mode];
    } else {
      [SFSecurityLockout unlockSuccessPostProcessing:SFSecurityLockoutActionNone];
    }
}

+ (void)setSecurityLockoutTime:(NSUInteger)newSecurityLockoutTime
{
    // NOTE: This method directly alters securityLockoutTime and its persisted value.  Do not call
    // if passcode policy evaluation is required.
    securityLockoutTime = newSecurityLockoutTime;
    [SFSecurityLockout writeLockoutTimeToKeychain:@(securityLockoutTime)];
}

+ (BOOL)usersHavePasscodePolicy
{
    for (SFUserAccount *account in [SFUserAccountManager sharedInstance].allUserAccounts) {
        if (account.idData.mobileAppScreenLockTimeout > 0) {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)currentUserHasPasscodePolicy {
    SFUserAccount *currentAccount = [SFUserAccountManager sharedInstance].currentUser;
    return currentAccount && currentAccount.idData.mobileAppScreenLockTimeout > 0;
}

+ (BOOL)otherUsersHavePasscodePolicy:(SFUserAccount *)thisUser
{
    for (SFUserAccount *account in [SFUserAccountManager sharedInstance].allUserAccounts) {
        if (![account isEqual:thisUser]) {
            if (account.idData.mobileAppScreenLockTimeout > 0) {
                return YES;
            }
        }
    }
    return NO;
}

+ (void)clearPasscodeState:(SFUserAccount *)userLoggingOut
{
    if (![SFSecurityLockout otherUsersHavePasscodePolicy:userLoggingOut]) {
        [SFSecurityLockout clearAllPasscodeState];
    }
}

+ (void)clearAllPasscodeState
{
    // NOTE: This private method directly clears all of the persisted passcode state for the app.  It should only
    // be called in the event that the greater app state needs to be cleared; it's currently used internally in
    // cases where the passcode is no longer valid (user forgot the passcode, failed the maximum verification
    // attempts, etc.).  Calling this method should be reasonably followed upstream with a general resetting of
    // the app state.
    [SFSecurityLockout setSecurityLockoutTime:kDefaultLockoutTime];
    [SFSecurityLockout setPasscodeLength:kDefaultPasscodeLength];
    [SFSecurityLockout setBiometricState:SFBiometricUnlockUnavailable];
    [SFInactivityTimerCenter removeTimer:kTimerSecurity];
    [SFSecurityLockout changePasscode:nil];
}

+ (NSUInteger)passcodeLength
{
    return passcodeLength;
}

+ (void)setPasscodeLength:(NSUInteger)newPasscodeLength
{
    // NOTE: This method directly alters the passcode length global preference persisted value.  Do not call if
    // passcode policy evaluation is required.
    passcodeLength = newPasscodeLength;
    [SFSecurityLockout writePasscodeLengthToKeychain:[NSNumber numberWithUnsignedInteger:newPasscodeLength]];
}

+ (BOOL)deviceHasBiometric {
    LAContext *context = [[LAContext alloc] init];
    NSError *biometricError;
    BOOL deviceHasBiometric = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&biometricError];
    if (!deviceHasBiometric) {
        [SFSDKCoreLogger d:[self class] format:@"Device cannot use Touch Id or Face Id.  Error: %@", biometricError];
    }
    return deviceHasBiometric;
}

+ (BOOL)biometricUnlockAllowed
{
    return [[SFPreferences globalPreferences] boolForKey:kBiometricUnlockAllowedKey] && [SFSecurityLockout deviceHasBiometric];
}

+ (void)setBiometricAllowed:(BOOL)enabled
{
    [[SFPreferences globalPreferences] setBool:enabled forKey:kBiometricUnlockAllowedKey];
    [[SFPreferences globalPreferences] synchronize];
}

+ (SFBiometricUnlockState)biometricState
{
    SFBiometricUnlockState currentState = [[SFPreferences globalPreferences] integerForKey:kBiometricStateKey];
    // Check if state should be updated
    switch (currentState) {
        case SFBiometricUnlockDeclined:
            break;
        case SFBiometricUnlockApproved:
        case SFBiometricUnlockAvailable:
            if (![self biometricUnlockAllowed]) {
                currentState = SFBiometricUnlockUnavailable;
            }
            break;
        case SFBiometricUnlockUnavailable:
            if ([self biometricUnlockAllowed]) {
                currentState = SFBiometricUnlockAvailable;
            }
            break;
        default:
            [SFSDKCoreLogger d:[self class] format:@"Invalid biometric state retrived."];
            currentState = SFBiometricUnlockUnavailable;
    }
    
    [SFSecurityLockout setBiometricState:currentState];
    return currentState;
}

+ (void)setBiometricState:(SFBiometricUnlockState)state
{
    [[SFPreferences globalPreferences] setObject:@(state) forKey:kBiometricStateKey];
    [[SFPreferences globalPreferences] synchronize];
}

+ (BOOL)hasValidSession
{
    return [SFUserAccountManager sharedInstance].currentUser != nil && [SFUserAccountManager sharedInstance].currentUser.isSessionValid;
}

// For unit tests.
+ (void)setLockoutTimeInternal:(NSUInteger)seconds
{
    securityLockoutTime = seconds;
}

+ (NSUInteger)lockoutTime
{
	return securityLockoutTime;
}

+ (BOOL)inactivityExpired
{
	NSInteger elapsedTime = [[NSDate date] timeIntervalSinceDate:[SFInactivityTimerCenter lastActivityTimestamp]];
	return (securityLockoutTime > 0) && (elapsedTime >= securityLockoutTime);
}

+ (void)startActivityMonitoring
{
    if ([SFSecurityLockout lockoutTime] > 0) {
        [[SFUserActivityMonitor sharedInstance] startMonitoring];
    }
}

+ (void)stopActivityMonitoring
{
    [[SFUserActivityMonitor sharedInstance] stopMonitoring];
}

+ (void)setupTimer
{
	if(securityLockoutTime > 0) {
		[SFInactivityTimerCenter registerTimer:kTimerSecurity
                                        target:self
                                      selector:@selector(timerExpired:)
                                 timerInterval:securityLockoutTime];
	}
    [SFInactivityTimerCenter updateActivityTimestamp];
}

+ (void)removeTimer
{
    [SFInactivityTimerCenter removeTimer:kTimerSecurity];
}

+ (void)setPasscodeViewConfig:(SFSDKAppLockViewConfig *)passcodeViewConfig {
    _passcodeViewConfig = passcodeViewConfig;
}

+ (SFSDKAppLockViewConfig *)passcodeViewConfig {
    if (_passcodeViewConfig == nil) {
        _passcodeViewConfig = [SFSDKAppLockViewConfig createDefaultConfig];
    }
    return _passcodeViewConfig;
}

static NSString *const kSecurityLockoutSessionId = @"securityLockoutSession";

+ (void)unlock:(SFSecurityLockoutAction)action
{
    [self unlock:YES action:action];
}

+ (void)wipeState
{
    [self unlock:NO action:SFSecurityLockoutActionNone];
}

+ (void)unlock:(BOOL)success action:(SFSecurityLockoutAction)action
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self unlock:success action:action];
        });
        return;
    }
    
    [SFSDKEventBuilderHelper createAndStoreEvent:@"passcodeUnlock" userAccount:nil className:NSStringFromClass([self class]) attributes:nil];
    [self sendPasscodeFlowCompletedNotification:success];
    UIViewController *passVc = [SFSecurityLockout passcodeViewController];
    if (passVc != nil) {
        if (success) {
            __weak typeof (self) weakSelf = self;
            [SFSecurityLockout dismissPasscodeWithCompletion:^{
                __strong typeof (weakSelf) strongSelf = weakSelf;
                [SFSecurityLockout setPasscodeViewController:nil];
                [SFSecurityLockout unlockSuccessPostProcessing:action];

                [SFSDKEventBuilderHelper createAndStoreEvent:@"passcodeUnlock" userAccount:nil className:NSStringFromClass([strongSelf class]) attributes:nil];
                [strongSelf sendPasscodeFlowCompletedNotification:success];
            }];
        } else {
            // Clear the SFSecurityLockout passcode state, as it's no longer valid.
            [SFSecurityLockout clearAllPasscodeState];
            [[SFUserAccountManager sharedInstance] logoutAllUsers];
            [SFSecurityLockout unlockFailurePostProcessing];
            [SFSecurityLockout setBiometricState:SFBiometricUnlockUnavailable];
            [SFSecurityLockout setPasscodeViewController:nil];
        }
    }
}

+ (void)timerExpired:(NSTimer*)theTimer
{
    [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
        [[SFUserAccountManager sharedInstance] logout];
    }];
    
    [SFSDKCoreLogger i:[self class] format:@"NSTimer expired, but checking lastUserEvent before locking!"];
    NSDate *lastEventAsOfNow = [(SFApplication *)[SFApplicationHelper sharedApplication] lastEventDate];
    NSInteger elapsedTime = [[NSDate date] timeIntervalSinceDate:lastEventAsOfNow];
    if (elapsedTime >= securityLockoutTime) {
        [SFSDKCoreLogger i:[self class] format:@"Inactivity NSTimer expired."];
        [SFSecurityLockout lock];
    } else {
        [SFInactivityTimerCenter removeTimer:kTimerSecurity];
        [SFSecurityLockout setupTimer];
    }
}

+ (void)lock
{
    if (![SFSecurityLockout hasValidSession]) {
        [SFSDKCoreLogger i:[self class] format:@"Skipping 'lock' since not authenticated"];
        [SFSecurityLockout unlockSuccessPostProcessing:SFSecurityLockoutActionNone];
        return;
    }
    if ([SFSecurityLockout lockoutTime] == 0) {
        [SFSDKCoreLogger i:[self class] format:@"Skipping 'lock' since pin policies are not configured."];
        [SFSecurityLockout unlockSuccessPostProcessing:SFSecurityLockoutActionNone];
        return;
    }
    
    if ([SFApplicationHelper sharedApplication].applicationState == UIApplicationStateActive || ![[SFSDKWindowManager sharedManager] snapshotWindow:nil].isEnabled) {
        if (![SFSecurityLockout deviceHasBiometric]) {
            [self setBiometricState:SFBiometricUnlockUnavailable];
        }
        
        SFAppLockControllerMode lockType = ([self biometricState] == SFBiometricUnlockApproved) ? SFAppLockControllerModeVerifyBiometric : SFAppLockControllerModeVerifyPasscode;
        [SFSecurityLockout presentPasscodeController:lockType];
    }
    [SFSDKCoreLogger i:[self class] format:@"Device locked."];
}

+ (void)presentPasscodeController:(SFAppLockControllerMode)modeValue
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentPasscodeController:modeValue];
        });
        return;
    }
    
    if ([[[SFSDKWindowManager sharedManager] snapshotWindow:nil] isEnabled]) {
        [[[SFSDKWindowManager sharedManager] snapshotWindow:nil] dismissWindow];
    }
    // Don't present the passcode screen if it's already present.
    if ([SFSecurityLockout passcodeScreenIsPresent]) {
        return;
    }
    
    [self setIsLocked:YES];
    [self sendPasscodeFlowWillBeginNotification:modeValue];
    UIViewController *passcodeViewController = [[SFSDKAppLockViewController alloc] initWithMode:modeValue andViewConfig:self.passcodeViewConfig];
    [SFSecurityLockout setPasscodeViewController:passcodeViewController];
    passcodeViewController.modalPresentationStyle = UIModalPresentationFullScreen;
    [[SFSDKWindowManager sharedManager].passcodeWindow presentWindowAnimated:NO withCompletion:^{
        [[SFSDKWindowManager sharedManager].passcodeWindow.viewController presentViewController:passcodeViewController animated:NO completion:nil];
    }];
}

+ (void)presentBiometricEnrollment:(SFSDKAppLockViewConfig *)viewConfig
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentBiometricEnrollment:viewConfig];
        });
        return;
    }
    
    if ([SFSecurityLockout biometricState] == SFBiometricUnlockUnavailable) {
        [SFSDKCoreLogger i:[self class] format:@"Biometric enrollemnt screen cannot be presented because biometric unlock is not permitted by either the org or device."];
    } else {
        SFSDKAppLockViewConfig *displayConfig = (viewConfig) ? viewConfig : self.passcodeViewConfig;
        [[SFSDKWindowManager sharedManager].passcodeWindow presentWindowAnimated:NO withCompletion:^{
            SFSDKAppLockViewController *navController = [[SFSDKAppLockViewController alloc] initWithMode:SFAppLockControllerModeEnableBiometric andViewConfig:displayConfig];
            navController.modalPresentationStyle = UIModalPresentationFullScreen;
            [[SFSDKWindowManager sharedManager].passcodeWindow.viewController presentViewController:navController animated:NO completion:^{}];
        }];
    }
}

+ (void)sendPasscodeFlowWillBeginNotification:(SFAppLockControllerMode)mode
{
    [SFSDKCoreLogger d:[self class] format:@"Sending passcode flow will begin notification with mode %lu", (unsigned long)mode];
    NSNotification *n = [NSNotification notificationWithName:kSFPasscodeFlowWillBegin
                                                      object:[NSNumber numberWithUnsignedInteger:mode]
                                                    userInfo:nil];
    [[NSNotificationCenter defaultCenter] postNotification:n];
}

+ (void)sendPasscodeFlowCompletedNotification:(BOOL)validationSuccess
{
    [SFSDKCoreLogger d:[self class]
       format:@"Sending passcode flow completed notification with validation success = %d", validationSuccess];
    NSNotification *n = [NSNotification notificationWithName:kSFPasscodeFlowCompleted
                                                      object:@(validationSuccess)
                                                    userInfo:nil];
    [[NSNotificationCenter defaultCenter] postNotification:n];
}

+ (void)setIsLocked:(BOOL)locked
{
    [SFSecurityLockout writeIsLockedToKeychain:@(locked)];
}

+ (BOOL)locked
{
    BOOL locked = NO;
    NSNumber *n = [self readIsLockedFromKeychain];
    if (n != nil) {
        locked = [n boolValue];
    }
    return locked;
}

+ (BOOL)isPasscodeSet {
    return ([SFSecurityLockout hashedVerificationPasscode] != nil);
}

+ (NSString *)hashedVerificationPasscode {
    SFPBKDFData *pbkdfData = [SFSecurityLockout passcodeData:kKeychainIdentifierPasscodeVerify];
    NSString *keyDataAsString = (pbkdfData != nil ? [pbkdfData.derivedKey base64Encode] : nil);
    return keyDataAsString;
}

+ (BOOL)isPasscodeValid
{
	if (securityLockoutTime == 0) return YES; // no passcode is required.
    return [SFSecurityLockout isPasscodeSet];
}

+ (BOOL)shouldLock {
    if (securityLockoutTime == 0) return NO; // no passcode is required.

    BOOL result = [SFSecurityLockout inactivityExpired] || ![SFSecurityLockout isPasscodeValid];
    return result;
}

+ (BOOL)isLockoutEnabled
{
	return securityLockoutTime > 0;
}

+ (void)setPasscodeViewController:(UIViewController *)vc
{
    if (vc != sPasscodeViewController) {
        sPasscodeViewController = vc;
    }
}

+ (UIViewController *)passcodeViewController
{
    return sPasscodeViewController;
}

+ (void)dismissPasscodeWithCompletion:(void (^ _Nullable)(void))completionBlock {
    [[SFSDKWindowManager sharedManager].passcodeWindow.viewController dismissViewControllerAnimated:NO completion:^{
        [[SFSDKWindowManager sharedManager].passcodeWindow dismissWindowAnimated:NO withCompletion:^{
            if (completionBlock) {
                completionBlock();
            }
        }];
    }];
}

+ (void)cancelPasscodeScreen
{
    void (^cancelPasscodeBlock)(void) = ^{
        UIViewController *passVc = [SFSecurityLockout passcodeViewController];
        [SFSDKCoreLogger i:[SFSecurityLockout class] format:@"App requested passcode screen cancel.  Screen %@ displayed.", (passVc != nil ? @"is" : @"is not")];
        if (passVc != nil) {
            [SFSecurityLockout dismissPasscodeWithCompletion:^{
                [SFSecurityLockout setPasscodeViewController:nil];
            }];
        }
    };
    
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), cancelPasscodeBlock);
    } else {
        cancelPasscodeBlock();
    }
}

+ (void)setLockScreenFailureCallbackBlock:(SFLockScreenFailureCallbackBlock)block
{
    // Callback blocks can't be altered if the passcode screen is already in progress.
    if (![SFSecurityLockout passcodeScreenIsPresent] && sLockScreenFailureCallbackBlock != block) {
        sLockScreenFailureCallbackBlock = [block copy];
    }
}

+ (SFLockScreenFailureCallbackBlock)lockScreenFailureCallbackBlock
{
    return sLockScreenFailureCallbackBlock;
}

+ (void)setLockScreenSuccessCallbackBlock:(SFLockScreenSuccessCallbackBlock)block
{
    // Callback blocks can't be altered if the passcode screen is already in progress.
    if (![SFSecurityLockout passcodeScreenIsPresent] && sLockScreenSuccessCallbackBlock != block) {
        sLockScreenSuccessCallbackBlock = [block copy];
    }
}

+ (SFLockScreenSuccessCallbackBlock)lockScreenSuccessCallbackBlock
{
    return sLockScreenSuccessCallbackBlock;
}

+ (BOOL)passcodeScreenIsPresent
{
    if ([SFSecurityLockout passcodeViewController] != nil && [[SFSecurityLockout passcodeViewController] presentedViewController] != nil) {
        [SFSDKCoreLogger i:[self class] format:kPasscodeScreenAlreadyPresentMessage];
        return YES;
    } else {
        return NO;
    }
}

+ (void)unlockSuccessPostProcessing:(SFSecurityLockoutAction)action
{
    [self setIsLocked:NO];
    [SFSecurityLockout setLockScreenFailureCallbackBlock:NULL];
    if ([SFSecurityLockout lockScreenSuccessCallbackBlock] != NULL) {
        SFLockScreenSuccessCallbackBlock blockCopy = [[SFSecurityLockout lockScreenSuccessCallbackBlock] copy];
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:NULL];
        blockCopy(action);
    }
    [self setupTimer];
}

+ (void)unlockFailurePostProcessing
{
    [self setIsLocked:NO];
    [SFSecurityLockout setLockScreenSuccessCallbackBlock:NULL];
    if ([SFSecurityLockout lockScreenFailureCallbackBlock] != NULL) {
        SFLockScreenFailureCallbackBlock blockCopy = [[SFSecurityLockout lockScreenFailureCallbackBlock] copy];
        [SFSecurityLockout setLockScreenFailureCallbackBlock:NULL];
        blockCopy();
    }
}

+ (void)userAllowedBiometricUnlock:(BOOL)userAllowedBiometric
{
    [SFSecurityLockout setBiometricState:userAllowedBiometric ? SFBiometricUnlockApproved : SFBiometricUnlockDeclined];
}

#pragma mark keychain methods

+ (NSNumber *)readLockoutTimeFromKeychain
{
    return [SFSecurityLockout readNumberFromKeychain:kKeychainIdentifierLockoutTime];
}

+ (void)writeLockoutTimeToKeychain:(nullable NSNumber *)time
{
    [SFSecurityLockout writeNumberToKeychain:time identifier:kKeychainIdentifierLockoutTime];
}

+ (NSNumber *)readPasscodeLengthFromKeychain
{
    return [SFSecurityLockout readNumberFromKeychain:kKeychainIdentifierPasscodeLengthKey];
}

+ (void)writePasscodeLengthToKeychain:(NSNumber *)length
{
    [SFSecurityLockout writeNumberToKeychain:length identifier:kKeychainIdentifierPasscodeLengthKey];
}

+ (NSNumber *)readIsLockedFromKeychain
{
    NSNumber *locked = nil;
    SFSDKKeychainResult *result = [SFSDKKeychainHelper readWithService:kKeychainIdentifierIsLocked account:nil];
    NSData *valueData = result.data;
    if (valueData) {
        BOOL b = NO;
        [valueData getBytes:&b length:sizeof(b)];
        locked = @(b);
    }
    return locked;
}

+ (void)writeIsLockedToKeychain:(NSNumber *)locked
{
    NSData *data = nil;
    if (locked != nil) {
        BOOL b = [locked boolValue];
        data = [NSData dataWithBytes:&b length:sizeof(b)];
    }
    
    SFSDKKeychainResult *result = [SFSDKKeychainHelper readWithService:kKeychainIdentifierIsLocked account:nil];
    if (data != nil)
        result = [SFSDKKeychainHelper writeWithService:kKeychainIdentifierIsLocked data:data account:nil];
   
}

+ (NSNumber *)readNumberFromKeychain:(NSString *)identifier
{
    NSNumber *data = nil;
    SFSDKKeychainResult *result = [SFSDKKeychainHelper readWithService:identifier account:nil];
    NSData *valueData = result.data;
    if (valueData) {
        NSUInteger i = 0;
        [valueData getBytes:&i length:sizeof(i)];
        data = @(i);
    }
    return data;
}

+ (void)writeNumberToKeychain:(NSNumber *)number identifier:(NSString *)identifier
{
    NSData *data = nil;
    if (number != nil) {
        NSUInteger i = [number unsignedIntegerValue];
        data = [NSData dataWithBytes:&i length:sizeof(i)];
    }
    SFSDKKeychainResult *writeResult = nil;
    if (data != nil)
        writeResult = [SFSDKKeychainHelper writeWithService:identifier data:data account:nil];
    else // Predominantly for unit tests
        writeResult = [SFSDKKeychainHelper resetWithService:identifier account:nil];
    if (!writeResult.success) {
        [SFSDKCoreLogger e:[self class] format:@"Error writing number to keychain %@", writeResult.error];
    }
    
}

#pragma mark passcode management

+ (void)resetPasscode {
    [SFSDKCoreLogger i:[self class] format:@"Resetting passcode."];
    SFSDKKeychainResult *result = [SFSDKKeychainHelper removeWithService:kKeychainIdentifierPasscodeVerify  account:nil];
    if (result.status==errSecItemNotFound) {
        return;
    }
    [SFSDKCoreLogger e:[self class] format:@"Error resetting passcode in keychain %@", result.error];
}

+ (BOOL)verifyPasscode:(NSString *)passcode {
    SFPBKDFData *passcodeData = [SFSecurityLockout passcodeData:kKeychainIdentifierPasscodeVerify];
       
       // Sanity check data.
       if (passcodeData == nil) {
           [SFSDKCoreLogger e:[self class] format:@"No passcode data found.  Cannot verify passcode."];
           return NO;
       } else if (passcodeData.derivedKey == nil) {
           [SFSDKCoreLogger e:[self class] format:@"Passcode key has not been set.  Cannot verify passcode."];
           return NO;
       } else if (passcodeData.salt == nil) {
           [SFSDKCoreLogger e:[self class] format:@"Passcode salt has not been set.  Cannot verify passcode."];
           return NO;
       } else if (passcodeData.numDerivationRounds == 0) {
           [SFSDKCoreLogger e:[self class] format:@"Number of derivation rounds has not been set.  Cannot verify passcode."];
           return NO;
       }
       
       // Generate verification key from input passcode.
       SFPBKDFData *verifyData = [self createPBKDF2DerivedKey:passcode
                                                         salt:passcodeData.salt
                                             derivationRounds:passcodeData.numDerivationRounds
                                                    keyLength:[passcodeData.derivedKey length]];
       return [passcodeData.derivedKey isEqualToData:verifyData.derivedKey];
    
}

+ (void)changePasscode:(nullable NSString *)newPasscode {
    if ([newPasscode length] == 0) {
        [self resetPasscode];
    } else {
        [SFSecurityLockout setPasscode:newPasscode];
    }
}

+ (void)setPasscode:(NSString *)newPasscode {
    if (newPasscode == nil) {
        [SFSecurityLockout resetPasscode];
        return;
    }
    
    NSData *salt = [SFSDKCryptoUtils randomByteDataWithLength:kSFPBKDFDefaultSaltByteLength];
    SFPBKDFData *pbkdfData = [self createPBKDF2DerivedKey:newPasscode
                                                     salt:salt
                                         derivationRounds:kSFPBKDFDefaultNumberOfDerivationRounds
                                                keyLength:kSFPBKDFDefaultDerivedKeyByteLength];
    [SFSecurityLockout setPasscodeData:pbkdfData keychainId:kKeychainIdentifierPasscodeVerify];
}

+ (SFPBKDFData *)passcodeData:(NSString *)keychainIdentifier {
    SFSDKKeychainResult *result = [SFSDKKeychainHelper readWithService:keychainIdentifier account:nil];
    NSData *keychainPasscodeData = result.data;
    if (keychainPasscodeData == nil) {
        return nil;
    }
    
    SFPBKDFData *pbkdfData = nil;
    NSError* error = nil;
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:keychainPasscodeData error:&error];
    unarchiver.requiresSecureCoding = NO;
    if (error) {
        [SFSDKCoreLogger e:[self class] format:@"Failed to init unarchiver for passcode data: %@.", error];
    } else {
        pbkdfData = [unarchiver decodeObjectForKey:kPBKDFArchiveDataKey];
        [unarchiver finishDecoding];
    }
    
    return pbkdfData;
}

+ (void)setPasscodeData:(SFPBKDFData *)passcodeData keychainId:(NSString *)keychainIdentifier
{
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
    [archiver encodeObject:passcodeData forKey:kPBKDFArchiveDataKey];
    [archiver finishEncoding];
    
    SFSDKKeychainResult *result = [SFSDKKeychainHelper writeWithService:keychainIdentifier
                                            data:archiver.encodedData
                                         account:nil];
    if (!result.success) {
        [SFSDKCoreLogger e:[self class] format:@"Failed to write %@ to keychain: %@.", keychainIdentifier, result.error];
    }
    
}

+ (SFPBKDFData *)createPBKDF2DerivedKey:(NSString *)stringToHash
                                   salt:(NSData *)salt
                       derivationRounds:(NSUInteger)numDerivationRounds
                              keyLength:(NSUInteger)derivedKeyLength {
    NSData *keyData = [SFSDKCryptoUtils pbkdf2DerivedKey:stringToHash salt:salt derivationRounds:numDerivationRounds keyLength:derivedKeyLength];
    if (keyData) {
        return [[SFPBKDFData alloc] initWithKey:keyData salt:salt derivationRounds:numDerivationRounds derivedKeyLength:derivedKeyLength];
    } else {
        return nil;
    }
}

@end
