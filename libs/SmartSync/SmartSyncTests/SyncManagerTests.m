/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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
#import "TestSyncServerTarget.h"
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/TestSetupUtils.h>
#import <SalesforceSDKCore/SFJsonUtils.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFSmartStore.h>
#import <SalesforceSDKCore/SFSoupIndex.h>
#import <SalesforceSDKCore/SFQuerySpec.h>
#import <SalesforceSDKCore/SFSDKTestRequestListener.h>
#import <SmartSync/SFSoqlSyncTarget.h>
#import <SmartSync/SFSoslSyncTarget.h>
#import <SmartSync/SFMruSyncTarget.h>
#import <SmartSync/SFSyncServerTarget.h>

#define ACCOUNTS_SOUP       @"accounts"
#define ACCOUNT_ID          @"Id"
#define ACCOUNT_NAME        @"Name"
#define ACCOUNT_TYPE        @"Account"
#define ATTRIBUTES          @"attributes"
#define TYPE                @"type"
#define RECORDS             @"records"
#define COUNT_TEST_ACCOUNTS 10

@interface SFSmartSyncSyncManager()
- (NSString*) addFilterForReSync:(NSString*)query maxTimeStamp:(long long)maxTimeStamp;
@end

@interface SyncManagerTests : XCTestCase
{
    SFUserAccount *currentUser;
    SFSmartSyncSyncManager *syncManager;
    SFSmartStore *store;
    NSMutableDictionary* idToNames;
}
@end

static NSException *authException = nil;

@implementation SyncManagerTests

#pragma mark - setUp/tearDown

+ (void)setUp
{
    @try {
        [SFLogger setLogLevel:SFLogLevelDebug];
        [TestSetupUtils populateAuthCredentialsFromConfigFileForClass:[self class]];
        [TestSetupUtils synchronousAuthRefresh];
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
 * Test serialization and deserialization of SFSyncServerTargets to and from NSDictionary objects.
 */
- (void)testSyncServerTargetSerialization {
    
    // Default server target should be the base class.
    NSDictionary *defaultDict = @{ };
    SFSyncServerTarget *defaultServerTarget = [SFSyncServerTarget newFromDict:defaultDict];
    XCTAssertEqual([defaultServerTarget class], [SFSyncServerTarget class], @"Default class should be SFSyncServerTarget");
    XCTAssertEqual(defaultServerTarget.targetType, SFSyncServerTargetTypeRestStandard, @"Sync server target type is incorrect.");
    
    // Explicit rest server target type creates base class.
    NSDictionary *restDict = @{ kSFSyncTargetTypeKey: @"rest" };
    SFSyncServerTarget *restServerTarget = [SFSyncServerTarget newFromDict:restDict];
    XCTAssertEqual([restServerTarget class], [SFSyncServerTarget class], @"Rest class should be SFSyncServerTarget");
    XCTAssertEqual(restServerTarget.targetType, SFSyncServerTargetTypeRestStandard, @"Sync server target type is incorrect.");
    
    // Custom server target
    TestSyncServerTarget *customTarget = [[TestSyncServerTarget alloc] init];
    NSDictionary *customDict = [customTarget asDict];
    XCTAssertEqualObjects(customDict[kSFSyncTargetTypeKey], @"custom", @"Should be a custom server target.");
    XCTAssertEqualObjects(customDict[kSFSyncTargetiOSImplKey], NSStringFromClass([TestSyncServerTarget class]), @"Custom class is incorrect.");
    SFSyncServerTarget *customTargetFromDict = [SFSyncServerTarget newFromDict:customDict];
    XCTAssertEqual([customTargetFromDict class], [TestSyncServerTarget class], @"Custom class is incorrect.");
    XCTAssertEqual(customTargetFromDict.targetType, SFSyncServerTargetTypeCustom, @"Target type should be custom.");
}

- (void)testDefaultSyncServerTarget {
    SFSyncOptions *options = [SFSyncOptions newSyncOptionsForSyncUp:@[ACCOUNT_NAME] mergeMode:SFSyncStateMergeModeOverwrite];
    SFSyncState *syncUpState = [SFSyncState newSyncUpWithOptions:options soupName:ACCOUNTS_SOUP store:store];
    XCTAssertEqual([syncUpState.serverTarget class], [SFSyncServerTarget class], @"Default sync up target should be SFSyncServerTarget");
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
    [self checkDb:idToNames];
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
    NSDictionary* idToNamesLocallyUpdated = [self makeSomeLocalChanges];
    
    // sync down again with MergeMode.LEAVE_IF_CHANGED
    [self trySyncDown:SFSyncStateMergeModeLeaveIfChanged];
    
    // Check db
    NSMutableDictionary* idToNamesExpected = [[NSMutableDictionary alloc] initWithDictionary:idToNames];
    [idToNamesExpected setDictionary:idToNamesLocallyUpdated];
    [self checkDb:idToNamesExpected];
    
    // sync down again with MergeMode.OVERWRITE
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Check db
    [self checkDb:idToNames];
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
    SFSyncTarget* target = sync.target;
    SFSyncOptions* options = sync.options;
    long long maxTimeStamp = sync.maxTimeStamp;
    XCTAssertTrue(maxTimeStamp > 0);
    
    // Make some remote changes
    [NSThread sleepForTimeInterval:1.0f];
    NSMutableDictionary* idToNamesUpdated = [NSMutableDictionary new];
    NSArray* allIds = [idToNames allKeys];
    NSArray* ids = @[ allIds[0], allIds[2] ];
    for (NSString* accountId in ids) {
        idToNamesUpdated[accountId] = [NSString stringWithFormat:@"%@_updated", idToNames[accountId]];
    }
    [self updateAccountsOnServer:idToNamesUpdated];
    
    
    // Call reSync
    SFSyncUpdateCallbackQueue* queue = [[SFSyncUpdateCallbackQueue alloc] init];
    [queue runReSync:syncId syncManager:syncManager];
    
    // Check status updates
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:-1]; // we get an update right away before getting records to sync
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:idToNamesUpdated.count];
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusDone expectedProgress:100 expectedTotalSize:idToNamesUpdated.count];
    
    // Check db
    [self checkDb:idToNamesUpdated];
    
    // Check sync time stamp
    XCTAssertTrue([syncManager getSyncStatus:syncId].maxTimeStamp > maxTimeStamp);
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
    NSDictionary* idToNamesLocallyUpdated = [self makeSomeLocalChanges];
    
    // Sync up
    [self trySyncUp:3 mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Check that db doesn't show entries as locally modified anymore
    NSArray* ids = [idToNamesLocallyUpdated allKeys];
    NSString* idsClause = [self buildInClause:ids];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        XCTAssertEqual(@NO, account[kSyncManagerLocal]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyDeleted]);
    }
    
    // Check server
    NSString* soql = [NSString stringWithFormat:@"SELECT Id, Name FROM Account WHERE Id IN %@", idsClause];
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql];
    NSArray* records = [self sendSyncRequest:request][RECORDS];
    for (NSDictionary* record in records) {
        XCTAssertEqualObjects(idToNamesLocallyUpdated[record[ACCOUNT_ID]], record[ACCOUNT_NAME]);
    }
}

