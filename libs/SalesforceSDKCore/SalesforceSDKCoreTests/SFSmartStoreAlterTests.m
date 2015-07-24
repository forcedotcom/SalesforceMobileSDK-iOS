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

#import "SFSmartStoreAlterTests.h"
#import "SFAlterSoupLongOperation.h"
#import "SFSmartStore+Internal.h"
#import "SFSoupIndex.h"
#import "SFQuerySpec.h"
#import "SFJsonUtils.h"
#import "FMDatabaseQueue.h"
#import "FMDatabase.h"

@interface SFSmartStoreAlterTests ()

@property (nonatomic, strong) SFUserAccount *smartStoreUser;
@property (nonatomic, strong) SFSmartStore *store;
@property (nonatomic, strong) SFSmartStore *globalStore;

@end

@implementation SFSmartStoreAlterTests

#define kTestSmartStoreName   @"testSmartStore"
#define kTestSoupName         @"testSoup"
#define kName                 @"name"
#define kPopulation           @"population"
#define kCity                 @"city"
#define kCountry              @"country"
#define kTestSoupTableName    @"TABLE_1"
#define kTestSoupFtsTableName @"TABLE_1_fts"
#define kCityCol              @"TABLE_1_0"
#define kCountryCol           @"TABLE_1_1"
#define kLastName             @"lastName"
#define kAddress              @"address"
#define kStreet               @"street"
#define kAddressCity          @"address.city"
#define kAddressStreet        @"address.street"
#define kLastNameCol          @"TABLE_1_0"
#define kAddressStreetCol     @"TABLE_1_1"

#pragma mark - setup and teardown


- (void) setUp
{
    [super setUp];
    [SFLogger setLogLevel:SFLogLevelDebug];
    self.smartStoreUser = [self setUpSmartStoreUser];
    self.store = [SFSmartStore sharedStoreWithName:kTestSmartStoreName];
    self.globalStore = [SFSmartStore sharedGlobalStoreWithName:kTestSmartStoreName];
}

- (void) tearDown
{
    [SFSmartStore removeSharedStoreWithName:kTestSmartStoreName];
    [SFSmartStore removeSharedGlobalStoreWithName:kTestSmartStoreName];
    [self tearDownSmartStoreUser:self.smartStoreUser];
    [super tearDown];
    
    self.smartStoreUser = nil;
    self.store = nil;
    self.globalStore = nil;
}

#pragma mark - tests

/**
 * Test for getSoupIndexSpecs
 */
- (void) testGetSoupIndexSpecs {
    NSArray* indexSpecs = [SFSoupIndex asArraySoupIndexes:@[@{@"path": @"lastName", @"type": @"string"},
                                                            @{@"path": @"address.city", @"type": @"string"},
                                                            @{@"path": @"salary", @"type": @"integer"},
                                                            @{@"path": @"interest", @"type": @"floating"},
                                                            @{@"path": @"note", @"type": @"full_text"}
                                                            ]];
    
    XCTAssertFalse([self.store soupExists:kTestSoupName], "Test soup should not exists");
    [self.store registerSoup:kTestSoupName withIndexSpecs:indexSpecs];
    XCTAssertTrue([self.store soupExists:kTestSoupName], "Register soup call failed");

    
    // Check indices
    NSArray* actualIndexSpecs = [self.store indicesForSoup:kTestSoupName];
    [self checkIndexSpecs:actualIndexSpecs withExpectedIndexSpecs:indexSpecs checkColumnName:NO];
}

/**
 * Test for alterSoup with reIndexData = false
 */
- (void) testAlterSoupNoReIndexing
{
    [self alterSoupHelper:NO];
}

/**
 * Test for alterSoup with reIndexData = true
 */
- (void) testAlterSoupWithReIndexing
{
    [self alterSoupHelper:YES];
}


/**
 * Test for alterSoup with column type change from string to integer
 */
