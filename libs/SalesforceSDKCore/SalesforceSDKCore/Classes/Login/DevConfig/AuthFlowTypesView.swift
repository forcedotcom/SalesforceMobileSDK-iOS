/*
 AuthFlowTypesView.swift
 SalesforceSDKCore

 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
 
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

// MARK: - JSON Import Labels
public struct AuthFlowTypesJSONKeys {
    public static let useWebServerFlow = "useWebServerFlow"
    public static let useHybridFlow = "useHybridFlow"
    public static let forceAdvancedAuthentication = "forceAdvancedAuthentication"
}

public struct AuthFlowTypesView: View {
    @State private var useWebServerFlow: Bool
    @State private var useHybridFlow: Bool
    @State private var forceAdvancedAuth: Bool
    @State private var showImportAlert: Bool = false
    @State private var importJSONText: String = ""

    public init() {
        _useWebServerFlow = State(initialValue: Self.readUseWebServerAuthentication())
        _useHybridFlow = State(initialValue: SalesforceManager.shared.useHybridAuthentication)
        _forceAdvancedAuth = State(initialValue: Self.readForceAdvancedAuthentication())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(SFSDKResourceUtils.localizedString("LOGIN_OPTIONS_AUTH_FLOW_TYPES_TITLE"))
                    .font(.headline)
                Spacer()
                Button(action: {
                    importJSONText = ""
                    showImportAlert = true
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .accessibilityIdentifier("importAuthFlowTypesButton")
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $useWebServerFlow) {
                    Text(SFSDKResourceUtils.localizedString("LOGIN_OPTIONS_USE_WEB_SERVER_FLOW"))
                        .font(.body)
                }
                .accessibilityIdentifier("useWebServerFlowToggle")
                .onChange(of: useWebServerFlow) { _, newValue in
                    Self.writeUseWebServerAuthentication(newValue)
                }
                .padding(.horizontal)

                Toggle(isOn: $useHybridFlow) {
                    Text(SFSDKResourceUtils.localizedString("LOGIN_OPTIONS_USE_HYBRID_FLOW"))
                        .font(.body)
                }
                .accessibilityIdentifier("useHybridFlowToggle")
                .onChange(of: useHybridFlow) { _, newValue in
                    SalesforceManager.shared.useHybridAuthentication = newValue
                }
                .padding(.horizontal)

                Toggle(isOn: $forceAdvancedAuth) {
                    Text(SFSDKResourceUtils.localizedString("LOGIN_OPTIONS_FORCE_ADVANCED_AUTH"))
                        .font(.body)
                }
                .accessibilityIdentifier("forceAdvancedAuthToggle")
                .onChange(of: forceAdvancedAuth) { _, newValue in
                    Self.writeForceAdvancedAuthentication(newValue)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .alert("Import Auth Flow Types", isPresented: $showImportAlert) {
            TextField("Paste JSON here", text: $importJSONText)
            Button("Import") {
                applyAuthFlowTypesFromJSON(importJSONText)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Paste JSON with useWebServerFlow, useHybridFlow and forceAdvancedAuthentication")
        }
    }

    // MARK: - Helper Methods

    internal func applyAuthFlowTypesFromJSON(_ jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            return
        }

        if let webServerFlow = json[AuthFlowTypesJSONKeys.useWebServerFlow] as? Bool {
            useWebServerFlow = webServerFlow
            Self.writeUseWebServerAuthentication(webServerFlow)
        }
        if let hybridFlow = json[AuthFlowTypesJSONKeys.useHybridFlow] as? Bool {
            useHybridFlow = hybridFlow
            SalesforceManager.shared.useHybridAuthentication = hybridFlow
        }
        if let forceAdvancedAuthentication = json[AuthFlowTypesJSONKeys.forceAdvancedAuthentication] as? Bool {
            forceAdvancedAuth = forceAdvancedAuthentication
            Self.writeForceAdvancedAuthentication(forceAdvancedAuthentication)
        }
    }

    // MARK: - forceAdvancedAuthentication access
    //
    // `SalesforceManager.forceAdvancedAuthentication` is deprecated (14.0, removed in 15.0). Internal
    // Objective-C SDK code reaches the same backing storage through the non-deprecated
    // `sdk_forceAdvancedAuthentication` accessor in SalesforceSDKManager+Internal.h, but that class
    // extension is not visible to this framework's own Swift, and Swift has no inline way to silence a
    // deprecation warning. This dev-only toggle therefore reads and writes the flag through key-value
    // coding so it stays warning-free without deprecating this view's public API. Remove these helpers
    // when the property is removed in 15.0.
    private static let forceAdvancedAuthenticationKey = "forceAdvancedAuthentication"

    private static func readForceAdvancedAuthentication() -> Bool {
        (SalesforceManager.shared.value(forKey: forceAdvancedAuthenticationKey) as? Bool) ?? true
    }

    private static func writeForceAdvancedAuthentication(_ newValue: Bool) {
        SalesforceManager.shared.setValue(newValue, forKey: forceAdvancedAuthenticationKey)
    }

    // MARK: - useWebServerAuthentication access
    //
    // `SalesforceManager.useWebServerAuthentication` is deprecated (14.0, removed in 15.0). Internal
    // Objective-C SDK code reaches the same backing storage through the non-deprecated
    // `sdk_useWebServerAuthentication` accessor in SalesforceSDKManager+Internal.h, but that class
    // extension is not visible to this framework's own Swift, and Swift has no inline way to silence a
    // deprecation warning. This dev-only toggle therefore reads and writes the flag through key-value
    // coding so it stays warning-free without deprecating this view's public API. Remove these helpers
    // when the property is removed in 15.0.
    private static let useWebServerAuthenticationKey = "useWebServerAuthentication"

    private static func readUseWebServerAuthentication() -> Bool {
        (SalesforceManager.shared.value(forKey: useWebServerAuthenticationKey) as? Bool) ?? true
    }

    private static func writeUseWebServerAuthentication(_ newValue: Bool) {
        SalesforceManager.shared.setValue(newValue, forKey: useWebServerAuthenticationKey)
    }
}

