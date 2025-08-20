//
//  PushNotificationManager+ActionableNotifications.swift
//  SalesforceSDKCore
//
//  Created by Riley Crebs on 3/28/25.
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

@objc
public extension PushNotificationManager {
    
    /// Retrieves all stored notification types for the current or specified user account.
    ///
    /// - Parameter account: The user account from which to retrieve notification types. Defaults to the current user.
    /// - Returns: An array of `NotificationType` if available, otherwise `nil`.
    @objc
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
    func getActionGroups(notificationTypeApiName: String,
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
    func getActionGroup(notificationTypeApiName: String,
                               actionGroupName: String,
                               account: UserAccount? = UserAccountManager.shared.currentUserAccount) -> ActionGroup? {
        guard let account = account,
              let notificationType = getNotificationType(apiName: notificationTypeApiName, account: account) else {
            return nil
        }
        return notificationType.actionGroups?.first { $0.name == actionGroupName }
    }
    
    /// Retrieves a specific action by its identifier within a given notification type.
    ///
    /// - Parameters:
    ///   - notificationTypeApiName: The API name of the notification type.
    ///   - actionIdentifier: The identifier of the action.
    ///   - account: The user account from which to retrieve the action. Defaults to the current user.
    /// - Returns: The `Action` if found, otherwise `nil`.
    @objc
    func getAction(notificationTypeApiName: String,
                          actionIdentifier: String,
                          account: UserAccount? = UserAccountManager.shared.currentUserAccount) -> Action? {
        guard let account = account,
              let notificationType = getNotificationType(apiName: notificationTypeApiName, account: account),
              let actionGroups = notificationType.actionGroups else {
            return nil
        }
        return actionGroups
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
    func invokeServerNotificationAction(client: RestClient = RestClient.shared,
                                               notificationId: String,
                                               actionIdentifier: String
    ) async throws -> ActionResultRepresentation {
        guard client.apiVersion.compare("v64.0").rawValue >= 0 else {
            throw PushNotificationManagerError.notificationActionInvocationFailed("API Version must be at least v64.0")
        }
        
        let request = client.request(forInvokeNotificationAction: notificationId, actionIdentifier: actionIdentifier)
        do {
            let response = try await client.send(request: request)
            return try response.asDecodable(type: ActionResultRepresentation.self)
        } catch {
            throw PushNotificationManagerError.notificationActionInvocationFailed(error.localizedDescription)
        }
    }
}

internal extension PushNotificationManager {
    func fetchNotificationTypesFromAPI(with client: RestClient) async throws -> [NotificationType] {
        guard client.apiVersion.compare("v64.0").rawValue >= 0 else {
            throw PushNotificationManagerError.notificationActionInvocationFailed("API Version must be at least v64.0")
        }
        let request = client.requestForNotificationTypes()
        let response = try await client.send(request: request)
        do {
            let result = try JSONDecoder().decode(NotificationTypesResponse.self, from: response.data)
            return result.notificationTypes
        } catch {
            SFSDKCoreLogger.e(PushNotificationManager.self, message: "Decoding error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func storeNotification(types: [NotificationType], with account: UserAccount) throws {
        account.notificationTypes = types
        try UserAccountManager.shared.upsert(account)
    }
    
    func setNotificationCategories(types: [NotificationType]) {
        
        let filterTypes: [NotificationType]
        if let filter = UserAccountManager.shared.filterSupportedNotificationTypes {
            filterTypes = filter(types)
        } else {
            filterTypes = types
        }
        
        let categories = filterTypes
            .flatMap { createNotificationCategories(from: $0) }
        UNUserNotificationCenter.current().setNotificationCategories(Set(categories))
    }
    
    func getCachedNotificationTypes(with account: UserAccount) -> [NotificationType]? {
        return account.notificationTypes
    }
}

private extension PushNotificationManager {
    
    func createNotificationCategories(from type: NotificationType) -> [UNNotificationCategory] {
        guard let actionGroups = type.actionGroups else { return [] }

        return actionGroups.map { group in
            let actions = createActions(from: group)
            return UNNotificationCategory(
                identifier: group.name,
                actions: actions,
                intentIdentifiers: []
            )
        }
    }
    
    func createActions(from actionGroup: ActionGroup?) -> [UNNotificationAction] {
        guard let actionGroup = actionGroup else {
            return []
        }
        
        return actionGroup.actions.compactMap { action in
            UNNotificationAction(
                identifier: action.identifier,
                title: action.label,
                options: [.foreground] // Ensures the app opens if needed
            )
        }
    }
    
    func getNotificationType(apiName: String, account: UserAccount) -> NotificationType? {
        guard let notificationTypes = account.notificationTypes else { return nil }
        return notificationTypes.first { $0.apiName == apiName }
    }
}
