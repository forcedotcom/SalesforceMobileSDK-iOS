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

// MARK: - Label Constants (mirroring the app's Labels structs for JSON parsing)

struct CredentialsLabels {
    // Section titles
    static let userIdentity = "User Identity"
    static let oauthClientConfiguration = "OAuth Client Configuration"
    static let tokens = "Tokens"
    static let urls = "URLs"
    static let community = "Community"
    static let domainsAndSids = "Domains and SIDs"
    static let cookiesAndSecurity = "Cookies and Security"
    static let beacon = "Beacon"
    static let other = "Other"
    
    // User Identity fields
    static let username = "Username"
    static let userIdLabel = "User ID"
    static let organizationId = "Organization ID"
    
    // OAuth Client Configuration fields
    static let clientId = "Client ID"
    static let redirectUri = "Redirect URI"
    static let protocolLabel = "Protocol"
    static let domain = "Domain"
    static let identifier = "Identifier"
    
    // Tokens fields
    static let accessToken = "Access Token"
    static let refreshToken = "Refresh Token"
    static let tokenFormat = "Token Format"
    static let jwt = "JWT"
    static let authCode = "Auth Code"
    static let challengeString = "Challenge String"
    static let issuedAt = "Issued At"
    static let scopes = "Scopes"
    
    // URLs fields
    static let instanceUrl = "Instance URL"
    static let apiInstanceUrl = "API Instance URL"
    static let apiUrl = "API URL"
    static let identityUrl = "Identity URL"
    
    // Community fields
    static let communityId = "Community ID"
    static let communityUrl = "Community URL"
    
    // Domains and SIDs fields
    static let lightningDomain = "Lightning Domain"
    static let lightningSid = "Lightning SID"
    static let vfDomain = "VF Domain"
    static let vfSid = "VF SID"
    static let contentDomain = "Content Domain"
    static let contentSid = "Content SID"
    static let parentSid = "Parent SID"
    static let sidCookieName = "SID Cookie Name"
    
    // Cookies and Security fields
    static let csrfToken = "CSRF Token"
    static let cookieClientSrc = "Cookie Client Src"
    static let cookieSidClient = "Cookie SID Client"
    
    // Beacon fields
    static let beaconChildConsumerKey = "Beacon Child Consumer Key"
    static let beaconChildConsumerSecret = "Beacon Child Consumer Secret"
    
    // Other fields
    static let additionalOAuthFields = "Additional OAuth Fields"
}

struct OAuthConfigLabels {
    static let consumerKey = "Configured Consumer Key"
    static let callbackUrl = "Configured Callback URL"
    static let scopes = "Configured Scopes"
}

struct JwtTokenLabels {
    // Section titles
    static let header = "Header"
    static let payload = "Payload"
    
    // Header fields
    static let algorithm = "Algorithm (alg)"
    static let type = "Type (typ)"
    static let keyId = "Key ID (kid)"
    static let tokenType = "Token Type (tty)"
    static let tenantKey = "Tenant Key (tnk)"
    static let version = "Version (ver)"
    
    // Payload fields
    static let audience = "Audience (aud)"
    static let expirationDate = "Expiration Date (exp)"
    static let issuer = "Issuer (iss)"
    static let subject = "Subject (sub)"
    static let scopes = "Scopes (scp)"
    static let clientId = "Client ID (client_id)"
}

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

/// Page object for interacting with the AuthFlowTester main screen during UI tests.
/// Provides methods to perform actions (revoke access token, make REST requests, change consumer key, change users, logout).
/// and extract data (user credentials, OAuth configuration, JWT details) from the UI.
class AuthFlowTesterMainPageObject {
    let app: XCUIApplication
    let timeout: double_t = 3
    
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
    
    func performAddUser() {
        // Tap Switch User button to open the user management screen
        tap(bottomBarSwitchUserButton())
        
        // Tap "New User" button in the user list navigation bar
        tap(newUserButton())
    }
    
