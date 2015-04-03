//
//  CSFChatterFeedItemPageOutputTest.h
//  CoreSalesforce
//
//  Created automatically by Michael Nachbaur on 12/12/14.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "CSFChatterFeedItemPageOutput.h"
#import "CSFOutput_Internal.h"

@interface CSFChatterFeedItemPageOutputTest : XCTestCase

@end

@implementation CSFChatterFeedItemPageOutputTest

- (void)testInitializer {
    NSString *fn = [[NSBundle bundleForClass:self.class] pathForResource:@"CSFChatterFeedItemPageOutput" ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:fn]; 
    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];

    XCTAssertNil(error);

    CSFChatterFeedItemPageOutput *model = [[CSFChatterFeedItemPageOutput alloc] initWithJSON:json context:nil];
    XCTAssertNotNil(model, @"Output object should not be nil");

    CSFChatterFeedItemPageOutput *model2 = [[CSFChatterFeedItemPageOutput alloc] initWithJSON:json context:nil];
    XCTAssertEqualObjects(model, model2, @"Output objects should be equal");
    XCTAssertTrue([model isEqual:model2], @"Output objects should pass isEqual");
    XCTAssertTrue([model isEqualToOutput:model2], @"Output objects should pass isEqualToOutput");
}

// TODO: Performance measurements aren't standard
- (void)testSimpleImportMeasurement {
    NSString *fn = [[NSBundle bundleForClass:self.class] pathForResource:@"CSFChatterFeedItemPageOutput" ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:fn];
    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    
    XCTAssertNil(error);
    
    [self measureBlock:^{
        CSFChatterFeedItemPageOutput *model = [[CSFChatterFeedItemPageOutput alloc] initWithJSON:json context:nil];
        #pragma unused(model)
    }];
}

- (void)testFullImportMeasurement {
    NSString *fn = [[NSBundle bundleForClass:self.class] pathForResource:@"CSFChatterFeedItemPageOutput" ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:fn];
    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    
    XCTAssertNil(error);
    
    [self measureBlock:^{
        CSFChatterFeedItemPageOutput *model = [[CSFChatterFeedItemPageOutput alloc] initWithJSON:json context:nil];
        [model importAllProperties];
    }];
}

@end
