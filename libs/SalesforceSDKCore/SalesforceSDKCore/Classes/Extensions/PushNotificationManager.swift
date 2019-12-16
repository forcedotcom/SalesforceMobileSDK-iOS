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
