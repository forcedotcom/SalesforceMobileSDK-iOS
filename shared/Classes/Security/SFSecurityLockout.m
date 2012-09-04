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
#import "SFInactivityTimerCenter.h"
#import "SFPasscodeViewController.h"
#import "SFOAuthCredentials.h"
#import "SFKeychainItemWrapper.h"
#import "SFLogger.h"
#import "SFAccountManager.h"
#import "SFPasscodeManager.h"
#import "SFSmartStore.h"

// Private constants

static NSUInteger const kDefaultLockoutTime                  = 0;
static NSUInteger const kDefaultPasscodeLength               = 5;
static NSString * const kSecurityTimeoutKey                  = @"security.timeout";
static NSString * const kTimerSecurity                       = @"security.timer";
static NSString * const kPasscodeLengthKey                   = @"security.passcode.length";
static NSString * const kPasscodeScreenAlreadyPresentMessage = @"A passcode screen is already present.";
static NSString * const kSecurityIsLockedKey                 = @"security.islocked";

// Public constants

static NSUInteger              securityLockoutTime;
static UIViewController        *sPasscodeViewController        = nil;
static SFLockScreenCallbackBlock sLockScreenSuccessCallbackBlock = NULL;
static SFLockScreenCallbackBlock sLockScreenFailureCallbackBlock = NULL;

// Flag used to prevent the display of the passcode view controller.
// Note: it is used by the unit tests only.
static BOOL _showPasscode = YES;

@implementation SFSecurityLockout

+ (void)initialize {
	NSNumber *n = [[NSUserDefaults standardUserDefaults] objectForKey:kSecurityTimeoutKey];
	if(n) {
		securityLockoutTime = [n intValue];
	} else {
		securityLockoutTime = kDefaultLockoutTime;
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
    NSNumber *nPasscodeLength = [NSNumber numberWithInt:passcodeLength];
    [[NSUserDefaults standardUserDefaults] setObject:nPasscodeLength forKey:kPasscodeLengthKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSInteger)passcodeLength
{
    NSNumber *nPasscodeLength = [[NSUserDefaults standardUserDefaults] objectForKey:kPasscodeLengthKey];
    return (nPasscodeLength != nil ? [nPasscodeLength intValue] : kDefaultPasscodeLength);
}

+ (BOOL)hasValidSession
{
    return [[SFAccountManager sharedInstance] credentials] != nil
        && [[SFAccountManager sharedInstance] credentials].accessToken != nil;
}

+ (void)setLockoutTime:(NSUInteger)seconds {
	securityLockoutTime = seconds;
    
    [self log:SFLogLevelInfo format:@"Setting lockout time to: %d", seconds]; 
    
	NSNumber *n = [NSNumber numberWithInt:securityLockoutTime];
	[[NSUserDefaults standardUserDefaults] setObject:n forKey:kSecurityTimeoutKey];
	if (securityLockoutTime == 0) {  // 0 = security code is removed.
        if ([[SFPasscodeManager sharedManager] hashedPasscode] != nil) {
            // TODO: Any content/artifacts tied to this passcode should get untied here (encrypted content, etc.).
        }
		[SFSecurityLockout unlock:YES];
		[[SFPasscodeManager sharedManager] resetPasscode];
		[SFInactivityTimerCenter removeTimer:kTimerSecurity];
	} else { 
		if (![SFSecurityLockout isPasscodeValid]) {
            // TODO: Again, new passcode, so make sure related content/artifacts are updated.
            
            [SFSecurityLockout presentPasscodeController:SFPasscodeControllerModeCreate];
		}
        else {
            [SFSecurityLockout setupTimer];
            [SFSecurityLockout unlockSuccessPostProcessing];  // "Unlocking" was a success, since no lock required.
        }
	}
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// For unit tests.
+ (void)setLockoutTimeInternal:(NSUInteger)seconds
{
    securityLockoutTime = seconds;
}

+ (NSUInteger)lockoutTime {
	return securityLockoutTime;
}

+ (BOOL)inactivityExpired {
	NSInteger elapsedTime = [[NSDate date] timeIntervalSinceDate:[SFInactivityTimerCenter lastActivityTimestamp]];
	return (securityLockoutTime > 0) && (elapsedTime > securityLockoutTime);
}

+ (void)setupTimer {
	if(securityLockoutTime > 0) {
		[SFInactivityTimerCenter registerTimer:kTimerSecurity
                                        target:self
                                      selector:@selector(timerExpired:)
                                 timerInterval:securityLockoutTime];
	}
}

+ (void)removeTimer {
    [SFInactivityTimerCenter removeTimer:kTimerSecurity];
}

static NSString *const kSecurityLockoutSessionId = @"securityLockoutSession";

+ (void)unlock:(BOOL)success {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self unlock:success];
        });
        return;
    }
    
	if ([self locked]) {
        UIViewController *passVc = [SFSecurityLockout passcodeViewController];
        if (passVc != nil) {
            if (success) {
                [passVc.presentingViewController dismissViewControllerAnimated:YES
                                                                    completion:^{
                                                                        [SFSecurityLockout setPasscodeViewController:nil];
                                                                        [SFSecurityLockout unlockSuccessPostProcessing];
                                                                    }];
            } else {
                [passVc.presentingViewController dismissViewControllerAnimated:YES
                                                                    completion:^{
                                                                        [SFSecurityLockout setPasscodeViewController:nil];
                                                                        [SFSecurityLockout unlockFailurePostProcessing];
                                                                    }];
            }
        } else {  // Not sure how this would happen, but for completeness sake.
            if (success)
                [SFSecurityLockout unlockSuccessPostProcessing];
            else
                [SFSecurityLockout unlockFailurePostProcessing];
        }
	} 
}

