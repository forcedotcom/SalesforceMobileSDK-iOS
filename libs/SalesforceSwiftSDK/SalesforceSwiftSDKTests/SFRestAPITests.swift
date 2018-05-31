/*
 SFRestAPITests
 Created by Raj Rao on 11/27/17.
 
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
import Foundation
import XCTest
import SalesforceSDKCore
import PromiseKit
@testable import SalesforceSwiftSDK

class SFRestAPITests: SalesforceSwiftSDKBaseTest {
  
    override class func setUp() {
        super.setUp()
    }
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
        super.tearDown()
    }
    
    override class func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testQuery() {
        
        var restResonse : Dictionary<String, Any>?
        var restError : Error?
        let restApi  = SFRestAPI.sharedInstance()
        XCTAssertNotNil(restApi)
        let exp = expectation(description: "restApi")
        
        restApi.Promises.query(soql: "SELECT Id,FirstName,LastName FROM User")
        .then { request in
            restApi.Promises.send(request: request)
        }
        .done { sfRestResponse in
            restResonse = sfRestResponse.asJsonDictionary()
            exp.fulfill()
        }
        .catch { error in
            restError = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
        XCTAssertNil(restError)
        XCTAssertNotNil(restResonse)
        
    }
    
    func testQueryAll() {
        
        var restResonse : Dictionary<String, Any>?
        var restError : Error?
        
        let restApi  = SFRestAPI.sharedInstance()
        XCTAssertNotNil(restApi)
        let exp = expectation(description: "restApi")
        
        restApi.Promises.queryAll(soql: "SELECT Id,FirstName,LastName FROM User")
        .then { request in
            restApi.Promises.send(request: request)
        }
        .done { sfRestResponse in
            restResonse = sfRestResponse.asJsonDictionary()
            exp.fulfill()
        }
        .catch { error in
            restError = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
        XCTAssertNil(restError)
        XCTAssertNotNil(restResonse)
        
    }
    
    func testDescribeGlobal() {
        
        var restResonse : Dictionary<String, Any>?
        var restError : Error?
        
        let restApi  = SFRestAPI.sharedInstance()
        XCTAssertNotNil(restApi)
        let exp = expectation(description: "restApi")
        
        restApi.Promises.describeGlobal()
        .then { request in
            restApi.Promises.send(request: request)
        }
        .done { sfRestResponse in
            restResonse = sfRestResponse.asJsonDictionary()
            exp.fulfill()
        }
        .catch { error in
            restError = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
        XCTAssertNil(restError)
        XCTAssertNotNil(restResonse)
        
    }
    
    func testDescribeObject() {
        
        var restResonse : Dictionary<String, Any>?
        var restError : Error?
        let restApi  = SFRestAPI.sharedInstance()
        XCTAssertNotNil(restApi)
        let exp = expectation(description: "restApi")
        
        restApi.Promises.describe(objectType: "Account")
        .then { request in
            restApi.Promises.send(request: request)
        }
        .done { sfRestResponse in
            restResonse = sfRestResponse.asJsonDictionary()
            exp.fulfill()
        }
        .catch { error in
            restError = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
        XCTAssertNil(restError)
        XCTAssertNotNil(restResonse)
    }
    
    func testDescribeObjectAsString() {
        
        var restResonse : String?
        var restError : Error?
        let restApi  = SFRestAPI.sharedInstance()
        XCTAssertNotNil(restApi)
        let exp = expectation(description: "restApi")
        
        restApi.Promises.describe(objectType: "Account")
        .then { request in
            restApi.Promises.send(request: request)
        }
        .done { sfRestResponse in
            restResonse = sfRestResponse.asString()
            exp.fulfill()
        }
        .catch { error in
            restError = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
        XCTAssertNil(restError)
        XCTAssertNotNil(restResonse)
    }
    
    func testCreateUpdateQueryDelete() {
        
        var restError : Error?
        let restApi  = SFRestAPI.sharedInstance()
        XCTAssertNotNil(restApi)
        let exp = expectation(description: "restApi")
        
        // create, uodate ,query delete chain
        restApi.Promises.create(objectType: "Contact", fields:["FirstName": "John",
                                                              "LastName": "Petrucci"])
        .then { request in
            restApi.Promises.send(request: request)
        }
        .then { sfRestResponse -> Promise<SFRestRequest> in
            let restResonse = sfRestResponse.asJsonDictionary()
            XCTAssertNotNil(restResonse)
            XCTAssertNotNil(restResonse["id"])
            // retrieve
            return restApi.Promises.retrieve(objectType: "Contact", objectId: restResonse["id"] as! String, fieldList: "FirstName","LastName")
        }
        .then {  (request) -> Promise<SFRestResponse> in
            XCTAssertNotNil(request)
            return restApi.Promises.send(request: request)
        }
        .then { sfRestResponse -> Promise<SFRestRequest> in
            let restResonse = sfRestResponse.asJsonDictionary()
            XCTAssertNotNil(restResonse)
            // update
            return  restApi.Promises.update(objectType: "Contact", objectId: restResonse["Id"] as! String, fieldList: ["FirstName" : "Steve","LastName" : "Morse"], ifUnmodifiedSince: nil)
        }
        .then { request -> Promise<SFRestResponse> in
            XCTAssertNotNil(request)
            return restApi.Promises.send(request: request)
        }
        .then { data -> Promise<SFRestRequest> in
            XCTAssertNotNil(data)
            return restApi.Promises.query(soql : "Select Id,FirstName,LastName from Contact where LastName='Morse'")
        }
        .then {  request -> Promise<SFRestResponse> in
            XCTAssertNotNil(request)
            return restApi.Promises.send(request: request)
        }
        .then { (sfRestResponse) -> Promise<SFRestRequest> in
            let restResonse = sfRestResponse.asJsonDictionary()
            XCTAssertNotNil(restResonse)
            XCTAssertNotNil(restResonse["records"])
            var records: [Any] = restResonse["records"] as! [Any]
            var record: [String:Any] = records[0] as! [String:Any]
            return  restApi.Promises.delete(objectType: "Contact", objectId: record["Id"] as! String)
        }
        .then { request -> Promise<SFRestResponse> in
            XCTAssertNotNil(request)
            return restApi.Promises.send(request: request)
        } .done { sfRestResponse in
            let strResp = sfRestResponse.asJsonDictionary()
            XCTAssertNotNil(strResp)
            exp.fulfill()
        }
        .catch { error in
            restError = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 30)
        XCTAssertNil(restError)
    }
    
    func testSearch() {
        var restResonse : Dictionary<String, Any>?
        var restError : Error?
        let restApi  = SFRestAPI.sharedInstance()
        XCTAssertNotNil(restApi)
        let exp = expectation(description: "restApi")
        
        restApi.Promises.search(sosl: "FIND {blah} IN NAME FIELDS RETURNING User")
        .then { request in
            restApi.Promises.send(request: request)
        }
        .done { sfRestResponse in
            restResonse = sfRestResponse.asJsonDictionary()
            exp.fulfill()
        }
        .catch { error in
            restError = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
        XCTAssertNil(restError)
        XCTAssertNotNil(restResonse)
    }
    
    func testSearchScopeAndOrder() {
        var restResonse : [Dictionary<String, Any>]?
        var restError : Error?
        let restApi  = SFRestAPI.sharedInstance()
        XCTAssertNotNil(restApi)
        let exp = expectation(description: "restApi")
        
        restApi.Promises.searchScopeAndOrder()
        .then { request in
            restApi.Promises.send(request: request)
        }
        .done { (sfRestResponse) in
            restResonse = sfRestResponse.asJsonArray()
            exp.fulfill()
        }
        .catch { error in
            restError = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
        XCTAssertNil(restError)
        XCTAssertNotNil(restResonse)
    }
    
    func testSearchLayout() {
        var restResonse : [Dictionary<String, Any>]?
        var restError : Error?
        let restApi  = SFRestAPI.sharedInstance()
        XCTAssertNotNil(restApi)
        let exp = expectation(description: "restApi")
        
        restApi.Promises.searchResultLayout(objectList: "Account")
        .then { request in
            restApi.Promises.send(request: request)
        }
        .done { sfRestResponse in
            print(sfRestResponse.asString())
            restResonse = sfRestResponse.asJsonArray()
            exp.fulfill()
        }
        .catch { error in
            restError = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
        XCTAssertNil(restError)
        XCTAssertNotNil(restResonse)
    }
    
    func testQueryDecodable() {
        
        var restError : Error?
        let restApi  = SFRestAPI.sharedInstance()
        XCTAssertNotNil(restApi)
        let exp = expectation(description: "restApi")
        
        // create, uodate ,query delete chain
        restApi.Promises.create(objectType: "Contact", fields:["FirstName": "John",
                                                              "LastName": "Petrucci"])
        .then { request in
            restApi.Promises.send(request: request)
        }
        .then { (sfRestResponse) -> Promise<SFRestRequest> in
            let restResonse = sfRestResponse.asJsonDictionary()
            XCTAssertNotNil(restResonse)
            XCTAssertNotNil(restResonse["id"])
            return restApi.Promises.query(soql : "Select Id,FirstName,LastName from Contact where LastName='Petrucci'")
        }
        .then {  request -> Promise<SFRestResponse> in
            XCTAssertNotNil(request)
            return restApi.Promises.send(request: request)
        }
        .then { (sfRestResponse) -> Promise<QueryResponse<SampleRecord>> in
            let restResonse = sfRestResponse.asDecodable(type: QueryResponse<SampleRecord>.self) as!  QueryResponse<SampleRecord>
            XCTAssertNotNil(restResonse)
            return Promise(value:restResonse)
            // update
        }
        .done { response in
            XCTAssertNotNil(response)
            exp.fulfill()
        }
        .catch { error in
            restError = error
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 30)
        XCTAssertNil(restError)
    }
    
    func testPerformQueryDecodable() {
        
        var restError : Error?
        let restApi  = SFRestAPI.sharedInstance()
        XCTAssertNotNil(restApi)
        
        let exp = expectation(description: "restApi")
        
        firstly {
            restApi.Promises.query(soql:"Select Id,FirstName,LastName from Contact where LastName='Petrucci'")
        }
        .then {  request -> Promise<SFRestResponse> in
            XCTAssertNotNil(request)
            return restApi.Promises.send(request: request)
        }
        .done { sfResponse  in
            XCTAssertNotNil(sfResponse.asDecodable(type: QueryResponse<SampleRecord>.self))
            exp.fulfill()
        }
        .catch { error in
            restError = error
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 30)
        XCTAssertNil(restError)
    }
    
    func testPerformSearchDecodable() {
        
        var restError : Error?
        let restApi  = SFRestAPI.sharedInstance()
        XCTAssertNotNil(restApi)
        
        let exp = expectation(description: "restApi")
        
        firstly {
            restApi.Promises.search(sosl:"FIND {John} IN ALL FIELDS RETURNING Account(Name), Contact(FirstName,LastName)")
        }
        .then {  request -> Promise<SFRestResponse> in
            XCTAssertNotNil(request)
            return restApi.Promises.send(request: request)
        }
        .done { sfResponse  in
            XCTAssertNotNil(sfResponse.asDecodable(type: SearchResponse<SearchRecord>.self))
            exp.fulfill()
        }
        .catch { error in
            restError = error
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 30)
        XCTAssertNil(restError)
    }
    
    func testCompositeRequest() {
        // Create account
        let accountName: String = generateRecordName()
        let restApi  = SFRestAPI.sharedInstance()
        var restError : Error?
        let exp = expectation(description: "restApi")
       
        let createAcccountRequest = restApi.requestForCreate(withObjectType: "Account", fields: ["Name" : accountName])
        
        let contactName: String = generateRecordName()
        
        let createContactRequest = restApi.requestForCreate(withObjectType: "Contact", fields:["LastName": contactName, "AccountId": "@{refAccount.id}"])
        
        let queryForContactRequest = SFRestAPI.sharedInstance().request(forQuery: "select Id, AccountId from Contact where LastName = '\(contactName)'")
        
        restApi.Promises.composite(requests: [createAcccountRequest,createContactRequest,queryForContactRequest], refIds: ["refAccount", "refContact", "refQuery"],allOrNone: true)
        .then { request in
             restApi.Promises.send(request: request)
        }.done { sfRestResponse in
            var response = sfRestResponse.asJsonDictionary()
            var results = response["compositeResponse"] as! [[String:Any]]
            XCTAssertNotNil(results)
            XCTAssertEqual(results[0]["httpStatusCode"] as! Int, 201, "Wrong status for first request")
            XCTAssertEqual(results[1]["httpStatusCode"] as! Int, 201, "Wrong status for second request")
            XCTAssertEqual(results[2]["httpStatusCode"] as! Int, 200, "Wrong status for third request")
            let accountId = ((results[0]["body"] as! [AnyHashable: Any])["id"]) as! String
            let contactId = ((results[1]["body"] as! [AnyHashable: Any])["id"]) as! String
            let queryRecords = (results[2]["body"] as! [AnyHashable: Any])["records"] as! [[String: Any]]
            XCTAssertEqual(1, queryRecords.count, "Wrong number of results for query request")
            var record = queryRecords[0]
            XCTAssertEqual(accountId, record["AccountId"] as! String)
            XCTAssertEqual(contactId, record["Id"] as! String)
            exp.fulfill()
        }.catch { error in
            restError = error
            exp.fulfill()
        }
         wait(for: [exp], timeout: 30)
         XCTAssertNil(restError)
   }

    func testBatchRequest() {
       
        // Create account
        let accountName: String = generateRecordName()
        let restApi  = SFRestAPI.sharedInstance()
        var restError : Error?
        let exp = expectation(description: "restApi")
        
        let createAccountRequest = restApi.requestForCreate(withObjectType: "Account", fields: ["Name" : accountName])
        
        let contactName: String = generateRecordName()
        let createContactRequest = restApi.requestForCreate(withObjectType: "Contact", fields: ["LastName": contactName])
        
        let queryForAccount = SFRestAPI.sharedInstance().request(forQuery: "select Id from Account where Name = '\(accountName)'")
        // Query for contact
        let queryForContact = SFRestAPI.sharedInstance().request(forQuery: "select Id from Contact where Name = '\(contactName)'")
        
        // Build batch request
        restApi.Promises.batch(requests: createAccountRequest, createContactRequest, queryForAccount, queryForContact, haltOnError: true)
        .then { request in
            restApi.Promises.send(request: request)
        }
        .done { sfRestResponse in
            let response = sfRestResponse.asJsonDictionary()
            XCTAssertNotNil(response)
            let hasErrors =  response["hasErrors"] as! Bool
            XCTAssertFalse(hasErrors)
            XCTAssertNotNil(response)
            exp.fulfill()
        }.catch { error in
            restError = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 30)
        XCTAssertNil(restError)
    }
    
    func testOwnedFilesList() {
        let restApi  = SFRestAPI.sharedInstance()
        var restError : Error?
        let exp = expectation(description: "restApi")
        restApi.Promises.filesOwned(userId: nil, page: 0)
        .then { request in
            restApi.Promises.send(request: request)
        }
        .done { sfResponse in
            exp.fulfill()
        }
        .catch { error in
            restError = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
        XCTAssertNil(restError)
    }
    
    func testFilesInUsersGroups() {
        let restApi  = SFRestAPI.sharedInstance()
        var restError : Error?
        let exp = expectation(description: "restApi")
        restApi.Promises.filesInUsersGroups(userId: nil, page: 0)
        .then { request in
            restApi.Promises.send(request: request)
        }
        .done { sfResponse in
            exp.fulfill()
        }
        .catch { error in
            restError = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
        XCTAssertNil(restError)
    }
    
    func testFilesSharedWithUser() {
     
        let restApi  = SFRestAPI.sharedInstance()
        var restError : Error?
        let exp = expectation(description: "restApi")
        restApi.Promises.filesShared(userId: nil, page: 0)
            .then { request in
                restApi.Promises.send(request: request)
            }
            .done { sfResponse in
                exp.fulfill()
            }
            .catch { error in
                restError = error
                exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
        XCTAssertNil(restError)
    }

    func generateRecordName() -> String {
        let timecode: TimeInterval = Date.timeIntervalSinceReferenceDate
        return "RestClientSwiftTestsiOS\(timecode)"
    }
    
}
