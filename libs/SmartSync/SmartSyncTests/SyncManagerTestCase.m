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
#import "SFSyncUpdateCallbackQueue.h"
#import <SalesforceSDKCore/SFSDKTestRequestListener.h>
#import <SmartStore/SFSoupIndex.h>
#import <SmartStore/SFSmartStore.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/TestSetupUtils.h>
#import "TestSyncUpTarget.h"
#import "SyncManagerTestCase.h"

static NSException *authException = nil;

@implementation SyncManagerTestCase

+ (void)setUp
{
    @try {
        [SFSDKSmartSyncLogger setLogLevel:DDLogLevelDebug];
        [TestSetupUtils populateAuthCredentialsFromConfigFileForClass:[self class]];
        [TestSetupUtils synchronousAuthRefresh];
        [SFSmartStore removeAllStores];

    } @catch (NSException *exception) {
        [SFSDKSmartSyncLogger d:[self class] format:@"Populating auth from config failed: %@", exception];
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

    // User and managers setup
    self.currentUser = [SFUserAccountManager sharedInstance].currentUser;
    self.syncManager = [SFSmartSyncSyncManager sharedInstance:self.currentUser];
    self.store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName user:self.currentUser];
    self.globalStore = [SFSmartStore sharedGlobalStoreWithName:kDefaultSmartStoreName];
    self.globalSyncManager = [SFSmartSyncSyncManager sharedInstanceForStore:self.globalStore];

    [super setUp];
}

- (void)tearDown
{
    // User and managers tear down
    [self deleteSyncs];
    [self deleteGlobalSyncs];
    [SFSmartSyncSyncManager removeSharedInstance:self.currentUser];
    [[SFRestAPI sharedInstance] cleanup];
    [SFRestAPI setIsTestRun:NO];

    self.currentUser = nil;
    self.syncManager = nil;
    self.store = nil;

    // Some test runs were failing, saying the run didn't complete. This seems to fix that.
    [NSThread sleepForTimeInterval:0.1];
    [super tearDown];
}

- (void)deleteSyncs
{
    [self.store clearSoup:kSFSyncStateSyncsSoupName];
}

- (void)deleteGlobalSyncs
{
    [self.globalStore clearSoup:kSFSyncStateSyncsSoupName];
}

- (NSString*)createRecordName:(NSString*)objectType {
    return [NSString stringWithFormat:@"SyncManagerTestCase_%@_%08d", objectType, arc4random_uniform(100000000)];
}

- (NSString*) createAccountName {
    return [self createRecordName:ACCOUNT_TYPE];
}


- (NSArray*) createAccountsLocally:(NSArray*)names {
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
        account[kSyncTargetLocal] = @YES;
        account[kSyncTargetLocallyCreated] = @YES;
        account[kSyncTargetLocallyDeleted] = @NO;
        account[kSyncTargetLocallyUpdated] = @NO;
        [createdAccounts addObject:account];
    }
    return [self.store upsertEntries:createdAccounts toSoup:ACCOUNTS_SOUP];
}

- (NSString*) createLocalId {
    return [NSString stringWithFormat:@"local_%08d", arc4random_uniform(100000000)];
}

- (void)createAccountsSoup {
    NSArray* indexSpecs = @[
                            [[SFSoupIndex alloc] initWithPath:ID indexType:kSoupIndexTypeString columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:NAME indexType:kSoupIndexTypeString columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:DESCRIPTION indexType:kSoupIndexTypeFullText columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:kSyncTargetLocal indexType:kSoupIndexTypeString columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:kSyncTargetSyncId indexType:kSoupIndexTypeInteger columnName:nil]
                            ];
    [self.store registerSoup:ACCOUNTS_SOUP withIndexSpecs:indexSpecs error:nil];
}

- (void)dropAccountsSoup{
    [self.store removeSoup:ACCOUNTS_SOUP];
}

- (void)createContactsSoup {
    NSArray* indexSpecs = @[
            [[SFSoupIndex alloc] initWithPath:ID indexType:kSoupIndexTypeString columnName:nil],
            [[SFSoupIndex alloc] initWithPath:LAST_NAME indexType:kSoupIndexTypeString columnName:nil],
            [[SFSoupIndex alloc] initWithPath:ACCOUNT_ID indexType:kSoupIndexTypeString columnName:nil],
            [[SFSoupIndex alloc] initWithPath:kSyncTargetLocal indexType:kSoupIndexTypeString columnName:nil],
            [[SFSoupIndex alloc] initWithPath:kSyncTargetSyncId indexType:kSoupIndexTypeInteger columnName:nil]
    ];
    [self.store registerSoup:CONTACTS_SOUP withIndexSpecs:indexSpecs error:nil];
}