+ (void)timerExpired:(NSTimer*)theTimer {
    [self log:SFLogLevelInfo msg:@"Inactivity NSTimer expired."];
    [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
        id<UIApplicationDelegate> appDelegate = [[UIApplication sharedApplication] delegate];
        if ([appDelegate respondsToSelector:@selector(logout)]) {
            [appDelegate performSelector:@selector(logout)];
        }
    }];
	[SFSecurityLockout lock];
}

+ (void)lock
{
	if(![SFSecurityLockout hasValidSession]) {
		[self log:SFLogLevelInfo msg:@"Skipping 'lock' since not authenticated"];
		return;
	}
    
    if (![[SFAccountManager sharedInstance] mobilePinPolicyConfigured]) {
        [self log:SFLogLevelInfo msg:@"Skipping 'lock' since pin policies are not configured."];
        return;
    }
    
	if([[SFPasscodeManager sharedManager] hashedPasscode] == nil) {
		[SFSecurityLockout presentPasscodeController:SFPasscodeControllerModeCreate];
	} else {
        [SFSecurityLockout presentPasscodeController:SFPasscodeControllerModeVerify];
    }
    [self log:SFLogLevelInfo msg:@"Device locked."];
}

+ (void)presentPasscodeController:(SFPasscodeControllerMode)modeValue {
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
        [self log:SFLogLevelInfo msg:@"Setting window to key window."];
        UIWindow *topWindow = [[UIApplication sharedApplication] keyWindow];
        SFPasscodeViewController *pvc = nil;
        if (modeValue == SFPasscodeControllerModeCreate ) {
            pvc = [[[SFPasscodeViewController alloc] initForPasscodeCreation:[SFSecurityLockout passcodeLength]] autorelease];
        } else {
            pvc = [[[SFPasscodeViewController alloc] initForPasscodeVerification] autorelease];
        }
        UINavigationController *nc = [[[UINavigationController alloc] initWithRootViewController:pvc] autorelease];
        [SFSecurityLockout setPasscodeViewController:nc];
        UIViewController *presentingViewController;
        if (topWindow.rootViewController.presentedViewController != nil)
            presentingViewController = topWindow.rootViewController.presentedViewController;
        else
            presentingViewController = topWindow.rootViewController;
        [presentingViewController presentViewController:nc animated:YES completion:NULL];
    }
}

+ (void)setIsLocked:(BOOL)locked {
	[[NSUserDefaults standardUserDefaults] setBool:locked forKey:kSecurityIsLockedKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)locked {
	return [[NSUserDefaults standardUserDefaults] boolForKey:kSecurityIsLockedKey];
}

+ (BOOL)isPasscodeValid {
	if(securityLockoutTime == 0) return YES; // no passcode is required.
    return([[SFPasscodeManager sharedManager] hashedPasscode] != nil);
}

+ (BOOL)isLockoutEnabled {
	return securityLockoutTime > 0;
}

+ (void)setPasscodeViewController:(UIViewController *)vc
{
    if (vc != sPasscodeViewController) {
        UIViewController *oldValue = sPasscodeViewController;
        sPasscodeViewController = [vc retain];
        [oldValue release];
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
        SFLockScreenCallbackBlock oldValue = sLockScreenFailureCallbackBlock;
        sLockScreenFailureCallbackBlock = [block copy];
        [oldValue release];
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
        SFLockScreenCallbackBlock oldValue = sLockScreenSuccessCallbackBlock;
        sLockScreenSuccessCallbackBlock = [block copy];
        [oldValue release];
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
        SFLockScreenCallbackBlock blockCopy = [[[SFSecurityLockout lockScreenSuccessCallbackBlock] copy] autorelease];
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:NULL];
        blockCopy();
    }
}

+ (void)unlockFailurePostProcessing
{
    [self setIsLocked:NO];
    [SFSecurityLockout setLockScreenSuccessCallbackBlock:NULL];
    if ([SFSecurityLockout lockScreenFailureCallbackBlock] != NULL) {
        SFLockScreenCallbackBlock blockCopy = [[[SFSecurityLockout lockScreenFailureCallbackBlock] copy] autorelease];
        [SFSecurityLockout setLockScreenFailureCallbackBlock:NULL];
        blockCopy();
    }
}

#pragma mark keychain methods

+ (void)setPasscode:(NSString *)passcode
{
    // Get the old passcode, before changing.
    NSString *oldHashedPasscode = [[SFPasscodeManager sharedManager] hashedPasscode];
    if (oldHashedPasscode == nil) oldHashedPasscode = @"";
    
    if (passcode == nil || [passcode length] == 0) {
        [[SFPasscodeManager sharedManager] resetPasscode];
    } else if (securityLockoutTime == 0) {
        [self log:SFLogLevelInfo msg:@"Skipping passcode set since lockout timer is 0."];
        [[SFPasscodeManager sharedManager] resetPasscode];
    } else {
        [[SFPasscodeManager sharedManager] setPasscode:passcode];
    }
    
    NSString *newHashedPasscode = [[SFPasscodeManager sharedManager] hashedPasscode];
    if (newHashedPasscode == nil) newHashedPasscode = @"";
    
    [SFSmartStore changeKeyForStores:oldHashedPasscode newKey:newHashedPasscode];
}

+ (void)setCanShowPasscode:(BOOL)showPasscode {
    _showPasscode = showPasscode;
}

@end

