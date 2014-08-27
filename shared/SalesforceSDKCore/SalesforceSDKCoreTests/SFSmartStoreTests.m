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

#import "SFSmartStoreTests.h"
#import "SFJsonUtils.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueue.h"
#import "SFQuerySpec.h"
#import "SFStoreCursor.h"
#import "SFSmartStoreDatabaseManager.h"
#import "SFSmartStore.h"
#import "SFSmartStore+Internal.h"
#import "SFAlterSoupLongOperation.h"
#import "SFSoupIndex.h"
#import "SFSmartStoreUpgrade.h"
#import "SFSmartStoreUpgrade+Internal.h"
#import <SalesforceSecurity/SFPasscodeManager.h>
#import <SalesforceSecurity/SFPasscodeManager+Internal.h>
#import <SalesforceSecurity/SFPasscodeProviderManager.h>
#import "SFSecurityLockout+Internal.h"
#import "SFUserAccountManager.h"
#import <SalesforceSecurity/SFKeyStoreManager.h>
#import <SalesforceSecurity/SFEncryptionKey.h>
#import <SalesforceCommonUtils/NSString+SFAdditions.h>
#import <SalesforceCommonUtils/NSData+SFAdditions.h>

NSString * const kTestSmartStoreName   = @"testSmartStore";
NSString * const kTestSoupName   = @"testSoup";

@interface SFSmartStoreTests ()
- (BOOL) hasTable:(NSString*)tableName;
- (void)createDbDir:(NSString *)dbName;
- (FMDatabase *)openDatabase:(NSString *)dbName key:(NSString *)key openShouldFail:(BOOL)openShouldFail;
- (void)createTestTable:(NSString *)tableName db:(FMDatabase *)db;
- (int)rowCountForTable:(NSString *)tableName db:(FMDatabase *)db;
- (BOOL)tableNameInMaster:(NSString *)tableName db:(FMDatabase *)db;
- (BOOL)canReadDatabase:(FMDatabase *)db;
- (void)clearAllStores;
@end

@implementation SFSmartStoreTests


#pragma mark - setup and teardown


- (void) setUp
{
    [super setUp];
    [SFLogger setLogLevel:SFLogLevelDebug];
    _store = [SFSmartStore sharedStoreWithName:kTestSmartStoreName];
}

- (void) tearDown
{
    _store = nil;
    [SFSmartStore removeSharedStoreWithName:kTestSmartStoreName];
    [super tearDown];
}


#pragma mark - tests
// All code under test must be linked into the Unit Test bundle

/**
 * Testing method with paths to top level string/integer/array/map as well as edge cases (nil object/nil or empty path)
 */
- (void) testProjectTopLevel
{
    NSString* rawJson = @"{\"a\":\"va\", \"b\":2, \"c\":[0,1,2], \"d\": {\"d1\":\"vd1\", \"d2\":\"vd2\", \"d3\":[1,2], \"d4\":{\"e\":5}}}";
    NSDictionary* json = [SFJsonUtils objectFromJSONString:rawJson];
    
    // Null object
    STAssertNil([SFJsonUtils projectIntoJson:nil path:@"path"], @"Should have been null");
    
    // Root object
    [self assertSameJSONWithExpected:json actual:[SFJsonUtils projectIntoJson:json path:nil] message:@"Should have returned whole object"];
    [self assertSameJSONWithExpected:json actual:[SFJsonUtils projectIntoJson:json path:@""] message:@"Should have returned whole object"];
    
    // Top-level elements
    [self assertSameJSONWithExpected:@"va" actual:[SFJsonUtils projectIntoJson:json path:@"a"] message:@"Wrong value for key a"];
    [self assertSameJSONWithExpected:@2 actual:[SFJsonUtils projectIntoJson:json path:@"b"] message:@"Wrong value for key b"];
    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"[0,1,2]"] actual:[SFJsonUtils projectIntoJson:json path:@"c"] message:@"Wrong value for key c"];
    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"{\"d1\":\"vd1\", \"d2\":\"vd2\", \"d3\":[1,2], \"d4\":{\"e\":5}}"] actual:[SFJsonUtils projectIntoJson:json path:@"d"] message:@"Wrong value for key d"];
}

/**
  * Testing method with paths to non-top level string/integer/array/map
  */
- (void) testProjectNested
{
    NSString* rawJson = @"{\"a\":\"va\", \"b\":2, \"c\":[0,1,2], \"d\": {\"d1\":\"vd1\", \"d2\":\"vd2\", \"d3\":[1,2], \"d4\":{\"e\":5}}}";    
    NSDictionary* json = [SFJsonUtils objectFromJSONString:rawJson];

    // Nested elements
    [self assertSameJSONWithExpected:@"vd1" actual:[SFJsonUtils projectIntoJson:json path:@"d.d1"] message:@"Wrong value for key d.d1"];
    [self assertSameJSONWithExpected:@"vd2" actual:[SFJsonUtils projectIntoJson:json path:@"d.d2"] message:@"Wrong value for key d.d2"];    
    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"[1,2]"] actual:[SFJsonUtils projectIntoJson:json path:@"d.d3"] message:@"Wrong value for key d.d3"];    
    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"{\"e\":5}"] actual:[SFJsonUtils projectIntoJson:json path:@"d.d4"] message:@"Wrong value for key d.d4"];        
    [self assertSameJSONWithExpected:@5 actual:[SFJsonUtils projectIntoJson:json path:@"d.d4.e"] message:@"Wrong value for key d.d4.e"];    
}

/**
 * Check that the meta data tables (soup index map and soup names) have been created
 */
- (void) testMetaDataTablesCreated
{
    BOOL hasSoupIndexMapTable = [self hasTable:@"soup_index_map"];
    STAssertTrue(hasSoupIndexMapTable, @"Soup index map table not found");
    BOOL hasTableSoupNames = [self hasTable:@"soup_names"];
    STAssertTrue(hasTableSoupNames, @"Soup names table not found");
}

/**
 * Test register/remove soup
 */
