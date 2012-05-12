/*
 SecurityLockout.m
 Chatter
 Created by Amol Prabhu on 10/6/11.
 Copyright 2011 Salesforce.com. All rights reserved.
 */

#import "SFSecurityLockout.h"
#import "SFInactivityTimerCenter.h"

static NSUInteger const kDefaultLockoutTime = 600; 
static NSString * const kSecurityTimeoutKey = @"security.timeout";
static NSString * const kSecurityIsLockedKey = @"security.islocked";
static NSString * const kTimerSecurity = @"security.timer";
static NSUInteger securityLockoutTime;
NSString * const kKeychainIdentifierPasscode = @"com.salesforce.security.passcode";

static NSUInteger const kPadPasscodeViewWidth  = 322; /// Width of the wrapper view for iPad (from the UI specs).
static NSUInteger const kPadPasscodeViewHeight = 367; /// Height of the wrapper view for iPad (from the UI specs).

// Flag used to prevent the display of the passcode view controller.
// Note: it is used by the unit tests only.
static BOOL _showPasscode = YES;

@interface SFSecurityLockout() 

+ (void)timerExpired:(NSTimer *)theTimer;
+ (void)presentPasscodeController:(NSNumber *)modeValue;

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
            NSLog(@"timer expired");
            [SFSecurityLockout lock];
        } 
        else {
            [SFSecurityLockout setupTimer];
            [SFInactivityTimerCenter updateActivityTimestamp];	
        }
    } 
}

+ (void)setLockoutTime:(NSUInteger)seconds {
	securityLockoutTime = seconds;
    
    NSLog(@"Setting lockout time to: %d", seconds); 
    
	NSNumber *n = [NSNumber numberWithInt:securityLockoutTime];
	[[NSUserDefaults standardUserDefaults] setObject:n forKey:kSecurityTimeoutKey];
	if (seconds == 0) {
        if ([SFSecurityLockout hashedPasscode] != nil) {
            // TODO: Any content/artifacts tied to this passcode should get untied here (encrypted content, etc.).
        }
		[SFSecurityLockout unlock];
		[SFSecurityLockout resetPasscode];
		[SFInactivityTimerCenter removeTimer:kTimerSecurity];
	} else { 
		if (![SFSecurityLockout isPasscodeValid]) {
            // TODO: Again, new passcode, so make sure related content/artifacts are updated.
            [SFSecurityLockout presentPasscodeController:[NSNumber numberWithInt:(int)ChatterPasscodeControllerModeCreate]];
		}
        else {
            [SecurityLockout setupTimer];
        }
	}
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSUInteger)lockoutTime {
	return securityLockoutTime;
}

+ (BOOL)inactivityExpired {
	NSInteger elapsedTime = [[NSDate date] timeIntervalSinceDate:[InactivityTimerCenter lastActivityTimestamp]];
	return (securityLockoutTime > 0) && (elapsedTime > securityLockoutTime);
}

+ (void)setupTimer {
	if(securityLockoutTime > 0) {
		[InactivityTimerCenter registerTimer:kTimerSecurity	target:self selector:@selector(timerExpired:) timerInterval:securityLockoutTime];
	}
}

+ (void)removeTimer {
    [InactivityTimerCenter removeTimer:kTimerSecurity];
}

static NSString *const kSecurityLockoutSessionId = @"securityLockoutSession";

+ (void)unlock {
	if([self locked]) {
        [[SplashScreenManager sharedInstance] endPresentationSession:kSecurityLockoutSessionId];
        
        [self setIsLocked:NO];
	} 
}

+ (void)timerExpired:(NSTimer*)theTimer {
    [self log:Info msg:@"Inactivity NSTimer expired."];
	[SecurityLockout lock];
}

+ (void)lock {
	if(![[SFUserAccountManager sharedInstance] haveValidSession]) {
		[self log:Info msg:@"skipping 'lock' since not authenticated"];
		return;
	}
	if([SecurityLockout hashedPasscode] == nil) {
		[SecurityLockout presentPasscodeController:[NSNumber numberWithInt:(int)ChatterPasscodeControllerModeCreate]];
		return;
	}
    
    [SecurityLockout presentPasscodeController:[NSNumber numberWithInt:(int)ChatterPasscodeControllerModeVerify]];
    [self log:Info msg:@"Device locked."];
}

+ (void)presentPasscodeController:(NSNumber *)modeValue {
    [self setIsLocked:YES];
    if (_showPasscode) {
        SplashScreenManager *manager = [SplashScreenManager sharedInstance];    
        [manager beginPresentationSession:kSecurityLockoutSessionId block:^{
            ChatterPasscodeControllerMode mode = (ChatterPasscodeControllerMode)[modeValue intValue];
            UIViewController *passcodeViewController = [[ChatterPasscodeViewController alloc] initWithMode:mode];
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                passcodeViewController.view.frame = CGRectMake(0.0, 0.0, kPadPasscodeViewWidth, kPadPasscodeViewHeight);
            }
            [manager presentNestedViewController:passcodeViewController options:UIViewAnimationOptionTransitionFlipFromRight];            
            [passcodeViewController release];
        }];
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
    return([SecurityLockout hashedPasscode] != nil);
}

+ (BOOL)isLockoutEnabled {
	return securityLockoutTime > 0;
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

