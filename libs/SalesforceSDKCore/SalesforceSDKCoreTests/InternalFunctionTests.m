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

#import "CSFInternalDefines.h"
#import "TestDataAction.h"

@interface InternalFunctionTests : XCTestCase

@end

@implementation InternalFunctionTests

- (void)testNotNull {
    XCTAssertNil(CSFNotNull([NSNull null], [NSString class]));
    XCTAssertNil(CSFNotNull([NSNull null], [NSURL class]));
    XCTAssertNil(CSFNotNull([NSNull null], [NSObject class]));
    XCTAssertNil(CSFNotNull(@YES, [NSString class]));
    XCTAssertNil(CSFNotNull(@{ @"foo": @"bar" }, [NSURL class]));
    XCTAssertNotNil(CSFNotNull(@"Test", [NSString class]));
    XCTAssertNotNil(CSFNotNull(@{ @"foo": @"bar" }, [NSDictionary class]));
    XCTAssertNotNil(CSFNotNull(@"Test", [NSObject class]));
    
    XCTAssertNil(CSFNotNullURL([NSNull null]));
    XCTAssertNotNil(CSFNotNullURL(@"testing"));
    XCTAssertEqualObjects(CSFNotNullURL([NSURL URLWithString:@"http://example.org/foo"]), [NSURL URLWithString:@"http://example.org/foo"]);
    XCTAssertEqualObjects(CSFNotNullURL(@"http://example.org/foo"), [NSURL URLWithString:@"http://example.org/foo"]);
    
    XCTAssertNil(CSFNotNullURLRelative([NSNull null], nil));
    XCTAssertNotNil(CSFNotNullURLRelative(@"testing", nil));
    XCTAssertEqualObjects([CSFNotNullURLRelative(@"testing", [NSURL URLWithString:@"http://example.org/foo/"]) absoluteString],
                           @"http://example.org/foo/testing");
    XCTAssertEqualObjects([CSFNotNullURLRelative([NSURL URLWithString:@"http://example.org/foo"], nil) absoluteString], @"http://example.org/foo");
    XCTAssertEqualObjects([CSFNotNullURLRelative(@"http://example.org/foo", nil) absoluteString], @"http://example.org/foo");
    XCTAssertEqualObjects([CSFNotNullURLRelative([NSURL URLWithString:@"/foo"], [NSURL URLWithString:@"http://example.org"]) absoluteString], @"/foo");
    XCTAssertEqualObjects([CSFNotNullURLRelative(@"/foo", [NSURL URLWithString:@"http://example.org"]) absoluteString], @"http://example.org/foo");
}

- (void)testURLEncoding {
    XCTAssertEqualObjects(CSFURLEncode(@"This and that"), @"This%20and%20that");
    XCTAssertEqualObjects(CSFURLDecode(@"This%20and%20that"), @"This and that");
    
    NSError *error = nil;
    XCTAssertEqualObjects(CSFURLFormEncode(@{ @"foo": @"bar", @"baz": @15 }, &error), @"baz=15&foo=bar");
    XCTAssertNil(error);

    NSDictionary *expected = @{ @"foo": @"bar", @"baz": @"15" };
    XCTAssertEqualObjects(CSFURLFormDecode(@"foo=bar&baz=15", &error), expected);
    XCTAssertNil(error);
}

- (void)testCachePath {
    SFUserAccount *account = [TestDataAction testUserAccount];
    NSURL *url = CSFCachePath(account, nil);
    XCTAssertNotNil(url);
    XCTAssertTrue([url isFileURL]);
    NSString *bundleId = [[NSBundle bundleForClass:NSClassFromString(@"CSFNetwork")] bundleIdentifier];
    
    NSString *expectedPathSuffix = [NSString stringWithFormat:@"/Library/Caches/%@/orgID/userID/Default", bundleId];
    XCTAssertTrue([[url path] hasSuffix:expectedPathSuffix]);
    XCTAssertEqualObjects([url.pathComponents lastObject], @"Default");
    XCTAssertEqualObjects([[NSURL URLWithString:@"baz" relativeToURL:url].pathComponents lastObject], @"baz");

    url = CSFCachePath(account, @"Foo");
    expectedPathSuffix = [NSString stringWithFormat:@"/Library/Caches/%@/orgID/userID/Default/Foo", bundleId];
    XCTAssertNotNil(url);
    XCTAssertTrue([[url path] hasSuffix:expectedPathSuffix]);
    XCTAssertEqualObjects([url.pathComponents lastObject], @"Foo");
    XCTAssertEqualObjects([[NSURL URLWithString:@"baz" relativeToURL:url].pathComponents lastObject], @"baz");

    account.credentials.communityId = @"commID";
    url = CSFCachePath(account, @"Bar");
    expectedPathSuffix = [NSString stringWithFormat:@"/Library/Caches/%@/orgID/userID/commID/Bar", bundleId];
    XCTAssertNotNil(url);
    XCTAssertTrue([[url path] hasSuffix:expectedPathSuffix]);
    XCTAssertEqualObjects([url.pathComponents lastObject], @"Bar");
    XCTAssertEqualObjects([[NSURL URLWithString:@"baz" relativeToURL:url].pathComponents lastObject], @"baz");
}

@end
