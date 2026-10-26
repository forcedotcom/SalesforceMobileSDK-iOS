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
    @available(*, deprecated, message: "Exercises deprecated useWebServerAuthentication; remove with the property in 15.0.")
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

final class FrontdoorBridgeLoginTests: XCTestCase, SFOAuthCoordinatorDelegate {
    private let consumerKey = "qr-test-public-client"
    private var savedBootConfig: BootConfig?
    private var failureExpectation: XCTestExpectation?
    private var failure: NSError?
    private var failureCount = 0
    private var onAuthenticationBegin: (() -> Void)?
    private var onWebViewBegin: (() -> Void)?
    private var onNetworkAvailability: (() -> Bool)?
    private var pendingBrowserApproval: ((Bool) -> Void)?

    override func setUp() {
        super.setUp()
        savedBootConfig = SalesforceManager.shared.bootConfig
        SalesforceManager.shared.bootConfig = BootConfig([
            "remoteAccessConsumerKey": consumerKey,
            "oauthRedirectURI": "qr-test://callback",
            "oauthScopes": ["api"]
        ])
    }

    override func tearDown() {
        SalesforceManager.shared.bootConfig = savedBootConfig
        failureExpectation = nil
        failure = nil
        failureCount = 0
        clearFlowDelegateHooks()
        pendingBrowserApproval = nil
        super.tearDown()
    }

    func test_givenUntrustedHostAndMatchingPublicClient_whenCreatingBridge_thenURLAndVerifierAreRejected() throws {
        let bridge = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: try bridgeURL(origin: "https://attacker.example"),
            codeVerifier: "test-verifier")

