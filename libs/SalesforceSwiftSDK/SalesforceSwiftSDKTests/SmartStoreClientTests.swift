/*
 SmartStoreClientTests
 Created by Raj Rao on 01/19/18.
 
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
import Foundation
import XCTest
import SalesforceSDKCore
import PromiseKit
import SmartStore
@testable import SalesforceSwiftSDK

class SmartStoreClientTests: SalesforceSwiftSDKBaseTest {
    
    override class func setUp() {
        super.setUp()
    }
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    override class func tearDown() {
        super.tearDown()
    }
    
    func testCreateGlobalStore() {
        let glbStoreName = "SWIFTGLBLCOOKBOOK"
        let soupName = "WONTONSOUP"
        let expectation = XCTestExpectation(description: "CreateStore")
        _ = SFSmartStoreClient
            .globalStore(withName: glbStoreName)
            .then { globalStore -> Promise<SFSmartStore> in
                XCTAssertNotNil(globalStore)
                return Promise(value: globalStore)
            }
            .then { store -> Promise<(Bool,SFSmartStore)>  in
                let result  = store.soupExists(soupName)
                return Promise(value:(result,store))
            }
            .then { (result,store) -> Promise<Void> in
                XCTAssertFalse(result)
                XCTAssertNotNil(store)
                return SFSmartStoreClient.removeGlobalStore(withName: glbStoreName)
            }
            .done {
                expectation.fulfill()
            }
        self.wait(for: [expectation], timeout: 10)
    }
    
    
    func testCreateSharedStore() {
        let lclStoreName = "SWIFTLOCALCOOKBOOK"
        let soupName = "WONTONSOUP"
        let expectation = XCTestExpectation(description: "CreateUserStore")
        _ = SFSmartStoreClient
            .store(withName: lclStoreName)
            .then { localStore -> Promise<SFSmartStore> in
                XCTAssertNotNil(localStore)
                return Promise(value: localStore)
            }
            .then { store -> Promise<(Bool,SFSmartStore)>  in
                let result  = store.soupExists(soupName)
                return Promise(value:(result,store))
            }
            .then { (result,store) -> Promise<Void> in
                XCTAssertFalse(result)
                XCTAssertNotNil(store)
                return SFSmartStoreClient.removeSharedStore(withName: lclStoreName)
            }
            .done {
                expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 10)
    }
    
    
    func testCreateSoup() {
        let lclStoreName = "SWIFTLOCALCOOKBOOK"
        let soupName = "WONTONSOUP"
        let expectation = XCTestExpectation(description: "CreateSoup")
        
        _ =  SFSmartStoreClient
            .store(withName: lclStoreName)
            .then { localStore -> Promise<SFSmartStore> in
                XCTAssertNotNil(localStore)
                return Promise(value: localStore)
            }
            .then { store -> Promise<Bool>  in
                let result  = store.soupExists(soupName)
                XCTAssertFalse(result)
                let indexSpecs = SFSoupIndex.asArraySoupIndexes([ ["path": "key"], ["type" : "string"] ])
                return store.Promises.registerSoup(soupName: soupName, indexSpecs: indexSpecs)
            }
            .then { soupCreated -> Promise<Void> in
                XCTAssertTrue(soupCreated)
                return SFSmartStoreClient.removeSharedStore(withName: lclStoreName)
            }
            .done {
                expectation.fulfill()
            }
            .catch { error in
                XCTFail("testCreateSoup() Failed" + error.localizedDescription)
                expectation.fulfill()
            }
        self.wait(for: [expectation], timeout: 10)
    }
    
    func testFindAndRemoveSoup() {
        let lclStoreName = "SWIFTLOCALCOOKBOOK"
        let soupName = "WONTONSOUP"
        let expectation = XCTestExpectation(description: "CreateAndRemoveSoup")
        
        let store: SFSmartStore  = SFSmartStore.sharedStore(withName: lclStoreName) as! SFSmartStore
        let result  = store.soupExists(soupName)
        XCTAssertFalse(result)
        let indexSpecs = SFSoupIndex.asArraySoupIndexes([ ["path": "key"], ["type" : "string"]])
            
        store.Promises.registerSoup(soupName: soupName, indexSpecs: indexSpecs)
        .then { soupCreated -> Promise<Void> in
            XCTAssertTrue(soupCreated)
            return store.Promises.removeSoup(soupName: soupName)
        }
        .then { _ in
           return SFSmartStoreClient.removeSharedStore(withName: lclStoreName)
        }
        .done {
            expectation.fulfill()
        }
        .catch { error in
            XCTFail("testCreateSoup() Failed" + error.localizedDescription)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 10)
    }
    
    func testCountQuerySpecBuilder() {
        let spec =  SFQuerySpec.Builder(soupName: "chickensoup")
            .queryType(value: .range)
            .path(value: "wings")
            .beginKey(value: "1")
            .endKey(value: "2")
            .pageSize(value: 1)
            .build()
        XCTAssertEqual("SELECT count(*) FROM {chickensoup} WHERE {chickensoup:wings} >= ? AND {chickensoup:wings} <= ?", spec.countSmartSql.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testSmartSqlWithSelectPathsQuerySpecBuilder() {
        let spec =  SFQuerySpec.Builder(soupName: "chickensoup")
            .queryType(value: .range)
            .selectedPaths(value: ["wings", "legs", "qty"])
            .orderPath(value: "qty")
            .order(value: .ascending)
            .pageSize(value: 1)
            .build()
        XCTAssertEqual("SELECT {chickensoup:wings}, {chickensoup:legs}, {chickensoup:qty} FROM {chickensoup} ORDER BY {chickensoup:qty} ASC", spec.smartSql.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testAllQuerySmartSql() {
        let spec =  SFQuerySpec.Builder(soupName: "chickensoup")
            .queryType(value: .range)
            .orderPath(value: "wings")
            .order(value: .descending)
            .pageSize(value: 1)
            .build()
        
        XCTAssertEqual("SELECT {chickensoup:_soup} FROM {chickensoup} ORDER BY {chickensoup:wings} DESC", spec.smartSql.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testAllQuerySmartSqlWithSelectPaths() {
        let spec =  SFQuerySpec.Builder(soupName: "chickensoup")
            .queryType(value: .range)
            .selectedPaths(value: ["wings", "legs", "qty"])
            .orderPath(value: "qty")
            .order(value: .descending)
            .pageSize(value: 1)
            .build()
        
        XCTAssertEqual("SELECT {chickensoup:wings}, {chickensoup:legs}, {chickensoup:qty} FROM {chickensoup} ORDER BY {chickensoup:qty} DESC", spec.smartSql.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testAllQueryCountSmartSql() {
        let spec =  SFQuerySpec.Builder(soupName: "chickensoup")
            .queryType(value: .range)
            .path(value: "qty")
            .orderPath(value: "qty")
            .order(value: .descending)
            .pageSize(value: 1)
            .build()
        XCTAssertEqual("SELECT count(*) FROM {chickensoup}", spec.countSmartSql.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testAllQueryIdsSmartSql() {
        let spec =  SFQuerySpec.Builder(soupName: "chickensoup")
            .queryType(value: .range)
            .path(value: "qty")
            .orderPath(value: "qty")
            .order(value: .descending)
            .pageSize(value: 1)
            .build()
        
        XCTAssertEqual("SELECT id FROM {chickensoup} ORDER BY {chickensoup:qty} DESC", spec.idsSmartSql.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    
    func testExactQueryIdsSmartSql() {
        let spec =  SFQuerySpec.Builder(soupName: "chickensoup")
            .queryType(value: .exact)
            .path(value: "wings")
            .beginKey(value: "1")
            .endKey(value: "2")
            .pageSize(value: 1)
            .build()
        XCTAssertEqual("SELECT id FROM {chickensoup} WHERE {chickensoup:wings} = ?", spec.idsSmartSql.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testMatchQuerySmartSql() {
        let spec =  SFQuerySpec.Builder(soupName: "chickensoup")
            .queryType(value: .match)
            .path(value: "wings")
            .orderPath(value: "wings")
            .order(value: .ascending)
            .matchKey(value: "2")
            .pageSize(value: 1)
            .build()
        XCTAssertEqual("SELECT {chickensoup:_soup} FROM {chickensoup} WHERE {chickensoup:_soupEntryId} IN (SELECT rowid FROM {chickensoup}_fts WHERE {chickensoup}_fts MATCH '{chickensoup:wings}:2') ORDER BY {chickensoup:wings} ASC", spec.smartSql.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testMatchQuerySmartSqlWithSelectPaths() {
        let spec =  SFQuerySpec.Builder(soupName: "chickensoup")
            .queryType(value: .match)
            .selectedPaths(value: ["wings", "legs", "qty"])
            .path(value: "wings")
            .matchKey(value: "2")
            .order(value: .ascending)
            .orderPath(value: "legs")
            .pageSize(value: 1)
            .build()
        
        XCTAssertEqual("SELECT {chickensoup:wings}, {chickensoup:legs}, {chickensoup:qty} FROM {chickensoup} WHERE {chickensoup:_soupEntryId} IN (SELECT rowid FROM {chickensoup}_fts WHERE {chickensoup}_fts MATCH '{chickensoup:wings}:2') ORDER BY {chickensoup:legs} ASC", spec.smartSql.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
}

