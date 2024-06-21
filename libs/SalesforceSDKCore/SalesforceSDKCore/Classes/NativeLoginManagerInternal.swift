//
//  NativeLoginManager.swift
//  SalesforceSDKCore
//
//  Created by Brandon Page on 12/13/23.
//  Copyright (c) 2023-present, salesforce.com, inc. All rights reserved.
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

import CryptoKit

/// Global Constants
let maximumUsernameLength = 80
let minimumPasswordLength = 8
let maximumPasswordLengthInBytes = 16000

///
/// This class is internal to the Mobile SDK - don't instantiate in your application code!
///
/// It's only public to be visible from the obj-c code when the library is compiled as a framework.
/// See https://developer.apple.com/documentation/swift/importing-swift-into-objective-c#Import-Code-Within-a-Framework-Target
@objc(SFNativeLoginManagerInternal)
public class NativeLoginManagerInternal: NSObject, NativeLoginManager {
    
    @objc public let clientId: String
    @objc public let redirectUri: String
    @objc public let loginUrl: String
    
    ///   The Google Cloud project reCAPTCHA Key's "Id" as shown in Google Cloud Console under
    ///   "Products & Solutions", "Security" and "reCAPTCHA Enterprise"
    private let reCaptchaSiteKeyId: String?
    
    ///   The Google Cloud project's "Id" as shown in Google Cloud Console
    private let googleCloudProjectId: String?
    
    ///  Specifies if reCAPTCHA uses the enterprise license
    private let isReCaptchaEnterprise: Bool
    
    let scene: UIScene?
    
    /// A structure for the Headless Identity API's authorization endpoint response
    private struct AuthorizationResponseBody: Codable {
        let sfdc_community_url: String
        let sfdc_community_id: String
        let code: String
    }
    
