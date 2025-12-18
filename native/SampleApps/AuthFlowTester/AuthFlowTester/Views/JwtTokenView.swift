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

// MARK: - Labels Constants
public struct JwtTokenLabels {
    // Section titles
    public static let header = "Header"
    public static let payload = "Payload"
    
    // Header fields
    public static let algorithm = "Algorithm (alg)"
    public static let type = "Type (typ)"
    public static let keyId = "Key ID (kid)"
    public static let tokenType = "Token Type (tty)"
    public static let tenantKey = "Tenant Key (tnk)"
    public static let version = "Version (ver)"
    
    // Payload fields
    public static let audience = "Audience (aud)"
    public static let expirationDate = "Expiration Date (exp)"
    public static let issuer = "Issuer (iss)"
    public static let subject = "Subject (sub)"
    public static let scopes = "Scopes (scp)"
    public static let clientId = "Client ID (client_id)"
}

struct JwtTokenView: View {
    let jwtToken: JwtAccessToken
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
                        Text("JWT Access Token Details")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Button(action: {
                    exportedJSON = generateJwtJSON()
                    showExportAlert = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .accessibilityIdentifier("exportJwtTokenButton")
            }
            
            if isExpanded {
                // JWT Header
                Text("\(JwtTokenLabels.header):")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top, 4)
                
                JwtHeaderView(token: jwtToken)
                
                // JWT Payload
                Text("\(JwtTokenLabels.payload):")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top, 8)
                
                JwtPayloadView(token: jwtToken)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .alert("JWT Token JSON", isPresented: $showExportAlert) {
            Button("Copy to Clipboard") {
                UIPasteboard.general.string = exportedJSON
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportedJSON)
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateJwtJSON() -> String {
        var result: [String: [String: String]] = [:]
        
        // Header section
        var headerDict: [String: String] = [:]
        let header = jwtToken.header
        if let algorithm = header.algorithm {
            headerDict[JwtTokenLabels.algorithm] = algorithm
        }
        if let type = header.type {
            headerDict[JwtTokenLabels.type] = type
        }
        if let keyId = header.keyId {
            headerDict[JwtTokenLabels.keyId] = keyId
        }
        if let tokenType = header.tokenType {
            headerDict[JwtTokenLabels.tokenType] = tokenType
        }
        if let tenantKey = header.tenantKey {
            headerDict[JwtTokenLabels.tenantKey] = tenantKey
        }
        if let version = header.version {
            headerDict[JwtTokenLabels.version] = version
        }
        result[JwtTokenLabels.header] = headerDict
        
        // Payload section
        var payloadDict: [String: String] = [:]
        let payload = jwtToken.payload
        if let audience = payload.audience {
            payloadDict[JwtTokenLabels.audience] = audience.joined(separator: ", ")
        }
        if let expirationDate = jwtToken.expirationDate() {
            payloadDict[JwtTokenLabels.expirationDate] = formatDate(expirationDate)
        }
        if let issuer = payload.issuer {
            payloadDict[JwtTokenLabels.issuer] = issuer
        }
        if let subject = payload.subject {
            payloadDict[JwtTokenLabels.subject] = subject
        }
        if let scopes = payload.scopes {
            payloadDict[JwtTokenLabels.scopes] = scopes
        }
        if let clientId = payload.clientId {
            payloadDict[JwtTokenLabels.clientId] = clientId
        }
        result[JwtTokenLabels.payload] = payloadDict
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - JWT Header View

struct JwtHeaderView: View {
    let token: JwtAccessToken
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let header = token.header
            
            if let algorithm = header.algorithm {
                InfoRowView(label: "\(JwtTokenLabels.algorithm):", value: algorithm)
            }
            if let type = header.type {
                InfoRowView(label: "\(JwtTokenLabels.type):", value: type)
            }
            if let keyId = header.keyId {
                InfoRowView(label: "\(JwtTokenLabels.keyId):", value: keyId)
            }
            if let tokenType = header.tokenType {
                InfoRowView(label: "\(JwtTokenLabels.tokenType):", value: tokenType)
            }
            if let tenantKey = header.tenantKey {
                InfoRowView(label: "\(JwtTokenLabels.tenantKey):", value: tenantKey)
            }
            if let version = header.version {
                InfoRowView(label: "\(JwtTokenLabels.version):", value: version)
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
                InfoRowView(label: "\(JwtTokenLabels.audience):", value: audience.joined(separator: ", "))
            }
            
            if let expirationDate = token.expirationDate() {
                InfoRowView(label: "\(JwtTokenLabels.expirationDate):", value: formatDate(expirationDate))
            }
            
            if let issuer = payload.issuer {
                InfoRowView(label: "\(JwtTokenLabels.issuer):", value: issuer)
            }
            if let subject = payload.subject {
                InfoRowView(label: "\(JwtTokenLabels.subject):", value: subject)
            }
            if let scopes = payload.scopes {
                InfoRowView(label: "\(JwtTokenLabels.scopes):", value: scopes)
            }
            if let clientId = payload.clientId {
                InfoRowView(label: "\(JwtTokenLabels.clientId):", value: clientId, isSensitive: true)
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