- (void)testCustomSyncUpWithLocallyUpdatedRecords
{
    // Create test data.
    [self createTestData];
    
    // Sync down data to local store.
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Make some local changes.
    NSDictionary* idToNamesLocallyUpdated = [self makeSomeLocalChanges];
    
    // Sync up with custom sync server target.
    SFSyncServerTarget *customServerTarget = [[TestSyncServerTarget alloc] initWithRemoteModDateCompare:TestSyncServerTargetRemoteModDateSameAsLocal
                                                                                     sendRemoteModError:NO
                                                                                        sendSyncUpError:NO];
    [self trySyncUp:3 actualChanges:3 serverTarget:customServerTarget mergeMode:SFSyncStateMergeModeOverwrite completionStatus:SFSyncStateStatusDone];
    
    // Check that db doesn't show entries as locally modified anymore
    NSArray* ids = [idToNamesLocallyUpdated allKeys];
    NSString* idsClause = [self buildInClause:ids];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        XCTAssertEqual(@NO, account[kSyncManagerLocal]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyDeleted]);
    }
}

/**
 * Sync down the test accounts, modify a few, sync up with merge mode LEAVE_IF_CHANGED, check smartstore and server afterwards
 */
- (void)testSyncUpWithLocallyUpdatedRecordsWithoutOverwrite
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeLeaveIfChanged];
    
    // Make some local change
    NSDictionary* idToNamesLocallyUpdated = [self makeSomeLocalChanges];
    NSArray* ids = [idToNamesLocallyUpdated allKeys];

    // Update entries on server
    NSMutableDictionary* idToNamesRemotelyUpdated = [NSMutableDictionary new];
    for (NSString* accountId in ids) {
        idToNamesRemotelyUpdated[accountId] = [NSString stringWithFormat:@"%@_updated_again", idToNames[accountId]];
    }
    [self updateAccountsOnServer:idToNamesRemotelyUpdated];
    
    // Sync up
    [self trySyncUp:3 mergeMode:SFSyncStateMergeModeLeaveIfChanged];
    
    // Check that db doesn't show entries as locally modified anymore
    NSString* idsClause = [self buildInClause:ids];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        XCTAssertEqual(@YES, account[kSyncManagerLocal]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqual(@YES, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyDeleted]);
    }

    // Check server
    NSString* soql = [NSString stringWithFormat:@"SELECT Id, Name FROM Account WHERE Id IN %@", idsClause];
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql];
    NSArray* records = [self sendSyncRequest:request][RECORDS];
    for (NSDictionary* record in records) {
        XCTAssertNotEqualObjects(idToNamesLocallyUpdated[record[ACCOUNT_ID]], record[ACCOUNT_NAME]);
    }
}

