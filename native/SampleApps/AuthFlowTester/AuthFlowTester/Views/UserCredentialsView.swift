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
    let refreshTrigger: UUID
    
    // Section expansion states - all expand/collapse together with parent
    @State private var userIdentityExpanded = true
    @State private var oauthConfigExpanded = true
    @State private var tokensExpanded = true
    @State private var urlsExpanded = true
    @State private var communityExpanded = true
    @State private var domainsAndSidsExpanded = true
    @State private var cookiesAndSecurityExpanded = true
    @State private var beaconExpanded = true
    @State private var otherExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                    // Expand/collapse all subsections with the parent
                    expandAllSubsections(isExpanded)
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
                VStack(spacing: 8) {
                    InfoSectionView(title: "User Identity", isExpanded: $userIdentityExpanded) {
                        InfoRowView(label: "Username:", value: username)
                        InfoRowView(label: "User ID:", value: userId)
                        InfoRowView(label: "Organization ID:", value: organizationId)
                    }
                    
                    InfoSectionView(title: "OAuth Client Configuration", isExpanded: $oauthConfigExpanded) {
                        InfoRowView(label: "Client ID:", value: clientId, isSensitive: true)
                        InfoRowView(label: "Redirect URI:", value: redirectUri)
                        InfoRowView(label: "Protocol:", value: authProtocol)
                        InfoRowView(label: "Domain:", value: domain)
                        InfoRowView(label: "Identifier:", value: identifier)
                    }
                    
                    InfoSectionView(title: "Tokens", isExpanded: $tokensExpanded) {
                        InfoRowView(label: "Access Token:", value: accessToken, isSensitive: true)
                        InfoRowView(label: "Refresh Token:", value: refreshToken, isSensitive: true)
                        InfoRowView(label: "Token Format:", value: tokenFormat)
                        InfoRowView(label: "JWT:", value: jwt, isSensitive: true)
                        InfoRowView(label: "Auth Code:", value: authCode, isSensitive: true)
                        InfoRowView(label: "Challenge String:", value: challengeString, isSensitive: true)
                        InfoRowView(label: "Issued At:", value: issuedAt)
                        InfoRowView(label: "Scopes:", value: credentialsScopes)
                    }
                    
                    InfoSectionView(title: "URLs", isExpanded: $urlsExpanded) {
                        InfoRowView(label: "Instance URL:", value: instanceUrl)
                        InfoRowView(label: "API Instance URL:", value: apiInstanceUrl)
                        InfoRowView(label: "API URL:", value: apiUrl)
                        InfoRowView(label: "Identity URL:", value: identityUrl)
                    }
                    
                    InfoSectionView(title: "Community", isExpanded: $communityExpanded) {
                        InfoRowView(label: "Community ID:", value: communityId)
                        InfoRowView(label: "Community URL:", value: communityUrl)
                    }
                    
                    InfoSectionView(title: "Domains and SIDs", isExpanded: $domainsAndSidsExpanded) {
                        InfoRowView(label: "Lightning Domain:", value: lightningDomain)
                        InfoRowView(label: "Lightning SID:", value: lightningSid, isSensitive: true)
                        InfoRowView(label: "VF Domain:", value: vfDomain)
                        InfoRowView(label: "VF SID:", value: vfSid, isSensitive: true)
                        InfoRowView(label: "Content Domain:", value: contentDomain)
                        InfoRowView(label: "Content SID:", value: contentSid, isSensitive: true)
                        InfoRowView(label: "Parent SID:", value: parentSid, isSensitive: true)
                        InfoRowView(label: "SID Cookie Name:", value: sidCookieName)
                    }
                    
                    InfoSectionView(title: "Cookies and Security", isExpanded: $cookiesAndSecurityExpanded) {
                        InfoRowView(label: "CSRF Token:", value: csrfToken, isSensitive: true)
                        InfoRowView(label: "Cookie Client Src:", value: cookieClientSrc)
                        InfoRowView(label: "Cookie SID Client:", value: cookieSidClient, isSensitive: true)
                    }
                    
                    InfoSectionView(title: "Beacon", isExpanded: $beaconExpanded) {
                        InfoRowView(label: "Beacon Child Consumer Key:", value: beaconChildConsumerKey)
                        InfoRowView(label: "Beacon Child Consumer Secret:", value: beaconChildConsumerSecret, isSensitive: true)
                    }
                    
                    InfoSectionView(title: "Other", isExpanded: $otherExpanded) {
                        InfoRowView(label: "Additional OAuth Fields:", value: additionalOAuthFields)
                    }
                }
                .id(refreshTrigger)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    private func expandAllSubsections(_ expand: Bool) {
        userIdentityExpanded = expand
        oauthConfigExpanded = expand
        tokensExpanded = expand
        urlsExpanded = expand
        communityExpanded = expand
        domainsAndSidsExpanded = expand
        cookiesAndSecurityExpanded = expand
        beaconExpanded = expand
        otherExpanded = expand
    }
    
    // MARK: - Computed Properties
    
    private var credentials: OAuthCredentials? {
        return UserAccountManager.shared.currentUserAccount?.credentials
    }
    
    // User Identity
    private var username: String {
        return UserAccountManager.shared.currentUserAccount?.idData.username ?? ""
    }
    
    private var userId: String {
        return credentials?.userId ?? ""
    }
    
    private var organizationId: String {
        return credentials?.organizationId ?? ""
    }
    
    // OAuth Client Configuration
    private var clientId: String {
        return credentials?.clientId ?? ""
    }
    
    private var redirectUri: String {
        return credentials?.redirectUri ?? ""
    }
    
    private var authProtocol: String {
        return credentials?.protocol ?? ""
    }
    
    private var domain: String {
        return credentials?.domain ?? ""
    }
    
    private var identifier: String {
        return credentials?.identifier ?? ""
    }
    
    // Tokens
    private var accessToken: String {
        return credentials?.accessToken ?? ""
    }
    
    private var refreshToken: String {
        return credentials?.refreshToken ?? ""
    }
    
    private var tokenFormat: String {
        return credentials?.tokenFormat ?? ""
    }
    
    private var jwt: String {
        return credentials?.jwt ?? ""
    }
    
    private var authCode: String {
        return credentials?.authCode ?? ""
    }
    
    private var challengeString: String {
        return credentials?.challengeString ?? ""
    }
    
    private var issuedAt: String {
        guard let date = credentials?.issuedAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private var credentialsScopes: String {
        guard let scopes = credentials?.scopes else {
            return ""
        }
        return scopes.sorted().joined(separator: " ")
    }
    
    // URLs
    private var instanceUrl: String {
        return credentials?.instanceUrl?.absoluteString ?? ""
    }
    
    private var apiInstanceUrl: String {
        return credentials?.apiInstanceUrl?.absoluteString ?? ""
    }
    
    private var apiUrl: String {
        return credentials?.apiUrl?.absoluteString ?? ""
    }
    
    private var identityUrl: String {
        return credentials?.identityUrl?.absoluteString ?? ""
    }
    
    // Community
    private var communityId: String {
        return credentials?.communityId ?? ""
    }
    
    private var communityUrl: String {
        return credentials?.communityUrl?.absoluteString ?? ""
    }
    
    // Domains and SIDs
    private var lightningDomain: String {
        return credentials?.lightningDomain ?? ""
    }
    
    private var lightningSid: String {
        return credentials?.lightningSid ?? ""
    }
    
    private var vfDomain: String {
        return credentials?.vfDomain ?? ""
    }
    
    private var vfSid: String {
        return credentials?.vfSid ?? ""
    }
    
    private var contentDomain: String {
        return credentials?.contentDomain ?? ""
    }
    
    private var contentSid: String {
        return credentials?.contentSid ?? ""
    }
    
    private var parentSid: String {
        return credentials?.parentSid ?? ""
    }
    
    private var sidCookieName: String {
        return credentials?.sidCookieName ?? ""
    }
    
    // Cookies and Security
    private var csrfToken: String {
        return credentials?.csrfToken ?? ""
    }
    
    private var cookieClientSrc: String {
        return credentials?.cookieClientSrc ?? ""
    }
    
    private var cookieSidClient: String {
        return credentials?.cookieSidClient ?? ""
    }
    
    // Beacon
    private var beaconChildConsumerKey: String {
        return credentials?.beaconChildConsumerKey ?? ""
    }
    
    private var beaconChildConsumerSecret: String {
        return credentials?.beaconChildConsumerSecret ?? ""
    }
    
    // Other
    private var additionalOAuthFields: String {
        guard let fields = credentials?.additionalOAuthFields,
              let jsonData = try? JSONSerialization.data(withJSONObject: fields, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return ""
        }
        return jsonString
    }
    
}

