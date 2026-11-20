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
@import FMDB;
#import "SFQuerySpec.h"
#import "SFStoreCursor.h"
#import "SFSmartStoreDatabaseManager.h"
#import "SFSmartStore+Internal.h"
#import "SFSoupIndex.h"
#import <SalesforceSDKCore/SalesforceSDKCore-Swift.h>
#import <SalesforceSDKCore/NSString+SFAdditions.h>
#import <SalesforceSDKCore/NSData+SFAdditions.h>
@import SQLCipher;

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
    XCTAssertEqualObjects(version, @"3.53.3");
}

- (void) testSqlCipherVersion
{
    NSString* version = [self.store getSQLCipherVersion];
    XCTAssertEqualObjects(version, @"4.17.0 community");
}

- (void) testCipherProviderVersion
{
    NSString *cipherProviderVersion = [self.store getCipherProviderVersion];
    XCTAssertNotNil(cipherProviderVersion);
    XCTAssertTrue(cipherProviderVersion.length > 0, @"cipherProviderVersion should not be an empty string");
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

#pragma mark - transaction tests

- (NSUInteger) countEntriesInSoup:(NSString*)soupName store:(SFSmartStore*)store
{
    NSError* error = nil;
    SFQuerySpec* querySpec = [SFQuerySpec newAllQuerySpec:soupName withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:100];
    NSNumber* count = [store countWithQuerySpec:querySpec error:&error];
    XCTAssertNil(error);
    return [count unsignedIntegerValue];
}

- (void) testPerformTransactionCommitsOnSuccess
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    NSError* error = nil;
    __block NSArray* upserted = nil;
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        upserted = [txn upsertEntries:@[@{@"key":@"k1", @"value":@"v1"}, @{@"key":@"k2", @"value":@"v2"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil];
    } error:&error];
    XCTAssertTrue(success);
    XCTAssertNil(error);
    XCTAssertEqual(upserted.count, 2UL);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 2UL);
}

- (void) testPerformTransactionRollsBackWhenBlockRequestsIt
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    NSError* error = nil;
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        [txn upsertEntries:@[@{@"key":@"k1", @"value":@"v1"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil];
        [txn rollback];
    } error:&error];
    XCTAssertFalse(success, @"A requested rollback returns NO");
    XCTAssertNil(error);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 0UL);
}

- (void) testPerformTransactionFailWithErrorRollsBackWithThatError
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    NSError* mine = [NSError errorWithDomain:@"test" code:42 userInfo:nil];
    NSError* other = [NSError errorWithDomain:@"test" code:43 userInfo:nil];
    NSError* error = nil;
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        [txn upsertEntries:@[@{@"key":@"k1", @"value":@"v1"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil];
        [txn failWithError:mine];
        [txn failWithError:other];
    } error:&error];
    XCTAssertFalse(success);
    XCTAssertEqual(error, mine, @"First failure wins");
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 0UL);
}

- (void) testPerformTransactionFailureWinsOverRequestedRollback
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    NSError* mine = [NSError errorWithDomain:@"test" code:42 userInfo:nil];
    NSError* error = nil;
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        [txn rollback];
        [txn failWithError:mine];
    } error:&error];
    XCTAssertFalse(success);
    XCTAssertEqual(error, mine);
    error = nil;
    success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        [txn failWithError:mine];
        [txn rollback];
    } error:&error];
    XCTAssertFalse(success);
    XCTAssertEqual(error, mine);
}

- (void) testPerformTransactionRollbackAndFailWithErrorRejectedFromOtherThreadOrAfterBlock
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    NSError* error = nil;
    __block SFSmartStoreTransaction* captured = nil;
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        captured = txn;
        [txn upsertEntries:@[@{@"key":@"k1", @"value":@"v1"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil];
        NSConditionLock* lock = [[NSConditionLock alloc] initWithCondition:0];
        NSThread* waiter = [[NSThread alloc] initWithBlock:^{
            [txn rollback];
            [txn failWithError:[NSError errorWithDomain:@"test" code:1 userInfo:nil]];
            [lock lock]; [lock unlockWithCondition:1];
        }];
        [waiter start];
        [lock lockWhenCondition:1]; [lock unlock];
    } error:&error];
    XCTAssertTrue(success, @"Rejected calls from another thread must not affect the transaction");
    XCTAssertNil(error);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 1UL);

    // After the block: no effect, no crash, and nothing changes in the store
    [captured rollback];
    [captured failWithError:[NSError errorWithDomain:@"test" code:1 userInfo:nil]];
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 1UL);
}

