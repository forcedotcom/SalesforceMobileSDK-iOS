/*
 ConfigPickerViewController.swift
 AuthFlowTester

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
import SalesforceSDKCore

struct ConfigPickerView: View {
    @State private var isLoading = false
    @State private var staticConsumerKey = ""
    @State private var staticCallbackUrl = ""
    @State private var staticScopes = ""
    @State private var dynamicConsumerKey = ""
    @State private var dynamicCallbackUrl = ""
    @State private var dynamicScopes = ""
    
    let onConfigurationCompleted: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Flow types section
                    FlowTypesView()
                        .padding(.top, 20)
                    
                    Divider()
                    
                    // Static config section
                    BootConfigEditor(
                        title: "Static Configuration",
                        buttonLabel: "Use static config",
                        buttonColor: .blue,
                        consumerKey: $staticConsumerKey,
                        callbackUrl: $staticCallbackUrl,
                        scopes: $staticScopes,
                        isLoading: isLoading,
                        onUseConfig: handleStaticConfig
                    )
                    
                    Divider()
                    
                    // Dynamic config section
                    BootConfigEditor(
                        title: "Dynamic Configuration",
                        buttonLabel: "Use dynamic config",
                        buttonColor: .green,
                        consumerKey: $dynamicConsumerKey,
                        callbackUrl: $dynamicCallbackUrl,
                        scopes: $dynamicScopes,
                        isLoading: isLoading,
                        onUseConfig: handleDynamicBootconfig
                    )
                    
                    // Loading indicator
                    if isLoading {
                        ProgressView("Authenticating...")
                            .padding()
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationTitle(appName)
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            loadConfigDefaults()
        }
    }
    
    // MARK: - Computed Properties
    
    private var appName: String {
        guard let info = Bundle.main.infoDictionary,
              let name = info[kCFBundleNameKey as String] as? String else {
            return "AuthFlowTester"
        }
        return name
    }
    
    // MARK: - Helper Methods
    
    private func loadConfigDefaults() {
        // Load static config from bootconfig.plist (via SalesforceManager)
        if let config = SalesforceManager.shared.bootConfig {
            staticConsumerKey = config.remoteAccessConsumerKey
            staticCallbackUrl = config.oauthRedirectURI
            staticScopes = config.oauthScopes.sorted().joined(separator: " ")
        }
        
        // Load dynamic config defaults from bootconfig2.plist
        if let config = BootConfig("/bootconfig2.plist") {
            dynamicConsumerKey = config.remoteAccessConsumerKey
            dynamicCallbackUrl = config.oauthRedirectURI
            dynamicScopes = config.oauthScopes.sorted().joined(separator: " ")
        }
    }
    
    // MARK: - Button Actions
    
    private func handleStaticConfig() {
        isLoading = true
        
        // Parse scopes from space-separated string
        let scopesArray = staticScopes
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }
        
        // Create BootConfig with values from the editor
        var configDict: [String: Any] = [
            "remoteAccessConsumerKey": staticConsumerKey,
            "oauthRedirectURI": staticCallbackUrl,
            "shouldAuthenticate": true
        ]
        
        // Only add scopes if not empty
        if !scopesArray.isEmpty {
            configDict["oauthScopes"] = scopesArray
        }
        
        // Set as the bootConfig
        SalesforceManager.shared.bootConfig = BootConfig(configDict)
        SalesforceManager.shared.bootConfigRuntimeSelector = nil
        
        // Update UserAccountManager properties
        UserAccountManager.shared.oauthClientID = staticConsumerKey
        UserAccountManager.shared.oauthCompletionURL = staticCallbackUrl
        UserAccountManager.shared.scopes = scopesArray.isEmpty ? [] : Set(scopesArray)
        
        // Proceed with login
        onConfigurationCompleted()
    }
    
    private func handleDynamicBootconfig() {
        isLoading = true
        
        SalesforceManager.shared.bootConfigRuntimeSelector = { _ in
            // Create dynamic BootConfig from user-entered values
            // Parse scopes from space-separated string
            let scopesArray = self.dynamicScopes
                .split(separator: " ")
                .map { String($0) }
                .filter { !$0.isEmpty }
            
            var configDict: [String: Any] = [
                "remoteAccessConsumerKey": self.dynamicConsumerKey,
                "oauthRedirectURI": self.dynamicCallbackUrl,
                "shouldAuthenticate": true
            ]
            
            // Only add scopes if not empty
            if !scopesArray.isEmpty {
                configDict["oauthScopes"] = scopesArray
            }
            
            return BootConfig(configDict)
        }
        
        // Proceed with login
        onConfigurationCompleted()
    }
}

// MARK: - UIViewControllerRepresentable

struct ConfigPickerViewController: UIViewControllerRepresentable {
    let onConfigurationCompleted: () -> Void
    
    func makeUIViewController(context: Context) -> UIHostingController<ConfigPickerView> {
        return UIHostingController(rootView: ConfigPickerView(onConfigurationCompleted: onConfigurationCompleted))
    }
    
    func updateUIViewController(_ uiViewController: UIHostingController<ConfigPickerView>, context: Context) {
        // No updates needed
    }
}
