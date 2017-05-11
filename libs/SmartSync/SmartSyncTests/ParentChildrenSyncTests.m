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

#import "SyncManagerTestCase.h"
#import "SFParentChildrenSyncDownTarget.h"
#import "SFSmartSyncObjectUtils.h"

@interface SFParentChildrenSyncDownTarget ()

- (NSString *)getSoqlForRemoteIds;
- (NSString*) getDirtyRecordIdsSql:(NSString*)soupName idField:(NSString*)idField;
- (NSString*) getNonDirtyRecordIdsSql:(NSString*)soupName idField:(NSString*)idField;
- (NSOrderedSet *)getNonDirtyRecordIds:(SFSmartSyncSyncManager *)syncManager soupName:(NSString *)soupName idField:(NSString *)idField;

@end

@interface ParentChildrenSyncTests : SyncManagerTestCase

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

    NSDictionary<NSDictionary *, NSArray<NSDictionary *> *> *mapAccountToContacts = [self createAccountsAndContactsLocally:accountNames numberOfContactsPerAccount:3];
    NSArray<NSDictionary *>* accounts = [mapAccountToContacts allKeys];

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

#pragma mark - Helper methods

- (void)createTestData {
    [self createAccountsSoup];
    [self createContactsSoup];
}

- (void)deleteTestData {
    [self dropAccountsSoup];
    [self dropContactsSoup];
}

- (NSDictionary<NSDictionary*, NSArray<NSDictionary*>*>*) createAccountsAndContactsLocally:(NSArray<NSString*>*)names
                                                                numberOfContactsPerAccount:(NSUInteger)numberOfContactsPerAccount
{
    NSArray<NSDictionary *>* accounts = [self createAccountsLocally:names];
    NSMutableArray * accountIds = [NSMutableArray new];
    for (NSDictionary * account in accounts) {
        [accountIds addObject:account[ID]];
    }

    NSDictionary<NSDictionary *, NSArray<NSDictionary *> *> *accountIdsToContacts = [self createContactsForAccountsLocally:numberOfContactsPerAccount accountIds:accountIds];

    NSMutableDictionary<NSDictionary*, NSArray<NSDictionary*>*>* accountToContacts = [NSMutableDictionary new];

    for (NSDictionary * account in accounts) {
        accountToContacts[account] = accountIdsToContacts[account[ID]];
    }
    return accountToContacts;
}

- (NSDictionary<NSDictionary*, NSArray<NSDictionary*>*>*) createContactsForAccountsLocally:(NSUInteger)numberOfContactsPerAccount
                                                                                accountIds:(NSArray<NSString*>*)accountIds
{
    NSMutableDictionary<NSDictionary *, NSArray<NSDictionary *> *> *accountIdsToContacts = [NSMutableDictionary new];

    NSDictionary *attributes = @{TYPE: ACCOUNT_TYPE};
    for (NSString *accountId in accountIds) {
        NSMutableArray<NSDictionary *>* contacts = [NSMutableArray new];
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
    return [self getAccountContactsSyncDownTarget:@""];
}

- (SFParentChildrenSyncDownTarget*) getAccountContactsSyncDownTarget:(NSString*) parentSoqlFilter {
    return [self getAccountContactsSyncDownTarget:LAST_MODIFIED_DATE contactModificationDateFieldName:LAST_MODIFIED_DATE parentSoqlFilter:parentSoqlFilter];
}

- (SFParentChildrenSyncDownTarget*) getAccountContactsSyncDownTarget:(NSString*) accountModificationDateFieldName
                                    contactModificationDateFieldName:(NSString*) contactModificationDateFieldName
                                                    parentSoqlFilter:(NSString*) parentSoqlFilter {

    SFParentChildrenSyncDownTarget *target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:ACCOUNT_TYPE soupName:ACCOUNTS_SOUP idFieldName:ID modificationDateFieldName:accountModificationDateFieldName]
                        parentFieldlist:@[ID, NAME, DESCRIPTION]
                       parentSoqlFilter:parentSoqlFilter
                           childrenInfo:[SFChildrenInfo newWithSObjectType:CONTACT_TYPE sobjectTypePlural:@"Contacts" soupName:CONTACTS_SOUP parentIdFieldName:ACCOUNT_ID idFieldName:ID modificationDateFieldName:LAST_MODIFIED_DATE]
                      childrenFieldlist:@[LAST_NAME, ACCOUNT_ID]
                       relationshipType:SFParentChildrenRelationpshipMasterDetail]; // account-contacts are master-detail
    return target;
}

@end
