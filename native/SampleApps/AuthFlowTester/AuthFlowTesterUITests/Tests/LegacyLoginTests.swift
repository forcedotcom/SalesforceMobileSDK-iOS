/*
 LegacyLoginTests.swift
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

import XCTest

/// Tests for legacy login flows including:
/// - Connected App (CA) configurations (traditional OAuth connected apps)
/// - User agent flow tests
/// - Default, subset, and all scope variations
/// - Hybrid flow (default behavior)
///
/// For non-hybrid flow tests, see LegacyLoginTestsNotHybrid which extends this class.
///
/// NB: Tests use the first user from ui_test_config.json
///
class LegacyLoginTests: BaseAuthFlowTester {

    // MARK: - Test Configuration

    /// Returns whether to use hybrid flow for tests.
    /// Subclasses can override this to test non-hybrid flows.
    func useHybridFlow() -> Bool {
        return true
    }

    // MARK: - CA Web Server Flow Tests

    /// Login with CA opaque using default scopes and web server flow.
    func testCAOpaque_DefaultScopes_WebServerFlow() throws {
        launchLoginAndValidate(staticAppConfigName: .caOpaque, useHybridFlow: useHybridFlow(), useDPoP: false)
    }

    /// Login with CA opaque using subset of scopes and web server flow.
    func testCAOpaque_SubsetScopes_WebServerFlow() throws {
        launchLoginAndValidate(staticAppConfigName: .caOpaque, staticScopeSelection: .subset, useHybridFlow: useHybridFlow(), useDPoP: false)
    }

    /// Login with CA opaque using all scopes and web server flow.
    func testCAOpaque_AllScopes_WebServerFlow() throws {
        launchLoginAndValidate(staticAppConfigName: .caOpaque, staticScopeSelection: .all, useHybridFlow: useHybridFlow(), useDPoP: false)
    }

    // MARK: - CA Web Server Flow Tests (In-App WebView)

    /// Login with CA opaque using default scopes, web server flow, and in-app WebView (advanced auth disabled).
    func testCAOpaque_DefaultScopes_WebServerFlow_InAppWebView() throws {
        launchLoginAndValidate(staticAppConfigName: .caOpaque, useHybridFlow: useHybridFlow(), forceAdvancedAuthentication: false, useDPoP: false)
    }

    /// Login with CA opaque using subset of scopes, web server flow, and in-app WebView (advanced auth disabled).
    func testCAOpaque_SubsetScopes_WebServerFlow_InAppWebView() throws {
        launchLoginAndValidate(staticAppConfigName: .caOpaque, staticScopeSelection: .subset, useHybridFlow: useHybridFlow(), forceAdvancedAuthentication: false, useDPoP: false)
    }

    /// Login with CA opaque using all scopes, web server flow, and in-app WebView (advanced auth disabled).
    func testCAOpaque_AllScopes_WebServerFlow_InAppWebView() throws {
        launchLoginAndValidate(staticAppConfigName: .caOpaque, staticScopeSelection: .all, useHybridFlow: useHybridFlow(), forceAdvancedAuthentication: false, useDPoP: false)
    }

    // MARK: - CA User Agent Flow Tests

    /// Login with CA opaque using default scopes and user agent flow.
    ///
    /// The user agent (implicit) flow is incompatible with forced advanced authentication, which
    /// always uses the web server flow. This test therefore disables advanced authentication so the
    /// legacy in-app WebView / user agent path is exercised. It is intentionally the only user
    /// agent flow test retained: scope-variation coverage lives on the web server flow (advanced
    /// auth on) tests above, which is the default path for the vast majority of apps.
    func testCAOpaque_DefaultScopes_UserAgentFlow() throws {
        launchLoginAndValidate(staticAppConfigName: .caOpaque, useWebServerFlow: false, useHybridFlow: useHybridFlow(), forceAdvancedAuthentication: false, useDPoP: false)
    }
}

