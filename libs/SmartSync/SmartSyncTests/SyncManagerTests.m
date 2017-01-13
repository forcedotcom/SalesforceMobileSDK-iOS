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

#import <XCTest/XCTest.h>
#import "SFSmartSyncSyncManager.h"
#import "SFSyncUpdateCallbackQueue.h"
#import "TestSyncUpTarget.h"
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/TestSetupUtils.h>
#import <SalesforceSDKCore/SFJsonUtils.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SmartStore/SFSmartStore.h>
#import <SmartStore/SFSoupIndex.h>
#import <SmartStore/SFQuerySpec.h>
#import <SalesforceSDKCore/SFSDKTestRequestListener.h>
#import <SmartSync/SFSoqlSyncDownTarget.h>
#import <SmartSync/SFSoslSyncDownTarget.h>
#import <SmartSync/SFMruSyncDownTarget.h>
#import <SmartSync/SFSyncUpTarget.h>
#import <SalesforceSDKCore/SFSDKSoqlBuilder.h>
#import <SalesforceSDKCore/SFSDKSoslBuilder.h>
#import <SalesforceSDKCore/SFSDKSoslReturningBuilder.h>

#define ACCOUNTS_SOUP       @"accounts"
#define ID                  @"Id"
#define NAME                @"Name"
#define DESCRIPTION         @"Description"
#define ACCOUNT_TYPE        @"Account"
#define LAST_MODIFIED_DATE  @"lastModifiedDate"
#define ATTRIBUTES          @"attributes"
#define TYPE                @"type"
#define RECORDS             @"records"
#define COUNT_TEST_ACCOUNTS 10
#define TOTAL_SIZE_UNKNOWN  -2

/**
 To test multiple round trip during refresh-sync-down, we need access to countIdsPerSoql
 */
@interface SFRefreshSyncDownTarget ()
@property (nonatomic, assign, readwrite) NSUInteger countIdsPerSoql;
@end

/**
 Soql sync down target that pauses for a second at the beginning of the fetch
 */
@interface SlowSoqlSyncDownTarget : SFSoqlSyncDownTarget
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


@interface SyncManagerTests : XCTestCase
{
    SFUserAccount *currentUser;
    SFSmartSyncSyncManager *syncManager;
    SFSmartStore *store;
    NSMutableDictionary* idToFields; // id -> {Name: xxx, Description: yyy}
}
@end

static NSException *authException = nil;

@implementation SyncManagerTests

#pragma mark - setUp/tearDown

+ (void)setUp
{
    @try {
        [SFLogger sharedLogger].logLevel = SFLogLevelDebug;
        [TestSetupUtils populateAuthCredentialsFromConfigFileForClass:[self class]];
        [TestSetupUtils synchronousAuthRefresh];
        [SFSmartStore removeAllStores];
        
    } @catch (NSException *exception) {
        [self log:SFLogLevelDebug format:@"Populating auth from config failed: %@", exception];
        authException = exception;
    }
    [super setUp];
}

- (void)setUp
{
    if (authException) {
        XCTFail(@"Setting up authentication failed: %@", authException);
    }
    [SFRestAPI setIsTestRun:YES];
    [[SFRestAPI sharedInstance] setCoordinator:[SFAuthenticationManager sharedManager].coordinator];
    
    // User and managers setup
    currentUser = [SFUserAccountManager sharedInstance].currentUser;
    syncManager = [SFSmartSyncSyncManager sharedInstance:currentUser];
    store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName user:currentUser];
    [super setUp];
}

