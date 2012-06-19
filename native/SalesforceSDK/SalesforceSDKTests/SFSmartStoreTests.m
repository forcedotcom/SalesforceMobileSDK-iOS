//
//  SFSmartStoreTests.m
//  SalesforceSDK
//
//  Created by Wolfgang Mathurin on 6/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SFSmartStoreTests.h"
#import "SFJsonUtils.h"

NSString * const kTestSmartStoreName   = @"testSmartStore";

@interface SFSmartStoreTests ()
- (void) assertSameJSONWithExpected:(id)expected actual:(id)actual message:(NSString*)message;
- (void) assertSameJSONArrayWithExpected:(NSArray*)expected actual:(NSArray*)actual message:(NSString*)message;
- (void) assertSameJSONMapWithExpected:(NSDictionary*)expected actual:(NSDictionary*)actual message:(NSString*)message;
@end

@implementation SFSmartStoreTests


#pragma mark - setup and teardown


- (void)setUp
{
    // Set-up code here.
    [super setUp];
}

- (void)tearDown
{
    // Tear-down code here.    
    [super tearDown];
}


#pragma mark - tests


// All code under test must be linked into the Unit Test bundle
- (void)testProjectTopLevel
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

#pragma mark - helper methods

- (void) assertSameJSONWithExpected:(id)expected actual:(id) actual message:(NSString*) message {
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

- (void) assertSameJSONArrayWithExpected:(NSArray*)expected actual:(NSArray*) actual message:(NSString*) message {
    // First compare length
    NSUInteger expectedCount = [expected count];
    STAssertEquals(expectedCount, [actual count], message);
 
    // Compare values in array
    for (int i=0; i<expectedCount; i++) {
        [self assertSameJSONWithExpected:[expected objectAtIndex:i] actual:[actual objectAtIndex:i] message:message];
    }
}

- (void) assertSameJSONMapWithExpected:(NSDictionary*)expected actual:(NSDictionary*) actual message:(NSString*) message {
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

@end
