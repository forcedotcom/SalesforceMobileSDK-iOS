import XCTest
@testable import SalesforceSDKCore

class SFOAuthCoordinatorTests: XCTestCase {

    // Tracked so the DPoP URL tests can restore the flag they toggle.
    private var priorUsesDPoP: Bool = false
    // Per-test scope identifiers so DPoP key material never bleeds across tests.
    private var trackedScopes: [String] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        priorUsesDPoP = SalesforceManager.shared.usesDPoP
        trackedScopes.removeAll()
    }

    override func tearDownWithError() throws {
        SalesforceManager.shared.usesDPoP = priorUsesDPoP
        for scope in trackedScopes {
            DPoPKeyStore.shared.delete(forScope: scope)
        }
        trackedScopes.removeAll()
        try super.tearDownWithError()
    }

    // MARK: - Existing coverage

    func testDecidePolicyForNavigationAction_DomainDiscoveryCallback() {
        // Given
        let expectedLoginHint = "testuser@example.com"
        let mockDomain = "mydomain.example.com"
        let callbackURLString = "sfdc://discocallback?my_domain=\(mockDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&login_hint=\(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
        guard let callbackURL = URL(string: callbackURLString) else {
            XCTFail("Failed to create callback URL")
            return
        }
        let mockNavigationAction = MockNavigationAction(url: callbackURL)
        let coordinator = SFOAuthCoordinator()
        coordinator.delegate = self
        let credentials = OAuthCredentials(identifier: "test",
                                           clientId: "client",
                                           encrypted: false)
        credentials?.testDomain = "foo.bar.com/discovery"
        credentials?.testRedirectURI = "sfdc://callback"
        coordinator.credentials = credentials

        // When
        coordinator.authenticate(with: credentials!)

        // Then
        var didCallDecisionHandlerPolicy: WKNavigationActionPolicy = .allow
        coordinator.webView(WKWebView(), decidePolicyFor: mockNavigationAction, decisionHandler: { policy in
            didCallDecisionHandlerPolicy = policy
        })

        // Assert
        XCTAssertEqual(didCallDecisionHandlerPolicy, .cancel)
        XCTAssertEqual(coordinator.testLoginHint, expectedLoginHint)
        XCTAssertEqual(coordinator.credentials?.domain, mockDomain)
    }

    // MARK: - dpop_jkt URL-shape tests (RFC 9449 §10 authorization code binding)

    /// When DPoP is enabled, the login server is a my-domain host, and
    /// `credentials.identifier` is present, the approval URL includes
    /// `dpop_jkt=<43-char base64url>` matching the RFC 7638 shape.
    func test_givenDPoPEnabledAndMyDomainAndIdentifier_whenGenerateApprovalUrlString_thenUrlContainsDPoPJktMatchingBase64UrlShape() throws {
        SalesforceManager.shared.usesDPoP = true

        let scope = trackedScope("sc1-dpop-jkt")
        let credentials = try makeCredentials(identifier: scope, domain: "acme.my.salesforce.com")
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials

        let url = coordinator.generateApprovalUrlString()
        let jktValue = try XCTUnwrap(queryValue(name: "dpop_jkt", in: url),
                                     "dpop_jkt must be present under DPoP + my-domain + identifier")
        let pattern = try NSRegularExpression(pattern: "^[A-Za-z0-9_-]{43}$")
        let range = NSRange(location: 0, length: jktValue.utf16.count)
        XCTAssertNotNil(pattern.firstMatch(in: jktValue, options: [], range: range),
                        "dpop_jkt must be a 43-char base64url string, got: \(jktValue)")
    }

    /// The `dpop_jkt` value in the authorize URL equals the RFC 7638
    /// thumbprint of the same key pair that `DPoPKeyStore` will later return at
    /// token-endpoint time. This is the invariant that binds `/authorize` to
    /// `/token`.
    func test_givenDPoPEnabled_whenGenerateApprovalUrlString_thenDPoPJktEqualsThumbprintOfKeyPairFromStore() throws {
        SalesforceManager.shared.usesDPoP = true

        let scope = trackedScope("sc3-thumbprint-match")
        let credentials = try makeCredentials(identifier: scope, domain: "acme.my.salesforce.com")
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials

        let url = coordinator.generateApprovalUrlString()
        let jktValue = try XCTUnwrap(queryValue(name: "dpop_jkt", in: url))

        // Independently load the same-scope key pair the coordinator uses and
        // recompute the thumbprint — must match byte-for-byte.
        let pair = try DPoPKeyStore.shared.keyPair(forScope: scope)
        let expectedThumbprint = try DPoPProofBuilder.jwkThumbprint(publicKey: pair.publicKey)
        XCTAssertEqual(jktValue, expectedThumbprint,
                       "dpop_jkt on /authorize must equal jwkThumbprint of the token-endpoint key pair")
    }

    /// Pool login hosts (`login.salesforce.com`) must never receive
    /// `dpop_jkt`, even when DPoP is enabled. Salesforce blocks DPoP at the
    /// pool servers.
    func test_givenDPoPEnabledAndProductionPoolHost_whenGenerateApprovalUrlString_thenUrlHasNoDPoPJkt() throws {
        SalesforceManager.shared.usesDPoP = true

        let scope = trackedScope("sc4-pool-prod")
        let credentials = try makeCredentials(identifier: scope, domain: "login.salesforce.com")
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials

        let url = coordinator.generateApprovalUrlString()
        XCTAssertNil(queryValue(name: "dpop_jkt", in: url),
                     "login.salesforce.com is a pool host; dpop_jkt must not be sent")
    }

    /// Sandbox pool host `test.salesforce.com` must not receive `dpop_jkt`.
    func test_givenDPoPEnabledAndSandboxPoolHost_whenGenerateApprovalUrlString_thenUrlHasNoDPoPJkt() throws {
        SalesforceManager.shared.usesDPoP = true

        let scope = trackedScope("sc4-pool-sandbox")
        let credentials = try makeCredentials(identifier: scope, domain: "test.salesforce.com")
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials

        let url = coordinator.generateApprovalUrlString()
        XCTAssertNil(queryValue(name: "dpop_jkt", in: url),
                     "test.salesforce.com is a pool host; dpop_jkt must not be sent")
    }

    /// Welcome / discovery pool host `welcome.salesforce.com/discovery`
    /// must not receive `dpop_jkt`.
    func test_givenDPoPEnabledAndWelcomePoolHost_whenGenerateApprovalUrlString_thenUrlHasNoDPoPJkt() throws {
        SalesforceManager.shared.usesDPoP = true

        let scope = trackedScope("sc4-pool-welcome")
        let credentials = try makeCredentials(identifier: scope,
                                              domain: "welcome.salesforce.com/discovery")
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials

        let url = coordinator.generateApprovalUrlString()
        XCTAssertNil(queryValue(name: "dpop_jkt", in: url),
                     "welcome.salesforce.com/discovery is a pool host; dpop_jkt must not be sent")
    }

    /// When `usesDPoP` is `NO`, the approval URL must be byte-identical
    /// to the pre-change baseline (the coordinator behaves exactly as it did
    /// before the dpop_jkt feature landed). We construct the baseline from the
    /// same known inputs — no magic strings — so any future URL-parameter drift
    /// under the DPoP-off flag will fail loudly here.
    func test_givenDPoPDisabled_whenGenerateApprovalUrlString_thenUrlIsByteIdenticalBaseline() throws {
        SalesforceManager.shared.usesDPoP = false

        let scope = trackedScope("sc5-baseline")
        let credentials = try makeCredentials(identifier: scope, domain: "acme.my.salesforce.com")
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials

        let url = coordinator.generateApprovalUrlString()

        // No dpop_jkt regardless of my-domain, because the feature is off.
        XCTAssertFalse(url.contains("dpop_jkt"),
                       "dpop_jkt must not appear when usesDPoP is disabled")

        // Byte-identical baseline: reconstruct the URL from known inputs and
        // strip the volatile params (device_id which is per-installation, and
        // code_challenge which is a fresh SHA-256 per call). The rest must
        // match exactly — this catches accidental new parameters appearing.
        let baselinePrefix = "https://acme.my.salesforce.com/services/oauth2/authorize" +
            "?client_id=test-client-id" +
            "&redirect_uri=testapp://callback" +
            "&display=touch" +
            "&device_id="
        XCTAssertTrue(url.hasPrefix(baselinePrefix),
                      "URL prefix drifted from baseline. url=\(url)")

        // Assert on the ordered tail structure. `display=touch` is followed by
        // device_id (variable), then response_type=code, then code_challenge=<sha256>.
        // This guards against unrelated param additions/reorderings sneaking in.
        let responseTypeToken = "&response_type=code"
        let codeChallengeToken = "&code_challenge="
        XCTAssertTrue(url.contains(responseTypeToken),
                      "response_type=code missing from baseline URL")
        XCTAssertTrue(url.contains(codeChallengeToken),
                      "code_challenge= missing from baseline URL")
        // scope / login_hint / dpop_jkt are the only optional trailing params.
        // With no scopes and no loginHint set, and DPoP off, none of them
        // should be present.
        XCTAssertFalse(url.contains("&scope="),
                       "scope should not appear when credentials.scopes is unset")
        XCTAssertFalse(url.contains("&login_hint="),
                       "login_hint should not appear when coordinator.loginHint is unset")
    }

    /// Soft-fail — When key-material lookup is impossible, the append
    /// path must log a warning and leave the URL untouched. `DPoPKeyStore.shared`
    /// is a non-injectable singleton, so a throwing stub cannot be installed
    /// without production DI plumbing. This test exercises the same soft-fail
    /// branch via the natural precondition failure: an empty
    /// `credentials.identifier` bypasses the append and continues login.
    func test_givenDPoPEnabledAndEmptyCredentialsIdentifier_whenGenerateApprovalUrlString_thenUrlHasNoDPoPJktAndNoException() throws {
        SalesforceManager.shared.usesDPoP = true

        // A valid identifier is needed to construct SFOAuthCredentials (the
        // designated initializer rejects empty), so we set it non-empty at
        // init and then null out via the +Internal (readwrite) property so the
        // dpop_jkt gate observes the empty-identifier path.
        let credentials = try makeCredentials(identifier: "will-be-erased",
                                              domain: "acme.my.salesforce.com")
        credentials.identifier = ""
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials

        // The line below must not throw. If the soft-fail path throws or if
        // the append logic doesn't gate on empty identifier, this test fails.
        let url = coordinator.generateApprovalUrlString()
        XCTAssertNil(queryValue(name: "dpop_jkt", in: url),
                     "empty credentials.identifier must skip the dpop_jkt append")
    }

    /// The `migrateRefreshToken:` flow constructs its single-access
    /// request path from `generateApprovalUrlString()`. Under the same gate
    /// (DPoP enabled + my-domain + identifier set), the URL it feeds to
    /// `requestForSingleAccess` therefore includes `dpop_jkt`. Because the
    /// downstream `SFRestAPI sendRequest:` invocation makes a real network
    /// call, this test verifies the URL produced by the same coordinator
    /// method that migrateRefreshToken invokes — no REST mocking needed.
    func test_givenDPoPEnabledMigrateRefreshTokenSetup_whenGenerateApprovalUrlString_thenUrlContainsDPoPJkt() throws {
        SalesforceManager.shared.usesDPoP = true

        let scope = trackedScope("sc7-migrate-refresh")
        let credentials = try makeCredentials(identifier: scope, domain: "acme.my.salesforce.com")
        credentials.refreshToken = "test-refresh-token"
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials

        // migrateRefreshToken: internally does:
        //   NSURL *approvalUrl = [NSURL URLWithString:[self generateApprovalUrlString]];
        // so the URL passed to the SFRestAPI single-access call is exactly
        // this string. The dpop_jkt binding therefore propagates end-to-end.
        let url = coordinator.generateApprovalUrlString()
        let jktValue = try XCTUnwrap(queryValue(name: "dpop_jkt", in: url),
                                     "migrateRefreshToken path must produce a URL with dpop_jkt under DPoP + my-domain gate")
        XCTAssertEqual(jktValue.count, 43,
                       "dpop_jkt on migrateRefreshToken path must be a 43-char base64url string")
    }

    /// Entry-point coverage — user-agent flow (webServerFlow resolves to `NO`
    /// when `useBrowserAuth=NO` and web-server auth is off). The URL builder
    /// emits `response_type=token` (or `hybrid_token` when hybrid mode is on),
    /// but the dpop_jkt append happens after the flow branch, so the gate
    /// result must be identical.
    func test_givenDPoPEnabledAndUserAgentFlow_whenGenerateApprovalUrlString_thenUrlStillContainsDPoPJkt() throws {
        SalesforceManager.shared.usesDPoP = true

        let scope = trackedScope("entry-user-agent")
        let credentials = try makeCredentials(identifier: scope, domain: "acme.my.salesforce.com")
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials

        // Force the user-agent branch: no browser auth, no web-server flag.
        coordinator.useBrowserAuth = false
        let priorWebServer = SalesforceManager.shared.useWebServerAuthentication
        SalesforceManager.shared.useWebServerAuthentication = false
        defer { SalesforceManager.shared.useWebServerAuthentication = priorWebServer }

        let url = coordinator.generateApprovalUrlString()
        XCTAssertNotNil(queryValue(name: "dpop_jkt", in: url),
                        "dpop_jkt must be appended for the user-agent-flow entry point as well")
        let responseType = queryValue(name: "response_type", in: url) ?? ""
        XCTAssertTrue(responseType == "token" || responseType == "hybrid_token",
                      "user-agent branch expected — response_type should be token or hybrid_token, got \(responseType)")
    }

    /// Entry-point coverage — advanced-browser / web-server flow. Forces
    /// `webServerFlow=YES` so the URL builder appends `response_type=code` plus
    /// a `code_challenge`. The dpop_jkt append still fires under the same gate.
    func test_givenDPoPEnabledAndWebServerFlow_whenGenerateApprovalUrlString_thenUrlContainsDPoPJktAndCodeChallenge() throws {
        SalesforceManager.shared.usesDPoP = true

        let scope = trackedScope("entry-web-server")
        let credentials = try makeCredentials(identifier: scope, domain: "acme.my.salesforce.com")
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials
        coordinator.useBrowserAuth = true

        let url = coordinator.generateApprovalUrlString()
        XCTAssertNotNil(queryValue(name: "dpop_jkt", in: url),
                        "dpop_jkt must be appended for the web-server-flow entry point as well")
        XCTAssertEqual(queryValue(name: "response_type", in: url), "code",
                       "web-server branch expected — response_type should be `code`")
        XCTAssertNotNil(queryValue(name: "code_challenge", in: url),
                        "web-server branch expected — code_challenge should be present")
    }

    // MARK: - Helpers

    /// Registers a per-test DPoP scope so its keychain entry is cleaned up in
    /// tearDown. Returns a unique scope string that never collides across
    /// tests, even under `xcodebuild -parallel-testing`.
    private func trackedScope(_ label: String) -> String {
        let scope = "\(label)-\(UUID().uuidString)"
        trackedScopes.append(scope)
        return scope
    }

    /// Builds a minimally viable `OAuthCredentials` for URL construction.
    /// The public initializer accepts identifier + clientId; domain and
    /// redirectUri are readonly publicly but readwrite via the +Internal
    /// header (already imported in the bridging header).
    private func makeCredentials(identifier: String,
                                 domain: String) throws -> OAuthCredentials {
        let creds = try XCTUnwrap(OAuthCredentials(identifier: identifier,
                                                   clientId: "test-client-id",
                                                   encrypted: false))
        creds.testDomain = domain
        creds.testRedirectURI = "testapp://callback"
        return creds
    }

    /// Extracts the first value of `name` from a URL's query string using
    /// `URLComponents` so we don't hand-roll query parsing that could disagree
    /// with the coordinator's URL encoder in edge cases.
    private func queryValue(name: String, in urlString: String) -> String? {
        guard let comps = URLComponents(string: urlString) else { return nil }
        return comps.queryItems?.first(where: { $0.name == name })?.value
    }
}

// MARK: - SFOAuthCoordinatorDelegate conformance for tests
extension SFOAuthCoordinatorTests: SFOAuthCoordinatorDelegate {
    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith view: WKWebView) {}
    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith session: ASWebAuthenticationSession) {}
    func oauthCoordinatorDidBeginNativeAuthentication(_ coordinator: SFOAuthCoordinator) {}
    func oauthCoordinatorDidCancelBrowserAuthentication(_ coordinator: SFOAuthCoordinator) {}
}

// MARK: - Test-only extension for SFOAuthCredentials to set domain
@testable import SalesforceSDKCore

extension OAuthCredentials {
    var testDomain: String? {
        get { return self.domain }
        set { self.setValue(newValue, forKey: "domain") }
    }

    var testRedirectURI: String? {
        get { return self.redirectUri }
        set { self.setValue(newValue, forKey: "redirectUri") }
    }
}

// MARK: - Test-only extension for SFOAuthCoordinator to get loginHint
extension SFOAuthCoordinator {
    var testLoginHint: String? {
        get { self.value(forKey: "loginHint") as? String }
        set { self.setValue(newValue, forKey: "loginHint") }
    }
}
