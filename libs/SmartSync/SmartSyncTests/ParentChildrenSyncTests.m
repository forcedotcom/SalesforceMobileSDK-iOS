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
#import "SFSyncUpdateCallbackQueue.h"
#import "SFParentChildrenSyncUpTarget.h"

//  Useful enum for trySyncUpsWithVariousChanges
typedef NS_ENUM(NSInteger, SFSyncUpChange) {
    NONE,
    UPDATE,
    DELETE
};

@interface SFParentChildrenSyncDownTarget ()

- (NSString *)getSoqlForRemoteIds;
- (NSString*) getDirtyRecordIdsSql:(NSString*)soupName idField:(NSString*)idField;

- (NSString *)getNonDirtyRecordIdsSql:(NSString *)soupName idField:(NSString *)idField additionalPredicate:(NSString *)additionalPredicate;

- (NSOrderedSet *)getNonDirtyRecordIds:(SFSmartSyncSyncManager *)syncManager soupName:(NSString *)soupName idField:(NSString *)idField additionalPredicate:(NSString *)additionalPredicate;

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

    NSString *expectedQuery = @"SELECT DISTINCT {parentsSoup:IdForQuery} FROM {parentsSoup} WHERE {parentsSoup:__local__} = 0 AND {parentsSoup:__sync_id__} = 123 AND NOT EXISTS (SELECT {childrenSoup:ChildId} FROM {childrenSoup} WHERE {childrenSoup:ChildParentId} = {parentsSoup:ParentId} AND {childrenSoup:__local__} = 1)";
    XCTAssertEqualObjects([target getNonDirtyRecordIdsSql:@"parentsSoup" idField:@"IdForQuery" additionalPredicate:@"AND {parentsSoup:__sync_id__} = 123"], expectedQuery);
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
    NSNumber* syncId = [NSNumber numberWithInteger:123];

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
    [target cleanAndSaveRecordsToLocalStore:self.syncManager soupName:ACCOUNTS_SOUP records:records syncId:syncId];

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
        XCTAssertEqualObjects(syncId, accountFromDb[kSyncTargetSyncId]);

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
            XCTAssertEqualObjects(syncId, contactFromDb[kSyncTargetSyncId]);
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
    NSUInteger numberAccounts = 4;
    NSUInteger numberContactsPerAccount = 3;

    // Creating test accounts and contacts on server
    [self createAccountsAndContactsOnServer:numberAccounts numberContactsPerAccount:numberContactsPerAccount];

    // Sync down
    NSString *parentSoqlFilter = [NSString stringWithFormat:@"%@ IN %@", ID, [self buildInClause:[accountIdToFields allKeys]]];
    SFParentChildrenSyncDownTarget * target = [self getAccountContactsSyncDownTargetWithParentSoqlFilter:parentSoqlFilter];
    NSNumber* syncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeOverwrite target:target soupName:ACCOUNTS_SOUP totalSize:numberAccounts numberFetches:1]];

    // Check sync time stamp
    SFSyncState* sync = [self.syncManager getSyncStatus:syncId];
    SFSyncOptions* options = sync.options;
    long long maxTimeStamp = sync.maxTimeStamp;
    XCTAssertTrue(maxTimeStamp > 0, @"Wrong time stamp");

    // Make some remote change to accounts
    NSDictionary* idToFieldsUpdated = [self makeSomeRemoteChanges:accountIdToFields objectType:ACCOUNT_TYPE];

    // Call reSync
    SFSyncUpdateCallbackQueue* queue = [[SFSyncUpdateCallbackQueue alloc] init];
    [queue runReSync:syncId syncManager:self.syncManager];

    // Check status updates
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:-1]; // we get an update right away before getting records to sync
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:idToFieldsUpdated.count];
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusDone expectedProgress:100 expectedTotalSize:idToFieldsUpdated.count];

    // Check db
    [self checkDb:idToFieldsUpdated soupName:ACCOUNTS_SOUP];

    // Check sync time stamp
    XCTAssertTrue([self.syncManager getSyncStatus:syncId].maxTimeStamp > maxTimeStamp);
}

/**
 * Sync down the test accounts and contacts
 * Modify an account and some of its contacts and modify other contacts (without changing parent account)
 * Make sure only the modified account and its modified contacts are re-synced
 */
- (void) testReSyncWithUpdatedChildren {
    NSUInteger numberAccounts = 4;
    NSUInteger numberContactsPerAccount = 3;

    // Creating test accounts and contacts on server
    [self createAccountsAndContactsOnServer:numberAccounts numberContactsPerAccount:numberContactsPerAccount];

    // Sync down
    NSString *parentSoqlFilter = [NSString stringWithFormat:@"%@ IN %@", ID, [self buildInClause:[accountIdToFields allKeys]]];
    SFParentChildrenSyncDownTarget * target = [self getAccountContactsSyncDownTargetWithParentSoqlFilter:parentSoqlFilter];
    NSNumber* syncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeOverwrite target:target soupName:ACCOUNTS_SOUP totalSize:numberAccounts numberFetches:1]];

    // Check sync time stamp
    SFSyncState* sync = [self.syncManager getSyncStatus:syncId];
    SFSyncOptions* options = sync.options;
    long long maxTimeStamp = sync.maxTimeStamp;
    XCTAssertTrue(maxTimeStamp > 0, @"Wrong time stamp");

    // Make some remote changes
    NSArray* accountIds = [accountIdToFields allKeys];
    NSString* accountId = accountIds[0]; // account that will updated along with some of the children
    NSDictionary* accountIdToFieldsUpdated = [self makeSomeRemoteChanges:accountIdToFields objectType:ACCOUNT_TYPE idsToUpdate:@[accountId]];
    NSDictionary* contactIdToFieldsUpdated = [self makeSomeRemoteChanges:accountIdContactIdToFields[accountId] objectType:CONTACT_TYPE];
    NSString* otherAccountId = accountIds[1]; // account that will not be updated but will have updated children
    /*NSDictionary* otherContactIdToFieldsUpdated =*/ [self makeSomeRemoteChanges:accountIdContactIdToFields[otherAccountId] objectType:CONTACT_TYPE];

    // Call reSync
    SFSyncUpdateCallbackQueue* queue = [[SFSyncUpdateCallbackQueue alloc] init];
    [queue runReSync:syncId syncManager:self.syncManager];

    // Check status updates
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:-1]; // we get an update right away before getting records to sync
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusRunning expectedProgress:0 expectedTotalSize:accountIdToFieldsUpdated.count];
    [self checkStatus:[queue getNextSyncUpdate] expectedType:SFSyncStateSyncTypeDown expectedId:[syncId integerValue] expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusDone expectedProgress:100 expectedTotalSize:accountIdToFieldsUpdated.count];

    // Check db
    [self checkDb:accountIdToFieldsUpdated soupName:ACCOUNTS_SOUP]; // updated account should be updated in db
    [self checkDb:contactIdToFieldsUpdated soupName:CONTACTS_SOUP]; // updated contacts of updated account should be updated in db
    [self checkDb:accountIdContactIdToFields[otherAccountId] soupName:CONTACTS_SOUP]; // updated contacts of non-updated account should not be updated in db

    // Check sync time stamp
    XCTAssertTrue([self.syncManager getSyncStatus:syncId].maxTimeStamp > maxTimeStamp);
}