- (void)testCustomSyncUpWithLocallyUpdatedRecordsWithoutOverwrite
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeLeaveIfChanged];
    
    // Make some local change
    NSDictionary* idToNamesLocallyUpdated = [self makeSomeLocalChanges];
    NSArray* ids = [idToNamesLocallyUpdated allKeys];
    
    // Sync up
    SFSyncServerTarget *customServerTarget = [[TestSyncServerTarget alloc] initWithRemoteModDateCompare:TestSyncServerTargetRemoteModDateGreaterThanLocal
                                                                                     sendRemoteModError:NO
                                                                                        sendSyncUpError:NO];
    [self trySyncUp:3 actualChanges:3 serverTarget:customServerTarget mergeMode:SFSyncStateMergeModeLeaveIfChanged completionStatus:SFSyncStateStatusDone];
    
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
 * Create accounts locally, sync up, check smartstore and server afterwards
 */
- (void)testSyncUpWithLocallyCreatedRecords
{
    // Create test data
    [self createTestData];
    
    // Create a few entries locally
    NSArray* names = @[ [self createAccountName], [self createAccountName], [self createAccountName]];
    [self createAccountsLocally:names];
   
    // Sync up
    [self trySyncUp:3 mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Check that db doesn't show entries as locally created anymore and that they use sfdc id
    NSString* namesClause = [self buildInClause:names];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Name} IN %@", namesClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:names.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    NSMutableDictionary* idToNamesCreated = [NSMutableDictionary new];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        NSString* accountId = account[ACCOUNT_ID];
        idToNamesCreated[accountId] = account[ACCOUNT_NAME];
        XCTAssertEqual(@NO, account[kSyncManagerLocal]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyDeleted]);
        XCTAssertFalse([accountId hasPrefix:@"local_"]);
    }
    
    // Check server
    NSString* soql = [NSString stringWithFormat:@"SELECT Id, Name FROM Account WHERE Name IN %@", namesClause];
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql];
    NSArray* records = [self sendSyncRequest:request][RECORDS];
    for (NSDictionary* record in records) {
        XCTAssertEqualObjects(idToNamesCreated[record[ACCOUNT_ID]], record[ACCOUNT_NAME]);
    }
    
    // Adding to idToNames so that they get deleted in tearDown
    [idToNames setDictionary:idToNamesCreated];
}

