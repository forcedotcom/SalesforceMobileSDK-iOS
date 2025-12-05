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

// MARK: - Labels Constants
public struct CredentialsLabels {
    // Section titles
    public static let userIdentity = "User Identity"
    public static let oauthClientConfiguration = "OAuth Client Configuration"
    public static let tokens = "Tokens"
    public static let urls = "URLs"
    public static let community = "Community"
    public static let domainsAndSids = "Domains and SIDs"
    public static let cookiesAndSecurity = "Cookies and Security"
    public static let beacon = "Beacon"
    public static let other = "Other"
    
    // User Identity fields
    public static let username = "Username"
    public static let userIdLabel = "User ID"
    public static let organizationId = "Organization ID"
    
    // OAuth Client Configuration fields
    public static let clientId = "Client ID"
    public static let redirectUri = "Redirect URI"
    public static let protocolLabel = "Protocol"
    public static let domain = "Domain"
    public static let identifier = "Identifier"
    
    // Tokens fields
    public static let accessToken = "Access Token"
    public static let refreshToken = "Refresh Token"
    public static let tokenFormat = "Token Format"
    public static let jwt = "JWT"
    public static let authCode = "Auth Code"
    public static let challengeString = "Challenge String"
    public static let issuedAt = "Issued At"
    public static let scopes = "Scopes"
    
    // URLs fields
    public static let instanceUrl = "Instance URL"
    public static let apiInstanceUrl = "API Instance URL"
    public static let apiUrl = "API URL"
    public static let identityUrl = "Identity URL"
    
    // Community fields
    public static let communityId = "Community ID"
    public static let communityUrl = "Community URL"
    
    // Domains and SIDs fields
    public static let lightningDomain = "Lightning Domain"
    public static let lightningSid = "Lightning SID"
    public static let vfDomain = "VF Domain"
    public static let vfSid = "VF SID"
    public static let contentDomain = "Content Domain"
    public static let contentSid = "Content SID"
    public static let parentSid = "Parent SID"
    public static let sidCookieName = "SID Cookie Name"
    
    // Cookies and Security fields
    public static let csrfToken = "CSRF Token"
    public static let cookieClientSrc = "Cookie Client Src"
    public static let cookieSidClient = "Cookie SID Client"
    
    // Beacon fields
    public static let beaconChildConsumerKey = "Beacon Child Consumer Key"
    public static let beaconChildConsumerSecret = "Beacon Child Consumer Secret"
    
