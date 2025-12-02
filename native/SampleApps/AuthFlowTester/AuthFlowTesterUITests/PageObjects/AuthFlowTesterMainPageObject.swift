/*
 AuthFlowTesterMainPageObject.swift
 AuthFlowTesterUITests
 
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

import Foundation
import XCTest

// MARK: - Data Structures

struct UserCredentialsData {
    // User Identity
    var username: String
    var userId: String
    var organizationId: String
    
    // OAuth Client Configuration
    var clientId: String
    var redirectUri: String
    var authProtocol: String
    var domain: String
    var identifier: String
    
    // Tokens
    var accessToken: String
    var refreshToken: String
    var tokenFormat: String
    var jwt: String
    var authCode: String
    var challengeString: String
    var issuedAt: String
    var credentialsScopes: String
    
    // URLs
    var instanceUrl: String
    var apiInstanceUrl: String
    var apiUrl: String
    var identityUrl: String
    
    // Community
    var communityId: String
    var communityUrl: String
    
    // Domains and SIDs
    var lightningDomain: String
    var lightningSid: String
    var vfDomain: String
    var vfSid: String
    var contentDomain: String
    var contentSid: String
    var parentSid: String
    var sidCookieName: String
    
    // Cookies and Security
    var csrfToken: String
    var cookieClientSrc: String
    var cookieSidClient: String
    
    // Beacon
    var beaconChildConsumerKey: String
    var beaconChildConsumerSecret: String
    
    // Other
    var additionalOAuthFields: String
}

struct OAuthConfigurationData {
    var configuredConsumerKey: String
    var configuredCallbackUrl: String
    var configuredScopes: String
}

struct JwtDetailsData {
    // Header
    var algorithm: String
    var type: String
    var keyId: String
    var tokenType: String
    var tenantKey: String
    var version: String
    
    // Payload
    var audience: String
    var expirationDate: String
    var issuer: String
    var subject: String
    var scopes: String
    var clientId: String
}

class AuthFlowTesterMainPageObject {
    let app: XCUIApplication
    let timeout: double_t = 5
    
    init(testApp: XCUIApplication) {
        app = testApp
    }
    
    func isShowing() -> Bool {
        return navigationTitle().waitForExistence(timeout: timeout)
    }
    
    func performLogout() {
        tap(bottomBarLogoutButton())
        tap(alertLogoutButton())
    }
    
    func makeRestRequest() -> Bool {
        tap(makeRestRequestButton())
        let alert = app.alerts["Request Successful"]
        if (alert.waitForExistence(timeout: timeout)) {
            alert.buttons["OK"].tap()
            return true
        }
        return false
    }
    
    func revokeAccessToken() -> Bool {
        tap(revokeButton())
        let alert = app.alerts["Access Token Revoked"]
        if (alert.waitForExistence(timeout: timeout)) {
            alert.buttons["OK"].tap()
            return true
        }
        return false
    }
    
    // MARK: - UI Element Accessors
    
    private func navigationTitle() -> XCUIElement {
        return app.navigationBars["AuthFlowTester"]
    }
    
    private func revokeButton() -> XCUIElement {
        return app.buttons["Revoke Access Token"]
    }
    
    private func makeRestRequestButton() -> XCUIElement {
        return app.buttons["Make REST API Request"]
    }
    
    private func bottomBarChangeKeyButton() -> XCUIElement {
        return app.buttons["Change Key"]
    }
    
    private func bottomBarSwitchUserButton() -> XCUIElement {
        return app.buttons["Switch User"]
    }
    
    private func bottomBarLogoutButton() -> XCUIElement {
        return app.buttons["Logout"]
    }
    
    private func alertLogoutButton() -> XCUIElement {
        return app.alerts["Logout"].buttons["Logout"]
    }
    
    private func userCredentialsSection() -> XCUIElement {
        return app.buttons["User Credentials"]
    }
    
    private func userIdentitySection() -> XCUIElement {
        return app.buttons["User Identity"]
    }
    
    private func oauthConfigSection() -> XCUIElement {
        return app.buttons["OAuth Configuration"]
    }
    
    private func jwtDetailsSection() -> XCUIElement {
        return app.buttons["JWT Access Token Details"]
    }
    
    // UserCredentialsView subsections
    private func oauthClientConfigSection() -> XCUIElement {
        return app.buttons["OAuth Client Configuration"]
    }
    
    private func tokensSection() -> XCUIElement {
        return app.buttons["Tokens"]
    }
    
    private func urlsSection() -> XCUIElement {
        return app.buttons["URLs"]
    }
    
    private func communitySection() -> XCUIElement {
        return app.buttons["Community"]
    }
    
    private func domainsAndSidsSection() -> XCUIElement {
        return app.buttons["Domains and SIDs"]
    }
    
    private func cookiesAndSecuritySection() -> XCUIElement {
        return app.buttons["Cookies and Security"]
    }
    
    private func beaconSection() -> XCUIElement {
        return app.buttons["Beacon"]
    }
    
    private func otherSection() -> XCUIElement {
        return app.buttons["Other"]
    }
    
    // MARK: - Actions
    
    private func tap(_ element: XCUIElement) {
        _ = element.waitForExistence(timeout: timeout)
        element.tap()
    }
    
    // MARK: - Data Extraction Methods
    
    func getUserCredentials() -> UserCredentialsData {
        // Expand User Credentials if not already expanded
        tap(userCredentialsSection())
        
        // Extract data from each section
        let userIdentity = extractUserIdentityData()
        let oauthClientConfig = extractOAuthClientConfigData()
        let tokens = extractTokensData()
        let urls = extractURLsData()
        let community = extractCommunityData()
        let domainsAndSids = extractDomainsAndSidsData()
        let cookiesAndSecurity = extractCookiesAndSecurityData()
        let beacon = extractBeaconData()
        let other = extractOtherData()
        
        // Collapse User Credentials
        tap(userCredentialsSection())
        
        return UserCredentialsData(
            // User Identity
            username: userIdentity.0,
            userId: userIdentity.1,
            organizationId: userIdentity.2,
            // OAuth Client Configuration
            clientId: oauthClientConfig.0,
            redirectUri: oauthClientConfig.1,
            authProtocol: oauthClientConfig.2,
            domain: oauthClientConfig.3,
            identifier: oauthClientConfig.4,
            // Tokens
            accessToken: tokens.0,
            refreshToken: tokens.1,
            tokenFormat: tokens.2,
            jwt: tokens.3,
            authCode: tokens.4,
            challengeString: tokens.5,
            issuedAt: tokens.6,
            credentialsScopes: tokens.7,
            // URLs
            instanceUrl: urls.0,
            apiInstanceUrl: urls.1,
            apiUrl: urls.2,
            identityUrl: urls.3,
            // Community
            communityId: community.0,
            communityUrl: community.1,
            // Domains and SIDs
            lightningDomain: domainsAndSids.0,
            lightningSid: domainsAndSids.1,
            vfDomain: domainsAndSids.2,
            vfSid: domainsAndSids.3,
            contentDomain: domainsAndSids.4,
            contentSid: domainsAndSids.5,
            parentSid: domainsAndSids.6,
            sidCookieName: domainsAndSids.7,
            // Cookies and Security
            csrfToken: cookiesAndSecurity.0,
            cookieClientSrc: cookiesAndSecurity.1,
            cookieSidClient: cookiesAndSecurity.2,
            // Beacon
            beaconChildConsumerKey: beacon.0,
            beaconChildConsumerSecret: beacon.1,
            // Other
            additionalOAuthFields: other
        )
    }
    
    func getOAuthConfiguration() -> OAuthConfigurationData {
        // Expand OAuth Configuration if not already expanded
        tap(oauthConfigSection())
        
        // Extract values - note that consumer key label may have "(default)" suffix
        let consumerKey = extractFieldValue(label: "Configured Consumer Key:")
        let callbackUrl = extractFieldValue(label: "Configured Callback URL:")
        let scopes = extractFieldValue(label: "Configured Scopes:")
        
        // Collapse OAuth Configuration
        tap(oauthConfigSection())
        
        return OAuthConfigurationData(
            configuredConsumerKey: consumerKey,
            configuredCallbackUrl: callbackUrl,
            configuredScopes: scopes
        )
    }
    
    func getJwtDetails() -> JwtDetailsData? {
        // Check if JWT section exists
        let jwtSection = jwtDetailsSection()
        guard jwtSection.waitForExistence(timeout: 1) else {
            return nil
        }
        
        // Expand JWT Details if not already expanded
        tap(jwtSection)
        
        // Extract header values
        let algorithm = extractFieldValue(label: "Algorithm (alg):")
        let type = extractFieldValue(label: "Type (typ):")
        let keyId = extractFieldValue(label: "Key ID (kid):")
        let tokenType = extractFieldValue(label: "Token Type (tty):")
        let tenantKey = extractFieldValue(label: "Tenant Key (tnk):")
        let version = extractFieldValue(label: "Version (ver):")
        
        // Extract payload values
        let audience = extractFieldValue(label: "Audience (aud):")
        let expirationDate = extractFieldValue(label: "Expiration Date (exp):")
        let issuer = extractFieldValue(label: "Issuer (iss):")
        let subject = extractFieldValue(label: "Subject (sub):")
        let scopes = extractFieldValue(label: "Scopes (scp):")
        let clientId = extractFieldValue(label: "Client ID (client_id):")
        
        // Collapse JWT Details
        tap(jwtSection)
        
        return JwtDetailsData(
            algorithm: algorithm,
            type: type,
            keyId: keyId,
            tokenType: tokenType,
            tenantKey: tenantKey,
            version: version,
            audience: audience,
            expirationDate: expirationDate,
            issuer: issuer,
            subject: subject,
            scopes: scopes,
            clientId: clientId
        )
    }
    
    // MARK: - Private Helper Methods for Data Extraction
    
    private func extractUserIdentityData() -> (String, String, String) {
        tap(userIdentitySection())
        let username = extractFieldValue(label: "Username:")
        let userId = extractFieldValue(label: "User ID:")
        let organizationId = extractFieldValue(label: "Organization ID:")
        tap(userIdentitySection())
        return (username, userId, organizationId)
    }
    
    private func extractOAuthClientConfigData() -> (String, String, String, String, String) {
        tap(oauthClientConfigSection())
        let clientId = extractFieldValue(label: "Client ID:")
        let redirectUri = extractFieldValue(label: "Redirect URI:")
        let authProtocol = extractFieldValue(label: "Protocol:")
        let domain = extractFieldValue(label: "Domain:")
        let identifier = extractFieldValue(label: "Identifier:")
        tap(oauthClientConfigSection())
        return (clientId, redirectUri, authProtocol, domain, identifier)
    }
    
    private func extractTokensData() -> (String, String, String, String, String, String, String, String) {
        tap(tokensSection())
        let accessToken = extractFieldValue(label: "Access Token:")
        let refreshToken = extractFieldValue(label: "Refresh Token:")
        let tokenFormat = extractFieldValue(label: "Token Format:")
        let jwt = extractFieldValue(label: "JWT:")
        let authCode = extractFieldValue(label: "Auth Code:")
        let challengeString = extractFieldValue(label: "Challenge String:")
        let issuedAt = extractFieldValue(label: "Issued At:")
        let scopes = extractFieldValue(label: "Scopes:")
        tap(tokensSection())
        return (accessToken, refreshToken, tokenFormat, jwt, authCode, challengeString, issuedAt, scopes)
    }
    
    private func extractURLsData() -> (String, String, String, String) {
        tap(urlsSection())
        let instanceUrl = extractFieldValue(label: "Instance URL:")
        let apiInstanceUrl = extractFieldValue(label: "API Instance URL:")
        let apiUrl = extractFieldValue(label: "API URL:")
        let identityUrl = extractFieldValue(label: "Identity URL:")
        tap(urlsSection())
        return (instanceUrl, apiInstanceUrl, apiUrl, identityUrl)
    }
    
    private func extractCommunityData() -> (String, String) {
        tap(communitySection())
        let communityId = extractFieldValue(label: "Community ID:")
        let communityUrl = extractFieldValue(label: "Community URL:")
        tap(communitySection())
        return (communityId, communityUrl)
    }
    
    private func extractDomainsAndSidsData() -> (String, String, String, String, String, String, String, String) {
        tap(domainsAndSidsSection())
        let lightningDomain = extractFieldValue(label: "Lightning Domain:")
        let lightningSid = extractFieldValue(label: "Lightning SID:")
        let vfDomain = extractFieldValue(label: "VF Domain:")
        let vfSid = extractFieldValue(label: "VF SID:")
        let contentDomain = extractFieldValue(label: "Content Domain:")
        let contentSid = extractFieldValue(label: "Content SID:")
        let parentSid = extractFieldValue(label: "Parent SID:")
        let sidCookieName = extractFieldValue(label: "SID Cookie Name:")
        tap(domainsAndSidsSection())
        return (lightningDomain, lightningSid, vfDomain, vfSid, contentDomain, contentSid, parentSid, sidCookieName)
    }
    
    private func extractCookiesAndSecurityData() -> (String, String, String) {
        tap(cookiesAndSecuritySection())
        let csrfToken = extractFieldValue(label: "CSRF Token:")
        let cookieClientSrc = extractFieldValue(label: "Cookie Client Src:")
        let cookieSidClient = extractFieldValue(label: "Cookie SID Client:")
        tap(cookiesAndSecuritySection())
        return (csrfToken, cookieClientSrc, cookieSidClient)
    }
    
    private func extractBeaconData() -> (String, String) {
        tap(beaconSection())
        let beaconChildConsumerKey = extractFieldValue(label: "Beacon Child Consumer Key:")
        let beaconChildConsumerSecret = extractFieldValue(label: "Beacon Child Consumer Secret:")
        tap(beaconSection())
        return (beaconChildConsumerKey, beaconChildConsumerSecret)
    }
    
    private func extractOtherData() -> String {
        tap(otherSection())
        let additionalOAuthFields = extractFieldValue(label: "Additional OAuth Fields:")
        tap(otherSection())
        return (additionalOAuthFields)
    }
    
    private func extractFieldValue(label: String) -> String {
        // InfoRowView uses accessibility identifier "\(label)_row"
        let rowIdentifier = "\(label)_row"
        let row = app.otherElements[rowIdentifier]
        
        // Wait for the row to exist
        guard row.waitForExistence(timeout: timeout) else {
            return ""
        }
        
        // Get all static texts in the row
        let staticTexts = row.staticTexts.allElementsBoundByIndex
        
        // The first text is the label, the second is the value
        // Skip the label and get the value text
        for text in staticTexts {
            let textLabel = text.label
            // Skip if it's the label itself
            if textLabel == label || textLabel.isEmpty {
                continue
            }
            // Return the value (could be actual value, masked value, or "(empty)")
            return textLabel
        }
        
        return ""
    }
    
    // MARK: - Other
    
    private func hasStaticText(_ text: String) -> Bool {
        let staticText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '\(text)'"))
        return staticText.firstMatch.waitForExistence(timeout: timeout)
    }
}

