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

// MARK: - Configuration Models

/// Represents an app configuration for testing
struct AppConfig: Codable {
    enum AppType: String, Codable {
        case ca = "ca"
        case eca = "eca"
        case beacon = "beacon"
    }
    
    let type: AppType
    let name: String
    let consumerKey: String
    let redirectUri: String
    let scopes: String
    let issuesJwt: Bool
    
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

/// Utility class to parse and access test configuration from command-line arguments
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
    
    /// Returns the first user (convenience method)
    var firstUser: UserConfig? {
        return config?.users.first
    }
    
    /// Returns the first app (convenience method)
    var firstApp: AppConfig? {
        return config?.apps.first
    }
    
    /// Returns app of a specific type
    func app(ofType type: AppConfig.AppType) -> AppConfig? {
        return config?.apps.first { $0.type == type }
    }
    
    /// Returns app by consumer key
    func app(withConsumerKey consumerKey: String) -> AppConfig? {
        return config?.apps.first { $0.consumerKey == consumerKey }
    }
    
    /// Returns app by name
    func app(withName name: String) -> AppConfig? {
        return config?.apps.first { $0.name == name }
    }
    
    /// Returns user by username
    func user(withUsername username: String) -> UserConfig? {
        return config?.users.first { $0.username == username }
    }
    
    // MARK: - Debug Helpers
    
    /// Prints the current configuration (for debugging)
    func printConfiguration() {
        guard let config = config else {
            print("No configuration loaded")
            return
        }
        
        print("=== Test Configuration ===")
        print("Login Host: \(config.loginHost)")
        print("\nApps (\(config.apps.count)):")
        for (index, app) in config.apps.enumerated() {
            print("  [\(index)] Name: \(app.name)")
            print("      Type: \(app.type.rawValue)")
            print("      Consumer Key: \(app.consumerKey)")
            print("      Redirect URI: \(app.redirectUri)")
            print("      Scopes: \(app.scopes.isEmpty ? "(none)" : app.scopes)")
            print("      Issues JWT: \(app.issuesJwt)")
        }
        print("\nUsers (\(config.users.count)):")
        for (index, user) in config.users.enumerated() {
            print("  [\(index)] Username: \(user.username)")
            print("      Password: [REDACTED]")
        }
        print("==========================")
    }
}