- (void) testPerformTransactionRollsBackAndReturnsErrorOnException
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    NSError* error = nil;
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        [txn upsertEntries:@[@{@"key":@"k1", @"value":@"v1"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil];
        @throw [NSException exceptionWithName:@"TestException" reason:@"boom" userInfo:nil];
    } error:&error];
    XCTAssertFalse(success);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, kSFSmartStoreErrorDomain);
    XCTAssertEqual(error.code, 999);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 0UL);
}

- (void) testPerformTransactionMultipleWritesAreAtomic
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    NSString* otherSoupName = @"otherTestSoup";
    NSError* error = nil;
    [self.store registerSoup:otherSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key", @"type": kSoupIndexTypeString}]] error:&error];
    XCTAssertNil(error);

    // Two soups written in one transaction: commit
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        [txn upsertEntries:@[@{@"key":@"k1"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil];
        [txn upsertEntries:@[@{@"key":@"q1"}] toSoup:otherSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil];
    } error:&error];
    XCTAssertTrue(success);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 1UL);
    XCTAssertEqual([self countEntriesInSoup:otherSoupName store:self.store], 1UL);

    // Second write fails (unknown soup): the first write is rolled back too
    error = nil;
    __block NSError* opError = nil;
    success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        XCTAssertNotNil([txn upsertEntries:@[@{@"key":@"k2"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil]);
        XCTAssertNil([txn upsertEntries:@[@{@"key":@"x"}] toSoup:@"noSuchSoup" withExternalIdPath:SOUP_ENTRY_ID error:&opError]);
        // Block does not call rollback: failed write alone must roll back
    } error:&error];
    XCTAssertFalse(success);
    XCTAssertNotNil(error);
    XCTAssertNotNil(opError);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 1UL);

    // A batch where a later entry fails (external id missing): earlier entries of the batch are rolled back too
    error = nil;
    success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        NSArray* batch = @[@{@"key":@"k3"}, @{@"value":@"no key"}];
        NSArray* batchResult = [txn upsertEntries:batch toSoup:kTestSoupName withExternalIdPath:@"key" error:nil];
        XCTAssertNil(batchResult);
    } error:&error];
    XCTAssertFalse(success);
    XCTAssertNotNil(error);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 1UL);

    // Remove inside a rolled back transaction is undone
    NSNumber* existingId = [self.store lookupSoupEntryIdForSoupName:kTestSoupName forFieldPath:@"key" fieldValue:@"k1" error:nil];
    XCTAssertNotNil(existingId);
    error = nil;
    success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        XCTAssertTrue([txn removeEntries:@[existingId] fromSoup:kTestSoupName error:nil]);
        [txn rollback];
    } error:&error];
    XCTAssertFalse(success);
    XCTAssertNil(error);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 1UL);
}

- (void) testPerformTransactionReadsSeeOwnWrites
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    NSError* error = nil;
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        NSArray* upserted = [txn upsertEntries:@[@{@"key":@"k1", @"value":@"v1"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil];
        NSNumber* entryId = upserted[0][SOUP_ENTRY_ID];

        NSArray* retrieved = [txn retrieveEntries:@[entryId] fromSoup:kTestSoupName error:nil];
        XCTAssertEqual(retrieved.count, 1UL);
        XCTAssertEqualObjects(retrieved[0][@"value"], @"v1");

        XCTAssertEqualObjects([txn lookupSoupEntryIdForSoupName:kTestSoupName forFieldPath:@"key" fieldValue:@"k1" error:nil], entryId);

        SFQuerySpec* querySpec = [SFQuerySpec newAllQuerySpec:kTestSoupName withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:10];
        XCTAssertEqual([txn queryWithQuerySpec:querySpec pageIndex:0 whereArgs:nil error:nil].count, 1UL);
        XCTAssertEqualObjects([txn countWithQuerySpec:querySpec error:nil], @1);

        // whereArgs only for smart queries
        NSError* whereArgsError = nil;
        XCTAssertNil([txn queryWithQuerySpec:querySpec pageIndex:0 whereArgs:@[@"x"] error:&whereArgsError]);
        XCTAssertNotNil(whereArgsError);

        // Removing inside the transaction is also visible
        XCTAssertTrue([txn removeEntries:@[entryId] fromSoup:kTestSoupName error:nil]);
        XCTAssertEqualObjects([txn countWithQuerySpec:querySpec error:nil], @0);
    } error:&error];
    XCTAssertTrue(success);
    XCTAssertNil(error);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 0UL);
}

