/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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

#import "NSURL+SFStringUtilsTests.h"
#import "NSURL+SFStringUtils.h"

@implementation NSURL_SFStringUtilsTests

#pragma mark - NSURL+SFStringUtils tests

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

- (void)testNoQueryString
{
    NSString *inUrlString = @"https://www.myserver.com/path.html";
    NSURL *url = [NSURL URLWithString:inUrlString];
    NSString *outUrlString = [url redactedAbsoluteString:nil];
    XCTAssertEqual(inUrlString, outUrlString,
                   @"'%@' and '%@' should be the same, with no querystring.",
                   inUrlString,
                   outUrlString);
}

- (void)testNoParams
{
    NSString *inUrlString = @"https://www.myserver.com/path?param1=val1&param2=val2";
    NSURL *url = [NSURL URLWithString:inUrlString];
    NSString *outUrlString = [url redactedAbsoluteString:nil];
    XCTAssertEqual(inUrlString, outUrlString,
                   @"'%@' and '%@' should be the same, with no arguments.",
                   inUrlString,
                   outUrlString);
}

- (void)testNoMatchingParams
{
    NSString *inUrlString = @"https://www.myserver.com/path?param1=val1&param2=val2";
    NSURL *url = [NSURL URLWithString:inUrlString];
    NSArray *redactParams = @[@"param3", @"param4"];
    NSString *outUrlString = [url redactedAbsoluteString:redactParams];
    XCTAssertTrue([inUrlString isEqualToString:outUrlString],
                 @"'%@' and '%@' should be the same, with no matching arguments.",
                 inUrlString,
                 outUrlString);
}

- (void)testOneMatchingParam
{
    NSString *inUrlString = @"https://www.myserver.com/path?param1=val1&param2=val2";
    NSURL *url = [NSURL URLWithString:inUrlString];
    NSArray *redactParams = @[@"param1"];
    NSString *expectedOutUrlString = [NSString stringWithFormat:@"https://www.myserver.com/path?param1=%@&param2=val2",
                                      kSFRedactedQuerystringValue];
    NSString *actualOutUrlString = [url redactedAbsoluteString:redactParams];
    XCTAssertTrue([expectedOutUrlString isEqualToString:actualOutUrlString],
                 @"'%@' should turn into '%@'.  Got '%@' instead.",
                 inUrlString,
                 expectedOutUrlString,
                 actualOutUrlString);
}

- (void)testMultipleMatchingParams
{
    NSString *inUrlString = @"https://www.myserver.com/path?param1=val1&param2=val2";
    NSURL *url = [NSURL URLWithString:inUrlString];
    NSArray *redactParams = @[@"param1", @"param2"];
    NSString *expectedOutUrlString = [NSString stringWithFormat:@"https://www.myserver.com/path?param1=%@&param2=%@",
                                      kSFRedactedQuerystringValue,
                                      kSFRedactedQuerystringValue];
    NSString *actualOutUrlString = [url redactedAbsoluteString:redactParams];
    XCTAssertTrue([expectedOutUrlString isEqualToString:actualOutUrlString],
                 @"'%@' should turn into '%@'.  Got '%@' instead.",
                 inUrlString,
                 expectedOutUrlString,
                 actualOutUrlString);
}

- (void)testStringUrlWithBaseUrlAndComponents {
    XCTAssertEqualObjects(@"http://test.salesforce.com", [NSURL stringUrlWithBaseUrl:[NSURL URLWithString:@"http://test.salesforce.com"] pathComponents:nil], @"Invalid URL string");
    XCTAssertEqualObjects(@"http://test.salesforce.com:8080", [NSURL stringUrlWithBaseUrl:[NSURL URLWithString:@"http://test.salesforce.com:8080"] pathComponents:nil], @"Invalid URL string");
    XCTAssertEqualObjects(@"http://test.salesforce.com:8080/customers", [NSURL stringUrlWithBaseUrl:[NSURL URLWithString:@"http://test.salesforce.com:8080/customers"] pathComponents:nil], @"Invalid URL string");
    XCTAssertEqualObjects(@"http://test.salesforce.com:8080/customers/service/data/v42.0", ([NSURL stringUrlWithBaseUrl:[NSURL URLWithString:@"http://test.salesforce.com:8080/customers"] pathComponents:@[@"service/data", @"v42.0"]]), @"Invalid URL string");
}

