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
#import "SFSmartStore.h"
#import "SFAuthenticationManager.h"
#import "SFRootViewManager.h"
#import "SFPreferences.h"

// Private constants

static NSUInteger const kDefaultPasscodeLength               = 5;
static NSString * const kTimerSecurity                       = @"security.timer";
static NSString * const kPasscodeLengthKey                   = @"security.passcode.length";
static NSString * const kPasscodeScreenAlreadyPresentMessage = @"A passcode screen is already present.";
static NSString * const kKeychainIdentifierLockoutTime       = @"com.salesforce.security.lockoutTime";
static NSString * const kKeychainIdentifierIsLocked          = @"com.salesforce.security.isLocked";

// Public constants

NSString * const kSFPasscodeFlowWillBegin = @"SFPasscodeFlowWillBegin";
NSString * const kSFPasscodeFlowCompleted = @"SFPasscodeFlowCompleted";

// Notification that will be sent out when passcode is reset
NSString *const SFPasscodeResetNotification = @"SFPasscodeResetNotification";

// Key in userInfo published by `SFPasscodeResetNotification` to store old hashed passcode before the passcode reset
NSString *const SFPasscodeResetOldPasscodeKey = @"SFPasscodeResetOldPasswordKey";


// Key in userInfo published by `SFPasscodeResetNotification` to store the new hashed passcode that triggers the new passcode reset
NSString *const SFPasscodeResetNewPasscodeKey = @"SFPasscodeResetOldPasswordKey";

// Static vars

static NSUInteger              securityLockoutTime;
static UIViewController        *sPasscodeViewController        = nil;
static SFLockScreenCallbackBlock sLockScreenSuccessCallbackBlock = NULL;
static SFLockScreenCallbackBlock sLockScreenFailureCallbackBlock = NULL;
static SFPasscodeViewControllerCreationBlock sPasscodeViewControllerCreationBlock = NULL;
static SFPasscodeViewControllerPresentationBlock sPresentPasscodeViewControllerBlock = NULL;
static SFPasscodeViewControllerPresentationBlock sDismissPasscodeViewControllerBlock = NULL;
static NSMutableOrderedSet *sDelegates = nil;
static BOOL sForcePasscodeDisplay = NO;

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
            [SFSecurityLockout writeLockoutTimeToKeychain:[NSNumber numberWithUnsignedInteger:kDefaultLockoutTime]];
        } else {
            [SFSecurityLockout writeLockoutTimeToKeychain:lockoutTime];
        }
    }
    
    // Is locked
    NSNumber *n = [SFSecurityLockout readIsLockedFromKeychain];
    if (n == nil) {
        // Try to fall back to the user defaults if isLocked isn't found in the keychain
        BOOL locked = [[NSUserDefaults standardUserDefaults] boolForKey:kSecurityIsLockedLegacyKey];
        [SFSecurityLockout writeIsLockedToKeychain:[NSNumber numberWithBool:locked]];
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
            [SFSecurityLockout unlockSuccessPostProcessing];  // "Unlock" was successful, as locking wasn't required.
        }
    } 
}

+ (void)setPasscodeLength:(NSInteger)passcodeLength
{
    NSNumber *nPasscodeLength = [NSNumber numberWithInteger:passcodeLength];
    [[SFPreferences currentUserLevelPreferences] setObject:nPasscodeLength forKey:kPasscodeLengthKey];
    [[SFPreferences currentUserLevelPreferences] synchronize];
}

+ (NSInteger)passcodeLength
{
    NSNumber *nPasscodeLength = [[SFPreferences currentUserLevelPreferences] objectForKey:kPasscodeLengthKey];
    return (nPasscodeLength != nil ? [nPasscodeLength intValue] : kDefaultPasscodeLength);
}

+ (BOOL)hasValidSession
{
    return [[SFAuthenticationManager sharedManager] haveValidSession];
}

