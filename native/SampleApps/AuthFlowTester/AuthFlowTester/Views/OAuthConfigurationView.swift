/*
 OAuthConfigurationView.swift
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

// MARK: - Labels Constants
public struct OAuthConfigLabels {
    public static let consumerKey = "Configured Consumer Key"
    public static let callbackUrl = "Configured Callback URL"
    public static let scopes = "Configured Scopes"
}

struct OAuthConfigurationView: View {
    @Binding var isExpanded: Bool
    
    // Export alert state
    @State private var showExportAlert = false
    @State private var exportedJSON = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text("OAuth Configuration")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Button(action: {
                    exportedJSON = generateConfigJSON()
                    showExportAlert = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .accessibilityIdentifier("exportOAuthConfigButton")
            }
            
            if isExpanded {
                InfoRowView(label: configuredConsumerKeyLabel, 
                       value: configuredConsumerKey, isSensitive: true)
                
                InfoRowView(label: "\(OAuthConfigLabels.callbackUrl):", 
                       value: configuredCallbackUrl)
                
                InfoRowView(label: "\(OAuthConfigLabels.scopes):", 
                       value: configuredScopes)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .alert("OAuth Configuration JSON", isPresented: $showExportAlert) {
            Button("Copy to Clipboard") {
                UIPasteboard.general.string = exportedJSON
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportedJSON)
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateConfigJSON() -> String {
        let result: [String: String] = [
            OAuthConfigLabels.consumerKey: configuredConsumerKey,
            OAuthConfigLabels.callbackUrl: configuredCallbackUrl,
            OAuthConfigLabels.scopes: configuredScopes
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
    
    // MARK: - Computed Properties
    
    private var configuredConsumerKeyLabel: String {
        let label = "\(OAuthConfigLabels.consumerKey):"
        if let defaultKey = SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey,
           configuredConsumerKey == defaultKey {
            return "\(label) (default)"
        }
        return label
    }
    
    private var configuredConsumerKey: String {
        return UserAccountManager.shared.oauthClientID
    }
    
    private var configuredCallbackUrl: String {
        return UserAccountManager.shared.oauthCompletionURL
    }
    
    private var configuredScopes: String {
        let scopes = UserAccountManager.shared.scopes
        return scopes.isEmpty ? "(none)" : scopes.sorted().joined(separator: " ")
    }
}

