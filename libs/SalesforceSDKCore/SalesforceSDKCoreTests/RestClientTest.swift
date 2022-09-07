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

import XCTest
@testable import SalesforceSDKCore

struct TestContact: Decodable{
    var id: UUID = UUID()
    var Id: String?
    var FirstName: String?
    var LastName: String?
}

class RestClientTests: XCTestCase {
    
    var currentUser: UserAccount?
    
    override class func setUp() {
        super.setUp()
        SFSDKLogoutBlocker.block()
        TestSetupUtils.populateAuthCredentialsFromConfigFile(for: SFSDKAuthUtilTests.self)
        TestSetupUtils.synchronousAuthRefresh()
    }
    
    override func setUp() {
        currentUser = UserAccountManager.shared.currentUserAccount
    }
    
    
    func testFetchRecordsNonCombine() {
        let expectation = XCTestExpectation(description: "queryTest")
        let request = RestClient.shared.request(forQuery: "select name from CONTACT", apiVersion: nil)
        
        var erroredResult: RestClientError?
        RestClient.shared.fetchRecords(ofModelType: TestContact.self, forRequest: request) { result in
            switch (result) {
            case .failure(let error):
                erroredResult = error
            default: break
            }
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 10.0)
        XCTAssertNil(erroredResult,"Query call should not have failed")
    }
    
    func testQuery() {
        let expectation = XCTestExpectation(description: "queryTest")
        let request = RestClient.shared.request(forQuery: "select name from CONTACT", apiVersion: nil)
        
        var erroredResult: RestClientError?
        RestClient.shared.send(request: request) { result  in
            switch (result) {
            case .failure(let error):
                erroredResult = error
            default: break
            }
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 10.0)
        XCTAssertNil(erroredResult,"Query call should not have failed")
    }
    
    func testQueryWithDefaultBatchSize() {
        let request = RestClient.shared.request(forQuery: "select name from CONTACT", apiVersion: nil, batchSize: 2000)
        XCTAssertNil(request.customHeaders?["@SForce-Query-Options"]);
    }
    
    func testQueryWithNonDefaultBatchSize() {
        let request500 = RestClient.shared.request(forQuery: "select name from CONTACT", apiVersion: nil, batchSize: 500)
        let request199 = RestClient.shared.request(forQuery: "select name from CONTACT", apiVersion: nil, batchSize: 199)
        let request2001 = RestClient.shared.request(forQuery: "select name from CONTACT", apiVersion: nil, batchSize: 2001)
        XCTAssertTrue("batchSize=500" == request500.customHeaders?["Sforce-Query-Options"] as! String);
        XCTAssertTrue("batchSize=200" == request199.customHeaders?["Sforce-Query-Options"] as! String);
        XCTAssertNil(request2001.customHeaders?["@SForce-Query-Options"]);
    }
    
