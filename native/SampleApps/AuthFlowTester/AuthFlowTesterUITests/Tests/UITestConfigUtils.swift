/*
 UITestConfigUtils.swift
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
    case noThirdUser
    case noFourthUser
    case noFifthUser
    case userNotFound(String)
    case appNotFound(String)
    case appNotConfigured(String)
    case loginHostNotFound(String)
    
    var description: String {
        switch self {
        case .noPrimaryUser:
            return "No primary user found in ui_test_config.json"
        case .noSecondaryUser:
            return "No secondary user found in ui_test_config.json"
        case .noThirdUser:
            return "No third user found in ui_test_config.json"
        case .noFourthUser:
            return "No fourth user found in ui_test_config.json"
        case .noFifthUser:
            return "No fifth user found in ui_test_config.json"
        case .userNotFound(let username):
            return "User '\(username)' not found in ui_test_config.json"
        case .appNotFound(let appName):
            return "App '\(appName)' not found in ui_test_config.json"
        case .appNotConfigured(let appName):
            return "App '\(appName)' has empty consumerKey in ui_test_config.json"
        case .loginHostNotFound(let hostName):
            return "Login host '\(hostName)' not found in ui_test_config.json"
        }
    }
}

// MARK: - ScopeSelection
enum ScopeSelection {
    case empty // will not send scopes param - should be granted all the scopes defined on the server
    case all // will send all the scopes defined in ui_test_config.json
    case subset // will send a subset of the scopes defined in ui_test_config.json
}

// MARK: - Configured Users

enum KnownUserConfig {
    case first
    case second
    case third
    case fourth
    case fifth
}

// MARK: - Login Host Names

enum KnownLoginHostConfig: String {
    case regularAuth = "regular_auth"
    case advancedAuth = "advanced_auth"
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

/// Represents a login host configuration for testing
struct LoginHostConfig: Codable {
    let name: String
    let url: String
    let users: [UserConfig]
    
    /// Returns URL without protocol (https:// or http://)
    var urlNoProtocol: String {
        return url
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }
}

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
    let loginHosts: [LoginHostConfig]
    let apps: [AppConfig]
}

// MARK: - Configuration Utility

/// Utility class to parse and access test configuration from ui_test_config.json in the test bundle
class UITestConfigUtils {
    
    /// Shared singleton instance
    static let shared = UITestConfigUtils()
    
    /// Parsed test configuration (nil if not provided or parsing failed)
    private(set) var config: TestConfig?
    
    /// Error encountered during parsing (if any)
    private(set) var parseError: Error?
    
    private init() {
        parseConfiguration()
    }
    
    // MARK: - Configuration Parsing
    
    /// Parses the test configuration from ui_test_config.json file in the test bundle
    private func parseConfiguration() {
        // Get the bundle for this class
        let bundle = Bundle(for: UITestConfigUtils.self)
        
        // Look for ui_test_config.json file
        guard let configPath = bundle.path(forResource: "ui_test_config", ofType: "json") else {
            print("⚠️ ui_test_config.json file not found in test bundle")
            return
        }
        
        // Read the file contents
        guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: configPath)) else {
            let error = NSError(domain: "UITestConfigUtils", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to read ui_test_config.json file"])
            parseError = error
            print("❌ Failed to read ui_test_config.json file")
            return
        }
        
        // Parse JSON configuration
        do {
            let decoder = JSONDecoder()
            config = try decoder.decode(TestConfig.self, from: jsonData)
            print("✅ Test configuration loaded successfully from ui_test_config.json")
            print("   Login Hosts: \(config?.loginHosts.count ?? 0)")
            print("   Apps: \(config?.apps.count ?? 0)")
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
    
    /// Returns all login hosts from configuration
    var loginHosts: [LoginHostConfig] {
        return config?.loginHosts ?? []
    }
    
    /// Returns all apps from configuration
    var apps: [AppConfig] {
        return config?.apps ?? []
    }
    
    // MARK: - Scope Utilities
    
    /// Removes a scope from a space-separated scope string.
    ///
    /// - Parameters:
    ///   - scopes: Space-separated scope string.
    ///   - scopeToRemove: The scope to remove from the string.
    /// - Returns: Space-separated scope string with the specified scope removed.
    func removeScope(scopes: String, scopeToRemove: String) -> String {
        // Split the scopes string into an array
        let scopesArray = scopes.split(separator: " ")
        
        // Remove the specified scope
        let filteredScopes = scopesArray.filter { $0 != scopeToRemove }
        
        // Join the remaining scopes with space delimiter
        return filteredScopes.joined(separator: " ")
    }
    
    // MARK: - Throwing Accessors
    
    /// Returns a login host configuration by its name or throws an error if not found
    func getLoginHost(_ loginHost: KnownLoginHostConfig) throws -> LoginHostConfig {
        guard let hostConfig = config?.loginHosts.first(where: { $0.name == loginHost.rawValue }) else {
            throw TestConfigError.loginHostNotFound(loginHost.rawValue)
        }
        return hostConfig
    }
    
    /// Returns a user by their position (first, second, etc.) for a specific login host or throws an error if not found
    func getUser(_ loginHost: KnownLoginHostConfig, _ user: KnownUserConfig) throws -> UserConfig {
        let hostConfig = try getLoginHost(loginHost)
        
        switch user {
        case .first:
            guard let firstUser = hostConfig.users.first else {
                throw TestConfigError.noPrimaryUser
            }
            return firstUser
        case .second:
            guard hostConfig.users.count >= 2 else {
                throw TestConfigError.noSecondaryUser
            }
            return hostConfig.users[1]
        case .third:
            guard hostConfig.users.count >= 3 else {
                throw TestConfigError.noThirdUser
            }
            return hostConfig.users[2]
        case .fourth:
            guard hostConfig.users.count >= 4 else {
                throw TestConfigError.noFourthUser
            }
            return hostConfig.users[3]
        case .fifth:
            guard hostConfig.users.count >= 5 else {
                throw TestConfigError.noFifthUser
            }
            return hostConfig.users[4]
        }
    }
    
    /// Returns a known user config by their username for a specific login host or throws an error if not found
    func getKnownUserConfig(_ loginHost: KnownLoginHostConfig, byUsername username: String) throws -> KnownUserConfig {
        let hostConfig = try getLoginHost(loginHost)
        guard let index = hostConfig.users.firstIndex(where: { $0.username == username }) else {
            throw TestConfigError.userNotFound(username)
        }
        switch index {
        case 0: return .first
        case 1: return .second
        case 2: return .third
        case 3: return .fourth
        case 4: return .fifth
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
        case .subset: return removeScope(scopes: appConfig.scopes, scopeToRemove: "sfap_api") // that assumes the selected ca/eca/beacon has the sfap_api scope
        case .all: return appConfig.scopes
        }
    }

    /// Returns expected scopes granted
    func getExpectedScopesGranted(for appConfig:AppConfig, _ scopeSelection: ScopeSelection) -> String {
        switch(scopeSelection) {
        case .empty: return appConfig.scopes // that assumes the scopes in ui_test_config.json match the server config
        case .subset: return removeScope(scopes: appConfig.scopes, scopeToRemove: "sfap_api") // that assumes the selected ca/eca/beacon has the sfap_api scope
        case .all: return appConfig.scopes
        }
    }
}
