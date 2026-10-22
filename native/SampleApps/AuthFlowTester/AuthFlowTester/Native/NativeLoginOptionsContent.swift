//
//  NativeLoginOptionsContent.swift
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

/// Content injected at the top of the SDK's Login Options screen (see `LoginOptionsCustomization`):
/// the Authentication Mode picker and, for Native mode, the Native Login client settings. In Native
/// mode the SDK's browser-only sections are hidden.
struct NativeLoginOptionsContent: View {
    @ObservedObject private var settings = NativeLoginSettings.shared
    @State private var draft = NativeLoginConfig()
    @State private var showImportAlert = false
    @State private var importJSONText = ""

    /// Installs this content into the SDK's Login Options screen.
    static func install() {
        let customization = LoginOptionsViewController.customization
        customization.topContent = AnyView(NativeLoginOptionsContent())
        customization.hidesDefaultSections = NativeLoginSettings.shared.savedMode == .native
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Authentication Mode")
                .font(.headline)
            Picker("Authentication Mode", selection: $settings.savedMode) {
                ForEach(AuthenticationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("authModePicker")
            if settings.relaunchRequired {
                Text("Relaunch to apply")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .accessibilityIdentifier("authModeRelaunchNotice")
            }

            if settings.savedMode == .native {
                Divider()

                HStack {
                    Text("Native Login Client")
                        .font(.headline)
                    Spacer()
                    Button {
                        importJSONText = ""
                        showImportAlert = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityIdentifier("importNativeConfigButton")
                }
                field("Client ID", text: $draft.clientId, id: "nativeClientIdField")
                field("Native Callback URL", text: $draft.callbackUrl, id: "nativeCallbackUrlField")
                field("Community Login URL", text: $draft.communityUrl, id: "nativeCommunityUrlField")

                Toggle("Use Hybrid Authentication", isOn: $draft.useHybridFlow)
                    .accessibilityIdentifier("useHybridFlowToggle")
                Toggle("Use DPoP", isOn: $draft.useDPoP)
                    .accessibilityIdentifier("useDPoPToggle")
                Button("Apply") {
                    settings.update(draft)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("nativeApplyButton")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .onAppear { draft = settings.config }
        .onChange(of: settings.savedMode) { _, mode in
            LoginOptionsViewController.customization.hidesDefaultSections = mode == .native
        }
        .alert("Import Native Login Configuration", isPresented: $showImportAlert) {
            TextField("Paste JSON here", text: $importJSONText)
            Button("Import") {
                // Fills the fields; Done commits them.
                _ = draft.apply(json: importJSONText)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Paste JSON with consumerKey, redirectUri, communityUrl, useDPoP and useHybridFlow")
        }
    }

    private func field(_ title: String, text: Binding<String>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField(title, text: text)
                .font(.system(.caption, design: .monospaced))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .accessibilityIdentifier(id)
        }
    }
}

/// Presents the SDK's Login Options screen from the native form.
struct LoginOptionsSheetView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        LoginOptionsViewController.makeViewController { }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
}
