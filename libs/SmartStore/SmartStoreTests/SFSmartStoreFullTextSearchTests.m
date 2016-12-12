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

#import "SFSmartStoreFullTextSearchTests.h"
#import "SFSmartStore+Internal.h"
#import "SFSoupIndex.h"
#import "SFQuerySpec.h"
#import <SalesforceSDKCore/SFJsonUtils.h>
#import "FMDatabaseQueue.h"
#import "FMDatabase.h"

@interface SFSmartStoreFullTextSearchTests ()

@property (nonatomic, strong) SFSmartStore *store;
@property (nonatomic, strong) NSNumber *christineHaasId;
@property (nonatomic, strong) NSNumber *michaelThompsonId;
@property (nonatomic, strong) NSNumber *aliHaasId;
@property (nonatomic, strong) NSNumber *johnGeyerId;
@property (nonatomic, strong) NSNumber *irvingSternId;
@property (nonatomic, strong) NSNumber *evaPulaskiId;
@property (nonatomic, strong) NSNumber *eileenEvaId;

@end

@implementation SFSmartStoreFullTextSearchTests

#pragma mark - setup and teardown

- (void) setUp
{
    [super setUp];
    self.store = [SFSmartStore sharedGlobalStoreWithName:kTestStore];
}

- (void) tearDown
{
    [self.store removeSoup:kEmployeesSoup];
    [SFSmartStore removeSharedGlobalStoreWithName:kTestStore];
    [super tearDown];
    self.store = nil;
}

- (void) setupSoup:(SFSmartStoreFtsExtension) ftsExtension
{
    self.store.ftsExtension = ftsExtension;
    NSArray* soupIndices = [SFSoupIndex asArraySoupIndexes:
                            @[[self createFullTextIndexSpec:kFirstName],    // should be TABLE_1_0
                              [self createFullTextIndexSpec:kLastName],     // should be TABLE_1_1
                              [self createStringIndexSpec:kEmployeeId]]];   // should be TABLE_1_2
    // Employees soup
    [self.store registerSoup:kEmployeesSoup                             // should be TABLE_1
              withIndexSpecs:soupIndices
                       error:nil];
}

#pragma mark - Tests

/**
 * Test register/drop soup that uses full-text search indices - with fts4
 */
- (void) testRegisterDropSoupFts4
{
    [self tryRegisterDropSoup:SFSmartStoreFTS4];
}

/**
 * Test register/drop soup that uses full-text search indices - with fts5
 */
- (void) testRegisterDropSoupFts5
{
    [self tryRegisterDropSoup:SFSmartStoreFTS5];
}

- (void) tryRegisterDropSoup:(SFSmartStoreFtsExtension)ftsExtension
{
    [self setupSoup:ftsExtension];
    
    NSString* soupTableName = [self getSoupTableName:kEmployeesSoup store:self.store];
    XCTAssertEqualObjects(@"TABLE_1", soupTableName, @"getSoupTableName should have returned TABLE_1");
    XCTAssertTrue([self hasTable:@"TABLE_1" store:self.store], @"Table for soup employees does exit");
    XCTAssertTrue([self hasTable:@"TABLE_1_fts" store:self.store], @"FTS Table for soup employees does exit");
    XCTAssertTrue([self.store soupExists:kEmployeesSoup], @"Register soup failed");
    
    NSString* expectedCreateSql = [NSString stringWithFormat:@"CREATE VIRTUAL TABLE TABLE_1_fts USING fts%lu", (unsigned long)ftsExtension];
    [self checkCreateTableStatment:@"TABLE_1_fts" expectedSqlStatementPrefix:expectedCreateSql store:self.store];

    // Drop
    [self.store removeSoup:kEmployeesSoup];

    // After
    XCTAssertFalse([self.store soupExists:kEmployeesSoup], @"Soup employees should no longer exist");
    XCTAssertNil([self getSoupTableName:kEmployeesSoup store:self.store], "Soup employees should no longer exist");
    XCTAssertFalse([self hasTable:@"TABLE_1" store:self.store], @"Table for soup employees should not exit");
    XCTAssertFalse([self hasTable:@"TABLE_1_fts" store:self.store], @"FTS Table for soup employees should not exit");
}

/**
 * Test inserting rows with fts4
 */
- (void) testInsertWithFts4
{
    [self tryInsert:SFSmartStoreFTS4];
}

/**
 * Test inserting rows with fts5
 */
- (void) testInsertWithFts5
{
    [self tryInsert:SFSmartStoreFTS5];
}

