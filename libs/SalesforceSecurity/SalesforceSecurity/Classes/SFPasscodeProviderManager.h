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

#import <Foundation/Foundation.h>

/**
 * String representing the provider name for the SHA-256 passcode provider.
 */
extern NSString * const kSFPasscodeProviderSHA256;

/**
 * String representing the provider name for the PBKDF2 passcode provider.
 */
extern NSString * const kSFPasscodeProviderPBKDF2;

/**
 * Protocol that a passcode provider class must implement.
 */
@protocol SFPasscodeProvider <NSObject>

/**
 * The canonical name of this passcode provider.
 */
@property (nonatomic, readonly) NSString *providerName;

/**
 * Designated initializer for an SFPasscodeProvider.
 * @param providerName The canonical name of the provider.
 */
- (id)initWithProviderName:(NSString *)providerName;

/**
 * Reset (unset) the passcode and any persisted data associated with it.
 */
- (void)resetPasscodeData;

/**
 * Verify that the input passcode is the correct passcode.
 * @param passcode The passcode to verify.
 * @return YES if the passcode is verified, NO otherwise.
 */
- (BOOL)verifyPasscode:(NSString *)passcode;

/**
 * @return The hashed verification passcode, or nil if not configured.
 */
- (NSString *)hashedVerificationPasscode;

/**
 * Set/persist the verification passcode, based on the input passcode.
 * @param newPasscode The new (plaintext) passcode to set.
 */
- (void)setVerificationPasscode:(NSString *)newPasscode;

/**
 * Generates an encryption key, based on the input passcode.
 * NOTE: This method must generate the same encryption key for the given
 * input passcode.
 * @param passcode The (plaintext) passcode used to generate the encryption key.
 * @return The encryption key generated from the passcode.
 */
- (NSString *)generateEncryptionKey:(NSString *)passcode;

@optional

@end

/**
 * Class for managing passcode providers.
 */
@interface SFPasscodeProviderManager : NSObject

/**
 * The name of the currently configured passcode provider.  There can only be one "current"
 * passcode provider at any given time, though multiple passcode providers can be worked
 * with, usign the [SFPasscodeProviderManager passcodeProviderForProviderName:] method.
 * @return The name of the currently configured passcode provider.
 */
+ (NSString *)currentPasscodeProviderName;

/**
 * Sets the current passcode provider.  Note: the passcode provider implementation class itself
 * must first be configured through the [SFPasscodeProviderManager addPasscodeProvider:name:]
 * method.  The default providers in the SDK will already be configured.
 * @param providerName The name of the passcode provider that will become the current provider.
 */
+ (void)setCurrentPasscodeProviderByName:(NSString *)providerName;

/**
 * @return The provider implementation for the current passcode provider.
 */
+ (id<SFPasscodeProvider>)currentPasscodeProvider;

/**
 * Returns the passcode provider implementation associated with the given provider name, or
 * `nil` if no provider is configured for the given name.
 * @param providerName The name associated with the requested provider.
 * @return The passcode provider implementation.
 */
+ (id<SFPasscodeProvider>)passcodeProviderForProviderName:(NSString *)providerName;

/**
 * Adds a custom passcode provider implementation to the global provider configuration.
 * Note: custom providers are not persisted across app restarts.  You should call this method
 * to add your provider in your app's initialization logic.
 * @param provider The passcode provider implementation.
 */
+ (void)addPasscodeProvider:(id<SFPasscodeProvider>)provider;

/**
 * Removes a passcode provider from configuration.  If it is designated as the current-configured provider,
 * the current provider will be reset to the default value.
 * @param providerName The name of the provider to remove.
 */
+ (void)removePasscodeProviderWithName:(NSString *)providerName;


@end
