/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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
#import <SalesforceSDKCommon/SFJsonUtils.h>

#define COUNT_TEST_ACCOUNTS 10

@interface SyncUpTargetTests : SyncManagerTestCase

@end

@interface SyncUpTargetTests ()
{
    NSMutableDictionary* idToFields; // id -> {Name: xxx, Description: yyy}
}

@end

@implementation SyncUpTargetTests

#pragma mark - setUp/tearDown

- (void)tearDown {
    // Deleting test data
    [self deleteTestData];
    [super tearDown];
}

#pragma mark - tests

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
            XCTAssertNotNil([SFJsonUtils objectFromJSONString:lastError], "Unable to parse error");
        }
        else if ([name isEqualToString:@""]) {
            XCTAssertTrue([lastError containsString:@"Required fields are missing: [Name]"], @"Missing name error expected");
            XCTAssertNotNil([SFJsonUtils objectFromJSONString:lastError], "Unable to parse error");
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
 * Sync up records missing sobject type
 */
- (void) testSyncUpWithNoType {
    [self trySyncUpBadTypeOrNoType:YES];
}


/**
  * Sync up records using bad sobject type
 */
- (void) testSyncUpWithBadType {
    [self trySyncUpBadTypeOrNoType:NO];
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
    SFSyncUpTarget *target = [self buildSyncUpTargetWithCreateFieldlist:nil updateFieldlist:@[NAME]];
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
    SFSyncUpTarget *target = [self buildSyncUpTargetWithCreateFieldlist:@[NAME] updateFieldlist:nil];
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
    SFSyncUpTarget *target = [self buildSyncUpTargetWithCreateFieldlist:@[NAME] updateFieldlist:@[DESCRIPTION]];
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
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql apiVersion:kSFRestDefaultAPIVersion];
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
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql apiVersion:kSFRestDefaultAPIVersion];
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
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql apiVersion:kSFRestDefaultAPIVersion];
    NSArray* records = [self sendSyncRequest:request][RECORDS];
    XCTAssertEqual(0, records.count);
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
 * Create accounts locally but with external id field populated, sync up with external id field name provided, check smartstore and server afterwards
 */
