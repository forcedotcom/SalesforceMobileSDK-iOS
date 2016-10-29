/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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
#import "NSData+SFSDKUtils_Internal.h"

@interface SDKCommonNSDataTests : XCTestCase

@end

@implementation SDKCommonNSDataTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testBase64UrlReplacements {
    NSArray *beforeAfterStrings = @[ @[ @"", @""],
                                     @[ @"abcdefg", @"abcdefg" ],
                                     @[ @"/////", @"_____" ],
                                     @[ @"+++++", @"-----" ],
                                     @[ @"=====", @"" ],
                                     @[ @"///+++===", @"___---" ],
                                     @[ @"===+++///", @"===---___" ],
                                     @[ @"abc+//+def==", @"abc-__-def" ],
                                     @[ @"a/b=c+d", @"a_b=c-d" ]
                                     ];
    
    NSString *nilResult = [NSData replaceBase64CharsForBase64UrlString:nil];
    XCTAssertNil(nilResult, @"nil in should give nil out");
    for (NSArray *beforeAfterPair in beforeAfterStrings) {
        NSString *base64UrlReplace = [NSData replaceBase64CharsForBase64UrlString:beforeAfterPair[0]];
        XCTAssertEqualObjects(base64UrlReplace, beforeAfterPair[1], @"Strings don't match");
    }
}

- (void)testSha256DataGeneration {
    // We'll test that the same SHA256 hash gets generated for each piece of data
    NSMutableArray *entriesArray = [NSMutableArray array];
    for (NSUInteger i = 0; i < 100; i++) {
        NSData *randomData = [self randomDataOfRandomLength];
        [entriesArray addObject:@[ randomData, [randomData msdkSha256Data] ]];
    }
    
    for (NSUInteger i = 0; i < 100; i++) {
        NSData *inData = entriesArray[i][0];
        NSData *sha256Data = [inData msdkSha256Data];
        XCTAssertTrue([sha256Data isEqualToData:entriesArray[i][1]], @"SHA256 value should be the same across generations");
    }
}

#pragma mark - Private methods

- (NSData *)randomDataOfRandomLength {
    // Return an NSData object of a random length, up to 1KB.
    NSUInteger dataLength = (arc4random() % 1024) + 1;
    NSMutableData *data = [NSMutableData dataWithCapacity:dataLength];
    for (NSUInteger i = 0; i < dataLength; i++) {
        u_int8_t byteVal = arc4random() % 256;
        [data appendBytes:&byteVal length:1];
    }
    return data;
}

@end