- (void) testRegisterRemoveSoup
{
    // Before
    STAssertFalse([_store soupExists:kTestSoupName], @"Soup %@ should not exist", kTestSoupName);
    
    // Register
    NSDictionary* soupIndex = @{@"path": @"name",@"type": @"string"};
    [_store registerSoup:kTestSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]]];
    BOOL testSoupExists = [_store soupExists:kTestSoupName];
    STAssertTrue(testSoupExists, @"Soup %@ should exist", kTestSoupName);
    
    // Remove
    [_store removeSoup:kTestSoupName];
    testSoupExists = [_store soupExists:kTestSoupName];
    STAssertFalse(testSoupExists, @"Soup %@ should no longer exist", kTestSoupName);
    
}

/**
 * Test registering same soup name multiple times.
 */
- (void) testMultipleRegisterSameSoup
{
    // Before
    BOOL testSoupExists = [_store soupExists:kTestSoupName];
    STAssertFalse(testSoupExists, @"Soup %@ should not exist", kTestSoupName);
    
    // Register first time.
    NSDictionary* soupIndex = @{@"path": @"name",@"type": @"string"};
    [_store registerSoup:kTestSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]]];
    testSoupExists = [_store soupExists:kTestSoupName];
    STAssertTrue(testSoupExists, @"Soup %@ should exist", kTestSoupName);
    
    // Register second time.  Should only create one soup per unique soup name.
    [_store registerSoup:kTestSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]]];
    __block int rowCount;
    [_store.storeQueue inDatabase:^(FMDatabase* db) {
        rowCount = [db intForQuery:@"SELECT COUNT(*) FROM soup_names WHERE soupName = ?", kTestSoupName];
    }];
    STAssertEquals(rowCount, 1, @"Soup names should be unique within a store.");
    
    // Remove
    [_store removeSoup:kTestSoupName];
    testSoupExists = [_store soupExists:kTestSoupName];
    STAssertFalse(testSoupExists, @"Soup %@ should no longer exist", kTestSoupName);
}

- (void)testQuerySpecPageSize
{
    NSDictionary *allQueryNoPageSize = @{kQuerySpecParamQueryType: kQuerySpecTypeRange,
                              kQuerySpecParamIndexPath: @"a"};
    
    SFQuerySpec *querySpec = [[SFQuerySpec alloc] initWithDictionary:allQueryNoPageSize withSoupName:kTestSoupName];
    NSUInteger querySpecPageSize = querySpec.pageSize;
    STAssertEquals(querySpecPageSize, kQuerySpecDefaultPageSize, @"Page size value should be default, if not specified.");
    NSUInteger expectedPageSize = 42;
    NSDictionary *allQueryWithPageSize = @{kQuerySpecParamQueryType: kQuerySpecTypeRange,
                                        kQuerySpecParamIndexPath: @"a",
                                          kQuerySpecParamPageSize: @(expectedPageSize)};
    querySpec = [[SFQuerySpec alloc] initWithDictionary:allQueryWithPageSize withSoupName:kTestSoupName];
    querySpecPageSize = querySpec.pageSize;
    STAssertEquals(querySpecPageSize, expectedPageSize, @"Page size value should reflect input value.");
}

- (void)testCursorTotalPages
{
    uint totalEntries = 50;
    
    // Entries divided evenly by the page size.
    uint evenDividePageSize = 25;
    int expectedPageSize = totalEntries / evenDividePageSize;
    NSDictionary *allQuery = @{kQuerySpecParamQueryType: kQuerySpecTypeRange,
                                          kQuerySpecParamIndexPath: @"a",
                                          kQuerySpecParamPageSize: [NSNumber numberWithInt:evenDividePageSize]};
    SFQuerySpec *querySpec = [[SFQuerySpec alloc] initWithDictionary:allQuery  withSoupName:kTestSoupName];
    SFStoreCursor *cursor = [[SFStoreCursor alloc] initWithStore:nil querySpec:querySpec totalEntries:totalEntries firstPageEntries:nil];
    STAssertEquals([cursor.totalEntries unsignedIntValue], totalEntries, @"Wrong value for totalEntries");
    int cursorTotalPages = [cursor.totalPages intValue];
    STAssertEquals(cursorTotalPages, expectedPageSize, @"%d entries across a page size of %d should make %d total pages.", totalEntries, evenDividePageSize, expectedPageSize);

    // Entries not evenly divided across the page size.
    uint unevenDividePageSize = 24;
    expectedPageSize = totalEntries / unevenDividePageSize + 1;
    allQuery = @{kQuerySpecParamQueryType: kQuerySpecTypeRange,
                              kQuerySpecParamIndexPath: @"a",
                              kQuerySpecParamPageSize: [NSNumber numberWithInt:unevenDividePageSize]};
    querySpec = [[SFQuerySpec alloc] initWithDictionary:allQuery  withSoupName:kTestSoupName];
    cursor = [[SFStoreCursor alloc] initWithStore:nil querySpec:querySpec totalEntries:totalEntries firstPageEntries:nil];
    STAssertEquals([cursor.totalEntries unsignedIntValue], totalEntries, @"Wrong value for totalEntries");
    cursorTotalPages = [cursor.totalPages intValue];
    STAssertEquals(cursorTotalPages, expectedPageSize, @"%d entries across a page size of %d should make %d total pages.", totalEntries, unevenDividePageSize, expectedPageSize);
}

- (void)testPersistentStoreExists
{
    NSString *storeName = @"xyzpdq";
    BOOL persistentStoreExists = [[SFSmartStoreDatabaseManager sharedManager] persistentStoreExists:storeName];
    STAssertFalse(persistentStoreExists, @"Store should not exist at this point.");
    [self createDbDir:storeName];
    FMDatabase *db = [self openDatabase:storeName key:@"" openShouldFail:NO];
    persistentStoreExists = [[SFSmartStoreDatabaseManager sharedManager] persistentStoreExists:storeName];
    STAssertTrue(persistentStoreExists, @"Store should exist after creation.");
    [db close];
    [[SFSmartStoreDatabaseManager sharedManager] removeStoreDir:storeName];
    persistentStoreExists = [[SFSmartStoreDatabaseManager sharedManager] persistentStoreExists:storeName];
    STAssertFalse(persistentStoreExists, @"Store should no longer exist at this point.");
}

