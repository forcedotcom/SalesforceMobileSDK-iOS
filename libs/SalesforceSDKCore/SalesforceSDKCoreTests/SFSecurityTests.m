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

static NSUInteger const kNumThreadsInSafetyTest = 100;

@interface SFKeyStoreManager ()

- (void)renameKeysWithKeyTypePasscode:(SFGeneratedKeyStore*)generatedKeyStore;

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
    [[SFPasscodeManager sharedManager] changePasscode:nil];
    mgr = [SFKeyStoreManager sharedInstance];
}

- (void)tearDown {
    [super tearDown];
}

// Kick off a bunch of threads and, while threads are still doing things, randomly change passcodes.
- (void)testKeyStoreThreadSafety
{
    // set up passcode mgr
    [[SFPasscodeManager sharedManager] changePasscode:@"12345"];
    
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
            [[SFPasscodeManager sharedManager] changePasscode:newPasscode];
        }
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
}

#pragma mark - Upgrade tests

- (void)testUpgradeTo60NoPasscode
{
    // Pre SDK 6.0 code would store keys with keytype passcode in generated store if there was no passcode enabled
    // Starting with SDK 6.0, we don't pass the keytype anymore (it's always generated)
    // When initializing the generated key store, the keys named xxx__Passcode should be automatically renamed to xxx_Generated

    NSString *keyLabel = @"keyLabel";
    
    // Manually inserting key with key type passcode in generated store
    SFPasscodeKeyStore *passcodeKeyStore = [[SFPasscodeKeyStore alloc] init]; // only used to create the right label for the key
    SFEncryptionKey *encryptionKey = [mgr keyWithRandomValue];
    SFKeyStoreKey *keyStoreKey = [[SFKeyStoreKey alloc] initWithKey:encryptionKey];
    NSString *originalKeyLabel = [passcodeKeyStore keyLabelForString:keyLabel];
    XCTAssertEqualObjects(@"keyLabel__Passcode", originalKeyLabel);
    NSMutableDictionary *mutableKeyStoreDict = [NSMutableDictionary dictionaryWithDictionary:mgr.generatedKeyStore.keyStoreDictionary];
    mutableKeyStoreDict[originalKeyLabel] = keyStoreKey;
    mgr.generatedKeyStore.keyStoreDictionary = mutableKeyStoreDict;

    // Make sure it was saved in generated key store
    [self assertKeyForDictionary:mgr.generatedKeyStore.keyStoreDictionary
                       withLabel:originalKeyLabel
                hasEncryptionKey:encryptionKey];
    
    // Make sure it cannot be retrieved currently
    XCTAssertNil([mgr retrieveKeyWithLabel:keyLabel autoCreate:NO]);

    // We want to simulate an upgrade
    // Migration happens at start up when renameKeysWithKeyTypePasscode runs
    [mgr renameKeysWithKeyTypePasscode:mgr.generatedKeyStore];
    
    // Make sure the key was renamed
    NSString *newKeyLabel = [mgr.generatedKeyStore keyLabelForString:keyLabel];
    XCTAssertEqualObjects(@"keyLabel__Generated", newKeyLabel);
    XCTAssertFalse([mgr.generatedKeyStore.keyStoreDictionary objectForKey:originalKeyLabel]);
    XCTAssertTrue([mgr.generatedKeyStore.keyStoreDictionary objectForKey:newKeyLabel]);
    [self assertKeyForDictionary:mgr.generatedKeyStore.keyStoreDictionary
                       withLabel:newKeyLabel
                hasEncryptionKey:encryptionKey];

    // Make sure we can now retrieve the key through the SFKeyStoreManager
    SFEncryptionKey *retrievedKey = [mgr retrieveKeyWithLabel:keyLabel autoCreate:NO];
    XCTAssertEqualObjects(retrievedKey.keyAsString, encryptionKey.keyAsString, @"Encryption keys do not match");
    
    // Cleanup
    [mgr removeKeyWithLabel:keyLabel];
}

