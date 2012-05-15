/*
 SecurityLockout.m
 Chatter
 Created by Amol Prabhu on 10/6/11.
 Copyright 2011 Salesforce.com. All rights reserved.
 */

#import "SFSecurityLockout.h"
#import "SFInactivityTimerCenter.h"
#import "SFPasscodeViewController.h"
#import "SFOAuthCredentials.h"

static NSUInteger const kDefaultLockoutTime                  = 600; 
static NSString * const kSecurityTimeoutKey                  = @"security.timeout";
static NSString * const kTimerSecurity                       = @"security.timer";
static NSString * const kPasscodeScreenAlreadyPresentMessage = @"A passcode screen is already present.";
static NSString * const kSecurityIsLockedKey                 = @"security.islocked";
//NSString * const kKeychainIdentifierPasscode = @"com.salesforce.security.passcode";
//static NSUInteger const kPadPasscodeViewWidth  = 322; /// Width of the wrapper view for iPad (from the UI specs).
//static NSUInteger const kPadPasscodeViewHeight = 367; /// Height of the wrapper view for iPad (from the UI specs).

static NSUInteger         securityLockoutTime;
static SFOAuthCredentials *sOAuthCredentials = nil; 
static UIViewController   *sPasscodeViewController = nil;

// Flag used to prevent the display of the passcode view controller.
// Note: it is used by the unit tests only.
static BOOL _showPasscode = YES;

@interface SFSecurityLockout() 

+ (void)timerExpired:(NSTimer *)theTimer;
+ (void)presentPasscodeController:(SFPasscodeControllerMode)modeValue;
+ (void)setPasscodeViewController:(UIViewController *)vc;
+ (UIViewController *)passcodeViewController;
+ (BOOL)passcodeScreenIsPresent;
+ (BOOL)hasValidSession;

@end

@implementation SFSecurityLockout

+ (void)initialize {
	NSNumber *n = [[NSUserDefaults standardUserDefaults] objectForKey:kSecurityTimeoutKey];
	if(n) {
		securityLockoutTime = [n intValue];
	} else {
		securityLockoutTime = kDefaultLockoutTime;
	}
}

+ (void)didLogin {
    [SFSecurityLockout validateTimer];
}

+ (void)validateTimer {
    if ([SFSecurityLockout isPasscodeValid]) {
        if([SFSecurityLockout inactivityExpired] || [SFSecurityLockout locked]) {
            NSLog(@"Timer expired.");
            [SFSecurityLockout lock];
        } 
        else {
            [SFSecurityLockout setupTimer];
            [SFInactivityTimerCenter updateActivityTimestamp];	
        }
    } 
}

+ (void)setCredentials:(SFOAuthCredentials *)credentials
{
    if (credentials != sOAuthCredentials) {
        SFOAuthCredentials *oldValue = sOAuthCredentials;
        sOAuthCredentials = [credentials retain];
        [oldValue release];
    }
}

+ (SFOAuthCredentials *)credentials
{
    return sOAuthCredentials;
}

+ (BOOL)hasValidSession
{
    return [self credentials] != nil && [self credentials].accessToken != nil;
}

+ (void)setLockoutTime:(NSUInteger)seconds {
	securityLockoutTime = seconds;
    
    NSLog(@"Setting lockout time to: %d", seconds); 
    
	NSNumber *n = [NSNumber numberWithInt:securityLockoutTime];
	[[NSUserDefaults standardUserDefaults] setObject:n forKey:kSecurityTimeoutKey];
	if (securityLockoutTime == 0) {  // 0 = security code is removed.
        if ([SFSecurityLockout hashedPasscode] != nil) {
            // TODO: Any content/artifacts tied to this passcode should get untied here (encrypted content, etc.).
        }
		[SFSecurityLockout unlock];
		[SFSecurityLockout resetPasscode];
		[SFInactivityTimerCenter removeTimer:kTimerSecurity];
	} else { 
		if (![SFSecurityLockout isPasscodeValid]) {
            // TODO: Again, new passcode, so make sure related content/artifacts are updated.
            
            if ([SFSecurityLockout passcodeScreenIsPresent]) {
                return;
            }
            [SFSecurityLockout presentPasscodeController:SFPasscodeControllerModeCreate];
		}
        else {
            [SFSecurityLockout setupTimer];
        }
	}
    [[NSUserDefaults standardUserDefaults] synchronize];
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

+ (void)unlock {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self unlock];
        });
        return;
    }
    
	if([self locked]) {
        UIViewController *passVc = [SFSecurityLockout passcodeViewController];
        if (passVc != nil) {
            [passVc.presentingViewController dismissModalViewControllerAnimated:YES];
            [SFSecurityLockout setPasscodeViewController:nil];
        }
        
        [self setIsLocked:NO];
	} 
}

