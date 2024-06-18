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
    /// Email address is not a valid format
    case invalidEmail
    
    /// Username does not meet Salesforce criteria (length, email format, ect)
    case invalidUsername
    
    /// Password does not meet the weakest Salesforce criteria
    case invalidPassword
    
    /// Username/password combination is incorrect
    case invalidCredentials
    
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
    
    // MARK: Salesforce Identity API Headless Registration Flow
    
    ///  Submits a request to start a user registration to the Salesforce Identity API headless registration
    ///  flow.  This fulfills step four of the headless registration flow.
    ///
    ///  See https://help.salesforce.com/s/articleView?id=sf.remoteaccess_headless_registration_public_clients.htm&type=5
    ///
    /// - Parameters:
    ///   - email: The user-entered email address
    ///   - firstName: The user-entered first name
    ///   - lastName: The user-entered last name
    ///   - username: A valid Salesforce username or email
    ///   - newPassword: The user-entered new password
    ///   - reCaptchaToken: A reCAPTCHA token provided by the reCAPTCHA SDK
    ///   - otpVerificationMethod: The delivery method for the OTP
    ///  - Returns: The start registration result with the request identifier returned by the Salesforce
    ///  Identity API and a native login result indicating success or one of several possible failures,
    ///  including both in-app and Salesforce Identity API results
    @objc func startRegistration(
        email: String,
        firstName: String,
        lastName: String,
        username: String,
        newPassword: String,
        reCaptchaToken: String,
        otpVerificationMethod: OtpVerificationMethod
    ) async -> StartRegistrationResult
    
    ///  Submits a request to complete a user registration to the Salesforce Identity API headless
    ///  registration flow.  This fulfills step eight of the headless registration flow.
    ///
    ///  See https://help.salesforce.com/s/articleView?id=sf.remoteaccess_headless_registration_public_clients.htm&type=5
    ///
    /// - Parameters:
    ///    - otp: A user-entered one-time-password
    ///    - requestIdentifier: The request identifier issued by the Salesforce Identity API headless
    ///    registration flow in the start registration method
    ///    - otpVerificationMethod: The one-time-password verification method used to obtain the
    ///    OTP identifier
    ///  - Returns: A native login result indicating success or one of several possible failures, including
    ///  both in-app and Salesforce Identity API results
    @objc func completeRegistration(
        otp: String,
        requestIdentifier: String,
        otpVerificationMethod: OtpVerificationMethod
    ) async -> NativeLoginResult
    
    // MARK: Salesforce Identity API Headless Forgot Password Flow
    
    /// Submits a request to start a password reset to the Salesforce Identity API headless forgot password
    /// flow.  This fulfills step one of the headless forgot password flow.
    ///
    /// See https://help.salesforce.com/s/articleView?id=sf.remoteaccess_headless_forgot_password_flow.htm&type=5
    ///
    /// - Parameters:
    ///   - username: A valid Salesforce username or email
    ///   - reCaptchaToken: A reCAPTCHA token provided by the reCAPTCHA SDK
    /// - Returns: A native login result indicating success or one of several possible failures, including
    ///  both in-app and Salesforce Identity API results
    @objc func startPasswordReset(
        username: String,
        reCaptchaToken: String
    ) async -> NativeLoginResult
    
    /// Submits a request to complete a password reset to the Salesforce Identity API headless forgot
    /// password flow. This fulfills step four of the headless forgot password flow.
    ///
    /// See https://help.salesforce.com/s/articleView?id=sf.remoteaccess_headless_forgot_password_flow.htm&type=5
    ///
    /// - Parameters:
    ///   - username: A valid Salesforce username or email
    ///   - otp: A user-entered one-time-password
    ///   - newPassword: The user-entered new password
    /// - Returns: A native login result indicating success or one of several possible failures, including
    /// both in-app and Salesforce Identity API results
    @objc func completePasswordReset(
        username: String,
        otp: String,
        newPassword: String
    ) async -> NativeLoginResult
    
    // MARK: Salesforce Identity API Headless, Password-Less Login Via One-Time-Passcode
    
    /// Submits a request to start password-less login via one-time-passcode to the Salesforce Identity API
    /// headless, password-less login flow. This fulfills step three of the headless, password-less login flow.
    ///
    /// See https://help.salesforce.com/s/articleView?id=sf.remoteaccess_headless_passwordless_login_public_clients.htm&type=5
    ///
    /// - Parameters:
    ///   - username: A valid Salesforce username or email
    ///   - reCaptchaToken: A reCAPTCHA token provided by the reCAPTCHA SDK
    ///   - otpVerificationMethod: The delivery method for the OTP
    /// - Returns: An OTP request result with the overall login result and the OTP identifier for
    /// successful OTP requests
    ///
    @objc func submitOtpRequest(
        username: String,
        reCaptchaToken: String,
        otpVerificationMethod: OtpVerificationMethod) async -> OtpRequestResult
    
    /// Submits a request to complete a password-less login to the Salesforce Identity API headless,
    /// password-less login flow. This fulfills steps eight, eleven and thirteen of the headless password-less
    /// login flow.
    ///
    /// See https://help.salesforce.com/s/articleView?id=sf.remoteaccess_headless_passwordless_login_public_clients.htm&type=5
    ///
    /// - Parameters:
    ///   - otp: A user-entered one-time-password
    ///   - otpIdentifier: The one-time-password identifier issued by the Salesforce Identity API
    ///   headless, password-less login flow in the start password-less authorization method.
    ///   - otpVerificationMethod: The one-time-password verification method used to obtain the
    ///   OTP identifier
    /// - Returns: A native login result indicating success or one of several possible failures, including
    /// both in-app and Salesforce Identity API results
    ///
    @objc func submitPasswordlessAuthorizationRequest(
        otp: String,
        otpIdentifier: String,
        otpVerificationMethod: OtpVerificationMethod
    ) async -> NativeLoginResult
}

// MARK: Salesforce Identity API Headless Registration Flow Data Types

/// An Objective-C compatible start registration result.
@objc(SFStartRegistrationResult)
@objcMembers
public class StartRegistrationResult: NSObject {
    
    /// The overall result of the start registration request
    public let nativeLoginResult: NativeLoginResult
    
    /// On success result, the email address provided by the Salesforce Identity API
    public let email: String?
    
    /// On success result, the request identifier provided by the Salesforce Identity API
    public let requestIdentifier: String?
    
    init(
        nativeLoginResult: NativeLoginResult,
        email: String? = nil,
        requestIdentifier: String? = nil
    ) {
        self.nativeLoginResult = nativeLoginResult
        self.email = email
        self.requestIdentifier = requestIdentifier
    }
}

// MARK: Salesforce Identity API Headless, Password-Less Login Via One-Time-Passcode Data Types

/// An Objective-C compatible OTP request result
@objc(SFOtpRequestResult)
@objcMembers
public class OtpRequestResult: NSObject {
    
    /// The overall result of the OTP request
    public let nativeLoginResult: NativeLoginResult
    
    /// On success result, the OTP identifier provided by the API
    public let otpIdentifier: String?
    
    init(
        nativeLoginResult: NativeLoginResult,
        otpIdentifier: String? = nil
    ) {
        self.nativeLoginResult = nativeLoginResult
        self.otpIdentifier = otpIdentifier
    }
}

// MARK: Common Data Types

/// The possible OTP verification methods.
@objc public enum OtpVerificationMethod: Int {
    case email
    case sms
}