- (void) tryInsert:(SFSmartStoreFtsExtension)ftsExtension
{
    [self setupSoup:ftsExtension];

    // Insert a couple of rows
    NSDictionary* firstEmployee = [self createEmployeeWithFirstName:@"Christine" lastName:@"Haas" employeeId:@"00010"];
    NSDictionary* secondEmployee = [self createEmployeeWithFirstName:@"Michael" lastName:@"Thompson" employeeId:@"00020"];

    // Getting index specs from db
    NSArray* actualIndexSpecs = [self.store indicesForSoup:kEmployeesSoup];
    
    // Check DB
    NSString* soupTableName = [self getSoupTableName:kEmployeesSoup store:self.store];
    XCTAssertEqualObjects(@"TABLE_1", soupTableName, @"getSoupTableName should have returned TABLE_1");
    XCTAssertTrue([self hasTable:@"TABLE_1" store:self.store], @"Table for soup employees does exit");
    XCTAssertTrue([self hasTable:@"TABLE_1_fts" store:self.store], @"FTS Table for soup employees does exit");
    
    
    // Check soup table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:@"TABLE_1" forColumns:nil orderBy:@"id ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkSoupRow:frs withExpectedEntry:firstEmployee withSoupIndexes:actualIndexSpecs];
        [self checkSoupRow:frs withExpectedEntry:secondEmployee withSoupIndexes:actualIndexSpecs];
        XCTAssertFalse([frs next], @"Only two rows should have been returned");
        [frs close];
    }];
    
    // Check fts table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:@"TABLE_1_fts" forColumns:@[ROWID_COL, @"TABLE_1_0", @"TABLE_1_1"] orderBy:@"rowid ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkFtsRow:frs withExpectedEntry:firstEmployee withSoupIndexes:actualIndexSpecs];
        [self checkFtsRow:frs withExpectedEntry:secondEmployee withSoupIndexes:actualIndexSpecs];
        XCTAssertFalse([frs next], @"Only two rows should have been returned");
        [frs close];
    }];
}

/**
 * Test updating rows with fts4
 */
- (void) testUpdateWithFts4
{
    [self tryUpdate:SFSmartStoreFTS4];
}

/**
 * Test updating rows with fts5
 */
- (void) testUpdateWithFts5
{
    [self tryUpdate:SFSmartStoreFTS5];
}

- (void) tryUpdate:(SFSmartStoreFtsExtension)ftsExtension
{
    [self setupSoup:SFSmartStoreFTS5];

    // Insert a couple of rows
    NSDictionary* firstEmployee = [self createEmployeeWithFirstName:@"Christine" lastName:@"Haas" employeeId:@"00010"];
    NSDictionary* secondEmployee = [self createEmployeeWithFirstName:@"Michael" lastName:@"Thompson" employeeId:@"00020"];
    
    // Getting index specs from db
    NSArray* actualIndexSpecs = [self.store indicesForSoup:kEmployeesSoup];
    
    // Update second employee
    NSDictionary* secondEmployeeUpdated = [self updateEnployeeWithFirstName:@"Michael-updated" lastName:@"Thompson" employeeId:@"00020-updated" soupEntryId:secondEmployee[SOUP_ENTRY_ID]];
    
    // Check soup table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:@"TABLE_1" forColumns:nil orderBy:@"id ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkSoupRow:frs withExpectedEntry:firstEmployee withSoupIndexes:actualIndexSpecs];
        [self checkSoupRow:frs withExpectedEntry:secondEmployeeUpdated withSoupIndexes:actualIndexSpecs];
        XCTAssertFalse([frs next], @"Only two rows should have been returned");
        [frs close];
    }];
    
    // Check fts table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:@"TABLE_1_fts" forColumns:@[ROWID_COL, @"TABLE_1_0", @"TABLE_1_1"] orderBy:@"rowid ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkFtsRow:frs withExpectedEntry:firstEmployee withSoupIndexes:actualIndexSpecs];
        [self checkFtsRow:frs withExpectedEntry:secondEmployeeUpdated withSoupIndexes:actualIndexSpecs];
        XCTAssertFalse([frs next], @"Only two rows should have been returned");
        [frs close];
    }];
}

/**
 * Test deleting rows with fts4
 */
- (void) testDeleteWithFts4
{
    [self tryDelete:SFSmartStoreFTS4];
}

/**
 * Test deleting rows with fts5
 */
- (void) testDeleteWithFts5
{
    [self tryDelete:SFSmartStoreFTS5];
}