- (void)testCustomSyncUpWithLocallyCreatedRecords
{
    // Create test data
    [self createTestData];
    
    // Create a few entries locally
    NSArray* names = @[ [self createAccountName], [self createAccountName], [self createAccountName]];
    [self createAccountsLocally:names];
    
    // Sync up
    SFSyncServerTarget *customServerTarget = [[TestSyncServerTarget alloc] initWithRemoteModDateCompare:TestSyncServerTargetRemoteModDateSameAsLocal
                                                                                     sendRemoteModError:NO
                                                                                        sendSyncUpError:NO];
    [self trySyncUp:3 actualChanges:3 serverTarget:customServerTarget mergeMode:SFSyncStateMergeModeOverwrite completionStatus:SFSyncStateStatusDone];
    
    // Check that db doesn't show entries as locally created anymore and that they use returned id
    NSString* namesClause = [self buildInClause:names];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Name} IN %@", namesClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:names.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        NSString* accountId = account[ACCOUNT_ID];
        XCTAssertEqual(@NO, account[kSyncManagerLocal]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyDeleted]);
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
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Delete a few entries locally
    NSArray* allIds = [idToNames allKeys];
    NSArray* idsLocallyDeleted = @[ allIds[0], allIds[1], allIds[2] ];
    [self deleteAccountsLocally:idsLocallyDeleted];
    
    // Sync up
    [self trySyncUp:3 mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Check that db doesn't show entries as locally modified anymore
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

-(void) testCustomSyncUpWithLocallyDeletedRecords
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeOverwrite];
    
    // Delete a few entries locally
    NSArray* allIds = [idToNames allKeys];
    NSArray* idsLocallyDeleted = @[ allIds[0], allIds[1], allIds[2] ];
    [self deleteAccountsLocally:idsLocallyDeleted];
    
    // Sync up
    SFSyncServerTarget *customServerTarget = [[TestSyncServerTarget alloc] initWithRemoteModDateCompare:TestSyncServerTargetRemoteModDateSameAsLocal
                                                                                     sendRemoteModError:NO
                                                                                        sendSyncUpError:NO];
    [self trySyncUp:3 actualChanges:3 serverTarget:customServerTarget mergeMode:SFSyncStateMergeModeOverwrite completionStatus:SFSyncStateStatusDone];
    
    // Check that db doesn't show entries as locally modified anymore
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
    NSArray* allIds = [idToNames allKeys];
    NSArray* idsLocallyDeleted = @[ allIds[0], allIds[1], allIds[2] ];
    [self deleteAccountsLocally:idsLocallyDeleted];

    // Update entries on server
    NSMutableDictionary* idToNamesRemotelyUpdated = [NSMutableDictionary new];
    NSArray* ids = @[ idsLocallyDeleted[0], idsLocallyDeleted[1], idsLocallyDeleted[2] ];
    for (NSString* accountId in ids) {
        idToNamesRemotelyUpdated[accountId] = [NSString stringWithFormat:@"%@_updated_again", idToNames[accountId]];
    }
    [self updateAccountsOnServer:idToNamesRemotelyUpdated];

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
        XCTAssertEqual(@YES, account[kSyncManagerLocal]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqual(@YES, account[kSyncManagerLocallyDeleted]);
    }

    // Check server
    NSString* soql = [NSString stringWithFormat:@"SELECT Id, Name FROM Account WHERE Id IN %@", idsClause];
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql];
    NSArray* records = [self sendSyncRequest:request][RECORDS];
    XCTAssertEqual(3, records.count);
}

-(void) testCustomSyncUpWithLocallyDeletedRecordsWithoutOverwrite
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeLeaveIfChanged];
    
    // Delete a few entries locally
    NSArray* allIds = [idToNames allKeys];
    NSArray* idsLocallyDeleted = @[ allIds[0], allIds[1], allIds[2] ];
    [self deleteAccountsLocally:idsLocallyDeleted];
    
    // Sync up
    SFSyncServerTarget *customServerTarget = [[TestSyncServerTarget alloc] initWithRemoteModDateCompare:TestSyncServerTargetRemoteModDateGreaterThanLocal
                                                                                     sendRemoteModError:NO
                                                                                        sendSyncUpError:NO];
    [self trySyncUp:3 actualChanges:3 serverTarget:customServerTarget mergeMode:SFSyncStateMergeModeLeaveIfChanged completionStatus:SFSyncStateStatusDone];
    
    // Check that db still shows entries as locally deleted
    NSString* idsClause = [self buildInClause:idsLocallyDeleted];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN %@", idsClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:idsLocallyDeleted.count];
    NSArray* rows = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    XCTAssertEqual(3, rows.count);
    for (NSArray* row in rows) {
        NSDictionary* account = row[0];
        XCTAssertEqual(@YES, account[kSyncManagerLocal]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyCreated]);
        XCTAssertEqual(@NO, account[kSyncManagerLocallyUpdated]);
        XCTAssertEqual(@YES, account[kSyncManagerLocallyDeleted]);
    }
}

/**
 * Tests the flow for a failure determining modification date.
 */
- (void)testCustomSyncUpWithFetchModificationDateFailure
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeLeaveIfChanged];
    
    // Make some local change
    [self makeSomeLocalChanges];
    
    // Sync up
    SFSyncServerTarget *customServerTarget = [[TestSyncServerTarget alloc] initWithRemoteModDateCompare:TestSyncServerTargetRemoteModDateGreaterThanLocal
                                                                                     sendRemoteModError:YES
                                                                                        sendSyncUpError:NO];
    [self trySyncUp:3 actualChanges:1 serverTarget:customServerTarget mergeMode:SFSyncStateMergeModeLeaveIfChanged completionStatus:SFSyncStateStatusFailed];
}

/**
 * Tests the flow for a failure syncing up the data.
 */
