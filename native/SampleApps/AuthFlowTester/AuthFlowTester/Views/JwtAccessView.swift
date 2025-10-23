/*
 JwtAccessView.swift
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

struct JwtAccessView: View {
    let jwtToken: JwtAccessToken
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            Text("JWT Access Token Details")
                .font(.headline)
                .padding(.top, 8)
            
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
}

// MARK: - JWT Header View

struct JwtHeaderView: View {
    let token: JwtAccessToken
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let header = token.header
            
            JwtFieldRow(label: "Algorithm (alg):", value: header.algorithm)
            JwtFieldRow(label: "Type (typ):", value: header.type)
            JwtFieldRow(label: "Key ID (kid):", value: header.keyId)
            JwtFieldRow(label: "Token Type (tty):", value: header.tokenType)
            JwtFieldRow(label: "Tenant Key (tnk):", value: header.tenantKey)
            JwtFieldRow(label: "Version (ver):", value: header.version)
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
                JwtFieldRow(label: "Audience (aud):", value: audience.joined(separator: ", "))
            }
            
            if let expirationDate = token.expirationDate() {
                JwtFieldRow(label: "Expiration Date (exp):", value: formatDate(expirationDate))
            }
            
            JwtFieldRow(label: "Issuer (iss):", value: payload.issuer)
            JwtFieldRow(label: "Subject (sub):", value: payload.subject)
            JwtFieldRow(label: "Scopes (scp):", value: payload.scopes)
            JwtFieldRow(label: "Client ID (client_id):", value: payload.clientId)
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

// MARK: - Helper Views

struct JwtFieldRow: View {
    let label: String
    let value: String?
    
    var body: some View {
        if let value = value, !value.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
            }
        }
    }
}