- (void) tryDelete:(SFSmartStoreFtsExtension)ftsExtension
{
    [self setupSoup:ftsExtension];
    
    // Insert a couple of rows
    NSDictionary* firstEmployee = [self createEmployeeWithFirstName:@"Christine" lastName:@"Haas" employeeId:@"00010"];
    NSDictionary* secondEmployee = [self createEmployeeWithFirstName:@"Michael" lastName:@"Thompson" employeeId:@"00020"];
    
    // Getting index specs from db
    NSArray* actualIndexSpecs = [self.store indicesForSoup:kEmployeesSoup];
    
    // Delete first employee
    [self.store removeEntries:@[firstEmployee[SOUP_ENTRY_ID]] fromSoup:kEmployeesSoup];

    // Check soup table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:@"TABLE_1" forColumns:nil orderBy:@"id ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkSoupRow:frs withExpectedEntry:secondEmployee withSoupIndexes:actualIndexSpecs];
        XCTAssertFalse([frs next], @"Only one row should have been returned");
        [frs close];
    }];
    
    // Check fts table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:@"TABLE_1_fts" forColumns:@[ROWID_COL, @"TABLE_1_0", @"TABLE_1_1"] orderBy:@"rowid ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkFtsRow:frs withExpectedEntry:secondEmployee withSoupIndexes:actualIndexSpecs];
        XCTAssertFalse([frs next], @"Only one should have been returned");
        [frs close];
    }];

    // Delete second employee
    [self.store removeEntries:@[secondEmployee[SOUP_ENTRY_ID]] fromSoup:kEmployeesSoup];
    
    // Check soup table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:@"TABLE_1" forColumns:nil orderBy:@"id ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        XCTAssertFalse([frs next], @"No rows should have been returned");
        [frs close];
    }];
    
    // Check fts table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:@"TABLE_1_fts" forColumns:@[ROWID_COL, @"TABLE_1_0", @"TABLE_1_1"] orderBy:@"rowid ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        XCTAssertFalse([frs next], @"No rows should have been returned");
        [frs close];
    }];
}

/**
 * Test clearing rows with fts4
 */
- (void) testClearWithFts4
{
    [self tryClear:SFSmartStoreFTS4];
}

/**
 * Test clearing rows with fts5
 */
- (void) testClearWithFts5
{
    [self tryClear:SFSmartStoreFTS5];
}

- (void) tryClear:(SFSmartStoreFtsExtension)ftsExtension
{
    [self setupSoup:ftsExtension];

    // Insert a couple of rows
    [self createEmployeeWithFirstName:@"Christine" lastName:@"Haas" employeeId:@"00010"];
    [self createEmployeeWithFirstName:@"Michael" lastName:@"Thompson" employeeId:@"00020"];

    // Clear soup
    [self.store clearSoup:kEmployeesSoup];
    
    // Check soup table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:@"TABLE_1" forColumns:nil orderBy:@"id ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        XCTAssertFalse([frs next], @"No rows should have been returned");
        [frs close];
    }];
    
    // Check fts table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:@"TABLE_1_fts" forColumns:@[ROWID_COL, @"TABLE_1_0", @"TABLE_1_1"] orderBy:@"rowid ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        XCTAssertFalse([frs next], @"No rows should have been returned");
        [frs close];
    }];
}

/**
 * Test search on single field returning no results with fts4
 */
- (void) testSearchSingleFielNoResultsWithFts4
{
    [self trySearchSingleFielNoResults:SFSmartStoreFTS4];
}

/**
 * Test search on single field returning no results with fts5
 */
- (void) testSearchSingleFielNoResultsWithFts5
{
    [self trySearchSingleFielNoResults:SFSmartStoreFTS5];
}

- (void) trySearchSingleFielNoResults:(SFSmartStoreFtsExtension) ftsExtension
{
    [self loadData:ftsExtension];
    
    // One field - full word - no results
    [self trySearch:@[] path:kFirstName matchKey:@"Christina" orderPath:nil];
    [self trySearch:@[] path:kLastName matchKey:@"Sternn" orderPath:nil];
    
    // One field - prefix - no results
    [self trySearch:@[] path:kFirstName matchKey:@"Christo*" orderPath:nil];
    [self trySearch:@[] path:kLastName matchKey:@"Stel*" orderPath:nil];

    // One field - set operation - no results
    [self trySearch:@[] path:kFirstName matchKey:@"Ei* NOT Eileen" orderPath:nil];
}

