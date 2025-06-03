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
    
    func testAsyncFetchRecordsNonCombine() async {
        let request = RestClient.shared.request(forQuery: "select name from CONTACT", apiVersion: nil)
        
        do {
            let result = try await RestClient.shared.fetchRecords(ofModelType: TestContact.self, forRequest: request)
            XCTAssertNotNil(result, "Query call should not have failed")
        } catch {
            XCTFail("Fetch Record should not throw an error")
        }
    }
    
    func testQuery() async {
        let request = RestClient.shared.request(forQuery: "select name from CONTACT", apiVersion: nil)
        do {
            let result = try await RestClient.shared.send(request: request)
            XCTAssertNotNil(result, "Query call should not have failed")
        } catch {
            XCTFail("Fetch Record should not throw an error")
        }
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
    
    func testAsyncCompositeRequest() async throws {
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
        
        do {
            let compositeResponse = try await RestClient.shared.send(compositeRequest: compositeRequest)
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
        } catch {
            XCTFail("Send Composite Request should not throw an error")
        }
    }
    
    func testAsyncCompositeRequestFailure() async throws {
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
        
        do {
            let compositeResponse = try await RestClient.shared.send(compositeRequest: compositeRequest)
            XCTAssertNotNil(compositeResponse.subResponses, "Composite Sub Responses should not be nil")
            XCTAssertTrue(3 == compositeResponse.subResponses.count, "Wrong number of results")
            XCTAssertEqual(compositeResponse.subResponses[0].httpStatusCode, 400, "Wrong status for first request")
            XCTAssertEqual(compositeResponse.subResponses[1].httpStatusCode, 400, "Wrong status for second request")
            XCTAssertEqual(compositeResponse.subResponses[2].httpStatusCode, 400, "Wrong status for third request")
        } catch {
            XCTFail("Send Composite Request should not throw an error")
        }
    }
    
    func testAsyncCompositeRequestPartialSuccess() async throws {
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
        
        do {
            let compositeResponse = try await RestClient.shared.send(compositeRequest: compositeRequest)
            XCTAssertNotNil(compositeResponse.subResponses, "Composite Sub Responses should not be nil")
            XCTAssertTrue(3 == compositeResponse.subResponses.count, "Wrong number of results")
            XCTAssertEqual(compositeResponse.subResponses[0].httpStatusCode, 201, "Wrong status for first request")
            XCTAssertEqual(compositeResponse.subResponses[1].httpStatusCode, 201, "Wrong status for second request")
            XCTAssertEqual(compositeResponse.subResponses[2].httpStatusCode, 400, "Wrong status for third request")
        } catch {
            XCTFail("Send Composite Request should not throw an error")
        }
    }
    
    func testAsyncBatchRequest() async throws {
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
        
        
        do {
            let batchResponse = try await RestClient.shared.send(batchRequest: batchRequest)
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
        } catch {
            XCTFail("Send Batch Request should not throw an error")
        }
    }
    
    func testAsyncBatchRequestStopOnFailure() async throws {
        do {
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
            
            let batchResponse = try await RestClient.shared.send(batchRequest: batchRequest)
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
        } catch {
            XCTFail("Send Batch Request should not throw an error")
        }
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
    
    func testDecodableResponse() async throws {
        let apiVersion = RestClient.shared.apiVersion
        
        let query = "select Id from Account limit 5"
        let request = RestClient.shared.request(forQuery: query, apiVersion: apiVersion)
        
        do {
            let response = try await RestClient.shared.send(request: request)
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
            
            XCTAssertNoThrow(try response.asDecodable(type: Response.self), "RestResponse should be decodable")
        } catch {
            XCTFail("Send Batch Request should not throw an error")
        }
    }
    
    func testSendCompositeRequest_ThrowsOnInvalidResponseFormat() async {
        // Arrange: create a composite request with one valid subrequest
        let builder = CompositeRequestBuilder()
        let dummyRequest = RestRequest(method: .GET, path: "/dummy", queryParams: nil)
        let composite = builder
            .add(dummyRequest, referenceId: "ref1")
            .buildCompositeRequest("v56.0")

        // Inject mock client with bad response
        let mockClient = MockRestClient()
        mockClient.jsonResponse = """
            [ { "shouldBe": "a dictionary" } ]
        """.data(using: .utf8)! // Invalid top-level type
        
        // Act + Assert
        do {
            _ = try await mockClient.send(compositeRequest: composite)
            XCTFail("Expected an error for invalid response format")
        } catch let error as RestClientError {
            switch error {
            case .apiFailed(_, let underlyingError, _):
                let nsError = underlyingError as NSError
                XCTAssertEqual(nsError.localizedDescription, "CompositeResponse format invalid")
                XCTAssertEqual(nsError.domain, "API Error")
                XCTAssertEqual(nsError.code, 42)
            default:
                XCTFail("Unexpected RestClientError case: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSendURLRequestSuccess() async throws {
        // Given
        let request = URLRequest(url: URL(string: "https://test.salesforce.com")!)
        
        // When
        let (data, response) = try await RestClient.shared.send(urlRequest: request)
        
        // Then
        XCTAssertNotNil(data, "Response data should not be nil")
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }
    
    func testSendURLRequestNetworkError() async {
        // Given
        let request = URLRequest(url: URL(string: "https://invalid.salesforce.com")!)
        
        // When/Then
        do {
            _ = try await RestClient.shared.send(urlRequest: request)
            XCTFail("Expected error to be thrown")
        } catch {
            // Verify it's a RestClientError
            XCTAssertTrue(error is RestClientError, "Error should be RestClientError")
        }
    }
    
    func testSendURLRequestHTTPError() async {
        // Given
        let request = URLRequest(url: URL(string: "https://test.salesforce.com/services/data/v56.0/sobjects/InvalidObject")!)
        
        // When/Then
        do {
            _ = try await RestClient.shared.send(urlRequest: request)
            XCTFail("Expected error to be thrown")
        } catch let error as RestClientError {
            switch error {
            case .apiFailed(_, let underlyingError, let urlResponse):
                XCTAssertNotNil(underlyingError, "Underlying error should not be nil")
                XCTAssertNotNil(urlResponse, "URL response should not be nil")
                XCTAssertEqual((urlResponse as? HTTPURLResponse)?.statusCode, 400)
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSendBatchRequest_ThrowsOnInvalidResponseFormat() async {
        // Arrange: create a composite request with one valid subrequest
        let builder = BatchRequestBuilder()
        let dummyRequest = RestRequest(method: .GET, path: "/dummy", queryParams: nil)
        let batch = builder
            .add(dummyRequest)
            .buildBatchRequest("v56.0")

        // Inject mock client with bad response
        let mockClient = MockRestClient()
        mockClient.jsonResponse = """
            [ { "shouldBe": "a dictionary" } ]
        """.data(using: .utf8)! // Invalid top-level type
        
        // Act + Assert
        do {
            _ = try await mockClient.send(batchRequest: batch)
            XCTFail("Expected an error for invalid response format")
        } catch let error as RestClientError {
            switch error {
            case .apiFailed(_, let underlyingError, _):
                let nsError = underlyingError as NSError
                XCTAssertEqual(nsError.localizedDescription, "BatchResponse format invalid")
                XCTAssertEqual(nsError.domain, "API Error")
                XCTAssertEqual(nsError.code, 42)
            default:
                XCTFail("Unexpected RestClientError case: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    private func generateRecordName() -> String {
        let timecode = Date.timeIntervalSinceReferenceDate
        return "SwiftTestsiOS\(timecode)"
    }
    
}

final class RestClientWebSocketTests: XCTestCase {

    // Dummy delegate to satisfy the WebSocket call
    class DummyWebSocketDelegate: NSObject, URLSessionWebSocketDelegate {}

    func testNewWebSocketFromURLRequest() {
        // Given
        let request = RestRequest(method: .GET,
                                  serviceHostType: .login,
                                  path: "/a",
                                  queryParams: nil)
        
        
        guard let urlRequest = request.prepare(forSend: RestClient.shared.userAccount) else {
            XCTFail("Failed to prepare URLRequest from RestRequest")
            return
        }

        // When
        let socket = RestClient.shared.newWebSocket(
            from: urlRequest,
            delegate: DummyWebSocketDelegate()
        )
        socket.resume()

        // Then
        XCTAssertNotNil(socket, "WebSocket should not be nil")
        XCTAssertEqual(socket.state, .running, "WebSocket should be in running state after resume")

        // Cleanup
        socket.cancel(with: .goingAway, reason: nil)
    }
    
    func testNewWebSocketAppliesCustomAuthToken() {
        // Given
        let token = "test.jwt.token"
        var request = URLRequest(url: URL(string: "wss://example.com")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // When
        let socket = RestClient.shared.newWebSocket(from: request, delegate: DummyWebSocketDelegate())
        socket.resume()

        // Then
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(token)")
        socket.cancel(with: .goingAway, reason: nil)
    }
}
