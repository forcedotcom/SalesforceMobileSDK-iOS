//
//  NativeLoginManagerTests.swift
//  SalesforceSDKCore
//
//  Created by Brandon Page on 1/12/24.
//  Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import XCTest
import ObjectiveC
@testable import SalesforceSDKCore

final class NativeLoginManagerTests: XCTestCase {
    let nativeLoginManager = SalesforceManager.shared.useNativeLogin(withConsumerKey: "c", callbackUrl: "r", communityUrl: "l", nativeLoginViewController: UIViewController(), scene: nil)
    private var networkIdentifiersBeforeTest = Set<String>()
    private var restoreBootstrap: (() -> Void)?

    private func sharedNetworkIdentifiers() -> Set<String> {
        Set(Network.sharedInstanceIdentifiers()?.compactMap { $0 as? String } ?? [])
    }
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        networkIdentifiersBeforeTest = sharedNetworkIdentifiers()
        let sdk = SalesforceManager.shared
        let uam = UserAccountManager.shared
        let bootConfig = sdk.bootConfig
        let selector = sdk.bootConfigRuntimeSelector
        let clientId = uam.oauthClientID
        let redirect = uam.oauthCompletionURL
        let scopes = uam.scopes
        let nativeEnabled = uam.nativeLoginEnabled
        let fallback = uam.shouldFallbackToWebAuthentication
        let config = try XCTUnwrap(BootConfig([
            "remoteAccessConsumerKey": "bootstrap-test-app",
            "oauthRedirectURI": "bootstrap-test://callback", "oauthScopes": ["api"]
        ]))
        sdk.bootConfig = config
        sdk.bootConfigRuntimeSelector = nil
        uam.oauthClientID = config.remoteAccessConsumerKey
        uam.oauthCompletionURL = config.oauthRedirectURI
        uam.scopes = config.oauthScopes
        let original = try XCTUnwrap(class_getClassMethod(SFSDKWebViewStateManager.self,
            NSSelectorFromString("removeSessionForcefullyWithCompletionHandler:")))
        let replacement = try XCTUnwrap(class_getClassMethod(SFSDKWebViewStateManager.self,
            #selector(SFSDKWebViewStateManager.nativeTestRemoveSession(_:))))
        method_exchangeImplementations(original, replacement)
        restoreBootstrap = {
            method_exchangeImplementations(original, replacement)
            sdk.bootConfig = bootConfig
            sdk.bootConfigRuntimeSelector = selector
            uam.oauthClientID = clientId
            uam.oauthCompletionURL = redirect
            uam.scopes = scopes
            uam.nativeLoginEnabled = nativeEnabled
            uam.shouldFallbackToWebAuthentication = fallback
        }
        _ = KeychainHelper.removeAll()
        BiometricAuthenticationManagerInternal.shared.locked = false
    }
    
    @MainActor
    override func tearDown() async throws {
        _ = await UserAccountManager.shared.stopCurrentAuthentication()
        // Native identity requests own uniquely named SFNetwork instances. Remove only instances
        // created by this test so SFNetworkTests does not inherit an active request's session.
        sharedNetworkIdentifiers()
            .subtracting(networkIdentifiersBeforeTest)
            .forEach { Network.removeSharedInstance(forIdentifier: $0) }
        _ = KeychainHelper.removeAll()
        UserAccountManager.shared.clearAllAccountState()
        restoreBootstrap?()
        restoreBootstrap = nil
        try await super.tearDown()
    }
    
    func testUsernameValidation() async {
        var result = await nativeLoginManager.login(username: "", password: "")
        XCTAssertEqual(.invalidUsername, result, "Should not allow empty username.")
        result = await nativeLoginManager.login(username: "test@c", password: "")
        XCTAssertEqual(.invalidUsername, result, "Should not allow invalid username.")
        
        // success
        result = await nativeLoginManager.login(username: "test@c.co   ", password: "")
        XCTAssertEqual(.invalidPassword, result, "Should allow username.")
    }

    @MainActor
    func test_givenDPoPEnabled_whenPasswordAuthorizationFails_thenRequestHasProofAndPreservesBasic() async throws {
        let originalDPoP = SalesforceManager.shared.usesDPoP
        SalesforceManager.shared.usesDPoP = true
        let identifier = NetworkEphemeralInstanceIdentifier
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ScriptedURLProtocol.self] + (config.protocolClasses ?? [])
        ScriptedURLProtocol.installScripts([
            .init(statusCode: 400, headers: nil, body: Data("{\"error\":\"invalid_grant\"}".utf8))
        ], identifier: identifier)
        Network.setSessionConfiguration(config, identifier: identifier)
        defer {
            SalesforceManager.shared.usesDPoP = originalDPoP
            Network.removeSharedInstance(forIdentifier: identifier)
            ScriptedURLProtocol.removeScripts(identifier: identifier)
        }

        let manager = SalesforceManager.shared.useNativeLogin(
            withConsumerKey: "native-dpop-test",
            callbackUrl: "testapp://callback",
            communityUrl: "https://login.example.com/community",
            nativeLoginViewController: UIViewController(),
            scene: nil)
        let authRequest = SFSDKAuthRequest()
        authRequest.oauthClientId = "native-dpop-test"
        authRequest.oauthCompletionUrl = "testapp://callback"
        authRequest.loginHost = "https://login.example.com/community"
        let session = SFSDKAuthSession(authRequest, credentials: nil)
        session.isAuthenticating = true
        session.oauthCoordinator.useNativeAuth = true
        UserAccountManager.shared.authSessions[session.sceneId as NSString] = session
        defer {
            DPoPKeyStore.shared.delete(forCredentials: session.credentials)
            DPoPNonceCache.shared.clear(forScope: session.credentials.identifier)
        }
        let username = "native-test@example.com"
        let password = UUID().uuidString + "1a"
        let result = await manager.login(username: username, password: password)
        XCTAssertEqual(result, .invalidCredentials)
        let requests = ScriptedURLProtocol.capturedRequests(identifier: identifier)
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"),
                       "Basic \(Data("\(username):\(password)".utf8).base64EncodedString())")
        let proof = try XCTUnwrap(request.value(forHTTPHeaderField: "DPoP"),
                                  "Enabled native authorization must carry a proof without replacing Basic")
        let segments = proof.split(separator: ".")
        XCTAssertEqual(segments.count, 3)
        var encodedPayload = String(segments[1]).replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        encodedPayload += String(repeating: "=", count: (4 - encodedPayload.count % 4) % 4)
        let payloadData = try XCTUnwrap(Data(base64Encoded: encodedPayload))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: payloadData) as? [String: Any])
        XCTAssertEqual(payload["htm"] as? String, "POST")
        XCTAssertEqual(payload["htu"] as? String, request.url?.absoluteString)
        XCTAssertNotNil(payload["iat"] as? Int)
        XCTAssertNotNil(payload["jti"] as? String)
        XCTAssertNil(payload["ath"])
    }
    
    @MainActor
    func test_givenNonceChallenges_whenAllNativePathsAuthorize_thenRetryWithSameKeyAndFreshProofs() async throws {
        for path in 0...2 {
            try await withNativeSession { manager, session, identifier in
                ScriptedURLProtocol.installScripts([
                    .init(statusCode: 400, headers: ["DPoP-Nonce": "authorize-nonce"], body: Data("{\"error\":\"use_dpop_nonce\"}".utf8)),
                    .init(statusCode: 200, headers: ["DPoP-Nonce": "success-nonce"], body: Data("{\"code\":\"test-code\",\"sfdc_community_url\":\"https://community.example.com/site\",\"sfdc_community_id\":\"community\"}".utf8)),
                    .init(statusCode: 401, headers: ["DPoP-Nonce": "token-nonce"], body: Data("{\"error\":\"use_dpop_nonce\"}".utf8)),
                    .init(statusCode: 400, headers: nil, body: Data("{\"error\":\"invalid_grant\"}".utf8))
                ], identifier: identifier)
                let result: NativeLoginResult
                switch path {
                case 0: result = await manager.login(username: "native-test@example.com", password: UUID().uuidString + "1a")
                case 1: result = await manager.submitPasswordlessAuthorizationRequest(otp: "123456", otpIdentifier: "request-id", otpVerificationMethod: .sms)
                default: result = await manager.completeRegistration(otp: "123456", requestIdentifier: "request-id", otpVerificationMethod: .email)
                }
                XCTAssertEqual(result, .unknownError)
                let requests = ScriptedURLProtocol.capturedRequests(identifier: identifier)
                XCTAssertEqual(requests.count, 4)
                guard requests.count == 4 else { return }
                let payloads = try requests.map { try self.proofPart($0, index: 1) }
                let headers = try requests.map { try self.proofPart($0, index: 0) }
                XCTAssertEqual(headers[0]["jwk"] as? NSDictionary, headers[3]["jwk"] as? NSDictionary)
                XCTAssertEqual(Set(payloads.compactMap { $0["jti"] as? String }).count, 4)
                XCTAssertNil(payloads[0]["nonce"])
                XCTAssertEqual(payloads[1]["nonce"] as? String, "authorize-nonce")
                XCTAssertEqual(payloads[2]["nonce"] as? String, "success-nonce")
                XCTAssertEqual(payloads[3]["nonce"] as? String, "token-nonce")
                let bodies = try requests.map { try self.requestBody($0) }
                XCTAssertFalse(bodies[0].isEmpty)
                XCTAssertFalse(bodies[2].isEmpty)
                XCTAssertEqual(bodies[0], bodies[1])
                XCTAssertEqual(bodies[2], bodies[3])
                let binding = try XCTUnwrap(self.formBody(bodies[0])["dpop_jkt"])
                XCTAssertEqual(try self.formBody(bodies[1])["dpop_jkt"], binding)
                for request in requests {
                    XCTAssertEqual(try self.proofThumbprint(request), binding)
                }
                XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Authorization"), requests[1].value(forHTTPHeaderField: "Authorization"))
                XCTAssertTrue(requests[0].value(forHTTPHeaderField: "Authorization")?.hasPrefix("Basic ") == true)
                XCTAssertNil(requests[2].value(forHTTPHeaderField: "Authorization"))
                for (request, payload) in zip(requests, payloads) {
                    XCTAssertEqual(payload["htu"] as? String, request.url?.absoluteString)
                    XCTAssertEqual(payload["htm"] as? String, "POST")
                    XCTAssertNil(payload["ath"])
                }
                XCTAssertNil(DPoPNonceCache.shared.latest(forScope: session.credentials.identifier))
                XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials))
            }
        }
    }

    @MainActor
    func test_givenNativeNonChallenge401WithNonce_whenAuthorizeOrToken_thenDoesNotReplayCredentials() async throws {
        for path in 0...2 {
            for tokenEndpoint in [false, true] {
                for body in ["{\"error\":\"invalid_client\"}", "{\"error\":\"invalid_grant\"}", "{}", "not-json",
                             "{\"error_description\":\"use_dpop_nonce\"}"] {
                    try await withNativeSession { manager, _, identifier in
                        var scripts = [ScriptedURLProtocol.ScriptedResponse]()
                        if tokenEndpoint {
                            scripts.append(.init(statusCode: 200, headers: nil, body: Data("{\"code\":\"test-code\",\"sfdc_community_url\":\"https://community.example.com/site\",\"sfdc_community_id\":\"community\"}".utf8)))
                        }
                        scripts.append(.init(statusCode: 401, headers: ["DPoP-Nonce": "nonce"], body: Data(body.utf8)))
                        scripts.append(.init(statusCode: 400, headers: nil, body: Data("{\"error\":\"invalid_grant\"}".utf8)))
                        ScriptedURLProtocol.installScripts(scripts, identifier: identifier)
                        let result: NativeLoginResult
                        switch path {
                        case 0: result = await manager.login(username: "native-test@example.com", password: UUID().uuidString + "1a")
                        case 1: result = await manager.submitPasswordlessAuthorizationRequest(otp: "123456", otpIdentifier: "request-id", otpVerificationMethod: .sms)
                        default: result = await manager.completeRegistration(otp: "123456", requestIdentifier: "request-id", otpVerificationMethod: .email)
                        }
                        XCTAssertNotEqual(result, .success)
                        XCTAssertEqual(ScriptedURLProtocol.capturedRequests(identifier: identifier).count, tokenEndpoint ? 2 : 1,
                                       "Unrelated 401 must not replay credentials: path=\(path) token=\(tokenEndpoint) body=\(body)")
                    }
                }
            }
        }
    }

    func test_givenMalformedProof_whenDecodingPart_thenThrows() throws {
        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com")))
        for proof in ["e30.e30.signature.extra", "e30", "e30..signature", "e30.%%%.signature", "e30.W10.signature"] {
            request.setValue(proof, forHTTPHeaderField: "DPoP")
            XCTAssertThrowsError(try proofPart(request, index: 1), "Malformed proof: \(proof)")
        }
        request.setValue("e30.e30.signature", forHTTPHeaderField: "DPoP")
        for index in [-1, 3] {
            XCTAssertThrowsError(try proofPart(request, index: index), "Invalid proof index: \(index)")
        }
        XCTAssertTrue(try proofPart(request, index: 1).isEmpty)
    }

    func test_givenDuplicateFormParameters_whenDecodingBody_thenThrows() throws {
        XCTAssertThrowsError(try formBody(Data("code=first&code=second".utf8)))
        XCTAssertThrowsError(try formBody(Data("code=first&%63ode=second".utf8)))
        XCTAssertEqual(try formBody(Data("code=first&empty=".utf8)), ["code": "first", "empty": ""])
    }

    private enum RequestDecodingError: Error {
        case malformedProof
        case duplicateFormParameter(String)
    }

    private func proofPart(_ request: URLRequest, index: Int) throws -> [String: Any] {
        let proof = try XCTUnwrap(request.value(forHTTPHeaderField: "DPoP"))
        let parts = proof.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty }), parts.indices.contains(index) else {
            throw RequestDecodingError.malformedProof
        }
        var encoded = String(parts[index]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let data = Data(base64Encoded: encoded),
              let part = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RequestDecodingError.malformedProof
        }
        return part
    }

    @MainActor
    func test_givenCapturedDPoPIntent_whenAllNativePathsAuthorize_thenCodeBindingMatchesTransactionProofs() async throws {
        for enabled in [true, false] {
            for path in 0...2 {
                try await withNativeSession(usesDPoP: enabled) { manager, session, identifier in
                    // The request snapshot, not a later process-wide flag, owns binding intent.
                    session.oauthRequest.useDPoP = NSNumber(value: enabled)
                    SalesforceManager.shared.usesDPoP = !enabled
                    let expectedThumbprint: String?
                    if enabled {
                        let pair = try DPoPKeyStore.shared.keyPair(forCredentials: session.credentials)
                        expectedThumbprint = try DPoPProofBuilder.jwkThumbprint(publicKey: pair.publicKey)
                    } else {
                        expectedThumbprint = nil
                    }
                    let config = URLSessionConfiguration.ephemeral
                    config.protocolClasses = [NativeIntentURLProtocol.self]
                    Network.setSessionConfiguration(config, identifier: identifier)
                    NativeIntentURLProtocol.requests = []
                    NativeIntentURLProtocol.onAuthorize = { SalesforceManager.shared.usesDPoP = !enabled }
                    defer { NativeIntentURLProtocol.onAuthorize = nil }
                    let result: NativeLoginResult
                    switch path {
                    case 0: result = await manager.login(username: "native-test@example.com", password: "Test-password1")
                    case 1: result = await manager.submitPasswordlessAuthorizationRequest(otp: "123456", otpIdentifier: "request-id", otpVerificationMethod: .sms)
                    default: result = await manager.completeRegistration(otp: "123456", requestIdentifier: "request-id", otpVerificationMethod: .email)
                    }
                    XCTAssertEqual(result, .unknownError)
                    let requests = NativeIntentURLProtocol.requests
                    XCTAssertEqual(requests.count, 2)
                    guard requests.count == 2 else { return }
                    let authorizeBody = try self.formBody(requests[0])
                    let tokenBody = try self.formBody(requests[1])
                    XCTAssertEqual(authorizeBody["dpop_jkt"], expectedThumbprint,
                                   "Native authorize path \(path) must bind the code to its transaction key")
                    XCTAssertNil(tokenBody["dpop_jkt"])
                    XCTAssertEqual(Set(authorizeBody.keys), Set(["response_type", "client_id", "redirect_uri", "code_challenge"] + (enabled ? ["dpop_jkt"] : [])))
                    XCTAssertEqual(authorizeBody["response_type"], "code_credentials")
                    XCTAssertEqual(authorizeBody["client_id"], "native-dpop-test")
                    XCTAssertEqual(authorizeBody["redirect_uri"], "testapp://callback")
                    let verifier = try XCTUnwrap(tokenBody["code_verifier"])
                    let digest = try XCTUnwrap((Data(verifier.utf8) as NSData).sfsdk_sha256())
                    XCTAssertEqual(authorizeBody["code_challenge"], (digest as NSData).sfsdk_base64UrlString())
                    XCTAssertEqual(tokenBody["code"], "test-code")
                    XCTAssertEqual(tokenBody["client_id"], authorizeBody["client_id"])
                    XCTAssertEqual(tokenBody["redirect_uri"], authorizeBody["redirect_uri"])
                    let basicValues = path == 0 ? "native-test@example.com:Test-password1" : "request-id:123456"
                    XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Authorization"), "Basic \(Data(basicValues.utf8).base64EncodedString())")
                    XCTAssertNil(requests[1].value(forHTTPHeaderField: "Authorization"))
                    for request in requests {
                        XCTAssertEqual(request.value(forHTTPHeaderField: "DPoP") != nil, enabled)
                        if enabled {
                            XCTAssertEqual(try self.proofThumbprint(request), expectedThumbprint)
                        }
                    }
                    XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials))
                }
            }
        }
    }

    private func formBody(_ request: URLRequest) throws -> [String: String] {
        try formBody(requestBody(request))
    }

    private func formBody(_ data: Data) throws -> [String: String] {
        let body = try XCTUnwrap(String(data: data, encoding: .utf8))
        let items = try XCTUnwrap(URLComponents(string: "https://example.com/?\(body)")?.queryItems)
        var parameters: [String: String] = [:]
        for item in items {
            guard parameters[item.name] == nil else {
                throw RequestDecodingError.duplicateFormParameter(item.name)
            }
            parameters[item.name] = item.value ?? ""
        }
        return parameters
    }

    private func proofThumbprint(_ request: URLRequest) throws -> String {
        let header = try proofPart(request, index: 0)
        let jwk = try XCTUnwrap(header["jwk"] as? [String: String])
        let canonical = try JSONSerialization.data(withJSONObject: jwk, options: [.sortedKeys, .withoutEscapingSlashes])
        let digest = try XCTUnwrap((canonical as NSData).sfsdk_sha256())
        return (digest as NSData).sfsdk_base64UrlString()
    }

    private func requestBody(_ request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }
        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            XCTAssertGreaterThanOrEqual(count, 0)
            guard count > 0 else { break }
            body.append(contentsOf: buffer.prefix(count))
        }
        return body
    }

    @MainActor
    func test_givenDefaultControllerScene_whenNilSceneLoginStarts_thenExistingSessionOwnsProof() async throws {
        try await withNativeSession { _, unscopedSession, identifier in
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
            let controller = UIViewController()
            let window = UIWindow(windowScene: scene)
            window.rootViewController = controller
            window.isHidden = false
            defer { window.isHidden = true }
            UserAccountManager.shared.authSessions.removeObject(unscopedSession.sceneId as NSString)
            let request = unscopedSession.oauthRequest
            request.scene = scene
            let session = SFSDKAuthSession(request, credentials: nil)
            session.isAuthenticating = true
            session.oauthCoordinator.useNativeAuth = true
            UserAccountManager.shared.authSessions[session.sceneId as NSString] = session
            defer {
                UserAccountManager.shared.authSessions.removeObject(session.sceneId as NSString)
                DPoPKeyStore.shared.delete(forCredentials: session.credentials)
                DPoPNonceCache.shared.clear(forScope: session.credentials.identifier)
            }
            let manager = SalesforceManager.shared.useNativeLogin(
                withConsumerKey: "native-dpop-test", callbackUrl: "testapp://callback",
                communityUrl: "https://login.example.com/community", nativeLoginViewController: controller, scene: nil)
            let key = try DPoPKeyStore.shared.keyPair(forScope: session.credentials.identifier)
            let expected = try Encryptor.jwkP256(from: key.publicKey)
            ScriptedURLProtocol.installScripts([
                .init(statusCode: 400, headers: nil, body: Data("{\"error\":\"invalid_grant\"}".utf8))
            ], identifier: identifier)
            _ = await manager.login(username: "native-test@example.com", password: "Test-password1")
            let captured = try XCTUnwrap(ScriptedURLProtocol.capturedRequests(identifier: identifier).first)
            let header = try proofPart(captured, index: 0)
            let jwk = try XCTUnwrap(header["jwk"] as? [String: String])
            XCTAssertEqual(jwk, expected)
            XCTAssertEqual(UserAccountManager.shared.authSessions.allValues.count, 1)
        }
    }

    @MainActor
    func test_givenCancelledAuthorization_whenResponseArrives_thenNoTokenRequestOrAbandonedKey() async throws {
        for enabled in [true, false] {
            try await withNativeSession(usesDPoP: enabled) { manager, session, identifier in
                let config = URLSessionConfiguration.ephemeral
                config.protocolClasses = [NativeIntentURLProtocol.self]
                Network.setSessionConfiguration(config, identifier: identifier)
                NativeIntentURLProtocol.requests = []
                NativeIntentURLProtocol.onAuthorize = {
                    UserAccountManager.shared.stopCurrentAuthentication()
                }
                defer { NativeIntentURLProtocol.onAuthorize = nil }
                let result = await manager.login(username: "native-test@example.com", password: "Test-password1")
                XCTAssertNotEqual(result, .success)
                XCTAssertEqual(NativeIntentURLProtocol.requests.count, 1)
                XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials))
                XCTAssertNil(DPoPNonceCache.shared.latest(forScope: session.credentials.identifier))
            }
        }
    }

    // Task.cancel does not propagate through the public Objective-C async bridge.
    // Cancellation coverage uses stopCurrentAuthentication/reset, the supported lifecycle APIs.

    @MainActor
    func test_givenBootstrapConfigMismatch_whenNativeLoginRunsWithoutDPoP_thenCapturedRequestOwnsSession() async throws {
        try await withNativeSession(usesDPoP: false) { _, unscopedSession, identifier in
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
            UserAccountManager.shared.authSessions.removeObject(unscopedSession.sceneId as NSString)
            let request = unscopedSession.oauthRequest
            request.scene = scene
            let session = SFSDKAuthSession(request, credentials: nil)
            session.isAuthenticating = true
            session.oauthCoordinator.useNativeAuth = true
            UserAccountManager.shared.authSessions[session.sceneId as NSString] = session
            defer { UserAccountManager.shared.authSessions.removeObject(session.sceneId as NSString) }
            let manager = SalesforceManager.shared.useNativeLogin(
                withConsumerKey: session.oauthRequest.oauthClientId,
                callbackUrl: session.oauthRequest.oauthCompletionUrl,
                communityUrl: session.oauthRequest.loginHost,
                nativeLoginViewController: UIViewController(), scene: scene)
            // Reproduce authenticateWithRequest's app-config bootstrap overwriting credentials,
            // while the native manager and captured request still use their native configuration.
            session.credentials.clientId = "boot-client"
            session.credentials.redirectUri = "bootapp://callback"
            ScriptedURLProtocol.installScripts([
                .init(statusCode: 200, headers: nil, body: Data("{\"code\":\"test-code\",\"sfdc_community_url\":\"https://community.example.com/site\",\"sfdc_community_id\":\"community\"}".utf8)),
                .init(statusCode: 400, headers: nil, body: Data("{\"error\":\"invalid_grant\"}".utf8))
            ], identifier: identifier)
            let result = await manager.login(username: "native-test@example.com", password: "Test-password1")
            XCTAssertEqual(result, .unknownError, "Native session must reach token exchange despite boot-config mismatch")
            XCTAssertEqual(session.credentials.clientId, session.oauthRequest.oauthClientId)
            XCTAssertEqual(session.credentials.redirectUri, session.oauthRequest.oauthCompletionUrl)
            let requests = ScriptedURLProtocol.capturedRequests(identifier: identifier)
            XCTAssertEqual(requests.count, 2)
            for request in requests {
                XCTAssertNil(request.value(forHTTPHeaderField: "DPoP"))
                let body = try self.formBody(request)
                XCTAssertEqual(body["client_id"], session.oauthRequest.oauthClientId)
                XCTAssertEqual(body["redirect_uri"], session.oauthRequest.oauthCompletionUrl)
            }
            XCTAssertTrue(UserAccountManager.shared.authSessions[session.sceneId as NSString] === session)
        }
    }

    @MainActor
    func test_givenTokenHandoff_whenResetThenLateIdentitySuccess_thenNoStaleAccountIsPersisted() async throws {
        for resetAll in [true, false] {
            try await withNativeSession { manager, session, identifier in
                let original = try XCTUnwrap(class_getInstanceMethod(SFIdentityCoordinator.self, #selector(SFIdentityCoordinator.initiateIdentityDataRetrieval)))
                let replacement = try XCTUnwrap(class_getInstanceMethod(SFIdentityCoordinator.self, #selector(SFIdentityCoordinator.nativeTestIdentityRetrieval)))
                let cancel = try XCTUnwrap(class_getInstanceMethod(SFIdentityCoordinator.self, #selector(SFIdentityCoordinator.cancelRetrieval)))
                let captureCancel = try XCTUnwrap(class_getInstanceMethod(SFIdentityCoordinator.self, #selector(SFIdentityCoordinator.nativeTestCancelRetrieval)))
                var identity: SFIdentityCoordinator?
                var cancelled = false
                NativeIdentityCapture.onRetrieve = { coordinator in
                    identity = coordinator
                    coordinator.setValue(true, forKey: "retrievingData")
                }
                NativeIdentityCapture.onCancel = { coordinator in
                    XCTAssertTrue(coordinator === identity)
                    XCTAssertTrue(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials), "Invalidate identity before deleting its bound key")
                    cancelled = true
                }
                method_exchangeImplementations(original, replacement)
                method_exchangeImplementations(cancel, captureCancel)
                defer {
                    method_exchangeImplementations(original, replacement)
                    method_exchangeImplementations(cancel, captureCancel)
                    NativeIdentityCapture.onRetrieve = nil
                    NativeIdentityCapture.onCancel = nil
                }
                ScriptedURLProtocol.installScripts([
                    .init(statusCode: 200, headers: nil, body: Data("{\"code\":\"test-code\",\"sfdc_community_url\":\"https://community.example.com/site\",\"sfdc_community_id\":\"community\"}".utf8)),
                    .init(statusCode: 200, headers: nil, body: Data("{\"access_token\":\"test-token\",\"refresh_token\":\"test-refresh\",\"token_type\":\"DPoP\",\"instance_url\":\"https://community.example.com\",\"id\":\"https://community.example.com/id/00D000000000001/005000000000001\"}".utf8))
                ], identifier: identifier)
                let result = await manager.login(username: "native-test@example.com", password: "Test-password1")
                XCTAssertEqual(result, .success)
                let coordinator = try XCTUnwrap(identity)
                XCTAssertTrue(coordinator.retrievingData)
                XCTAssertTrue(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials))
                if resetAll {
                    _ = await UserAccountManager.shared.stopCurrentAuthentication()
                } else {
                    UserAccountManager.shared.perform(NSSelectorFromString("resetAuthentication:"), with: session)
                }
                XCTAssertTrue(cancelled, "Reset must cancel in-flight identity retrieval")
                XCTAssertFalse(coordinator.retrievingData)
                XCTAssertNil(coordinator.delegate)
                XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials))
                // Deliver success after cancellation, even if the network completion was already queued.
                coordinator.perform(NSSelectorFromString("processResponse:"), with: Data("{\"user_id\":\"005000000000001\",\"organization_id\":\"00D000000000001\",\"username\":\"native-test@example.com\"}".utf8))
                // Also exercise a delegate callback captured before reset, bypassing delegate detachment.
                UserAccountManager.shared.perform(NSSelectorFromString("identityCoordinatorRetrievedData:"), with: coordinator)
                let drained = expectation(description: "Late identity callback processed")
                DispatchQueue.main.async { drained.fulfill() }
                await fulfillment(of: [drained], timeout: 5)
                XCTAssertTrue(UserAccountManager.shared.userAccounts()?.isEmpty ?? true, "Late identity must not persist credentials whose key was reclaimed")
                XCTAssertNil(UserAccountManager.shared.currentUserAccount)
            }
        }
    }

    @MainActor
    func test_givenRetainedIdentityAlert_whenResetOrReplaced_thenRetryCannotStartRetrieval() async throws {
        for scenario in 0...5 {
            try await withNativeSession { _, session, _ in
                UserAccountManager.shared.perform(NSSelectorFromString("beginNativeAuthentication:"), with: ["clientId": session.oauthRequest.oauthClientId, "redirectUri": session.oauthRequest.oauthCompletionUrl, "loginUrl": session.oauthRequest.loginHost])
                session.nativeLogin = true
                session.credentials.accessToken = "test-token"
                session.credentials.tokenType = "DPoP"
                session.credentials.identityUrl = URL(string: "https://community.example.com/id/test")
                let coordinator = SFIdentityCoordinator(credentials: session.credentials)
                coordinator.authSession = session
                session.identityCoordinator = coordinator
                let displayed = expectation(description: "Real identity Retry handler captured")
                let originalDisplay = UserAccountManager.shared.alertDisplayBlock
                var retry: (() -> Void)?
                UserAccountManager.shared.alertDisplayBlock = { message, _ in
                    retry = message.actionOneCompletion
                    displayed.fulfill()
                }
                let send = try XCTUnwrap(class_getInstanceMethod(Network.self, NSSelectorFromString("sendRequest:dataResponseBlock:")))
                let capture = try XCTUnwrap(class_getInstanceMethod(Network.self, #selector(Network.nativeTestHoldLifecycleRequest(_:dataResponseBlock:))))
                method_exchangeImplementations(send, capture)
                NativeLifecycleCapture.requests = []
                NativeLifecycleCapture.holdIdentity = true
                defer {
                    coordinator.cancelRetrieval()
                    method_exchangeImplementations(send, capture)
                    UserAccountManager.shared.alertDisplayBlock = originalDisplay
                    NativeLifecycleCapture.responses = []
                    NativeLifecycleCapture.holdIdentity = false
                }
                coordinator.initiateIdentityDataRetrieval()
                XCTAssertEqual(NativeLifecycleCapture.requests.count, 1)
                UserAccountManager.shared.identityCoordinator(coordinator, didFailWithError: NSError(domain: "test", code: 1))
                coordinator.cancelRetrieval() // Failure delivery normally cleans up this retrieval.
                await fulfillment(of: [displayed], timeout: 5)
                if scenario == 1 {
                    let successor = SFSDKAuthSession(session.oauthRequest, credentials: nil)
                    successor.isAuthenticating = true
                    UserAccountManager.shared.authSessions[session.sceneId as NSString] = successor
                    DPoPKeyStore.shared.delete(forCredentials: session.credentials)
                } else if scenario == 2 {
                    _ = await UserAccountManager.shared.stopCurrentAuthentication()
                } else if scenario == 3 {
                    session.credentials.accessToken = nil
                    UserAccountManager.shared.perform(NSSelectorFromString("beginNativeAuthentication:"), with: ["clientId": session.oauthRequest.oauthClientId, "redirectUri": session.oauthRequest.oauthCompletionUrl, "loginUrl": session.oauthRequest.loginHost])
                    session.credentials.accessToken = "successor-token"
                } else if scenario == 0 || scenario == 5 {
                    UserAccountManager.shared.perform(NSSelectorFromString("resetAuthentication:"), with: session)
                    if scenario == 5 { coordinator.authSession = nil }
                }
                try XCTUnwrap(retry)()
                XCTAssertEqual(NativeLifecycleCapture.requests.count, scenario == 4 ? 2 : 1, "Only the still-current attempt may start retained alert Retry")
                XCTAssertEqual(coordinator.retrievingData, scenario == 4)
                XCTAssertEqual(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials), scenario == 4)
            }
        }
    }

    @MainActor
    func test_givenNativeIdentityFailure_whenDismissed_thenAttemptIsReclaimedAndFreshLoginCanStart() async throws {
        for superseded in [false, true] {
            try await withNativeSession { manager, session, identifier in
                let uam = UserAccountManager.shared
                let configuration = ["clientId": "native-dpop-test", "redirectUri": "testapp://callback", "loginUrl": "https://login.example.com/community"]
                let retrieve = try XCTUnwrap(class_getInstanceMethod(SFIdentityCoordinator.self, #selector(SFIdentityCoordinator.initiateIdentityDataRetrieval)))
                let capture = try XCTUnwrap(class_getInstanceMethod(SFIdentityCoordinator.self, #selector(SFIdentityCoordinator.nativeTestIdentityRetrieval)))
                method_exchangeImplementations(retrieve, capture)
                defer { method_exchangeImplementations(retrieve, capture) }
                ScriptedURLProtocol.installScripts([
                    .init(statusCode: 200, headers: nil, body: Data("{\"code\":\"test-code\",\"sfdc_community_url\":\"https://community.example.com/site\",\"sfdc_community_id\":\"community\"}".utf8)),
                    .init(statusCode: 200, headers: nil, body: Data("{\"access_token\":\"test-token\",\"refresh_token\":\"test-refresh\",\"token_type\":\"DPoP\",\"instance_url\":\"https://community.example.com\",\"id\":\"https://community.example.com/id/00D000000000001/005000000000001\"}".utf8))
                ], identifier: identifier)
                let result = await manager.login(username: "native-test@example.com", password: "Test-password1")
                XCTAssertEqual(result, .success)
                let coordinator = try XCTUnwrap(session.identityCoordinator)
                let url = try XCTUnwrap(URL(string: "https://community.example.com"))
                DPoPNonceCache.shared.setNonce("identity-nonce", htu: url, scope: session.credentials.identifier)
                let displayed = expectation(description: "Identity failure alert captured")
                let originalDisplay = uam.alertDisplayBlock
                var dismiss: (() -> Void)?
                uam.alertDisplayBlock = { message, _ in
                    if message.value(forKey: "actionTwoCompletion") != nil {
                        dismiss = message.actionTwoCompletion
                    }
                    displayed.fulfill()
                }
                defer { uam.alertDisplayBlock = originalDisplay }
                uam.identityCoordinator(coordinator, didFailWithError: NSError(domain: "NativeIdentityTest", code: 1))
                await fulfillment(of: [displayed], timeout: 5)
                if superseded {
                    session.credentials.accessToken = nil
                    _ = uam.perform(NSSelectorFromString("beginNativeAuthentication:"), with: configuration)
                    session.credentials.accessToken = "successor-token"
                    _ = try DPoPKeyStore.shared.keyPair(forCredentials: session.credentials)
                    DPoPNonceCache.shared.setNonce("successor-nonce", htu: url, scope: session.credentials.identifier)
                }
                // Invoke the real terminal alert action, not reset directly.
                dismiss?()
                XCTAssertNotNil(dismiss, "Native identity Dismiss must have scoped terminal cleanup")
                XCTAssertEqual(session.isAuthenticating, superseded)
                XCTAssertEqual(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials), superseded)
                XCTAssertEqual(DPoPNonceCache.shared.latest(forScope: session.credentials.identifier), superseded ? "successor-nonce" : nil)
                if superseded {
                    XCTAssertEqual(session.credentials.accessToken, "successor-token")
                    XCTAssertTrue(uam.authSessions[session.sceneId as NSString] === session)
                } else {
                    XCTAssertNil(coordinator.delegate)
                    XCTAssertNil(session.credentials.accessToken, "Terminal Dismiss must discard the unpersisted token")
                    XCTAssertNil(uam.authSessions[session.sceneId as NSString])
                    let fresh = try XCTUnwrap(uam.perform(NSSelectorFromString("beginNativeAuthentication:"), with: configuration)?.takeUnretainedValue() as? NSDictionary)
                    let freshSession = try XCTUnwrap(fresh["session"] as? SFSDKAuthSession)
                    XCTAssertFalse(freshSession === session)
                    XCTAssertNil(freshSession.credentials.accessToken)
                    uam.perform(NSSelectorFromString("resetAuthentication:"), with: freshSession)
                }
            }
        }
    }

    @MainActor
    func test_givenNativeDPoP_whenCryptoDispatched_thenRunsOffMainThread() async throws {
        let isMain = try await NativeLoginManagerInternal.performCrypto { Thread.isMainThread }
        XCTAssertFalse(isMain, "Native key generation and proof signing must run off the UI thread")
        XCTAssertTrue(Thread.isMainThread, "Session ownership and UI resume on the main actor")
    }

    @MainActor
    func test_givenCancelledNativeAttempt_whenCryptoFinishesLate_thenAbandonReclaimsLateKey() async throws {
        try await withNativeSession { _, session, _ in
            let uam = UserAccountManager.shared
            let context = try XCTUnwrap(uam.perform(NSSelectorFromString("beginNativeAuthentication:"), with: [
                "clientId": "native-dpop-test", "redirectUri": "testapp://callback", "loginUrl": "https://login.example.com/community"
            ])?.takeUnretainedValue() as? NSDictionary)
            uam.perform(NSSelectorFromString("resetAuthentication:"), with: session)
            let scope = session.credentials.identifier
            _ = try await NativeLoginManagerInternal.performCrypto {
                try DPoPKeyStore.shared.keyPair(forScope: scope)
            }
            XCTAssertTrue(DPoPKeyStore.shared.hasKeyPair(forScope: scope))
            uam.perform(NSSelectorFromString("abandonNativeAuthentication:"), with: context)
            XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forScope: scope))
            XCTAssertNil(uam.authSessions[session.sceneId as NSString])
        }
    }


    @MainActor
    func test_givenNativeIdentityPending_whenSceneDisconnects_thenRetrievalAndUnreferencedDPoPStateAreReclaimed() async throws {
        for referenced in [false, true] {
            try await withNativeSession { _, unscoped, _ in
                let uam = UserAccountManager.shared
                let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first)
                uam.authSessions.removeObject(unscoped.sceneId as NSString)
                unscoped.oauthRequest.scene = scene
                let session = SFSDKAuthSession(unscoped.oauthRequest, credentials: nil)
                session.isAuthenticating = true
                session.oauthCoordinator.useNativeAuth = true
                session.nativeLogin = true
                session.credentials.accessToken = "test-token"
                uam.authSessions[session.sceneId as NSString] = session
                let coordinator = SFIdentityCoordinator(credentials: session.credentials)
                coordinator.authSession = session
                coordinator.delegate = uam
                coordinator.setValue(true, forKey: "retrievingData")
                session.identityCoordinator = coordinator
                _ = try DPoPKeyStore.shared.keyPair(forCredentials: session.credentials)
                DPoPNonceCache.shared.setNonce("identity-nonce", htu: try XCTUnwrap(URL(string: "https://community.example.com")), scope: session.credentials.identifier)
                let other = SFSDKAuthSession(SFSDKAuthRequest(), credentials: referenced ? session.credentials : nil)
                other.isAuthenticating = true
                uam.authSessions["other-scene" as NSString] = other
                defer {
                    uam.authSessions.removeObject("other-scene" as NSString)
                    uam.authSessions.removeObject(session.sceneId as NSString)
                    DPoPKeyStore.shared.delete(forCredentials: session.credentials)
                    DPoPNonceCache.shared.clear(forScope: session.credentials.identifier)
                }
                NotificationCenter.default.post(name: UIScene.didDisconnectNotification, object: scene)
                XCTAssertNil(uam.authSessions[session.sceneId as NSString])
                XCTAssertFalse(session.isAuthenticating)
                XCTAssertFalse(coordinator.retrievingData)
                XCTAssertNil(coordinator.delegate)
                XCTAssertEqual(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials), referenced)
                XCTAssertEqual(DPoPNonceCache.shared.latest(forScope: session.credentials.identifier), referenced ? "identity-nonce" : nil)
                XCTAssertTrue(uam.authSessions["other-scene" as NSString] === other)
            }
        }
    }

    @MainActor
    func test_givenRealIdentityRefresh_whenResetBeforeLateResponse_thenNoNonceRetryOrKeyRecreation() async throws {
        enum SimulatedFixtureError: Error { case afterTransportStarted }
        for scenario in 0...9 {
            let status = [200, 400, 401, 0][scenario % 4]
            try await withNativeSession { manager, session, identifier in
                let send = try XCTUnwrap(class_getInstanceMethod(Network.self, NSSelectorFromString("sendRequest:dataResponseBlock:")))
                let capture = try XCTUnwrap(class_getInstanceMethod(Network.self, #selector(Network.nativeTestHoldLifecycleRequest(_:dataResponseBlock:))))
                let refreshClass: AnyClass = try XCTUnwrap(NSClassFromString("SFSDKTokenRefreshCoordinator"))
                let refresh = try XCTUnwrap(class_getInstanceMethod(refreshClass, NSSelectorFromString("refreshSessionForCredentials:completion:error:")))
                let observeRefresh = try XCTUnwrap(class_getInstanceMethod(NSObject.self, #selector(NSObject.nativeTestObserveRealRefresh(_:completion:error:))))
                let refreshCompleted = XCTestExpectation(description: "Real refresh completion delivered")
                var didCompleteRefresh = false
                NativeLifecycleCapture.onRefreshCompleted = {
                    didCompleteRefresh = true
                    refreshCompleted.fulfill()
                }
                NativeLifecycleCapture.requests = []
                NativeLifecycleCapture.responses = []
                let started = expectation(description: "Real OAuth refresh reached transport")
                NativeLifecycleCapture.onRefresh = {
                    NativeLifecycleCapture.onRefresh = nil
                    started.fulfill()
                }
                method_exchangeImplementations(send, capture)
                method_exchangeImplementations(refresh, observeRefresh)
                defer {
                    session.identityCoordinator.cancelRetrieval()
                    method_exchangeImplementations(send, capture)
                    method_exchangeImplementations(refresh, observeRefresh)
                    NativeLifecycleCapture.onRefreshCompleted = nil
                    NativeLifecycleCapture.onRefresh = nil
                    NativeLifecycleCapture.responses = []
                }
                do {
                ScriptedURLProtocol.installScripts([
                    .init(statusCode: 200, headers: nil, body: Data("{\"code\":\"test-code\",\"sfdc_community_url\":\"https://community.example.com/site\",\"sfdc_community_id\":\"community\"}".utf8)),
                    .init(statusCode: 200, headers: nil, body: Data("{\"access_token\":\"test-token\",\"refresh_token\":\"test-refresh\",\"token_type\":\"DPoP\",\"instance_url\":\"https://community.example.com\",\"id\":\"https://community.example.com/id/00D000000000001/005000000000001\"}".utf8))
                ], identifier: identifier)
                let result = await manager.login(username: "native-test@example.com", password: "Test-password1")
                XCTAssertEqual(result, .success)
                await fulfillment(of: [started], timeout: 5)
                let request = try XCTUnwrap(NativeLifecycleCapture.requests.last)
                let response = try XCTUnwrap(NativeLifecycleCapture.responses.last)
                if scenario == 9 { throw SimulatedFixtureError.afterTransportStarted }
                XCTAssertNotNil(request.value(forHTTPHeaderField: "DPoP"))
                if scenario == 8 {
                    let replayed = expectation(description: "Active real refresh replays identity")
                    NativeLifecycleCapture.onIdentity = { replayed.fulfill() }
                    NativeLifecycleCapture.holdIdentity = true
                    defer {
                        NativeLifecycleCapture.onIdentity = nil
                        NativeLifecycleCapture.holdIdentity = false
                    }
                    let url = try XCTUnwrap(request.url)
                    let challenge = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 400, httpVersion: "HTTP/1.1", headerFields: ["DPoP-Nonce": "active-refresh-nonce"]))
                    response(Data("{\"error\":\"use_dpop_nonce\"}".utf8), challenge, nil)
                    XCTAssertEqual(NativeLifecycleCapture.responses.count, 2, "Active refresh retries nonce challenge exactly once")
                    let retry = try XCTUnwrap(NativeLifecycleCapture.requests.last)
                    XCTAssertEqual(try self.proofThumbprint(request), try self.proofThumbprint(retry))
                    XCTAssertEqual(try self.proofPart(retry, index: 1)["nonce"] as? String, "active-refresh-nonce")
                    let success = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["DPoP-Nonce": "success-refresh-nonce"]))
                    try XCTUnwrap(NativeLifecycleCapture.responses.last)(Data("{\"access_token\":\"active-refreshed-token\",\"token_type\":\"DPoP\",\"instance_url\":\"https://community.example.com\"}".utf8), success, nil)
                    await fulfillment(of: [replayed], timeout: 5)
                    await fulfillment(of: [refreshCompleted], timeout: 5)
                    XCTAssertEqual(session.credentials.accessToken, "active-refreshed-token")
                    XCTAssertTrue(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials))
                    XCTAssertEqual(DPoPNonceCache.shared.latest(forScope: session.credentials.identifier), "success-refresh-nonce")
                    return
                }
                if scenario < 4 {
                    UserAccountManager.shared.perform(NSSelectorFromString("resetAuthentication:"), with: session)
                } else {
                    _ = await UserAccountManager.shared.stopCurrentAuthentication()
                }
                let count = NativeLifecycleCapture.requests.count
                let http = try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: max(status, 200), httpVersion: "HTTP/1.1", headerFields: ["DPoP-Nonce": "late-refresh-nonce"]))
                let body = status == 200 ? "{\"access_token\":\"late-token\",\"token_type\":\"DPoP\",\"instance_url\":\"https://community.example.com\"}" : "{\"error\":\"use_dpop_nonce\"}"
                if status == 0 {
                    response(nil, nil, NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut))
                } else {
                    // Deliver off-main to cover an already queued real OAuth response.
                    let delivered = expectation(description: "Transport completion released off-main")
                    DispatchQueue.global().async {
                        response(Data(body.utf8), http, nil)
                        delivered.fulfill()
                    }
                    await fulfillment(of: [delivered], timeout: 5)
                }
                await fulfillment(of: [refreshCompleted], timeout: 5)
                XCTAssertEqual(NativeLifecycleCapture.requests.count, count, "Late real refresh must not retry transport")
                XCTAssertEqual(session.credentials.accessToken, "test-token", "Cancelled refresh must not update credentials")
                XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials), "Late real OAuth retry must not recreate reclaimed key")
                XCTAssertNil(DPoPNonceCache.shared.latest(forScope: session.credentials.identifier), "Late real OAuth response must not harvest nonce")
                } catch {
                    // Stop the owner before delivering cancellation, while both transport and
                    // completion observation are still installed. Reset alone does not finish
                    // the shared refresh entry; its held transport response must also be released.
                    _ = await UserAccountManager.shared.stopCurrentAuthentication()
                    if !didCompleteRefresh, let pendingResponse = NativeLifecycleCapture.responses.last {
                        pendingResponse(nil, nil, NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))
                        await fulfillment(of: [refreshCompleted], timeout: 5)
                    }
                    if error is SimulatedFixtureError {
                        XCTAssertTrue(didCompleteRefresh, "Throwing fixture cleanup must finish the shared real refresh before restoring hooks")
                        XCTAssertEqual(session.credentials.accessToken, "test-token")
                        XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials))
                        XCTAssertNil(DPoPNonceCache.shared.latest(forScope: session.credentials.identifier))
                        return
                    }
                    throw error
                }
            }
        }
    }

    @MainActor
    func test_givenHeldIdentityRefresh_whenNativeAuthenticationResets_thenStaleContinuationCannotRetry() async throws {
        // Cover both reset APIs, failure, an already-queued retry, coordinator reuse,
        // and the active (not cancelled) native refresh path.
        for scenario in 0...5 {
            try await withNativeSession { manager, session, identifier in
                let refreshClass: AnyClass = try XCTUnwrap(NSClassFromString("SFSDKTokenRefreshCoordinator"))
                let refresh = try XCTUnwrap(class_getInstanceMethod(refreshClass, NSSelectorFromString("refreshSessionForCredentials:completion:error:")))
                let captureRefresh = try XCTUnwrap(class_getInstanceMethod(NSObject.self, #selector(NSObject.nativeTestHoldIdentityRefresh(_:completion:error:))))
                let send = try XCTUnwrap(class_getInstanceMethod(Network.self, NSSelectorFromString("sendRequest:dataResponseBlock:")))
                let captureSend = try XCTUnwrap(class_getInstanceMethod(Network.self, #selector(Network.nativeTestSendIdentityRequest(_:dataResponseBlock:))))
                let held = expectation(description: "Identity 403 refresh continuation held")
                NativeIdentityRefreshCapture.onRefresh = { held.fulfill() }
                NativeIdentityRefreshCapture.requests = []
                method_exchangeImplementations(refresh, captureRefresh)
                method_exchangeImplementations(send, captureSend)
                defer {
                    session.identityCoordinator.cancelRetrieval()
                    method_exchangeImplementations(refresh, captureRefresh)
                    method_exchangeImplementations(send, captureSend)
                    NativeIdentityRefreshCapture.onRefresh = nil
                    NativeIdentityRefreshCapture.completion = nil
                    NativeIdentityRefreshCapture.failure = nil
                }
                ScriptedURLProtocol.installScripts([
                    .init(statusCode: 200, headers: nil, body: Data("{\"code\":\"test-code\",\"sfdc_community_url\":\"https://community.example.com/site\",\"sfdc_community_id\":\"community\"}".utf8)),
                    .init(statusCode: 200, headers: nil, body: Data("{\"access_token\":\"test-token\",\"refresh_token\":\"test-refresh\",\"token_type\":\"DPoP\",\"instance_url\":\"https://community.example.com\",\"id\":\"https://community.example.com/id/00D000000000001/005000000000001\"}".utf8))
                ], identifier: identifier)
                let result = await manager.login(username: "native-test@example.com", password: "Test-password1")
                XCTAssertEqual(result, .success)
                await fulfillment(of: [held], timeout: 5)
                let coordinator = try XCTUnwrap(session.identityCoordinator)
                let completion = try XCTUnwrap(NativeIdentityRefreshCapture.completion)
                let failure = try XCTUnwrap(NativeIdentityRefreshCapture.failure)
                let updated = try XCTUnwrap(OAuthCredentials(identifier: session.credentials.identifier, clientId: "native-dpop-test", encrypted: true))
                updated.accessToken = "refreshed-token"
                updated.identityUrl = session.credentials.identityUrl
                updated.tokenType = "DPoP"
                DPoPNonceCache.shared.setNonce("identity-nonce", htu: try XCTUnwrap(session.credentials.identityUrl), scope: session.credentials.identifier)
                if scenario == 5 {
                    completion(updated)
                    let drained = expectation(description: "Active refresh retry sent")
                    DispatchQueue.main.async { drained.fulfill() }
                    await fulfillment(of: [drained], timeout: 5)
                    XCTAssertEqual(NativeIdentityRefreshCapture.requests.count, 2)
                    XCTAssertTrue(coordinator.credentials === updated)
                    XCTAssertEqual(coordinator.value(forKey: "identityRefreshes") as? UInt, 1)
                    XCTAssertTrue(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials))
                    return
                }
                // Release success on main, then reset before the queued retry can run.
                if scenario == 3 { completion(updated) }
                if scenario == 0 {
                    _ = await UserAccountManager.shared.stopCurrentAuthentication()
                } else {
                    UserAccountManager.shared.perform(NSSelectorFromString("resetAuthentication:"), with: session)
                }
                XCTAssertFalse(coordinator.retrievingData)
                XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials))
                XCTAssertNil(DPoPNonceCache.shared.latest(forScope: session.credentials.identifier))
                let requestsBeforeRelease = NativeIdentityRefreshCapture.requests.count
                if scenario == 4 {
                    // A new active retrieval must not make the old generation current again.
                    coordinator.initiateIdentityDataRetrieval()
                }
                let credentialsBeforeRelease = coordinator.credentials
                let refreshesBeforeRelease = coordinator.value(forKey: "identityRefreshes") as? UInt
                let statusBeforeRelease = coordinator.value(forKey: "identityFinalStatus") as? String
                if scenario == 2 {
                    failure(NSError(domain: "NativeIdentityRefreshTest", code: 1))
                } else if scenario != 3 {
                    completion(updated)
                }
                // FIFO barriers drain the retry and its mocked response/delegate continuations.
                for _ in 0..<4 {
                    let drained = expectation(description: "Identity continuation queue drained")
                    DispatchQueue.main.async { drained.fulfill() }
                    await fulfillment(of: [drained], timeout: 5)
                }
                XCTAssertEqual(NativeIdentityRefreshCapture.requests.count, requestsBeforeRelease, "Cancelled identity refresh must not send a retry or restart")
                XCTAssertTrue(coordinator.credentials === credentialsBeforeRelease, "Stale refresh must not replace credentials")
                XCTAssertEqual(coordinator.value(forKey: "identityRefreshes") as? UInt, refreshesBeforeRelease)
                XCTAssertEqual(coordinator.value(forKey: "identityFinalStatus") as? String, statusBeforeRelease)
                if scenario == 4 {
                    coordinator.cancelRetrieval()
                    DPoPKeyStore.shared.delete(forCredentials: session.credentials)
                }
                XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials), "Cancelled retry must not recreate the deleted bound key")
                XCTAssertNil(DPoPNonceCache.shared.latest(forScope: session.credentials.identifier))
                XCTAssertTrue(UserAccountManager.shared.userAccounts()?.isEmpty ?? true)
                XCTAssertNil(UserAccountManager.shared.currentUserAccount)
            }
        }
    }

    @MainActor
    func test_givenSameClientAndCallback_whenLoginSiteDiffers_thenSessionIsNotReused() async throws {
        try await withNativeSession { _, session, identifier in
            let pair = try DPoPKeyStore.shared.keyPair(forCredentials: session.credentials)
            let originalThumbprint = try DPoPProofBuilder.jwkThumbprint(publicKey: pair.publicKey)
            DPoPNonceCache.shared.setNonce("original-site-nonce", htu: try XCTUnwrap(URL(string: "https://login.example.com/community")), scope: session.credentials.identifier)
            ScriptedURLProtocol.installScripts([.init(statusCode: 400, headers: nil, body: Data())], identifier: identifier)
            let manager = SalesforceManager.shared.useNativeLogin(withConsumerKey: "native-dpop-test", callbackUrl: "testapp://callback", communityUrl: "https://login.example.com/other-site", nativeLoginViewController: UIViewController(), scene: nil)
            _ = await manager.login(username: "native-test@example.com", password: "Test-password1")
            let request = try XCTUnwrap(ScriptedURLProtocol.capturedRequests(identifier: identifier).first)
            XCTAssertNotEqual(try self.proofThumbprint(request), originalThumbprint)
            XCTAssertTrue(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials))
            XCTAssertEqual(DPoPNonceCache.shared.latest(forScope: session.credentials.identifier), "original-site-nonce")
        }
    }

    @MainActor
    func test_givenEquivalentLoginSite_whenHostCaseAndTrailingSlashDiffer_thenSessionIsReused() async throws {
        try await withNativeSession { _, session, identifier in
            let pair = try DPoPKeyStore.shared.keyPair(forCredentials: session.credentials)
            let expected = try DPoPProofBuilder.jwkThumbprint(publicKey: pair.publicKey)
            ScriptedURLProtocol.installScripts([.init(statusCode: 400, headers: nil, body: Data())], identifier: identifier)
            let manager = SalesforceManager.shared.useNativeLogin(withConsumerKey: "native-dpop-test", callbackUrl: "testapp://callback", communityUrl: "https://LOGIN.example.com:443/community/", nativeLoginViewController: UIViewController(), scene: nil)
            _ = await manager.login(username: "native-test@example.com", password: "Test-password1")
            let request = try XCTUnwrap(ScriptedURLProtocol.capturedRequests(identifier: identifier).first)
            XCTAssertEqual(try self.proofThumbprint(request), expected)
        }
    }

    @MainActor
    func test_givenSameSessionOverlappingAttempts_whenOlderAuthorizationCompletes_thenOnlyLatestSendsToken() async throws {
        for enabled in [true, false] {
            try await withNativeSession(usesDPoP: enabled) { manager, _, identifier in
                let config = URLSessionConfiguration.ephemeral
                config.protocolClasses = [NativeOverlapURLProtocol.self]
                Network.setSessionConfiguration(config, identifier: identifier)
                let firstStarted = expectation(description: "First authorization held")
                NativeOverlapURLProtocol.reset { firstStarted.fulfill() }
                defer { NativeOverlapURLProtocol.reset {} }
                let first = Task { await manager.login(username: "native-test@example.com", password: "First-password1") }
                await fulfillment(of: [firstStarted], timeout: 5)
                let second = await manager.login(username: "native-test@example.com", password: "Second-password1")
                NativeOverlapURLProtocol.releaseFirst()
                let older = await first.value
                XCTAssertNotEqual(second, .success)
                XCTAssertNotEqual(older, .success)
                XCTAssertEqual(NativeOverlapURLProtocol.tokenRequests, 1)
            }
        }
    }

    @MainActor
    func test_givenReplacedAuthorization_whenResponseArrives_thenOnlyAbandonedStateIsCleaned() async throws {
        try await withNativeSession { manager, session, identifier in
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [NativeIntentURLProtocol.self]
            Network.setSessionConfiguration(config, identifier: identifier)
            NativeIntentURLProtocol.requests = []
            let replacement = SFSDKAuthSession(session.oauthRequest, credentials: nil)
            replacement.isAuthenticating = true
            replacement.oauthCoordinator.useNativeAuth = true
            _ = try DPoPKeyStore.shared.keyPair(forCredentials: replacement.credentials)
            DPoPNonceCache.shared.setNonce("replacement-nonce",
                                          htu: try XCTUnwrap(URL(string: "https://login.example.com/community/services/oauth2/authorize")),
                                          scope: replacement.credentials.identifier)
            NativeIntentURLProtocol.onAuthorize = {
                UserAccountManager.shared.authSessions[session.sceneId as NSString] = replacement
            }
            defer {
                NativeIntentURLProtocol.onAuthorize = nil
                DPoPKeyStore.shared.delete(forCredentials: replacement.credentials)
                DPoPNonceCache.shared.clear(forScope: replacement.credentials.identifier)
            }
            _ = await manager.login(username: "native-test@example.com", password: "Test-password1")
            XCTAssertEqual(NativeIntentURLProtocol.requests.count, 1)
            XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials))
            XCTAssertNil(DPoPNonceCache.shared.latest(forScope: session.credentials.identifier))
            XCTAssertTrue(DPoPKeyStore.shared.hasKeyPair(forCredentials: replacement.credentials))
            XCTAssertEqual(DPoPNonceCache.shared.latest(forScope: replacement.credentials.identifier), "replacement-nonce")
        }
    }

    @MainActor
    func test_givenPersistedAccountKey_whenAuthenticationStops_thenBoundStateIsPreserved() async throws {
        try await withNativeSession { _, session, _ in
            let account = UserAccount(credentials: session.credentials)
            try UserAccountManager.shared.upsert(account)
            _ = try DPoPKeyStore.shared.keyPair(forCredentials: session.credentials)
            DPoPNonceCache.shared.setNonce("account-nonce", htu: try XCTUnwrap(URL(string: "https://login.example.com")),
                                          scope: session.credentials.identifier)
            _ = await UserAccountManager.shared.stopCurrentAuthentication()
            XCTAssertTrue(DPoPKeyStore.shared.hasKeyPair(forCredentials: account.credentials))
            XCTAssertEqual(DPoPNonceCache.shared.latest(forScope: account.credentials.identifier), "account-nonce")
        }
    }

    @MainActor
    func test_givenOverlappingTokenResponses_whenLatestSucceeds_thenOlderCannotOverwriteOrDeleteBoundKey() async throws {
        for enabled in [true, false] {
            try await withNativeSession(usesDPoP: enabled) { manager, session, identifier in
                let original = try XCTUnwrap(class_getInstanceMethod(SFIdentityCoordinator.self, #selector(SFIdentityCoordinator.initiateIdentityDataRetrieval)))
                let replacement = try XCTUnwrap(class_getInstanceMethod(SFIdentityCoordinator.self, #selector(SFIdentityCoordinator.nativeTestIdentityRetrieval)))
                var identityRequests = 0
                NativeIdentityCapture.onRetrieve = { _ in identityRequests += 1 }
                method_exchangeImplementations(original, replacement)
                defer {
                    method_exchangeImplementations(original, replacement)
                    NativeIdentityCapture.onRetrieve = nil
                    NativeOverlapURLProtocol.reset {}
                }
                let config = URLSessionConfiguration.ephemeral
                config.protocolClasses = [NativeOverlapURLProtocol.self]
                Network.setSessionConfiguration(config, identifier: identifier)
                let firstStarted = expectation(description: "First token held")
                NativeOverlapURLProtocol.reset(holdToken: true, tokenSuccess: true) { firstStarted.fulfill() }
                let first = Task { await manager.login(username: "native-test@example.com", password: "First-password1") }
                await fulfillment(of: [firstStarted], timeout: 5)
                let winner = await manager.login(username: "native-test@example.com", password: "Second-password1")
                NativeOverlapURLProtocol.releaseFirst()
                let older = await first.value
                XCTAssertEqual(winner, .success)
                XCTAssertNotEqual(older, .success)
                XCTAssertEqual(identityRequests, 1)
                XCTAssertEqual(session.credentials.accessToken, "test-token")
                XCTAssertEqual(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials), enabled)
            }
        }
    }

    @MainActor
    func test_givenDebugFormWithoutAccount_whenCancelledBeforeTokenSuccess_thenNoAccountAndRetryWorks() async throws {
        for enabled in [true, false] {
            try await withNativeSession(usesDPoP: enabled) { manager, session, identifier in
                let original = try XCTUnwrap(class_getInstanceMethod(SFIdentityCoordinator.self, #selector(SFIdentityCoordinator.initiateIdentityDataRetrieval)))
                let replacement = try XCTUnwrap(class_getInstanceMethod(SFIdentityCoordinator.self, #selector(SFIdentityCoordinator.nativeTestIdentityRetrieval)))
                var identityRequests = 0
                NativeIdentityCapture.onRetrieve = { _ in identityRequests += 1 }
                method_exchangeImplementations(original, replacement)
                defer {
                    (manager as? NativeLoginManagerInternal)?.invalidateCurrentAttempt()
                    method_exchangeImplementations(original, replacement)
                    NativeIdentityCapture.onRetrieve = nil
                    NativeOverlapURLProtocol.reset {}
                }
                let config = URLSessionConfiguration.ephemeral
                config.protocolClasses = [NativeOverlapURLProtocol.self]
                Network.setSessionConfiguration(config, identifier: identifier)
                let tokenHeld = expectation(description: "Token response held")
                NativeOverlapURLProtocol.reset(holdToken: true, tokenSuccess: true) { tokenHeld.fulfill() }

                let model = DebugNativeLoginModel(manager: manager)
                model.username = "native-test@example.com"
                model.password = "First-password1"
                model.login()
                let attempt = model.currentLoginTask
                await fulfillment(of: [tokenHeld], timeout: 5)

                XCTAssertFalse(model.canDismiss, "No account to return to")
                model.cancel()
                NativeOverlapURLProtocol.releaseFirst()
                await attempt?.value

                XCTAssertEqual(model.state, .idle)
                XCTAssertEqual(identityRequests, 0, "A token released after Cancel must not start an account")
                XCTAssertNil(session.credentials.accessToken)
                XCTAssertNil(UserAccountManager.shared.currentUserAccount)

                // Retry starts a fresh attempt that completes normally.
                let retryStarted = expectation(description: "Retry authorize held")
                NativeOverlapURLProtocol.reset(tokenSuccess: true) { retryStarted.fulfill() }
                model.password = "Second-password1"
                model.login()
                let retry = model.currentLoginTask
                await fulfillment(of: [retryStarted], timeout: 5)
                NativeOverlapURLProtocol.releaseFirst()
                await retry?.value
                XCTAssertEqual(model.state, .success)
                XCTAssertEqual(identityRequests, 1)
            }
        }
    }

    @MainActor
    func test_givenNativeAttemptAndExistingAccount_whenNativeAttemptsCancelled_thenOnlyTheAttemptIsInvalidated() async throws {
        try await withNativeSession { manager, session, _ in
            let uam = UserAccountManager.shared
            uam.clearAllAccountState()
            defer { uam.clearAllAccountState() }
            let existing = try XCTUnwrap(OAuthCredentials(identifier: UUID().uuidString, clientId: "other-app", encrypted: true))
            existing.identityUrl = URL(string: "https://community.example.com/id/00D000000000001/005000000000009")
            let account = UserAccount(credentials: existing)
            try uam.upsert(account)
            _ = try DPoPKeyStore.shared.keyPair(forCredentials: existing)
            defer { DPoPKeyStore.shared.delete(forCredentials: existing) }
            let context = try XCTUnwrap(uam.perform(NSSelectorFromString("beginNativeAuthentication:"), with: [
                "clientId": "native-dpop-test", "redirectUri": "testapp://callback", "loginUrl": "https://login.example.com/community"
            ])?.takeUnretainedValue() as? NSDictionary)
            XCTAssertTrue((uam.perform(NSSelectorFromString("isCurrentNativeAuthentication:"), with: context)?.takeUnretainedValue() as? NSNumber)?.boolValue == true)

            (manager as? NativeLoginManagerInternal)?.invalidateCurrentAttempt()

            XCTAssertFalse((uam.perform(NSSelectorFromString("isCurrentNativeAuthentication:"), with: context)?.takeUnretainedValue() as? NSNumber)?.boolValue == true,
                           "A token response that arrives after cancellation is no longer the current attempt")
            XCTAssertFalse(session.isAuthenticating)
            XCTAssertNil(uam.authSessions[session.sceneId as NSString])
            XCTAssertEqual(uam.userAccounts()?.count, 1, "The existing account is untouched")
            XCTAssertTrue(DPoPKeyStore.shared.hasKeyPair(forCredentials: existing), "The existing account keeps its DPoP key")
        }
    }

    @MainActor
    func test_givenBrowserAndOtherNativeAttempts_whenFormAttemptCancelled_thenOnlyTheFormsAttemptIsInvalidated() async throws {
        try await withNativeSession { manager, session, _ in
            let uam = UserAccountManager.shared
            let browserRequest = SFSDKAuthRequest()
            browserRequest.oauthClientId = "browser-client"
            browserRequest.oauthCompletionUrl = "testapp://callback"
            browserRequest.loginHost = "login.salesforce.com"
            let browser = SFSDKAuthSession(browserRequest, credentials: nil)
            browser.isAuthenticating = true

            // Another, separately owned native attempt (different client, as another form or scene would have).
            let otherRequest = SFSDKAuthRequest()
            otherRequest.oauthClientId = "other-native-client"
            otherRequest.oauthCompletionUrl = "testapp://callback"
            otherRequest.loginHost = "https://other.example.com/community"
            let other = SFSDKAuthSession(otherRequest, credentials: nil)
            other.isAuthenticating = true
            other.oauthCoordinator.useNativeAuth = true
            uam.authSessions[browser.sceneId as NSString] = browser
            uam.authSessions[other.sceneId as NSString] = other
            _ = try DPoPKeyStore.shared.keyPair(forCredentials: other.credentials)
            defer {
                DPoPKeyStore.shared.delete(forCredentials: other.credentials)
                uam.authSessions.removeObject(browser.sceneId as NSString)
                uam.authSessions.removeObject(other.sceneId as NSString)
            }

            (manager as? NativeLoginManagerInternal)?.invalidateCurrentAttempt()

            XCTAssertFalse(session.isAuthenticating, "The form's own attempt is invalidated")
            XCTAssertNil(uam.authSessions[session.sceneId as NSString])
            XCTAssertTrue(browser.isAuthenticating)
            XCTAssertTrue(uam.authSessions[browser.sceneId as NSString] === browser)
            XCTAssertTrue(other.isAuthenticating, "Another native attempt is left alone")
            XCTAssertTrue(uam.authSessions[other.sceneId as NSString] === other)
            XCTAssertTrue(DPoPKeyStore.shared.hasKeyPair(forCredentials: other.credentials), "and keeps its DPoP key")
        }
    }

    @MainActor
    func test_givenUnscopedNativeSession_whenTokenCompletes_thenOwningCredentialsAreUpdated() async throws {
        try await withNativeSession { manager, session, identifier in
            let original = try XCTUnwrap(class_getInstanceMethod(SFIdentityCoordinator.self, #selector(SFIdentityCoordinator.initiateIdentityDataRetrieval)))
            let replacement = try XCTUnwrap(class_getInstanceMethod(SFIdentityCoordinator.self, #selector(SFIdentityCoordinator.nativeTestIdentityRetrieval)))
            let completed = expectation(description: "Identity retrieval starts on owning credentials")
            NativeIdentityCapture.onRetrieve = { coordinator in
                XCTAssertTrue(coordinator.credentials === session.credentials)
                XCTAssertEqual(coordinator.credentials?.accessToken, "test-token")
                XCTAssertEqual(coordinator.credentials?.tokenType, "DPoP")
                completed.fulfill()
            }
            method_exchangeImplementations(original, replacement)
            defer {
                method_exchangeImplementations(original, replacement)
                NativeIdentityCapture.onRetrieve = nil
            }
            ScriptedURLProtocol.installScripts([
                .init(statusCode: 200, headers: nil, body: Data("{\"code\":\"test-code\",\"sfdc_community_url\":\"https://community.example.com/site\",\"sfdc_community_id\":\"community\"}".utf8)),
                .init(statusCode: 200, headers: ["DPoP-Nonce": "bound-nonce"], body: Data("{\"access_token\":\"test-token\",\"refresh_token\":\"test-refresh\",\"token_type\":\"DPoP\",\"instance_url\":\"https://community.example.com\"}".utf8))
            ], identifier: identifier)
            let scope = session.credentials.identifier
            let result = await manager.login(username: "native-test@example.com", password: UUID().uuidString + "1a")
            XCTAssertEqual(result, .success)
            await fulfillment(of: [completed], timeout: 5)
            XCTAssertEqual(session.credentials.accessToken, "test-token")
            XCTAssertEqual(session.credentials.tokenType, "DPoP")
            XCTAssertEqual(session.credentials.identifier, scope)
            XCTAssertTrue(DPoPKeyStore.shared.hasKeyPair(forScope: scope))
            XCTAssertEqual(DPoPNonceCache.shared.latest(forScope: scope), "bound-nonce")
        }
    }

    @MainActor
    func test_givenInlineTokenParser_whenNativeLoginReturnsSuccess_thenOwningCredentialsArePopulatedBeforeIdentityFinishes() async throws {
        for enabled in [true, false] {
            try await withNativeSession(usesDPoP: enabled) { manager, session, identifier in
                let original = try XCTUnwrap(class_getInstanceMethod(SFIdentityCoordinator.self, #selector(SFIdentityCoordinator.initiateIdentityDataRetrieval)))
                let replacement = try XCTUnwrap(class_getInstanceMethod(SFIdentityCoordinator.self, #selector(SFIdentityCoordinator.nativeTestIdentityRetrieval)))
                var identity: SFIdentityCoordinator?
                NativeIdentityCapture.onRetrieve = { coordinator in
                    identity = coordinator
                    coordinator.setValue(true, forKey: "retrievingData")
                }
                method_exchangeImplementations(original, replacement)
                defer {
                    identity?.cancelRetrieval()
                    method_exchangeImplementations(original, replacement)
                    NativeIdentityCapture.onRetrieve = nil
                }
                let credentials = session.credentials
                let scope = credentials.identifier
                let accessToken = UUID().uuidString
                let refreshToken = UUID().uuidString
                let tokenType = enabled ? "DPoP" : "Bearer"
                let instanceURL = "https://community.example.com"
                let identityURL = "\(instanceURL)/id/00D000000000001/005000000000001"
                let tokenData = try JSONSerialization.data(withJSONObject: [
                    "access_token": accessToken, "refresh_token": refreshToken, "token_type": tokenType,
                    "instance_url": instanceURL, "id": identityURL
                ])
                ScriptedURLProtocol.installScripts([
                    .init(statusCode: 200, headers: nil, body: Data("{\"code\":\"test-code\",\"sfdc_community_url\":\"https://community.example.com/site\",\"sfdc_community_id\":\"community\"}".utf8)),
                    .init(statusCode: 200, headers: nil, body: tokenData)
                ], identifier: identifier)
                XCTAssertNil(credentials.accessToken)
                let result = await manager.login(username: "native-test@example.com", password: UUID().uuidString + "1a")
                XCTAssertEqual(result, .success)
                // No run-loop drain: success promises the real inline parser has already populated credentials.
                XCTAssertTrue(session.credentials === credentials)
                XCTAssertEqual(credentials.accessToken, accessToken)
                XCTAssertEqual(credentials.refreshToken, refreshToken)
                XCTAssertEqual(credentials.tokenType, tokenType)
                XCTAssertEqual(credentials.instanceUrl?.absoluteString, instanceURL)
                XCTAssertEqual(credentials.identityUrl?.absoluteString, identityURL)
                XCTAssertEqual(credentials.identifier, scope)
                let coordinator = try XCTUnwrap(identity)
                XCTAssertTrue(coordinator.credentials === credentials)
                XCTAssertTrue(coordinator.retrievingData, "Public success must not wait for identity completion")
                XCTAssertTrue(session.isAuthenticating)
                XCTAssertTrue(UserAccountManager.shared.userAccounts()?.isEmpty ?? true)
                XCTAssertNil(UserAccountManager.shared.currentUserAccount)
                XCTAssertEqual(ScriptedURLProtocol.capturedRequests(identifier: identifier).count, 2)
            }
        }
    }

    @MainActor
    private func withNativeSession(usesDPoP: Bool = true,
                                   execute: (NativeLoginManager, SFSDKAuthSession, String) async throws -> Void) async throws {
        let originalDPoP = SalesforceManager.shared.usesDPoP
        SalesforceManager.shared.usesDPoP = usesDPoP
        let identifier = NetworkEphemeralInstanceIdentifier
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ScriptedURLProtocol.self]
        Network.setSessionConfiguration(config, identifier: identifier)
        let manager = SalesforceManager.shared.useNativeLogin(withConsumerKey: "native-dpop-test", callbackUrl: "testapp://callback", communityUrl: "https://login.example.com/community", nativeLoginViewController: UIViewController(), scene: nil)
        let request = SFSDKAuthRequest()
        request.oauthClientId = "native-dpop-test"
        request.oauthCompletionUrl = "testapp://callback"
        request.loginHost = "https://login.example.com/community"
        let session = SFSDKAuthSession(request, credentials: nil)
        session.isAuthenticating = true
        session.oauthCoordinator.useNativeAuth = true
        UserAccountManager.shared.authSessions[session.sceneId as NSString] = session
        defer {
            session.identityCoordinator.cancelRetrieval()
            session.oauthCoordinator.stopAuthentication()
            SalesforceManager.shared.usesDPoP = originalDPoP
            Network.removeSharedInstance(forIdentifier: identifier)
            ScriptedURLProtocol.removeScripts(identifier: identifier)
            DPoPKeyStore.shared.delete(forCredentials: session.credentials)
            DPoPNonceCache.shared.clear(forScope: session.credentials.identifier)
            UserAccountManager.shared.authSessions.removeObject(session.sceneId as NSString)
        }
        try await execute(manager, session, identifier)
    }

    @MainActor
    func test_givenSameUserReauth_whenNativeReplacementPersists_thenOnlyUnreferencedPreviousDPoPStateIsReclaimed() async throws {
        for reference in 0...2 {
            try await withNativeSession { _, session, _ in
                let uam = UserAccountManager.shared
                uam.clearAllAccountState()
                let old = try XCTUnwrap(OAuthCredentials(identifier: UUID().uuidString, clientId: "native-dpop-test", encrypted: true))
                old.identityUrl = URL(string: "https://community.example.com/id/00D000000000001/005000000000001")
                old.tokenType = "DPoP"
                let account = UserAccount(credentials: old)
                account.idData = IdentityData(jsonDict: ["user_id": "005000000000001", "organization_id": "00D000000000001"])
                try uam.upsert(account)
                let other = try XCTUnwrap(OAuthCredentials(identifier: reference == 1 ? old.identifier : UUID().uuidString, clientId: "other-app", encrypted: true))
                other.identityUrl = URL(string: "https://community.example.com/id/00D000000000001/005000000000002")
                other.tokenType = "DPoP"
                let otherAccount = UserAccount(credentials: other)
                try uam.upsert(otherAccount)
                let retainedSession = SFSDKAuthSession(session.oauthRequest, credentials: reference == 2 ? old : nil)
                if reference == 2 { uam.authSessions["retained-reference" as NSString] = retainedSession }
                let url = try XCTUnwrap(URL(string: "https://community.example.com"))
                let oldThumbprint = try DPoPProofBuilder.jwkThumbprint(publicKey: DPoPKeyStore.shared.keyPair(forCredentials: old).publicKey)
                let otherThumbprint = try DPoPProofBuilder.jwkThumbprint(publicKey: DPoPKeyStore.shared.keyPair(forCredentials: other).publicKey)
                DPoPNonceCache.shared.setNonce("previous-nonce", htu: url, scope: old.identifier)
                if reference != 1 { DPoPNonceCache.shared.setNonce("other-nonce", htu: url, scope: other.identifier) }
                session.nativeLogin = true
                session.oauthCoordinator.updateCredentials([
                    "access_token": "replacement-token", "token_type": "DPoP", "instance_url": url.absoluteString,
                    "id": try XCTUnwrap(old.identityUrl).absoluteString
                ])
                let new = session.credentials
                let newThumbprint = try DPoPProofBuilder.jwkThumbprint(publicKey: DPoPKeyStore.shared.keyPair(forCredentials: new).publicKey)
                DPoPNonceCache.shared.setNonce("replacement-nonce", htu: url, scope: new.identifier)
                defer {
                    uam.authSessions.removeObject("retained-reference" as NSString)
                    for persistedAccount in uam.userAccounts() ?? [] {
                        try? uam.delete(persistedAccount)
                    }
                    for credentials in [old, other, new] {
                        DPoPKeyStore.shared.delete(forCredentials: credentials)
                        DPoPNonceCache.shared.clear(forScope: credentials.identifier)
                    }
                    uam.clearAllAccountState()
                }
                let identity = SFIdentityCoordinator(credentials: new)
                identity.authSession = session
                identity.idData = account.idData
                session.identityCoordinator = identity
                let completed = expectation(description: "Native replacement persisted")
                session.authSuccessCallback = { _, _ in completed.fulfill() }
                uam.perform(NSSelectorFromString("finalizeAuthCompletion:"), with: session)
                await fulfillment(of: [completed], timeout: 5)
                let persisted = try XCTUnwrap(uam.userAccounts()?.first { $0.credentials.userId == old.userId })
                XCTAssertEqual(persisted.credentials.identifier, new.identifier)
                XCTAssertEqual(persisted.credentials.accessToken, "replacement-token")
                XCTAssertEqual(DPoPKeyStore.shared.hasKeyPair(forCredentials: old), reference != 0,
                               "Only an unreferenced previous native key may be reclaimed")
                XCTAssertEqual(DPoPNonceCache.shared.latest(forScope: old.identifier), reference == 0 ? nil : "previous-nonce")
                if reference != 0 {
                    XCTAssertEqual(try DPoPProofBuilder.jwkThumbprint(publicKey: DPoPKeyStore.shared.keyPair(forCredentials: old).publicKey), oldThumbprint)
                }
                XCTAssertEqual(try DPoPProofBuilder.jwkThumbprint(publicKey: DPoPKeyStore.shared.keyPair(forCredentials: new).publicKey), newThumbprint)
                XCTAssertEqual(DPoPNonceCache.shared.latest(forScope: new.identifier), "replacement-nonce")
                XCTAssertEqual(try DPoPProofBuilder.jwkThumbprint(publicKey: DPoPKeyStore.shared.keyPair(forCredentials: other).publicKey), otherThumbprint)
                XCTAssertEqual(DPoPNonceCache.shared.latest(forScope: other.identifier), reference == 1 ? "previous-nonce" : "other-nonce")
            }
        }
    }

    @MainActor
    func test_givenQueuedNativePreflightFailure_whenAttemptStartsOrSessionIsReplaced_thenFailureCannotInvalidateSuccessor() async throws {
        for replaced in [false, true] {
            try await withNativeSession { _, session, _ in
                let uam = UserAccountManager.shared
                session.oauthCoordinator.delegate = uam
                var failures = 0
                session.authFailureCallback = { _, _ in failures += 1 }
                let error = NSError(domain: "NativePreflightTest", code: 1)
                session.oauthCoordinator.perform(NSSelectorFromString("notifyDelegateOfFailure:authInfo:"), with: error, with: session.oauthCoordinator.authInfo)
                let successor: SFSDKAuthSession
                if replaced {
                    successor = SFSDKAuthSession(session.oauthRequest, credentials: nil)
                    successor.oauthCoordinator.useNativeAuth = true
                    successor.isAuthenticating = true
                    uam.authSessions.removeObject(session.sceneId as NSString)
                    uam.authSessions[successor.sceneId as NSString] = successor
                } else { successor = session }
                let context = try XCTUnwrap(uam.perform(NSSelectorFromString("beginNativeAuthentication:"), with: [
                    "clientId": "native-dpop-test", "redirectUri": "testapp://callback", "loginUrl": "https://login.example.com/community"
                ])?.takeUnretainedValue() as? NSDictionary)
                _ = try DPoPKeyStore.shared.keyPair(forCredentials: successor.credentials)
                DPoPNonceCache.shared.setNonce("successor-nonce", htu: try XCTUnwrap(URL(string: "https://login.example.com")), scope: successor.credentials.identifier)
                defer {
                    DPoPKeyStore.shared.delete(forCredentials: successor.credentials)
                    DPoPNonceCache.shared.clear(forScope: successor.credentials.identifier)
                    uam.authSessions.removeObject(successor.sceneId as NSString)
                }
                let drained = expectation(description: "Queued preflight callback drained")
                DispatchQueue.main.async { drained.fulfill() }
                await fulfillment(of: [drained], timeout: 5)
                XCTAssertEqual(failures, 0, "Obsolete preflight failure must not notify application callbacks")
                XCTAssertNil(session.authError)
                XCTAssertTrue((uam.perform(NSSelectorFromString("isCurrentNativeAuthentication:"), with: context)?.takeUnretainedValue() as? NSNumber)?.boolValue == true)
                XCTAssertTrue(DPoPKeyStore.shared.hasKeyPair(forCredentials: successor.credentials))
                XCTAssertEqual(DPoPNonceCache.shared.latest(forScope: successor.credentials.identifier), "successor-nonce")
            }
        }
    }

    private enum HeldNativeStage: String, CaseIterable {
        case authorize, token, identity
    }

    private enum FallbackTerminal: String, CaseIterable {
        case cancelled, failed, succeeded
    }

    private enum StaleResponseRelease: String, CaseIterable {
        case beforeFreshCompletion, afterFreshCompletion
    }

    private var fallbackScenarioLabel: String?

    override func record(_ issue: XCTIssue) {
        guard let label = fallbackScenarioLabel else {
            super.record(issue)
            return
        }
        super.record(XCTIssue(type: issue.type,
                             compactDescription: "\(label): \(issue.compactDescription)",
                             detailedDescription: issue.detailedDescription,
                             sourceCodeContext: issue.sourceCodeContext,
                             associatedError: issue.associatedError,
                             attachments: issue.attachments))
    }

    @MainActor
    func test_givenHeldNativeResponses_whenIndependentFallbackTerminates_thenFreshNativeAccountSurvivesStaleCallbacks() async throws {
        for stage in HeldNativeStage.allCases {
            for terminal in FallbackTerminal.allCases {
                for release in StaleResponseRelease.allCases {
                    let label = "stage=\(stage.rawValue), terminal=\(terminal.rawValue), release=\(release.rawValue)"
                    fallbackScenarioLabel = label
                    defer { fallbackScenarioLabel = nil }
                    do {
                        try await assertIndependentFallback(stage: stage, terminal: terminal, release: release)
                    } catch {
                        XCTFail("\(label): \(error)")
                    }
                }
            }
        }
    }

    @MainActor
    private func assertIndependentFallback(stage: HeldNativeStage, terminal: FallbackTerminal,
                                           release: StaleResponseRelease) async throws {
                    try await withNativeSession { manager, originalSession, _ in
                        let uam = UserAccountManager.shared
                        originalSession.oauthRequest.useDPoP = true
                        let send = try XCTUnwrap(class_getInstanceMethod(RestClient.self, NSSelectorFromString("send:failureBlock:successBlock:")))
                        let holdSend = try XCTUnwrap(class_getInstanceMethod(RestClient.self, #selector(RestClient.nativeTestHoldFallbackRequest(_:failureBlock:successBlock:))))
                        let authenticate = try XCTUnwrap(class_getInstanceMethod(SFOAuthCoordinator.self, NSSelectorFromString("authenticateWithCredentials:")))
                        let holdBrowser = try XCTUnwrap(class_getInstanceMethod(SFOAuthCoordinator.self, #selector(SFOAuthCoordinator.nativeTestHoldFallbackAuthentication(_:))))
                        let network = try XCTUnwrap(class_getInstanceMethod(Network.self, NSSelectorFromString("sendRequest:dataResponseBlock:")))
                        let holdNetwork = try XCTUnwrap(class_getInstanceMethod(Network.self, #selector(Network.nativeTestHoldLifecycleRequest(_:dataResponseBlock:))))
                        let originalFallback = uam.shouldFallbackToWebAuthentication
                        NativeFallbackCapture.requests = []
                        NativeFallbackCapture.responses = []
                        NativeLifecycleCapture.holdIdentity = true
                        NativeLifecycleCapture.requests = []
                        NativeLifecycleCapture.responses = []
                        method_exchangeImplementations(send, holdSend)
                        method_exchangeImplementations(authenticate, holdBrowser)
                        method_exchangeImplementations(network, holdNetwork)
                        var nativeTasks: [Task<NativeLoginResult, Never>] = []
                        func finishHeldWork() async {
                            NativeFallbackCapture.onRequest = nil
                            NativeFallbackCapture.onAuthenticate = nil
                            NativeLifecycleCapture.onIdentity = nil
                            _ = await uam.stopCurrentAuthentication()
                            // Dropping these closures leaks RestClient.send's checked continuation.
                            // Deliver cancellation while the fixture hooks and session state still exist.
                            NativeFallbackCapture.responses.forEach { $0(Data(), "") }
                            NativeLifecycleCapture.responses.forEach {
                                $0(nil, nil, NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))
                            }
                            for task in nativeTasks { _ = await task.value }
                        }
                        defer {
                            method_exchangeImplementations(send, holdSend)
                            method_exchangeImplementations(authenticate, holdBrowser)
                            method_exchangeImplementations(network, holdNetwork)
                            NativeFallbackCapture.onRequest = nil
                            NativeFallbackCapture.onAuthenticate = nil
                            NativeFallbackCapture.responses = []
                            NativeLifecycleCapture.onIdentity = nil
                            NativeLifecycleCapture.holdIdentity = false
                            NativeLifecycleCapture.responses = []
                            uam.shouldFallbackToWebAuthentication = originalFallback
                            for case let session as SFSDKAuthSession in uam.authSessions.allValues {
                                DPoPKeyStore.shared.delete(forCredentials: session.credentials)
                                DPoPNonceCache.shared.clear(forScope: session.credentials.identifier)
                            }
                            for account in uam.userAccounts() ?? [] {
                                DPoPKeyStore.shared.delete(forCredentials: account.credentials)
                                DPoPNonceCache.shared.clear(forScope: account.credentials.identifier)
                                try? uam.delete(account)
                            }
                            uam.clearAllAccountState()
                        }

                        do {
                        let other = createUser()
                        other.credentials.tokenType = "DPoP"
                        let otherScope = other.credentials.identifier
                        let otherPair = try DPoPKeyStore.shared.keyPair(forCredentials: other.credentials)
                        let otherThumbprint = try DPoPProofBuilder.jwkThumbprint(publicKey: otherPair.publicKey)
                        let nonceURL = try XCTUnwrap(URL(string: "https://community.example.com/services/oauth2/token"))
                        DPoPNonceCache.shared.setNonce("other-nonce", htu: nonceURL, scope: otherScope)
                        let authorizeBody = Data("{\"code\":\"test-code\",\"sfdc_community_url\":\"https://community.example.com/site\",\"sfdc_community_id\":\"community\"}".utf8)
                        let tokenBody = Data("{\"access_token\":\"fresh-token\",\"refresh_token\":\"fresh-refresh\",\"token_type\":\"DPoP\",\"instance_url\":\"https://community.example.com\",\"id\":\"https://community.example.com/id/00D000000000001/005000000000001\"}".utf8)
                        let identityBody = Data("{\"user_id\":\"005000000000001\",\"organization_id\":\"00D000000000001\",\"username\":\"native-test@example.com\"}".utf8)
                        let heldAuthorize = expectation(description: "Original native authorize held")
                        NativeFallbackCapture.onRequest = { heldAuthorize.fulfill() }
                        let oldTask = Task { await manager.login(username: "native-test@example.com", password: "Test-password1") }
                        nativeTasks.append(oldTask)
                        await fulfillment(of: [heldAuthorize], timeout: 5)
                        NativeFallbackCapture.onRequest = nil
                        let originalAuthorize = try XCTUnwrap(NativeFallbackCapture.requests.first)
                        let originalThumbprint = try self.proofThumbprint(originalAuthorize)
                         if stage != .authorize {
                            let heldToken = expectation(description: "Original native token held")
                            NativeFallbackCapture.onRequest = { heldToken.fulfill() }
                            try XCTUnwrap(NativeFallbackCapture.responses.first)(authorizeBody, "old-authorize-nonce")
                            await fulfillment(of: [heldToken], timeout: 5)
                            NativeFallbackCapture.onRequest = nil
                        }
                         if stage == .identity {
                            let heldIdentity = expectation(description: "Original native identity held")
                            NativeLifecycleCapture.onIdentity = { heldIdentity.fulfill() }
                            try XCTUnwrap(NativeFallbackCapture.responses.last)(tokenBody, "old-token-nonce")
                            let oldResult = await oldTask.value
                            XCTAssertEqual(oldResult, .success)
                            await fulfillment(of: [heldIdentity], timeout: 5)
                            NativeLifecycleCapture.onIdentity = nil
                        }
                        let oldScope = originalSession.credentials.identifier
                        DPoPNonceCache.shared.setNonce("old-native-nonce", htu: nonceURL, scope: oldScope)
                         let oldResponse = stage == .identity ? nil : NativeFallbackCapture.responses.last
                         let oldIdentityResponse = stage == .identity ? NativeLifecycleCapture.responses.last : nil
                        let oldIdentity: SFIdentityCoordinator? = originalSession.identityCoordinator

                        // Only the browser's UI/network start is held; fallback/reset/request routing is production code.
                        SalesforceManager.shared.usesDPoP = false
                        let browserStarted = expectation(description: "Independent browser fallback routed")
                        var browser: SFSDKAuthSession?
                        NativeFallbackCapture.onAuthenticate = { coordinator in
                            browser = coordinator.authSession
                            browserStarted.fulfill()
                        }
                        manager.fallbackToWebAuthentication()
                        await fulfillment(of: [browserStarted], timeout: 5)
                        NativeFallbackCapture.onAuthenticate = nil
                        let browserSession = try XCTUnwrap(browser)
                        XCTAssertFalse(browserSession.oauthCoordinator.useNativeAuth)
                        XCTAssertNil(browserSession.oauthRequest.useDPoP, "Fallback must not hand Native's captured flag to the existing browser flow")
                        XCTAssertNil(browserSession.oauthCoordinator.dpopOverride)
                        XCTAssertNotEqual(browserSession.credentials.identifier, oldScope)
                        XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forCredentials: browserSession.credentials))
                        XCTAssertNil(DPoPNonceCache.shared.latest(forScope: browserSession.credentials.identifier))
                        XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forScope: oldScope))
                        XCTAssertNil(DPoPNonceCache.shared.latest(forScope: oldScope))
                        XCTAssertTrue(uam.shouldFallbackToWebAuthentication)
                        SalesforceManager.shared.usesDPoP = true
                         switch terminal {
                         case .cancelled:
                            let returnedToNative = expectation(description: "Fallback terminal route returned")
                            NativeFallbackCapture.onAuthenticate = { coordinator in
                                XCTAssertTrue(coordinator.useNativeAuth)
                                returnedToNative.fulfill()
                            }
                            uam.oauthCoordinatorDidCancelBrowserAuthentication(browserSession.oauthCoordinator)
                            await fulfillment(of: [returnedToNative], timeout: 5)
                         case .failed:
                            browserSession.notifiesDelegatesOfFailure = false
                            uam.perform(NSSelectorFromString("handleFailure:session:"), with: NSError(domain: "NativeFallbackTest", code: 1), with: browserSession)
                         case .succeeded:
                            browserSession.oauthCoordinator.updateCredentials([
                                "access_token": "browser-token", "token_type": "Bearer",
                                "instance_url": "https://community.example.com",
                                "id": "https://community.example.com/id/00D000000000001/005000000000002"
                            ])
                            let browserIdentity = SFIdentityCoordinator(credentials: browserSession.credentials)
                            browserIdentity.authSession = browserSession
                            browserIdentity.idData = IdentityData(jsonDict: [
                                "user_id": "005000000000002", "organization_id": "00D000000000001",
                                "username": "browser-test@example.com"
                            ])
                            browserSession.identityCoordinator = browserIdentity
                            let browserCompleted = expectation(description: "Browser account finalized through existing completion")
                            let completion = browserSession.authSuccessCallback
                            browserSession.authSuccessCallback = { info, account in
                                completion?(info, account)
                                browserCompleted.fulfill()
                            }
                            uam.perform(NSSelectorFromString("identityCoordinatorRetrievedData:"), with: browserIdentity)
                            await fulfillment(of: [browserCompleted], timeout: 5)
                            XCTAssertEqual(uam.currentUserAccount?.credentials.accessToken, "browser-token")
                            XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forCredentials: browserSession.credentials))
                        }
                        NativeFallbackCapture.onAuthenticate = nil
                        XCTAssertFalse(uam.shouldFallbackToWebAuthentication)

                        let freshManager = SalesforceManager.shared.useNativeLogin(
                            withConsumerKey: "native-dpop-test", callbackUrl: "testapp://callback",
                            communityUrl: "https://login.example.com/community", nativeLoginViewController: UIViewController(),
                            scene: browserSession.oauthRequest.scene)
                        let freshAuthorizeHeld = expectation(description: "Fresh native authorize held")
                        NativeFallbackCapture.onRequest = { freshAuthorizeHeld.fulfill() }
                        let freshTask = Task { await freshManager.login(username: "native-test@example.com", password: "Fresh-password1") }
                        nativeTasks.append(freshTask)
                        await fulfillment(of: [freshAuthorizeHeld], timeout: 5)
                        NativeFallbackCapture.onRequest = nil
                        let freshAuthorize = try XCTUnwrap(NativeFallbackCapture.requests.last)
                        let freshResponse = try XCTUnwrap(NativeFallbackCapture.responses.last)
                        let freshSession = try XCTUnwrap(uam.authSessions.allValues.compactMap { $0 as? SFSDKAuthSession }.first { $0.oauthCoordinator.useNativeAuth })
                        let freshScope = freshSession.credentials.identifier
                        let freshThumbprint = try self.proofThumbprint(freshAuthorize)
                        XCTAssertNotEqual(freshScope, oldScope)
                        XCTAssertNotEqual(freshScope, browserSession.credentials.identifier)
                        XCTAssertNotEqual(freshThumbprint, originalThumbprint)
                        XCTAssertEqual(try self.formBody(freshAuthorize)["dpop_jkt"], freshThumbprint)
                        XCTAssertNil(try self.proofPart(freshAuthorize, index: 1)["nonce"])

                        func releaseOld() async throws {
                            let count = NativeFallbackCapture.requests.count
                             oldResponse?(stage == .authorize ? authorizeBody : tokenBody, "late-native-nonce")
                            if let oldIdentityResponse {
                                let url = try XCTUnwrap(oldIdentity?.credentials?.identityUrl)
                                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["DPoP-Nonce": "late-identity-nonce"]))
                                oldIdentityResponse(identityBody, response, nil)
                                uam.perform(NSSelectorFromString("identityCoordinatorRetrievedData:"), with: oldIdentity)
                            } else {
                                let oldResult = await oldTask.value
                                XCTAssertNotEqual(oldResult, .success)
                            }
                            uam.perform(NSSelectorFromString("resetAuthentication:"), with: originalSession)
                            // Native task completion above is the authorize/token boundary;
                            // identity processing and reset are synchronous on main here.
                            XCTAssertEqual(NativeFallbackCapture.requests.count, count)
                            XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forScope: oldScope))
                            XCTAssertNil(DPoPNonceCache.shared.latest(forScope: oldScope))
                            XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forCredentials: browserSession.credentials))
                            XCTAssertNil(DPoPNonceCache.shared.latest(forScope: browserSession.credentials.identifier))
                            XCTAssertTrue(DPoPKeyStore.shared.hasKeyPair(forScope: freshScope))
                            XCTAssertEqual(try DPoPProofBuilder.jwkThumbprint(publicKey: DPoPKeyStore.shared.keyPair(forScope: freshScope).publicKey), freshThumbprint)
                            XCTAssertEqual(try DPoPProofBuilder.jwkThumbprint(publicKey: DPoPKeyStore.shared.keyPair(forScope: otherScope).publicKey), otherThumbprint)
                            XCTAssertEqual(DPoPNonceCache.shared.latest(forScope: otherScope), "other-nonce")
                        }
                         if release == .beforeFreshCompletion {
                            try await releaseOld()
                            XCTAssertTrue(uam.authSessions[freshSession.sceneId as NSString] === freshSession)
                            XCTAssertNil(freshSession.credentials.accessToken)
                            XCTAssertNil(DPoPNonceCache.shared.latest(forScope: freshScope))
                        }
                        let freshTokenHeld = expectation(description: "Fresh token held")
                        NativeFallbackCapture.onRequest = { freshTokenHeld.fulfill() }
                        freshResponse(authorizeBody, "fresh-authorize-nonce")
                        await fulfillment(of: [freshTokenHeld], timeout: 5)
                        NativeFallbackCapture.onRequest = nil
                        let freshToken = try XCTUnwrap(NativeFallbackCapture.requests.last)
                        XCTAssertEqual(try self.proofThumbprint(freshToken), freshThumbprint)
                        XCTAssertEqual(try self.proofPart(freshToken, index: 1)["nonce"] as? String, "fresh-authorize-nonce")
                        XCTAssertNotEqual(try self.proofPart(freshToken, index: 1)["jti"] as? String, try self.proofPart(freshAuthorize, index: 1)["jti"] as? String)
                        let freshIdentityHeld = expectation(description: "Fresh identity held")
                        NativeLifecycleCapture.onIdentity = { freshIdentityHeld.fulfill() }
                        try XCTUnwrap(NativeFallbackCapture.responses.last)(tokenBody, "fresh-token-nonce")
                        let freshResult = await freshTask.value
                        XCTAssertEqual(freshResult, .success)
                        await fulfillment(of: [freshIdentityHeld], timeout: 5)
                        NativeLifecycleCapture.onIdentity = nil
                        let identityRequest = try XCTUnwrap(NativeLifecycleCapture.requests.last)
                        XCTAssertEqual(try self.proofThumbprint(identityRequest), freshThumbprint)
                        XCTAssertEqual(identityRequest.value(forHTTPHeaderField: "Authorization"), "DPoP fresh-token")
                        let accountCompleted = expectation(description: "Fresh account persisted")
                        freshSession.authSuccessCallback = { _, _ in accountCompleted.fulfill() }
                        let identityHTTP = try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(identityRequest.url), statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil))
                        try XCTUnwrap(NativeLifecycleCapture.responses.last)(identityBody, identityHTTP, nil)
                        await fulfillment(of: [accountCompleted], timeout: 5)
                        let freshAccount = try XCTUnwrap(uam.currentUserAccount)
                        XCTAssertEqual(freshAccount.credentials.identifier, freshScope)
                        XCTAssertEqual(freshAccount.credentials.accessToken, "fresh-token")
                        XCTAssertEqual(freshAccount.credentials.tokenType, "DPoP")
                         if release == .afterFreshCompletion { try await releaseOld() }
                        XCTAssertTrue(uam.currentUserAccount === freshAccount)
                        XCTAssertEqual(freshAccount.credentials.accessToken, "fresh-token")
                        XCTAssertEqual(freshAccount.credentials.tokenType, "DPoP")
                         XCTAssertEqual(uam.userAccounts()?.count, terminal == .succeeded ? 3 : 2)
                        XCTAssertEqual(DPoPNonceCache.shared.latest(forScope: freshScope), "fresh-token-nonce")
                        XCTAssertTrue(DPoPKeyStore.shared.hasKeyPair(forScope: freshScope))
                        DPoPKeyStore.shared.delete(forScope: freshScope)
                        DPoPNonceCache.shared.clear(forScope: freshScope)
                        DPoPKeyStore.shared.delete(forScope: otherScope)
                          DPoPNonceCache.shared.clear(forScope: otherScope)
                        } catch {
                            await finishHeldWork()
                            throw error
                        }
                        await finishHeldWork()
                     }
    }

    @MainActor
    func test_givenCapturedDPoPIntent_whenFlagChangesDuringAuthorize_thenTokenKeepsOriginalIntent() async throws {
        for enabled in [true, false] {
            try await withNativeSession(usesDPoP: enabled) { manager, _, identifier in
                let config = URLSessionConfiguration.ephemeral
                config.protocolClasses = [NativeIntentURLProtocol.self]
                Network.setSessionConfiguration(config, identifier: identifier)
                NativeIntentURLProtocol.requests = []
                NativeIntentURLProtocol.onAuthorize = { SalesforceManager.shared.usesDPoP = !enabled }
                defer { NativeIntentURLProtocol.onAuthorize = nil }
                let result = await manager.login(username: "native-test@example.com", password: UUID().uuidString + "1a")
                XCTAssertEqual(result, .unknownError)
                let requests = NativeIntentURLProtocol.requests
                XCTAssertEqual(requests.count, 2)
                for request in requests {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "DPoP") != nil, enabled)
                }
            }
        }
    }

    @MainActor
    func test_givenReplacedNativeSession_whenLateCompletionArrives_thenNeitherSessionIsUpdated() async throws {
        try await withNativeSession { _, session, _ in
            let replacement = SFSDKAuthSession(session.oauthRequest, credentials: nil)
            replacement.isAuthenticating = true
            UserAccountManager.shared.authSessions[session.sceneId as NSString] = replacement
            UserAccountManager.shared.createNativeUserAccount(Data("{\"access_token\":\"late-token\",\"token_type\":\"DPoP\"}".utf8), authSession: session)
            XCTAssertNil(session.credentials.accessToken)
            XCTAssertNil(replacement.credentials.accessToken)
        }
    }

    @MainActor
    func test_givenTerminalNonceResponses_whenNativeAuthorizationRuns_thenRetriesAtMostOnce() async throws {
        for tokenEndpoint in [false, true] {
            for statusCode in [400, 401] {
                for scenario in 0...2 {
                    try await withNativeSession { manager, _, identifier in
                        let headers = scenario == 0 ? nil : ["DPoP-Nonce": "challenge-nonce"]
                        let body = Data((scenario == 1 ? "{\"error\":\"invalid_grant\"}" : "{\"error\":\"use_dpop_nonce\"}").utf8)
                        var scripts = [ScriptedURLProtocol.ScriptedResponse]()
                        if tokenEndpoint {
                            scripts.append(.init(statusCode: 200, headers: nil, body: Data("{\"code\":\"test-code\",\"sfdc_community_url\":\"https://community.example.com/site\",\"sfdc_community_id\":\"community\"}".utf8)))
                        }
                        scripts.append(contentsOf: [
                            .init(statusCode: statusCode, headers: headers, body: body),
                            .init(statusCode: statusCode, headers: headers, body: body)
                        ])
                        ScriptedURLProtocol.installScripts(scripts, identifier: identifier)
                        let result = await manager.login(username: "native-test@example.com", password: UUID().uuidString + "1a")
                        XCTAssertEqual(result, tokenEndpoint ? .unknownError : .invalidCredentials)
                        XCTAssertEqual(ScriptedURLProtocol.requestCount(identifier: identifier),
                                       (tokenEndpoint ? 1 : 0) + (scenario == 2 ? 2 : 1))
                    }
                }
            }
        }
    }

    @MainActor
    func test_givenNoNativeSession_whenDPoPLoginStarts_thenInternalSessionOwnsProof() async throws {
        let originalDPoP = SalesforceManager.shared.usesDPoP
        SalesforceManager.shared.usesDPoP = true
        let identifier = NetworkEphemeralInstanceIdentifier
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ScriptedURLProtocol.self]
        Network.setSessionConfiguration(config, identifier: identifier)
        ScriptedURLProtocol.installScripts([.init(statusCode: 400, headers: nil, body: Data())], identifier: identifier)
        defer {
            SalesforceManager.shared.usesDPoP = originalDPoP
            Network.removeSharedInstance(forIdentifier: identifier)
            ScriptedURLProtocol.removeScripts(identifier: identifier)
            for case let session as SFSDKAuthSession in UserAccountManager.shared.authSessions.allValues {
                DPoPKeyStore.shared.delete(forCredentials: session.credentials)
                DPoPNonceCache.shared.clear(forScope: session.credentials.identifier)
            }
        }
        let manager = SalesforceManager.shared.useNativeLogin(withConsumerKey: "native-fallback-test", callbackUrl: "testapp://callback", communityUrl: "https://login.example.com/community", nativeLoginViewController: UIViewController(), scene: nil)
        let result = await manager.login(username: "native-test@example.com", password: UUID().uuidString + "1a")
        XCTAssertEqual(result, .invalidCredentials)
        let request = try XCTUnwrap(ScriptedURLProtocol.capturedRequests(identifier: identifier).first)
        XCTAssertNotNil(request.value(forHTTPHeaderField: "DPoP"))
        let sessions = UserAccountManager.shared.authSessions.allValues.compactMap { $0 as? SFSDKAuthSession }
        let session = try XCTUnwrap(sessions.first { $0.credentials.clientId == "native-fallback-test" })
        XCTAssertFalse(session.credentials.identifier.isEmpty)
        XCTAssertFalse(DPoPKeyStore.shared.hasKeyPair(forCredentials: session.credentials))
    }

    func testUsernameValidationInSubmitOtpRequest() async {
        var result = await nativeLoginManager.submitOtpRequest(
            username: "",
            reCaptchaToken: "",
            otpVerificationMethod: .sms)
        XCTAssertEqual(
            .invalidUsername,
            result.nativeLoginResult,
            "Should not allow empty username.")
        result = await nativeLoginManager.submitOtpRequest(
            username: "test@c",
            reCaptchaToken: "",
            otpVerificationMethod: .sms)
        XCTAssertEqual(
            NativeLoginResult.invalidUsername,
            result.nativeLoginResult,
            "Should not allow invalid username.")
        
        // success
        result = await nativeLoginManager.submitOtpRequest(
            username: "test@c.co   ",
            reCaptchaToken: "",
            otpVerificationMethod: .sms)
        XCTAssertEqual(
            NativeLoginResult.unknownError,
            result.nativeLoginResult,
            "Should allow username.")
    }
    
    func testPasswordValidation() async {
        var result = await nativeLoginManager.login(username: "bpage@salesforce.com", password: "")
        XCTAssertEqual(.invalidPassword, result, "Should not allow invalid password.")
        result = await nativeLoginManager.login(username: "bpage@salesforce.com", password: "test123")
        XCTAssertEqual(.invalidPassword, result, "Should not allow password shorter than 8 chars.")
        result = await nativeLoginManager.login(username: "bpage@salesforce.com", password: "123456789")
        XCTAssertEqual(.invalidPassword, result, "Should not allow password without any letter chars.")
        result = await nativeLoginManager.login(username: "bpage@salesforce.com", password: "abcdefghi")
        XCTAssertEqual(.invalidPassword, result, "Should not allow password without any numbers.")
        
        // success
        result = await nativeLoginManager.login(username: "bpage@salesforce.com", password: "mypass12")
        XCTAssertEqual(.invalidCredentials, result, "Password should be acceptable.")
    }
    
    /// Tests that `login` builds the Basic-Auth `Authorization` header using
    /// the standard Base64 alphabet with padding (RFC 4648 §4, as required by
    /// RFC 7617), rather than the URL-safe alphabet. The credentials below are
    /// chosen so that the colon-concatenated, UTF-8-encoded username:password
    /// bytes Base64-encode differently under the standard and URL-safe
    /// alphabets (contains `/` and requires `=` padding under the standard
    /// alphabet), so a regression back to URL-safe encoding would be caught.
    @MainActor
    func testLoginUsesStandardBase64ForAuthorizationHeader() async throws {
        let identifier = NetworkEphemeralInstanceIdentifier
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ScriptedURLProtocol.self] + (config.protocolClasses ?? [])
        ScriptedURLProtocol.installScripts([
            .init(statusCode: 401, headers: nil, body: Data())
        ], identifier: identifier)
        Network.setSessionConfiguration(config, identifier: identifier)
        defer {
            Network.removeSharedInstance(forIdentifier: identifier)
            ScriptedURLProtocol.removeScripts(identifier: identifier)
        }

        let manager = SalesforceManager.shared.useNativeLogin(
            withConsumerKey: "c",
            callbackUrl: "r",
            communityUrl: "https://login.example.com",
            nativeLoginViewController: UIViewController(),
            scene: nil)

        let username = "regdemouser501@salesforce.com"
        let password = "Winter2026!?!"
        _ = await manager.login(username: username, password: password)

        let authRequest = try XCTUnwrap(
            ScriptedURLProtocol.capturedRequests(identifier: identifier).first {
                $0.value(forHTTPHeaderField: "Authorization") != nil
            })
        let expectedCreds = Data("\(username):\(password)".utf8).base64EncodedString()
        XCTAssertEqual(
            authRequest.value(forHTTPHeaderField: "Authorization"),
            "Basic \(expectedCreds)")
    }

    /// Tests that `submitPasswordlessAuthorizationRequest`, which shares the
    /// same colon-concatenated Base64 encoding helper as `login`, also produces
    /// a standard-alphabet, padded Basic-Auth header rather than URL-safe
    /// encoding.
    @MainActor
    func testSubmitPasswordlessAuthorizationRequestUsesStandardBase64ForAuthorizationHeader() async throws {
        let identifier = NetworkEphemeralInstanceIdentifier
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ScriptedURLProtocol.self] + (config.protocolClasses ?? [])
        ScriptedURLProtocol.installScripts([
            .init(statusCode: 401, headers: nil, body: Data())
        ], identifier: identifier)
        Network.setSessionConfiguration(config, identifier: identifier)
        defer {
            Network.removeSharedInstance(forIdentifier: identifier)
            ScriptedURLProtocol.removeScripts(identifier: identifier)
        }

        let manager = SalesforceManager.shared.useNativeLogin(
            withConsumerKey: "c",
            callbackUrl: "r",
            communityUrl: "https://login.example.com",
            nativeLoginViewController: UIViewController(),
            scene: nil)

        let otpIdentifier = "regdemouser501@salesforce.com"
        let otp = "Winter2026!?!"
        _ = await manager.submitPasswordlessAuthorizationRequest(
            otp: otp,
            otpIdentifier: otpIdentifier,
            otpVerificationMethod: .email)

        let authRequest = try XCTUnwrap(
            ScriptedURLProtocol.capturedRequests(identifier: identifier).first {
                $0.value(forHTTPHeaderField: "Authorization") != nil
            })
        let expectedCreds = Data("\(otpIdentifier):\(otp)".utf8).base64EncodedString()
        XCTAssertEqual(
            authRequest.value(forHTTPHeaderField: "Authorization"),
            "Basic \(expectedCreds)")
    }

    func testShouldShowBackButton() {
        let accountManager = UserAccountManager.shared
        XCTAssertNil(accountManager.currentUserAccount)
        XCTAssertFalse(nativeLoginManager.shouldShowBackButton(), "Should not show back button by default.")
        _ = createUser()
        XCTAssertTrue(nativeLoginManager.shouldShowBackButton(), "Should show back button when there is a logged in user.")
        
        // Clear account
        _ = KeychainHelper.removeAll()
        UserAccountManager.shared.clearAllAccountState()
        XCTAssertFalse(nativeLoginManager.shouldShowBackButton(), "Should not show back button when there are no other accounts.")
    }
    
    func testShouldShowBackButtonWithBioAuth() {
        let user = createUser()
        let bioAuthManager = BiometricAuthenticationManagerInternal.shared
        bioAuthManager.storePolicy(userAccount: user, hasMobilePolicy: true, sessionTimeout: 1)
        XCTAssertTrue(nativeLoginManager.shouldShowBackButton(), "Should show back button when there is a logged in user (but not locked).")

        bioAuthManager.locked = true
        XCTAssertFalse(nativeLoginManager.shouldShowBackButton(), "Should not show back button when bio auth is locked.")
        
        // Clear account
        _ = KeychainHelper.removeAll()
        UserAccountManager.shared.clearAllAccountState()
        bioAuthManager.locked = false
    }
    
    func testNativeLoginPresentationHidesNavigationBar() {
        // Verify that when native login is enabled and the auth view is presented,
        // the wrapping SFSDKNavigationController has its navigation bar hidden.
        // This prevents an unwanted Salesforce-blue nav bar from appearing on top
        // of custom native login views (especially on re-presentation after
        // fallback-to-web-auth → back).
        let accountManager = UserAccountManager.shared

        // Native login is already configured via `nativeLoginManager` property.
        XCTAssertTrue(accountManager.nativeLoginEnabled, "Native login should be enabled.")
        accountManager.shouldFallbackToWebAuthentication = false

        let expectation = self.expectation(description: "Auth view presented")
        var presentedController: UIViewController?

        // Set up auth window with a mock VC that captures presentViewController: calls.
        // This lets the real presentLoginView: execute end-to-end.
        let mockPresenter = MockPresenterViewController()
        mockPresenter.onPresent = { controller in
            presentedController = controller
            expectation.fulfill()
        }
        SFSDKWindowManager.shared().authWindow(nil).viewController = mockPresenter

        // Directly invoke the default authViewHandler's display block with an
        // AuthViewHolder configured for the native login path (no loginController,
        // not advanced auth). This triggers presentLoginView: in production code.
        let viewHolder = AuthViewHolder()
        viewHolder.isAdvancedAuthFlow = false
        accountManager.authViewHandler.authViewDisplayBlock(viewHolder)

        waitForExpectations(timeout: 5)

        // Verify the navigation bar is hidden on the presented SFSDKNavigationController
        if let navController = presentedController as? UINavigationController {
            XCTAssertTrue(navController.isNavigationBarHidden, "Navigation bar should be hidden for native login presentation.")
        } else {
            XCTFail("Expected a UINavigationController to be presented for native login.")
        }
    }

    private func createUser() -> UserAccount {
        let credentials = OAuthCredentials(identifier: "identifier-0", clientId: "fakeClientIdForTesting", encrypted: true)!
        let user = UserAccount(credentials: credentials)
        user.idData = IdentityData(jsonDict: [ "user_id": "0" ])
        do {
            try UserAccountManager.shared.upsert(user)
        } catch { }
        UserAccountManager.shared.currentUserAccount = user
        
        return user
    }
}