+ (void)setLockoutTime:(NSUInteger)seconds
{
    securityLockoutTime = seconds;
    
    [self log:SFLogLevelInfo format:@"Setting lockout time to: %d", seconds];
    
    NSNumber *n = [NSNumber numberWithUnsignedInteger:securityLockoutTime];
    [SFSecurityLockout writeLockoutTimeToKeychain:n];
    if (securityLockoutTime == 0) {  // 0 = security code is removed.
        if ([[SFPasscodeManager sharedManager] passcodeIsSet]) {
            // TODO: Any content/artifacts tied to this passcode should get untied here (encrypted content, etc.).
        }
        [SFSecurityLockout unlock:YES];
        
        // Call setPasscode to trigger extra clean up logic.
        [SFSecurityLockout setPasscode:nil];
        
        [SFInactivityTimerCenter removeTimer:kTimerSecurity];
    } else {
        if (![SFSecurityLockout isPasscodeValid]) {
            // TODO: Again, new passcode, so make sure related content/artifacts are updated.
            
            [SFSecurityLockout presentPasscodeController:SFPasscodeControllerModeCreate];
        } else {
            [SFSecurityLockout setupTimer];
            [SFSecurityLockout unlockSuccessPostProcessing];  // "Unlocking" was a success, since no lock required.
        }
    }
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
	return (securityLockoutTime > 0) && (elapsedTime > securityLockoutTime);
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

+ (void)unlock:(BOOL)success
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self unlock:success];
        });
        return;
    }
    
	if ([self locked]) {
        [self sendPasscodeFlowCompletedNotification:success];
        UIViewController *passVc = [SFSecurityLockout passcodeViewController];
        if (passVc != nil) {
            SFPasscodeViewControllerPresentationBlock dismissBlock = [SFSecurityLockout dismissPasscodeViewControllerBlock];
            dismissBlock(passVc);
            [SFSecurityLockout setPasscodeViewController:nil];
            if (success) {
                [SFSecurityLockout unlockSuccessPostProcessing];
            } else {
                [SFSecurityLockout unlockFailurePostProcessing];
            }
        } else {  // Not sure how this would happen, but for completeness sake.
            if (success)
                [SFSecurityLockout unlockSuccessPostProcessing];
            else
                [SFSecurityLockout unlockFailurePostProcessing];
        }
        [self enumerateDelegates:^(id<SFSecurityLockoutDelegate> delegate) {
            if ([delegate respondsToSelector:@selector(passcodeFlowDidComplete:)]) {
                [delegate passcodeFlowDidComplete:success];
            }
        }];
	} 
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
            return;
        }
        
        if (![[SFAuthenticationManager sharedManager] mobilePinPolicyConfigured]) {
            [self log:SFLogLevelInfo msg:@"Skipping 'lock' since pin policies are not configured."];
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
                                                      object:[NSNumber numberWithBool:validationSuccess]
                                                    userInfo:nil];
    [[NSNotificationCenter defaultCenter] postNotification:n];
}

+ (void)setIsLocked:(BOOL)locked
{
    [SFSecurityLockout writeIsLockedToKeychain:[NSNumber numberWithBool:locked]];
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
    BOOL result = [self inactivityExpired] || ![self isPasscodeValid];
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

+ (void)setLockScreenFailureCallbackBlock:(SFLockScreenCallbackBlock)block
{
    // Callback blocks can't be altered if the passcode screen is already in progress.
    if (![SFSecurityLockout passcodeScreenIsPresent] && sLockScreenFailureCallbackBlock != block) {
        sLockScreenFailureCallbackBlock = [block copy];
    }
}

+ (SFLockScreenCallbackBlock)lockScreenFailureCallbackBlock
{
    return sLockScreenFailureCallbackBlock;
}

+ (void)setLockScreenSuccessCallbackBlock:(SFLockScreenCallbackBlock)block
{
    // Callback blocks can't be altered if the passcode screen is already in progress.
    if (![SFSecurityLockout passcodeScreenIsPresent] && sLockScreenSuccessCallbackBlock != block) {
        sLockScreenSuccessCallbackBlock = [block copy];
    }
}

+ (SFLockScreenCallbackBlock)lockScreenSuccessCallbackBlock
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

+ (void)unlockSuccessPostProcessing
{
    [self setIsLocked:NO];
    [SFSecurityLockout setLockScreenFailureCallbackBlock:NULL];
    if ([SFSecurityLockout lockScreenSuccessCallbackBlock] != NULL) {
        SFLockScreenCallbackBlock blockCopy = [[SFSecurityLockout lockScreenSuccessCallbackBlock] copy];
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:NULL];
        blockCopy();
    }
}

+ (void)unlockFailurePostProcessing
{
    [self setIsLocked:NO];
    [SFSecurityLockout setLockScreenSuccessCallbackBlock:NULL];
    if ([SFSecurityLockout lockScreenFailureCallbackBlock] != NULL) {
        SFLockScreenCallbackBlock blockCopy = [[SFSecurityLockout lockScreenFailureCallbackBlock] copy];
        [SFSecurityLockout setLockScreenFailureCallbackBlock:NULL];
        blockCopy();
    }
}

#pragma mark keychain methods

+ (void)setPasscode:(NSString *)passcode
{
    // Get the old encryption key, before changing.
    NSString *oldEncryptionKey = [SFPasscodeManager sharedManager].encryptionKey;
    if (oldEncryptionKey == nil) oldEncryptionKey = @"";
    
    if (passcode == nil || [passcode length] == 0) {
        [[SFPasscodeManager sharedManager] resetPasscode];
    } else if (securityLockoutTime == 0) {
        [self log:SFLogLevelInfo msg:@"Skipping passcode set since lockout timer is 0."];
        [[SFPasscodeManager sharedManager] resetPasscode];
    } else {
        [[SFPasscodeManager sharedManager] setPasscode:passcode];
    }
    
    NSString *newEncryptionKey = [SFPasscodeManager sharedManager].encryptionKey;
    if (newEncryptionKey == nil) newEncryptionKey = @"";
    
    if (![oldEncryptionKey isEqualToString:newEncryptionKey]) {
        //Passcode changed, post the notification
        [[NSNotificationCenter defaultCenter] postNotificationName:SFPasscodeResetNotification object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:oldEncryptionKey, SFPasscodeResetOldPasscodeKey, newEncryptionKey, SFPasscodeResetNewPasscodeKey, nil]];
    }
    
    [SFSmartStore changeKeyForStores:oldEncryptionKey newKey:newEncryptionKey];
}

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
        time = [NSNumber numberWithUnsignedInteger:i];
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
        locked = [NSNumber numberWithBool:b];
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

