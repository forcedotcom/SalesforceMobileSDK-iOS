@testable import SalesforceSDKCore

class MockUserAccountManager: UserAccountManaging {
    var mockUserAccount: UserAccount? = UserAccount()
    let mockInfo = AuthInfo()
    
    var shouldError = false
    
    func account() -> UserAccount? {
        mockUserAccount
    }
    
    func refresh(credentials: OAuthCredentials, _ completionBlock: @escaping (Result<(UserAccount, AuthInfo), SalesforceSDKCore.UserAccountManagerError>) -> Void) -> Bool {
        if shouldError {
            let error = NSError(domain: "test", code: 1, userInfo: nil)
            let refreshError = UserAccountManagerError.refreshFailed(underlyingError: error, authInfo: mockInfo)
            completionBlock(.failure(refreshError))
        } else {
            completionBlock(.success((mockUserAccount!, mockInfo)))
        }
        return true
    }
}
