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
#import "SFSoupQuerySpec.h"
#import "SFSoupCursor.h"
#import "SFSmartStoreDatabaseManager.h"
#import "SFSmartStore.h"
#import "SFSmartStore+Internal.h"
#import "SFPasscodeManager.h"
#import "SFSecurityLockout.h"
#import "SFSecurityLockout+Internal.h"
#import "NSString+SFAdditions.h"
#import "NSData+SFAdditions.h"

NSString * const kTestSmartStoreName   = @"testSmartStore";
NSString * const kTestSoupName   = @"testSoup";

@interface SFSmartStoreTests ()
- (void) assertSameJSONWithExpected:(id)expected actual:(id)actual message:(NSString*)message;
- (void) assertSameJSONArrayWithExpected:(NSArray*)expected actual:(NSArray*)actual message:(NSString*)message;
- (void) assertSameJSONMapWithExpected:(NSDictionary*)expected actual:(NSDictionary*)actual message:(NSString*)message;
- (BOOL) hasTable:(NSString*)tableName;
- (void)createDbDir:(NSString *)dbName;
- (FMDatabase *)openDatabase:(NSString *)dbName key:(NSString *)key openShouldFail:(BOOL)openShouldFail;
- (void)createTestTable:(NSString *)tableName db:(FMDatabase *)db;
- (int)rowCountForTable:(NSString *)tableName db:(FMDatabase *)db;
- (BOOL)tableNameInMaster:(NSString *)tableName db:(FMDatabase *)db;
- (BOOL)canReadDatabase:(FMDatabase *)db;
- (NSArray *)variedStores:(NSString *)passcode;
- (void)clearAllStores;
- (NSString *)hashedKey:(NSString *)key;
@end

@implementation SFSmartStoreTests


#pragma mark - setup and teardown


- (void) setUp
{
    [super setUp];
    _store = [[SFSmartStore sharedStoreWithName:kTestSmartStoreName] retain];
}

- (void) tearDown
{
    [_store release]; // close underlying db
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
    [self assertSameJSONWithExpected:[NSNumber numberWithInt:2]  actual:[SFJsonUtils projectIntoJson:json path:@"b"] message:@"Wrong value for key b"];
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
    [self assertSameJSONWithExpected:[NSNumber numberWithInt:5] actual:[SFJsonUtils projectIntoJson:json path:@"d.d4.e"] message:@"Wrong value for key d.d4.e"];    
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
    NSDictionary* soupIndex = [NSDictionary dictionaryWithObjectsAndKeys:@"name",@"path",@"string",@"type",nil];
    [_store registerSoup:kTestSoupName withIndexSpecs:[NSArray arrayWithObjects:soupIndex, nil]];
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
    NSDictionary* soupIndex = [NSDictionary dictionaryWithObjectsAndKeys:@"name",@"path",@"string",@"type",nil];
    [_store registerSoup:kTestSoupName withIndexSpecs:[NSArray arrayWithObjects:soupIndex, nil]];
    testSoupExists = [_store soupExists:kTestSoupName];
    STAssertTrue(testSoupExists, @"Soup %@ should exist", kTestSoupName);
    
    // Register second time.  Should only create one soup per unique soup name.
    [_store registerSoup:kTestSoupName withIndexSpecs:[NSArray arrayWithObjects:soupIndex, nil]];
    int rowCount = [_store.storeDb intForQuery:@"SELECT COUNT(*) FROM soup_names WHERE soupName = ?", kTestSoupName];
    STAssertEquals(rowCount, 1, @"Soup names should be unique within a store.");
    
    // Remove
    [_store removeSoup:kTestSoupName];
    testSoupExists = [_store soupExists:kTestSoupName];
    STAssertFalse(testSoupExists, @"Soup %@ should no longer exist", kTestSoupName);
    
}

- (void)testQuerySpecPageSize
{
    NSDictionary *allQueryNoPageSize = [NSDictionary dictionaryWithObjectsAndKeys:kQuerySpecTypeRange, kQuerySpecParamQueryType,
                              @"a/path", kQuerySpecParamIndexPath,
                              nil];
    
    SFSoupQuerySpec *querySpec = [[SFSoupQuerySpec alloc] initWithDictionary:allQueryNoPageSize];
    NSUInteger querySpecPageSize = querySpec.pageSize;
    STAssertEquals(querySpecPageSize, kQuerySpecDefaultPageSize, @"Page size value should be default, if not specified.");
    [querySpec release];
    
    uint expectedPageSize = 42;
    NSDictionary *allQueryWithPageSize = [NSDictionary dictionaryWithObjectsAndKeys:kQuerySpecTypeRange, kQuerySpecParamQueryType,
                                        @"a/path", kQuerySpecParamIndexPath,
                                          [NSNumber numberWithInt:expectedPageSize], kQuerySpecParamPageSize,
                                        nil];
    querySpec = [[SFSoupQuerySpec alloc] initWithDictionary:allQueryWithPageSize];
    querySpecPageSize = querySpec.pageSize;
    STAssertEquals(querySpecPageSize, expectedPageSize, @"Page size value should reflect input value.");
    [querySpec release];
}

