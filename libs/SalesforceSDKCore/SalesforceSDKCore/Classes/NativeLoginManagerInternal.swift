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

/*
 * This class is internal to the Mobile SDK - don't instantiate in your application code
 * It's only public to be visible from the obj-c code when the library is compiled as a framework
 * See https://developer.apple.com/documentation/swift/importing-swift-into-objective-c#Import-Code-Within-a-Framework-Target
 */

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
    
    @objc public func login(username: String, password: String) -> Bool {
        // TODO: check username, password, clientId, redirect uri, login url for validity
        
        // TODO:  get kSFOAuthEndPointAuthorize and other consants from source
        
        guard let creds: Data = "\(username):\(password)".data(using: .utf8) else {
            // log
            return false
        }
        let encodedCreds = urlSafeBase64Encode(data: creds)
        let authRequest = RestRequest(method: RestRequest.Method.POST, baseURL: loginUrl, path: "/services/oauth2/authorize", queryParams: nil)
        let customHeaders: NSMutableDictionary = ["Auth-Request-Type": "Named-User",
                                                  "Content-Type": "application/x-www-form-urlencoded",
                                                  "Authorization": "Basic \(encodedCreds)"]
        
        let codeVerifier = generateCodeVerifier()
        guard let challenge = generateChallenge(codeVerifier: codeVerifier) else { return false }
        let authRequestBody = "response_type=code_credentials&client_id=\(clientId)&redirect_uri=\(redirectUri)&code_challenge=\(challenge)"
        authRequest.customHeaders = customHeaders
        authRequest.setCustomRequestBodyString(authRequestBody, contentType: "application/x-www-form-urlencoded")
        authRequest.requiresAuthentication = false
        authRequest.endpoint = ""
        
        RestClient.sharedGlobal.send(request: authRequest, { authResult in
            switch(authResult) {
            case .success(let authResponse):
                do {
                    let data = try authResponse.asDecodable(type: AuthorizationResponse.self)
                    let tokenRequest = RestRequest(method: RestRequest.Method.POST, baseURL: data.sfdc_community_url, path: "/services/oauth2/token", queryParams: nil)
                    let tokenRequestBody = "code=\(data.code)&grant_type=authorization_code&client_id=\(self.clientId)&redirect_uri=\(self.redirectUri)&code_verifier=\(codeVerifier)"
                    
                    tokenRequest.setCustomRequestBodyString(tokenRequestBody, contentType: "application/x-www-form-urlencoded")
                    tokenRequest.requiresAuthentication = false
                    tokenRequest.endpoint = ""
                    
                    RestClient.sharedGlobal.send(request: tokenRequest) { tokenResult in
                        switch(tokenResult) {
                        case .success(let tokenResponse):
                            UserAccountManager.shared.createNativeUserAccount(with: tokenResponse.asData())
                        case .failure(let error):
                            SFSDKCoreLogger().e(self.classForCoder, message: "error: \(error)")
                        }
                    }
                } catch {
                    SFSDKCoreLogger().e(self.classForCoder, message: "error: \(error)")
                }
            case .failure(let error):
                // you will get auth failure here if the use cannot login this way
                SFSDKCoreLogger().e(self.classForCoder, message: "error: \(error)")
            }
        })
        
        return false
    }
    
    @objc public func fallbackToWebview() {
        
    }
    
    private func urlSafeBase64Encode(data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func generateCodeVerifier() -> String {
        let randomData = SFSDKCryptoUtils.randomByteData(withLength: 128)
        return urlSafeBase64Encode(data: randomData)
    }
    
    private func generateChallenge(codeVerifier: String) -> String? {
        guard let data = codeVerifier.data(using: .utf8) else { return nil }
        let hash = SHA256.hash(data: data)
        return urlSafeBase64Encode(data: hash.dataRepresentation)
    }
}