-(void) testSyncUpWithExternalId {
    NSString* externalIdFieldName = @"Id";

    // Create test data
    [self createTestData];
    
    // Creating 3 new names
    NSString* name1 = [self createAccountName];
    NSString* name2 = [self createAccountName];
    NSString* name3 = [self createAccountName];

    // Get id of two records on the server
    NSArray* allIds = [idToFields allKeys];
    NSString* id1 = allIds[0];
    NSString* id2 = allIds[1];

    // Create accounts locally
    NSArray* localAccounts = [self createAccountsLocally:@[ name1, name2, name3 ]];
    NSMutableDictionary* localRecord1 = [NSMutableDictionary dictionaryWithDictionary:localAccounts[0]];
    NSMutableDictionary* localRecord2 = [NSMutableDictionary dictionaryWithDictionary:localAccounts[1]];
    NSMutableDictionary* localRecord3 = [NSMutableDictionary dictionaryWithDictionary:localAccounts[2]];

    // Update Id field to match and existing id for record 1 and 2
    localRecord1[externalIdFieldName] = id1;
    localRecord2[externalIdFieldName] = id2;
    localRecord3[externalIdFieldName] = nil;
    [self.store upsertEntries:@[localRecord1, localRecord2, localRecord3] toSoup:ACCOUNTS_SOUP];

    // Sync up with external id field name - NB: only syncing up name field not description
    SFSyncOptions* options = [SFSyncOptions newSyncOptionsForSyncUp:@[NAME]];
    [self trySyncUp:3 options:options externalIdFieldName:externalIdFieldName];
    
    // Getting id for third record upserted - the one without an valid external id
    NSString* id3 = [[self getIdToFieldsByName:ACCOUNTS_SOUP fieldNames:@[] nameField:NAME names:@[name3]] allKeys][0];
     
    // Expected records locally
    NSMutableDictionary* expectedDbIdFields = [NSMutableDictionary new];
    expectedDbIdFields[id1] = @{NAME: name1, DESCRIPTION:localRecord1[DESCRIPTION]};
    expectedDbIdFields[id2] = @{NAME: name2, DESCRIPTION:localRecord2[DESCRIPTION]};
    expectedDbIdFields[id3] = @{NAME: name3, DESCRIPTION:localRecord3[DESCRIPTION]};

    // Check db
    [self checkDbStateFlags:[expectedDbIdFields allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];
    [self checkDb:expectedDbIdFields soupName:ACCOUNTS_SOUP];

    // Expected records on server
    NSMutableDictionary* expectedServerIdToFields = [NSMutableDictionary new];
    expectedServerIdToFields[id1] = @{NAME: name1, DESCRIPTION:idToFields[id1][DESCRIPTION]};
    expectedServerIdToFields[id2] = @{NAME: name2, DESCRIPTION:idToFields[id2][DESCRIPTION]};
    expectedServerIdToFields[id3] = @{NAME: name3, DESCRIPTION:[NSNull null]};

    // Check server
    [self checkServer:expectedServerIdToFields];

    // Adding to idToFields so that they get deleted in tearDown
    [idToFields addEntriesFromDictionary:expectedServerIdToFields];
}


#pragma mark - helper methods

-(void) trySyncUpBadTypeOrNoType:(BOOL) noType
{
    // Setup soup
    [self createAccountsSoup];
    idToFields = [NSMutableDictionary new];
    
    // Create a few entries locally
    NSArray* namesGoodRecords = @[ [self createAccountName], [self createAccountName], [self createAccountName]];
    NSArray* namesBadRecords = @[ [self createAccountName], [self createAccountName] ];
    
    [self createAccountsLocally:namesGoodRecords];
    [self createAccountsLocally:namesBadRecords mutateBlock:^NSMutableDictionary *(NSMutableDictionary *record) {
        if (noType) {
            [record removeObjectForKey:ATTRIBUTES];
        } else {
            NSMutableDictionary* attributes = [NSMutableDictionary new];
            attributes[TYPE] = @"badType";
            record[ATTRIBUTES] = attributes;
        }
        return record;
    }];
    
    // Sync up
    [self trySyncUp:5 mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Check db for records with good names
    NSDictionary* idToFieldsGoodNames = [self getIdToFieldsByName:ACCOUNTS_SOUP fieldNames:@[NAME, DESCRIPTION] nameField:NAME names:namesGoodRecords];
    [self checkDbStateFlags:[idToFieldsGoodNames allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];
    
    // Check db for records with bad names
    NSDictionary* idToFieldsBadNames = [self getIdToFieldsByName:ACCOUNTS_SOUP fieldNames:@[NAME, DESCRIPTION, kSyncTargetLastError] nameField:NAME names:namesBadRecords];
    [self checkDbStateFlags:[idToFieldsBadNames allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:YES expectedLocallyUpdated:NO expectedLocallyDeleted:NO];
    
    XCTAssertEqual(idToFieldsBadNames.count, namesBadRecords.count);
    for (NSDictionary * fields in [idToFieldsBadNames allValues]) {
        NSString* name = fields[NAME];
        NSString* lastError = fields[kSyncTargetLastError];
        if ([namesBadRecords containsObject:name]) {
            XCTAssertTrue([lastError containsString:@"The requested resource does not exist"], @"Wrong error: %@", lastError);
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


- (void)trySyncUp:(NSInteger)numberChanges mergeMode:(SFSyncStateMergeMode)mergeMode {
    SFSyncOptions* defaultOptions = [SFSyncOptions newSyncOptionsForSyncUp:@[NAME, DESCRIPTION] mergeMode:mergeMode];
    [self trySyncUp:numberChanges options:defaultOptions];
}

- (void)trySyncUp:(NSInteger)numberChanges options:(SFSyncOptions *)options {
    [self trySyncUp:numberChanges options:options externalIdFieldName:nil];
}

- (void)trySyncUp:(NSInteger)numberChanges options:(SFSyncOptions *)options externalIdFieldName:(NSString*)externalIdFieldName {
    SFSyncUpTarget *defaultTarget = [self buildSyncUpTarget];
    defaultTarget.externalIdFieldName = externalIdFieldName;
    [self trySyncUp:numberChanges
      actualChanges:numberChanges
             target:defaultTarget
            options:options
   completionStatus:SFSyncStateStatusDone];
}

- (void) checkServer:(NSDictionary*)idToFieldsToCheck {
    return [self checkServer:idToFieldsToCheck objectType:ACCOUNT_TYPE];
}

- (void) checkServer:(NSDictionary*)idToFieldsToCheck byNames:(NSArray*)names {
    // Ids clause.
    NSString* namesClause = [self buildInClause:names];
    
    // Query
    NSString* soql = [NSString stringWithFormat:@"SELECT Id, Name, Description FROM Account WHERE Name IN %@", namesClause];
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql apiVersion:kSFRestDefaultAPIVersion];
    NSArray* records = [self sendSyncRequest:request][RECORDS];
    XCTAssertEqual(names.count, records.count);
    for (NSDictionary* record in records) {
        NSString* accountId = record[ID];
        for (NSString* fieldName in [idToFieldsToCheck[accountId] allKeys]) {
            XCTAssertEqualObjects(idToFieldsToCheck[accountId][fieldName], record[fieldName]);
        }
    }
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

- (NSDictionary*) makeSomeLocalChanges {
    return [self makeSomeLocalChanges:idToFields soupName:ACCOUNTS_SOUP];
}

- (NSDictionary*) makeSomeRemoteChanges {
    return [self makeSomeRemoteChanges:idToFields objectType:ACCOUNT_TYPE];
}

- (NSInteger)trySyncDown:(SFSyncStateMergeMode)mergeMode {
    
    // IDs clause.
    NSString* idsClause = [self buildInClause:[idToFields allKeys]];
    
    // Creates sync.
    NSString* soql = [@[@"SELECT Id, Name, Description, LastModifiedDate FROM Account WHERE Id IN ", idsClause] componentsJoinedByString:@""];
    SFSoqlSyncDownTarget* target = [SFSoqlSyncDownTarget newSyncTarget:soql];
    return [self trySyncDown:mergeMode target:target soupName:ACCOUNTS_SOUP totalSize:idToFields.count numberFetches:1];
}

#pragma mark - THE methods responsible for building sync up targets used in all the tests

- (SFSyncUpTarget*) buildSyncUpTarget {
    return [self buildSyncUpTargetWithCreateFieldlist:nil updateFieldlist:nil];
}


- (SFSyncUpTarget*) buildSyncUpTargetWithCreateFieldlist:(nullable NSArray*)createFieldlist updateFieldlist:(nullable NSArray*)updateFieldlist {
    return [[SFSyncUpTarget alloc] initWithCreateFieldlist:createFieldlist updateFieldlist:updateFieldlist];
}

@end
