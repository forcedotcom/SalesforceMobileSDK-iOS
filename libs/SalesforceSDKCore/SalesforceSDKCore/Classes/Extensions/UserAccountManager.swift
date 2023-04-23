
/*
 UserAccountManager.swift
 SalesforceSDKCore
 
 Created by Raj Rao on 10/21/19.
 
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

public enum UserAccountManagerError: Error {
    case loginFailed(underlyingError: Error, authInfo: AuthInfo)
    case loginJWTFailed(underlyingError: Error, authInfo: AuthInfo)
    case refreshFailed(underlyingError: Error, authInfo: AuthInfo)
    case userSwitchFailed(underlyingError: Error)
    case userSwitchFailedUnknown
}

extension UserAccountManager {
    
    ///  Kick off the login process for credentials that's previously configured.
    /// - Parameter completionBlock: completion block to invoke with a success tuple (UserAccount, AuthInfo) or   UserAccountManagerError for failure wrapped in a Result type.
    public func login(_ completionBlock: @escaping (Result<(UserAccount, AuthInfo), UserAccountManagerError>) -> Void) -> Bool {
        return __login(completion: { (authInfo, userAccount) in
             completionBlock(Result.success((userAccount,authInfo)))
        }) { (authInfo, error) in
            completionBlock(Result.failure(.loginFailed(underlyingError: error, authInfo: authInfo)))
        }
    }

    /// Kick off the login process for jwt token with credentials previously configured.
    /// - Parameters:
    ///   - jwt: the jwt token
    ///   - completionBlock: completion block to invoke with a success tuple (UserAccount, AuthInfo) or   UserAccountManagerError for failure wrapped in a Result type.
   public func login(using jwt: String, _ completionBlock: @escaping (Result<(UserAccount, AuthInfo), UserAccountManagerError>) -> Void) -> Bool {
        return __login(withJwtToken: jwt, completion: { (authInfo, userAccount) in
            completionBlock(Result.success((userAccount,authInfo)))
        }) { (authInfo, error) in
            completionBlock(Result.failure(.loginJWTFailed(underlyingError: error, authInfo: authInfo)))
        }
   }

    /// Kick off the login process for jwt token with credentials previously configured.
    /// - Parameters:
    ///   - credentials: the OAuthCredentials object
    ///   - completionBlock: completion block to invoke with a success tuple (UserAccount, AuthInfo) or   UserAccountManagerError for failure wrapped in a Result type.
   public func refresh(credentials: OAuthCredentials, _ completionBlock: @escaping (Result<(UserAccount, AuthInfo), UserAccountManagerError>) -> Void) -> Bool {
        return __refreshCredentials(credentials, completion: { (authInfo, userAccount) in
            completionBlock(Result.success((userAccount,authInfo)))
        }) { (authInfo, error) in
            completionBlock(Result.failure(.refreshFailed(underlyingError: error, authInfo: authInfo)))
        }
    }

    /// Switch to a new user. Kicks off the login flow. Once complete switches to a new user on success else does not change the current user.
    /// - Parameter completionBlock: completion block to invoke with a  UserAccount on success or  UserAccountManagerError on  failure wrapped in a Result type.
    public func switchToNewUserAccount(_ completionBlock: @escaping (Result<UserAccount, UserAccountManagerError>) -> Void) {
        return __switchToNewUser { (err, userAccount) in
            guard let user = userAccount else {
                var switchUserError = UserAccountManagerError.userSwitchFailedUnknown
                if let error = err {
                   switchUserError = UserAccountManagerError.userSwitchFailed(underlyingError: error)
                }
                completionBlock(Result.failure(switchUserError))
                return
            }
            completionBlock(Result.success(user))
        }
    }

    /// Handle an authentication request with auth code from the IDP application
    /// - Parameters:
    ///    - url: The URL response returned to the app from the IDP application.
    ///    - options: Dictionary of name-value pairs received from open URL
    ///    - completion: Completion block to invoke with a UserAccount on success or UserAccountManagerError on failure wrapped in a Result type.
    /// - Returns: true if this is a valid URL response from IDP authentication that should be handled, false otherwise.
    public func handleIdentityProviderCommand(from url: URL, with options: [AnyHashable: Any], completion: @escaping (Result<(UserAccount, AuthInfo), UserAccountManagerError>) -> Void) -> Bool {
        return __handleIDPAuthenticationCommand(url, options: options, completion: { (authInfo, userAccount) in
            completion(Result.success((userAccount, authInfo)))
        }) { (authInfo, error) in
            completion(Result.failure(.loginFailed(underlyingError: error, authInfo: authInfo)))
        }
    }
}