/**
 * Test search on single field returning a single result with fts4
 */
- (void) testSearchSingleFieldSingleResultWithFts4
{
    [self trySearchSingleFieldSingleResult:SFSmartStoreFTS4];
}

/**
 * Test search on single field returning a single result with fts5
 */
- (void) testSearchSingleFieldSingleResultWithFts5
{
    [self trySearchSingleFieldSingleResult:SFSmartStoreFTS5];
}

- (void) trySearchSingleFieldSingleResult:(SFSmartStoreFtsExtension) ftsExtension
{
    [self loadData:ftsExtension];
    
    // One field - full word - one result
    [self trySearch:@[self.christineHaasId] path:kFirstName matchKey:@"Christine" orderPath:nil];
    [self trySearch:@[self.irvingSternId] path:kLastName matchKey:@"Stern" orderPath:nil];
    
    // One field - prefix - one result
    [self trySearch:@[self.christineHaasId] path:kFirstName matchKey:@"Christ*" orderPath:nil];
    [self trySearch:@[self.irvingSternId] path:kLastName matchKey:@"Ste*" orderPath:nil];
    
    // One field - set operation - one result
    [self trySearch:@[self.eileenEvaId] path:kFirstName matchKey:@"E* NOT Eva" orderPath:nil];
}

/**
 * Test search on single field returning multiple results - testing ordering with fts4
 */
- (void) testSearchSingleFieldMultipleResultsWithFts4
{
    [self trySearchSingleFieldMultipleResults:SFSmartStoreFTS4];
}

/**
 * Test search on single field returning multiple results - testing ordering with fts5
 */
- (void) testSearchSingleFieldMultipleResultsWithFts5
{
    [self trySearchSingleFieldMultipleResults:SFSmartStoreFTS5];
}

- (void) trySearchSingleFieldMultipleResults:(SFSmartStoreFtsExtension) ftsExtension
{
    [self loadData:ftsExtension];

    // One field - full word - more than one results
    [self trySearch:@[self.christineHaasId, self.aliHaasId] path:kLastName matchKey:@"Haas" orderPath:kEmployeeId];
    [self trySearch:@[self.aliHaasId, self.christineHaasId] path:kLastName matchKey:@"Haas" orderPath:kFirstName];

    // One field - prefix - more than one results
    [self trySearch:@[self.evaPulaskiId, self.eileenEvaId] path:kFirstName matchKey:@"E*" orderPath:kEmployeeId];
    [self trySearch:@[self.eileenEvaId, self.evaPulaskiId] path:kFirstName matchKey:@"E*" orderPath:kFirstName];

    // One field - set operation - more than one results
    [self trySearch:@[self.evaPulaskiId, self.eileenEvaId] path:kFirstName matchKey:@"Eva OR Eileen" orderPath:kEmployeeId];
    [self trySearch:@[self.eileenEvaId, self.evaPulaskiId] path:kFirstName matchKey:@"Eva OR Eileen" orderPath:kFirstName];
}

/**
 * Test search on all fields returning no results with fts4
 */
- (void) testSearchAllFieldsNoResultsWithFts4
{
    [self trySearchAllFieldsNoResults:SFSmartStoreFTS4];
}

/**
 * Test search on all fields returning no results with fts5
 */
- (void) testSearchAllFieldsNoResultsWithFts5
{
    [self trySearchAllFieldsNoResults:SFSmartStoreFTS5];
}

- (void) trySearchAllFieldsNoResults:(SFSmartStoreFtsExtension) ftsExtension
{
    [self loadData:ftsExtension];

    // All fields - full word - no results
    [self trySearch:@[] path:nil matchKey:@"Sternn" orderPath:nil];

    // All fields - prefix - no results
    [self trySearch:@[] path:nil matchKey:@"Stel*" orderPath:nil];

    // All fields - multiple words - no results
    [self trySearch:@[] path:nil matchKey:@"Haas Christina" orderPath:nil];

    // All fields - set operation - no results
    [self trySearch:@[] path:nil matchKey:@"Christine NOT Haas" orderPath:nil];
}

/**
 * Test search on all fields returning a single result with fts4
 */
- (void) testSearchAllFieldsSingleResultWithFts4
{
    [self trySearchAllFieldsSingleResult:SFSmartStoreFTS4];
}

/**
 * Test search on all fields returning a single result with fts5
 */
- (void) testSearchAllFieldsSingleResultWithFts5
{
    [self trySearchAllFieldsSingleResult:SFSmartStoreFTS5];
}