- (void)tearDown
{
    // Deleting test data
    [self deleteTestData];
    
    // User and managers tear down
    [SFSmartSyncSyncManager removeSharedInstance:currentUser];
    [[SFRestAPI sharedInstance] cleanup];
    [SFRestAPI setIsTestRun:NO];
    
    currentUser = nil;
    syncManager = nil;
    store = nil;
    
    // Some test runs were failing, saying the run didn't complete. This seems to fix that.
    [NSThread sleepForTimeInterval:0.1];
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
    [target getListOfRemoteIds:syncManager localIds:@[] errorBlock:^(NSError *e) {
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

    // Creates 3 accounts on the server.
    NSMutableDictionary* accountIdToFields = [[NSMutableDictionary alloc] initWithDictionary:[self createAccountsOnServer:3]];
    XCTAssertEqual(accountIdToFields.count, 3, @"3 accounts should have been created");
    NSArray* accountIds = [accountIdToFields allKeys];
    NSString* soupName = ACCOUNTS_SOUP;
    [self createAccountsSoup:soupName];

    // Builds SOQL sync down target and performs initial sync.
    NSMutableString* soql = [[NSMutableString alloc] init];
    [soql appendString:@"SELECT Id, Name FROM Account WHERE Id IN ('"];
    [soql appendString:accountIds[0]];
    [soql appendString:@"', '"];
    [soql appendString:accountIds[1]];
    [soql appendString:@"', '"];
    [soql appendString:accountIds[2]];
    [soql appendString:@"')"];
    NSNumber* syncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeLeaveIfChanged target:[SFSoqlSyncDownTarget newSyncTarget:soql] soupName:soupName totalSize:accountIdToFields.count numberFetches:1]];
    SFQuerySpec *querySpec = [SFQuerySpec newAllQuerySpec:soupName withOrderPath:ID withOrder:kSFSoupQuerySortOrderAscending withPageSize:10];
    NSUInteger numRecords = [store countWithQuerySpec:querySpec error:nil];
    XCTAssertEqual(numRecords, 3, @"3 accounts should be stored in the soup");

    // Deletes 1 account on the server and verifies the ghost record is cleared from the soup.
    [self deleteAccountsOnServer:@[accountIds[0]]];
    XCTestExpectation* cleanResyncGhosts = [self expectationWithDescription:@"cleanResyncGhosts"];
    [syncManager cleanResyncGhosts:syncId completionStatusBlock:^(SFSyncStateStatus syncStatus) {
        if (syncStatus == SFSyncStateStatusFailed || syncStatus == SFSyncStateStatusDone) {
                [cleanResyncGhosts fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    numRecords = [store countWithQuerySpec:querySpec error:nil];
    XCTAssertEqual(numRecords, 2, @"2 accounts should be stored in the soup");

    // Deletes the remaining accounts on the server.
    [self deleteAccountsOnServer:@[accountIds[1]]];
    [self deleteAccountsOnServer:@[accountIds[2]]];
}

/**
 * Tests if ghost records are cleaned locally for a MRU target.
 */
- (void)testCleanResyncGhostsForMRUTarget
{
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForMetadataWithObjectType:ACCOUNT_TYPE];
    NSMutableArray* existingAcccounts =[self sendSyncRequest:request][kRecentItems];

    // Creates 3 accounts on the server.
    NSMutableDictionary* accountIdToFields = [[NSMutableDictionary alloc] initWithDictionary:[self createAccountsOnServer:3]];
    XCTAssertEqual(accountIdToFields.count, 3, @"3 accounts should have been created");
    NSArray* accountIds = [accountIdToFields allKeys];
    NSString* soupName = ACCOUNTS_SOUP;
    [self createAccountsSoup:soupName];
    
    for (NSDictionary* account in existingAcccounts) {
        accountIdToFields[account[ID]] = @{NAME:account[NAME]};
    }

    // Builds MRU sync down target and performs initial sync.
    NSNumber* syncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeLeaveIfChanged target:[SFMruSyncDownTarget newSyncTarget:ACCOUNT_TYPE fieldlist:@[ID, NAME, DESCRIPTION]] soupName:soupName totalSize:accountIdToFields.count numberFetches:1]];
    SFQuerySpec *querySpec = [SFQuerySpec newAllQuerySpec:soupName withOrderPath:ID withOrder:kSFSoupQuerySortOrderAscending withPageSize:10];
    NSUInteger preNumRecords = [store countWithQuerySpec:querySpec error:nil];
    XCTAssertTrue(preNumRecords > 0, @"At least 1 account should be stored in the soup");

    // Deletes 1 account on the server and verifies the ghost record is cleared from the soup.
    [self deleteAccountsOnServer:@[accountIds[0]]];
    XCTestExpectation* cleanResyncGhosts = [self expectationWithDescription:@"cleanResyncGhosts"];
    [syncManager cleanResyncGhosts:syncId completionStatusBlock:^(SFSyncStateStatus syncStatus) {
        if (syncStatus == SFSyncStateStatusFailed || syncStatus == SFSyncStateStatusDone) {
            [cleanResyncGhosts fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    NSUInteger postNumRecords = [store countWithQuerySpec:querySpec error:nil];
    XCTAssertEqual(postNumRecords, preNumRecords - 1, @"1 less account should be stored in the soup");

    // Deletes the remaining accounts on the server.
    [self deleteAccountsOnServer:@[accountIds[1]]];
    [self deleteAccountsOnServer:@[accountIds[2]]];
}

/**
 * Tests if ghost records are cleaned locally for a SOSL target.
 */
- (void)testCleanResyncGhostsForSOSLTarget
{

    // Creates 1 account on the server.
    NSMutableDictionary* accountIdToFields = [[NSMutableDictionary alloc] initWithDictionary:[self createAccountsOnServer:1]];
    XCTAssertEqual(accountIdToFields.count, 1, @"1 account should have been created");
    NSArray* accountIds = [accountIdToFields allKeys];
    NSString* soupName = ACCOUNTS_SOUP;
    [self createAccountsSoup:soupName];

    // Builds SOSL sync down target and performs initial sync.
    SFSDKSoslBuilder* soslBuilder = [SFSDKSoslBuilder withSearchTerm:accountIdToFields[accountIds[0]][NAME]];
    SFSDKSoslReturningBuilder* returningBuilder = [SFSDKSoslReturningBuilder withObjectName:ACCOUNT_TYPE];
    [returningBuilder fields:@"Id, Name, Description"];
    NSString* sosl = [[[soslBuilder returning:returningBuilder] searchGroup:@"NAME FIELDS"] build];
    NSNumber* syncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeLeaveIfChanged target:[SFSoslSyncDownTarget newSyncTarget:sosl] soupName:soupName totalSize:accountIdToFields.count numberFetches:1]];
    SFQuerySpec *querySpec = [SFQuerySpec newAllQuerySpec:soupName withOrderPath:ID withOrder:kSFSoupQuerySortOrderAscending withPageSize:10];
    NSUInteger numRecords = [store countWithQuerySpec:querySpec error:nil];
    XCTAssertEqual(numRecords, 1, @"1 account should be stored in the soup");

    // Deletes 1 account on the server and verifies the ghost record is cleared from the soup.
    [self deleteAccountsOnServer:@[accountIds[0]]];
    XCTestExpectation* cleanResyncGhosts = [self expectationWithDescription:@"cleanResyncGhosts"];
    [syncManager cleanResyncGhosts:syncId completionStatusBlock:^(SFSyncStateStatus syncStatus) {
        if (syncStatus == SFSyncStateStatusFailed || syncStatus == SFSyncStateStatusDone) {
            [cleanResyncGhosts fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    numRecords = [store countWithQuerySpec:querySpec error:nil];
    XCTAssertEqual(numRecords, 0, @"No accounts should be stored in the soup");

    // Deletes the remaining accounts on the server.
    [self deleteAccountsOnServer:@[accountIds[0]]];
}

/**
 * Test instantiation of sync manager from various sharedInstance methods.
 */
- (void)testSyncManagerSharedInstanceMethods
{
    SFSmartSyncSyncManager *mgr1 = [SFSmartSyncSyncManager sharedInstance:currentUser];
    SFSmartStore *store1 = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
    SFSmartSyncSyncManager *mgr2 = [SFSmartSyncSyncManager sharedInstanceForStore:store1];
    SFSmartSyncSyncManager *mgr3 = [SFSmartSyncSyncManager sharedInstanceForUser:currentUser storeName:kDefaultSmartStoreName];
    XCTAssertEqual(mgr1, mgr2, @"Sync managers should be the same.");
    XCTAssertEqual(mgr1, mgr3, @"Sync managers should be the same.");
    
    NSString *storeName2 = @"AnotherStore";
    SFSmartSyncSyncManager *mgr4 = [SFSmartSyncSyncManager sharedInstance:currentUser];
    SFSmartStore *store2 = [SFSmartStore sharedStoreWithName:storeName2];
    SFSmartSyncSyncManager *mgr5 = [SFSmartSyncSyncManager sharedInstanceForStore:store2];
    SFSmartSyncSyncManager *mgr6 = [SFSmartSyncSyncManager sharedInstanceForUser:currentUser storeName:storeName2];
    XCTAssertEqual(mgr1, mgr4, @"Sync managers should be the same.");
    XCTAssertNotEqual(mgr4, mgr5, @"Sync managers should not be the same.");
    XCTAssertNotEqual(mgr4, mgr6, @"Sync managers should not be the same.");
    XCTAssertEqual(mgr5, mgr6, @"Sync managers should be the same.");
    
    [SFSmartStore removeSharedStoreWithName:storeName2 forUser:currentUser];
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
    SFSyncState *syncUpState = [SFSyncState newSyncUpWithOptions:options soupName:ACCOUNTS_SOUP store:store];
    XCTAssertEqual([syncUpState.target class], [SFSyncUpTarget class], @"Default sync up target should be SFSyncUpTarget");
}

/**
 * getSyncStatus should return null for invalid sync id
 */
- (void)testGetSyncStatusForInvalidSyncId
{
    SFSyncState* sync = [syncManager getSyncStatus:[NSNumber numberWithInt:-1]];
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
 * Sync down the test accounts, modify a few on the server, re-sync, make sure only the updated ones are downloaded
 */
- (void)testReSync
{
    // Create test data
    [self createTestData];
    
    // first sync down
    NSNumber* syncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeOverwrite]];
    
    // Check sync time stamp
    SFSyncState* sync = [syncManager getSyncStatus:syncId];
    SFSyncDownTarget* target = (SFSyncDownTarget*) sync.target;
    SFSyncOptions* options = sync.options;
    long long maxTimeStamp = sync.maxTimeStamp;
    XCTAssertTrue(maxTimeStamp > 0);
    
    // Make some remote changes
    NSDictionary* idToFieldsUpdated = [self makeSomeRemoteChanges];
    
    // Call reSync
    SFSyncUpdateCallbackQueue* queue = [[SFSyncUpdateCallbackQueue alloc] init];
    [queue runReSync:syncId syncManager:syncManager];
    
    // Check status updates
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:-1]; // we get an update right away before getting records to sync
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:idToFieldsUpdated.count];
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusDone expectedProgress:100 expectedTotalSize:idToFieldsUpdated.count];
    
    // Check db
    [self checkDb:idToFieldsUpdated];
    
    // Check sync time stamp
    XCTAssertTrue([syncManager getSyncStatus:syncId].maxTimeStamp > maxTimeStamp);
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
        [store upsertEntries:@[@{ID:accountId}] toSoup:ACCOUNTS_SOUP];
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
        [store upsertEntries:@[@{ID:accountId}] toSoup:ACCOUNTS_SOUP];
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
        [store upsertEntries:@[@{ID:accountId}] toSoup:ACCOUNTS_SOUP];
    }

    // Running a refresh-sync-down for soup with two ids per soql query (to force multiple round trips)
    SFRefreshSyncDownTarget* target = [SFRefreshSyncDownTarget newSyncTarget:ACCOUNTS_SOUP objectType:ACCOUNT_TYPE fieldlist:@[ID, NAME, DESCRIPTION, LAST_MODIFIED_DATE]];
    target.countIdsPerSoql = 1;
    NSNumber* syncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeOverwrite target:target soupName:ACCOUNTS_SOUP totalSize:idToFields.count numberFetches:idToFields.count]];

    // Check sync time stamp
    SFSyncState* sync = [syncManager getSyncStatus:syncId];
    SFSyncOptions* options = sync.options;
    long long maxTimeStamp = sync.maxTimeStamp;
    XCTAssertTrue(maxTimeStamp > 0, @"Wrong time stamp");

    // Make sure the soup has the records with id and names
    [self checkDb:idToFields];

    // Make some remote changes
    NSDictionary* idToFieldsUpdated = [self makeSomeRemoteChanges];
    
    // Call reSync
    SFSyncUpdateCallbackQueue* queue = [[SFSyncUpdateCallbackQueue alloc] init];
    [queue runReSync:syncId syncManager:syncManager];
    
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
    XCTAssertTrue([syncManager getSyncStatus:syncId].maxTimeStamp > maxTimeStamp);
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
        [store upsertEntries:@[@{ID:accountId}] toSoup:ACCOUNTS_SOUP];
    }
    
    // Running a refresh-sync-down for soup
    SFRefreshSyncDownTarget* target = [SFRefreshSyncDownTarget newSyncTarget:ACCOUNTS_SOUP objectType:ACCOUNT_TYPE fieldlist:@[ID, NAME, DESCRIPTION]];
    NSNumber* syncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeOverwrite target:target soupName:ACCOUNTS_SOUP totalSize:idToFields.count numberFetches:1]];
    
    // Deletes 1 account on the server and verifies the ghost record is cleared from the soup.
    NSString* idDeleted = accountIds[0];
    [self deleteAccountsOnServer:@[idDeleted]];
    XCTestExpectation* cleanResyncGhosts = [self expectationWithDescription:@"cleanResyncGhosts"];
    [syncManager cleanResyncGhosts:syncId completionStatusBlock:^(SFSyncStateStatus syncStatus) {
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
    NSUInteger numRecords = [store countWithQuerySpec:[SFQuerySpec newAllQuerySpec:ACCOUNTS_SOUP withOrderPath:ID withOrder:kSFSoupQuerySortOrderAscending withPageSize:10] error:nil];
    XCTAssertEqual(numRecords, idToFieldsLeft.count, @"Wrong number of accounts found in soup");
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
    NSArray* ids = [idToFields allKeys];
    NSString* idsClause = [self buildInClause:ids];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocal]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyDeleted]);
    }
    
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
    NSArray* ids = [idToFieldsLocallyUpdated allKeys];
    NSString* idsClause = [self buildInClause:ids];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocal]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyDeleted]);
    }
    
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
    SFSyncOptions* options = [SFSyncOptions newSyncOptionsForSyncUp:@[NAME, DESCRIPTION] createFieldlist:nil updateFieldlist:@[NAME] mergeMode:SFSyncStateMergeModeOverwrite];
    [self trySyncUp:idToFieldsLocallyUpdated.count options:options];
    
    // Check that db doesn't show entries as locally modified anymore
    NSArray* ids = [idToFieldsLocallyUpdated allKeys];
    NSString* idsClause = [self buildInClause:ids];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocal]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyDeleted]);
    }
    
    // Check server - make sure only name was updated
    NSMutableDictionary* idToFieldsExpectedOnServer = [NSMutableDictionary new];
    for (NSString* id in idToFieldsLocallyUpdated) {
        idToFieldsExpectedOnServer[id] = @{NAME: idToFieldsLocallyUpdated[id][NAME], DESCRIPTION:idToFields[id][DESCRIPTION]}; // should have modified name but original description
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
    SFSyncOptions* options = [SFSyncOptions newSyncOptionsForSyncUp:@[NAME, DESCRIPTION] createFieldlist:@[NAME] updateFieldlist:nil mergeMode:SFSyncStateMergeModeOverwrite];
    [self trySyncUp:names.count options:options];
    
    // Check that db doesn't show entries as locally created anymore and that they use sfdc id
    NSString* namesClause = [self buildInClause:names];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Name} IN %@", namesClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:names.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    NSMutableDictionary* idToFieldsCreated = [NSMutableDictionary new];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        NSString* accountId = account[ID];
        idToFieldsCreated[accountId] = @{NAME:account[NAME], DESCRIPTION:account[DESCRIPTION]};
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocal]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyDeleted]);
        XCTAssertFalse([accountId hasPrefix:@"local_"]);
    }
    
    // Check server - make sure only name was set
    NSMutableDictionary* idToFieldsExpectedOnServer = [NSMutableDictionary new];
    for (NSString* id in idToFieldsCreated) {
        idToFieldsExpectedOnServer[id] = @{NAME: idToFieldsCreated[id][NAME], DESCRIPTION:[NSNull null]}; // should have name but no description
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
    for (NSString* id in idToFieldsLocallyUpdated) {
        [namesOfUpdated addObject:idToFieldsLocallyUpdated[id][NAME]];
    }
    
    // Create a few entries locally
    NSArray* namesOfCreated = @[ [self createAccountName], [self createAccountName], [self createAccountName]];
    [self createAccountsLocally:namesOfCreated];
    
    // Sync up with different create and update field lists
    SFSyncOptions* options = [SFSyncOptions newSyncOptionsForSyncUp:@[NAME, DESCRIPTION] createFieldlist:@[NAME] updateFieldlist:@[DESCRIPTION] mergeMode:SFSyncStateMergeModeOverwrite];
    [self trySyncUp:(namesOfUpdated.count + namesOfCreated.count) options:options];
    
    // Check that db doesn't show entries as locally created anymore and that they use sfdc id
    NSArray* allNames = [namesOfCreated arrayByAddingObjectsFromArray:namesOfUpdated];
    NSString* namesClause = [self buildInClause:allNames];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Name} IN %@", namesClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:allNames.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    NSMutableDictionary* idToFieldsCreated = [NSMutableDictionary new];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        NSString* accountId = account[ID];
        NSString* accountName = account[NAME];
        NSString* accountDescription = account[DESCRIPTION];
        if ([namesOfCreated containsObject:accountName]) {
            idToFieldsCreated[accountId] = @{NAME:accountName, DESCRIPTION:accountDescription};
        }
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocal]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyDeleted]);
        XCTAssertFalse([accountId hasPrefix:@"local_"]);
    }
    // Make sure all the locally created records have synched up
    XCTAssertEqual(namesOfCreated.count, idToFieldsCreated.count);
    
    // Check server - make updated records only have updated description - make sure created records only have name
    NSMutableDictionary* idToFieldsExpectedOnServer = [NSMutableDictionary new];
    for (NSString* id in idToFieldsLocallyUpdated) {
        idToFieldsExpectedOnServer[id] = @{NAME: idToFields[id][NAME], DESCRIPTION:idToFieldsLocallyUpdated[id][DESCRIPTION]}; // updated records should have original name and updated description
    }
    for (NSString* id in idToFieldsCreated) {
        idToFieldsExpectedOnServer[id] = @{NAME: idToFieldsCreated[id][NAME], DESCRIPTION:[NSNull null]}; // created recrods should have name but no description
    }

    // Make sure we found all the records on the server
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
    NSArray* ids = [idToFieldsLocallyUpdated allKeys];
    NSString* idsClause = [self buildInClause:ids];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocal]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyDeleted]);
    }
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
    NSString* idsClause = [self buildInClause:ids];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        XCTAssertEqualObjects(@YES, account[kSyncManagerLocal]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqualObjects(@YES, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyDeleted]);
    }

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
    NSString* idsClause = [self buildInClause:ids];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        XCTAssertEqualObjects(@YES, account[kSyncManagerLocal]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqualObjects(@YES, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyDeleted]);
    }
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
    NSString* namesClause = [self buildInClause:names];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Name} IN %@", namesClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:names.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    NSMutableDictionary* idToFieldsCreated = [NSMutableDictionary new];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        NSString* accountId = account[ID];
        idToFieldsCreated[accountId] = @{NAME:account[NAME], DESCRIPTION:account[DESCRIPTION]};
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocal]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyDeleted]);
        XCTAssertFalse([accountId hasPrefix:@"local_"]);
    }
    
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
    NSDictionary* idToFieldsCreated = [self createAccountsLocally:names];

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
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
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
    SFSyncUpTarget *customTarget = [[TestSyncUpTarget alloc] initWithRemoteModDateCompare:TestSyncUpTargetRemoteModDateSameAsLocal
                                                                                     sendRemoteModError:NO
                                                                                        sendSyncUpError:NO];
    [self trySyncUp:3 target:customTarget mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Check that db doesn't show entries as locally created anymore and that they use returned id
    NSString* namesClause = [self buildInClause:names];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Name} IN %@", namesClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:names.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        NSString* accountId = account[ID];
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocal]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyDeleted]);
        XCTAssertFalse([accountId hasPrefix:@"local_"]);
    }
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
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
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
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    NSMutableDictionary* idToFieldsUpdated = [NSMutableDictionary new];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        NSString* accountId = account[ID];
        NSString* accountName = account[NAME];
        idToFieldsUpdated[accountId] = @{NAME: accountName, DESCRIPTION: account[DESCRIPTION]};
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocal]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyDeleted]);

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
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        if ([account[ID] isEqualToString:remotelyDeletedId]) {
            XCTAssertEqualObjects(@YES, account[kSyncManagerLocal]);
            XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyCreated]);
            XCTAssertEqualObjects(@YES, account[kSyncManagerLocallyUpdated]);
            XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyDeleted]);
        } else {
            XCTAssertEqualObjects(@NO, account[kSyncManagerLocal]);
            XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyCreated]);
            XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyUpdated]);
            XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyDeleted]);
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
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
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
    SFSyncUpTarget *customTarget = [[TestSyncUpTarget alloc] initWithRemoteModDateCompare:TestSyncUpTargetRemoteModDateSameAsLocal
                                                                                     sendRemoteModError:NO
                                                                                        sendSyncUpError:NO];
    [self trySyncUp:3 target:customTarget mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Check that db doesn't doesn't contain those entries anymore
    NSString* idsClause = [self buildInClause:idsLocallyDeleted];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:idsLocallyDeleted.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
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
    NSString* idsClause = [self buildInClause:idsLocallyDeleted];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:idsLocallyDeleted.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    XCTAssertEqual(3, rows.count);
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        XCTAssertEqualObjects(@YES, account[kSyncManagerLocal]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqualObjects(@YES, account[kSyncManagerLocallyDeleted]);
    }

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
    SFSyncUpTarget *customTarget = [[TestSyncUpTarget alloc] initWithRemoteModDateCompare:TestSyncUpTargetRemoteModDateGreaterThanLocal
                                                                                     sendRemoteModError:NO
                                                                                        sendSyncUpError:NO];
    [self trySyncUp:3 target:customTarget mergeMode:SFSyncStateMergeModeLeaveIfChanged];
    
    // Check that db still shows entries as locally deleted
    NSString* idsClause = [self buildInClause:idsLocallyDeleted];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:idsLocallyDeleted.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    XCTAssertEqual(3, rows.count);
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        XCTAssertEqualObjects(@YES, account[kSyncManagerLocal]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqualObjects(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqualObjects(@YES, account[kSyncManagerLocallyDeleted]);
    }
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
    SFSyncUpTarget *customTarget = [[TestSyncUpTarget alloc] initWithRemoteModDateCompare:TestSyncUpTargetRemoteModDateGreaterThanLocal
                                                                                     sendRemoteModError:YES
                                                                                        sendSyncUpError:NO];
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
    SFSyncUpTarget *customTarget = [[TestSyncUpTarget alloc] initWithRemoteModDateCompare:TestSyncUpTargetRemoteModDateSameAsLocal
                                                                                     sendRemoteModError:NO
                                                                                        sendSyncUpError:YES];
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
    SFSyncState* sync = [SFSyncState newSyncDownWithOptions:options target:target soupName:ACCOUNTS_SOUP store:store];
    NSNumber* syncId = [NSNumber numberWithInteger:sync.syncId];

    // Run sync -- will freeze during fetch
    SFSyncUpdateCallbackQueue* queue = [[SFSyncUpdateCallbackQueue alloc] init];
    [queue runSync:sync syncManager:syncManager];
    
    // Wait for sync to be running
    [queue getNextSyncUpdate];

    // Calling reSync -- expect nil
    XCTAssertNil([syncManager reSync:syncId updateBlock:nil]);
    
    // Wait for sync to complete successfully
    while ([queue getNextSyncUpdate].status != SFSyncStateStatusDone);
    
    // Calling reSync again -- should return the SFSyncState
    XCTAssertEqual(sync.syncId, [queue runReSync:syncId syncManager:syncManager].syncId);

    // Waiting for reSync to complete successfully
    while ([queue getNextSyncUpdate].status != SFSyncStateStatusDone);
}

#pragma mark - helper methods

- (NSInteger)trySyncDown:(SFSyncStateMergeMode)mergeMode {

    // IDs clause.
    NSString* idsClause = [self buildInClause:[idToFields allKeys]];

    // Creates sync.
    NSString* soql = [@[@"SELECT Id, Name, Description, LastModifiedDate FROM Account WHERE Id IN ", idsClause] componentsJoinedByString:@""];
    SFSoqlSyncDownTarget* target = [SFSoqlSyncDownTarget newSyncTarget:soql];
    return [self trySyncDown:mergeMode target:target soupName:ACCOUNTS_SOUP totalSize:idToFields.count numberFetches:1];
}

- (NSInteger)trySyncDown:(SFSyncStateMergeMode)mergeMode target:(SFSyncDownTarget*)target soupName:(NSString*)soupName {
    return [self trySyncDown:mergeMode target:target soupName:soupName totalSize:TOTAL_SIZE_UNKNOWN numberFetches:1];
}

- (NSInteger)trySyncDown:(SFSyncStateMergeMode)mergeMode target:(SFSyncDownTarget*)target soupName:(NSString*)soupName totalSize:(NSUInteger)totalSize numberFetches:(NSUInteger)numberFetches {

    // Creates sync.
    SFSyncOptions* options = [SFSyncOptions newSyncOptionsForSyncDown:mergeMode];
    SFSyncState* sync = [SFSyncState newSyncDownWithOptions:options target:target soupName:soupName store:store];
    NSInteger syncId = sync.syncId;
    [self checkStatus:sync expectedType:SFSyncStateSyncTypeDown expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusNew expectedProgress:0 expectedTotalSize:-1];

    // Runs sync.
    SFSyncUpdateCallbackQueue* queue = [[SFSyncUpdateCallbackQueue alloc] init];
    [queue runSync:sync syncManager:syncManager];

    // Checks status updates.
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:-1];

    if (totalSize != TOTAL_SIZE_UNKNOWN) {
        for (int i = 0; i < numberFetches; i++) {
            [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:(i*100/numberFetches) expectedTotalSize:totalSize];
        }
        [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusDone expectedProgress:100 expectedTotalSize:totalSize];
    } else {
        [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0];
        [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusDone expectedProgress:100];
    }
    return syncId;
}

