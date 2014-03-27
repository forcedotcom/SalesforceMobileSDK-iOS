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

#import <Foundation/Foundation.h>

/**
 Class for managing storage, retrieval, and verification of passcodes.
 */
@interface SFPasscodeManager : NSObject

/**
 @return The shared instance of the passcode manager.
 */
+ (SFPasscodeManager *)sharedManager;

/**
 The encryption key associated with the app.
 */
@property (nonatomic, readonly) NSString *encryptionKey;

/**
 The preferred passcode provider for the app.  If another provider was previously configured,
 the passcode manager will automatically update to the preferred provider at the next passcode
 update or verification.
 */
@property (nonatomic, copy) NSString *preferredPasscodeProvider;

/**
 @return Whether or not a passcode has been set.
 */
- (BOOL)passcodeIsSet;

/**
 Reset the passcode in the keychain.
 */
- (void)resetPasscode;

/**
 Verify the passcode.
 @param passcode The passcode to verify.
 @return YES if the passcode verifies, NO otherwise.
 */
- (BOOL)verifyPasscode:(NSString *)passcode;

/**
 Set the passcode.
 @param newPasscode The passcode to set.
 */
- (void)setPasscode:(NSString *)newPasscode;

@end