- (void)testOpenDatabase
{
    // Create a new DB.  Verify its emptiness.
    NSString *storeName = @"awesometown";
    [self createDbDir:storeName];
    FMDatabase *createDb = [self openDatabase:storeName key:@"" openShouldFail:NO];
    int actualRowCount = [self rowCountForTable:@"sqlite_master" db:createDb];
    STAssertEquals(actualRowCount, 0, @"%@ should be a new database with no schema.", storeName);
    
    // Create a table, verify its addition to the DB.
    NSString *tableName = @"My_Table";
    [self createTestTable:tableName db:createDb];
    actualRowCount = [self rowCountForTable:@"sqlite_master" db:createDb];
    STAssertEquals(actualRowCount, 1, @"%@ should now have one table in the DB schema.", storeName);
    
    // Close the current handle, open the database in another call, verify it has a previously-defined table.
    [createDb close];
    FMDatabase *existingDb = [self openDatabase:storeName key:@"" openShouldFail:NO];
    actualRowCount = [self rowCountForTable:@"sqlite_master" db:existingDb];
    STAssertEquals(actualRowCount, 1, @"Existing database %@ should have one table in the DB schema.", storeName);
    
    [existingDb close];
    [[SFSmartStoreDatabaseManager sharedManager] removeStoreDir:storeName];
}

- (void)testEncryptDatabase
{
    NSString *storeName = @"nunyaBusiness";
    
    // Create the unencrypted database, add a table.
    [self createDbDir:storeName];
    FMDatabase *unencryptedDb = [self openDatabase:storeName key:@"" openShouldFail:NO];
    NSString *tableName = @"My_Table";
    [self createTestTable:tableName db:unencryptedDb];
    BOOL isTableNameInMaster = [self tableNameInMaster:tableName db:unencryptedDb];
    STAssertTrue(isTableNameInMaster, @"Table %@ should have been added to sqlite_master.", tableName);

    // Encrypt the DB, verify access.
    NSString *encKey = @"BigSecret";
    NSError *encryptError = nil;
    FMDatabase *encryptedDb = [[SFSmartStoreDatabaseManager sharedManager] encryptDb:unencryptedDb name:storeName key:encKey error:&encryptError];
    STAssertNotNil(encryptedDb, @"Encrypted DB should be a valid object.");
    STAssertNil(encryptError, @"Error encrypting the DB: %@", [encryptError localizedDescription]);
    isTableNameInMaster = [self tableNameInMaster:tableName db:encryptedDb];
    STAssertTrue(isTableNameInMaster, @"Table %@ should still exist in sqlite_master, for encrypted DB.", tableName);
    [encryptedDb close];

    // Try to open the DB with an empty key, verify no read access.
    FMDatabase *unencryptedDb2 = [self openDatabase:storeName key:@"" openShouldFail:NO];
    BOOL canReadDb = [self canReadDatabase:unencryptedDb2];
    STAssertFalse(canReadDb, @"Shouldn't be able to read encrypted database, opened as unencrypted.");
    [unencryptedDb2 close];

    // Try to read the encrypted database with the wrong key.
    FMDatabase *encryptedDb2 = [self openDatabase:storeName key:@"WrongKey" openShouldFail:NO];
    canReadDb = [self canReadDatabase:encryptedDb2];
    STAssertFalse(canReadDb, @"Shouldn't be able to read encrypted database, opened with the wrong key.");
    [encryptedDb2 close];
    
    // Finally, try to re-open the encrypted database with the right key.  Verify read access.
    FMDatabase *encryptedDb3 = [self openDatabase:storeName key:encKey openShouldFail:NO];
    isTableNameInMaster = [self tableNameInMaster:tableName db:encryptedDb3];
    STAssertTrue(isTableNameInMaster, @"Should find the original table name in sqlite_master, with proper encryption key.");
    [encryptedDb3 close];
    
    [[SFSmartStoreDatabaseManager sharedManager] removeStoreDir:storeName];
}

- (void)testUnencryptDatabase
{
    NSString *storeName = @"lookAtThatData";
    
    // Create the encrypted database, add a table.
    [self createDbDir:storeName];
    NSString *encKey = @"GiantSecret";
    FMDatabase *encryptedDb = [self openDatabase:storeName key:encKey openShouldFail:NO];
    NSString *tableName = @"My_Table";
    [self createTestTable:tableName db:encryptedDb];
    BOOL isTableNameInMaster = [self tableNameInMaster:tableName db:encryptedDb];
    STAssertTrue(isTableNameInMaster, @"Table %@ should have been added to sqlite_master.", tableName);
    [encryptedDb close];
    
    // Verify that we can't read data with a plaintext DB open.
    FMDatabase *unencryptedDb = [self openDatabase:storeName key:@"" openShouldFail:NO];
    BOOL canReadDb = [self canReadDatabase:unencryptedDb];
    STAssertFalse(canReadDb, @"Should not be able to read encrypted database with no key.");
    [unencryptedDb close];
    
    // Unencrypt the database, verify data.
    FMDatabase *encryptedDb2 = [self openDatabase:storeName key:encKey openShouldFail:NO];
    NSError *unencryptError = nil;
    FMDatabase *unencryptedDb2 = [[SFSmartStoreDatabaseManager sharedManager] unencryptDb:encryptedDb2
                                                                                     name:storeName
                                                                                   oldKey:encKey
                                                                                    error:&unencryptError];
    STAssertNil(unencryptError, @"Error unencrypting the database: %@", [unencryptError localizedDescription]);
    isTableNameInMaster = [self tableNameInMaster:tableName db:unencryptedDb2];
    STAssertTrue(isTableNameInMaster, @"Table should be present in unencrypted DB.");
    [unencryptedDb2 close];
    
    // Open the database with no key, out of band.  Verify data.
    FMDatabase *unencryptedDb3 = [self openDatabase:storeName key:@"" openShouldFail:NO];
    isTableNameInMaster = [self tableNameInMaster:tableName db:unencryptedDb3];
    STAssertTrue(isTableNameInMaster, @"Table should be present in unencrypted DB.");
    [unencryptedDb3 close];
    
    [[SFSmartStoreDatabaseManager sharedManager] removeStoreDir:storeName];
}