- (void) trySearchAllFieldsSingleResult:(SFSmartStoreFtsExtension) ftsExtension
{
    [self loadData:ftsExtension];

    // All fields - full word - one result
    [self trySearch:@[self.irvingSternId] path:nil matchKey:@"Stern" orderPath:nil];

    // All fields - prefix - one result
    [self trySearch:@[self.irvingSternId] path:nil matchKey:@"St*" orderPath:nil];

    // All fields - multiple words - one result
    [self trySearch:@[self.christineHaasId] path:nil matchKey:@"Haas Christine" orderPath:nil];

    // All fields - set operation - one result
    [self trySearch:@[self.aliHaasId] path:nil matchKey:@"Haas NOT Christine" orderPath:nil];
}

/**
 * Test search on all fields returning multiple results - testing ordering with fts4
 */
- (void) testSearchAllFieldMultipleResultsWithFts4
{
    [self trySearchAllFieldMultipleResults:SFSmartStoreFTS4];
}

/**
 * Test search on all fields returning multiple results - testing ordering with fts5
 */
- (void) testSearchAllFieldMultipleResultsWithFts5
{
    [self trySearchAllFieldMultipleResults:SFSmartStoreFTS5];
}

- (void) trySearchAllFieldMultipleResults:(SFSmartStoreFtsExtension) ftsExtension
{
    [self loadData:ftsExtension];

    // All fields - full word - more than one results
    [self trySearch:@[self.evaPulaskiId, self.eileenEvaId] path:nil matchKey:@"Eva" orderPath:kEmployeeId];
    [self trySearch:@[self.eileenEvaId, self.evaPulaskiId] path:nil matchKey:@"Eva" orderPath:kLastName];

    // All fields - prefix - more than one results
    [self trySearch:@[self.evaPulaskiId, self.eileenEvaId] path:nil matchKey:@"Ev*" orderPath:kEmployeeId];
    [self trySearch:@[self.eileenEvaId, self.evaPulaskiId] path:nil matchKey:@"Ev*" orderPath:kLastName];

    // All fields - set operation - more than result
    [self trySearch:@[self.michaelThompsonId, self.aliHaasId] path:nil matchKey:@"Thompson OR Ali" orderPath:kEmployeeId];
    [self trySearch:@[self.aliHaasId, self.michaelThompsonId] path:nil matchKey:@"Thompson OR Ali" orderPath:kFirstName];
    [self trySearch:@[self.christineHaasId, self.evaPulaskiId, self.eileenEvaId] path:nil matchKey:@"Eva OR Haas NOT Ali" orderPath:kEmployeeId];
    [self trySearch:@[self.christineHaasId, self.eileenEvaId, self.evaPulaskiId] path:nil matchKey:@"Eva OR Haas NOT Ali" orderPath:kFirstName];
}

/**
 * Test search with queries that have field:value predicates with fts4
 */
- (void) testSearchWithFieldColonQueriesWithFts4
{
    [self trySearchWithFieldColonQueries:SFSmartStoreFTS4];
}

/**
 * Test search with queries that have field:value predicates with fts5
 */
- (void) testSearchWithFieldColonQueriesWithFts5
{
    [self trySearchWithFieldColonQueries:SFSmartStoreFTS5];
}

- (void) trySearchWithFieldColonQueries:(SFSmartStoreFtsExtension) ftsExtension
{
    [self loadData:ftsExtension];

    // All fields - full word - no results
    [self trySearch:@[] path:nil matchKey:@"{employees:firstName}:Haas" orderPath:nil];

    // All fields - full word - one result
    [self trySearch:@[self.evaPulaskiId] path:nil matchKey:@"{employees:firstName}:Eva" orderPath:nil];
    [self trySearch:@[self.eileenEvaId] path:nil matchKey:@"{employees:lastName}:Eva" orderPath:nil];

    // All fields - full word - more than one results
    [self trySearch:@[self.christineHaasId, self.aliHaasId] path:nil matchKey:@"{employees:lastName}:Haas" orderPath:kEmployeeId];

    // All fields - prefix - more than one results
    [self trySearch:@[self.evaPulaskiId, self.eileenEvaId] path:nil matchKey:@"{employees:firstName}:E*" orderPath:kEmployeeId];
    [self trySearch:@[self.christineHaasId, self.aliHaasId] path:nil matchKey:@"{employees:lastName}:H*" orderPath:kEmployeeId];

    // All fields - set operation - more than result
    [self trySearch:@[self.michaelThompsonId, self.aliHaasId] path:nil matchKey:@"{employees:lastName}:Thompson OR {employees:firstName}:Ali" orderPath:kEmployeeId];
    [self trySearch:@[self.aliHaasId, self.michaelThompsonId] path:nil matchKey:@"{employees:lastName}:Thompson OR {employees:firstName}:Ali" orderPath:kFirstName];
    [self trySearch:@[self.christineHaasId, self.eileenEvaId] path:nil matchKey:@"{employees:lastName}:Eva OR Haas NOT Ali" orderPath:kEmployeeId];
    [self trySearch:@[self.eileenEvaId, self.christineHaasId] path:nil matchKey:@"{employees:lastName}:Eva OR Haas NOT Ali" orderPath:kLastName];
}


