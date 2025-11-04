/*
 UserCredentialsView.swift
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

struct UserCredentialsView: View {
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("User Credentials")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if isExpanded {
                InfoRowView(label: "Username:", value: username)
                InfoRowView(label: "Access Token:", value: accessToken, isSensitive: true)
                InfoRowView(label: "Token Format:", value: tokenFormat)
                InfoRowView(label: "Refresh Token:", value: refreshToken, isSensitive: true)
                InfoRowView(label: "Client ID:", value: clientId, isSensitive: true)
                InfoRowView(label: "Redirect URI:", value: redirectUri)
                InfoRowView(label: "Instance URL:", value: instanceUrl)
                InfoRowView(label: "Scopes:", value: credentialsScopes)
                InfoRowView(label: "Beacon Child Consumer Key:", value: beaconChildConsumerKey)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Computed Properties
    
    private var clientId: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.clientId ?? ""
    }
    
    private var redirectUri: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.redirectUri ?? ""
    }
    
    private var instanceUrl: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.instanceUrl?.absoluteString ?? ""
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
    
    private var tokenFormat: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.tokenFormat ?? ""
    }
    
    private var beaconChildConsumerKey: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.beaconChildConsumerKey ?? ""
    }
    
    private var accessToken: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.accessToken ?? ""
    }
    
    private var refreshToken: String {
        return UserAccountManager.shared.currentUserAccount?.credentials.refreshToken ?? ""
    }
    
}

