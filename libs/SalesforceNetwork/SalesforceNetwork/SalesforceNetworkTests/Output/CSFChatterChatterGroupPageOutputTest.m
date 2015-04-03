//
//  CHConnectChatterGroupPageResponseTest.h
//  ChatterSDK
//
//  Created automatically by Michael Nachbaur on 09/05/13.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "CSFChatterChatterGroupPageOutput.h"

@interface CSFChatterChatterGroupPageOutputTest : XCTestCase

@end

@implementation CSFChatterChatterGroupPageOutputTest

- (void)testInitializer {
    NSString *fn = [[NSBundle bundleForClass:self.class] pathForResource:@"ChatterGroupPage" ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:fn]; 
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

    CSFChatterChatterGroupPageOutput *model = [[CSFChatterChatterGroupPageOutput alloc] initWithJSON:json context:nil];
    XCTAssertNotNil(model, @"Response object should not be nil");

    CSFChatterChatterGroupPageOutput *model2 = [[CSFChatterChatterGroupPageOutput alloc] initWithJSON:json context:nil];
    XCTAssertEqual(model.hash, model2.hash);
    XCTAssertEqualObjects(model, model2, @"Response objects should be equal");
    XCTAssertTrue([model isEqual:model2], @"Response objects should pass isEqual");
    XCTAssertTrue([model isEqualToOutput:model2], @"Response objects should pass isEqualToResponse");
}

@end
