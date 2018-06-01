/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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

#import "SyncManagerTestCase.h"
#import "SFSyncUpdateCallbackQueue.h"
#import "TestSyncUpTarget.h"
#import "SFMetadataSyncDownTarget.h"
#import "SFLayoutSyncDownTarget.h"
#import <SmartStore/SFQuerySpec.h>
#import <SmartStore/SFSoupIndex.h>
#import <SalesforceSDKCore/SFSDKSoqlBuilder.h>
#import <SalesforceSDKCore/SFSDKSoslBuilder.h>

#define COUNT_TEST_ACCOUNTS 10

/**
 To test multiple round trip during refresh-sync-down, we need access to countIdsPerSoql
 */
@interface SFRefreshSyncDownTarget ()

@property (nonatomic, assign, readwrite) NSUInteger countIdsPerSoql;

@end

/**
 To test getRemoteIds
 */
@interface SFSyncDownTarget ()

- (void) getRemoteIds:(SFSmartSyncSyncManager*)syncManager
             localIds:(NSArray *)localIds
           errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
        completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock;

@end

/**
 Soql sync down target that pauses for a second at the beginning of the fetch
 */
@interface SlowSoqlSyncDownTarget : SFSoqlSyncDownTarget

@end

/**
 To test addFilterForReSync 
 */
@interface SFSoqlSyncDownTarget ()

+ (NSString*) addFilterForReSync:(NSString*)query modDateFieldName:(NSString *)modDateFieldName maxTimeStamp:(long long)maxTimeStamp;

@end

@implementation SlowSoqlSyncDownTarget

+ (SlowSoqlSyncDownTarget*) newSyncTarget:(NSString*)query {
    SlowSoqlSyncDownTarget* syncTarget = [[SlowSoqlSyncDownTarget alloc] init];
    syncTarget.query = query;
    return syncTarget;
}

- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    [NSThread sleepForTimeInterval:1.0];
    [super startFetch:syncManager maxTimeStamp:maxTimeStamp errorBlock:errorBlock completeBlock:completeBlock];
}

@end

@interface SyncManagerTests : SyncManagerTestCase
{
    NSMutableDictionary* idToFields; // id -> {Name: xxx, Description: yyy}
}

@end

@implementation SyncManagerTests

#pragma mark - setUp/tearDown

- (void)tearDown {
    // Deleting test data
    [self deleteTestData];
    [super tearDown];
}

#pragma mark - tests
/**
 * Test query with "From_customer__c" field
 */
- (void)testQueryWithFromFieldtoSOQLTarget
{
    NSString *soqlQueryWithFromField = [[[[SFSDKSoqlBuilder withFields:@"From_customer__c, Id"] from:ACCOUNT_TYPE] limit:10] build];
    SFSoqlSyncDownTarget* target = [SFSoqlSyncDownTarget newSyncTarget:soqlQueryWithFromField];
    [target getRemoteIds:self.syncManager localIds:@[] errorBlock:^(NSError *e) {
        NSLog(@"%@", [e localizedDescription]);
        XCTFail(@"Wrong query was generated.");
    } completeBlock:^(NSArray *records) {}];
}

/**
 * Test adding 'Id' and 'LastModifiedDate' to SOQL query, if they're missing.
 */
- (void)testAddMissingFieldstoSOQLTarget
{
    NSString *soqlQueryWithSpecialFields = [[[[SFSDKSoqlBuilder withFields:@"Id, LastModifiedDate, FirstName, LastName"] from:@"Contact"] limit:10] build];
    NSString *soqlQueryWithoutSpecialFields = [[[[SFSDKSoqlBuilder withFields:@"FirstName, LastName"] from:@"Contact"] limit:10] build];
    SFSoqlSyncDownTarget* target = [SFSoqlSyncDownTarget newSyncTarget:soqlQueryWithoutSpecialFields];
    NSString *targetSoqlQuery = [target query];
    XCTAssertTrue([soqlQueryWithSpecialFields isEqualToString:targetSoqlQuery], @"SOQL query should contain Id and LastModifiedDate fields.");
}

/**
 * Tests if ghost records are cleaned locally for a SOQL target.
 * FIXME crashing
 */