- (void) testPerformTransactionRejectsReentrantCalls
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    NSError* error = nil;
    __block NSError* publicWriteError = nil;
    __block NSError* nestedTransactionError = nil;
    __block BOOL nestedTransactionResult = YES;
    __block NSArray* publicWriteResult = nil;
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        [txn upsertEntries:@[@{@"key":@"k1"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil];
        // Public write method of the store from inside the block: would deadlock, fails instead
        publicWriteResult = [self.store upsertEntries:@[@{@"key":@"k2"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:&publicWriteError];
        // Nested transaction: fails without running the nested block
        nestedTransactionResult = [self.store performTransaction:^(SFSmartStoreTransaction* innerTxn) {
            XCTFail(@"Nested block must not run");
        } error:&nestedTransactionError];
    } error:&error];
    XCTAssertTrue(success, @"Failed re-entrant calls do not affect the outer transaction");
    XCTAssertNil(error);
    XCTAssertNil(publicWriteResult);
    XCTAssertEqual(publicWriteError.code, 999);
    XCTAssertFalse(nestedTransactionResult);
    XCTAssertEqual(nestedTransactionError.code, 999);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 1UL);

    // The store is still usable afterwards
    XCTAssertNotNil([self.store upsertEntries:@[@{@"key":@"k3"}] toSoup:kTestSoupName]);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 2UL);
}

- (void) testPerformTransactionObjectInvalidAfterBlock
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    __block SFSmartStoreTransaction* leaked = nil;
    [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        leaked = txn;
    } error:nil];
    NSError* error = nil;
    XCTAssertNil([leaked upsertEntries:@[@{@"key":@"k1"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:&error]);
    XCTAssertNotNil(error);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 0UL);
}

- (void) testPerformTransactionOnDifferentStoresCanBeNested
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    [self registerTestSoup:self.globalStore indexType:kSoupIndexTypeString];
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        [txn upsertEntries:@[@{@"key":@"k1"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil];
        // Other store has its own queue: the re-entrancy guard only applies to the same store
        XCTAssertNotNil([self.globalStore upsertEntries:@[@{@"key":@"g1"}] toSoup:kTestSoupName]);
    } error:nil];
    XCTAssertTrue(success);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 1UL);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.globalStore], 1UL);
}


// Makes inserts and deletes on the soup fail with a SQL error (the soup still exists as far as the store knows)
- (void) makeWritesFailOnSoup:(NSString*)soupName
{
    NSString* tableName = [self getSoupTableName:soupName store:self.store];
    [self.store.storeQueue inDatabase:^(FMDatabase* db) {
        for (NSString* op in @[@"INSERT", @"UPDATE", @"DELETE"]) {
            NSString* sql = [NSString stringWithFormat:@"CREATE TRIGGER fail_%@ BEFORE %@ ON %@ BEGIN SELECT RAISE(ABORT, 'injected failure'); END", op, op, tableName];
            BOOL created = [db executeUpdate:sql];
            XCTAssertTrue(created);
        }
    }];
}

- (void) testPerformTransactionUpsertSqlFailureCaughtInBlockStillRollsBack
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    NSString* brokenSoupName = @"brokenSoup";
    NSError* error = nil;
    [self.store registerSoup:brokenSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key", @"type": kSoupIndexTypeString}]] error:&error];
    XCTAssertNil(error);
    [self makeWritesFailOnSoup:brokenSoupName];

    __block BOOL upsertThrew = NO;
    __block NSError* opError = nil;
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        XCTAssertNotNil([txn upsertEntries:@[@{@"key":@"k1"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil]);
        @try {
            NSArray* result = [txn upsertEntries:@[@{@"key":@"x"}] toSoup:brokenSoupName withExternalIdPath:SOUP_ENTRY_ID error:&opError];
            XCTAssertNil(result);
        }
        @catch (NSException* e) {
            upsertThrew = YES;
        }
        // Block swallows the failure and returns normally
    } error:&error];
    XCTAssertFalse(upsertThrew, @"Transaction operations report SQL failures through NSError, not exceptions");
    XCTAssertNotNil(opError);
    XCTAssertFalse(success);
    XCTAssertNotNil(error);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 0UL, @"Earlier write must be rolled back");
}

