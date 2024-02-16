//
//  NativeLoginManager.swift
//  SalesforceSDKCore
//
//  Created by Brandon Page on 1/3/24.
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
 
@objc public enum NativeLoginResult: Int {
    case invalidUsername         // Username does not meet Salesforce criteria (length, email format, ect).
    case invalidPassword         // Password does not meet the weakest Salesforce criteria.
    case invalidCredentials      // Username/password combination is incorrect.
    case unknownError
    case success
}

@objc(SFNativeLoginManager)
public protocol NativeLoginManager {
    
    /// Initiate a login with user provided username and password.
    ///
    /// - Parameters:
    ///   - username: User provided Salesforce username.
    ///   - password: User provided Salesforce password.
    /// - Returns: NativeLoginResult
    @objc func login(username: String, password: String) async -> NativeLoginResult
    
    /// Initiates web based authenticatioin.
    @objc func fallbackToWebAuthentication()
    
    /// If the native login view should show a back button.
    @objc func shouldShowBackButton() -> Bool
    
    /// Cancels authentication if appropriate.  Use this function to
    /// navigate back to the app if the user backs out of authentication
    /// when another user is logged in.
    @objc func cancelAuthentication()
    
    
    /// Biometric Authentication Helpers
    
    /// The username of the locked account.  Can be used to pre-populate the username field
    /// or in a message telling the user which account biometric will unlock.
    ///
    /// - Returns: The username of the locked user or nil.
    @objc func getBiometricAuthenticationUsername() -> String?
    
    /// Signals that the user has preformed a successful biometric challenge.
    /// Used to unlock the app in the case of Biometric Authentication.
    ///
    /// Note: this call will dismiss your login view controller.
    @objc func biometricAuthenticationSuccess()
}
