//
//  NativeLoginView.swift
//  AuthFlowTester
//
//  Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
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
//

import SwiftUI
import SalesforceSDKCore

/// Username/password form that drives the SDK's `NativeLoginManager`.
///
/// The password is only held in view state and passed to `login`; it is never logged or persisted.
struct NativeLoginView: View {
    @StateObject private var diagnostics = NativeLoginDiagnostics.shared
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var resultText = ""
    @State private var showOptions = false

    private var manager: NativeLoginManager? {
        SalesforceManager.shared.nativeLoginManager()
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Native Login")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)

            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .disabled(isLoading)
                .accessibilityIdentifier("nativeUsernameField")

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(isLoading)
                .accessibilityIdentifier("nativePasswordField")

            Button(action: submit) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .accessibilityIdentifier("nativeLoadingIndicator")
                    }
                    Text(isLoading ? "Logging in..." : "Log In")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isLoading ? Color.gray : Color.blue)
                .cornerRadius(8)
            }
            .disabled(isLoading)
            .accessibilityIdentifier("nativeLoginButton")

            if !resultText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(resultText)
                        .font(.headline)
                        .foregroundColor(resultText == "success" ? .green : .red)
                        .accessibilityIdentifier("nativeResultLabel")
                    if resultText != "success" {
                        Text(diagnostics.lines.last ?? "(no network activity recorded)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("nativeErrorDetail")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if manager?.shouldShowBackButton() == true {
                    Button("Cancel") {
                        manager?.cancelAuthentication()
                    }
                    .accessibilityIdentifier("nativeCancelButton")
                    Spacer()
                }
                Button("Login Options") {
                    showOptions = true
                }
                .accessibilityIdentifier("nativeLoginOptionsButton")
                Spacer()
                Button("Use Browser") {
                    manager?.fallbackToWebAuthentication()
                }
                .disabled(isLoading)
                .accessibilityIdentifier("nativeBrowserFallbackButton")
            }

            Text(diagnostics.text)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("nativeDiagnosticsLabel")

            Spacer()
        }
        .padding(.horizontal, 24)
        .background(Color(.systemBackground))
        .sheet(isPresented: $showOptions) {
            LoginOptionsSheetView()
        }
    }

    private func submit() {
        guard !isLoading, let manager else { return }
        isLoading = true
        resultText = ""
        diagnostics.reset()
        let enteredUsername = username
        let enteredPassword = password
        Task {
            let result = await manager.login(username: enteredUsername, password: enteredPassword)
            await MainActor.run {
                isLoading = false
                resultText = Self.describe(result)
            }
        }
    }

    private static func describe(_ result: NativeLoginResult) -> String {
        switch result {
        case .success: return "success"
        case .invalidEmail: return "invalidEmail"
        case .invalidUsername: return "invalidUsername"
        case .invalidPassword: return "invalidPassword"
        case .invalidCredentials: return "invalidCredentials"
        case .unknownError: return "unknownError"
        @unknown default: return "unknownError"
        }
    }
}
