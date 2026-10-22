/*
 NativeLoginDebugSettingsTests.swift
 SalesforceSDKCoreTests

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

private let completeConfigJSON = """
{"authenticationMode":"native","consumerKey":" nativeKey ","redirectUri":"https://native.example.com/callback",\
"communityUrl":"https://community.example.com/site","useDPoP":false,"useHybridFlow":false}
"""

// MARK: - Persistence and validation

class NativeLoginDebugSettingsTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var devSupport = true
    private var appRegistered = false
    private var settings: NativeLoginDebugSettings!

    override func setUp() {
        super.setUp()
        suiteName = "NativeLoginDebugSettingsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        devSupport = true
        appRegistered = false
        settings = makeSettings()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeSettings() -> NativeLoginDebugSettings {
        NativeLoginDebugSettings(defaults: defaults,
                                 isDevSupportEnabled: { [unowned self] in self.devSupport },
                                 isAppNativeLoginRegistered: { [unowned self] in self.appRegistered })
    }

    func test_givenNoStoredSettings_whenRead_thenBrowserModeAndEmptyConfig() {
        XCTAssertEqual(settings.mode, .browser)
        XCTAssertEqual(settings.config, NativeLoginDebugConfig())
        XCTAssertTrue(settings.config.useDPoP)
        XCTAssertTrue(settings.config.useHybridFlow)
        XCTAssertFalse(settings.isNativeLoginActive)
    }

    func test_givenCompleteJSON_whenApplied_thenPersistedTrimmedAndActive() throws {
        try settings.apply(json: completeConfigJSON)

        let reloaded = makeSettings()
        XCTAssertEqual(reloaded.mode, .native)
        XCTAssertEqual(reloaded.config.consumerKey, "nativeKey")
        XCTAssertEqual(reloaded.config.redirectUri, "https://native.example.com/callback")
        XCTAssertEqual(reloaded.config.communityUrl, "https://community.example.com/site")
        XCTAssertFalse(reloaded.config.useDPoP)
        XCTAssertFalse(reloaded.config.useHybridFlow)
        XCTAssertTrue(reloaded.isNativeLoginActive)
    }

    func test_givenAppliedConfig_whenPartialJSONApplied_thenAbsentKeysKept() throws {
        try settings.apply(json: completeConfigJSON)
        try settings.apply(json: #"{"useDPoP":true}"#)

        XCTAssertTrue(settings.config.useDPoP)
        XCTAssertEqual(settings.config.consumerKey, "nativeKey")
        XCTAssertEqual(settings.mode, .native)
    }

    func test_givenNativeModeWithIncompleteConfig_whenApplied_thenThrowsAndSavesNothing() {
        XCTAssertThrowsError(try settings.apply(json: #"{"authenticationMode":"native","consumerKey":"key"}"#)) { error in
            XCTAssertEqual(error as? NativeLoginDebugSettingsError,
                           .invalidConfiguration("Native Callback URL must be an https:// URL"))
        }
        XCTAssertEqual(settings.mode, .browser)
        XCTAssertEqual(settings.config, NativeLoginDebugConfig())
    }

    func test_givenBrowserMode_whenIncompleteConfigApplied_thenSaved() throws {
        try settings.apply(json: #"{"consumerKey":"key"}"#)

        XCTAssertEqual(settings.config.consumerKey, "key")
        XCTAssertEqual(settings.mode, .browser)
        XCTAssertFalse(settings.isNativeLoginActive)
    }

    func test_givenMalformedJSON_whenApplied_thenThrowsMalformed() {
        for json in ["not json", "[1,2]", ""] {
            XCTAssertThrowsError(try settings.apply(json: json), json) { error in
                XCTAssertEqual(error as? NativeLoginDebugSettingsError, .malformedJSON)
            }
        }
    }

    func test_givenWrongValueTypes_whenApplied_thenThrowsWrongTypeAndSavesNothing() {
        XCTAssertThrowsError(try settings.apply(json: #"{"consumerKey":42}"#)) { error in
            XCTAssertEqual(error as? NativeLoginDebugSettingsError, .wrongType(key: "consumerKey"))
        }
        // A number is not a boolean, even though JSONSerialization decodes both to NSNumber.
        XCTAssertThrowsError(try settings.apply(json: #"{"consumerKey":"key","useDPoP":1}"#)) { error in
            XCTAssertEqual(error as? NativeLoginDebugSettingsError, .wrongType(key: "useDPoP"))
        }
        XCTAssertEqual(settings.config, NativeLoginDebugConfig())
    }

    func test_givenUnknownMode_whenApplied_thenThrows() {
        XCTAssertThrowsError(try settings.apply(json: #"{"authenticationMode":"sideways"}"#)) { error in
            XCTAssertEqual(error as? NativeLoginDebugSettingsError, .unknownAuthenticationMode("sideways"))
        }
    }

    func test_givenModeName_whenParsed_thenCaseInsensitive() {
        XCTAssertEqual(AuthenticationMode(name: "NATIVE"), .native)
        XCTAssertEqual(AuthenticationMode(name: "Browser"), .browser)
        XCTAssertNil(AuthenticationMode(name: "web"))
    }

    func test_givenNonHttpsUrls_whenValidated_thenReportsFirstProblem() {
        XCTAssertEqual(NativeLoginDebugConfig().validationError, "Client ID is required")
        XCTAssertEqual(NativeLoginDebugConfig(consumerKey: "k", redirectUri: "myapp://cb").validationError,
                       "Native Callback URL must be an https:// URL")
        XCTAssertEqual(NativeLoginDebugConfig(consumerKey: "k", redirectUri: "https://a.example.com",
                                              communityUrl: "http://c.example.com").validationError,
                       "Community Login URL must be an https:// URL")
        XCTAssertTrue(NativeLoginDebugConfig(consumerKey: "k", redirectUri: "https://a.example.com",
                                             communityUrl: "https://c.example.com/site").isComplete)
    }

    func test_givenDevSupportDisabled_whenUsed_thenInertAndBrowser() throws {
        try settings.apply(json: completeConfigJSON)
        devSupport = false

        XCTAssertFalse(settings.isAvailable)
        XCTAssertEqual(settings.mode, .browser)
        XCTAssertFalse(settings.isNativeLoginActive)
        XCTAssertThrowsError(try settings.apply(json: #"{"useDPoP":true}"#)) { error in
            XCTAssertEqual(error as? NativeLoginDebugSettingsError, .unavailable)
        }
        settings.mode = .native
        devSupport = true
        XCTAssertFalse(settings.config.useDPoP, "Writes are ignored while unavailable")
    }

    func test_givenAppRegisteredNativeLogin_whenUsed_thenInert() throws {
        try settings.apply(json: completeConfigJSON)
        appRegistered = true

        XCTAssertFalse(settings.isAvailable)
        XCTAssertEqual(settings.mode, .browser)
        XCTAssertFalse(settings.isNativeLoginActive)
    }

    func test_givenAppliedSettings_whenReset_thenDefaults() throws {
        try settings.apply(json: completeConfigJSON)
        settings.reset()

        XCTAssertEqual(makeSettings().mode, .browser)
        XCTAssertEqual(makeSettings().config, NativeLoginDebugConfig())
    }

    func test_givenAppliedSettings_whenRead_thenBrowserBootConfigUntouched() throws {
        let bootConfig = SalesforceManager.shared.bootConfig
        let clientId = UserAccountManager.shared.oauthClientID
        let usesDPoP = SalesforceManager.shared.usesDPoP
        let useHybrid = SalesforceManager.shared.useHybridAuthentication

        try settings.apply(json: completeConfigJSON)

        XCTAssertEqual(SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey, bootConfig?.remoteAccessConsumerKey)
        XCTAssertEqual(UserAccountManager.shared.oauthClientID, clientId)
        XCTAssertEqual(SalesforceManager.shared.usesDPoP, usesDPoP)
        XCTAssertEqual(SalesforceManager.shared.useHybridAuthentication, useHybrid)
        XCTAssertNil(UserDefaults.standard.object(forKey: "config"), "Native settings stay in their own suite")
    }
}

// MARK: - Login Options visibility

class LoginOptionsVisibilityTests: XCTestCase {

    func test_givenUnavailable_whenMade_thenOnlyBrowserOptions() {
        for mode in AuthenticationMode.allCases {
            let visibility = LoginOptionsVisibility.make(isAvailable: false, mode: mode)
            XCTAssertFalse(visibility.showsAuthenticationMode)
            XCTAssertFalse(visibility.showsNativeOptions)
            XCTAssertTrue(visibility.showsBrowserOptions)
        }
    }

    func test_givenAvailableBrowserMode_whenMade_thenModePickerAndBrowserOptions() {
        let visibility = LoginOptionsVisibility.make(isAvailable: true, mode: .browser)
        XCTAssertTrue(visibility.showsAuthenticationMode)
        XCTAssertFalse(visibility.showsNativeOptions)
        XCTAssertTrue(visibility.showsBrowserOptions)
    }

    func test_givenAvailableNativeMode_whenMade_thenModePickerAndNativeOptionsOnly() {
        let visibility = LoginOptionsVisibility.make(isAvailable: true, mode: .native)
        XCTAssertTrue(visibility.showsAuthenticationMode)
        XCTAssertTrue(visibility.showsNativeOptions)
        XCTAssertFalse(visibility.showsBrowserOptions)
    }
}

// MARK: - Diagnostics

class NativeLoginDiagnosticsTests: XCTestCase {

    private func response(status: Int, headers: [String: String] = [:]) -> HTTPURLResponse? {
        HTTPURLResponse(url: URL(string: "https://community.example.com/site/services/oauth2/authorize")!,
                        statusCode: status, httpVersion: nil, headerFields: headers)
    }

    func test_givenRejectedAuthorize_whenRecorded_thenSummaryAndFailureNameTheError() throws {
        let diagnostics = NativeLoginDiagnostics(isEnabled: { true })
        let body = try JSONSerialization.data(withJSONObject: [
            "error": "invalid_request",
            "error_description": "missing required dpop_jkt for code binding"
        ])
        diagnostics.record(path: "/site/services/oauth2/authorize", dpop: false, retry: 0,
                           urlResponse: response(status: 400), body: body)

        XCTAssertEqual(diagnostics.summary,
                       #"stage=authorize status=400 error=invalid_request dpop=false nonce=false retry=0 description="missing required dpop_jkt for code binding""#)
        XCTAssertEqual(diagnostics.lastFailure, "HTTP 400 invalid_request: missing required dpop_jkt for code binding")
    }

    func test_givenSuccessWithNonce_whenRecorded_thenNoFailureAndNonceValueNotKept() {
        let diagnostics = NativeLoginDiagnostics(isEnabled: { true })
        diagnostics.record(path: "/services/oauth2/token", dpop: true, retry: 1,
                           urlResponse: response(status: 200, headers: ["DPoP-Nonce": "secret-nonce"]), body: Data())

        XCTAssertEqual(diagnostics.summary, "stage=token status=200 dpop=true nonce=true retry=1")
        XCTAssertNil(diagnostics.lastFailure)
        XCTAssertFalse(diagnostics.summary.contains("secret-nonce"))
    }

    func test_givenNoResponse_whenRecorded_thenStatusNoneIsAFailure() {
        let diagnostics = NativeLoginDiagnostics(isEnabled: { true })
        diagnostics.record(path: "/services/oauth2/authorize", dpop: false, retry: 0, urlResponse: nil, body: nil)

        XCTAssertEqual(diagnostics.lastFailure, "HTTP none")
    }

    func test_givenLongDescription_whenRecorded_thenTruncated() throws {
        let diagnostics = NativeLoginDiagnostics(isEnabled: { true })
        let body = try JSONSerialization.data(withJSONObject: ["error": "x", "error_description": String(repeating: "a", count: 500)])
        diagnostics.record(path: "/services/oauth2/token", dpop: false, retry: 0, urlResponse: response(status: 401), body: body)

        XCTAssertEqual(diagnostics.events.first?.errorDescription?.count, NativeLoginDiagnostics.maxDescriptionLength)
    }

    func test_givenDisabled_whenRecorded_thenNothingKept() {
        let diagnostics = NativeLoginDiagnostics(isEnabled: { false })
        diagnostics.record(path: "/services/oauth2/token", dpop: false, retry: 0, urlResponse: response(status: 500), body: nil)

        XCTAssertTrue(diagnostics.events.isEmpty)
    }

    func test_givenEvents_whenReset_thenEmpty() {
        let diagnostics = NativeLoginDiagnostics(isEnabled: { true })
        diagnostics.record(path: "/services/oauth2/token", dpop: false, retry: 0, urlResponse: response(status: 500), body: nil)
        diagnostics.reset()

        XCTAssertTrue(diagnostics.events.isEmpty)
        XCTAssertEqual(diagnostics.summary, "")
    }

    func test_givenPaths_whenStaged_thenAuthorizeTokenOrOther() {
        XCTAssertEqual(NativeLoginDiagnostics.stage(forPath: "/site/services/oauth2/authorize"), "authorize")
        XCTAssertEqual(NativeLoginDiagnostics.stage(forPath: "/services/oauth2/token"), "token")
        XCTAssertEqual(NativeLoginDiagnostics.stage(forPath: "/services/oauth2/userinfo"), "other")
    }
}

// MARK: - Debug form state machine

@MainActor
class DebugNativeLoginModelTests: XCTestCase {

    private var diagnostics: NativeLoginDiagnostics!
    private var cancelCount = 0
    private var fallbackCount = 0
    private var canDismiss = false
    private var submitted: [(String, String)] = []

    override func setUp() async throws {
        try await super.setUp()
        diagnostics = NativeLoginDiagnostics(isEnabled: { true })
        cancelCount = 0
        fallbackCount = 0
        canDismiss = false
        submitted = []
    }

    private func makeModel(login: @escaping (String, String) async -> NativeLoginResult) -> DebugNativeLoginModel {
        DebugNativeLoginModel(loginAction: { [unowned self] username, password in
                                  self.submitted.append((username, password))
                                  return await login(username, password)
                              },
                              cancelAction: { [unowned self] in self.cancelCount += 1 },
                              fallbackAction: { [unowned self] in self.fallbackCount += 1 },
                              canDismiss: { [unowned self] in self.canDismiss },
                              diagnostics: diagnostics)
    }

    func test_givenNewModel_whenShown_thenIdle() {
        let model = makeModel { _, _ in .success }
        XCTAssertEqual(model.state, .idle)
        XCTAssertFalse(model.showsCancel)
    }

    func test_givenCredentials_whenLoginSucceeds_thenSuccessAndPasswordCleared() async {
        let model = makeModel { _, _ in .success }
        model.username = "user@example.com"
        model.password = "secret"

        model.login()
        XCTAssertEqual(model.state, .loading)
        XCTAssertTrue(model.showsCancel, "Cancel stops an attempt in progress")
        await model.currentLoginTask?.value

        XCTAssertEqual(model.state, .success)
        XCTAssertEqual(model.password, "")
        XCTAssertEqual(submitted.first?.0, "user@example.com")
        XCTAssertEqual(submitted.first?.1, "secret")
    }

    func test_givenServerRejection_whenLoginFails_thenDetailNamesResultAndLastFailure() async throws {
        let body = try JSONSerialization.data(withJSONObject: ["error": "invalid_request", "error_description": "missing dpop_jkt"])
        let model = makeModel { [diagnostics] _, _ in
            diagnostics?.record(path: "/services/oauth2/authorize", dpop: false, retry: 0,
                                urlResponse: HTTPURLResponse(url: URL(string: "https://c.example.com")!, statusCode: 400,
                                                             httpVersion: nil, headerFields: nil),
                                body: body)
            return .unknownError
        }

        model.login()
        await model.currentLoginTask?.value

        XCTAssertEqual(model.state, .failed(result: .unknownError, detail: "unknownError (HTTP 400 invalid_request: missing dpop_jkt)"))
        XCTAssertTrue(model.diagnosticsSummary.contains("stage=authorize status=400 error=invalid_request dpop=false"))
    }

    func test_givenNoDiagnostics_whenLoginFails_thenDetailIsResultName() async {
        let model = makeModel { _, _ in .invalidCredentials }
        model.login()
        await model.currentLoginTask?.value

        XCTAssertEqual(model.state, .failed(result: .invalidCredentials, detail: "invalidCredentials"))
    }

    func test_givenPreviousAttempt_whenLoginAgain_thenDiagnosticsReset() async {
        diagnostics.record(NativeLoginDiagnosticEvent(stage: "token", status: 500, error: nil, errorDescription: nil,
                                                      dpop: false, nonce: false, retry: 0))
        let model = makeModel { _, _ in .success }
        model.login()
        await model.currentLoginTask?.value

        XCTAssertTrue(diagnostics.events.isEmpty)
    }

    func test_givenLoading_whenLoginTappedAgain_thenSingleAttempt() async {
        let model = makeModel { _, _ in .success }
        model.login()
        model.login()
        await model.currentLoginTask?.value

        XCTAssertEqual(submitted.count, 1)
    }

    func test_givenNoAccount_whenCancelledWhileLoading_thenIdleWithoutCancellingAuthentication() async {
        let gate = AsyncGate()
        let model = makeModel { _, _ in
            await gate.wait()
            return .success
        }
        model.login()
        let task = model.currentLoginTask

        model.cancel()
        await gate.open()
        await task?.value

        XCTAssertEqual(model.state, .idle, "A cancelled attempt's result is ignored")
        XCTAssertEqual(cancelCount, 0, "Nothing to return to without an account")
        XCTAssertFalse(model.showsCancel)
    }

    func test_givenExistingAccount_whenCancelled_thenAuthenticationCancelled() {
        canDismiss = true
        let model = makeModel { _, _ in .success }

        XCTAssertTrue(model.showsCancel)
        model.cancel()

        XCTAssertEqual(cancelCount, 1)
    }

    func test_givenForm_whenBrowserFallback_thenFallbackActionCalled() {
        let model = makeModel { _, _ in .success }
        model.fallbackToBrowser()

        XCTAssertEqual(fallbackCount, 1)
        XCTAssertEqual(model.state, .idle)
    }

    func test_givenResults_whenNamed_thenCaseNames() {
        XCTAssertEqual(NativeLoginResult.invalidCredentials.name, "invalidCredentials")
        XCTAssertEqual(NativeLoginResult.unknownError.name, "unknownError")
        XCTAssertEqual(NativeLoginResult.success.name, "success")
    }
}

/// Holds an async login until the test opens it, without sleeping.
private actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

// MARK: - Routing, precedence and restart

class DebugNativeLoginRoutingTests: XCTestCase {

    /// Native login state is process-wide, and other suites (NativeLoginManagerTests) register an
    /// app native login when their test instances are created; each test starts without one and
    /// puts the previous registration back.
    private struct NativeLoginState {
        let appRegistered: Bool
        let enabled: Bool
        let viewControllers: [AnyHashable: UIViewController]
        let manager: NativeLoginManagerInternal?
        let hasMarker: Bool
    }

    private var originalDevSupport = false
    private var originalBootConfig: BootConfig?
    private var originalNativeLogin: NativeLoginState!

    override func setUp() {
        super.setUp()
        let sdkManager = SalesforceManager.shared
        originalDevSupport = sdkManager.isDevSupportEnabled
        originalBootConfig = sdkManager.bootConfig
        let appRegistered: Bool = sdkManager.appRegisteredNativeLogin
        let viewControllers: [AnyHashable: UIViewController] = sdkManager.nativeLoginViewControllers?.dictionary() ?? [:]
        var manager: NativeLoginManagerInternal?
        if appRegistered {
            let registered: NativeLoginManager? = sdkManager.nativeLoginManager()
            manager = registered as? NativeLoginManagerInternal
        }
        let features: Set<String> = SFSDKAppFeatureMarkers.appFeatures()
        originalNativeLogin = NativeLoginState(appRegistered: appRegistered,
                                               enabled: UserAccountManager.shared.nativeLoginEnabled,
                                               viewControllers: viewControllers,
                                               manager: manager,
                                               hasMarker: features.contains(kSFAppFeatureNativeLogin))
        clearNativeLogin()
        sdkManager.isDevSupportEnabled = true
        NativeLoginDebugSettings.shared.reset()
    }

    override func tearDown() {
        NativeLoginDebugSettings.shared.reset()
        clearNativeLogin()
        let sdkManager = SalesforceManager.shared
        if let manager = originalNativeLogin.manager,
           let viewController = originalNativeLogin.viewControllers[kSFDefaultNativeLoginViewControllerKey] {
            _ = sdkManager.useNativeLogin(withConsumerKey: manager.clientId, callbackUrl: manager.redirectUri,
                                          communityUrl: manager.loginUrl, nativeLoginViewController: viewController, scene: nil)
        }
        sdkManager.appRegisteredNativeLogin = originalNativeLogin.appRegistered
        sdkManager.nativeLoginViewControllers?.setDictionary(originalNativeLogin.viewControllers)
        UserAccountManager.shared.nativeLoginEnabled = originalNativeLogin.enabled
        if !originalNativeLogin.hasMarker {
            SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureNativeLogin)
        }
        sdkManager.isDevSupportEnabled = originalDevSupport
        sdkManager.bootConfig = originalBootConfig
        super.tearDown()
    }

    /// There is no public API to unregister an app's native login; undo it by hand.
    private func clearNativeLogin() {
        let sdkManager = SalesforceManager.shared
        sdkManager.deactivateDebugNativeLogin()
        sdkManager.appRegisteredNativeLogin = false
        sdkManager.nativeLoginViewControllers?.removeAllObjects()
        UserAccountManager.shared.nativeLoginEnabled = false
        SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureNativeLogin)
    }

    private var debugViewControllerIsRegistered: Bool {
        SalesforceManager.shared.nativeLoginViewControllers?.object(forKey: kSFDefaultNativeLoginViewControllerKey as NSString) is DebugNativeLoginViewController
    }

    func test_givenNativeModeWithCompleteConfig_whenApplied_thenDebugFormRegistered() throws {
        try NativeLoginDebugSettings.shared.apply(json: completeConfigJSON)

        SalesforceManager.shared.applyDebugNativeLoginSettings()

        XCTAssertTrue(SalesforceManager.shared.debugNativeLoginActive)
        XCTAssertTrue(UserAccountManager.shared.nativeLoginEnabled)
        XCTAssertTrue(debugViewControllerIsRegistered)
        let manager = SalesforceManager.shared.nativeLoginManager() as? NativeLoginManagerInternal
        XCTAssertEqual(manager?.clientId, "nativeKey")
        XCTAssertEqual(manager?.redirectUri, "https://native.example.com/callback")
        XCTAssertEqual(manager?.useHybridAuthenticationOverride, false)
    }

    func test_givenNativeMode_whenAuthRequestBuilt_thenUsesNativeClientAndNativeDPoPChoice() throws {
        try NativeLoginDebugSettings.shared.apply(json: completeConfigJSON)
        SalesforceManager.shared.applyDebugNativeLoginSettings()

        let request = UserAccountManager.shared.nativeLoginAuthRequest()

        XCTAssertEqual(request.oauthClientId, "nativeKey")
        XCTAssertEqual(request.oauthCompletionUrl, "https://native.example.com/callback")
        XCTAssertEqual(request.useDPoP, false, "Native Login uses its own DPoP choice, not the browser flag")
    }

    func test_givenNativeModeActive_whenSwitchedToBrowser_thenDebugFormUnregistered() throws {
        try NativeLoginDebugSettings.shared.apply(json: completeConfigJSON)
        SalesforceManager.shared.applyDebugNativeLoginSettings()

        NativeLoginDebugSettings.shared.mode = .browser
        SalesforceManager.shared.applyDebugNativeLoginSettings()

        XCTAssertFalse(SalesforceManager.shared.debugNativeLoginActive)
        XCTAssertFalse(UserAccountManager.shared.nativeLoginEnabled)
        XCTAssertFalse(debugViewControllerIsRegistered)
    }

    func test_givenDevSupportDisabled_whenApplied_thenBrowserLogin() throws {
        try NativeLoginDebugSettings.shared.apply(json: completeConfigJSON)
        SalesforceManager.shared.isDevSupportEnabled = false

        SalesforceManager.shared.applyDebugNativeLoginSettings()

        XCTAssertFalse(SalesforceManager.shared.debugNativeLoginActive)
        XCTAssertFalse(UserAccountManager.shared.nativeLoginEnabled)
    }

    func test_givenAppRegisteredNativeLogin_whenApplied_thenAppViewControllerWins() throws {
        try NativeLoginDebugSettings.shared.apply(json: completeConfigJSON)
        SalesforceManager.shared.applyDebugNativeLoginSettings()
        let appViewController = UIViewController()

        SalesforceManager.shared.useNativeLogin(withConsumerKey: "appKey",
                                                callbackUrl: "https://app.example.com/callback",
                                                communityUrl: "https://app.example.com/site",
                                                nativeLoginViewController: appViewController,
                                                scene: nil)
        SalesforceManager.shared.applyDebugNativeLoginSettings()

        XCTAssertFalse(SalesforceManager.shared.debugNativeLoginActive)
        XCTAssertFalse(NativeLoginDebugSettings.shared.isAvailable)
        XCTAssertTrue(SalesforceManager.shared.nativeLoginViewControllers?.object(forKey: kSFDefaultNativeLoginViewControllerKey as NSString) === appViewController)
        XCTAssertEqual((SalesforceManager.shared.nativeLoginManager() as? NativeLoginManagerInternal)?.clientId, "appKey")
        XCTAssertNil(UserAccountManager.shared.nativeLoginAuthRequest().useDPoP, "App native login keeps the global DPoP flag")
    }

    func test_givenBrowserSession_whenNativeModeSelected_thenRestartBuildsNativeRequest() throws {
        let browserRequest = UserAccountManager.shared.defaultAuthRequest()
        browserRequest.loginHost = "test.salesforce.com"
        let session = SFSDKAuthSession(browserRequest, credentials: nil)
        try NativeLoginDebugSettings.shared.apply(json: completeConfigJSON)

        let request = UserAccountManager.shared.authRequestAfterLoginOptionsChange(for: session)

        XCTAssertTrue(SalesforceManager.shared.debugNativeLoginActive)
        XCTAssertEqual(request.oauthClientId, "nativeKey")
    }

    func test_givenNativeSession_whenBrowserModeSelected_thenRestartBuildsBrowserRequestWithSelectedHost() throws {
        try NativeLoginDebugSettings.shared.apply(json: completeConfigJSON)
        SalesforceManager.shared.applyDebugNativeLoginSettings()
        let nativeRequest = UserAccountManager.shared.nativeLoginAuthRequest()
        let session = SFSDKAuthSession(nativeRequest, credentials: nil)
        session.oauthCoordinator.useNativeAuth = true
        NativeLoginDebugSettings.shared.mode = .browser

        let request = UserAccountManager.shared.authRequestAfterLoginOptionsChange(for: session)

        XCTAssertFalse(SalesforceManager.shared.debugNativeLoginActive)
        XCTAssertEqual(request.oauthClientId, UserAccountManager.shared.oauthClientID, "Browser login keeps the boot config")
        XCTAssertEqual(request.loginHost, UserAccountManager.shared.loginHost,
                       "The native request's community host must not carry over to browser login")
        XCTAssertNil(request.useDPoP)
    }
}
