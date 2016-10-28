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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "CSFDateValueTransformer.h"
#import "CSFURLValueTransformer.h"
#import "CSFUTF8StringValueTransformer.h"

@interface ValueTransformerTests : XCTestCase

@end

@implementation ValueTransformerTests

- (void)testDateTransformer {
    CSFDateValueTransformer *transformer = [[CSFDateValueTransformer alloc] init];

    XCTAssertEqualObjects([transformer reverseTransformedValue:@"2012-11-31T23:59:59.000Z"],
                          [NSDate dateWithTimeIntervalSince1970:1354406399]);
    XCTAssertEqualObjects([transformer reverseTransformedValue:@"2012-12-31T23:59:59.000Z"],
                          [NSDate dateWithTimeIntervalSince1970:1356998399]);
    XCTAssertEqualObjects([transformer reverseTransformedValue:@"2011-03-01T12:00:00.000Z"],
                          [NSDate dateWithTimeIntervalSince1970:1298980800]);
}

- (void)testURLTransformer {
    CSFURLValueTransformer *transformer = [[CSFURLValueTransformer alloc] init];
    
    NSArray *testStrings = @[ @"http://foo.org/",
                              @"http://foo.baz.com:8100/this/is/a/path" ];
    for (NSString *testString in testStrings) {
        NSURL *url = [NSURL URLWithString:testString];
        XCTAssertEqualObjects([transformer transformedValue:url], testString);
        XCTAssertEqualObjects([transformer reverseTransformedValue:testString], url);
    }
}

- (void)testUTF8Transformer {
    CSFUTF8StringValueTransformer *transformer = [[CSFUTF8StringValueTransformer alloc] init];
    
    NSString *string = @"This is a test. Even with Ümlauts!";
    NSData *data = [transformer transformedValue:string];
    NSString *reverseString = [transformer reverseTransformedValue:data];
    XCTAssertEqualObjects(string, reverseString);
}

@end