- (void)testAllStoreNames
{
    // Test with no stores. (Note: Have to get rid of the 'default' store created at setup.)
    _store = nil;
    [SFSmartStore removeSharedStoreWithName:kTestSmartStoreName];
    NSArray *noStoresArray = [[SFSmartStoreDatabaseManager sharedManager] allStoreNames];
    if (noStoresArray != nil) {
        NSUInteger expectedCount = [noStoresArray count];
        STAssertEquals(expectedCount, (NSUInteger)0, @"There should not be any stores defined.  Count = %lu", expectedCount);
    }
    
    // Create some stores.  Verify them.
    int numStores = arc4random() % 20 + 1;
    NSMutableSet *initialStoreList = [NSMutableSet set];
    NSString *tableName = @"My_Table";
    for (int i = 0; i < numStores; i++) {
        NSString *storeName = [NSString stringWithFormat:@"myStore%d", (i + 1)];
        [self createDbDir:storeName];
        FMDatabase *db = [self openDatabase:storeName key:@"" openShouldFail:NO];
        [self createTestTable:tableName db:db];
        [db close];
        [initialStoreList addObject:storeName];
    }
    NSSet *allStoresStoreList = [NSSet setWithArray:[[SFSmartStoreDatabaseManager sharedManager] allStoreNames]];
    BOOL setsAreEqual = [initialStoreList isEqualToSet:allStoresStoreList];
    STAssertTrue(setsAreEqual, @"Store list is not equal!");
    
    // Cleanup.
    for (NSString *storeName in initialStoreList) {
        [[SFSmartStoreDatabaseManager sharedManager] removeStoreDir:storeName];
    }
}

- (void)testEncryptionForSFSmartStore
{
    for (NSString *passcodeProviderName in @[kSFPasscodeProviderSHA256, kSFPasscodeProviderPBKDF2]) {
        [self log:SFLogLevelDebug format:@"---Testing encryption using passcode provider '%@'.---", passcodeProviderName];
        [SFPasscodeProviderManager setCurrentPasscodeProviderByName:passcodeProviderName];
        
        [[SFPasscodeManager sharedManager] changePasscode:nil];
        NSString *noPasscodeKey = [SFSmartStore encKey];
        STAssertTrue([noPasscodeKey length] > 0, @"Even without passcode, SmartStore should have an encryption key.");
        NSString *newNoPasscodeStoreName = @"new_no_passcode_store";
        STAssertFalse([[SFSmartStoreDatabaseManager sharedManager] persistentStoreExists:newNoPasscodeStoreName], @"For provider '%@': Store '%@' should not currently exist.", passcodeProviderName, newNoPasscodeStoreName);
        SFSmartStore *newNoPasscodeStore = [SFSmartStore sharedStoreWithName:newNoPasscodeStoreName];
        BOOL canReadSmartStoreDb = [self canReadDatabaseQueue:newNoPasscodeStore.storeQueue];
        STAssertTrue(canReadSmartStoreDb, @"For provider '%@': Can't read DB created by SFSmartStore.", passcodeProviderName);
        [newNoPasscodeStore.storeQueue close];
        FMDatabase *rawDb = [self openDatabase:newNoPasscodeStoreName key:@"" openShouldFail:NO];
        canReadSmartStoreDb = [self canReadDatabase:rawDb];
        STAssertFalse(canReadSmartStoreDb, @"For provider '%@': Shouldn't be able to read store with no key.", passcodeProviderName);
        [rawDb close];
        rawDb = [self openDatabase:newNoPasscodeStoreName key:noPasscodeKey openShouldFail:NO];
        canReadSmartStoreDb = [self canReadDatabase:rawDb];
        STAssertTrue(canReadSmartStoreDb, @"For provider '%@': Should be able to read DB with SmartStore key.", passcodeProviderName);
        [rawDb close];
        
        // Make sure SFSmartStore encrypts a new store with a passcode, if a passcode exists.
        NSString *newPasscodeStoreName = @"new_passcode_store";
        NSString *passcode = @"blah";
        [[SFPasscodeManager sharedManager] changePasscode:passcode];
        NSString *passcodeKey = [SFSmartStore encKey];
        STAssertTrue([passcodeKey isEqualToString:noPasscodeKey], @"Passcode change shouldn't impact encryption key value.");
        STAssertFalse([[SFSmartStoreDatabaseManager sharedManager] persistentStoreExists:newPasscodeStoreName], @"For provider '%@': Store '%@' should not currently exist.", passcodeProviderName, newPasscodeStoreName);
        SFSmartStore *newPasscodeStore = [SFSmartStore sharedStoreWithName:newPasscodeStoreName];
        canReadSmartStoreDb = [self canReadDatabaseQueue:newPasscodeStore.storeQueue];
        STAssertTrue(canReadSmartStoreDb, @"For provider '%@': Can't read DB created by SFSmartStore.", passcodeProviderName);
        [newPasscodeStore.storeQueue close];
        rawDb = [self openDatabase:newPasscodeStoreName key:@"" openShouldFail:NO];
        canReadSmartStoreDb = [self canReadDatabase:rawDb];
        STAssertFalse(canReadSmartStoreDb, @"For provider '%@': Shouldn't be able to read store with no key.", passcodeProviderName);
        [rawDb close];
        rawDb = [self openDatabase:newPasscodeStoreName key:passcodeKey openShouldFail:NO];
        canReadSmartStoreDb = [self canReadDatabase:rawDb];
        STAssertTrue(canReadSmartStoreDb, @"For provider '%@': Should be able to read DB with passcode key.", passcodeProviderName);
        [rawDb close];
        
        // Make sure existing stores have the expected keys associated with them, between launches.
        [SFSmartStore clearSharedStoreMemoryState];
        [[SFPasscodeManager sharedManager] changePasscode:nil];
        SFSmartStore *existingNoPasscodeStore = [SFSmartStore sharedStoreWithName:newNoPasscodeStoreName];
        canReadSmartStoreDb = [self canReadDatabaseQueue:existingNoPasscodeStore.storeQueue];
        STAssertTrue(canReadSmartStoreDb, @"For provider '%@': Should be able to read existing store with default key.", passcodeProviderName);
        [[SFPasscodeManager sharedManager] changePasscode:passcode];
        SFSmartStore *existingPasscodeStore = [SFSmartStore sharedStoreWithName:newPasscodeStoreName];
        canReadSmartStoreDb = [self canReadDatabaseQueue:existingPasscodeStore.storeQueue];
        STAssertTrue(canReadSmartStoreDb, @"For provider '%@': Should be able to read existing store with passcode key.", passcodeProviderName);
        
        // Cleanup.
        [[SFPasscodeManager sharedManager] changePasscode:nil];
        [SFSmartStore removeSharedStoreWithName:newNoPasscodeStoreName];
        [SFSmartStore removeSharedStoreWithName:newPasscodeStoreName];
        STAssertFalse([[SFSmartStoreDatabaseManager sharedManager] persistentStoreExists:newNoPasscodeStoreName], @"For provider '%@': Store '%@' should no longer exist.", passcodeProviderName, newNoPasscodeStoreName);
        STAssertFalse([[SFSmartStoreDatabaseManager sharedManager] persistentStoreExists:newPasscodeStoreName], @"For provider '%@': Store '%@' should no longer exist.", passcodeProviderName, newPasscodeStoreName);
    }
}

