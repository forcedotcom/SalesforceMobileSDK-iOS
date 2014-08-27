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

#import "SFSecurityLockout.h"
#import "SFSecurityLockout+Internal.h"
#import <SalesforceCommonUtils/SFInactivityTimerCenter.h>
#import <SalesforceOAuth/SFOAuthCredentials.h>
#import <SalesforceCommonUtils/SFKeychainItemWrapper.h>
#import "SFUserAccountManager.h"
#import <SalesforceSecurity/SFPasscodeManager.h>
#import "SFAuthenticationManager.h"
#import "SFRootViewManager.h"
#import "SFPreferences.h"
#import "SFUserActivityMonitor.h"

// Private constants

static NSUInteger const kDefaultPasscodeLength               = 4;
static NSString * const kTimerSecurity                       = @"security.timer";
static NSString * const kPasscodeLengthKey                   = @"security.passcode.length";
static NSString * const kPasscodeScreenAlreadyPresentMessage = @"A passcode screen is already present.";
static NSString * const kKeychainIdentifierLockoutTime       = @"com.salesforce.security.lockoutTime";
static NSString * const kKeychainIdentifierIsLocked          = @"com.salesforce.security.isLocked";

// Public constants

NSString * const kSFPasscodeFlowWillBegin = @"SFPasscodeFlowWillBegin";
NSString * const kSFPasscodeFlowCompleted = @"SFPasscodeFlowCompleted";

// Static vars

static NSUInteger              securityLockoutTime;
static UIViewController        *sPasscodeViewController        = nil;
static SFLockScreenSuccessCallbackBlock sLockScreenSuccessCallbackBlock = NULL;
static SFLockScreenFailureCallbackBlock sLockScreenFailureCallbackBlock = NULL;
static SFPasscodeViewControllerCreationBlock sPasscodeViewControllerCreationBlock = NULL;
static SFPasscodeViewControllerPresentationBlock sPresentPasscodeViewControllerBlock = NULL;
static SFPasscodeViewControllerPresentationBlock sDismissPasscodeViewControllerBlock = NULL;
static NSMutableOrderedSet *sDelegates = nil;
static BOOL sForcePasscodeDisplay = NO;
static BOOL sValidatePasscodeAtStartup = NO;

// Flag used to prevent the display of the passcode view controller.
// Note: it is used by the unit tests only.
static BOOL _showPasscode = YES;

@implementation SFSecurityLockout