    func testCompositeRequest() throws {
        let expectation = XCTestExpectation(description: "compositeTest")
        let accountName = self.generateRecordName()
        let contactName = self.generateRecordName()
        let apiVersion = RestClient.shared.apiVersion
        let requestBuilder = CompositeRequestBuilder()
            .add(RestClient.shared.requestForCreate(withObjectType: "Account", fields: ["Name": accountName], apiVersion: apiVersion), referenceId: "refAccount")
            .add(RestClient.shared.requestForCreate(withObjectType: "Contact", fields: ["LastName": contactName,"AccountId": "@{refAccount.id}"], apiVersion: apiVersion), referenceId: "refContact")
            .add(RestClient.shared.request(forQuery: "select Id, AccountId from Contact where LastName =  '\(contactName)'", apiVersion: apiVersion), referenceId: "refQuery")
            .setAllOrNone(true)
        
        let compositeRequest = requestBuilder.buildCompositeRequest(apiVersion)
        XCTAssertNotNil(compositeRequest, "Composite Request should not be nil")
        XCTAssertNotNil(compositeRequest.allSubRequests.count == 3, "Composite Requests should have 3 requests")
        
        var response: CompositeResponse?
        var restClientError: Error?
        
        RestClient.shared.send(compositeRequest: compositeRequest) { result in
            defer { expectation.fulfill() }
            switch (result) {
            case .success(let resp):
                response = resp
            case .failure(let error):
                restClientError = error
            }
        }
        self.wait(for: [expectation], timeout: 20)
        XCTAssertNil(restClientError, "Error should not have occurred")
        let compositeResponse = try XCTUnwrap(response)
        XCTAssertNotNil(compositeResponse.subResponses, "Composite Sub Responses should not be nil")
        XCTAssertTrue(3 == compositeResponse.subResponses.count, "Wrong number of results")
        XCTAssertEqual(compositeResponse.subResponses[0].httpStatusCode, 201, "Wrong status for first request")
        XCTAssertEqual(compositeResponse.subResponses[1].httpStatusCode, 201, "Wrong status for second request")
        XCTAssertEqual(compositeResponse.subResponses[2].httpStatusCode, 200, "Wrong status for third request")
        XCTAssertNotNil(compositeResponse.subResponses[0].body, "Subresponse must have a response body")
        XCTAssertNotNil(compositeResponse.subResponses[1].body, "Subresponse must have a response body")
        XCTAssertNotNil(compositeResponse.subResponses[2].body, "Subresponse must have a response body")
        
        let resp1 = compositeResponse.subResponses[0].body as! [String:Any]
        let resp2 = compositeResponse.subResponses[1].body as! [String:Any]
        let resp3 = compositeResponse.subResponses[2].body as! [String:Any]
        XCTAssertNotNil(resp1["id"] as? String, "Subresponse must have a Id in reponse body")
        XCTAssertNotNil(resp2["id"] as? String, "Subresponse must have an Id in reponse body")
        
        let accountID = try XCTUnwrap(resp1["id"] as? String)
        let contactID = try XCTUnwrap(resp2["id"] as? String)
        let queryRecords = try XCTUnwrap(resp3["records"] as? [[String:Any]])
        
        XCTAssertNotNil(queryRecords, "Subresponse must have records in body")
        
        let accountIDInQuery = queryRecords[0]["AccountId"] as! String
        let contactIDInQuery = queryRecords[0]["Id"] as! String
        // Query should have returned ids of newly created account and contact
        XCTAssertTrue(1 == queryRecords.count, "Wrong number of results for query request")
        XCTAssertTrue(accountID == accountIDInQuery, "Account id not returned by query")
        XCTAssertTrue(contactID == contactIDInQuery, "Contact id not returned by query");
    }
    
    func testCompositeRequestFailure() throws {
        let expectation = XCTestExpectation(description: "compositeTest")
        let accountName = self.generateRecordName()
        let contactName = self.generateRecordName()
        let apiVersion = RestClient.shared.apiVersion
        let requestBuilder = CompositeRequestBuilder()
            .add(RestClient.shared.requestForCreate(withObjectType: "Account", fields: ["Name": accountName], apiVersion: apiVersion), referenceId: "refAccount")
            .add(RestClient.shared.requestForCreate(withObjectType: "Contact", fields: ["LastName": contactName,"AccountId": "@{refAccount.id}"], apiVersion: apiVersion), referenceId: "refContact")
            .add(RestClient.shared.request(forQuery: "select Id, AccountId", apiVersion: apiVersion), referenceId: "refQuery") // bad request!
            .setAllOrNone(true)
        
        let compositeRequest = requestBuilder.buildCompositeRequest(apiVersion)
        XCTAssertNotNil(compositeRequest, "Composite Request should not be nil")
        XCTAssertNotNil(compositeRequest.allSubRequests.count == 3, "Composite Requests should have 3 requests")
        
        var response: CompositeResponse?
        var restClientError: Error?
        
        RestClient.shared.send(compositeRequest: compositeRequest) { result in
            defer { expectation.fulfill() }
            switch (result) {
            case .success(let resp):
                response = resp
            case .failure(let error):
                restClientError = error
            }
        }
        self.wait(for: [expectation], timeout: 20)
        XCTAssertNil(restClientError, "Error should not have occurred")
        let compositeResponse = try XCTUnwrap(response)
        XCTAssertNotNil(compositeResponse.subResponses, "Composite Sub Responses should not be nil")
        XCTAssertTrue(3 == compositeResponse.subResponses.count, "Wrong number of results")
        XCTAssertEqual(compositeResponse.subResponses[0].httpStatusCode, 400, "Wrong status for first request")
        XCTAssertEqual(compositeResponse.subResponses[1].httpStatusCode, 400, "Wrong status for second request")
        XCTAssertEqual(compositeResponse.subResponses[2].httpStatusCode, 400, "Wrong status for third request")
    }
    
