/*
 LoginForAdminTests.swift
 AuthFlowTesterUITests

 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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

/// Tests for the "Login for Admin" feature which forces browser-based (ASWebAuthenticationSession)
/// authentication to support phishing-resistant MFA for admin users.
///
/// The "Login for Admin" menu item in the login screen's Settings gear icon forces the
/// web server OAuth flow via native browser, regardless of the app's configured auth flow.
///
/// These tests verify Login for Admin works:
/// - With web server flow enabled (default)
/// - With web server flow disabled (user agent flow) - Login for Admin should still use web server flow
///
/// NB: Tests use the first user from ui_test_config.json
///
class LoginForAdminTests: BaseAuthFlowTester {

    // MARK: - Login for Admin with Web Server Flow Enabled

    /// Login for Admin with ECA opaque app, web server flow enabled (default).
    /// Verifies the admin browser auth flow works when web server flow is already the default.
    func testLoginForAdmin_WebServerFlowEnabled() throws {
        launchLoginAndValidate(
            staticAppConfigName: .ecaOpaque,
            loginForAdmin: true
        )
    }

    // MARK: - Login for Admin with Web Server Flow Disabled

    /// Login for Admin with ECA opaque app, web server flow disabled.
    /// Verifies Login for Admin forces web server flow even when the app is configured
    /// to use user agent flow.
    func testLoginForAdmin_WebServerFlowDisabled() throws {
        launchLoginAndValidate(
            staticAppConfigName: .ecaOpaque,
            useWebServerFlow: false,
            loginForAdmin: true
        )
    }
}
