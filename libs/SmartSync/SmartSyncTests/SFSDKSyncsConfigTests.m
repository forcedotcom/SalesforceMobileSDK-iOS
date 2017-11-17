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
#import <XCTest/XCTest.h>

@implementation SFSDKSyncsConfigTests

#pragma mark - setup and teardown

- (void) tearDown
{
//    deleteSyncs();
//    deleteGlobalSyncs();
//    super.tearDown();
}

#pragma mark - tests

- (void) testSetupGlobalSyncsFromDefaultConfig  {

//    assertFalse(SyncState.hasSyncWithName(globalSmartStore, "globalSync1"));
//    assertFalse(SyncState.hasSyncWithName(globalSmartStore, "globalSync2"));
//
//    // Setting up soup
//    SmartSyncSDKManager.getInstance().setupGlobalSyncsFromDefaultConfig();
//
//    // Checking smartstore
//    assertTrue(SyncState.hasSyncWithName(globalSmartStore, "globalSync1"));
//    assertTrue(SyncState.hasSyncWithName(globalSmartStore, "globalSync2"));
//
//    // Checking first sync in details
//    SyncState actualSync1 = SyncState.byName(globalSmartStore, "globalSync1");
//    assertEquals("Wrong soup name", ACCOUNTS_SOUP, actualSync1.getSoupName());
//    checkStatus(actualSync1, SyncState.Type.syncDown, actualSync1.getId(), new SoqlSyncDownTarget("SELECT Id, Name, LastModifiedDate FROM Account"), SyncOptions.optionsForSyncDown(SyncState.MergeMode.OVERWRITE), SyncState.Status.NEW, 0);
//
//    // Checking second sync in details
//    SyncState actualSync2 = SyncState.byName(globalSmartStore, "globalSync2");
//    assertEquals("Wrong soup name", ACCOUNTS_SOUP, actualSync2.getSoupName());
//    checkStatus(actualSync2, SyncState.Type.syncUp, actualSync2.getId(),
//            new SyncUpTarget(Arrays.asList(new String[]{"Name"}), null),
//    SyncOptions.optionsForSyncUp(Arrays.asList(new String[]{"Id", "Name", "LastModifiedDate"}), SyncState.MergeMode.LEAVE_IF_CHANGED),
//    SyncState.Status.NEW, 0);

}

- (void) testSetupUserSyncsFromDefaulltConfig {

//    assertFalse(SyncState.hasSyncWithName(smartStore, "userSync1"));
//    assertFalse(SyncState.hasSyncWithName(smartStore, "userSync2"));
//
//    // Setting up soup
//    SmartSyncSDKManager.getInstance().setupUserSyncsFromDefaultConfig();
//
//    // Checking smartstore
//    assertTrue(SyncState.hasSyncWithName(smartStore, "userSync1"));
//    assertTrue(SyncState.hasSyncWithName(smartStore, "userSync2"));
//
//    // Checking first sync in details
//    SyncState actualSync1 = SyncState.byName(smartStore, "userSync1");
//    assertEquals("Wrong soup name", ACCOUNTS_SOUP, actualSync1.getSoupName());
//    checkStatus(actualSync1, SyncState.Type.syncDown, actualSync1.getId(), new SoqlSyncDownTarget("SELECT Id, Name, LastModifiedDate FROM Account"), SyncOptions.optionsForSyncDown(SyncState.MergeMode.OVERWRITE), SyncState.Status.NEW, 0);
//
//    // Checking second sync in details
//    SyncState actualSync2 = SyncState.byName(smartStore, "userSync2");
//    assertEquals("Wrong soup name", ACCOUNTS_SOUP, actualSync2.getSoupName());
//    checkStatus(actualSync2, SyncState.Type.syncUp, actualSync2.getId(),
//            new SyncUpTarget(Arrays.asList(new String[]{"Name"}), null),
//    SyncOptions.optionsForSyncUp(Arrays.asList(new String[]{"Id", "Name", "LastModifiedDate"}), SyncState.MergeMode.LEAVE_IF_CHANGED),
//    SyncState.Status.NEW, 0);

}

@end