- (void)testStringUrlWithComponents
{
    XCTAssertEqualObjects(@"http://test.salesforce.com", [NSURL stringUrlWithScheme:@"http" host:@"test.salesforce.com" port:nil pathComponents:nil], @"Invalid URL string");
    XCTAssertEqualObjects(@"http://test.salesforce.com:8080", [NSURL stringUrlWithScheme:@"http" host:@"test.salesforce.com" port:@(8080) pathComponents:nil], @"Invalid URL string");
    XCTAssertEqualObjects(@"https://test.salesforce.com:3747", [NSURL stringUrlWithScheme:@"https" host:@"test.salesforce.com" port:@(3747) pathComponents:nil], @"Invalid URL string");
    XCTAssertEqualObjects(@"https://test.salesforce.com:3747/customers", [NSURL stringUrlWithScheme:@"https" host:@"test.salesforce.com" port:@(3747) pathComponents:@[@"customers"]], @"Invalid URL string");
    XCTAssertEqualObjects(@"https://test.salesforce.com:3747/customers", [NSURL stringUrlWithScheme:@"https" host:@"test.salesforce.com" port:@(3747) pathComponents:@[@"/customers"]], @"Invalid URL string");
    XCTAssertEqualObjects(@"https://test.salesforce.com:3747/customers/", [NSURL stringUrlWithScheme:@"https" host:@"test.salesforce.com" port:@(3747) pathComponents:@[@"customers/"]], @"Invalid URL string");
    XCTAssertEqualObjects(@"https://test.salesforce.com:3747/customers/", [NSURL stringUrlWithScheme:@"https" host:@"test.salesforce.com" port:@(3747) pathComponents:@[@"/customers/"]], @"Invalid URL string");
    XCTAssertEqualObjects(@"https://test.salesforce.com:3747/customers/service/data/v42.0/settings", ([NSURL stringUrlWithScheme:@"https" host:@"test.salesforce.com" port:@(3747) pathComponents:@[@"/customers", @"service/data/v42.0/", @"settings"]]), @"Invalid URL string");
    XCTAssertEqualObjects(@"https://test.salesforce.com:3747/customers/service/data/v42.0/settings", ([NSURL stringUrlWithScheme:@"https" host:@"test.salesforce.com" port:@(3747) pathComponents:@[@"/customers/", @"/service/data/v42.0/", @"/settings"]]), @"Invalid URL string");
}

- (void)testStringURLWithNil
{
    XCTAssertNil([NSURL stringUrlWithScheme:nil host:@"test.salesforce.com" port:nil pathComponents:nil], @"Should return nil");
    XCTAssertNil([NSURL stringUrlWithScheme:@"http" host:nil port:nil pathComponents:nil], @"Should return nil");
    XCTAssertNil([NSURL stringUrlWithScheme:nil host:nil port:nil pathComponents:nil], @"Should return nil");
}

- (void)testSlashTerminatedUrl {
    NSURL *url = [NSURL URLWithString:@"https://www.salesforce.com"];
    XCTAssertEqualObjects([url slashTerminatedUrl], [NSURL URLWithString:@"https://www.salesforce.com/"]);
}

- (void)testSlashTerminatedUrlWithAlreadySlashTerminatedUrl {
    NSURL *url = [NSURL URLWithString:@"https://www.salesforce.com/"];
    XCTAssertEqualObjects([url slashTerminatedUrl], [NSURL URLWithString:@"https://www.salesforce.com/"]);
}

@end

#pragma clang diagnostic pop
