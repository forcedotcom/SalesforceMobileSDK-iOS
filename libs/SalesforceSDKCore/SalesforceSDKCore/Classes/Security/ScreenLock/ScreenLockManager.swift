//
//  SFScreenLock.swift
//  SalesforceSDKCore
//
//  Created by Brandon Page on 9/9/21.
//  Copyright (c) 2021-present, salesforce.com, inc. All rights reserved.
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
import SwiftUI

// Callback block used to launch the app when the screen is unlocked.
public typealias ScreenLockCallbackBlock = () -> Void

@objc(SFScreenLockManager)
public class ScreenLockManager: NSObject {
    @objc public static let shared = ScreenLockManager()
    
    private let kScreenLockIdentifier = "com.salesforce.security.screenlock"
    private var callbackBlock: ScreenLockCallbackBlock? = nil
    
    private override init() {}
    
    // MARK: Screen Lock Manager
    
    /// Locks the screen if necessary
    @objc public func handleAppForeground() {
        if readMobilePolicy() {
            lock()
        } else {
            unlockPostProcessing()
        }
    }
    
    /// Stores the mobile policy for the user.
    ///
    /// - Parameters:
    ///   - userAccount: The user account
    ///   - hasMobilePolicy: Whether the user has a mobile policy
    @objc public func storeMobilePolicy(userAccount: UserAccount, hasMobilePolicy: Bool) {
        let hasPolicyData = try! JSONEncoder().encode(MobilePolicy(hasPolicy: hasMobilePolicy))
        let result = KeychainHelper.write(service: kScreenLockIdentifier, data: hasPolicyData, account: userAccount.idData.userId)
        if result.success {
            SFSDKCoreLogger.i(ScreenLockManager.self, message: "Mobile policy stored for user.")
        } else {
            SFSDKCoreLogger.e(ScreenLockManager.self, message: "Failed to store mobile policy for user.")
        }

        // If true set for the app
        if hasMobilePolicy {
            let globalResult = KeychainHelper.write(service: kScreenLockIdentifier, data: hasPolicyData, account: nil)
            if globalResult.success {
                SFSDKCoreLogger.i(ScreenLockManager.self, message: "Global mobile policy stored.")
            } else {
                SFSDKCoreLogger.e(ScreenLockManager.self, message: "Failed to store global mobile policy.")
            }
        }
    }
    
    /// Stores the callback block to be run upon screen unlock
    ///
    /// - Parameters:
    ///   -  screenLockCallbackBlock: The block to be run upon unlock
    @objc public func setCallbackBlock(screenLockCallbackBlock: @escaping ScreenLockCallbackBlock) {
        callbackBlock = screenLockCallbackBlock
    }
    
    /// Checks all users for Screen Lock policy and removes global policy if none are found.
    @objc public func checkForScreenLockUsers() {
        if readMobilePolicy() {
            var screenLockNeeded = false
            if let accounts = UserAccountManager.shared.userAccounts() {
                accounts.forEach { userAccount in
                    let id = userAccount.idData.userId
                    let result = KeychainHelper.read(service: kScreenLockIdentifier, account: id)
                    if result.success && result.data != nil {
                        do {
                            if try JSONDecoder().decode(MobilePolicy.self, from: result.data!).hasPolicy {
                                screenLockNeeded = true
                            }
                        } catch {
                            SFSDKCoreLogger.e(ScreenLockManager.self, message: "Failed to read Mobile policy for user.")
                        }
                    }
                }
            }
            
            // Remove global lock if no users that require it are left.
            if !screenLockNeeded {
                let globalResult = KeychainHelper.remove(service: kScreenLockIdentifier, account: nil)
                if globalResult.success {
                    SFSDKCoreLogger.i(ScreenLockManager.self, message: "Global mobile policy removed.")
                } else {
                    SFSDKCoreLogger.e(ScreenLockManager.self, message: "Failed to remove global mobile policy.")
                }
            }
        }
    }
    
