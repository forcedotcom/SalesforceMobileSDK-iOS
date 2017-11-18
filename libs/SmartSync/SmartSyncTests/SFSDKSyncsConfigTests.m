/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKSyncsConfigTests.h"
#import "SmartSyncSDKManager.h"
#import "SFSoqlSyncDownTarget.h"
#import <XCTest/XCTest.h>

@interface SFSDKSyncsConfigTests ()

@property (nonatomic, strong) SmartSyncSDKManager* sdkManager;

@end

@implementation SFSDKSyncsConfigTests

#pragma mark - setup and teardown

- (void) setUp
{
    [super setUp];
    [SFSDKSmartSyncLogger setLogLevel:DDLogLevelDebug];
    self.sdkManager = [[SmartSyncSDKManager alloc] init];
}

- (void) tearDown
{
    [super tearDown];
    self.sdkManager = nil;
}

- (void) testSetupGlobalSyncsFromDefaultConfig  {
    XCTAssertFalse([self.globalSyncManager hasSyncWithName:@"globalSync1"]);
    XCTAssertFalse([self.globalSyncManager hasSyncWithName:@"globalSync2"]);

    // Setting up syncs
    [self.sdkManager setupGlobalSyncsFromDefaultConfig];

    // Checking smartstore
    XCTAssertTrue([self.globalSyncManager hasSyncWithName:@"globalSync1"]);
    XCTAssertTrue([self.globalSyncManager hasSyncWithName:@"globalSync2"]);

    // Checking first sync in details
    SFSyncState* actualSync1 = [self.globalSyncManager getSyncStatusByName:@"globalSync1"];
    XCTAssertEqualObjects(actualSync1.soupName, @"accounts");
    [self checkStatus:actualSync1
         expectedType:SFSyncStateSyncTypeDown
           expectedId:actualSync1.syncId
         expectedName:@"globalSync1"
       expectedTarget:[SFSoqlSyncDownTarget
               newSyncTarget:@"SELECT Id, Name, LastModifiedDate FROM Account"]
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeOverwrite]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];

    // Checking second sync in details
    SFSyncState* actualSync2 = [self.globalSyncManager getSyncStatusByName:@"globalSync2"];
    XCTAssertEqualObjects(actualSync2.soupName, @"accounts");
    [self checkStatus:actualSync2
         expectedType:SFSyncStateSyncTypeUp
           expectedId:actualSync2.syncId
         expectedName:@"globalSync2"
       expectedTarget:[[SFSyncUpTarget alloc] initWithCreateFieldlist:@[@"Name"] updateFieldlist:nil]
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncUp:@[@"Id", @"Name", @"LastModifiedDate"] mergeMode:SFSyncStateMergeModeLeaveIfChanged]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];
}

- (void) testSetupUserSyncsFromDefaulltConfig {
    XCTAssertFalse([self.syncManager hasSyncWithName:@"userSync1"]);
    XCTAssertFalse([self.syncManager hasSyncWithName:@"userSync2"]);

    // Setting up syncs
    [self.sdkManager setupUserSyncsFromDefaultConfig];

    // Checking smartstore
    XCTAssertTrue([self.syncManager hasSyncWithName:@"userSync1"]);
    XCTAssertTrue([self.syncManager hasSyncWithName:@"userSync2"]);

    // Checking first sync in details
    SFSyncState* actualSync1 = [self.syncManager getSyncStatusByName:@"userSync1"];
    XCTAssertEqualObjects(actualSync1.soupName, @"accounts");
    [self checkStatus:actualSync1
         expectedType:SFSyncStateSyncTypeDown
           expectedId:actualSync1.syncId
         expectedName:@"userSync1"
       expectedTarget:[SFSoqlSyncDownTarget
               newSyncTarget:@"SELECT Id, Name, LastModifiedDate FROM Account"]
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeOverwrite]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];

    // Checking second sync in details
    SFSyncState* actualSync2 = [self.syncManager getSyncStatusByName:@"userSync2"];
    XCTAssertEqualObjects(actualSync2.soupName, @"accounts");
    [self checkStatus:actualSync2
         expectedType:SFSyncStateSyncTypeUp
           expectedId:actualSync2.syncId
         expectedName:@"userSync2"
       expectedTarget:[[SFSyncUpTarget alloc] initWithCreateFieldlist:@[@"Name"] updateFieldlist:nil]
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncUp:@[@"Id", @"Name", @"LastModifiedDate"] mergeMode:SFSyncStateMergeModeLeaveIfChanged]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];
}

@end
