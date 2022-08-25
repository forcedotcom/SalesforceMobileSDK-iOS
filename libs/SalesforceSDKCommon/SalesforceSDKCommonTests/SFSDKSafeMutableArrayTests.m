/*
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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

@import XCTest;
#import "SFSDKSafeMutableArray.h"

@interface SFSDKSafeMutableArrayTests : XCTestCase
@end

@implementation SFSDKSafeMutableArrayTests

- (void)testReadWrites {
    SFSDKSafeMutableArray *array = [SFSDKSafeMutableArray array];
    NSString *obj1 = @"Test1";
    NSString *obj2 = @"Test2";
    
    [array addObject:obj1];
    [array addObject:obj2];
    [array addObject:[NSNumber numberWithInt:10]];
    
    XCTAssertTrue([array containsObject:obj1]);
    XCTAssertTrue([array containsObject:obj2]);
    XCTAssertTrue([[array[0] description] isEqualToString:obj1]);
    XCTAssertTrue([[array[1] description] isEqualToString:obj2]);
    XCTAssertEqual([array[2] integerValue], 10);
}

- (void)testReadWriteDelete {
    SFSDKSafeMutableArray *array = [SFSDKSafeMutableArray arrayWithCapacity:3];
    [array insertObject:@"Test2" atIndex:0];
    [array insertObject:@"Test1" atIndex:1];
    
    XCTAssertEqual([array[0] description], @"Test2");
    XCTAssertEqual([array[1] description], @"Test1");
    [array removeObject:@"Test2"];
    XCTAssertEqual([array[0] description], @"Test1");
    [array removeAllObjects];
    XCTAssertTrue([array count]==0);
}

- (void)testConcurrentWrites {
    NSArray *inputs = @[@"Test1", @"Test2", @"Test3", @"Test4", @"Test5"];
    
    SFSDKSafeMutableArray *array = [SFSDKSafeMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [array addObjectsFromArray:inputs];
    });
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    //Does the array have the right number of items?
    XCTAssertTrue(array.count == inputs.count);
    //Does the array have each of our items?
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        XCTAssertTrue([inputs containsObject:obj]);
        XCTAssertEqual(inputs[idx], obj);
    }];
}

- (void)testConcurrentReadWrites {
    NSArray *inputs = @[@"Test1", @"Test2", @"Test3", @"Test4", @"Test5"];
    
    SFSDKSafeMutableArray *array = [SFSDKSafeMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    
    [inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [array addObject:inputs[idx]];
    }];
    
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            XCTAssertNotNil(array[idx]);
        });
    }];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    //Does the array have the right number of items?
    XCTAssertTrue(array.count == inputs.count);
    //Does the array have each of our items?
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        XCTAssertTrue([inputs containsObject:obj]);
        XCTAssertEqual(inputs[idx], obj);
    }];
}

- (void)testConcurrentReadsAndRemove {
    NSArray *inputs = @[@"Test1", @"Test2", @"Test3", @"Test4", @"Test5"];
    
    SFSDKSafeMutableArray *array = [SFSDKSafeMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    
    [inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [array addObject:inputs[idx]];
    }];
    
    XCTAssertEqual(array.count,inputs.count);
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [array removeLastObject];
        });
    }];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    //Have all items been removed
    XCTAssertTrue(array.count == 0);
}

- (void)testConcurrentReadsAndRemoveAll {
    NSArray *inputs = @[@"Test1", @"Test2", @"Test3", @"Test4", @"Test5"];
    
    SFSDKSafeMutableArray *array = [SFSDKSafeMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    
    [inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [array addObject:inputs[idx]];
    }];
    
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (idx < array.count) {
                XCTAssertNotNil(array[idx]);
            }
        });
    }];
    
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [array removeAllObjects];
    });
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    //Have all items been removed
    XCTAssertTrue(array.count == 0);
}

- (void)testConcurrentReadsAndRemoveWithIndexes {
    NSArray *inputs = @[@"Test1", @"Test2", @"Test3", @"Test4", @"Test5"];
    
    SFSDKSafeMutableArray *array = [SFSDKSafeMutableArray arrayWithCapacity:6];
    [array insertObject:@"Test0" atIndex:0];
    dispatch_group_t group = dispatch_group_create();
    
    NSIndexSet* indexSet = [[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(1, 5)];
    [array insertObjects:inputs atIndexes:indexSet];
    
    
    XCTAssertEqual(array.count,inputs.count + 1);
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (idx > 0) {
                XCTAssertEqual(inputs[idx - 1], obj);
            }
        });
    }];
    
    [inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [array removeObjectIdenticalTo:obj];
        });
    }];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    //Have all items been removed
    XCTAssertTrue(array.count == 1);
}

@end
