/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSmartStoreTests.h"
#import <SalesforceSDKCommon/SalesforceSDKCommon-Swift.h>
#import <SalesforceSDKCommon/SFJsonUtils.h>
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueue.h"
#import "SFQuerySpec.h"
#import "SFStoreCursor.h"
#import "SFSmartStoreDatabaseManager.h"
#import "SFSmartStore+Internal.h"
#import "SFSoupIndex.h"
#import <SalesforceSDKCore/SalesforceSDKCore-Swift.h>
#import <SalesforceSDKCore/NSString+SFAdditions.h>
#import <SalesforceSDKCore/NSData+SFAdditions.h>
#import "sqlite3.h"

#define kTestSmartStoreName  @"testSmartStore"
#define kTestSoupName        @"testSoup"

@interface SFSmartStore (Tests)
+ (void)setJsonSerializationCheckEnabled:(BOOL)jsonSerializationCheckEnabled;
@end

@implementation SFSmartStoreTests


#pragma mark - setup and teardown

- (void) setUp
{
    [super setUp];
    [SFSDKSmartStoreLogger setLogLevel:SFLogLevelDebug];
    self.smartStoreUser = [self setUpSmartStoreUser];
    self.store = [SFSmartStore sharedStoreWithName:kTestSmartStoreName];
    self.globalStore = [SFSmartStore sharedGlobalStoreWithName:kTestSmartStoreName];
    self.store.captureExplainQueryPlan = YES;
    self.globalStore.captureExplainQueryPlan = YES;
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
 * Test to check compile options
 */
- (void) testCompileOptions
{
    NSArray* options = [self.store getCompileOptions];

    XCTAssertTrue([options containsObject:@"ENABLE_FTS4"]);
    XCTAssertTrue([options containsObject:@"ENABLE_FTS3_PARENTHESIS"]);
    XCTAssertTrue([options containsObject:@"ENABLE_FTS5"]);
}

/**
 * Test to check runtime settings
 */
- (void) testRuntimeSettings
{
    NSArray* settings = [self.store getRuntimeSettings];
    
    // Make sure run time settings are 4.x settings except for kdf_iter
    XCTAssertTrue([settings containsObject:@"PRAGMA kdf_iter = 4000;"]);
    XCTAssertTrue([settings containsObject:@"PRAGMA cipher_page_size = 4096;"]);
    XCTAssertTrue([settings containsObject:@"PRAGMA cipher_use_hmac = 1;"]);
    XCTAssertTrue([settings containsObject:@"PRAGMA cipher_plaintext_header_size = 0;"]);
    XCTAssertTrue([settings containsObject:@"PRAGMA cipher_hmac_algorithm = HMAC_SHA512;"]);
    XCTAssertTrue([settings containsObject:@"PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512;"]);
}

- (void) testSqliteVersion
{
    NSString* version = [NSString stringWithUTF8String:sqlite3_libversion()];
    XCTAssertEqualObjects(version, @"3.49.2");
}

- (void) testSqlCipherVersion
{
    NSString* version = [self.store getSQLCipherVersion];
    XCTAssertEqualObjects(version, @"4.9.0 community");
}

- (void) testCipherProviderVersion
{
    NSString* cipherProviderVersion = [self.store getCipherProviderVersion];
    XCTAssertEqualObjects(cipherProviderVersion, @"unknown");
}

- (void) testCipherFIPSStatus
{
    BOOL cipherFIPSStatus = [self.store getCipherFIPSStatus];
    XCTAssertFalse(cipherFIPSStatus);
}

/**
 * Test fts extension
 */
- (void) testFtsExtension
{
    XCTAssertEqual(self.store.ftsExtension, 5, @"Expected FTS5");
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

/**
 * Testing method with paths to top level string/integer/array/map as well as edge cases (nil object/nil or empty path)
 */
- (void) testProjectTopLevel
{
    NSString* rawJson = @"{\"a\":\"va\", \"b\":2, \"c\":[0,1,2], \"d\": {\"d1\":\"vd1\", \"d2\":\"vd2\", \"d3\":[1,2], \"d4\":{\"e\":5}}}";
    NSDictionary* json = [SFJsonUtils objectFromJSONString:rawJson];
    
    // Null object
    XCTAssertNil([SFJsonUtils projectIntoJson:nil path:@"path"], @"Should have been null");
    
    // Root object
    [self assertSameJSONWithExpected:json actual:[SFJsonUtils projectIntoJson:json path:nil] message:@"Should have returned whole object"];
    [self assertSameJSONWithExpected:json actual:[SFJsonUtils projectIntoJson:json path:@""] message:@"Should have returned whole object"];
    
    // Top-level elements
    [self assertSameJSONWithExpected:@"va" actual:[SFJsonUtils projectIntoJson:json path:@"a"] message:@"Wrong value for key a"];
    [self assertSameJSONWithExpected:@2 actual:[SFJsonUtils projectIntoJson:json path:@"b"] message:@"Wrong value for key b"];
    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"[0,1,2]"] actual:[SFJsonUtils projectIntoJson:json path:@"c"] message:@"Wrong value for key c"];
    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"{\"d1\":\"vd1\", \"d2\":\"vd2\", \"d3\":[1,2], \"d4\":{\"e\":5}}"] actual:[SFJsonUtils projectIntoJson:json path:@"d"] message:@"Wrong value for key d"];
}

#pragma clang diagnostic pop

/**
  * Testing method with paths to non-top level string/integer/array/map
  */
- (void) testProjectNested
{
    NSString* rawJson = @"{\"a\":\"va\", \"b\":2, \"c\":[0,1,2], \"d\": {\"d1\":\"vd1\", \"d2\":\"vd2\", \"d3\":[1,2], \"d4\":{\"e\":5}}}";    
    NSDictionary* json = [SFJsonUtils objectFromJSONString:rawJson];

    // Nested elements
    [self assertSameJSONWithExpected:@"vd1" actual:[SFJsonUtils projectIntoJson:json path:@"d.d1"] message:@"Wrong value for key d.d1"];
    [self assertSameJSONWithExpected:@"vd2" actual:[SFJsonUtils projectIntoJson:json path:@"d.d2"] message:@"Wrong value for key d.d2"];    
    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"[1,2]"] actual:[SFJsonUtils projectIntoJson:json path:@"d.d3"] message:@"Wrong value for key d.d3"];    
    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"{\"e\":5}"] actual:[SFJsonUtils projectIntoJson:json path:@"d.d4"] message:@"Wrong value for key d.d4"];        
    [self assertSameJSONWithExpected:@5 actual:[SFJsonUtils projectIntoJson:json path:@"d.d4.e"] message:@"Wrong value for key d.d4.e"];    
}

/**
  * Testing method with path through arrays
  */
- (void) testProjectThroughArrays
{
    NSString* rawJson = @"{\"a\":\"a1\", \"b\":2, \"c\":[{\"cc\":\"cc1\"}, {\"cc\":2}, {\"cc\":[1,2,3]}, {}, {\"cc\":{\"cc5\":5}}], \"d\":[{\"dd\":[{\"ddd\":\"ddd11\"},{\"ddd\":\"ddd12\"}]}, {\"dd\":[{\"ddd\":\"ddd21\"}]}, {\"dd\":[{\"ddd\":\"ddd31\"},{\"ddd3\":\"ddd32\"}]}]}";
    NSDictionary* json = [SFJsonUtils objectFromJSONString:rawJson];
    
    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"[{\"cc\":\"cc1\"}, {\"cc\":2}, {\"cc\":[1,2,3]}, {}, {\"cc\":{\"cc5\":5}}]"] actual:[SFJsonUtils projectIntoJson:json path:@"c"] message:@"Wrong value for key c"];

    
    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"[\"cc1\",2, [1,2,3], {\"cc5\":5}]"] actual:[SFJsonUtils projectIntoJson:json path:@"c.cc"] message:@"Wrong value for key c.cc"];

    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"[5]"] actual:[SFJsonUtils projectIntoJson:json path:@"c.cc.cc5"] message:@"Wrong value for key c.cc.cc5"];
    
    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"[{\"dd\":[{\"ddd\":\"ddd11\"},{\"ddd\":\"ddd12\"}]}, {\"dd\":[{\"ddd\":\"ddd21\"}]}, {\"dd\":[{\"ddd\":\"ddd31\"},{\"ddd3\":\"ddd32\"}]}]"] actual:[SFJsonUtils projectIntoJson:json path:@"d"] message:@"Wrong value for key d"];

    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"[[{\"ddd\":\"ddd11\"},{\"ddd\":\"ddd12\"}], [{\"ddd\":\"ddd21\"}], [{\"ddd\":\"ddd31\"},{\"ddd3\":\"ddd32\"}]]"] actual:[SFJsonUtils projectIntoJson:json path:@"d.dd"] message:@"Wrong value for key d.dd"];

    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"[[\"ddd11\",\"ddd12\"],[\"ddd21\"],[\"ddd31\"]]"] actual:[SFJsonUtils projectIntoJson:json path:@"d.dd.ddd"] message:@"Wrong value for key d.dd.ddd"];

    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"[[\"ddd32\"]]"] actual:[SFJsonUtils projectIntoJson:json path:@"d.dd.ddd3"] message:@"Wrong value for key d.dd.ddd3"];
    
    
}

