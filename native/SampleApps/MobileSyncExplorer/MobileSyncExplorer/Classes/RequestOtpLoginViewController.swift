//
//  RequestOtpLoginViewController.swift
//  MobileSyncExplorer
//
//  Created by Eric Johnson on 1/29/24.
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
import SalesforceSDKCore
import UIKit


@objc
class RequestOtpLoginViewController : UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    
    // MARK: LoginViewController Implementation
    
    
    /// The username text field.
    private let userNameTextField = UITextField()
    
    /// The OTP delivery method picker.
    private let otpDeliveryMethodPickerView = UIPickerView()
    
    /// The submit button.
    private let submitButton = UIButton()
    
    /// The user-selected OTP delivery method.
    private var otpVerificationMethod = OtpVerificationMethod.sms
    
    /// The reCAPTCHA token, which is provided by the view controller's owner.
    @objc
    var recaptchaToken: String? = nil
    
    
    /// Submits a request for a one-time-passcode to the Salesforce headless password-less login flow.
    /// - Parameters:
    ///   - username: The user-entered Salesforce username
    private func submitOtpRequest(username: String) {
        let appDelegate = (UIApplication.shared.delegate as? AppDelegate)
        
        // Execute reCAPTCHA for a new token.
        appDelegate?.executeReCaptcha { recaptchaToken in
            if let recaptchaTokenUnwrapped = recaptchaToken {
                Task {
                    // Submit the OTP request with the acquired reCAPTCHA token and username.
                    async let otpRequestResult = SalesforceManager.shared.nativeLoginManager().submitOtpRequest(
                        username: username,
                        reCaptchaToken: recaptchaTokenUnwrapped,
                        otpVerificationMethod: self.otpVerificationMethod
                    )
                    
                    do {
                        guard let otpIdentifier = try await otpRequestResult.otpIdentifier else { return }
                        self.presentOtpVerification(
                            otpIdentifier: otpIdentifier,
                            otpVerificationMethod: self.otpVerificationMethod
                        )
                    } catch let error {
                        print("Cannot request headless, password-less login one-time-passcode due to an error with description '\(error.localizedDescription)'.")
                    }
                }
            }
        }
    }
    
    /// Presents a view for user-entry of the previously requested headless, password-less one-time-passcode.
    /// - Parameters:
    ///   - otpIdentifier: The OTP identifier issued by the Headless Identity API
    ///   - otpVerificationMethod The OTP verification method used to obtain the OTP identifier
    private func presentOtpVerification(
        otpIdentifier: String,
        otpVerificationMethod: OtpVerificationMethod
    ) {
        present(
            SubmitOtpLoginViewController(
                otpIdentifier: otpIdentifier,
                otpVerificationMethod: otpVerificationMethod),
            animated: true)
    }
    
    
    // MARK: UIViewController Implementation
    
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        
        // Layout the username text field at the top.
        if let superview = userNameTextField.superview {
            userNameTextField.centerXAnchor.constraint(
                equalTo: superview.centerXAnchor
            ).isActive = true
            userNameTextField.centerYAnchor.constraint(
                equalTo: superview.centerYAnchor
            ).isActive = true
            userNameTextField.leadingAnchor.constraint(
                equalTo: superview.leadingAnchor,
                constant: 44.0
            ).isActive = true
            userNameTextField.trailingAnchor.constraint(
                equalTo: superview.trailingAnchor,
                constant: -44.0
            ).isActive = true
        }
        
        // Layout the OTP delivery method picker in the middle.
        otpDeliveryMethodPickerView.centerXAnchor.constraint(
            equalTo: userNameTextField.centerXAnchor
        ).isActive = true
        otpDeliveryMethodPickerView.heightAnchor.constraint(
            equalToConstant: 44.0
        ).isActive = true
        otpDeliveryMethodPickerView.topAnchor.constraint(
            equalTo: userNameTextField.bottomAnchor,
            constant: 22.0
        ).isActive = true
        
        // Layout the submit button at the bottom.
        submitButton.centerXAnchor.constraint(
            equalTo: userNameTextField.centerXAnchor
        ).isActive = true
        submitButton.heightAnchor.constraint(
            equalToConstant: 44.0
        ).isActive = true
        submitButton.topAnchor.constraint(
            equalTo: otpDeliveryMethodPickerView.bottomAnchor,
            constant: 22.0
        ).isActive = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure the root view.
        view.backgroundColor = .white
        
        // Configure the user name text field.
        userNameTextField.placeholder = "Salesforce Username"
        userNameTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure the OTP delivery method picker.
        otpDeliveryMethodPickerView.backgroundColor = .white
        otpDeliveryMethodPickerView.dataSource = self
        otpDeliveryMethodPickerView.delegate = self
        otpDeliveryMethodPickerView.translatesAutoresizingMaskIntoConstraints = false
        otpDeliveryMethodPickerView.selectRow(
            1,
            inComponent: 0,
            animated: false
        )
        
        // Configure the submit button.
        submitButton.backgroundColor = .lightGray
        submitButton.setTitle(
            "Request Passcode",
            for: UIControlState.normal)
        submitButton.addTarget(
            self,
            action: #selector(onRequestPasscodeTapped(_:)),
            for: .touchUpInside
        )
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Assemble view.
        view.addSubview(userNameTextField)
        view.addSubview(otpDeliveryMethodPickerView)
        view.addSubview(submitButton)
        
        // Layout.
        view.layoutIfNeeded()
    }
    
    
    // MARK: User Interface Events
    
    
    @objc
    private func onRequestPasscodeTapped(
        _ sender: UIButton
    ) {
        guard let username = userNameTextField.text else { return }
        submitOtpRequest(username: username)
    }
    
    
    // MARK: UIPickerViewDataSource Implementation
    
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 2
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return switch(row) {
        case 0: "Email"
        case 1: "SMS"
        default: "SMS"
        }
    }
    
    
    // MARK: UIPickerViewDelegate Implementation
    
    
    func pickerView(
        _ pickerView: UIPickerView,
        didSelectRow row: Int,
        inComponent component: Int
    ) {
        
        otpVerificationMethod = switch(row) {
        case 0: .email
        case 1: .sms
        default: .sms
        }
    }
}
