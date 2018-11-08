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
#import <XCTest/XCTest.h>
#import "SFSDKSafeMutableSet.h"
@interface SFSDKSafeMutableSetTests : XCTestCase
@end

@implementation SFSDKSafeMutableSetTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testReadWrites {
    
    SFSDKSafeMutableSet *set = [SFSDKSafeMutableSet set];
    [set addObject:@"Test1"];
    [set addObject:@"Test2"];
    
    [set addObject:[NSNumber numberWithInt:10]];
    
    XCTAssertTrue([set containsObject:@"Test1"]);
    XCTAssertTrue([set containsObject:@"Test2"]);
    XCTAssertTrue([set containsObject:[NSNumber numberWithInt:10]]);
}


- (void)testReadWriteDelete {
    
    SFSDKSafeMutableSet *set = [SFSDKSafeMutableSet set];
    [set addObject:@"Test1"];
    [set addObject:@"Test2"];
    XCTAssertTrue([set containsObject:@"Test1"]);
    XCTAssertTrue([set containsObject:@"Test2"]);
    [set removeObject:@"Test1"];
    XCTAssertFalse([set containsObject:@"Test1"]);
    [set removeAllObjects];
    XCTAssertTrue([set count]==0);
}

- (void)testConcurrentWrites {
    NSArray *inputs = @[@"Test1", @"Test2", @"Test3", @"Test4", @"Test5"];
    
    SFSDKSafeMutableSet *set = [SFSDKSafeMutableSet set];
    dispatch_group_t group = dispatch_group_create();
   
    [inputs enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [set addObject:inputs[idx]];
        });
    }];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    //Does the set have the right number of items?
    XCTAssertTrue(set.count == inputs.count);
    //Does the set have each of our items?
    [inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
       XCTAssertTrue([set containsObject:inputs[idx]]);
    }];
}

- (void)testConcurrentReadWrites {
    NSArray *inputs = @[@"Test1", @"Test2", @"Test3", @"Test4", @"Test5"];
    
    SFSDKSafeMutableSet *set = [SFSDKSafeMutableSet set];
    dispatch_group_t group = dispatch_group_create();
    
    [inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [set addObject:inputs[idx]];
        });
    }];
    
   [inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [set anyObject];
        });
    }];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    //Does the set have the right number of items?
    XCTAssertTrue(set.count == inputs.count);
     //Does the set have each of our items?
    [inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        XCTAssertTrue([set containsObject:inputs[idx]]);
    }];
}

- (void)testConcurrentReadsAndRemove {
    NSArray *inputs = @[@"Test1", @"Test2", @"Test3", @"Test4", @"Test5"];
    
    SFSDKSafeMutableSet *set = [SFSDKSafeMutableSet set];
    dispatch_group_t group = dispatch_group_create();
    
    [inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [set addObject:inputs[idx]];
    }];
    
    XCTAssertEqual(set.count,inputs.count);
    [inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [set removeObject:inputs[idx]];
        });
    }];
    
    [inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [set anyObject];
        });
    }];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    //Have all items been removed
    XCTAssertTrue(set.count == 0);
    
}

- (void)testConcurrentReadsAndRemoveAll {
    NSArray *inputs = @[@"Test1", @"Test2", @"Test3", @"Test4", @"Test5"];
    
    SFSDKSafeMutableSet *set = [SFSDKSafeMutableSet set];
    dispatch_group_t group = dispatch_group_create();
    
    [inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [set addObject:inputs[idx]];
    }];
    
    XCTAssertEqual(set.count,inputs.count);
    [inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            [set anyObject];
        });
    }];
    
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [set removeAllObjects];
    });
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    //Have all items been removed
    XCTAssertTrue(set.count == 0);
    
}
@end
