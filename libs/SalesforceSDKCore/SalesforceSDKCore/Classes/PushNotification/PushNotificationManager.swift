//
//  PushNotificationManager.swift
//  SalesforceSDKCore
//
//  Created by Riley Crebs on 3/27/25.
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

import Foundation

struct PushNotificationConstants {
    static let deviceToken = "deviceToken"
    static let deviceSalesforceId = "deviceSalesforceId"
    static let endPoint = "sobjects/MobilePushServiceDevice"
    static let appFeaturePushNotifications = "PN"
}

@objc(SFSDKPushNotificationEncryptionConstants)
@objcMembers
public class PushNotificationManagerConstants: NSObject {
    public static let kPNEncryptionKeyName = "com.salesforce.mobilesdk.notificationKey"
    public static let kPNEncryptionKeyLength: UInt = 2048
}

public enum PushNotificationManagerError: Error, Equatable {
    case registrationFailed
    case currentUserNotDetected
    case failedNotificationTypesRetrieval
    case notificationActionInvocationFailed(String)
    
    public static func == (lhs: PushNotificationManagerError, rhs: PushNotificationManagerError) -> Bool {
        switch (lhs, rhs) {
        case (.registrationFailed, .registrationFailed):
            return true
        case (.currentUserNotDetected, .currentUserNotDetected):
            return true
        case (.failedNotificationTypesRetrieval, .failedNotificationTypesRetrieval):
            return true
        case (.notificationActionInvocationFailed(let lhsMsg), .notificationActionInvocationFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

@objc(SFPushNotificationManager)
@objcMembers
public class PushNotificationManager: NSObject {

    public static let shared = PushNotificationManager()
    @objc public static func sharedInstance() -> PushNotificationManager {
        return shared
    }
    
    public var deviceToken: String?
    public var deviceSalesforceId: String?
    public var customPushRegistrationBody: [String: Any]?
    public var registerOnForeground: Bool = true
    
    var isSimulator: Bool = false
    private let notificationRegister: RemoteNotificationRegistering
    private let apiVersion: String
    private let restClient: RestClient?
    private let currentUser: UserAccount?
    private let preferences: SFPreferences?
    
    /// Convenience initializer that sets up the PushNotificationManager with default values:
    /// - notificationRegister: DefaultRemoteNotificationRegistrar() - Handles APNS registration
    /// - apiVersion: RestClient.shared.apiVersion - Uses the current API version from RestClient
    /// - restClient: RestClient.shared - Uses the shared RestClient instance
    /// - currentUser: UserAccountManager.shared.currentUserAccount - Uses the current logged-in user
    /// - preferences: SFPreferences.sharedPreferences(for: .user, user: currentUser) - Uses user-level preferences
    @objc
    public override convenience init() {
        self.init(notificationRegister: DefaultRemoteNotificationRegistrar(),
                   apiVersion: RestClient.shared.apiVersion,
                   restClient: RestClient.shared,
                   currentUser: UserAccountManager.shared.currentUserAccount,
                   preferences: SFPreferences.sharedPreferences(for: .user, user: UserAccountManager.shared.currentUserAccount))
    }
    
    /// Internal initializer used for testing and dependency injection.
    /// This initializer allows for customizing the dependencies of PushNotificationManager:
    /// - Parameter notificationRegister: The registrar that handles APNS registration. Defaults to DefaultRemoteNotificationRegistrar.
    /// - Parameter apiVersion: The Salesforce API version to use. Defaults to RestClient.shared.apiVersion.
    /// - Parameter restClient: The REST client for making API calls. Defaults to RestClient.shared.
    /// - Parameter currentUser: The user account to use. Defaults to UserAccountManager.shared.currentUserAccount.
    /// - Parameter preferences: The preferences store to use. Defaults to user-level SFPreferences.
    internal init(notificationRegister: RemoteNotificationRegistering = DefaultRemoteNotificationRegistrar(),
                  apiVersion: String = RestClient.shared.apiVersion,
                  restClient : RestClient? = RestClient.shared,
                  currentUser: UserAccount? = UserAccountManager.shared.currentUserAccount,
                  preferences: SFPreferences? = nil) {
        self.notificationRegister = notificationRegister
        self.apiVersion = apiVersion
        self.restClient = restClient
        self.currentUser = currentUser
        
        if preferences == nil {
            self.preferences = SFPreferences.sharedPreferences(for: .user, user: currentUser)
        } else {
            self.preferences = preferences
        }
        
        super.init()
        
#if targetEnvironment(simulator)
        self.isSimulator = true
#else
        self.isSimulator = false
#endif
        
        let prefs = SFPreferences.currentUserLevel()
        self.deviceToken = prefs?.string(forKey: PushNotificationConstants.deviceToken)
        self.deviceSalesforceId = prefs?.string(forKey: PushNotificationConstants.deviceSalesforceId)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onUserLoggedIn(_:)),
                                               name: NSNotification.Name(rawValue: UserAccountManager.didLogInUser.rawValue),
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onAppWillEnterForeground(_:)),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }
    
    /// Registers the app with Apple Push Notification Service (APNS).
    ///
    /// This should be called to initiate push notification registration.
    /// No-op if running in the simulator.
    public func registerForRemoteNotifications() {
        guard !isSimulator else {
            SFSDKCoreLogger.i(Self.self, message: "Skipping push registration in simulator")
            return
        }
        
        SFSDKCoreLogger.i(Self.self, message: "Registering with APNS")
        notificationRegister.registerForRemoteNotifications()
    }
    
    /**
     * Call this method from your app delegate's didRegisterForRemoteNotificationsWithDeviceToken
     * @param deviceTokenData The device token returned by APNS.
     */
    @objc(didRegisterForRemoteNotificationsWithDeviceToken:)
    public func didRegisterForRemoteNotifications(withDeviceToken: Data) {
        
        SFSDKCoreLogger.i(Self.self, message: "APNS registration succeeded")
        guard let hexString = NSString.sfsdk_string(withHexData: withDeviceToken) else {
            SFSDKCoreLogger.e(Self.self, message: "Data was empty, got nil")
            return
        }
        self.deviceToken = hexString
        if let prefs = SFPreferences.currentUserLevel() {
            prefs.setObject(hexString, forKey: PushNotificationConstants.deviceToken)
            prefs.synchronize()
        }
    }
    
    // MARK: - Salesforce Registration
    
    /// Registers the device for push notifications with Salesforce using the current user account.
    ///
    /// - Parameters:
    ///   - completionBlock: A block executed on successful registration.
    ///   - failBlock: A block executed if registration fails.
    /// - Returns: `true` if registration started successfully, otherwise `false`.
    @discardableResult
    @objc(registerSalesforceNotificationsWithCompletionBlock:failBlock:)
    public func registerSalesforceNotifications(completionBlock: (() -> Void)?, failBlock: (() -> Void)?) -> Bool {
        guard let user = UserAccountManager.shared.currentUserAccount else {
            SFSDKCoreLogger.e(Self.self, message: "No current user found")
            failBlock?()
            return false
        }
        
        return registerSalesforceNotifications(for: user, completionBlock: completionBlock, failBlock: failBlock)
    }
    
    /// Registers the device for push notifications with Salesforce for a specific user account.
    ///
    /// - Parameters:
    ///   - user: The user account to use for registration.
    ///   - completionBlock: A block executed on successful registration.
    ///   - failBlock: A block executed if registration fails.
    /// - Returns: `true` if registration started successfully, otherwise `false`.
    @discardableResult
    @objc(registerSalesforceNotificationsWithCompletionBlock:completionBlock:failBlock:)
    public func registerSalesforceNotifications(for user: UserAccount,
                                                completionBlock: (() -> Void)?,
                                                failBlock: (() -> Void)?) -> Bool {
        if isSimulator {
            SFSDKCoreLogger.i(Self.self, message: "Skipping Salesforce push notification registration because push isn't supported on the simulator")
            completionBlock?()
            return true
        }
        
        let credentials = user.credentials
        
        guard let deviceToken = deviceToken else {
            SFSDKCoreLogger.e(Self.self, message: "Cannot register for notifications with Salesforce: no deviceToken")
            failBlock?()
            return false
        }
        
        let path = "/\(apiVersion)/\(PushNotificationConstants.endPoint)"
        let request = RestRequest(method: .POST, path: path, queryParams: nil)
        
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        var bodyDict: [String: Any] = [
            "ConnectionToken": deviceToken,
            "ServiceType": "Apple",
            "ApplicationBundle": bundleId
        ]
        
        if let customBody = customPushRegistrationBody {
            bodyDict.merge(customBody) { _, new in new }
        }
        
        if let communityId = credentials.communityId {
            bodyDict["NetworkId"] = communityId
        }
        
        if let rsaPublicKey = getRSAPublicKey() {
            bodyDict["RsaPublicKey"] = rsaPublicKey
        }
        
        bodyDict["CipherName"] = "RSA_OAEP_SHA256"
        
        request.setCustomRequestBodyDictionary(bodyDict, contentType: "application/json")
        Task {
            do {
                
                guard let restClient = restClient else {
                    SFSDKCoreLogger.e(Self.self, message: "Cannot register for notifications with Salesforce: no restClient")
                    failBlock?()
                    return
                }
                
                let result = try await restClient.send(request: request)
                
                SFSDKAppFeatureMarkers.registerAppFeature(PushNotificationConstants.appFeaturePushNotifications)
                
                guard let httpResponse = result.urlResponse as? HTTPURLResponse else {
                    SFSDKCoreLogger.e(Self.self, message: "Unexpected raw response type")
                    failBlock?()
                    return
                }
                
                guard (200..<300).contains(httpResponse.statusCode),
                      let json = try? result.asJson() as? [String: Any] else {
                    SFSDKCoreLogger.e(Self.self, message: "Registration failed. Status: \(httpResponse.statusCode). Response: \(result)")
                    failBlock?()
                    return
                }
                
                SFSDKCoreLogger.i(Self.self, message: "Registration succeeded")
                self.deviceSalesforceId = json["id"] as? String
                
                let prefs = SFPreferences.currentUserLevel()
                prefs?.setObject(self.deviceSalesforceId ?? "", forKey: PushNotificationConstants.deviceSalesforceId)
                prefs?.synchronize()
                
                SFSDKCoreLogger.i(Self.self, message: "Response: \(json)")
                
                Task {
                    do {
                        try await self.fetchAndStoreNotificationTypes(restClient: restClient, account: user)
                    } catch {
                        SFSDKCoreLogger.e(Self.self, message: "Get Notification Types Error: \(error.localizedDescription)")
                    }
                    completionBlock?()
                }
            } catch {
                SFSDKCoreLogger.e(Self.self, message: "Registration for notifications with Salesforce failed with error \(error.localizedDescription)")
                failBlock?()
            }
        }
        return true
    }
    
    // MARK: - Salesforce Unregistration
    
    /// Unregisters the device from Salesforce push notifications for the current user.
    ///
    /// - Parameter completionBlock: A block executed when unregistration is complete.
    /// - Returns: `true` if unregistration started successfully, otherwise `false`.
    @discardableResult
    @objc(unregisterSalesforceNotificationsWithCompletionBlock:)
    public func unregisterSalesforceNotifications(completionBlock: (() -> Void)?) -> Bool {
        guard let user = UserAccountManager.shared.currentUserAccount else {
            completionBlock?()
            return false
        }
        
        return unregisterSalesforceNotifications(for: user, completionBlock: completionBlock)
    }
    
    /// Unregisters the device from Salesforce push notifications for a specific user.
    ///
    /// - Parameters:
    ///   - user: The user account to unregister.
    ///   - completionBlock: A block executed when unregistration is complete.
    /// - Returns: `true` if unregistration started successfully, otherwise `false`.
    @discardableResult
    @objc(unregisterSalesforceNotificationsWithCompletionBlock:completionBlock:)
    public func unregisterSalesforceNotifications(for user: UserAccount,
                                                  completionBlock: (() -> Void)?) -> Bool {
        guard deviceSalesforceId != nil else {
            completionBlock?()
            return true
        }
        
        if isSimulator {
            completionBlock?()
            return true
        }
        
        guard let prefs = preferences else {
            SFSDKCoreLogger.e(Self.self, message: "Cannot unregister from notifications with Salesforce: no user prefs")
            return false
        }
        
        guard let sfId = prefs.string(forKey: PushNotificationConstants.deviceSalesforceId) else {
            SFSDKCoreLogger.e(Self.self, message: "Cannot unregister from notifications with Salesforce: no deviceSalesforceId")
            return false
        }
        
        let path = "/\(apiVersion)/\(PushNotificationConstants.endPoint)/\(sfId)"
        let request = RestRequest(method: .DELETE,
                                  path: path,
                                  queryParams: nil)
        Task {
            do {
                _ = try await restClient?.send(request: request)
                completionBlock?()
            } catch {
                SFSDKCoreLogger.e(Self.self, message: "Push notification unregistration failed: \(error.localizedDescription)")
                completionBlock?()
            }
        }
        
        SFSDKCoreLogger.i(Self.self, message: "Unregister from notifications with Salesforce sent")
        return true
    }
    
    /// Fetches and stores actionable notification types from the server or cache.
    ///
    /// - Parameters:
    ///   - restClient: The `RestClient` to use for the API call.
    ///   - account: The user account to associate notification types with.
    /// - Throws: An error if the types cannot be retrieved from server or cache.
    @objc(fetchAndStoreNotificationTypesWithRestClient:account:completionHandler:)
    public func fetchAndStoreNotificationTypes(restClient: RestClient = RestClient.shared,
                                               account: UserAccount? = UserAccountManager.shared.currentUserAccount) async throws {
        guard let account = account else {
            throw PushNotificationManagerError.currentUserNotDetected
        }
        
        do {
            let types = try await fetchNotificationTypesFromAPI(with: restClient)
            storeNotification(types: types, with: account)
            setNotificationCategories(types: types)
        } catch {
            SFSDKCoreLogger.d(PushNotificationManager.self, message: "API fetch failed: \(error.localizedDescription). Trying cache...")
            guard let cachedTypes = getCachedNotificationTypes(with: account) else {
                SFSDKCoreLogger.e(PushNotificationManager.self, message: "No cached notification types available.")
                throw PushNotificationManagerError.failedNotificationTypesRetrieval as Error
            }
            SFSDKCoreLogger.d(PushNotificationManager.self, message: "Using cached notification types.")
            setNotificationCategories(types: cachedTypes)
        }
    }
    
    /// Returns the RSA public key used for encrypting push notification payloads.
    ///
    /// - Returns: A base64-encoded string representation of the RSA public key, or `nil` if unavailable.
    @objc
    public func getRSAPublicKey() -> String? {
        let name = PushNotificationManagerConstants.kPNEncryptionKeyName
        let length = PushNotificationManagerConstants.kPNEncryptionKeyLength
        var key = SFSDKCryptoUtils.getRSAPublicKeyString(withName: name, keyLength: length)
        if key == nil {
            SFSDKCryptoUtils.createRSAKeyPair(withName: name, keyLength: length, accessibleAttribute: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
            key = SFSDKCryptoUtils.getRSAPublicKeyString(withName: name, keyLength: length)
        }
        return key
    }
    
    /// Register for Salesforce notfications for a current user
    /// - Parameter completionBlock: completion block to call with success or failure
    public func registerForSalesforceNotifications(_ completionBlock:@escaping (Result<Bool, PushNotificationManagerError>)->()) {
        if let currentUser = UserAccountManager.shared.currentUserAccount {
            return self.registerForSalesforceNotifications(user: currentUser, completionBlock: completionBlock)
        }
        completionBlock(.failure(.currentUserNotDetected))
    }
    
    /// Register for Salesforce notfications for a given user
    /// - Parameters:
    ///   - user: A user account ot use  to register for noitfications
    ///   - completionBlock: completion block to call with success or failure
    public func registerForSalesforceNotifications(user: UserAccount, completionBlock:@escaping (Result<Bool, PushNotificationManagerError>)->()) {
        _ = registerSalesforceNotifications(for: user) {
            return completionBlock(.success(true))
        } failBlock: {
            completionBlock(.failure(.registrationFailed))
        }
    }
    
    /// Unregister from notifications with Salesforce for a current user
    /// - Parameter completionBlock: completion block to call with success or failure
    public func unregisterForSalesforceNotifications(_ completionBlock:@escaping (Bool)->()) {
        
        guard let currentUser = UserAccountManager.shared.currentUserAccount else {
            completionBlock(false)
            return
        }
        self.unregisterForSalesforceNotifications(user: currentUser, completionBlock)
    }
    
    ///  Unregister from Salesforce notfications for a specific user
    /// - Parameters:
    ///   - user: The user that should be unregistered from notfications
    ///   - completionBlock: completion block to call with success or failure
    public func unregisterForSalesforceNotifications(user: UserAccount, _ completionBlock:@escaping (Bool)->()) {
        let result = unregisterSalesforceNotifications(for: user) {
            completionBlock(true)
        }
        
        if (!result) {
            completionBlock(false)
        }
    }
}

private extension PushNotificationManager {
    @objc private func onUserLoggedIn(_ notification: Notification) {
        if deviceToken != nil {
            SFSDKCoreLogger.i(Self.self, message: "User logged in, registering push")
            _ = registerSalesforceNotifications(completionBlock: nil, failBlock: nil)
        }
    }
    
    @objc private func onAppWillEnterForeground(_ notification: Notification) {
        guard registerOnForeground,
              !UserAccountManager.shared.isLogoutSettingEnabled,
              deviceToken != nil else {
            return
        }
        
        SFSDKCoreLogger.i(Self.self, message: "App entering foreground, re-registering push")
        _ = registerSalesforceNotifications(completionBlock: nil, failBlock: nil)
    }
}
