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
    @objc let clientId: String
    @objc let redirectUri: String
    @objc let loginUrl: String
    
    struct AuthorizationResponse: Codable {
        let sfdc_community_url: String
        let sfdc_community_id: String
        let code: String
    }
    
    @objc internal init(clientId: String, redirectUri: String, loginUrl: String) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.loginUrl = loginUrl
    }
    
    public func login(username: String, password: String) async -> NativeLoginResult {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !isValidUsername(username: trimmedUsername) {
            return .invalidUsername
        }
        
        if !isValidPassword(password: trimmedPassword) {
            return .invalidPassword
        }
        
        guard let creds: Data = "\(trimmedUsername):\(trimmedPassword)".data(using: .utf8) else {
            SFSDKCoreLogger().e(self.classForCoder, message: "Username or Password contain non-UTF8 characters.")
            return .invalidCredentials
        }
        let encodedCreds = urlSafeBase64Encode(data: creds)
        let authRequest = RestRequest(method: RestRequest.Method.POST, baseURL: loginUrl, path: kSFOAuthEndPointAuthorize, queryParams: nil)
        let customHeaders: NSMutableDictionary = [kSFOAuthRequestTypeParamName: kSFOAuthRequestTypeNamedUser,
                                                  kHttpHeaderContentType: kHttpPostContentType,
                                                  kSFOAuthAuthorizationTypeParamName: "\(kSFOAuthAuthorizationTypeBasic) \(encodedCreds)"]
        
        let codeVerifier = generateCodeVerifier()
        guard let challenge = generateChallenge(codeVerifier: codeVerifier) else { return .unknownError }
        let authRequestBody = "\(kSFOAuthResponseType)=\(kSFOAuthCodeCredentialsParamName)&\(kSFOAuthClientId)=\(self.clientId)&\(kSFOAuthRedirectUri)=\(redirectUri)&\(kSFOAuthCodeChallengeParamName)=\(challenge)"
        authRequest.customHeaders = customHeaders
        authRequest.setCustomRequestBodyString(authRequestBody, contentType: kHttpPostContentType)
        authRequest.requiresAuthentication = false
        authRequest.endpoint = ""
   
        // First REST Call - Authorization
        let authResult = await withCheckedContinuation { continuation in
            RestClient.sharedGlobal.send(request: authRequest) { result in
                continuation.resume(returning: result)
            }
        }
        
        switch authResult {
        case .success(let authResponse):
            do {
                let data = try authResponse.asDecodable(type: AuthorizationResponse.self)
                let tokenRequest = RestRequest(method: RestRequest.Method.POST, baseURL: data.sfdc_community_url, path: kSFOAuthEndPointToken, queryParams: nil)
                let tokenRequestBody = "\(kSFOAuthResponseTypeCode)=\(data.code)&\(kSFOAuthGrantType)=\(kSFOAuthGrantTypeAuthorizationCode)&\(kSFOAuthClientId)=\(self.clientId)&\(kSFOAuthRedirectUri)=\(self.redirectUri)&\(kSFOAuthCodeVerifierParamName)=\(codeVerifier)"
                
                tokenRequest.setCustomRequestBodyString(tokenRequestBody, contentType: kHttpPostContentType)
                tokenRequest.requiresAuthentication = false
                tokenRequest.endpoint = ""
                
                // Second REST Call - token request with code verifier
                let tokenResult = await withCheckedContinuation { continuation in
                    RestClient.sharedGlobal.send(request: tokenRequest) { tokenResult in
                        continuation.resume(returning: tokenResult)
                    }
                }
                
                switch(tokenResult) {
                case .success(let tokenResponse):
                    UserAccountManager.shared.createNativeUserAccount(with: tokenResponse.asData())
                    return .success
                case .failure(let error):
                    SFSDKCoreLogger().e(self.classForCoder, message: "error: \(error)")
                    return .unknownError
                }
            } catch {
                SFSDKCoreLogger().e(self.classForCoder, message: "error: \(error)")
                return .unknownError
            }
        case .failure(let error):
            // You will catch the error here in the event of auth failure or if the use cannot login this way.
            SFSDKCoreLogger().e(self.classForCoder, message: "authenication error: \(error)")
            return .invalidCredentials
        }
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
        
        if (UserAccountManager.shared.isIDPEnabled) {
            return true
        }
        
        guard let totalAccounts = UserAccountManager.shared.userAccounts()?.count else { return false }
        return (totalAccounts > 0 && UserAccountManager.shared.currentUserAccount != nil)
    }
    
    public func cancelAuthentication() {
        if (shouldShowBackButton()) {
            UserAccountManager.shared.stopCurrentAuthentication()
            
            if (UserAccountManager.shared.isIDPEnabled) {
                SFSDKWindowManager.shared().authWindow(nil).viewController?.dismiss(animated: false)
            } else {
                SFSDKWindowManager.shared().authWindow(nil).viewController?.presentedViewController?.dismiss(animated: false, completion: {
                    SFSDKWindowManager.shared().authWindow(nil).dismissWindow()
                })
            }
        }
    }
    
    public func biometricAuthenticationSuccess() {
        let bioAuthMgr = BiometricAuthenticationManagerInternal.shared
        
        if bioAuthMgr.enabled && bioAuthMgr.locked {
            SFSDKCoreLogger.i(self.classForCoder, message: "Native Login biometric authentication success.")
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
}