/**
 * Check that the meta data tables (soup index map and soup names) have been created
 */
- (void) testMetaDataTablesCreated
{
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        BOOL hasSoupIndexMapTable = [self hasTable:@"soup_index_map" store:store];
        XCTAssertTrue(hasSoupIndexMapTable, @"Soup index map table not found");
        BOOL hasTableSoupAttrs = [self hasTable:@"soup_attrs" store:store];
        XCTAssertTrue(hasTableSoupAttrs, @"Soup attrs table not found");
    }
}

/**
 * Test register/remove soup with only string indexes
 * The underlying table's columns and indexes are checked
 */
- (void) testRegisterRemoveSoupWithStringIndexes {
    [self tryRegisterRemoveSoup:@"string"];
}

/**
 * Test register/remove soup with json1 and string indexes
 * The underlying table's columns and indexes are checked
 */
- (void) testRegisterRemoveSoupWithJSON1Indexes {
    [self tryRegisterRemoveSoup:@"json1"];
}

- (void) tryRegisterRemoveSoup:(NSString*)indexType
{
    NSUInteger const numRegisterAndDropIterations = 10;
    
    // Make sure you can register, drop, and re-add a soup through n iterations.
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        for (NSUInteger i = 0; i < numRegisterAndDropIterations; i++) {
            // Before
            XCTAssertFalse([store soupExists:kTestSoupName], @"In iteration %lu: Soup %@ should not exist before registration.", (i + 1), kTestSoupName);
            
            // Register
            NSError* error = nil;
            [store registerSoup:kTestSoupName
                 withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key",@"type": indexType}, @{@"path": @"value",@"type": @"string"}]]
                          error:&error];
            BOOL testSoupExists = [store soupExists:kTestSoupName];
            XCTAssertTrue(testSoupExists, @"In iteration %lu: Soup %@ should exist after registration.", (i + 1), kTestSoupName);
            XCTAssertNil(error, @"There should be no errors.");
            NSString* soupTableName = [self getSoupTableName:kTestSoupName store:store];
            
            // Check soup indexes
            NSString* expectedColumnName0 = ([indexType isEqualToString:@"json1"]
                                             ? @"json_extract(soup, '$.key')"
                                             : [NSString stringWithFormat:@"%@_0", soupTableName]);
            NSString* expectedColumnName1 = [NSString stringWithFormat:@"%@_1", soupTableName];

            NSArray* indexSpecs = [store indicesForSoup:kTestSoupName];
            [self checkSoupIndex:(SFSoupIndex*)indexSpecs[0] expectedPath:@"key" expectedType:indexType expectedColumnName:expectedColumnName0];
            [self checkSoupIndex:(SFSoupIndex*)indexSpecs[1] expectedPath:@"value" expectedType:@"string" expectedColumnName:expectedColumnName1];

            // Check db columns
            NSArray* expectedColumns = ([indexType isEqualToString:@"json1"]
                                        ? @[@"id", @"soup", @"created", @"lastModified", expectedColumnName1]
                                        : @[@"id", @"soup", @"created", @"lastModified", expectedColumnName0, expectedColumnName1]);
            [self checkColumns:soupTableName
               expectedColumns:expectedColumns
                         store:store];
            
            // Check db indexes
            NSString* indexSqlFormat = @"CREATE INDEX %@_%@_idx ON %1$@ ( %3$@ )";
            [self checkDatabaseIndexes:soupTableName
                 expectedSqlStatements:@[ [NSString stringWithFormat:indexSqlFormat, soupTableName, @"0", expectedColumnName0],
                                          [NSString stringWithFormat:indexSqlFormat, soupTableName, @"1", expectedColumnName1],
                                          [NSString stringWithFormat:indexSqlFormat, soupTableName, @"created", @"created"],
                                          [NSString stringWithFormat:indexSqlFormat, soupTableName, @"lastModified", @"lastModified"]
                                         ]
                                 store:store];
            
            // Remove
            [store removeSoup:kTestSoupName];
            testSoupExists = [store soupExists:kTestSoupName];
            XCTAssertFalse(testSoupExists, @"In iteration %lu: Soup %@ should no longer exist after dropping.", (i + 1), kTestSoupName);
        }
    }
}

/**
 * Test query when looking for all elements when soup has string index
 */
-(void) testAllQueryWithStringIndex
{
    [self tryAllQuery:kSoupIndexTypeString];
}

/**
 * Test query when looking for all elements when soup has json1 index
 */
-(void) testAllQueryWithJSON1Index
{
    [self tryAllQuery:kSoupIndexTypeJSON1];
}

/**
 * Test query when looking for all elements
 */
-(void) tryAllQuery:(NSString*)indexType
{
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // Before
        XCTAssertFalse([store soupExists:kTestSoupName], @"%@ should not exist before registration.", kTestSoupName);
        
        // Register
        NSError* error = nil;
        [store registerSoup:kTestSoupName
             withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key",@"type": indexType}]]
                      error:&error];
        BOOL testSoupExists = [store soupExists:kTestSoupName];
        XCTAssertTrue(testSoupExists, @"Soup %@ should exist after registration.", kTestSoupName);
        XCTAssertNil(error, @"There should be no errors.");

        // Populate soup
        NSDictionary* soupElt0 = @{@"key": @"ka1", @"value":@"va1", @"otherValue":@"ova1"};
        NSDictionary* soupElt1 = @{@"key": @"ka2", @"value":@"va2", @"otherValue":@"ova2"};
        NSDictionary* soupElt2 = @{@"key": @"ka3", @"value":@"va3", @"otherValue":@"ova3"};

        NSArray* soupEltsCreated = [store upsertEntries:@[soupElt0, soupElt1, soupElt2] toSoup:kTestSoupName];
        
        // Query all - small page
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newAllQuerySpec:kTestSoupName withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:2]
                                            page:0
                                 expectedResults:@[soupEltsCreated[0], soupEltsCreated[1]]
                                        covering:NO
                             expectedDbOperation:@"SCAN"
                                           store:store];
        
        // Query all - next small page
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newAllQuerySpec:kTestSoupName withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:2]
                                            page:1
                                 expectedResults:@[soupEltsCreated[2]]
                                        covering:NO
                             expectedDbOperation:@"SCAN"
                                           store:store];

        // Query all - large page
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newAllQuerySpec:kTestSoupName withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:10]
                                            page:0
                                 expectedResults:@[soupEltsCreated[0], soupEltsCreated[1], soupEltsCreated[2]]
                                        covering:NO
                             expectedDbOperation:@"SCAN"
                                           store:store];

        // Query all with select paths
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newAllQuerySpec:kTestSoupName withSelectPaths:@[@"key"] withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:10]
                                            page:0
                                 expectedResults:@[@[@"ka1"], @[@"ka2"], @[@"ka3"]]
                                        covering:YES
                             expectedDbOperation:@"SCAN"
                                           store:store];

    }
}

/**
 * Test range query when soup has string index
 */
-(void) testRangeQueryWithStringIndex
{
    [self tryRangeQuery:kSoupIndexTypeString];
}

/**
 * Test range query when soup has json1 index
 */
