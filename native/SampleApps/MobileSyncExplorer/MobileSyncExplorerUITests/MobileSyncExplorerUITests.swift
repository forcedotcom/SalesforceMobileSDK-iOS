/*
SmartSyncExplorerUITests.swift
SmartSyncExplorerUITests

Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.

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

class SmartSyncExplorerTest: SalesforceTestCase {

    let searchScreen = SearchScreen()
    
    // MARK: Setup
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        searchScreen.logout()
        super.tearDown()
    }
    
    // MARK: Tests
    
    func testCreateSaveSearchOpen() {
        let uids = createLocally(3)
        for uid in uids {
            searchAndCheck(uid);
        }
    }

    // MARK: Helper methods

    // Create n records and return their uid's
    func createLocally(_ n:Int) -> [Int] {
        var uids : [Int] = []
        
        for _ in 0 ..< n {
            let uid = generateUid()
            uids.append(uid)
            createRecord(uid)
        }
        
        return uids;
    }
    
    // Clicks add, fills some fields, clicks save
    func createRecord(_ uid:Int) {
        let detailScreen = searchScreen.addRecord()
        detailScreen.typeFirstName("fn\(uid)").typeLastName("ln\(uid)").typeTitle("t\(uid)")
        detailScreen.save()
    }
    
    // Search for record, check results, open detail screen for record, check fields, goes back to search screen
    func searchAndCheck(_ uid:Int) {
        searchScreen.clearSearch()
        searchScreen.typeSearch("fn\(uid)")
        XCTAssertEqual(searchScreen.countRecords(), 1)
        XCTAssert(searchScreen.hasRecord("fn\(uid) ln\(uid)"))
        let detailScreen = searchScreen.openRecord("fn\(uid) ln\(uid)")
        detailScreen.edit()
        XCTAssert(detailScreen.hasFirstName("fn\(uid)"))
        XCTAssert(detailScreen.hasLastName("ln\(uid)"))
        XCTAssert(detailScreen.hasTitle("t\(uid)"))
        detailScreen.cancel()
        detailScreen.backToSearch()
    }
    
    func generateUid() -> Int {
        return Int(arc4random_uniform(9000) + 1000);
    }
}
