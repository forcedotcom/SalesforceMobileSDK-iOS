/*
 UITestTimeouts.swift
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

import Foundation

/// Provides timeout values for UI test element waits.
/// Values come from the environment (`UI_TEST_SHORT_TIMEOUT`, `UI_TEST_LONG_TIMEOUT`,
/// `UI_TEST_NETWORK_TIMEOUT`) when set, otherwise from defaults.
/// CI workflows can pass larger timeouts via these env vars.
enum UITestTimeouts {
    /// Default short timeout in seconds (e.g. for quick UI state checks).
    private static let defaultShort: TimeInterval = 2
    /// Default long timeout in seconds (e.g. for page load or alert appearance).
    private static let defaultLong: TimeInterval = 10
    /// Default network timeout in seconds (e.g. for operations that hit real OAuth servers).
    private static let defaultNetwork: TimeInterval = 30

    private static func parseEnv(_ key: String) -> TimeInterval? {
        guard let raw = ProcessInfo.processInfo.environment[key],
              !raw.isEmpty,
              let value = TimeInterval(raw),
              value > 0 else { return nil }
        return value
    }

    /// Short timeout (seconds). Use for fast UI checks (e.g. menu items, close buttons).
    static var short: TimeInterval {
        parseEnv("UI_TEST_SHORT_TIMEOUT") ?? defaultShort
    }

    /// Long timeout (seconds). Use for page visibility, alerts, and general element waits.
    static var long: TimeInterval {
        parseEnv("UI_TEST_LONG_TIMEOUT") ?? defaultLong
    }

    /// Network timeout (seconds). Use for operations involving real server round-trips
    /// (e.g. OAuth login, WKWebView page loads hitting Salesforce endpoints).
    static var network: TimeInterval {
        parseEnv("UI_TEST_NETWORK_TIMEOUT") ?? defaultNetwork
    }
}
