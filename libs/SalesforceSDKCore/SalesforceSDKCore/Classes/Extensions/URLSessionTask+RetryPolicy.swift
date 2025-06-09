//
//  URLSession+RetryPolicy.swift
//  SalesforceSDKCore
//
//  Created by Riley Crebs on 6/9/25.
//  Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
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

extension URLSessionTask {
    @objc
    public func shouldRetry(with responseData: Data? = nil) -> Bool {
        let response = self.response as? HTTPURLResponse
        let statusCode = response?.statusCode ?? 0
        
        // most calls return 401 if oauth access token is not valid
        let isNotAuthorized = statusCode == 401
        
        // service/oauth2 calls return 403 with Bad_OAuth_Token response if oauth access is not valid
        let hasBadOAuthToken = statusCode == 403
        && ((self.originalRequest?.url?.path().hasPrefix("/services/oauth2")) != nil)
        && String(data: responseData ?? Data(), encoding: .utf8) == "Bad_OAuth_Token"
        
        if isNotAuthorized || hasBadOAuthToken {
            SFSDKCoreLogger.d(Self.self, message: "response request path: \(self.originalRequest?.url?.path() ?? "")")
            SFSDKCoreLogger.d(Self.self, message: "response status code: \(statusCode)")
        }
        
        // Do not refresh token if biometric authentication lock is enabled
        return (isNotAuthorized || hasBadOAuthToken) && !BiometricAuthenticationManagerInternal.shared.locked
    }
}