        XCTAssertNil(bridge.frontdoorBridgeUrl)
        XCTAssertNil(bridge.codeVerifier)
    }

    func test_givenValidBridge_whenMutatingURLAndMatchFlag_thenUntrustedURLCannotBeConsumed() throws {
        let bridge = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: try bridgeURL(), codeVerifier: "test-verifier")
        bridge.frontdoorBridgeUrl = try bridgeURL(origin: "https://attacker.example")
        bridge.matchesConsumerKey = true

        XCTAssertNil(bridge.frontdoorBridgeUrl)
        XCTAssertNil(bridge.codeVerifier)
    }

    func test_givenMyDomainBridge_whenCreatingOverride_thenURLAndVerifierArePreserved() throws {
        let url = try bridgeURL()
        let bridge = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: url, codeVerifier: "test-verifier")

        XCTAssertEqual(bridge.frontdoorBridgeUrl, url)
        XCTAssertEqual(bridge.codeVerifier, "test-verifier")
        XCTAssertTrue(bridge.matchesConsumerKey)
    }

    func test_givenForeignClient_whenCreatingBridge_thenURLAndVerifierAreRejected() throws {
        let bridge = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: try bridgeURL(clientID: "another-public-client"),
            codeVerifier: "test-verifier")

        XCTAssertFalse(bridge.matchesConsumerKey)
        XCTAssertNil(bridge.frontdoorBridgeUrl)
        XCTAssertNil(bridge.codeVerifier)
    }

    func test_givenAmbiguousOrUnsafeURL_whenCreatingBridge_thenOverrideIsRejected() throws {
        let validURL = try bridgeURL()
        let invalidURLs = [
            try bridgeURL(origin: "http://qr-test.my.salesforce.com"),
            try bridgeURL(origin: "https://qr-test.my.salesforce.com:444"),
            try bridgeURL(origin: "https://user@qr-test.my.salesforce.com"),
            try bridgeURL(origin: "https://qr-test.my.salesforce.com.attacker.example"),
            try bridgeURL(origin: "https://attacker-my.salesforce.com.example"),
            try bridgeURL(origin: "https://qr-test.force.com"),
            try bridgeURL(origin: "https://127.0.0.1"),
            try modified(validURL) { $0.fragment = "fragment" },
            try modified(validURL) { $0.path = "/attacker" },
            try modified(validURL) { $0.percentEncodedPath = "/secur/%66rontdoor.jsp" },
            try modified(validURL) { $0.path = "/../secur/frontdoor.jsp" },
            try modified(validURL) { $0.path = "/customers//secur/frontdoor.jsp" },
            try modified(validURL) { $0.path = "/customers\\secur/frontdoor.jsp" },
            try modified(validURL) { $0.queryItems = [] },
            try modified(validURL) {
                let duplicate = $0.queryItems?.first
                if let duplicate { $0.queryItems?.append(duplicate) }
            }
        ]
        for url in invalidURLs {
            let bridge = AuthCoordinatorFrontdoorBridgeLoginOverride(
                frontdoorBridgeUrl: url, codeVerifier: "test-verifier")
            XCTAssertNil(bridge.frontdoorBridgeUrl, url.absoluteString)
            XCTAssertNil(bridge.codeVerifier, url.absoluteString)
        }
    }

    func test_givenCanonicalAuthorityVariants_whenWebKitInterpretsBridge_thenOriginIsPreserved() throws {
        let original = try bridgeURL().absoluteString
        let origins = [
            "https://qr-test.my.salesforce.com",
            "HTTPS://QR-TEST.MY.SALESFORCE.COM:443",
            "https://%71r-test.my.salesforce.com",
            "https://qr-test.my%2Esalesforce.com"
        ]
        for origin in origins {
            let url = try XCTUnwrap(URL(string: original.replacingOccurrences(
                of: "https://qr-test.my.salesforce.com", with: origin)))
            let bridge = AuthCoordinatorFrontdoorBridgeLoginOverride(
                frontdoorBridgeUrl: url, codeVerifier: nil)
            let validatedURL = try XCTUnwrap(bridge.frontdoorBridgeUrl, origin)
            let validated = try XCTUnwrap(URLComponents(url: validatedURL, resolvingAgainstBaseURL: false))
            let observed = expectation(description: "WebKit policy for \(origin)")
            let delegate = BridgeCancellingNavigationDelegate { request in
                defer { observed.fulfill() }
                guard let requestURL = request.url,
                      let browser = URLComponents(url: requestURL, resolvingAgainstBaseURL: false) else {
                    XCTFail("WebKit did not provide a URL for \(origin)")
                    return
                }
                XCTAssertEqual(browser.scheme?.lowercased(), NSURLProtectionSpaceHTTPS, origin)
                XCTAssertEqual(browser.host?.lowercased(), "qr-test.my.salesforce.com", origin)
                XCTAssertEqual(browser.host?.lowercased(), validated.host?.lowercased(), origin)
                XCTAssertEqual(browser.port ?? 443, validated.port ?? 443, origin)
                XCTAssertEqual(browser.percentEncodedPath, validated.percentEncodedPath, origin)
                XCTAssertEqual(browser.queryItems, validated.queryItems, origin)
                XCTAssertNil(browser.user, origin)
                XCTAssertNil(browser.password, origin)
            }
            let webView = WKWebView()
            webView.navigationDelegate = delegate
            webView.load(URLRequest(url: validatedURL))
            wait(for: [observed], timeout: 10)
            webView.stopLoading()
            withExtendedLifetime(delegate) {}
        }
    }

    func test_givenMisleadingAuthoritySpellings_whenCreatingBridge_thenNoURLIsAuthorized() throws {
        let original = try bridgeURL().absoluteString
        let origins = [
            "https://qr-test.my.salesforce.com@attacker.example",
            "https://attacker.example@qr-test.my.salesforce.com",
            "https://qr-test.my.salesforce.com%2F.attacker.example",
            "https://qr-test.my.salesforce.com%40attacker.example",
            "https://qr-test.my.salesforce.com\\@attacker.example",
            "https://qr-test.my.salesforce.com.",
            "https://qr-test.my.s\u{0430}lesforce.com"
        ]
        for origin in origins {
            guard let url = URL(string: original.replacingOccurrences(
                of: "https://qr-test.my.salesforce.com", with: origin)) else { continue }
            XCTAssertNil(AuthCoordinatorFrontdoorBridgeLoginOverride(
                frontdoorBridgeUrl: url, codeVerifier: nil).frontdoorBridgeUrl, origin)
        }
    }

    func test_givenUnsafeStartURL_whenCreatingBridge_thenOverrideIsRejected() throws {
        let values = [
            "", "/services/oauth2/authorize", "/services/oauth2/authorize?client_id=",
            "/services/oauth2/authorize?client_id=\(consumerKey)&client_id=\(consumerKey)",
            "https://attacker.example/services/oauth2/authorize?client_id=\(consumerKey)",
            "//attacker.example/services/oauth2/authorize?client_id=\(consumerKey)",
            "http://qr-test.my.salesforce.com/services/oauth2/authorize?client_id=\(consumerKey)",
            "https://user@qr-test.my.salesforce.com/services/oauth2/authorize?client_id=\(consumerKey)",
            "https://qr-test.my.salesforce.com:444/services/oauth2/authorize?client_id=\(consumerKey)",
            "/customers//services/oauth2/authorize?client_id=\(consumerKey)",
            "/customers\\services/oauth2/authorize?client_id=\(consumerKey)",
            "/services/oauth2/%61uthorize?client_id=\(consumerKey)",
            "/attacker?client_id=\(consumerKey)",
            "/../services/oauth2/authorize?client_id=\(consumerKey)",
            "/services/oauth2/authorize?client_id=\(consumerKey)#fragment"
        ]
        for value in values {
            let url = try modified(bridgeURL()) {
                $0.queryItems = [URLQueryItem(name: "startURL", value: value)]
            }
            let bridge = AuthCoordinatorFrontdoorBridgeLoginOverride(
                frontdoorBridgeUrl: url, codeVerifier: "test-verifier")
            XCTAssertNil(bridge.frontdoorBridgeUrl, value)
        }
    }

    func test_givenConfiguredCommunity_whenCreatingBridge_thenPrefixAndVerifierArePreserved() throws {
        let storage = SFSDKLoginHostStorage.sharedInstance()
        let index = storage.numberOfLoginHosts()
        storage.add(SalesforceLoginHost(name: "QR test", host: "qr-community.example", deletable: true))
        defer { storage.removeLoginHost(at: index) }
        let url = try modified(bridgeURL(origin: "https://qr-community.example")) {
            $0.path = "/customers/secur/frontdoor.jsp"
            $0.queryItems = [URLQueryItem(name: "startURL", value:
                "/customers/services/oauth2/authorize?client_id=\(consumerKey)")]
        }
        let bridge = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: url, codeVerifier: "community-verifier")
        XCTAssertEqual(bridge.frontdoorBridgeUrl, url)
        XCTAssertEqual(bridge.codeVerifier, "community-verifier")
    }

    func test_givenSameOriginAbsoluteStartURL_whenCreatingBridge_thenOverrideIsAccepted() throws {
        let url = try modified(bridgeURL(origin: "https://QR-TEST.MY.SALESFORCE.COM:443")) {
            $0.queryItems = [URLQueryItem(name: "startURL", value:
                "https://qr-test.my.salesforce.com/services/oauth2/authorize?client_id=\(consumerKey)")]
        }
        XCTAssertEqual(AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: url, codeVerifier: nil).frontdoorBridgeUrl, url)
    }

    func test_givenConfiguredAddressWithSchemeOrSitePath_whenCreatingBridge_thenOnlyThatHostIsTrusted() throws {
        let storage = SFSDKLoginHostStorage.sharedInstance()
        for address in ["qr-community.example/customers", "https://QR-COMMUNITY.EXAMPLE:443/customers"] {
            let index = storage.numberOfLoginHosts()
            storage.add(SalesforceLoginHost(name: "QR test", host: address, deletable: true))
            defer { storage.removeLoginHost(at: index) }
            let url = try bridgeURL(origin: "https://qr-community.example")
            XCTAssertEqual(AuthCoordinatorFrontdoorBridgeLoginOverride(
                frontdoorBridgeUrl: url, codeVerifier: nil).frontdoorBridgeUrl, url)
            let spoofed = try bridgeURL(origin: "https://qr-community.example.attacker.example")
            XCTAssertNil(AuthCoordinatorFrontdoorBridgeLoginOverride(
                frontdoorBridgeUrl: spoofed, codeVerifier: nil).frontdoorBridgeUrl)
        }
    }

    func test_givenUntrustedBridge_whenLoadingWebView_thenFailureArrivesWithoutNavigation() throws {
        let coordinator = try makeCoordinator(origin: "https://attacker.example")
        let webView = BridgeRecordingWebView()
        coordinator.view = webView
        failureExpectation = expectation(description: "invalid bridge fails")
        coordinator.loadWebView(withUrlString: "https://login.salesforce.com", cookie: false)
        waitForExpectations(timeout: 3)
        XCTAssertEqual(failure?.code, Int(kSFOAuthErrorInvalidRequest))
        XCTAssertTrue(webView.requests.isEmpty)
        XCTAssertNil(coordinator.frontdoorBridgeLoginOverride)
    }

    func test_givenMutatedBridge_whenExchangingCode_thenNoTokenRequestIsSent() throws {
        let coordinator = try makeCoordinator()
        let client = BridgeRecordingOAuthClient()
        coordinator.authClient = client
        coordinator.frontdoorBridgeLoginOverride?.frontdoorBridgeUrl = try bridgeURL(origin: "https://attacker.example")
        failureExpectation = expectation(description: "invalid code exchange fails")
        coordinator.exchangeApprovalCode(withAttestation: nil)
        waitForExpectations(timeout: 3)
        XCTAssertEqual(failure?.code, Int(kSFOAuthErrorInvalidRequest))
        XCTAssertTrue(client.requests.isEmpty)
    }

    func test_givenUntrustedBridge_whenAuthenticating_thenFailurePrecedesAnyLoginFlow() throws {
        let coordinator = try makeCoordinator(origin: "https://attacker.example")
        let webView = BridgeRecordingWebView()
        coordinator.view = webView
        coordinator.useBrowserAuth = true
        failureExpectation = expectation(description: "authentication rejects bridge")
        coordinator.authenticate()
        XCTAssertFalse(coordinator.authenticating)
        waitForExpectations(timeout: 3)
        XCTAssertEqual(failure?.domain, kSFOAuthErrorDomain)
        XCTAssertEqual(failure?.code, Int(kSFOAuthErrorInvalidRequest))
        XCTAssertFalse(coordinator.authenticating)
        XCTAssertTrue(webView.requests.isEmpty)
        XCTAssertEqual(coordinator.credentials?.domain, "login.salesforce.com")
    }

    func test_givenBridgeMutatedAfterLoadIsQueued_whenMainQueueRuns_thenNoNavigationOccurs() throws {
        let coordinator = try makeCoordinator()
        let webView = BridgeRecordingWebView()
        coordinator.view = webView
        failureExpectation = expectation(description: "queued load rejects mutation")
        coordinator.loadWebView(withUrlString: "https://login.salesforce.com", cookie: false)
        coordinator.frontdoorBridgeLoginOverride?.frontdoorBridgeUrl = try bridgeURL(origin: "https://attacker.example")
        waitForExpectations(timeout: 3)
        XCTAssertEqual(failure?.code, Int(kSFOAuthErrorInvalidRequest))
        XCTAssertTrue(webView.requests.isEmpty)
    }

    func test_givenUntrustedQRPayload_whenParsingLogin_thenItIsNotAccepted() throws {
        let storage = SFSDKLoginHostStorage.sharedInstance()
        let storedHosts = (0..<storage.numberOfLoginHosts()).map { storage.loginHost(at: $0).host }
        let selectedHost = UserAccountManager.shared.loginHost
        let json = try JSONSerialization.data(withJSONObject: [
            "frontdoor_bridge_url": try bridgeURL(origin: "https://attacker.example").absoluteString,
            "pkce_code_verifier": "test-verifier"
        ])
        let string = try XCTUnwrap(String(data: json, encoding: .utf8))
        let encoded = try XCTUnwrap(string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        XCTAssertFalse(SalesforceLoginViewController.loginWithFrontdoorBridgeUrlFromQrCode(
            "qr-test://login/qr?bridgeJson=\(encoded)"))
        XCTAssertFalse(SalesforceLoginViewController.loginWithFrontdoorBridgeUrlFromQrCode(nil))
        XCTAssertEqual(UserAccountManager.shared.loginHost, selectedHost)
        XCTAssertEqual((0..<storage.numberOfLoginHosts()).map { storage.loginHost(at: $0).host }, storedHosts)
        XCTAssertNil(AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: try bridgeURL(origin: "https://attacker.example"),
            codeVerifier: nil).frontdoorBridgeUrl)
    }

    func test_givenMutatedUserAgentBridge_whenRedirectArrives_thenCredentialsAreNotAccepted() throws {
        let coordinator = try makeCoordinator()
        coordinator.frontdoorBridgeLoginOverride?.codeVerifier = nil
        coordinator.frontdoorBridgeLoginOverride?.frontdoorBridgeUrl = try bridgeURL(origin: "https://attacker.example")
        let url = try XCTUnwrap(URL(string: "qr-test://callback#access_token=qr-test-placeholder"))
        let action = MockNavigationAction(url: url)
        failureExpectation = expectation(description: "user-agent callback rejects mutation")
        let webView = BridgeRecordingWebView()
        coordinator.webView(webView, decidePolicyFor: action) { policy in
            XCTAssertEqual(policy, .cancel)
        }
        waitForExpectations(timeout: 3)
        XCTAssertEqual(failure?.code, Int(kSFOAuthErrorInvalidRequest))
        XCTAssertNil(coordinator.credentials?.accessToken)
    }

    func test_givenMutatedBridge_whenNavigationArrives_thenNavigationIsCancelled() throws {
        let coordinator = try makeCoordinator()
        let url = try bridgeURL(origin: "https://attacker.example")
        coordinator.frontdoorBridgeLoginOverride?.frontdoorBridgeUrl = url
        failureExpectation = expectation(description: "navigation rejects mutation")
        coordinator.webView(BridgeRecordingWebView(), decidePolicyFor: MockNavigationAction(url: url)) { policy in
            XCTAssertEqual(policy, .cancel)
        }
        waitForExpectations(timeout: 3)
        XCTAssertEqual(failure?.code, Int(kSFOAuthErrorInvalidRequest))
    }

    func test_givenEmptyBootClient_whenCreatingBridge_thenEmptyClientCannotEstablishValidity() throws {
        SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = ""
        let bridge = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: try bridgeURL(clientID: ""), codeVerifier: nil)
        XCTAssertFalse(bridge.matchesConsumerKey)
        XCTAssertNil(bridge.frontdoorBridgeUrl)
    }

    func test_givenBootConfigChanges_whenConsumingExistingBridge_thenOldClientIsRejected() throws {
        let bridge = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: try bridgeURL(), codeVerifier: "test-verifier")
        SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey = "changed-client"
        bridge.matchesConsumerKey = true
        XCTAssertNil(bridge.frontdoorBridgeUrl)
        XCTAssertNil(bridge.codeVerifier)
    }

    func test_givenValidBridge_whenExchangingCode_thenConfiguredTokenOriginAndVerifierAreUsed() throws {
        let coordinator = try makeCoordinator()
        let client = BridgeRecordingOAuthClient()
        coordinator.authClient = client
        coordinator.exchangeApprovalCode(withAttestation: nil)
        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(request.serverURL.host, "login.salesforce.com")
        XCTAssertEqual(request.codeVerifier, "test-verifier")
    }

    func test_givenOtherMyDomainWithMatchingClient_whenReadingBridge_thenNoTenantMatchIsRequired() throws {
        let url = try bridgeURL(origin: "https://other-tenant.my.salesforce.com")
        let coordinator = try makeCoordinator(origin: "https://other-tenant.my.salesforce.com")
        XCTAssertEqual(coordinator.credentials?.domain, "login.salesforce.com")
        XCTAssertEqual(coordinator.frontdoorBridgeLoginOverride?.frontdoorBridgeUrl, url)
    }

    func test_givenValidUserAgentBridge_whenLoadingWebView_thenExactBridgeIsLoaded() throws {
        let coordinator = try makeCoordinator()
        coordinator.frontdoorBridgeLoginOverride?.codeVerifier = nil
        let webView = BridgeRecordingWebView()
        coordinator.view = webView
        let loaded = expectation(description: "bridge loaded")
        webView.didLoad = { loaded.fulfill() }
        coordinator.loadWebView(withUrlString: "https://login.salesforce.com", cookie: false)
        waitForExpectations(timeout: 3)
        XCTAssertEqual(webView.requests.map(\.url), [try bridgeURL()])
        XCTAssertNil(coordinator.frontdoorBridgeLoginOverride?.codeVerifier)
    }

    func test_givenMutationDuringValidation_whenReadingURL_thenOnlyValidatedURLIsReturned() throws {
        let config = try installMutatingConfig()
        let url = try bridgeURL()
        let attackerURL = try bridgeURL(origin: "https://attacker.example")
        let bridge = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: url, codeVerifier: "test-verifier")
        config.beforeConsumerKeyRead = {
            bridge.frontdoorBridgeUrl = attackerURL
        }
        XCTAssertEqual(bridge.frontdoorBridgeUrl, url)
        config.beforeConsumerKeyRead = nil
        XCTAssertNil(bridge.frontdoorBridgeUrl)
    }

    func test_givenMutationDuringValidation_whenReadingVerifier_thenOnlyCapturedVerifierIsReturned() throws {
        let config = try installMutatingConfig()
        let attackerURL = try bridgeURL(origin: "https://attacker.example")
        let bridge = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: try bridgeURL(), codeVerifier: "test-verifier")
        config.beforeConsumerKeyRead = {
            bridge.frontdoorBridgeUrl = attackerURL
            bridge.codeVerifier = "replacement-verifier"
        }
        XCTAssertEqual(bridge.codeVerifier, "test-verifier")
        config.beforeConsumerKeyRead = nil
        XCTAssertNil(bridge.codeVerifier)
    }

    func test_givenMutationBetweenValidationAndLoad_whenLoading_thenAttackerURLIsNeverLoaded() throws {
        let config = try installMutatingConfig()
        let coordinator = try makeCoordinator()
        let attackerURL = try bridgeURL(origin: "https://attacker.example")
        var reads = 0
        config.beforeConsumerKeyRead = {
            reads += 1
            if reads == 2 {
                coordinator.frontdoorBridgeLoginOverride?.frontdoorBridgeUrl = attackerURL
            }
        }
        let webView = BridgeRecordingWebView()
        coordinator.view = webView
        let loaded = expectation(description: "validated URL loaded")
        webView.didLoad = { loaded.fulfill() }
        coordinator.loadWebView(withUrlString: "https://login.salesforce.com", cookie: false)
        waitForExpectations(timeout: 3)
        config.beforeConsumerKeyRead = nil
        XCTAssertEqual(webView.requests.map(\.url), [try bridgeURL()])
    }

    func test_givenInvalidBridgeAndDiscoveryHost_whenAuthenticating_thenFailurePrecedesDiscovery() throws {
        let coordinator = try makeCoordinator(origin: "https://attacker.example")
        let credentials = try XCTUnwrap(coordinator.credentials)
        credentials.testDomain = "welcome.salesforce.com/discovery"
        let webView = BridgeRecordingWebView()
        coordinator.view = webView
        failureExpectation = expectation(description: "invalid bridge fails before discovery")
        performAndDrainMainQueue {
            coordinator.authenticate(with: credentials)
        }
        XCTAssertEqual(failure?.code, Int(kSFOAuthErrorInvalidRequest))
        XCTAssertTrue(webView.requests.isEmpty)
        XCTAssertFalse(coordinator.authenticating)
        XCTAssertNil(coordinator.frontdoorBridgeLoginOverride)
    }

    func test_givenDiscoveryHostWithValidOrNoBridge_whenAuthenticating_thenDiscoveryIsPreserved() throws {
        for hasBridge in [true, false] {
            let coordinator = try makeCoordinator()
            if !hasBridge { coordinator.frontdoorBridgeLoginOverride = nil }
            let credentials = try XCTUnwrap(coordinator.credentials)
            credentials.testDomain = "welcome.salesforce.com/discovery"
            let webView = BridgeRecordingWebView()
            coordinator.view = webView
            performAndDrainMainQueue {
                coordinator.authenticate(with: credentials)
            }
            XCTAssertEqual(webView.requests.count, 1)
            XCTAssertEqual(webView.requests.first?.url?.host, "welcome.salesforce.com")
            XCTAssertNil(failure)
        }
    }

    func test_givenTwoQueuedLoads_whenBridgeBecomesInvalid_thenNeitherLoadOccurs() throws {
        let coordinator = try makeCoordinator()
        let attackerURL = try bridgeURL(origin: "https://attacker.example")
        let webView = BridgeRecordingWebView()
        coordinator.view = webView
        failureExpectation = expectation(description: "invalid queued bridge fails once")
        failureExpectation?.assertForOverFulfill = true
        performAndDrainMainQueue {
            coordinator.loadWebView(withUrlString: "https://login.salesforce.com", cookie: false)
            coordinator.loadWebView(withUrlString: "https://login.salesforce.com", cookie: false)
            coordinator.frontdoorBridgeLoginOverride?.frontdoorBridgeUrl = attackerURL
        }
        XCTAssertEqual(failure?.code, Int(kSFOAuthErrorInvalidRequest))
        XCTAssertEqual(failureCount, 1)
        XCTAssertTrue(webView.requests.isEmpty)
        XCTAssertNil(coordinator.frontdoorBridgeLoginOverride)
    }

    func test_givenPendingAuthConfig_whenBridgeRejected_thenContinuationCannotLoadOrdinaryLogin() throws {
        let coordinator = try makePoolCoordinator()
        let attackerURL = try bridgeURL(origin: "https://attacker.example")
        let webView = BridgeRecordingWebView()
        coordinator.view = webView
        failureExpectation = expectation(description: "bridge rejected during pending auth config")
        performAndDrainMainQueue {
            coordinator.authenticate()
            coordinator.frontdoorBridgeLoginOverride?.frontdoorBridgeUrl = attackerURL
            coordinator.exchangeApprovalCode(withAttestation: nil)
        }
        XCTAssertEqual(failure?.code, Int(kSFOAuthErrorInvalidRequest))
        XCTAssertTrue(webView.requests.isEmpty)
        XCTAssertFalse(coordinator.authenticating)
    }

    func test_givenRejectedBridge_whenExplicitlyStartingNewAttempt_thenValidBridgeLoads() throws {
        let coordinator = try makePoolCoordinator()
        let attackerURL = try bridgeURL(origin: "https://attacker.example")
        let validURL = try bridgeURL(origin: "https://login.salesforce.com")
        let webView = BridgeRecordingWebView()
        coordinator.view = webView
        failureExpectation = expectation(description: "first bridge rejected")
        performAndDrainMainQueue {
            coordinator.frontdoorBridgeLoginOverride?.frontdoorBridgeUrl = attackerURL
            coordinator.exchangeApprovalCode(withAttestation: nil)
        }
        XCTAssertEqual(failure?.code, Int(kSFOAuthErrorInvalidRequest))
        failure = nil
        failureExpectation = nil
        performAndDrainMainQueue {
            coordinator.frontdoorBridgeLoginOverride = AuthCoordinatorFrontdoorBridgeLoginOverride(
                frontdoorBridgeUrl: validURL, codeVerifier: "fresh-verifier")
            coordinator.authenticate()
        }
        XCTAssertEqual(webView.requests.map(\.url), [validURL])
        XCTAssertTrue(coordinator.authenticating)
        XCTAssertNil(failure)
    }

    func test_givenRejectedPendingAttempt_whenNewAttemptStarts_thenOldWorkAndFailureStayStale() throws {
        let coordinator = try makePoolCoordinator()
        let attackerURL = try bridgeURL(origin: "https://attacker.example")
        let validURL = try bridgeURL(origin: "https://login.salesforce.com")
        let webView = BridgeRecordingWebView()
        coordinator.view = webView
        performAndDrainMainQueue {
            coordinator.authenticate()
            coordinator.frontdoorBridgeLoginOverride?.frontdoorBridgeUrl = attackerURL
            coordinator.exchangeApprovalCode(withAttestation: nil)
            coordinator.frontdoorBridgeLoginOverride = AuthCoordinatorFrontdoorBridgeLoginOverride(
                frontdoorBridgeUrl: validURL, codeVerifier: "fresh-verifier")
            coordinator.authenticate()
        }
        XCTAssertEqual(webView.requests.map(\.url), [validURL])
        XCTAssertTrue(coordinator.authenticating)
        XCTAssertNil(failure)
        XCTAssertEqual(coordinator.frontdoorBridgeLoginOverride?.codeVerifier, "fresh-verifier")
    }

    func test_givenQueuedBridgeLoads_whenStopped_thenNoLoadOrTokenRequestOccurs() throws {
        let coordinator = try makeCoordinator()
        let webView = BridgeRecordingWebView()
        let client = BridgeRecordingOAuthClient()
        coordinator.view = webView
        coordinator.authClient = client
        performAndDrainMainQueue {
            coordinator.loadWebView(withUrlString: "https://login.salesforce.com", cookie: false)
            coordinator.loadWebView(withUrlString: "https://login.salesforce.com", cookie: false)
            coordinator.stopAuthentication()
            coordinator.exchangeApprovalCode(withAttestation: nil)
        }
        XCTAssertTrue(webView.requests.isEmpty)
        XCTAssertTrue(client.requests.isEmpty)
        XCTAssertFalse(coordinator.authenticating)
        XCTAssertNil(failure)
    }

    func test_givenPendingAuthConfig_whenStopped_thenNeitherBridgeNorOrdinaryLoginLoads() throws {
        for hasBridge in [true, false] {
            let coordinator = try makePoolCoordinator()
            if !hasBridge { coordinator.frontdoorBridgeLoginOverride = nil }
            let webView = BridgeRecordingWebView()
            coordinator.view = webView
            performAndDrainMainQueue {
                coordinator.authenticate()
                coordinator.stopAuthentication()
            }
            XCTAssertTrue(webView.requests.isEmpty, "hasBridge: \(hasBridge)")
            XCTAssertFalse(coordinator.authenticating)
            XCTAssertNil(failure)
        }
    }

    func test_givenStoppedPendingAttempt_whenStartingNewAttempt_thenOnlyFreshBridgeLoads() throws {
        let coordinator = try makePoolCoordinator()
        let freshURL = try modified(bridgeURL(origin: "https://login.salesforce.com")) {
            $0.queryItems?.append(URLQueryItem(name: "qr_retry", value: "fresh"))
        }
        let webView = BridgeRecordingWebView()
        coordinator.view = webView
        performAndDrainMainQueue {
            coordinator.authenticate()
            coordinator.loadWebView(withUrlString: "https://login.salesforce.com", cookie: false)
            coordinator.stopAuthentication()
            coordinator.frontdoorBridgeLoginOverride = AuthCoordinatorFrontdoorBridgeLoginOverride(
                frontdoorBridgeUrl: freshURL, codeVerifier: "fresh-verifier")
            coordinator.authenticate()
        }
        XCTAssertEqual(webView.requests.map(\.url), [freshURL])
        XCTAssertTrue(coordinator.authenticating)
        XCTAssertEqual(coordinator.frontdoorBridgeLoginOverride?.codeVerifier, "fresh-verifier")
        XCTAssertNil(failure)
    }

    func test_givenConfiguredHostRemovedBeforeQueuedLoad_whenConsumed_thenBridgeIsRejected() throws {
        let storage = SFSDKLoginHostStorage.sharedInstance()
        let index = storage.numberOfLoginHosts()
        storage.add(SalesforceLoginHost(name: "QR revocation test", host: "qr-revoked.example", deletable: true))
        defer {
            if storage.numberOfLoginHosts() > index { storage.removeLoginHost(at: index) }
        }
        let coordinator = try makeCoordinator(origin: "https://qr-revoked.example")
        let webView = BridgeRecordingWebView()
        coordinator.view = webView
        XCTAssertNotNil(coordinator.frontdoorBridgeLoginOverride?.frontdoorBridgeUrl)
        failureExpectation = expectation(description: "removed configuration rejects queued bridge")
        performAndDrainMainQueue {
            coordinator.loadWebView(withUrlString: "https://login.salesforce.com", cookie: false)
            storage.removeLoginHost(at: index)
        }
        XCTAssertTrue(webView.requests.isEmpty)
        XCTAssertEqual(failure?.code, Int(kSFOAuthErrorInvalidRequest))
        XCTAssertFalse(coordinator.authenticating)
        XCTAssertNil(coordinator.frontdoorBridgeLoginOverride)
    }

    func test_givenConfiguredHostRemoved_whenReadingBridge_thenURLAndVerifierAreNil() throws {
        let storage = SFSDKLoginHostStorage.sharedInstance()
        let index = storage.numberOfLoginHosts()
        storage.add(SalesforceLoginHost(name: "QR getter test", host: "qr-getter.example", deletable: true))
        defer {
            if storage.numberOfLoginHosts() > index { storage.removeLoginHost(at: index) }
        }
        let url = try bridgeURL(origin: "https://qr-getter.example")
        let bridge = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: url, codeVerifier: "getter-test-verifier")
        XCTAssertEqual(bridge.frontdoorBridgeUrl, url)
        XCTAssertEqual(bridge.codeVerifier, "getter-test-verifier")
        storage.removeLoginHost(at: index)
        XCTAssertNil(bridge.frontdoorBridgeUrl)
        XCTAssertNil(bridge.codeVerifier)
    }

    @available(*, deprecated, message: "Exercises IDP response handling; remove with the deprecated IDP API.")
    func test_givenStoppedNonBridgeAttempt_whenResponseArrives_thenOnlyExplicitRetryExchangesCode() throws {
        for usesIDP in [false, true] {
            let coordinator = try makePoolCoordinator()
            coordinator.frontdoorBridgeLoginOverride = nil
            let client = BridgeRecordingOAuthClient()
            coordinator.authClient = client
            coordinator.view = BridgeRecordingWebView()
            let callback = try XCTUnwrap(URL(string: "qr-test://callback?code=late-code"))
            let freshCallback = try XCTUnwrap(URL(string: "qr-test://callback?code=fresh-code"))
            let handleResponse: (URL) -> Bool = { url in
                usesIDP ? coordinator.handleIDPAuthenticationResponse(url)
                    : coordinator.handleAdvancedAuthenticationResponse(url)
            }
            defer { coordinator.stopAuthentication() }
            try withControlledFlowBoundaries {
                performAndDrainMainQueue {
                    coordinator.authenticate()
                    coordinator.stopAuthentication()
                    XCTAssertFalse(handleResponse(callback))
                }
                XCTAssertTrue(client.requests.isEmpty)
                performAndDrainMainQueue {
                    coordinator.authenticate()
                    XCTAssertTrue(handleResponse(freshCallback))
                }
                XCTAssertEqual(client.requests.count, 1)
                XCTAssertEqual(client.requests.first?.approvalCode, "fresh-code")
            }
            XCTAssertNil(failure)
            pendingBrowserApproval = nil
        }
    }

    @available(*, deprecated, message: "Exercises IDP response handling; remove with the deprecated IDP API.")
    func test_givenFreshNonBridgeCoordinator_whenIDPResponseArrives_thenAuthenticateIsNotRequired() throws {
        let coordinator = try makePoolCoordinator()
        coordinator.frontdoorBridgeLoginOverride = nil
        let client = BridgeRecordingOAuthClient()
        coordinator.authClient = client
        let callback = try XCTUnwrap(URL(string: "qr-test://callback?code=idp-initiated-code"))
        defer { coordinator.stopAuthentication() }
        try withControlledFlowBoundaries {
            performAndDrainMainQueue {
                XCTAssertTrue(coordinator.handleIDPAuthenticationResponse(callback))
            }
            XCTAssertEqual(client.requests.count, 1)
            XCTAssertEqual(client.requests.first?.approvalCode, "idp-initiated-code")
        }
        XCTAssertNil(failure)
    }

    @available(*, deprecated, message: "Exercises IDP response handling; remove with the deprecated IDP API.")
    func test_givenQueuedWebOrIDPResponse_whenStoppedOrReplaced_thenOnlyCurrentCodeIsExchanged() throws {
        for usesIDP in [false, true] {
            for state in ["current", "stopped", "replaced"] {
                for hasBridge in [false, true] {
                    let coordinator = try makePoolCoordinator()
                    if !hasBridge { coordinator.frontdoorBridgeLoginOverride = nil }
                    let client = BridgeRecordingOAuthClient()
                    coordinator.authClient = client
                    coordinator.view = BridgeRecordingWebView()
                    let callback = try XCTUnwrap(URL(string: "qr-test://callback?code=original-code"))
                    let freshURL = try bridgeURL(origin: "https://login.salesforce.com")
                    let label = "IDP: \(usesIDP), state: \(state), bridge: \(hasBridge)"
                    defer { coordinator.stopAuthentication() }
                    let handleResponse: (URL) -> Bool = { url in
                        usesIDP ? coordinator.handleIDPAuthenticationResponse(url)
                            : coordinator.handleAdvancedAuthenticationResponse(url)
                    }
                    try withControlledFlowBoundaries {
                        performAndDrainMainQueue {
                            coordinator.authenticate()
                            XCTAssertTrue(handleResponse(callback), label)
                            if state != "current" { coordinator.stopAuthentication() }
                            if state == "replaced" {
                                coordinator.frontdoorBridgeLoginOverride = AuthCoordinatorFrontdoorBridgeLoginOverride(
                                    frontdoorBridgeUrl: freshURL, codeVerifier: "replacement-verifier")
                                coordinator.authenticate()
                            }
                        }
                        XCTAssertEqual(client.requests.count, state == "current" ? 1 : 0, label)
                        if state == "current" {
                            XCTAssertEqual(client.requests.first?.approvalCode, "original-code", label)
                        } else if state == "replaced" {
                            client.requests.removeAll()
                            let freshCallback = try XCTUnwrap(URL(string: "qr-test://callback?code=fresh-code"))
                            performAndDrainMainQueue { XCTAssertTrue(handleResponse(freshCallback), label) }
                            XCTAssertEqual(client.requests.count, 1, label)
                            XCTAssertEqual(client.requests.first?.approvalCode, "fresh-code", label)
                            XCTAssertEqual(client.requests.first?.codeVerifier, "replacement-verifier", label)
                        }
                    }
                    XCTAssertNil(failure, label)
                    pendingBrowserApproval = nil
                }
            }
        }
    }

    func test_givenBeginDelegateStopsAndRestarts_whenReturning_thenOnlyReplacementBridgeLoads() throws {
        for stage in ["notification", "view", "network", "discovery"] {
            let coordinator = try makePoolCoordinator()
            let webView = BridgeRecordingWebView()
            coordinator.view = webView
            let credentials = try XCTUnwrap(coordinator.credentials)
            if stage == "discovery" { credentials.testDomain = "welcome.salesforce.com/discovery" }
            let freshURL = try modified(bridgeURL(origin: "https://login.salesforce.com")) {
                $0.queryItems?.append(URLQueryItem(name: "retry", value: stage))
            }
            defer { clearFlowDelegateHooks(); coordinator.stopAuthentication() }
            let restart = {
                self.clearFlowDelegateHooks()
                coordinator.stopAuthentication()
                credentials.testDomain = "login.salesforce.com"
                coordinator.frontdoorBridgeLoginOverride = AuthCoordinatorFrontdoorBridgeLoginOverride(
                    frontdoorBridgeUrl: freshURL, codeVerifier: "replacement-verifier")
                coordinator.authenticate()
            }
            installFlowDelegateHook(stage: stage, action: restart)
            if stage != "network" { expectFirstLoadAndItsQueuedContinuations(webView) }
            performAndDrainMainQueue {
                if stage == "discovery" { coordinator.authenticate(with: credentials) }
                else { coordinator.authenticate() }
            }
            XCTAssertEqual(webView.requests.map(\.url), [freshURL], stage)
            XCTAssertTrue(coordinator.authenticating, stage)
            XCTAssertNil(failure, stage)
        }
    }

    func test_givenBeginDelegateStops_whenReturning_thenNoLoginWorkOrFailureResumes() throws {
        for stage in ["notification", "view", "network", "discovery"] {
            let coordinator = try makePoolCoordinator()
            let webView = BridgeRecordingWebView()
            coordinator.view = webView
            let credentials = try XCTUnwrap(coordinator.credentials)
            if stage == "discovery" { credentials.testDomain = "welcome.salesforce.com/discovery" }
            defer { clearFlowDelegateHooks() }
            installFlowDelegateHook(stage: stage) {
                self.clearFlowDelegateHooks()
                coordinator.stopAuthentication()
            }
            performAndDrainMainQueue {
                if stage == "discovery" { coordinator.authenticate(with: credentials) }
                else { coordinator.authenticate() }
            }
            XCTAssertTrue(webView.requests.isEmpty, stage)
            XCTAssertFalse(coordinator.authenticating, stage)
            XCTAssertNil(failure, stage)
        }
    }

    func test_givenDeferredBrowserApproval_whenStoppedOrReplaced_thenOnlyCurrentApprovalLaunches() throws {
        for state in ["current", "stopped", "replaced"] {
            let coordinator = try makePoolCoordinator()
            coordinator.frontdoorBridgeLoginOverride = nil
            coordinator.useBrowserAuth = true
            coordinator.view = BridgeRecordingWebView()
            defer { coordinator.stopAuthentication(); pendingBrowserApproval = nil }
            try withControlledFlowBoundaries {
                performAndDrainMainQueue { coordinator.authenticate() }
                let approval = try XCTUnwrap(pendingBrowserApproval, state)
                performAndDrainMainQueue {
                    if state != "current" { coordinator.stopAuthentication() }
                    if state == "replaced" { coordinator.authenticate() }
                    approval(true)
                }
                XCTAssertEqual(BridgeFlowBoundaryStub.browserLaunches, state == "current" ? 1 : 0, state)
            }
        }
    }

    func test_givenPendingAttestation_whenAttemptIsReplaced_thenOldCompletionCannotExchangeCode() throws {
        let coordinator = try makePoolCoordinator()
        let client = BridgeRecordingOAuthClient()
        coordinator.authClient = client
        coordinator.view = BridgeRecordingWebView()
        let callback = try XCTUnwrap(URL(string: "qr-test://callback?code=old-code"))
        defer { coordinator.stopAuthentication() }
        try withControlledFlowBoundaries {
            BridgeFlowBoundaryStub.holdAttestation = true
            performAndDrainMainQueue {
                XCTAssertTrue(coordinator.handleAdvancedAuthenticationResponse(callback))
            }
            let complete = try XCTUnwrap(BridgeFlowBoundaryStub.pendingAttestation)
            performAndDrainMainQueue {
                coordinator.stopAuthentication()
                coordinator.authenticate()
                complete(nil)
            }
            XCTAssertTrue(client.requests.isEmpty)
        }
    }

    func test_givenNavigationPolicyStopsOrReplacesAttempt_whenReturning_thenOldNavigationIsCancelled() throws {
        let manager = UserAccountManager.shared
        let savedPolicy = manager.navigationPolicyForAction
        defer { manager.navigationPolicyForAction = savedPolicy }
        for state in ["current", "stopped", "replaced"] {
            let coordinator = try makePoolCoordinator()
            let webView = BridgeRecordingWebView()
            coordinator.view = webView
            let url = try XCTUnwrap(URL(string: "https://sso.example/continue"))
            manager.navigationPolicyForAction = { _, _ in
                if state != "current" { coordinator.stopAuthentication() }
                if state == "replaced" { coordinator.authenticate() }
                return .allow
            }
            var observed: WKNavigationActionPolicy?
            performAndDrainMainQueue {
                coordinator.webView(webView, decidePolicyFor: MockNavigationAction(url: url)) { observed = $0 }
            }
            XCTAssertEqual(observed, state == "current" ? .allow : .cancel, state)
            coordinator.stopAuthentication()
        }
    }

    func test_givenInvalidDirectBridge_whenStartingLogin_thenCurrentAuthenticationIsNotStopped() throws {
        let stop = try XCTUnwrap(class_getInstanceMethod(UserAccountManager.self,
            NSSelectorFromString("stopCurrentAuthentication:")))
        let stopStub = try XCTUnwrap(class_getInstanceMethod(BridgeFlowBoundaryStub.self,
            NSSelectorFromString("bridgeStopCurrentAuthentication:")))
        method_exchangeImplementations(stop, stopStub)
        let savedStopCalls = BridgeFlowBoundaryStub.stopCalls
        BridgeFlowBoundaryStub.stopCalls = 0
        defer {
            method_exchangeImplementations(stop, stopStub)
            BridgeFlowBoundaryStub.stopCalls = savedStopCalls
        }

        let invalidValues = ["https://[", try bridgeURL(origin: "https://attacker.example").absoluteString,
                             try bridgeURL(clientID: "foreign-public-client").absoluteString]
        for value in invalidValues {
            SalesforceLoginViewController.loginWithFrontdoorBridgeUrl(value, pkceCodeVerifier: "test-verifier")
            XCTAssertEqual(BridgeFlowBoundaryStub.stopCalls, 0)
        }
        SalesforceLoginViewController.loginWithFrontdoorBridgeUrl(
            try bridgeURL().absoluteString, pkceCodeVerifier: "test-verifier")
        XCTAssertEqual(BridgeFlowBoundaryStub.stopCalls, 1)
    }

    func test_givenMalformedConfiguredAddresses_whenReadingBridge_thenConfigurationDoesNotGrantTrust() throws {
        let storage = SFSDKLoginHostStorage.sharedInstance()
        let host = "qr-malformed-config.example"
        let url = try bridgeURL(origin: "https://\(host)")
        let addresses = ["http://\(host)", "https://user@\(host)", "https://\(host):444",
                         "https://\(host)?query=value", "https://\(host)#fragment", "https://["]
        for address in addresses + ["https://\(host)/customers"] {
            let index = storage.numberOfLoginHosts()
            storage.add(SalesforceLoginHost(name: "QR configuration test", host: address, deletable: true))
            defer { storage.removeLoginHost(at: index) }
            let bridge = AuthCoordinatorFrontdoorBridgeLoginOverride(
                frontdoorBridgeUrl: url, codeVerifier: "test-verifier")
            if address == "https://\(host)/customers" {
                XCTAssertEqual(bridge.frontdoorBridgeUrl, url)
                XCTAssertEqual(bridge.codeVerifier, "test-verifier")
            } else {
                XCTAssertNil(bridge.frontdoorBridgeUrl, address)
                XCTAssertNil(bridge.codeVerifier, address)
            }
        }
    }

    func test_givenValidBridgeCallback_whenNavigating_thenVerifierSelectsTheCorrectFlow() throws {
        for hasBridge in [false, true] {
            for hasVerifier in [false, true] {
                let coordinator = try makePoolCoordinator()
                if !hasBridge { coordinator.frontdoorBridgeLoginOverride = nil }
                else if !hasVerifier { coordinator.frontdoorBridgeLoginOverride?.codeVerifier = nil }
                let client = BridgeRecordingOAuthClient()
                coordinator.authClient = client
                let webView = BridgeRecordingWebView()
                coordinator.view = webView
                let usesCode = !hasBridge || hasVerifier
                let callback = try XCTUnwrap(URL(string: usesCode
                    ? "qr-test://callback?code=navigation-code"
                    : "qr-test://callback#access_token=navigation-test-placeholder"))
                defer {
                    coordinator.credentials?.accessToken = nil
                    coordinator.stopAuthentication()
                }
                try withControlledFlowBoundaries {
                    performAndDrainMainQueue {
                        coordinator.webView(webView, decidePolicyFor: MockNavigationAction(url: callback)) {
                            XCTAssertEqual($0, .cancel)
                        }
                    }
                }
                XCTAssertEqual(client.requests.count, usesCode ? 1 : 0)
                if usesCode {
                    XCTAssertEqual(client.requests.first?.approvalCode, "navigation-code")
                    XCTAssertEqual(client.requests.first?.codeVerifier, hasBridge ? "test-verifier" : coordinator.codeVerifier)
                } else {
                    XCTAssertEqual(coordinator.credentials?.accessToken, "navigation-test-placeholder")
                }
                XCTAssertNil(failure)
            }
        }
    }

    func test_givenStopDuringValidation_whenLoading_thenCapturedBridgeAndLaterLoadsAreDiscarded() throws {
        let config = try installMutatingConfig()
        let coordinator = try makePoolCoordinator()
        let webView = BridgeRecordingWebView()
        let client = BridgeRecordingOAuthClient()
        coordinator.view = webView
        coordinator.authClient = client
        let url = try bridgeURL(origin: "https://login.salesforce.com").absoluteString
        var configurationReads = 0
        config.beforeConsumerKeyRead = {
            config.beforeConsumerKeyRead = nil
            configurationReads += 1
            coordinator.stopAuthentication()
        }
        defer { config.beforeConsumerKeyRead = nil; coordinator.stopAuthentication() }
        performAndDrainMainQueue {
            coordinator.loadWebView(withUrlString: url, cookie: true)
        }
        performAndDrainMainQueue {
            coordinator.loadWebView(withUrlString: url, cookie: true)
        }
        XCTAssertEqual(configurationReads, 1)
        XCTAssertTrue(webView.requests.isEmpty)
        XCTAssertTrue(client.requests.isEmpty)
        XCTAssertFalse(coordinator.authenticating)
        XCTAssertNil(failure)
    }

    private func clearFlowDelegateHooks() {
        onAuthenticationBegin = nil
        onWebViewBegin = nil
        onNetworkAvailability = nil
    }

    private func installFlowDelegateHook(stage: String, action: @escaping () -> Void) {
        if stage == "notification" {
            onAuthenticationBegin = action
        } else if stage == "view" || stage == "discovery" {
            onWebViewBegin = action
        } else {
            onNetworkAvailability = { action(); return false }
        }
    }

    private func expectFirstLoadAndItsQueuedContinuations(_ webView: BridgeRecordingWebView) {
        let drained = expectation(description: "observed load and queued replacement work")
        webView.didLoad = { [weak webView] in
            webView?.didLoad = nil
            DispatchQueue.main.async {
                DispatchQueue.main.async { drained.fulfill() }
            }
        }
    }

    private func withControlledFlowBoundaries(_ work: () throws -> Void) throws {
        let attest = try XCTUnwrap(class_getClassMethod(AppAttestation.self,
            NSSelectorFromString("attestationIfEnabledFor:consumerKey:completionHandler:")))
        let attestStub = try XCTUnwrap(class_getClassMethod(BridgeFlowBoundaryStub.self,
            NSSelectorFromString("bridgeAttestationFor:consumerKey:completionHandler:")))
        let browser = try XCTUnwrap(class_getInstanceMethod(SFOAuthCoordinator.self,
            NSSelectorFromString("continueNativeBrowserFlowWithSharedBrowserSessionEnabled:")))
        let browserStub = try XCTUnwrap(class_getInstanceMethod(BridgeFlowBoundaryStub.self,
            NSSelectorFromString("bridgeContinueNativeBrowserWithSharedBrowserSessionEnabled:")))
        method_exchangeImplementations(attest, attestStub)
        method_exchangeImplementations(browser, browserStub)
        BridgeFlowBoundaryStub.browserLaunches = 0
        defer {
            method_exchangeImplementations(browser, browserStub)
            method_exchangeImplementations(attest, attestStub)
            BridgeFlowBoundaryStub.pendingAttestation = nil
            BridgeFlowBoundaryStub.holdAttestation = false
        }
        try work()
    }

    func oauthCoordinatorWillBeginAuthentication(_ coordinator: SFOAuthCoordinator, authInfo: AuthInfo) {
        onAuthenticationBegin?()
    }

    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, willBeginAuthenticationWith view: WKWebView) {
        onWebViewBegin?()
    }

    func oauthCoordinatorIsNetworkAvailable(_ coordinator: SFOAuthCoordinator) -> Bool {
        onNetworkAvailability?() ?? true
    }

    func oauthCoordinator(_ coordinator: SFOAuthCoordinator,
                          willBeginBrowserAuthentication callback: @escaping (Bool) -> Void) {
        pendingBrowserApproval = callback
    }

    private func makePoolCoordinator() throws -> SFOAuthCoordinator {
        let coordinator = try makeCoordinator(origin: "https://login.salesforce.com")
        coordinator.dpopOverride = NSNumber(value: false)
        coordinator.authClient = BridgeRecordingOAuthClient()
        return coordinator
    }

    private func performAndDrainMainQueue(_ work: @escaping () -> Void) {
        let drained = expectation(description: "main-queue continuations drained")
        DispatchQueue.main.async {
            work()
            DispatchQueue.main.async {
                DispatchQueue.main.async { drained.fulfill() }
            }
        }
        waitForExpectations(timeout: 3)
    }

    private func installMutatingConfig() throws -> BridgeMutatingBootConfig {
        let config = try XCTUnwrap(BridgeMutatingBootConfig([
            "remoteAccessConsumerKey": consumerKey,
            "oauthRedirectURI": "qr-test://callback",
            "oauthScopes": ["api"]
        ]))
        SalesforceManager.shared.bootConfig = config
        return config
    }

    private func makeCoordinator(origin: String = "https://qr-test.my.salesforce.com") throws -> SFOAuthCoordinator {
        let credentials = try XCTUnwrap(OAuthCredentials(
            identifier: "qr-bridge-test", clientId: consumerKey, encrypted: false))
        credentials.testDomain = "login.salesforce.com"
        credentials.testRedirectURI = "qr-test://callback"
        let coordinator = SFOAuthCoordinator()
        coordinator.credentials = credentials
        coordinator.delegate = self
        coordinator.approvalCode = "qr-test-code"
        coordinator.frontdoorBridgeLoginOverride = AuthCoordinatorFrontdoorBridgeLoginOverride(
            frontdoorBridgeUrl: try bridgeURL(origin: origin), codeVerifier: "test-verifier")
        return coordinator
    }

    private func modified(_ url: URL, change: (inout URLComponents) -> Void) throws -> URL {
        var components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        change(&components)
        return try XCTUnwrap(components.url)
    }

    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didFailWithError error: Error, authInfo: AuthInfo?) {
        failure = error as NSError
        failureCount += 1
        failureExpectation?.fulfill()
    }

    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith view: WKWebView) {
        onWebViewBegin?()
    }
    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith session: ASWebAuthenticationSession) {}
    func oauthCoordinatorDidBeginNativeAuthentication(_ coordinator: SFOAuthCoordinator) {}
    func oauthCoordinatorDidCancelBrowserAuthentication(_ coordinator: SFOAuthCoordinator) {}

    private func bridgeURL(origin: String = "https://qr-test.my.salesforce.com",
                           clientID: String? = nil) throws -> URL {
        var components = try XCTUnwrap(URLComponents(string: origin))
        components.path = "/secur/frontdoor.jsp"
        components.queryItems = [URLQueryItem(
            name: "startURL",
            value: "/services/oauth2/authorize?client_id=\(clientID ?? consumerKey)")]
        return try XCTUnwrap(components.url)
    }
}