    func testCompositeRequestPartialSuccess() throws {
        let expectation = XCTestExpectation(description: "compositeRequestTest")
        let accountName = self.generateRecordName()
        let contactName = self.generateRecordName()
        let apiVersion = RestClient.shared.apiVersion
        let requestBuilder = CompositeRequestBuilder()
            .add(RestClient.shared.requestForCreate(withObjectType: "Account", fields: ["Name": accountName], apiVersion: apiVersion), referenceId: "refAccount")
            .add(RestClient.shared.requestForCreate(withObjectType: "Contact", fields: ["LastName": contactName,"AccountId": "@{refAccount.id}"], apiVersion: apiVersion), referenceId: "refContact")
            .add(RestClient.shared.request(forQuery: "select Id, AccountId", apiVersion: apiVersion), referenceId: "refQuery") // bad request!
            .setAllOrNone(false)
        
        let compositeRequest = requestBuilder.buildCompositeRequest(apiVersion)
        XCTAssertNotNil(compositeRequest, "Composite Request should not be nil")
        XCTAssertNotNil(compositeRequest.allSubRequests.count == 3, "Composite Requests should have 3 requests")
        
        var response: CompositeResponse?
        var restClientError: Error?
        
        RestClient.shared.send(compositeRequest: compositeRequest) { result in
            defer { expectation.fulfill() }
            switch (result) {
            case .success(let resp):
                response = resp
            case .failure(let error):
                restClientError = error
            }
        }
        self.wait(for: [expectation], timeout: 20)
        XCTAssertNil(restClientError, "Error should not have occurred")
        let compositeResponse = try XCTUnwrap(response)
        XCTAssertNotNil(compositeResponse.subResponses, "Composite Sub Responses should not be nil")
        XCTAssertTrue(3 == compositeResponse.subResponses.count, "Wrong number of results")
        XCTAssertEqual(compositeResponse.subResponses[0].httpStatusCode, 201, "Wrong status for first request")
        XCTAssertEqual(compositeResponse.subResponses[1].httpStatusCode, 201, "Wrong status for second request")
        XCTAssertEqual(compositeResponse.subResponses[2].httpStatusCode, 400, "Wrong status for third request")
    }
    
    func testBatchRequest() throws {
        let expectation = XCTestExpectation(description: "batchRequestTest")
        
        // Create account
        let accountName = self.generateRecordName()
        let contactName = self.generateRecordName()
        let apiVersion = RestClient.shared.apiVersion
        
        let requestBuilder = BatchRequestBuilder()
            .add(RestClient.shared.requestForCreate(withObjectType: "Account", fields: ["Name": accountName], apiVersion: apiVersion))
            .add(RestClient.shared.requestForCreate(withObjectType: "Contact", fields: ["LastName": contactName], apiVersion: apiVersion))
            .add(RestClient.shared.request(forQuery: "select Id from Account where Name = '\(accountName)'", apiVersion: apiVersion))
            .add(RestClient.shared.request(forQuery: "select Id from Contact where Name = '\(contactName)'", apiVersion: apiVersion))
            .setHaltOnError(true)
        
        let batchRequest = requestBuilder.buildBatchRequest(apiVersion)
        XCTAssertNotNil(batchRequest, "Batch Request should not be nil")
        XCTAssertTrue(batchRequest.batchRequests.count==4,"Batch Requests should have 4 requests")
        
        var response: BatchResponse?
        var restClientError: Error?
        
        RestClient.shared.send(batchRequest: batchRequest) { result in
            defer { expectation.fulfill() }
            switch (result) {
            case .success(let resp):
                response = resp
            case .failure(let error):
                restClientError = error
            }
        }
        self.wait(for: [expectation], timeout: 20)
        XCTAssertNil(restClientError, "Error should not have occurred")
        let batchResponse = try XCTUnwrap(response)
        XCTAssertFalse(batchResponse.hasErrors, "BatchResponse results should not have any errors")
        XCTAssertNotNil(batchResponse.results, "BatchResponse results should not be nil")
        XCTAssertTrue(4 == batchResponse.results.count, "Wrong number of results")
        
        XCTAssertNotNil(batchResponse.results[0] as? [String: Any], "BatchResponse result should be a dictionary")
        XCTAssertNotNil(batchResponse.results[1] as? [String: Any], "BatchResponse results should be a dictionary")
        XCTAssertNotNil(batchResponse.results[2] as? [String: Any], "BatchResponse results should be a dictionary")
        XCTAssertNotNil(batchResponse.results[3] as? [String: Any], "BatchResponse results should be a dictionary")
        
        
        let resp1 = batchResponse.results[0] as! [String: Any]
        let resp2 = batchResponse.results[1] as! [String: Any]
        let resp3 = batchResponse.results[2] as! [String: Any]
        let resp4 = batchResponse.results[3] as! [String: Any]
        
        XCTAssertTrue(resp1["statusCode"] as? Int == 201, "Wrong status for first request")
        XCTAssertTrue(resp2["statusCode"] as? Int == 201, "Wrong status for first request")
        XCTAssertTrue(resp3["statusCode"] as? Int == 200, "Wrong status for first request")
        XCTAssertTrue(resp4["statusCode"] as? Int == 200, "Wrong status for first request")
        
        let result1 = resp1["result"] as! [String: Any]
        let result2 = resp2["result"] as! [String: Any]
        let result3 = resp3["result"] as! [String: Any]
        let result4 = resp4["result"] as! [String: Any]
        
        let accountId = result1["id"] as? String
        let contactId = result2["id"] as? String
        let resFomfirstQuery = result3["records"] as? [[String: Any]]
        let resFomSecondQuery = result4["records"] as? [[String: Any]]
        XCTAssertNotNil(accountId)
        XCTAssertNotNil(contactId)
        XCTAssertNotNil(resFomfirstQuery)
        XCTAssertNotNil(resFomSecondQuery)
        
        let idFromFirstQuery = try XCTUnwrap(resFomfirstQuery?[0]["Id"] as? String)
        let idFromSecondQuery = try XCTUnwrap(resFomSecondQuery?[0]["Id"] as? String)
        XCTAssertTrue(accountId! == idFromFirstQuery, "Account id not returned by query")
        XCTAssertTrue(contactId! == idFromSecondQuery, "Account id not returned by query")
        
    }
    
