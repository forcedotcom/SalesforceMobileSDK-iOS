/*
 JwtTokenView.swift
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

struct JwtTokenView: View {
    let jwtToken: JwtAccessToken
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("JWT Access Token Details")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                // JWT Header
                Text("Header:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top, 4)
                
                JwtHeaderView(token: jwtToken)
                
                // JWT Payload
                Text("Payload:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top, 8)
                
                JwtPayloadView(token: jwtToken)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - JWT Header View

struct JwtHeaderView: View {
    let token: JwtAccessToken
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let header = token.header
            
            if let algorithm = header.algorithm {
                InfoRowView(label: "Algorithm (alg):", value: algorithm)
            }
            if let type = header.type {
                InfoRowView(label: "Type (typ):", value: type)
            }
            if let keyId = header.keyId {
                InfoRowView(label: "Key ID (kid):", value: keyId)
            }
            if let tokenType = header.tokenType {
                InfoRowView(label: "Token Type (tty):", value: tokenType)
            }
            if let tenantKey = header.tenantKey {
                InfoRowView(label: "Tenant Key (tnk):", value: tenantKey)
            }
            if let version = header.version {
                InfoRowView(label: "Version (ver):", value: version)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(4)
    }
}

// MARK: - JWT Payload View

struct JwtPayloadView: View {
    let token: JwtAccessToken
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let payload = token.payload
            
            if let audience = payload.audience {
                InfoRowView(label: "Audience (aud):", value: audience.joined(separator: ", "))
            }
            
            if let expirationDate = token.expirationDate() {
                InfoRowView(label: "Expiration Date (exp):", value: formatDate(expirationDate))
            }
            
            if let issuer = payload.issuer {
                InfoRowView(label: "Issuer (iss):", value: issuer)
            }
            if let subject = payload.subject {
                InfoRowView(label: "Subject (sub):", value: subject)
            }
            if let scopes = payload.scopes {
                InfoRowView(label: "Scopes (scp):", value: scopes)
            }
            if let clientId = payload.clientId {
                InfoRowView(label: "Client ID (client_id):", value: clientId, isSensitive: true)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}


