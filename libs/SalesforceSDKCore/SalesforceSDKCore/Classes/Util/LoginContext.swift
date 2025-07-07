import Foundation

@objc(SFSDKLoginContext)
@objcMembers
class LoginContext: NSObject {
    var loginHint: String?
    var loginHost: String?
    var manager: UserAccountManaging?
    var appConfig: BootstrappingConfig?

    init(loginHint: String?, loginHost: String?, userAccountManager: UserAccountManaging?, appConfig: BootstrappingConfig?) {
        self.loginHint = loginHint
        self.loginHost = loginHost
        self.manager = userAccountManager
        self.appConfig = appConfig
    }

    func hasLoginHint() -> Bool {
        return (loginHint?.count ?? 0) > 0
    }

    func hasLoginHost() -> Bool {
        return (loginHost?.count ?? 0) > 0
    }

    func shouldLogin() -> Bool {
        return (hasLoginHint() && hasLoginHost()) ||
        ((manager?.account() == nil) && (appConfig?.shouldAuthenticateOnFirstLaunch == true))
    }
} 
