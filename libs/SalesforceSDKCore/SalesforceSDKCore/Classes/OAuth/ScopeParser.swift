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

import Foundation

/**
 * Utility class for parsing and formatting OAuth scopes.
 * Based on the Android ScopeParser implementation.
 */
@objc(SFScopeParser)
public class ScopeParser: NSObject {
    
    // MARK: - Constants
    
    /// The refresh token scope that should always be included when explicit scopes are provided
    @objc public static let REFRESH_TOKEN = "refresh_token"
    
    /// The ID scope constant
    @objc public static let ID = "id"
    
    // MARK: - Private Properties
    
    private var _scopes: Set<String>
    
    // MARK: - Public Properties
    
    /// Returns the set of scopes
    @objc public var scopes: Set<String> {
        return _scopes
    }
    
    /// Returns the scopes as a space-delimited string
    @objc public var scopesAsString: String {
        if _scopes.isEmpty {
            return ""
        } else {
            return _scopes.sorted().joined(separator: " ")
        }
    }
    
    // MARK: - Initializers
    
    /**
     * Initializer that takes an array of scopes.
     *
     * - Parameter scopes: Array of scopes.
     */
    @objc public init(scopes: [String]?) {
        self._scopes = Set<String>()
        if let scopes = scopes {
            for scope in scopes {
                let trimmedScope = scope.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedScope.isEmpty {
                    self._scopes.insert(trimmedScope)
                }
            }
        }
    }
    
    /**
     * Initializer that takes a space-delimited scope string.
     *
     * - Parameter scopeString: Space-delimited scope string.
     */
    @objc public init(scopeString: String?) {
        self._scopes = Set<String>()
        if let scopeString = scopeString {
            let trimmedString = scopeString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedString.isEmpty {
                let scopes = trimmedString.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                self._scopes = Set(scopes)
            }
        }
    }
    
    // MARK: - Static Factory Methods
    
    /**
     * Factory method that creates a ScopeParser from a space-delimited scope string.
     *
     * - Parameter scopeString: Space-delimited scope string.
     * - Returns: ScopeParser instance.
     */
    @objc public static func parseScopes(_ scopeString: String?) -> ScopeParser {
        return ScopeParser(scopeString: scopeString)
    }
    
    // MARK: - Static Methods
    
    /**
     * Computes the scope parameter from an array of scopes.
     *
     * Behavior:
     * - If scopes is null or empty, returns an empty string. This indicates that all
     *   scopes assigned to the connected app / external client app will be requested by default
     *   (no explicit scope parameter is sent).
     * - If scopes is non-empty, ensures refresh_token is present in the set and
     *   returns a space-delimited string of unique, sorted scopes.
     *
     * - Parameter scopes: Array of scopes.
     * - Returns: Scope parameter string (possibly empty).
     */
    @objc public static func computeScopeParameter(scopes: Set<String>?) -> String {
        // If no scopes are provided, return an empty string. This indicates that all scopes
        // assigned to the connected app / external client app will be requested by default.
        guard let scopes = scopes, !scopes.isEmpty else {
            return ""
        }
        
        // When explicit scopes are provided, ensure REFRESH_TOKEN is included.
        var scopesSet = scopes
        scopesSet.insert(REFRESH_TOKEN)
        
        // Convert to sorted array and join with spaces
        let sortedScopes = scopesSet.sorted()
        return sortedScopes.joined(separator: " ")
    }
    
    /**
     * Computes the scope parameter string for OAuth requests with URL encoding.
     * 
     * - Parameter scopes: The array of OAuth scopes to include in the parameter
     * - Returns: A URL-encoded scope parameter string, or empty string if no scopes provided
     */
    @objc public static func computeScopeParameterWithURLEncoding(scopes: Set<String>?) -> String {
        let scopeString = computeScopeParameter(scopes: scopes)
        guard !scopeString.isEmpty else {
            return ""
        }
        
        // URL encode the scope string
        return scopeString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scopeString
    }
    
    // MARK: - Instance Methods
    
    /**
     * Checks whether the provided scope exists in this parser's scope set.
     *
     * - Parameter scope: Scope name to check.
     * - Returns: True if present, false otherwise.
     */
    @objc public func hasScope(_ scope: String?) -> Bool {
        guard let scope = scope, !scope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return _scopes.contains(scope.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    /**
     * Checks whether the refresh_token scope exists in this parser's scope set.
     *
     * - Returns: True if refresh_token scope is present, false otherwise.
     */
    @objc public func hasRefreshTokenScope() -> Bool {
        return hasScope(ScopeParser.REFRESH_TOKEN)
    }
    
    /**
     * Checks whether the id scope exists in this parser's scope set.
     *
     * - Returns: True if id scope is present, false otherwise.
     */
    @objc public func hasIdentityScope() -> Bool {
        return hasScope(ScopeParser.ID)
    }
}
