/*
 AuthenticationModeView.swift
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

/// Which Login Options sections show, for the debug settings' availability and mode.
struct LoginOptionsVisibility: Equatable {
    /// The Authentication Mode picker (and the import button).
    let showsAuthenticationMode: Bool
    /// The Native Login fields and toggles.
    let showsNativeOptions: Bool
    /// The browser-only rows: flow types, DPoP, static/dynamic config and discovery.
    let showsBrowserOptions: Bool

    static func make(isAvailable: Bool, mode: AuthenticationMode) -> LoginOptionsVisibility {
        let isNative = isAvailable && mode == .native
        return LoginOptionsVisibility(showsAuthenticationMode: isAvailable,
                                      showsNativeOptions: isNative,
                                      showsBrowserOptions: !isNative)
    }
}

/// Authentication Mode section of the Login Options: Browser or the SDK's debug Native Login form,
/// and the Native Login configuration. Changes are saved as they are made and take effect when the
/// Login Options close (authentication restarts).
struct AuthenticationModeView: View {
    @ObservedObject var settings: NativeLoginDebugSettings
    @State private var showImportAlert = false
    @State private var importJSONText = ""
    @State private var importError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(SFSDKResourceUtils.localizedString("LOGIN_OPTIONS_AUTH_MODE_TITLE"))
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
                .accessibilityIdentifier("importNativeConfigButton")
            }

            HStack(spacing: 0) {
                modeButton(.browser, title: "LOGIN_OPTIONS_AUTH_MODE_BROWSER", identifier: "authModeBrowser")
                modeButton(.native, title: "LOGIN_OPTIONS_AUTH_MODE_NATIVE", identifier: "authModeNative")
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemFill)))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("authModePicker")

            if let importError {
                Text(importError)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .accessibilityIdentifier("nativeConfigError")
            }

            if settings.mode == .native {
                nativeOptions
            }
        }
        .padding(.horizontal, 20)
        .alert(SFSDKResourceUtils.localizedString("LOGIN_OPTIONS_NATIVE_IMPORT"), isPresented: $showImportAlert) {
            TextField(SFSDKResourceUtils.localizedString("LOGIN_OPTIONS_NATIVE_IMPORT_PLACEHOLDER"), text: $importJSONText)
                .accessibilityIdentifier("importNativeConfigField")
            Button(SFSDKResourceUtils.localizedString("LOGIN_OPTIONS_NATIVE_IMPORT_BUTTON")) {
                importConfiguration(importJSONText)
            }
            .accessibilityIdentifier("importNativeConfigApplyButton")
            Button(SFSDKResourceUtils.localizedString("LOGIN_OPTIONS_NATIVE_IMPORT_CANCEL"), role: .cancel) { }
        } message: {
            Text(SFSDKResourceUtils.localizedString("LOGIN_OPTIONS_NATIVE_IMPORT_MESSAGE"))
        }
    }

    @ViewBuilder
    private var nativeOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            nativeField("LOGIN_OPTIONS_NATIVE_CLIENT_ID", identifier: "nativeClientIdField",
                        value: binding(\.consumerKey))
            nativeField("LOGIN_OPTIONS_NATIVE_CALLBACK_URL", identifier: "nativeCallbackUrlField",
                        value: binding(\.redirectUri))
            nativeField("LOGIN_OPTIONS_NATIVE_COMMUNITY_URL", identifier: "nativeCommunityUrlField",
                        value: binding(\.communityUrl))

            if let error = settings.config.validationError, importError == nil {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .accessibilityIdentifier("nativeConfigError")
            }

            Toggle(SFSDKResourceUtils.localizedString("LOGIN_OPTIONS_NATIVE_USE_DPOP"), isOn: binding(\.useDPoP))
                .accessibilityIdentifier("useDPoPToggle")
            Toggle(SFSDKResourceUtils.localizedString("LOGIN_OPTIONS_NATIVE_USE_HYBRID"), isOn: binding(\.useHybridFlow))
                .accessibilityIdentifier("useHybridFlowToggle")
        }
    }

    private func modeButton(_ mode: AuthenticationMode, title: String, identifier: String) -> some View {
        let selected = settings.mode == mode
        return Button(action: {
            importError = nil
            settings.mode = mode
        }) {
            Text(SFSDKResourceUtils.localizedString(title))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .foregroundColor(selected ? .white : .primary)
                .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.blue : Color.clear))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func nativeField(_ title: String, identifier: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(SFSDKResourceUtils.localizedString(title))
                .font(.caption)
                .foregroundColor(.secondary)
            TextField(SFSDKResourceUtils.localizedString(title), text: value)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(identifier == "nativeClientIdField" ? .asciiCapable : .URL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(.body, design: .monospaced))
                .accessibilityIdentifier(identifier)
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<NativeLoginDebugConfig, Value>) -> Binding<Value> {
        Binding(
            get: { settings.config[keyPath: keyPath] },
            set: { newValue in
                importError = nil
                var config = settings.config
                config[keyPath: keyPath] = newValue
                settings.config = config
            }
        )
    }

    internal func importConfiguration(_ json: String) {
        do {
            try settings.apply(json: json)
            importError = nil
        } catch {
            importError = error.localizedDescription
        }
    }
}
