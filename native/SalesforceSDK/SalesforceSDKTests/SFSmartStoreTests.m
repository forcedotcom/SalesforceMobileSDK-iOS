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

NSString * const kTestSmartStoreName   = @"testSmartStore";
NSString * const kTestSoupName   = @"testSoup";

@interface SFSmartStoreTests ()
- (void) assertSameJSONWithExpected:(id)expected actual:(id)actual message:(NSString*)message;
- (void) assertSameJSONArrayWithExpected:(NSArray*)expected actual:(NSArray*)actual message:(NSString*)message;
- (void) assertSameJSONMapWithExpected:(NSDictionary*)expected actual:(NSDictionary*)actual message:(NSString*)message;
- (BOOL) hasTable:(NSString*)tableName store:(SFSmartStore*)store;
@end

@implementation SFSmartStoreTests


#pragma mark - setup and teardown


- (void) setUp
{
    // Set-up code here.
    [super setUp];
}

- (void) tearDown
{
    // Tear-down code here.    
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
    NSDictionary* json = (NSDictionary*) [SFJsonUtils objectFromJSONString:rawJson];
    
    // Null object
    STAssertNil([SFJsonUtils projectIntoJson:nil path:@"path"], @"Should have been null");
    
    NSLog(@"here");
    
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
    NSDictionary* json = (NSDictionary*) [SFJsonUtils objectFromJSONString:rawJson];

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
    SFSmartStore* store = [[SFSmartStore sharedStoreWithName:kTestSmartStoreName] retain];
    @try {
        STAssertTrue([self hasTable:@"soup_index_map" store:store], @"Soup index map table not found");
        STAssertTrue([self hasTable:@"soup_names" store:store], @"Soup names table not found");
    }
    @finally {
        [store release]; // close the underlying db
        [SFSmartStore removeSharedStoreWithName:kTestSmartStoreName];
    }
}

/**
 * Test register/remove soup
 */
- (void) testRegisterRemoveSoup
{
    SFSmartStore* store = [[SFSmartStore sharedStoreWithName:kTestSmartStoreName] retain];
    @try {
        // Before
        STAssertFalse([store soupExists:kTestSoupName], @"Soup %@ should not exist", kTestSoupName);
        
        // Register
        NSDictionary* soupIndex = [NSDictionary dictionaryWithObjectsAndKeys:@"name",@"path",@"string",@"type",nil];
        [store registerSoup:kTestSoupName withIndexSpecs:[NSArray arrayWithObjects:soupIndex, nil]];
        STAssertTrue([store soupExists:kTestSoupName], @"Soup %@ should exist", kTestSoupName);
        
        // Remove
        [store removeSoup:kTestSoupName];
        STAssertFalse([store soupExists:kTestSoupName], @"Soup %@ should no longer exist", kTestSoupName);
    }
    @finally {
        [store release]; // close the underlying db
        [SFSmartStore removeSharedStoreWithName:kTestSmartStoreName];
    }
    
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

- (BOOL) hasTable:(NSString*)tableName store:(SFSmartStore*)store
{
    FMResultSet *frs = [store.storeDb executeQuery:@"select count(1) from sqlite_master where type = ? and name = ?" withArgumentsInArray:[NSArray arrayWithObjects:@"table", tableName, nil]];

    int result = NSNotFound;
    if ([frs next]) {        
        result = [frs intForColumnIndex:0];
    }
    [frs close];
    
    return result == 1;
}
@end