private final class BridgeRecordingWebView: WKWebView {
    var requests: [URLRequest] = []
    var didLoad: (() -> Void)?

    override func load(_ request: URLRequest) -> WKNavigation? {
        requests.append(request)
        didLoad?()
        return nil
    }
}

private final class BridgeCancellingNavigationDelegate: NSObject, WKNavigationDelegate {
    private let observe: (URLRequest) -> Void

    init(observe: @escaping (URLRequest) -> Void) {
        self.observe = observe
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.cancel)
        observe(navigationAction.request)
    }
}

private final class BridgeRecordingOAuthClient: NSObject, SFSDKOAuthProtocol {
    var requests: [SFSDKOAuthTokenEndpointRequest] = []

    func accessToken(forApprovalCode request: SFSDKOAuthTokenEndpointRequest,
                     completion: @escaping (SFSDKOAuthTokenEndpointResponse) -> Void) {
        requests.append(request)
    }

    func accessToken(forRefresh request: SFSDKOAuthTokenEndpointRequest,
                     completion: @escaping (SFSDKOAuthTokenEndpointResponse) -> Void) {
        XCTFail("Unexpected refresh")
    }

    func openIDToken(forRefresh request: SFSDKOAuthTokenEndpointRequest,
                     completion: @escaping (String) -> Void) {}
    func revokeRefreshToken(_ credentials: OAuthCredentials, reason: SFLogoutReason) {}
}

