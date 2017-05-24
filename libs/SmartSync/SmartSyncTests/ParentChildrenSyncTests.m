/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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

#import <SmartStore/SFQuerySpec.h>
#import "SyncManagerTestCase.h"
#import "SFParentChildrenSyncDownTarget.h"
#import "SFSmartSyncObjectUtils.h"

//  Useful enum for trySyncUpsWithVariousChanges
typedef NS_ENUM(NSInteger, SFSyncUpChange) {
    NONE,
    UPDATE,
    DELETE
};

@interface SFParentChildrenSyncDownTarget ()

- (NSString *)getSoqlForRemoteIds;
- (NSString*) getDirtyRecordIdsSql:(NSString*)soupName idField:(NSString*)idField;
- (NSString*) getNonDirtyRecordIdsSql:(NSString*)soupName idField:(NSString*)idField;
- (NSOrderedSet *)getNonDirtyRecordIds:(SFSmartSyncSyncManager *)syncManager soupName:(NSString *)soupName idField:(NSString *)idField;

@end

@interface ParentChildrenSyncTests : SyncManagerTestCase {
    NSMutableDictionary* accountIdToFields;          // id -> {Name: xxx, Description: yyy}
    NSMutableDictionary* accountIdContactIdToFields; // account-id -> {contact-id -> {LastName: xxx}, ...}
}

@end

@implementation ParentChildrenSyncTests

#pragma mark - setUp/tearDown

- (void)setUp {
    [super setUp];

    [self createTestData];
}

- (void)tearDown {
    // Deleting test data
    [self deleteTestData];

    [super tearDown];
}

#pragma mark - Tests

/**
 * Test getQuery for SFParentChildrenSyncDownTarget
 */
- (void) testGetQuery {
    SFParentChildrenSyncDownTarget* target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    NSString *expectedQuery = @"select ParentName, Title, ParentId, ParentModifiedDate, (select ChildName, School, ChildId, ChildLastModifiedDate from Children) from Parent where School = 'MIT'";
    XCTAssertEqualObjects([target getQueryToRun], expectedQuery);

    // With default id and modification date fields
    target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    expectedQuery = @"select ParentName, Title, Id, LastModifiedDate, (select ChildName, School, Id, LastModifiedDate from Children) from Parent where School = 'MIT'";
    XCTAssertEqualObjects([target getQueryToRun], expectedQuery);
}

/**
 * Test query for reSync by calling getQuery with maxTimeStamp for SFParentChildrenSyncDownTarget
 */
- (void) testGetQueryWithMaxTimeStamp {
    NSDate* date = [NSDate new];
    long long maxTimeStamp = [date timeIntervalSince1970];
    NSString* dateStr = [SFSmartSyncObjectUtils getIsoStringFromMillis:maxTimeStamp];
    
    SFParentChildrenSyncDownTarget* target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    NSString* expectedQuery = [NSString stringWithFormat:@"select ParentName, Title, ParentId, ParentModifiedDate, (select ChildName, School, ChildId, ChildLastModifiedDate from Children where ChildLastModifiedDate > %@) from Parent where ParentModifiedDate > %@ and School = 'MIT'", dateStr, dateStr];
    XCTAssertEqualObjects([target getQueryToRun:maxTimeStamp], expectedQuery);

    // With default id and modification date fields
    target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    expectedQuery = [NSString stringWithFormat:@"select ParentName, Title, Id, LastModifiedDate, (select ChildName, School, Id, LastModifiedDate from Children where LastModifiedDate > %@) from Parent where LastModifiedDate > %@ and School = 'MIT'", dateStr, dateStr];
    XCTAssertEqualObjects([target getQueryToRun:maxTimeStamp], expectedQuery);
}

/**
 * Test getSoqlForRemoteIds for SFParentChildrenSyncDownTarget
 */
- (void) testGetSoqlForRemoteIds {
    SFParentChildrenSyncDownTarget* target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"ChildParentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    NSString *expectedQuery = @"select ParentId from Parent where School = 'MIT'";
    XCTAssertEqualObjects([target getSoqlForRemoteIds], expectedQuery);

    // With default id and modification date fields
    target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    expectedQuery = @"select Id from Parent where School = 'MIT'";
    XCTAssertEqualObjects([target getSoqlForRemoteIds], expectedQuery);
}

/**
 * Test testGetDirtyRecordIdsSql for SFParentChildrenSyncDownTarget
 */
- (void) testGetDirtyRecordIdsSql {
    SFParentChildrenSyncDownTarget *target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"ChildParentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    NSString *expectedQuery = @"SELECT DISTINCT {parentsSoup:IdForQuery} FROM {parentsSoup} WHERE {parentsSoup:__local__} = 1 OR EXISTS (SELECT {childrenSoup:ChildId} FROM {childrenSoup} WHERE {childrenSoup:ChildParentId} = {parentsSoup:ParentId} AND {childrenSoup:__local__} = 1)";
    XCTAssertEqualObjects([target getDirtyRecordIdsSql:@"parentsSoup" idField:@"IdForQuery"], expectedQuery);
}

/**
 * Test testGetNonDirtyRecordIdsSql for SFParentChildrenSyncDownTarget
 */
- (void) testGetNonDirtyRecordIdsSql {
    SFParentChildrenSyncDownTarget *target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"ChildParentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    NSString *expectedQuery = @"SELECT DISTINCT {parentsSoup:IdForQuery} FROM {parentsSoup} WHERE {parentsSoup:__local__} = 0 AND NOT EXISTS (SELECT {childrenSoup:ChildId} FROM {childrenSoup} WHERE {childrenSoup:ChildParentId} = {parentsSoup:ParentId} AND {childrenSoup:__local__} = 1)";
    XCTAssertEqualObjects([target getNonDirtyRecordIdsSql:@"parentsSoup" idField:@"IdForQuery"], expectedQuery);
}

