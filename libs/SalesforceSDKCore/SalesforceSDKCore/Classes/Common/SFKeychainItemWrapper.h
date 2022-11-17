/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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
 
 Until Apple fixes the issue, please DO NOT ARC this class!
 
 Relevant links and info:
 - https://devforums.apple.com/thread/246122
 - https://forums.developer.apple.com/thread/4743
 - https://github.com/ResearchKit/AppCore/issues/119
 - https://github.com/soffes/sskeychain/issues/52
 
 Apple parent radar for this issue is 18766047. 'Open' as of 2015-08-27
 
 */

#import <Foundation/Foundation.h>

// Keychain item exception defines
SFSDK_DEPRECATED("9.1", "10.0", "Will be removed in Mobile SDK 10.0")
typedef NS_ENUM(NSUInteger, SFKeychainItemExceptionErrorCode) {
    SFKeychainItemExceptionKeychainInaccessible = 1,
};

extern NSString * _Nullable const kSFKeychainItemExceptionType SFSDK_DEPRECATED("9.1", "10.0", "Will be removed in Mobile SDK 10.0.");
extern NSString * _Nullable const kSFKeychainItemExceptionErrorCodeKey SFSDK_DEPRECATED("9.1", "10.0", "Will be removed in Mobile SDK 10.0.");

/**
 This class is a wrapper class used to interact with the keychain.
 */
SFSDK_DEPRECATED("9.1", "10.0", "Will be removed in Mobile SDK 10.0, use SFSDKKeychainHelper instead.")
API_UNAVAILABLE(macCatalyst)
@interface SFKeychainItemWrapper : NSObject 

/**
 Returns the accessible attribute used to store this keychain item.
 */
@property (nonatomic, readonly, nullable) CFTypeRef accessibleAttribute SFSDK_DEPRECATED("9.1", "10.0", "Will be removed in Mobile SDK 10.0. Use SFKeychainHelper instead.");

/**
 @return Indicates whether keychain access errors cause a fatal exception.  Default is YES.
 */
+ (BOOL)keychainAccessErrorsAreFatal SFSDK_DEPRECATED("9.1", "10.0", "Will be removed in Mobile SDK 10.0.");

/**
 Sets whether or not keychain access errors cause a fatal exception.
 @param errorsAreFatal Whether keychain access errors should be fatal.
 */
+ (void)setKeychainAccessErrorsAreFatal:(BOOL)errorsAreFatal SFSDK_DEPRECATED("9.1", "10.0", "Will be removed in Mobile SDK 10.0. Use SFKeychainHelper instead.");

/**
 Sets the accessible attribute used by this keychain item wrapper class.
 If the previous attribute value is different, this method will trigger
 an update of all the items in the keychain.
 @param accessibleAttribute The accessible attribute for this keychain item wrapper class.
 */
+ (void)setAccessibleAttribute:(nullable CFTypeRef)accessibleAttribute SFSDK_DEPRECATED("9.1", "10.0", "Will be removed in Mobile SDK 10.0. Use SFKeychainHelper instead.");

/**
 Factory method to hand out an SFKeychainItemWrapper object with the given identifier and account.
 Note that, for any given combination of identifier and account, only one object will be created
 at runtime.  Subsequent requests will return the same object.
 @param identifier Identifier to use for the SFKeychainItemWrapper object.
 @param account Account to use for the SFKeychainItemWrapper object.
 */
+ (nullable SFKeychainItemWrapper *)itemWithIdentifier:(nullable NSString *)identifier account:(nullable NSString *)account SFSDK_DEPRECATED("9.1", "10.0", "Will be removed in Mobile SDK 10.0. Use SFKeychainHelper instead.");

/**
 Reset the keychain item.
 */
- (BOOL)resetKeychainItem SFSDK_DEPRECATED("9.1", "10.0", "Will be removed in Mobile SDK 10.0. Use SFKeychainHelper instead.");

/**
 Store arbitrary data to the keychain for the service (identifier) and account specified in the initializer.
 @param data Arbitrary data to store in the keychain. Can be `nil`.
 @return The status of the keychain update request.
 */
- (OSStatus)setValueData:(nullable NSData *)data SFSDK_DEPRECATED("9.1", "10.0", "Will be removed in Mobile SDK 10.0. Use SFKeychainHelper instead.");

/**
 Read arbitrary string from the keychain for the service (identifier) and account specified in the initializer.
 @return Arbitrary string read from the keychain. Can be `nil`.
 */
- (nullable NSString *)valueString SFSDK_DEPRECATED("9.1", "10.0", "Will be removed in Mobile SDK 10.0. Use SFKeychainHelper instead.");

/**
 Store arbitrary string to the keychain for the service (identifier) and account specified in the initializer.
 @param string Arbitrary string to store in the keychain. Can be `nil`.
 @return The status of the keychain update request.
 */
- (OSStatus)setValueString:(nullable NSString *)string SFSDK_DEPRECATED("9.1", "10.0", "Will be removed in Mobile SDK 10.0. Use SFKeychainHelper instead.");

/**
 Read arbitrary data from the keychain for the service (identifier) and account specified in the initializer.
 @return Arbitrary data read from the keychain. Can be `nil`.
 */
- (nullable NSData *)valueData SFSDK_DEPRECATED("9.1", "10.0", "Will be removed in Mobile SDK 10.0. Use SFKeychainHelper instead.");

/**
 Return a string value for an `OSStatus` error code.
 @param errorCode The code to stringify.
 @return The string version of the error code.
 */
+ (nullable NSString *)keychainErrorCodeString:(OSStatus)errorCode SFSDK_DEPRECATED("9.1", "10.0", "Will be removed in Mobile SDK 10.0. Use SFKeychainHelper instead.");

@end