-(void) testRangeQueryWithJSON1Index
{
    [self tryRangeQuery:kSoupIndexTypeJSON1];
}

/**
 * Test range query
 */
-(void) tryRangeQuery:(NSString*)indexType
{
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // Before
        XCTAssertFalse([store soupExists:kTestSoupName], @"%@ should not exist before registration.", kTestSoupName);
        
        // Register
        NSError* error = nil;
        [store registerSoup:kTestSoupName
             withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key",@"type": indexType}]]
                      error:&error];
        BOOL testSoupExists = [store soupExists:kTestSoupName];
        XCTAssertTrue(testSoupExists, @"Soup %@ should exist after registration.", kTestSoupName);
        XCTAssertNil(error, @"There should be no errors.");
        
        // Populate soup
        NSDictionary* soupElt0 = @{@"key": @"ka1", @"value":@"va1", @"otherValue":@"ova1"};
        NSDictionary* soupElt1 = @{@"key": @"ka2", @"value":@"va2", @"otherValue":@"ova2"};
        NSDictionary* soupElt2 = @{@"key": @"ka3", @"value":@"va3", @"otherValue":@"ova3"};
        
        NSArray* soupEltsCreated = [store upsertEntries:@[soupElt0, soupElt1, soupElt2] toSoup:kTestSoupName];
        
        // Range query
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newRangeQuerySpec:kTestSoupName withPath:@"key" withBeginKey:@"ka2" withEndKey:@"ka3" withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:10]
                                            page:0
                                 expectedResults:@[soupEltsCreated[1], soupEltsCreated[2]]
                                        covering:NO
                             expectedDbOperation:@"SEARCH"
                                           store:store];
        
        // Range query - descending order
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newRangeQuerySpec:kTestSoupName withPath:@"key" withBeginKey:@"ka2" withEndKey:@"ka3" withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderDescending withPageSize:10]
                                            page:0
                                 expectedResults:@[soupEltsCreated[2], soupEltsCreated[1]]
                                        covering:NO
                             expectedDbOperation:@"SEARCH"
                                           store:store];
        

        // Range query with select paths
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newRangeQuerySpec:kTestSoupName withSelectPaths:@[@"key"] withPath:@"key" withBeginKey:@"ka2" withEndKey:@"ka3" withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderDescending withPageSize:10]
                                            page:0
                                 expectedResults:@[@[@"ka3"], @[@"ka2"]]
                                        covering:YES
                             expectedDbOperation:@"SEARCH"
                                           store:store];
        
    }
}

/**
 * Test like query when soup has string index
 */
-(void) testLikeQueryWithStringIndex
{
    [self tryLikeQuery:kSoupIndexTypeString];
}

/**
 * Test like query when soup has json1 index
 */
-(void) testLikeQueryWithJSON1Index
{
    [self tryLikeQuery:kSoupIndexTypeJSON1];
}

/**
 * Test like query
 */
-(void) tryLikeQuery:(NSString*)indexType
{
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // Before
        XCTAssertFalse([store soupExists:kTestSoupName], @"%@ should not exist before registration.", kTestSoupName);
        
        // Register
        NSError* error = nil;
        [store registerSoup:kTestSoupName
             withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key",@"type": indexType}]]
                      error:&error];
        BOOL testSoupExists = [store soupExists:kTestSoupName];
        XCTAssertTrue(testSoupExists, @"Soup %@ should exist after registration.", kTestSoupName);
        XCTAssertNil(error, @"There should be no errors.");
        
        // Populate soup
        NSDictionary* soupElt0 = @{@"key": @"abcd", @"value":@"va1", @"otherValue":@"ova1"};
        NSDictionary* soupElt1 = @{@"key": @"bbcd", @"value":@"va2", @"otherValue":@"ova2"};
        NSDictionary* soupElt2 = @{@"key": @"abcc", @"value":@"va3", @"otherValue":@"ova3"};
        NSDictionary* soupElt3 = @{@"key": @"defg", @"value":@"va1", @"otherValue":@"ova1"};

        
        NSArray* soupEltsCreated = [store upsertEntries:@[soupElt0, soupElt1, soupElt2, soupElt3] toSoup:kTestSoupName];
        
         // Like query (starts with)
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newLikeQuerySpec:kTestSoupName withPath:@"key" withLikeKey:@"abc%" withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:10]
                                            page:0
                                 expectedResults:@[soupEltsCreated[2], soupEltsCreated[0]]
                                        covering:NO
                             expectedDbOperation:@"SCAN"
                                           store:store];
        
         
         // Like query (ends with)
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newLikeQuerySpec:kTestSoupName withPath:@"key" withLikeKey:@"%bcd" withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:10]
                                            page:0
                                 expectedResults:@[soupEltsCreated[0], soupEltsCreated[1]]
                                        covering:NO
                             expectedDbOperation:@"SCAN"
                                           store:store];
        
         
         // Like query (starts with) - descending order
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newLikeQuerySpec:kTestSoupName withPath:@"key" withLikeKey:@"abc%" withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderDescending withPageSize:10]
                                            page:0
                                 expectedResults:@[soupEltsCreated[0], soupEltsCreated[2]]
                                        covering:NO
                             expectedDbOperation:@"SCAN"
                                           store:store];
        
         
         // Like query (ends with) - descending order
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newLikeQuerySpec:kTestSoupName withPath:@"key" withLikeKey:@"%bcd" withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderDescending withPageSize:10]
                                            page:0
                                 expectedResults:@[soupEltsCreated[1], soupEltsCreated[0]]
                                        covering:NO
                             expectedDbOperation:@"SCAN"
                                           store:store];
        
         
         // Like query (contains)
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newLikeQuerySpec:kTestSoupName withPath:@"key" withLikeKey:@"%bc%" withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:10]
                                            page:0
                                 expectedResults:@[soupEltsCreated[2], soupEltsCreated[0], soupEltsCreated[1]]
                                        covering:NO
                             expectedDbOperation:@"SCAN"
                                           store:store];
        
         
         // Like query (contains) - descending order
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newLikeQuerySpec:kTestSoupName withPath:@"key" withLikeKey:@"%bc%" withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderDescending withPageSize:10]
                                            page:0
                                 expectedResults:@[soupEltsCreated[1], soupEltsCreated[0], soupEltsCreated[2]]
                                        covering:NO
                             expectedDbOperation:@"SCAN"
                                           store:store];

        // Like query (contains) with select paths
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newLikeQuerySpec:kTestSoupName withSelectPaths:@[@"key"] withPath:@"key" withLikeKey:@"%bc%" withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderDescending withPageSize:10]
                                            page:0
                                 expectedResults:@[@[@"bbcd"], @[@"abcd"], @[@"abcc"]]
                                        covering:YES
                             expectedDbOperation:@"SCAN"
                                           store:store];
    
    }
}

/**
 * Test smart query when soup has string index
 */
-(void) testSmartQueryWithStringIndex
{
    [self trySmartQuery:kSoupIndexTypeString];
}

/**
 * Test smart query when soup has json1 index
 */
-(void) testSmartQueryWithJSON1Index
{
    [self trySmartQuery:kSoupIndexTypeJSON1];
}

/**
 * Test smart query
 */
