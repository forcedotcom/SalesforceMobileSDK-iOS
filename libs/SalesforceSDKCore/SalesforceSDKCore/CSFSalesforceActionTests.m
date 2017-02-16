//
//  CSFSalesforceActionTests.m
//  SalesforceSDKCore
//
//  Created by Jonathan Arbogast on 2/16/17.
//  Copyright © 2017 salesforce.com. All rights reserved.
//

@import XCTest;
#import "CSFSalesforceAction_Internal.h"

@interface CSFSalesforceActionTests : XCTestCase

@property (strong, nonatomic) CSFSalesforceAction *action;

@end

@implementation CSFSalesforceActionTests

- (void)setUp {
    [super setUp];
    self.action = [[CSFSalesforceAction alloc] initWithResponseBlock:^(CSFAction *action, NSError *error) {
        
    }];
}

- (void)testShouldUpdateNilBaseURL {
    XCTAssertTrue([self.action shouldUpdateBaseUrl]);
}

- (void)testShouldNotUpdateManuallySetBaseURL {
    self.action.baseURL = [NSURL URLWithString:@"https://www.salesforce.com"];
    XCTAssertFalse([self.action shouldUpdateBaseUrl]);
}

- (void)testShouldUpdateAutomaticallySetBaseURL {
    self.action.baseURL = [NSURL URLWithString:@"https://www.salesforce.com/"];
    self.action.cachedAPIURL = [NSURL URLWithString:@"https://www.salesforce.com/"];
    
    XCTAssertTrue([self.action shouldUpdateBaseUrl]);
}

@end
