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

/*
 * This class is internal to the Mobile SDK - don't instantiate in your application code
 * It's only public to be visible from the obj-c code when the library is compiled as a framework
 * See https://developer.apple.com/documentation/swift/importing-swift-into-objective-c#Import-Code-Within-a-Framework-Target
 */

@objc(SFScreenLockManagerInternal)
public class ScreenLockManagerInternal: NSObject, ScreenLockManager {
    public var enabled: Bool {
        get {
            return (getTimeout() != nil)
        }
    }
    
    @objc public static let shared = ScreenLockManagerInternal()
    
    private let kScreenLockIdentifier = "com.salesforce.security.screenlock"
    private var callbackBlock: ScreenLockCallbackBlock? = nil
    private var backgroundTimestamp: Double = 0
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            if !SFSDKWindowManager.shared().screenLockWindow().isEnabled() {
                self?.backgroundTimestamp = Date().timeIntervalSince1970
            }
        }
    }
    
    // MARK: Screen Lock Manager
    
    /// Locks the screen if necessary
    @objc public func handleAppForeground() {
        if let policyTimeout = getTimeout(), lockTimeoutExpired(lockTimeout: policyTimeout) {
            lock()
        } else {
            unlockPostProcessing()
        }
    }
    
    func lockTimeoutExpired(lockTimeout: NSNumber) -> Bool {
        return (Date().timeIntervalSince1970 - backgroundTimestamp) > lockTimeout.doubleValue * 60
    }
    
    /// Stores the mobile policy for the user.
    ///
    /// - Parameters:
    ///   - userAccount: The user account
    ///   - hasMobilePolicy: Whether the user has a mobile policy
    @available(*, deprecated, renamed: "storeMobilePolicy(userAccount:hasMobilePolicy:lockTimeout:)")
    @objc public func storeMobilePolicy(userAccount: UserAccount, hasMobilePolicy: Bool) {
        storeMobilePolicy(userAccount: userAccount, hasMobilePolicy: hasMobilePolicy, lockTimeout: 1)
    }
    
    /// Stores the mobile policy for the user.
    ///
    /// - Parameters:
    ///   - userAccount: The user account
    ///   - hasMobilePolicy: Whether the user has a mobile policy
    ///   - lockTimeout: The length of time in minutes before the app will be locked after backgrounding
    @objc public func storeMobilePolicy(userAccount: UserAccount, hasMobilePolicy: Bool, lockTimeout: Int32) {
        let hasPolicyData = try! JSONEncoder().encode(MobilePolicy(hasPolicy: hasMobilePolicy, timeout: lockTimeout))
        let result = KeychainHelper.write(service: kScreenLockIdentifier, data: hasPolicyData, account: userAccount.idData.userId)
        if result.success {
            SFSDKCoreLogger.i(ScreenLockManagerInternal.self, message: "Mobile policy stored for user.")
        } else {
            SFSDKCoreLogger.e(ScreenLockManagerInternal.self, message: "Failed to store mobile policy for user.")
        }

        if hasMobilePolicy {
            defer { lock() }

            if let globalTimeout = getTimeout(), lockTimeout >= globalTimeout.intValue {
                // Only write global policy if there is no policy or the existing timeout is less restrictive
                return
            }
            writeGlobalPolicy(hasPolicyData)
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
        guard getTimeout() != nil else {
            return
        }
        
        let allPolicies = UserAccountManager.shared.userAccounts()?.compactMap { userAccount -> MobilePolicy? in
            readMobilePolicy(id: userAccount.idData.userId)
        }
        
        let strictestPolicy = allPolicies?
            .filter { $0.hasPolicy && $0.timeout > 0 }
            .min { $0.timeout < $1.timeout }
        
        if let strictestPolicy = strictestPolicy {
            do {
                let encodedPolicy = try JSONEncoder().encode(strictestPolicy)
                writeGlobalPolicy(encodedPolicy)
            } catch {
                SFSDKCoreLogger.e(ScreenLockManagerInternal.self, message: "Failed to update mobile policy.")
            }
        } else {
            // Remove global lock if no users that require it are left.
           removeGlobalPolicy()
        }
    }
    
    // TODO: Remove in Mobile SDK 12.0
    /// Upgrades from SFSecurityLockout to ScreenLockManager
    @objc public func upgradePasscode() {
        let userAccounts = UserAccountManager.shared.userAccounts()
        
        userAccounts?.forEach({ account in
            let hasMobilePolicy = account.idData.mobileAppPinLength > 0 && account.idData.mobileAppScreenLockTimeout != -1
            self.storeMobilePolicy(userAccount: account, hasMobilePolicy: hasMobilePolicy, lockTimeout: account.idData.mobileAppScreenLockTimeout)
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
                                SFSDKCoreLogger.i(ScreenLockManagerInternal.self, message: "Mobile policy for user removed.")
                            } else {
                                SFSDKCoreLogger.e(ScreenLockManagerInternal.self, message: "Failed to remove Mobile policy for user.")
                            }
                            
                            UserAccountManager.shared.logout(userAccount)
                        }
                    } catch {
                        SFSDKCoreLogger.e(ScreenLockManagerInternal.self, message: "Failed to read Mobile policy for user.")
                    }
                }
            }
        }
        
        removeGlobalPolicy()
    }
    
    @objc func getTimeout() -> NSNumber? {
        if let policy = readMobilePolicy(id: "global") {
            if (policy.hasPolicy && policy.timeout > 0) {
                return NSNumber(value: policy.timeout)
            }
        }
        
        return nil
    }
    
    func writeGlobalPolicy(_ data: Data) {
        let globalResult = KeychainHelper.write(service: kScreenLockIdentifier, data: data, account: "global")
        if globalResult.success {
            SFSDKCoreLogger.i(ScreenLockManagerInternal.self, message: "Global mobile policy stored.")
        } else {
            SFSDKCoreLogger.e(ScreenLockManagerInternal.self, message: "Failed to store global mobile policy.")
        }
    }
    
    func removeGlobalPolicy() {
        let globalResult = KeychainHelper.remove(service: kScreenLockIdentifier, account: "global")
        if globalResult.success {
            SFSDKCoreLogger.i(ScreenLockManagerInternal.self, message: "Global mobile policy removed.")
        } else {
            SFSDKCoreLogger.e(ScreenLockManagerInternal.self, message: "Failed to remove global mobile policy.")
        }
    }
    
    func unlock() {
        // Send flow will begin notification
        SFSDKCoreLogger.d(ScreenLockManagerInternal.self, message: "Sending screen lock flow completed notification")
        NotificationCenter.default.post(name: Notification.Name(rawValue: kSFScreenLockFlowCompleted), object: nil)
        
        SFSDKWindowManager.shared().screenLockWindow().dismissWindow()
        unlockPostProcessing()
    }
    
    public func lock() {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.lock()
            }
        }
        
        if SFSDKWindowManager.shared().snapshotWindow(nil).isEnabled() {
            SFSDKWindowManager.shared().snapshotWindow(nil).dismissWindow()
        }
        
        // Send flow will begin notification
        SFSDKCoreLogger.d(ScreenLockManagerInternal.self, message: "Sending Screen Lock flow will begin notification")
        NotificationCenter.default.post(name: Notification.Name(rawValue: kSFScreenLockFlowWillBegin), object: nil)
        
        // Launch Screen Lock
        let screenLockViewController = UIHostingController(rootView: ScreenLockUIView())
        screenLockViewController.modalPresentationStyle = .fullScreen
        SFSDKWindowManager.shared().screenLockWindow().presentWindow(animated: false) {
            SFSDKWindowManager.shared().screenLockWindow().viewController?.present(screenLockViewController, animated: false, completion: nil)
        }
    }

    @objc public func checkForPolicy(userId: String) -> Bool {
        return readMobilePolicy(id: userId)?.hasPolicy ?? false
    }
    
    private func unlockPostProcessing() {
        if callbackBlock != nil {
            let callbackBlockCopy = callbackBlock!
            callbackBlock = nil
            callbackBlockCopy()
        } else {
            SFSDKCoreLogger.e(ScreenLockManagerInternal.self, message: "callbackBlock is nil.")
        }
    }
    
    private func readMobilePolicy(id: String) -> MobilePolicy? {
        let result = KeychainHelper.read(service: kScreenLockIdentifier, account: id)
        if let data = result.data, result.success {
            do {
                return try JSONDecoder().decode(MobilePolicy.self, from: data)
            } catch {
                SFSDKCoreLogger.e(ScreenLockManagerInternal.self, message: "Failed to read global mobile policy.")
            }
        }
        
        return nil
    }

    private struct MobilePolicy: Encodable, Decodable {
        let hasPolicy: Bool
        let timeout: Int32
    }
}