- (void)checkDb:(NSDictionary*)dict {

    // Ids clause
    NSString* idsClause = [self buildInClause:[dict allKeys]];

    // Query
    NSString* smartSql = [@[@"SELECT {accounts:Id}, {accounts:Name}, {accounts:Description} FROM {accounts} WHERE {accounts:Id} IN ", idsClause] componentsJoinedByString:@""];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:dict.count];
    NSArray* accountsFromDb = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    NSMutableDictionary* idToFieldsFromDb = [NSMutableDictionary new];
    for (NSArray* row in accountsFromDb) {
        idToFieldsFromDb[row[0]] = @{NAME: row[1], DESCRIPTION: row[2]};
    }
    XCTAssertEqual(dict.count, idToFieldsFromDb.count);
    for (NSString* accountId in dict) {
        for (NSString* fieldName in [dict[accountId] allKeys]) {
            XCTAssertEqualObjects(dict[accountId][fieldName], idToFieldsFromDb[accountId][fieldName]);
        }
    }
}

- (void) checkServer:(NSDictionary*)dict {
    // Ids clause.
    NSString* idsClause = [self buildInClause:[dict allKeys]];

    // Query
    NSString* soql = [NSString stringWithFormat:@"SELECT Id, Name, Description FROM Account WHERE Id IN %@", idsClause];
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql];
    NSArray* records = [self sendSyncRequest:request][RECORDS];
    XCTAssertEqual(dict.count, records.count);
    for (NSDictionary* record in records) {
        NSString* accountId = record[ID];
        for (NSString* fieldName in [dict[accountId] allKeys]) {
            XCTAssertEqualObjects(dict[accountId][fieldName], record[fieldName]);
        }
    }
}