-(void) trySmartQuery:(NSString*)indexType
{
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // Before
        XCTAssertFalse([store soupExists:kTestSoupName], @"%@ should not exist before registration.", kTestSoupName);
        
        // Register
        NSError* error = nil;
        [store registerSoup:kTestSoupName
             withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key",@"type": indexType}]]
                      error:&error];
        BOOL testSoupExists = [store soupExists:kTestSoupName];
        XCTAssertTrue(testSoupExists, @"Soup %@ should exist after registration.", kTestSoupName);
        XCTAssertNil(error, @"There should be no errors.");
        
        // Populate soup
        NSDictionary* soupElt0 = @{@"key": @"abcd", @"value":@"va1", @"otherValue":@"ova1"};
        NSDictionary* soupElt1 = @{@"key": @"bbcd", @"value":@"va2", @"otherValue":@"ova2"};
        NSDictionary* soupElt2 = @{@"key": @"abcc", @"value":@"va3", @"otherValue":@"ova3"};
        NSDictionary* soupElt3 = @{@"key": @"defg", @"value":@"va1", @"otherValue":@"ova1"};
        
        
        /* NSArray* soupEltsCreated = */[store upsertEntries:@[soupElt0, soupElt1, soupElt2, soupElt3] toSoup:kTestSoupName];
        
        // Smart query
        NSString* smartSql = [NSString stringWithFormat:@"SELECT {%1$@:key} FROM {%1$@} WHERE {%1$@:key} LIKE 'abc%%' ORDER BY {%1$@:key}", kTestSoupName];
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newSmartQuerySpec:smartSql withPageSize:10]
                                            page:0
                                 expectedResults:@[@[@"abcc"], @[@"abcd"]]
                                        covering:YES
                             expectedDbOperation:@"SCAN"
                                           store:store];
        // Anoter smart query
        smartSql = [NSString stringWithFormat:@"SELECT {%1$@:key} FROM {%1$@} ORDER BY {%1$@:key}", kTestSoupName];
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newSmartQuerySpec:smartSql withPageSize:2]
                                            page:0
                                 expectedResults:@[@[@"abcc"], @[@"abcd"]]
                                        covering:YES
                             expectedDbOperation:@"SCAN"
                                           store:store];
    }
}

/**
 * Test query against soup with special characters when soup has string index
 */
-(void) testQueryDataWithSpecialCharactersWithStringIndex
{
    [self tryQueryDataWithSpecialCharacters:kSoupIndexTypeString];
}

/**
 * Test query against soup with special characters when soup has json1 index
 */
-(void) testQueryDataWithSpecialCharactersWithJSON1Index
{
    [self tryQueryDataWithSpecialCharacters:kSoupIndexTypeJSON1];
}

-(void) tryQueryDataWithSpecialCharacters:(NSString*)indexType
{
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // Before
        XCTAssertFalse([store soupExists:kTestSoupName], @"%@ should not exist before registration.", kTestSoupName);
        
        // Register
        NSError* error = nil;
        [store registerSoup:kTestSoupName
             withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key",@"type": indexType}, @{@"path": @"value",@"type": indexType}]]
                      error:&error];
        BOOL testSoupExists = [store soupExists:kTestSoupName];
        XCTAssertTrue(testSoupExists, @"Soup %@ should exist after registration.", kTestSoupName);
        XCTAssertNil(error, @"There should be no errors.");
        
        
        NSMutableString* value = [NSMutableString new];
        for (unichar i=1; i<1000; i++) {
            [value appendFormat:@"%C", i];
        }
        NSString* valueForAbcd = [NSString stringWithFormat:@"abcd%@", value];
        NSString* valueForDefg = [NSString stringWithFormat:@"defg%@", value];

        // Populate soup
        NSDictionary* soupElt0 = @{@"key": @"abcd", @"value":valueForAbcd};
        NSDictionary* soupElt1 = @{@"key": @"defg", @"value":valueForDefg};
        
        /* NSArray* soupEltsCreated = */[store upsertEntries:@[soupElt0, soupElt1] toSoup:kTestSoupName];
        
        // Smart query
        NSString* smartSql = [NSString stringWithFormat:@"SELECT {%1$@:value} FROM {%1$@} ORDER BY {%1$@:key}", kTestSoupName];
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newSmartQuerySpec:smartSql withPageSize:10]
                                            page:0
                                 expectedResults:@[@[valueForAbcd], @[valueForDefg]]
                                        covering:NO
                             expectedDbOperation:nil
                                           store:store];
    }
}

/**
 * Test remove entries with ids
 */
-(void) testRemoveEntriesByIds
{
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // Before
        XCTAssertFalse([store soupExists:kTestSoupName], @"%@ should not exist before registration.", kTestSoupName);
        
        // Register
        NSError* error = nil;
        [store registerSoup:kTestSoupName
             withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key",@"type": kSoupIndexTypeString}]]
                      error:&error];
        BOOL testSoupExists = [store soupExists:kTestSoupName];
        XCTAssertTrue(testSoupExists, @"Soup %@ should exist after registration.", kTestSoupName);
        XCTAssertNil(error, @"There should be no errors.");
        
        // Populate soup
        NSDictionary* soupElt0 = @{@"key": @"abcd", @"value":@"va1", @"otherValue":@"ova1"};
        NSDictionary* soupElt1 = @{@"key": @"bbcd", @"value":@"va2", @"otherValue":@"ova2"};
        NSDictionary* soupElt2 = @{@"key": @"abcc", @"value":@"va3", @"otherValue":@"ova3"};
        NSDictionary* soupElt3 = @{@"key": @"defg", @"value":@"va1", @"otherValue":@"ova1"};
        
        
        NSArray* soupEltsCreated = [store upsertEntries:@[soupElt0, soupElt1, soupElt2, soupElt3] toSoup:kTestSoupName];
        
        // Remove two entries
        [store removeEntries:@[soupEltsCreated[1][SOUP_ENTRY_ID], soupEltsCreated[3][SOUP_ENTRY_ID]] fromSoup:kTestSoupName error:&error];
        XCTAssertNil(error, @"There should be no errors.");
        

        // Query all and make sure the two entries are gone
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newAllQuerySpec:kTestSoupName withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:10]
                                            page:0
                                 expectedResults:@[soupEltsCreated[2], soupEltsCreated[0]]
                                        covering:NO
                             expectedDbOperation:@"SCAN"
                                           store:store];

        // Remove one more entry
        [store removeEntries:@[soupEltsCreated[0][SOUP_ENTRY_ID]] fromSoup:kTestSoupName error:&error];
        XCTAssertNil(error, @"There should be no errors.");
        
        // Query all and make sure the removed entry is gone
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newAllQuerySpec:kTestSoupName withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:10]
                                            page:0
                                 expectedResults:@[soupEltsCreated[2]]
                                        covering:NO
                             expectedDbOperation:@"SCAN"
                                           store:store];
    
    }
}

/**
 * Test remove entries by query
 */
-(void) testRemoveEntriesByQuery
{
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // Before
        XCTAssertFalse([store soupExists:kTestSoupName], @"%@ should not exist before registration.", kTestSoupName);
        
        // Register
        NSError* error = nil;
        [store registerSoup:kTestSoupName
             withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key",@"type": kSoupIndexTypeString}]]
                      error:&error];
        BOOL testSoupExists = [store soupExists:kTestSoupName];
        XCTAssertTrue(testSoupExists, @"Soup %@ should exist after registration.", kTestSoupName);
        XCTAssertNil(error, @"There should be no errors.");
        
        // Populate soup
        NSDictionary* soupElt0 = @{@"key": @"abcd", @"value":@"va1", @"otherValue":@"ova1"};
        NSDictionary* soupElt1 = @{@"key": @"bbcd", @"value":@"va2", @"otherValue":@"ova2"};
        NSDictionary* soupElt2 = @{@"key": @"abcc", @"value":@"va3", @"otherValue":@"ova3"};
        NSDictionary* soupElt3 = @{@"key": @"defg", @"value":@"va1", @"otherValue":@"ova1"};
        
        
        NSArray* soupEltsCreated = [store upsertEntries:@[soupElt0, soupElt1, soupElt2, soupElt3] toSoup:kTestSoupName];
        
        // Remove two entries
        [store removeEntriesByQuery:[SFQuerySpec newLikeQuerySpec:kTestSoupName withPath:@"key" withLikeKey:@"abc%" withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:10]
                           fromSoup:kTestSoupName
                              error:&error];
        XCTAssertNil(error, @"There should be no errors.");
        
        
        // Query all and make sure the removed entries are gone
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newAllQuerySpec:kTestSoupName withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:10]
                                            page:0
                                 expectedResults:@[soupEltsCreated[1], soupEltsCreated[3]]
                                        covering:NO
                             expectedDbOperation:@"SCAN"
                                           store:store];
        
        // Remove one more entry using a query all with page size of 1
        [store removeEntriesByQuery:[SFQuerySpec newAllQuerySpec:kTestSoupName withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1]
                           fromSoup:kTestSoupName
                              error:&error];
        XCTAssertNil(error, @"There should be no errors.");

        
        // Query all and make sure the removed entry is gone
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newAllQuerySpec:kTestSoupName withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:10]
                                            page:0
                                 expectedResults:@[soupEltsCreated[3]]
                                        covering:NO
                             expectedDbOperation:@"SCAN"
                                           store:store];
        
    }
}


