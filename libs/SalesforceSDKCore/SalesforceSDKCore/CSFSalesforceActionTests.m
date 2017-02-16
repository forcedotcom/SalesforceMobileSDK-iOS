//
//  CSFSalesforceActionTests.m
//  SalesforceSDKCore
//
//  Created by Jonathan Arbogast on 2/16/17.
//  Copyright © 2017 salesforce.com. All rights reserved.
//

@import XCTest;
#import <OCMock/OCMock.h>

#import "CSFSalesforceAction.h"
#import "CSFAction+Internal.h"
#import "CSFNetwork.h"
#import "SFUserAccount.h"
#import "SFOAuthCredentials.h"

@interface CSFSalesforceActionTests : XCTestCase

@property (strong, nonatomic) CSFSalesforceAction *action;

@end

@implementation CSFSalesforceActionTests

- (void)setUp {
    [super setUp];
    self.action = [[CSFSalesforceAction alloc] initWithResponseBlock:^(CSFAction *action, NSError *error) {
        
    }];
}

- (void)testBaseUrlNilByDefault {
    XCTAssertNil(self.action.baseURL);
}

- (void)testAppendTrailingSlashForBaseURL {
    self.action.baseURL = [NSURL URLWithString:@"https://www.salesforce.com"];
    XCTAssertEqualObjects(self.action.baseURL, [NSURL URLWithString:@"https://www.salesforce.com/"]);
}

- (void)testSetBaseURLThenEnqueueOntoNetwork {
    NSURL *networkURL = [NSURL URLWithString:@"https://www.salesforce.com/"];
    NSURL *baseURL = [NSURL URLWithString:@"http://www.example.com/"];
    
    self.action.baseURL = baseURL;
    self.action.enqueuedNetwork = [self networkWithApiURL:networkURL];
    
    XCTAssertEqualObjects(self.action.baseURL, baseURL);
}

- (void)testEnqueueOntoNetworkThenSetBaseURL {
    NSURL *networkURL = [NSURL URLWithString:@"https://www.salesforce.com/"];
    NSURL *baseURL = [NSURL URLWithString:@"http://www.example.com/"];

    self.action.enqueuedNetwork = [self networkWithApiURL:networkURL];
    self.action.baseURL = baseURL;
    
    XCTAssertEqualObjects(self.action.baseURL, baseURL);
}

- (void)testEnqueueOntoNetwork {
    NSURL *networkURL = [NSURL URLWithString:@"https://www.salesforce.com/"];
    
    self.action.enqueuedNetwork = [self networkWithApiURL:networkURL];
    
    XCTAssertEqualObjects(self.action.baseURL, networkURL);
}

- (id)networkWithApiURL:(NSURL *)url {
    id credentials = OCMClassMock([SFOAuthCredentials class]);
    OCMStub([credentials apiUrl]).andReturn(url);
    
    id account = OCMClassMock([SFUserAccount class]);
    OCMStub([account credentials]).andReturn(credentials);
    
    id network = OCMClassMock([CSFNetwork class]);
    OCMStub([network account]).andReturn(account);
    
    return network;
}

@end