/**
 * Test getDirtyRecordIds and getNonDirtyRecordIds for SFParentChildrenSyncDownTarget when parent and/or all and/or some children are dirty
 */
- (void) testGetDirtyAndNonDirtyRecordIds {

    NSArray<NSString *> *accountNames = @[
            [self createAccountName],
            [self createAccountName],
            [self createAccountName],
            [self createAccountName],
            [self createAccountName],
            [self createAccountName]
    ];

    NSDictionary* mapAccountToContacts = [self createAccountsAndContactsLocally:accountNames numberOfContactsPerAccount:3];
    NSArray* accounts = [mapAccountToContacts allKeys];

    // All Accounts should be returned
    [self tryGetDirtyRecordIds:accounts];

    // No accounts should be returned
    [self tryGetNonDirtyRecordIds:@[]];


    // Cleaning up:
    // accounts[0]: dirty account and dirty contacts
    // accounts[1]: clean account and dirty contacts
    // accounts[2]: dirty account and clean contacts
    // accounts[3]: clean account and clean contacts
    // accounts[4]: dirty account and some dirty contacts
    // accounts[5]: clean account and some dirty contacts

    [self  cleanRecord:ACCOUNTS_SOUP record:accounts[1]];
    [self  cleanRecords:CONTACTS_SOUP records:mapAccountToContacts[accounts[2]]];
    [self  cleanRecord:ACCOUNTS_SOUP record:accounts[3]];
    [self  cleanRecords:CONTACTS_SOUP records:mapAccountToContacts[accounts[3]]];
    [self  cleanRecord:CONTACTS_SOUP record:mapAccountToContacts[accounts[4]][0]];
    [self  cleanRecord:ACCOUNTS_SOUP record:accounts[5]];
    [self  cleanRecord:CONTACTS_SOUP record:mapAccountToContacts[accounts[5]][0]];

    // Only clean account with clean contacts should not be returned
    [self tryGetDirtyRecordIds:@[accounts[0], accounts[1], accounts[2], accounts[4], accounts[5]]];

    // Only clean account with clean contacts should be returned
    [self tryGetNonDirtyRecordIds:@[accounts[3]]];
}


/**
  * Test saveRecordsToLocalStore
  */
- (void) testSaveRecordsToLocalStore {

    // Putting together an array of accounts with contacts
    // looking like what we would get back from startFetch/continueFetch
    // - not having local fields
    // - not have _soupEntryId field
    NSUInteger numberAccounts = 4;
    NSUInteger numberContactsPerAccount = 3;

    NSDictionary * accountAttributes = @{TYPE: ACCOUNT_TYPE};
    NSDictionary * contactAttributes = @{TYPE: CONTACT_TYPE};

    NSMutableArray* accounts = [NSMutableArray new];
    NSMutableDictionary * mapAccountContacts = [NSMutableDictionary new];

    for (NSUInteger i = 0; i<numberAccounts; i++) {
        NSDictionary * account = @{ID: [self createLocalId], ATTRIBUTES: accountAttributes};
        NSMutableArray * contacts = [NSMutableArray new];
        for (NSUInteger j = 0; j < numberContactsPerAccount; j++) {
            [contacts addObject:@{ID: [self createLocalId], ATTRIBUTES: contactAttributes, ACCOUNT_ID: account[ID]}];
        }
        mapAccountContacts[account] = contacts;
        [accounts addObject:account];
    }

    NSMutableArray * records = [NSMutableArray new];
    for (NSDictionary * account in accounts) {
        NSMutableDictionary * record = [account mutableCopy];
        NSMutableArray * contacts = [NSMutableArray new];
        for (NSDictionary * contact in mapAccountContacts[account]) {
            [contacts addObject:contact];
        }
        record[CONTACT_TYPE_PLURAL] = contacts;
        [records addObject:record];
    }

    // Now calling saveRecordsToLocalStore
    SFParentChildrenSyncDownTarget * target = [self getAccountContactsSyncDownTarget];
    [target saveRecordsToLocalStore:self.syncManager soupName:ACCOUNTS_SOUP records:records];

    // Checking accounts and contacts soup
    // Making sure local fields are populated
    // Making sure accountId and accountLocalId fields are populated on contacts

    NSMutableArray * accountIds = [NSMutableArray new];
    for (NSDictionary * account in accounts) {
        [accountIds addObject:account[ID]];
    }
    NSArray<NSDictionary *> *accountsFromDb = [self queryWithInClause:ACCOUNTS_SOUP fieldName:ID values:accountIds orderBy:SOUP_ENTRY_ID];
    XCTAssertEqual(accountsFromDb.count, accounts.count, @"Wrong number of accounts in db");

    for (NSUInteger i = 0; i < accountsFromDb.count; i++) {
        NSDictionary * account = accounts[i];
        NSDictionary * accountFromDb = accountsFromDb[i];

        XCTAssertEqualObjects(accountFromDb[ID], account[ID]);
        XCTAssertEqualObjects(accountFromDb[ATTRIBUTES][TYPE], ACCOUNT_TYPE);
        XCTAssertEqualObjects(@NO, accountFromDb[kSyncTargetLocal]);
        XCTAssertEqualObjects(@NO, accountFromDb[kSyncTargetLocallyCreated]);
        XCTAssertEqualObjects(@NO, accountFromDb[kSyncTargetLocallyUpdated]);
        XCTAssertEqualObjects(@NO, accountFromDb[kSyncTargetLocallyDeleted]);

        NSArray<NSDictionary *>* contactsFromDb = [self queryWithInClause:CONTACTS_SOUP fieldName:ACCOUNT_ID values:@[account[ID]] orderBy:SOUP_ENTRY_ID];
        NSArray<NSDictionary *>* contacts = mapAccountContacts[account];
        XCTAssertEqual(contactsFromDb.count, contacts.count, @"Wrong number of accounts in db");

        for (NSUInteger j = 0; j < contactsFromDb.count; j++) {
            NSDictionary *  contact = contacts[j];
            NSDictionary *  contactFromDb = contactsFromDb[j];

            XCTAssertEqualObjects(contactFromDb[ID], contact[ID]);
            XCTAssertEqualObjects(contactFromDb[ATTRIBUTES][TYPE], CONTACT_TYPE);
            XCTAssertEqualObjects(@NO, contactFromDb[kSyncTargetLocal]);
            XCTAssertEqualObjects(@NO, contactFromDb[kSyncTargetLocallyCreated]);
            XCTAssertEqualObjects(@NO, contactFromDb[kSyncTargetLocallyUpdated]);
            XCTAssertEqualObjects(@NO, contactFromDb[kSyncTargetLocallyDeleted]);
            XCTAssertEqualObjects(accountFromDb[ID], contactFromDb[ACCOUNT_ID]);
        }
    }
}

