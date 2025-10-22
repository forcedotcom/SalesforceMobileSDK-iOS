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
    @State private var dynamicConsumerKey = ""
    @State private var dynamicCallbackUrl = ""
    
    let onConfigurationCompleted: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // App name label
                Text(appName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.top, 40)
                
                // Default config section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Default Configuration")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Consumer Key:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(defaultConsumerKey)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                        
                        Text("Callback URL:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(defaultCallbackUrl)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                    .padding(.horizontal)
                    
                    Button(action: handleDefaultConfig) {
                        Text("Use default config")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                Divider()
                
                // Dynamic config section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dynamic Configuration")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Consumer Key:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Consumer Key", text: $dynamicConsumerKey)
                            .font(.system(.caption, design: .monospaced))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Text("Callback URL:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Callback URL", text: $dynamicCallbackUrl)
                            .font(.system(.caption, design: .monospaced))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal)
                    
                    Button(action: handleDynamicBootconfig) {
                        Text("Use dynamic bootconfig")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                // Loading indicator
                if isLoading {
                    ProgressView("Authenticating...")
                        .padding()
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
        .onAppear {
            loadDynamicConfigDefaults()
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
    
    private var defaultConsumerKey: String {
        return SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey ?? ""
    }
    
    private var defaultCallbackUrl: String {
        return SalesforceManager.shared.bootConfig?.oauthRedirectURI ?? ""
    }
    
    // MARK: - Helper Methods
    
    private func loadDynamicConfigDefaults() {
        // Load initial values from bootconfig2.plist
        if let config = BootConfig("/bootconfig2.plist") {
            dynamicConsumerKey = config.remoteAccessConsumerKey ?? ""
            dynamicCallbackUrl = config.oauthRedirectURI ?? ""
        }
    }
    
    // MARK: - Button Actions
    
    private func handleDefaultConfig() {
        isLoading = true
        
        SalesforceManager.shared.revertToBootConfig()
        
        // Use default bootconfig - no additional setup needed
        onConfigurationCompleted()
    }
    
    private func handleDynamicBootconfig() {
        isLoading = true
        
        // Use the values from the text fields
        SalesforceManager.shared.overrideBootConfig(
            consumerKey: dynamicConsumerKey,
            callbackUrl: dynamicCallbackUrl
        )
        
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
