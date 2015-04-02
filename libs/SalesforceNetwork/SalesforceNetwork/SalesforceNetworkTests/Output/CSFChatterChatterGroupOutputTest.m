//
//  CSFChatterChatterGroupResponseTest.h
//  ChatterSDK
//
//  Created automatically by Michael Nachbaur on 09/05/13.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "CSFChatterChatterGroupOutput.h"

@interface CSFChatterChatterGroupResponseTest : XCTestCase

@end

@implementation CSFChatterChatterGroupResponseTest

- (void)testInitializer {
    NSString *fn = [[NSBundle bundleForClass:self.class] pathForResource:@"ChatterGroup" ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:fn]; 
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

    CSFChatterChatterGroupOutput *model = [[CSFChatterChatterGroupOutput alloc] initWithJSON:json context:nil];
    XCTAssertNotNil(model, @"Output object should not be nil");

    CSFChatterChatterGroupOutput *model2 = [[CSFChatterChatterGroupOutput alloc] initWithJSON:json context:nil];
    XCTAssertEqualObjects(model, model2, @"Output objects should be equal");
    XCTAssertTrue([model isEqual:model2], @"Output objects should pass isEqual");
    XCTAssertTrue([model isEqualToOutput:model2], @"Output objects should pass isEqualToOutput");

    XCTAssertEqualObjects(model.name, @"a public group");
    XCTAssertEqual(model.visibility, CSFChatterGroupVisibilityPublicAccess);
    XCTAssertEqual(model.myRole, CSFChatterGroupMembershipTypeNotAMember);
    XCTAssertEqual(model.memberCount, 6);
    XCTAssertFalse(model.haveChatterGuests);
    XCTAssertNil(model.descriptionText);
}

@end