- (void) checkServer:(NSDictionary*)dict byNames:(NSArray*)names {
    // Ids clause.
    NSString* namesClause = [self buildInClause:names];
    
    // Query
    NSString* soql = [NSString stringWithFormat:@"SELECT Id, Name, Description FROM Account WHERE Name IN %@", namesClause];
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql];
    NSArray* records = [self sendSyncRequest:request][RECORDS];
    XCTAssertEqual(names.count, records.count);
    for (NSDictionary* record in records) {
        NSString* accountId = record[ID];
        for (NSString* fieldName in [dict[accountId] allKeys]) {
            XCTAssertEqualObjects(dict[accountId][fieldName], record[fieldName]);
        }
    }
}


- (void)trySyncUp:(NSInteger)numberChanges mergeMode:(SFSyncStateMergeMode)mergeMode {
    SFSyncOptions* defaultOptions = [SFSyncOptions newSyncOptionsForSyncUp:@[NAME, DESCRIPTION] mergeMode:mergeMode];
    [self trySyncUp:numberChanges options:defaultOptions];
}

- (void)trySyncUp:(NSInteger)numberChanges
           target:(SFSyncUpTarget *)target
        mergeMode:(SFSyncStateMergeMode)mergeMode {
    SFSyncOptions* defaultOptions = [SFSyncOptions newSyncOptionsForSyncUp:@[NAME, DESCRIPTION] mergeMode:mergeMode];
    [self trySyncUp:numberChanges
      actualChanges:numberChanges
             target:target
            options:defaultOptions
   completionStatus:SFSyncStateStatusDone];
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


- (void) trySyncUp:(NSInteger)numberChanges
     actualChanges:(NSInteger)actualNumberChanges
            target:(SFSyncUpTarget *)target
           options:(SFSyncOptions *) options
  completionStatus:(SFSyncStateStatus)completionStatus {

    // Creates sync.
    SFSyncState *sync = [SFSyncState newSyncUpWithOptions:options target:target soupName:ACCOUNTS_SOUP store:store];
    NSInteger syncId = sync.syncId;
    [self checkStatus:sync expectedType:SFSyncStateSyncTypeUp expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusNew expectedProgress:0 expectedTotalSize:-1];

    // Runs sync.
    SFSyncUpdateCallbackQueue* queue = [[SFSyncUpdateCallbackQueue alloc] init];
    [queue runSync:sync syncManager:syncManager];

    // Checks status updates.
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeUp expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:-1];
    if (actualNumberChanges > 0) {
        [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeUp expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:numberChanges];
        for (int i=1; i<actualNumberChanges; i++) {
            [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeUp expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:i*100/numberChanges expectedTotalSize:numberChanges];
        }
    }
    if (completionStatus == SFSyncStateStatusDone) {
        [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeUp expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:completionStatus expectedProgress:100 expectedTotalSize:numberChanges];
    } else if (completionStatus == SFSyncStateStatusFailed) {
        NSInteger expectedProgress = (actualNumberChanges - 1) * 100 / numberChanges;
        [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeUp expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:completionStatus expectedProgress:expectedProgress expectedTotalSize:numberChanges];
    } else {
        XCTFail(@"completionStatus value '%ld' not currently supported.", (long)completionStatus);
    }
}

