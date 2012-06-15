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
- (id)initWithIdentifier: (NSString *)identifier account:(NSString *) account;
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
/*!
 @deprecated use the `token` method instead
 */
- (NSData *)getToken;

@end
