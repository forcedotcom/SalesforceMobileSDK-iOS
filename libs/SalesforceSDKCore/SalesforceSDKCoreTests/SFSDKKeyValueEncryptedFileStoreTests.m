//
//  SFSDKKeyValueEncryptedFileStoreTests.m
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 6/23/20.
//  Copyright (c) 2020-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import <XCTest/XCTest.h>
#import <SalesforceSDKCore/SFUserAccount.h>
#import <SalesforceSDKCore/SFOAuthCredentials.h>
#import <SalesforceSDKCore/SFDirectoryManager.h>
#import <SalesforceSDKCore/SalesforceSDKCore-Swift.h>

@interface SFOAuthCredentials ()
@property (nonatomic, readwrite, nullable) NSURL *identityUrl;
@end

@interface SFSDKKeyValueEncryptedFileStoreTests : XCTestCase

@property (nonatomic, strong) SFUserAccount *userAccount;

@end

@implementation SFSDKKeyValueEncryptedFileStoreTests

- (void)setUp {
    [super setUp];
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:[NSString stringWithFormat:@"keyvalue-test"] clientId:@"fakeClientIdForTesting" encrypted:YES];
    self.userAccount = [[SFUserAccount alloc] initWithCredentials:credentials];
    self.userAccount.credentials.identityUrl = [NSURL URLWithString:@"https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0IAC"];
}

- (void)tearDown {
    NSError *error;
    if ([NSFileManager.defaultManager fileExistsAtPath:[self globalPath]]) {
        [NSFileManager.defaultManager removeItemAtPath:[self globalPath] error:&error];
        XCTAssertNil(error, @"Error removing item at path '%@': %@", [self globalPath], error);
    }
    if ([NSFileManager.defaultManager fileExistsAtPath:[self userPath:self.userAccount]]) {
        [NSFileManager.defaultManager removeItemAtPath:[self userPath:self.userAccount] error:&error];
        XCTAssertNil(error, @"Error removing item at path '%@': %@", [self userPath:self.userAccount], error);
    }
    self.userAccount = nil;
    [super tearDown];
}

#pragma mark - Store management

- (void)testGlobalStoreUsesSameStore {
    NSString *storeName = @"test_global_uses_same_store";

    SFSDKKeyValueEncryptedFileStore *store = [SFSDKKeyValueEncryptedFileStore sharedGlobalStoreWithName:storeName];
    store[@"key1"] = @"value1";
    store[@"key2"] = @"value2";
    XCTAssertEqual(store.count, 2);

    SFSDKKeyValueEncryptedFileStore *storeAgain = [SFSDKKeyValueEncryptedFileStore sharedGlobalStoreWithName:storeName];
    XCTAssertEqual(storeAgain.count, 2);
    XCTAssert([storeAgain[@"key1"] isEqualToString:@"value1"]);
    XCTAssert([storeAgain[@"key2"] isEqualToString:@"value2"]);
}

- (void)testUserStoreUsesSameStore {
    NSString *storeName = @"test_user_uses_same_store";
    SFSDKKeyValueEncryptedFileStore *store = [SFSDKKeyValueEncryptedFileStore sharedStoreWithName:storeName user:self.userAccount];
    store[@"user_key1"] = @"user_value1";
    store[@"user_key2"] = @"user_value2";
    XCTAssertEqual(store.count, 2);

    SFSDKKeyValueEncryptedFileStore *storeAgain = [SFSDKKeyValueEncryptedFileStore sharedStoreWithName:storeName user:self.userAccount];
    XCTAssertEqual(storeAgain.count, 2);
    XCTAssert([storeAgain[@"user_key1"] isEqualToString:@"user_value1"]);
    XCTAssert([storeAgain[@"user_key2"] isEqualToString:@"user_value2"]);
}

