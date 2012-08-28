//
//  SFSmartStoreTests.m
//  SalesforceSDK
//
//  Created by Wolfgang Mathurin on 6/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SFSmartStoreTests.h"
#import "SFJsonUtils.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "SFSoupQuerySpec.h"
#import "SFSoupCursor.h"
#import "SFSmartStoreDatabaseManager.h"

NSString * const kTestSmartStoreName   = @"testSmartStore";
NSString * const kTestSoupName   = @"testSoup";

@interface SFSmartStoreTests ()
- (void) assertSameJSONWithExpected:(id)expected actual:(id)actual message:(NSString*)message;
- (void) assertSameJSONArrayWithExpected:(NSArray*)expected actual:(NSArray*)actual message:(NSString*)message;
- (void) assertSameJSONMapWithExpected:(NSDictionary*)expected actual:(NSDictionary*)actual message:(NSString*)message;
- (BOOL) hasTable:(NSString*)tableName;
@end

@implementation SFSmartStoreTests


#pragma mark - setup and teardown


- (void) setUp
{
    [super setUp];
    _store = [[SFSmartStore sharedStoreWithName:kTestSmartStoreName] retain];
}

- (void) tearDown
{
    [_store release]; // close underlying db
    _store = nil;
    [SFSmartStore removeSharedStoreWithName:kTestSmartStoreName];
    [super tearDown];
}


#pragma mark - tests
// All code under test must be linked into the Unit Test bundle

/**
 * Testing method with paths to top level string/integer/array/map as well as edge cases (nil object/nil or empty path)
 */
- (void) testProjectTopLevel
{
    NSString* rawJson = @"{\"a\":\"va\", \"b\":2, \"c\":[0,1,2], \"d\": {\"d1\":\"vd1\", \"d2\":\"vd2\", \"d3\":[1,2], \"d4\":{\"e\":5}}}";
    NSDictionary* json = [SFJsonUtils objectFromJSONString:rawJson];
    
    // Null object
    STAssertNil([SFJsonUtils projectIntoJson:nil path:@"path"], @"Should have been null");
    
    // Root object
    [self assertSameJSONWithExpected:json actual:[SFJsonUtils projectIntoJson:json path:nil] message:@"Should have returned whole object"];
    [self assertSameJSONWithExpected:json actual:[SFJsonUtils projectIntoJson:json path:@""] message:@"Should have returned whole object"];
    
    // Top-level elements
    [self assertSameJSONWithExpected:@"va" actual:[SFJsonUtils projectIntoJson:json path:@"a"] message:@"Wrong value for key a"];
    [self assertSameJSONWithExpected:[NSNumber numberWithInt:2]  actual:[SFJsonUtils projectIntoJson:json path:@"b"] message:@"Wrong value for key b"];
    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"[0,1,2]"] actual:[SFJsonUtils projectIntoJson:json path:@"c"] message:@"Wrong value for key c"];
    [self assertSameJSONWithExpected:[SFJsonUtils objectFromJSONString:@"{\"d1\":\"vd1\", \"d2\":\"vd2\", \"d3\":[1,2], \"d4\":{\"e\":5}}"] actual:[SFJsonUtils projectIntoJson:json path:@"d"] message:@"Wrong value for key d"];
}

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
    [self assertSameJSONWithExpected:[NSNumber numberWithInt:5] actual:[SFJsonUtils projectIntoJson:json path:@"d.d4.e"] message:@"Wrong value for key d.d4.e"];    
}

/**
 * Check that the meta data tables (soup index map and soup names) have been created
 */
- (void) testMetaDataTablesCreated
{
    STAssertTrue([self hasTable:@"soup_index_map"], @"Soup index map table not found");
    STAssertTrue([self hasTable:@"soup_names"], @"Soup names table not found");
}

/**
 * Test register/remove soup
 */
- (void) testRegisterRemoveSoup
{
    // Before
    STAssertFalse([_store soupExists:kTestSoupName], @"Soup %@ should not exist", kTestSoupName);
    
    // Register
    NSDictionary* soupIndex = [NSDictionary dictionaryWithObjectsAndKeys:@"name",@"path",@"string",@"type",nil];
    [_store registerSoup:kTestSoupName withIndexSpecs:[NSArray arrayWithObjects:soupIndex, nil]];
    STAssertTrue([_store soupExists:kTestSoupName], @"Soup %@ should exist", kTestSoupName);
    
    // Remove
    [_store removeSoup:kTestSoupName];
    STAssertFalse([_store soupExists:kTestSoupName], @"Soup %@ should no longer exist", kTestSoupName);
    
}