/**
 * Test getLatestModificationTimeStamp
 */
- (void) testGetLatestModificationTimeStamp
{
    // Putting together a JSONArray of accounts with contacts
    // looking like what we would get back from startFetch/continueFetch
    // with different fields for last modified time
    NSUInteger numberAccounts = 4;
    NSUInteger numberContactsPerAccount = 3;


    NSMutableArray<NSNumber*> *timeStamps = [NSMutableArray new];
    NSMutableArray<NSString*> *timeStampStrs = [NSMutableArray new];
    for (NSUInteger i = 1; i<5; i++) {
        long long int millis = i*100000000;
        [timeStamps addObject:@(millis)];
        [timeStampStrs addObject:[SFSmartSyncObjectUtils getIsoStringFromMillis:millis]];
    }

    NSDictionary * accountAttributes = @{TYPE: ACCOUNT_TYPE};
    NSDictionary * contactAttributes = @{TYPE: CONTACT_TYPE};

    NSMutableArray* accounts = [NSMutableArray new];
    NSMutableDictionary * mapAccountContacts = [NSMutableDictionary new];

    for (NSUInteger i = 0; i<numberAccounts; i++) {
        NSDictionary * account = @{ID: [self createLocalId],
                ATTRIBUTES: accountAttributes,
                @"AccountTimeStamp1": timeStampStrs[i % timeStampStrs.count],
                @"AccountTimeStamp2": timeStampStrs[0]
        };
        NSMutableArray * contacts = [NSMutableArray new];
        for (NSUInteger j = 0; j < numberContactsPerAccount; j++) {
            [contacts addObject:@{ID: [self createLocalId],
                    ATTRIBUTES: contactAttributes,
                    ACCOUNT_ID: account[ID],
                    @"ContactTimeStamp1": timeStampStrs[1],
                    @"ContactTimeStamp2": timeStampStrs[j % timeStampStrs.count]
            }
            ];
        }
        mapAccountContacts[account] = contacts;
        [accounts addObject:account];
    }

    NSMutableArray * records = [NSMutableArray new];
    for (NSDictionary * account in accounts) {
        NSMutableDictionary * record = [account mutableCopy];
        NSMutableArray * contacts = [NSMutableArray new];
        for (NSDictionary * contact in mapAccountContacts[account]) {
            [contacts addObject:contact];
        }
        record[CONTACT_TYPE_PLURAL] = contacts;
        [records addObject:record];
    }

    // Maximums

    // Get max time stamps based on fields AccountTimeStamp1 / ContactTimeStamp1
    SFParentChildrenSyncDownTarget *target = [self getAccountContactsSyncDownTargetWithAccountModificationDateFieldName:@"AccountTimeStamp1" contactModificationDateFieldName:@"ContactTimeStamp1" parentSoqlFilter:nil];
    XCTAssertEqual(
            [target getLatestModificationTimeStamp:records],
            [timeStamps[3] longLongValue]
    );

    // Get max time stamps based on fields AccountTimeStamp1 / ContactTimeStamp2
    target = [self getAccountContactsSyncDownTargetWithAccountModificationDateFieldName:@"AccountTimeStamp1" contactModificationDateFieldName:@"ContactTimeStamp2" parentSoqlFilter:nil];
    XCTAssertEqual(
            [target getLatestModificationTimeStamp:records],
            [timeStamps[3] longLongValue]
    );

    // Get max time stamps based on fields AccountTimeStamp2 / ContactTimeStamp1
    target = [self getAccountContactsSyncDownTargetWithAccountModificationDateFieldName:@"AccountTimeStamp2" contactModificationDateFieldName:@"ContactTimeStamp1" parentSoqlFilter:nil];
    XCTAssertEqual(
            [target getLatestModificationTimeStamp:records],
            [timeStamps[1] longLongValue]
    );

    // Get max time stamps based on fields AccountTimeStamp2 / ContactTimeStamp2
    target = [self getAccountContactsSyncDownTargetWithAccountModificationDateFieldName:@"AccountTimeStamp2" contactModificationDateFieldName:@"ContactTimeStamp2" parentSoqlFilter:nil];
    XCTAssertEqual(
            [target getLatestModificationTimeStamp:records],
            [timeStamps[2] longLongValue]
    );
}


/**
 * Sync down the test accounts and contacts, check smart store, check status during sync
 */
- (void) testSyncDown {
    NSUInteger numberAccounts = 4;
    NSUInteger numberContactsPerAccount = 3;

    // Creating test accounts and contacts on server
    [self createAccountsAndContactsOnServer:numberAccounts numberContactsPerAccount:numberContactsPerAccount];

    // Sync down
    NSString *parentSoqlFilter = [NSString stringWithFormat:@"%@ IN %@", ID, [self buildInClause:[accountIdToFields allKeys]]];
    SFParentChildrenSyncDownTarget * target = [self getAccountContactsSyncDownTargetWithParentSoqlFilter:parentSoqlFilter];

    [self trySyncDown:SFSyncStateMergeModeOverwrite target:target soupName:ACCOUNTS_SOUP totalSize:numberAccounts numberFetches:1];

    // Check that db was correctly populated
    [self checkDb:accountIdToFields soupName:ACCOUNTS_SOUP];

    for (NSString* accountId in [accountIdToFields allKeys]) {
        [self checkDb:accountIdContactIdToFields[accountId] soupName:CONTACTS_SOUP];
    }
}

