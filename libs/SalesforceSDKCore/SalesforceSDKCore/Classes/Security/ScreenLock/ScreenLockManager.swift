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

typealias ScreenLockCallbackBlock = () -> Void

@objc(SFScreenLockManager)
class ScreenLockManager: NSObject {
    @objc static let shared = ScreenLockManager()
    
    private let kScreenLockIdentifier = "com.salesforce.security.screenlock"
    private var callbackBlock: ScreenLockCallbackBlock? = nil
    
    private override init() {}
    
    @objc func handleAppForground() {
        if readMobilePolicy() {
            lock()
        }
    }
    
    @objc func storeMobilePolicy(userAccount: UserAccount, hasMobilePolicy: Bool) {
        let hasPolicyData = try! JSONEncoder().encode(MobilePolicy(hasPolicy: hasMobilePolicy))
        let result = KeychainHelper.write(service: kScreenLockIdentifier, data: hasPolicyData, account: userAccount.idData.userId)
        if result.success {
            SFSDKCoreLogger.i(ScreenLockManager.self, message: "Mobile policy stored as \(hasPolicyData) for user.")
        } else {
            SFSDKCoreLogger.i(ScreenLockManager.self, message: "Failed to store mobile policy for user.")
        }

        // If true set for the app
        if hasMobilePolicy {
            let globalResult = KeychainHelper.write(service: kScreenLockIdentifier, data: hasPolicyData, account: nil)
            if globalResult.success {
                SFSDKCoreLogger.i(ScreenLockManager.self, message: "Global mobile policy stored as \(hasPolicyData).")
            } else {
                SFSDKCoreLogger.i(ScreenLockManager.self, message: "Failed to store global mobile policy.")
            }
            lock()
        }
    }
    
    @objc func setCallbackBlock(screenLockCallbackBlock: @escaping ScreenLockCallbackBlock) {
        callbackBlock = screenLockCallbackBlock
    }
    
    func unlock() {
        // Send flow will begin notification
        SFSDKCoreLogger.d(ScreenLockManager.self, message: "Sending screen lock flow completed notification")
        NotificationCenter.default.post(name: Notification.Name(rawValue: kSFScreenLockFlowCompleted), object: nil)
        
        SFSDKWindowManager.shared().screenLockWindow().dismissWindow()
        if callbackBlock != nil {
            let callbackBlockCopy = callbackBlock!
            callbackBlock = nil
            callbackBlockCopy()
        }
    }
    
    func logoutScreenLockUsers() {
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
                                SFSDKCoreLogger.i(ScreenLockManager.self, message: "Failed to remove Mobile policy for user.")
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
            SFSDKCoreLogger.i(ScreenLockManager.self, message: "Failed to remove global mobile policy.")
        }
    }
    
    internal func readMobilePolicy() -> Bool {
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