+ (void)initialize
{
    [SFSecurityLockout upgradeSettings];  // Ensures a lockout time value in the keychain.
    securityLockoutTime = [[SFSecurityLockout readLockoutTimeFromKeychain] unsignedIntegerValue];
    
    sDelegates = [NSMutableOrderedSet orderedSet];
    
    [SFSecurityLockout setPasscodeViewControllerCreationBlock:^UIViewController *(SFPasscodeControllerMode mode, NSInteger passcodeLength) {
        SFPasscodeViewController *pvc = nil;
        if (mode == SFPasscodeControllerModeCreate) {
            pvc = [[SFPasscodeViewController alloc] initForPasscodeCreation:passcodeLength];
        } else if (mode == SFPasscodeControllerModeChange) {
            pvc = [[SFPasscodeViewController alloc] initForPasscodeChange:passcodeLength];
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
}

+ (void)addDelegate:(id<SFSecurityLockoutDelegate>)delegate
{
    @synchronized (self) {
        if (delegate) {
            NSValue *nonretainedDelegate = [NSValue valueWithNonretainedObject:delegate];
            [sDelegates addObject:nonretainedDelegate];
        }
    }
}

+ (void)removeDelegate:(id<SFSecurityLockoutDelegate>)delegate
{
    @synchronized (self) {
        if (delegate) {
            NSValue *nonretainedDelegate = [NSValue valueWithNonretainedObject:delegate];
            [sDelegates removeObject:nonretainedDelegate];
        }
    }
}

+ (void)enumerateDelegates:(void (^)(id<SFSecurityLockoutDelegate>))block
{
    @synchronized (self) {
        [sDelegates enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            id<SFSecurityLockoutDelegate> delegate = [obj nonretainedObjectValue];
            if (delegate) {
                if (block) block(delegate);
            }
        }];
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
            [SFInactivityTimerCenter updateActivityTimestamp];
            [SFSecurityLockout unlockSuccessPostProcessing:SFSecurityLockoutActionNone];  // "Unlock" was successful, as locking wasn't required.
        }
    } else {
        [SFSecurityLockout unlockSuccessPostProcessing:SFSecurityLockoutActionNone];  // "Unlock" was successful, as locking wasn't required.
    }
}

+ (void)setPasscodeLength:(NSInteger)newPasscodeLength lockoutTime:(NSUInteger)newLockoutTime
{
    // Cases where there's initially no passcode configured.
    if (securityLockoutTime == 0) {
        if (newLockoutTime == 0) {
            // Passcode off -> off.
            [SFSecurityLockout unlockSuccessPostProcessing:SFSecurityLockoutActionNone];
        } else {
            // Passcode off -> on.  Trigger passcode creation.
            [SFSecurityLockout setSecurityLockoutTime:newLockoutTime];
            [SFSecurityLockout setPasscodeLength:newPasscodeLength];
            [SFSecurityLockout presentPasscodeController:SFPasscodeControllerModeCreate];
        }
        return;
    }
    
    //
    // From this point, there was already a passcode configured prior to calling this method.
    //
    
    // Lockout time can only go down, to enforce the most restrictive passcode policy across users.
    if (newLockoutTime < securityLockoutTime) {
        if (newLockoutTime > 0) {
            [SFLogger log:[SFSecurityLockout class] level:SFLogLevelInfo format:@"Setting lockout time to %d seconds.", newLockoutTime];
            [SFSecurityLockout setSecurityLockoutTime:newLockoutTime];
            [SFInactivityTimerCenter removeTimer:kTimerSecurity];
            [SFSecurityLockout setupTimer];
        } else {
            // '0' is a special case.  We can't turn off passcodes unless all other users' passcode policies
            // are also off.
            if (![SFSecurityLockout nonCurrentUsersHavePasscodePolicy]) {
                [SFSecurityLockout clearAllPasscodeState];
                [SFSecurityLockout unlock:YES action:SFSecurityLockoutActionPasscodeRemoved];
                return;
            }
        }
    }
    
    // Passcode lengths can only go up; same reason as lockout times only going down.
    NSInteger currentPasscodeLength = [self passcodeLength];
    if (newPasscodeLength > currentPasscodeLength) {
        [SFSecurityLockout setPasscodeLength:newPasscodeLength];
        [SFSecurityLockout presentPasscodeController:SFPasscodeControllerModeChange];
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
    [[SFUserActivityMonitor sharedInstance] stopMonitoring];
    [[SFPasscodeManager sharedManager] changePasscode:nil];
}

+ (NSInteger)passcodeLength
{
    NSNumber *nPasscodeLength = [[SFPreferences globalPreferences] objectForKey:kPasscodeLengthKey];
    return (nPasscodeLength != nil ? [nPasscodeLength intValue] : kDefaultPasscodeLength);
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

+ (void)setupTimer
{
	if(securityLockoutTime > 0) {
		[SFInactivityTimerCenter registerTimer:kTimerSecurity
                                        target:self
                                      selector:@selector(timerExpired:)
                                 timerInterval:securityLockoutTime];
	}
}

+ (void)removeTimer
{
    [SFInactivityTimerCenter removeTimer:kTimerSecurity];
}

static NSString *const kSecurityLockoutSessionId = @"securityLockoutSession";

+ (void)unlock:(BOOL)success action:(SFSecurityLockoutAction)action
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self unlock:success action:action];
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
    [self log:SFLogLevelInfo msg:@"Inactivity NSTimer expired."];
    [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
        [[SFAuthenticationManager sharedManager] logout];
    }];
	[SFSecurityLockout lock];
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
    
	if(![[SFPasscodeManager sharedManager] passcodeIsSet]) {
		[SFSecurityLockout presentPasscodeController:SFPasscodeControllerModeCreate];
	} else {
        [SFSecurityLockout presentPasscodeController:SFPasscodeControllerModeVerify];
    }
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

+ (void)presentPasscodeController:(SFPasscodeControllerMode)modeValue
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentPasscodeController:modeValue];
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
        UIViewController *passcodeViewController = passcodeVcCreationBlock(modeValue, [SFSecurityLockout passcodeLength]);
        [SFSecurityLockout setPasscodeViewController:passcodeViewController];
        SFPasscodeViewControllerPresentationBlock presentBlock = [SFSecurityLockout presentPasscodeViewControllerBlock];
        presentBlock(passcodeViewController);
    }
}

+ (void)sendPasscodeFlowWillBeginNotification:(SFPasscodeControllerMode)mode
{
    [self log:SFLogLevelDebug format:@"Sending passcode flow will begin notification with mode %d", mode];
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

+ (void)setValidatePasscodeAtStartup:(BOOL)validateAtStartup
{
    sValidatePasscodeAtStartup = validateAtStartup;
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
    SFKeychainItemWrapper *keychainWrapper = [[SFKeychainItemWrapper alloc] initWithIdentifier:kKeychainIdentifierLockoutTime account:nil];
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
    SFKeychainItemWrapper *keychainWrapper = [[SFKeychainItemWrapper alloc] initWithIdentifier:kKeychainIdentifierLockoutTime account:nil];
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
    SFKeychainItemWrapper *keychainWrapper = [[SFKeychainItemWrapper alloc] initWithIdentifier:kKeychainIdentifierIsLocked account:nil];
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
    SFKeychainItemWrapper *keychainWrapper = [[SFKeychainItemWrapper alloc] initWithIdentifier:kKeychainIdentifierIsLocked account:nil];
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