- (void)testCustomSyncUpWithSyncUpFailure
{
    // Create test data
    [self createTestData];
    
    // first sync down
    [self trySyncDown:SFSyncStateMergeModeLeaveIfChanged];
    
    // Make some local change
    [self makeSomeLocalChanges];
    
    // Sync up
    SFSyncServerTarget *customServerTarget = [[TestSyncServerTarget alloc] initWithRemoteModDateCompare:TestSyncServerTargetRemoteModDateSameAsLocal
                                                                                     sendRemoteModError:NO
                                                                                        sendSyncUpError:YES];
    [self trySyncUp:3 actualChanges:1 serverTarget:customServerTarget mergeMode:SFSyncStateMergeModeOverwrite completionStatus:SFSyncStateStatusFailed];
}

/**
 * Test addFilterForReSync with various queries
 */
- (void) testAddFilterForResync
{
    NSDateFormatter* isoDateFormatter = [NSDateFormatter new];
    isoDateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
    NSString* dateStr = @"2015-02-05T13:12:03.956-0800";
    NSDate* date = [isoDateFormatter dateFromString:dateStr];
    long long dateLong = (long long)([date timeIntervalSince1970] * 1000.0);

    // Original queries
    NSString* originalBasicQuery = @"select Id from Account";
    NSString* originalLimitQuery = @"select Id from Account limit 100";
    NSString* originalNameQuery = @"select Id from Account where Name = 'John'";
    NSString* originalNameLimitQuery = @"select Id from Account where Name = 'John' limit 100";
    NSString* originalBasicQueryUpper = @"SELECT Id FROM Account";
    NSString* originalLimitQueryUpper = @"SELECT Id FROM Account LIMIT 100";
    NSString* originalNameQueryUpper = @"SELECT Id FROM Account WHERE Name = 'John'";
    NSString* originalNameLimitQueryUpper = @"SELECT Id FROM Account WHERE Name = 'John' LIMIT 100";

    // Expected queries
    NSString* basicQuery = [NSString stringWithFormat:@"select Id from Account where LastModifiedDate > %@", dateStr];
    NSString* limitQuery = [NSString stringWithFormat:@"select Id from Account where LastModifiedDate > %@ limit 100", dateStr];
    NSString* nameQuery = [NSString stringWithFormat:@"select Id from Account where LastModifiedDate > %@ and Name = 'John'", dateStr];
    NSString* nameLimitQuery = [NSString stringWithFormat:@"select Id from Account where LastModifiedDate > %@ and Name = 'John' limit 100", dateStr];
    NSString* basicQueryUpper = [NSString stringWithFormat:@"SELECT Id FROM Account where LastModifiedDate > %@", dateStr];
    NSString* limitQueryUpper = [NSString stringWithFormat:@"SELECT Id FROM Account where LastModifiedDate > %@ LIMIT 100", dateStr];
    NSString* nameQueryUpper = [NSString stringWithFormat:@"SELECT Id FROM Account WHERE LastModifiedDate > %@ and Name = 'John'", dateStr];
    NSString* nameLimitQueryUpper = [NSString stringWithFormat:@"SELECT Id FROM Account WHERE LastModifiedDate > %@ and Name = 'John' LIMIT 100", dateStr];

    // Tests
    XCTAssertEqualObjects(basicQuery, [SFSoqlSyncTarget addFilterForReSync:originalBasicQuery maxTimeStamp:dateLong]);
    XCTAssertEqualObjects(limitQuery, [SFSoqlSyncTarget addFilterForReSync:originalLimitQuery maxTimeStamp:dateLong]);
    XCTAssertEqualObjects(nameQuery, [SFSoqlSyncTarget addFilterForReSync:originalNameQuery maxTimeStamp:dateLong]);
    XCTAssertEqualObjects(nameLimitQuery, [SFSoqlSyncTarget addFilterForReSync:originalNameLimitQuery maxTimeStamp:dateLong]);
    XCTAssertEqualObjects(basicQueryUpper, [SFSoqlSyncTarget addFilterForReSync:originalBasicQueryUpper maxTimeStamp:dateLong]);
    XCTAssertEqualObjects(limitQueryUpper, [SFSoqlSyncTarget addFilterForReSync:originalLimitQueryUpper maxTimeStamp:dateLong]);
    XCTAssertEqualObjects(nameQueryUpper, [SFSoqlSyncTarget addFilterForReSync:originalNameQueryUpper maxTimeStamp:dateLong]);
    XCTAssertEqualObjects(nameLimitQueryUpper, [SFSoqlSyncTarget addFilterForReSync:originalNameLimitQueryUpper maxTimeStamp:dateLong]);
}


#pragma mark - helper methods