- (void)testUserStores {
    NSString *storeName1 = @"user_store_1";
    NSString *storeName2 = @"user_store_2";
    NSString *storeName3 = @"user_store_3";

    SFSDKKeyValueEncryptedFileStore *store1 = [SFSDKKeyValueEncryptedFileStore sharedStoreWithName:storeName1 user:self.userAccount];
    SFSDKKeyValueEncryptedFileStore *store2 = [SFSDKKeyValueEncryptedFileStore sharedStoreWithName:storeName2 user:self.userAccount];
    SFSDKKeyValueEncryptedFileStore *store3 = [SFSDKKeyValueEncryptedFileStore sharedStoreWithName:storeName3 user:self.userAccount];

    XCTAssertNotNil(store1);
    XCTAssertNotNil(store2);
    XCTAssertNotNil(store3);

    // Verify stores exist on disk
    NSError *error;
    NSArray *storeDirectories = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self userPath:self.userAccount] error:&error];
    XCTAssertEqual(storeDirectories.count, 3, @"Number of directories don't match number of stores created");

    // Verify names
    NSArray *storeNames = [SFSDKKeyValueEncryptedFileStore allStoreNamesForUser:self.userAccount];
    XCTAssertEqual(storeNames.count, 3);
    [storeNames containsObject:storeName1];
    [storeNames containsObject:storeName2];
    [storeNames containsObject:storeName3];

    [SFSDKKeyValueEncryptedFileStore removeSharedStoreWithName:storeName2 forUser:self.userAccount];
    XCTAssertEqual([SFSDKKeyValueEncryptedFileStore allStoreNamesForUser:self.userAccount].count, 2);

    [SFSDKKeyValueEncryptedFileStore removeAllStoresForUser:self.userAccount];
    XCTAssertEqual([SFSDKKeyValueEncryptedFileStore allStoreNamesForUser:self.userAccount].count, 0);
}

- (void)testGlobalStores {
    NSString *storeName1 = @"global_store_1";
    NSString *storeName2 = @"global_store_2";
    NSString *storeName3 = @"global_store_3";

    SFSDKKeyValueEncryptedFileStore *store1 = [SFSDKKeyValueEncryptedFileStore sharedGlobalStoreWithName:storeName1];
    SFSDKKeyValueEncryptedFileStore *store2 = [SFSDKKeyValueEncryptedFileStore sharedGlobalStoreWithName:storeName2];
    SFSDKKeyValueEncryptedFileStore *store3 = [SFSDKKeyValueEncryptedFileStore sharedGlobalStoreWithName:storeName3];

    XCTAssertNotNil(store1);
    XCTAssertNotNil(store2);
    XCTAssertNotNil(store3);

    // Verify stores exist on disk
    NSError *error;
    NSArray *storeDirectories = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self globalPath] error:&error];
    XCTAssertEqual(storeDirectories.count, 3, @"Number of directories don't match number of stores created");

    // Verify names
    NSArray *storeNames = SFSDKKeyValueEncryptedFileStore.allGlobalStoreNames;
    XCTAssertEqual(storeNames.count, 3);
    [storeNames containsObject:storeName1];
    [storeNames containsObject:storeName2];
    [storeNames containsObject:storeName3];

    [SFSDKKeyValueEncryptedFileStore removeSharedGlobalStoreWithName:storeName2];
    XCTAssertEqual(SFSDKKeyValueEncryptedFileStore.allGlobalStoreNames.count, 2);

    [SFSDKKeyValueEncryptedFileStore removeAllGlobalStores];
    XCTAssertEqual(SFSDKKeyValueEncryptedFileStore.allGlobalStoreNames.count, 0);
}

#pragma mark - Store operations

- (void)testStoreVersion {
    SFSDKKeyValueEncryptedFileStore *store = [self createStoreWithName:@"new_store"];
    XCTAssertEqual([store storeVersion], 2);
}

- (void)testV1StoreVersion {
    SFSDKKeyValueEncryptedFileStore *store = [self createV1StoreWithName:@"legacy_store"];
    XCTAssertEqual([store storeVersion], 1);
}

- (void)testStoreWithUnreadableVersion {
    SFSDKKeyValueEncryptedFileStore *store = [self createStoreWithName:@"new_store"];
    XCTAssertNotNil(store);
    NSURL *versionFileURL = [store.storeDirectory URLByAppendingPathComponent:@"version"];
    NSData *badVersionData = [@"bad_version_data" dataUsingEncoding:NSUTF8StringEncoding];
    [badVersionData writeToFile:versionFileURL.path atomically:YES];
    store = [self createStoreWithName:@"new_store"];
    XCTAssertNil(store);
}

- (void)testIsValidName {
    XCTAssertTrue([SFSDKKeyValueEncryptedFileStore isValidStoreName:@"123456789"]);
    XCTAssertTrue([SFSDKKeyValueEncryptedFileStore isValidStoreName:@"test_store"]);

    NSString *longName = @"this_is_a_string_for_a_test_store_name_that_is_going_to_be_too_long_and_should_not_be_considered_valid";
    XCTAssertFalse([SFSDKKeyValueEncryptedFileStore isValidStoreName:longName]);
    XCTAssertFalse([SFSDKKeyValueEncryptedFileStore isValidStoreName:(NSString * _Nonnull)nil]);
    XCTAssertFalse([SFSDKKeyValueEncryptedFileStore isValidStoreName:@""]);
    XCTAssertFalse([SFSDKKeyValueEncryptedFileStore isValidStoreName:@"test store"]);
    XCTAssertFalse([SFSDKKeyValueEncryptedFileStore isValidStoreName:@"test.store"]);
    XCTAssertFalse([SFSDKKeyValueEncryptedFileStore isValidStoreName:@"test/store"]);
}