- (void)testCleanResyncGhostsForSOQLTarget
{
    [self createAccountsSoup];

    // Creates 3 accounts on the server.
    NSArray* accountIds = [[self createAccountsOnServer:3] allKeys];

    // Builds SOQL sync down target and performs initial sync.
    NSString* soql = [NSString stringWithFormat:@"SELECT Id, Name FROM Account WHERE Id IN %@", [self buildInClause:accountIds]];
    NSNumber* syncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeLeaveIfChanged target:[SFSoqlSyncDownTarget newSyncTarget:soql] soupName:ACCOUNTS_SOUP totalSize:accountIds.count numberFetches:1]];
    [self checkDbExists:ACCOUNTS_SOUP ids:accountIds idField:@"Id"];

    // Deletes 1 account on the server and verifies the ghost record is cleared from the soup.
    [self deleteAccountsOnServer:@[accountIds[0]]];
    XCTestExpectation* cleanResyncGhosts = [self expectationWithDescription:@"cleanResyncGhosts"];
    [self.syncManager cleanResyncGhosts:syncId completionStatusBlock:^(SFSyncStateStatus syncStatus) {
        if (syncStatus == SFSyncStateStatusFailed || syncStatus == SFSyncStateStatusDone) {
                [cleanResyncGhosts fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self checkDbDeleted:ACCOUNTS_SOUP ids:@[accountIds[0]] idField:@"Id"];

    // Deletes the remaining accounts on the server.
    [self deleteAccountsOnServer:accountIds];
}

/**
 * Tests clean ghosts when soup is populated through more than one sync down
 */
- (void) testCleanResyncGhostsWithMultipleSyncs
{
    [self createAccountsSoup];
        
    // Creates 6 accounts on the server.
    NSArray* accountIds = [[self createAccountsOnServer:6] allKeys];
    NSArray* accountIdsFirstSubset = [accountIds subarrayWithRange:NSMakeRange(0, 3)];  // id0, id1, id2
    NSArray* accountIdsSecondSubset = [accountIds subarrayWithRange:NSMakeRange(2, 4)]; //           id2, id3, id4, id5

    // Runs a first SOQL sync down target (bringing down id0, id1, id2)
    NSNumber* firstSyncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeLeaveIfChanged
                                                                   target:[SFSoqlSyncDownTarget newSyncTarget:[NSString stringWithFormat:@"SELECT Id, Name FROM Account WHERE Id IN %@", [self buildInClause:accountIdsFirstSubset]]]
                                                                 soupName:ACCOUNTS_SOUP
                                                                totalSize:accountIdsFirstSubset.count
                                                            numberFetches:1]];
    [self checkDbExists:ACCOUNTS_SOUP ids:accountIdsFirstSubset idField:@"Id"];
    [self checkDbSyncIdField:accountIdsFirstSubset soupName:ACCOUNTS_SOUP syncId:firstSyncId];

    // Runs a second SOQL sync down target (bringing down id2, id3, id4, id5)
    NSNumber* secondSyncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeLeaveIfChanged
                                                                    target:[SFSoqlSyncDownTarget newSyncTarget:[NSString stringWithFormat:@"SELECT Id, Name FROM Account WHERE Id IN %@", [self buildInClause:accountIdsSecondSubset]]]
                                                                  soupName:ACCOUNTS_SOUP
                                                                 totalSize:accountIdsSecondSubset.count
                                                             numberFetches:1]];
    [self checkDbExists:ACCOUNTS_SOUP ids:accountIdsSecondSubset idField:@"Id"];
    [self checkDbSyncIdField:accountIdsSecondSubset soupName:ACCOUNTS_SOUP syncId:secondSyncId];

    // Deletes id0, id2, id5 on the server
    [self deleteAccountsOnServer:@[accountIds[0], accountIds[2], accountIds[5]]];

    // Cleaning ghosts of first sync (should only remove id0)
    XCTestExpectation* firstCleanExpectation = [self expectationWithDescription:@"firstCleanGhosts"];
    [self.syncManager cleanResyncGhosts:firstSyncId completionStatusBlock:^(SFSyncStateStatus syncStatus) {
        if (syncStatus == SFSyncStateStatusFailed || syncStatus == SFSyncStateStatusDone) {
            [firstCleanExpectation fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self checkDbExists:ACCOUNTS_SOUP ids:@[accountIds[1], accountIds[2], accountIds[3], accountIds[4], accountIds[5]] idField:@"Id"];
    [self checkDbDeleted:ACCOUNTS_SOUP ids:@[accountIds[0]] idField:@"Id"];

    // Cleaning ghosts of second sync (should remove id2 and id5)
    XCTestExpectation* secondCleanExpectation = [self expectationWithDescription:@"secondCleanGhosts"];
    [self.syncManager cleanResyncGhosts:secondSyncId completionStatusBlock:^(SFSyncStateStatus syncStatus) {
        if (syncStatus == SFSyncStateStatusFailed || syncStatus == SFSyncStateStatusDone) {
            [secondCleanExpectation fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self checkDbExists:ACCOUNTS_SOUP ids:@[accountIds[1], accountIds[3], accountIds[4]] idField:@"Id"];
    [self checkDbDeleted:ACCOUNTS_SOUP ids:@[accountIds[0], accountIds[2], accountIds[5]] idField:@"Id"];

    // Deletes the remaining accounts on the server.
    [self deleteAccountsOnServer:@[accountIds[1], accountIds[3], accountIds[4]]];
}

/**
 * Tests if ghost records are cleaned locally for a MRU target.
 */
- (void)testCleanResyncGhostsForMRUTarget
{
    [self createAccountsSoup];

    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForMetadataWithObjectType:ACCOUNT_TYPE];
    NSMutableArray* existingAccounts =[self sendSyncRequest:request][kRecentItems];

    // Creates 3 accounts on the server.
    NSMutableArray* accountIds = [[[self createAccountsOnServer:3] allKeys] mutableCopy];
    for (NSDictionary* account in existingAccounts) {
        [accountIds addObject:account[ID]];
    }

    // Builds MRU sync down target and performs initial sync.
    NSNumber* syncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeLeaveIfChanged target:[SFMruSyncDownTarget newSyncTarget:ACCOUNT_TYPE fieldlist:@[ID, NAME, DESCRIPTION]] soupName:ACCOUNTS_SOUP totalSize:accountIds.count numberFetches:1]];
    [self checkDbExists:ACCOUNTS_SOUP ids:accountIds idField:@"Id"];

    // Deletes 1 account on the server and verifies the ghost record is cleared from the soup.
    [self deleteAccountsOnServer:@[accountIds[0]]];
    XCTestExpectation* cleanResyncGhosts = [self expectationWithDescription:@"cleanResyncGhosts"];
    [self.syncManager cleanResyncGhosts:syncId completionStatusBlock:^(SFSyncStateStatus syncStatus) {
        if (syncStatus == SFSyncStateStatusFailed || syncStatus == SFSyncStateStatusDone) {
            [cleanResyncGhosts fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self checkDbDeleted:ACCOUNTS_SOUP ids:@[accountIds[0]] idField:@"Id"];

    // Deletes the remaining accounts on the server.
    [self deleteAccountsOnServer:accountIds];
}

/**
 * Tests if ghost records are cleaned locally for a SOSL target.
 */
- (void)testCleanResyncGhostsForSOSLTarget
{
    [self createAccountsSoup];

    // Creates 1 account on the server.
    NSDictionary* accountIdToFields = [self createAccountsOnServer:1];
    [NSThread sleepForTimeInterval:1]; //give server a second to settle to reflect in API

    NSArray* accountIds = [accountIdToFields allKeys];
    
    NSMutableArray* accountNames = [NSMutableArray new];
    for (NSDictionary* fields in [accountIdToFields allValues]) {
        [accountNames addObject:fields[NAME]];
    }

    // Builds SOSL sync down target and performs initial sync.
    NSString* searchQuery = [accountNames componentsJoinedByString:@" OR "];
    SFSDKSoslBuilder* soslBuilder = [SFSDKSoslBuilder withSearchTerm:searchQuery];
    SFSDKSoslReturningBuilder* returningBuilder = [SFSDKSoslReturningBuilder withObjectName:ACCOUNT_TYPE];
    [returningBuilder fields:@"Id, Name, Description"];
    NSString* sosl = [[[soslBuilder returning:returningBuilder] searchGroup:@"NAME FIELDS"] build];
    NSNumber* syncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeLeaveIfChanged target:[SFSoslSyncDownTarget newSyncTarget:sosl] soupName:ACCOUNTS_SOUP totalSize:accountIds.count numberFetches:1]];
    [self checkDbExists:ACCOUNTS_SOUP ids:accountIds idField:@"Id"];

    // Deletes 1 account on the server and verifies the ghost record is cleared from the soup.
    [self deleteAccountsOnServer:@[accountIds[0]]];
    [NSThread sleepForTimeInterval:1]; //give server a second to settle to reflect in API
 
    XCTestExpectation* cleanResyncGhosts = [self expectationWithDescription:@"cleanResyncGhosts"];
    [self.syncManager cleanResyncGhosts:syncId completionStatusBlock:^(SFSyncStateStatus syncStatus) {
        if (syncStatus == SFSyncStateStatusFailed || syncStatus == SFSyncStateStatusDone) {
            [cleanResyncGhosts fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self checkDbDeleted:ACCOUNTS_SOUP ids:@[accountIds[0]] idField:@"Id"];

    // Deletes the remaining accounts on the server.
    [self deleteAccountsOnServer:accountIds];
}

/**
 * Test instantiation of sync manager from various sharedInstance methods.
 */
- (void)testSyncManagerSharedInstanceMethods
{
    SFSmartSyncSyncManager *mgr1 = [SFSmartSyncSyncManager sharedInstance:self.currentUser];
    SFSmartStore *store1 = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
    SFSmartSyncSyncManager *mgr2 = [SFSmartSyncSyncManager sharedInstanceForStore:store1];
    SFSmartSyncSyncManager *mgr3 = [SFSmartSyncSyncManager sharedInstanceForUser:self.currentUser storeName:kDefaultSmartStoreName];
    XCTAssertEqual(mgr1, mgr2, @"Sync managers should be the same.");
    XCTAssertEqual(mgr1, mgr3, @"Sync managers should be the same.");
    NSString *storeName2 = @"AnotherStore";
    SFSmartSyncSyncManager *mgr4 = [SFSmartSyncSyncManager sharedInstance:self.currentUser];
    SFSmartStore *store2 = [SFSmartStore sharedStoreWithName:storeName2];
    SFSmartSyncSyncManager *mgr5 = [SFSmartSyncSyncManager sharedInstanceForStore:store2];
    SFSmartSyncSyncManager *mgr6 = [SFSmartSyncSyncManager sharedInstanceForUser:self.currentUser storeName:storeName2];
    XCTAssertEqual(mgr1, mgr4, @"Sync managers should be the same.");
    XCTAssertNotEqual(mgr4, mgr5, @"Sync managers should not be the same.");
    XCTAssertNotEqual(mgr4, mgr6, @"Sync managers should not be the same.");
    XCTAssertEqual(mgr5, mgr6, @"Sync managers should be the same.");
    
    [SFSmartStore removeSharedStoreWithName:storeName2 forUser:self.currentUser];
}

/**
 * Test serialization and deserialization of SFSyncUpTargets to and from NSDictionary objects.
 */
- (void)testSyncUpTargetSerialization {
    
    // Default sync up target should be the base class.
    SFSyncUpTarget *defaulttarget = [[SFSyncUpTarget alloc] init];
    XCTAssertEqual([defaulttarget class], [SFSyncUpTarget class], @"Default class should be SFSyncUpTarget");
    XCTAssertEqual(defaulttarget.targetType, SFSyncUpTargetTypeRestStandard, @"Sync sync up target type is incorrect.");
    
    // Explicit rest sync up target type creates base class.
    NSDictionary *restDict = @{ kSFSyncTargetTypeKey: @"rest" };
    SFSyncUpTarget *resttarget = [SFSyncUpTarget newFromDict:restDict];
    XCTAssertEqual([resttarget class], [SFSyncUpTarget class], @"Rest class should be SFSyncUpTarget");
    XCTAssertEqual(resttarget.targetType, SFSyncUpTargetTypeRestStandard, @"Sync sync up target type is incorrect.");
    
    // Custom sync up target
    TestSyncUpTarget *customTarget = [[TestSyncUpTarget alloc] init];
    NSDictionary *customDict = [customTarget asDict];
    XCTAssertEqualObjects(customDict[kSFSyncTargetiOSImplKey], NSStringFromClass([TestSyncUpTarget class]), @"Custom class is incorrect.");
    SFSyncUpTarget *customTargetFromDict = [SFSyncUpTarget newFromDict:customDict];
    XCTAssertEqual([customTargetFromDict class], [TestSyncUpTarget class], @"Custom class is incorrect.");
}

/**
 Test that sync up uses SFSyncUpTarget by default
 */
- (void)testDefaultSyncUpTarget {
    SFSyncOptions *options = [SFSyncOptions newSyncOptionsForSyncUp:@[NAME, DESCRIPTION] mergeMode:SFSyncStateMergeModeOverwrite];
    SFSyncState *syncUpState = [SFSyncState newSyncUpWithOptions:options soupName:ACCOUNTS_SOUP store:self.store];
    XCTAssertEqual([syncUpState.target class], [SFSyncUpTarget class], @"Default sync up target should be SFSyncUpTarget");
}

/**
 * getSyncStatus should return null for invalid sync id
 */
- (void)testGetSyncStatusForInvalidSyncId
{
    SFSyncState* sync = [self.syncManager getSyncStatus:[NSNumber numberWithInt:-1]];
    XCTAssertTrue(sync == nil, @"Sync status should be nil");
}

/**
 * Sync down the test accounts, check smart store, check status during sync
 */
- (void)testSyncDown
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Check that db was correctly populated
    [self checkDb:idToFields];
}

/**
 * Sync down the test accounts, make some local changes, sync down again with merge mode LEAVE_IF_CHANGED then sync down with merge mode OVERWRITE
 */
-(void) testSyncDownWithoutOverwrite
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Make some local change
    NSDictionary* idToFieldsLocallyUpdated = [self makeSomeLocalChanges];
    
    // sync down again with MergeMode.LEAVE_IF_CHANGED
    [self trySyncDown:SFSyncStateMergeModeLeaveIfChanged];
    
    // Check db
    NSMutableDictionary* idToFieldsExpected = [[NSMutableDictionary alloc] initWithDictionary:idToFields];
    [idToFieldsExpected setDictionary:idToFieldsLocallyUpdated];
    [self checkDb:idToFieldsExpected];
    
    // sync down again with MergeMode.OVERWRITE
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Check db
    [self checkDb:idToFields];
}

/**
 * Test for sync down with metadata target.
 */
- (void)testSyncDownForMetadataTarget {
    NSArray* indexSpecs = @[
                            [[SFSoupIndex alloc] initWithPath:@"Id" indexType:kSoupIndexTypeString columnName:nil]
                            ];
    [self.store registerSoup:ACCOUNTS_SOUP withIndexSpecs:indexSpecs error:nil];
    [self trySyncDown:SFSyncStateMergeModeOverwrite target:[SFMetadataSyncDownTarget newSyncTarget:ACCOUNT_TYPE] soupName:ACCOUNTS_SOUP totalSize:1 numberFetches:1];
    NSString* smartSql = @"SELECT {accounts:_soup} FROM {accounts}";
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:1];
    NSArray *rows = [self.store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
    rows = [self.store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
    XCTAssertEqual(rows.count, 1, @"Number of rows should be 1");
    NSDictionary *metadata = rows[0][0];
    XCTAssertNotNil(metadata, @"Metadata should not be nil");
    NSString *keyPrefix = metadata[@"keyPrefix"];
    NSString *label = metadata[@"label"];
    XCTAssertEqualObjects(keyPrefix, @"001", @"Key prefix should be 001");
    XCTAssertEqualObjects(label, ACCOUNT_TYPE, @"Label should be Account");
}

/**
 * Test for sync down with layout target.
 */
- (void)testSyncDownForLayoutTarget {
    NSArray* indexSpecs = @[
                            [[SFSoupIndex alloc] initWithPath:@"Id" indexType:kSoupIndexTypeString columnName:nil]
                            ];
    [self.store registerSoup:ACCOUNTS_SOUP withIndexSpecs:indexSpecs error:nil];
    [self trySyncDown:SFSyncStateMergeModeOverwrite target:[SFLayoutSyncDownTarget newSyncTarget:ACCOUNT_TYPE layoutType:@"Compact"] soupName:ACCOUNTS_SOUP totalSize:1 numberFetches:1];
    NSString* smartSql = @"SELECT {accounts:_soup} FROM {accounts}";
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:1];
    NSArray *rows = [self.store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
    XCTAssertEqual(rows.count, 1, @"Number of rows should be 1");
    NSDictionary *layout = rows[0][0];
    XCTAssertNotNil(layout, @"Layout should not be nil");
    NSString *layoutType = layout[@"layoutType"];
    XCTAssertEqualObjects(layoutType, @"Compact", @"Layout type should be Compact");
}

/**
 * Sync down the test accounts, modify a few on the server, re-sync, make sure only the updated ones are downloaded
 */
- (void)testReSync
{
    // Create test data
    [self createTestData];
    
    // first sync down
    NSNumber* syncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeOverwrite]];
    
    // Check sync time stamp
    SFSyncState* sync = [self.syncManager getSyncStatus:syncId];
    SFSyncDownTarget* target = (SFSyncDownTarget*) sync.target;
    SFSyncOptions* options = sync.options;
    long long maxTimeStamp = sync.maxTimeStamp;
    XCTAssertTrue(maxTimeStamp > 0);
    
    // Make some remote changes
    NSDictionary* idToFieldsUpdated = [self makeSomeRemoteChanges];
    
    // Call reSync
    SFSyncUpdateCallbackQueue* queue = [[SFSyncUpdateCallbackQueue alloc] init];
    [queue runReSync:syncId syncManager:self.syncManager];
    
    // Check status updates
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:-1]; // we get an update right away before getting records to sync
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:idToFieldsUpdated.count];
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusDone expectedProgress:100 expectedTotalSize:idToFieldsUpdated.count];
    
    // Check db
    [self checkDb:idToFieldsUpdated];
    
    // Check sync time stamp
    XCTAssertTrue([self.syncManager getSyncStatus:syncId].maxTimeStamp > maxTimeStamp);
}

