/*
 Copyright (c) 2013, salesforce.com, inc. All rights reserved.
 
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

#import "SFPasscodeManager.h"

@interface SFPasscodeManager ()

@property (nonatomic, strong, nonnull) NSHashTable<id<SFPasscodeManagerDelegate>> *delegates;

/**
 Executes the given block against the set of delegates.
 @param block The block to execute against each delegate.
 */
- (void)enumerateDelegates:(nullable void (^)(id<SFPasscodeManagerDelegate> _Nonnull))block;

/**
 Set a value for the encryption key.  Note: this is just the internal setter for
 the encryptionKey property.  I.e. the value you set should be the end-result
 encryption key value.  Call setEncryptionKeyForPasscode if you want validation
 and encryption based on a plain-text passcode value.
 @param newEncryptionKey The new value for the encryption key.
 */
- (void)setEncryptionKey:(nullable NSString *)newEncryptionKey;

/**
 Set the value of the encryption key, based on the input passcode.  Note: this method
 will not set the encryption key if a verification passcode is not set and valid, in
 the interests of maintaining a consistent passcode state.
 @param passcode The passcode to convert into an encryption key.
 */
- (void)setEncryptionKeyForPasscode:(nonnull NSString *)passcode;

@end