    func testBatchRequestStopOnFailure() throws {
        let expectation = XCTestExpectation(description: "batchRequestTest")
        
        // Create account
        let accountName = self.generateRecordName()
        let contactName = self.generateRecordName()
        let apiVersion = RestClient.shared.apiVersion
        
        let requestBuilder = BatchRequestBuilder()
            .add(RestClient.shared.requestForCreate(withObjectType: "Account", fields: ["Name": accountName], apiVersion: apiVersion))
            .add(RestClient.shared.requestForCreate(withObjectType: "Contact", fields: ["LastName": contactName], apiVersion: apiVersion))
            .add(RestClient.shared.request(forQuery: "select Id from Account where Name ", apiVersion:  apiVersion)) // bad query
            .add(RestClient.shared.request(forQuery: "select Id from Contact where Name = '\(contactName)'", apiVersion: apiVersion))
            .setHaltOnError(true)
        
        let batchRequest = requestBuilder.buildBatchRequest(apiVersion)
        XCTAssertNotNil(batchRequest, "Batch Request should not be nil")
        XCTAssertTrue(batchRequest.batchRequests.count == 4, "Batch Requests should have 4 requests")
        
        var response: BatchResponse?
        var restClientError: Error?
        
        RestClient.shared.send(batchRequest: batchRequest) { result in
            defer { expectation.fulfill() }
            switch (result) {
            case .success(let resp):
                response = resp
            case .failure(let error):
                restClientError = error
            }
        }
        self.wait(for: [expectation], timeout: 20)
        XCTAssertNil(restClientError, "Error should not have occurred")
        XCTAssertNotNil(response, "BatchResponse should not be nil")
        let batchResponse = try XCTUnwrap(response)
        XCTAssertTrue(batchResponse.hasErrors, "BatchResponse results should not have any errors")
        XCTAssertNotNil(batchResponse.results, "BatchResponse results should not be nil")
        XCTAssertTrue(4 == batchResponse.results.count, "Wrong number of results")
        
        XCTAssertNotNil(batchResponse.results[0] as? [String: Any], "BatchResponse result should be a dictionary")
        XCTAssertNotNil(batchResponse.results[1] as? [String: Any], "BatchResponse results should be a dictionary")
        XCTAssertNotNil(batchResponse.results[2] as? [String: Any], "BatchResponse results should be a dictionary")
        XCTAssertNotNil(batchResponse.results[3] as? [String: Any], "BatchResponse results should be a dictionary")
        
        
        let resp1 = batchResponse.results[0] as! [String: Any]
        let resp2 = batchResponse.results[1] as! [String: Any]
        let resp3 = batchResponse.results[2] as! [String: Any]
        let resp4 = batchResponse.results[3] as! [String: Any]
        
        XCTAssertTrue(resp1["statusCode"] as? Int == 201, "Wrong status for first request")
        XCTAssertTrue(resp2["statusCode"] as? Int == 201, "Wrong status for first request")
        XCTAssertTrue(resp3["statusCode"] as? Int == 400, "Wrong status for first request")
        XCTAssertTrue(resp4["statusCode"] as? Int == 412, "Request processing should have stopped on error")
    }
    