- (void)checkStatus:(SFSyncState*)sync
       expectedType:(SFSyncStateSyncType)expectedType
         expectedId:(NSInteger)expectedId
     expectedTarget:(SFSyncTarget*)expectedTarget
    expectedOptions:(SFSyncOptions*)expectedOptions
     expectedStatus:(SFSyncStateStatus)expectedStatus
   expectedProgress:(NSInteger)expectedProgress
  expectedTotalSize:(NSInteger)expectedTotalSize {
    XCTAssertNotNil(sync);
    if (!sync) {
        return;
    }
    XCTAssertEqual(expectedType, sync.type);
    XCTAssertEqual(expectedId, sync.syncId);
    XCTAssertEqual(expectedStatus, sync.status);
    XCTAssertEqual(expectedProgress, sync.progress);
    if (expectedTotalSize != TOTAL_SIZE_UNKNOWN) {
        XCTAssertEqual(expectedTotalSize, sync.totalSize);
    }
    if (expectedTarget) {
        XCTAssertNotNil(sync.target);
        if (expectedType == SFSyncStateSyncTypeDown) {
            XCTAssertTrue([sync.target isKindOfClass:[SFSyncDownTarget class]]);
            SFSyncDownTargetQueryType expectedQueryType = ((SFSyncDownTarget*) expectedTarget).queryType;
            XCTAssertEqual(expectedQueryType, ((SFSyncDownTarget*)sync.target).queryType);
            if (expectedQueryType == SFSyncDownTargetQueryTypeSoql) {
                XCTAssertTrue([sync.target isKindOfClass:[SFSoqlSyncDownTarget class]]);
                XCTAssertEqualObjects(((SFSoqlSyncDownTarget*)expectedTarget).query, ((SFSoqlSyncDownTarget*)sync.target).query);
            } else if (expectedQueryType == SFSyncDownTargetQueryTypeSosl) {
                XCTAssertTrue([sync.target isKindOfClass:[SFSoslSyncDownTarget class]]);
                XCTAssertEqualObjects(((SFSoslSyncDownTarget*)expectedTarget).query, ((SFSoslSyncDownTarget*)sync.target).query);
            } else if (expectedQueryType == SFSyncDownTargetQueryTypeMru) {
                XCTAssertTrue([sync.target isKindOfClass:[SFMruSyncDownTarget class]]);
                XCTAssertEqualObjects(((SFMruSyncDownTarget*)expectedTarget).objectType, ((SFMruSyncDownTarget*)sync.target).objectType);
                XCTAssertEqualObjects(((SFMruSyncDownTarget*)expectedTarget).fieldlist, ((SFMruSyncDownTarget*)sync.target).fieldlist);
            } else if (expectedQueryType == SFSyncDownTargetQueryTypeCustom) {
                XCTAssertTrue([sync.target isKindOfClass:[SFSyncDownTarget class]]);
            }
        } else {
            XCTAssertTrue([sync.target isKindOfClass:[SFSyncUpTarget class]]);
        }
    } else {
        XCTAssertNil(sync.target);
    }
    if (expectedOptions) {
        XCTAssertNotNil(sync.options);
        XCTAssertEqual(expectedOptions.mergeMode, sync.options.mergeMode);
        XCTAssertEqualObjects(expectedOptions.fieldlist, sync.options.fieldlist);
        XCTAssertEqualObjects(expectedOptions.createFieldlist, sync.options.createFieldlist);
        XCTAssertEqualObjects(expectedOptions.updateFieldlist, sync.options.updateFieldlist);
    } else {
        XCTAssertNil(sync.options);
    }
}

