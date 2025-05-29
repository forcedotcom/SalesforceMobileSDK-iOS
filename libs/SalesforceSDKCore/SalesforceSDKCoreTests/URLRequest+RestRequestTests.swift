/*
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
 
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

class URLRequestRestRequestTests: XCTestCase {
    
    func testBasicURLRequestConversion() {
        // Given
        let url = URL(string: "https://example.com/api/v1/resource")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // When
        let restRequest = request.toRestRequest()
        
        // Then
        XCTAssertNotNil(restRequest)
        XCTAssertEqual(restRequest?.method, .GET)
        XCTAssertEqual(restRequest?.path, "/api/v1/resource")
        XCTAssertEqual(restRequest?.baseURL, "https://example.com")
        XCTAssertEqual(restRequest?.queryParams?.count, 0)
    }
    
    func testURLRequestWithQueryParameters() {
        // Given
        let url = URL(string: "https://example.com/api/v1/resource?param1=value1&param2=value2")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // When
        let restRequest = request.toRestRequest()
        
        // Then
        XCTAssertNotNil(restRequest)
        XCTAssertEqual(restRequest?.queryParams?["param1"] as? String, "value1")
        XCTAssertEqual(restRequest?.queryParams?["param2"] as? String, "value2")
    }
    
    func testURLRequestWithHeaders() {
        // Given
        let url = URL(string: "https://example.com/api/v1/resource")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer token123", forHTTPHeaderField: "Authorization")
        
        // When
        let restRequest = request.toRestRequest()
        
        // Then
        XCTAssertNotNil(restRequest)
        XCTAssertEqual(restRequest?.customHeaders?["Content-Type"] as! String, "application/json")
        XCTAssertEqual(restRequest?.customHeaders?["Authorization"] as! String, "Bearer token123")
    }
    
    func testURLRequestWithBody() {
        // Given
        let url = URL(string: "https://example.com/api/v1/resource")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = "{\"key\":\"value\"}".data(using: .utf8)
        request.httpBody = body
        
        // When
        let restRequest = request.toRestRequest()
        
        // Then
        XCTAssertNotNil(restRequest)
        XCTAssertEqual(restRequest?.method, .POST)
    }
    
    func testURLRequestWithTimeout() {
        // Given
        let url = URL(string: "https://example.com/api/v1/resource")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        
        // When
        let restRequest = request.toRestRequest()
        
        // Then
        XCTAssertNotNil(restRequest)
        XCTAssertEqual(restRequest?.timeoutInterval, 30)
    }
    
    func testInvalidURLRequest() {
        // Given
        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.url = nil
        
        // When
        let restRequest = request.toRestRequest()
        
        // Then
        XCTAssertNil(restRequest)
    }
    
    func testDifferentHTTPMethods() {
        // Test all supported HTTP methods
        let methods = ["GET", "POST", "PUT", "DELETE", "HEAD", "PATCH"]
        let expectedRestMethods: [RestRequest.Method] = [.GET, .POST, .PUT, .DELETE, .HEAD, .PATCH]
        
        for (index, method) in methods.enumerated() {
            // Given
            let url = URL(string: "https://example.com/api/v1/resource")!
            var request = URLRequest(url: url)
            request.httpMethod = method
            
            // When
            let restRequest = request.toRestRequest()
            
            // Then
            XCTAssertNotNil(restRequest)
            XCTAssertEqual(restRequest?.method, expectedRestMethods[index])
        }
    }

    func testURLRequestWithCustomEndpoint() {
        // Create a URLRequest with a custom endpoint
        let url = URL(string: "https://example.com/items/info/details")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Convert to RestRequest
        let restRequest = request.toRestRequest()
        
        // Verify conversion
        XCTAssertNotNil(restRequest)
        XCTAssertEqual(restRequest?.method, .GET)
        XCTAssertEqual(restRequest?.path, "/items/info/details")
        XCTAssertEqual(restRequest?.endpoint, "/items/info/details")
    }

    func testRoundTripConversion() {
        // Given
        let url = URL(string: "https://example.com/services/data/v57.0/sobjects/Account")!
        var originalRequest = URLRequest(url: url)
        originalRequest.httpMethod = "POST"
        originalRequest.timeoutInterval = 30

        originalRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        originalRequest.setValue("Bearer token123", forHTTPHeaderField: "Authorization")
        originalRequest.setValue("custom-value", forHTTPHeaderField: "X-Custom-Header")
        
        let bodyDict = [
            "Name": "Test Account",
            "Type": "Prospect",
            "Industry": "Technology",
            "BillingCity": "San Francisco"
        ]
        let bodyData = try? JSONSerialization.data(withJSONObject: bodyDict)
        originalRequest.httpBody = bodyData
        
        // When
        let restRequest = originalRequest.toRestRequest()
        let mockUser = UserAccount()
        let convertedRequest = restRequest?.prepare(forSend: mockUser)
        
        // Then
        XCTAssertNotNil(convertedRequest)
        
        XCTAssertEqual(convertedRequest?.url?.scheme, originalRequest.url?.scheme)
        XCTAssertEqual(convertedRequest?.url?.host, originalRequest.url?.host)
        XCTAssertEqual(convertedRequest?.url?.path, originalRequest.url?.path)

        XCTAssertEqual(convertedRequest?.httpMethod, originalRequest.httpMethod)
        
        XCTAssertEqual(convertedRequest?.value(forHTTPHeaderField: "Content-Type"), originalRequest.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertEqual(convertedRequest?.value(forHTTPHeaderField: "Authorization"), originalRequest.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(convertedRequest?.value(forHTTPHeaderField: "X-Custom-Header"), originalRequest.value(forHTTPHeaderField: "X-Custom-Header"))

        XCTAssertEqual(convertedRequest?.timeoutInterval, originalRequest.timeoutInterval)
        
        if let bodyStream = convertedRequest?.httpBodyStream {
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            
            bodyStream.open()
            let bytesRead = bodyStream.read(buffer, maxLength: bufferSize)
            bodyStream.close()
            
            XCTAssertGreaterThan(bytesRead, 0)
            if bytesRead > 0 {
                let data = Data(bytes: buffer, count: bytesRead)
                let streamDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                XCTAssertEqual(streamDict?["Name"] as? String, bodyDict["Name"])
                XCTAssertEqual(streamDict?["Type"] as? String, bodyDict["Type"])
                XCTAssertEqual(streamDict?["Industry"] as? String, bodyDict["Industry"])
                XCTAssertEqual(streamDict?["BillingCity"] as? String, bodyDict["BillingCity"])
            }
        }
    }
} 