- (void)testCursorTotalPages
{
    uint totalEntries = 50;
    
    // Entries divided evenly by the page size.
    uint evenDividePageSize = 25;
    int expectedPageSize = totalEntries / evenDividePageSize;
    NSDictionary *allQuery = [NSDictionary dictionaryWithObjectsAndKeys:kQuerySpecTypeRange, kQuerySpecParamQueryType,
                                          @"a/path", kQuerySpecParamIndexPath,
                                          [NSNumber numberWithInt:evenDividePageSize], kQuerySpecParamPageSize,
                                          nil];
    SFSoupQuerySpec *querySpec = [[SFSoupQuerySpec alloc] initWithDictionary:allQuery];
    SFSoupCursor *cursor = [[SFSoupCursor alloc] initWithSoupName:@"test" store:nil querySpec:querySpec totalEntries:totalEntries];
    int cursorTotalPages = [cursor.totalPages intValue];
    STAssertEquals(cursorTotalPages, expectedPageSize, @"%d entries across a page size of %d should make %d total pages.", totalEntries, evenDividePageSize, expectedPageSize);
    [querySpec release];
    [cursor release];
    
    // Entries not evenly divided across the page size.
    uint unevenDividePageSize = 24;
    expectedPageSize = totalEntries / unevenDividePageSize + 1;
    allQuery = [NSDictionary dictionaryWithObjectsAndKeys:kQuerySpecTypeRange, kQuerySpecParamQueryType,
                              @"a/path", kQuerySpecParamIndexPath,
                              [NSNumber numberWithInt:unevenDividePageSize], kQuerySpecParamPageSize,
                              nil];
    querySpec = [[SFSoupQuerySpec alloc] initWithDictionary:allQuery];
    cursor = [[SFSoupCursor alloc] initWithSoupName:@"test" store:nil querySpec:querySpec totalEntries:totalEntries];
    cursorTotalPages = [cursor.totalPages intValue];
    STAssertEquals(cursorTotalPages, expectedPageSize, @"%d entries across a page size of %d should make %d total pages.", totalEntries, unevenDividePageSize, expectedPageSize);
    [querySpec release];
    [cursor release];
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
    [_store release]; // close underlying db
    _store = nil;
    [SFSmartStore removeSharedStoreWithName:kTestSmartStoreName];
    NSArray *noStoresArray = [[SFSmartStoreDatabaseManager sharedManager] allStoreNames];
    if (noStoresArray != nil) {
        int expectedCount = [noStoresArray count];
        STAssertEquals(expectedCount, 0, @"There should not be any stores defined.  Count = %d", expectedCount);
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
    // Make sure SFSmartStore does default key encryption, if no passcode.
    [[SFPasscodeManager sharedManager] resetPasscode];
    NSString *newNoPasscodeStoreName = @"new_no_passcode_store";
    SFSmartStore *newNoPasscodeStore = [SFSmartStore sharedStoreWithName:newNoPasscodeStoreName];
    BOOL canReadSmartStoreDb = [self canReadDatabase:newNoPasscodeStore.storeDb];
    STAssertTrue(canReadSmartStoreDb, @"Can't read DB created by SFSmartStore.");
    [newNoPasscodeStore.storeDb close];
    FMDatabase *rawDb = [self openDatabase:newNoPasscodeStoreName key:@"" openShouldFail:NO];
    canReadSmartStoreDb = [self canReadDatabase:rawDb];
    STAssertFalse(canReadSmartStoreDb, @"Shouldn't be able to read store with no key.");
    [rawDb close];
    rawDb = [self openDatabase:newNoPasscodeStoreName key:[SFSmartStore defaultKey] openShouldFail:NO];
    canReadSmartStoreDb = [self canReadDatabase:rawDb];
    STAssertTrue(canReadSmartStoreDb, @"Should be able to read DB with default key.");
    [rawDb close];
    
    // Make sure SFSmartStore encrypts a new store with a passcode, if a passcode exists.
    NSString *newPasscodeStoreName = @"new_passcode_store";
    NSString *passcode = @"blah";
    [[SFPasscodeManager sharedManager] setPasscode:passcode];
    SFSmartStore *newPasscodeStore = [SFSmartStore sharedStoreWithName:newPasscodeStoreName];
    canReadSmartStoreDb = [self canReadDatabase:newPasscodeStore.storeDb];
    STAssertTrue(canReadSmartStoreDb, @"Can't read DB created by SFSmartStore.");
    [newPasscodeStore.storeDb close];
    rawDb = [self openDatabase:newPasscodeStoreName key:@"" openShouldFail:NO];
    canReadSmartStoreDb = [self canReadDatabase:rawDb];
    STAssertFalse(canReadSmartStoreDb, @"Shouldn't be able to read store with no key.");
    [rawDb close];
    rawDb = [self openDatabase:newPasscodeStoreName key:[SFSmartStore encKey] openShouldFail:NO];
    canReadSmartStoreDb = [self canReadDatabase:rawDb];
    STAssertTrue(canReadSmartStoreDb, @"Should be able to read DB with passcode key.");
    [rawDb close];
    
    // Make sure existing stores have the expected keys associated with them, between launches.
    [SFSmartStore clearSharedStoreMemoryState];
    [[SFPasscodeManager sharedManager] resetPasscode];
    SFSmartStore *existingDefaultKeyStore = [SFSmartStore sharedStoreWithName:newNoPasscodeStoreName];
    canReadSmartStoreDb = [self canReadDatabase:existingDefaultKeyStore.storeDb];
    STAssertTrue(canReadSmartStoreDb, @"Should be able to read existing store with default key.");
    [[SFPasscodeManager sharedManager] setPasscode:passcode];
    SFSmartStore *existingPasscodeStore = [SFSmartStore sharedStoreWithName:newPasscodeStoreName];
    canReadSmartStoreDb = [self canReadDatabase:existingPasscodeStore.storeDb];
    STAssertTrue(canReadSmartStoreDb, @"Should be able to read existing store with passcode key.");
    
    // Cleanup.
    [[SFPasscodeManager sharedManager] resetPasscode];
    [SFSmartStore removeSharedStoreWithName:newNoPasscodeStoreName];
    [SFSmartStore removeSharedStoreWithName:newPasscodeStoreName];
}

- (void)testPasscodeChange
{
    // Clear the store state.
    [self clearAllStores];
    
    // First, no passcode -> passcode.
    [SFSecurityLockout setLockoutTimeInternal:600];
    NSString *newPasscode = @"blah";
    NSArray *storeNames = [self variedStores:@""];
    [SFSecurityLockout setPasscode:newPasscode];
    NSString *hashedPasscode = [self hashedKey:newPasscode];
    for (NSString *storeName in storeNames) {
        FMDatabase *db = [self openDatabase:storeName key:hashedPasscode openShouldFail:NO];
        BOOL canReadDb = [self canReadDatabase:db];
        STAssertTrue(canReadDb, @"Cannot read DB of store with store name '%@'", storeName);
        [db close];
        SFSmartStore *store = [SFSmartStore sharedStoreWithName:storeName];
        canReadDb = [self canReadDatabase:store.storeDb];
        STAssertTrue(canReadDb, @"Cannot read DB of store with store name '%@'", storeName);
        BOOL usesDefault = [SFSmartStore usesDefaultKey:storeName];
        STAssertFalse(usesDefault, @"None of the smart store instances should be configured with the default passcode.");
    }
    
    // Passcode to no passcode.
    newPasscode = [SFSmartStore defaultKey];
    [SFSecurityLockout setPasscode:@""];
    for (NSString *storeName in storeNames) {
        FMDatabase *db = [self openDatabase:storeName key:newPasscode openShouldFail:NO];
        BOOL canReadDb = [self canReadDatabase:db];
        STAssertTrue(canReadDb, @"Cannot read DB of store with store name '%@'", storeName);
        [db close];
        SFSmartStore *store = [SFSmartStore sharedStoreWithName:storeName];
        canReadDb = [self canReadDatabase:store.storeDb];
        STAssertTrue(canReadDb, @"Cannot read DB of store with store name '%@'", storeName);
        BOOL usesDefault = [SFSmartStore usesDefaultKey:storeName];
        STAssertTrue(usesDefault, @"All of the smart store instances should be configured with the default passcode.");
    }
    
    [self clearAllStores];
    [SFSecurityLockout setLockoutTimeInternal:0];
    [[SFPasscodeManager sharedManager] resetPasscode];
}

#pragma mark - helper methods

- (void) assertSameJSONWithExpected:(id)expected actual:(id) actual message:(NSString*) message
{
    // At least one nil
    if (expected == nil || actual == nil) {
        // Both nil
        if (expected == nil && actual == nil) {
            return;
        }
        else {
           STFail(message);
        }
    }
    // Both arrays
    else if ([expected isKindOfClass:[NSArray class]] && [actual isKindOfClass:[NSArray class]]) {
        [self  assertSameJSONArrayWithExpected:(NSArray*) expected actual:(NSArray*) actual message:message];
    }
    // Both maps
    else if ([expected isKindOfClass:[NSDictionary class]] && [actual isKindOfClass:[NSDictionary class]]) {
        [self  assertSameJSONMapWithExpected:(NSDictionary*) expected actual:(NSDictionary*) actual message:message];        
    }
    // Strings/numbers/booleans
    else {
        STAssertEqualObjects(expected, actual, message);
    }
    
}

- (void) assertSameJSONArrayWithExpected:(NSArray*)expected actual:(NSArray*) actual message:(NSString*) message 
{
    // First compare length
    NSUInteger expectedCount = [expected count];
    NSUInteger actualCount = [actual count];
    STAssertEquals(expectedCount, actualCount, message);
 
    // Compare values in array
    for (int i=0; i<expectedCount; i++) {
        [self assertSameJSONWithExpected:[expected objectAtIndex:i] actual:[actual objectAtIndex:i] message:message];
    }
}

- (void) assertSameJSONMapWithExpected:(NSDictionary*)expected actual:(NSDictionary*) actual message:(NSString*) message
{
    // First compare length
    NSUInteger expectedCount = [expected count];
    NSUInteger actualCount = [actual count];
    STAssertEquals(expectedCount, actualCount, message);
    
    // Compare values in array
    NSEnumerator* enumator = [expected keyEnumerator];
    id key;
    while (key = [enumator nextObject]) {
        [self assertSameJSONWithExpected:[expected objectForKey:key] actual:[actual objectForKey:key] message:message];
    }
}

- (BOOL) hasTable:(NSString*)tableName
{
    FMResultSet *frs = [_store.storeDb executeQuery:@"select count(1) from sqlite_master where type = ? and name = ?" withArgumentsInArray:[NSArray arrayWithObjects:@"table", tableName, nil]];

    int result = NSNotFound;
    if ([frs next]) {        
        result = [frs intForColumnIndex:0];
    }
    [frs close];
    
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
        STAssertNotNil(db, @"Opening database should have returned a non-nil DB object.  Error: %@", [openDbError localizedDescription]);
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
    NSLog(@"rowCountQuery: %@", rowCountQuery);
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

- (BOOL)tableNameInMaster:(NSString *)tableName db:(FMDatabase *)db
{
    // Turn off hard errors from FMDB first.
    BOOL origCrashOnErrors = [db crashOnErrors];
    [db setCrashOnErrors:NO];
    
    BOOL result = YES;
    NSString *querySql = @"SELECT * FROM sqlite_master WHERE name = ?";
    FMResultSet *rs = [db executeQuery:querySql withArgumentsInArray:[NSArray arrayWithObject:tableName]];
    if (rs == nil || ![rs next]) {
        result = NO;
    }
    
    [rs close];
    [db setCrashOnErrors:origCrashOnErrors];
    return result;
}

- (NSArray *)variedStores:(NSString *)passcode
{
    NSMutableArray *storeNames = [NSMutableArray array];
    NSString *storeName;
    NSString *tableName = @"My_Table";
    
    // Default smartstore.
    storeName = @"store1";
    SFSmartStore *ss = [SFSmartStore sharedStoreWithName:storeName];
    STAssertNotNil(ss, @"Creating new SmartStore instance failed.");
    [storeNames addObject:storeName];
    
    // Non-memory store with passcode (or no) as key.
    storeName = @"store2";
    [self createDbDir:storeName];
    FMDatabase *db = [self openDatabase:storeName key:passcode openShouldFail:NO];
    [self createTestTable:tableName db:db];
    [db close];
    [storeNames addObject:storeName];
    
    // If there's no passcode, non-memory store with default key.
    if (passcode == nil || [passcode length] == 0) {
        storeName = @"store3";
        NSString *defKey = [SFSmartStore defaultKey];
        [self createDbDir:storeName];
        db = [self openDatabase:storeName key:defKey openShouldFail:NO];
        [self createTestTable:tableName db:db];
        [SFSmartStore setUsesDefaultKey:YES forStore:storeName];
        [db close];
        [storeNames addObject:storeName];
    }
    
    return storeNames;
}

- (void)clearAllStores
{
    [_store release]; _store = nil;
    [SFSmartStore removeAllStores];
    NSArray *allStoreNames = [[SFSmartStoreDatabaseManager sharedManager] allStoreNames];
    int allStoreCount = [allStoreNames count];
    STAssertEquals(allStoreCount, 0, @"Should not be any stores after removing them all.");
}

- (NSString *)hashedKey:(NSString *)key
{
    return [[key sha256] base64Encode];
}

@end
