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

    // MARK: - QR Code Login Via UI Bridge API Public Implementation

    /**
     * Automatically log in with a UI Bridge API login QR code.
     * - Parameters
     *     - loginQrCodeContent:  The login QR code content.  This should be either a URL or URL
     *     query containing the UI Bridge API JSON parameter.  The UI Bridge API JSON parameter
     *     should contain URL-encoded JSON with two values:
     *       - frontdoor_bridge_url
     *       - pkce_code_verifier
     * If pkce_code_verifier is not specified then the user agent flow is used
     * - Returns: Boolean true if a log in attempt is possible using the provided QR code content, false
     * otherwise
     */
    func loginFromQrCode(
        loginQrCodeContent: String?
    ) -> Bool {
        if let uiBridgeApiParameters = uiBridgeApiParametersFromLoginQrCodeContent(
            loginQrCodeContent
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
     * Automatically log in with a UI Bridge API front door bridge URL and PKCE code verifier.
     * - Parameters
     *   - frontdoorBridgeUrl: The UI Bridge API front door bridge URL
     *   - pkceCodeVerifier: The PKCE code verifier
     */
    func loginWithFrontdoorBridgeUrl(
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

    // MARK: - QR Code Login Via UI Bridge API Private Implementation

    /**
     * Parses UI Bridge API parameters from the provided login QR code content.
     * - Parameters
     *   - loginQrCodeContent: The login QR code content string
     *   - UiBridgeApiParameters: The UI Bridge API parameters or null if the QR code content cannot
     *   provide them for any reason
     */
    private func uiBridgeApiParametersFromLoginQrCodeContent(
        _ loginQrCodeContent: String?
    ) -> UiBridgeApiParameters? {
        guard let loginQrCodeContentUnwrapped = loginQrCodeContent else { return nil }
        guard let uiBridgeApiJson = uiBridgeApiJsonFromQrCodeContent(loginQrCodeContentUnwrapped) else { return nil }
        return uiBridgeApiParametersFromUiBridgeApiJson(uiBridgeApiJson)
    }

    /**
     * Parses UI Bridge API parameters JSON from the provided string, which may be formatted to match
     * either QR code content provided by app's QR code library or a custom app deep link from an external
     * QR code reader.
     *
     * 1. From external QR reader: ?bridgeJson={...}
     * 2. From the app's QR reader: ?bridgeJson=%7B...%7D
     *
     * - Parameters
     *   - qrCodeContent: The QR code content string
     * - Returns: String: The UI Bridge API parameter JSON or null if the string cannot provide the
     *  JSON for any reason
     */
    private func uiBridgeApiJsonFromQrCodeContent(
        _ qrCodeContent: String
    ) -> String? {
        return try? NSRegularExpression(
            pattern: "^.*\\?bridgeJson=").stringByReplacingMatches(
                in: qrCodeContent,
                range: NSRange(
                    location: 0,
                    length: qrCodeContent.utf16.count),
                withTemplate: "").removingPercentEncoding
    }

    /**
     * Creates UI Bridge API parameters from the provided JSON string.
     * - Parameters
     *   - uiBridgeApiParameterJsonString: The UI Bridge API parameters JSON string
     * - Returns: The UI Bridge API parameters
     */
    private func uiBridgeApiParametersFromUiBridgeApiJson(
        _ uiBridgeApiParameterJsonString: String
    ) -> UiBridgeApiParameters? {
        guard let uiBridgeApiParameterJsonData = uiBridgeApiParameterJsonString.data(
            using: .utf8
        ) else { return nil }
        
        do { return try JSONDecoder().decode(
            UiBridgeApiParameters.self,
            from: uiBridgeApiParameterJsonData)
        } catch let error {
            SFSDKCoreLogger().e(
                classForCoder,
                message: "Cannot JSON decode UI bridge API parameters due to a decoding error with description '\(error.localizedDescription)'.")
            return nil
        }
    }

    /**
     * A struct representing UI Bridge API parameters provided by a login QR code.
     */
    private struct UiBridgeApiParameters: Codable {
        
        /** The front door bridge URL provided by the login QR code */
        let frontdoorBridgeUrl: String
        
        /** The PKCE code verifier provided by the login QR code */
        let pkceCodeVerifier: String?
        
        enum CodingKeys: String, CodingKey {
            case frontdoorBridgeUrl = "frontdoor_bridge_url"
            case pkceCodeVerifier = "pkce_code_verifier"
        }
    }
}