- (void)testPasscodeChange
{
    NSArray *internalPasscodeProviders = @[kSFPasscodeProviderSHA256, kSFPasscodeProviderPBKDF2];
    
    // This loop changes the 'preferred' provider, to create test scenarios for jumping between one passcode provider
    // and another.  See [SFPasscodeManager setPasscode:].
    for (NSString *preferredPasscodeProviderName in internalPasscodeProviders) {
        [SFPasscodeManager sharedManager].preferredPasscodeProvider = preferredPasscodeProviderName;
        
        // This loop will toggle the 'current' passcode provider.
        for (NSString *currentPasscodeProviderName in internalPasscodeProviders) {
            [SFPasscodeProviderManager setCurrentPasscodeProviderByName:currentPasscodeProviderName];
            
            // First, no passcode -> passcode.
            [SFSecurityLockout setLockoutTimeInternal:600];
            NSString *newPasscode = @"blah";
            [[SFPasscodeManager sharedManager] changePasscode:newPasscode];
            NSString *encryptionKey = [SFSmartStore encKey];
            FMDatabase *db = [self openDatabase:kTestSmartStoreName key:encryptionKey openShouldFail:NO];
            BOOL canReadDb = [self canReadDatabase:db];
            STAssertTrue(canReadDb, @"Preferred provider: '%@', Current provider: '%@' -- Cannot read DB of store with store name '%@'", preferredPasscodeProviderName, currentPasscodeProviderName, kTestSmartStoreName);
            [db close];
            SFSmartStore *store = [SFSmartStore sharedStoreWithName:kTestSmartStoreName];
            canReadDb = [self canReadDatabaseQueue:store.storeQueue];
            STAssertTrue(canReadDb, @"Preferred provider: '%@', Current provider: '%@' -- Cannot read DB of store with store name '%@'", preferredPasscodeProviderName, currentPasscodeProviderName, kTestSmartStoreName);
            BOOL usesDefault = [SFSmartStoreUpgrade usesLegacyDefaultKey:kTestSmartStoreName];
            STAssertFalse(usesDefault, @"Preferred provider: '%@', Current provider: '%@' -- The store should not be configured with the default passcode.", preferredPasscodeProviderName, currentPasscodeProviderName);
            
            // Passcode to no passcode.
            [[SFPasscodeManager sharedManager] changePasscode:@""];
            db = [self openDatabase:kTestSmartStoreName key:encryptionKey openShouldFail:NO];
            canReadDb = [self canReadDatabase:db];
            STAssertTrue(canReadDb, @"Preferred provider: '%@', Current provider: '%@' -- Cannot read DB of store with store name '%@'", preferredPasscodeProviderName, currentPasscodeProviderName, kTestSmartStoreName);
            [db close];
            store = [SFSmartStore sharedStoreWithName:kTestSmartStoreName];
            canReadDb = [self canReadDatabaseQueue:store.storeQueue];
            STAssertTrue(canReadDb, @"Preferred provider: '%@', Current provider: '%@' -- Cannot read DB of store with store name '%@'", preferredPasscodeProviderName, currentPasscodeProviderName, kTestSmartStoreName);
            usesDefault = [SFSmartStoreUpgrade usesLegacyDefaultKey:kTestSmartStoreName];
            STAssertFalse(usesDefault, @"Preferred provider: '%@', Current provider: '%@' -- The store should not be configured with the default passcode.", preferredPasscodeProviderName, currentPasscodeProviderName);
            
            [SFSecurityLockout setLockoutTimeInternal:0];
        }
    }
}