/**
 * Sync down the test accounts that do not have children contacts, check smart store, check status during sync
 */
- (void) testSyncDownNoChildren {

    NSUInteger numberAccounts = 4;

    // Creating test accounts on server
    accountIdToFields = [[self createAccountsOnServer:numberAccounts] mutableCopy];

    // Sync down
    NSString *parentSoqlFilter = [NSString stringWithFormat:@"%@ IN %@", ID, [self buildInClause:[accountIdToFields allKeys]]];
    SFParentChildrenSyncDownTarget * target = [self getAccountContactsSyncDownTargetWithParentSoqlFilter:parentSoqlFilter];

    [self trySyncDown:SFSyncStateMergeModeOverwrite target:target soupName:ACCOUNTS_SOUP totalSize:numberAccounts numberFetches:1];

    // Check that db was correctly populated
    [self checkDb:accountIdToFields soupName:ACCOUNTS_SOUP];
}

/**
 * Sync down the test accounts and contacts, make some local changes,
 * then sync down again with merge mode LEAVE_IF_CHANGED then sync down with merge mode OVERWRITE
 */
- (void) testSyncDownWithoutOverwrite {

    NSUInteger numberAccounts = 4;
    NSUInteger numberContactsPerAccount = 3;

    // Creating test accounts and contacts on server
    [self createAccountsAndContactsOnServer:numberAccounts numberContactsPerAccount:numberContactsPerAccount];

    // Sync down
    NSString *parentSoqlFilter = [NSString stringWithFormat:@"%@ IN %@", ID, [self buildInClause:[accountIdToFields allKeys]]];
    SFParentChildrenSyncDownTarget * target = [self getAccountContactsSyncDownTargetWithParentSoqlFilter:parentSoqlFilter];

    [self trySyncDown:SFSyncStateMergeModeOverwrite target:target soupName:ACCOUNTS_SOUP totalSize:numberAccounts numberFetches:1];

    // Make some local changes
    NSArray* accountIds = [accountIdToFields allKeys];
    NSString* accountIdUpdated = accountIds[0]; // account that will updated along with some of the children
    NSDictionary *accountIdToFieldsUpdated = [self makeSomeLocalChanges:accountIdToFields soupName:ACCOUNTS_SOUP idsToUpdate:@[accountIdUpdated]];
    NSDictionary *contactIdToFieldsUpdated = [self makeSomeLocalChanges:accountIdContactIdToFields[accountIdUpdated] soupName:CONTACTS_SOUP];
    NSString* otherAccountId = accountIds[1]; // account that will not be updated but will have updated children
    NSDictionary *otherContactIdToFieldsUpdated = [self makeSomeLocalChanges:accountIdContactIdToFields[otherAccountId] soupName:CONTACTS_SOUP];

    // Sync down again with LEAVE_IF_CHANGED
    [self trySyncDown:SFSyncStateMergeModeLeaveIfChanged target:target soupName:ACCOUNTS_SOUP totalSize:numberAccounts numberFetches:1];

    // Check db - if an account and/or its children was locally modified then that account and all its children should be left alone
    NSMutableDictionary * accountIdToFieldsExpected = [NSMutableDictionary dictionaryWithDictionary:accountIdToFields];
    [accountIdToFieldsExpected setDictionary:accountIdToFieldsUpdated];
    [self checkDb:accountIdToFieldsExpected soupName:ACCOUNTS_SOUP];

    for (NSString* accountId in [accountIdToFields allKeys]) {

        if ([accountId isEqualToString:accountIdUpdated]) {
            [self checkDbStateFlags:@[accountId] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:YES expectedLocallyDeleted:NO];
            [self checkDb:contactIdToFieldsUpdated soupName:CONTACTS_SOUP];
            [self checkDbStateFlags:[contactIdToFieldsUpdated allKeys] soupName:CONTACTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:YES expectedLocallyDeleted:NO];
        } else if ([accountId isEqualToString:otherAccountId]) {
            [self checkDbStateFlags:@[accountId] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];
            [self checkDb:contactIdToFieldsUpdated soupName:CONTACTS_SOUP];
            [self checkDbStateFlags:[otherContactIdToFieldsUpdated allKeys] soupName:CONTACTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:YES expectedLocallyDeleted:NO];
        } else {
            [self checkDbStateFlags:@[accountId] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];
            [self checkDb:accountIdContactIdToFields[accountId] soupName:CONTACTS_SOUP];
            [self checkDbStateFlags:[accountIdContactIdToFields[accountId] allKeys] soupName:CONTACTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];
        }
    }

    // Sync down again with OVERWRITE
    [self trySyncDown:SFSyncStateMergeModeOverwrite target:target soupName:ACCOUNTS_SOUP totalSize:numberAccounts numberFetches:1];

    // Check db - all local changes should have been written over
    [self checkDb:accountIdToFields soupName:ACCOUNTS_SOUP];
    [self checkDbStateFlags:[accountIdToFields allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    for (NSString* accountId in [accountIdToFields allKeys]) {
        [self checkDb:accountIdContactIdToFields[accountId] soupName:CONTACTS_SOUP];
        [self checkDbStateFlags:[accountIdContactIdToFields[accountId] allKeys] soupName:CONTACTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];
    }
}


/**
 * Sync down the test accounts and contacts, modify accounts, re-sync, make sure only the updated ones are downloaded
 */
-(void) testReSyncWithUpdatedParents {
    XCTFail(@"Test not implemented yet");
}

/**
 * Sync down the test accounts and contacts
 * Modify an account and some of its contacts and modify other contacts (without changing parent account)
 * Make sure only the modified account and its modified contacts are re-synced
 */
- (void) testReSyncWithUpdatedChildren {
    XCTFail(@"Test not implemented yet");
}

/**
 * Sync down the test accounts and contacts
 * Delete account from server - run cleanResyncGhosts
 */
- (void) testCleanResyncGhostsForParentChildrenTarget {
    XCTFail(@"Test not implemented yet");
}

/**
 * Create accounts and contacts locally, sync up with merge mode OVERWRITE, check smartstore and server afterwards
 */
- (void) testSyncUpWithLocallyCreatedRecords {
    [self trySyncUpWithLocallyCreatedRecords:SFSyncStateMergeModeOverwrite];
}

/**
 * Create accounts and contacts locally, sync up with mege mode LEAVE_IF_CHANGED, check smartstore and server afterwards
 */
- (void) testSyncUpWithLocallyCreatedRecordsWithoutOverwrite {
    [self trySyncUpWithLocallyCreatedRecords:SFSyncStateMergeModeLeaveIfChanged];
}

/**
 * Create contacts on server, sync down
 * Create accounts locally, update contacts locally to be associated with them
 * Run sync up
 * Check smartstore and server afterwards
 */
- (void) testSyncUpWithLocallyCreatedParentRecords {
    XCTFail(@"Test not implemented yet");
}

/**
 * Create accounts on server, sync down
 * Create contacts locally associated the accounts with them and run sync up
 * Check smartstore and server afterwards
 */
- (void) testSyncUpWithLocallyCreatedChildrenRecords {
    XCTFail(@"Test not implemented yet");
}

/**
 * Sync up with locally updated child
 */
- (void)testSyncUpLocallyUpdatedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:NONE remoteChangeForAccount:NONE localChangeForContact:UPDATE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally updated child remotely updated child
 */
- (void)testSyncUpLocallyUpdatedChildRemotelyUpdatedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:NONE remoteChangeForAccount:NONE localChangeForContact:UPDATE remoteChangeForContact:UPDATE];
}