+ (void)timerExpired:(NSTimer*)theTimer {
    NSLog(@"Inactivity NSTimer expired.");
	[SFSecurityLockout lock];
}

+ (void)lock {
	if(![SFSecurityLockout hasValidSession]) {
		NSLog(@"skipping 'lock' since not authenticated");
		return;
	}
    
    if ([SFSecurityLockout passcodeScreenIsPresent]) {
        return;
    }
    
	if([SFSecurityLockout hashedPasscode] == nil) {
		[SFSecurityLockout presentPasscodeController:SFPasscodeControllerModeCreate];
	} else {
        [SFSecurityLockout presentPasscodeController:SFPasscodeControllerModeVerify];
    }
    NSLog(@"Device locked.");
}

+ (void)presentPasscodeController:(SFPasscodeControllerMode)modeValue {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentPasscodeController:modeValue];
        });
        return;
    }
    
    [self setIsLocked:YES];
    if (_showPasscode) {
        UIWindow *topWindow = [[[UIApplication sharedApplication].windows sortedArrayUsingComparator:^NSComparisonResult(UIWindow *win1, UIWindow *win2)
                                                                                                     {
                                                                                                         return win1.windowLevel - win2.windowLevel;
                                                                                                     }] lastObject];
        SFPasscodeViewController *pvc = [[[SFPasscodeViewController alloc] initWithMode:modeValue] autorelease];
        UINavigationController *nc = [[[UINavigationController alloc] initWithRootViewController:pvc] autorelease];
        [SFSecurityLockout setPasscodeViewController:nc];
        [topWindow.rootViewController presentModalViewController:nc animated:NO];
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
    return([SFSecurityLockout hashedPasscode] != nil);
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

+ (BOOL)passcodeScreenIsPresent
{
    if ([SFSecurityLockout passcodeViewController] != nil) {
        NSLog(@"%@", kPasscodeScreenAlreadyPresentMessage);
        return YES;
    } else {
        return NO;
    }
}

#pragma mark keychain methods

+ (NSString *)hashedPasscode {
    CHKeychainItemWrapper *passcodeWrapper = [[[CHKeychainItemWrapper alloc] initWithIdentifier:kKeychainIdentifierPasscode account:nil] autorelease];
    return [passcodeWrapper passcode];
}

+ (void)resetPasscode {
    [self log:Info msg:@"reseting passcode upon logout"];
    CHKeychainItemWrapper *passcodeWrapper = [[CHKeychainItemWrapper alloc] initWithIdentifier:kKeychainIdentifierPasscode account:nil];
    [passcodeWrapper resetKeychainItem];
    [passcodeWrapper release];
}

+ (BOOL)verifyPasscode:(NSString *)passcode {
    CHKeychainItemWrapper *passcodeWrapper = [[[CHKeychainItemWrapper alloc] initWithIdentifier:kKeychainIdentifierPasscode account:nil] autorelease];
    return [passcodeWrapper verifyPasscode:passcode];
}

+ (void)setPasscode:(NSString *)passcode{
	if(passcode == nil) {
		[SecurityLockout resetPasscode];
		return;
	}
	if(securityLockoutTime == 0) {
		[self log:Info msg:@"skipping passcode set since lockout timer is 0"];
		return;
	}
    CHKeychainItemWrapper *passcodeWrapper = [[CHKeychainItemWrapper alloc] initWithIdentifier:kKeychainIdentifierPasscode account:nil];
    [passcodeWrapper setPasscode:passcode];
    [passcodeWrapper release];
}

+ (void)setCanShowPasscode:(BOOL)showPasscode {
    _showPasscode = showPasscode;
}

@end

