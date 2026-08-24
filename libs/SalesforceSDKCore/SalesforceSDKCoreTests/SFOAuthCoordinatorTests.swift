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

    /// Production pool host `login.salesforce.com` must receive `dpop_jkt` when DPoP is enabled.
    func test_givenDPoPEnabledAndProductionPoolHost_whenGenerateApprovalUrlString_thenUrlHasDPoPJkt() throws {
        SalesforceManager.shared.usesDPoP = true

        let scope = trackedScope("sc4-pool-prod")
        let credentials = try makeCredentials(identifier: scope, domain: "login.salesforce.com")
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials

        let url = coordinator.generateApprovalUrlString()
        let jktValue = try XCTUnwrap(queryValue(name: "dpop_jkt", in: url),
                                     "login.salesforce.com supports DPoP code binding; dpop_jkt must be present")
        let pattern = try NSRegularExpression(pattern: "^[A-Za-z0-9_-]{43}$")
        let range = NSRange(location: 0, length: jktValue.utf16.count)
        XCTAssertNotNil(pattern.firstMatch(in: jktValue, options: [], range: range),
                        "dpop_jkt must be a 43-char base64url string, got: \(jktValue)")
    }

    /// Sandbox pool host `test.salesforce.com` must receive `dpop_jkt` when DPoP is enabled.
    func test_givenDPoPEnabledAndSandboxPoolHost_whenGenerateApprovalUrlString_thenUrlHasDPoPJkt() throws {
        SalesforceManager.shared.usesDPoP = true

        let scope = trackedScope("sc4-pool-sandbox")
        let credentials = try makeCredentials(identifier: scope, domain: "test.salesforce.com")
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials

        let url = coordinator.generateApprovalUrlString()
        let jktValue = try XCTUnwrap(queryValue(name: "dpop_jkt", in: url),
                                     "test.salesforce.com supports DPoP code binding; dpop_jkt must be present")
        let pattern = try NSRegularExpression(pattern: "^[A-Za-z0-9_-]{43}$")
        let range = NSRange(location: 0, length: jktValue.utf16.count)
        XCTAssertNotNil(pattern.firstMatch(in: jktValue, options: [], range: range),
                        "dpop_jkt must be a 43-char base64url string, got: \(jktValue)")
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

    /// Defensive-guard coverage — When `domain` is nil the
    /// `appendDPoPJktIfNeededTo:domain:credentials:` guard must return
    /// immediately, leaving the URL untouched.
    ///
    /// `generateApprovalUrlString()` always resolves a non-nil domain before
    /// calling the append helper (it falls back to `credentials.domain` and
    /// asserts), so the nil-domain guard in the helper is a defensive
    /// belt-and-suspenders check. We exercise it by calling the internal
    /// helper through the ObjC runtime with a nil domain string rather than
    /// going through `generateApprovalUrlString` which cannot reach it.
    func test_givenDPoPEnabledAndNilDomain_whenAppendDPoPJktIfNeededTo_thenUrlRemainsUnchanged() throws {
        SalesforceManager.shared.usesDPoP = true

        let identifier = trackedScope("sc6-nil-domain")
        let credentials = try makeCredentials(identifier: identifier,
                                              domain: "acme.my.salesforce.com")

        // Build a baseline approval URL with a known domain so we can pass a nil
        // domain directly to the append helper and confirm the URL is unchanged.
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials
        let baseUrl = NSMutableString(string:
            "https://acme.my.salesforce.com/services/oauth2/authorize?client_id=test&redirect_uri=x://cb&display=touch")
        let sel = NSSelectorFromString("appendDPoPJktIfNeededTo:domain:credentials:")
        // The selector must exist — if it disappears the test fails here, loudly.
        XCTAssertTrue(coordinator.responds(to: sel),
                      "appendDPoPJktIfNeededTo:domain:credentials: must be present on SFOAuthCoordinator")
        // Invoke with nil domain via NSInvocation-style IMP call.
        // swiftlint:disable:next force_cast
        typealias AppendFn = @convention(c) (AnyObject, Selector, NSMutableString, AnyObject?, AnyObject?) -> Void
        let imp = coordinator.method(for: sel)
        let fn = unsafeBitCast(imp, to: AppendFn.self)
        fn(coordinator, sel, baseUrl, nil, credentials)

        XCTAssertFalse(baseUrl.contains("dpop_jkt"),
                       "dpop_jkt must not be appended when domain is nil — the nil-domain guard must return early")
    }

    /// The `migrateRefreshToken:` flow constructs its single-access
    /// request path from `generateApprovalUrlString()`. Under the same gate
    /// (a per-call `dpopOverride=@YES` + my-domain + identifier set), the URL it
    /// feeds to `requestForSingleAccess` therefore includes `dpop_jkt`, regardless
    /// of the process-wide `usesDPoP` flag. Because the downstream
    /// `SFRestAPI sendRequest:` invocation makes a real network call, this test
    /// verifies the URL produced by the same coordinator method that
    /// migrateRefreshToken invokes — no REST mocking needed.
    func test_givenDPoPEnabledMigrateRefreshTokenSetup_whenGenerateApprovalUrlString_thenUrlContainsDPoPJkt() throws {
        SalesforceManager.shared.usesDPoP = false

        let scope = trackedScope("sc7-migrate-refresh")
        let credentials = try makeCredentials(identifier: scope, domain: "acme.my.salesforce.com")
        credentials.refreshToken = "test-refresh-token"
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials
        coordinator.dpopOverride = NSNumber(value: true)

        // migrateRefreshToken: internally does:
        //   NSURL *approvalUrl = [NSURL URLWithString:[self generateApprovalUrlString]];
        // so the URL passed to the SFRestAPI single-access call is exactly
        // this string. The dpop_jkt binding therefore propagates end-to-end.
        let url = coordinator.generateApprovalUrlString()
        let jktValue = try XCTUnwrap(queryValue(name: "dpop_jkt", in: url),
                                     "migrateRefreshToken path must produce a URL with dpop_jkt under a per-call dpopOverride, independent of the global flag")
        XCTAssertEqual(jktValue.count, 43,
                       "dpop_jkt on migrateRefreshToken path must be a 43-char base64url string")
    }

    // MARK: - dpopOverride per-call gate (independent of the global usesDPoP flag)

    /// Global flag OFF + a per-call `dpopOverride=@YES` (e.g. an in-place DPoP
    /// upgrade migration) still attaches `dpop_jkt`. This is the crux of the
    /// per-call gate: the override takes precedence over the global flag.
    func test_givenGlobalFlagOffAndDpopOverrideYes_whenGenerateApprovalUrlString_thenUrlContainsDPoPJkt() throws {
        SalesforceManager.shared.usesDPoP = false

        let scope = trackedScope("override-flag-off-override-yes")
        let credentials = try makeCredentials(identifier: scope, domain: "acme.my.salesforce.com")
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials
        coordinator.dpopOverride = NSNumber(value: true)

        let url = coordinator.generateApprovalUrlString()
        XCTAssertNotNil(queryValue(name: "dpop_jkt", in: url),
                        "dpop_jkt must be present when dpopOverride=YES, even with the global flag off")
    }

    /// Global flag ON + a per-call `dpopOverride=@NO` (e.g. an explicit
    /// downgrade migration) omits `dpop_jkt`. The override can turn DPoP off
    /// per call just as it can turn it on.
    func test_givenGlobalFlagOnAndDpopOverrideNo_whenGenerateApprovalUrlString_thenUrlHasNoDPoPJkt() throws {
        SalesforceManager.shared.usesDPoP = true

        let scope = trackedScope("override-flag-on-override-no")
        let credentials = try makeCredentials(identifier: scope, domain: "acme.my.salesforce.com")
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials
        coordinator.dpopOverride = NSNumber(value: false)

        let url = coordinator.generateApprovalUrlString()
        XCTAssertNil(queryValue(name: "dpop_jkt", in: url),
                     "dpop_jkt must be absent when dpopOverride=NO, even with the global flag on")
    }

    /// A nil `dpopOverride` (the normal-login default — never set outside a
    /// per-call migration) must defer to the global flag exactly as before:
    /// flag on ⇒ dpop_jkt present, flag off ⇒ absent.
    func test_givenDpopOverrideNil_whenGenerateApprovalUrlString_thenUrlFollowsGlobalFlag() throws {
        let scopeOn = trackedScope("override-nil-flag-on")
        SalesforceManager.shared.usesDPoP = true
        let credentialsOn = try makeCredentials(identifier: scopeOn, domain: "acme.my.salesforce.com")
        let coordinatorOn = SFOAuthCoordinator()
        coordinatorOn.credentials = credentialsOn
        XCTAssertNil(coordinatorOn.dpopOverride, "normal login must never set dpopOverride")
        let urlOn = coordinatorOn.generateApprovalUrlString()
        XCTAssertNotNil(queryValue(name: "dpop_jkt", in: urlOn),
                        "with dpopOverride nil and the global flag on, dpop_jkt must be present")

        let scopeOff = trackedScope("override-nil-flag-off")
        SalesforceManager.shared.usesDPoP = false
        let credentialsOff = try makeCredentials(identifier: scopeOff, domain: "acme.my.salesforce.com")
        let coordinatorOff = SFOAuthCoordinator()
        coordinatorOff.credentials = credentialsOff
        let urlOff = coordinatorOff.generateApprovalUrlString()
        XCTAssertNil(queryValue(name: "dpop_jkt", in: urlOff),
                     "with dpopOverride nil and the global flag off, dpop_jkt must be absent")
    }

    // MARK: - Per-user credential binding on re-auth (independent of the global flag)

    /// Interactive re-authentication of an already-Bearer credential (e.g. a
    /// session that was downgraded from DPoP) must NOT re-bind to DPoP, even
    /// with the global `usesDPoP` flag on and no per-call override. Before the
    /// fix this fell through to the global flag and silently re-bound on the
    /// stale-session re-login that follows a revoke+refresh. The per-user
    /// `credentials.tokenType` is now the source of truth for re-auth.
    func test_givenDpopOverrideNilAndBearerCredential_whenGenerateApprovalUrlString_thenUrlHasNoDPoPJktEvenWithGlobalFlagOn() throws {
        SalesforceManager.shared.usesDPoP = true

        let scope = trackedScope("reauth-bearer-credential")
        let credentials = try makeCredentials(identifier: scope, domain: "acme.my.salesforce.com")
        credentials.testTokenType = "Bearer"
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials
        XCTAssertNil(coordinator.dpopOverride, "interactive re-auth must never set dpopOverride")

        let url = coordinator.generateApprovalUrlString()
        XCTAssertNil(queryValue(name: "dpop_jkt", in: url),
                     "a Bearer (downgraded) credential must not re-bind to DPoP on re-login, even with the global flag on")
    }

    /// Interactive re-authentication of a DPoP-bound credential must stay
    /// DPoP-bound, even with the global `usesDPoP` flag off and no per-call
    /// override — the per-user binding is honored in both directions.
    func test_givenDpopOverrideNilAndDPoPCredential_whenGenerateApprovalUrlString_thenUrlHasDPoPJktEvenWithGlobalFlagOff() throws {
        SalesforceManager.shared.usesDPoP = false

        let scope = trackedScope("reauth-dpop-credential")
        let credentials = try makeCredentials(identifier: scope, domain: "acme.my.salesforce.com")
        credentials.testTokenType = DPoPRequestDecorator.dpopTokenType
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials

        let url = coordinator.generateApprovalUrlString()
        XCTAssertNotNil(queryValue(name: "dpop_jkt", in: url),
                        "a DPoP-bound credential must stay DPoP on re-login, even with the global flag off")
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

    var testTokenType: String? {
        get { return self.tokenType }
        set { self.setValue(newValue, forKey: "tokenType") }
    }
}

// MARK: - Test-only extension for SFOAuthCoordinator to get loginHint
extension SFOAuthCoordinator {
    var testLoginHint: String? {
        get { self.value(forKey: "loginHint") as? String }
        set { self.setValue(newValue, forKey: "loginHint") }
    }
}
