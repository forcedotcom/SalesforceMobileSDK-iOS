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

/// Helper functions for AuthFlowTester UI Tests
class TestHelper {
    
    /// Launches the app with test credentials for authenticated tests
    /// - Parameter app: The XCUIApplication instance to configure
    /// - Throws: If test_credentials.json cannot be loaded
    static func launchWithCredentials(_ app: XCUIApplication) throws {
        // Load test credentials from bundle
        guard let credentialsPath = Bundle(for: TestHelper.self).path(forResource: "test_credentials", ofType: "json") else {
            throw TestHelperError.credentialsFileNotFound
        }
        
        guard let credentialsData = try? Data(contentsOf: URL(fileURLWithPath: credentialsPath)) else {
            throw TestHelperError.credentialsFileNotReadable
        }
        
        // Minify JSON (remove newlines/whitespace) for passing via launch args
        let credentialsString: String
        if let jsonObject = try? JSONSerialization.jsonObject(with: credentialsData),
           let minifiedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
           let minifiedString = String(data: minifiedData, encoding: .utf8) {
            credentialsString = minifiedString
        } else if let asString = String(data: credentialsData, encoding: .utf8) {
            // Fallback: use original string if minification fails
            credentialsString = asString.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
        } else {
            throw TestHelperError.credentialsNotValidString
        }
        
        // Validate that credentials have been configured (not using default values)
        if credentialsString.contains("__INSERT_TOKEN_HERE__") ||
           credentialsString.contains("__INSERT_REMOTE_ACCESS_CLIENT_KEY_HERE__") ||
           credentialsString.contains("__INSERT_REMOTE_ACCESS_CALLBACK_URL_HERE__") {
            throw TestHelperError.credentialsNotConfigured
        }
        
        // Configure launch arguments
        app.launchArguments = [
            "-creds", credentialsString
        ]
        
        app.launch()
    }
    
    /// Launches the app in UI testing mode without credentials (unauthenticated tests)
    /// - Parameter app: The XCUIApplication instance to configure
    static func launchWithoutCredentials(_ app: XCUIApplication) {
        app.launchArguments = ["CONFIG_PICKER"]
        app.launch()
    }
}

/// Structure to hold bootconfig values loaded from plist
struct BootConfigData {
    let consumerKey: String
    let redirectURI: String
    let scopes: String
}

extension TestHelper {
    /// Loads a bootconfig plist (e.g. "bootconfig" or "bootconfig2") from the test bundle
    /// - Parameter name: The plist name without extension
    /// - Returns: Parsed BootConfigData
    /// - Throws: TestHelperError if the file cannot be found or parsed
    static func loadBootConfig(named name: String) throws -> BootConfigData {
        guard let url = Bundle(for: TestHelper.self).url(forResource: name, withExtension: "plist") else {
            throw TestHelperError.bootconfigFileNotFound(name)
        }
        guard let dict = NSDictionary(contentsOf: url) as? [String: Any] else {
            throw TestHelperError.bootconfigNotParseable(name)
        }
        guard let consumerKey = dict["remoteAccessConsumerKey"] as? String,
              let redirectURI = dict["oauthRedirectURI"] as? String else {
            throw TestHelperError.bootconfigMissingFields(name)
        }
        
        // Parse scopes (optional field) - convert array to space-separated string
        let scopes: String
        if let scopesArray = dict["oauthScopes"] as? [String] {
            scopes = scopesArray.sorted().joined(separator: " ")
        } else {
            scopes = "(none)"
        }
        
        return BootConfigData(consumerKey: consumerKey, redirectURI: redirectURI, scopes: scopes)
    }
}

/// Structure to hold test credentials loaded from test_credentials.json
/// This mirrors the structure of SFSDKTestCredentialsData from TestSetupUtils
struct TestCredentials {
    let username: String
    let instanceUrl: String
    let clientId: String
    let redirectUri: String
    let displayName: String
    let accessToken: String
    let refreshToken: String
    let identityUrl: String
    let organizationId: String
    let userId: String
    let photoUrl: String
    let loginDomain: String
    let scopes: String
    