/**
 * Test to verify an aggregate query on floating point values indexed as floating.
 */
-(void) testAggregateQueryOnFloatingIndexedField
{
    [self tryAggregateQueryOnIndexedField:kSoupIndexTypeFloating];
}

/**
 * Test to verify an aggregate query on floating point values indexed as JSON1.
 */
- (void) testAggregateQueryOnJSON1IndexedField
{
    [self tryAggregateQueryOnIndexedField:kSoupIndexTypeJSON1];
}

- (void) tryAggregateQueryOnIndexedField:(NSString*) indexType
{
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // Before
        XCTAssertFalse([store soupExists:kTestSoupName], @"%@ should not exist before registration.", kTestSoupName);
        
        // Register
        NSError* error = nil;
        [store registerSoup:kTestSoupName
             withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"amount",@"type": indexType}]]
                      error:&error];
        BOOL testSoupExists = [store soupExists:kTestSoupName];
        XCTAssertTrue(testSoupExists, @"Soup %@ should exist after registration.", kTestSoupName);
        XCTAssertNil(error, @"There should be no errors.");
        
        // Populate soup
        NSDictionary* soupElt1 = @{@"amount": [NSNumber numberWithDouble:10.2]};
        NSDictionary* soupElt2 = @{@"amount": [NSNumber numberWithDouble:9.9]};
        [store upsertEntries:@[soupElt1, soupElt2] toSoup:kTestSoupName];
        
        // Aggregate query
        NSString* smartSql = [NSString stringWithFormat:@"SELECT SUM({%@:amount}) FROM {%@}", kTestSoupName, kTestSoupName];
        [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newSmartQuerySpec:smartSql withPageSize:10]
                                            page:0
                                 expectedResults:@[@[[NSNumber numberWithDouble:20.1]]]
                                        covering:NO
                             expectedDbOperation:nil
                                           store:store];
    }
}

-(void) runQueryCheckResultsAndExplainPlan:(SFQuerySpec*)querySpec page:(NSUInteger)page expectedResults:(NSArray*)expectedResults covering:(BOOL)covering expectedDbOperation:(NSString*)expectedDbOperation store:(SFSmartStore*)store
{
    // Run query
    NSError* error = nil;
    NSArray* results = [store queryWithQuerySpec:querySpec pageIndex:page error:&error];
    XCTAssertNil(error, @"There should be no errors.");
    
    // Check results
    [self assertSameJSONArrayWithExpected:expectedResults actual:results message:@"Wrong results"];
    
    // Check explain plan and make sure index was used unless caller passed nil for expectedDbOperation
    if (expectedDbOperation) {
        [self checkExplainQueryPlan:kTestSoupName index:0 covering:covering dbOperation:expectedDbOperation store:store];
    }
}

/**
 * Test smart sql returning entire soup elements (i.e. select {soup:_soup} from {soup})
 */
- (void) testSelectUnderscoreSoup
{
    // Create soup
    NSError* error = nil;
    [self.store registerSoup:kTestSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key",@"type": kSoupIndexTypeString}]] error:&error];

    // Create soup elements
    NSDictionary* soupElt1 = @{@"key":@"ka1", @"value":@"va1"};
    NSDictionary* soupElt2 = @{@"key":@"ka2", @"value":@"va2"};
    NSDictionary* soupElt3 = @{@"key":@"ka3", @"value":@"va3"};
    NSDictionary* soupElt4 = @{@"key":@"ka4", @"value":@"va4"};
    NSArray* soupEltsCreated = [self.store upsertEntries:@[soupElt1, soupElt2, soupElt3, soupElt4] toSoup:kTestSoupName];
    
    // Query _soup
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {%@:_soup} FROM {%@} ORDER BY {%@:key}", kTestSoupName, kTestSoupName, kTestSoupName];
    [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newSmartQuerySpec:smartSql withPageSize:10]
                                        page:0
                             expectedResults:@[@[soupEltsCreated[0]], @[soupEltsCreated[1]], @[soupEltsCreated[2]], @[soupEltsCreated[3]]]
                                    covering:NO
                         expectedDbOperation:@"SCAN"
                                       store:self.store];
}
    
    /**
     * Test smart sql returning entire soup elements from multiple soups
     */
- (void) testSelectUnderscoreSoupFromMultipleSoups
{
    // Create soups
    NSString* otherTestSoupName = @"otherTestSoup";
    NSError* error = nil;
    [self.store registerSoup:kTestSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key",@"type": kSoupIndexTypeString}]] error:&error];
    [self.store registerSoup:otherTestSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key",@"type": @"string"}]] error:&error];


    // Create soup elements
    NSDictionary* soupElt1 = @{@"key":@"ka1", @"value":@"va1"};
    NSDictionary* soupElt1Created = [self.store upsertEntries:@[soupElt1] toSoup:kTestSoupName][0];
    
    NSDictionary* soupElt2 = @{@"key":@"ka1", @"value":@"va1", @"otherValue":@"ova1"};
    NSDictionary* soupElt2Created = [self.store upsertEntries:@[soupElt2] toSoup:otherTestSoupName][0];

    // Query _soup from both soups
    NSString* smartSql = [NSString stringWithFormat:@"SELECT {%@:_soup}, {%@:_soup} FROM {%@}, {%@}", kTestSoupName, otherTestSoupName, kTestSoupName, otherTestSoupName];
    [self runQueryCheckResultsAndExplainPlan:[SFQuerySpec newSmartQuerySpec:smartSql withPageSize:10]
                                        page:0
                             expectedResults:@[@[soupElt1Created, soupElt2Created]]
                                    covering:NO
                         expectedDbOperation:nil
                                       store:self.store];
}

/**
 * Test registering same soup name multiple times.
 */
- (void) testMultipleRegisterSameSoup
{
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // Before
        BOOL testSoupExists = [store soupExists:kTestSoupName];
        XCTAssertFalse(testSoupExists, @"Soup %@ should not exist", kTestSoupName);
        
        // Register first time.
        NSDictionary* soupIndex = @{@"path": @"name",@"type": @"string"};
        NSError* error = nil;
        [store registerSoup:kTestSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]] error:&error];
        testSoupExists = [store soupExists:kTestSoupName];
        XCTAssertTrue(testSoupExists, @"Soup %@ should exist", kTestSoupName);
        XCTAssertNil(error, @"There should be no errors.");
        
        // Register second time.  Should only create one soup per unique soup name.
        [store registerSoup:kTestSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]] error:nil];
        __block int rowCount;
        [store.storeQueue inDatabase:^(FMDatabase* db) {
            rowCount = [db intForQuery:@"SELECT COUNT(*) FROM soup_attrs WHERE soupName = ?", kTestSoupName];
        }];
        XCTAssertEqual(rowCount, 1, @"Soup names should be unique within a store.");
        
        // Remove
        [store removeSoup:kTestSoupName];
        testSoupExists = [store soupExists:kTestSoupName];
        XCTAssertFalse(testSoupExists, @"Soup %@ should no longer exist", kTestSoupName);
    }
}

- (void)testQuerySpecPageSize
{
    NSDictionary *allQueryNoPageSize = @{kQuerySpecParamQueryType: kQuerySpecTypeRange,
                              kQuerySpecParamIndexPath: @"a"};
    
    SFQuerySpec *querySpec = [[SFQuerySpec alloc] initWithDictionary:allQueryNoPageSize withSoupName:kTestSoupName];
    NSUInteger querySpecPageSize = querySpec.pageSize;
    XCTAssertEqual(querySpecPageSize, kQuerySpecDefaultPageSize, @"Page size value should be default, if not specified.");
    NSUInteger expectedPageSize = 42;
    NSDictionary *allQueryWithPageSize = @{kQuerySpecParamQueryType: kQuerySpecTypeRange,
                                        kQuerySpecParamIndexPath: @"a",
                                          kQuerySpecParamPageSize: @(expectedPageSize)};
    querySpec = [[SFQuerySpec alloc] initWithDictionary:allQueryWithPageSize withSoupName:kTestSoupName];
    querySpecPageSize = querySpec.pageSize;
    XCTAssertEqual(querySpecPageSize, expectedPageSize, @"Page size value should reflect input value.");
}