    // Other fields
    public static let additionalOAuthFields = "Additional OAuth Fields"
}

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
    
    // Export alert state
    @State private var showExportAlert = false
    @State private var exportedJSON = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
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
                Button(action: {
                    exportedJSON = generateCredentialsJSON()
                    showExportAlert = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .accessibilityIdentifier("exportCredentialsButton")
            }

            if isExpanded {
                VStack(spacing: 8) {
                    InfoSectionView(title: CredentialsLabels.userIdentity, isExpanded: $userIdentityExpanded) {
                        InfoRowView(label: "\(CredentialsLabels.username):", value: username)
                        InfoRowView(label: "\(CredentialsLabels.userIdLabel):", value: usernameId)
                        InfoRowView(label: "\(CredentialsLabels.organizationId):", value: organizationId)
                    }
                    
                    InfoSectionView(title: CredentialsLabels.oauthClientConfiguration, isExpanded: $oauthConfigExpanded) {
                        InfoRowView(label: "\(CredentialsLabels.clientId):", value: clientId, isSensitive: true)
                        InfoRowView(label: "\(CredentialsLabels.redirectUri):", value: redirectUri)
                        InfoRowView(label: "\(CredentialsLabels.protocolLabel):", value: authProtocol)
                        InfoRowView(label: "\(CredentialsLabels.domain):", value: domain)
                        InfoRowView(label: "\(CredentialsLabels.identifier):", value: identifier)
                    }
                    
                    InfoSectionView(title: CredentialsLabels.tokens, isExpanded: $tokensExpanded) {
                        InfoRowView(label: "\(CredentialsLabels.accessToken):", value: accessToken, isSensitive: true)
                        InfoRowView(label: "\(CredentialsLabels.refreshToken):", value: refreshToken, isSensitive: true)
                        InfoRowView(label: "\(CredentialsLabels.tokenFormat):", value: tokenFormat)
                        InfoRowView(label: "\(CredentialsLabels.jwt):", value: jwt, isSensitive: true)
                        InfoRowView(label: "\(CredentialsLabels.authCode):", value: authCode, isSensitive: true)
                        InfoRowView(label: "\(CredentialsLabels.challengeString):", value: challengeString, isSensitive: true)
                        InfoRowView(label: "\(CredentialsLabels.issuedAt):", value: issuedAt)
                        InfoRowView(label: "\(CredentialsLabels.scopes):", value: credentialsScopes)
                    }
                    
                    InfoSectionView(title: CredentialsLabels.urls, isExpanded: $urlsExpanded) {
                        InfoRowView(label: "\(CredentialsLabels.instanceUrl):", value: instanceUrl)
                        InfoRowView(label: "\(CredentialsLabels.apiInstanceUrl):", value: apiInstanceUrl)
                        InfoRowView(label: "\(CredentialsLabels.apiUrl):", value: apiUrl)
                        InfoRowView(label: "\(CredentialsLabels.identityUrl):", value: identityUrl)
                    }
                    
                    InfoSectionView(title: CredentialsLabels.community, isExpanded: $communityExpanded) {
                        InfoRowView(label: "\(CredentialsLabels.communityId):", value: communityId)
                        InfoRowView(label: "\(CredentialsLabels.communityUrl):", value: communityUrl)
                    }
                    
                    InfoSectionView(title: CredentialsLabels.domainsAndSids, isExpanded: $domainsAndSidsExpanded) {
                        InfoRowView(label: "\(CredentialsLabels.lightningDomain):", value: lightningDomain)
                        InfoRowView(label: "\(CredentialsLabels.lightningSid):", value: lightningSid, isSensitive: true)
                        InfoRowView(label: "\(CredentialsLabels.vfDomain):", value: vfDomain)
                        InfoRowView(label: "\(CredentialsLabels.vfSid):", value: vfSid, isSensitive: true)
                        InfoRowView(label: "\(CredentialsLabels.contentDomain):", value: contentDomain)
                        InfoRowView(label: "\(CredentialsLabels.contentSid):", value: contentSid, isSensitive: true)
                        InfoRowView(label: "\(CredentialsLabels.parentSid):", value: parentSid, isSensitive: true)
                        InfoRowView(label: "\(CredentialsLabels.sidCookieName):", value: sidCookieName)
                    }
                    
                    InfoSectionView(title: CredentialsLabels.cookiesAndSecurity, isExpanded: $cookiesAndSecurityExpanded) {
                        InfoRowView(label: "\(CredentialsLabels.csrfToken):", value: csrfToken, isSensitive: true)
                        InfoRowView(label: "\(CredentialsLabels.cookieClientSrc):", value: cookieClientSrc)
                        InfoRowView(label: "\(CredentialsLabels.cookieSidClient):", value: cookieSidClient, isSensitive: true)
                    }
                    
                    InfoSectionView(title: CredentialsLabels.beacon, isExpanded: $beaconExpanded) {
                        InfoRowView(label: "\(CredentialsLabels.beaconChildConsumerKey):", value: beaconChildConsumerKey)
                        InfoRowView(label: "\(CredentialsLabels.beaconChildConsumerSecret):", value: beaconChildConsumerSecret, isSensitive: true)
                    }
                    
                    InfoSectionView(title: CredentialsLabels.other, isExpanded: $otherExpanded) {
                        InfoRowView(label: "\(CredentialsLabels.additionalOAuthFields):", value: additionalOAuthFields)
                    }
                }
                .id(refreshTrigger)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .alert("Credentials JSON", isPresented: $showExportAlert) {
            Button("Copy to Clipboard") {
                UIPasteboard.general.string = exportedJSON
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportedJSON)
        }
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
    
    private func generateCredentialsJSON() -> String {
        var result: [String: [String: String]] = [:]
        
        // User Identity section
        result[CredentialsLabels.userIdentity] = [
            CredentialsLabels.username: username,
            CredentialsLabels.userIdLabel: usernameId,
            CredentialsLabels.organizationId: organizationId
        ]
        
        // OAuth Client Configuration section
        result[CredentialsLabels.oauthClientConfiguration] = [
            CredentialsLabels.clientId: clientId,
            CredentialsLabels.redirectUri: redirectUri,
            CredentialsLabels.protocolLabel: authProtocol,
            CredentialsLabels.domain: domain,
            CredentialsLabels.identifier: identifier
        ]
        
        // Tokens section
        result[CredentialsLabels.tokens] = [
            CredentialsLabels.accessToken: accessToken,
            CredentialsLabels.refreshToken: refreshToken,
            CredentialsLabels.tokenFormat: tokenFormat,
            CredentialsLabels.jwt: jwt,
            CredentialsLabels.authCode: authCode,
            CredentialsLabels.challengeString: challengeString,
            CredentialsLabels.issuedAt: issuedAt,
            CredentialsLabels.scopes: credentialsScopes
        ]
        
        // URLs section
        result[CredentialsLabels.urls] = [
            CredentialsLabels.instanceUrl: instanceUrl,
            CredentialsLabels.apiInstanceUrl: apiInstanceUrl,
            CredentialsLabels.apiUrl: apiUrl,
            CredentialsLabels.identityUrl: identityUrl
        ]
        
        // Community section
        result[CredentialsLabels.community] = [
            CredentialsLabels.communityId: communityId,
            CredentialsLabels.communityUrl: communityUrl
        ]
        
        // Domains and SIDs section
        result[CredentialsLabels.domainsAndSids] = [
            CredentialsLabels.lightningDomain: lightningDomain,
            CredentialsLabels.lightningSid: lightningSid,
            CredentialsLabels.vfDomain: vfDomain,
            CredentialsLabels.vfSid: vfSid,
            CredentialsLabels.contentDomain: contentDomain,
            CredentialsLabels.contentSid: contentSid,
            CredentialsLabels.parentSid: parentSid,
            CredentialsLabels.sidCookieName: sidCookieName
        ]
        
        // Cookies and Security section
        result[CredentialsLabels.cookiesAndSecurity] = [
            CredentialsLabels.csrfToken: csrfToken,
            CredentialsLabels.cookieClientSrc: cookieClientSrc,
            CredentialsLabels.cookieSidClient: cookieSidClient
        ]
        
        // Beacon section
        result[CredentialsLabels.beacon] = [
            CredentialsLabels.beaconChildConsumerKey: beaconChildConsumerKey,
            CredentialsLabels.beaconChildConsumerSecret: beaconChildConsumerSecret
        ]
        
        // Other section
        result[CredentialsLabels.other] = [
            CredentialsLabels.additionalOAuthFields: additionalOAuthFields
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
    
    // MARK: - Computed Properties
    
    private var credentials: OAuthCredentials? {
        return UserAccountManager.shared.currentUserAccount?.credentials
    }
    
    // User Identity
    private var username: String {
        return UserAccountManager.shared.currentUserAccount?.idData.username ?? ""
    }
    
    private var usernameId: String {
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

