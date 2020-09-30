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

#import <Foundation/Foundation.h>
#import "SalesforceSDKConstants.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Notification that will be posted when passcode is reset. This notification will have userInfo
 populated with old passcode stored with `SFPasscodeResetOldPasscodeKey` key and new passcode
 stored with `SFPasscodeResetNewPasscodeKey` key.
 */
extern NSString *const SFPasscodeResetNotification SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/** Key in userInfo published by `SFPasscodeResetNotification`.
 
 The value of this key is the old hashed passcode before the passcode reset
 */
extern NSString *const SFPasscodeResetOldPasscodeKey SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");


/** Key in userInfo published by `SFPasscodeResetNotification`.
 
 The value of this key is the new hashed passcode that triggers the new passcode reset
 */
extern NSString *const SFPasscodeResetNewPasscodeKey SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

@class SFPasscodeManager;

/**
 Delegate protocol for SFPasscodeManager callbacks
 */
SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.")
@protocol SFPasscodeManagerDelegate <NSObject>

@optional

/**
 Notifies delegates of an encryption key change.
 @param manager The passcode manager instance making the change.
 @param oldKey The old encryption key.
 @param newKey The new encryption key.
 */
- (void)passcodeManager:(SFPasscodeManager *)manager didChangeEncryptionKey:(NSString *)oldKey toEncryptionKey:(NSString *)newKey;

@end

/**
 Class for managing storage, retrieval, and verification of passcodes.
 */
SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.")
@interface SFPasscodeManager : NSObject

/**
 @return The shared instance of the passcode manager.
 */
+ (SFPasscodeManager *)sharedManager SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 The encryption key associated with the app.
 */
@property (nonatomic, readonly, nullable) NSString *encryptionKey SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 The preferred passcode provider for the app.  If another provider was previously configured,
 the passcode manager will automatically update to the preferred provider at the next passcode
 update or verification.
 */
@property (nonatomic, copy) NSString *preferredPasscodeProvider SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 The lenght of the user's passcode.
 */
@property (nonatomic) NSUInteger passcodeLength SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 Whether the device has the capability to use biometric unlock.
 */
@property (nonatomic) BOOL deviceHasBiometric SFSDK_DEPRECATED(8.3, 9.0, "Use deviceHasBiometric on SFSecurityLockout instead");

/**
 Adds a delegate to the list of passcode manager delegates.
 @param delegate Delegate to add to the list.
 */
- (void)addDelegate:(id<SFPasscodeManagerDelegate>)delegate SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 Removes a delegate from the delegate list.  No action is taken if the delegate does not exist.
 @param delegate Delegate to be removed.
 */
- (void)removeDelegate:(id<SFPasscodeManagerDelegate>)delegate SFSDK_DEPRECATED(8.3, 9.0, "Will be removed.");

/**
 @return Whether or not a passcode has been set.
 */
- (BOOL)passcodeIsSet SFSDK_DEPRECATED(8.3, 9.0, "Use isPasscodeSet on SFSecurityLockout instead.");

/**
 Reset the passcode in the keychain.
 */
- (void)resetPasscode SFSDK_DEPRECATED(8.3, 9.0, "Will be internal.");

/**
 Verify the passcode.
 @param passcode The passcode to verify.
 @return YES if the passcode verifies, NO otherwise.
 */
- (BOOL)verifyPasscode:(NSString *)passcode SFSDK_DEPRECATED(8.3, 9.0, "Will be internal.");

/**
 Change the current passcode.  This method serves as an entry point for managing the change
 or removal of a passcode, notifications of the change, etc.  The setPasscode method, by
 comparison, handles the internals of actually setting a new passcode value.
 @param newPasscode The new passcode to change to.  If nil or empty, this method will unset the
 existing passcode.
 */
- (void)changePasscode:(nullable NSString *)newPasscode SFSDK_DEPRECATED(8.3, 9.0, "Will be internal.");

/**
 Set the passcode.
 @param newPasscode The passcode to set.
 */
- (void)setPasscode:(NSString *)newPasscode SFSDK_DEPRECATED(8.3, 9.0, "Will be internal.");

@end

NS_ASSUME_NONNULL_END
