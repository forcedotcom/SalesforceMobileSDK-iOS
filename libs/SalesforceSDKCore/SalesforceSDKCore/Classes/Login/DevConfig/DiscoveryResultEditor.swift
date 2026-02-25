/*
 DiscoveryResultEditor.swift
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

/// JSON keys for importing a discovery result.
public enum DiscoveryResultJSONKeys {
    public static let loginHint = "login_hint"
    public static let myDomain = "my_domain"
}

/// Editor for simulating a domain discovery result (login host and username). Used in debug to bypass the real discovery flow.
public struct DiscoveryResultEditor: View {
    @Binding var loginHost: String
    @Binding var userName: String
    let onUseForSimulation: (DomainDiscoveryResult?) -> Void
    @State private var isExpanded: Bool = false
    @State private var showImportAlert: Bool = false
    @State private var importJSONText: String = ""
    let initiallyExpanded: Bool

    public init(
        loginHost: Binding<String>,
        userName: Binding<String>,
        onUseForSimulation: @escaping (DomainDiscoveryResult?) -> Void,
        initiallyExpanded: Bool = false
    ) {
        self._loginHost = loginHost
        self._userName = userName
        self.onUseForSimulation = onUseForSimulation
        self.initiallyExpanded = initiallyExpanded
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text(SFSDKResourceUtils.localizedString("DISCOVERY_SIMULATE_TITLE"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                    }
                }
                Button(action: {
                    importJSONText = ""
                    showImportAlert = true
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .accessibilityIdentifier("importDiscoveryResultButton")
            }
            .padding(.horizontal)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(SFSDKResourceUtils.localizedString("DISCOVERY_LOGIN_HOST_LABEL"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField(SFSDKResourceUtils.localizedString("DISCOVERY_LOGIN_HOST_PLACEHOLDER"), text: $loginHost)
                        .font(.system(.caption, design: .monospaced))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .accessibilityIdentifier("discoveryLoginHostTextField")

                    Text(SFSDKResourceUtils.localizedString("DISCOVERY_USER_NAME_LABEL"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField(SFSDKResourceUtils.localizedString("DISCOVERY_USER_NAME_PLACEHOLDER"), text: $userName)
                        .font(.system(.caption, design: .monospaced))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                        .accessibilityIdentifier("discoveryUserNameTextField")

                    Button(action: applySimulatedResult) {
                        Text(SFSDKResourceUtils.localizedString("DISCOVERY_SAVE_SIMULATED_RESULT"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.orange)
                            .cornerRadius(8)
                    }
                    .accessibilityIdentifier("saveSimulatedResultButton")
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .onAppear {
            isExpanded = initiallyExpanded
        }
        .alert("Import Discovery Result", isPresented: $showImportAlert) {
            TextField("Paste JSON here", text: $importJSONText)
            Button("Import") {
                if importDiscoveryResultFromJSON() {
                    applySimulatedResult()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Paste JSON with login_hint and my_domain")
        }
    }

    private func importDiscoveryResultFromJSON() -> Bool {
        guard let jsonData = importJSONText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            return false
        }

        var discoveryChanged = false

        if let hint = json[DiscoveryResultJSONKeys.loginHint] as? String {
            userName = hint
            discoveryChanged = true
        }
        if let domain = json[DiscoveryResultJSONKeys.myDomain] as? String {
            loginHost = domain
            discoveryChanged = true
        }

        return discoveryChanged
    }

    /// Applies current field values and invokes the callback. Internal for unit testing.
    internal func applySimulatedResult() {
        let trimmedHost = loginHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHost.isEmpty {
            onUseForSimulation(nil)
            return
        }
        let result = DomainDiscoveryResult(loginHint: trimmedUser, myDomain: trimmedHost)
        onUseForSimulation(result)
    }
}