/**
 * Tests refresh-sync-down
 */
-(void) testRefreshSyncDown
{
    // Create test data
    [self createTestData];

    // Adding soup elements with just ids to soup
    for (NSString* accountId in [idToFields allKeys]) {
        [self.store upsertEntries:@[@{ID:accountId}] toSoup:ACCOUNTS_SOUP];
    }

    // Running a refresh-sync-down for soup
    SFRefreshSyncDownTarget* target = [SFRefreshSyncDownTarget newSyncTarget:ACCOUNTS_SOUP objectType:ACCOUNT_TYPE fieldlist:@[ID, NAME, DESCRIPTION]];
    [self trySyncDown:SFSyncStateMergeModeOverwrite target:target soupName:ACCOUNTS_SOUP totalSize:idToFields.count numberFetches:1];
    
    // Check db
    [self checkDb:idToFields];
}

/**
 * Tests refresh-sync-down when they are more records in the table than can be enumerated in one
 * soql call to the server
 */
-(void) testRefreshSyncDownWithMultipleRoundTrips
{
    // Create test data
    [self createTestData];
    
    // Adding soup elements with just ids to soup
    for (NSString* accountId in [idToFields allKeys]) {
        [self.store upsertEntries:@[@{ID:accountId}] toSoup:ACCOUNTS_SOUP];
    }

    // Running a refresh-sync-down for soup with two ids per soql query (to force multiple round trips)
    SFRefreshSyncDownTarget* target = [SFRefreshSyncDownTarget newSyncTarget:ACCOUNTS_SOUP objectType:ACCOUNT_TYPE fieldlist:@[ID, NAME, DESCRIPTION]];
    target.countIdsPerSoql = 2;
    [self trySyncDown:SFSyncStateMergeModeOverwrite target:target soupName:ACCOUNTS_SOUP totalSize:idToFields.count numberFetches:idToFields.count/2];
    
    // Check db
    [self checkDb:idToFields];
}

/**
 * Tests resync for a refresh-sync-down when they are more records in the table than can be enumerated
 * in one soql call to the server
 */
-(void) testRefreshReSyncWithMultipleRoundTrips
{
    // Create test data
    [self createTestData];
    
    // Adding soup elements with just ids to soup
    for (NSString* accountId in [idToFields allKeys]) {
        [self.store upsertEntries:@[@{ID:accountId}] toSoup:ACCOUNTS_SOUP];
    }

    // Running a refresh-sync-down for soup with two ids per soql query (to force multiple round trips)
    SFRefreshSyncDownTarget* target = [SFRefreshSyncDownTarget newSyncTarget:ACCOUNTS_SOUP objectType:ACCOUNT_TYPE fieldlist:@[ID, NAME, DESCRIPTION, LAST_MODIFIED_DATE]];
    target.countIdsPerSoql = 1;
    NSNumber* syncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeOverwrite target:target soupName:ACCOUNTS_SOUP totalSize:idToFields.count numberFetches:idToFields.count]];

    // Check sync time stamp
    SFSyncState* sync = [self.syncManager getSyncStatus:syncId];
    SFSyncOptions* options = sync.options;
    long long maxTimeStamp = sync.maxTimeStamp;
    XCTAssertTrue(maxTimeStamp > 0, @"Wrong time stamp");

    // Make sure the soup has the records with id and names
    [self checkDb:idToFields];

    // Make some remote changes
    NSDictionary* idToFieldsUpdated = [self makeSomeRemoteChanges];
    
    // Call reSync
    SFSyncUpdateCallbackQueue* queue = [[SFSyncUpdateCallbackQueue alloc] init];
    [queue runReSync:syncId syncManager:self.syncManager];
    
    // Check status updates
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:-1]; // we get an update right away before getting records to sync
    for (NSNumber* expectedProgress in @[@0,@10,@10,@20,@20,@20,@20,@20,@20,@20,@20]) {
        SFSyncState* state = [queue getNextSyncUpdate];
        [self checkStatus:state expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:expectedProgress.unsignedIntegerValue expectedTotalSize:idToFields.count]; // totalSize is off for resync of sync-down-target if not all recrods got updated
    }
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusDone expectedProgress:100 expectedTotalSize:idToFields.count];

    // Check db
    [self checkDb:idToFieldsUpdated];
    
    // Check sync time stamp
    XCTAssertTrue([self.syncManager getSyncStatus:syncId].maxTimeStamp > maxTimeStamp);
}

/**
 * Tests if ghost records are cleaned locally for a refresh target.
 */
