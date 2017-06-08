/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFSDKSafeMutableDictionary.h"

@interface SFSDKSafeMutableDictionaryTests : XCTestCase

@property (strong, nonatomic) SFSDKSafeMutableDictionary *testDictionary;
@property (strong, nonatomic) NSArray *testKeys;
@end

@implementation SFSDKSafeMutableDictionaryTests

- (void)setUp {
    [super setUp];
    self.testDictionary = [[SFSDKSafeMutableDictionary alloc] init];
    self.testKeys = [self generateTestKeys];
    NSArray *objects = [self generateTestValues];
    [self.testKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
        [self.testDictionary setObject:objects[idx] forKey:key];
    }];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testConcurrentReadWrites {
    NSArray *overwriteValues = [self generateTestValues];
    XCTestExpectation *writeExpectation = [self expectationWithDescription:@"writeExpectation"];
    XCTestExpectation *readExpectation = [self expectationWithDescription:@"readExpectation"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self performWrites:self.testDictionary keys:self.testKeys objects:overwriteValues];
        [writeExpectation fulfill];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self performReads:self.testDictionary keys:self.testKeys];
        [readExpectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Error occurred while waiting for expectations! Error: %@", error.localizedDescription);
        }
    }];
}

#pragma Mark - Helper Methods

- (NSArray *)generateTestKeys {
    NSMutableArray *keys = [[NSMutableArray alloc] initWithCapacity:1000];
    for (NSUInteger idx = 0; idx < 1000; idx++) {
        [keys addObject:[NSString stringWithFormat:@"%lu", idx]];
    }
    return keys;
}

- (NSArray *)generateTestValues {
    NSMutableArray *values = [[NSMutableArray alloc] initWithCapacity:1000];
    for (NSUInteger idx = 0; idx < 1000; idx++) {
        [values addObject:@(arc4random_uniform(1000))];
    }
    return values;
}

- (void)performWrites:(SFSDKSafeMutableDictionary *)dictionary keys:(NSArray<NSCopying> *)keys objects:(NSArray *)objects {
    [keys enumerateObjectsUsingBlock:^(NSString * _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
        [self.testDictionary setObject:objects[idx] forKey:key];
    }];
}

- (void)performReads:(SFSDKSafeMutableDictionary *)dictionary keys:(NSArray<NSCopying> *)keys {
    for (id key in keys) {
        [self.testDictionary objectForKey:key];
    }
}

@end