- (void) testPerformTransactionRemoveSqlFailureCaughtInBlockStillRollsBack
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    [self.store upsertEntries:@[@{@"key":@"k0"}] toSoup:kTestSoupName];
    NSString* brokenSoupName = @"brokenSoup";
    [self.store registerSoup:brokenSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key", @"type": kSoupIndexTypeString}]] error:nil];
    NSArray* brokenEntries = [self.store upsertEntries:@[@{@"key":@"b0"}] toSoup:brokenSoupName];
    NSNumber* brokenEntryId = brokenEntries[0][SOUP_ENTRY_ID];
    [self makeWritesFailOnSoup:brokenSoupName];
    NSError* error = nil;
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        XCTAssertNotNil([txn upsertEntries:@[@{@"key":@"k1"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil]);
        XCTAssertFalse([txn removeEntries:@[brokenEntryId] fromSoup:brokenSoupName error:nil]);
    } error:&error];
    XCTAssertFalse(success);
    XCTAssertNotNil(error);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 1UL);
}

- (void) testPerformTransactionFailedReadsReturnErrorAndDoNotAbortTransaction
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    NSError* error = nil;
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        XCTAssertNotNil([txn upsertEntries:@[@{@"key":@"k1"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil]);

        SFQuerySpec* badQuery = [SFQuerySpec newSmartQuerySpec:@"select {noSuchSoup:key} from {noSuchSoup}" withPageSize:10];
        NSError* queryError = nil;
        XCTAssertNil([txn queryWithQuerySpec:badQuery pageIndex:0 whereArgs:nil error:&queryError]);
        XCTAssertNotNil(queryError);
        NSError* countError = nil;
        XCTAssertNil([txn countWithQuerySpec:badQuery error:&countError]);
        XCTAssertNotNil(countError);
        NSError* lookupError = nil;
        XCTAssertNil([txn lookupSoupEntryIdForSoupName:kTestSoupName forFieldPath:@"notIndexed" fieldValue:@"x" error:&lookupError]);
        XCTAssertNotNil(lookupError);
        NSError* retrieveError = nil;
        XCTAssertNotNil([txn retrieveEntries:@[@1] fromSoup:kTestSoupName error:&retrieveError]);
        XCTAssertNil(retrieveError);

        // The callback keeps going and the transaction is still usable
        XCTAssertNotNil([txn upsertEntries:@[@{@"key":@"k2"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil]);
    } error:&error];
    XCTAssertTrue(success);
    XCTAssertNil(error);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 2UL);
}

- (void) testPerformTransactionLookupWithNoMatchReturnsNilWithoutError
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        NSError* error = nil;
        XCTAssertNil([txn lookupSoupEntryIdForSoupName:kTestSoupName forFieldPath:@"key" fieldValue:@"nope" error:&error]);
        XCTAssertNil(error);
    } error:nil];
}

- (void) testReentrantCallsToOtherPublicApisFailSafely
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    [self.store upsertEntries:@[@{@"key":@"k1"}] toSoup:kTestSoupName];
    SFQuerySpec* querySpec = [SFQuerySpec newAllQuerySpec:kTestSoupName withOrderPath:@"key" withOrder:kSFSoupQuerySortOrderAscending withPageSize:10];
    NSError* error = nil;
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        // queryPragma based
        XCTAssertEqualObjects([self.store getSQLCipherVersion], @"");
        XCTAssertEqual([self.store getCompileOptions].count, 0UL);
        XCTAssertFalse([self.store getCipherFIPSStatus]);
        // soupExists / count / lookup with error
        XCTAssertFalse([self.store soupExists:kTestSoupName]);
        NSError* countError = nil;
        XCTAssertNil([self.store countWithQuerySpec:querySpec error:&countError]);
        XCTAssertEqual(countError.code, 999);
        NSError* lookupError = nil;
        XCTAssertNil([self.store lookupSoupEntryIdForSoupName:kTestSoupName forFieldPath:@"key" fieldValue:@"k1" error:&lookupError]);
        XCTAssertEqual(lookupError.code, 999);
        NSError* queryError = nil;
        XCTAssertNil([self.store queryWithQuerySpec:querySpec pageIndex:0 error:&queryError]);
        XCTAssertEqual(queryError.code, 999);
        XCTAssertNil([self.store allSoupNames]);
        XCTAssertFalse([self.store alterSoup:kTestSoupName withIndexSpecs:@[] reIndexData:NO]);
        XCTAssertFalse([self.store reIndexSoup:kTestSoupName withIndexPaths:@[@"key"]]);
    } error:&error];
    XCTAssertTrue(success);
    XCTAssertNil(error);
    // Outside of a block everything works as usual
    XCTAssertTrue([self.store soupExists:kTestSoupName]);
    XCTAssertGreaterThan([self.store getSQLCipherVersion].length, 0UL);
}