    func switchToUser(username: String) {
        // Tap Switch User button to open the user management screen
        tap(bottomBarSwitchUserButton())
        
        // Tap the row containing the username
        tap(userRow(username: username))
        
        // Tap "Switch to User" button
        tap(swithToUserButton())
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
    
    // Export buttons
    
    private func exportCredentialsButton() -> XCUIElement {
        return app.buttons["exportCredentialsButton"].firstMatch
    }
    
    private func exportOAuthConfigButton() -> XCUIElement {
        return app.buttons["exportOAuthConfigButton"].firstMatch
    }
    
    private func exportJwtTokenButton() -> XCUIElement {
        return app.buttons["exportJwtTokenButton"].firstMatch
    }
    
    // Refresh token migration
    
    private func newAppConfigurationSection() -> XCUIElement {
        return app.buttons["New App Configuration"]
    }

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
    
    private func allowButton() -> XCUIElement {
        let buttons = app.webViews.webViews.webViews.buttons
        let predicate = NSPredicate(format: "label CONTAINS[c] 'Allow'")
        return buttons.matching(predicate).firstMatch
    }
    
    // User switching
    
    private func newUserButton() -> XCUIElement {
        return app.navigationBars["User List"].buttons["New User"]
    }
    
    private func userRow(username: String) -> XCUIElement {
        return app.staticTexts[username]
    }
    
    private func swithToUserButton() -> XCUIElement {
        return app.buttons["Switch to User"]
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
        // Tap export button and get JSON
        let json = tapExportAndGetJSON(exportCredentialsButton(), alertTitle: "Credentials JSON")
        
        // Parse JSON sections
        let userIdentity = json[CredentialsLabels.userIdentity] as? [String: String] ?? [:]
        let oauthConfig = json[CredentialsLabels.oauthClientConfiguration] as? [String: String] ?? [:]
        let tokens = json[CredentialsLabels.tokens] as? [String: String] ?? [:]
        let urls = json[CredentialsLabels.urls] as? [String: String] ?? [:]
        let community = json[CredentialsLabels.community] as? [String: String] ?? [:]
        let domainsAndSids = json[CredentialsLabels.domainsAndSids] as? [String: String] ?? [:]
        let cookiesAndSecurity = json[CredentialsLabels.cookiesAndSecurity] as? [String: String] ?? [:]
        let beacon = json[CredentialsLabels.beacon] as? [String: String] ?? [:]
        let other = json[CredentialsLabels.other] as? [String: String] ?? [:]
        
        return UserCredentialsData(
            username: userIdentity[CredentialsLabels.username] ?? "",
            userId: userIdentity[CredentialsLabels.userIdLabel] ?? "",
            organizationId: userIdentity[CredentialsLabels.organizationId] ?? "",
            clientId: oauthConfig[CredentialsLabels.clientId] ?? "",
            redirectUri: oauthConfig[CredentialsLabels.redirectUri] ?? "",
            authProtocol: oauthConfig[CredentialsLabels.protocolLabel] ?? "",
            domain: oauthConfig[CredentialsLabels.domain] ?? "",
            identifier: oauthConfig[CredentialsLabels.identifier] ?? "",
            accessToken: tokens[CredentialsLabels.accessToken] ?? "",
            refreshToken: tokens[CredentialsLabels.refreshToken] ?? "",
            tokenFormat: tokens[CredentialsLabels.tokenFormat] ?? "",
            jwt: tokens[CredentialsLabels.jwt] ?? "",
            authCode: tokens[CredentialsLabels.authCode] ?? "",
            challengeString: tokens[CredentialsLabels.challengeString] ?? "",
            issuedAt: tokens[CredentialsLabels.issuedAt] ?? "",
            credentialsScopes: tokens[CredentialsLabels.scopes] ?? "",
            instanceUrl: urls[CredentialsLabels.instanceUrl] ?? "",
            apiInstanceUrl: urls[CredentialsLabels.apiInstanceUrl] ?? "",
            apiUrl: urls[CredentialsLabels.apiUrl] ?? "",
            identityUrl: urls[CredentialsLabels.identityUrl] ?? "",
            communityId: community[CredentialsLabels.communityId] ?? "",
            communityUrl: community[CredentialsLabels.communityUrl] ?? "",
            lightningDomain: domainsAndSids[CredentialsLabels.lightningDomain] ?? "",
            lightningSid: domainsAndSids[CredentialsLabels.lightningSid] ?? "",
            vfDomain: domainsAndSids[CredentialsLabels.vfDomain] ?? "",
            vfSid: domainsAndSids[CredentialsLabels.vfSid] ?? "",
            contentDomain: domainsAndSids[CredentialsLabels.contentDomain] ?? "",
            contentSid: domainsAndSids[CredentialsLabels.contentSid] ?? "",
            parentSid: domainsAndSids[CredentialsLabels.parentSid] ?? "",
            sidCookieName: domainsAndSids[CredentialsLabels.sidCookieName] ?? "",
            csrfToken: cookiesAndSecurity[CredentialsLabels.csrfToken] ?? "",
            cookieClientSrc: cookiesAndSecurity[CredentialsLabels.cookieClientSrc] ?? "",
            cookieSidClient: cookiesAndSecurity[CredentialsLabels.cookieSidClient] ?? "",
            beaconChildConsumerKey: beacon[CredentialsLabels.beaconChildConsumerKey] ?? "",
            beaconChildConsumerSecret: beacon[CredentialsLabels.beaconChildConsumerSecret] ?? "",
            additionalOAuthFields: other[CredentialsLabels.additionalOAuthFields] ?? ""
        )
    }
    
    func getOAuthConfiguration() -> OAuthConfigurationData {
        // Tap export button and get JSON
        let json = tapExportAndGetJSON(exportOAuthConfigButton(), alertTitle: "OAuth Configuration JSON")
        
        return OAuthConfigurationData(
            configuredConsumerKey: json[OAuthConfigLabels.consumerKey] as? String ?? "",
            configuredCallbackUrl: json[OAuthConfigLabels.callbackUrl] as? String ?? "",
            configuredScopes: json[OAuthConfigLabels.scopes] as? String ?? ""
        )
    }
    
    func getJwtDetails() -> JwtDetailsData? {
        // Check if JWT export button exists (indicates JWT token is available)
        guard exportJwtTokenButton().waitForExistence(timeout: 1) else {
            return nil
        }
        
        // Tap export button and get JSON
        let json = tapExportAndGetJSON(exportJwtTokenButton(), alertTitle: "JWT Token JSON")
        
        // Parse JSON sections
        let header = json[JwtTokenLabels.header] as? [String: String] ?? [:]
        let payload = json[JwtTokenLabels.payload] as? [String: String] ?? [:]
        
        return JwtDetailsData(
            algorithm: header[JwtTokenLabels.algorithm] ?? "",
            type: header[JwtTokenLabels.type] ?? "",
            keyId: header[JwtTokenLabels.keyId] ?? "",
            tokenType: header[JwtTokenLabels.tokenType] ?? "",
            tenantKey: header[JwtTokenLabels.tenantKey] ?? "",
            version: header[JwtTokenLabels.version] ?? "",
            audience: payload[JwtTokenLabels.audience] ?? "",
            expirationDate: payload[JwtTokenLabels.expirationDate] ?? "",
            issuer: payload[JwtTokenLabels.issuer] ?? "",
            subject: payload[JwtTokenLabels.subject] ?? "",
            scopes: payload[JwtTokenLabels.scopes] ?? "",
            clientId: payload[JwtTokenLabels.clientId] ?? ""
        )
    }
    
    // MARK: - Private Helper Methods for Data Extraction
    
    /// Taps the export button and returns the parsed JSON from the alert
    private func tapExportAndGetJSON(_ exportButton: XCUIElement, alertTitle: String) -> [String: Any] {
        // Tap the export button
        tap(exportButton)
        
        // Wait for and get the alert
        let alert = app.alerts[alertTitle]
        guard alert.waitForExistence(timeout: timeout) else {
            return [:]
        }
        
        // Get the message text from the alert (contains the JSON)
        let jsonString = alert.staticTexts.element(boundBy: 1).label
        
        // Dismiss the alert
        alert.buttons["OK"].tap()
        
        // Parse the JSON
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            return [:]
        }
        
        return json
    }
    
    // MARK: - Other
    
    private func hasStaticText(_ text: String) -> Bool {
        let staticText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '\(text)'"))
        return staticText.firstMatch.waitForExistence(timeout: timeout)
    }
}