- (void)testPersistentStoreExists
{
    for (SFSmartStoreDatabaseManager *dbMgr in @[ [SFSmartStoreDatabaseManager sharedManager], [SFSmartStoreDatabaseManager sharedGlobalManager] ]) {
        NSString *storeName = @"xyzpdq";
        BOOL persistentStoreExists = [dbMgr persistentStoreExists:storeName];
        XCTAssertFalse(persistentStoreExists, @"Store should not exist at this point.");
        [self createDbDir:storeName withManager:dbMgr];
        FMDatabase *db = [self openDatabase:storeName withManager:dbMgr key:@"" openShouldFail:NO];
        persistentStoreExists = [dbMgr persistentStoreExists:storeName];
        XCTAssertTrue(persistentStoreExists, @"Store should exist after creation.");
        [db close];
        [dbMgr removeStoreDir:storeName];
        persistentStoreExists = [dbMgr persistentStoreExists:storeName];
        XCTAssertFalse(persistentStoreExists, @"Store should no longer exist at this point.");
    }
}

- (void)testSmartStoreIsRecreatedWhenKeyIsLost {
    NSString *storeName = @"testSmartStoreIsRecreatedWhenKeyIsLost";
    NSString *keyLabel = [NSString stringWithFormat:@"com.salesforce.keystore.%@", kSFSmartStoreEncryptionKeyLabel];
    NSData *originalKey = [SFSDKKeychainHelper readWithService:keyLabel account:nil].data;

    @try {
        // Create store
        SFSmartStore* store = [SFSmartStore sharedStoreWithName:storeName];
        XCTAssertNotNil(store, @"New store should have been created");
        
        // Create soup in store
        [self registerTestSoup:store indexType:kSoupIndexTypeString];
        
        // Close store
        [store.storeQueue close];
        
        // Clear store map
        [SFSmartStore clearSharedStoreMemoryState];
        
        // Re-open store
        store = [SFSmartStore sharedStoreWithName:storeName];
        XCTAssertNotNil(store, @"Existing store should have been found");
        XCTAssertTrue([store soupExists:kTestSoupName], @"Soup should still exist");
        
        // Close store
        [store.storeQueue close];
        
        // Clear store map
        [SFSmartStore clearSharedStoreMemoryState];
        
        // Drop key
        [SFSDKKeyGenerator removeEncryptionKeyFor:kSFSmartStoreEncryptionKeyLabel];
        
        // Re-open store -- but expect new empty store since key has changed
        store = [SFSmartStore sharedStoreWithName:storeName];
        XCTAssertNotNil(store, @"A store should have been returned");
        XCTAssertFalse([store soupExists:kTestSoupName], @"Soup should no longer exist");

    }
    @finally {
        // Drop store
        [SFSmartStore removeSharedStoreWithName:storeName];
        // Restore key
        XCTAssertTrue([SFSDKKeychainHelper writeWithService:keyLabel data:originalKey account:nil].success);
    }
}

- (void)testOpenDatabase
{
    for (SFSmartStoreDatabaseManager *dbMgr in @[ [SFSmartStoreDatabaseManager sharedManager], [SFSmartStoreDatabaseManager sharedGlobalManager] ]) {
        // Create a new DB.  Verify its emptiness.
        NSString *storeName = @"awesometown";
        [self createDbDir:storeName withManager:dbMgr];
        FMDatabase *createDb = [self openDatabase:storeName withManager:dbMgr key:@"" openShouldFail:NO];
        int actualRowCount = [self rowCountForTable:@"sqlite_master" db:createDb];
        XCTAssertEqual(actualRowCount, 0, @"%@ should be a new database with no schema.", storeName);
        
        // Create a table, verify its addition to the DB.
        NSString *tableName = @"My_Table";
        [self createTestTable:tableName db:createDb];
        actualRowCount = [self rowCountForTable:@"sqlite_master" db:createDb];
        XCTAssertEqual(actualRowCount, 1, @"%@ should now have one table in the DB schema.", storeName);
        
        // Close the current handle, open the database in another call, verify it has a previously-defined table.
        [createDb close];
        FMDatabase *existingDb = [self openDatabase:storeName withManager:dbMgr key:@"" openShouldFail:NO];
        actualRowCount = [self rowCountForTable:@"sqlite_master" db:existingDb];
        XCTAssertEqual(actualRowCount, 1, @"Existing database %@ should have one table in the DB schema.", storeName);
        
        [existingDb close];
        [dbMgr removeStoreDir:storeName];
    }
}

- (void)testEncryptDatabase
{
    NSString *storeName = @"nunyaBusiness";
    
    for (SFSmartStoreDatabaseManager *dbMgr in @[ [SFSmartStoreDatabaseManager sharedManager], [SFSmartStoreDatabaseManager sharedGlobalManager] ]) {
        // Create the unencrypted database, add a table.
        [self createDbDir:storeName withManager:dbMgr];
        FMDatabase *unencryptedDb = [self openDatabase:storeName withManager:dbMgr key:@"" openShouldFail:NO];
        NSString *tableName = @"My_Table";
        [self createTestTable:tableName db:unencryptedDb];
        BOOL isTableNameInMaster = [self tableNameInMaster:tableName db:unencryptedDb];
        XCTAssertTrue(isTableNameInMaster, @"Table %@ should have been added to sqlite_master.", tableName);
        
        // Encrypt the DB, verify access.
        NSString *encKey = @"BigSecret";
        NSError *encryptError = nil;
        FMDatabase *encryptedDb = [dbMgr encryptDb:unencryptedDb name:storeName key:encKey salt:nil error:&encryptError];
        XCTAssertNotNil(encryptedDb, @"Encrypted DB should be a valid object.");
        XCTAssertNil(encryptError, @"Error encrypting the DB: %@", [encryptError localizedDescription]);
        isTableNameInMaster = [self tableNameInMaster:tableName db:encryptedDb];
        XCTAssertTrue(isTableNameInMaster, @"Table %@ should still exist in sqlite_master, for encrypted DB.", tableName);
        [encryptedDb close];
        
        // Try to open the DB with an empty key, verify no read access.
        FMDatabase *encryptedDbEmptyKey = [self openDatabase:storeName withManager:dbMgr key:@"" openShouldFail:YES];
        XCTAssertNil(encryptedDbEmptyKey, @"Shouldn't be able to read encrypted database, opened as unencrypted.");
        if(encryptedDbEmptyKey) [encryptedDbEmptyKey close];
        
        // Try to read the encrypted database with the wrong key.
        FMDatabase *encryptedDbWrongKey = [self openDatabase:storeName withManager:dbMgr key:@"WrongKey" openShouldFail:YES];
        XCTAssertNil(encryptedDbWrongKey, @"Shouldn't be able to read encrypted database, opened with the wrong key.");
        if(encryptedDbWrongKey) [encryptedDbWrongKey close];
        
        // Finally, try to re-open the encrypted database with the right key.  Verify read access.
        FMDatabase *encryptedDbCorrectKey = [self openDatabase:storeName withManager:dbMgr key:encKey openShouldFail:NO];
        isTableNameInMaster = [self tableNameInMaster:tableName db:encryptedDbCorrectKey];
        XCTAssertTrue(isTableNameInMaster, @"Should find the original table name in sqlite_master, with proper encryption key.");
        [encryptedDbCorrectKey close];
        
        [dbMgr removeStoreDir:storeName];
    }
}

