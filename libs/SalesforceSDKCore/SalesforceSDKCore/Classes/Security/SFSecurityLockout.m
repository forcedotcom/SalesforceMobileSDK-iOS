/*
 Copyright (c) 2012-2014, salesforce.com, inc. All rights reserved.
 
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
#import "SFKeychainItemWrapper.h"
#import "SFUserAccountManager.h"
#import "SFPasscodeManager.h"
#import "SFAuthenticationManager.h"
#import "SFRootViewManager.h"
#import "SFPreferences.h"
#import "SFUserActivityMonitor.h"
#import "SFIdentityData.h"
#import "SFApplicationHelper.h"
#import "SFApplication.h"

// Private constants

static NSUInteger const kDefaultPasscodeLength               = 4;
static NSString * const kTimerSecurity                       = @"security.timer";
static NSString * const kLegacyPasscodeLengthKey             = @"security.pinlength";
static NSString * const kPasscodeLengthKey                   = @"security.passcode.length";
static NSString * const kPasscodeScreenAlreadyPresentMessage = @"A passcode screen is already present.";
static NSString * const kKeychainIdentifierLockoutTime       = @"com.salesforce.security.lockoutTime";
static NSString * const kKeychainIdentifierIsLocked          = @"com.salesforce.security.isLocked";

// Public constants

NSString * const kSFPasscodeFlowWillBegin                         = @"SFPasscodeFlowWillBegin";
NSString * const kSFPasscodeFlowCompleted                         = @"SFPasscodeFlowCompleted";
SFPasscodeConfigurationData const SFPasscodeConfigurationDataNull = { -1, NSUIntegerMax };

// Static vars

static NSUInteger              securityLockoutTime;
static UIViewController        *sPasscodeViewController        = nil;
static SFLockScreenSuccessCallbackBlock sLockScreenSuccessCallbackBlock = NULL;
static SFLockScreenFailureCallbackBlock sLockScreenFailureCallbackBlock = NULL;
static SFPasscodeViewControllerCreationBlock sPasscodeViewControllerCreationBlock = NULL;
static SFPasscodeViewControllerPresentationBlock sPresentPasscodeViewControllerBlock = NULL;
static SFPasscodeViewControllerPresentationBlock sDismissPasscodeViewControllerBlock = NULL;
static NSHashTable<id<SFSecurityLockoutDelegate>> *sDelegates = nil;
static BOOL sForcePasscodeDisplay = NO;
static BOOL sValidatePasscodeAtStartup = NO;

// Flag used to prevent the display of the passcode view controller.
// Note: it is used by the unit tests only.
static BOOL _showPasscode = YES;

@implementation SFSecurityLockout

+ (void)initialize
{
    if (self == [SFSecurityLockout class]) {
        [SFSecurityLockout upgradeSettings];  // Ensures a lockout time value in the keychain.
        
        // If this is the first time the passcode functionality has been run in the lifetime of the app install,
        // reset passcode data, since keychain data can persist between app installs.
        if (![SFCrypto baseAppIdentifierIsConfigured] || [SFCrypto baseAppIdentifierConfiguredThisLaunch]) {
            [SFSecurityLockout setSecurityLockoutTime:0];
            [SFSecurityLockout setPasscodeLength:kDefaultPasscodeLength];
        } else {
            securityLockoutTime = [[SFSecurityLockout readLockoutTimeFromKeychain] unsignedIntegerValue];
        }
        
        sDelegates = [NSHashTable weakObjectsHashTable];
        
        [SFSecurityLockout setPasscodeViewControllerCreationBlock:^UIViewController *(SFPasscodeControllerMode mode, SFPasscodeConfigurationData configData) {
            SFPasscodeViewController *pvc = nil;
            if (mode == SFPasscodeControllerModeCreate) {
                pvc = [[SFPasscodeViewController alloc] initForPasscodeCreation:configData];
            } else if (mode == SFPasscodeControllerModeChange) {
                pvc = [[SFPasscodeViewController alloc] initForPasscodeChange:configData];
            } else {
                pvc = [[SFPasscodeViewController alloc] initForPasscodeVerification];
            }
            UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:pvc];
            return nc;
        }];
        
        [SFSecurityLockout setPresentPasscodeViewControllerBlock:^(UIViewController *pvc) {
            [[SFRootViewManager sharedManager] pushViewController:pvc];
        }];
        
        [SFSecurityLockout setDismissPasscodeViewControllerBlock:^(UIViewController *pvc) {
            [[SFRootViewManager sharedManager] popViewController:pvc];
        }];
    }
}

+ (void)upgradeSettings
{
    // Lockout time
    NSNumber *lockoutTime = [SFSecurityLockout readLockoutTimeFromKeychain];
	if (lockoutTime == nil) {
        // Try falling back to user defaults if there's no timeout in the keychain.
        lockoutTime = [[NSUserDefaults standardUserDefaults] objectForKey:kSecurityTimeoutLegacyKey];
        if (lockoutTime == nil) {
            [SFSecurityLockout writeLockoutTimeToKeychain:@(kDefaultLockoutTime)];
        } else {
            [SFSecurityLockout writeLockoutTimeToKeychain:lockoutTime];
        }
    }
    
    // Is locked
    NSNumber *n = [SFSecurityLockout readIsLockedFromKeychain];
    if (n == nil) {
        // Try to fall back to the user defaults if isLocked isn't found in the keychain
        BOOL locked = [[NSUserDefaults standardUserDefaults] boolForKey:kSecurityIsLockedLegacyKey];
        [SFSecurityLockout writeIsLockedToKeychain:@(locked)];
    }
    
    NSNumber *currentPasscodeLength = [[SFPreferences globalPreferences] objectForKey:kPasscodeLengthKey];
    
    if (currentPasscodeLength) {
        NSNumber *previousLength = [[NSUserDefaults standardUserDefaults] objectForKey:kLegacyPasscodeLengthKey];
        if (previousLength) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLegacyPasscodeLengthKey];
        }
        return;
    }
    
    NSNumber *previousLength = [[NSUserDefaults standardUserDefaults] objectForKey:kLegacyPasscodeLengthKey];
    if (previousLength) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLegacyPasscodeLengthKey];
        [self setPasscodeLength:[previousLength integerValue]];
    }
}

+ (void)addDelegate:(id<SFSecurityLockoutDelegate>)delegate
{
    @synchronized (self) {
        if (delegate) {
            [sDelegates addObject:delegate];
        }
    }
}

+ (void)removeDelegate:(id<SFSecurityLockoutDelegate>)delegate
{
    @synchronized (self) {
        if (delegate) {
            [sDelegates removeObject:delegate];
        }
    }
}

+ (void)enumerateDelegates:(void (^)(id<SFSecurityLockoutDelegate>))block
{
    @synchronized (self) {
        for (id<SFSecurityLockoutDelegate> delegate in sDelegates) {
            if (block) block(delegate);
        }
    }
}

+ (void)validateTimer;
{
    if ([SFSecurityLockout isPasscodeValid]) {
        if([SFSecurityLockout inactivityExpired] || [SFSecurityLockout locked]) {
            [self log:SFLogLevelInfo msg:@"Timer expired."];
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

+ (void)setPasscodeLength:(NSInteger)newPasscodeLength lockoutTime:(NSUInteger)newLockoutTime
{
    SFPasscodeConfigurationData configData;
    configData.lockoutTime = securityLockoutTime;
    configData.passcodeLength = [self passcodeLength];
    
    // Cases where there's initially no passcode configured.
    if (securityLockoutTime == 0) {
        if (newLockoutTime == 0) {
            // Passcode off -> off.
            [SFSecurityLockout unlockSuccessPostProcessing:SFSecurityLockoutActionNone];
        } else {
            // Passcode off -> on.  Trigger passcode creation.
            configData.lockoutTime = newLockoutTime;
            configData.passcodeLength = newPasscodeLength;
            [SFSecurityLockout presentPasscodeController:SFPasscodeControllerModeCreate passcodeConfig:configData];
        }
        return;
    }
    
    //
    // From this point, there was already a passcode configured prior to calling this method.
    //
    
    // Lockout time can only go down, to enforce the most restrictive passcode policy across users.
    if (newLockoutTime < securityLockoutTime) {
        if (newLockoutTime > 0) {
            [SFLogger log:[SFSecurityLockout class] level:SFLogLevelInfo format:@"Setting lockout time to %lu seconds.", (unsigned long)newLockoutTime];
            [SFSecurityLockout setSecurityLockoutTime:newLockoutTime];
            configData.lockoutTime = newLockoutTime;
            [SFInactivityTimerCenter removeTimer:kTimerSecurity];
            [SFSecurityLockout setupTimer];
        } else {
            // '0' is a special case.  We can't turn off passcodes unless all other users' passcode policies
            // are also off.
            if (![SFSecurityLockout nonCurrentUsersHavePasscodePolicy]) {
                [SFSecurityLockout clearAllPasscodeState];
                [SFSecurityLockout unlock:YES action:SFSecurityLockoutActionPasscodeRemoved passcodeConfig:SFPasscodeConfigurationDataNull];  // config values already cleared.
                return;
            }
        }
    }
    
    // Passcode lengths can only go up; same reason as lockout times only going down.
    NSInteger currentPasscodeLength = [self passcodeLength];
    if (newPasscodeLength > currentPasscodeLength) {
        configData.passcodeLength = newPasscodeLength;
        [SFSecurityLockout presentPasscodeController:SFPasscodeControllerModeChange passcodeConfig:configData];
        return;
    }
    
    // If we got this far, no passcode action was taken.
    [SFSecurityLockout unlockSuccessPostProcessing:SFSecurityLockoutActionNone];
}

+ (void)setSecurityLockoutTime:(NSUInteger)newSecurityLockoutTime
{
    // NOTE: This method directly alters securityLockoutTime and its persisted value.  Do not call
    // if passcode policy evaluation is required.
    securityLockoutTime = newSecurityLockoutTime;
    [SFSecurityLockout writeLockoutTimeToKeychain:@(securityLockoutTime)];
}

+ (BOOL)nonCurrentUsersHavePasscodePolicy
{
    SFUserAccount *currentAccount = [SFUserAccountManager sharedInstance].currentUser;
    for (SFUserAccount *account in [SFUserAccountManager sharedInstance].allUserAccounts) {
        if (![account isEqual:currentAccount]) {
            if (account.idData.mobileAppScreenLockTimeout > 0) {
                return YES;
            }
        }
    }
    
    return NO;
}

+ (void)clearPasscodeState
{
    // Public method that attempts to clear passcode state for the current user.  Clear state will be dependent
    // on passcode policies across users.  So for instance, if another configured user in the app still has
    // passcode policies which apply to that account, this method will effectively do nothing.  On the other hand,
    // if the current user is the only user of the app, this will remove passcode policies for the app.
    
    if (![SFSecurityLockout nonCurrentUsersHavePasscodePolicy]) {
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
    [SFSecurityLockout setSecurityLockoutTime:0];
    [SFSecurityLockout setPasscodeLength:kDefaultPasscodeLength];
    [SFInactivityTimerCenter removeTimer:kTimerSecurity];
    [[SFPasscodeManager sharedManager] changePasscode:nil];
}

+ (NSInteger)passcodeLength
{
    NSNumber *nPasscodeLength = [[SFPreferences globalPreferences] objectForKey:kPasscodeLengthKey];
    return (nPasscodeLength != nil ? [nPasscodeLength integerValue] : kDefaultPasscodeLength);
}

+ (void)setPasscodeLength:(NSInteger)newPasscodeLength
{
    // NOTE: This method directly alters the passcode length global preference persisted value.  Do not call if
    // passcode policy evaluation is required.
    [[SFPreferences globalPreferences] setObject:@(newPasscodeLength) forKey:kPasscodeLengthKey];
    [[SFPreferences globalPreferences] synchronize];
}

+ (BOOL)hasValidSession
{
    return [[SFAuthenticationManager sharedManager] haveValidSession];
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

static NSString *const kSecurityLockoutSessionId = @"securityLockoutSession";

+ (void)unlock:(BOOL)success action:(SFSecurityLockoutAction)action passcodeConfig:(SFPasscodeConfigurationData)configData
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self unlock:success action:action passcodeConfig:configData];
        });
        return;
    }
    
    [self sendPasscodeFlowCompletedNotification:success];
    UIViewController *passVc = [SFSecurityLockout passcodeViewController];
    if (passVc != nil) {
        SFPasscodeViewControllerPresentationBlock dismissBlock = [SFSecurityLockout dismissPasscodeViewControllerBlock];
        dismissBlock(passVc);
        [SFSecurityLockout setPasscodeViewController:nil];
    }
    
    if (success) {
        if (action == SFSecurityLockoutActionPasscodeCreated || action == SFSecurityLockoutActionPasscodeChanged) {
            if (&configData != &SFPasscodeConfigurationDataNull) {
                [SFSecurityLockout setSecurityLockoutTime:configData.lockoutTime];
                [SFSecurityLockout setPasscodeLength:configData.passcodeLength];
            }
        }
        [SFSecurityLockout unlockSuccessPostProcessing:action];
    } else {
        // Clear the SFSecurityLockout passcode state, as it's no longer valid.
        [SFSecurityLockout clearAllPasscodeState];
        [[SFAuthenticationManager sharedManager] logoutAllUsers];
        [SFSecurityLockout unlockFailurePostProcessing];
    }
    
    [self enumerateDelegates:^(id<SFSecurityLockoutDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(passcodeFlowDidComplete:)]) {
            [delegate passcodeFlowDidComplete:success];
        }
    }];
}

+ (void)timerExpired:(NSTimer*)theTimer
{
    [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
        [[SFAuthenticationManager sharedManager] logout];
    }];
    
    [self log:SFLogLevelInfo msg:@"NSTimer expired, but checking lastUserEvent before locking!"];
    NSDate *lastEventAsOfNow = [(SFApplication *)[SFApplicationHelper sharedApplication] lastEventDate];
    NSInteger elapsedTime = [[NSDate date] timeIntervalSinceDate:lastEventAsOfNow];
    if (elapsedTime >= securityLockoutTime) {
        [self log:SFLogLevelInfo msg:@"Inactivity NSTimer expired."];
        [SFSecurityLockout lock];
    } else {
        [SFInactivityTimerCenter removeTimer:kTimerSecurity];
        [SFSecurityLockout setupTimer];
    }
}

+ (void)setForcePasscodeDisplay:(BOOL)forceDisplay
{
    sForcePasscodeDisplay = forceDisplay;
}

+ (BOOL)forcePasscodeDisplay
{
    return sForcePasscodeDisplay;
}

+ (void)lock
{
    if (!sForcePasscodeDisplay) {
        // Only go through sanity checks for locking if we don't want to force the passcode screen.
        if (![SFSecurityLockout hasValidSession]) {
            [self log:SFLogLevelInfo msg:@"Skipping 'lock' since not authenticated"];
            [SFSecurityLockout unlockSuccessPostProcessing:SFSecurityLockoutActionNone];
            return;
        }
        
        if ([SFSecurityLockout lockoutTime] == 0) {
            [self log:SFLogLevelInfo msg:@"Skipping 'lock' since pin policies are not configured."];
            [SFSecurityLockout unlockSuccessPostProcessing:SFSecurityLockoutActionNone];
            return;
        }
    }
    
    SFPasscodeConfigurationData configData;
    configData.lockoutTime = [self lockoutTime];
    configData.passcodeLength = [self passcodeLength];
    [SFSecurityLockout presentPasscodeController:SFPasscodeControllerModeVerify passcodeConfig:configData];
    [self log:SFLogLevelInfo msg:@"Device locked."];
    sForcePasscodeDisplay = NO;
}

+ (SFPasscodeViewControllerCreationBlock)passcodeViewControllerCreationBlock
{
    return sPasscodeViewControllerCreationBlock;
}

+ (void)setPasscodeViewControllerCreationBlock:(SFPasscodeViewControllerCreationBlock)vcBlock
{
    if (vcBlock != sPasscodeViewControllerCreationBlock) {
        sPasscodeViewControllerCreationBlock = [vcBlock copy];
    }
}

+ (SFPasscodeViewControllerPresentationBlock)presentPasscodeViewControllerBlock
{
    return sPresentPasscodeViewControllerBlock;
}

+ (void)setPresentPasscodeViewControllerBlock:(SFPasscodeViewControllerPresentationBlock)vcBlock
{
    if (vcBlock != sPresentPasscodeViewControllerBlock) {
        sPresentPasscodeViewControllerBlock = vcBlock;
    }
}

+ (SFPasscodeViewControllerPresentationBlock)dismissPasscodeViewControllerBlock
{
    return sDismissPasscodeViewControllerBlock;
}

+ (void)setDismissPasscodeViewControllerBlock:(SFPasscodeViewControllerPresentationBlock)vcBlock
{
    if (vcBlock != sDismissPasscodeViewControllerBlock) {
        sDismissPasscodeViewControllerBlock = vcBlock;
    }
}

+ (void)presentPasscodeController:(SFPasscodeControllerMode)modeValue passcodeConfig:(SFPasscodeConfigurationData)configData
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentPasscodeController:modeValue passcodeConfig:configData];
        });
        return;
    }
    
    // Don't present the passcode screen if it's already present.
    if ([SFSecurityLockout passcodeScreenIsPresent]) {
        return;
    }
    
    [self setIsLocked:YES];
    if (_showPasscode) {
        [self sendPasscodeFlowWillBeginNotification:modeValue];
        [self enumerateDelegates:^(id<SFSecurityLockoutDelegate> delegate) {
            if ([delegate respondsToSelector:@selector(passcodeFlowWillBegin:)]) {
                [delegate passcodeFlowWillBegin:modeValue];
            }
        }];
        SFPasscodeViewControllerCreationBlock passcodeVcCreationBlock = [SFSecurityLockout passcodeViewControllerCreationBlock];
        UIViewController *passcodeViewController = passcodeVcCreationBlock(modeValue, configData);
        [SFSecurityLockout setPasscodeViewController:passcodeViewController];
        SFPasscodeViewControllerPresentationBlock presentBlock = [SFSecurityLockout presentPasscodeViewControllerBlock];
        presentBlock(passcodeViewController);
    }
}

+ (void)sendPasscodeFlowWillBeginNotification:(SFPasscodeControllerMode)mode
{
    [self log:SFLogLevelDebug format:@"Sending passcode flow will begin notification with mode %lu", (unsigned long)mode];
    NSNotification *n = [NSNotification notificationWithName:kSFPasscodeFlowWillBegin
                                                      object:[NSNumber numberWithInt:mode]
                                                    userInfo:nil];
    [[NSNotificationCenter defaultCenter] postNotification:n];
}

+ (void)sendPasscodeFlowCompletedNotification:(BOOL)validationSuccess
{
    [self log:SFLogLevelDebug
       format:@"Sending passcode flow completed notification with validation success = %d", validationSuccess];
    NSNotification *n = [NSNotification notificationWithName:kSFPasscodeFlowCompleted
                                                      object:@(validationSuccess)
                                                    userInfo:nil];
    [[NSNotificationCenter defaultCenter] postNotification:n];
}

+ (BOOL)validatePasscodeAtStartup
{
    return sValidatePasscodeAtStartup;
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

+ (BOOL)isPasscodeValid
{
	if(securityLockoutTime == 0) return YES; // no passcode is required.
    return([[SFPasscodeManager sharedManager] passcodeIsSet]);
}

+ (BOOL)isPasscodeNeeded
{
    if(securityLockoutTime == 0) return NO; // no passcode is required.

    BOOL result = [SFSecurityLockout inactivityExpired] || [SFSecurityLockout validatePasscodeAtStartup] || ![SFSecurityLockout isPasscodeValid];
    result = result || sForcePasscodeDisplay;
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

+ (void)cancelPasscodeScreen
{
    void (^cancelPasscodeBlock)(void) = ^{
        UIViewController *passVc = [SFSecurityLockout passcodeViewController];
        [SFLogger log:[SFSecurityLockout class] level:SFLogLevelInfo format:@"App requested passcode screen cancel.  Screen %@ displayed.", (passVc != nil ? @"is" : @"is not")];
        if (passVc != nil) {
            SFPasscodeViewControllerPresentationBlock dismissBlock = [SFSecurityLockout dismissPasscodeViewControllerBlock];
            dismissBlock(passVc);
            [SFSecurityLockout setPasscodeViewController:nil];
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
    if ([SFSecurityLockout passcodeViewController] != nil) {
        [self log:SFLogLevelInfo msg:kPasscodeScreenAlreadyPresentMessage];
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

#pragma mark keychain methods

+ (void)setCanShowPasscode:(BOOL)showPasscode
{
    _showPasscode = showPasscode;
}

+ (NSNumber *)readLockoutTimeFromKeychain
{
    NSNumber *time = nil;
    SFKeychainItemWrapper *keychainWrapper = [SFKeychainItemWrapper itemWithIdentifier:kKeychainIdentifierLockoutTime account:nil];
    NSData *valueData = [keychainWrapper valueData];
    if (valueData) {
        NSUInteger i = 0;
        [valueData getBytes:&i length:sizeof(i)];
        time = @(i);
    }
    return time;
}

+ (void)writeLockoutTimeToKeychain:(NSNumber *)time
{
    SFKeychainItemWrapper *keychainWrapper = [SFKeychainItemWrapper itemWithIdentifier:kKeychainIdentifierLockoutTime account:nil];
    NSData *data = nil;
    if (time != nil) {
        NSUInteger i = [time unsignedIntegerValue];
        data = [NSData dataWithBytes:&i length:sizeof(i)];
    }
    if (data != nil)
        [keychainWrapper setValueData:data];
    else
        [keychainWrapper resetKeychainItem];  // Predominantly for unit tests
}

+ (NSNumber *)readIsLockedFromKeychain
{
    NSNumber *locked = nil;
    SFKeychainItemWrapper *keychainWrapper = [SFKeychainItemWrapper itemWithIdentifier:kKeychainIdentifierIsLocked account:nil];
    NSData *valueData = [keychainWrapper valueData];
    if (valueData) {
        BOOL b = NO;
        [valueData getBytes:&b length:sizeof(b)];
        locked = @(b);
    }
    return locked;
}

+ (void)writeIsLockedToKeychain:(NSNumber *)locked
{
    SFKeychainItemWrapper *keychainWrapper = [SFKeychainItemWrapper itemWithIdentifier:kKeychainIdentifierIsLocked account:nil];
    NSData *data = nil;
    if (locked != nil) {
        BOOL b = [locked boolValue];
        data = [NSData dataWithBytes:&b length:sizeof(b)];
    }
    if (data != nil)
        [keychainWrapper setValueData:data];
    else
        [keychainWrapper resetKeychainItem];  // Predominantly for unit tests
}

@end

