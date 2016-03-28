/*
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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

#import <XCTest/XCTest.h>
#import "NSMutableOrderedSet+SFSDKUtils.h"

@interface NSMutableOrderedSet_SFSDKUtilsTests : XCTestCase

@property (nonatomic, strong) NSMutableOrderedSet *set;

@end

@implementation NSMutableOrderedSet_SFSDKUtilsTests

- (void)setUp {
    [super setUp];
    self.set = [NSMutableOrderedSet orderedSet];
}

- (void)tearDown {
    self.set = nil;
    [super tearDown];
}

- (void)testAddWeakifiedObjectSingleReference {
    NSArray *ary1 = @[ @"One", @"Two", @"Three" ];
    NSArray *ary2 = @[ @"One", @"Two", @"Three" ];
    [self.set msdkAddObjectToWeakify:ary1];
    [self.set msdkAddObjectToWeakify:ary1];
    [self.set msdkAddObjectToWeakify:ary2];
    __block NSUInteger ary1ObjectsCount = 0;
    __block NSUInteger ary2ObjectsCount = 0;
    [self.set msdkEnumerateWeakifiedObjectsWithBlock:^(id aryObj) {
        if (aryObj == ary1) {
            ary1ObjectsCount++;
        } else if (aryObj == ary2) {
            ary2ObjectsCount++;
        }
    }];
    XCTAssertEqual(self.set.count, 2, @"Should be two elements in the ordered set.");
    XCTAssertEqual(ary1ObjectsCount, 1, @"A given object reference should only be stored once.");
    XCTAssertEqual(ary2ObjectsCount, 1, @"A given object reference should only be stored once.");
}

- (void)testRemoveWeakifiedObject {
    NSDictionary *dict = @{ @1: @"One", @2: @"Two", @3: @"Three" };
    [self.set msdkAddObjectToWeakify:dict];
    XCTAssertEqual(self.set.count, 1, @"Object should have been added to the ordered set.");
    NSUInteger objIdx = [self.set msdkIndexOfWeakifiedObject:dict];
    XCTAssertEqual(objIdx, 0, @"Dict should be the first object in the ordered set.");
    id dictObj = [self.set msdkWeakifiedObjectAtIndex:objIdx];
    XCTAssertEqual(dict, dictObj, @"Dict objects should be the same.");
    
    [self.set msdkRemoveWeakifiedObject:dict];
    XCTAssertEqual(self.set.count, 0, @"Should no longer be items in the ordered set.");
    objIdx = [self.set msdkIndexOfWeakifiedObject:dict];
    XCTAssertEqual(objIdx, NSNotFound, @"Index for non-existent object should be NSNotFound.");
}

- (void)testWeakifiedObjectIndex {
    __strong NSArray *ary;
    @autoreleasepool {
        ary = @[ @"One", @"Two", @"Three" ];
        [self.set msdkAddObjectToWeakify:ary];
        NSUInteger objIdx = [self.set msdkIndexOfWeakifiedObject:ary];
        XCTAssertEqual(objIdx, 0, @"Weakified object not found in ordered set.");
        
        // Set strong array reference to a different object/value.
        ary = @[ ];
    }
    
    NSArray *weakifiedArray = [self.set msdkWeakifiedObjectAtIndex:0];
    XCTAssertNil(weakifiedArray, @"Once released, weakified object should be nil.");
    NSUInteger indexForNonExistentObj = [self.set msdkIndexOfWeakifiedObject:ary];
    XCTAssertEqual(indexForNonExistentObj, NSNotFound, @"Should return NSNotFound for object not in set.");
}

- (void)testEnumerateWeakifiedObjects {
    NSDictionary *obj1 = @{ @"key1": @"value1" };
    NSArray *obj2 = @[ @1, @2, @3 ];
    NSString *obj3 = @"Test String";
    [self.set msdkAddObjectToWeakify:obj1];
    [self.set msdkAddObjectToWeakify:obj2];
    [self.set msdkAddObjectToWeakify:obj3];
    __block BOOL obj1Occurs = NO;
    __block BOOL obj2Occurs = NO;
    __block BOOL obj3Occurs = NO;
    [self.set msdkEnumerateWeakifiedObjectsWithBlock:^(id weakObj) {
        if (weakObj == obj1) {
            obj1Occurs = YES;
        } else if (weakObj == obj2) {
            obj2Occurs = YES;
        } else if (weakObj == obj3) {
            obj3Occurs = YES;
        } else {
            XCTFail(@"Object '%@' should not occur in the ordered set.", weakObj);
        }
    }];
    XCTAssertTrue(obj1Occurs, @"Didn't find obj1 in the ordered set.");
    XCTAssertTrue(obj2Occurs, @"Didn't find obj2 in the ordered set.");
    XCTAssertTrue(obj3Occurs, @"Didn't find obj3 in the ordered set.");
}

- (void)testContainsWeakifiedObject {
    XCTAssertFalse([self.set msdkContainsWeakifiedObject:nil], @"Nil should never be 'contained' (acknoweldged) in the ordered set.");
    NSArray *ary = @[ @"hello", @"world" ];
    NSDictionary *dict = @{ @"key": @"value" };
    [self.set msdkAddObjectToWeakify:ary];
    XCTAssertTrue([self.set msdkContainsWeakifiedObject:ary], @"Array should be contained in the ordered set.");
    XCTAssertFalse([self.set msdkContainsWeakifiedObject:dict], @"Dictionary should not be contained in the ordered set.");
}

- (void)testWeakifiedObjectAtIndex {
    [self.set addObject:@"Non-weakified string"];
    XCTAssertNil([self.set msdkWeakifiedObjectAtIndex:0], @"Non-weakified objects should report as nil in this case.");
    NSArray *ary = @[ @"Test", @"Array" ];
    [self.set msdkAddObjectToWeakify:ary];
    id weakifiedObj = [self.set msdkWeakifiedObjectAtIndex:1];
    XCTAssertEqual(weakifiedObj, ary, @"Weakified array and input array should be equal.");
    XCTAssertThrows([self.set msdkWeakifiedObjectAtIndex:2], @"Indexes out of range should throw an NSRangeException.");
}

@end
