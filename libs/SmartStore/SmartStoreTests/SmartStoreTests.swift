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

    func testBadQueryWhenUsingExternalStorage() {
        // NB: Starting with Mobile SDK 9.1, it is possible to query non-indexed path (when using internal storage), it is no longer a bad query
        let soupSpec = SoupSpec.newSoupSpec("MyTestSoup", withFeatures: [kSoupFeatureExternalStorage])
        let soupIndexes = [SoupIndex(path:"key", indexType:kSoupIndexTypeString, columnName:nil)!,
                           SoupIndex(path:"owner", indexType:kSoupIndexTypeString, columnName:nil)!]
        do {
            try store!.registerSoup(withSpecification: soupSpec, withIndices:soupIndexes)
            let result = store!.query("select {MyTestSoup:date} from {MyTestSoup}")
            switch (result) {
                case .success(_): XCTFail("query should have failed")
                case .failure(let error): XCTAssertNotNil(error)
            }

        } catch {
            XCTFail("registration should not have failed")
        }
    }

}