// MARK: - Test Helpers

private class MockPresenterViewController: UIViewController {
    var onPresent: ((UIViewController) -> Void)?

    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        onPresent?(viewControllerToPresent)
        completion?()
    }
}

private final class NativeIntentURLProtocol: URLProtocol {
    static var onAuthorize: (() -> Void)?
    static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: url.path.hasSuffix("authorize") ? 200 : 400,
                                             httpVersion: "HTTP/1.1", headerFields: nil) else { return }
        let body: Data
        if url.path.hasSuffix("authorize") {
            if Thread.isMainThread {
                Self.onAuthorize?()
            } else {
                DispatchQueue.main.sync { Self.onAuthorize?() }
            }
            body = Data("{\"code\":\"test-code\",\"sfdc_community_url\":\"https://community.example.com/site\",\"sfdc_community_id\":\"community\"}".utf8)
        } else {
            body = Data("{\"error\":\"invalid_grant\"}".utf8)
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class NativeOverlapURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var held: NativeOverlapURLProtocol?
    private static var authorizeCount = 0
    private static var started: (() -> Void)?
    private static var tokens = 0
    private static var holdToken = false
    private static var tokenSuccess = false

    static var tokenRequests: Int {
        lock.lock()
        defer { lock.unlock() }
        return tokens
    }

    static func reset(holdToken: Bool = false, tokenSuccess: Bool = false, onStart: @escaping () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        held = nil
        authorizeCount = 0
        tokens = 0
        Self.holdToken = holdToken
        Self.tokenSuccess = tokenSuccess
        started = onStart
    }

    static func releaseFirst() {
        lock.lock()
        let first = held
        held = nil
        lock.unlock()
        first?.respond()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        if request.url?.path.hasSuffix("authorize") == true {
            Self.authorizeCount += 1
            if Self.authorizeCount == 1 && !Self.holdToken {
                Self.held = self
                let callback = Self.started
                Self.lock.unlock()
                callback?()
                return
            }
        } else {
            Self.tokens += 1
            if Self.tokens == 1 && Self.holdToken {
                Self.held = self
                let callback = Self.started
                Self.lock.unlock()
                callback?()
                return
            }
        }
        Self.lock.unlock()
        respond()
    }

    private func respond() {
        guard let url = request.url else { return }
        let authorize = url.path.hasSuffix("authorize")
        guard let response = HTTPURLResponse(url: url, statusCode: authorize || Self.tokenSuccess ? 200 : 400,
                                             httpVersion: "HTTP/1.1", headerFields: nil) else { return }
        let body = authorize
            ? "{\"code\":\"test-code\",\"sfdc_community_url\":\"https://community.example.com/site\",\"sfdc_community_id\":\"community\"}"
            : Self.tokenSuccess
                ? "{\"access_token\":\"test-token\",\"refresh_token\":\"test-refresh\",\"token_type\":\"Bearer\",\"instance_url\":\"https://community.example.com\"}"
                : "{\"error\":\"invalid_grant\"}"
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private enum NativeIdentityCapture {
    static var onRetrieve: ((SFIdentityCoordinator) -> Void)?
    static var onCancel: ((SFIdentityCoordinator) -> Void)?
}

private enum NativeIdentityRefreshCapture {
    static var onRefresh: (() -> Void)?
    static var completion: ((OAuthCredentials) -> Void)?
    static var failure: ((NSError) -> Void)?
    static var requests: [URLRequest] = []
}

private enum NativeLifecycleCapture {
    static var requests: [URLRequest] = []
    static var responses: [(Data?, URLResponse?, Error?) -> Void] = []
    static var onRefresh: (() -> Void)?
    static var onRefreshCompleted: (() -> Void)?
    static var holdIdentity = false
    static var onIdentity: (() -> Void)?
}

private enum NativeFallbackCapture {
    static var requests: [URLRequest] = []
    static var responses: [(Data, String) -> Void] = []
    static var onRequest: (() -> Void)?
    static var onAuthenticate: ((SFOAuthCoordinator) -> Void)?
}

private extension RestClient {
    @objc func nativeTestHoldFallbackRequest(_ request: RestRequest,
                                             failureBlock: @escaping SFRestRequestFailBlock,
                                             successBlock: @escaping SFRestResponseBlock) {
        DispatchQueue.main.async {
            guard let credentials = OAuthCredentials(identifier: "fallback-transport", clientId: "native-dpop-test", encrypted: true),
                  let prepared = request.prepare(forSend: UserAccount(credentials: credentials)), let url = prepared.url else { return }
            NativeFallbackCapture.requests.append(prepared)
            var pendingSuccess: SFRestResponseBlock? = successBlock
            NativeFallbackCapture.responses.append { data, nonce in
                guard let callback = pendingSuccess else { return }
                pendingSuccess = nil
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["DPoP-Nonce": nonce])
                callback(data, response)
            }
            NativeFallbackCapture.onRequest?()
        }
    }
}

private extension SFOAuthCoordinator {
    @objc func nativeTestHoldFallbackAuthentication(_ credentials: OAuthCredentials) {
        NativeFallbackCapture.onAuthenticate?(self)
    }
}

private extension SFSDKWebViewStateManager {
    @objc static func nativeTestRemoveSession(_ completion: @escaping () -> Void) {
        // Cookie-store latency is not part of the native request/fallback contract.
        completion()
    }
}

private extension NSObject {
    @objc func nativeTestObserveRealRefresh(_ credentials: OAuthCredentials,
                                          completion: @escaping (OAuthCredentials) -> Void,
                                          error: @escaping (NSError) -> Void) {
        // Invoke the unchanged shared coordinator/refresher/attestation/OAuth pipeline.
        let finished = NativeLifecycleCapture.onRefreshCompleted
        nativeTestObserveRealRefresh(credentials, completion: { updated in
            completion(updated)
            finished?()
        }, error: { failure in
            error(failure)
            finished?()
        })
    }

    @objc func nativeTestHoldIdentityRefresh(_ credentials: OAuthCredentials,
                                            completion: @escaping (OAuthCredentials) -> Void,
                                            error: @escaping (NSError) -> Void) {
        NativeIdentityRefreshCapture.completion = completion
        NativeIdentityRefreshCapture.failure = error
        NativeIdentityRefreshCapture.onRefresh?()
    }
}

private extension Network {
    @objc func nativeTestHoldLifecycleRequest(_ request: URLRequest,
                                             dataResponseBlock: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        guard request.url?.path.hasPrefix("/id/") == true || request.url?.path == "/services/oauth2/token" else {
            return nativeTestHoldLifecycleRequest(request, dataResponseBlock: dataResponseBlock)
        }
        NativeLifecycleCapture.requests.append(request)
        if request.url?.path.hasPrefix("/id/") == true {
            NativeLifecycleCapture.onIdentity?()
            if NativeLifecycleCapture.holdIdentity {
                var pendingResponse: ((Data?, URLResponse?, Error?) -> Void)? = dataResponseBlock
                NativeLifecycleCapture.responses.append { data, response, error in
                    guard let callback = pendingResponse else { return }
                    pendingResponse = nil
                    callback(data, response, error)
                }
                return URLSession.shared.dataTask(with: request)
            }
            let response = request.url.flatMap { HTTPURLResponse(url: $0, statusCode: 403, httpVersion: "HTTP/1.1", headerFields: nil) }
            DispatchQueue.main.async { dataResponseBlock(Data(), response, nil) }
        } else {
            var pendingResponse: ((Data?, URLResponse?, Error?) -> Void)? = dataResponseBlock
            NativeLifecycleCapture.responses.append { data, response, error in
                guard let callback = pendingResponse else { return }
                pendingResponse = nil
                callback(data, response, error)
            }
            NativeLifecycleCapture.onRefresh?()
        }
        return URLSession.shared.dataTask(with: request)
    }

    @objc func nativeTestSendIdentityRequest(_ request: URLRequest,
                                            dataResponseBlock: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        guard request.url?.path.hasPrefix("/id/") == true else {
            return nativeTestSendIdentityRequest(request, dataResponseBlock: dataResponseBlock)
        }
        NativeIdentityRefreshCapture.requests.append(request)
        if NativeIdentityRefreshCapture.requests.count == 1 {
            let response = request.url.flatMap { HTTPURLResponse(url: $0, statusCode: 403, httpVersion: "HTTP/1.1", headerFields: nil) }
            DispatchQueue.main.async { dataResponseBlock(Data(), response, nil) }
        }
        // An inert task: no external request is ever resumed.
        return URLSession.shared.dataTask(with: request)
    }
}

private extension SFIdentityCoordinator {
    @objc func nativeTestIdentityRetrieval() {
        NativeIdentityCapture.onRetrieve?(self)
    }

    @objc func nativeTestCancelRetrieval() {
        NativeIdentityCapture.onCancel?(self)
        nativeTestCancelRetrieval() // Calls the production implementation while swizzled.
    }
}
