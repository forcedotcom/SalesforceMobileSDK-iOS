/*
 SmartStoreTests.swift
 Test for Swift SmarStore extensions
 
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

import XCTest
import Foundation
@testable import SmartStore

class SmartStoreTests: XCTestCase {
    
    let testStoreName = "SmartStoreTestsGlobalStore"
    
    var store:SmartStore?

    override func setUp() {
        store = SmartStore.sharedGlobal(withName: testStoreName)
    }
    
    override func tearDown() {
        SmartStore.removeSharedGlobal(withName: testStoreName)
    }

    func testRegisterSoup() {
        let result = store!.registerSoup(withName: "MyTestSoup", withIndexPaths: ["key", "owner"])
        switch(result) {
        case .success(let val): XCTAssertTrue(val)
        case .failure(_): XCTFail("registerSoup should not have failed")
        }
    }

    func testBadRegisterSoup() {
        let result = store!.registerSoup(withName: "", withIndexPaths: ["key", "owner"])
        switch(result) {
        case .success(_): XCTFail("registerSoup should have failed")
        case .failure(let error): XCTAssertNotNil(error)
        }
    }

    func testQuery() {
        _ = store!.registerSoup(withName: "MyTestSoup", withIndexPaths: ["key", "owner"])
        store!.upsert(entries: [["key":"key1", "owner":"owner1"],
                               ["key":"key2", "owner":"owner2"],
                               ["key":"key3", "owner":"owner1"]], forSoupNamed: "MyTestSoup")
        let result = store!.query("select {MyTestSoup:key} from {MyTestSoup} where {MyTestSoup:owner} = 'owner1' order by {MyTestSoup:key}")
        switch (result) {
        case .success(let val):
            let arr = val as! [[String]]
            XCTAssertEqual(arr, [["key1"], ["key3"]])
        case .failure(_): XCTFail("query should not have failed")
        }
    }

    func testTransactionLookupWithNoMatchReturnsNilInsteadOfThrowing() throws {
        _ = store!.registerSoup(withName: "MyTestSoup", withIndexPaths: ["key"])
        var lookedUp = false
        try store!.performTransaction { txn in
            do {
                let entryId = try txn.lookupSoupEntryId(soupNamed: "MyTestSoup", fieldPath: "key", fieldValue: "nope")
                XCTAssertNil(entryId)
                lookedUp = true
            } catch {
                XCTFail("Lookup with no match must not throw: \(error)")
            }
        }
        XCTAssertTrue(lookedUp)
    }

    func testTransactionLookupFailureThrows() throws {
        _ = store!.registerSoup(withName: "MyTestSoup", withIndexPaths: ["key"])
        var threw = false
        try store!.performTransaction { txn in
            do {
                _ = try txn.lookupSoupEntryId(soupNamed: "MyTestSoup", fieldPath: "notIndexed", fieldValue: "x")
            } catch {
                threw = true
            }
        }
        XCTAssertTrue(threw)
    }

    func testTransactionReadsAndWritesFromSwift() throws {
        _ = store!.registerSoup(withName: "MyTestSoup", withIndexPaths: ["key"])
        try store!.performTransaction { txn in
            do {
                let upserted = try txn.upsert(entries: [["key": "k1"]], forSoupNamed: "MyTestSoup", withExternalIdPath: SmartStore.soupEntryId)
                XCTAssertEqual(upserted.count, 1)
                let found = try txn.lookupSoupEntryId(soupNamed: "MyTestSoup", fieldPath: "key", fieldValue: "k1")
                XCTAssertNotNil(found)
                XCTAssertEqual(try txn.retrieve(usingSoupEntryIds: [], fromSoupNamed: "MyTestSoup").count, 0)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testTransactionRollbackAndFailFromSwift() throws {
        _ = store!.registerSoup(withName: "MyTestSoup", withIndexPaths: ["key"])
        // Requested rollback: returns NO with no NSError, which Swift reports as a thrown error
        XCTAssertThrowsError(try store!.performTransaction { txn in
            _ = try? txn.upsert(entries: [["key": "k1"]], forSoupNamed: "MyTestSoup", withExternalIdPath: SmartStore.soupEntryId)
            txn.rollback()
        })
        // Explicit failure: thrown error is the one passed
        let mine = NSError(domain: "test", code: 42, userInfo: nil)
        do {
            try store!.performTransaction { txn in txn.fail(with: mine) }
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual((error as NSError).code, 42)
        }
        if case .success(let val) = store!.query("select {MyTestSoup:key} from {MyTestSoup}") {
            XCTAssertEqual((val as! [[String]]).count, 0)
        } else { XCTFail("query should not have failed") }
    }
}
