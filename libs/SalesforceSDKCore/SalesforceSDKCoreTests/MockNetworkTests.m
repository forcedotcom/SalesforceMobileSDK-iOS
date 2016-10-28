/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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
#import "TestDataAction.h"

#import "CSFNetwork+Internal.h"
#import "CSFSalesforceAction.h"

@interface MockAction : CSFAction

@property (nonatomic, strong) NSString *actionName;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;

- (instancetype) initWithName:(NSString*)actionName;
@end

@implementation MockAction

- (instancetype) initWithName:(NSString*)actionName {
    self = [super initWithResponseBlock:^(CSFAction *action, NSError *error){}];
    if (self) {
        self.actionName = actionName;
        self.semaphore = dispatch_semaphore_create(0);
    }
    return self;
}

- (void) completeAction {
    dispatch_semaphore_signal(self.semaphore);
}

- (NSURLRequest*)createURLRequest:(NSError**)error {
    NSURL* url = [NSURL URLWithString:@"https://cs1.salesforce.com/services/data"];
    return [NSMutableURLRequest requestWithURL:url];
}

- (void)completeOperationWithError:(NSError *)error {
    long result = dispatch_semaphore_wait(self.semaphore, dispatch_time(DISPATCH_TIME_NOW, 15LL * NSEC_PER_SEC)); // at most 15s
    if (result != 0 && error == nil) {
        error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                    code:CSFNetworkInternalError
                                userInfo:@{ NSLocalizedDescriptionKey: @"Semaphore wait timed out",
                                            CSFNetworkErrorActionKey: self }];
    }
    [super completeOperationWithError:error];
}

- (BOOL)isEqualToAction:(CSFAction *)action {
    return [action isKindOfClass:[MockAction class]] && [self.actionName isEqualToString:((MockAction*)action).actionName];
}

@end

@interface MockNetworkTests : XCTestCase

@end

@implementation MockNetworkTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testNetworkBasics {
    SFUserAccount *user = [TestDataAction testUserAccount];
    
    CSFNetwork *network = [[CSFNetwork alloc] initWithUserAccount:user];
    XCTAssertNotNil(network);
    XCTAssertFalse(network.refreshingAccessToken);
    XCTAssertNil(network.defaultConnectCommunityId);
    XCTAssertFalse(network.networkSuspended);
    [network setNetworkSuspended:YES];
    
    CSFSalesforceAction *action1 = [[CSFSalesforceAction alloc] initWithResponseBlock:^(CSFAction *action, NSError *error){}];
    CSFSalesforceAction *action2 = [[CSFSalesforceAction alloc] initWithResponseBlock:^(CSFAction *action, NSError *error){}];
    
    // Setting verbs and methods (values do not matter - but can't be nil otherwise it confuses duplicateActionInFlight/isEqualToAction
    action1.method = action2.method = @"GET";
    action1.verb = action2.verb = @"/xyz";
    
    [network executeAction:action1];
    [NSThread sleepForTimeInterval:1];
    XCTAssertEqual(network.actionCount, 1);
    
    [network executeAction:action2];
    [NSThread sleepForTimeInterval:1];
    XCTAssertEqual(network.actionCount, 2);
    
    CSFAction *duplicateAction = [network duplicateActionInFlight:action2];
    [NSThread sleepForTimeInterval:1];
    XCTAssertEqual(duplicateAction, action2);
    XCTAssertTrue([action2.dependencies containsObject:action1]);
}

- (void)dont_testNetworkContexts {
    SFUserAccount *user = [TestDataAction testUserAccount];

    CSFNetwork *network = [[CSFNetwork alloc] initWithUserAccount:user];
    XCTAssertNotNil(network);
    XCTAssertFalse(network.refreshingAccessToken);
    XCTAssertNil(network.defaultConnectCommunityId);
    XCTAssertFalse(network.networkSuspended);

    CSFAction *action1 = [[TestDataAction alloc] initWithResponseBlock:nil testString:@"{}"];
    CSFAction *action2 = [[TestDataAction alloc] initWithResponseBlock:nil testString:@"{}"];
    CSFAction *action3 = [[TestDataAction alloc] initWithResponseBlock:nil testString:@"{}"];
    CSFAction *action4 = [[TestDataAction alloc] initWithResponseBlock:nil testString:@"{}"];
    CSFAction *action5 = [[TestDataAction alloc] initWithResponseBlock:nil testString:@"{}"];
    
    NSObject *context1 = [[NSObject alloc] init];
    action1.context = context1;
    action2.context = context1;
    
    NSObject *context2 = [[NSObject alloc] init];
    action3.context = context2;
    action4.context = context2;

    [network executeAction:action1];
    XCTAssertEqual(network.actionCount, 1);
    
    [network executeAction:action2];
    XCTAssertEqual(network.actionCount, 2);
    
    [network executeAction:action3];
    XCTAssertEqual(network.actionCount, 3);
    
    [network executeAction:action4];
    XCTAssertEqual(network.actionCount, 4);
    
    [network executeAction:action5];
    XCTAssertEqual(network.actionCount, 5);
    
    NSArray *actions = [network actionsWithContext:context1];
    NSArray *compareObjects = @[ action1, action2 ];
    XCTAssertEqualObjects(actions, compareObjects);
    
    actions = [network actionsWithContext:context2];
    compareObjects = @[ action3, action4 ];
    XCTAssertEqualObjects(actions, compareObjects);
    
    actions = [network actionsWithContext:nil];
    compareObjects = @[ action5 ];
    XCTAssertEqualObjects(actions, compareObjects);
    
    [network cancelAllActionsWithContext:context1];
    XCTAssertTrue(action1.cancelled);
    XCTAssertTrue(action2.cancelled);
    XCTAssertFalse(action3.cancelled);
    XCTAssertFalse(action4.cancelled);
    XCTAssertFalse(action5.cancelled);
}

// Test that the cached CSFNetwork is removed on logout
- (void) testLogout {
    SFUserAccount *user = [TestDataAction testUserAccount];
    XCTAssertNotNil([CSFNetwork networkForUserAccount:user]);
    XCTAssertNotNil([CSFNetwork cachedNetworkForUserAccount:user]);
    [[SFAuthenticationManager sharedManager] logoutUser:user];
    XCTAssertNil([CSFNetwork cachedNetworkForUserAccount:user]);
}

// Test that dependent actions run after parent completes
- (void)skip_testDependentActions {
    SFUserAccount *user = [TestDataAction testUserAccount];
    CSFNetwork *network = [[CSFNetwork alloc] initWithUserAccount:user];
    
    MockAction *action1 = [[MockAction alloc] initWithName:@"action"];
    MockAction *action2 = [[MockAction alloc] initWithName:@"action"];

    [network executeAction:action1];
    [network executeAction:action2];

    // Expect two actions in queue, second one depending on first one
    XCTAssertEqual(network.actionCount, 2);
    XCTAssertTrue([action2.dependencies containsObject:action1]);

    // Expect only first action running
    XCTAssertTrue(action1.isExecuting);
    XCTAssertFalse(action2.isExecuting);

    // Finishing first one
    [action1 completeAction];
    [action1 waitUntilFinished];

    // Expect only second action running
    XCTAssertFalse(action1.isExecuting);
    XCTAssertTrue(action2.isExecuting);

    // Finishing second one
    [action2 completeAction];
    [action2 waitUntilFinished];

    // Expect no actions running
    XCTAssertFalse(action1.isExecuting);
    XCTAssertFalse(action2.isExecuting);
}


@end
