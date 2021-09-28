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

@interface ScreenLockManagerTests : XCTestCase

@end

@implementation ScreenLockManagerTests

- (void)setUp {
    [SFSDKKeychainHelper removeAll];
}

- (void)testShouldNotLock {
    XCTAssertFalse([[SFScreenLockManager shared] readMobilePolicy], @"App should not lock by default.");
}

- (void)testShouldLock {
    SFUserAccount *user0 = [self createNewUserAccount:0];
    [[SFScreenLockManager shared] storeMobilePolicyWithUserAccount:user0 hasMobilePolicy:YES];
    XCTAssertTrue([[SFScreenLockManager shared] readMobilePolicy], @"App should lock.");
}

- (void)testShouldLockMultiuser {
    SFUserAccount *user0 = [self createNewUserAccount:0];
    [[SFScreenLockManager shared] storeMobilePolicyWithUserAccount:user0 hasMobilePolicy:YES];
    SFUserAccount *user1 = [self createNewUserAccount:1];
    [[SFScreenLockManager shared] storeMobilePolicyWithUserAccount:user1 hasMobilePolicy:NO];
    XCTAssertTrue([[SFScreenLockManager shared] readMobilePolicy], @"App should lock.");
}

- (void)testLogoutScreenLockUsers {
    SFUserAccount *user0 = [self createNewUserAccount:0];
    [[SFScreenLockManager shared] storeMobilePolicyWithUserAccount:user0 hasMobilePolicy:YES];
    SFUserAccount *user1 = [self createNewUserAccount:1];
    [[SFScreenLockManager shared] storeMobilePolicyWithUserAccount:user1 hasMobilePolicy:NO];
    SFUserAccount *user2 = [self createNewUserAccount:2];
    [[SFScreenLockManager shared] storeMobilePolicyWithUserAccount:user2 hasMobilePolicy:YES];
    XCTAssertTrue([[SFScreenLockManager shared] readMobilePolicy], @"App should lock.");
    
    [[SFScreenLockManager shared] logoutScreenLockUsers];
    XCTAssertFalse([[SFScreenLockManager shared] readMobilePolicy], @"App not should lock.");
    // Can't test the users are actually logged out because it is a test.
}


-(SFUserAccount *)createNewUserAccount:(NSInteger) index {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc]initWithIdentifier:[NSString stringWithFormat:@"identifier-%lu", (unsigned long)index] clientId:@"fakeClientIdForTesting" encrypted:YES];
    SFUserAccount *user = [[SFUserAccount alloc] initWithCredentials:credentials];
    return user;
}

@end
