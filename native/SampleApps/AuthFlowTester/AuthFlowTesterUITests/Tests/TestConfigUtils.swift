/*
 TestConfigUtils.swift
 AuthFlowTesterUITests
 
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

import Foundation

// MARK: - Errors

enum TestConfigError: Error, CustomStringConvertible {
    case noPrimaryUser
    case noSecondaryUser
    case userNotFound(String)
    case appNotFound(String)
    case appNotConfigured(String)
    
    var description: String {
        switch self {
        case .noPrimaryUser:
            return "No primary user found in test_config.json"
        case .noSecondaryUser:
            return "No secondary user found in test_config.json"
        case .userNotFound(let username):
            return "User '\(username)' not found in test_config.json"
        case .appNotFound(let appName):
            return "App '\(appName)' not found in test_config.json"
        case .appNotConfigured(let appName):
            return "App '\(appName)' has empty consumerKey in test_config.json"
        }
    }
}

// MAKR: - ScopeSelection
enum ScopeSelection {
    case empty // will not send scopes param - should be granted all the scopes defined on the server
    case all // will send all the scopes defined in test_config.json
    case subset // will send a subset of the scopes defined in test_config.json
}

// MARK: - Configured Users

enum KnownUserConfig {
    case first
    case second
}

// MARK: - App Names

enum KnownAppConfig: String {
    case ecaBasicOpaque = "eca_basic_opaque"
    case ecaBasicJwt = "eca_basic_jwt"
    case ecaAdvancedOpaque = "eca_advanced_opaque"
    case ecaAdvancedJwt = "eca_advanced_jwt"
    case beaconBasicOpaque = "beacon_basic_opaque"
    case beaconBasicJwt = "beacon_basic_jwt"
    case beaconAdvancedOpaque = "beacon_advanced_opaque"
    case beaconAdvancedJwt = "beacon_advanced_jwt"
    case caBasicOpaque = "ca_basic_opaque"
    case caBasicJwt = "ca_basic_jwt"
    case caAdvancedOpaque = "ca_advanced_opaque"
    case caAdvancedJwt = "ca_advanced_jwt"
}

// MARK: - Configuration Models

/// Represents an app configuration for testing
struct AppConfig: Codable {
    let name: String
    let consumerKey: String
    let redirectUri: String
    let scopes: String
    
    /// Returns true if the app issues JWT tokens (name contains "_jwt")
    var issuesJwt: Bool {
        return name.contains("_jwt")
    }
    
    /// Returns scopes as an array
    var scopesArray: [String] {
        return scopes.split(separator: " ").map { String($0) }.filter { !$0.isEmpty }
    }
}

/// Represents a user configuration for testing
struct UserConfig: Codable {
    let username: String
    let password: String
}

/// Represents the complete test configuration
struct TestConfig: Codable {
    let loginHost: String
    let apps: [AppConfig]
    let users: [UserConfig]
}

// MARK: - Configuration Utility

/// Utility class to parse and access test configuration from test_config.json in the test bundle
class TestConfigUtils {
    
    /// Shared singleton instance
    static let shared = TestConfigUtils()
    
    /// Parsed test configuration (nil if not provided or parsing failed)
    private(set) var config: TestConfig?
    
    /// Error encountered during parsing (if any)
    private(set) var parseError: Error?
    
    private init() {
        parseConfiguration()
    }
    
    // MARK: - Configuration Parsing
    
    /// Parses the test configuration from test_config.json file in the test bundle
    private func parseConfiguration() {
        // Get the bundle for this class
        let bundle = Bundle(for: TestConfigUtils.self)
        
        // Look for test_config.json file
        guard let configPath = bundle.path(forResource: "test_config", ofType: "json") else {
            print("⚠️ test_config.json file not found in test bundle")
            return
        }
        
        // Read the file contents
        guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: configPath)) else {
            let error = NSError(domain: "TestConfigUtils", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to read test_config.json file"])
            parseError = error
            print("❌ Failed to read test_config.json file")
            return
        }
        
        // Parse JSON configuration
        do {
            let decoder = JSONDecoder()
            config = try decoder.decode(TestConfig.self, from: jsonData)
            print("✅ Test configuration loaded successfully from test_config.json")
            print("   Login Host: \(config?.loginHost ?? "none")")
            print("   Apps: \(config?.apps.count ?? 0)")
            print("   Users: \(config?.users.count ?? 0)")
        } catch {
            parseError = error
            print("❌ Failed to parse test configuration: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Configuration Access
    
    /// Returns true if configuration was successfully loaded
    var hasConfig: Bool {
        return config != nil
    }
    
    /// Returns the login host from configuration
    var loginHost: String? {
        return config?.loginHost
    }
    
    var loginHostNoProtocol: String? {
        return loginHost?
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }
    
    /// Returns all apps from configuration
    var apps: [AppConfig] {
        return config?.apps ?? []
    }
    
    /// Returns all users from configuration
    var users: [UserConfig] {
        return config?.users ?? []
    }
    
    // MARK: - Throwing Accessors
    
    /// Returns a user by their position (first or second) or throws an error if not found
    func getUser(_ user: KnownUserConfig) throws -> UserConfig {
        switch user {
        case .first:
            guard let firstUser = config?.users.first else {
                throw TestConfigError.noPrimaryUser
            }
            return firstUser
        case .second:
            guard let users = config?.users, users.count >= 2 else {
                throw TestConfigError.noSecondaryUser
            }
            return users[1]
        }
    }
    
    /// Returns a known user config by their username or throws an error if not found
    func getKnownUserConfig(byUsername username: String) throws -> KnownUserConfig {
        guard let users = config?.users,
              let index = users.firstIndex(where: { $0.username == username }) else {
            throw TestConfigError.userNotFound(username)
        }
        switch index {
        case 0: return .first
        case 1: return .second
        default: throw TestConfigError.userNotFound(username)
        }
    }
    
    /// Returns an app by its name or throws an error if not found or not configured
    func getApp(named name: KnownAppConfig) throws -> AppConfig {
        guard let app = config?.apps.first(where: { $0.name == name.rawValue }) else {
            throw TestConfigError.appNotFound(name.rawValue)
        }
        guard !app.consumerKey.isEmpty else {
            throw TestConfigError.appNotConfigured(name.rawValue)
        }
        return app
    }

    /// Returns scopes to request
    func getScopesToRequest(for appConfig: AppConfig, _ scopesParam: ScopeSelection) -> String {
        switch(scopesParam) {
        case .empty: return ""
        case .subset: return "api content id lightning refresh_token visualforce web" // that assumes the selected ca/eca/beacon has those scopes and more
        case .all: return appConfig.scopes
        }
    }

    /// Returns expected scopes granted
    func getExpectedScopesGranted(for appConfig:AppConfig, _ scopeSelection: ScopeSelection) -> String {
        switch(scopeSelection) {
        case .empty: return appConfig.scopes // that assumes the scopes in test_config.json match the server config
        case .subset: return "api content id lightning refresh_token visualforce web" // that assumes the selected ca/eca/beacon has those scopes and more
        case .all: return appConfig.scopes
        }
    }
}

