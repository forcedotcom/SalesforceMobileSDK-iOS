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
    
    func changeAppConfig(appConfig: AppConfig, scopesToRequest: String = "") {
        // Tap Change Key button to open the sheet
        tap(bottomBarChangeKeyButton())
        
        // Fill in the text fields
        setTextField(consumerKeyTextField(), value: appConfig.consumerKey)
        setTextField(callbackUrlTextField(), value: appConfig.redirectUri)
        setTextField(scopesTextField(), value: scopesToRequest)
        
        // Tap the migrate button
        tap(migrateRefreshTokenButton())
        
        // Tap the allow button if it appears
        tapIfPresent(allowButton())
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
    
    private func oauthConfigSection() -> XCUIElement {
        return app.buttons["OAuth Configuration"]
    }
    
    private func jwtDetailsSection() -> XCUIElement {
        return app.buttons["JWT Access Token Details"]
    }
    
    // BootConfigEditor fields (for Change Key sheet)
    private func consumerKeyTextField() -> XCUIElement {
        return app.textFields["consumerKeyTextField"]
    }
    
    private func callbackUrlTextField() -> XCUIElement {
        return app.textFields["callbackUrlTextField"]
    }
    
    private func scopesTextField() -> XCUIElement {
        return app.textFields["scopesTextField"]
    }
    
    private func migrateRefreshTokenButton() -> XCUIElement {
        return app.buttons["Migrate refresh token"]
    }
    
    private func newAppConfigurationSection() -> XCUIElement {
        return app.buttons["New App Configuration"]
    }
    
    // Refresh token migration
    private func allowButton() -> XCUIElement {
        return app.webViews.webViews.webViews.buttons[" Allow "]
    }
    
    // MARK: - Actions
    
    private func tap(_ element: XCUIElement) {
        _ = element.waitForExistence(timeout: timeout)
        element.tap()
    }
    
    private func tapIfPresent(_ element: XCUIElement) {
        if (element.waitForExistence(timeout: timeout)) {
            element.tap()
        }
    }
    
    private func setTextField(_ textField: XCUIElement, value: String) {
        _ = textField.waitForExistence(timeout: timeout)
        textField.tap()
        
        // Clear any existing text
        if let currentValue = textField.value as? String, !currentValue.isEmpty {
            textField.tap()
            let selectAll = app.menuItems["Select All"]
            if selectAll.waitForExistence(timeout: 1) {
                selectAll.tap()
                textField.typeText(XCUIKeyboardKey.delete.rawValue)
            }
        }
        
        textField.typeText(value)
    }
    
    // MARK: - Data Extraction Methods
    
    func getUserCredentials() -> UserCredentialsData {
        // Expand User Credentials (all subsections expand automatically)
        tap(userCredentialsSection())
        
        // Collect all static texts once
        let allLabels = collectAllStaticTextLabels()
        
        // Extract all data from the collected list - User Identity
        let username = extractFieldValue(from: allLabels, label: "Username:")
        let userId = extractFieldValue(from: allLabels, label: "User ID:")
        let organizationId = extractFieldValue(from: allLabels, label: "Organization ID:")
        
        // OAuth Client Configuration
        let clientId = extractFieldValue(from: allLabels, label: "Client ID:")
        let redirectUri = extractFieldValue(from: allLabels, label: "Redirect URI:")
        let authProtocol = extractFieldValue(from: allLabels, label: "Protocol:")
        let domain = extractFieldValue(from: allLabels, label: "Domain:")
        let identifier = extractFieldValue(from: allLabels, label: "Identifier:")
        
        // Tokens
        let accessToken = extractFieldValue(from: allLabels, label: "Access Token:")
        let refreshToken = extractFieldValue(from: allLabels, label: "Refresh Token:")
        let tokenFormat = extractFieldValue(from: allLabels, label: "Token Format:")
        let jwt = extractFieldValue(from: allLabels, label: "JWT:")
        let authCode = extractFieldValue(from: allLabels, label: "Auth Code:")
        let challengeString = extractFieldValue(from: allLabels, label: "Challenge String:")
        let issuedAt = extractFieldValue(from: allLabels, label: "Issued At:")
        let credentialsScopes = extractFieldValue(from: allLabels, label: "Scopes:")
        
        // URLs
        let instanceUrl = extractFieldValue(from: allLabels, label: "Instance URL:")
        let apiInstanceUrl = extractFieldValue(from: allLabels, label: "API Instance URL:")
        let apiUrl = extractFieldValue(from: allLabels, label: "API URL:")
        let identityUrl = extractFieldValue(from: allLabels, label: "Identity URL:")
        
        // Community
        let communityId = extractFieldValue(from: allLabels, label: "Community ID:")
        let communityUrl = extractFieldValue(from: allLabels, label: "Community URL:")
        
        // Domains and SIDs
        let lightningDomain = extractFieldValue(from: allLabels, label: "Lightning Domain:")
        let lightningSid = extractFieldValue(from: allLabels, label: "Lightning SID:")
        let vfDomain = extractFieldValue(from: allLabels, label: "VF Domain:")
        let vfSid = extractFieldValue(from: allLabels, label: "VF SID:")
        let contentDomain = extractFieldValue(from: allLabels, label: "Content Domain:")
        let contentSid = extractFieldValue(from: allLabels, label: "Content SID:")
        let parentSid = extractFieldValue(from: allLabels, label: "Parent SID:")
        let sidCookieName = extractFieldValue(from: allLabels, label: "SID Cookie Name:")
        
        // Cookies and Security
        let csrfToken = extractFieldValue(from: allLabels, label: "CSRF Token:")
        let cookieClientSrc = extractFieldValue(from: allLabels, label: "Cookie Client Src:")
        let cookieSidClient = extractFieldValue(from: allLabels, label: "Cookie SID Client:")
        
        // Beacon
        let beaconChildConsumerKey = extractFieldValue(from: allLabels, label: "Beacon Child Consumer Key:")
        let beaconChildConsumerSecret = extractFieldValue(from: allLabels, label: "Beacon Child Consumer Secret:")
        
        // Other
        let additionalOAuthFields = extractFieldValue(from: allLabels, label: "Additional OAuth Fields:")
        
        // Collapse User Credentials
        tap(userCredentialsSection())
        
        return UserCredentialsData(
            username: username,
            userId: userId,
            organizationId: organizationId,
            clientId: clientId,
            redirectUri: redirectUri,
            authProtocol: authProtocol,
            domain: domain,
            identifier: identifier,
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenFormat: tokenFormat,
            jwt: jwt,
            authCode: authCode,
            challengeString: challengeString,
            issuedAt: issuedAt,
            credentialsScopes: credentialsScopes,
            instanceUrl: instanceUrl,
            apiInstanceUrl: apiInstanceUrl,
            apiUrl: apiUrl,
            identityUrl: identityUrl,
            communityId: communityId,
            communityUrl: communityUrl,
            lightningDomain: lightningDomain,
            lightningSid: lightningSid,
            vfDomain: vfDomain,
            vfSid: vfSid,
            contentDomain: contentDomain,
            contentSid: contentSid,
            parentSid: parentSid,
            sidCookieName: sidCookieName,
            csrfToken: csrfToken,
            cookieClientSrc: cookieClientSrc,
            cookieSidClient: cookieSidClient,
            beaconChildConsumerKey: beaconChildConsumerKey,
            beaconChildConsumerSecret: beaconChildConsumerSecret,
            additionalOAuthFields: additionalOAuthFields
        )
    }
    
    func getOAuthConfiguration() -> OAuthConfigurationData {
        // Expand OAuth Configuration if not already expanded
        tap(oauthConfigSection())
        
        // Collect all static texts once
        let allLabels = collectAllStaticTextLabels()
        
        // Extract values - note that consumer key label may have "(default)" suffix
        var consumerKey = extractFieldValue(from: allLabels, label: "Configured Consumer Key:")
        if consumerKey.isEmpty {
            consumerKey = extractFieldValue(from: allLabels, label: "Configured Consumer Key: (default)")
        }
        let callbackUrl = extractFieldValue(from: allLabels, label: "Configured Callback URL:")
        let scopes = extractFieldValue(from: allLabels, label: "Configured Scopes:")
        
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
        
        // Collect all static texts once
        let allLabels = collectAllStaticTextLabels()
        
        // Extract header values
        let algorithm = extractFieldValue(from: allLabels, label: "Algorithm (alg):")
        let type = extractFieldValue(from: allLabels, label: "Type (typ):")
        let keyId = extractFieldValue(from: allLabels, label: "Key ID (kid):")
        let tokenType = extractFieldValue(from: allLabels, label: "Token Type (tty):")
        let tenantKey = extractFieldValue(from: allLabels, label: "Tenant Key (tnk):")
        let version = extractFieldValue(from: allLabels, label: "Version (ver):")
        
        // Extract payload values
        let audience = extractFieldValue(from: allLabels, label: "Audience (aud):")
        let expirationDate = extractFieldValue(from: allLabels, label: "Expiration Date (exp):")
        let issuer = extractFieldValue(from: allLabels, label: "Issuer (iss):")
        let subject = extractFieldValue(from: allLabels, label: "Subject (sub):")
        let scopes = extractFieldValue(from: allLabels, label: "Scopes (scp):")
        let clientId = extractFieldValue(from: allLabels, label: "Client ID (client_id):")
        
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
    
    /// Collects all static text labels from the current screen once
    private func collectAllStaticTextLabels() -> [String] {
        // Wait a moment for UI to settle
        sleep(1)
        
        // Get all static texts from the app
        let allStaticTexts = app.staticTexts.allElementsBoundByIndex
        
        // Extract all labels into an array
        var labels: [String] = []
        for element in allStaticTexts {
            let label = element.label
            if !label.isEmpty {
                labels.append(label)
            }
        }
        
        return labels
    }
    
    /// Extracts a field value from a list of labels by finding the value after the given label
    private func extractFieldValue(from labels: [String], label: String) -> String {
        // Find the index of the label
        guard let labelIndex = labels.firstIndex(of: label) else {
            return ""
        }
        
        // The value should be the next element after the label
        let valueIndex = labelIndex + 1
        guard valueIndex < labels.count else {
            return ""
        }
        
        let value = labels[valueIndex]
        
        // Skip if the next element is another label (ends with colon) or a section title
        // This handles cases where a field is empty and the next label immediately follows
        if value.hasSuffix(":") || value == label {
            return ""
        }
        
        return value
    }
    
    // MARK: - Other
    
    private func hasStaticText(_ text: String) -> Bool {
        let staticText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '\(text)'"))
        return staticText.firstMatch.waitForExistence(timeout: timeout)
    }
}

