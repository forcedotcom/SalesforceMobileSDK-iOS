/*
PushNotificationManager.swift
SalesforceSDKCore

Created by Raj Rao on 9/24/19.

Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

Redistribution and use of this software in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
* Redistributions of source code must retain the above copyright notice, this list of conditions
and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice, this list of
conditions and the following disclaimer in the documentation and/or other materials provided
with the distribution.
* Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
endorse or promote products derived from this software without specific prior written
permission of salesforce.com, inc.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
import Foundation

public enum PushNotificationManagerError: Error {
    case registrationFailed
    case currentUserNotDetected
    case failedNotificationTypesRetrieval
    case notificationActionInvocationFailed(String)
}

enum UserDefaultsKeys {
    static let cachedNotificationTypes = "cachedNotificationTypes"
}

extension PushNotificationManager {
    
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
        let result = __registerSalesforceNotifications(withCompletionBlock: user, completionBlock:{
             return completionBlock(.success(true))
        } ) {
             return completionBlock(.failure(.registrationFailed))
        }
        if (!result) {
           completionBlock(.failure(.registrationFailed))
        }
    }
    
    /// Unregister from notifications with Salesforce for a current user
    /// - Parameter completionBlock: completion block to call with success or failure
    public func unregisterForSalesforceNotifications(_ completionBlock:@escaping (Bool)->()) {
        if let currentUser = UserAccountManager.shared.currentUserAccount {
            self.unregisterForSalesforceNotifications(user: currentUser, completionBlock)
           return
        }
        completionBlock(false)
     }
    
    ///  Unregister from Salesforce notfications for a specific user
    /// - Parameters:
    ///   - user: The user that should be unregistered from notfications
    ///   - completionBlock: <#completionBlock description#>
    public func unregisterForSalesforceNotifications(user: UserAccount, _ completionBlock:@escaping (Bool)->()) {
        let result = __unregisterSalesforceNotifications(withCompletionBlock: user) {
            completionBlock(true)
            return
        }
        
        if (!result) {
            completionBlock(false)
        }
    }
}

extension PushNotificationManager {
    @objc
    func getNotificationTypes(restClient: RestClient = RestClient.shared,
                                 account: UserAccount? = UserAccountManager.shared.currentUserAccount) async throws -> [NotificationType] {
        guard let account = account else {
            throw PushNotificationManagerError.currentUserNotDetected as Error
        }
        
        do {
            let types = try await fetchNotificationTypesFromAPI(with: restClient)
            storeNotification(types: types, with: account)
            setNotificationCategories(types: types)
            return (types)
        } catch {
            SFSDKCoreLogger().d(PushNotificationManager.self, message: "API fetch failed: \(error.localizedDescription). Trying cache...")
            guard let cachedTypes = getCachedNotificationTypes(with: account) else {
                SFSDKCoreLogger().e(PushNotificationManager.self, message: "No cached notification types available.")
                throw PushNotificationManagerError.failedNotificationTypesRetrieval as Error
            }
            SFSDKCoreLogger().d(PushNotificationManager.self, message: "Using cached notification types.")
            setNotificationCategories(types: cachedTypes)
            return (cachedTypes)
        }
    }
    
    private func fetchNotificationTypesFromAPI(with client: RestClient) async throws -> [NotificationType] {
        let request = RestRequest(method: .GET, path: "connect/notifications/types", queryParams: nil)
        let response = try await client.send(request: request)
        let result = try response.asDecodable(type: NotificationTypesResponse.self)
        return result.notificationTypes
    }
    
    private func storeNotification(types: [NotificationType], with account: UserAccount) {
        account.notificationTypes = types
    }
    
    private func getCachedNotificationTypes(with account: UserAccount) -> [NotificationType]? {
        return account.notificationTypes
    }
    
        private func setNotificationCategories(types: [NotificationType]) {
            let categories = types.map { createNotificationCategory(from: $0) }
            UNUserNotificationCenter.current().setNotificationCategories(Set(categories))
        }
    
        private func createNotificationCategory(from type: NotificationType) -> UNNotificationCategory {
            let actions = createActions(from: type.actionGroups)
            return UNNotificationCategory(identifier: type.apiName, actions: actions, intentIdentifiers: [])
        }
    
        private func createActions(from actionGroups: [ActionGroup]) -> [UNNotificationAction] {
            return actionGroups.flatMap { actionGroup in
                actionGroup.actions.map { action in
                    UNNotificationAction(
                        identifier: action.identifier,
                        title: action.label,
                        options: [.foreground] // Ensures the app opens if needed
                    )
                }
            }
        }
    
    private func getNotificationType(apiName: String, account: UserAccount) -> NotificationType? {
        guard let notificationTypes = account.notificationTypes else { return nil }
        return notificationTypes.first { $0.apiName == apiName }
    }
}

@objc
extension PushNotificationManager {
    
    /// Retrieves all stored notification types for the current or specified user account.
    ///
    /// - Parameter account: The user account from which to retrieve notification types. Defaults to the current user.
    /// - Returns: An array of `NotificationType` if available, otherwise `nil`.
    func getNotificationTypes(account: UserAccount? = UserAccountManager.shared.currentUserAccount) -> [NotificationType]? {
        return account?.notificationTypes
    }
    
    /// Retrieves all action groups for a given notification type.
    ///
    /// - Parameters:
    ///   - notificationTypeApiName: The API name of the notification type.
    ///   - account: The user account from which to retrieve action groups. Defaults to the current user.
    /// - Returns: An array of `ActionGroup` if found, otherwise `nil`.
    @objc
    public func getActionGroups(notificationTypeApiName: String,
                                account: UserAccount? = UserAccountManager.shared.currentUserAccount) -> [ActionGroup]? {
        guard let account = account,
              let notificationType = getNotificationType(apiName: notificationTypeApiName, account: account) else {
            return nil
        }
        return notificationType.actionGroups
    }
    
    /// Retrieves a specific action group for a given notification type.
    ///
    /// - Parameters:
    ///   - notificationTypeApiName: The API name of the notification type.
    ///   - actionGroupName: The name of the action group.
    ///   - account: The user account from which to retrieve the action group. Defaults to the current user.
    /// - Returns: The `ActionGroup` if found, otherwise `nil`.
    @objc
    public func getActionGroup(notificationTypeApiName: String,
                               actionGroupName: String,
                               account: UserAccount? = UserAccountManager.shared.currentUserAccount) -> ActionGroup? {
        guard let account = account,
              let notificationType = getNotificationType(apiName: notificationTypeApiName, account: account) else {
            return nil
        }
        return notificationType.actionGroups.first { $0.name == actionGroupName }
    }
    
    /// Retrieves a specific action by its identifier within a given notification type.
    ///
    /// - Parameters:
    ///   - notificationTypeApiName: The API name of the notification type.
    ///   - actionIdentifier: The identifier of the action.
    ///   - account: The user account from which to retrieve the action. Defaults to the current user.
    /// - Returns: The `Action` if found, otherwise `nil`.
    @objc
    public func getAction(notificationTypeApiName: String,
                          actionIdentifier: String,
                          account: UserAccount? = UserAccountManager.shared.currentUserAccount) -> Action? {
        guard let account = account,
              let notificationType = getNotificationType(apiName: notificationTypeApiName, account: account) else {
            return nil
        }
        return notificationType.actionGroups
            .flatMap { $0.actions }
            .first { $0.identifier == actionIdentifier }
    }
    
    /// Invokes a server-side notification action for a specific notification.
    ///
    /// - Parameters:
    ///   - client: The `RestClient` instance to use for the request. Defaults to `RestClient.shared`.
    ///   - notificationId: The ID of the notification for which the action is invoked.
    ///   - actionIdentifier: The identifier of the action to be performed.
    /// - Throws: `PushNotificationManagerError.notificationActionInvocationFailed` if the action invocation fails.
    /// - Returns: An `ActionResultRepresentation` containing the response from the server.
    @objc
    public func invokeServerNotificationAction(client: RestClient = RestClient.shared,
                                               notificationId: String,
                                               actionIdentifier: String
    ) async throws -> ActionResultRepresentation {
        let path = "/connect/notifications/\(notificationId)/actions/\(actionIdentifier)"
        let request = RestRequest(method: .POST, path: path, queryParams: nil)
        
        do {
            let response = try await client.send(request: request)
            return try response.asDecodable(type: ActionResultRepresentation.self)
        } catch {
            throw PushNotificationManagerError.notificationActionInvocationFailed(error.localizedDescription)
        }
    }
}

