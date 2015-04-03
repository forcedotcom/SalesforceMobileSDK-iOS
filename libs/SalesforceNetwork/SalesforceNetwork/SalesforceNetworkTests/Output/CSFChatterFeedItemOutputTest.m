//
//  CSFChatterFeedItemResponseTest.h
//  ChatterSDK
//
//  Created automatically by Michael Nachbaur on 06/22/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "CSFChatterFeedItemOutput.h"

@interface CSFChatterFeedItemResponseTest : XCTestCase

@end

@implementation CSFChatterFeedItemResponseTest

- (void)testInitializer {
    NSString *fn = [[NSBundle bundleForClass:self.class] pathForResource:@"FeedItem" ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:fn]; 
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

    CSFChatterFeedItemOutput *model = [[CSFChatterFeedItemOutput alloc] initWithJSON:json context:nil];
    XCTAssertNotNil(model, @"Output object should not be nil");

    CSFChatterFeedItemOutput *model2 = [[CSFChatterFeedItemOutput alloc] initWithJSON:json context:nil];
    XCTAssertEqualObjects(model, model2, @"Output objects should be equal");
    XCTAssertTrue([model isEqual:model2], @"Output objects should pass isEqual");
    XCTAssertTrue([model isEqualToOutput:model2], @"Output objects should pass isEqualToOutput");
}

@end
