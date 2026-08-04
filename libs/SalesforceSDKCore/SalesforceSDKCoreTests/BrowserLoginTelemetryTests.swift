/*
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
@testable import SalesforceSDKCore

/// Tests for the B-marker (why browser login was used) and L-marker (which login server type)
/// helpers added to SFUserAccountManager in W-23701450.
///
/// All tests are pure unit tests — no network calls, no sandbox org required.
/// The private helper methods are exposed via the `BrowserLoginTelemetryTesting` category
/// declared in SalesforceSDKCoreTests-Bridging-Header.h.
class BrowserLoginTelemetryTests: XCTestCase {

    private var accountManager: UserAccountManager { .shared }
    private var originalForceAdvancedAuth: Bool = true

    override func setUp() {
        super.setUp()
        // Capture the current value so we can restore it.
        // Use KVC to access the internal sdk_forceAdvancedAuthentication property.
        originalForceAdvancedAuth = (SalesforceManager.shared.value(forKey: "sdk_forceAdvancedAuthentication") as? Bool) ?? true
    }

    override func tearDown() {
        SalesforceManager.shared.setValue(originalForceAdvancedAuth, forKey: "sdk_forceAdvancedAuthentication")
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeSession(loginAsAdmin: Bool = false,
                              useBrowserAuth: Bool = false) -> SFSDKAuthSession {
        let request = SFSDKAuthRequest()
        request.oauthClientId = "testClientId"
        request.oauthCompletionUrl = "test://callback"
        request.loginHost = "login.salesforce.com"
        request.loginAsAdmin = loginAsAdmin
        request.useBrowserAuth = useBrowserAuth
        return SFSDKAuthSession(request, credentials: nil)
    }

    private func setForceAdvancedAuthentication(_ value: Bool) {
        SalesforceManager.shared.setValue(value, forKey: "sdk_forceAdvancedAuthentication")
    }

    // MARK: - B-marker tests

    /// B3: loginAsAdmin takes highest priority.
    func test_givenBrowserLoginViaLoginForAdmin_whenAuthCompletes_thenB3Returned() {
        let session = makeSession(loginAsAdmin: true, useBrowserAuth: false)
        let marker = accountManager._bMarkerForAuthSession(session, completedAuthType: SFOAuthTypeAdvancedBrowser)
        XCTAssertEqual(marker, kSFAppFeatureBrowserLoginForAdmin,
                       "loginAsAdmin should produce B3 (highest priority)")
    }

    /// B2: MDM-required browser auth (useBrowserAuth, no loginAsAdmin).
    func test_givenBrowserLoginViaMDM_whenAuthCompletes_thenB2Returned() {
        let session = makeSession(loginAsAdmin: false, useBrowserAuth: true)
        let marker = accountManager._bMarkerForAuthSession(session, completedAuthType: SFOAuthTypeAdvancedBrowser)
        XCTAssertEqual(marker, kSFAppFeatureBrowserLoginMDM,
                       "useBrowserAuth without loginAsAdmin should produce B2")
    }

    /// B4: forceAdvancedAuthentication SDK flag, no MDM or LFA.
    func test_givenBrowserLoginViaForceFlag_whenAuthCompletes_thenB4Returned() {
        setForceAdvancedAuthentication(true)
        let session = makeSession(loginAsAdmin: false, useBrowserAuth: false)
        let marker = accountManager._bMarkerForAuthSession(session, completedAuthType: SFOAuthTypeAdvancedBrowser)
        XCTAssertEqual(marker, kSFAppFeatureBrowserLoginForceFlag,
                       "sdk_forceAdvancedAuthentication=YES without MDM/LFA should produce B4")
    }

    /// B1: server auth-config required browser login (no other reasons set).
    func test_givenBrowserLoginViaServerAuthConfig_whenAuthCompletes_thenB1Returned() {
        setForceAdvancedAuthentication(false)
        let session = makeSession(loginAsAdmin: false, useBrowserAuth: false)
        let marker = accountManager._bMarkerForAuthSession(session, completedAuthType: SFOAuthTypeAdvancedBrowser)
        XCTAssertEqual(marker, kSFAppFeatureBrowserLoginServerAuthConfig,
                       "Browser login with no other reason flags should produce B1 (server auth-config)")
    }

    /// Non-browser login: refresh → no B-marker.
    func test_givenRefreshFlow_whenAuthCompletes_thenNoBMarkerReturned() {
        setForceAdvancedAuthentication(true)
        let session = makeSession(loginAsAdmin: false, useBrowserAuth: true)
        let marker = accountManager._bMarkerForAuthSession(session, completedAuthType: SFOAuthTypeRefresh)
        XCTAssertNil(marker, "Refresh flow should never produce a B-marker")
    }

    /// Non-browser login: user-agent → no B-marker.
    func test_givenNonBrowserLogin_whenAuthCompletes_thenNoBMarkerReturned() {
        setForceAdvancedAuthentication(false)
        let session = makeSession(loginAsAdmin: false, useBrowserAuth: false)
        let marker = accountManager._bMarkerForAuthSession(session, completedAuthType: SFOAuthTypeUserAgent)
        XCTAssertNil(marker, "Non-browser auth type should produce no B-marker")
    }

    /// Priority: B3 > B2. When both loginAsAdmin and useBrowserAuth are true, B3 wins.
    func test_givenLoginAsAdminAndMDMBothSet_whenAdvancedBrowser_thenB3Wins() {
        // Note: SFSDKAuthSession sets coordinator.useBrowserAuth = request.useBrowserAuth || request.loginAsAdmin,
        // but the request properties are inspected separately in the helper.
        let session = makeSession(loginAsAdmin: true, useBrowserAuth: true)
        let marker = accountManager._bMarkerForAuthSession(session, completedAuthType: SFOAuthTypeAdvancedBrowser)
        XCTAssertEqual(marker, kSFAppFeatureBrowserLoginForAdmin, "B3 must win over B2 when both are set")
    }

    /// Priority: B3 > B4. loginAsAdmin + forceAdvancedAuthentication → B3 wins.
    func test_givenLoginAsAdminAndForceFlagBothSet_whenAdvancedBrowser_thenB3Wins() {
        setForceAdvancedAuthentication(true)
        let session = makeSession(loginAsAdmin: true, useBrowserAuth: false)
        let marker = accountManager._bMarkerForAuthSession(session, completedAuthType: SFOAuthTypeAdvancedBrowser)
        XCTAssertEqual(marker, kSFAppFeatureBrowserLoginForAdmin, "B3 must win over B4 when both are set")
    }

    // MARK: - L-marker tests

    /// L1: production login server.
    func test_givenProductionLoginServer_whenAuthCompletes_thenL1Returned() {
        let marker = accountManager._lMarkerForDomain("login.salesforce.com", usedWelcomeDiscovery: false)
        XCTAssertEqual(marker, kSFAppFeatureLoginServerProduction, "login.salesforce.com should produce L1")
    }

    /// L2: sandbox login server.
    func test_givenSandboxLoginServer_whenAuthCompletes_thenL2Returned() {
        let marker = accountManager._lMarkerForDomain("test.salesforce.com", usedWelcomeDiscovery: false)
        XCTAssertEqual(marker, kSFAppFeatureLoginServerSandbox, "test.salesforce.com should produce L2")
    }

    /// L4: My Domain server (.my.salesforce.com suffix).
    func test_givenMyDomainLoginServer_whenAuthCompletes_thenL4Returned() {
        let marker = accountManager._lMarkerForDomain("acme.my.salesforce.com", usedWelcomeDiscovery: false)
        XCTAssertEqual(marker, kSFAppFeatureLoginServerMyDomain, "My Domain host should produce L4")
    }

    /// L3: Welcome Discovery was used (flag set before WD global is cleared).
    func test_givenWelcomeDiscoveryLogin_whenAuthCompletes_thenL3Returned() {
        // Regardless of the resolved domain, when WD was used, L3 takes priority.
        let marker = accountManager._lMarkerForDomain("acme.my.salesforce.com", usedWelcomeDiscovery: true)
        XCTAssertEqual(marker, kSFAppFeatureLoginServerWelcomeDiscovery, "WD flag set should produce L3")
    }

    /// L3 priority: even production domain yields L3 if WD was used (edge case).
    func test_givenWelcomeDiscoveryWithProductionDomain_whenAuthCompletes_thenL3Returned() {
        let marker = accountManager._lMarkerForDomain("login.salesforce.com", usedWelcomeDiscovery: true)
        XCTAssertEqual(marker, kSFAppFeatureLoginServerWelcomeDiscovery, "WD flag always takes priority (even over L1)")
    }

    /// Exactly one L-marker: no other L-markers should be set when L1 is expected.
    func test_givenProductionServer_whenLMarkerEvaluated_thenOnlyL1IsNonNil() {
        let allLCodes: [String] = [
            kSFAppFeatureLoginServerProduction,
            kSFAppFeatureLoginServerSandbox,
            kSFAppFeatureLoginServerMyDomain,
            kSFAppFeatureLoginServerWelcomeDiscovery,
            kSFAppFeatureLoginServerCustom
        ]
        let result = accountManager._lMarkerForDomain("login.salesforce.com", usedWelcomeDiscovery: false)
        XCTAssertEqual(result, kSFAppFeatureLoginServerProduction)
        // The helper returns a single string — callers register exactly that one.
        // Verify no other code could match for this input.
        for code in allLCodes where code != kSFAppFeatureLoginServerProduction {
            XCTAssertNotEqual(result, code, "No other L-marker should be returned for production login server")
        }
    }

    /// Exactly one B-marker: no other B-markers should be returned for B3 scenario.
    func test_givenLoginForAdmin_whenBMarkerEvaluated_thenOnlyB3IsNonNil() {
        let allBCodes: [String] = [
            kSFAppFeatureBrowserLoginServerAuthConfig,
            kSFAppFeatureBrowserLoginMDM,
            kSFAppFeatureBrowserLoginForAdmin,
            kSFAppFeatureBrowserLoginForceFlag
        ]
        let session = makeSession(loginAsAdmin: true, useBrowserAuth: true)
        let result = accountManager._bMarkerForAuthSession(session, completedAuthType: SFOAuthTypeAdvancedBrowser)
        XCTAssertEqual(result, kSFAppFeatureBrowserLoginForAdmin)
        for code in allBCodes where code != kSFAppFeatureBrowserLoginForAdmin {
            XCTAssertNotEqual(result, code, "No other B-marker should be returned when loginAsAdmin is set")
        }
    }
}
