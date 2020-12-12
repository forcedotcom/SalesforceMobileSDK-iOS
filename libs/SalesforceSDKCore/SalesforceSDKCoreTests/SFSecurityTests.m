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

#import <XCTest/XCTest.h>
#import <CommonCrypto/CommonCrypto.h>
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFKeyStoreManager+Internal.h"
#import "SFKeyStore+Internal.h"
#import "SFSecurityLockout+Internal.h"

static NSUInteger const kNumThreadsInSafetyTest = 100;

@interface SFKeyStoreManager ()

- (void)renameKeysWithKeyTypePasscode:(SFGeneratedKeyStore*)generatedKeyStore;

- (void)switchToSecureKeyIfNeeded:(SFGeneratedKeyStore*)generatedKeyStore;

@end;

@interface SFSecurityTests : XCTestCase
{
    SFKeyStoreManager *mgr;
    BOOL _threadSafetyTestCompleted;
    NSMutableArray *_completedThreads;
}
- (void)keyStoreThreadSafeHelper;
- (void)assertKeyForDictionary: (NSDictionary*)dictionary withLabel: (NSString*)label hasEncryptionKey:(SFEncryptionKey*)encKey;
@end

// high level test scenarios (ie, more than a unit test)
@implementation SFSecurityTests

- (void)setUp {
    [super setUp];

    // No passcode, to start.
    [SFSecurityLockout changePasscode:nil];
    mgr = [SFKeyStoreManager sharedInstance];
}

- (void)tearDown {
    [super tearDown];
}

// Kick off a bunch of threads and, while threads are still doing things, randomly change passcodes.
- (void)testKeyStoreThreadSafety
{
    // set up passcode
    [SFSecurityLockout changePasscode:@"12345"];
    
    // start threads
    _threadSafetyTestCompleted = NO;
    _completedThreads = [NSMutableArray array];
    for (NSInteger i = 0; i < kNumThreadsInSafetyTest; i++) {
        [self performSelectorInBackground:@selector(keyStoreThreadSafeHelper) withObject:nil];
    }

    // randomly change passcodes
    while (!_threadSafetyTestCompleted) {
        // Passcode change chaos.
        NSUInteger randomInt = arc4random() % 10;
        if (randomInt > 4) {
            NSString *newPasscode = [[SFSDKCryptoUtils randomByteDataWithLength:32] base64EncodedStringWithOptions: 0];
            [SFSecurityLockout changePasscode:newPasscode];
        }
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
}

#pragma mark - Upgrade tests

- (void)testUpgradeTo71
{
    // Pre SDK 7.1, key store were encrypted using SFEncryptionKey
    // Starting in SDK 7.1, key store are encrypted using SFSecureEncryptionKey
    
    SFGeneratedKeyStore *keyStore = [[SFGeneratedKeyStore alloc] init];
    keyStore.keyStoreKey = [SFKeyStoreKey createKey];
    NSDictionary *data = @{@"one":@"", @"two":@""};

    // Check encryptiong key type before upgrade
    XCTAssertFalse([keyStore.keyStoreKey.encryptionKey isKindOfClass:[SFSecureEncryptionKey class]]);

    // set
    [keyStore setKeyStoreDictionary:data];
    
    // Now upgrade store to use secure encryption key
    [mgr switchToSecureKeyIfNeeded:keyStore];
    
    // Check encryptiong key type after upgrade
    XCTAssertTrue([keyStore.keyStoreKey.encryptionKey isKindOfClass:[SFSecureEncryptionKey class]]);

    // get
    NSDictionary *retrievedData = [keyStore keyStoreDictionary];
    
    XCTAssertTrue([data isEqualToDictionary:retrievedData], @"Dictionaries should be equal");
}

#pragma mark - Private methods
- (void)keyStoreThreadSafeHelper
{
    static NSUInteger keyId = 1;
    
    // generate a new key
    NSString *keyName = [NSString stringWithFormat:@"%@%ld", @"threadSafeKeyName", (unsigned long)keyId++];
    SFEncryptionKey *origKey = [SFEncryptionKey createKey];
    
    // store it
    [mgr storeKey:origKey withLabel:keyName];
    XCTAssertTrue([mgr keyWithLabelExists:keyName], @"Key '%@' should exist in the key store.", keyName);
    
    // get it back
    SFEncryptionKey *retrievedKey = [mgr retrieveKeyWithLabel:keyName autoCreate:NO];
    XCTAssertEqualObjects(origKey, retrievedKey, @"Keys with label '%@' are not equal", keyName);
    
    // remove it
    [mgr removeKeyWithLabel:keyName];
    XCTAssertFalse([mgr keyWithLabelExists:keyName], @"Key '%@' should no longer exist in key store after removal.", keyName);
    
    // update state so main loop will know when all threads are done
    @synchronized (self) {
        [_completedThreads addObject:keyName];
        if ([_completedThreads count] == kNumThreadsInSafetyTest) {
            _threadSafetyTestCompleted = YES;
        }
    }
}

// general assertions for the given key
- (void)assertKeyForDictionary: (NSDictionary*)dictionary withLabel: (NSString*)label hasEncryptionKey:(SFEncryptionKey*)encKey
{
    SFKeyStoreKey *key = [dictionary valueForKey:label];
    XCTAssertEqualObjects(key.encryptionKey.keyAsString, encKey.keyAsString, @"Encryption keys do not match");
}

@end