- (void)dropContactsSoup{
    [self.store removeSoup:CONTACTS_SOUP];
}

- (NSString*) buildInClause:(NSArray*)values {
    return [NSString stringWithFormat:@"('%@')", [values componentsJoinedByString:@"', '"]];
}

- (void)deleteRecordsOnServer:(NSArray *)ids objectType:(NSString*)objectType {

    NSMutableArray* requests = [NSMutableArray new];
    for (NSString* recordId in ids) {
        SFRestRequest *deleteRequest = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:objectType objectId:recordId];
        [requests addObject:deleteRequest];
        if (requests.count == 25) {
            [self sendSyncRequest:[[SFRestAPI sharedInstance] batchRequest:requests haltOnError:NO]];
            [requests removeAllObjects];
        }
    }
    if (requests.count > 0) {
        [self sendSyncRequest:[[SFRestAPI sharedInstance] batchRequest:requests haltOnError:NO]];
    }
}

- (NSDictionary*)sendSyncRequest:(SFRestRequest*)request {
    return [self sendSyncRequest:request ignoreNotFound:NO];
}

- (NSDictionary*)sendSyncRequest:(SFRestRequest*)request ignoreNotFound:(BOOL)ignoreNotFound {
    SFSDKTestRequestListener *listener = [[SFSDKTestRequestListener alloc] init];
    SFRestFailBlock failBlock = ^(NSError *error, NSURLResponse *rawResponse) {
        listener.lastError = error;
        listener.returnStatus = kTestRequestStatusDidFail;

    };
    SFRestDictionaryResponseBlock completeBlock = ^(NSDictionary *data, NSURLResponse *rawResponse) {
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


-(NSArray*) buildFieldsMapForRecords:(NSUInteger)count objectType:(NSString*)objectType additionalFields:(NSDictionary*)additionalFields
{
    NSMutableArray* listFields = [NSMutableArray new];
    for (NSUInteger i = 0; i < count; i++) {

        // Request
        NSString* name = [self createRecordName:objectType];
        NSMutableDictionary * fields = [NSMutableDictionary new];

        // Add additional fields if any
        if (additionalFields) {
            [fields addEntriesFromDictionary:additionalFields];
        }

        // Add more object type if need to support to use this API
        // to create a new record on server
        if ([objectType isEqualToString:ACCOUNT_TYPE]) {
            fields[NAME] = name;
            fields[DESCRIPTION] = [self createDescription:name];
        }
        else if ([objectType isEqualToString:CONTACT_TYPE]) {
            fields[LAST_NAME] = name;
        }

        [listFields addObject:fields];
    }

    return listFields;
}

- (NSString *)createDescription:(NSString *)name {
    return [@[@"Description", name] componentsJoinedByString:@"_"];
}

- (NSDictionary*)createAccountsOnServer:(NSUInteger)count {
    return [self createRecordsOnServerReturnFields:count objectType:ACCOUNT_TYPE additionalFields:nil];
}

 - (NSDictionary<NSString*, NSString*>*) createRecordsOnServer:(NSUInteger)count objectType:(NSString*)objectType {
     NSDictionary<NSString *, NSDictionary *> *idToFields = [self createRecordsOnServerReturnFields:count objectType:objectType additionalFields:nil];
     NSMutableDictionary * idToNames = [NSMutableDictionary new];
     for (NSString * recordId in [idToFields allKeys]) {
         NSString* nameField = [objectType isEqualToString:CONTACT_TYPE] ? LAST_NAME : NAME;
         idToNames[recordId] = idToFields[recordId][nameField];
     }
     return idToNames;
}

- (NSDictionary<NSString*, NSDictionary*>*) createRecordsOnServerReturnFields:(NSUInteger)count objectType:(NSString*)objectType additionalFields:(NSDictionary*)additionalFields {
    NSArray *listFields = [self buildFieldsMapForRecords:count objectType:objectType additionalFields:additionalFields];
    NSMutableArray *requests = [NSMutableArray new];
    for (NSUInteger i = 0; i < count; i++) {
        [requests addObject:[[SFRestAPI sharedInstance] requestForCreateWithObjectType:objectType fields:listFields[i]]];
    }

    NSMutableDictionary *idToFields = [NSMutableDictionary new];
    NSDictionary *batchResponse = [self sendSyncRequest:[[SFRestAPI sharedInstance] batchRequest:requests haltOnError:NO]];
    NSArray *results = batchResponse[@"results"];
    for (NSUInteger i = 0; i < results.count; i++) {
        NSDictionary *result = results[i];
        XCTAssertEqual(201, [result[@"statusCode"] intValue], "Status code should be HTTP_CREATED");
        idToFields[result[@"result"][@"id"]] = listFields[i];
    }

    return idToFields;
}

- (NSInteger)trySyncDown:(SFSyncStateMergeMode)mergeMode target:(SFSyncDownTarget*)target soupName:(NSString*)soupName totalSize:(NSUInteger)totalSize numberFetches:(NSUInteger)numberFetches {

    // Creates sync.
    SFSyncOptions* options = [SFSyncOptions newSyncOptionsForSyncDown:mergeMode];
    SFSyncState* sync = [SFSyncState newSyncDownWithOptions:options target:target soupName:soupName name:nil store:self.store];
    NSInteger syncId = sync.syncId;
    [self checkStatus:sync expectedType:SFSyncStateSyncTypeDown expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusNew expectedProgress:0 expectedTotalSize:-1];

    // Runs sync.
    SFSyncUpdateCallbackQueue* queue = [[SFSyncUpdateCallbackQueue alloc] init];
    [queue runSync:sync syncManager:self.syncManager];

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

- (void)checkStatus:(SFSyncState *)sync expectedType:(SFSyncStateSyncType)expectedType expectedId:(NSInteger)expectedId expectedTarget:(SFSyncTarget *)expectedTarget expectedOptions:(SFSyncOptions *)expectedOptions expectedStatus:(SFSyncStateStatus)expectedStatus expectedProgress:(NSInteger)expectedProgress expectedTotalSize:(NSInteger)expectedTotalSize {
    [self checkStatus:sync expectedType:expectedType expectedId:expectedId expectedName:nil expectedTarget:expectedTarget expectedOptions:expectedOptions expectedStatus:expectedStatus expectedProgress:expectedProgress expectedTotalSize:expectedTotalSize];
}

- (void)checkStatus:(SFSyncState *)sync expectedType:(SFSyncStateSyncType)expectedType expectedId:(NSInteger)expectedId expectedName:(NSString *)expectedName expectedTarget:(SFSyncTarget *)expectedTarget expectedOptions:(SFSyncOptions *)expectedOptions expectedStatus:(SFSyncStateStatus)expectedStatus expectedProgress:(NSInteger)expectedProgress expectedTotalSize:(NSInteger)expectedTotalSize {
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
            } else if (expectedQueryType == SFSyncDownTargetQueryTypeMetadata) {
                XCTAssertTrue([sync.target isKindOfClass:[SFMetadataSyncDownTarget class]]);
                XCTAssertEqualObjects(((SFMetadataSyncDownTarget*)expectedTarget).objectType, ((SFMetadataSyncDownTarget*)sync.target).objectType);
            } else if (expectedQueryType == SFSyncDownTargetQueryTypeLayout) {
                XCTAssertTrue([sync.target isKindOfClass:[SFLayoutSyncDownTarget class]]);
                XCTAssertEqualObjects(((SFLayoutSyncDownTarget*)expectedTarget).objectType, ((SFLayoutSyncDownTarget*)sync.target).objectType);
                XCTAssertEqualObjects(((SFLayoutSyncDownTarget*)expectedTarget).layoutType, ((SFLayoutSyncDownTarget*)sync.target).layoutType);
            } else if (expectedQueryType == SFSyncDownTargetQueryTypeCustom) {
                XCTAssertTrue([sync.target isKindOfClass:[SFSyncDownTarget class]]);
            }
        } else {
            XCTAssertTrue([sync.target isKindOfClass:[SFSyncUpTarget class]]);
            XCTAssertEqualObjects(((SFSyncUpTarget*)expectedTarget).createFieldlist, ((SFSyncUpTarget*)sync.target).createFieldlist);
            XCTAssertEqualObjects(((SFSyncUpTarget*)expectedTarget).updateFieldlist, ((SFSyncUpTarget*)sync.target).updateFieldlist);
        }
    } else {
        XCTAssertNil(sync.target);
    }
    if (expectedOptions) {
        XCTAssertNotNil(sync.options);
        XCTAssertEqual(expectedOptions.mergeMode, sync.options.mergeMode);
        XCTAssertEqualObjects(expectedOptions.fieldlist, sync.options.fieldlist);
    } else {
        XCTAssertNil(sync.options);
    }
    if (sync.status != SFSyncStateStatusNew) {
        XCTAssertTrue(sync.startTime > 0);
    }
    if (sync.status == SFSyncStateStatusDone || sync.status == SFSyncStateStatusFailed) {
        XCTAssertTrue(sync.endTime > 0);
        XCTAssertTrue(sync.endTime > sync.startTime);
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

- (void)checkDbExists:(NSString*)soupName ids:(NSArray*)ids idField:(NSString*)idField {
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {%@:_soup} FROM {%@} WHERE {%@:%@} IN %@",
                                                    soupName, soupName, soupName, idField, [self buildInClause:ids]];

    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rowsFromDb = [self.store queryWithQuerySpec:query pageIndex:0 error:nil];
    XCTAssertEqual(ids.count, rowsFromDb.count, "All records should have been returned from smartstore");
}


- (void)checkDb:(NSDictionary*)expectedIdToFields soupName:(NSString*)soupName {

    // Ids clause
    NSString* idsClause = [self buildInClause:[expectedIdToFields allKeys]];

    // Query
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {%@:_soup} FROM {%@} WHERE {%@:Id} IN %@", soupName, soupName, soupName, idsClause];

    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:expectedIdToFields.count];
    NSArray* rows = [self.store queryWithQuerySpec:query pageIndex:0 error:nil];
    XCTAssertEqual(expectedIdToFields.count, rows.count);
    for (NSArray* row in rows) {
        NSDictionary * recordFromDb = row[0];
        NSString* recordId = recordFromDb[ID];
        NSDictionary * expectedFields = expectedIdToFields[recordId];
        for (NSString* fieldName in [expectedFields allKeys]) {
            XCTAssertEqualObjects(expectedFields[fieldName], recordFromDb[fieldName]);
        }
    }
}