-(void) testAlterSoupTypeChangeStringToInteger
{
    NSArray* indexSpecs = [SFSoupIndex asArraySoupIndexes:@[@{@"path": kName, @"type": @"string"}, @{@"path": kPopulation, @"type": @"string"}]];
    XCTAssertFalse([self.store soupExists:kTestSoupName], "Test soup should not exists");
    [self.store registerSoup:kTestSoupName withIndexSpecs:indexSpecs];
    XCTAssertTrue([self.store soupExists:kTestSoupName], "Register soup call failed");
    
    [self.store upsertEntries:@[@{kName:@"San Francisco", kPopulation:@825863}, @{kName:@"Paris", kPopulation:@2234105}]
                       toSoup:kTestSoupName];

    // Query all sorted by population ascending - we should get Paris first because we indexed population as a string
    NSArray* results = [self.store queryWithQuerySpec:[SFQuerySpec newAllQuerySpec:kTestSoupName withOrderPath:kPopulation withOrder:kSFSoupQuerySortOrderAscending withPageSize:2 ] pageIndex:0 error:nil];
    XCTAssertEqualObjects(results[0][kName], @"Paris", "Paris should be first");
    XCTAssertEqualObjects(results[1][kName], @"San Francisco", "San Francisco should be second");

    // Alter soup - index population as integer
    NSArray* indexSpecsNew = [SFSoupIndex asArraySoupIndexes:@[@{@"path": kName, @"type": @"string"}, @{@"path": kPopulation, @"type": @"integer"}]];
    [self.store alterSoup:kTestSoupName withIndexSpecs:indexSpecsNew reIndexData:YES];

    // Query all sorted by population ascending - we should get San Francisco first because we indexed population as an integer
    NSArray* results2 = [self.store queryWithQuerySpec:[SFQuerySpec newAllQuerySpec:kTestSoupName withOrderPath:kPopulation withOrder:kSFSoupQuerySortOrderAscending withPageSize:2 ] pageIndex:0 error:nil];
    XCTAssertEqualObjects(results2[0][kName], @"San Francisco", "San Francisco should be first");
    XCTAssertEqualObjects(results2[1][kName], @"Paris", "Paris should be second");
}

/**
 * Test for alterSoup with column type change from string to full_text
 */