- (NSInteger)trySyncDown:(SFSyncStateMergeMode)mergeMode
{
    // Ids clause
    NSString* idsClause = [self buildInClause:[idToNames allKeys]];
    
    // Create sync
    NSString* soql = [@[@"SELECT Id, Name, LastModifiedDate FROM Account WHERE Id IN ", idsClause] componentsJoinedByString:@""];
    SFSoqlSyncTarget* target = [SFSoqlSyncTarget newSyncTarget:soql];
    SFSyncOptions* options = [SFSyncOptions newSyncOptionsForSyncDown:mergeMode];
    SFSyncState* sync = [SFSyncState newSyncDownWithOptions:options target:target soupName:ACCOUNTS_SOUP store:store];
    NSInteger syncId = sync.syncId;
    [self checkStatus:sync expectedType:SFSyncStateSyncTypeDown expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusNew expectedProgress:0 expectedTotalSize:-1];

    // Run sync
    SFSyncUpdateCallbackQueue* queue = [[SFSyncUpdateCallbackQueue alloc] init];
    [queue runSync:sync syncManager:syncManager];
    
    // Check status updates
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:-1]; // we get an update right away before getting records to sync
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:idToNames.count];
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusDone expectedProgress:100 expectedTotalSize:idToNames.count];

     return syncId;
}

- (void)checkDb:(NSDictionary*)dict
{
    // Ids clause
    NSString* idsClause = [self buildInClause:[dict allKeys]];

    // Query
    NSString* smartSql = [@[@"SELECT {accounts:Id}, {accounts:Name} FROM {accounts} WHERE {accounts:Id} IN ", idsClause] componentsJoinedByString:@""];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:dict.count];
    NSArray* accountsFromDb = [store queryWithQuerySpec:query pageIndex:0 error:nil];
    NSMutableDictionary* idToNamesFromdb = [NSMutableDictionary new];
    for (NSArray* row in accountsFromDb) {
        idToNamesFromdb[row[0]] = row[1];
    }
    
    // Compare
    XCTAssertEqual(dict.count, idToNamesFromdb.count);
    for (NSString* accountId in dict) {
        XCTAssertEqualObjects(dict[accountId], idToNamesFromdb[accountId]);
    }
}

- (void)trySyncUp:(NSInteger)numberChanges mergeMode:(SFSyncStateMergeMode)mergeMode {
    SFSyncServerTarget *defaultTarget = [SFSyncServerTarget newFromDict:@{ }];
    [self trySyncUp:numberChanges actualChanges:numberChanges serverTarget:defaultTarget mergeMode:mergeMode completionStatus:SFSyncStateStatusDone];
}

- (void) trySyncUp:(NSInteger)numberChanges
     actualChanges:(NSInteger)actualNumberChanges
      serverTarget:(SFSyncServerTarget *)serverTarget
         mergeMode:(SFSyncStateMergeMode)mergeMode
  completionStatus:(SFSyncStateStatus)completionStatus
{
    // Create sync
    SFSyncOptions* options = [SFSyncOptions newSyncOptionsForSyncUp:@[ACCOUNT_NAME] mergeMode:mergeMode];
    SFSyncState *sync = [SFSyncState newSyncUpWithOptions:options target:serverTarget soupName:ACCOUNTS_SOUP store:store];
    NSInteger syncId = sync.syncId;
    [self checkStatus:sync expectedType:SFSyncStateSyncTypeUp expectedId:syncId expectedTarget:nil expectedOptions:options expectedStatus:SFSyncStateStatusNew expectedProgress:0 expectedTotalSize:-1];
    
    // Run sync
    SFSyncUpdateCallbackQueue* queue = [[SFSyncUpdateCallbackQueue alloc] init];
    [queue runSync:sync syncManager:syncManager];
    
    // Check status updates
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeUp expectedId:syncId expectedTarget:nil expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:-1]; // we get an update right away before getting records to sync
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeUp expectedId:syncId expectedTarget:nil expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:numberChanges];
    for (int i=1; i<actualNumberChanges; i++) {
        [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeUp expectedId:syncId expectedTarget:nil expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:i*100/numberChanges expectedTotalSize:numberChanges];
    }
    
    if (completionStatus == SFSyncStateStatusDone) {
        [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeUp expectedId:syncId expectedTarget:nil expectedOptions:options expectedStatus:completionStatus expectedProgress:100 expectedTotalSize:numberChanges];
    } else if (completionStatus == SFSyncStateStatusFailed) {
        NSInteger expectedProgress = (actualNumberChanges - 1) * 100 / numberChanges;
        [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeUp expectedId:syncId expectedTarget:nil expectedOptions:options expectedStatus:completionStatus expectedProgress:expectedProgress expectedTotalSize:numberChanges];
    } else {
        XCTFail(@"completionStatus value '%d' not currently supported.", completionStatus);
    }
}

