/*
 SmartSyncManagerTests
 Created by Raj Rao on 01/30/18.
 
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
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
import XCTest
import SalesforceSDKCore
import SmartStore
import SmartSync
import PromiseKit

@testable import SalesforceSwiftSDK

class SmartSyncManagerTests: SyncManagerBaseTest {
    
    override class func setUp() {
        super.setUp()
    }
    
    override func setUp() {
        super.setUp()
        let expectation = XCTestExpectation(description: "setup")
        firstly {
            return super.dropContactsSoup()
        }
        .then { _ -> Promise<Bool> in
            return super.createContactsSoup()
        }
        .done { createdSoup in
            XCTAssertTrue(createdSoup)
            expectation.fulfill()
        }
         .catch {_ in
            expectation.fulfill()
        }
        
        self.wait(for: [expectation], timeout: 10)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    override class func tearDown() {
        super.tearDown()
    }
    
    func testSyncDown() {
        let expectation = XCTestExpectation(description: "Down")
        let numberOfRecords: UInt = 1
        var contactIds:[String] = []
        firstly {
            try super.createContactsOnServer(noOfRecords: numberOfRecords)
        }
        .then { ids -> Promise<SFSyncState> in
            contactIds = ids
            let syncDownTarget = super.createSyncDownTargetFor(contactIds: contactIds)
            let syncOptions    = SFSyncOptions.newSyncOptions(forSyncDown: SFSyncStateMergeMode.overwrite)
            return (self.syncManager?.Promises.syncDown(target: syncDownTarget, options: syncOptions, soupName: CONTACTS_SOUP))!
        }
        .then { syncState -> Promise<UInt> in
            XCTAssertTrue(syncState.isDone())
            let querySpec =  SFQuerySpec.Builder(soupName: CONTACTS_SOUP)
                                        .queryType(value: .range)
                                        .build()
            return (self.store?.Promises.count(querySpec: querySpec))!
        }
        .then { count -> Promise<Void>  in
            XCTAssertTrue(count==numberOfRecords)
            return try super.deleteContactsFromServer(contactIds: contactIds)
        }
        .done {
            expectation.fulfill()
        }
        .catch { error in
            XCTFail("Could not Sync Down and  Sync Up")
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 10)
    }
 
    func testSyncUp() {
        let expectation = XCTestExpectation(description: "Down")
        let numberOfRecords: UInt = 1
        firstly {
            super.createContactsLocally(count: 1)
        }
        .then { result -> Promise<SFSyncState> in
            XCTAssert(result.count == numberOfRecords)
            result.forEach { value in
                XCTAssertTrue(value [kSyncTargetLocallyCreated] as! Bool == true)
            }
            let syncOptions = SFSyncOptions.newSyncOptions(forSyncUp: contactSyncFieldList, mergeMode: SFSyncStateMergeMode.overwrite)
            return (self.syncManager?.Promises.syncUp(options: syncOptions, soupName: CONTACTS_SOUP))!
        }
        .then { syncState -> Promise<Void> in
             XCTAssertTrue(syncState.isDone())
             return try super.deleteAllTestContactsFromServer()
        }
        .done { _ in
            expectation.fulfill()
        }
        .catch {error in
            XCTFail("Could not Sync Down and  Sync Up")
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 20)
    }
    
    func testCleanReSyncGhosts() {
        let expectation = XCTestExpectation(description: "Ghosts")
        let numberOfRecords: UInt = 1
        var contactIds:[String] = []
        var syncId: UInt = 0
        firstly {
            try super.createContactsOnServer(noOfRecords: numberOfRecords)
            }
            .then { ids -> Promise<SFSyncState> in
                contactIds = ids
                let syncDownTarget = super.createSyncDownTargetFor(contactIds: contactIds)
                let syncOptions    = SFSyncOptions.newSyncOptions(forSyncDown: SFSyncStateMergeMode.overwrite)
                return (self.syncManager?.Promises.syncDown(target: syncDownTarget, options: syncOptions, soupName: CONTACTS_SOUP))!
            }
            .then { syncState -> Promise<UInt> in
                XCTAssertTrue(syncState.isDone())
                syncId = UInt(syncState.syncId)
                let querySpec =  SFQuerySpec.Builder(soupName: CONTACTS_SOUP)
                    .queryType(value: .range)
                    .build()
                return (self.store?.Promises.count(querySpec: querySpec))!
            }
            .then { count -> Promise<Void>  in
                XCTAssertTrue(count==numberOfRecords)
                return try super.deleteContactsFromServer(contactIds: contactIds)
            }
            .then { _ -> Promise<SFSyncStateStatus> in
                XCTAssertTrue(syncId > 0)
                return (self.syncManager?.Promises.cleanResyncGhosts(syncId: syncId))!
            }
            .done { syncStateStatus in
                XCTAssertTrue(syncStateStatus==SFSyncStateStatus.done)
                expectation.fulfill()
            }
            .catch { error in
                XCTFail("Could CleanReSyncGhosts")
                expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 10)
    }
      
    func testResync() {
        let expectation = XCTestExpectation(description: "Resync")
        let numberOfRecords: UInt = 1
        var contactIds:[String] = []
        var syncId: UInt = 0
        firstly {
            try super.createContactsOnServer(noOfRecords: numberOfRecords)
        }
        .then { ids -> Promise<SFSyncState> in
            contactIds = ids
            let syncDownTarget = super.createSyncDownTargetFor(contactIds: contactIds)
            let syncOptions    = SFSyncOptions.newSyncOptions(forSyncDown: SFSyncStateMergeMode.overwrite)
            return (self.syncManager?.Promises.syncDown(target: syncDownTarget, options: syncOptions, soupName: CONTACTS_SOUP))!
        }
        .then { syncState -> Promise<UInt> in
            XCTAssertTrue(syncState.isDone())
            syncId = UInt(syncState.syncId)
            let querySpec =  SFQuerySpec.Builder(soupName: CONTACTS_SOUP)
                .queryType(value: .range)
                .build()
            return (self.store?.Promises.count(querySpec: querySpec))!
        }
        .then { count -> Promise<Void>  in
            XCTAssertTrue(count==numberOfRecords)
            return try super.deleteContactsFromServer(contactIds: contactIds)
        }
        .then { _ -> Promise<SFSyncState> in
            XCTAssertTrue(syncId > 0)
            return (self.syncManager?.Promises.reSync(syncId: syncId))!
        }
        .done { syncState in
            XCTAssertTrue(syncState.isDone())
            expectation.fulfill()
        }
        .catch { error in
            XCTFail("Could not reSync")
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 10)
    }
}