-(void) testAlterSoupTypeChangeStringToFullText
{
    NSArray* indexSpecs = [SFSoupIndex asArraySoupIndexes:@[@{@"path": kCity, @"type": @"string"}, @{@"path": kCountry, @"type": @"string"}]];
    XCTAssertFalse([self.store soupExists:kTestSoupName], "Test soup should not exists");
    [self.store registerSoup:kTestSoupName withIndexSpecs:indexSpecs];
    XCTAssertTrue([self.store soupExists:kTestSoupName], "Register soup call failed");

    NSArray* savedEntries = [self.store upsertEntries:@[@{kCity:@"San Francisco", kCountry:@"United States"}, @{kName:@"Paris", kCountry:@"France"}]
                                               toSoup:kTestSoupName];
    
    // Check indices
    NSArray* actualIndexSpecs = [self.store indicesForSoup:kTestSoupName];
    [self checkIndexSpecs:actualIndexSpecs withExpectedIndexSpecs:indexSpecs checkColumnName:NO];

    // Check soup table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:kTestSoupTableName forColumns:nil orderBy:@"id ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkSoupRow:frs withExpectedEntry:savedEntries[0] withSoupIndexes:actualIndexSpecs];
        [self checkSoupRow:frs withExpectedEntry:savedEntries[1] withSoupIndexes:actualIndexSpecs];
        XCTAssertFalse([frs next], @"Only two rows should have been returned");
        [frs close];
    }];
    
    // Check fts table
    XCTAssertFalse([self hasTable:kTestSoupFtsTableName store:self.store], "No fts table expected");

    // Alter soup - country now full_text
    NSArray* indexSpecsNew = [SFSoupIndex asArraySoupIndexes:@[@{@"path": kCity, @"type": @"string"}, @{@"path": kCountry, @"type": @"full_text"}]];
    [self.store alterSoup:kTestSoupName withIndexSpecs:indexSpecsNew reIndexData:YES];

    // Check indices
    NSArray* actualIndexSpecsNew = [self.store indicesForSoup:kTestSoupName];
    [self checkIndexSpecs:actualIndexSpecsNew withExpectedIndexSpecs:indexSpecsNew checkColumnName:NO];

    // Check soup table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:kTestSoupTableName forColumns:nil orderBy:@"id ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkSoupRow:frs withExpectedEntry:savedEntries[0] withSoupIndexes:actualIndexSpecsNew];
        [self checkSoupRow:frs withExpectedEntry:savedEntries[1] withSoupIndexes:actualIndexSpecsNew];
        XCTAssertFalse([frs next], @"Only two rows should have been returned");
        [frs close];
    }];

    // Check fts table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:kTestSoupFtsTableName forColumns:@[DOCID_COL, kCountryCol] orderBy:@"docid ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkFtsRow:frs withExpectedEntry:savedEntries[0] withSoupIndexes:actualIndexSpecsNew];
        [self checkFtsRow:frs withExpectedEntry:savedEntries[1] withSoupIndexes:actualIndexSpecsNew];
        XCTAssertFalse([frs next], @"Only two rows should have been returned");
        [frs close];
    }];
    
    // Alter soup - city now full_text
    NSArray* indexSpecsNew2 = [SFSoupIndex asArraySoupIndexes:@[@{@"path": kCity, @"type": @"full_text"}, @{@"path": kCountry, @"type": @"full_text"}]];
    [self.store alterSoup:kTestSoupName withIndexSpecs:indexSpecsNew2 reIndexData:YES];
    
    // Check indices
    NSArray* actualIndexSpecsNew2 = [self.store indicesForSoup:kTestSoupName];
    [self checkIndexSpecs:actualIndexSpecsNew2 withExpectedIndexSpecs:indexSpecsNew2 checkColumnName:NO];
    
    // Check soup table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:kTestSoupTableName forColumns:nil orderBy:@"id ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkSoupRow:frs withExpectedEntry:savedEntries[0] withSoupIndexes:actualIndexSpecsNew2];
        [self checkSoupRow:frs withExpectedEntry:savedEntries[1] withSoupIndexes:actualIndexSpecsNew2];
        XCTAssertFalse([frs next], @"Only two rows should have been returned");
        [frs close];
    }];
    
    // Check fts table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:kTestSoupFtsTableName forColumns:@[DOCID_COL, kCityCol, kCountryCol] orderBy:@"docid ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkFtsRow:frs withExpectedEntry:savedEntries[0] withSoupIndexes:actualIndexSpecsNew2];
        [self checkFtsRow:frs withExpectedEntry:savedEntries[1] withSoupIndexes:actualIndexSpecsNew2];
        XCTAssertFalse([frs next], @"Only two rows should have been returned");
        [frs close];
    }];
}

/**
 * Test for alterSoup with column type change from full_text to string
 */
