//
//  SFAbstractPasscodeViewController.h
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 1/13/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFSecurityLockout.h"

@interface SFAbstractPasscodeViewController : UIViewController

/**
 * The minimum passcode length, which this view controller will enforce.
 */
@property (readonly) NSInteger minPasscodeLength;

/**
 * Whether or not this controller is in a passcode creation or verification mode.
 */
@property (readonly) SFPasscodeControllerMode mode;

@property (readonly) NSInteger numAttempts;

- (id)initWithMode:(SFPasscodeControllerMode)mode minPasscodeLength:(NSInteger)minPasscodeLength;
- (void)createPasscodeConfirmed:(NSString *)newPasscode;
- (void)validatePasscodeConfirmed:(NSString *)validPasscode;
- (BOOL)decrementPasscodeAttempts;
- (void)validatePasscodeFailed;

/**
 * Gets the (persisted) remaining attempts available for verifying a passcode.
 */
- (NSInteger)remainingAttempts;

/**
 * Sets the (persisted) remaining attempts for verifying a passcode.
 */
- (void)setRemainingAttempts:(NSUInteger)remainingAttempts;

@end