- (void)checkStatus:(SFSyncState*)sync
       expectedType:(SFSyncStateSyncType)expectedType
         expectedId:(NSInteger)expectedId
     expectedTarget:(SFSyncTarget*)expectedTarget
    expectedOptions:(SFSyncOptions*)expectedOptions
     expectedStatus:(SFSyncStateStatus)expectedStatus
   expectedProgress:(NSInteger)expectedProgress {
    [self checkStatus:sync expectedType:expectedType expectedId:expectedId expectedTarget:expectedTarget expectedOptions:expectedOptions expectedStatus:expectedStatus expectedProgress:expectedProgress expectedTotalSize:TOTAL_SIZE_UNKNOWN];
}

- (void)createTestData {
    [self createAccountsSoup];
    idToFields = [[NSMutableDictionary alloc] initWithDictionary:[self createAccountsOnServer:COUNT_TEST_ACCOUNTS]];
}

- (void)deleteTestData {
    [self deleteAccountsOnServer:[idToFields allKeys]];
    [self dropAccountsSoup];
    [self deleteSyncs];
}

- (void)createAccountsSoup {
    [self createAccountsSoup:ACCOUNTS_SOUP];
}

- (void)createAccountsSoup:(NSString*)soupName {
    NSArray* indexSpecs = @[
                            [[SFSoupIndex alloc] initWithPath:ID indexType:kSoupIndexTypeFullText columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:NAME indexType:kSoupIndexTypeFullText columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:DESCRIPTION indexType:kSoupIndexTypeFullText columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:kSyncManagerLocal indexType:kSoupIndexTypeString columnName:nil]
                            ];
    [store registerSoup:soupName withIndexSpecs:indexSpecs error:nil];
}