- (void)testStoreName {
    NSString *storeName = @"test_store_name";
    SFSDKKeyValueEncryptedFileStore *store = [self createStoreWithName:storeName];
    XCTAssert([store.storeName isEqualToString:storeName], @"Store names don't match");
}

- (void)testBadStoreName {
    SFSDKKeyValueEncryptedFileStore *store = [self createStoreWithName:@""];
    XCTAssertNil(store);
}

- (void)testBadDirectory {
    SFSDKKeyValueEncryptedFileStore *store = [[SFSDKKeyValueEncryptedFileStore alloc] initWithParentDirectory:@"" name:@"test_bad_directory"];
    XCTAssertNil(store);
}

- (void)testSaveReadRemoveEntries {
    int entryCount = 20;
    SFSDKKeyValueEncryptedFileStore *store = [self createStoreWithName:@"test_entries"];
    for (int i = 0; i < entryCount; i++) {
        NSString *key = [NSString stringWithFormat:@"key%i", i];
        NSString *value =  [NSString stringWithFormat:@"value%i", i];
        BOOL saveSuccess = [store saveValue:value forKey:key];
        XCTAssertTrue(saveSuccess);
    }

    for (int i = 0; i < entryCount; i++) {
        XCTAssertEqual(store.count, entryCount - i);
        NSString *key = [NSString stringWithFormat:@"key%i", i];
        NSString *expectedValue = [NSString stringWithFormat:@"value%i", i];
        NSString *value = store[key];
        XCTAssert([expectedValue isEqualToString:value]);
        BOOL deleteSuccess = [store removeValueForKey:key];
        XCTAssertTrue(deleteSuccess);
        XCTAssertEqual(store.count, entryCount - i - 1);
    }
}

- (void)testSubscriptSaveRemove {
    SFSDKKeyValueEncryptedFileStore *store = [self createStoreWithName:@"test_subscript_save_remove"];
    NSString *key = @"key";
    NSString *value = @"value";
    store[key] = value;
    XCTAssert([value isEqualToString:store[key]]);
    store[key] = nil;
    XCTAssertNil(store[key]);
}

- (void)testRemoveAll {
    int entryCount = 20;
    SFSDKKeyValueEncryptedFileStore *store = [self createStoreWithName:@"test_remove_all"];
    for (int i = 0; i < entryCount; i++) {
        NSString *key = [NSString stringWithFormat:@"key%i", i];
        NSString *value =  [NSString stringWithFormat:@"value%i", i];
        BOOL saveSuccess = [store saveValue:value forKey:key];
        XCTAssertTrue(saveSuccess);
    }
    XCTAssertEqual(store.count, entryCount);
    [store removeAll];
    XCTAssertEqual(store.count, 0);
}

- (void)testAllKeys {
    SFSDKKeyValueEncryptedFileStore *store = [self createStoreWithName:@"test_all_keys"];
    int entryCount = 12;
    NSMutableArray<NSString *> *expectedKeys = [[NSMutableArray alloc] initWithCapacity:entryCount];
    for (int i = 0; i < entryCount; i++) {
        NSString *key = [NSString stringWithFormat:@"key%i", i];
        NSString *value =  [NSString stringWithFormat:@"value%i", i];
        BOOL saveSuccess = [store saveValue:value forKey:key];
        XCTAssertTrue(saveSuccess);
        [expectedKeys addObject:key];
    }
    NSArray<NSString *> *keys = [store allKeys];
    NSArray<NSString *> *sortedKeys = [keys sortedArrayUsingComparator:^NSComparisonResult(NSString *key1, NSString *key2) {
        return [key1 compare:key2];
    }];
    NSArray<NSString *> *sortedExpectedKeys = [expectedKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *key1, NSString *key2) {
        return [key1 compare:key2];
    }];
    XCTAssertTrue([sortedKeys isEqualToArray:sortedExpectedKeys]);
}

- (void)testV1StoreAllKeys {
    SFSDKKeyValueEncryptedFileStore *store = [self createV1StoreWithName:@"test_all_keys_v1"];
    int entryCount = 12;
    for (int i = 0; i < entryCount; i++) {
        NSString *key = [NSString stringWithFormat:@"key%i", i];
        NSString *value =  [NSString stringWithFormat:@"value%i", i];
        BOOL saveSuccess = [store saveValue:value forKey:key];
        XCTAssertTrue(saveSuccess);
    }
    XCTAssertNil([store allKeys]);
}