    /// Loads test credentials from test_credentials.json in the test bundle
    /// This follows the same pattern as TestSetupUtils.populateAuthCredentialsFromConfigFileForClass
    /// - Returns: TestCredentials parsed from the JSON file
    /// - Throws: TestHelperError if the file cannot be loaded or parsed
    static func loadFromBundle() throws -> TestCredentials {
        // Load credentials file from bundle - similar to TestSetupUtils line 53
        guard let credentialsPath = Bundle(for: TestHelper.self).path(forResource: "test_credentials", ofType: "json") else {
            throw TestHelperError.credentialsFileNotFound
        }
        
        guard let credentialsData = try? Data(contentsOf: URL(fileURLWithPath: credentialsPath)) else {
            throw TestHelperError.credentialsFileNotReadable
        }
        
        // Parse JSON into dictionary - similar to TestSetupUtils line 56-57
        guard let jsonDict = try? JSONSerialization.jsonObject(with: credentialsData) as? [String: Any] else {
            throw TestHelperError.credentialsNotParseable(NSError(domain: "TestHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"]))
        }
        
        // Extract values from dictionary - similar to SFSDKTestCredentialsData property getters
        guard let username = jsonDict["username"] as? String,
              let instanceUrl = jsonDict["instance_url"] as? String,
              let clientId = jsonDict["test_client_id"] as? String,
              let redirectUri = jsonDict["test_redirect_uri"] as? String,
              let displayName = jsonDict["display_name"] as? String,
              let accessToken = jsonDict["access_token"] as? String,
              let refreshToken = jsonDict["refresh_token"] as? String,
              let identityUrl = jsonDict["identity_url"] as? String,
              let organizationId = jsonDict["organization_id"] as? String,
              let userId = jsonDict["user_id"] as? String,
              let photoUrl = jsonDict["photo_url"] as? String,
              let loginDomain = jsonDict["test_login_domain"] as? String else {
            throw TestHelperError.credentialsNotParseable(NSError(domain: "TestHelper", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing required credentials fields"]))
        }
        
        // Parse scopes (optional field) - convert array to space-separated string
        let scopes: String
        if let scopesArray = jsonDict["test_scopes"] as? [String] {
            scopes = scopesArray.sorted().joined(separator: ", ")
        } else {
            scopes = "(none)"
        }
        
        // Check if credentials have been configured - similar to TestSetupUtils line 135
        guard refreshToken != "__INSERT_TOKEN_HERE__" else {
            throw TestHelperError.credentialsNotConfigured
        }
        
        return TestCredentials(
            username: username,
            instanceUrl: instanceUrl,
            clientId: clientId,
            redirectUri: redirectUri,
            displayName: displayName,
            accessToken: accessToken,
            refreshToken: refreshToken,
            identityUrl: identityUrl,
            organizationId: organizationId,
            userId: userId,
            photoUrl: photoUrl,
            loginDomain: loginDomain,
            scopes: scopes
        )
    }
}

/// Errors that can occur during test setup
enum TestHelperError: Error, LocalizedError {
    case credentialsFileNotFound
    case credentialsFileNotReadable
    case credentialsNotValidString
    case credentialsNotConfigured
    case credentialsNotParseable(Error)
    case bootconfigFileNotFound(String)
    case bootconfigNotParseable(String)
    case bootconfigMissingFields(String)
    
    var errorDescription: String? {
        switch self {
        case .credentialsFileNotFound:
            return "test_credentials.json file not found in test bundle. Make sure it's added to Copy Bundle Resources."
        case .credentialsFileNotReadable:
            return "test_credentials.json file could not be read."
        case .credentialsNotValidString:
            return "test_credentials.json contains invalid UTF-8 data."
        case .credentialsNotConfigured:
            return """
                test_credentials.json has not been configured with real credentials.
                Please replace the placeholder values with actual test org credentials.
                """
        case .credentialsNotParseable(let error):
            return "test_credentials.json could not be parsed: \(error.localizedDescription)"
        case .bootconfigFileNotFound(let name):
            return "\(name).plist file not found in test bundle. Make sure it's added to Copy Bundle Resources."
        case .bootconfigNotParseable(let name):
            return "\(name).plist could not be parsed as a property list dictionary."
        case .bootconfigMissingFields(let name):
            return "\(name).plist is missing required keys: remoteAccessConsumerKey and/or oauthRedirectURI."
        }
    }
}

