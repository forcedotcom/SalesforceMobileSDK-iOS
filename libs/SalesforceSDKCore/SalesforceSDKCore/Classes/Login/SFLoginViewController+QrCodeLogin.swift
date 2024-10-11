//
//  SFLoginViewController+QrCodeLogin.swift
//  SalesforceSDKCore
//
//  Created by Eric Johnson on 9/5/24.
//  Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

public extension SalesforceLoginViewController {
    
    // MARK: - QR Code Login Via Salesforce Identity API UI Bridge Public Implementation
    
    /**
     * Automatically log in with a UI Bridge API front door bridge URL and PKCE code verifier.
     *
     * This method is the intended entry point to Salesforce Mobile SDK when using the Salesforce
     * Identity API UI Bridge front door URL.  Usable, default implementations of methods are
     * provided for parsing the UI Bridge parameters from the reference JSON and log in URLs used
     * by the reference QR Code Log In implementation.  However, the URL and JSON structure in the
     * reference implementation is not required.  An app may use a custom structure so long as this
     * entry point is used to log in with the front door URL and optional PKCE code verifier.
     *
     * - Parameters
     *   - frontdoorBridgeUrl: The UI Bridge API front door bridge URL
     *   - pkceCodeVerifier: The optional PKCE code verifier, which is not required for User Agent
     * Authorization Flow but is required for Web Server Authorization Flow
     */
    class func loginWithFrontdoorBridgeUrl(
        _ frontdoorBridgeUrlString: String,
        pkceCodeVerifier: String?
    ) {
        guard let frontdoorBridgeUrl = URL(string: frontdoorBridgeUrlString) else { return }
        
        // Stop current authentication attempt, if applicable, before starting the new one.
        UserAccountManager.shared.stopCurrentAuthentication { result in
            
            DispatchQueue.main.async {
                // Login using front door bridge URL and PKCE code verifier provided by the QR code.
                AuthHelper.loginIfRequired(nil,
                                           frontDoorBridgeUrl: frontdoorBridgeUrl,
                                           codeVerifier: pkceCodeVerifier) {
                }
            }
        }
    }
    
    /**
     * Automatically log in using a QR code login URL and Salesforce Identity API UI Bridge.
     *
     * This method is the intended entry point for login using the reference QR Code Login URL and JSON
     * format.  It will parse the UI Bridge parameters from the login QR code URL and call
     * ``SFLoginViewController/loginWithFrontdoorBridgeUrl(_:pkceCodeVerifier:)``.
     * However, the URL and JSON structure in the reference implementation is not required.  An app may
     * use a custom structure so long as UI Bridge front door URL and optional PKCE code verifier are
     * provided to
     * ``SFLoginViewController/loginWithFrontdoorBridgeUrl(_:pkceCodeVerifier:)``.
     * - Parameters
     *     - qrCodeLoginUrl:  The QR code login URL
     * - Returns: Boolean true if a log in attempt is possible using the provided QR code log in URL,
     * false otherwise
     */
    class func loginWithFrontdoorBridgeUrlFromQrCode(
        _ qrCodeLoginUrl: String?
    ) -> Bool {
        if let uiBridgeApiParameters = uiBridgeApiParametersFromQrCodeLoginUrl(
            qrCodeLoginUrl
        ) {
            loginWithFrontdoorBridgeUrl(
                uiBridgeApiParameters.frontdoorBridgeUrl,
                pkceCodeVerifier: uiBridgeApiParameters.pkceCodeVerifier
            )
            return true
        } else {
            return false
        }
    }
    
    /**
     * For QR code login URLs, the URL path which distinguishes them from other URLs provided by the
     * app's internal QR code reader or deep link intents from external QR code readers.
     *
     * Apps may customize this so long as it matches the server-side Apex class or other code generating
     * the QR code.
     *
     * Apps need not use the QR code login URL structure provided here if they wish to entirely customize
     * the QR code login URL format and implement a custom parsing scheme.
     */
    static var qrCodeLoginUrlPath = "/login/qr"
    
    /**
     * For QR code login URLs, the URL query string parameter name for the Salesforce Identity API UI
     * Bridge parameters JSON object.
     *
     * Apps may customize this so long as it matches the server-side Apex class or other code generating
     * the QR code.
     */
    static var qrCodeLoginUrlJsonParameterName = "bridgeJson"
    