- (void)checkStatus:(SFSyncState*)sync
       expectedType:(SFSyncStateSyncType)expectedType
         expectedId:(NSInteger)expectedId
     expectedTarget:(SFSyncTarget*)expectedTarget
    expectedOptions:(SFSyncOptions*)expectedOptions
     expectedStatus:(SFSyncStateStatus)expectedStatus
   expectedProgress:(NSInteger)expectedProgress
  expectedTotalSize:(NSInteger)expectedTotalSize
{
    XCTAssertNotNil(sync);
    if (!sync)
        return;
    
    XCTAssertEqual(expectedType, sync.type);
    XCTAssertEqual(expectedId, sync.syncId);
    XCTAssertEqual(expectedStatus, sync.status);
    XCTAssertEqual(expectedProgress, sync.progress);
    XCTAssertEqual(expectedTotalSize, sync.totalSize);
    
    if (expectedTarget) {
        XCTAssertNotNil(sync.target);
        XCTAssertEqual(expectedTarget.queryType, sync.target.queryType);
        if (expectedTarget.queryType == SFSyncTargetQueryTypeSoql) {
            XCTAssertTrue([sync.target isKindOfClass:[SFSoqlSyncTarget class]]);
            XCTAssertEqualObjects(((SFSoqlSyncTarget*)expectedTarget).query, ((SFSoqlSyncTarget*)sync.target).query);
        }
        else if (expectedTarget.queryType == SFSyncTargetQueryTypeSosl) {
            XCTAssertTrue([sync.target isKindOfClass:[SFSoslSyncTarget class]]);
            XCTAssertEqualObjects(((SFSoslSyncTarget*)expectedTarget).query, ((SFSoslSyncTarget*)sync.target).query);
        }
        else if (expectedTarget.queryType == SFSyncTargetQueryTypeMru) {
            XCTAssertTrue([sync.target isKindOfClass:[SFMruSyncTarget class]]);
            XCTAssertEqualObjects(((SFMruSyncTarget*)expectedTarget).objectType, ((SFMruSyncTarget*)sync.target).objectType);
            XCTAssertEqualObjects(((SFMruSyncTarget*)expectedTarget).fieldlist, ((SFMruSyncTarget*)sync.target).fieldlist);
        }
        else if (expectedTarget.queryType == SFSyncTargetQueryTypeCustom) {
            XCTAssertTrue([sync.target isKindOfClass:[SFSyncTarget class]]);
        }
    }
    else {
        XCTAssertNil(sync.target);
    }
    
    if (expectedOptions) {
        XCTAssertNotNil(sync.options);
        XCTAssertEqual(expectedOptions.mergeMode, sync.options.mergeMode);
        XCTAssertEqualObjects(expectedOptions.fieldlist, sync.options.fieldlist);
    }
    else {
        XCTAssertNil(sync.options);
    }
}

- (void)createTestData
{
    [self createAccountsSoup];
    idToNames = [[NSMutableDictionary alloc] initWithDictionary:[self createTestAccountsOnServer:COUNT_TEST_ACCOUNTS]];
}

- (void)deleteTestData
{
    [self deleteTestAccountsOnServer:idToNames];
    [self dropAccountsSoup];
    [self deleteSyncs];
}

- (void)createAccountsSoup
{
    NSArray* indexSpecs = @[
                            [[SFSoupIndex alloc] initWithPath:ACCOUNT_ID indexType:kSoupIndexTypeString columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:ACCOUNT_NAME indexType:kSoupIndexTypeString columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:kSyncManagerLocal indexType:kSoupIndexTypeString columnName:nil]
                            ];
    [store registerSoup:ACCOUNTS_SOUP withIndexSpecs:indexSpecs];
}


- (void)dropAccountsSoup
{
    [store removeSoup:ACCOUNTS_SOUP];
}

- (NSDictionary*)createTestAccountsOnServer:(NSUInteger)count
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    for (NSUInteger i=0; i<count; i++) {
        // Request
        NSString* accountName = [self createAccountName];
        NSDictionary* fields = @{ACCOUNT_NAME: accountName};
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:ACCOUNT_TYPE fields:fields];
        // Response
        NSString* accountId = [self sendSyncRequest:request][@"id"];
        dict[accountId] = accountName;
    }
    return dict;
}