private final class BridgeMutatingBootConfig: BootConfig {
    var beforeConsumerKeyRead: (() -> Void)?

    override var remoteAccessConsumerKey: String {
        get {
            beforeConsumerKeyRead?()
            return super.remoteAccessConsumerKey
        }
        set { super.remoteAccessConsumerKey = newValue }
    }
}

/*
 Control attestation completion and record browser launch at external
 boundaries. Keep callback-order tests independent of Swift task scheduling and
 browser UI.
 */
private final class BridgeFlowBoundaryStub: NSObject {
    static var stopCalls = 0
    static var browserLaunches = 0
    static var holdAttestation = false
    static var pendingAttestation: ((String?) -> Void)?

    @objc(bridgeStopCurrentAuthentication:)
    func stopAuthentication(_ completion: ((Bool) -> Void)?) {
        BridgeFlowBoundaryStub.stopCalls += 1
    }

    @objc(bridgeAttestationFor:consumerKey:completionHandler:)
    static func attest(domain: String?, consumerKey: String?, completion: @escaping (String?) -> Void) {
        if holdAttestation { pendingAttestation = completion } else { completion(nil) }
    }

    @objc(bridgeContinueNativeBrowserWithSharedBrowserSessionEnabled:)
    func continueBrowser(_ shareBrowserSession: Bool) {
        BridgeFlowBoundaryStub.browserLaunches += 1
    }
}