- (void)testUnencryptDatabase
{
    NSString *storeName = @"lookAtThatData";
    
    for (SFSmartStoreDatabaseManager *dbMgr in @[ [SFSmartStoreDatabaseManager sharedManager], [SFSmartStoreDatabaseManager sharedGlobalManager] ]) {
        // Create the encrypted database, add a table.
        [self createDbDir:storeName withManager:dbMgr];
        NSString *encKey = @"GiantSecret";
        FMDatabase *encryptedDb = [self openDatabase:storeName withManager:dbMgr key:encKey openShouldFail:NO];
        NSString *tableName = @"My_Table";
        [self createTestTable:tableName db:encryptedDb];
        BOOL isTableNameInMaster = [self tableNameInMaster:tableName db:encryptedDb];
        XCTAssertTrue(isTableNameInMaster, @"Table %@ should have been added to sqlite_master.", tableName);
        [encryptedDb close];
        
        // Verify that we can't read data with a plaintext DB open.
        FMDatabase *encryptedDbEmptyKey = [self openDatabase:storeName withManager:dbMgr key:@"" openShouldFail:YES];
        XCTAssertNil(encryptedDbEmptyKey, @"Shouldn't be able to read encrypted database, opened as unencrypted.");
        if(encryptedDbEmptyKey) [encryptedDbEmptyKey close];
        
        // Unencrypt the database, verify data.
        FMDatabase *encryptedDb2 = [self openDatabase:storeName withManager:dbMgr key:encKey openShouldFail:NO];
        NSError *unencryptError = nil;
        FMDatabase *unencryptedDb2 = [dbMgr unencryptDb:encryptedDb2
                                                   name:storeName
                                                 oldKey:encKey
                                                   salt:nil
                                                  error:&unencryptError];
        XCTAssertNil(unencryptError, @"Error unencrypting the database: %@", [unencryptError localizedDescription]);
        isTableNameInMaster = [self tableNameInMaster:tableName db:unencryptedDb2];
        XCTAssertTrue(isTableNameInMaster, @"Table should be present in unencrypted DB.");
        [unencryptedDb2 close];
        
        // Open the database with no key, out of band.  Verify data.
        FMDatabase *unencryptedDb3 = [self openDatabase:storeName withManager:dbMgr key:@"" openShouldFail:NO];
        isTableNameInMaster = [self tableNameInMaster:tableName db:unencryptedDb3];
        XCTAssertTrue(isTableNameInMaster, @"Table should be present in unencrypted DB.");
        [unencryptedDb3 close];
        
        [dbMgr removeStoreDir:storeName];
    }
}

- (void)testAllStoreNames
{
    // Test with no stores. (Note: Have to get rid of the 'default' store created at setup.)
    self.store = nil;
    self.globalStore = nil;
    [SFSmartStore removeSharedStoreWithName:kTestSmartStoreName];
    [SFSmartStore removeSharedGlobalStoreWithName:kTestSmartStoreName];
    
    for (SFSmartStoreDatabaseManager *dbMgr in @[ [SFSmartStoreDatabaseManager sharedManager], [SFSmartStoreDatabaseManager sharedGlobalManager] ]) {
        NSArray *noStoresArray = [dbMgr allStoreNames];
        if (noStoresArray != nil) {
            NSUInteger expectedCount = [noStoresArray count];
            XCTAssertEqual(expectedCount, (NSUInteger)0, @"There should not be any stores defined.  Count = %lu", (unsigned long)expectedCount);
        }
        
        // Create some stores.  Verify them.
        int numStores = arc4random() % 20 + 1;
        NSMutableSet *initialStoreList = [NSMutableSet set];
        NSString *tableName = @"My_Table";
        for (int i = 0; i < numStores; i++) {
            NSString *storeName = [NSString stringWithFormat:@"myStore%d", (i + 1)];
            [self createDbDir:storeName withManager:dbMgr];
            FMDatabase *db = [self openDatabase:storeName withManager:dbMgr key:@"" openShouldFail:NO];
            [self createTestTable:tableName db:db];
            [db close];
            [initialStoreList addObject:storeName];
        }
        NSSet *allStoresStoreList = [NSSet setWithArray:[dbMgr allStoreNames]];
        BOOL setsAreEqual = [initialStoreList isEqualToSet:allStoresStoreList];
        XCTAssertTrue(setsAreEqual, @"Store list is not equal!");
        
        // Cleanup.
        for (NSString *storeName in initialStoreList) {
            [dbMgr removeStoreDir:storeName];
        }
    }
}

- (void) testGetDatabaseSize
{
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // Before
        unsigned long long initialSize = [store getDatabaseSize];
        
        // Register
        NSDictionary* soupIndex = @{@"path": @"name",@"type": @"string"};
        [store registerSoup:kTestSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]] error:nil];
        
        // Upserts
        NSMutableArray* entries = [NSMutableArray array];
        for (int i=0; i<100; i++) {
            NSMutableDictionary* soupElt = [NSMutableDictionary dictionary];
            soupElt[@"name"] = [NSString stringWithFormat:@"name_%d", i];
            soupElt[@"value"] = [NSString stringWithFormat:@"value_%d", i];
            [entries addObject:soupElt];
        }
        [store upsertEntries:entries toSoup:kTestSoupName];
        
        // After
        XCTAssertTrue([store getDatabaseSize] > initialSize, @"Database size should be larger");
    }
}

- (void)testReadMultiByteCharacterAroundBufferBoundary {
    // This test ensures that a string containing a multi-byte character is properly read back
    // when that character is located at the buffer boundary.
    NSMutableString *text = [NSMutableString string];
    // Fill the string up to one byte before the buffer ends
    for (NSUInteger index = 0; index < kBufferSize - 1; index++) {
        [text appendString:@"A"];
    }
    // Let's use the character 𝄞 which uses 4 bytes (internally stored as UTF-16 surrogate pair)
    // and will span the buffer boundary
    [text appendString:@"𝄞"];
    // Add a few more character after the buffer boundary
    for (NSUInteger index = 0; index < 125; index++) {
        [text appendString:@"B"];
    }
    NSInputStream *is = [NSInputStream inputStreamWithData:[text dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSString *outputText = [SFSmartStore stringFromInputStream:is];
    XCTAssertEqualObjects(text, outputText);
}

/**
 Test running a valid query with SFStoreCursor
 NB: there are many more tests in SalesforceMobileSDK-iOS-Hybrid exercising SFStoreCursor
 */
- (void)testValidQueryWithStoreCursor {
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // Register
        NSDictionary* soupIndex = @{@"path": @"key",@"type": @"string"};
        [store registerSoup:kTestSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]] error:nil];
        
        // Populate soup
        NSDictionary* soupElt0 = @{@"key": @"ka1", @"value":@"va1", @"otherValue":@"ova1"};
        NSDictionary* soupElt1 = @{@"key": @"ka2", @"value":@"va2", @"otherValue":@"ova2"};
        NSDictionary* soupElt2 = @{@"key": @"ka3", @"value":@"va3", @"otherValue":@"ova3"};

        [store upsertEntries:@[soupElt0, soupElt1, soupElt2] toSoup:kTestSoupName];
        
        // Query spec
        SFQuerySpec* querySpec = [SFQuerySpec newAllQuerySpec:kTestSoupName withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:2];
        
        // Run query with cursor
        NSError* error;
        SFStoreCursor* cursor = [[SFStoreCursor alloc] initWithStore:store querySpec:querySpec];
        NSDictionary* serializedCursorDeserialized = [SFJsonUtils objectFromJSONString:[cursor getDataSerialized:store error:&error]];
        XCTAssertNil(error, @"No error expected");
        NSDictionary* cursorDeserialized = [cursor getDataDeserialized:store error:&error];
        XCTAssertNil(error, @"No error expected");
        
        // Check cursor
        XCTAssertEqualObjects(cursor.pageSize, @2, @"Wrong page size");
        XCTAssertEqualObjects(cursor.currentPageIndex, @0, @"Wrong page index");
        XCTAssertEqualObjects(cursor.totalPages, @2, @"Wrong total pages count");
        XCTAssertEqualObjects(cursor.totalEntries, @3, @"Wrong total entries count");

        // Check serialized cursor
        XCTAssertEqualObjects(serializedCursorDeserialized[@"pageSize"], @2, @"Wrong page size");
        XCTAssertEqualObjects(serializedCursorDeserialized[@"currentPageIndex"], @0, @"Wrong page index");
        XCTAssertEqualObjects(serializedCursorDeserialized[@"totalPages"], @2, @"Wrong total pages count");
        XCTAssertEqualObjects(serializedCursorDeserialized[@"totalEntries"], @3, @"Wrong total entries count");
        NSArray* currentPageOrderedEntries = serializedCursorDeserialized[@"currentPageOrderedEntries"];
        XCTAssertEqual(currentPageOrderedEntries.count, 2, "Wrong entries count in page");
        XCTAssertEqualObjects(currentPageOrderedEntries[0][@"key"], @"ka1", "Wrong first entry");
        XCTAssertEqualObjects(currentPageOrderedEntries[1][@"key"], @"ka2", "Wrong second entry");
        
        // Check deserialized cursor
        XCTAssertEqualObjects(cursorDeserialized[@"pageSize"], @2, @"Wrong page size");
        XCTAssertEqualObjects(cursorDeserialized[@"currentPageIndex"], @0, @"Wrong page index");
        XCTAssertEqualObjects(cursorDeserialized[@"totalPages"], @2, @"Wrong total pages count");
        XCTAssertEqualObjects(cursorDeserialized[@"totalEntries"], @3, @"Wrong total entries count");
        currentPageOrderedEntries = cursorDeserialized[@"currentPageOrderedEntries"];
        XCTAssertEqual(currentPageOrderedEntries.count, 2, "Wrong entries count in page");
        XCTAssertEqualObjects(currentPageOrderedEntries[0][@"key"], @"ka1", "Wrong first entry");
        XCTAssertEqualObjects(currentPageOrderedEntries[1][@"key"], @"ka2", "Wrong second entry");
    }
}