- (void)dropAccountsSoup {
    [self dropAccountsSoup:ACCOUNTS_SOUP];
}

- (void)dropAccountsSoup:(NSString*)soupName {
    [store removeSoup:soupName];
}

- (NSDictionary*)createAccountsOnServer:(NSUInteger)count {
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < count; i++) {
        NSString* accountName = [self createAccountName];
        NSString* description = [self createDescription:accountName];
        NSDictionary* fields = @{NAME: accountName, DESCRIPTION: description};
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:ACCOUNT_TYPE fields:fields];
        NSString* accountId = [self sendSyncRequest:request][@"id"];
        dict[accountId] = fields;
    }
    [NSThread sleepForTimeInterval:1]; //give server a second to settle to reflect in API
    return dict;
}

- (void)deleteAccountsOnServer:(NSArray*)ids {
    for (NSString* accountId in ids) {
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:ACCOUNT_TYPE objectId:accountId];
        [self sendSyncRequest:request ignoreNotFound:YES];
    }
    [NSThread sleepForTimeInterval:1]; //give server a second to settle to reflect in API
}

- (NSString*) createAccountName {
    return [NSString stringWithFormat:@"SyncManagerTest%08d", arc4random_uniform(100000000)];
}

- (NSString*) createDescription:(NSString*)name {
    return [NSString stringWithFormat:@"Description_%@", name];
}

- (NSString*) createLocalId {
    return [NSString stringWithFormat:@"local_%08d", arc4random_uniform(100000000)];
}

- (void) deleteSyncs {
    [store clearSoup:kSFSyncStateSyncsSoupName];
}

- (NSDictionary*) makeSomeLocalChanges {
    NSMutableDictionary* idToFieldsLocallyUpdated = [self prepareSomeChanges:@[@0,@1,@2]];
    [self updateAccountsLocally:idToFieldsLocallyUpdated];
    return idToFieldsLocallyUpdated;
}

