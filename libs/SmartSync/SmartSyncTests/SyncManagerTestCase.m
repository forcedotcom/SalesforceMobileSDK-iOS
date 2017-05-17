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
        [SFLogger sharedLogger].logLevel = SFLogLevelDebug;
        [SFSyncManagerLogger setLevel:SFLogLevelDebug];
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
    self.currentUser = [SFUserAccountManager sharedInstance].currentUser;
    self.syncManager = [SFSmartSyncSyncManager sharedInstance:self.currentUser];
    self.store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName user:self.currentUser];
    [super setUp];
}

- (void)tearDown
{
    // User and managers tear down
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

- (NSString*)createRecordName:(NSString*)objectType {
    return [NSString stringWithFormat:@"SyncManagerTestCase_%@_%08d", objectType, arc4random_uniform(100000000)];
}

- (NSString*) createAccountName {
    return [self createRecordName:ACCOUNT_TYPE];
}

- (NSArray<NSDictionary*>*) createAccountsLocally:(NSArray<NSString*>*)names {
    NSMutableArray<NSDictionary *> *accounts = [NSMutableArray new];
    NSDictionary *attributes = @{TYPE: ACCOUNT_TYPE};
    for (NSString *name in names) {
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
    }
    return [self.store upsertEntries:accounts toSoup:ACCOUNTS_SOUP];
}

- (NSString*) createLocalId {
    return [NSString stringWithFormat:@"local_%08d", arc4random_uniform(100000000)];
}

- (void)createAccountsSoup {
    NSArray* indexSpecs = @[
                            [[SFSoupIndex alloc] initWithPath:ID indexType:kSoupIndexTypeString columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:NAME indexType:kSoupIndexTypeString columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:DESCRIPTION indexType:kSoupIndexTypeFullText columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:kSyncTargetLocal indexType:kSoupIndexTypeString columnName:nil]
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
            [[SFSoupIndex alloc] initWithPath:kSyncTargetLocal indexType:kSoupIndexTypeString columnName:nil]
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
    for (NSString* id in ids) {
        SFRestRequest *deleteRequest = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:objectType objectId:id];
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
    NSArray * listFields = [self buildFieldsMapForRecords:count objectType:ACCOUNT_TYPE additionalFields:nil];
    NSMutableArray* requests = [NSMutableArray new];
    for (NSUInteger i = 0; i < count; i++) {
        [requests addObject:[[SFRestAPI sharedInstance] requestForCreateWithObjectType:ACCOUNT_TYPE fields:listFields[i]]];
    }

    NSMutableDictionary * idToFields = [NSMutableDictionary new];
    NSDictionary * batchResponse = [self sendSyncRequest:[[SFRestAPI sharedInstance] batchRequest:requests haltOnError:NO]];
    NSArray* results = batchResponse[@"results"];
    for (NSUInteger  i = 0; i < results.count; i++) {
        NSDictionary * result = results[i];
        XCTAssertEqual(201, [result[@"statusCode"] intValue], "Status code should be HTTP_CREATED");
        idToFields[result[@"result"][@"id"]] = listFields[i];
    }

    return idToFields;
}

- (NSInteger)trySyncDown:(SFSyncStateMergeMode)mergeMode target:(SFSyncDownTarget*)target soupName:(NSString*)soupName totalSize:(NSUInteger)totalSize numberFetches:(NSUInteger)numberFetches {

    // Creates sync.
    SFSyncOptions* options = [SFSyncOptions newSyncOptionsForSyncDown:mergeMode];
    SFSyncState* sync = [SFSyncState newSyncDownWithOptions:options target:target soupName:soupName store:self.store];
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

    // Ids clause
    NSString* idsClause = [self buildInClause:ids];

    // Query
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {%@:_soup} FROM {%@} WHERE {%@:Id} IN %@", soupName, soupName, soupName, idsClause];

    SFQuerySpec* query = [SFQuerySpec newSmartQuerySpec:smartSql withPageSize:ids.count];
    NSArray* rows = [self.store queryWithQuerySpec:query pageIndex:0 error:nil];
    XCTAssertEqual(ids.count, rows.count);
    for (NSArray* row in rows) {
        NSDictionary *recordFromDb = row[0];
        XCTAssertEqualObjects(@(expectedLocallyCreated||expectedLocallyUpdated||expectedLocallyDeleted), recordFromDb[kSyncTargetLocal]);
        XCTAssertEqualObjects(@(expectedLocallyCreated), recordFromDb[kSyncTargetLocallyCreated]);
        XCTAssertEqualObjects(@(expectedLocallyUpdated), recordFromDb[kSyncTargetLocallyUpdated]);
        XCTAssertEqualObjects(@(expectedLocallyDeleted), recordFromDb[kSyncTargetLocallyDeleted]);
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
    for (NSString* id in [idToFieldsLocallyUpdated allKeys]) {
        NSDictionary * updatedFields = idToFieldsLocallyUpdated[id];
        NSMutableDictionary * record = [[self.store retrieveEntries:@[[self.store lookupSoupEntryIdForSoupName:soupName forFieldPath:ID fieldValue:id error:nil]] fromSoup:soupName][0] mutableCopy];
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
@end
