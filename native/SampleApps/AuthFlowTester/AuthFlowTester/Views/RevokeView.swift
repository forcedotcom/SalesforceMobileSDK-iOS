/*
 RevokeView.swift
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

struct RevokeView: View {
    enum AlertType {
        case success
        case error(String)
    }
    
    @State private var isRevoking = false
    @State private var alertType: AlertType?
    
    let onRevokeCompleted: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                Task {
                    await revokeAccessToken()
                }
            }) {
                HStack {
                    if isRevoking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(isRevoking ? "Revoking..." : "Revoke Access Token")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isRevoking ? Color.gray : Color.red)
                .cornerRadius(8)
            }
            .disabled(isRevoking)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .alert(item: Binding(
            get: { alertType.map { AlertItem(type: $0) } },
            set: { alertType = $0?.type }
        )) { alertItem in
            switch alertItem.type {
            case .success:
                return Alert(
                    title: Text("Access Token Revoked"),
                    message: Text("The access token has been successfully revoked. You may need to make a REST API request to trigger a token refresh."),
                    dismissButton: .default(Text("OK"))
                )
            case .error(let message):
                return Alert(
                    title: Text("Revoke Failed"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    struct AlertItem: Identifiable {
        let id = UUID()
        let type: AlertType
    }
    
    // MARK: - Revoke Token
    
    @MainActor
    private func revokeAccessToken() async {
        guard let credentials = UserAccountManager.shared.currentUserAccount?.credentials else {
            alertType = .error("No credentials found")
            return
        }
        
        guard let accessToken = credentials.accessToken,
              let encodedToken = accessToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            alertType = .error("Invalid access token")
            return
        }
        
        isRevoking = true
        
        do {
            // Create POST request to revoke endpoint
            let request = RestRequest(method: .POST, path: "/services/oauth2/revoke", queryParams: nil)
            request.endpoint = ""
            
            // Set the request body with URL-encoded token
            let bodyString = "token=\(encodedToken)"
            request.setCustomRequestBodyString(bodyString, contentType: "application/x-www-form-urlencoded")
            
            // Send the request
            _ = try await RestClient.shared.send(request: request)
            
            alertType = .success
            
            // Notify parent to refresh fields
            onRevokeCompleted()
        } catch {
            alertType = .error(error.localizedDescription)
        }
        
        isRevoking = false
    }
}