- (void)checkDbStateFlags:(NSArray *)ids
                 soupName:(NSString *)soupName
   expectedLocallyCreated:(bool)expectedLocallyCreated
   expectedLocallyUpdated:(bool)expectedLocallyUpdated
   expectedLocallyDeleted:(bool)expectedLocallyDeleted {

    BOOL expectedDirty = expectedLocallyCreated||expectedLocallyUpdated||expectedLocallyDeleted;

    // Ids clause
    NSString* idsClause = [self buildInClause:ids];

    // Query
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {%@:_soup} FROM {%@} WHERE {%@:Id} IN %@", soupName, soupName, soupName, idsClause];

    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rows = [self.store queryWithQuerySpec:query pageIndex:0 error:nil];
    XCTAssertEqual(ids.count, rows.count);
    for (NSArray* row in rows) {
        NSDictionary *recordFromDb = row[0];
        XCTAssertEqualObjects(@(expectedDirty), recordFromDb[kSyncTargetLocal]);
        XCTAssertEqualObjects(@(expectedLocallyCreated), recordFromDb[kSyncTargetLocallyCreated]);
        XCTAssertEqualObjects(@(expectedLocallyUpdated), recordFromDb[kSyncTargetLocallyUpdated]);
        XCTAssertEqualObjects(@(expectedLocallyDeleted), recordFromDb[kSyncTargetLocallyDeleted]);
        NSString* id = recordFromDb[ID];
        bool hasLocalIdPrefix = [id hasPrefix:LOCAL_ID_PREFIX];
        XCTAssertEqual(expectedLocallyCreated, hasLocalIdPrefix);

        // Last error field should be empty for a clean record
        if (!expectedDirty) {
            XCTAssertTrue([recordFromDb[kSyncTargetLastError] length] == 0, "Last error should be empty");
        }
    }
}

