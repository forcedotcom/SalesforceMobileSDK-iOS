/*
 DebugNativeLoginView.swift
 SalesforceSDKCore

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

import SwiftUI
import UIKit

/// State of the SDK's debug Native Login form.
enum DebugNativeLoginState: Equatable {
    case idle
    case loading
    case failed(result: NativeLoginResult, detail: String)
    case success
}

extension NativeLoginResult {
    /// The case name, as shown in the debug form's failure detail.
    var name: String {
        switch self {
        case .invalidEmail: return "invalidEmail"
        case .invalidUsername: return "invalidUsername"
        case .invalidPassword: return "invalidPassword"
        case .invalidCredentials: return "invalidCredentials"
        case .unknownError: return "unknownError"
        case .success: return "success"
        @unknown default: return "unknownError"
        }
    }
}

/// Drives the debug Native Login form through the public Native Login API. The password is kept in
/// memory only and cleared after each attempt.
@MainActor
final class DebugNativeLoginModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published private(set) var state: DebugNativeLoginState = .idle

    private let loginAction: (String, String) async -> NativeLoginResult
    private let cancelAction: () -> Void
    private let fallbackAction: () -> Void
    private let invalidateAttemptAction: () -> Void
    private let canDismissProvider: () -> Bool
    private let diagnostics: NativeLoginDiagnostics
    private var loginTask: Task<Void, Never>?

    init(loginAction: @escaping (String, String) async -> NativeLoginResult,
         cancelAction: @escaping () -> Void,
         fallbackAction: @escaping () -> Void,
         invalidateAttempt: @escaping () -> Void = {},
         canDismiss: @escaping () -> Bool,
         diagnostics: NativeLoginDiagnostics = .shared) {
        self.loginAction = loginAction
        self.cancelAction = cancelAction
        self.fallbackAction = fallbackAction
        self.invalidateAttemptAction = invalidateAttempt
        self.canDismissProvider = canDismiss
        self.diagnostics = diagnostics
    }

    /// Builds a model for the SDK's current Native Login manager.
    convenience init(manager: NativeLoginManager) {
        self.init(loginAction: { username, password in await manager.login(username: username, password: password) },
                  cancelAction: { manager.cancelAuthentication() },
                  fallbackAction: { manager.fallbackToWebAuthentication() },
                  invalidateAttempt: { UserAccountManager.shared.perform(NSSelectorFromString("cancelNativeAuthentications")) },
                  canDismiss: { manager.shouldShowBackButton() })
    }

    /// True when an account exists to return to.
    var canDismiss: Bool { canDismissProvider() }

    /// Cancel is offered to return to an existing account, or to stop an attempt in progress.
    var showsCancel: Bool { canDismiss || state == .loading }

    /// Redacted network attempts of the last login.
    var diagnosticsSummary: String { diagnostics.summary }

    /// The task of the attempt in progress, exposed so tests can await it.
    var currentLoginTask: Task<Void, Never>? { loginTask }

    func login() {
        guard state != .loading else { return }
        state = .loading
        diagnostics.reset()
        let username = self.username
        let password = self.password
        loginTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.loginAction(username, password)
            guard !Task.isCancelled else { return }
            self.finish(result)
        }
    }

    /// Cancels an attempt in progress (which then adds no account), and returns to the existing
    /// account when there is one.
    func cancel() {
        stopLogin()
        if canDismiss {
            cancelAction()
        }
    }

    /// Hands off to the browser login, which keeps using the boot config and the browser options.
    func fallbackToBrowser() {
        stopLogin()
        fallbackAction()
    }

    /// Cancelling the Swift task does not stop the SDK request chain, so the SDK attempt is
    /// invalidated too: a token response that arrives later then creates no account, and a retry
    /// starts a fresh attempt.
    private func stopLogin() {
        loginTask?.cancel()
        loginTask = nil
        if state == .loading {
            invalidateAttemptAction()
            state = .idle
        }
    }

    private func finish(_ result: NativeLoginResult) {
        loginTask = nil
        password = ""
        if result == .success {
            state = .success
        } else {
            let detail = diagnostics.lastFailure.map { "\(result.name) (\($0))" } ?? result.name
            state = .failed(result: result, detail: detail)
        }
    }
}

/// The SDK's debug Native Login form, shown in Native mode of the Login Options when the app
/// registered no native login of its own.
struct DebugNativeLoginView: View {
    @ObservedObject var model: DebugNativeLoginModel
    let onLoginOptions: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(SFSDKResourceUtils.localizedString("NATIVE_LOGIN_DEBUG_TITLE"))
                    .font(.title2)
                    .padding(.bottom, 8)

                TextField(SFSDKResourceUtils.localizedString("NATIVE_LOGIN_DEBUG_USERNAME"), text: $model.username)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("nativeUsernameField")

                SecureField(SFSDKResourceUtils.localizedString("NATIVE_LOGIN_DEBUG_PASSWORD"), text: $model.password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("nativePasswordField")

                Button(action: model.login) {
                    Text(SFSDKResourceUtils.localizedString("NATIVE_LOGIN_DEBUG_LOG_IN"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.state == .loading)
                .accessibilityIdentifier("nativeLoginButton")

                Button(action: model.fallbackToBrowser) {
                    Text(SFSDKResourceUtils.localizedString("NATIVE_LOGIN_DEBUG_BROWSER_FALLBACK"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("nativeBrowserFallbackButton")

                switch model.state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("nativeLoadingIndicator")
                case .failed(_, let detail):
                    Text(SFSDKResourceUtils.localizedString("NATIVE_LOGIN_DEBUG_FAILED"))
                        .foregroundColor(.red)
                        .accessibilityIdentifier("nativeResultLabel")
                    Text(detail)
                        .font(.callout)
                        .accessibilityIdentifier("nativeErrorDetail")
                    Text(model.diagnosticsSummary)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("nativeDiagnosticsLabel")
                case .success:
                    Text("success")
                        .accessibilityIdentifier("nativeResultLabel")
                case .idle:
                    EmptyView()
                }

                HStack {
                    Button(SFSDKResourceUtils.localizedString("LOGIN_OPTIONS"), action: onLoginOptions)
                        .accessibilityIdentifier("nativeLoginOptionsButton")
                    Spacer()
                    if model.showsCancel {
                        Button(SFSDKResourceUtils.localizedString("NATIVE_LOGIN_DEBUG_CANCEL"), action: model.cancel)
                            .accessibilityIdentifier("nativeCancelButton")
                    }
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
    }
}

/// Hosts the SDK's debug Native Login form. Internal to the Mobile SDK; public only so the
/// Objective-C login routing can create it.
@objc(SFSDKDebugNativeLoginViewController)
public final class DebugNativeLoginViewController: UIViewController {

    private var model: DebugNativeLoginModel?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        // The manager is the one registered with this form; it is replaced when settings change.
        let registered: NativeLoginManager? = SalesforceManager.shared.nativeLoginManager()
        guard let manager = registered else { return }
        let model = DebugNativeLoginModel(manager: manager)
        self.model = model
        let hosting = UIHostingController(rootView: DebugNativeLoginView(model: model, onLoginOptions: { [weak self] in
            self?.presentLoginOptions()
        }))
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
    }

    private func presentLoginOptions() {
        let loginOptions = LoginOptionsViewController.makeViewController { [weak self] in
            guard let self else { return }
            self.dismiss(animated: true) {
                // Mode or Native Login configuration changes take effect through a restart.
                let scene = self.view.window?.windowScene
                UserAccountManager.shared.perform(NSSelectorFromString("restartAuthenticationAfterLoginOptionsChangeForScene:"),
                                                  with: scene)
            }
        }
        present(loginOptions, animated: true)
    }
}
