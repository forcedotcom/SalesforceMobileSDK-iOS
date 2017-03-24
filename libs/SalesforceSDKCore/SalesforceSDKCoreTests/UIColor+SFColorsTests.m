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

#import <XCTest/XCTestCase.h>
#import "UIColor+SFColors.h"

#define HexStringFromComponents(colorsComponents) \
[NSString stringWithFormat:@"%X%X%X", (unsigned char)(colorsComponents[0]*255), \
(unsigned char)(colorsComponents[1]*255), \
(unsigned char)(colorsComponents[2]*255)];

@interface UIColor_SFColorsTests : XCTestCase

@end

@implementation UIColor_SFColorsTests

- (void)testColorWithShortHandHexAndPoundPrefix {
    NSString *shortHandHexColor = @"#abc";
    UIColor *color = [UIColor colorFromHexValue:shortHandHexColor];
    NSString *hexFromColor = HexStringFromComponents(CGColorGetComponents(color.CGColor));
    XCTAssert([hexFromColor caseInsensitiveCompare:@"aabbcc"] == NSOrderedSame, @"Hex strings do not match color generated!");
}

- (void)testColorWithShortHandHexNoPoundPrefix {
    NSString *shortHandHexColor = @"abc";
    UIColor *color = [UIColor colorFromHexValue:shortHandHexColor];
    NSString *hexFromColor = HexStringFromComponents(CGColorGetComponents(color.CGColor));
    XCTAssert([hexFromColor caseInsensitiveCompare:@"aabbcc"] == NSOrderedSame, @"Hex strings do not match color generated!");
}

- (void)testColorWithPoundPrefix {
    NSString *shortHandHexColor = @"#aabbcc";
    UIColor *color = [UIColor colorFromHexValue:shortHandHexColor];
    NSString *hexFromColor = HexStringFromComponents(CGColorGetComponents(color.CGColor));
    XCTAssert([hexFromColor caseInsensitiveCompare:@"aabbcc"] == NSOrderedSame, @"Hex strings do not match color generated!");
}

- (void)testColorWithNoPoundPrefix {
    NSString *shortHandHexColor = @"aabbcc";
    UIColor *color = [UIColor colorFromHexValue:shortHandHexColor];
    NSString *hexFromColor = HexStringFromComponents(CGColorGetComponents(color.CGColor));
    XCTAssert([hexFromColor caseInsensitiveCompare:@"aabbcc"] == NSOrderedSame, @"Hex strings do not match color generated!");
}

- (void)testInvalidShorthand {
    NSString *shortHandHexColor = @"ab";
    UIColor *color = [UIColor colorFromHexValue:shortHandHexColor];
    XCTAssertNil(color, @"Color must be nil for invalid hex representation!");
}

- (void)testInvalidShorthandWithPoundPrefix {
    NSString *shortHandHexColor = @"#ab";
    UIColor *color = [UIColor colorFromHexValue:shortHandHexColor];
    XCTAssertNil(color, @"Color must be nil for invalid hex representation!");
}

- (void)testEmptyHexString {
    NSString *shortHandHexColor = @"";
    UIColor *color = [UIColor colorFromHexValue:shortHandHexColor];
    XCTAssertNil(color, @"Color must be nil for empty hex representation!");
}

- (void)testNilHexString {
    NSString *shortHandHexColor = nil;
    UIColor *color = [UIColor colorFromHexValue:shortHandHexColor];
    XCTAssertNil(color, @"Color must be nil for nil hex representation!");
}


@end