- (void)checkDbSyncIdField:(NSArray *)ids
                  soupName:(NSString *)soupName
                    syncId:(NSNumber*)syncId {

    // Ids clause
    NSString* idsClause = [self buildInClause:ids];

    // Query
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {%@:_soup} FROM {%@} WHERE {%@:Id} IN %@", soupName, soupName, soupName, idsClause];

    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rows = [self.store queryWithQuerySpec:query pageIndex:0 error:nil];
    XCTAssertEqual(ids.count, rows.count);
    for (NSArray* row in rows) {
        NSDictionary *recordFromDb = row[0];
        XCTAssertEqualObjects(syncId, recordFromDb[kSyncTargetSyncId]);
    }
}

- (void)checkDbLastErrorField:(NSArray *)ids
                  soupName:(NSString *)soupName
        lastErrorSubString:(NSString*)lastErrorSubString {

    // Ids clause
    NSString* idsClause = [self buildInClause:ids];

    // Query
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {%@:_soup} FROM {%@} WHERE {%@:Id} IN %@", soupName, soupName, soupName, idsClause];

    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rows = [self.store queryWithQuerySpec:query pageIndex:0 error:nil];
    XCTAssertEqual(ids.count, rows.count);
    for (NSArray* row in rows) {
        NSDictionary *recordFromDb = row[0];
        NSString* lastErrorInDb = recordFromDb[kSyncTargetLastError];
        XCTAssertTrue([lastErrorInDb containsString:lastErrorSubString]);
    }
}