- (void) testAlterSoupTypeChangeFullTextToString
{
    NSArray* indexSpecs = [SFSoupIndex asArraySoupIndexes:@[@{@"path": kCity, @"type": @"full_text"}, @{@"path": kCountry, @"type": @"full_text"}]];
    XCTAssertFalse([self.store soupExists:kTestSoupName], "Test soup should not exists");
    [self.store registerSoup:kTestSoupName withIndexSpecs:indexSpecs];
    XCTAssertTrue([self.store soupExists:kTestSoupName], "Register soup call failed");

    NSArray* savedEntries = [self.store upsertEntries:@[@{kCity:@"San Francisco", kCountry:@"United States"}, @{kName:@"Paris", kCountry:@"France"}]
                                               toSoup:kTestSoupName];
    
    // Check indices
    NSArray* actualIndexSpecs = [self.store indicesForSoup:kTestSoupName];
    [self checkIndexSpecs:actualIndexSpecs withExpectedIndexSpecs:indexSpecs checkColumnName:NO];

    // Check soup table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:kTestSoupTableName forColumns:nil orderBy:@"id ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkSoupRow:frs withExpectedEntry:savedEntries[0] withSoupIndexes:actualIndexSpecs];
        [self checkSoupRow:frs withExpectedEntry:savedEntries[1] withSoupIndexes:actualIndexSpecs];
        XCTAssertFalse([frs next], @"Only two rows should have been returned");
        [frs close];
    }];
    
    // Check fts table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:kTestSoupFtsTableName forColumns:@[DOCID_COL, kCityCol, kCountryCol] orderBy:@"docid ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkFtsRow:frs withExpectedEntry:savedEntries[0] withSoupIndexes:actualIndexSpecs];
        [self checkFtsRow:frs withExpectedEntry:savedEntries[1] withSoupIndexes:actualIndexSpecs];
        XCTAssertFalse([frs next], @"Only two rows should have been returned");
        [frs close];
    }];

    // Alter soup - country now string
    NSArray* indexSpecsNew = [SFSoupIndex asArraySoupIndexes:@[@{@"path": kCity, @"type": @"full_text"}, @{@"path": kCountry, @"type": @"string"}]];
    [self.store alterSoup:kTestSoupName withIndexSpecs:indexSpecsNew reIndexData:YES];

    // Check indices
    NSArray* actualIndexSpecsNew = [self.store indicesForSoup:kTestSoupName];
    [self checkIndexSpecs:actualIndexSpecsNew withExpectedIndexSpecs:indexSpecsNew checkColumnName:NO];

    // Check soup table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:kTestSoupTableName forColumns:nil orderBy:@"id ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkSoupRow:frs withExpectedEntry:savedEntries[0] withSoupIndexes:actualIndexSpecsNew];
        [self checkSoupRow:frs withExpectedEntry:savedEntries[1] withSoupIndexes:actualIndexSpecsNew];
        XCTAssertFalse([frs next], @"Only two rows should have been returned");
        [frs close];
    }];

    // Check fts table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:kTestSoupFtsTableName forColumns:@[DOCID_COL, kCityCol] orderBy:@"docid ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkFtsRow:frs withExpectedEntry:savedEntries[0] withSoupIndexes:actualIndexSpecsNew];
        [self checkFtsRow:frs withExpectedEntry:savedEntries[1] withSoupIndexes:actualIndexSpecsNew];
        XCTAssertFalse([frs next], @"Only two rows should have been returned");
        [frs close];
    }];
    
    // Alter soup - city now string
    NSArray* indexSpecsNew2 = [SFSoupIndex asArraySoupIndexes:@[@{@"path": kCity, @"type": @"string"}, @{@"path": kCountry, @"type": @"string"}]];
    [self.store alterSoup:kTestSoupName withIndexSpecs:indexSpecsNew2 reIndexData:YES];
    
    // Check indices
    NSArray* actualIndexSpecsNew2 = [self.store indicesForSoup:kTestSoupName];
    [self checkIndexSpecs:actualIndexSpecsNew2 withExpectedIndexSpecs:indexSpecsNew2 checkColumnName:NO];
    
    // Check soup table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:kTestSoupTableName forColumns:nil orderBy:@"id ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkSoupRow:frs withExpectedEntry:savedEntries[0] withSoupIndexes:actualIndexSpecsNew2];
        [self checkSoupRow:frs withExpectedEntry:savedEntries[1] withSoupIndexes:actualIndexSpecsNew2];
        XCTAssertFalse([frs next], @"Only two rows should have been returned");
        [frs close];
    }];
    
    // Check fts table
    XCTAssertFalse([self hasTable:kTestSoupFtsTableName store:self.store], "No fts table expected");
}

-(void) testAlterSoupResumeAfterRenameOldSoupTable
{
    [self tryAlterSoupInterruptResume:SFAlterSoupStepRenameOldSoupTable];
}

-(void) testAlterSoupResumeAfterDropOldIndexes
{
    [self tryAlterSoupInterruptResume:SFAlterSoupStepDropOldIndexes];
}

-(void) testAlterSoupResumeAfterRegisterSoupUsingTableName
{
    [self tryAlterSoupInterruptResume:SFAlterSoupStepRegisterSoupUsingTableName];
}

-(void) testAlterSoupResumeAfterCopyTable
{
    [self tryAlterSoupInterruptResume:SFAlterSoupStepCopyTable];
}

-(void) testAlterSoupResumeAfterReIndexSoup
{
    [self tryAlterSoupInterruptResume:SFAlterSoupStepReIndexSoup];
}

-(void) testAlterSoupResumeAfterDropOldTable
{
    [self tryAlterSoupInterruptResume:SFAlterSoupStepDropOldTable];
}

#pragma mark - helper methods

