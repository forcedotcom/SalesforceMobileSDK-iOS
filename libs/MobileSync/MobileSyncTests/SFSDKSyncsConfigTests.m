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

#import <XCTest/XCTest.h>
#import "SyncManagerTestCase.h"
#import "MobileSyncSDKManager.h"
#import "SFSoqlSyncDownTarget.h"

@interface SFSDKSyncsConfigTests : SyncManagerTestCase

@end

@interface SFSDKSyncsConfigTests ()

@property (nonatomic, strong) MobileSyncSDKManager* sdkManager;

@end

@implementation SFSDKSyncsConfigTests

#pragma mark - setup and teardown

- (void) setUp
{
    [super setUp];
    [SFSDKMobileSyncLogger setLogLevel:SFLogLevelDebug];
    self.sdkManager = [[MobileSyncSDKManager alloc] init];
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
       expectedTarget:[[SFBatchSyncUpTarget alloc] initWithCreateFieldlist:@[@"Name"] updateFieldlist:nil]
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncUp:@[@"Id", @"Name", @"LastModifiedDate"] mergeMode:SFSyncStateMergeModeLeaveIfChanged]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];
}

- (void) testSetupUserSyncsFromDefaultConfig {
    XCTAssertFalse([self.syncManager hasSyncWithName:@"soqlSyncDown"]);
    XCTAssertFalse([self.syncManager hasSyncWithName:@"soslSyncDown"]);
    XCTAssertFalse([self.syncManager hasSyncWithName:@"mruSyncDown"]);
    XCTAssertFalse([self.syncManager hasSyncWithName:@"refreshSyncDown"]);
    XCTAssertFalse([self.syncManager hasSyncWithName:@"layoutSyncDown"]);
    XCTAssertFalse([self.syncManager hasSyncWithName:@"metadataSyncDown"]);
    XCTAssertFalse([self.syncManager hasSyncWithName:@"parentChildrenSyncDown"]);
    XCTAssertFalse([self.syncManager hasSyncWithName:@"noBatchSyncUp"]);
    XCTAssertFalse([self.syncManager hasSyncWithName:@"batchSyncUp"]);
    XCTAssertFalse([self.syncManager hasSyncWithName:@"parentChildrenSyncUp"]);
    
    // Setting up syncs
    [self.sdkManager setupUserSyncsFromDefaultConfig];
    
    // Checking smartstore
    XCTAssertTrue([self.syncManager hasSyncWithName:@"soqlSyncDown"]);
    XCTAssertTrue([self.syncManager hasSyncWithName:@"soslSyncDown"]);
    XCTAssertTrue([self.syncManager hasSyncWithName:@"mruSyncDown"]);
    XCTAssertTrue([self.syncManager hasSyncWithName:@"refreshSyncDown"]);
    XCTAssertTrue([self.syncManager hasSyncWithName:@"layoutSyncDown"]);
    XCTAssertTrue([self.syncManager hasSyncWithName:@"metadataSyncDown"]);
    XCTAssertTrue([self.syncManager hasSyncWithName:@"parentChildrenSyncDown"]);
    XCTAssertTrue([self.syncManager hasSyncWithName:@"noBatchSyncUp"]);
    XCTAssertTrue([self.syncManager hasSyncWithName:@"batchSyncUp"]);
    XCTAssertTrue([self.syncManager hasSyncWithName:@"parentChildrenSyncUp"]);
}

- (void) testSoqlSyncDownFromConfig {
    [self.sdkManager setupUserSyncsFromDefaultConfig];
    
    SFSyncState* sync = [self.syncManager getSyncStatusByName:@"soqlSyncDown"];
    XCTAssertEqualObjects(sync.soupName, @"accounts");
    [self checkStatus:sync
         expectedType:SFSyncStateSyncTypeDown
           expectedId:sync.syncId
         expectedName:@"soqlSyncDown"
       expectedTarget:[SFSoqlSyncDownTarget
                       newSyncTarget:@"SELECT Id, Name, LastModifiedDate FROM Account"]
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeOverwrite]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];
}

- (void) testSoqlSyncDownWithBatchSizeFromConfig {
    [self.sdkManager setupUserSyncsFromDefaultConfig];
    
    SFSyncState* sync = [self.syncManager getSyncStatusByName:@"soqlSyncDownWithBatchSize"];
    XCTAssertEqualObjects(sync.soupName, @"accounts");
    [self checkStatus:sync
         expectedType:SFSyncStateSyncTypeDown
           expectedId:sync.syncId
         expectedName:@"soqlSyncDown"
       expectedTarget:[SFSoqlSyncDownTarget
                       newSyncTarget:@"SELECT Id, Name, LastModifiedDate FROM Account" maxBatchSize:200]
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeOverwrite]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];
}

