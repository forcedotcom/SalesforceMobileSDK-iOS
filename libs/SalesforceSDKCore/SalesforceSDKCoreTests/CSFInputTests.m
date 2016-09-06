/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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

#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "CSFInput_Internal.h"

@interface TestInputWithMutable : CSFInput

@property (nonatomic, strong) NSString *someProperty;
@property (nonatomic, strong) NSMutableArray *mutableArray;
@property (nonatomic, strong) NSMutableDictionary *mutableDictionary;
@property (nonatomic, strong) NSMutableString *mutableString;
@property (nonatomic, strong) NSMutableAttributedString *mutableAttributedString;

@end

@implementation TestInputWithMutable

@dynamic someProperty, mutableArray, mutableDictionary, mutableString, mutableAttributedString;

@end


@interface TestInputWithCustomAttrs : CSFInput

@end

@implementation TestInputWithCustomAttrs

+ (BOOL)allowsCustomAttributes {
    return YES;
}

@end


@interface CSFInputTests : XCTestCase

@end

@implementation CSFInputTests

- (void)testKeyInput {
    NSDictionary *expected = nil;
    TestInputWithMutable *input = nil;
    
    input = [[TestInputWithMutable alloc] init];
    XCTAssertNotNil(input);
    
    input[@"someProperty"] = @"foo";
    expected = @{ @"someProperty": @"foo" };
    NSLog(@"%@", input.JSONDictionary);
    XCTAssertEqualObjects(input.JSONDictionary, expected);
    
    XCTAssertThrowsSpecificNamed([input setValue:@"bar" forKey:@"otherProperty"], NSException, @"NSUnknownKeyException");
    XCTAssertThrowsSpecificNamed([input setObject:@"bar" forKeyedSubscript:@"otherProperty"], NSException, @"NSUnknownKeyException");
    expected = @{ @"someProperty": @"foo" };
    XCTAssertEqualObjects(input.JSONDictionary, expected);
    NSLog(@"%@", input);
}

- (void)testCustomInput {
    NSDictionary *expected = nil;
    TestInputWithCustomAttrs *input = nil;
    
    input = [[TestInputWithCustomAttrs alloc] init];
    XCTAssertNotNil(input);
    
    input[@"someProperty"] = @"foo";
    expected = @{ @"someProperty": @"foo" };
    XCTAssertEqualObjects(input.JSONDictionary, expected);
    NSLog(@"%@", input);

    input[@"otherProperty"] = @[ @1, @2, @3 ];
    expected = @{ @"someProperty": @"foo", @"otherProperty": @[ @1, @2, @3 ] };
    XCTAssertEqualObjects(input.JSONDictionary, expected);
    NSLog(@"%@", input);
}

- (void)testMutableInput {
    NSDictionary *expected = nil;
    TestInputWithMutable *input = nil;
    
    input = [[TestInputWithMutable alloc] init];
    XCTAssertNotNil(input);
    XCTAssertEqualObjects(input.class, [TestInputWithMutable class]);

    XCTAssertNotNil(input.mutableArray, @"Ensure that accessing a mutable property that hasn't been set yet will auto-create one");
    input.mutableDictionary[@"someKey"] = @"foo";
    XCTAssertNotNil(input.mutableDictionary);
    XCTAssertEqualObjects(input.mutableDictionary[@"someKey"], @"foo");
    XCTAssertEqualObjects([input valueForKeyPath:@"mutableDictionary.someKey"], @"foo");

    expected = @{ @"mutableDictionary": @{ @"someKey": @"foo" }, @"mutableArray": @[] };
    XCTAssertEqualObjects(input.JSONDictionary, expected);
}

- (void)testMutableString {
    NSDictionary *expected = nil;
    TestInputWithMutable *input = nil;
    
    input = [[TestInputWithMutable alloc] init];
    XCTAssertNotNil(input);

    [input.mutableString appendString:@"Test"];
    expected = @{ @"mutableString": @"Test" };
    XCTAssertEqualObjects(input.JSONDictionary, expected);
   
    [input.mutableString appendString:@"Other"];
    expected = @{ @"mutableString": @"TestOther" };
    XCTAssertEqualObjects(input.JSONDictionary, expected);

    [input.mutableString insertString:@"Foo" atIndex:1];
    expected = @{ @"mutableString": @"TFooestOther" };
    XCTAssertEqualObjects(input.JSONDictionary, expected);
}

@end