- (void)testUpgradeTo60PasscodeEnabled
{
    NSString *keyLabel = @"keyLabel";
    NSString *passcode = @"passcode";

    SFPasscodeKeyStore * passcodeKeyStore = [[SFPasscodeKeyStore alloc] init];
    XCTAssertFalse([passcodeKeyStore keyStoreAvailable], @"Passcode key store should not be ready.");

    [[SFPasscodeManager sharedManager] changePasscode:passcode];

    // SFKeyStoreManager no longer deals with passcode key store in SDK 6.0
    // To simulate pre-6.0 code, we have to create the passcode key store and then insert key into it "manually"

    // Create a new passcode key store key
    NSString *passcodeEncryptionKey = [SFPasscodeManager sharedManager].encryptionKey;
    SFEncryptionKey *encKey = [[SFEncryptionKey alloc] initWithData:[SFKeyStoreManager keyStringToData:passcodeEncryptionKey]
                                               initializationVector:[SFSDKCryptoUtils randomByteDataWithLength:kCCBlockSizeAES128]];
    passcodeKeyStore.keyStoreKey = [[SFKeyStoreKey alloc] initWithKey:encKey];

    // Insert key to passcode key store
    SFEncryptionKey *encryptionKey = [mgr keyWithRandomValue];
    SFKeyStoreKey *keyStoreKey = [[SFKeyStoreKey alloc] initWithKey:encryptionKey];
    NSString *originalKeyLabel = [passcodeKeyStore keyLabelForString:keyLabel];
    XCTAssertEqualObjects(@"keyLabel__Passcode", originalKeyLabel);
    NSMutableDictionary *mutableKeyStoreDict = [NSMutableDictionary dictionaryWithDictionary:passcodeKeyStore.keyStoreDictionary];
    mutableKeyStoreDict[originalKeyLabel] = keyStoreKey;
    passcodeKeyStore.keyStoreDictionary = mutableKeyStoreDict;

    // Make sure it was saved in passcode key store
    [self assertKeyForDictionary:passcodeKeyStore.keyStoreDictionary
                       withLabel:originalKeyLabel
                hasEncryptionKey:encryptionKey];

    // We want to simulate an upgrade
    // We need to put the SFPasscodeManager back into the state it would be in following a restart
    // NB: We don't want the passcode data reset
    [[SFPasscodeManager sharedManager] setEncryptionKey:nil];
    XCTAssertFalse([passcodeKeyStore keyStoreAvailable], @"Passcode key store should not be ready.");

    // Next the user will unlock the app
    // After verification, the following method gets called
    // This should cause the encryption key's observer in SFKeyStoreManager to migrate all passcode keys
    [[SFPasscodeManager sharedManager] setEncryptionKeyForPasscode:passcode];

    // Make sure we can now retrieve the key through the SFKeyStoreManager
    SFEncryptionKey *retrievedKey = [mgr retrieveKeyWithLabel:keyLabel autoCreate:NO];
    XCTAssertEqualObjects(retrievedKey.keyAsString, encryptionKey.keyAsString, @"Encryption keys do not match");

    // Ensure the key is now in generated dictionary with an updated label
    NSString *newKeyLabel = [mgr.generatedKeyStore keyLabelForString:keyLabel];
    XCTAssertEqualObjects(@"keyLabel__Generated", newKeyLabel);
    [self assertKeyForDictionary:mgr.generatedKeyStore.keyStoreDictionary
                       withLabel:newKeyLabel
                hasEncryptionKey:encryptionKey];

    // Make sure the passcode key store is empty
    XCTAssertEqual(0, [passcodeKeyStore.keyStoreDictionary count], @"Passcode dictionary should be empty");
    
    // Cleanup
    [mgr removeKeyWithLabel:keyLabel];
}

#pragma mark - Private methods
- (void)keyStoreThreadSafeHelper
{
    static NSUInteger keyId = 1;
    
    // generate a new key
    NSString *keyName = [NSString stringWithFormat:@"%@%ld", @"threadSafeKeyName", (unsigned long)keyId++];
    SFEncryptionKey *origKey = [mgr keyWithRandomValue];
    
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