- (void) alterSoupHelper:(BOOL)reIndexData
{
    NSArray* indexSpecs = [SFSoupIndex asArraySoupIndexes:@[@{@"path": kLastName, @"type": @"string"}, @{@"path": kAddressCity, @"type": @"string"}]];
    XCTAssertFalse([self.store soupExists:kTestSoupName], "Test soup should not exists");
    [self.store registerSoup:kTestSoupName withIndexSpecs:indexSpecs];
    XCTAssertTrue([self.store soupExists:kTestSoupName], "Register soup call failed");
    
    NSArray* savedEntries = [self.store upsertEntries:@[@{kLastName:@"Doe", kAddress: @{kCity: @"San Francisco", kStreet: @"1 market"}},
                                                        @{kLastName:@"Jackson", kAddress: @{kCity: @"Los Angeles", kStreet: @"100 mission"}},
                                                        @{kLastName:@"Watson", kAddress: @{kCity: @"London", kStreet: @"50 market"}}]
                                               toSoup:kTestSoupName];
    

    // Check indices
    NSArray* actualIndexSpecs = [self.store indicesForSoup:kTestSoupName];
    [self checkIndexSpecs:actualIndexSpecs withExpectedIndexSpecs:indexSpecs checkColumnName:NO];
    
    // Check soup table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:kTestSoupTableName forColumns:nil orderBy:@"id ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        [self checkSoupRow:frs withExpectedEntry:savedEntries[0] withSoupIndexes:actualIndexSpecs];
        [self checkSoupRow:frs withExpectedEntry:savedEntries[1] withSoupIndexes:actualIndexSpecs];
        [self checkSoupRow:frs withExpectedEntry:savedEntries[2] withSoupIndexes:actualIndexSpecs];
        XCTAssertFalse([frs next], @"Only three rows should have been returned");
        [frs close];
    }];
    
    // Alter soup - country now string
    NSArray* indexSpecsNew = [SFSoupIndex asArraySoupIndexes:@[@{@"path": kLastName, @"type": @"string"}, @{@"path": kAddressStreet, @"type": @"string"}]];
    [self.store alterSoup:kTestSoupName withIndexSpecs:indexSpecsNew reIndexData:reIndexData];
    
    // Check indices
    NSArray* actualIndexSpecsNew = [self.store indicesForSoup:kTestSoupName];
    [self checkIndexSpecs:actualIndexSpecsNew withExpectedIndexSpecs:indexSpecsNew checkColumnName:NO];
    
    // Check soup table
    [self.store.storeQueue inDatabase:^(FMDatabase *db) {
        FMResultSet* frs = [self.store queryTable:kTestSoupTableName forColumns:nil orderBy:@"id ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
        
        for (int i=0; i<3; i++) {
            [frs next];
            XCTAssertEqualObjects(@([frs longForColumn:ID_COL]), savedEntries[i][SOUP_ENTRY_ID], "Wrong id");
            XCTAssertEqualObjects([frs stringForColumn:kLastNameCol], savedEntries[i][kLastName], "Wrong name");
            if (reIndexData) {
                XCTAssertEqualObjects([frs stringForColumn:kAddressStreetCol], savedEntries[i][kAddress][kStreet], "Wrong street");
            }
            else {
                XCTAssertNil([frs stringForColumn:kAddressStreetCol], "Wrong street - nil expected");
            }
        }
        XCTAssertFalse([frs next], @"Only three rows should have been returned");
        [frs close];
    }];
}