- (void)testEncryptionUpdate
{
    NSString *encKey = [SFSmartStore encKey];
    
    // Set up different database encryptions, verify that encryption upgrade updates all of them.  NB: "Default"
    // store already exists.
    NSString *unencryptedStoreName = @"unencryptedStore";
    NSString *macStoreName = @"macStore";
    NSString *vendorIdStoreName = @"vendorIdStore";
    NSString *baseAppIdStoreName = @"baseAppIdStore";
    NSArray *goodKeyStoreNames = @[ kTestSmartStoreName,
                             unencryptedStoreName,
                             macStoreName,
                             vendorIdStoreName,
                             baseAppIdStoreName
                             ];
    NSString *badKeyStoreName = @"badKeyStore";
    NSArray *initialStoreInstances = @[ [SFSmartStore sharedStoreWithName:kTestSmartStoreName],
                                        [SFSmartStore sharedStoreWithName:unencryptedStoreName],
                                        [SFSmartStore sharedStoreWithName:macStoreName],
                                        [SFSmartStore sharedStoreWithName:vendorIdStoreName],
                                        [SFSmartStore sharedStoreWithName:baseAppIdStoreName],
                                        [SFSmartStore sharedStoreWithName:badKeyStoreName]
                                        ];
    
    // Clear all in-memory state and DB handles prior to upgrade.  It's the state SmartStore will be in when the
    // upgrade runs.
    for (SFSmartStore *store in initialStoreInstances) {
        [store.storeQueue close];
    }
    [SFSmartStore clearSharedStoreMemoryState];
    
    // Unencrypted store
    FMDatabase *storeDb = [self openDatabase:unencryptedStoreName key:encKey openShouldFail:NO];
    NSError *unencryptStoreError = nil;
    storeDb = [[SFSmartStoreDatabaseManager sharedManager] unencryptDb:storeDb name:unencryptedStoreName oldKey:encKey error:&unencryptStoreError];
    STAssertNotNil(storeDb, @"Failed to unencrypt '%@': %@", unencryptedStoreName, [unencryptStoreError localizedDescription]);
    [storeDb close];
    [SFSmartStoreUpgrade setUsesKeyStoreEncryption:NO forUser:[SFUserAccountManager sharedInstance].currentUser store:unencryptedStoreName];
    [SFSmartStoreUpgrade setUsesLegacyDefaultKey:NO forStore:unencryptedStoreName];
    
    // MAC store
    storeDb = [self openDatabase:macStoreName key:encKey openShouldFail:NO];
    BOOL rekeyResult = [storeDb rekey:[SFSmartStoreUpgrade legacyDefaultKeyMac]];
    STAssertTrue(rekeyResult, @"Re-encryption to MAC address should have been successful.");
    [storeDb close];
    [SFSmartStoreUpgrade setUsesKeyStoreEncryption:NO forUser:[SFUserAccountManager sharedInstance].currentUser store:macStoreName];
    [SFSmartStoreUpgrade setUsesLegacyDefaultKey:YES forStore:macStoreName];
    [SFSmartStoreUpgrade setLegacyDefaultEncryptionType:SFSmartStoreDefaultEncryptionTypeMac forStore:macStoreName];
    
    // Vendor ID store
    storeDb = [self openDatabase:vendorIdStoreName key:encKey openShouldFail:NO];
    rekeyResult = [storeDb rekey:[SFSmartStoreUpgrade legacyDefaultKeyIdForVendor]];
    STAssertTrue(rekeyResult, @"Re-encryption to Vendor ID should have been successful.");
    [storeDb close];
    [SFSmartStoreUpgrade setUsesKeyStoreEncryption:NO forUser:[SFUserAccountManager sharedInstance].currentUser store:vendorIdStoreName];
    [SFSmartStoreUpgrade setUsesLegacyDefaultKey:YES forStore:vendorIdStoreName];
    [SFSmartStoreUpgrade setLegacyDefaultEncryptionType:SFSmartStoreDefaultEncryptionTypeIdForVendor forStore:vendorIdStoreName];
    
    // Base App ID store
    storeDb = [self openDatabase:baseAppIdStoreName key:encKey openShouldFail:NO];
    rekeyResult = [storeDb rekey:[SFSmartStoreUpgrade legacyDefaultKeyBaseAppId]];
    STAssertTrue(rekeyResult, @"Re-encryption to Base App ID should have been successful.");
    [storeDb close];
    [SFSmartStoreUpgrade setUsesKeyStoreEncryption:NO forUser:[SFUserAccountManager sharedInstance].currentUser store:baseAppIdStoreName];
    [SFSmartStoreUpgrade setUsesLegacyDefaultKey:YES forStore:baseAppIdStoreName];
    [SFSmartStoreUpgrade setLegacyDefaultEncryptionType:SFSmartStoreDefaultEncryptionTypeBaseAppId forStore:baseAppIdStoreName];
    
    // Bad key store
    storeDb = [self openDatabase:badKeyStoreName key:encKey openShouldFail:NO];
    rekeyResult = [storeDb rekey:@"SomeUnrecognizedKey"];
    STAssertTrue(rekeyResult, @"Re-encryption to bad key should have been successful.");
    [storeDb close];
    [SFSmartStoreUpgrade setUsesKeyStoreEncryption:NO forUser:[SFUserAccountManager sharedInstance].currentUser store:badKeyStoreName];
    [SFSmartStoreUpgrade setUsesLegacyDefaultKey:YES forStore:badKeyStoreName]; // Random configuration.
    [SFSmartStoreUpgrade setLegacyDefaultEncryptionType:SFSmartStoreDefaultEncryptionTypeBaseAppId forStore:badKeyStoreName];
    
    // Update encryption
    [SFSmartStoreUpgrade updateEncryption];
    
    // Verify that all good key store DBs are now accessible through the same store encryption.
    for (NSString *storeName in goodKeyStoreNames) {
        storeDb = [self openDatabase:storeName key:encKey openShouldFail:NO];
        BOOL canReadDb = [self canReadDatabase:storeDb];
        STAssertTrue(canReadDb, @"Should be able to read encrypted database on encryption upgrade for store '%@'.", storeName);
    }
    
    // Verify that a bad key store will be removed as part of the upgrade process.
    BOOL storeExists = [[SFSmartStoreDatabaseManager sharedManager] persistentStoreExists:badKeyStoreName];
    STAssertFalse(storeExists, @"Un-decryptable store should have been removed on encryption update.");
    
    [self clearAllStores];
}