/**
 * Test registering same soup name multiple times.
 */
- (void) testMultipleRegisterSameSoup
{
    // Before
    STAssertFalse([_store soupExists:kTestSoupName], @"Soup %@ should not exist", kTestSoupName);
    
    // Register first time.
    NSDictionary* soupIndex = [NSDictionary dictionaryWithObjectsAndKeys:@"name",@"path",@"string",@"type",nil];
    [_store registerSoup:kTestSoupName withIndexSpecs:[NSArray arrayWithObjects:soupIndex, nil]];
    STAssertTrue([_store soupExists:kTestSoupName], @"Soup %@ should exist", kTestSoupName);
    
    // Register second time.  Should only create one soup per unique soup name.
    [_store registerSoup:kTestSoupName withIndexSpecs:[NSArray arrayWithObjects:soupIndex, nil]];
    int rowCount = [_store.storeDb intForQuery:@"SELECT COUNT(*) FROM soup_names WHERE soupName = ?", kTestSoupName];
    STAssertEquals(rowCount, 1, @"Soup names should be unique within a store.");
    
    // Remove
    [_store removeSoup:kTestSoupName];
    STAssertFalse([_store soupExists:kTestSoupName], @"Soup %@ should no longer exist", kTestSoupName);
    
}

- (void)testQuerySpecPageSize
{
    NSDictionary *allQueryNoPageSize = [NSDictionary dictionaryWithObjectsAndKeys:kQuerySpecTypeRange, kQuerySpecParamQueryType,
                              @"a/path", kQuerySpecParamIndexPath,
                              nil];
    
    SFSoupQuerySpec *querySpec = [[SFSoupQuerySpec alloc] initWithDictionary:allQueryNoPageSize];
    STAssertEquals(querySpec.pageSize, kQuerySpecDefaultPageSize, @"Page size value should be default, if not specified.");
    [querySpec release];
    
    uint expectedPageSize = 42;
    NSDictionary *allQueryWithPageSize = [NSDictionary dictionaryWithObjectsAndKeys:kQuerySpecTypeRange, kQuerySpecParamQueryType,
                                        @"a/path", kQuerySpecParamIndexPath,
                                          [NSNumber numberWithInt:expectedPageSize], kQuerySpecParamPageSize,
                                        nil];
    querySpec = [[SFSoupQuerySpec alloc] initWithDictionary:allQueryWithPageSize];
    STAssertEquals(querySpec.pageSize, expectedPageSize, @"Page size value should reflect input value.");
    [querySpec release];
}

- (void)testCursorTotalPages
{
    uint totalEntries = 50;
    
    // Entries divided evenly by the page size.
    uint evenDividePageSize = 25;
    int expectedPageSize = totalEntries / evenDividePageSize;
    NSDictionary *allQuery = [NSDictionary dictionaryWithObjectsAndKeys:kQuerySpecTypeRange, kQuerySpecParamQueryType,
                                          @"a/path", kQuerySpecParamIndexPath,
                                          [NSNumber numberWithInt:evenDividePageSize], kQuerySpecParamPageSize,
                                          nil];
    SFSoupQuerySpec *querySpec = [[SFSoupQuerySpec alloc] initWithDictionary:allQuery];
    SFSoupCursor *cursor = [[SFSoupCursor alloc] initWithSoupName:@"test" store:nil querySpec:querySpec totalEntries:totalEntries];
    STAssertEquals([cursor.totalPages intValue], expectedPageSize, @"%d entries across a page size of %d should make %d total pages.", totalEntries, evenDividePageSize, expectedPageSize);
    [querySpec release];
    [cursor release];
    
    // Entries not evenly divided across the page size.
    uint unevenDividePageSize = 24;
    expectedPageSize = totalEntries / unevenDividePageSize + 1;
    allQuery = [NSDictionary dictionaryWithObjectsAndKeys:kQuerySpecTypeRange, kQuerySpecParamQueryType,
                              @"a/path", kQuerySpecParamIndexPath,
                              [NSNumber numberWithInt:unevenDividePageSize], kQuerySpecParamPageSize,
                              nil];
    querySpec = [[SFSoupQuerySpec alloc] initWithDictionary:allQuery];
    cursor = [[SFSoupCursor alloc] initWithSoupName:@"test" store:nil querySpec:querySpec totalEntries:totalEntries];
    STAssertEquals([cursor.totalPages intValue], expectedPageSize, @"%d entries across a page size of %d should make %d total pages.", totalEntries, unevenDividePageSize, expectedPageSize);
    [querySpec release];
    [cursor release];
}