- (void) testPerformTransactionRejectsUseFromAnotherThread
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    NSError* error = nil;
    __block NSError* upsertError = nil;
    __block NSError* retrieveError = nil;
    __block NSArray* upsertResult = @[];
    __block NSArray* retrieveResult = @[];
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            upsertResult = [txn upsertEntries:@[@{@"key":@"other"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:&upsertError];
            retrieveResult = [txn retrieveEntries:@[@1] fromSoup:kTestSoupName error:&retrieveError];
            dispatch_semaphore_signal(done);
        });
        XCTAssertEqual(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0L);
        XCTAssertNotNil([txn upsertEntries:@[@{@"key":@"mine"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil]);
    } error:&error];
    XCTAssertNil(upsertResult);
    XCTAssertNotNil(upsertError);
    XCTAssertNil(retrieveResult);
    XCTAssertNotNil(retrieveError);
    XCTAssertTrue(success, @"Rejected calls from another thread do not affect the transaction");
    XCTAssertNil(error);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 1UL);
    XCTAssertNotNil([self.store lookupSoupEntryIdForSoupName:kTestSoupName forFieldPath:@"key" fieldValue:@"mine" error:nil]);
    XCTAssertNil([self.store lookupSoupEntryIdForSoupName:kTestSoupName forFieldPath:@"key" fieldValue:@"other" error:nil]);
}

static int rejectCommitHook(void* unused) { return 1; }

- (void) testPerformTransactionRejectsWritesAfterSqliteEndedTheTransaction
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    NSString* brokenSoupName = @"brokenSoup";
    NSError* error = nil;
    [self.store registerSoup:brokenSoupName withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[@{@"path": @"key", @"type": kSoupIndexTypeString}]] error:&error];
    XCTAssertNil(error);
    // RAISE(ROLLBACK) makes SQLite end the transaction itself; later writes would run in autocommit mode
    NSString* brokenTable = [self getSoupTableName:brokenSoupName store:self.store];
    [self.store.storeQueue inDatabase:^(FMDatabase* db) {
        NSString* sql = [NSString stringWithFormat:@"CREATE TRIGGER end_txn BEFORE INSERT ON %@ BEGIN SELECT RAISE(ROLLBACK, 'injected rollback'); END", brokenTable];
        XCTAssertTrue([db executeUpdate:sql]);
    }];

    __block NSError* afterError = nil;
    __block NSArray* afterResult = nil;
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        XCTAssertNotNil([txn upsertEntries:@[@{@"key":@"before"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil]);
        XCTAssertNil([txn upsertEntries:@[@{@"key":@"x"}] toSoup:brokenSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil]);
        afterResult = [txn upsertEntries:@[@{@"key":@"after"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:&afterError];
    } error:&error];
    XCTAssertFalse(success);
    XCTAssertNotNil(error);
    XCTAssertNil(afterResult, @"Writes after SQLite ended the transaction are rejected");
    XCTAssertNotNil(afterError);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 0UL, @"Neither write may survive");
}

- (void) testPerformTransactionReportsFailedCommit
{
    [self registerTestSoup:self.store indexType:kSoupIndexTypeString];
    // A commit hook returning non-zero makes SQLite turn COMMIT into a rollback
    [self.store.storeQueue inDatabase:^(FMDatabase* db) {
        sqlite3_commit_hook([db sqliteHandle], rejectCommitHook, NULL);
    }];
    NSError* error = nil;
    BOOL success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        XCTAssertNotNil([txn upsertEntries:@[@{@"key":@"k1"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil]);
    } error:&error];
    XCTAssertFalse(success, @"A failed COMMIT is not a successful transaction");
    XCTAssertNotNil(error);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 0UL);

    // The connection stays usable once the hook is gone
    [self.store.storeQueue inDatabase:^(FMDatabase* db) {
        sqlite3_commit_hook([db sqliteHandle], NULL, NULL);
    }];
    error = nil;
    success = [self.store performTransaction:^(SFSmartStoreTransaction* txn) {
        [txn upsertEntries:@[@{@"key":@"k2"}] toSoup:kTestSoupName withExternalIdPath:SOUP_ENTRY_ID error:nil];
    } error:&error];
    XCTAssertTrue(success);
    XCTAssertNil(error);
    XCTAssertEqual([self countEntriesInSoup:kTestSoupName store:self.store], 1UL);
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