- (void)testCleanResyncGhostsForRefreshTarget
{
    // Create test data
    [self createTestData];
    
    // Adding soup elements with just ids to soup
    NSArray* accountIds = [idToFields allKeys];
    for (NSString* accountId in [idToFields allKeys]) {
        [self.store upsertEntries:@[@{ID:accountId}] toSoup:ACCOUNTS_SOUP];
    }
    
    // Running a refresh-sync-down for soup
    SFRefreshSyncDownTarget* target = [SFRefreshSyncDownTarget newSyncTarget:ACCOUNTS_SOUP objectType:ACCOUNT_TYPE fieldlist:@[ID, NAME, DESCRIPTION]];
    NSNumber* syncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeOverwrite target:target soupName:ACCOUNTS_SOUP totalSize:idToFields.count numberFetches:1]];
    
    // Deletes 1 account on the server and verifies the ghost record is cleared from the soup.
    NSString* idDeleted = accountIds[0];
    [self deleteAccountsOnServer:@[idDeleted]];
    XCTestExpectation* cleanResyncGhosts = [self expectationWithDescription:@"cleanResyncGhosts"];
    [self.syncManager cleanResyncGhosts:syncId completionStatusBlock:^(SFSyncStateStatus syncStatus) {
        if (syncStatus == SFSyncStateStatusFailed || syncStatus == SFSyncStateStatusDone) {
            [cleanResyncGhosts fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];

    
    // Map of id to names expected to be found in db
    NSMutableDictionary* idToFieldsLeft = [NSMutableDictionary dictionaryWithDictionary:idToFields];
    [idToFieldsLeft removeObjectForKey:idDeleted];

    // Make sure the soup doesn't contain the record deleted on the server anymore
    [self checkDb:idToFieldsLeft];
    [self checkDbDeleted:ACCOUNTS_SOUP ids:@[idDeleted] idField:@"Id"];
}

/**
 Test that errors are captured on record during sync up
 Create a few records - some with bad names (too long or empty)
 Sync up
 Make sure the records with bad names are still marked as locally created and have the last error field populated
 */
-(void) testSyncUpWithErrors
{
    // Setup soup
    [self createAccountsSoup];
    idToFields = [NSMutableDictionary new];

    // Build name too long
    NSMutableString* nameTooLong = [NSMutableString new];
    for (int i = 0; i < 256; i++) [nameTooLong appendString:@"x"];

    // Create a few entries locally
    NSArray* goodNames = @[ [self createAccountName], [self createAccountName], [self createAccountName]];
    NSArray* badNames = @[ nameTooLong, @"" ];

    [self createAccountsLocally:goodNames];
    [self createAccountsLocally:badNames];

    // Sync up
    [self trySyncUp:5 mergeMode:SFSyncStateMergeModeOverwrite];

    // Check db for records with good names
    NSDictionary* idToFieldsGoodNames = [self getIdToFieldsByName:ACCOUNTS_SOUP fieldNames:@[NAME, DESCRIPTION] nameField:NAME names:goodNames];
    [self checkDbStateFlags:[idToFieldsGoodNames allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    // Check db for records with bad names
    NSDictionary* idToFieldsBadNames = [self getIdToFieldsByName:ACCOUNTS_SOUP fieldNames:@[NAME, DESCRIPTION, kSyncTargetLastError] nameField:NAME names:badNames];
    [self checkDbStateFlags:[idToFieldsBadNames allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:YES expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    for (NSDictionary * fields in [idToFieldsBadNames allValues]) {
        NSString* name = fields[NAME];
        NSString* lastError = fields[kSyncTargetLastError];
        if ([name isEqualToString:nameTooLong]) {
            XCTAssertTrue([lastError containsString:@"Account Name: data value too large"], @"Name too large error expected");
        }
        else if ([name isEqualToString:@""]) {
            XCTAssertTrue([lastError containsString:@"Required fields are missing: [Name]"], @"Missing name error expected");
        }
        else {
            XCTFail(@"Unexpected record found: %@", name);
        }
    }

    // Check server for records with good names
    [self checkServer:idToFieldsGoodNames];

    // Adding to idToFields so that they get deleted in tearDown
    [idToFields addEntriesFromDictionary:idToFieldsGoodNames];
}

/**
 * Sync down the test accounts, modify none, sync up, check smartstore and server afterwards
 */
-(void)testSyncUpWithNoLocalUpdates
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Sync up
    [self trySyncUp:0 mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Check that db doesn't show entries as locally modified
    [self checkDbStateFlags:[idToFields allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    // Check server
    [self checkServer:idToFields];
}

/**
 * Sync down the test accounts, modify a few, sync up, check smartstore and server afterwards
 */
-(void)testSyncUpWithLocallyUpdatedRecords
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
   
    // Make some local change
    NSDictionary* idToFieldsLocallyUpdated = [self makeSomeLocalChanges];
    
    // Sync up
    [self trySyncUp:idToFieldsLocallyUpdated.count mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Check that db doesn't show entries as locally modified anymore
    [self checkDbStateFlags:[idToFieldsLocallyUpdated allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    // Check server
    [self checkServer:idToFieldsLocallyUpdated];
}

/**
 * Sync down the test accounts, modify a few, sync up specifying update field list, check smartstore and server afterwards
 */
-(void)testSyncUpWithUpdateFieldList
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Make some local change
    NSDictionary* idToFieldsLocallyUpdated = [self makeSomeLocalChanges];
    
    // Sync up with update field list including only name
    SFSyncUpTarget *target = [[SFSyncUpTarget alloc] initWithCreateFieldlist:nil updateFieldlist:@[NAME]];
    [self trySyncUp:idToFieldsLocallyUpdated.count target:target mergeMode:SFSyncStateMergeModeOverwrite];

    // Check that db doesn't show entries as locally modified anymore
    [self checkDbStateFlags:[idToFieldsLocallyUpdated allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    // Check server - make sure only name was updated
    NSMutableDictionary* idToFieldsExpectedOnServer = [NSMutableDictionary new];
    for (NSString* recordId in idToFieldsLocallyUpdated) {
        idToFieldsExpectedOnServer[recordId] = @{NAME: idToFieldsLocallyUpdated[recordId][NAME], DESCRIPTION:idToFields[recordId][DESCRIPTION]}; // should have modified name but original description
    }
    [self checkServer:idToFieldsExpectedOnServer];
}

/**
 * Create accounts locally, sync up specifying create field list, check smartstore and server afterwards
 */
-(void)testSyncUpWithCreateFieldList
{
    // Create test data
    [self createTestData];
    
    // Create a few entries locally
    NSArray* names = @[ [self createAccountName], [self createAccountName], [self createAccountName]];
    [self createAccountsLocally:names];
    
    // Sync up with create field list including only name
    SFSyncUpTarget *target = [[SFSyncUpTarget alloc] initWithCreateFieldlist:@[NAME] updateFieldlist:nil];
    [self trySyncUp:names.count target:target mergeMode:SFSyncStateMergeModeOverwrite];

    // Check that db doesn't show entries as locally created anymore and that they use sfdc id
    NSDictionary* idToFieldsCreated = [self getIdToFieldsByName:ACCOUNTS_SOUP fieldNames:@[NAME, DESCRIPTION] nameField:NAME names:names];
    [self checkDbStateFlags:[idToFieldsCreated allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    // Check server - make sure only name was set
    NSMutableDictionary* idToFieldsExpectedOnServer = [NSMutableDictionary new];
    for (NSString* recordId in idToFieldsCreated) {
        idToFieldsExpectedOnServer[recordId] = @{NAME: idToFieldsCreated[recordId][NAME], DESCRIPTION:[NSNull null]}; // should have name but no description
    }
    [self checkServer:idToFieldsExpectedOnServer byNames:names];
    
    // Adding to idToFields so that they get deleted in tearDown
    [idToFields addEntriesFromDictionary:idToFieldsCreated];
}

/**
 * Sync down the test accounts, modify a few, create accounts locally, sync up specifying different create and update field list,
 * check smartstore and server afterwards
 */
-(void)testSyncUpWithCreateAndUpdateFieldList
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Make some local change
    NSDictionary* idToFieldsLocallyUpdated = [self makeSomeLocalChanges];
    NSMutableArray* namesOfUpdated = [NSMutableArray new];
    for (NSString* recordId in idToFieldsLocallyUpdated) {
        [namesOfUpdated addObject:idToFieldsLocallyUpdated[recordId][NAME]];
    }
    
    // Create a few entries locally
    NSArray* namesOfCreated = @[ [self createAccountName], [self createAccountName], [self createAccountName]];
    [self createAccountsLocally:namesOfCreated];
    
    // Sync up with different create and update field lists
    SFSyncUpTarget *target = [[SFSyncUpTarget alloc] initWithCreateFieldlist:@[NAME] updateFieldlist:@[DESCRIPTION]];
    [self trySyncUp:(namesOfUpdated.count + namesOfCreated.count) target:target mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Check that db doesn't show entries as locally created anymore and that they use sfdc id
    NSDictionary* idToFieldsCreated = [self getIdToFieldsByName:ACCOUNTS_SOUP fieldNames:@[NAME, DESCRIPTION] nameField:NAME names:namesOfCreated];
    [self checkDbStateFlags:[idToFieldsCreated allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    // Make sure all the locally created records have synched up
    XCTAssertEqual(namesOfCreated.count, idToFieldsCreated.count);
    
    // Check server - make sure updated records only have updated description - make sure created records only have name
    NSMutableDictionary* idToFieldsExpectedOnServer = [NSMutableDictionary new];
    for (NSString* recordId in idToFieldsLocallyUpdated) {
        idToFieldsExpectedOnServer[recordId] = @{NAME: idToFields[recordId][NAME], DESCRIPTION:idToFieldsLocallyUpdated[recordId][DESCRIPTION]}; // updated records should have original name and updated description
    }
    for (NSString* recordId in idToFieldsCreated) {
        idToFieldsExpectedOnServer[recordId] = @{NAME: idToFieldsCreated[recordId][NAME], DESCRIPTION:[NSNull null]}; // created records should have name but no description
    }

    // Make sure we found all the records on the server
    NSArray* allNames = [namesOfCreated arrayByAddingObjectsFromArray:namesOfUpdated];
    XCTAssertEqual(allNames.count, idToFieldsExpectedOnServer.count);
    [self checkServer:idToFieldsExpectedOnServer];
    
    // Adding to idToFields so that they get deleted in tearDown
    [idToFields addEntriesFromDictionary:idToFieldsCreated];
}

/**
 Test sync up of updated records with custom target
 */
- (void)testCustomSyncUpWithLocallyUpdatedRecords
{
    // Create test data.
    [self createTestData];
    
    // Sync down data to local store.
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Make some local changes.
    NSDictionary* idToFieldsLocallyUpdated = [self makeSomeLocalChanges];
    
    // Sync up with custom sync sync up target.
    SFSyncUpTarget *customTarget = [[TestSyncUpTarget alloc] initWithRemoteModDateCompare:TestSyncUpTargetRemoteModDateSameAsLocal
                                                                                     sendRemoteModError:NO
                                                                                        sendSyncUpError:NO];
    [self trySyncUp:idToFieldsLocallyUpdated.count target:customTarget mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Check that db doesn't show entries as locally modified anymore
    [self checkDbStateFlags:[idToFieldsLocallyUpdated allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];
}

/**
 * Sync down the test accounts, modify a few, sync up with merge mode LEAVE_IF_CHANGED, check smartstore and server afterwards
 */
- (void)testSyncUpWithLocallyUpdatedRecordsWithoutOverwrite
{
    // Create test data
    [self createTestData];
    
    // First sync down
    [self trySyncDown:SFSyncStateMergeModeLeaveIfChanged];
    
    // Make some local change
    NSDictionary* idToFieldsLocallyUpdated = [self makeSomeLocalChanges];
    NSArray* ids = [idToFieldsLocallyUpdated allKeys];

    // Update entries on server
    NSMutableDictionary* idToFieldsRemotelyUpdated = [NSMutableDictionary new];
    for (NSString* accountId in ids) {
        NSString* updatedName =  [NSString stringWithFormat:@"%@_updated_again", idToFields[accountId][NAME]];
        NSString* updatedDescription =  [NSString stringWithFormat:@"%@_updated_again", idToFields[accountId][DESCRIPTION]];
        idToFieldsRemotelyUpdated[accountId] = @{NAME:updatedName, DESCRIPTION:updatedDescription};
    }
    [self updateAccountsOnServer:idToFieldsRemotelyUpdated];
    
    // Sync up
    [self trySyncUp:idToFieldsLocallyUpdated.count mergeMode:SFSyncStateMergeModeLeaveIfChanged];
    
    // Check that db does still shows entries as locally modified
    [self checkDbStateFlags:ids soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:YES expectedLocallyDeleted:NO];

    // Check server
    [self checkServer:idToFieldsRemotelyUpdated];
}

/**
 Test custom sync up with locally updated records with merge mode LEAVE_IF_CHANGED
 */
- (void)testCustomSyncUpWithLocallyUpdatedRecordsWithoutOverwrite
{
    // Create test data
    [self createTestData];
    
    // First sync down
    [self trySyncDown:SFSyncStateMergeModeLeaveIfChanged];
    
    // Make some local change
    NSDictionary* idToFieldsLocallyUpdated = [self makeSomeLocalChanges];
    NSArray* ids = [idToFieldsLocallyUpdated allKeys];
    
    // Sync up
    SFSyncUpTarget *customTarget = [[TestSyncUpTarget alloc] initWithRemoteModDateCompare:TestSyncUpTargetRemoteModDateGreaterThanLocal
                                                                                     sendRemoteModError:NO
                                                                                        sendSyncUpError:NO];
    [self trySyncUp:ids.count target:customTarget mergeMode:SFSyncStateMergeModeLeaveIfChanged];
    
    // Check that db still shows entries as locally modified
    [self checkDbStateFlags:ids soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:YES expectedLocallyDeleted:NO];
}

/**
 * Create accounts locally, sync up with merge mode SFSyncStateMergeModeOverwrite, check smartstore and server afterwards
 */
- (void)testSyncUpWithLocallyCreatedRecords
{
    [self trySyncUpWithLocallyCreatedRecords:SFSyncStateMergeModeOverwrite];
}

/**
 * Create accounts locally, sync up with merge mode SFSyncStateMergeModeLeaveIfChanged, check smartstore and server afterwards
 */
- (void)testSyncUpWithLocallyCreatedRecordsWithoutOverwrite
{
    [self trySyncUpWithLocallyCreatedRecords:SFSyncStateMergeModeLeaveIfChanged];
    
}

-(void) trySyncUpWithLocallyCreatedRecords:(SFSyncStateMergeMode)syncUpMergeMode
{
    // Create test data
    [self createTestData];
    
    // Create a few entries locally
    NSArray* names = @[ [self createAccountName], [self createAccountName], [self createAccountName]];
    [self createAccountsLocally:names];
   
    // Sync up
    [self trySyncUp:3 mergeMode:syncUpMergeMode];
    
    // Check that db doesn't show entries as locally created anymore and that they use sfdc id
    NSDictionary* idToFieldsCreated = [self getIdToFieldsByName:ACCOUNTS_SOUP fieldNames:@[NAME, DESCRIPTION] nameField:NAME names:names];
    [self checkDbStateFlags:[idToFieldsCreated allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    // Check server
    [self checkServer:idToFieldsCreated byNames:names];
    
    // Adding to idToFields so that they get deleted in tearDown
    [idToFields addEntriesFromDictionary:idToFieldsCreated];
}

/**
 * Create accounts locally, delete them locally, sync up with merge mode SFSyncStateMergeModeLeaveIfChanged, check smartstore
 *
 * Ideally an application that deletes locally created records should simply remove them from the smartstore
 * But if records are kept in the smartstore and are flagged as created and deleted (or just deleted), then
 * sync up should not throw any error and the records should end up being removed from the smartstore
 *
 */
-(void) testSyncUpWithLocallyCreatedAndDeletedRecords
{
    // Create test data
    [self createTestData];
    
    // Create a few entries locally
    NSArray* names = @[ [self createAccountName], [self createAccountName], [self createAccountName]];
    [self createAccountsLocally:names];
    NSDictionary *idToFieldsCreated = [self getIdToFieldsByName:ACCOUNTS_SOUP fieldNames:@[NAME, DESCRIPTION] nameField:NAME names:names];

    // Delete a few entries locally
    NSArray* allIds = [idToFieldsCreated allKeys];
    NSArray* idsLocallyDeleted = @[ allIds[0], allIds[1], allIds[2] ];
    [self deleteAccountsLocally:idsLocallyDeleted];
    
    // Sync up
    [self trySyncUp:3 mergeMode:SFSyncStateMergeModeLeaveIfChanged];
    
    // Check that db doesn't doesn't contain those entries anymore
    NSString* idsClause = [self buildInClause:idsLocallyDeleted];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:idsLocallyDeleted.count];
    NSArray* rows = [self.store queryWithQuerySpec:query pageIndex:0 error:nil];
    XCTAssertEqual(0, rows.count);
}

/**
 Test custom sycn up with locally created records
 */
- (void)testCustomSyncUpWithLocallyCreatedRecords
{
    // Create test data
    [self createTestData];
    
    // Create a few entries locally
    NSArray* names = @[ [self createAccountName], [self createAccountName], [self createAccountName]];
    [self createAccountsLocally:names];
    
    // Sync up
    SFSyncUpTarget *customTarget = [[TestSyncUpTarget alloc] initWithRemoteModDateCompare:TestSyncUpTargetRemoteModDateSameAsLocal sendRemoteModError:NO sendSyncUpError:NO];
    [self trySyncUp:3 target:customTarget mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Check that db doesn't show entries as locally created anymore and that they use returned id
    NSDictionary* idToFieldsCreated = [self getIdToFieldsByName:ACCOUNTS_SOUP fieldNames:@[NAME, DESCRIPTION] nameField:NAME names:names];
    [self checkDbStateFlags:[idToFieldsCreated allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];
}

/**
 * Sync down the test accounts, delete a few, sync up, check smartstore and server afterwards
 */
-(void) testSyncUpWithLocallyDeletedRecords
{
    // Create test data
    [self createTestData];
    
    // First sync down
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Delete a few entries locally
    NSArray* allIds = [idToFields allKeys];
    NSArray* idsLocallyDeleted = @[ allIds[0], allIds[1], allIds[2] ];
    [self deleteAccountsLocally:idsLocallyDeleted];
    
    // Sync up
    [self trySyncUp:3 mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Check that db doesn't have deleted entries
    NSString* idsClause = [self buildInClause:idsLocallyDeleted];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:idsLocallyDeleted.count];
    NSArray* rows = [self.store queryWithQuerySpec:query pageIndex:0 error:nil];
    XCTAssertEqual(0, rows.count);
    
    // Check server
    NSString* soql = [NSString stringWithFormat:@"SELECT Id, Name FROM Account WHERE Id IN %@", idsClause];
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql];
    NSArray* records = [self sendSyncRequest:request][RECORDS];
    XCTAssertEqual(0, records.count);
}

/**
 * Sync down the test accounts, delete account on server, update same account locally, sync up, check smartstore and server afterwards
 */
-(void) testSyncUpWithLocallyUpdatedRemotelyDeletedRecords
{
    // Create test data
    [self createTestData];

    // First sync down
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Make some local change
    NSDictionary* idToFieldsLocallyUpdated = [self makeSomeLocalChanges];
    NSMutableArray* names = [NSMutableArray new];
    for (NSDictionary* fields in [idToFieldsLocallyUpdated allValues]) {
        [names addObject:fields[NAME]];
    }
    
    // Delete record on server
    NSString* remotelyDeletedId = [idToFieldsLocallyUpdated allKeys][0];
    [self deleteAccountsOnServer:@[remotelyDeletedId]];

    // Name of locally updated record that was deleted on server
    NSString* locallyUpdatedRemotelyDeletedName = idToFieldsLocallyUpdated[remotelyDeletedId][NAME];
    
    // Sync up
    [self trySyncUp:names.count mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Check that db doesn't show entries as locally updated anymore
    NSString* namesClause = [self buildInClause:names];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Name} IN %@", namesClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:names.count];
    NSArray* rows = [self.store queryWithQuerySpec:query pageIndex:0 error:nil];
    NSMutableDictionary* idToFieldsUpdated = [NSMutableDictionary new];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        NSString* accountId = account[ID];
        NSString* accountName = account[NAME];
        idToFieldsUpdated[accountId] = @{NAME: accountName, DESCRIPTION: account[DESCRIPTION]};
        XCTAssertEqualObjects(@NO, account[kSyncTargetLocal]);
        XCTAssertEqualObjects(@NO, account[kSyncTargetLocallyCreated]);
        XCTAssertEqualObjects(@NO, account[kSyncTargetLocallyUpdated]);
        XCTAssertEqualObjects(@NO, account[kSyncTargetLocallyDeleted]);

        // Check that locally updated / remotely deleted record has new id (not in idToFields)
        if ([accountName isEqualToString:locallyUpdatedRemotelyDeletedName]) {
            XCTAssertNil(idToFields[accountId]);
        }
        // Otherwise should be a known id (in idToFields)
        else {
            XCTAssertNotNil(idToFields[accountId]);
        }
    }
    
    // Check server
    [self checkServer:idToFieldsUpdated byNames:names];
    
    // Adding to idToFields so that they get deleted in tearDown
    [idToFields addEntriesFromDictionary:idToFieldsUpdated];
}

/**
 * Sync down the test accounts, delete account on server, update same account locally, sync up with merge mode LEAVE_IF_CHANGED, check smartstore and server afterwards
 */
-(void) testSyncUpWithLocallyUpdatedRemotelyDeletedRecordsWithoutOverwrite
{
    // Create test data
    [self createTestData];
    
    // First sync down
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Make some local change
    NSDictionary* idToFieldsLocallyUpdated = [self makeSomeLocalChanges];
    NSArray* ids = [idToFieldsLocallyUpdated allKeys];
    
    // Delete record on server
    NSString* remotelyDeletedId = [idToFieldsLocallyUpdated allKeys][0];
    [self deleteAccountsOnServer:@[remotelyDeletedId]];
    
    // Sync up
    [self trySyncUp:ids.count mergeMode:SFSyncStateMergeModeLeaveIfChanged];
    
    // Check that db only shows remotely deleted record as locally updated
    NSString* idsClause = [self buildInClause:ids];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rows = [self.store queryWithQuerySpec:query pageIndex:0 error:nil];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        if ([account[ID] isEqualToString:remotelyDeletedId]) {
            XCTAssertEqualObjects(@YES, account[kSyncTargetLocal]);
            XCTAssertEqualObjects(@NO, account[kSyncTargetLocallyCreated]);
            XCTAssertEqualObjects(@YES, account[kSyncTargetLocallyUpdated]);
            XCTAssertEqualObjects(@NO, account[kSyncTargetLocallyDeleted]);
        } else {
            XCTAssertEqualObjects(@NO, account[kSyncTargetLocal]);
            XCTAssertEqualObjects(@NO, account[kSyncTargetLocallyCreated]);
            XCTAssertEqualObjects(@NO, account[kSyncTargetLocallyUpdated]);
            XCTAssertEqualObjects(@NO, account[kSyncTargetLocallyDeleted]);
        }
    }
    
    // Check server
    NSString* soql = [NSString stringWithFormat:@"SELECT Id, Name, Description FROM Account WHERE Id IN %@", idsClause];
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql];
    NSArray* records = [self sendSyncRequest:request][RECORDS];
    NSMutableArray* idsOnServer = [NSMutableArray new];
    for (NSDictionary* record in records) {
        [idsOnServer addObject:record[ID]];
        XCTAssertEqualObjects(idToFieldsLocallyUpdated[record[ID]][NAME], record[NAME]);
        XCTAssertEqualObjects(idToFieldsLocallyUpdated[record[ID]][DESCRIPTION], record[DESCRIPTION]);
    }
    // Deleted id should not have been returned
    XCTAssertFalse([idsOnServer containsObject:remotelyDeletedId]);

    // There should be one less record on the server
    XCTAssertEqual(ids.count - 1, idsOnServer.count);
}

/**
 * Sync down the test accounts, delete account on server, delete same account locally, sync up, check smartstore and server afterwards
 */
-(void) testSyncUpWithLocallyDeletedRemotelyDeletedRecords
{
    // Create test data
    [self createTestData];
    
    // First sync down
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Delete record locally
    NSString* locallyAndRemotelyDeletedId = [idToFields allKeys][0];
    [self deleteAccountsLocally:@[locallyAndRemotelyDeletedId]];

    // Delete record on server
    [self deleteAccountsOnServer:@[locallyAndRemotelyDeletedId]];
    
    // Sync up
    [self trySyncUp:1 mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Check that db doesn't have deleted entry
    NSString* idsClause = [self buildInClause:@[locallyAndRemotelyDeletedId]];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:1];
    NSArray* rows = [self.store queryWithQuerySpec:query pageIndex:0 error:nil];
    XCTAssertEqual(0, rows.count);
    
    // Check server
    NSString* soql = [NSString stringWithFormat:@"SELECT Id, Name FROM Account WHERE Id IN %@", idsClause];
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql];
    NSArray* records = [self sendSyncRequest:request][RECORDS];
    XCTAssertEqual(0, records.count);
}

/**
 Test custom sync up with locally deleted records
 */
-(void) testCustomSyncUpWithLocallyDeletedRecords
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Delete a few entries locally
    NSArray* allIds = [idToFields allKeys];
    NSArray* idsLocallyDeleted = @[ allIds[0], allIds[1], allIds[2] ];
    [self deleteAccountsLocally:idsLocallyDeleted];
    
    // Sync up
    SFSyncUpTarget *customTarget = [[TestSyncUpTarget alloc] initWithRemoteModDateCompare:TestSyncUpTargetRemoteModDateSameAsLocal sendRemoteModError:NO sendSyncUpError:NO];
    [self trySyncUp:3 target:customTarget mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Check that db doesn't doesn't contain those entries anymore
    NSString* idsClause = [self buildInClause:idsLocallyDeleted];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:idsLocallyDeleted.count];
    NSArray* rows = [self.store queryWithQuerySpec:query pageIndex:0 error:nil];
    XCTAssertEqual(0, rows.count);
}

/**
 * Sync down the test accounts, delete a few, sync up with merge mode LEAVE_IF_CHANGED, check smartstore and server afterwards
 */
-(void) testSyncUpWithLocallyDeletedRecordsWithoutOverwrite
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeLeaveIfChanged];
    
    // Delete a few entries locally
    NSArray* allIds = [idToFields allKeys];
    NSArray* idsLocallyDeleted = @[ allIds[0], allIds[1], allIds[2] ];
    [self deleteAccountsLocally:idsLocallyDeleted];

    // Update entries on server
    NSMutableDictionary* idToFieldsRemotelyUpdated = [NSMutableDictionary new];
    NSArray* ids = @[ idsLocallyDeleted[0], idsLocallyDeleted[1], idsLocallyDeleted[2] ];
    for (NSString* accountId in ids) {
        NSString* updatedName = [NSString stringWithFormat:@"%@_updated_again", idToFields[accountId][NAME]];
        NSString* updatedDescription = [NSString stringWithFormat:@"%@_updated_again", idToFields[accountId][DESCRIPTION]];
        idToFieldsRemotelyUpdated[accountId] = @{NAME:updatedName, DESCRIPTION:updatedDescription};
    }
    [self updateAccountsOnServer:idToFieldsRemotelyUpdated];

    // Sync up
    [self trySyncUp:3 mergeMode:SFSyncStateMergeModeLeaveIfChanged];
    
    // Check that db still shows entries as locally deleted
    [self checkDbStateFlags:idsLocallyDeleted soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:YES];

    // Check server
    [self checkServer:idToFieldsRemotelyUpdated];
}

/**
 Test custom sync up target with locally updated records with merge mode LEAVE_IF_CHANGED
 */
-(void) testCustomSyncUpWithLocallyDeletedRecordsWithoutOverwrite
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeLeaveIfChanged];
    
    // Delete a few entries locally
    NSArray* allIds = [idToFields allKeys];
    NSArray* idsLocallyDeleted = @[ allIds[0], allIds[1], allIds[2] ];
    [self deleteAccountsLocally:idsLocallyDeleted];
    
    // Sync up
    SFSyncUpTarget *customTarget = [[TestSyncUpTarget alloc] initWithRemoteModDateCompare:TestSyncUpTargetRemoteModDateGreaterThanLocal sendRemoteModError:NO sendSyncUpError:NO];
    [self trySyncUp:3 target:customTarget mergeMode:SFSyncStateMergeModeLeaveIfChanged];
    
    // Check that db still shows entries as locally deleted
    [self checkDbStateFlags:idsLocallyDeleted soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:YES];
}

/**
 * Tests the flow for a failure determining modification date.
 * NB: Failure to determine the modification date should not stop the sync up.
 */
- (void)testCustomSyncUpWithFetchModificationDateFailure
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeLeaveIfChanged];
    
    // Make some local change
    NSDictionary* idsToLocallyUpdated = [self makeSomeLocalChanges];
    
    // Sync up
    SFSyncUpTarget *customTarget = [[TestSyncUpTarget alloc] initWithRemoteModDateCompare:TestSyncUpTargetRemoteModDateGreaterThanLocal sendRemoteModError:YES sendSyncUpError:NO];
    [self trySyncUp:idsToLocallyUpdated.count target:customTarget mergeMode:SFSyncStateMergeModeLeaveIfChanged];
}

/**
 * Tests the flow for a failure syncing up the data.
 */
- (void)testCustomSyncUpWithSyncUpFailure
{
    // Create test data
    [self createTestData];
    
    // First sync down
    [self trySyncDown:SFSyncStateMergeModeLeaveIfChanged];
    
    // Make some local change
    NSDictionary* idToLocallyUpdated = [self makeSomeLocalChanges];
    
    // Sync up
    SFSyncUpTarget *customTarget = [[TestSyncUpTarget alloc] initWithRemoteModDateCompare:TestSyncUpTargetRemoteModDateSameAsLocal sendRemoteModError:NO sendSyncUpError:YES];
    SFSyncOptions* options = [SFSyncOptions newSyncOptionsForSyncUp:@[NAME, DESCRIPTION] mergeMode:SFSyncStateMergeModeOverwrite];
    [self trySyncUp:idToLocallyUpdated.count actualChanges:1 target:customTarget options:options completionStatus:SFSyncStateStatusFailed];
}

/**
 * Test addFilterForReSync with various queries
 */
- (void) testAddFilterForResync
{
    NSDateFormatter* isoDateFormatter = [NSDateFormatter new];
    isoDateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
    NSString* baseDateStr = @"2015-02-05T13:12:03.956-0800";
    NSDate* date = [isoDateFormatter dateFromString:baseDateStr];
    long long dateLong = (long long)([date timeIntervalSince1970] * 1000.0);
    NSString* dateStr = [SFSmartSyncObjectUtils getIsoStringFromMillis:dateLong];
    
    // Original queries
    NSString* originalBasicQuery = @"select Id from Account";
    NSString* originalLimitQuery = @"select Id from Account limit 100";
    NSString* originalNameQuery = @"select Id from Account where Name = 'John'";
    NSString* originalNameLimitQuery = @"select Id from Account where Name = 'John' limit 100";
    NSString* originalBasicQueryUpper = @"SELECT Id FROM Account";
    NSString* originalLimitQueryUpper = @"SELECT Id FROM Account LIMIT 100";
    NSString* originalNameQueryUpper = @"SELECT Id FROM Account WHERE Name = 'John'";
    NSString* originalNameLimitQueryUpper = @"SELECT Id FROM Account WHERE Name = 'John' LIMIT 100";
    
    // Test different modification date field names.
    for (NSString *modDateFieldName in @[ @"LastModifiedDate", @"CustomModDate" ]) {
        // Expected queries
        NSString* basicQuery = [NSString stringWithFormat:@"select Id from Account where %@ > %@", modDateFieldName, dateStr];
        NSString* limitQuery = [NSString stringWithFormat:@"select Id from Account where %@ > %@ limit 100", modDateFieldName, dateStr];
        NSString* nameQuery = [NSString stringWithFormat:@"select Id from Account where %@ > %@ and Name = 'John'", modDateFieldName, dateStr];
        NSString* nameLimitQuery = [NSString stringWithFormat:@"select Id from Account where %@ > %@ and Name = 'John' limit 100", modDateFieldName, dateStr];
        NSString* basicQueryUpper = [NSString stringWithFormat:@"SELECT Id FROM Account where %@ > %@", modDateFieldName, dateStr];
        NSString* limitQueryUpper = [NSString stringWithFormat:@"SELECT Id FROM Account where %@ > %@ LIMIT 100", modDateFieldName, dateStr];
        NSString* nameQueryUpper = [NSString stringWithFormat:@"SELECT Id FROM Account WHERE %@ > %@ and Name = 'John'", modDateFieldName, dateStr];
        NSString* nameLimitQueryUpper = [NSString stringWithFormat:@"SELECT Id FROM Account WHERE %@ > %@ and Name = 'John' LIMIT 100", modDateFieldName, dateStr];
        
        // Tests
        XCTAssertEqualObjects(basicQuery, [SFSoqlSyncDownTarget addFilterForReSync:originalBasicQuery modDateFieldName:modDateFieldName maxTimeStamp:dateLong]);
        XCTAssertEqualObjects(limitQuery, [SFSoqlSyncDownTarget addFilterForReSync:originalLimitQuery modDateFieldName:modDateFieldName maxTimeStamp:dateLong]);
        XCTAssertEqualObjects(nameQuery, [SFSoqlSyncDownTarget addFilterForReSync:originalNameQuery modDateFieldName:modDateFieldName maxTimeStamp:dateLong]);
        XCTAssertEqualObjects(nameLimitQuery, [SFSoqlSyncDownTarget addFilterForReSync:originalNameLimitQuery modDateFieldName:modDateFieldName maxTimeStamp:dateLong]);
        XCTAssertEqualObjects(basicQueryUpper, [SFSoqlSyncDownTarget addFilterForReSync:originalBasicQueryUpper modDateFieldName:modDateFieldName maxTimeStamp:dateLong]);
        XCTAssertEqualObjects(limitQueryUpper, [SFSoqlSyncDownTarget addFilterForReSync:originalLimitQueryUpper modDateFieldName:modDateFieldName maxTimeStamp:dateLong]);
        XCTAssertEqualObjects(nameQueryUpper, [SFSoqlSyncDownTarget addFilterForReSync:originalNameQueryUpper modDateFieldName:modDateFieldName maxTimeStamp:dateLong]);
        XCTAssertEqualObjects(nameLimitQueryUpper, [SFSoqlSyncDownTarget addFilterForReSync:originalNameLimitQueryUpper modDateFieldName:modDateFieldName maxTimeStamp:dateLong]);
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

/**
 Test that doing resync while corresponding sync is running fails.
 */
- (void) testReSyncRunningSync
{

    // Create test data
    [self createTestData];
    
    // Ids clause
    NSString* idsClause = [self buildInClause:[idToFields allKeys]];
    
    // Create sync
    NSString* soql = [@[@"SELECT Id, Name, LastModifiedDate FROM Account WHERE Id IN ", idsClause] componentsJoinedByString:@""];
    SlowSoqlSyncDownTarget* target = [SlowSoqlSyncDownTarget newSyncTarget:soql];
    SFSyncOptions* options = [SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeLeaveIfChanged];
    SFSyncState* sync = [SFSyncState newSyncDownWithOptions:options target:target soupName:ACCOUNTS_SOUP name:nil store:self.store];
    NSNumber* syncId = [NSNumber numberWithInteger:sync.syncId];

    // Run sync -- will freeze during fetch
    SFSyncUpdateCallbackQueue* queue = [[SFSyncUpdateCallbackQueue alloc] init];
    [queue runSync:sync syncManager:self.syncManager];
    
    // Wait for sync to be running
    [queue getNextSyncUpdate];

    // Calling reSync -- expect nil
    XCTAssertNil([self.syncManager reSync:syncId updateBlock:nil]);
    
    // Wait for sync to complete successfully
    while ([queue getNextSyncUpdate].status != SFSyncStateStatusDone);
    
    // Calling reSync again -- should return the SFSyncState
    XCTAssertEqual(sync.syncId, [queue runReSync:syncId syncManager:self.syncManager].syncId);

    // Waiting for reSync to complete successfully
    while ([queue getNextSyncUpdate].status != SFSyncStateStatusDone);
}

/**
* Create sync down, get it by id, delete it by id, make sure it's gone
*/
-(void) testCreateGetDeleteSyncDownById {
    // Create
    SFSyncState* sync = [SFSyncState newSyncDownWithOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeLeaveIfChanged] target:[SFSoqlSyncDownTarget newSyncTarget:@"SELECT Id, Name from Account"] soupName:ACCOUNTS_SOUP name:nil store:self.store];
    NSNumber* syncId = [NSNumber numberWithInteger:sync.syncId];
    // Get by id
    SFSyncState* fetchedSync = [SFSyncState byId:syncId store:self.store];
    [self checkStatus:fetchedSync expectedType:sync.type expectedId:sync.syncId expectedName:nil expectedTarget:sync.target expectedOptions:sync.options expectedStatus:sync.status expectedProgress:sync.progress expectedTotalSize:sync.totalSize];
    // Delete by id
    [SFSyncState deleteById:syncId store:self.store];
    XCTAssertNil([SFSyncState byId:syncId store:self.store], "Sync should be gone");
}

/**
 * Create sync down with a name, get it by name, delete it by name, make sure it's gone
 */
-(void) testCreateGetDeleteSyncDownByName {
    NSString* syncName = @"MyNamedSyncDown";
    // Create
    SFSyncState* sync = [SFSyncState newSyncDownWithOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeLeaveIfChanged] target:[SFSoqlSyncDownTarget newSyncTarget:@"SELECT Id, Name from Account"] soupName:ACCOUNTS_SOUP name:syncName store:self.store];
    NSNumber* syncId = [NSNumber numberWithInteger:sync.syncId];
    // Get by name
    SFSyncState* fetchedSync = [SFSyncState byName:syncName store:self.store];
    [self checkStatus:fetchedSync expectedType:sync.type expectedId:sync.syncId expectedName:syncName expectedTarget:sync.target expectedOptions:sync.options expectedStatus:sync.status expectedProgress:sync.progress expectedTotalSize:sync.totalSize];
    // Delete by name
    [SFSyncState deleteByName:syncName store:self.store];
    XCTAssertNil([SFSyncState byId:syncId store:self.store], "Sync should be gone");
    XCTAssertNil([SFSyncState byName:syncName store:self.store], "Sync should be gone");
}

/**
* Create sync up, get it by id, delete it by id, make sure it's gone
*/
-(void) testCreateGetDeleteSyncUpById {
    // Create
    SFSyncState* sync = [SFSyncState newSyncUpWithOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeLeaveIfChanged] target:[SFSyncUpTarget new] soupName:ACCOUNTS_SOUP name:nil store:self.store];
    NSNumber* syncId = [NSNumber numberWithInteger:sync.syncId];
    // Get by id
    SFSyncState* fetchedSync = [SFSyncState byId:syncId store:self.store];
    [self checkStatus:fetchedSync expectedType:sync.type expectedId:sync.syncId expectedName:nil expectedTarget:sync.target expectedOptions:sync.options expectedStatus:sync.status expectedProgress:sync.progress expectedTotalSize:sync.totalSize];
    // Delete by id
    [SFSyncState deleteById:syncId store:self.store];
    XCTAssertNil([SFSyncState byId:syncId store:self.store], "Sync should be gone");
}

/**
 * Create sync up with a name, get it by name, delete it by name, make sure it's gone
 */
-(void) testCreateGetDeleteSyncUpByName {
    NSString* syncName = @"MyNamedSyncUp";
    // Create
    SFSyncState* sync = [SFSyncState newSyncUpWithOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeLeaveIfChanged] target:[SFSyncUpTarget new] soupName:ACCOUNTS_SOUP name:syncName store:self.store];
    NSNumber* syncId = [NSNumber numberWithInteger:sync.syncId];
    // Get by name
    SFSyncState* fetchedSync = [SFSyncState byName:syncName store:self.store];
    [self checkStatus:fetchedSync expectedType:sync.type expectedId:sync.syncId expectedName:syncName expectedTarget:sync.target expectedOptions:sync.options expectedStatus:sync.status expectedProgress:sync.progress expectedTotalSize:sync.totalSize];
    // Delete by name
    [SFSyncState deleteByName:syncName store:self.store];
    XCTAssertNil([SFSyncState byId:syncId store:self.store], "Sync should be gone");
    XCTAssertNil([SFSyncState byName:syncName store:self.store], "Sync should be gone");
}

/**
 * Create sync with a name, make sure a new sync down with the same name cannot be created
 */
- (void) testCreateSyncDownWithExistingName {
    NSString* syncName = @"MyNamedSync";
    // Create a named sync
    [SFSyncState newSyncUpWithOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeLeaveIfChanged] target:[SFSyncUpTarget new] soupName:ACCOUNTS_SOUP name:syncName store:self.store];
    // Try to create a sync down with the same name
    SFSyncState* secondSync = [SFSyncState newSyncDownWithOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeLeaveIfChanged] target:[SFSoqlSyncDownTarget newSyncTarget:@"SELECT Id, Name from Account"] soupName:ACCOUNTS_SOUP name:syncName store:self.store];
    XCTAssertNil(secondSync, @"sync should nil");

    // Delete by name
    [SFSyncState deleteByName:syncName store:self.store];
    XCTAssertNil([SFSyncState byName:syncName store:self.store], "Sync should be gone");
}

/**
 * Create sync with a name, make sure a new sync up with the same name cannot be created
 */
- (void) testCreateSyncUpWithExistingName {
    NSString* syncName = @"MyNamedSync";
    // Create a named sync
    [SFSyncState newSyncDownWithOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeLeaveIfChanged] target:[SFSoqlSyncDownTarget newSyncTarget:@"SELECT Id, Name from Account"] soupName:ACCOUNTS_SOUP name:syncName store:self.store];
    // Try to create a sync up with the same name
    SFSyncState* secondSync = [SFSyncState newSyncUpWithOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeLeaveIfChanged] target:[SFSyncUpTarget new] soupName:ACCOUNTS_SOUP name:syncName store:self.store];
    XCTAssertNil(secondSync, @"sync should nil");

    // Delete by name
    [SFSyncState deleteByName:syncName store:self.store];
    XCTAssertNil([SFSyncState byName:syncName store:self.store], "Sync should be gone");
}

#pragma clang diagnostic pop

#pragma mark - helper methods

- (NSInteger)trySyncDown:(SFSyncStateMergeMode)mergeMode {

    // IDs clause.
    NSString* idsClause = [self buildInClause:[idToFields allKeys]];

    // Creates sync.
    NSString* soql = [@[@"SELECT Id, Name, Description, LastModifiedDate FROM Account WHERE Id IN ", idsClause] componentsJoinedByString:@""];
    SFSoqlSyncDownTarget* target = [SFSoqlSyncDownTarget newSyncTarget:soql];
    return [self trySyncDown:mergeMode target:target soupName:ACCOUNTS_SOUP totalSize:idToFields.count numberFetches:1];
}

- (void)checkDb:(NSDictionary*)dict {
    [self checkDb:dict soupName:ACCOUNTS_SOUP];
}

- (void) checkServer:(NSDictionary*)idToFieldsToCheck {
    return [self checkServer:idToFieldsToCheck objectType:ACCOUNT_TYPE];
}

- (void) checkServer:(NSDictionary*)idToFieldsToCheck byNames:(NSArray*)names {
    // Ids clause.
    NSString* namesClause = [self buildInClause:names];
    
    // Query
    NSString* soql = [NSString stringWithFormat:@"SELECT Id, Name, Description FROM Account WHERE Name IN %@", namesClause];
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql];
    NSArray* records = [self sendSyncRequest:request][RECORDS];
    XCTAssertEqual(names.count, records.count);
    for (NSDictionary* record in records) {
        NSString* accountId = record[ID];
        for (NSString* fieldName in [idToFieldsToCheck[accountId] allKeys]) {
            XCTAssertEqualObjects(idToFieldsToCheck[accountId][fieldName], record[fieldName]);
        }
    }
}

- (void)trySyncUp:(NSInteger)numberChanges mergeMode:(SFSyncStateMergeMode)mergeMode {
    SFSyncOptions* defaultOptions = [SFSyncOptions newSyncOptionsForSyncUp:@[NAME, DESCRIPTION] mergeMode:mergeMode];
    [self trySyncUp:numberChanges options:defaultOptions];
}

- (void)trySyncUp:(NSInteger)numberChanges
          options:(SFSyncOptions *) options {
    SFSyncUpTarget *defaultTarget = [[SFSyncUpTarget alloc] init];
    [self trySyncUp:numberChanges
      actualChanges:numberChanges
             target:defaultTarget
            options:options
   completionStatus:SFSyncStateStatusDone];
}

- (void)createTestData {
    [self createAccountsSoup];
    idToFields = [[self createAccountsOnServer:COUNT_TEST_ACCOUNTS] mutableCopy];
}

- (void)deleteTestData {
    [self deleteAccountsOnServer:[idToFields allKeys]];
    [self dropAccountsSoup];
    [self deleteSyncs];
    idToFields = nil;
}

- (void) deleteSyncs {
    [self.store clearSoup:kSFSyncStateSyncsSoupName];
}

- (NSDictionary*) makeSomeLocalChanges {
    return [self makeSomeLocalChanges:idToFields soupName:ACCOUNTS_SOUP];
}

- (NSDictionary*) makeSomeRemoteChanges {
    return [self makeSomeRemoteChanges:idToFields objectType:ACCOUNT_TYPE];
}

-(void) deleteAccountsLocally:(NSArray*)ids {
    [self deleteRecordsLocally:ids soupName:ACCOUNTS_SOUP];
}

-(void)updateAccountsOnServer:(NSDictionary*)idToFieldsUpdated {
    [self updateRecordsOnServer:idToFieldsUpdated objectType:ACCOUNT_TYPE];
}

- (void)deleteAccountsOnServer:(NSArray *)ids {
    [self deleteRecordsOnServer:ids objectType:ACCOUNT_TYPE];
}

@end