- (void) tryAlterSoupInterruptResume:(SFAlterSoupStep)toStep
{
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // Before
        XCTAssertFalse([store soupExists:kTestSoupName], @"Soup %@ should not exist", kTestSoupName);
 
        // Register
        NSDictionary* lastNameSoupIndex = @{@"path": @"lastName",@"type": @"string"};
        NSArray* indexSpecs = [SFSoupIndex asArraySoupIndexes:@[lastNameSoupIndex]];
        [store registerSoup:kTestSoupName withIndexSpecs:indexSpecs];
        BOOL testSoupExists = [store soupExists:kTestSoupName];
        XCTAssertTrue(testSoupExists, @"Soup %@ should exist", kTestSoupName);
        __block NSString* soupTableName;
        [store.storeQueue inDatabase:^(FMDatabase *db) {
            soupTableName = [store tableNameForSoup:kTestSoupName withDb:db];
        }];
        
        // Populate soup
        NSArray* entries = [SFJsonUtils objectFromJSONString:@"[{\"lastName\":\"Doe\", \"address\":{\"city\":\"San Francisco\",\"street\":\"1 market\"}},"
                            "{\"lastName\":\"Jackson\", \"address\":{\"city\":\"Los Angeles\",\"street\":\"100 mission\"}}]"];
        NSArray* insertedEntries  =[store upsertEntries:entries toSoup:kTestSoupName];
        
        // Partial alter - up to toStep included
        NSDictionary* citySoupIndex = @{@"path": @"address.city",@"type": @"string"};
        NSDictionary* streetSoupIndex = @{@"path": @"address.street",@"type": @"string"};
        NSArray* indexSpecsNew = [SFSoupIndex asArraySoupIndexes:@[lastNameSoupIndex, citySoupIndex, streetSoupIndex]];
        SFAlterSoupLongOperation* operation = [[SFAlterSoupLongOperation alloc] initWithStore:store soupName:kTestSoupName newIndexSpecs:indexSpecsNew reIndexData:YES];
        [operation runToStep:toStep];
        
        // Validate long_operations_status table
        NSArray* operations = [store getLongOperations];
        NSInteger expectedCount = (toStep == kLastStep ? 0 : 1);
        XCTAssertTrue([operations count] == expectedCount, @"Wrong number of long operations found");
        if ([operations count] > 0) {
            // Check details
            SFAlterSoupLongOperation* actualOperation = (SFAlterSoupLongOperation*)operations[0];
            XCTAssertEqualObjects(actualOperation.soupName, kTestSoupName, @"Wrong soup name");
            XCTAssertEqualObjects(actualOperation.soupTableName, soupTableName, @"Wrong soup name");
            XCTAssertTrue(actualOperation.reIndexData, @"Wrong re-index data");
            
            // Check last step completed
            XCTAssertEqual(actualOperation.afterStep, toStep, @"Wrong step");
            
            // Simulate restart (clear cache and call resumeLongOperations)
            // TODO clear memory cache
            [store resumeLongOperations];
            
            // Check that long operations table is now empty
            XCTAssertTrue([[store getLongOperations] count] == 0, @"There should be no long operations left");
            
            // Check index specs
            NSArray* actualIndexSpecs = [store indicesForSoup:kTestSoupName];
            [self checkIndexSpecs:actualIndexSpecs withExpectedIndexSpecs:[SFSoupIndex asArraySoupIndexes:indexSpecsNew] checkColumnName:NO];
            
            // Check data
            [store.storeQueue inDatabase:^(FMDatabase *db) {
                FMResultSet* frs = [store queryTable:soupTableName forColumns:nil orderBy:@"id ASC" limit:nil whereClause:nil whereArgs:nil withDb:db];
                [self checkSoupRow:frs withExpectedEntry:insertedEntries[0] withSoupIndexes:actualIndexSpecs];
                [self checkSoupRow:frs withExpectedEntry:insertedEntries[1] withSoupIndexes:actualIndexSpecs];
                XCTAssertFalse([frs next], @"Only two rows should have been returned");
                [frs close];
            }];
        }
    }
}

- (void) checkIndexSpecs:(NSArray*)actualSoupIndexes withExpectedIndexSpecs:(NSArray*)expectedSoupIndexes checkColumnName:(BOOL)checkColumnName
{
    XCTAssertTrue([actualSoupIndexes count] == [expectedSoupIndexes count], @"Wrong number of index specs");
    for (int i = 0; i<[expectedSoupIndexes count]; i++) {
        SFSoupIndex* actualSoupIndex = ((SFSoupIndex*)actualSoupIndexes[i]);
        SFSoupIndex* expectedSoupIndex = ((SFSoupIndex*)expectedSoupIndexes[i]);
        XCTAssertEqualObjects(actualSoupIndex.path, expectedSoupIndex.path, @"Wrong path");
        XCTAssertEqualObjects(actualSoupIndex.indexType, expectedSoupIndex.indexType, @"Wrong type");
        if (checkColumnName) {
            XCTAssertEqualObjects(actualSoupIndex.columnName, expectedSoupIndex.columnName, @"Wrong column name");
        }
    }
}

@end