- (void)testOverwriteValue {
    SFSDKKeyValueEncryptedFileStore *store = [self createStoreWithName:@"test_overwrite_value"];
    NSString *key = @"overwrite_key";
    NSString *value = @"value";
    NSString *newValue = @"new_value";

    [store saveValue:value forKey:key];
    NSString *storeValue = store[key];
    XCTAssert([storeValue isEqualToString:value]);
    [store saveValue:newValue forKey:key];
    storeValue = store[key];
    XCTAssert([storeValue isEqualToString:newValue]);
}

- (void)testIsEmpty {
    SFSDKKeyValueEncryptedFileStore *store = [self createStoreWithName:@"test_is_empty"];
    XCTAssertTrue([store isEmpty]);
    [store saveValue:@"value" forKey:@"key"];
    XCTAssertFalse([store isEmpty]);
}

- (void)testStoreEncryption {
    SFSDKKeyValueEncryptedFileStore *store = [self createStoreWithName:@"test_store_encryption"];
    NSString *value = @"value";
    [store saveValue:value forKey:@"key"];

    // Read value directly from file, shouldn't be the same as the unencrypted value
    NSError *error;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:store.storeDirectory.path error:&error];
    XCTAssertNil(error, @"Error getting contents of path '%@': %@", store.storeDirectory.path, error);
    XCTAssertEqual(files.count, 4, @"Unexpected number of files in store");
    NSString *valuePath = [store.storeDirectory.path stringByAppendingPathComponent:files[0]];
    NSData *fileData = [NSData dataWithContentsOfFile:valuePath];
    NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertFalse([fileData isEqualToData:valueData]);
}

- (void)testInvalidKey {
    SFSDKKeyValueEncryptedFileStore *store = [self createStoreWithName:@"test_invalid_key"];
    XCTAssertFalse([store saveValue:@"value" forKey:(NSString * _Nonnull)nil]);
    XCTAssertFalse([store saveValue:@"value" forKey:@""]);
}

- (void)testExistingFile {
    NSString *fileName = @"existing_file";
    [SFDirectoryManager ensureDirectoryExists:[self globalPath] error:nil];
    NSString *filePath = [[self globalPath] stringByAppendingPathComponent:fileName];

    // Create file
    NSString *fileContents = @"existing_file_contents";
    [fileContents writeToFile:filePath atomically:NO encoding:NSUTF8StringEncoding error:nil];

    // Shouldn't be able to create store at the same location as the existing file
    SFSDKKeyValueEncryptedFileStore *store = [self createStoreWithName:fileName];
    XCTAssertNil(store);
}

- (void) testBinaryStorage {
    SFSDKKeyValueEncryptedFileStore *store = [self createStoreWithName:@"test_binary_storage"];

    // Saving binary data to key value store
    NSData* sampleData = [self randomData];
    [store saveData:sampleData forKey:@"key"];

    // Retrieving binary back from key value store
    NSData* savedData = [store readDataWithKey:@"key"];

    // Comparing bytes
    XCTAssertTrue([savedData isEqualToData:sampleData], @"Retrieved data different from original data");
}

# pragma mark - Helpers
- (NSData*) randomData {
    int size           = 2048;
    NSMutableData* data = [NSMutableData dataWithCapacity:size];
    for( unsigned int i = 0 ; i < size/4 ; ++i )
    {
        u_int32_t randomBits = arc4random();
        [data appendBytes:(void*)&randomBits length:4];
    }
    return data;
}

- (NSString *)globalPath {
    return [[SFDirectoryManager sharedManager] globalDirectoryOfType:NSDocumentDirectory components:@[@"key_value_stores"]];
}

- (NSString *)userPath:(SFUserAccount *)user {
    return [[SFDirectoryManager sharedManager] directoryForUser:user type:NSDocumentDirectory components:@[@"key_value_stores"]];
}

- (SFSDKKeyValueEncryptedFileStore *)createStoreWithName:(NSString *)name {
    NSString *parentDirectory = [self globalPath];
    return [[SFSDKKeyValueEncryptedFileStore alloc] initWithParentDirectory:parentDirectory name:name];
}

- (SFSDKKeyValueEncryptedFileStore *)createV1StoreWithName:(NSString *)name {
    SFSDKKeyValueEncryptedFileStore *store = [self createStoreWithName:name];
    NSURL *versionFileURL = [store.storeDirectory URLByAppendingPathComponent:@"version"];
    NSError *error;
    [NSFileManager.defaultManager removeItemAtURL:versionFileURL error:&error];
    XCTAssertNil(error, @"Error deleting '%@': %@", store.storeDirectory.path, error);
    return [self createStoreWithName:name];
}

@end