- (void)testPersistentStoreExists
{
    NSString *storeName = @"xyzpdq";
    STAssertFalse([[SFSmartStoreDatabaseManager sharedManager] persistentStoreExists:storeName], @"Store should not exist at this point.");
    FMDatabase *db = nil;
    NSError *error = nil;
    [[SFSmartStoreDatabaseManager sharedManager] createStoreDir:storeName error:&error];
    STAssertNil(error, @"Error creating store dir: %@", [error localizedDescription]);
    [[SFSmartStoreDatabaseManager sharedManager] openStoreDatabaseWithName:storeName key:@"" db:&db];
    STAssertTrue([[SFSmartStoreDatabaseManager sharedManager] persistentStoreExists:storeName], @"Store should exist after creation.");
    [db close];
    [[SFSmartStoreDatabaseManager sharedManager] removeStoreDir:storeName];
    STAssertFalse([[SFSmartStoreDatabaseManager sharedManager] persistentStoreExists:storeName], @"Store should no longer exist at this point.");
}

#pragma mark - helper methods

- (void) assertSameJSONWithExpected:(id)expected actual:(id) actual message:(NSString*) message
{
    // At least one nil
    if (expected == nil || actual == nil) {
        // Both nil
        if (expected == nil && actual == nil) {
            return;
        }
        else {
           STFail(message);
        }
    }
    // Both arrays
    else if ([expected isKindOfClass:[NSArray class]] && [actual isKindOfClass:[NSArray class]]) {
        [self  assertSameJSONArrayWithExpected:(NSArray*) expected actual:(NSArray*) actual message:message];
    }
    // Both maps
    else if ([expected isKindOfClass:[NSDictionary class]] && [actual isKindOfClass:[NSDictionary class]]) {
        [self  assertSameJSONMapWithExpected:(NSDictionary*) expected actual:(NSDictionary*) actual message:message];        
    }
    // Strings/numbers/booleans
    else {
        STAssertEqualObjects(expected, actual, message);
    }
    
}

- (void) assertSameJSONArrayWithExpected:(NSArray*)expected actual:(NSArray*) actual message:(NSString*) message 
{
    // First compare length
    NSUInteger expectedCount = [expected count];
    STAssertEquals(expectedCount, [actual count], message);
 
    // Compare values in array
    for (int i=0; i<expectedCount; i++) {
        [self assertSameJSONWithExpected:[expected objectAtIndex:i] actual:[actual objectAtIndex:i] message:message];
    }
}

- (void) assertSameJSONMapWithExpected:(NSDictionary*)expected actual:(NSDictionary*) actual message:(NSString*) message
{
    // First compare length
    NSUInteger expectedCount = [expected count];
    STAssertEquals(expectedCount, [actual count], message);
    
    // Compare values in array
    NSEnumerator* enumator = [expected keyEnumerator];
    id key;
    while (key = [enumator nextObject]) {
        [self assertSameJSONWithExpected:[expected objectForKey:key] actual:[actual objectForKey:key] message:message];
    }
}

- (BOOL) hasTable:(NSString*)tableName
{
    FMResultSet *frs = [_store.storeDb executeQuery:@"select count(1) from sqlite_master where type = ? and name = ?" withArgumentsInArray:[NSArray arrayWithObjects:@"table", tableName, nil]];

    int result = NSNotFound;
    if ([frs next]) {        
        result = [frs intForColumnIndex:0];
    }
    [frs close];
    
    return result == 1;
}
@end
