//
//  SFKeychainItemWrapper.h
//  SalesforceCommonUtils
//
//  Created by Amol Prabhu on 1/11/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 This is a wrapper class used to interact with the keychain.
 */
@interface SFKeychainItemWrapper : NSObject {
    NSMutableDictionary *_keychainQuery;
}

@property (nonatomic, retain) NSMutableDictionary *keychainData;

/*!
 Determines if the keychain wrapper should encrypt/decrypt keychain sensitive data like refreshtoken
 */
@property (nonatomic) BOOL encrypted;

/*!
 Designated initializer
 */
- (id)initWithIdentifier:(NSString *)identifier account:(NSString *)account;
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
/*!
 sets passcode in keychain, input is an already hashed passcode. needed for v1 to v2 upgrade
 */
- (void)setHashedPasscode:(NSString *)passcode;

/*!
 oAuth token related methods
 */
- (void)setToken:(NSData *)token;
- (NSData *)token;

/**
 Store arbitrary data to the keychain for the service (identifier) and account specified in the initializer.
 @param data Arbitrary data to store to in the keychain. May be `nil`.
 */
- (void)setValueData:(NSData *)data;

/**
 Read arbitrary data from the keychain for the service (identifier) and account specified in the initializer.
 @return Arbitrary data read from the keychain. May be `nil`.
 */
- (NSData *)valueData;

@end