- (void) testGetDatabaseSize
{
    // Before
    long initialSize = [_store getDatabaseSize];
    
    // Register
    NSDictionary* soupIndex = @{@"path": @"name",@"type": @"string"};
    [_store registerSoup:kTestSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]]];
    
    // Upserts
    NSMutableArray* entries = [NSMutableArray array];
    for (int i=0; i<100; i++) {
        NSMutableDictionary* soupElt = [NSMutableDictionary dictionary];
        soupElt[@"name"] = [NSString stringWithFormat:@"name_%d", i];
        soupElt[@"value"] = [NSString stringWithFormat:@"value_%d", i];
        [entries addObject:soupElt];
    }
    [_store upsertEntries:entries toSoup:kTestSoupName];
    
    // After
    STAssertTrue([_store getDatabaseSize] > initialSize, @"Database size should be larger");
    
}

-(void) testAlterSoupResumeAfterRenameOldSoupTable
{
    [self tryAlterSoupInterruptResume:SFAlterSoupStepRenameOldSoupTable];
}

-(void) testAlterSoupResumeAfterDropOldIndexes
{
    [self tryAlterSoupInterruptResume:SFAlterSoupStepDropOldIndexes];
}

-(void) testAlterSoupResumeAfterRegisterSoupUsingTableName
{
    [self tryAlterSoupInterruptResume:SFAlterSoupStepRegisterSoupUsingTableName];
}

-(void) testAlterSoupResumeAfterCopyTable
{
    [self tryAlterSoupInterruptResume:SFAlterSoupStepCopyTable];
}

-(void) testAlterSoupResumeAfterReIndexSoup
{
    [self tryAlterSoupInterruptResume:SFAlterSoupStepReIndexSoup];
}

-(void) testAlterSoupResumeAfterDropOldTable
{
    [self tryAlterSoupInterruptResume:SFAlterSoupStepDropOldTable];
}

#pragma mark - helper methods

- (BOOL) hasTable:(NSString*)tableName
{
    __block NSInteger result = NSNotFound;

    [_store.storeQueue inDatabase:^(FMDatabase* db) {
        FMResultSet *frs = [db executeQuery:@"select count(1) from sqlite_master where type = ? and name = ?" withArgumentsInArray:@[@"table", tableName]];
        
        if ([frs next]) {
            result = [frs intForColumnIndex:0];
        }
        [frs close];
    }];
    
    return result == 1;
}

- (void)createDbDir:(NSString *)dbName
{
    NSError *createError = nil;
    [[SFSmartStoreDatabaseManager sharedManager] createStoreDir:dbName error:&createError];
    STAssertNil(createError, @"Error creating store dir: %@", [createError localizedDescription]);
}

- (FMDatabase *)openDatabase:(NSString *)dbName key:(NSString *)key openShouldFail:(BOOL)openShouldFail
{
    NSError *openDbError = nil;
    FMDatabase *db = [[SFSmartStoreDatabaseManager sharedManager] openStoreDatabaseWithName:dbName key:key error:&openDbError];
    if (openShouldFail) {
        STAssertNil(db, @"Opening database should have failed.");
    } else {
        STAssertNotNil(db, @"Opening database with name '%@' should have returned a non-nil DB object.  Error: %@", dbName, [openDbError localizedDescription]);
    }
    
    return db;
}

- (void)createTestTable:(NSString *)tableName db:(FMDatabase *)db
{
    NSString *tableSql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (Col1 TEXT, Col2 TEXT, Col3 TEXT, Col4 TEXT)", tableName];
    BOOL createSucceeded = [db executeUpdate:tableSql];
    STAssertTrue(createSucceeded, @"Could not create table %@: %@", tableName, [db lastErrorMessage]);
}

- (int)rowCountForTable:(NSString *)tableName db:(FMDatabase *)db
{
    NSString *rowCountQuery = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@", tableName];
    [self log:SFLogLevelDebug format:@"rowCountQuery: %@", rowCountQuery];
    int rowCount = [db intForQuery:rowCountQuery];
    return rowCount;
}

- (BOOL)canReadDatabase:(FMDatabase *)db
{
    // Turn off hard errors from FMDB first.
    BOOL origCrashOnErrors = [db crashOnErrors];
    [db setCrashOnErrors:NO];
    
    NSString *querySql = @"SELECT * FROM sqlite_master LIMIT 1";
    FMResultSet *rs = [db executeQuery:querySql];
    [rs close];
    [db setCrashOnErrors:origCrashOnErrors];
    return (rs != nil);
}

- (BOOL)canReadDatabaseQueue:(FMDatabaseQueue *)queue
{
    __block BOOL readable = NO;
    
    [queue inDatabase:^(FMDatabase* db) {
        // Turn off hard errors from FMDB first.
        BOOL origCrashOnErrors = [db crashOnErrors];
        [db setCrashOnErrors:NO];
        
        NSString *querySql = @"SELECT * FROM sqlite_master LIMIT 1";
        FMResultSet *rs = [db executeQuery:querySql];
        [rs close];
        [db setCrashOnErrors:origCrashOnErrors];
        readable = (rs != nil);
    }];
    
    return readable;
}

- (BOOL)tableNameInMaster:(NSString *)tableName db:(FMDatabase *)db
{
    // Turn off hard errors from FMDB first.
    BOOL origCrashOnErrors = [db crashOnErrors];
    [db setCrashOnErrors:NO];
    
    BOOL result = YES;
    NSString *querySql = @"SELECT * FROM sqlite_master WHERE name = ?";
    FMResultSet *rs = [db executeQuery:querySql withArgumentsInArray:@[tableName]];
    if (rs == nil || ![rs next]) {
        result = NO;
    }
    
    [rs close];
    [db setCrashOnErrors:origCrashOnErrors];
    return result;
}

- (void)clearAllStores
{
    _store = nil;
    [SFSmartStore removeAllStores];
    NSArray *allStoreNames = [[SFSmartStoreDatabaseManager sharedManager] allStoreNames];
    NSUInteger allStoreCount = [allStoreNames count];
    STAssertEquals(allStoreCount, (NSUInteger)0, @"Should not be any stores after removing them all.");
}

