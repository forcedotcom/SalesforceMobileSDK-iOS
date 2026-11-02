/*
 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of
 conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list
 of conditions and the following disclaimer in the documentation and/or other materials
 provided with the distribution.
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
@_spi(Internal) import SalesforceSDKCore

class RequestUserAgentParsingTests: XCTestCase {
    func test_givenVersionedRESTCapture_whenMatchingStablePath_thenFreshOwnerAndUserAgentMatch() {
        let credentials = AuthFlowTesterMainPageObject.parseUserCredentials([
            CredentialsLabels.sdk: [CredentialsLabels.requestUserAgents: [
                ["path": "/services/data/v66.0", "userKey": "org/user", "userAgent": "rest-ua", "seq": 8]
            ]]
        ])
        XCTAssertEqual(credentials.requestUserAgents.count, 1)
        guard let entry = credentials.requestUserAgents.first else { return }
        XCTAssertTrue(BaseAuthFlowTester.matchesSentUserAgent(entry, path: "/services/data", userKey: "org/user", since: 7, expectedUserAgent: "rest-ua"), "No matching sent User-Agent for /services/data since 7")
        XCTAssertFalse(BaseAuthFlowTester.matchesSentUserAgent(entry, path: "/services/data", userKey: "org/user", since: 8, expectedUserAgent: "rest-ua"))
        XCTAssertFalse(BaseAuthFlowTester.matchesSentUserAgent(entry, path: "/services/data", userKey: "org/other", since: 7, expectedUserAgent: "rest-ua"))
        XCTAssertFalse(BaseAuthFlowTester.matchesSentUserAgent(entry, path: "/services/data", userKey: "org/user", since: 7, expectedUserAgent: "other-ua"))
    }

    func test_givenRESTPaths_whenMatchingStablePath_thenOnlyVersionedResourcesPathMatches() {
        for path in ["/services/data/v67.1", "/services/data/v100.0"] {
            let entry = RequestUserAgentCaptureEntry(path: path, userKey: "org/user", userAgent: "ua", sequence: 8)
            XCTAssertTrue(BaseAuthFlowTester.matchesSentUserAgent(entry, path: "/services/data", userKey: "org/user", since: 7, expectedUserAgent: "ua"), path)
        }
        for path in ["/services/data", "/services/data/", "/services/data/v66", "/services/data/v66.0/query", "/services/data/v66.0/", "/services/data/v66.0extra", "/services/database/v66.0", "/services/data/v66x0", "/services/data/v66.0\n"] {
            let entry = RequestUserAgentCaptureEntry(path: path, userKey: "org/user", userAgent: "ua", sequence: 8)
            XCTAssertFalse(BaseAuthFlowTester.matchesSentUserAgent(entry, path: "/services/data", userKey: "org/user", since: 7, expectedUserAgent: "ua"), path)
        }
    }

    func test_givenOAuthOrExplicitRESTPath_whenMatching_thenPathRemainsExact() {
        for path in ["/services/oauth2/token", "/services/oauth2/revoke", "/services/data/v66.0"] {
            let entry = RequestUserAgentCaptureEntry(path: path, userKey: "org/user", userAgent: "ua", sequence: 8)
            XCTAssertTrue(BaseAuthFlowTester.matchesSentUserAgent(entry, path: path, userKey: "org/user", since: 7, expectedUserAgent: "ua"))
            for differentPath in [path + "/", path + "extra", "/prefix" + path] {
                let other = RequestUserAgentCaptureEntry(path: differentPath, userKey: "org/user", userAgent: "ua", sequence: 8)
                XCTAssertFalse(BaseAuthFlowTester.matchesSentUserAgent(other, path: path, userKey: "org/user", since: 7, expectedUserAgent: "ua"))
            }
        }
    }

    func test_givenUserAgentWithFeatureMarkers_whenMatchingPreAccountRequest_thenStablePrefixMatches() {
        let preAccountUserAgent = "SalesforceMobileSDK/14.0 iOS/27.0 (iPhone) AuthFlowTester/1.0(1) Native uid_123 ftr_AI"
        let postAccountUserAgent = "SalesforceMobileSDK/14.0 iOS/27.0 (iPhone) AuthFlowTester/1.0(1) Native uid_123 ftr_A1.BW.DP"

        XCTAssertEqual(
            BaseAuthFlowTester.userAgentPrefixBeforeFeatureMarkers(preAccountUserAgent),
            BaseAuthFlowTester.userAgentPrefixBeforeFeatureMarkers(postAccountUserAgent)
        )
    }

    func test_givenLegacySDKExport_whenParsing_thenScalarsRemainAndEntriesAreEmpty() {
        let credentials = AuthFlowTesterMainPageObject.parseUserCredentials([
            CredentialsLabels.sdk: [CredentialsLabels.userAgent: "legacy-ua",
                                    CredentialsLabels.lastTokenRequestUserAgent: "legacy-token-ua",
                                    CredentialsLabels.lastTokenRequestUrl: "legacy-url"]
        ])
        XCTAssertEqual(credentials.userAgent, "legacy-ua")
        XCTAssertEqual(credentials.lastTokenRequestUserAgent, "legacy-token-ua")
        XCTAssertEqual(credentials.lastTokenRequestUrl, "legacy-url")
        XCTAssertTrue(credentials.requestUserAgents.isEmpty)
    }

    func test_givenMissingOrMalformedEntries_whenParsing_thenEntriesAreEmpty() {
        XCTAssertTrue(AuthFlowTesterMainPageObject.parseUserCredentials([:]).requestUserAgents.isEmpty)
        let credentials = AuthFlowTesterMainPageObject.parseUserCredentials([
            CredentialsLabels.sdk: [CredentialsLabels.userAgent: "current-ua",
                                    CredentialsLabels.requestUserAgents: [["path": "/services/oauth2/token"]]]
        ])
        XCTAssertEqual(credentials.userAgent, "current-ua")
        XCTAssertTrue(credentials.requestUserAgents.isEmpty)
    }

    func test_givenStructuredSDKExport_whenParsing_thenLegacyScalarsArePreserved() throws {
        let json = """
        {"SDK":{"User Agent":"current-ua","Last Token Request User Agent":"token-ua",
        "Last Token Request URL":"https://example.invalid/services/oauth2/token",
        "Request User Agents":[{"path":"/services/oauth2/token","userKey":"org/user","userAgent":"token-ua","seq":7}]}}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let credentials = AuthFlowTesterMainPageObject.parseUserCredentials(object)
        XCTAssertEqual(credentials.userAgent, "current-ua")
        XCTAssertEqual(credentials.lastTokenRequestUserAgent, "token-ua")
        XCTAssertEqual(credentials.lastTokenRequestUrl, "https://example.invalid/services/oauth2/token")
        XCTAssertEqual(credentials.requestUserAgents, [
            RequestUserAgentCaptureEntry(path: "/services/oauth2/token", userKey: "org/user", userAgent: "token-ua", sequence: 7)
        ])
    }
}