    func testBatchRequestContinueOnFailure() throws {
        let expectation = XCTestExpectation(description: "batchRequestTest")
        
        // Create account
        let accountName = self.generateRecordName()
        let contactName = self.generateRecordName()
        let apiVersion = RestClient.shared.apiVersion
        
        let requestBuilder = BatchRequestBuilder()
            .add(RestClient.shared.requestForCreate(withObjectType: "Account", fields: ["Name": accountName], apiVersion: apiVersion))
            .add(RestClient.shared.requestForCreate(withObjectType: "Contact", fields: ["LastName": contactName], apiVersion: apiVersion))
            .add(RestClient.shared.request(forQuery: "select Id from Account where Name ", apiVersion:  apiVersion)) // bad query
            .add(RestClient.shared.request(forQuery: "select Id from Contact where Name = '\(contactName)'", apiVersion: apiVersion))
            .setHaltOnError(false)
        
        let batchRequest = requestBuilder.buildBatchRequest(apiVersion)
        XCTAssertNotNil(batchRequest, "Batch Request should not be nil")
        XCTAssertTrue(batchRequest.batchRequests.count == 4, "Batch Requests should have 4 requests")
        
        var response: BatchResponse?
        var restClientError: Error?
        
        RestClient.shared.send(batchRequest: batchRequest) { result in
            defer { expectation.fulfill() }
            switch (result) {
            case .success(let resp):
                response = resp
            case .failure(let error):
                restClientError = error
            }
        }
        self.wait(for: [expectation], timeout: 20)
        XCTAssertNil(restClientError, "Error should not have occurred")
        XCTAssertNotNil(response, "BatchResponse should not be nil")
        let batchResponse = try XCTUnwrap(response)
        XCTAssertTrue(batchResponse.hasErrors, "BatchResponse results should not have any errors")
        XCTAssertNotNil(batchResponse.results, "BatchResponse results should not be nil")
        XCTAssertTrue(4 == batchResponse.results.count, "Wrong number of results")
        
        XCTAssertNotNil(batchResponse.results[0] as? [String: Any], "BatchResponse result should be a dictionary")
        XCTAssertNotNil(batchResponse.results[1] as? [String: Any], "BatchResponse results should be a dictionary")
        XCTAssertNotNil(batchResponse.results[2] as? [String: Any], "BatchResponse results should be a dictionary")
        XCTAssertNotNil(batchResponse.results[3] as? [String: Any], "BatchResponse results should be a dictionary")
        
        let resp1 = batchResponse.results[0] as! [String: Any]
        let resp2 = batchResponse.results[1] as! [String: Any]
        let resp3 = batchResponse.results[2] as! [String: Any]
        let resp4 = batchResponse.results[3] as! [String: Any]
        
        XCTAssertTrue(resp1["statusCode"] as? Int == 201, "Wrong status for first request")
        XCTAssertTrue(resp2["statusCode"] as? Int == 201, "Wrong status for first request")
        XCTAssertTrue(resp3["statusCode"] as? Int == 400, "Wrong status for first request")
        XCTAssertTrue(resp4["statusCode"] as? Int == 200, "Request processing should have stopped on error")
    }
    
    func testDecodableResponse() {
        let expectation = XCTestExpectation(description: "decodableResponseTest")
        let apiVersion = RestClient.shared.apiVersion
        
        let query = "select Id from Account limit 5"
        let request = RestClient.shared.request(forQuery: query, apiVersion: apiVersion)
        
        var response: RestResponse?
        var restClientError: Error?
        
        RestClient.shared.send(request: request) { result in
            defer { expectation.fulfill() }
            switch (result) {
            case .success(let resp):
                response = resp
            case .failure(let error):
                restClientError = error
            }
        }
        self.wait(for: [expectation], timeout: 20)
        XCTAssertNil(restClientError, "Error should not have occurred")
        XCTAssertNotNil(response, "RestResponse should not be nil")
        
        struct Response: Decodable {
            struct Record: Decodable {
                struct Attributes: Decodable {
                    let type: String
                    let url: String
                }
                
                let attributes: Attributes
                let Id: String
            }
            
            let totalSize: Int
            let done: Bool
            let records: [Record]
        }
        
        XCTAssertNoThrow(try response?.asDecodable(type: Response.self), "RestResponse should be decodable")
    }
    
    private func generateRecordName() -> String {
        let timecode = Date.timeIntervalSinceReferenceDate
        return "SwiftTestsiOS\(timecode)"
    }
    
}