- (void) tryAlterSoupInterruptResume:(SFAlterSoupStep)toStep
{
    // Before
    STAssertFalse([_store soupExists:kTestSoupName], @"Soup %@ should not exist", kTestSoupName);
    
    // Register
    NSDictionary* lastNameSoupIndex = @{@"path": @"lastName",@"type": @"string"};
    NSArray* indexSpecs = [SFSoupIndex asArraySoupIndexes:@[lastNameSoupIndex]];
    [_store registerSoup:kTestSoupName withIndexSpecs:indexSpecs];
    BOOL testSoupExists = [_store soupExists:kTestSoupName];
    STAssertTrue(testSoupExists, @"Soup %@ should exist", kTestSoupName);
    __block NSString* soupTableName;
    [_store.storeQueue inDatabase:^(FMDatabase *db) {
        soupTableName = [_store tableNameForSoup:kTestSoupName withDb:db];
    }];

    // Populate soup
    NSArray* entries = [SFJsonUtils objectFromJSONString:@"[{\"lastName\":\"Doe\", \"address\":{\"city\":\"San Francisco\",\"street\":\"1 market\"}},"
                                                          "{\"lastName\":\"Jackson\", \"address\":{\"city\":\"Los Angeles\",\"street\":\"100 mission\"}}]"];
    NSArray* insertedEntries  =[_store upsertEntries:entries toSoup:kTestSoupName];

    // Partial alter - up to toStep included
    NSDictionary* citySoupIndex = @{@"path": @"address.city",@"type": @"string"};
    NSDictionary* streetSoupIndex = @{@"path": @"address.street",@"type": @"string"};
    NSArray* indexSpecsNew = [SFSoupIndex asArraySoupIndexes:@[lastNameSoupIndex, citySoupIndex, streetSoupIndex]];
    SFAlterSoupLongOperation* operation = [[SFAlterSoupLongOperation alloc] initWithStore:_store soupName:kTestSoupName newIndexSpecs:indexSpecsNew reIndexData:YES];
    [operation runToStep:toStep];
    
    // Validate long_operations_status table
    NSArray* operations = [_store getLongOperations];
    NSInteger expectedCount = (toStep == kLastStep ? 0 : 1);
    STAssertTrue([operations count] == expectedCount, @"Wrong number of long operations found");
    if ([operations count] > 0) {
        // Check details
        SFAlterSoupLongOperation* actualOperation = (SFAlterSoupLongOperation*)operations[0];
        STAssertEqualObjects(actualOperation.soupName, kTestSoupName, @"Wrong soup name");
        STAssertEqualObjects(actualOperation.soupTableName, soupTableName, @"Wrong soup name");
        STAssertTrue(actualOperation.reIndexData, @"Wrong re-index data");
        
        // Check last step completed
        STAssertEquals(actualOperation.afterStep, toStep, @"Wrong step");
        
        // Simulate restart (clear cache and call resumeLongOperations)
        // TODO clear memory cache
        [_store resumeLongOperations];
        
        // Check that long operations table is now empty
        STAssertTrue([[_store getLongOperations] count] == 0, @"There should be no long operations left");
        
        // Check index specs
        NSArray* actualIndexSpecs = [_store indicesForSoup:kTestSoupName];
        [self checkIndexSpecs:actualIndexSpecs withExpectedIndexSpecs:[SFSoupIndex asArraySoupIndexes:indexSpecsNew] checkColumnName:NO];
     
        // Check data
        [_store.storeQueue inDatabase:^(FMDatabase *db) {
            FMResultSet* frs = [_store queryTable:soupTableName forColumns:nil orderBy:@"id ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
            [self checkRow:frs withExpectedEntry:insertedEntries[0] withSoupIndexes:actualIndexSpecs];
            [self checkRow:frs withExpectedEntry:insertedEntries[1] withSoupIndexes:actualIndexSpecs];
            STAssertFalse([frs next], @"Only two rows should have been returned");
            [frs close];
        }];
    }
}

- (void) checkRow:(FMResultSet*) frs withExpectedEntry:(NSDictionary*)expectedEntry withSoupIndexes:(NSArray*)arraySoupIndexes
{
    STAssertTrue([frs next], @"Expected rows to be returned");
    // Check id
    STAssertEqualObjects(@([frs longForColumn:ID_COL]), expectedEntry[SOUP_ENTRY_ID], @"Wrong id");
    
    /*
     // FIXME value coming back is an int - needs to be investigated and fixed in 2.2
     STAssertEqualObjects([NSNumber numberWithLong:[frs longForColumn:LAST_MODIFIED_COL]], expectedEntry[SOUP_LAST_MODIFIED_DATE], @"Wrong last modified date");
     */
    
    for (SFSoupIndex* soupIndex in arraySoupIndexes)
    {
        NSString* actualValue = [frs stringForColumn:soupIndex.columnName];
        NSString* expectedValue = [SFJsonUtils projectIntoJson:expectedEntry path:soupIndex.path];
        STAssertEqualObjects(actualValue, expectedValue, @"Wrong value in index column for %@", soupIndex.path);
        
    }
    STAssertEqualObjects([frs stringForColumn:SOUP_COL], [SFJsonUtils JSONRepresentation:expectedEntry], @"Wrong value in soup column");
}

- (void) checkIndexSpecs:(NSArray*)actualSoupIndexes withExpectedIndexSpecs:(NSArray*)expectedSoupIndexes checkColumnName:(BOOL)checkColumnName
{
    STAssertTrue([actualSoupIndexes count] == [expectedSoupIndexes count], @"Wrong number of index specs");
    for (int i = 0; i<[expectedSoupIndexes count]; i++) {
        SFSoupIndex* actualSoupIndex = ((SFSoupIndex*)actualSoupIndexes[i]);
        SFSoupIndex* expectedSoupIndex = ((SFSoupIndex*)expectedSoupIndexes[i]);
        STAssertEqualObjects(actualSoupIndex.path, expectedSoupIndex.path, @"Wrong path");
        STAssertEqualObjects(actualSoupIndex.indexType, expectedSoupIndex.indexType, @"Wrong type");
        if (checkColumnName) {
            STAssertEqualObjects(actualSoupIndex.columnName, expectedSoupIndex.columnName, @"Wrong column name");
        }
    }
}

@end