- (void) testSoslSyncDownFromConfig {
    [self.sdkManager setupUserSyncsFromDefaultConfig];
    
    SFSyncState* sync = [self.syncManager getSyncStatusByName:@"soslSyncDown"];
    XCTAssertEqualObjects(sync.soupName, @"accounts");
    [self checkStatus:sync
         expectedType:SFSyncStateSyncTypeDown
           expectedId:sync.syncId
         expectedName:@"soslSyncDown"
       expectedTarget:[SFSoslSyncDownTarget
                       newSyncTarget:@"FIND {Joe} IN NAME FIELDS RETURNING Account"]
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeLeaveIfChanged]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];
}

- (void) testMruSyncDownFromConfig {
    [self.sdkManager setupUserSyncsFromDefaultConfig];
    
    SFSyncState* sync = [self.syncManager getSyncStatusByName:@"mruSyncDown"];
    XCTAssertEqualObjects(sync.soupName, @"accounts");
    [self checkStatus:sync
         expectedType:SFSyncStateSyncTypeDown
           expectedId:sync.syncId
         expectedName:@"mruSyncDown"
       expectedTarget:[SFMruSyncDownTarget
                       newSyncTarget:@"Account" fieldlist:@[@"Name", @"Description"]]
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeOverwrite]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];
}

- (void) testRefreshSyncDownFromConfig {
    [self.sdkManager setupUserSyncsFromDefaultConfig];
    
    SFSyncState* sync = [self.syncManager getSyncStatusByName:@"refreshSyncDown"];
    XCTAssertEqualObjects(sync.soupName, @"accounts");
    [self checkStatus:sync
         expectedType:SFSyncStateSyncTypeDown
           expectedId:sync.syncId
         expectedName:@"refreshSyncDown"
       expectedTarget:[SFRefreshSyncDownTarget
                       newSyncTarget:@"accounts" objectType:@"Account" fieldlist:@[@"Name", @"Description"]]
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeLeaveIfChanged]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];
}

- (void) testLayoutSyncDownFromConfig {
    [self.sdkManager setupUserSyncsFromDefaultConfig];
    
    SFSyncState* sync = [self.syncManager getSyncStatusByName:@"layoutSyncDown"];
    XCTAssertEqualObjects(sync.soupName, @"accounts");
    [self checkStatus:sync
         expectedType:SFSyncStateSyncTypeDown
           expectedId:sync.syncId
         expectedName:@"layoutSyncDown"
       expectedTarget:[SFLayoutSyncDownTarget
                       newSyncTarget:@"Account"
                       formFactor:@"Medium"
                       layoutType:@"Compact"
                       mode:@"Edit"
                       recordTypeId:nil]
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeOverwrite]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];
}

- (void) testMetadataSyncDownFromConfig {
    [self.sdkManager setupUserSyncsFromDefaultConfig];
    
    SFSyncState* sync = [self.syncManager getSyncStatusByName:@"metadataSyncDown"];
    XCTAssertEqualObjects(sync.soupName, @"accounts");
    [self checkStatus:sync
         expectedType:SFSyncStateSyncTypeDown
           expectedId:sync.syncId
         expectedName:@"metadataSyncDown"
       expectedTarget:[SFMetadataSyncDownTarget newSyncTarget:@"Account"]
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeLeaveIfChanged]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];
}

- (void) testParentChildrenSyncDownFromConfig {
    [self.sdkManager setupUserSyncsFromDefaultConfig];
    
    SFSyncState* sync = [self.syncManager getSyncStatusByName:@"parentChildrenSyncDown"];
    XCTAssertEqualObjects(sync.soupName, @"accounts");
    [self checkStatus:sync
         expectedType:SFSyncStateSyncTypeDown
           expectedId:sync.syncId
         expectedName:@"parentChildrenSyncDown"
       expectedTarget:[SFParentChildrenSyncDownTarget
                       newSyncTargetWithParentInfo:[SFParentInfo
                                                    newWithSObjectType:@"Account"
                                                    soupName:@"accounts"
                                                    idFieldName:@"IdX"
                                                    modificationDateFieldName:@"LastModifiedDateX"]
                       parentFieldlist:@[@"IdX",@"Name", @"Description"]
                       parentSoqlFilter:@"NameX like 'James%'"
                       childrenInfo:[SFChildrenInfo
                                     newWithSObjectType:@"Contact"
                                     sobjectTypePlural:@"Contacts"
                                     soupName:@"contacts"
                                     parentIdFieldName:@"AccountId"
                                     idFieldName:@"IdY"
                                     modificationDateFieldName:@"LastModifiedDateY"]
                       childrenFieldlist:@[@"LastName", @"AccountId"]
                       relationshipType:SFParentChildrenRelationpshipMasterDetail]
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeOverwrite]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];
}