#pragma mark - helper methods

- (void) trySearch:(NSArray*)expectedIds path:(NSString*)path matchKey:(NSString*)matchKey orderPath:(NSString*)orderPath
{
    // Returning soup elements
    SFQuerySpec* querySpec = [SFQuerySpec newMatchQuerySpec:kEmployeesSoup withPath:path withMatchKey:matchKey withOrderPath:orderPath withOrder:kSFSoupQuerySortOrderAscending withPageSize:25];
    NSArray* results = [self.store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
    XCTAssertEqual(expectedIds.count, results.count, @"Wrong number of results");
    for (int i=0; i<results.count; i++) {
        XCTAssertEqual(((NSNumber*)expectedIds[i]).longValue, ((NSNumber*)results[i][SOUP_ENTRY_ID]).longValue, @"Wrong results for match query returning soup elements");
    }
    
    // Returning just id
    querySpec = [SFQuerySpec newMatchQuerySpec:kEmployeesSoup withSelectPaths:@[SOUP_ENTRY_ID] withPath:path withMatchKey:matchKey withOrderPath:orderPath withOrder:kSFSoupQuerySortOrderAscending withPageSize:25];
    results = [self.store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
    XCTAssertEqual(expectedIds.count, results.count, @"Wrong number of results");
    for (int i=0; i<results.count; i++) {
        XCTAssertEqual(((NSNumber*)expectedIds[i]).longValue, ((NSNumber*)results[i][0]).longValue, @"Wrong results for match query with selectPaths");
    }
    
}


- (void) loadData:(SFSmartStoreFtsExtension) ftsExtension
{
    [self setupSoup:ftsExtension];
    
    self.christineHaasId = [self createEmployeeWithFirstName:@"Christine" lastName:@"Haas" employeeId:@"00010"][SOUP_ENTRY_ID];
    self.michaelThompsonId = [self createEmployeeWithFirstName:@"Michael" lastName:@"Thompson" employeeId:@"00020"][SOUP_ENTRY_ID];
    self.aliHaasId = [self createEmployeeWithFirstName:@"Ali" lastName:@"Haas" employeeId:@"00030"][SOUP_ENTRY_ID];
    self.johnGeyerId = [self createEmployeeWithFirstName:@"John" lastName:@"Geyer" employeeId:@"00040"][SOUP_ENTRY_ID];
    self.irvingSternId = [self createEmployeeWithFirstName:@"Irving" lastName:@"Stern" employeeId:@"00050"][SOUP_ENTRY_ID];
    self.evaPulaskiId = [self createEmployeeWithFirstName:@"Eva" lastName:@"Pulaski" employeeId:@"00060"][SOUP_ENTRY_ID];
    self.eileenEvaId = [self createEmployeeWithFirstName:@"Eileen" lastName:@"Eva" employeeId:@"00070"][SOUP_ENTRY_ID];
}

- (NSDictionary*) createEmployeeWithFirstName:(NSString*)firstName lastName:(NSString*)lastName employeeId:(NSString*)employeeId
{
    NSDictionary* employee = @{kFirstName: firstName, kLastName: lastName, kEmployeeId: employeeId};
    return [self.store upsertEntries:@[employee] toSoup:kEmployeesSoup][0];
}

- (NSDictionary*) updateEnployeeWithFirstName:(NSString*)firstName lastName:(NSString*)lastName employeeId:(NSString*)employeeId soupEntryId:(NSNumber*)soupEntryId
{
    NSDictionary* employee = @{SOUP_ENTRY_ID:soupEntryId, kFirstName: firstName, kLastName: lastName, kEmployeeId: employeeId};
    return [self.store upsertEntries:@[employee] toSoup:kEmployeesSoup][0];
}

@end

