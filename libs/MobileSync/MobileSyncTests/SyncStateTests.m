/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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
#import <SmartStore/SmartStore.h>
#import "SFSoqlSyncDownTarget.h"
#import "SFMobileSyncSyncManager.h"
#import "SFSyncState.h"


#define DB_NAME @"testDb"

@interface SyncStateTests : XCTestCase

@end

@interface SyncStateTests ()

@property (nonatomic, strong) SFSmartStore *store;

@end

@implementation SyncStateTests

#pragma mark - setUp/tearDown

- (void)setUp {
    [super setUp];
    self.store = [SFSmartStore sharedGlobalStoreWithName:DB_NAME];
}

- (void)tearDown {
    [SFSmartStore removeSharedGlobalStoreWithName:DB_NAME];
    [super tearDown];
}

#pragma mark - Tests

/**
 * Make sure syncs soup gets properly setup the first time around
 */
-(void) testSetupSyncsSoupFirstTime {
    // Setup syncs soup
    [SFSyncState setupSyncsSoupIfNeeded:self.store];
    
    // Check the soup
    [self checkSyncsSoupIndexSpecs:self.store];
}

/**
 * Make sure syncs soup gets properly setup when upgrading to 7.1
 */
-(void) testSetupSyncsSoupUpgradeTo71 {
    // Manually syncs soup the pre 7.1 way
    NSArray* indexSpecs = @[
                            [[SFSoupIndex alloc] initWithPath:@"type" indexType:kSoupIndexTypeString columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:@"name" indexType:kSoupIndexTypeString columnName:nil]
                            ];
    [self.store registerSoup:kSFSyncStateSyncsSoupName withIndexSpecs:indexSpecs error:nil];
    
    // Fix syncs soup
    [SFSyncState setupSyncsSoupIfNeeded:self.store];
    
    // Check the soup
    [self checkSyncsSoupIndexSpecs:self.store];
}

/**
 * Make sure syncs marked as running are "cleaned up" after restart
 */
-(void) testCleanupSyncsSoupIfNeeded {
    // Setup syncs soup
    [SFSyncState setupSyncsSoupIfNeeded:self.store];

    // Create syncs - some in the running state
    [self createSyncChangeStatus:@"newSyncUp" isSyncUp:YES status:SFSyncStateStatusNew];
    [self createSyncChangeStatus:@"stoppedSyncUp" isSyncUp:YES status:SFSyncStateStatusStopped];
    [self createSyncChangeStatus:@"runningSyncUp" isSyncUp:YES status:SFSyncStateStatusRunning];
    [self createSyncChangeStatus:@"failedSyncUp" isSyncUp:YES status:SFSyncStateStatusFailed];
    [self createSyncChangeStatus:@"doneSyncUp" isSyncUp:YES status:SFSyncStateStatusDone];
    [self createSyncChangeStatus:@"newSyncDown" isSyncUp:NO status:SFSyncStateStatusNew];
    [self createSyncChangeStatus:@"stoppedSyncDown" isSyncUp:NO status:SFSyncStateStatusStopped];
    [self createSyncChangeStatus:@"runningSyncDown" isSyncUp:NO status:SFSyncStateStatusRunning];
    [self createSyncChangeStatus:@"failedSyncDown" isSyncUp:NO status:SFSyncStateStatusFailed];
    [self createSyncChangeStatus:@"doneSyncDown" isSyncUp:NO status:SFSyncStateStatusDone];

    
    // Cleanup syncs soup
    [SFSyncState cleanupSyncsSoupIfNeeded:self.store];
    
    // Check the syncs
    [self checkSyncsSoupIndexSpecs:self.store];
}

#pragma mark - Helper methods

-(void) createSyncChangeStatus:(NSString*)name isSyncUp:(BOOL)isSyncUp status:(SFSyncStateStatus)status {
    
    SFSyncState* sync;
    if (isSyncUp) {
        sync = [SFSyncState newSyncUpWithOptions:[SFSyncOptions newSyncOptionsForSyncUp:@[@"Name"]]
                                          target:[SFSyncUpTarget newFromDict:@{}]
                                        soupName:@"Accounts"
                                            name:name
                                           store:self.store];
    } else {
        sync = [SFSyncState newSyncDownWithOptions:[SFSyncOptions newSyncOptionsForSyncDown:SFSyncStateMergeModeLeaveIfChanged]
                                            target:[SFSoqlSyncDownTarget newSyncTarget:@"SELECT Id, Name from Account"]
                                          soupName:@"Accounts"
                                              name:name
                                             store:self.store];
    }
    
    sync.status = status;
    [sync save:self.store];
}

- (void) checkSyncStatus:(NSString*) name expectedStatus:(SFSyncStateStatus)expectedStatus {
    SFSyncState* sync = [SFSyncState byName:name store:self.store];
    XCTAssertEqual(expectedStatus, sync.status);
}

/**
 * Check syncs soup index specs
 */
-(void) checkSyncsSoupIndexSpecs:(SFSmartStore*)store {
    NSArray* indexSpecs = [store indicesForSoup:kSFSyncStateSyncsSoupName];
    XCTAssertEqual(3, indexSpecs.count, @"Wrong number of index specs");

    NSArray* expectedPaths = @[@"name", @"type", @"status"];
    for (SFSoupIndex* indexSpec in indexSpecs) {
        XCTAssertTrue([expectedPaths containsObject:indexSpec.path], @"Wrong index spec path");
        XCTAssertEqualObjects(@"json1", indexSpec.indexType, @"Wrong index spec type");
    }
}
@end