    /**
     * For QR code login URLs, the Salesforce Identity API UI Bridge parameters JSON key for the
     * frontdoor URL.
     *
     * Apps may customize this so long as it matches the server-side Apex class or other code generating
     * the QR code.
     */
    static var qrCodeLoginUrlJsonFrontdoorBridgeUrlKey = "frontdoor_bridge_url"
    
    /**
     * For QR code login URLs, the Salesforce Identity API UI Bridge parameters JSON key for the PKCE
     * code verifier, which is only used when the front door URL was generated for the web server
     * authorization flow.  The user agent flow does not require a value for this parameter.
     *
     * Apps may customize this so long as it matches the server-side Apex class or other code generating
     * the QR code.
     */
    static var qrCodeLoginUrlJsonPkceCodeVerifierKey = "pkce_code_verifier"
    
    // MARK: - QR Code Login Via Salesforce Identity API UI Bridge Private Implementation
    
    /**
     * Parses Salesforce Identity API UI Bridge parameters from the provided login QR code login URL.
     * - Parameters
     *   - qrCodeLoginUrl: The QR code login URL
     *   - UiBridgeApiParameters: The UI Bridge API parameters or null if the QR code login URL cannot
     *   provide them for any reason
     */
    private class func uiBridgeApiParametersFromQrCodeLoginUrl(
        _ qrCodeLoginUrl: String?
    ) -> UiBridgeApiParameters? {
        guard let qrCodeLoginUrlUnwrapped = qrCodeLoginUrl else { return nil }
        guard let uiBridgeApiJson = uiBridgeApiJsonFromQrCodeLoginUrl(qrCodeLoginUrlUnwrapped) else { return nil }
        return uiBridgeApiParametersFromUiBridgeApiJson(uiBridgeApiJson)
    }
    
    /**
     * Parses Salesforce Identity API UI Bridge parameters JSON string from the provided QR code login
     * URL.
     *
     * - Parameters
     *   - qrCodeLoginUrl: The QR code login URL
     * - Returns: String: The UI Bridge API parameter JSON or null if the QR code login URL cannot
     * provide the JSON for any reason
     */
    private class func uiBridgeApiJsonFromQrCodeLoginUrl(
        _ qrCodeLoginUrl: String
    ) -> String? {
        return try? NSRegularExpression(
            pattern: "^.*\\?\(SalesforceLoginViewController.qrCodeLoginUrlJsonParameterName)=").stringByReplacingMatches(
                in: qrCodeLoginUrl,
                range: NSRange(
                    location: 0,
                    length: qrCodeLoginUrl.utf16.count),
                withTemplate: "").removingPercentEncoding
    }
    
    /**
     * Creates Salesforce Identity API UI Bridge parameters from the provided JSON string.
     * - Parameters
     *   - uiBridgeApiParameterJsonString: The UI Bridge API parameters JSON string
     * - Returns: The UI Bridge API parameters
     */
    private class func uiBridgeApiParametersFromUiBridgeApiJson(
        _ uiBridgeApiParameterJsonString: String
    ) -> UiBridgeApiParameters? {
        guard let uiBridgeApiParameterJsonData = uiBridgeApiParameterJsonString.data(
            using: .utf8
        ) else { return nil }
        
        do {
            let jsonAny = try JSONSerialization.jsonObject(
                with: uiBridgeApiParameterJsonData,
                options: []
            )
            if let jsonMap = jsonAny as? [String: Any] {
                guard let frontdoorBridgeUrl = jsonMap[qrCodeLoginUrlJsonFrontdoorBridgeUrlKey] as? String else { return nil}
                
                // Note: Codable is not used here so the JSON key names are customizable by the MSDK API consumer.
                return UiBridgeApiParameters(
                    frontdoorBridgeUrl: frontdoorBridgeUrl,
                    pkceCodeVerifier: jsonMap[qrCodeLoginUrlJsonPkceCodeVerifierKey] as? String
                )
            } else {
                SFSDKCoreLogger().e(
                    self,
                    message: "Cannot JSON decode UI bridge API parameters due to an unexpected JSON format.")
                return nil
            }
        } catch let error {
            SFSDKCoreLogger().e(
                self,
                message: "Cannot JSON decode UI bridge API parameters due to a decoding error with description '\(error.localizedDescription)'.")
            return nil
        }
    }
    
    /**
     * A struct representing UI Bridge API parameters provided by a login QR code.
     */
    private struct UiBridgeApiParameters {
        
        /** The front door bridge URL provided by the login QR code */
        let frontdoorBridgeUrl: String
        
        /** The PKCE code verifier provided by the login QR code */
        let pkceCodeVerifier: String?
    }
}
