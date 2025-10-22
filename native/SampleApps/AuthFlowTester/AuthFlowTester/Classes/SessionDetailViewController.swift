/*
 SessionDetailViewController.swift
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

struct SessionDetailView: View {
    @State private var isLoading = false
    @State private var lastRequestResult: String = ""
    @State private var isResultExpanded = false
    @State private var refreshTrigger = UUID()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // REST API Request Section (moved to top)
                VStack(alignment: .leading, spacing: 12) {
                    Text("REST API Test")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Button(action: {
                        Task {
                            await makeRestRequest()
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Making Request..." : "Make REST API Request")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(isLoading ? Color.gray : Color.blue)
                        .cornerRadius(8)
                    }
                    .disabled(isLoading)
                    
                    // Collapsible result section
                    if !lastRequestResult.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: {
                                withAnimation {
                                    isResultExpanded.toggle()
                                }
                            }) {
                                HStack {
                                    Text("Last Request Result:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Image(systemName: isResultExpanded ? "chevron.down" : "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if isResultExpanded {
                                ScrollView([.vertical, .horizontal], showsIndicators: true) {
                                    Text(lastRequestResult)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(lastRequestResult.hasPrefix("✓") ? .green : .red)
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(height: 300)
                                .background(Color(.systemGray6))
                                .cornerRadius(4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                
                // OAuth Configuration Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("OAuth Configuration")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    InfoRow(label: configuredConsumerKeyLabel, 
                           value: configuredConsumerKey)
                    
                    InfoRow(label: "Configured Callback URL:", 
                           value: configuredCallbackUrl)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                
                // Access Scopes Section
                if !accessScopes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Access Scopes")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        InfoRow(label: "Scopes:", value: accessScopes)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                // User Credentials Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("User Credentials")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    InfoRow(label: "Client ID:", value: clientId)
                    InfoRow(label: "Redirect URI:", value: redirectUri)
                    InfoRow(label: "Instance URL:", value: instanceUrl)
                    InfoRow(label: "Organization ID:", value: organizationId)
                    InfoRow(label: "User ID:", value: userId)
                    InfoRow(label: "Username:", value: username)
                    InfoRow(label: "Scopes:", value: credentialsScopes)
                    InfoRow(label: "Token Format:", value: tokenFormat)
                    InfoRow(label: "Beacon Child Consumer Key:", value: beaconChildConsumerKey)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                
                // Token Section (collapsed/sensitive)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tokens")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    InfoRow(label: "Access Token:", value: accessToken, isSensitive: true)
                    InfoRow(label: "Refresh Token:", value: refreshToken, isSensitive: true)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle("AuthFlowTester")
        .navigationBarTitleDisplayMode(.large)
        .id(refreshTrigger)
    }
    
    // MARK: - REST API Request
    
    private func makeRestRequest() async {
        isLoading = true
        lastRequestResult = ""
        
        do {
            let request = RestClient.shared.cheapRequest("v63.0")
            let response = try await RestClient.shared.send(request: request)
            
            // Request succeeded - pretty print the JSON
            let prettyJSON = prettyPrintJSON(response.asString())
            lastRequestResult = "✓ Success:\n\n\(prettyJSON)"
            isResultExpanded = true // Auto-expand on new result
            
            // Force refresh of all fields
            refreshTrigger = UUID()
        } catch {
            // Request failed
            lastRequestResult = "✗ Error: \(error.localizedDescription)"
            isResultExpanded = true // Auto-expand on error
        }
        
        isLoading = false
    }
    
    private func prettyPrintJSON(_ jsonString: String) -> String {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return jsonString
        }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
            let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
            
            if let prettyString = String(data: prettyData, encoding: .utf8) {
                return prettyString
            }
        } catch {
            // If parsing fails, return original string
            return jsonString
        }
        
        return jsonString
    }
    
    // MARK: - Computed Properties
    
    private var configuredConsumerKeyLabel: String {
        let label = "Configured Consumer Key:"
        if let defaultKey = SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey,
           configuredConsumerKey == defaultKey {
            return "\(label) (default)"
        }
        return label
    }
    
    private var configuredConsumerKey: String {
        return UserAccountManager.shared.oauthClientID ?? ""
    }
    
    private var configuredCallbackUrl: String {
        return UserAccountManager.shared.oauthCompletionURL ?? ""
    }
    
    private var accessScopes: String {
        guard let scopes = UserAccountManager.shared.currentUserAccount?.accessScopes else {
            return ""
        }
        return scopes.joined(separator: " ")
    }
    
    private var clientId: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.clientId ?? ""
    }
    
    private var redirectUri: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.redirectUri ?? ""
    }
    
    private var refreshToken: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.refreshToken ?? ""
    }
    
    private var accessToken: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.accessToken ?? ""
    }
    
    private var tokenFormat: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.tokenFormat ?? ""
    }
    
    private var beaconChildConsumerKey: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.beaconChildConsumerKey ?? ""
    }
    
    private var instanceUrl: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.instanceUrl?.absoluteString ?? ""
    }
    
    private var organizationId: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.organizationId ?? ""
    }
    
    private var userId: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.userId ?? ""
    }
    
    private var username: String {
        return UserAccountManager.shared.currentUserAccount?.idData.username ?? ""
    }
    
    private var credentialsScopes: String {
        guard let scopes = UserAccountManager.shared.currentUserAccount?.credentials.scopes else {
            return ""
        }
        return scopes.joined(separator: " ")
    }
}

// MARK: - Helper Views

struct InfoRow: View {
    let label: String
    let value: String
    var isSensitive: Bool = false
    
    @State private var isRevealed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isSensitive && !isRevealed {
                HStack {
                    Text("••••••••")
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Button(action: { isRevealed.toggle() }) {
                        Image(systemName: "eye")
                            .foregroundColor(.blue)
                    }
                }
            } else {
                HStack {
                    Text(value.isEmpty ? "(empty)" : value)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(value.isEmpty ? .secondary : .primary)
                    Spacer()
                    if isSensitive {
                        Button(action: { isRevealed.toggle() }) {
                            Image(systemName: "eye.slash")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

class SessionDetailViewController: UIHostingController<SessionDetailView> {
    init() {
        super.init(rootView: SessionDetailView())
    }
    
    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
