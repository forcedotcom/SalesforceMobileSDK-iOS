//
//  SFLoginViewController+QrCodeLogin.swift
//  SalesforceSDKCore
//
//  Created by Eric Johnson on 9/5/24.
//

import Foundation

public extension SalesforceLoginViewController {

    // MARK: QR Code Login Via UI Bridge API Public Implementation

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
        print("Login With Frontdoor Bridge URL: '\(frontdoorBridgeUrlString)'/'\(String(describing: pkceCodeVerifier))'.")
        
        // TODO: W-16171402: Integrate With Existing Login Logic And Resolve Use Of PKCE Code Verifier. ECJ20240912
        
        guard let frontdoorBridgeUrl = URL(string: frontdoorBridgeUrlString) else { return }
        guard let webView = oauthView as? WKWebView else { return }
        webView.load(URLRequest(url: frontdoorBridgeUrl))
    }

    // MARK: QR Code Login Via UI Bridge API Private Implementation

//    /**
//     * Determines if QR code login is enabled for the provided intent.
//     * @param intent The intent to determine QR code login enablement for
//     * @return Boolean true if QR code login is enabled for the the intent or
//     * false otherwise
//     */
//    private fun isDeepLinkedQrCodeLogin(
//        intent: Intent
//    ) = SalesforceSDKManager.getInstance().isQrCodeLoginEnabled
//            && intent.data?.path?.contains(LOGIN_QR_PATH) == true
//
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
     * TODO: W-16171402: Verify this after developing template app's external QR code deep-link support. ECJ20240912
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
                message: "Cannot JSON encode start password reset request body due to an encoding error with description '\(error.localizedDescription)'.")
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
