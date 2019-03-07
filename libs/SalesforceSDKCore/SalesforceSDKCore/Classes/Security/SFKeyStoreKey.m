/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFKeyStoreKey.h"
#import "SFKeychainItemWrapper.h"

// NSCoding constants
static NSString * const kKeyStoreKeyDataArchiveKey = @"com.salesforce.keystore.keyStoreKeyDataArchive";

@implementation SFKeyStoreKey

+ (instancetype) createKey
{
    SFEncryptionKey *encKey = [SFEncryptionKey createKey];
    SFKeyStoreKey *keyStoreKey = [[SFKeyStoreKey alloc] initWithKey:encKey];
    return keyStoreKey;
}

- (instancetype)initWithKey:(SFEncryptionKey *)key
{
    self = [super init];
    if (self) {
        self.encryptionKey = key;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.encryptionKey = [aDecoder decodeObjectForKey:kKeyStoreKeyDataArchiveKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.encryptionKey forKey:kKeyStoreKeyDataArchiveKey];
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    SFKeyStoreKey *keyCopy = [[[self class] allocWithZone:zone] init];
    keyCopy.encryptionKey = [self.encryptionKey copy];
    return keyCopy;
}

+ (nullable instancetype)fromKeyChain:(NSString*)keychainId archiverKey:(NSString*)archiverKey
{
    SFKeyStoreKey* keyStoreKey;
    SFKeychainItemWrapper *keychainItem = [SFKeychainItemWrapper itemWithIdentifier:keychainId account:nil];
    NSData *keyStoreKeyData = [keychainItem valueData];
    if (keyStoreKeyData == nil) {
        return nil;
    } else {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:keyStoreKeyData];
        keyStoreKey = [unarchiver decodeObjectForKey:archiverKey];
        [unarchiver finishDecoding];
        
        return keyStoreKey;
    }
}

- (OSStatus) toKeyChain:(NSString*)keychainId archiverKey:(NSString*)archiverKey
{
    SFKeychainItemWrapper *keychainItem = [SFKeychainItemWrapper itemWithIdentifier:keychainId account:nil];
    NSMutableData *keyStoreKeyData = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:keyStoreKeyData];
    [archiver encodeObject:self forKey:archiverKey];
    [archiver finishEncoding];
    return [keychainItem setValueData:keyStoreKeyData];
}

- (NSData*)encryptData:(NSData *)dataToEncrypt
{
    return [self.encryptionKey encryptData:dataToEncrypt];
}

- (NSData*)decryptData:(NSData *)dataToDecrypt
{
    return [self.encryptionKey decryptData:dataToDecrypt];
}

@end