- (void) testNoBatchSyncUpFromConfig {
    [self.sdkManager setupUserSyncsFromDefaultConfig];
    
    SFSyncState* sync = [self.syncManager getSyncStatusByName:@"noBatchSyncUp"];
    XCTAssertEqualObjects(sync.soupName, @"accounts");
    [self checkStatus:sync
         expectedType:SFSyncStateSyncTypeUp
           expectedId:sync.syncId
         expectedName:@"noBatchSyncUp"
       expectedTarget:[[SFSyncUpTarget alloc] initWithCreateFieldlist:@[@"Name"] updateFieldlist:@[@"Description"]]
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncUp:@[] mergeMode:SFSyncStateMergeModeLeaveIfChanged]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];
}

- (void) testBatchSyncUpFromConfig {
    [self.sdkManager setupUserSyncsFromDefaultConfig];
    
    SFSyncState* sync = [self.syncManager getSyncStatusByName:@"batchSyncUp"];
    XCTAssertEqualObjects(sync.soupName, @"accounts");
    SFBatchSyncUpTarget* expectedTarget = [[SFBatchSyncUpTarget alloc] initWithCreateFieldlist:nil updateFieldlist:nil];
    expectedTarget.idFieldName = @"IdX";
    expectedTarget.modificationDateFieldName = @"LastModifiedDateX";
    expectedTarget.externalIdFieldName = @"ExternalIdX";
    [self checkStatus:sync
         expectedType:SFSyncStateSyncTypeUp
           expectedId:sync.syncId
         expectedName:@"batchSyncUp"
       expectedTarget:expectedTarget
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncUp:@[@"Name", @"Description"] mergeMode:SFSyncStateMergeModeOverwrite]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];
}

- (void) testParentChildrenSyncUpFromConfig {
    [self.sdkManager setupUserSyncsFromDefaultConfig];
    
    SFSyncState* sync = [self.syncManager getSyncStatusByName:@"parentChildrenSyncUp"];
    XCTAssertEqualObjects(sync.soupName, @"accounts");
    [self checkStatus:sync
         expectedType:SFSyncStateSyncTypeUp
           expectedId:sync.syncId
         expectedName:@"parentChildrenSyncUp"
       expectedTarget:[SFParentChildrenSyncUpTarget
                       newSyncTargetWithParentInfo:[SFParentInfo
                                                    newWithSObjectType:@"Account"
                                                    soupName:@"accounts"
                                                    idFieldName:@"IdX"
                                                    modificationDateFieldName:@"LastModifiedDateX"
                                                    externalIdFieldName:@"ExternalIdX"]
                       parentCreateFieldlist:@[@"IdX",@"Name", @"Description"]
                       parentUpdateFieldlist:@[@"Name", @"Description"]
                       childrenInfo:[SFChildrenInfo
                                     newWithSObjectType:@"Contact"
                                     sobjectTypePlural:@"Contacts"
                                     soupName:@"contacts"
                                     parentIdFieldName:@"AccountId"
                                     idFieldName:@"IdY"
                                     modificationDateFieldName:@"LastModifiedDateY"
                                     externalIdFieldName:@"ExternalIdY"]
                       childrenCreateFieldlist:@[@"LastName", @"AccountId"]
                       childrenUpdateFieldlist:@[@"FirstName", @"AccountId"]
                       relationshipType:SFParentChildrenRelationpshipMasterDetail]
      expectedOptions:[SFSyncOptions newSyncOptionsForSyncUp:@[] mergeMode:SFSyncStateMergeModeLeaveIfChanged]
       expectedStatus:SFSyncStateStatusNew
     expectedProgress:0
    expectedTotalSize:-1];
}



@end