- (void)deleteTestAccountsOnServer:(NSDictionary*)dict
{
    for (NSString* accountId in dict) {
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:ACCOUNT_TYPE objectId:accountId];
        [self sendSyncRequest:request ignoreNotFound:YES];
    }
}

- (NSString*) createAccountName
{
    return [NSString stringWithFormat:@"SyncManagerTest%08d", arc4random_uniform(100000000)];
}

- (NSString*) createLocalId
{
    return [NSString stringWithFormat:@"local_%08d", arc4random_uniform(100000000)];
}

- (void) deleteSyncs
{
    [store clearSoup:ACCOUNTS_SOUP];
}

- (NSDictionary*) makeSomeLocalChanges
{
    NSMutableDictionary* idToNamesLocallyUpdated = [NSMutableDictionary new];
    NSArray* allIds = [idToNames allKeys];
    NSArray* ids = @[ allIds[0], allIds[1], allIds[2] ];
    for (NSString* accountId in ids) {
        idToNamesLocallyUpdated[accountId] = [NSString stringWithFormat:@"%@_updated", idToNames[accountId]];
    }
    [self updateAccountsLocally:idToNamesLocallyUpdated];
    return idToNamesLocallyUpdated;
}

- (void) createAccountsLocally:(NSArray*)names
{
    NSMutableArray* createdAccounts = [NSMutableArray new];
    NSMutableDictionary* attributes = [NSMutableDictionary new];
    attributes[TYPE] = ACCOUNT_TYPE;
    
    for (NSString* name in names) {
        NSMutableDictionary* account = [NSMutableDictionary new];
        account[ACCOUNT_ID] = [self createLocalId];
        account[ACCOUNT_NAME] = name;
        account[ATTRIBUTES] = attributes;
        account[kSyncManagerLocal] = @YES;
        account[kSyncManagerLocallyCreated] = @YES;
        account[kSyncManagerLocallyDeleted] = @NO;
        account[kSyncManagerLocallyUpdated] = @NO;
        [createdAccounts addObject:account];
    }
    [store upsertEntries:createdAccounts toSoup:ACCOUNTS_SOUP];
}

- (void)updateAccountsLocally:(NSDictionary*)idToNamesLocallyUpdated
{
    NSMutableArray* updatedAccounts = [NSMutableArray new];
    for (NSString* accountId in idToNamesLocallyUpdated) {
        NSString* updatedName = idToNamesLocallyUpdated[accountId];
        SFQuerySpec* query = [SFQuerySpec newExactQuerySpec:ACCOUNTS_SOUP withPath:ACCOUNT_ID withMatchKey:accountId withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
        NSArray* results = [store queryWithQuerySpec:query pageIndex:0 error:nil];
        NSMutableDictionary* account = [[NSMutableDictionary alloc] initWithDictionary:results[0]];
        account[ACCOUNT_NAME] = updatedName;
        account[kSyncManagerLocal] = @YES;
        account[kSyncManagerLocallyCreated] = @NO;
        account[kSyncManagerLocallyDeleted] = @NO;
        account[kSyncManagerLocallyUpdated] = @YES;
        [updatedAccounts addObject:account];
    }
    [store upsertEntries:updatedAccounts toSoup:ACCOUNTS_SOUP];
}

-(void) deleteAccountsLocally:(NSArray*)idsLocallyDeleted
{
    NSMutableArray* deletedAccounts = [NSMutableArray new];
    for (NSString* accountId in idsLocallyDeleted) {
        SFQuerySpec* query = [SFQuerySpec newExactQuerySpec:ACCOUNTS_SOUP withPath:ACCOUNT_ID withMatchKey:accountId withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
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

-(void)updateAccountsOnServer:(NSDictionary*)idToNamesUpdated
{
    for (NSString* accountId in idToNamesUpdated) {
        // Request
        NSString* updatedName = idToNamesUpdated[accountId];
        NSDictionary* fields = @{ACCOUNT_NAME: updatedName};
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:ACCOUNT_TYPE objectId:accountId fields:fields];
        // Response
        [self sendSyncRequest:request];
    }
}

- (NSString*) buildInClause:(NSArray*)values {
    return [NSString stringWithFormat:@"('%@')", [values componentsJoinedByString:@"', '"]];
}


- (NSDictionary*)sendSyncRequest:(SFRestRequest*)request {
    return [self sendSyncRequest:request ignoreNotFound:NO];
}

- (NSDictionary*)sendSyncRequest:(SFRestRequest*)request ignoreNotFound:(BOOL)ignoreNotFound
{
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
