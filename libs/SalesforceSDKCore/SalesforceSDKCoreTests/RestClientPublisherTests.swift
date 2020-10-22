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
import Combine
@testable import SalesforceSDKCore

class RestClientPublisherTests: XCTestCase {
    
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
    
    func testQueryPublisher() {
        let request = RestClient.shared.request(forQuery: "select name from CONTACT", apiVersion: nil)
        let publisher = RestClient.shared.publisher(for: request)
        
        let validTest = evaluateResults(publisher: publisher)
        wait(for: validTest.expectations, timeout: 5)
        validTest.cancellable?.cancel()
    }
    
    func testRecordsPublisher() {
        let request = RestClient.shared.request(forQuery: "select name from CONTACT", apiVersion: nil)
        let publisher: AnyPublisher<RestClient.QueryResponse<TestContact>, Never> = RestClient.shared.records(forRequest: request)
        
        let validTest = evaluateResults(publisher: publisher)
        wait(for: validTest.expectations, timeout: 5)
        validTest.cancellable?.cancel()
    }
  
    func testCompositePublisher() {
        let accountName = self.generateRecordName()
        let contactName = self.generateRecordName()
        let apiVersion = RestClient.shared.apiVersion
        let requestBuilder = CompositeRequestBuilder()
            .add(RestClient.shared.requestForCreate(withObjectType: "Account", fields: ["Name": accountName], apiVersion: apiVersion), referenceId: "refAccount")
            .add(RestClient.shared.requestForCreate(withObjectType: "Contact", fields: ["LastName": contactName,"AccountId": "@{refAccount.id}"], apiVersion: apiVersion), referenceId: "refContact")
            .add(RestClient.shared.request(forQuery: "select Id, AccountId from Contact where LastName =  '\(contactName)'", apiVersion: apiVersion), referenceId: "refQuery")
            .setAllOrNone(true)
        
        let compositeRequest = requestBuilder.buildCompositeRequest(apiVersion)
        let publisher = RestClient.shared.publisher(for: compositeRequest)
        
        let validTest = evaluateResults(publisher: publisher)
        wait(for: validTest.expectations, timeout: 10)
        validTest.cancellable?.cancel()
    }

    func testBatchPublisher() {
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
        let publisher = RestClient.shared.publisher(for: batchRequest)
        
        let validTest = evaluateResults(publisher: publisher)
        wait(for: validTest.expectations, timeout: 10)
        validTest.cancellable?.cancel()
    }
    
    private func evaluateResults<T: Publisher>(publisher: T?, evaluateValidResult: Bool = true) ->  (expectations:[XCTestExpectation], cancellable: AnyCancellable?)  {
        let finished = expectation(description: "finished")
        let received = expectation(description: "received")
        let failed = expectation(description: "failed")
        
        if evaluateValidResult {
            failed.isInverted = true
        } else {
            received.isInverted = true
        }
        
        let cancellable = publisher?.sink (receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                XCTAssertNotNil(error)
                failed.fulfill()
            case .finished:
                finished.fulfill()
            }
        }, receiveValue: { response in
            XCTAssertNotNil(response)
            received.fulfill()
        })
        return (expectations: [finished, received, failed], cancellable: cancellable)
    }
    
    private func generateRecordName() -> String {
        let timecode = Date.timeIntervalSinceReferenceDate
        return "SwiftPublishersTestsiOS\(timecode)"
    }
    
}
