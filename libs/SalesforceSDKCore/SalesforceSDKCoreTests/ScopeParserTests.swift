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

class ScopeParserTests: XCTestCase {
    
    // MARK: - Test Constants
    
    private let REFRESH_TOKEN = "refresh_token"
    private let API_SCOPE = "api"
    private let CHATTER_SCOPE = "chatter_api"
    private let CUSTOM_SCOPE = "custom_scope"
    
    // MARK: - computeScopeParameter Tests
    
    func testComputeScopeParameterWithNilScopes() {
        let result = ScopeParser.computeScopeParameter(scopes: nil)
        XCTAssertEqual(result, "", "Should return empty string for nil scopes")
    }
    
    func testComputeScopeParameterWithEmptyScopes() {
        let result = ScopeParser.computeScopeParameter(scopes: [])
        XCTAssertEqual(result, "", "Should return empty string for empty scopes")
    }
    
    func testComputeScopeParameterWithSingleScope() {
        let result = ScopeParser.computeScopeParameter(scopes: [API_SCOPE])
        
        // Should include both the original scope and refresh_token, sorted
        let expectedScopes = [API_SCOPE, REFRESH_TOKEN].sorted()
        let expectedResult = expectedScopes.joined(separator: " ")
        XCTAssertEqual(result, expectedResult, "Should include refresh_token and be sorted")
    }
    
    func testComputeScopeParameterWithMultipleScopes() {
        let result = ScopeParser.computeScopeParameter(scopes: [CHATTER_SCOPE, API_SCOPE, CUSTOM_SCOPE])
        
        // Should include all scopes plus refresh_token, sorted
        let expectedScopes = [API_SCOPE, CUSTOM_SCOPE, CHATTER_SCOPE, REFRESH_TOKEN].sorted()
        let expectedResult = expectedScopes.joined(separator: " ")
        XCTAssertEqual(result, expectedResult, "Should include all scopes plus refresh_token and be sorted")
    }
    
    func testComputeScopeParameterWithRefreshTokenAlreadyPresent() {
        let result = ScopeParser.computeScopeParameter(scopes: [API_SCOPE, REFRESH_TOKEN])
        
        // Should not duplicate refresh_token
        let expectedScopes = [API_SCOPE, REFRESH_TOKEN].sorted()
        let expectedResult = expectedScopes.joined(separator: " ")
        XCTAssertEqual(result, expectedResult, "Should not duplicate refresh_token")
    }
    
    // MARK: - computeScopeParameterWithURLEncoding Tests
    
    func testComputeScopeParameterWithURLEncodingNilScopes() {
        let result = ScopeParser.computeScopeParameterWithURLEncoding(scopes: nil)
        XCTAssertEqual(result, "", "Should return empty string for nil scopes")
    }
    
    func testComputeScopeParameterWithURLEncodingEmptyScopes() {
        let result = ScopeParser.computeScopeParameterWithURLEncoding(scopes: [])
        XCTAssertEqual(result, "", "Should return empty string for empty scopes")
    }
    
    func testComputeScopeParameterWithURLEncodingWithScopes() {
        let result = ScopeParser.computeScopeParameterWithURLEncoding(scopes: [API_SCOPE, REFRESH_TOKEN])
        
        // Should be URL encoded
        XCTAssertEqual(result, API_SCOPE + "%20" + REFRESH_TOKEN)
    }
}
