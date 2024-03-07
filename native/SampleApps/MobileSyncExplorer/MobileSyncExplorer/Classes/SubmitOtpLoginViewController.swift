//
//  SubmitOtpLoginViewController.swift
//  MobileSyncExplorer
//
//  Created by Eric Johnson on 3/6/24.
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
class SubmitOtpLoginViewController : UIViewController {
    
    // MARK: OTP View Controller Implementation - Data Properties
    
    /// The OTP identifier issued by the Headless Identity API
    private let otpIdentifier: String
    
    /// The OTP verification method used to obtain the OTP identifier
    private let otpVerificationMethod: OtpVerificationMethod
    
    // MARK: OTP View Controller Implementation - User Interface
    
    /// The one-time-passcode text field.
    private let otpTextField = UITextField()
    
    /// The submit button.
    private let submitButton = UIButton()
    
    // MARK: OTP View Controller Implementation
    
    init(
        otpIdentifier: String,
        otpVerificationMethod: OtpVerificationMethod
    ) {
        self.otpIdentifier = otpIdentifier
        self.otpVerificationMethod = otpVerificationMethod
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: UIViewController Implementation
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        
        // Layout the username text field at the top.
        if let superview = otpTextField.superview {
            otpTextField.centerXAnchor.constraint(
                equalTo: superview.centerXAnchor
            ).isActive = true
            otpTextField.centerYAnchor.constraint(
                equalTo: superview.centerYAnchor
            ).isActive = true
            otpTextField.leadingAnchor.constraint(
                equalTo: superview.leadingAnchor,
                constant: 44.0
            ).isActive = true
            otpTextField.trailingAnchor.constraint(
                equalTo: superview.trailingAnchor,
                constant: -44.0
            ).isActive = true
        }
        
        // Layout the submit button at the bottom.
        submitButton.centerXAnchor.constraint(
            equalTo: otpTextField.centerXAnchor
        ).isActive = true
        submitButton.heightAnchor.constraint(
            equalToConstant: 44.0
        ).isActive = true
        submitButton.topAnchor.constraint(
            equalTo: otpTextField.bottomAnchor,
            constant: 22.0
        ).isActive = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure the root view.
        view.backgroundColor = .white
        
        // Configure the user name text field.
        otpTextField.placeholder = "Passcode"
        otpTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure the submit button.
        submitButton.backgroundColor = .lightGray
        submitButton.setTitle(
            "Submit Passcode",
            for: UIControlState.normal)
        submitButton.addTarget(
            self,
            action: #selector(onSubmitPasscodeTapped(_:)),
            for: .touchUpInside
        )
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Assemble view.
        view.addSubview(otpTextField)
        view.addSubview(submitButton)
        
        // Layout.
        view.layoutIfNeeded()
    }
    
    // MARK: User Interface Events
    
    @objc
    private func onSubmitPasscodeTapped(
        _ sender: UIButton
    ) {
        guard let otp = otpTextField.text else { return }
        Task {
            async let otpRequestResult = SalesforceManager.shared.nativeLoginManager().submitPasswordlessAuthorizationRequest(
                otp: otp,
                otpIdentifier: otpIdentifier,
                otpVerificationMethod: otpVerificationMethod
            )
        }
    }
}
