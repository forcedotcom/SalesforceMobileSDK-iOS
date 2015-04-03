//
//  CSFChatterUserSummaryResponseTest.h
//  ChatterSDK
//
//  Created automatically by Michael Nachbaur on 09/05/13.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "CSFChatterUserSummaryOutput.h"

@interface CSFChatterUserSummaryResponseTest : XCTestCase

@end

@implementation CSFChatterUserSummaryResponseTest

- (void)testInitializer {
    NSString *fn = [[NSBundle bundleForClass:self.class] pathForResource:@"UserSummary" ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:fn]; 
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

    CSFChatterUserSummaryOutput *model = [[CSFChatterUserSummaryOutput alloc] initWithJSON:json context:nil];
    XCTAssertNotNil(model, @"Output object should not be nil");

    CSFChatterUserSummaryOutput *model2 = [[CSFChatterUserSummaryOutput alloc] initWithJSON:json context:nil];
    XCTAssertEqualObjects(model, model2, @"Output objects should be equal");
    XCTAssertTrue([model isEqual:model2], @"Output objects should pass isEqual");
    XCTAssertTrue([model isEqualToOutput:model2], @"Output objects should pass isEqualToOutput");
}

@end