/**
Test running an invalid query with SFStoreCursor
NB: there are many more tests in SalesforceMobileSDK-iOS-Hybrid exercising StoreCursor
*/
- (void)testInvalidQueryWithStoreCursor {
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // Make sure soup does NOT exist
        XCTAssertFalse([store soupExists:kTestSoupName]);
        
        // Query spec
        SFQuerySpec* querySpec = [SFQuerySpec newAllQuerySpec:kTestSoupName withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:2];
        
        NSError* error;
        SFStoreCursor* cursor = [[SFStoreCursor alloc] initWithStore:store querySpec:querySpec];

        // Run query by getting serialized data from cursor
        NSString* serializedCursor = [SFJsonUtils objectFromJSONString:[cursor getDataSerialized:store error:&error]];
        XCTAssertNotNil(error, @"Error expected");
        XCTAssertNil(serializedCursor, @"Serialized cursor should be nil");

        // Run query by getting deserialized data from cursor
        NSDictionary* deserializedCursor = [cursor getDataDeserialized:store error:&error];
        XCTAssertNotNil(error, @"Error expected");
        XCTAssertNil(deserializedCursor, @"Deserialized cursor should be nil");

    }
}

/**
Test running an invalid query with SFStoreCursor while JSON check are on
Make sure we do NOT get a notification for a JSON parsing error
*/
- (void)testInvalidQueryWithStoreCursorWithRawJsonCheckOn {
    [SFSmartStore setJsonSerializationCheckEnabled:YES];
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // Make sure soup does NOT exist
        XCTAssertFalse([store soupExists:kTestSoupName]);
        
        // Query spec
        SFQuerySpec* querySpec = [SFQuerySpec newAllQuerySpec:kTestSoupName withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:2];
        
        // Setup notification observer
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"JSON parse error notification"];
        expectation.inverted = YES; // not supposed to be fulfilled
        [[NSNotificationCenter defaultCenter] addObserverForName:kSFSmartStoreJSONParseErrorNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            [expectation fulfill];
        }];
        
        // Run query with cursor
        NSError* error;
        SFStoreCursor* cursor = [[SFStoreCursor alloc] initWithStore:store querySpec:querySpec];
        NSString* serializedCursor = [SFJsonUtils objectFromJSONString:[cursor getDataSerialized:store error:&error]];
        XCTAssertNotNil(error, @"Error expected");
        XCTAssertNil(serializedCursor, @"Serialized cursor should be nil");
        
        // Wait for notification (timeout expected)
        [self waitForExpectations:@[expectation] timeout:1];
    }
    [SFSmartStore setJsonSerializationCheckEnabled:NO];
}

#pragma mark - helper methods

- (SFSmartStore *)smartStoreForManager:(SFSmartStoreDatabaseManager *)dbMgr withName:(NSString *)storeName
{
    if (dbMgr == [SFSmartStoreDatabaseManager sharedGlobalManager]) {
        return [SFSmartStore sharedGlobalStoreWithName:storeName];
    } else {
        return [SFSmartStore sharedStoreWithName:storeName];
    }
}

- (void)removeStoreForManager:(SFSmartStoreDatabaseManager *)dbMgr withName:(NSString *)storeName
{
    if (dbMgr == [SFSmartStoreDatabaseManager sharedGlobalManager]) {
        [SFSmartStore removeSharedGlobalStoreWithName:storeName];
    } else {
        [SFSmartStore removeSharedStoreWithName:storeName];
    }
}

- (void)createDbDir:(NSString *)dbName withManager:(SFSmartStoreDatabaseManager *)dbMgr
{
    BOOL result = [dbMgr createStoreDir:dbName];
    XCTAssertTrue(result, @"Create db dir failed");
}

- (FMDatabase *)openDatabase:(NSString *)dbName withManager:(SFSmartStoreDatabaseManager *)dbMgr key:(NSString *)key openShouldFail:(BOOL)openShouldFail
{
    NSError *openDbError = nil;
    FMDatabase *db = [dbMgr openStoreDatabaseWithName:dbName key:key salt:nil error:&openDbError];
    if (openShouldFail) {
        XCTAssertNil(db, @"Opening database should have failed.");
    } else {
        XCTAssertNotNil(db, @"Opening database with name '%@' should have returned a non-nil DB object.  Error: %@", dbName, [openDbError localizedDescription]);
    }
    
    return db;
}

- (void)createTestTable:(NSString *)tableName db:(FMDatabase *)db
{
    NSString *tableSql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (Col1 TEXT, Col2 TEXT, Col3 TEXT, Col4 TEXT)", tableName];
    BOOL createSucceeded = [db executeUpdate:tableSql];
    XCTAssertTrue(createSucceeded, @"Could not create table %@: %@", tableName, [db lastErrorMessage]);
}

- (int)rowCountForTable:(NSString *)tableName db:(FMDatabase *)db
{
    NSString *rowCountQuery = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@", tableName];
    [SFSDKSmartStoreLogger d:[self class] format:@"rowCountQuery: %@", rowCountQuery];
    int rowCount = [db intForQuery:rowCountQuery];
    return rowCount;
}

- (BOOL)canReadDatabaseQueue:(FMDatabaseQueue *)queue
{
    __block BOOL readable = NO;
    
    [queue inDatabase:^(FMDatabase* db) {
        // Turn off hard errors from FMDB first.
        BOOL origCrashOnErrors = [db crashOnErrors];
        [db setCrashOnErrors:NO];
        
        NSString *querySql = @"SELECT * FROM sqlite_master LIMIT 1";
        FMResultSet *rs = [db executeQuery:querySql];
        [rs close];
        [db setCrashOnErrors:origCrashOnErrors];
        readable = (rs != nil);
    }];
    
    return readable;
}

- (BOOL)tableNameInMaster:(NSString *)tableName db:(FMDatabase *)db
{
    // Turn off hard errors from FMDB first.
    BOOL origCrashOnErrors = [db crashOnErrors];
    [db setCrashOnErrors:NO];
    
    BOOL result = YES;
    NSString *querySql = @"SELECT * FROM sqlite_master WHERE name = ?";
    FMResultSet *rs = [db executeQuery:querySql withArgumentsInArray:@[tableName]];
    if (rs == nil || ![rs next]) {
        result = NO;
    }
    
    [rs close];
    [db setCrashOnErrors:origCrashOnErrors];
    return result;
}

- (void)clearAllStores
{
    self.store = nil;
    [SFSmartStore removeAllStores];
    NSArray *allStoreNames = [[SFSmartStoreDatabaseManager sharedManager] allStoreNames];
    NSUInteger allStoreCount = [allStoreNames count];
    XCTAssertEqual(allStoreCount, (NSUInteger)0, @"Should not be any stores after removing them all.");
}

- (void) registerTestSoup:(SFSmartStore*)store indexType:(NSString*)indexType {
    NSError* error = nil;
    [store registerSoup:kTestSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key",@"type":indexType}, @{@"path": @"value",@"type":kSoupIndexTypeString}]] error:&error];
    XCTAssertNil(error, @"Soup should have registered without error");
    XCTAssertTrue([store soupExists:kTestSoupName], @"Soup should exist after registration");
}


@end
