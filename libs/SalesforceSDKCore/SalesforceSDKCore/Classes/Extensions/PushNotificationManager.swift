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
}

@objc
extension PushNotificationManager {
    /// Retrieves available notification types from the API or local cache if the API request fails.
    ///
    /// - Parameters:
    ///   - restClient: The `RestClient` instance used to fetch notification types from the API.
    ///   - userDefaults: Stores and retrieves cached notification types. Defaults to `.standard`.
    /// - Returns: A tuple containing:
    ///   - `Bool`: `true` if notification types were successfully retrieved and stored; `false` if retrieval failed.
    ///   - `Error?`: An error object if retrieval fails completely, or `nil` if successful.
    ///
    /// If the API fetch fails, the function attempts to retrieve notification types from the cache.
    /// If neither source provides data, the function returns `false` with an appropriate error.
    @objc
    public func getNotificationTypes(restClient: RestClient = RestClient.shared,
                                     account: UserAccount) async -> (Bool, Error?) {
        do {
            let types = try await fetchNotificationTypesFromAPI(with: restClient)
            storeNotification(types: types, with: account)
            setNotificationCategories(types: types)
            return (true, nil)
        } catch {
            print("API fetch failed: \(error.localizedDescription). Trying cache...")
            guard let cachedTypes = getCachedNotificationTypes(with: account) else {
                print("No cached notification types available.")
                return (false, PushNotificationManagerError.failedNotificationTypesRetrieval as Error)
            }
            print("Using cached notification types.")
            setNotificationCategories(types: cachedTypes)
            return (true, nil)
        }
    }
}

