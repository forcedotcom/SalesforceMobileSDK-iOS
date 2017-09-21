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
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFKeyStoreManager+Internal.h"

static NSUInteger const kNumThreadsInSafetyTest = 100;

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

- (void)testUpgradeTo60
{
    SFPasscodeKeyStore * passcodeKeyStore = [[SFPasscodeKeyStore alloc] init];
    XCTAssertFalse([passcodeKeyStore keyStoreAvailable], @"Passcode key store should not be ready.");

    // set up the passcode key  store
    NSString *passcode = @"passcode";
    [[SFPasscodeManager sharedManager] changePasscode:passcode];
    XCTAssertTrue([passcodeKeyStore keyStoreAvailable], @"Passcode key store is not ready.");

    SFEncryptionKey *encryptionKey = [mgr keyWithRandomValue];
    SFKeyStoreKey *keyStoreKey = [[SFKeyStoreKey alloc] initWithKey:encryptionKey];
    NSString *typedKeyLabel = [passcodeKeyStore keyLabelForString:@"keyLabel"];
    NSMutableDictionary *mutableKeyStoreDict = [NSMutableDictionary dictionaryWithDictionary:passcodeKeyStore.keyStoreDictionary];
    mutableKeyStoreDict[typedKeyLabel] = keyStoreKey;
    passcodeKeyStore.keyStoreDictionary = mutableKeyStoreDict;

    // make sure it was saved in passcode keystore
    [self assertKeyForDictionary:passcodeKeyStore.keyStoreDictionary
                       withLabel:typedKeyLabel
                hasEncryptionKey:encryptionKey];

    // Migration code is triggered during a verification only (which is a nil->val passcode change)
    // Going to nil should not affect passcode keystore (like it did before)
    // In SDK 6.0, in an app, by the time we change passcode to nil, the passcode keystore should already have been migrated
    [[SFPasscodeManager sharedManager] changePasscode:nil];
    [self assertKeyForDictionary:passcodeKeyStore.keyStoreDictionary
                       withLabel:typedKeyLabel
                hasEncryptionKey:encryptionKey];

    // simulate a verification
    [[SFPasscodeManager sharedManager] changePasscode:passcode];

    // ensure the key is now in generated dictionary
    [self assertKeyForDictionary:mgr.generatedKeyStore.keyStoreDictionary
                       withLabel:typedKeyLabel
                hasEncryptionKey:encryptionKey];

    // make sure passcode keystore is empty
    XCTAssertEqual(0, [passcodeKeyStore.keyStoreDictionary count], @"Passcode dictionary should be empty");
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