- (NSDictionary *)makeSomeLocalChanges:(NSDictionary *)idToFields soupName:(NSString *)soupName {
    NSArray* allIds = [[idToFields allKeys] sortedArrayUsingSelector:@selector(compare:)];
    return [self makeSomeLocalChanges:idToFields soupName:soupName idsToUpdate:@[allIds[0], allIds[2]]];
}

- (NSDictionary*) makeSomeLocalChanges:(NSDictionary*)idToFields soupName:(NSString*) soupName idsToUpdate:(NSArray*)idsToUpdate {
    NSDictionary* idToFieldsLocallyUpdated = [self prepareSomeChanges:idToFields idsToUpdate:idsToUpdate suffix:@"_updated"];
    [self updateRecordsLocally:idToFieldsLocallyUpdated soupName:soupName];
    return idToFieldsLocallyUpdated;
}

- (NSDictionary*)prepareSomeChanges:(NSDictionary*)idToFields idsToUpdate:(NSArray*)idsToUpdate suffix:(NSString*) suffix {
    NSMutableDictionary* idToFieldsUpdated = [NSMutableDictionary new];
    for (NSString* idToUpdate in idsToUpdate) {
        idToFieldsUpdated[idToUpdate] = [self updateFields:idToFields[idToUpdate] suffix:suffix];
    }
    return idToFieldsUpdated;
}

- (NSDictionary*)updateFields:(NSDictionary*)fields suffix:(NSString*)sufffix {
    NSArray* fieldNamesUpdatable = @[NAME, DESCRIPTION, LAST_NAME];

    NSMutableDictionary * updatedFields = [NSMutableDictionary new];
    for (NSString* fieldName in [fields allKeys]) {
        if ([fieldNamesUpdatable containsObject:fieldName]) {
            updatedFields[fieldName] = [NSString stringWithFormat:@"%@%@", fields[fieldName], sufffix];
        }
    }
    return updatedFields;
}

- (void)updateRecordsLocally:(NSDictionary*)idToFieldsLocallyUpdated soupName:(NSString*)soupName {
    for (NSString* recordId in [idToFieldsLocallyUpdated allKeys]) {
        NSDictionary * updatedFields = idToFieldsLocallyUpdated[recordId];
        NSNumber* soupEntryId = [self.store lookupSoupEntryIdForSoupName:soupName forFieldPath:ID fieldValue:recordId error:nil];
        NSArray* matchingRecords = [self.store retrieveEntries:@[soupEntryId] fromSoup:soupName];
        NSMutableDictionary * record = [matchingRecords[0] mutableCopy];
        for (NSString* fieldName in [updatedFields allKeys]) {
            record[fieldName] = updatedFields[fieldName];
        }
        record[kSyncTargetLocal] = @YES;
        record[kSyncTargetLocallyCreated] = @NO;
        record[kSyncTargetLocallyUpdated] = @YES;
        record[kSyncTargetLocallyDeleted] = @NO;
        [self.store upsertEntries:@[record] toSoup:soupName];
    }
}

