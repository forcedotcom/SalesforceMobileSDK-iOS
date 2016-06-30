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

#import "SFPBKDF2PasscodeProvider.h"
#import "SFKeychainItemWrapper.h"
#import "SFPBKDFData.h"
#import "SFSDKCryptoUtils.h"
#import "NSData+SFAdditions.h"

static NSString * const kKeychainIdentifierPasscodeVerify = @"com.salesforce.security.passcode.pbkdf2.verify";
static NSString * const kKeychainIdentifierPasscodeEncrypt = @"com.salesforce.security.passcode.pbkdf2.encrypt";
static NSString * const kPBKDFArchiveDataKey = @"pbkdfDataArchive";

@interface SFPBKDF2PasscodeProvider ()

- (SFPBKDFData *)passcodeData:(NSString *)keychainIdentifier;
- (void)setPasscodeData:(SFPBKDFData *)passcodeData keychainId:(NSString *)keychainIdentifier;

@end

@implementation SFPBKDF2PasscodeProvider

@synthesize saltLengthInBytes = _saltLengthInBytes;
@synthesize numDerivationRounds = _numDerivationRounds;
@synthesize derivedKeyLengthInBytes = _derivedKeyLengthInBytes;
@synthesize providerName = _providerName;

#pragma mark - SFPasscodeProvider

- (instancetype)initWithProviderName:(SFPasscodeProviderId)providerName
{
    self = [super init];
    if (self) {
        NSAssert(providerName != nil, @"providerName cannot be nil.");
        _providerName = [providerName copy];
        self.saltLengthInBytes = kSFPBKDFDefaultSaltByteLength;
        self.numDerivationRounds = kSFPBKDFDefaultNumberOfDerivationRounds;
        self.derivedKeyLengthInBytes = kSFPBKDFDefaultDerivedKeyByteLength;
    }
    
    return self;
}

- (void)resetPasscodeData
{
    SFKeychainItemWrapper *keychainWrapper = [SFKeychainItemWrapper itemWithIdentifier:kKeychainIdentifierPasscodeVerify account:nil];
    [keychainWrapper resetKeychainItem];
    keychainWrapper = [SFKeychainItemWrapper itemWithIdentifier:kKeychainIdentifierPasscodeEncrypt account:nil];
    [keychainWrapper resetKeychainItem];
}

- (BOOL)verifyPasscode:(NSString *)passcode
{
    SFPBKDFData *passcodeData = [self passcodeData:kKeychainIdentifierPasscodeVerify];
    
    // Sanity check data.
    if (passcodeData == nil) {
        [self log:SFLogLevelError msg:@"No passcode data found.  Cannot verify passcode."];
        return NO;
    } else if (passcodeData.derivedKey == nil) {
        [self log:SFLogLevelError msg:@"Passcode key has not been set.  Cannot verify passcode."];
        return NO;
    } else if (passcodeData.salt == nil) {
        [self log:SFLogLevelError msg:@"Passcode salt has not been set.  Cannot verify passcode."];
        return NO;
    } else if (passcodeData.numDerivationRounds == 0) {
        [self log:SFLogLevelError msg:@"Number of derivation rounds has not been set.  Cannot verify passcode."];
        return NO;
    }
    
    // Generate verification key from input passcode.
    SFPBKDFData *verifyData = [SFSDKCryptoUtils createPBKDF2DerivedKey:passcode
                                                                  salt:passcodeData.salt
                                                      derivationRounds:passcodeData.numDerivationRounds
                                                             keyLength:[passcodeData.derivedKey length]];
    return [passcodeData.derivedKey isEqualToData:verifyData.derivedKey];
}

- (NSString *)hashedVerificationPasscode
{
    SFPBKDFData *pbkdfData = [self passcodeData:kKeychainIdentifierPasscodeVerify];
    NSString *keyDataAsString = (pbkdfData != nil ? [pbkdfData.derivedKey base64Encode] : nil);
    return keyDataAsString;
}

- (void)setVerificationPasscode:(NSString *)newPasscode
{
    if (newPasscode == nil) {
        [self resetPasscodeData];
        return;
    }
    
    NSData *salt = [SFSDKCryptoUtils randomByteDataWithLength:self.saltLengthInBytes];
    SFPBKDFData *pbkdfData = [SFSDKCryptoUtils createPBKDF2DerivedKey:newPasscode
                                                                 salt:salt
                                                     derivationRounds:self.numDerivationRounds
                                                            keyLength:self.derivedKeyLengthInBytes];
    [self setPasscodeData:pbkdfData keychainId:kKeychainIdentifierPasscodeVerify];
}

- (NSString *)generateEncryptionKey:(NSString *)passcode
{
    NSData *salt;
    NSUInteger numDerivationRounds;
    NSUInteger derivedKeyLength;
    SFPBKDFData *existingEncData = [self passcodeData:kKeychainIdentifierPasscodeEncrypt];
    
    // We have to use an existing salt, number of derivation rounds, and derived key length, if present,
    // so we generate the same key that was originally created.
    if (existingEncData != nil) {
        salt = existingEncData.salt;
        numDerivationRounds = existingEncData.numDerivationRounds;
        derivedKeyLength = existingEncData.derivedKeyLength;
    } else {
        salt = [SFSDKCryptoUtils randomByteDataWithLength:self.saltLengthInBytes];
        numDerivationRounds = self.numDerivationRounds;
        derivedKeyLength = self.derivedKeyLengthInBytes;
    }
    
    SFPBKDFData *generatedKeyData = [SFSDKCryptoUtils createPBKDF2DerivedKey:passcode salt:salt derivationRounds:numDerivationRounds keyLength:derivedKeyLength];
    NSString *encodedKey = [generatedKeyData.derivedKey base64Encode];
    if (existingEncData == nil) {
        // No existing data.  We need to store the key configuration data for future use, minus the
        // key--we don't store that for encryption.
        generatedKeyData.derivedKey = nil;
        [self setPasscodeData:generatedKeyData keychainId:kKeychainIdentifierPasscodeEncrypt];
    }
    
    return encodedKey;
}

#pragma mark - Private methods

- (SFPBKDFData *)passcodeData:(NSString *)keychainIdentifier
{
    SFKeychainItemWrapper *keychainWrapper = [SFKeychainItemWrapper itemWithIdentifier:keychainIdentifier account:nil];
    NSData *keychainPasscodeData = [keychainWrapper valueData];
    if (keychainPasscodeData == nil) {
        return nil;
    }
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:keychainPasscodeData];
    SFPBKDFData *pbkdfData = [unarchiver decodeObjectForKey:kPBKDFArchiveDataKey];
    [unarchiver finishDecoding];
    
    return pbkdfData;
}

- (void)setPasscodeData:(SFPBKDFData *)passcodeData keychainId:(NSString *)keychainIdentifier
{
    NSMutableData *passcodeDataObj = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:passcodeDataObj];
    [archiver encodeObject:passcodeData forKey:kPBKDFArchiveDataKey];
    [archiver finishEncoding];
    
    SFKeychainItemWrapper *keychainWrapper = [SFKeychainItemWrapper itemWithIdentifier:keychainIdentifier account:nil];
    [keychainWrapper setValueData:passcodeDataObj];
    
}

@end
