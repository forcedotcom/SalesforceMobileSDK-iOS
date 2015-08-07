//
//  SFKeychainItemWrapper.h
//  SalesforceCommonUtils
//
//  Created by Amol Prabhu on 1/11/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

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
@interface SFKeychainItemWrapper : NSObject {
    NSMutableDictionary *_keychainQuery;
}

/*!
 @return Whether or not keychain access errors cause a fatal exception.  Default is YES.
 */
+ (BOOL)keychainAccessErrorsAreFatal;

/*!
 Sets whether or not keychain access errors cause a fatal exception.
 @param errorsAreFatal Whether keychain access errors should be fatal.
 */
+ (void)setKeychainAccessErrorsAreFatal:(BOOL)errorsAreFatal;

/*!
 Determines if the keychain wrapper should encrypt/decrypt keychain sensitive data like refreshtoken
 */
@property (nonatomic) BOOL encrypted;

/*!
 Factory method to hand out an SFKeychainItemWrapper object with the given identifier and account.
 Note that, for any given combination of identifier and account, only one object will be created
 at runtime.  Subsequent requests will return the same object.
 */
+ (SFKeychainItemWrapper *)itemWithIdentifier:(NSString *)identifier account:(NSString *)account;

/*!
 Reset the keychain item
 */
- (BOOL)resetKeychainItem;

/*!
 Passcode related methods
 */
/*!
 sets passcode in keychain, input is plain text passcode
 */
- (void)setPasscode:(NSString *)passcode;
- (NSString *)passcode;
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