/**
 * Sync down the test accounts and contacts
 * Delete account from server - run cleanResyncGhosts
 */
- (void) testCleanResyncGhostsForParentChildrenTarget {
    NSUInteger numberAccounts = 4;
    NSUInteger numberContactsPerAccount = 3;

    // Creating test accounts and contacts on server
    [self createAccountsAndContactsOnServer:numberAccounts numberContactsPerAccount:numberContactsPerAccount];

    // Sync down
    NSString *parentSoqlFilter = [NSString stringWithFormat:@"%@ IN %@", ID, [self buildInClause:[accountIdToFields allKeys]]];
    SFParentChildrenSyncDownTarget * target = [self getAccountContactsSyncDownTargetWithParentSoqlFilter:parentSoqlFilter];
    NSNumber* syncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeOverwrite target:target soupName:ACCOUNTS_SOUP totalSize:numberAccounts numberFetches:1]];

    // Deletes 1 account on the server and verifies the ghost record is cleared from the soup.
    NSString* accountIdDeleted = [accountIdToFields allKeys][0];
    [self deleteRecordsOnServer:@[accountIdDeleted] objectType:ACCOUNT_TYPE];
    XCTestExpectation* cleanResyncGhosts = [self expectationWithDescription:@"cleanResyncGhosts"];
    [self.syncManager cleanResyncGhosts:syncId completionStatusBlock:^(SFSyncStateStatus syncStatus) {
        if (syncStatus == SFSyncStateStatusFailed || syncStatus == SFSyncStateStatusDone) {
            [cleanResyncGhosts fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];

    // Accounts and contacts expected to still be in db
    NSMutableDictionary * accountIdToFieldsLeft = [accountIdToFields mutableCopy];
    [accountIdToFieldsLeft removeObjectForKey:accountIdDeleted];

    // Checking db
    [self checkDb:accountIdToFieldsLeft soupName:ACCOUNTS_SOUP];
    [self checkDbDeleted:ACCOUNTS_SOUP ids:@[accountIdDeleted] idField:ID];

    for (NSString* accountId in [accountIdContactIdToFields allKeys]) {
        if ([accountId isEqualToString:accountIdDeleted]) {
            [self checkDbDeleted:CONTACTS_SOUP ids:[((NSDictionary *) accountIdContactIdToFields[accountId]) allKeys] idField:ID];
        } else {
            [self checkDb:accountIdContactIdToFields[accountId] soupName:CONTACTS_SOUP];
        }
    }
}

/**
  * Tests clean ghosts when soup is populated through more than one sync down
  */
- (void) testCleanResyncGhostsForParentChildrenWithMultipleSyncs
{
    NSUInteger numberAccounts = 6;
    NSUInteger numberContactsPerAccount = 3;

    // Creating test accounts and contacts on server
    [self createAccountsAndContactsOnServer:numberAccounts numberContactsPerAccount:numberContactsPerAccount];

    NSArray* accountIds = [accountIdContactIdToFields allKeys];
    NSArray* accountIdsFirstSubset = [accountIds subarrayWithRange:NSMakeRange(0, 3)];  // id0, id1, id2
    NSArray* accountIdsSecondSubset = [accountIds subarrayWithRange:NSMakeRange(2, 4)]; //           id2, id3, id4, id5

    // Runs a first sync down (bringing down accounts id0, id1, id2 and their contacts)
    SFParentChildrenSyncDownTarget * firstTarget = [self getAccountContactsSyncDownTargetWithParentSoqlFilter:[NSString stringWithFormat:@"%@ IN %@", ID, [self buildInClause:accountIdsFirstSubset]]];
    NSNumber* firstSyncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeOverwrite
                                                                   target:firstTarget
                                                                 soupName:ACCOUNTS_SOUP
                                                                totalSize:accountIdsFirstSubset.count
                                                            numberFetches:1]];
    [self checkDbExists:ACCOUNTS_SOUP ids:accountIdsFirstSubset idField:@"Id"];
    [self checkDbSyncIdField:accountIdsFirstSubset soupName:ACCOUNTS_SOUP syncId:firstSyncId];

    // Runs a second sync down (bringing down accounts id2, id3, id4, id5 and their contacts)
    SFParentChildrenSyncDownTarget * secondTarget = [self getAccountContactsSyncDownTargetWithParentSoqlFilter:[NSString stringWithFormat:@"%@ IN %@", ID, [self buildInClause:accountIdsSecondSubset]]];
    NSNumber* secondSyncId = [NSNumber numberWithInteger:[self trySyncDown:SFSyncStateMergeModeOverwrite
                                                                   target:secondTarget
                                                                 soupName:ACCOUNTS_SOUP
                                                                totalSize:accountIdsSecondSubset.count
                                                            numberFetches:1]];
    [self checkDbExists:ACCOUNTS_SOUP ids:accountIdsSecondSubset idField:@"Id"];
    [self checkDbSyncIdField:accountIdsSecondSubset soupName:ACCOUNTS_SOUP syncId:secondSyncId];

    // Deletes id0, id2, id5 on the server
    [self deleteRecordsOnServer:@[accountIds[0], accountIds[2], accountIds[5]] objectType:ACCOUNT_TYPE];

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
    for (NSString* accountId in [accountIdContactIdToFields allKeys]) {
        if ([accountId isEqualToString:accountIds[0]]) {
            [self checkDbDeleted:CONTACTS_SOUP ids:[((NSDictionary *) accountIdContactIdToFields[accountId]) allKeys] idField:ID];
        } else {
            [self checkDb:accountIdContactIdToFields[accountId] soupName:CONTACTS_SOUP];
        }
    }

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
    for (NSString* accountId in [accountIdContactIdToFields allKeys]) {
        if ([accountId isEqualToString:accountIds[0]] || [accountId isEqualToString:accountIds[2]] || [accountId isEqualToString:accountIds[5]]) {
            [self checkDbDeleted:CONTACTS_SOUP ids:[((NSDictionary *) accountIdContactIdToFields[accountId]) allKeys] idField:ID];
        } else {
            [self checkDb:accountIdContactIdToFields[accountId] soupName:CONTACTS_SOUP];
        }
    }
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

    // Create contacts on server
    NSDictionary* contactIdToName = [self createRecordsOnServer:6 objectType:CONTACT_TYPE];

    // Sync down remote contacts
    NSString *soql = [NSString stringWithFormat:@"SELECT Id, LastName, LastModifiedDate FROM Contact WHERE Id IN %@", [self buildInClause:[contactIdToName allKeys]]];
    SFSyncDownTarget* contactSyncDownTarget = [SFSoqlSyncDownTarget newSyncTarget:soql];
    [self trySyncDown:SFSyncStateMergeModeOverwrite target:contactSyncDownTarget soupName:CONTACTS_SOUP totalSize:contactIdToName.count numberFetches:1];


    // Create a few accounts locally
    NSArray<NSString *> *accountNames = @[
            [self createAccountName],
            [self createAccountName]
    ];

    NSArray* localAccounts = [self createAccountsLocally:accountNames];

    // Build account name to id map
    NSMutableDictionary * accountNameToServerId = [NSMutableDictionary new];
    for (NSDictionary * localAccount in localAccounts) {
        accountNameToServerId[localAccount[NAME]] = localAccount[ID];
    }

    // Update contacts locally to use locally created accounts
    NSMutableDictionary * contactIdToAccountName = [NSMutableDictionary new];
    NSMutableDictionary * idToFieldsLocallyUpdated = [NSMutableDictionary new];
    int i=0;
    for (NSString* contactId in [contactIdToName allKeys]) {
        NSMutableDictionary* fieldsLocallyUpdated = [NSMutableDictionary new];
        NSString* accountName = accountNames[i % accountNames.count];
        fieldsLocallyUpdated[ACCOUNT_ID] = accountNameToServerId[accountName];
        idToFieldsLocallyUpdated[contactId] = fieldsLocallyUpdated;
        contactIdToAccountName[contactId] = accountName;
        i++;
    }
    [self updateRecordsLocally:idToFieldsLocallyUpdated soupName:CONTACTS_SOUP];

    // Sync up
    SFParentChildrenSyncUpTarget * target = [self getAccountContactsSyncUpTarget];
    [self trySyncUp:accountNames.count target:target mergeMode:SFSyncStateMergeModeOverwrite];

    // Check that db doesn't show account entries as locally created anymore and that they use sfdc id
    NSDictionary * accountIdToFieldsCreated = [self getIdToFieldsByName:ACCOUNTS_SOUP fieldNames:@[NAME, DESCRIPTION] nameField:NAME names:accountNames];
    [self checkDbStateFlags:[accountIdToFieldsCreated allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    // Updated account name to server id map
    for (NSString* accountId in [accountIdToFieldsCreated allKeys]) {
        accountNameToServerId[accountIdToFieldsCreated[accountId][NAME]] = accountId;
    }

    // Check accounts on server
    [self checkServer:accountIdToFieldsCreated objectType:ACCOUNT_TYPE];

    // Check that db doesn't show contact entries as locally updated anymore
    NSDictionary * contactIdToFieldsUpdated = [self getIdToFieldsByName:CONTACTS_SOUP fieldNames:@[LAST_NAME, ACCOUNT_ID] nameField:LAST_NAME names:[contactIdToName allValues]];
    [self checkDbStateFlags:[contactIdToFieldsUpdated allKeys] soupName:CONTACTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    // Check that contact use server account id in accountId field
    for (NSString* contactId in [contactIdToFieldsUpdated allKeys]) {
        XCTAssertEqualObjects(contactIdToFieldsUpdated[contactId][ACCOUNT_ID], accountNameToServerId[contactIdToAccountName[contactId]]);
    }

    // Check contacts on server
    [self checkServer:contactIdToFieldsUpdated objectType:CONTACT_TYPE];

    // Cleanup
    [self deleteRecordsOnServer:[accountIdToFieldsCreated allKeys] objectType:ACCOUNT_TYPE];
    [self deleteRecordsOnServer:[contactIdToFieldsUpdated allKeys] objectType:CONTACT_TYPE];
}

/**
 * Create accounts on server, sync down
 * Create contacts locally, associates them with the accounts and run sync up
 * Check smartstore and server afterwards
 */
- (void) testSyncUpWithLocallyCreatedChildrenRecords {

    // Create accounts on server
    NSDictionary* accountIdToName = [self createRecordsOnServer:2 objectType:ACCOUNT_TYPE];
    NSArray* accountNames = [accountIdToName allValues];
    
    // Sync down remote accounts
    NSString *soql = [NSString stringWithFormat:@"SELECT Id, Name, LastModifiedDate FROM Account WHERE Id IN %@", [self buildInClause:[accountIdToName allKeys]]];
    SFSyncDownTarget* accountSyncDownTarget = [SFSoqlSyncDownTarget newSyncTarget:soql];
    [self trySyncDown:SFSyncStateMergeModeOverwrite target:accountSyncDownTarget soupName:ACCOUNTS_SOUP totalSize:accountIdToName.count numberFetches:1];
    
    // Create a few contacts locally associated with existing accounts
    NSDictionary * accountIdToFieldsCreated = [self getIdToFieldsByName:ACCOUNTS_SOUP fieldNames:@[NAME] nameField:NAME names:accountNames];
    NSDictionary *contactsForAccountsLocally = [self createContactsForAccountLocally:3 accountIds:[accountIdToFieldsCreated allKeys]];
    NSMutableArray * contactNames = [NSMutableArray new];
    for (NSArray * contacts in [contactsForAccountsLocally allValues]) {
        for (NSDictionary * contact in contacts) {
            [contactNames addObject:contact[LAST_NAME]];
        }
    }

    // Sync up
    SFParentChildrenSyncUpTarget * target = [self getAccountContactsSyncUpTarget];
    [self trySyncUp:accountNames.count target:target mergeMode:SFSyncStateMergeModeOverwrite];

    // Check that db doesn't show contact entries as locally created anymore
    NSDictionary * contactIdToFieldsCreated = [self getIdToFieldsByName:CONTACTS_SOUP fieldNames:@[LAST_NAME, ACCOUNT_ID] nameField:LAST_NAME names:contactNames];
    [self checkDbStateFlags:[contactIdToFieldsCreated allKeys] soupName:CONTACTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    // Check contacts on server
    [self checkServer:contactIdToFieldsCreated objectType:CONTACT_TYPE];

    // Cleanup
    [self deleteRecordsOnServer:[accountIdToFieldsCreated allKeys] objectType:ACCOUNT_TYPE];
    [self deleteRecordsOnServer:[contactIdToFieldsCreated allKeys] objectType:CONTACT_TYPE];
}

/**
 * Create account on server, sync down
 * Remotely delete account
 * Create contacts locally, associates them with the account and run sync up
 * Check smartstore and server afterwards
 * The account should be recreated and the contacts should be associated to the new account id
 */
- (void) testSyncUpWithLocallyCreatedChildrenRemotelyDeletedParent {
    
    // Create account on server
    NSDictionary* accountIdToName = [self createRecordsOnServer:1 objectType:ACCOUNT_TYPE];
    NSString* accountId = [accountIdToName allKeys][0];
    NSString* accountName = accountIdToName[accountId];
    
    // Sync down remote accounts
    NSString *soql = [NSString stringWithFormat:@"SELECT Id, Name, LastModifiedDate FROM Account WHERE Id = '%@'", accountId];
    SFSyncDownTarget* accountSyncDownTarget = [SFSoqlSyncDownTarget newSyncTarget:soql];
    [self trySyncDown:SFSyncStateMergeModeOverwrite target:accountSyncDownTarget soupName:ACCOUNTS_SOUP totalSize:1 numberFetches:1];
    
    // Create a few contacts locally associated with account
    NSDictionary *contactsForAccountsLocally = [self createContactsForAccountLocally:3 accountIds:@[accountId]];
    NSMutableArray * contactNames = [NSMutableArray new];
    for (NSArray * contacts in [contactsForAccountsLocally allValues]) {
        for (NSDictionary * contact in contacts) {
            [contactNames addObject:contact[LAST_NAME]];
        }
    }
    
    // Delete account remotely
    [self deleteRecordsOnServer:@[accountId] objectType:ACCOUNT_TYPE];
    
    // Sync up
    SFParentChildrenSyncUpTarget * target = [self getAccountContactsSyncUpTarget];
    [self trySyncUp:1 target:target mergeMode:SFSyncStateMergeModeOverwrite];
    
    // Make sure account got recreated
    NSString* newAccountId = [self checkRecordRecreated:accountId fields:@{NAME:accountName} nameField:NAME soupName:ACCOUNTS_SOUP objectType:ACCOUNT_TYPE parentId:nil parentIdField:nil];
    
    // Check that db doesn't show contact entries as locally updated anymore
    NSDictionary * contactIdToFieldsCreated = [self getIdToFieldsByName:CONTACTS_SOUP fieldNames:@[LAST_NAME, ACCOUNT_ID] nameField:LAST_NAME names:contactNames];
    [self checkDbStateFlags:[contactIdToFieldsCreated allKeys] soupName:CONTACTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    // Check contacts on server
    [self checkServer:contactIdToFieldsCreated objectType:CONTACT_TYPE];
    
    // Check that contact use new account id in accountId field
    for (NSString* contactId in [contactIdToFieldsCreated allKeys]) {
        XCTAssertEqualObjects(contactIdToFieldsCreated[contactId][ACCOUNT_ID], newAccountId);
    }
    
    // Cleanup
    [self deleteRecordsOnServer:@[newAccountId] objectType:ACCOUNT_TYPE];
    [self deleteRecordsOnServer:[contactIdToFieldsCreated allKeys] objectType:CONTACT_TYPE];
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

/**
 * Create accounts and contacts on server, sync down
 * Update some of the accounts and contacts - using bad names (too long) for some
 * Sync up
 * Check smartstore and server afterwards
 */
- (void) testSyncUpWithErrors
{
    // Creating test accounts and contacts on server
    [self createAccountsAndContactsOnServer:3 numberContactsPerAccount:3];

    // Sync down
    SFParentChildrenSyncDownTarget * syncTarget = [self getAccountContactsSyncDownTargetWithParentSoqlFilter:
            [NSString stringWithFormat:@"Id IN %@", [self buildInClause:[accountIdContactIdToFields allKeys]]]];
    [self trySyncDown:SFSyncStateMergeModeOverwrite target:syncTarget soupName:ACCOUNTS_SOUP totalSize:3 numberFetches:1];

    // Picking accounts / contacts
    NSArray* accountIds = [accountIdToFields allKeys];
    NSString* account1Id = accountIds[0];
    NSArray* contactIdsOfAccount1 = [accountIdContactIdToFields[account1Id] allKeys];
    NSString* contact11Id = contactIdsOfAccount1[0];
    NSString* contact12Id = contactIdsOfAccount1[1];

    NSString* account2Id = accountIds[1];
    NSArray* contactIdsOfAccount2 = [accountIdContactIdToFields[account2Id] allKeys];
    NSString* contact21Id = contactIdsOfAccount2[0];
    NSString* contact22Id = contactIdsOfAccount2[1];

    // Build long suffix
    NSMutableString* suffixTooLong = [NSMutableString new];
    for (int i = 0; i < 255; i++) [suffixTooLong appendString:@"x"];

    // Updating with valid values
    NSDictionary * updatedAccount1Fields = [self updateRecordLocally:accountIdToFields[account1Id] idToUpdate:account1Id soupName:ACCOUNTS_SOUP][account1Id];
    NSDictionary * updatedContact11Fields = [self updateRecordLocally:accountIdContactIdToFields[account1Id][contact11Id] idToUpdate:contact11Id soupName:CONTACTS_SOUP][contact11Id];
    NSDictionary * updatedContact21Fields = [self updateRecordLocally:accountIdContactIdToFields[account2Id][contact22Id] idToUpdate:contact21Id soupName:CONTACTS_SOUP][contact21Id];

    // Updating with invalid values
    [self updateRecordLocally:accountIdToFields[account2Id] idToUpdate:account2Id soupName:ACCOUNTS_SOUP suffix:suffixTooLong];
    [self updateRecordLocally:accountIdContactIdToFields[account1Id][contact12Id] idToUpdate:contact12Id soupName:CONTACTS_SOUP suffix:suffixTooLong];
    [self updateRecordLocally:accountIdContactIdToFields[account2Id][contact22Id] idToUpdate:contact22Id soupName:CONTACTS_SOUP suffix:suffixTooLong];

    // Sync up
    [self trySyncUp:2 target:[self getAccountContactsSyncUpTarget] mergeMode:SFSyncStateMergeModeOverwrite];

    // Check valid records in db: should no longer be marked as dirty
    [self checkDbStateFlags:@[account1Id] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];
    [self checkDbStateFlags:@[contact11Id, contact21Id] soupName:CONTACTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    // Check invalid records in db
    // Should still be marked as dirty
    [self checkDbStateFlags:@[account2Id] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:YES expectedLocallyDeleted:NO];
    [self checkDbStateFlags:@[contact12Id, contact22Id] soupName:CONTACTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:YES expectedLocallyDeleted:NO];

    // Should have populated last error fields
    [self checkDbLastErrorField:@[ account2Id ] soupName:ACCOUNTS_SOUP lastErrorSubString:@"Account Name: data value too large"];
    [self checkDbLastErrorField:@[ contact12Id, contact22Id ] soupName:CONTACTS_SOUP lastErrorSubString:@"Last Name: data value too large"];

    // Check server
    NSMutableDictionary * accountIdToFieldsExpectedOnServer = [NSMutableDictionary new];
    for (NSString* id in accountIds) {
        // Only update to account1 should have gone through
        if ([id isEqualToString:account1Id]) {
            accountIdToFieldsExpectedOnServer[id] = updatedAccount1Fields;
        }
        else {
            accountIdToFieldsExpectedOnServer[id] = accountIdToFields[id];
        }
    }
    [self checkServer:accountIdToFieldsExpectedOnServer objectType:ACCOUNT_TYPE];

    NSMutableDictionary * contactIdToFieldsExpectedOnServer = [NSMutableDictionary new];
    for (NSString* id in accountIds) {
        NSDictionary * contactIdToFields = accountIdContactIdToFields[id];
        for (NSString* cid in [contactIdToFields allKeys]) {
            // Only update to contact11 and contact21 should have gone through
            if ([cid isEqualToString:contact11Id]) {
                contactIdToFieldsExpectedOnServer[cid] = updatedContact11Fields;
            } else if ([cid isEqualToString:contact21Id]) {
                contactIdToFieldsExpectedOnServer[cid] = updatedContact21Fields;
            } else {
                contactIdToFieldsExpectedOnServer[cid] = contactIdToFields[cid];
            }
        }
    }
    [self checkServer:contactIdToFieldsExpectedOnServer objectType:CONTACT_TYPE];
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
    NSOrderedSet* nonDirtyRecordIds = [target getNonDirtyRecordIds:self.syncManager soupName:ACCOUNTS_SOUP idField:ID additionalPredicate:@""];
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
    // Creating test accounts and contacts on server
    [self createAccountsAndContactsOnServer:numberAccounts numberContactsPerAccount:numberContactsPerAccount];

    // Sync down
    NSString *parentSoqlFilter = [NSString stringWithFormat:@"%@ IN %@", ID, [self buildInClause:[accountIdToFields allKeys]]];
    SFParentChildrenSyncDownTarget * syncDownTarget = [self getAccountContactsSyncDownTargetWithParentSoqlFilter:parentSoqlFilter];
    [self trySyncDown:SFSyncStateMergeModeOverwrite target:syncDownTarget soupName:ACCOUNTS_SOUP totalSize:numberAccounts numberFetches:1];

    // Pick an account and contact
    NSArray* accountIds = [accountIdToFields allKeys];
    NSString* accountId = accountIds[0];
    NSDictionary* accountFields = accountIdToFields[accountId];

    NSArray* contactIdsOfAccount = numberContactsPerAccount > 0 ? [((NSDictionary*)accountIdContactIdToFields[accountId]) allKeys] : nil;
    NSString* contactId = contactIdsOfAccount ? contactIdsOfAccount[0] : nil;
    NSString* otherContactId = contactIdsOfAccount ? contactIdsOfAccount[1] : nil;
    NSDictionary* contactFields = contactId ? accountIdContactIdToFields[accountId][contactId] : nil;

    // Build sync up target
    SFParentChildrenSyncUpTarget* syncUpTarget = [self getAccountContactsSyncUpTarget];

    // Apply localChangeForAccount
    NSDictionary * localUpdatesAccount = nil;
    switch (localChangeForAccount) {
        case NONE:
            break;
        case UPDATE:
            localUpdatesAccount = [self updateRecordLocally:accountFields idToUpdate:accountId soupName:ACCOUNTS_SOUP];
            break;
        case DELETE:
            [self deleteRecordsLocally:@[accountId] soupName:ACCOUNTS_SOUP];
            break;
    }

    // Apply localChangeForContact
    NSDictionary *localUpdatesContact = nil;
    if (contactId) {
        switch (localChangeForContact) {
            case NONE:
                break;
            case UPDATE:
                localUpdatesContact = [self updateRecordLocally:contactFields idToUpdate:contactId soupName:CONTACTS_SOUP];
                break;
            case DELETE:
                [self deleteRecordsLocally:@[contactId] soupName:CONTACTS_SOUP];
                break;
        }
    }

    // Sleep before doing remote changes
    if (remoteChangeForAccount != NONE || remoteChangeForContact != NONE) {
        [NSThread sleepForTimeInterval:1.0]; // time stamp precision is in seconds
    }

    // Apply remoteChangeForAccount
    NSDictionary *remoteUpdatesAccount = nil;
    switch (remoteChangeForAccount) {
        case NONE:
            break;
        case UPDATE:
            remoteUpdatesAccount = [self updateRecordOnServer:accountFields idToUpdate:accountId objectType:ACCOUNT_TYPE];
            break;
        case DELETE:
            [self deleteRecordsOnServer:@[accountId] objectType:ACCOUNT_TYPE];
            break;
    }

    NSDictionary *remoteUpdatesContact = nil;
    if (contactId) {
        switch (remoteChangeForContact) {
            case NONE:
                break;
            case UPDATE:
                remoteUpdatesContact = [self updateRecordOnServer:contactFields idToUpdate:contactId objectType:CONTACT_TYPE];

                break;
            case DELETE:
                [self deleteRecordsOnServer:@[contactId] objectType:CONTACT_TYPE];
                break;
        }
    }

    // Sync up

    // In some cases, leave-if-changed will succeed
    if ((remoteChangeForAccount == NONE || (remoteChangeForAccount == DELETE && localChangeForAccount == DELETE))          // no remote parent change or it's a delete and we did a local delete also
            && (remoteChangeForContact == NONE || (remoteChangeForContact == DELETE && localChangeForContact == DELETE)))  // no remote child change  or it's a delete and we did a local delete also
    {
        // Sync up with leave-if-changed
        [self trySyncUp:1 target:syncUpTarget mergeMode:SFSyncStateMergeModeLeaveIfChanged];

        // Check db and server - local changes should have made it over
        [self checkDbAndServerAfterCompletedSyncUp:accountId contactId:contactId otherContactId:otherContactId localChangeForAccount:localChangeForAccount remoteChangeForAccount:remoteChangeForAccount localChangeForContact:localChangeForContact remoteChangeForContact:remoteChangeForContact localUpdatesAccount:localUpdatesAccount localUpdatesContact:localUpdatesContact];

        // Sync up with overwrite - there should be dirty records found
        [self trySyncUp:0 target:syncUpTarget mergeMode:SFSyncStateMergeModeOverwrite];
    }
    // In all other cases, leave-if-changed will fail
    else {

        // Sync up with leave-if-changed
        [self trySyncUp:1 target:syncUpTarget mergeMode:SFSyncStateMergeModeLeaveIfChanged];

        // Check db and server - nothing should have changed
        [self checkDbAndServerAfterBlockedSyncUp:accountId contactId:contactId localChangeForAccount:localChangeForAccount remoteChangeForAccount:remoteChangeForAccount localChangeForContact:localChangeForContact remoteChangeForContact:remoteChangeForContact localUpdatesAccount:localUpdatesAccount remoteUpdatesAccount:remoteUpdatesAccount localUpdatesContact:localUpdatesContact remoteUpdatesContact:remoteUpdatesContact];

        // Sync up with overwrite
        [self trySyncUp:1 target:syncUpTarget mergeMode:SFSyncStateMergeModeOverwrite];

        // Check db and server - local changes should have made it over
        [self checkDbAndServerAfterCompletedSyncUp:accountId contactId:contactId otherContactId:otherContactId localChangeForAccount:localChangeForAccount remoteChangeForAccount:remoteChangeForAccount localChangeForContact:localChangeForContact remoteChangeForContact:remoteChangeForContact localUpdatesAccount:localUpdatesAccount localUpdatesContact:localUpdatesContact];
    }
}

- (void)checkDbAndServerAfterBlockedSyncUp:(NSString *)accountId
                                 contactId:(NSString *)contactId
                     localChangeForAccount:(SFSyncUpChange)localChangeForAccount
                    remoteChangeForAccount:(SFSyncUpChange)remoteChangeForAccount
                     localChangeForContact:(SFSyncUpChange)localChangeForContact
                    remoteChangeForContact:(SFSyncUpChange)remoteChangeForContact
                       localUpdatesAccount:(NSDictionary *)localUpdatesAccount
                      remoteUpdatesAccount:(NSDictionary *)remoteUpdatesAccount
                       localUpdatesContact:(NSDictionary *)localUpdatesContact
                      remoteUpdatesContact:(NSDictionary *)remoteUpdatesContact {

    //
    // Check parent
    //

    // Check db
    if (localChangeForAccount == UPDATE) {
        [self checkDb:localUpdatesAccount soupName:ACCOUNTS_SOUP];
    }

    [self checkDbStateFlags:@[accountId] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:localChangeForAccount == UPDATE expectedLocallyDeleted:localChangeForAccount == DELETE];

    // Check server
    switch (remoteChangeForAccount) {
        case NONE:
            break;
        case UPDATE:
            [self checkServer:remoteUpdatesAccount objectType:ACCOUNT_TYPE];
            break;
        case DELETE:
            [self checkServerDeleted:@[accountId] objectType:ACCOUNT_TYPE];
            break;
    }

    //
    // Check children if any
    //

    if (contactId) {
        NSArray *contactIdsOfAccounts = [((NSDictionary *) accountIdContactIdToFields[accountId]) allKeys];
        NSMutableArray* otherContactIdsOfAccount = [contactIdsOfAccounts mutableCopy];
        [otherContactIdsOfAccount removeObject:contactId];

        // Check db

        if (localChangeForContact == UPDATE) {
            [self checkDb:localUpdatesContact soupName:CONTACTS_SOUP];
        }

        [self checkDbStateFlags:@[contactId] soupName:CONTACTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:localChangeForContact == UPDATE expectedLocallyDeleted:localChangeForContact == DELETE];
        [self checkDbRelationshipsWithChildrenIds:contactIdsOfAccounts expectedParentId:accountId soupName:CONTACTS_SOUP idFieldName:ID parentIdFieldName:ACCOUNT_ID];

        // Check server

        if (remoteChangeForAccount == DELETE) {
            // Master delete => deletes children
            [self checkServerDeleted:contactIdsOfAccounts objectType:CONTACT_TYPE];
        }
        else {
            switch (remoteChangeForContact) {
                case NONE:
                    break;
                case UPDATE:
                    [self checkServer:remoteUpdatesContact objectType:CONTACT_TYPE];
                    break;
                case DELETE:
                    [self checkServerDeleted:@[contactId] objectType:CONTACT_TYPE];
                    break;
            }
        }
    }
}


- (void)checkDbAndServerAfterCompletedSyncUp:(NSString *)accountId
                                   contactId:(NSString *)contactId
                              otherContactId:(NSString *)otherContactId
                       localChangeForAccount:(SFSyncUpChange)localChangeForAccount
                      remoteChangeForAccount:(SFSyncUpChange)remoteChangeForAccount
                       localChangeForContact:(SFSyncUpChange)localChangeForContact
                      remoteChangeForContact:(SFSyncUpChange)remoteChangeForContact
                         localUpdatesAccount:(NSDictionary *)localUpdatesAccount
                         localUpdatesContact:(NSDictionary *)localUpdatesContact {

    NSString* newAccountId = nil;
    NSString* newContactId = nil;
    NSString* newOtherContactId = nil;

    //
    // Check parent
    //

    switch (localChangeForAccount) {
        case NONE:
            [self checkRecordAfterSync:accountId fields:accountIdToFields[accountId] soupName:ACCOUNTS_SOUP objectType:ACCOUNT_TYPE parentId:nil parentIdField:nil];
            break;
        case UPDATE:
            if (remoteChangeForAccount == DELETE) {
                newAccountId = [self checkRecordRecreated:accountId fields:localUpdatesAccount[accountId] nameField:NAME soupName:ACCOUNTS_SOUP objectType:ACCOUNT_TYPE parentId:nil parentIdField:nil];
            } else {
                [self checkRecordAfterSync:accountId fields:localUpdatesAccount[accountId] soupName:ACCOUNTS_SOUP objectType:ACCOUNT_TYPE parentId:nil parentIdField:nil];
            }
            break;
        case DELETE:
            [self checkDeletedRecordAfterSync:accountId soupName:ACCOUNTS_SOUP objectType:ACCOUNT_TYPE];
            break;
    }

    //
    // Check children if any
    //

    if (contactId) {

        if (localChangeForAccount == DELETE) {
            // Master delete => deletes children
            NSArray *contactIdsOfAcccount = [((NSDictionary *) accountIdContactIdToFields[accountId]) allKeys];
            [self checkDbDeleted:CONTACTS_SOUP ids:contactIdsOfAcccount idField:ID];
            [self checkServerDeleted:contactIdsOfAcccount objectType:CONTACT_TYPE];
        } else {
            switch (localChangeForContact) {
                case NONE:
                    if (remoteChangeForAccount == DELETE || remoteChangeForContact == DELETE) {
                        newContactId = [self checkRecordRecreated:contactId fields:accountIdContactIdToFields[accountId][contactId] nameField:LAST_NAME soupName:CONTACTS_SOUP objectType:CONTACT_TYPE parentId:(newAccountId ? newAccountId : accountId) parentIdField:ACCOUNT_ID];
                    } else {
                        [self checkRecordAfterSync:contactId fields:accountIdContactIdToFields[accountId][contactId] soupName:CONTACTS_SOUP objectType:CONTACT_TYPE parentId:accountId parentIdField:ACCOUNT_ID];
                    }
                    break;
                case UPDATE:
                    if (remoteChangeForAccount == DELETE || remoteChangeForContact == DELETE) {
                        newContactId = [self checkRecordRecreated:contactId fields:localUpdatesContact[contactId] nameField:LAST_NAME soupName:CONTACTS_SOUP objectType:CONTACT_TYPE parentId:(newAccountId ? newAccountId : accountId) parentIdField:ACCOUNT_ID];
                    } else {
                        [self checkRecordAfterSync:contactId fields:localUpdatesContact[contactId] soupName:CONTACTS_SOUP objectType:CONTACT_TYPE parentId:accountId parentIdField:ACCOUNT_ID];
                    }
                    break;
                case DELETE:
                    [self checkDeletedRecordAfterSync:contactId soupName:CONTACTS_SOUP objectType:CONTACT_TYPE];
                    break;
            }

            if (remoteChangeForAccount == DELETE) {
                // Check that other contact was recreated also
                newOtherContactId = [self checkRecordRecreated:otherContactId fields:accountIdContactIdToFields[accountId][otherContactId] nameField:LAST_NAME soupName:CONTACTS_SOUP objectType:CONTACT_TYPE parentId:newAccountId parentIdField:ACCOUNT_ID];
            }

        }
    }

    // Cleaning "recreated" records
    if (newAccountId) [self deleteRecordsOnServer:@[newAccountId] objectType:ACCOUNT_TYPE];
    if (newContactId) [self deleteRecordsOnServer:@[newContactId] objectType:CONTACT_TYPE];
    if (newOtherContactId) [self deleteRecordsOnServer:@[newOtherContactId] objectType:CONTACT_TYPE];
}

- (NSString*) checkRecordRecreated:(NSString*)recordId 
                            fields:(NSDictionary*)fields 
                         nameField:(NSString*)nameField 
                          soupName:(NSString*)soupName 
                        objectType:(NSString*)objectType 
                          parentId:(NSString*)parentId 
                     parentIdField:(NSString*)parentIdField {
    NSString* updatedName = fields[nameField];
    NSDictionary *newIdToFields = [self getIdToFieldsByName:soupName fieldNames:@[nameField] nameField:nameField names:@[updatedName]];
    NSString* newRecordId = [newIdToFields allKeys][0];

    // Make sure new id is really new
    XCTAssertNotEqualObjects(newRecordId, recordId, @"Record should have new id");

    // Make sure old id is gone from db and server
    [self checkDbDeleted:soupName ids:@[recordId] idField:ID];
    [self checkServerDeleted:@[recordId] objectType:objectType];

    // Make sure record with new id is correct in db and server
    [self checkRecordAfterSync:newRecordId fields:newIdToFields[newRecordId] soupName:soupName objectType:objectType parentId:parentId parentIdField:parentIdField];

    return newRecordId;
}

-(void) checkRecordAfterSync:(NSString*)recordId
                      fields:(NSDictionary*)fields
                    soupName:(NSString*)soupName
                  objectType:(NSString*)objectType
                    parentId:(NSString*)parentId
               parentIdField:(NSString*)parentIdField {

    // Check record is no longer marked as dirty
    [self checkDbStateFlags:@[recordId] soupName:soupName expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    // Prepare fields map to check (add parentId if provided)
    NSMutableDictionary * fieldsCopy = [fields mutableCopy];
    if (parentId) {
        fieldsCopy[parentIdField] = parentId;
    }
    NSMutableDictionary * idToFields = [NSMutableDictionary new];
    idToFields[recordId] = fieldsCopy;

    // Check db
    [self checkDb:idToFields soupName:soupName];

    // Check server
    [self checkServer:idToFields objectType:objectType];
}


- (void) checkDeletedRecordAfterSync:(NSString*)recordId
                            soupName:(NSString*)soupName
                          objectType:(NSString*)objectType {
 
    [self checkDbDeleted:soupName ids:@[recordId] idField:ID];
    [self checkServerDeleted:@[recordId] objectType:objectType];
}


/**
 * Helper method for testSyncUpWithLocallyCreatedRecords*
 */
- (void)trySyncUpWithLocallyCreatedRecords:(enum SFSyncStateMergeMode)mergeMode {
    NSUInteger numberContactsPerAccount = 3;

    // Create a few entries locally
    NSArray<NSString *> *accountNames = @[
            [self createAccountName],
            [self createAccountName],
            [self createAccountName],
            [self createAccountName],
            [self createAccountName]
    ];

    NSDictionary *mapAccountToContacts = [self createAccountsAndContactsLocally:accountNames numberOfContactsPerAccount:numberContactsPerAccount];
    NSMutableArray* contactNames = [NSMutableArray new];
    for (NSArray* contacts in [mapAccountToContacts allValues]) {
        for (NSDictionary* contact in contacts) {
            [contactNames addObject:contact[LAST_NAME]];
        }
    }

    // Sync up
    SFParentChildrenSyncUpTarget* target = [self getAccountContactsSyncUpTarget];
    [self trySyncUp:accountNames.count target:target mergeMode:mergeMode];

    // Check that db doesn't show account entries as locally created anymore and that they use sfdc id
    NSDictionary* accountIdToFieldsCreated = [self getIdToFieldsByName:ACCOUNTS_SOUP fieldNames:@[NAME, DESCRIPTION] nameField:NAME names:accountNames];
    [self checkDbStateFlags:[accountIdToFieldsCreated allKeys] soupName:ACCOUNTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    // Check accounts on server
    [self checkServer:accountIdToFieldsCreated objectType:ACCOUNT_TYPE];

    // Check that db doesn't show contact entries as locally created anymore and that they use sfc id
    NSDictionary* contactIdToFieldsCreated = [self getIdToFieldsByName:CONTACTS_SOUP fieldNames:@[LAST_NAME, ACCOUNT_ID] nameField:LAST_NAME names:contactNames];
    [self checkDbStateFlags:[contactIdToFieldsCreated allKeys] soupName:CONTACTS_SOUP expectedLocallyCreated:NO expectedLocallyUpdated:NO expectedLocallyDeleted:NO];

    // Check contacts on server
    [self checkServer:contactIdToFieldsCreated objectType:CONTACT_TYPE];

    // Cleanup
    [self deleteRecordsOnServer:[accountIdToFieldsCreated allKeys] objectType:ACCOUNT_TYPE];
    [self deleteRecordsOnServer:[contactIdToFieldsCreated allKeys] objectType:CONTACT_TYPE];
}

- (SFParentChildrenSyncUpTarget *)getAccountContactsSyncUpTarget {
    return [self getAccountContactsSyncUpTargetWithParentSoqlFilter:@""];
}

- (SFParentChildrenSyncUpTarget *)getAccountContactsSyncUpTargetWithParentSoqlFilter:(NSString*)parentSoqlFilter {
    return [self getAccountContactsSyncUpTargetWithParentSoqlFilter:parentSoqlFilter accountModificationDateFieldName:LAST_MODIFIED_DATE contactModificationDateFieldName:LAST_MODIFIED_DATE];
}

- (SFParentChildrenSyncUpTarget *)getAccountContactsSyncUpTargetWithParentSoqlFilter:(NSString*)parentSoqlFilter
                                                    accountModificationDateFieldName:(NSString*)accountModificationDateFieldName
                                                    contactModificationDateFieldName:(NSString*)contactModificationDateFieldName {


    SFParentChildrenSyncUpTarget *target = [SFParentChildrenSyncUpTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:ACCOUNT_TYPE soupName:ACCOUNTS_SOUP idFieldName:ID modificationDateFieldName:accountModificationDateFieldName]
                        parentCreateFieldlist:@[ID, NAME, DESCRIPTION]
                  parentUpdateFieldlist:@[NAME, DESCRIPTION]
                           childrenInfo:[SFChildrenInfo newWithSObjectType:CONTACT_TYPE sobjectTypePlural:CONTACT_TYPE_PLURAL soupName:CONTACTS_SOUP parentIdFieldName:ACCOUNT_ID idFieldName:ID modificationDateFieldName:contactModificationDateFieldName]
                      childrenCreateFieldlist:@[LAST_NAME, ACCOUNT_ID]
            childrenUpdateFieldlist:@[LAST_NAME, ACCOUNT_ID]
                       relationshipType:SFParentChildrenRelationpshipMasterDetail]; // account-contacts are master-detail
    return target;
}

@end
