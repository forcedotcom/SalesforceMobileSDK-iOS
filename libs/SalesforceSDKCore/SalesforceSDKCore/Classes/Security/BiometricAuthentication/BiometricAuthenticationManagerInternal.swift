//
//  BiometricAuthenticationManagerInternal.swift
//  SalesforceSDKCore
//
//  Created by Brandon Page on 4/24/23.
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

import Foundation
import LocalAuthentication

/*
 * This class is internal to the Mobile SDK - don't instantiate in your application code
 * It's only public to be visible from the obj-c code when the library is compiled as a framework
 * See https://developer.apple.com/documentation/swift/importing-swift-into-objective-c#Import-Code-Within-a-Framework-Target
 */

@objc(SFBiometricAuthenticationManagerInternal)
public class BiometricAuthenticationManagerInternal: NSObject, BiometricAuthenticationManager {
    @objc public static let shared = BiometricAuthenticationManagerInternal()
    
    public var enabled: Bool {
        get {
            return readBioAuhPolicy()?.hasPolicy ?? false
        }
    }
    
    public var locked = false
    
    internal var backgroundTimestamp: Double = 0
    // This is a local var so it can be stubbed for tests
    internal var laContext = LAContext()
    private let kBioAuthPolicyIdentifier = "com.salesforce.security.bioauthpolicy"
    private let kBioAuthEnabledIdentifier = "com.salesforce.security.bioauth"
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            // Do not set new background timestamp if we are already locked
            if (!(self?.locked ?? true)) {
                self?.backgroundTimestamp = Date().timeIntervalSince1970
            }
        }
    }
    
    /// Locks the screen if necessary
    @objc public func handleAppForeground() {
        if shouldLock() {
            lock()
        }
    }
    
    @objc internal func shouldLock() -> Bool {
        if let policy = readBioAuhPolicy() {
            if (policy.hasPolicy && policy.timeout > 0) {
                let timeNow = Date().timeIntervalSince1970
                return (timeNow - backgroundTimestamp) > Double(policy.timeout * 60)
            }
        }
        
        return false
    }
    
    @objc public func storePolicy(userAccount: UserAccount, hasMobilePolicy: Bool, sessionTimeout: Int32) {
        let policyData = try! JSONEncoder().encode(
            BioAuthPolicy(hasPolicy: hasMobilePolicy, timeout: sessionTimeout)
        )
        let result = KeychainHelper.write(service: kBioAuthPolicyIdentifier, data: policyData, account: userAccount.idData.userId)
        if result.success {
            SFSDKCoreLogger.i(BiometricAuthenticationManagerInternal.self, message: "Biometric authentication policy stored for user.")
        } else {
            SFSDKCoreLogger.e(BiometricAuthenticationManagerInternal.self, message: "Failed to store biometric authentication policy for user.")
        }
    }
    
    private func storePolicy(policy: BioAuthPolicy) {
        guard let userAccount = UserAccountManager.shared.currentUserAccount else {
            return
        }
        
        let policyData = try! JSONEncoder().encode(policy)
        let result = KeychainHelper.write(service: kBioAuthPolicyIdentifier, data: policyData, account: userAccount.idData.userId)
        if result.success {
            SFSDKCoreLogger.i(BiometricAuthenticationManagerInternal.self, message: "Biometric authentication policy stored for user.")
        } else {
            SFSDKCoreLogger.e(BiometricAuthenticationManagerInternal.self, message: "Failed to store biometric authentication policy for user.")
        }
    }
    
    private func readBioAuhPolicy() -> BioAuthPolicy? {
        guard let userAccount = UserAccountManager.shared.currentUserAccount else {
            return nil
        }
        
        return readBioAuthPolicy(userId: userAccount.idData.userId)
    }
    
    private func readBioAuthPolicy(userId: String) -> BioAuthPolicy? {
        let result = KeychainHelper.read(service: kBioAuthPolicyIdentifier, account: userId)
        if let data = result.data, result.success {
            do {
                return try JSONDecoder().decode(BioAuthPolicy.self, from: data)
            } catch {
                SFSDKCoreLogger.e(BiometricAuthenticationManager.self, message: "Failed to read biometric authentication policy.")
            }
        }
        
        return nil
    }
    
    public func lock() {
        locked = true
        NotificationCenter.default.post(name: Notification.Name(rawValue: kSFBiometricAuthenticationFlowWillBegin), object: nil)
        
        // Open the Login Screen
        _ = UserAccountManager.shared.login { result in
            switch result {
            case .success((_, _)):
                self.unlockPostProcessing()
                SFSDKCoreLogger.i(BiometricAuthenticationManagerInternal.self, message: "Biometric authentication success.")
                break
            case .failure(let error):
                SFSDKCoreLogger.e(BiometricAuthenticationManagerInternal.self, message: "Biometric authentication failed: \(error)")
            }
        }
    }
    
    public func biometricOptIn(optIn: Bool) {
        if var policy = readBioAuhPolicy() {
            policy.optIn = optIn
            storePolicy(policy: policy)
        }
    }
    
    public func hasBiometricOptedIn() -> Bool {
        return readBioAuhPolicy()?.optIn ?? false
    }
    
    public func presentOptInDialog(viewController: UIViewController) {
        let dialog = UIAlertController(title: SFSDKResourceUtils.localizedString("bioOptInPromptTitle"), message: SFSDKResourceUtils.localizedString("bioOptInPromptMessage"), preferredStyle: .alert)
        let enableAction = UIAlertAction(title: SFSDKResourceUtils.localizedString("bioPromptEnable"), style: .default) { _ in
            self.biometricOptIn(optIn: true)
        }
        let cancelAction = UIAlertAction(title: SFSDKResourceUtils.localizedString("bioPromtpCancel"), style: .default) { _ in
            self.biometricOptIn(optIn: false)
        }
        dialog.addAction(cancelAction)
        dialog.addAction(enableAction)
        viewController.present(dialog, animated: true)
    }
    
    public func enableNativeBiometricLoginButton(enabled: Bool) {
        if var policy = readBioAuhPolicy() {
            policy.nativeLoginButton = enabled
            storePolicy(policy: policy)
        }
    }
    
    @objc public func showNativeLoginButton() -> Bool {
        var error: NSError?
        if (!laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)) {
            return false
        }
        
        if let policy = readBioAuhPolicy() {
            if (policy.hasPolicy && locked && hasBiometricOptedIn()) {
                // true if not specified
                return readBioAuhPolicy()?.nativeLoginButton ?? true
            }
        }
        
        return false
    }
    
    @objc public func cleanup(user: UserAccount) {
        _ = KeychainHelper.remove(service: kBioAuthPolicyIdentifier, account: user.idData.userId)
        locked = false
    }
    
    @objc public func checkForPolicy(userId: String) -> Bool {
        let result = KeychainHelper.read(service: kBioAuthPolicyIdentifier, account: userId)
        if let data = result.data, result.success {
            do {
                return try JSONDecoder().decode(BioAuthPolicy.self, from: data).hasPolicy   
            } catch {
                SFSDKCoreLogger.e(BiometricAuthenticationManager.self, message: "Failed to read biometric authentication policy.")
            }
        }
        
        return false
    }
    
    @objc public func presentBiometric(scene: UIScene) {
        laContext.localizedCancelTitle = SFSDKResourceUtils.localizedString("usePassword")
        var error: NSError?
        if (laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)) {
            Task {
                do {
                    try await laContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: SFSDKResourceUtils.localizedString("biometricReason"))
                    
                    // Refresh token and unlock
                    let accountManager = UserAccountManager.shared
                    if let currentAccount = accountManager.currentUserAccount {
                        _ = accountManager.refresh(credentials: currentAccount.credentials, { (result) in
                            switch(result) {
                            case .success((_, _)):
                                SFSDKCoreLogger.d(BiometricAuthenticationManagerInternal.self, message: "Refresh credentials succeeded")
                            case .failure(let error):
                                SFSDKCoreLogger.d(BiometricAuthenticationManagerInternal.self, message: "Refresh credentials failed: \(error)")
                            }
                        })
                    }
                    
                    unlockPostProcessing()
                    await accountManager.stopCurrentAuthentication()
                    await MainActor.run {
                        SFSDKWindowManager.shared().authWindow(scene).viewController?.dismiss(animated: false)
                    }
                } catch {
                    // This just means the user chose the fallback option instead of biometric
                }
            }
        }
    }
    
    @objc public func unlockPostProcessing() {
        self.locked = false
        NotificationCenter.default.post(name: Notification.Name(rawValue: kSFBiometricAuthenticationFlowCompleted), object: nil)
    }
    
    private struct BioAuthPolicy: Encodable, Decodable {
        let hasPolicy: Bool
        let timeout: Int32
        var optIn: Bool?
        var nativeLoginButton: Bool?
        
        init(hasPolicy: Bool, timeout: Int32, optIn: Bool? = false, nativeLoginButton: Bool? = true) {
            self.hasPolicy = hasPolicy
            self.timeout = timeout
            self.optIn = optIn
            self.nativeLoginButton = nativeLoginButton
        }
    }
}