- (NSDictionary *)makeSomeRemoteChanges:(NSDictionary *)idToFields objectType:(NSString *)objectType {
    // Make some remote changes
    [NSThread sleepForTimeInterval:1.0f];
    NSArray* allIds = [[idToFields allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSArray *idsToUpdate = @[allIds[0], allIds[2]];
    return [self makeSomeRemoteChanges:idToFields objectType:objectType idsToUpdate:idsToUpdate];
}


- (NSDictionary *)makeSomeRemoteChanges:(NSDictionary *)idToFields objectType:(NSString *)objectType idsToUpdate:(NSArray*)idsToUpdate {
    NSDictionary* idToFieldsRemotelyUpdated = [self prepareSomeChanges:idToFields idsToUpdate:idsToUpdate suffix:@"_remotely_updated"];
    [self updateRecordsOnServer:idToFieldsRemotelyUpdated objectType:objectType];
    return idToFieldsRemotelyUpdated;

}

-(void)updateRecordsOnServer:(NSDictionary*)idToFieldsUpdated objectType:(NSString*)objectType {
    for (NSString* accountId in idToFieldsUpdated) {
        NSDictionary* fields = idToFieldsUpdated[accountId];
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:objectType objectId:accountId fields:fields];
        [self sendSyncRequest:request];
    }
}

- (void)checkDbDeleted:(NSString*)soupName ids:(NSArray*)ids idField:(NSString*)idField {
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {%@:_soup} FROM {%@} WHERE {%@:%@} IN %@",
                                                    soupName, soupName, soupName, idField, [self buildInClause:ids]];

    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rowsFromDb = [self.store queryWithQuerySpec:query pageIndex:0 error:nil];
    XCTAssertEqual(0, rowsFromDb.count, "No records should have been returned from smartstore");
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
    actualChanges:(NSInteger)actualNumberChanges
           target:(SFSyncUpTarget *)target
          options:(SFSyncOptions *) options
 completionStatus:(SFSyncStateStatus)completionStatus {

    // Creates sync.
    SFSyncState *sync = [SFSyncState newSyncUpWithOptions:options target:target soupName:ACCOUNTS_SOUP name:nil store:self.store];
    NSInteger syncId = sync.syncId;
    [self checkStatus:sync expectedType:SFSyncStateSyncTypeUp expectedId:syncId expectedTarget:target expectedOptions:options expectedStatus:SFSyncStateStatusNew expectedProgress:0 expectedTotalSize:-1];

    // Runs sync.
    SFSyncUpdateCallbackQueue* queue = [[SFSyncUpdateCallbackQueue alloc] init];
    [queue runSync:sync syncManager:self.syncManager];

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


- (NSDictionary*) getIdToFieldsByName:(NSString*)soupName fieldNames:(NSArray*)fieldNames nameField:(NSString*)nameField names:(NSArray*)names {
    NSString* namesClause = [self buildInClause:names];
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {%@:_soup} FROM {%@} WHERE {%@:%@} IN %@", soupName, soupName, soupName, nameField, namesClause];
    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:names.count];
    NSArray* rows = [self.store queryWithQuerySpec:query pageIndex:0 error:nil];
    NSMutableDictionary * idToFields = [NSMutableDictionary new];
    for (NSArray* row in rows) {
        NSDictionary* soupElt = row[0];
        NSString* id = soupElt[ID];
        NSMutableDictionary * fields = [NSMutableDictionary new];
        for (NSString* fieldName in fieldNames) {
            fields[fieldName] = soupElt[fieldName];
        }
        idToFields[id] = fields;
    }
    return idToFields;
}

- (void) checkServer:(NSDictionary*)idToFields objectType:(NSString*)objectType {
    // Ids clause
    NSString* idsClause = [self buildInClause:[idToFields allKeys]];

    // Field names
    NSArray* fieldNames = [((NSDictionary *) idToFields[[idToFields allKeys][0]]) allKeys];

    // Query
    NSString* soql = [NSString stringWithFormat:@"SELECT %@, %@ FROM %@ WHERE Id IN %@", ID, [fieldNames componentsJoinedByString:@","], objectType, idsClause];
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql];
    NSArray* records = [self sendSyncRequest:request][RECORDS];
    XCTAssertEqual(idToFields.count, records.count);
    for (NSDictionary* record in records) {
        NSString* recordId = record[ID];
        for (NSString* fieldName in [idToFields[recordId] allKeys]) {
            XCTAssertEqualObjects(idToFields[recordId][fieldName], record[fieldName]);
        }
    }
}

