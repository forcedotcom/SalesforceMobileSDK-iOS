//
//  SDKCommonNSDataTests.m
//  SalesforceSDKCommon
//
//  Created by Kevin Hawkins on 12/8/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
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

@end
