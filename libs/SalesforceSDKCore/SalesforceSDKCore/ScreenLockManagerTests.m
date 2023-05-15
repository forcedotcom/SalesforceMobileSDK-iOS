//
//  ScreenLockManagerTests.m
//  SalesforceSDKCore
//
//  Created by Brandon Page on 9/24/21.
//  Copyright (c) 2021-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import <XCTest/XCTest.h>
#import <SalesforceSDKCore/SalesforceSDKCore-Swift.h>
#import <SalesforceSDKCommon/SalesforceSDKCommon-Swift.h>
#import "SFUserAccountManager+Internal.h"
#import "SFUserAccount+Internal.h"
#import "SFSDKWindowManager.h"

@interface ScreenLockManagerTests : XCTestCase

@end

@implementation ScreenLockManagerTests

- (void)setUp {
    BOOL removed = [SFSDKKeychainHelper removeAll];
}

- (void)testShouldNotLock {
    XCTAssertNil([[SFScreenLockManagerInternal shared] getTimeout], @"App should not lock by default.");
}

- (void)testShouldLock {
    SFUserAccount *user0 = [self createNewUserAccount:0];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user0 hasMobilePolicy:YES lockTimeout:15];
    XCTAssertEqualObjects([[SFScreenLockManagerInternal shared] getTimeout], [[NSNumber alloc] initWithInt:15], @"App should lock.");
}

- (void)testShouldLockMultiuser {
    SFUserAccount *user0 = [self createNewUserAccount:0];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user0 hasMobilePolicy:YES lockTimeout:1];
    SFUserAccount *user1 = [self createNewUserAccount:1];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user1 hasMobilePolicy:NO lockTimeout:0];
    XCTAssertEqualObjects([[SFScreenLockManagerInternal shared] getTimeout], [[NSNumber alloc] initWithInt:1], @"App should lock.");
}

- (void)testShouldLockMultiuserDifferentTimeouts {
    SFUserAccount *user0 = [self createNewUserAccount:0];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user0 hasMobilePolicy:YES lockTimeout:1];
    SFUserAccount *user1 = [self createNewUserAccount:1];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user1 hasMobilePolicy:YES lockTimeout:5];
    SFUserAccount *user2 = [self createNewUserAccount:2];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user2 hasMobilePolicy:YES lockTimeout:15];
    XCTAssertEqualObjects([[SFScreenLockManagerInternal shared] getTimeout], [[NSNumber alloc] initWithInt:1], @"App should lock with most restrictive timeout");
}

- (void)testShouldLockMultiuserDifferentTimeoutsReverseOrder {
    SFUserAccount *user0 = [self createNewUserAccount:0];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user0 hasMobilePolicy:YES lockTimeout:15];
    SFUserAccount *user1 = [self createNewUserAccount:1];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user1 hasMobilePolicy:YES lockTimeout:5];
    SFUserAccount *user2 = [self createNewUserAccount:2];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user2 hasMobilePolicy:YES lockTimeout:1];
    XCTAssertEqualObjects([[SFScreenLockManagerInternal shared] getTimeout], [[NSNumber alloc] initWithInt:1], @"App should lock with most restrictive timeout");
}

- (void)testLockScreenTriggers {
    // Login with first user with a mobile policy -- should trigger lock screen
    SFUserAccount *user0 = [self createNewUserAccount:0];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user0 hasMobilePolicy:YES lockTimeout:15];
    XCTAssertTrue([[[SFSDKWindowManager sharedManager] screenLockWindow] isEnabled]);
    
    // Backgrounding/foregrounding on lock -- lock screen should remain & callback shouldn't be called
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Callback"];
    expectation.inverted = YES;
    [[SFScreenLockManagerInternal shared] setCallbackBlockWithScreenLockCallbackBlock:^{
        [expectation fulfill];
    }];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    [[SFScreenLockManagerInternal shared] handleAppForeground];
    XCTAssertTrue([[[SFSDKWindowManager sharedManager] screenLockWindow] isEnabled]);
    [self waitForExpectations:@[expectation] timeout:1];
    
    // Unlock
    [[[SFSDKWindowManager sharedManager] screenLockWindow] dismissWindow];
    XCTAssertFalse([[[SFSDKWindowManager sharedManager] screenLockWindow] isEnabled]);
    
    // Login with another user with a longer timeout -- should trigger lock screen
    SFUserAccount *user1 = [self createNewUserAccount:1];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user1 hasMobilePolicy:YES lockTimeout:20];
    XCTAssertTrue([[[SFSDKWindowManager sharedManager] screenLockWindow] isEnabled]);
    [[[SFSDKWindowManager sharedManager] screenLockWindow] dismissWindow];
    XCTAssertFalse([[[SFSDKWindowManager sharedManager] screenLockWindow] isEnabled]);
    
    // After backgrounding, adding a new user with a mobile policy should still trigger lock screen
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    SFUserAccount *user2 = [self createNewUserAccount:2];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user2 hasMobilePolicy:YES lockTimeout:5];
    XCTAssertTrue([[[SFSDKWindowManager sharedManager] screenLockWindow] isEnabled]);
    [[[SFSDKWindowManager sharedManager] screenLockWindow] dismissWindow];
    XCTAssertFalse([[[SFSDKWindowManager sharedManager] screenLockWindow] isEnabled]);
    
    // Since the timeout hasn't expired, adding a new user without a mobile policy shouldn't trigger the lock screen
    SFUserAccount *user3 = [self createNewUserAccount:3];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user3 hasMobilePolicy:NO lockTimeout:5];
    XCTAssertFalse([[[SFSDKWindowManager sharedManager] screenLockWindow] isEnabled]);
    
    // Since the timeout hasn't expired, backgrounding and adding a new user without a mobile policy shouldn't trigger the lock screen
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    SFUserAccount *user4 = [self createNewUserAccount:4];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user4 hasMobilePolicy:NO lockTimeout:5];
    [[SFScreenLockManagerInternal shared] handleAppForeground];
    XCTAssertFalse([[[SFSDKWindowManager sharedManager] screenLockWindow] isEnabled]);
}

- (void)testLogoutScreenLockUsers {
    SFUserAccount *user0 = [self createNewUserAccount:0];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user0 hasMobilePolicy:YES lockTimeout:15];
    SFUserAccount *user1 = [self createNewUserAccount:1];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user1 hasMobilePolicy:NO lockTimeout:0];
    SFUserAccount *user2 = [self createNewUserAccount:2];
    [[SFScreenLockManagerInternal shared] storeMobilePolicyWithUserAccount:user2 hasMobilePolicy:YES lockTimeout:5];
    XCTAssertEqualObjects([[SFScreenLockManagerInternal shared] getTimeout], [[NSNumber alloc] initWithInt:5], @"App should lock.");
    
    [[SFScreenLockManagerInternal shared] logoutScreenLockUsers];
    XCTAssertNil([[SFScreenLockManagerInternal shared] getTimeout], @"App not should lock.");
    // Can't test the users are actually logged out because it is a test.
}

-(SFUserAccount *)createNewUserAccount:(NSInteger) index {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc]initWithIdentifier:[NSString stringWithFormat:@"identifier-%lu", (unsigned long)index] clientId:@"fakeClientIdForTesting" encrypted:YES];
    NSDictionary *idDataDict = @{ @"user_id" : [NSString stringWithFormat: @"%ld", (long)index] };
    SFIdentityData *idData = [[SFIdentityData alloc] initWithJsonDict:idDataDict];
    SFUserAccount *user = [[SFUserAccount alloc] initWithCredentials:credentials];
    [user setIdData:idData];
    
    return user;
}

@end