/**
 * Sync up with locally updated child remotely deleted child
 */
- (void)testSyncUpLocallyUpdatedChildRemotelyDeletedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:NONE remoteChangeForAccount:NONE localChangeForContact:UPDATE remoteChangeForContact:DELETE];
}

/**
 * Sync up with locally deleted child
 */
- (void)testSyncUpLocallyDeletedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:NONE remoteChangeForAccount:NONE localChangeForContact:DELETE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally deleted child remotely updated child
 */
- (void)testSyncUpLocallyDeletedChildRemotelyUpdatedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:NONE remoteChangeForAccount:NONE localChangeForContact:DELETE remoteChangeForContact:UPDATE];
}

/**
 * Sync up with locally deleted child remotely deleted child
 */
- (void)testSyncUpLocallyDeletedChildRemotelyDeletedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:NONE remoteChangeForAccount:NONE localChangeForContact:DELETE remoteChangeForContact:DELETE];
}

/**
 * Sync up with locally updated parent
 */
- (void)testSyncUpLocallyUpdatedParent {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:NONE localChangeForContact:NONE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally updated parent remotely updated parent
 */
- (void)testSyncUpLocallyUpdatedParentRemotelyUpdatedParent {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:UPDATE localChangeForContact:NONE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally updated parent remotely deleted parent
 */
- (void)testSyncUpLocallyUpdatedParentRemotelyDeletedParent {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:DELETE localChangeForContact:NONE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally updated parent updated child
 */
- (void)testSyncUpLocallyUpdatedParentUpdatedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:NONE localChangeForContact:UPDATE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally updated parent updated child remotely updated child
 */
- (void)testSyncUpLocallyUpdatedParentUpdatedChildRemotelyUpdatedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:NONE localChangeForContact:UPDATE remoteChangeForContact:UPDATE];
}

/**
 * Sync up with locally updated parent updated child remotely deleted child
 */
- (void)testSyncUpLocallyUpdatedParentUpdatedChildRemotelyDeletedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:NONE localChangeForContact:UPDATE remoteChangeForContact:DELETE];
}

/**
 * Sync up with locally updated parent updated child remotely updated parent
 */
- (void)testSyncUpLocallyUpdatedParentUpdatedChildRemotelyUpdatedParent {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:UPDATE localChangeForContact:UPDATE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally updated parent updated child remotely updated parent updated child
 */
- (void)testSyncUpLocallyUpdatedParentUpdatedChildRemotelyUpdatedParentUpdatedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:UPDATE localChangeForContact:UPDATE remoteChangeForContact:UPDATE];
}

/**
 * Sync up with locally updated parent updated child remotely updated parent deleted child
 */
- (void)testSyncUpLocallyUpdatedParentUpdatedChildRemotelyUpdatedParentDeletedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:UPDATE localChangeForContact:UPDATE remoteChangeForContact:DELETE];
}

/**
 * Sync up with locally updated parent updated child remotely deleted parent
 */
- (void)testSyncUpLocallyUpdatedParentUpdatedChildRemotelyDeletedParent {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:DELETE localChangeForContact:UPDATE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally updated parent deleted child
 */
- (void)testSyncUpLocallyUpdatedParentDeletedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:NONE localChangeForContact:DELETE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally updated parent deleted child remotely updated child
 */
- (void)testSyncUpLocallyUpdatedParentDeletedChildRemotelyUpdatedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:NONE localChangeForContact:DELETE remoteChangeForContact:UPDATE];
}

/**
 * Sync up with locally updated parent deleted child remotely deleted child
 */
