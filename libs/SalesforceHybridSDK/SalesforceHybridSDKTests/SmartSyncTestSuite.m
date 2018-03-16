/*
 Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.
 
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

#import <UIKit/UIKit.h>
#import <SmartStore/SmartStore.h>
#import <SalesforceHybridSDK/SalesforceHybridSDK.h>
#import <SalesforceSDKCore/SFApplicationHelper.h>

#import "AppDelegate.h"
#import "SFTestRunnerPlugin.h"
#import "SFPluginTestSuite.h"

@interface SmartSyncTestSuite : SFPluginTestSuite
@end

@implementation SmartSyncTestSuite

- (void)setUp
{
    [super setUp];
    self.jsSuiteName = @"SmartSyncTestSuite";
    if ([self isTestRunnerReady]) {
        [SFSmartStore removeAllStores];
        [SFSmartStore removeAllGlobalStores];
        AppDelegate *appDelegate = (AppDelegate *)[SFApplicationHelper sharedApplication].delegate;
        SFSmartStorePlugin *smartstorePlugin = [appDelegate.viewController.commandDelegate getCommandInstance:kSmartStorePluginIdentifier];
        [smartstorePlugin resetCursorCaches];
        SFSmartSyncPlugin *smartsyncPlugin = [appDelegate.viewController.commandDelegate getCommandInstance:kSmartSyncPluginIdentifier];
        [smartsyncPlugin resetSyncManager];
    }
}

- (void)tearDown
{
    [SFSmartStore removeSharedStoreWithName:kDefaultSmartStoreName];
    [SFSmartStore removeSharedGlobalStoreWithName:kDefaultSmartStoreName];
    [super tearDown];
}

- (void)testStoreCacheInit {
    [self runTest:@"testStoreCacheInit"];
}

- (void)testStoreCacheRetrieve {
    [self runTest:@"testStoreCacheRetrieve"];
}

- (void)testStoreCacheSave {
    [self runTest:@"testStoreCacheSave"];
}

- (void)testStoreCacheSaveAll {
    [self runTest:@"testStoreCacheSaveAll"];
}

- (void)testStoreCacheRemove {
    [self runTest:@"testStoreCacheRemove"];
}

- (void)testStoreCacheFind {
    [self runTest:@"testStoreCacheFind"];
}

- (void)testStoreCacheAddLocalFields {
    [self runTest:@"testStoreCacheAddLocalFields"];
}

- (void)testStoreCacheWithGlobalStore {
    [self runTest:@"testStoreCacheWithGlobalStore"];
}

- (void)testSObjectTypeDescribe {
    [self runTest:@"testSObjectTypeDescribe"];
}

- (void)testSObjectTypeGetMetadata {
    [self runTest:@"testSObjectTypeGetMetadata"];
}

- (void)testSObjectTypeDescribeLayout {
    [self runTest:@"testSObjectTypeDescribeLayout"];
}

- (void)testSObjectTypeCacheOnlyMode {
    [self runTest:@"testSObjectTypeCacheOnlyMode"];
}

- (void)testSObjectTypeCacheMerge {
    [self runTest:@"testSObjectTypeCacheMerge"];
}

- (void)testMultiSObjectTypes {
    [self runTest:@"testMultiSObjectTypes"];
}

- (void)testSObjectTypeReset {
    [self runTest:@"testSObjectTypeReset"];
}

- (void)testSyncRemoteObjectWithCacheCreate {
    [self runTest:@"testSyncRemoteObjectWithCacheCreate"];
}

- (void)testSyncRemoteObjectWithCacheRead {
    [self runTest:@"testSyncRemoteObjectWithCacheRead"];
}

- (void)testSyncRemoteObjectWithCacheUpdate {
    [self runTest:@"testSyncRemoteObjectWithCacheUpdate"];
}

- (void)testSyncRemoteObjectWithCacheDelete {
    [self runTest:@"testSyncRemoteObjectWithCacheDelete"];
}

- (void)testSyncSObjectWithServerCreate {
    [self runTest:@"testSyncSObjectWithServerCreate"];
}

- (void)testSyncSObjectWithServerRead {
    [self runTest:@"testSyncSObjectWithServerRead"];
}

- (void)testSyncSObjectWithServerUpdate {
    [self runTest:@"testSyncSObjectWithServerUpdate"];
}

- (void)testSyncSObjectWithServerDelete {
    [self runTest:@"testSyncSObjectWithServerDelete"];
}

- (void)testSyncSObjectCreate {
    [self runTest:@"testSyncSObjectCreate"];
}

- (void)testSyncSObjectRetrieve {
    [self runTest:@"testSyncSObjectRetrieve"];
}

- (void)testSyncSObjectUpdate {
    [self runTest:@"testSyncSObjectUpdate"];
}

- (void)testSyncSObjectDelete {
    [self runTest:@"testSyncSObjectDelete"];
}

- (void)testSyncSObjectDetectConflictCreate {
    [self runTest:@"testSyncSObjectDetectConflictCreate"];
}

- (void)testSyncSObjectDetectConflictRetrieve {
    [self runTest:@"testSyncSObjectDetectConflictRetrieve"];
}

- (void)testSyncSObjectDetectConflictUpdate {
    [self runTest:@"testSyncSObjectDetectConflictUpdate"];
}

- (void)testSyncSObjectDetectConflictDelete {
    [self runTest:@"testSyncSObjectDetectConflictDelete"];
}

- (void)testSObjectFetch {
    [self runTest:@"testSObjectFetch"];
}
 
- (void)testSObjectSave {
    [self runTest:@"testSObjectSave"];
}

- (void)testSObjectDestroy {
    [self runTest:@"testSObjectDestroy"];
}

- (void)testSyncApexRestObjectWithServerCreate {
    [self runTest:@"testSyncApexRestObjectWithServerCreate"];
}

- (void)testSyncApexRestObjectWithServerRead {
    [self runTest:@"testSyncApexRestObjectWithServerRead"];
}

- (void)testSyncApexRestObjectWithServerUpdate {
    [self runTest:@"testSyncApexRestObjectWithServerUpdate"];
}

- (void)testSyncApexRestObjectWithServerDelete {
    [self runTest:@"testSyncApexRestObjectWithServerDelete"];
}

- (void)testFetchApexRestObjectsFromServer {
    [self runTest:@"testFetchApexRestObjectsFromServer"];
}

- (void)testFetchSObjectsFromServer {
    [self runTest:@"testFetchSObjectsFromServer"];
}

- (void)testFetchSObjects {
    [self runTest:@"testFetchSObjects"];
}

- (void)testSObjectCollectionFetch {
    [self runTest:@"testSObjectCollectionFetch"];
}

- (void)testSyncDown {
    [self runTest:@"testSyncDown"];
}

- (void)testSyncDownToGlobalStore {
    [self runTest:@"testSyncDownToGlobalStore"];
}

- (void)testSyncDownWithNoOverwrite {
    [self runTest:@"testSyncDownWithNoOverwrite"];
}

- (void)testRefreshSyncDown {
    [self runTest:@"testRefreshSyncDown"];
}

- (void)testReSync {
    [self runTest:@"testReSync"];
}

- (void)testCleanResyncGhosts {
    [self runTest:@"testCleanResyncGhosts"];
}

- (void)testSyncUpLocallyUpdated {
    [self runTest:@"testSyncUpLocallyUpdated"];
}

- (void)testSyncUpLocallyUpdatedWithGlobalStore {
    [self runTest:@"testSyncUpLocallyUpdatedWithGlobalStore"];
}

- (void)testSyncUpLocallyUpdatedWithNoOverwrite {
    [self runTest:@"testSyncUpLocallyUpdatedWithNoOverwrite"];
}

- (void)testSyncUpLocallyDeleted {
    [self runTest:@"testSyncUpLocallyDeleted"];
}

- (void)testSyncUpLocallyDeletedWithNoOverwrite {
    [self runTest:@"testSyncUpLocallyDeletedWithNoOverwrite"];
}

- (void)testSyncUpLocallyCreated {
    [self runTest:@"testSyncUpLocallyCreated"];
}


- (void)testStoreCacheWithGlobalStoreNamed {
    [self runTest:@"testStoreCacheWithGlobalStoreNamed"];
}

- (void)testSyncDownToGlobalStoreNamed {
    [self runTest:@"testSyncDownToGlobalStoreNamed"];
}

- (void)testSyncUpLocallyUpdatedWithGlobalStoreNamed {
    [self runTest:@"testSyncUpLocallyUpdatedWithGlobalStoreNamed"];
}

- (void) testSyncDownGetSyncDeleteSyncById {
    [self runTest:@"testSyncDownGetSyncDeleteSyncById"];
}

- (void) testSyncDownGetSyncDeleteSyncByName {
    [self runTest:@"testSyncDownGetSyncDeleteSyncByName"];
}

- (void) testSyncUpGetSyncDeleteSyncById {
    [self runTest:@"testSyncUpGetSyncDeleteSyncById"];
}

- (void) testSyncUpGetSyncDeleteSyncByName {
    [self runTest:@"testSyncUpGetSyncDeleteSyncByName"];
}

@end
