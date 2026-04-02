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

class BootconfigTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testInitializationWithValidDictionary() {
        let configDict: [String: Any] = [
            "remoteAccessConsumerKey": "testConsumerKey",
            "oauthRedirectURI": "testRedirectURI",
            "oauthScopes": ["scope1", "scope2"],
            "shouldAuthenticate": true
        ]
        
        let appConfig = BootConfig(configDict)
        
        XCTAssertNotNil(appConfig)
        XCTAssertEqual(appConfig?.remoteAccessConsumerKey, "testConsumerKey")
        XCTAssertEqual(appConfig?.oauthRedirectURI, "testRedirectURI")
        XCTAssertEqual(appConfig?.oauthScopes, Set(["scope1", "scope2"]))
        XCTAssertTrue(appConfig?.shouldAuthenticateOnFirstLaunch ?? false)
    }
    
    func testInitializationWithEmptyDictionary() {
        let appConfig = BootConfig([:])
        
        XCTAssertNotNil(appConfig)
        XCTAssertEqual(appConfig?.remoteAccessConsumerKey, "")
        XCTAssertEqual(appConfig?.oauthRedirectURI, "")
        XCTAssertEqual(appConfig?.oauthScopes, Set<String>())
        XCTAssertTrue(appConfig?.shouldAuthenticateOnFirstLaunch ?? false) // Default value should be true
    }
    
    func testInitializationWithNonExistentConfigFile() {
        let nonExistentPath = "/path/to/non/existent/file.plist"
        let appConfig = BootConfig(nonExistentPath)
        
        XCTAssertNil(appConfig, "Should return nil for non-existent config file")
    }
    
    func testInitializationWithInvalidConfigFile() {
        // Create a temporary file with invalid plist content
        let tempDir = NSTemporaryDirectory()
        let configFilePath = (tempDir as NSString).appendingPathComponent("invalid_config.plist")
        
        let invalidContent = "This is not a valid plist file"
        try? invalidContent.write(toFile: configFilePath, atomically: true, encoding: .utf8)
        
        let appConfig = BootConfig(configFilePath)
        
        XCTAssertNil(appConfig, "Should return nil for invalid plist file")
        
        // Clean up
        try? FileManager.default.removeItem(atPath: configFilePath)
    }
    
    // MARK: - Validation Tests
    
    func testValidationWithValidConfiguration() {
        let configDict: [String: Any] = [
            "remoteAccessConsumerKey": "testConsumerKey",
            "oauthRedirectURI": "testRedirectURI",
            "oauthScopes": ["scope1", "scope2"],
        ]
        
        let appConfig = BootConfig(configDict)
        do {
            try appConfig?.validate()
            XCTAssertTrue(true, "Validation should pass with valid config")
        } catch {
            XCTFail("Validation should not throw with valid config: \(error)")
        }
    }
    
    func testValidationWithMissingConsumerKey() {
        let configDict: [String: Any] = [
            "oauthRedirectURI": "testRedirectURI"
        ]
        
        let appConfig = BootConfig(configDict)
        do {
            try appConfig?.validate()
            XCTFail("Validation should throw with missing consumer key")
        } catch {
            XCTAssertTrue(true, "Validation should throw with missing consumer key: \(error)")
        }
    }
    
    func testValidationWithEmptyConsumerKey() {
        let configDict: [String: Any] = [
            "remoteAccessConsumerKey": "",
            "oauthRedirectURI": "testRedirectURI"
        ]
        
        let appConfig = BootConfig(configDict)
        do {
            try appConfig?.validate()
            XCTFail("Validation should throw with empty consumer key")
        } catch {
            XCTAssertTrue(true, "Validation should throw with empty consumer key: \(error)")
        }
    }
    
    func testValidationWithMissingRedirectURI() {
        let configDict: [String: Any] = [
            "remoteAccessConsumerKey": "testConsumerKey"
        ]
        
        let appConfig = BootConfig(configDict)
        do {
            try appConfig?.validate()
            XCTFail("Validation should throw with missing redirect URI")
        } catch {
            XCTAssertTrue(true, "Validation should throw with missing redirect URI: \(error)")
        }
    }
    
    func testValidationWithEmptyRedirectURI() {
        let configDict: [String: Any] = [
            "remoteAccessConsumerKey": "testConsumerKey",
            "oauthRedirectURI": ""
        ]
        
        let appConfig = BootConfig(configDict)
        do {
            try appConfig?.validate()
            XCTFail("Validation should throw with empty redirect URI")
        } catch {
            XCTAssertTrue(true, "Validation should throw with empty redirect URI: \(error)")
        }
    }
    
    func testValidationWithEmptyOAuthScopes() {
        let configDict: [String: Any] = [
            "remoteAccessConsumerKey": "testConsumerKey",
            "oauthRedirectURI": "testRedirectURI",
            "oauthScopes": []
        ]
        
        let appConfig = BootConfig(configDict)
        do {
            try appConfig?.validate()
            XCTAssertTrue(true, "Validation should pass with empty oauth scopes")
        } catch {
            XCTFail("Validation should not throw with empty oauth scopes: \(error)")
        }
    }
    
    func testValidationWithNilOAuthScopes() {
        let configDict: [String: Any] = [
            "remoteAccessConsumerKey": "testConsumerKey",
            "oauthRedirectURI": "testRedirectURI"
        ]
        
        let appConfig = BootConfig(configDict)
        do {
            try appConfig?.validate()
            XCTAssertTrue(true, "Validation should pass with nil oauth scopes")
        } catch {
            XCTFail("Validation should not throw with nil oauth scopes: \(error)")
        }
    }
    
    // MARK: - Whitespace Trimming Test
    
    func testWhitespaceTrimming() {
        let configDict: [String: Any] = [
            "remoteAccessConsumerKey": "  testConsumerKey  ",
            "oauthRedirectURI": "  testRedirectURI  "
        ]
        
        let appConfig = BootConfig(configDict)
        
        XCTAssertEqual(appConfig?.remoteAccessConsumerKey, "testConsumerKey")
        XCTAssertEqual(appConfig?.oauthRedirectURI, "testRedirectURI")
    }
        
    // MARK: - Default Values Tests
    
    func testDefaultShouldAuthenticateValue() {
        let appConfig = BootConfig(nil)
        XCTAssertTrue(appConfig?.shouldAuthenticateOnFirstLaunch ?? false, "Default shouldAuthenticateOnFirstLaunch should be true")
    }
    
    func testExplicitShouldAuthenticateValue() {
        let configDict: [String: Any] = [
            "shouldAuthenticate": false
        ]
        
        let appConfig = BootConfig(configDict)
        XCTAssertFalse(appConfig?.shouldAuthenticateOnFirstLaunch ?? true, "Explicit shouldAuthenticateOnFirstLaunch value should be respected")
    }
    
    // MARK: - Class Methods Tests
    
    func testFromDefaultConfigFile() {
        // This test will return nil because bootconfig.plist doesn't exist in the test bundle
        let appConfig = BootConfig.fromDefaultConfigFile()
        XCTAssertNil(appConfig, "fromDefaultConfigFile should return nil when bootconfig.plist doesn't exist")
    }
    
    func testFromConfigFileWithValidPath() {
        // This test will return nil because the config file doesn't exist in the expected location
        // The BootConfig class looks for files in the main bundle's resource path
        let configFilePath = "test_config_class.plist"
        let appConfig = BootConfig.fromConfigFile(configFilePath)
        
        XCTAssertNil(appConfig, "fromConfigFile should return nil when config file doesn't exist in bundle")
    }
    
    func testFromConfigFileWithInvalidPath() {
        let nonExistentPath = "/path/to/non/existent/file.plist"
        let appConfig = BootConfig.fromConfigFile(nonExistentPath)
        
        XCTAssertNil(appConfig, "Should return nil for non-existent config file")
    }
        
    // MARK: - Edge Cases Tests
    
    func testValidationWithWhitespaceOnlyValues() {
        let configDict: [String: Any] = [
            "remoteAccessConsumerKey": "   ",
            "oauthRedirectURI": "   "
        ]
        
        let appConfig = BootConfig(configDict)
        do {
            try appConfig?.validate()
            XCTFail("Validation should throw with whitespace-only values")
        } catch {
            XCTAssertTrue(true, "Validation should throw with whitespace-only values: \(error)")
        }
    }
    
    func testOAuthScopesWithEmptyArray() {
        let configDict: [String: Any] = [
            "remoteAccessConsumerKey": "testConsumerKey",
            "oauthRedirectURI": "testRedirectURI",
            "oauthScopes": []
        ]
        
        let appConfig = BootConfig(configDict)
        
        XCTAssertNotNil(appConfig?.oauthScopes)
        XCTAssertEqual(appConfig?.oauthScopes.count, 0)
    }
    
    func testOAuthScopesWithDuplicateValues() {
        let configDict: [String: Any] = [
            "remoteAccessConsumerKey": "testConsumerKey",
            "oauthRedirectURI": "testRedirectURI",
            "oauthScopes": ["scope1", "scope2", "scope1"] // Duplicate scope1
        ]
        
        let appConfig = BootConfig(configDict)
        
        XCTAssertNotNil(appConfig?.oauthScopes)
        XCTAssertEqual(appConfig?.oauthScopes.count, 2) // Should deduplicate
        XCTAssertTrue(appConfig?.oauthScopes.contains("scope1") ?? false)
        XCTAssertTrue(appConfig?.oauthScopes.contains("scope2") ?? false)
    }
}