- (void)testSyncUpLocallyUpdatedParentDeletedChildRemotelyDeletedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:NONE localChangeForContact:DELETE remoteChangeForContact:DELETE];
}

/**
 * Sync up with locally updated parent deleted child remotely updated parent
 */
- (void)testSyncUpLocallyUpdatedParentDeletedChildRemotelyUpdatedParent {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:UPDATE localChangeForContact:DELETE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally updated parent deleted child remotely updated parent updated child
 */
- (void)testSyncUpLocallyUpdatedParentDeletedChildRemotelyUpdatedParentUpdatedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:UPDATE localChangeForContact:DELETE remoteChangeForContact:UPDATE];
}

/**
 * Sync up with locally updated parent deleted child remotely updated parent deleted child
 */
- (void)testSyncUpLocallyUpdatedParentDeletedChildRemotelyUpdatedParentDeletedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:UPDATE localChangeForContact:DELETE remoteChangeForContact:DELETE];
}

/**
 * Sync up with locally updated parent deleted child remotely deleted parent
 */
- (void)testSyncUpLocallyUpdatedParentDeletedChildRemotelyDeletedParent {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:UPDATE remoteChangeForAccount:DELETE localChangeForContact:DELETE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally deleted parent
 */
- (void)testSyncUpLocallyDeletedParent {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:DELETE remoteChangeForAccount:NONE localChangeForContact:NONE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally deleted parent remotely updated parent
 */
- (void)testSyncUpLocallyDeletedParentRemotelyUpdatedParent {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:DELETE remoteChangeForAccount:UPDATE localChangeForContact:NONE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally deleted parent remotely deleted parent
 */
- (void)testSyncUpLocallyDeletedParentRemotelyDeletedParent {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:DELETE remoteChangeForAccount:DELETE localChangeForContact:NONE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally deleted parent updated child
 */
- (void)testSyncUpLocallyDeletedParentUpdatedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:DELETE remoteChangeForAccount:NONE localChangeForContact:UPDATE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally deleted parent updated child remotely updated parent
 */
- (void)testSyncUpLocallyDeletedParentUpdatedChildRemotelyUpdatedParent {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:DELETE remoteChangeForAccount:UPDATE localChangeForContact:UPDATE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally deleted parent updated child remotely deleted parent
 */
- (void)testSyncUpLocallyDeletedParentUpdatedChildRemotelyDeletedParent {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:DELETE remoteChangeForAccount:DELETE localChangeForContact:UPDATE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally deleted parent deleted child
 */
- (void)testSyncUpLocallyDeletedParentDeletedChild {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:DELETE remoteChangeForAccount:NONE localChangeForContact:DELETE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally deleted parent deleted child remotely updated parent
 */
- (void)testSyncUpLocallyDeletedParentDeletedChildRemotelyUpdatedParent {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:DELETE remoteChangeForAccount:UPDATE localChangeForContact:DELETE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally deleted parent deleted child remotely deleted parent
 */
- (void)testSyncUpLocallyDeletedParentDeletedChildRemotelyDeletedParent {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:2 localChangeForAccount:DELETE remoteChangeForAccount:DELETE localChangeForContact:DELETE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally updated parent and no children
 */
- (void)testSyncUpLocallyUpdatedParentNoChildren {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:0 localChangeForAccount:UPDATE remoteChangeForAccount:NONE localChangeForContact:NONE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally updated parent remotely updated parent and no children
 */
- (void)testSyncUpLocallyUpdatedParentRemotelyUpdatedParentNoChildren {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:0 localChangeForAccount:UPDATE remoteChangeForAccount:UPDATE localChangeForContact:NONE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally updated parent remotely deleted parent and no children
 */
- (void)testSyncUpLocallyUpdatedParentRemotelyDeletedParentNoChildren {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:0 localChangeForAccount:UPDATE remoteChangeForAccount:DELETE localChangeForContact:NONE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally deleted parent and no children
 */
- (void)testSyncUpLocallyDeletedParentNoChildren {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:0 localChangeForAccount:DELETE remoteChangeForAccount:NONE localChangeForContact:NONE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally deleted parent remotely updated parent and no children
 */
- (void)testSyncUpLocallyDeletedParentRemotelyUpdatedParentNoChildren {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:0 localChangeForAccount:DELETE remoteChangeForAccount:UPDATE localChangeForContact:NONE remoteChangeForContact:NONE];
}

/**
 * Sync up with locally deleted parent remotely deleted parent and no children
 */
- (void)testSyncUpLocallyDeletedParentRemotelyDeletedParentNoChildren {
    [self trySyncUpsWithVariousChangesWithNumberAccounts:2 numberContactsPerAccount:0 localChangeForAccount:DELETE remoteChangeForAccount:DELETE localChangeForContact:NONE remoteChangeForContact:NONE];
}


#pragma mark - Helper methods

- (void)createTestData {
    [self createAccountsSoup];
    [self createContactsSoup];
}

- (void)deleteTestData {
    [self dropAccountsSoup];
    [self dropContactsSoup];

    // accountIdToFields and accountIdContactIdToFields are not used by all tests
    if (accountIdToFields != nil) {
        [self deleteRecordsOnServer:[accountIdToFields allKeys] objectType:ACCOUNT_TYPE];
        accountIdToFields = nil;
    }

    if (accountIdContactIdToFields != nil) {
        for (NSString* accountId in [accountIdContactIdToFields allKeys]) {
            NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSObject *> *> *contactIdToFields = accountIdContactIdToFields[accountId];
            [self deleteRecordsOnServer:[contactIdToFields allKeys] objectType:CONTACT_TYPE];
        }
        accountIdContactIdToFields = nil;
    }
}

- (NSDictionary*) createAccountsAndContactsLocally:(NSArray<NSString*>*)names
                        numberOfContactsPerAccount:(NSUInteger)numberOfContactsPerAccount
{
    
    NSMutableArray* accounts = [NSMutableArray new];
    NSMutableArray* accountIds = [NSMutableArray new];
    NSDictionary *attributes = @{TYPE: ACCOUNT_TYPE};
    for (NSString* name in names) {
        NSDictionary *account = @{
                                  ID: [self createLocalId],
                                  NAME: name,
                                  DESCRIPTION: [@[DESCRIPTION, name] componentsJoinedByString:@"_"],
                                  ATTRIBUTES: attributes,
                                  kSyncTargetLocal: @YES,
                                  kSyncTargetLocallyCreated: @YES,
                                  kSyncTargetLocallyUpdated: @NO,
                                  kSyncTargetLocallyDeleted: @NO,
                                  };
        [accounts addObject:account];
        [accountIds addObject:account[ID]];
    }
    NSArray* createdAccounts = [self.store upsertEntries:accounts toSoup:ACCOUNTS_SOUP];

    NSDictionary* accountIdsToContacts = [self createContactsForAccountLocally:numberOfContactsPerAccount accountIds:accountIds];
    NSMutableDictionary* accountToContacts = [NSMutableDictionary new];

    for (NSDictionary* createdAccount in createdAccounts) {
        accountToContacts[createdAccount] = accountIdsToContacts[createdAccount[ID]];
        
    }
    return accountToContacts;
}

- (NSDictionary*) createContactsForAccountLocally:(NSUInteger)numberOfContactsPerAccount
                                        accountIds:(NSArray<NSString*>*)accountIds
{
    NSMutableDictionary* accountIdsToContacts = [NSMutableDictionary new];

    NSDictionary *attributes = @{TYPE: ACCOUNT_TYPE};
    for (NSString *accountId in accountIds) {
        NSMutableArray* contacts = [NSMutableArray new];
        for (NSUInteger i=0; i<numberOfContactsPerAccount; i++) {
            NSDictionary *contact = @{
                    ID: [self createLocalId],
                    LAST_NAME: [self createRecordName:CONTACT_TYPE],
                    ATTRIBUTES: attributes,
                    ACCOUNT_ID: accountId,
                    kSyncTargetLocal: @YES,
                    kSyncTargetLocallyCreated: @YES,
                    kSyncTargetLocallyUpdated: @NO,
                    kSyncTargetLocallyDeleted: @NO,
            };
            [contacts addObject:contact];
        }
        accountIdsToContacts[accountId] = [self.store upsertEntries:contacts toSoup:CONTACTS_SOUP];
    }
    return accountIdsToContacts;
}

- (void) tryGetDirtyRecordIds:(NSArray*) expectedRecords
{
    SFParentChildrenSyncDownTarget * target = [self getAccountContactsSyncDownTarget];
    NSOrderedSet* dirtyRecordIds = [target getDirtyRecordIds:self.syncManager soupName:ACCOUNTS_SOUP idField:ID];
    XCTAssertEqual(dirtyRecordIds.count, expectedRecords.count);

    for (NSDictionary * expectedRecord in expectedRecords) {
        XCTAssertTrue([dirtyRecordIds containsObject:expectedRecord[ID]]);
    }
}

- (void) tryGetNonDirtyRecordIds:(NSArray*) expectedRecords
{
    SFParentChildrenSyncDownTarget * target = [self getAccountContactsSyncDownTarget];
    NSOrderedSet* nonDirtyRecordIds = [target getNonDirtyRecordIds:self.syncManager soupName:ACCOUNTS_SOUP idField:ID];
    XCTAssertEqual(nonDirtyRecordIds.count, expectedRecords.count);

    for (NSDictionary * expectedRecord in expectedRecords) {
        XCTAssertTrue([nonDirtyRecordIds containsObject:expectedRecord[ID]]);
    }
}

- (void) cleanRecords:(NSString*)soupName records:(NSArray*)records {
    NSMutableArray * cleanRecords = [NSMutableArray new];
    for (NSDictionary * record in records) {
        NSMutableDictionary * mutableRecord = [record mutableCopy];
        mutableRecord[kSyncTargetLocal] = @NO;
        mutableRecord[kSyncTargetLocallyCreated] = @NO;
        mutableRecord[kSyncTargetLocallyUpdated] = @NO;
        mutableRecord[kSyncTargetLocallyDeleted] = @NO;
        [cleanRecords addObject:mutableRecord];
    }
    [self.store upsertEntries:cleanRecords toSoup:soupName];
}

- (void) cleanRecord:(NSString*)soupName record:(NSDictionary*)record {
    [self cleanRecords:soupName records:@[record]];
}


- (SFParentChildrenSyncDownTarget*) getAccountContactsSyncDownTarget {
    return [self getAccountContactsSyncDownTargetWithParentSoqlFilter:@""];
}

- (SFParentChildrenSyncDownTarget*)getAccountContactsSyncDownTargetWithParentSoqlFilter:(NSString*) parentSoqlFilter {
    return [self getAccountContactsSyncDownTargetWithAccountModificationDateFieldName:LAST_MODIFIED_DATE contactModificationDateFieldName:LAST_MODIFIED_DATE parentSoqlFilter:parentSoqlFilter];
}

- (SFParentChildrenSyncDownTarget*)getAccountContactsSyncDownTargetWithAccountModificationDateFieldName:(NSString *)accountModificationDateFieldName
                                                                       contactModificationDateFieldName:(NSString *)contactModificationDateFieldName
                                                                                       parentSoqlFilter:(NSString*) parentSoqlFilter {

    SFParentChildrenSyncDownTarget *target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:ACCOUNT_TYPE soupName:ACCOUNTS_SOUP idFieldName:ID modificationDateFieldName:accountModificationDateFieldName]
                        parentFieldlist:@[ID, NAME, DESCRIPTION]
                       parentSoqlFilter:parentSoqlFilter
                           childrenInfo:[SFChildrenInfo newWithSObjectType:CONTACT_TYPE sobjectTypePlural:CONTACT_TYPE_PLURAL soupName:CONTACTS_SOUP parentIdFieldName:ACCOUNT_ID idFieldName:ID modificationDateFieldName:contactModificationDateFieldName]
                      childrenFieldlist:@[LAST_NAME, ACCOUNT_ID]
                       relationshipType:SFParentChildrenRelationpshipMasterDetail]; // account-contacts are master-detail
    return target;
}

- (NSArray<NSDictionary*>*) queryWithInClause:(NSString*)soupName fieldName:(NSString*)fieldName values:(NSArray<NSString*>*)values orderBy:(NSString*)orderBy
{
    NSString* sql = [NSString stringWithFormat:@"SELECT {%@:%@} FROM {%@} WHERE {%@:%@} IN %@ %@",
            soupName, @"_soup", soupName, soupName, fieldName,
            [self buildInClause:values],
            orderBy == nil ? @"" : [NSString stringWithFormat:@" ORDER BY {%@:%@} ASC", soupName, orderBy]
            ];

    SFQuerySpec * querySpec = [SFQuerySpec newSmartQuerySpec:sql withPageSize:INT_MAX];
    NSArray* rows = [self.store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
    NSMutableArray * arr = [NSMutableArray new];
    for (NSUInteger i = 0; i < rows.count; i++) {
        arr[i] = rows[i][0];
    }
    return arr;
}

- (void) createAccountsAndContactsOnServer:(NSUInteger) numberAccounts numberContactsPerAccount:(NSUInteger) numberContactsPerAccount
{
    accountIdToFields = [NSMutableDictionary new];
    accountIdContactIdToFields = [NSMutableDictionary new];

    NSMutableDictionary* refIdToFields = [NSMutableDictionary new];
    NSMutableArray* accountTrees = [NSMutableArray new];
    NSArray* listAccountFields = [self buildFieldsMapForRecords:numberAccounts objectType:ACCOUNT_TYPE additionalFields:nil]; 
    
    for (NSUInteger i = 0; i<listAccountFields.count; i++) {
        NSArray* listContactFields = [self buildFieldsMapForRecords:numberContactsPerAccount objectType:CONTACT_TYPE additionalFields:nil];

        NSString* refIdAccount = [NSString stringWithFormat:@"refAccount_%lu", (unsigned long)i];
        NSDictionary * accountFields = listAccountFields[i];
        refIdToFields[refIdAccount] = accountFields;

        NSMutableArray* contactTrees = [NSMutableArray new];
        for (NSUInteger j = 0; j<listContactFields.count; j++) {
            NSString* refIdContact = [NSString stringWithFormat:@"%@:refContact_%lu", refIdAccount, (unsigned long)j];
            NSDictionary * contactFields = listContactFields[j];
            refIdToFields[refIdContact] = contactFields;
            [contactTrees addObject:[[SFSObjectTree alloc] initWithObjectType:CONTACT_TYPE objectTypePlural:CONTACT_TYPE_PLURAL referenceId:refIdContact fields:contactFields childrenTrees:nil]];
        }
        [accountTrees addObject:[[SFSObjectTree alloc] initWithObjectType:ACCOUNT_TYPE objectTypePlural:nil referenceId:refIdAccount fields:accountFields childrenTrees:contactTrees]];
    }

    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForSObjectTree:ACCOUNT_TYPE objectTrees:accountTrees];

    // Send request
    NSDictionary *response = [self sendSyncRequest:request];

    // Parse response
    NSMutableDictionary * refIdToId = [NSMutableDictionary new];

    NSArray* results = response[@"results"];
    for (NSUInteger i=0; i<results.count; i++) {
        NSDictionary* result = results[i];
        NSString* refId = result[@"referenceId"];
        NSString* id = result[@"id"];
        refIdToId[refId] = id;
    }

    // Populate accountIdToFields and accountIdContactIdToFields
    for (NSString* refId in [refIdToId allKeys]) {
        NSDictionary * fields = refIdToFields[refId];
        NSArray* parts = [refId componentsSeparatedByString:@":"];
        NSString* accountId = refIdToId[parts[0]];
        NSString* contactId = parts.count > 1 ? refIdToId[refId] : nil;

        if (contactId == nil) {
            accountIdToFields[accountId] = fields;
        }
        else {
            if (accountIdContactIdToFields[accountId] == nil) {
                accountIdContactIdToFields[accountId] = [NSMutableDictionary new];
            }
            accountIdContactIdToFields[accountId][contactId] = fields;
        }
    }
}

/**
 * Helper for various sync up test
 *
 * Create accounts and contacts on server
 * Run sync down
 * Then locally and/or remotely delete and/or update an account or contact
 * Run sync up with leave-if-changed (if requested)
 * Check db and server
 * Run sync up with overwrite
 * Check db and server
 */
- (void)trySyncUpsWithVariousChangesWithNumberAccounts:(NSUInteger)numberAccounts
                              numberContactsPerAccount:(NSUInteger)numberContactsPerAccount
                                 localChangeForAccount:(SFSyncUpChange)localChangeForAccount
                                remoteChangeForAccount:(SFSyncUpChange)remoteChangeForAccount
                                 localChangeForContact:(SFSyncUpChange)localChangeForContact
                                remoteChangeForContact:(SFSyncUpChange)remoteChangeForContact {
    XCTFail(@"trySyncUpsWithVariousChangesWithNumberAccounts not implemented");
}

/**
 * Helper method for testSyncUpWithLocallyCreatedRecords*
 */
- (void)trySyncUpWithLocallyCreatedRecords:(enum SFSyncStateMergeMode)mergeMode {
    XCTFail(@"trySyncUpWithLocallyCreatedRecords not implemented");

}



@end