- (NSDictionary*) makeSomeRemoteChanges {
    // Make some remote changes
    [NSThread sleepForTimeInterval:1.0f];
    NSMutableDictionary* idToFieldsRemotelyUpdated = [self prepareSomeChanges:@[@0,@2]];
    [self updateAccountsOnServer:idToFieldsRemotelyUpdated];
    return idToFieldsRemotelyUpdated;
}

- (NSMutableDictionary*) prepareSomeChanges:(NSArray*)indices {
    NSMutableDictionary* idToFieldsUpdated = [NSMutableDictionary new];
    NSArray* allIds = [[idToFields allKeys] sortedArrayUsingSelector:@selector(compare:)]; // // to make the status updates sequence deterministic
    NSMutableArray* ids = [NSMutableArray new];
    for (NSNumber* index in indices) {
        [ids addObject:allIds[index.unsignedIntegerValue]];
    }
    for (NSString* accountId in ids) {
        NSString* updatedName = [NSString stringWithFormat:@"%@_updated", idToFields[accountId][NAME]];
        NSString* updatedDescription = [NSString stringWithFormat:@"%@_updated", idToFields[accountId][DESCRIPTION]];
        idToFieldsUpdated[accountId] = @{NAME: updatedName, DESCRIPTION: updatedDescription};
    }
    return idToFieldsUpdated;
}

- (NSDictionary*) createAccountsLocally:(NSArray*)names {
    NSMutableDictionary* idToFieldsLocallyCreated = [NSMutableDictionary new];
    NSMutableArray* createdAccounts = [NSMutableArray new];
    NSMutableDictionary* attributes = [NSMutableDictionary new];
    attributes[TYPE] = ACCOUNT_TYPE;
    for (NSString* name in names) {
        NSMutableDictionary* account = [NSMutableDictionary new];
        NSString* accountId = [self createLocalId];
        account[ID] = accountId;
        account[NAME] = name;
        account[DESCRIPTION] = [self createDescription:name];
        account[ATTRIBUTES] = attributes;
        account[kSyncManagerLocal] = @YES;
        account[kSyncManagerLocallyCreated] = @YES;
        account[kSyncManagerLocallyDeleted] = @NO;
        account[kSyncManagerLocallyUpdated] = @NO;
        [createdAccounts addObject:account];
        idToFieldsLocallyCreated[accountId] = name;
    }
    [store upsertEntries:createdAccounts toSoup:ACCOUNTS_SOUP];
    return idToFieldsLocallyCreated;
}

- (void)updateAccountsLocally:(NSDictionary*)idToFieldsLocallyUpdated {
    NSMutableArray* updatedAccounts = [NSMutableArray new];
    for (NSString* accountId in idToFieldsLocallyUpdated) {
        NSString* updatedName = idToFieldsLocallyUpdated[accountId][NAME];
        NSString* updatedDescription = idToFieldsLocallyUpdated[accountId][DESCRIPTION];
        SFQuerySpec* query = [SFQuerySpec newExactQuerySpec:ACCOUNTS_SOUP withPath:ID withMatchKey:accountId withOrderPath:ID withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
        NSArray* results = [store queryWithQuerySpec:query pageIndex:0 error:nil];
        NSMutableDictionary* account = [[NSMutableDictionary alloc] initWithDictionary:results[0]];
        account[NAME] = updatedName;
        account[DESCRIPTION] = updatedDescription;
        account[kSyncManagerLocal] = @YES;
        account[kSyncManagerLocallyCreated] = @NO;
        account[kSyncManagerLocallyDeleted] = @NO;
        account[kSyncManagerLocallyUpdated] = @YES;
        [updatedAccounts addObject:account];
    }
    [store upsertEntries:updatedAccounts toSoup:ACCOUNTS_SOUP];
}

-(void) deleteAccountsLocally:(NSArray*)idsLocallyDeleted {
    NSMutableArray* deletedAccounts = [NSMutableArray new];
    for (NSString* accountId in idsLocallyDeleted) {
        SFQuerySpec* query = [SFQuerySpec newExactQuerySpec:ACCOUNTS_SOUP withPath:ID withMatchKey:accountId withOrderPath:ID withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
        NSArray* results = [store queryWithQuerySpec:query pageIndex:0 error:nil];
        NSMutableDictionary* account = [[NSMutableDictionary alloc] initWithDictionary:results[0]];
        account[kSyncManagerLocal] = @YES;
        account[kSyncManagerLocallyCreated] = @NO;
        account[kSyncManagerLocallyDeleted] = @YES;
        account[kSyncManagerLocallyUpdated] = @NO;
        [deletedAccounts addObject:account];
    }
    [store upsertEntries:deletedAccounts toSoup:ACCOUNTS_SOUP];
}

-(void)updateAccountsOnServer:(NSDictionary*)idToFieldsUpdated {
    for (NSString* accountId in idToFieldsUpdated) {
        NSDictionary* fields = idToFieldsUpdated[accountId];
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:ACCOUNT_TYPE objectId:accountId fields:fields];
        [self sendSyncRequest:request];
    }
}

- (NSString*) buildInClause:(NSArray*)values {
    return [NSString stringWithFormat:@"('%@')", [values componentsJoinedByString:@"', '"]];
}

- (NSDictionary*)sendSyncRequest:(SFRestRequest*)request {
    return [self sendSyncRequest:request ignoreNotFound:NO];
}

- (NSDictionary*)sendSyncRequest:(SFRestRequest*)request ignoreNotFound:(BOOL)ignoreNotFound {
    SFSDKTestRequestListener *listener = [[SFSDKTestRequestListener alloc] init];
    SFRestFailBlock failBlock = ^(NSError *error) {
        listener.lastError = error;
        listener.returnStatus = kTestRequestStatusDidFail;
        
    };
    SFRestDictionaryResponseBlock completeBlock = ^(NSDictionary *data) {
        listener.dataResponse = data;
        listener.returnStatus = kTestRequestStatusDidLoad;
    };
    [[SFRestAPI sharedInstance] sendRESTRequest:request
                                      failBlock:failBlock
                                  completeBlock:completeBlock];
    [listener waitForCompletion];
    if (listener.lastError && (listener.lastError.code != 404 || !ignoreNotFound)) {
        XCTFail(@"Rest call %@ failed with error %@", request, listener.lastError);
    }
    return (NSDictionary*) listener.dataResponse;
}

@end