    // TODO: Remove in Mobile SDK 11.0
    /// Upgrades from SFSecurityLockout to ScreenLockManager
    @objc public func upgradePasscode() {
        let userAccounts = UserAccountManager.shared.userAccounts()
        
        userAccounts?.forEach({ account in
            let hasMobilePolicy = account.idData.mobileAppPinLength > 0 && account.idData.mobileAppScreenLockTimeout != -1
            self.storeMobilePolicy(userAccount: account, hasMobilePolicy: hasMobilePolicy)
        })
    }
    
    @objc func logoutScreenLockUsers() {
        if let accounts = UserAccountManager.shared.userAccounts() {
            accounts.forEach { userAccount in
                let id = userAccount.idData.userId
                let result = KeychainHelper.read(service: kScreenLockIdentifier, account: id)
                if result.success && result.data != nil {
                    do {
                        if try JSONDecoder().decode(MobilePolicy.self, from: result.data!).hasPolicy {
                            let globalResult = KeychainHelper.remove(service: kScreenLockIdentifier, account: id)
                            if globalResult.success {
                                SFSDKCoreLogger.i(ScreenLockManager.self, message: "Mobile policy for user removed.")
                            } else {
                                SFSDKCoreLogger.e(ScreenLockManager.self, message: "Failed to remove Mobile policy for user.")
                            }
                            
                            UserAccountManager.shared.logout(userAccount)
                        }
                    } catch {
                        SFSDKCoreLogger.e(ScreenLockManager.self, message: "Failed to read Mobile policy for user.")
                    }
                }
            }
        }
        
        let globalResult = KeychainHelper.remove(service: kScreenLockIdentifier, account: nil)
        if globalResult.success {
            SFSDKCoreLogger.i(ScreenLockManager.self, message: "Global mobile policy removed.")
        } else {
            SFSDKCoreLogger.e(ScreenLockManager.self, message: "Failed to remove global mobile policy.")
        }
    }
    
    @objc func readMobilePolicy() -> Bool {
        var hasPolicy = false
        let result = KeychainHelper.read(service: kScreenLockIdentifier, account: nil)
        if result.success && result.data != nil {
            do {
                try hasPolicy = JSONDecoder().decode(MobilePolicy.self, from: result.data!).hasPolicy
            } catch {
                SFSDKCoreLogger.e(ScreenLockManager.self, message: "Failed to read global mobile policy.")
            }
        }

        return hasPolicy
    }
    
    func unlock() {
        // Send flow will begin notification
        SFSDKCoreLogger.d(ScreenLockManager.self, message: "Sending screen lock flow completed notification")
        NotificationCenter.default.post(name: Notification.Name(rawValue: kSFScreenLockFlowCompleted), object: nil)
        
        SFSDKWindowManager.shared().screenLockWindow().dismissWindow()
        unlockPostProcessing()
    }
    
    private func unlockPostProcessing() {
        if callbackBlock != nil {
            let callbackBlockCopy = callbackBlock!
            callbackBlock = nil
            callbackBlockCopy()
        } else {
            SFSDKCoreLogger.e(ScreenLockManager.self, message: "callbackBlock is nil.")
        }
    }

    private func lock() {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.lock()
            }
        }
        
        if SFSDKWindowManager.shared().snapshotWindow(nil).isEnabled() {
            SFSDKWindowManager.shared().snapshotWindow(nil).dismissWindow()
        }
        
        // Send flow will begin notification
        SFSDKCoreLogger.d(ScreenLockManager.self, message: "Sending Screen Lock flow will begin notification")
        NotificationCenter.default.post(name: Notification.Name(rawValue: kSFScreenLockFlowWillBegin), object: nil)
        
        // Launch Screen Lock
        let screenLockViewController = UIHostingController(rootView: ScreenLockUIView())
        screenLockViewController.modalPresentationStyle = .fullScreen
        SFSDKWindowManager.shared().screenLockWindow().presentWindow(animated: false) {
            SFSDKWindowManager.shared().screenLockWindow().viewController?.present(screenLockViewController, animated: false, completion: nil)
        }
    }
    
    private struct MobilePolicy: Encodable, Decodable {
        let hasPolicy: Bool
    }
}