-(NSDictionary *)updateRecordOnServer:(NSDictionary *)fields idToUpdate:(NSString *)idToUpdate objectType:(NSString*)objectType {
    NSMutableDictionary * idToFieldsRemotelyUpdated = [NSMutableDictionary new];
    NSDictionary* updatedFields = [self updateFields:fields suffix:REMOTELY_UPDATED];
    idToFieldsRemotelyUpdated[idToUpdate] = updatedFields;
    [self updateRecordsOnServer:idToFieldsRemotelyUpdated objectType:objectType];
    return idToFieldsRemotelyUpdated;
}

- (NSDictionary *)updateRecordLocally:(NSDictionary *)fields idToUpdate:(NSString *)idToUpdate soupName:(NSString*)soupName {
    return [self updateRecordLocally:fields idToUpdate:idToUpdate soupName:soupName suffix:LOCALLY_UPDATED];
}

- (NSDictionary *)updateRecordLocally:(NSDictionary *)fields idToUpdate:(NSString *)idToUpdate soupName:(NSString*)soupName suffix:(NSString*)suffix {
    NSMutableDictionary * idToFieldsLocallyUpdated = [NSMutableDictionary new];
    NSDictionary* updatedFields = [self updateFields:fields suffix:suffix];
    idToFieldsLocallyUpdated[idToUpdate] = updatedFields;
    [self updateRecordsLocally:idToFieldsLocallyUpdated soupName:soupName];
    return idToFieldsLocallyUpdated;
}

-(void)deleteRecordsLocally:(NSArray*)ids soupName:(NSString*)soupName {
    NSMutableArray* deletedAccounts = [NSMutableArray new];
    for (NSString* idToDelete in ids) {
        SFQuerySpec* query = [SFQuerySpec newExactQuerySpec:soupName withPath:ID withMatchKey:idToDelete withOrderPath:ID withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
        NSArray* results = [self.store queryWithQuerySpec:query pageIndex:0 error:nil];
        NSMutableDictionary* account = [[NSMutableDictionary alloc] initWithDictionary:results[0]];
        account[kSyncTargetLocal] = @YES;
        account[kSyncTargetLocallyCreated] = @NO;
        account[kSyncTargetLocallyDeleted] = @YES;
        account[kSyncTargetLocallyUpdated] = @NO;
        [deletedAccounts addObject:account];
    }
    [self.store upsertEntries:deletedAccounts toSoup:soupName];
}

-(void) checkServerDeleted:(NSArray*)ids objectType:(NSString*)objectType {
    NSString* soql = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ IN %@", ID, objectType, ID, [self buildInClause:ids]];
    SFRestRequest * request = [[SFRestAPI sharedInstance] requestForQuery:soql];
    NSDictionary * response = [self sendSyncRequest:request];
    NSArray* records = response[@"records"];
    XCTAssertEqual(records.count, 0, @"No accounts should have been returned from server");
}

-(void) checkDbRelationshipsWithChildrenIds:(NSArray*)childrenIds expectedParentId:(NSString*)expectedParentId soupName:(NSString*)soupName idFieldName:(NSString*)idFieldName parentIdFieldName:(NSString*)parentIdFieldName {
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {%@:_soup} FROM {%@} WHERE {%@:%@} IN %@", soupName, soupName, soupName, idFieldName, [self buildInClause:childrenIds]];
    SFQuerySpec * smartStoreQuery = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:childrenIds.count];
    NSArray* rows = [self.syncManager.store queryWithQuerySpec:smartStoreQuery pageIndex:0 error:nil];
    XCTAssertEqual(rows.count, childrenIds.count, @"All records should have been returned from smartstore");
    for (NSArray* row in rows) {
        NSDictionary * childRecord = row[0];
        XCTAssertEqualObjects(childRecord[parentIdFieldName], expectedParentId, @"Wrong parent id");
    }
}
@end