    @objc public init(clientId: String, redirectUri: String, loginUrl: String, scene: UIScene?
    ) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.loginUrl = loginUrl
        self.reCaptchaSiteKeyId = nil
        self.googleCloudProjectId = nil
        self.isReCaptchaEnterprise = false
        self.scene = scene
    }
    
    @objc public init(clientId: String, redirectUri: String, loginUrl: String, reCaptchaSiteKeyId: String?, googleCloudProjectId: String?, isReCaptchaEnterprise: Bool, scene: UIScene?) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.loginUrl = loginUrl
        self.reCaptchaSiteKeyId = reCaptchaSiteKeyId
        self.googleCloudProjectId = googleCloudProjectId
        self.isReCaptchaEnterprise = isReCaptchaEnterprise
        self.scene = scene
    }
    
    public func login(
        username: String,
        password: String
    ) async -> NativeLoginResult
    {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let it = mapInvalidUsernameToResult(trimmedUsername) { return it }
        if let it = mapInvalidPasswordToResult(trimmedPassword) { return it }
        
        guard let credentials = generateColonConcatenatedBase64String(
            value1: trimmedUsername,
            value2: trimmedPassword) else {
            SFSDKCoreLogger().e(
                classForCoder,
                message: "Unable to UTF-8 encode colon-concatenated string with values '\(trimmedUsername)' and '\(trimmedPassword)' due to a nil encoding result.")
            return .unknownError
            
        }
        let authRequest = RestRequest(method: .POST, baseURL: loginUrl, path: kSFOAuthEndPointAuthorize, queryParams: nil)
        let customHeaders: NSMutableDictionary = [kSFOAuthRequestTypeParamName: kSFOAuthRequestTypeNamedUser,
                                                        kHttpHeaderContentType: kHttpPostContentType,
                                            kSFOAuthAuthorizationTypeParamName: "\(kSFOAuthAuthorizationTypeBasic) \(credentials)"]
        
        let codeVerifier = generateCodeVerifier()
        guard let challenge = generateChallenge(codeVerifier: codeVerifier) else { return .unknownError }
        let authRequestBody = generateAuthorizationRequestBody(
            codeChallenge: challenge)
        authRequest.customHeaders = customHeaders
        authRequest.setCustomRequestBodyString(authRequestBody, contentType: kHttpPostContentType)
        authRequest.requiresAuthentication = false
        authRequest.endpoint = ""
        
        // First REST Call - Authorization
        let authorizationResponse = await withCheckedContinuation { continuation in
            RestClient.sharedGlobal.send(request: authRequest) { result in
                continuation.resume(returning: result)
            }
        }
        
        // Second REST Call - Access token request with code verifier
        return await submitAccessTokenRequest(
            authorizationResponse: authorizationResponse,
            codeVerifier: codeVerifier)
    }
    
    public func fallbackToWebAuthentication() {
        UserAccountManager.shared.shouldFallbackToWebAuthentication = true
        UserAccountManager.shared.switchToNewUserAccount { _ in
            UserAccountManager.shared.shouldFallbackToWebAuthentication = false
        }
    }
    
    public func shouldShowBackButton() -> Bool {
        if (SalesforceManager.shared.biometricAuthenticationManager().locked) {
            return false
        }
        
        guard let totalAccounts = UserAccountManager.shared.userAccounts()?.count else { return false }
        return (totalAccounts > 0 && UserAccountManager.shared.currentUserAccount != nil)
    }
    
    public func cancelAuthentication() {
        if (shouldShowBackButton()) {
            UserAccountManager.shared.stopCurrentAuthentication()
            SFSDKWindowManager.shared().authWindow(nil).viewController?.presentedViewController?.dismiss(animated: false, completion: {
                SFSDKWindowManager.shared().authWindow(nil).dismissWindow()
            })
        }
    }
    
    public func biometricAuthenticationSuccess() {
        let bioAuthMgr = BiometricAuthenticationManagerInternal.shared
        
        if bioAuthMgr.enabled && bioAuthMgr.locked {
            SFSDKCoreLogger.i(classForCoder, message: "Native Login biometric authentication success.")
            bioAuthMgr.unlockPostProcessing()
            UserAccountManager.shared.stopCurrentAuthentication()
        }
    }
    
    public func getBiometricAuthenticationUsername() -> String? {
        if BiometricAuthenticationManagerInternal.shared.locked {
            return UserAccountManager.shared.currentUserAccount?.idData.username
        }
        
        return nil
    }
    
    private func isValidUsername(username: String) -> Bool {
        if (username.count > maximumUsernameLength) {
            return false
        }
        
        let emailStyleRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailStyleRegex)
        return predicate.evaluate(with: username)
    }
    
    /// Validation of the weakest possible password requrements.
    /// Rules derived from: https://help.salesforce.com/s/articleView?id=sf.admin_password.htm&type=5
    private func isValidPassword(password: String) -> Bool {
        let containsNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        let containsLetter = password.rangeOfCharacter(from: .letters) != nil
        
        return containsNumber && containsLetter && password.count >= minimumPasswordLength && password.utf8.count <= maximumPasswordLengthInBytes
    }
    
    private func urlSafeBase64Encode(data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func generateCodeVerifier() -> String {
        let randomData = SFSDKCryptoUtils.randomByteData(withLength: kSFOAuthCodeVerifierByteLength)
        return urlSafeBase64Encode(data: randomData)
    }
    
    private func generateChallenge(codeVerifier: String) -> String? {
        guard let data = codeVerifier.data(using: .utf8) else { return nil }
        let hash = SHA256.hash(data: data)
        return urlSafeBase64Encode(data: hash.dataRepresentation)
    }
    
    // MARK: Salesforce Identity API Headless Registration Flow
    
    @objc public func startRegistration(
        email: String,
        firstName: String,
        lastName: String,
        username: String,
        newPassword: String,
        reCaptchaToken: String,
        otpVerificationMethod: OtpVerificationMethod
    ) async -> StartRegistrationResult {
        
        // Validate parameters.
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        if let it = mapInvalidEmailAddressToResult(trimmedEmail) { return StartRegistrationResult(nativeLoginResult: it) }
        if let it = mapInvalidUsernameToResult(trimmedUsername) { return StartRegistrationResult(nativeLoginResult: it) }
        if let it = mapInvalidPasswordToResult(trimmedPassword) { return StartRegistrationResult(nativeLoginResult: it) }
        let reCaptchaParameterGenerationResult = generateReCaptchaParameters(reCaptchaToken: reCaptchaToken)
        
        // Determine the OTP verification method.
        let otpVerificationMethodString = generateVerificationTypeHeaderValue(
            otpVerificationMethod: otpVerificationMethod)
        
        // Generate the start registration request body.
        guard let startRegistrationRequestBodyString = {
            do { return String(
                data: try JSONEncoder().encode(
                    StartRegistrationRequestBody(
                        recaptcha: reCaptchaParameterGenerationResult.nonEnterpriseReCaptchaToken,
                        recaptchaEvent: reCaptchaParameterGenerationResult.enterpriseReCaptchaEvent,
                        userData: UserData(
                            email: email,
                            username: username,
                            password: newPassword,
                            firstName: firstName,
                            lastName: lastName),
                        otpVerificationMethod: otpVerificationMethodString)
                ),
                encoding: .utf8)
            } catch let error {
                SFSDKCoreLogger().e(
                    classForCoder,
                    message: "Cannot JSON encode start registration request body due to an encoding error with description '\(error.localizedDescription)'.")
                return nil
            }}() else { return StartRegistrationResult(nativeLoginResult: .unknownError) }
        
        // Create the start registration request.
        let startRegistrationRequest = RestRequest(
            method: .POST,
            baseURL: loginUrl,
            path: kSFOAuthEndPointHeadlessInitRegistration,
            queryParams: nil)
        startRegistrationRequest.endpoint = ""
        startRegistrationRequest.requiresAuthentication = false
        startRegistrationRequest.setCustomRequestBodyString(
            startRegistrationRequestBodyString,
            contentType: kHttpPostApplicationJsonContentType
        )
        
        // Submit the start registration request and fetch the response.
        let startRegistrationResponse = await withCheckedContinuation { continuation in
            RestClient.sharedGlobal.send(
                request: startRegistrationRequest
            ) { result in
                continuation.resume(returning: result)
            }
        }
        
        // React to the start registration response.
        switch startRegistrationResponse {
            
        case .success(let startRegistrationResponse):
            // Decode the start registration response.
            guard let startRegistrationResponseBody = {
                do {
                    return try startRegistrationResponse.asDecodable(type: StartRegistrationResponseBody.self)
                } catch let error {
                    SFSDKCoreLogger().e(
                        classForCoder,
                        message: "Cannot JSON decode start registration response body due to a decoding error with description '\(error.localizedDescription)'.")
                    return nil
                }}() else { return StartRegistrationResult(nativeLoginResult: .unknownError) }
            return StartRegistrationResult(
                nativeLoginResult: .success,
                email: startRegistrationResponseBody.email,
                requestIdentifier: startRegistrationResponseBody.identifier)
            
        case .failure(let error):
            SFSDKCoreLogger().e(
                classForCoder,
                message: "Start registration request failure with description '\(error.localizedDescription)'.")
            return StartRegistrationResult(nativeLoginResult: .unknownError)
        }
    }
    
    public func completeRegistration(
        otp: String,
        requestIdentifier: String,
        otpVerificationMethod: OtpVerificationMethod
    ) async -> NativeLoginResult {
        
        return await submitAuthorizationRequest(
            authRequestType: kSFOAuthRequestTypeUserRegistration,
            otp: otp,
            otpIdentifier: requestIdentifier,
            otpVerificationMethod: otpVerificationMethod)
    }
    
    /// A data class for the Salesforce Identity API start registration request body.
    private struct StartRegistrationRequestBody : Codable {
        
        /// The reCAPTCHA token provided by the reCAPTCHA iOS SDK.  This is not used with reCAPTCHA Enterprise
        var recaptcha: String?
        
        /// The reCAPTCHA parameters for use with reCAPTCHA Enterprise
        var recaptchaEvent: ReCaptchaEventRequestParameter?
        
        /// The start registration request user data
        var userData: UserData
        
        /// The one-time-password's delivery method for verification in "email" or "sms"
        var otpVerificationMethod: String
        
        enum CodingKeys: String, CodingKey {
            case recaptcha = "recaptcha"
            case recaptchaEvent = "recaptchaevent"
            case userData = "userdata"
            case otpVerificationMethod = "verificationMethod"
        }
    }
    
    /// A data class for the Salesforce Identity API start registration request body's user info
    /// parameter.
    private struct UserData : Codable {
        
        /// A valid, user-entered email address
        var email: String
        
        /// A valid Salesforce username or email
        var username: String
        
        /// The user-entered new password
        var password: String
        
        /// The user-entered first name
        var firstName: String
        
        /// The user-entered last name
        var lastName: String
        
        enum CodingKeys: String, CodingKey {
            case email = "email"
            case username = "username"
            case password = "password"
            case firstName = "firstName"
            case lastName = "lastName"
        }
    }
    
    /// A structure for the start registration response body.
    private struct StartRegistrationResponseBody: Codable {
        let email: String
        let identifier: String
    }
    
    // MARK: Salesforce Identity API Headless Forgot Password Flow
    
    public func startPasswordReset(
        username: String,
        reCaptchaToken: String
    ) async -> NativeLoginResult {
        
        // Validate parameters.
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if let it = mapInvalidUsernameToResult(trimmedUsername) { return it }
        let reCaptchaParameterGenerationResult = generateReCaptchaParameters(reCaptchaToken: reCaptchaToken)
        
        // Generate the start password reset request body.
        guard let startPasswordResetRequestBodyString = {
            do { return String(
                data: try JSONEncoder().encode(
                    StartPasswordResetRequestBody(
                        recaptcha: reCaptchaParameterGenerationResult.nonEnterpriseReCaptchaToken,
                        recaptchaEvent: reCaptchaParameterGenerationResult.enterpriseReCaptchaEvent,
                        username: trimmedUsername)
                ),
                encoding: .utf8)
            } catch let error {
                SFSDKCoreLogger().e(
                    classForCoder,
                    message: "Cannot JSON encode start password reset request body due to an encoding error with description '\(error.localizedDescription)'.")
                return nil
            }}() else { return .unknownError }
        
        // Create the start password reset request.
        let startPasswordResetRequest = RestRequest(
            method: .POST,
            baseURL: loginUrl,
            path: kSFOAuthEndPointHeadlessForgotPassword,
            queryParams: nil)
        startPasswordResetRequest.endpoint = ""
        startPasswordResetRequest.requiresAuthentication = false
        startPasswordResetRequest.setCustomRequestBodyString(
            startPasswordResetRequestBodyString,
            contentType: kHttpPostApplicationJsonContentType
        )
        
        let startPasswordResetResponse = await withCheckedContinuation { continuation in
            RestClient.sharedGlobal.send(
                request: startPasswordResetRequest
            ) { result in
                continuation.resume(returning: result)
            }
        }
        
        // React to the start password reset response.
        switch startPasswordResetResponse {
            
        case .success:
            return .success
            
        case .failure(let error):
            SFSDKCoreLogger().e(
                classForCoder,
                message: "Start password reset request failure with description '\(error.localizedDescription)'.")
            return  .unknownError
        }
    }
    
    public func completePasswordReset(
        username: String,
        otp: String,
        newPassword: String
    ) async -> NativeLoginResult {
        
        // Validate parameters.
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if let it = mapInvalidUsernameToResult(trimmedUsername) { return it }
        let trimmedOtp = otp.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        if let it = mapInvalidPasswordToResult(trimmedPassword) { return it }
        
        // Generate the complete password reset request body.
        guard let completePasswordResetRequestBodyString = {
            do { return String(
                data: try JSONEncoder().encode(
                    CompletePasswordResetRequestBody(
                        username: trimmedUsername,
                        otp: trimmedOtp,
                        newPassword: trimmedPassword)
                ),
                encoding: .utf8)
            } catch let error {
                SFSDKCoreLogger().e(
                    classForCoder,
                    message: "Cannot JSON encode complete password reset request body due to an encoding error with description '\(error.localizedDescription)'.")
                return nil
            }}() else { return .unknownError }
        
        // Create the complete password reset request.
        let completePasswordResetRequest = RestRequest(
            method: .POST,
            baseURL: loginUrl,
            path: kSFOAuthEndPointHeadlessForgotPassword,
            queryParams: nil)
        completePasswordResetRequest.endpoint = ""
        completePasswordResetRequest.requiresAuthentication = false
        completePasswordResetRequest.setCustomRequestBodyString(
            completePasswordResetRequestBodyString,
            contentType: kHttpPostApplicationJsonContentType
        )
        
        let completePasswordResetResponse = await withCheckedContinuation { continuation in
            RestClient.sharedGlobal.send(
                request: completePasswordResetRequest
            ) { result in
                continuation.resume(returning: result)
            }
        }
        
        // React to the complete password reset response.
        switch completePasswordResetResponse {
            
        case .success:
            return .success
            
        case .failure(let error):
            SFSDKCoreLogger().e(
                classForCoder,
                message: "Complete password reset request failure with description '\(error.localizedDescription)'.")
            return  .unknownError
        }
    }
    
    // MARK: Salesforce Identity API Headless, Password-Less Login Via One-Time-Passcode
    
    public func submitOtpRequest(
        username: String,
        reCaptchaToken: String,
        otpVerificationMethod: OtpVerificationMethod) async -> OtpRequestResult
    {
        
        // Validate parameters.
        if !isValidUsername(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines)
        ) {
            return OtpRequestResult(nativeLoginResult: .invalidUsername)
        }
        let reCaptchaParameterGenerationResult = generateReCaptchaParameters(reCaptchaToken: reCaptchaToken)
        
        /*
         * Create the OTP request body with the provided parameters. Note: The
         * `emailtemplate` parameter isn't supported here, but could be added in
         * the future.
         */
        // Determine the OTP verification method.
        let otpVerificationMethodString = generateVerificationTypeHeaderValue(
            otpVerificationMethod: otpVerificationMethod)
        // Generate the OTP request body.
        guard let requestBodyString = {
            do { return String(
                data: try JSONEncoder().encode(
                    OtpRequestBody(
                        recaptcha: reCaptchaParameterGenerationResult.nonEnterpriseReCaptchaToken,
                        recaptchaEvent: reCaptchaParameterGenerationResult.enterpriseReCaptchaEvent,
                        username: username,
                        verificationMethod: otpVerificationMethodString)
                ),
                encoding: .utf8)
            } catch let error {
                SFSDKCoreLogger().e(
                    classForCoder,
                    message: "Cannot JSON encode OTP request body due to an encoding error with description '\(error.localizedDescription)'.")
                return nil
            }}() else { return OtpRequestResult(nativeLoginResult: .unknownError) }
        
        // Create the OTP request.
        let otpRequest = RestRequest(
            method: .POST,
            baseURL: loginUrl,
            path: kSFOAuthEndPointHeadlessInitPasswordlessLogin,
            queryParams: nil)
        otpRequest.endpoint = ""
        otpRequest.requiresAuthentication = false
        otpRequest.setCustomRequestBodyString(
            requestBodyString,
            contentType: kHttpPostApplicationJsonContentType
        )
        
        // Submit the OTP request and fetch the OTP response.
        let otpResponse = await withCheckedContinuation { continuation in
            RestClient.sharedGlobal.send(
                request: otpRequest
            ) { result in
                continuation.resume(returning: result)
            }
        }
        
        // React to the OTP response.
        switch otpResponse {
            
        case .success(let otpResponse):
            // Decode the OTP response to obtain the OTP email and identifier.
            guard let otpResponseBody = {
                do {
                    return try otpResponse.asDecodable(type: OtpResponseBody.self)
                } catch let error {
                    SFSDKCoreLogger().e(
                        classForCoder,
                        message: "Cannot JSON decode OTP response body due to a decoding error with description '\(error.localizedDescription)'.")
                    return nil
                }}() else { return OtpRequestResult(nativeLoginResult: .unknownError) }
            return OtpRequestResult(
                nativeLoginResult: .success,
                otpIdentifier: otpResponseBody.identifier)
            
        case .failure(let error):
            SFSDKCoreLogger().e(
                classForCoder,
                message: "OTP request failure with description '\(error.localizedDescription)'.")
            return OtpRequestResult(nativeLoginResult: .unknownError)
        }
    }
    
    public func submitPasswordlessAuthorizationRequest(
        otp: String,
        otpIdentifier: String,
        otpVerificationMethod: OtpVerificationMethod
    ) async -> NativeLoginResult
    {
        // Validate parameters.
        let trimmedOtp = otp.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Generate code verifier and code challenge.
        let codeVerifier = generateCodeVerifier()
        guard let codeChallenge = generateChallenge(
            codeVerifier: codeVerifier
        ) else {
            SFSDKCoreLogger().e(
                classForCoder,
                message: "Cannot generate code verifier due to a nil result.")
            return .unknownError
        }
        
        // Determine the OTP verification method.
        let otpVerificationMethodString = generateVerificationTypeHeaderValue(otpVerificationMethod: otpVerificationMethod)
        // Generate the authorization.
        guard let authorization = generateColonConcatenatedBase64String(
            value1: otpIdentifier,
            value2: trimmedOtp) else
        {
            SFSDKCoreLogger().e(
                classForCoder,
                message: "Unable to UTF-8 encode colon-concatenated string with values '\(otpIdentifier)' and '\(otp)' due to a nil encoding result.")
            return .unknownError
        }
        // Generate the authorization request headers.
        let authorizationRequestHeaders: NSMutableDictionary = [
            kSFOAuthRequestTypeParamName: kSFOAuthRequestTypePasswordlessLogin,
            kSFOAuthAuthVerificationTypeParamName: otpVerificationMethodString,
            kHttpHeaderContentType: kHttpPostContentType,
            kSFOAuthAuthorizationTypeParamName: "\(kSFOAuthAuthorizationTypeBasic) \(authorization)"]
        
        // Generate the authorization request body.
        let authorizationRequestBodyString = generateAuthorizationRequestBody(codeChallenge: codeChallenge)
        
        // Create the authorization request.
        let authorizationRequest = RestRequest(
            method: .POST,
            baseURL: loginUrl,
            path: kSFOAuthEndPointAuthorize,
            queryParams: nil)
        authorizationRequest.customHeaders = authorizationRequestHeaders
        authorizationRequest.endpoint = ""
        authorizationRequest.requiresAuthentication = false
        authorizationRequest.setCustomRequestBodyString(
            authorizationRequestBodyString,
            contentType: kHttpPostContentType)
        
        // Submit the authorization request and fetch the authorization response.
        let authorizationResponse = await withCheckedContinuation { continuation in
            RestClient.sharedGlobal.send(
                request: authorizationRequest
            ) { result in
                continuation.resume(returning: result)
            }
        }
        
        // React to the authorization response.
        return await submitAccessTokenRequest(
            authorizationResponse: authorizationResponse,
            codeVerifier: codeVerifier)
    }
    
    /// Resolves a Headless Identity API headless, password-less one-time-passcode verification type
    /// header value from the provided OTP verification method.
    /// - Parameters:
    ///   - otpVerificationMethod: An OTP verification method
    private func generateVerificationTypeHeaderValue(
        otpVerificationMethod: OtpVerificationMethod
    ) -> String {
        
        return switch (otpVerificationMethod) {
        case .email: kSFOAuthAuthVerificationTypeEmail
        case .sms: kSFOAuthAuthVerificationTypeSms
        }
    }
    
    /// A data class for the start password reset request body.
    private struct StartPasswordResetRequestBody: Codable {
        /// The reCAPTCHA token provided by the reCAPTCHA iOS SDK.  This is not used with reCAPTCHA Enterprise
        var recaptcha: String?
        
        /// The reCAPTCHA parameters for use with reCAPTCHA Enterprise
        var recaptchaEvent: ReCaptchaEventRequestParameter?
        
        /// A valid Salesforce username or email
        var username: String
        
        enum CodingKeys: String, CodingKey {
            case recaptcha = "recaptcha"
            case recaptchaEvent = "recaptchaevent"
            case username = "username"
        }
    }
    
    /// A data class for the complete reset password OTP request body.
    private struct CompletePasswordResetRequestBody: Codable {
        /// A valid Salesforce username or email
        var username: String
        
        /// The user-entered one-time-password previously delivered to the user by the Salesforce Identity API forgot password endpoint
        var otp: String
        
        /// The user-entered new password
        var newPassword: String
        
        enum CodingKeys: String, CodingKey {
            case username = "username"
            case otp = "otp"
            case newPassword = "newpassword"
        }
    }
    
    /// A structure for the OTP request body.
    private struct OtpRequestBody: Codable {
        
        /// The reCAPTCHA token provided by the reCAPTCHA iOS SDK.  This is not used with reCAPTCHA Enterprise
        let recaptcha: String?
        
        /// The reCAPTCHA parameters for use with reCAPTCHA Enterprise
        let recaptchaEvent: ReCaptchaEventRequestParameter?
        
        /// The Salesforce username
        let username: String
        
        /// The OTP verification code's delivery method in "email" or "sms"
        let verificationMethod: String
        
        enum CodingKeys: String, CodingKey {
            case recaptcha = "recaptcha"
            case recaptchaEvent = "recaptchaevent"
            case verificationMethod = "verificationmethod"
            case username = "username"
        }
    }
    
    /// A structure for the OTP request response body.
    private struct OtpResponseBody: Codable {
        let status: String
        let identifier: String
    }
    
    /// A data class for the Salesforce Identity API request body reCAPTCHA event parameters.
    private struct ReCaptchaEventRequestParameter: Codable {
        
        /// The reCAPTCHA token provided by the reCAPTCHA iOS SDK.  This is used only with reCAPTCHA Enterprise
        let token: String
        
        /// The Google Cloud project reCAPTCHA Key's "Id" as shown in Google Cloud Console under "Products & Solutions", "Security" and "reCAPTCHA Enterprise"
        let siteKey: String
        
        /// The user-initiated "Action Name" for the reCAPTCHA event.  A specific value is not required by Google though it is used in reCAPTCHA Metrics.  "login" is a recommended value from Google documentation.
        var expectedAction = "login"
        
        /// The Google Cloud project's "Id" as shown in Google Cloud Console
        let projectId: String
    }
    
    // MARK: Private Implementation
    
    /// Generates a Base64 encoded value by concatinating the provided values with a colon, which is
    /// commonly used in the Headless Identity API request headers.
    /// - Parameters:
    ///   - value1: The left-side value
    ///   - value2: The right-side value
    private func generateColonConcatenatedBase64String(
        value1: String,
        value2: String
    ) -> String? {
        guard let valuesUtf8EncodedData = "\(value1):\(value2)".data(
            using: .utf8
        ) else { return nil }
        
        return urlSafeBase64Encode(data: valuesUtf8EncodedData)
    }
    
    /// Generates either the reCAPTCHA token parameter for non-enterprise reCAPTCHA configurations or
    /// the reCAPTCHA event parameter for enterprise reCAPTCHA configurations.
    /// - Parameters:
    ///    - reCaptchaToken: A reCAPTCHA token provided by the reCAPTCHA SDK
    ///  - Returns: The reCAPTCHA parameter generation result with exactly one of the non-enterprise
    ///  reCAPTCHA parameter, enterprise reCAPTCHA parameter or a native login result for generation
    ///  failure
    private func generateReCaptchaParameters(
        reCaptchaToken: String
    ) -> ReCaptchaParameterGenerationResult {
        
        // Validate state.
        guard let reCaptchaSiteKeyId else {
            SFSDKCoreLogger().e(
                classForCoder,
                message: "A reCAPTCHA site key wasn't and must be provided when using enterprise reCAPATCHA.")
            return ReCaptchaParameterGenerationResult(result: .unknownError)
        }
        guard let googleCloudProjectId else {
            SFSDKCoreLogger().e(
                classForCoder,
                message: "A Google Cloud project id wasn't and must be provided when using enterprise reCAPATCHA.")
            return ReCaptchaParameterGenerationResult(result : .unknownError)
        }
        
        // Generate the Salesforce Identity API reCAPTCHA request parameters.
        return ReCaptchaParameterGenerationResult(
            nonEnterpriseReCaptchaToken: {
                switch(isReCaptchaEnterprise) {
                case true: return nil
                default: return reCaptchaToken
                }
            }(),
            enterpriseReCaptchaEvent: {
                switch(isReCaptchaEnterprise) {
                case true: return ReCaptchaEventRequestParameter(
                    token: reCaptchaToken,
                    siteKey: reCaptchaSiteKeyId,
                    projectId: googleCloudProjectId
                )
                    
                default: return nil
                }
            }()
        )
    }
    
    /// The result of generating Salesforce Identity API request reCAPTCHA parameters.
    private struct ReCaptchaParameterGenerationResult {
        /// The reCAPTCHA token parameter for non-enterprise reCAPTCHA
        var nonEnterpriseReCaptchaToken: String? = nil
        
        /// The reCAPTCHA event parameter for enterprise reCAPTCHA
        var enterpriseReCaptchaEvent: ReCaptchaEventRequestParameter? = nil
        
        /// The error native login result of the reCAPTCHA parameter generation or null for successful generation
        var result: NativeLoginResult? = nil
    }
    
    /// Generates a request body for the Headless Identity API authorization request.
    /// - Parameters:
    ///   - codeChallenge: The authorization code challenge
    private func generateAuthorizationRequestBody(
        codeChallenge: String
    ) -> String {
        return "\(kSFOAuthResponseType)=\(kSFOAuthCodeCredentialsParamName)&\(kSFOAuthClientId)=\(clientId)&\(kSFOAuthRedirectUri)=\(redirectUri)&\(kSFOAuthCodeChallengeParamName)=\(codeChallenge)"
    }
    
    /// Submits an authorization request to the Salesforce Identity API and, on success, submits the access
    /// token request.
    /// - Parameters:
    ///   - authRequestType: The Salesforce Identity API authorization request type header value
    ///   - otp: A one-time-password (OTP) previously issued by the Salesforce Identity API
    ///   - identifier: A OTP or request identifier previously issued by the Salesforce Identity API to
    /// match the provided OTP
    ///   - otpVerificationMethod: The OTP verification method used to obtain the identifier from the
    /// Salesforce Identity API
    /// - Returns: A native login result indicating success or one of several possible failures, including both
    /// in-app and Salesforce Identity API results
    public func submitAuthorizationRequest(
        authRequestType: String,
        otp: String,
        otpIdentifier: String,
        otpVerificationMethod: OtpVerificationMethod
    ) async -> NativeLoginResult
    {
        // Validate parameters.
        let trimmedOtp = otp.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Generate code verifier and code challenge.
        let codeVerifier = generateCodeVerifier()
        guard let codeChallenge = generateChallenge(
            codeVerifier: codeVerifier
        ) else {
            SFSDKCoreLogger().e(
                classForCoder,
                message: "Cannot generate code verifier due to a nil result.")
            return .unknownError
        }
        
        // Determine the OTP verification method.
        let otpVerificationMethodString = generateVerificationTypeHeaderValue(otpVerificationMethod: otpVerificationMethod)
        // Generate the authorization.
        guard let authorization = generateColonConcatenatedBase64String(
            value1: otpIdentifier,
            value2: trimmedOtp) else
        {
            SFSDKCoreLogger().e(
                classForCoder,
                message: "Unable to UTF-8 encode colon-concatenated string with values '\(otpIdentifier)' and '\(otp)' due to a nil encoding result.")
            return .unknownError
        }
        // Generate the authorization request headers.
        let authorizationRequestHeaders: NSMutableDictionary = [
            kSFOAuthRequestTypeParamName: authRequestType,
            kSFOAuthAuthVerificationTypeParamName: otpVerificationMethodString,
            kHttpHeaderContentType: kHttpPostContentType,
            kSFOAuthAuthorizationTypeParamName: "\(kSFOAuthAuthorizationTypeBasic) \(authorization)"]
        
        // Generate the authorization request body.
        let authorizationRequestBodyString = generateAuthorizationRequestBody(codeChallenge: codeChallenge)
        
        // Create the authorization request.
        let authorizationRequest = RestRequest(
            method: .POST,
            baseURL: loginUrl,
            path: kSFOAuthEndPointAuthorize,
            queryParams: nil)
        authorizationRequest.customHeaders = authorizationRequestHeaders
        authorizationRequest.endpoint = ""
        authorizationRequest.requiresAuthentication = false
        authorizationRequest.setCustomRequestBodyString(
            authorizationRequestBodyString,
            contentType: kHttpPostContentType)
        
        // Submit the authorization request and fetch the authorization response.
        let authorizationResponse = await withCheckedContinuation { continuation in
            RestClient.sharedGlobal.send(
                request: authorizationRequest
            ) { result in
                continuation.resume(returning: result)
            }
        }
        
        // React to the authorization response.
        return await submitAccessTokenRequest(
            authorizationResponse: authorizationResponse,
            codeVerifier: codeVerifier)
    }
    
    /// Reacts to a response from the Headless Identity API's authorization endpoint to initiate the token
    /// exchange, request a granted access token and create the user's session.
    /// - Parameters:
    ///   - authResult: The result from the Headless Identity API's authorization endpoint
    ///   - codeVerifier: The code verifier
    private func submitAccessTokenRequest(
        authorizationResponse: Result<RestResponse, RestClientError>,
        codeVerifier: String
    ) async -> NativeLoginResult {
        
        switch authorizationResponse {
            
        case .success(let successfulResponse): // Authorization success.
            do {
                // Decode the authorization response.
                let authorizationResponseBody = try successfulResponse.asDecodable(
                    type: AuthorizationResponseBody.self)
                let grantType = SalesforceManager.shared.useHybridAuthentication ? kSFOAuthGrantTypeHybridAuthorizationCode : kSFOAuthGrantTypeAuthorizationCode
                
                // Generate the access token request body.
                let tokenRequestBody = "\(kSFOAuthResponseTypeCode)=\(authorizationResponseBody.code)&\(kSFOAuthGrantType)=\(grantType)&\(kSFOAuthClientId)=\(clientId)&\(kSFOAuthRedirectUri)=\(redirectUri)&\(kSFOAuthCodeVerifierParamName)=\(codeVerifier)"
                
                // Create the access token request.
                let tokenRequest = RestRequest(
                    method: .POST,
                    baseURL: authorizationResponseBody.sfdc_community_url,
                    path: kSFOAuthEndPointToken,
                    queryParams: nil)
                tokenRequest.endpoint = ""
                tokenRequest.requiresAuthentication = false
                tokenRequest.setCustomRequestBodyString(
                    tokenRequestBody,
                    contentType: kHttpPostContentType)
                
                // Submit the access token request.
                let tokenResponse = await withCheckedContinuation { continuation in
                    RestClient.sharedGlobal.send(
                        request: tokenRequest
                    ) { tokenResponse in
                        continuation.resume(returning: tokenResponse)
                    }
                }
                
                // React to the token response.
                switch(tokenResponse) {
                    
                case .success(let tokenResponse): // Access token success.
                    // Create the successfully authorized user's session.
                    UserAccountManager.shared.createNativeUserAccount(
                        with: tokenResponse.asData(),
                        scene:scene)
                    return .success
                    
                case .failure(let error): // Access token failure.
                    SFSDKCoreLogger().e(
                        classForCoder,
                        message: "error: \(error)")
                    return .unknownError
                }
            } catch {
                SFSDKCoreLogger().e(classForCoder, message: "error: \(error)")
                return .unknownError
            }
            
        case .failure(let error): // Authorization failure.
            // You will catch the error here in the event of auth failure or if the user cannot login this way.
            SFSDKCoreLogger().e(classForCoder, message: "authentication error: \(error)")
            return .invalidCredentials
        }
    }
    
    // MARK: Private String Parameter Validation
    
    /// Validates a string is a valid email address.
    /// - Parameters:
    ///   - string: The string to validate
    /// - Returns: nil for valid email addresses - The invalid email login result otherwise
    ///
    func mapInvalidEmailAddressToResult(_ string: String) -> NativeLoginResult? {
        let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        )
        let range = NSRange(
            string.startIndex..<string.endIndex,
            in: string
        )
        let matches = detector?.matches(
            in: string,
            options: [],
            range: range
        )
        guard let match = matches?.first, matches?.count == 1 else {
            return .invalidEmail
        }
        guard match.url?.scheme == "mailto", match.range == range else {
            return .invalidEmail
        }
        
        return nil
    }
    
    /// Validates a string is a valid password.
    /// - Parameters:
    ///    - string: The string to validate
    /// - Returns: nil for valid passwords - The invalid password login result otherwise
    func mapInvalidPasswordToResult(_ string: String) -> NativeLoginResult? {
        switch (!isValidPassword(password: string.trimmingCharacters(in: .whitespacesAndNewlines))) {
        case true: return .invalidPassword
        default : return nil
        }
    }
    
    /// Validates this string is a valid username.
    /// - Parameters:
    ///   - string: The string to validate
    /// - Returns: nil for valid usernames - The invalid username login result otherwise
    func mapInvalidUsernameToResult(_ string: String) -> NativeLoginResult? {
        switch (!isValidUsername(username: string.trimmingCharacters(in: .whitespacesAndNewlines))) {
        case true: return .invalidUsername
        default:  return nil
        }
    }
}
