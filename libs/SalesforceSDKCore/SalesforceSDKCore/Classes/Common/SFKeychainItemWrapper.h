/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

/**
 This class is left to remain non-ARC INTENTIONALLY!
 
 There is a known issue reported by many developers on Apple Developer Forum and
 Github, detailing an issue related to error code -34018. Apple acknowledged the
 issue, yet has not provided a solution or workaround, and has not shared much
 about the root cause of the issue. Last reported case was encountered on iOS 9
 beta 2.
 
 The only proven workaround was to keep the class implementation non-ARC.
 
 Until, Apple fixes the issue, please DO NOT ARC this class!
 
 Relevant links and info:
 - https://devforums.apple.com/thread/246122
 - https://forums.developer.apple.com/thread/4743
 - https://github.com/ResearchKit/AppCore/issues/119
 - https://github.com/soffes/sskeychain/issues/52
 
 Apple parent radar for this issue is 18766047. 'Open' as of 2015-08-27
 
 */

#import <Foundation/Foundation.h>

// Keychain item exception defines

typedef NS_ENUM(NSUInteger, SFKeychainItemExceptionErrorCode) {
    SFKeychainItemExceptionKeychainInaccessible = 1,
};

extern NSString * const kSFKeychainItemExceptionType;
extern NSString * const kSFKeychainItemExceptionErrorCodeKey;

/**
 This is a wrapper class used to interact with the keychain.
 */
@interface SFKeychainItemWrapper : NSObject

/**
 Determines if the keychain wrapper should encrypt/decrypt keychain sensitive data like refreshtoken
 */
@property (nonatomic) BOOL encrypted;

/**
 Returns the accessible attribute used to store this keychain item
 */
@property (nonatomic, readonly) CFTypeRef accessibleAttribute;

/**
 @return Whether or not keychain access errors cause a fatal exception.  Default is YES.
 */
+ (BOOL)keychainAccessErrorsAreFatal;

/**
 Sets whether or not keychain access errors cause a fatal exception.
 @param errorsAreFatal Whether keychain access errors should be fatal.
 */
+ (void)setKeychainAccessErrorsAreFatal:(BOOL)errorsAreFatal;

/**
 Sets the accessible attribute used by this keychain item wrapper class.
 If the previous attribute value is different, this method will trigger
 an update of all the items in the keychain.
 @param accessibleAttribute The accessible attribute for this keychain item wrapper class.
 */
+ (void)setAccessibleAttribute:(CFTypeRef)accessibleAttribute;

/**
 Factory method to hand out an SFKeychainItemWrapper object with the given identifier and account.
 Note that, for any given combination of identifier and account, only one object will be created
 at runtime.  Subsequent requests will return the same object.
 @param identifier Identifier to use for the SFKeychainItemWrapper object.
 @param account Account to use for the SFKeychainItemWrapper object.
 */
+ (SFKeychainItemWrapper *)itemWithIdentifier:(NSString *)identifier account:(NSString *)account;

/**
 Reset the keychain item.
 */
- (BOOL)resetKeychainItem;

/* Passcode related methods */

/**
 Sets the passcode in the keychain.
 @param passcode Plain text passcode
 */
- (void)setPasscode:(NSString *)passcode;
/** The passcode.
 */
- (NSString *)passcode;
/** Performs passcode verification.
 @param passcode The passcode to verify.
 */
- (BOOL)verifyPasscode:(NSString *)passcode;

/**
 Store arbitrary data to the keychain for the service (identifier) and account specified in the initializer.
 @param data Arbitrary data to store to in the keychain. May be `nil`.
 @return The status of the keychain update request.
 */
- (OSStatus)setValueData:(NSData *)data;

/**
 Read arbitrary data from the keychain for the service (identifier) and account specified in the initializer.
 @return Arbitrary data read from the keychain. May be `nil`.
 */
- (NSData *)valueData;

/**
 Return a string value for an OSStatus error code.
 @param errorCode The code to stringify
 @return The string version of the error code.
 */
+ (NSString *)keychainErrorCodeString:(OSStatus)errorCode;

@end
