/*
 AppDelegate.swift
 AuthFlowTester
 
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
 
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

import UIKit
import SalesforceSDKCommon
// Imports the non-public Core diagnostics SPI used only by the AuthFlowTester capture switch.
@_spi(Internal) import SalesforceSDKCore
import MobileCoreServices
import UniformTypeIdentifiers
import Combine

#if DEBUG
final class RequestUserAgentCapturePublisher: ObservableObject {
    @MainActor @Published private(set) var publishedSnapshot: [RequestUserAgentCaptureEntry] = []
    private let store = RequestUserAgentCaptureStore()

    func reset() {
        store.reset(onSnapshot: publish)
    }

    func retire(_ userKey: String) {
        store.retire(userKey, onSnapshot: publish)
    }

    func login(_ userKey: String) {
        store.login(userKey)
    }

    func capture(url: URL, taskDescription: String?, userAgent: String) {
        _ = store.capture(
            url: url,
            taskDescription: taskDescription,
            userAgent: userAgent,
            onSnapshot: publish,
            onTokenRequest: { userAgent, url in
                UserDefaults.standard.set(userAgent, forKey: AppDelegate.uiTestLastTokenRequestUserAgentDefaultsKey)
                UserDefaults.standard.set(url, forKey: AppDelegate.uiTestLastTokenRequestUrlDefaultsKey)
            }
        )
    }

    private func publish(_ snapshot: [RequestUserAgentCaptureEntry]) {
        // Enqueue while serialized so concurrent capture/logout/reset publications retain mutation order.
        DispatchQueue.main.async { self.publishedSnapshot = snapshot }
    }
}
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    static let uiTestLastTokenRequestUserAgentDefaultsKey = "AuthFlowTesterLastTokenRequestUserAgent"
    static let uiTestLastTokenRequestUrlDefaultsKey = "AuthFlowTesterLastTokenRequestUrl"
    #if DEBUG
    static let requestUserAgentCapture = RequestUserAgentCapturePublisher()
    static var requestUserAgentCaptureEnabled: Bool { CommandLine.arguments.contains("--captureTokenRequestUserAgent") }
    private var captureObservers: [NSObjectProtocol] = []
    #endif

    private struct UITestLoginHost {
        let name: String
        let host: String
    }

    private static let uiTestLoginHostsInfoKey = "SFDCOAuthLoginHosts"
    
    override init() {
        super.init()

        #if DEBUG
        configureTokenRequestUserAgentCaptureForUITesting()
        #endif
        SalesforceManager.initializeSDK()
        #if DEBUG
        let shouldResetForUITesting = CommandLine.arguments.contains("--resetSDKForUITesting")
        if shouldResetForUITesting {
            SalesforceManager.resetForUITesting()
        }
        seedUITestLoginHosts(selectDefaultHost: shouldResetForUITesting)
        applyNativeLoginLaunchArguments()
        if CommandLine.arguments.contains("--disableDPoPAtStart") {
            SalesforceManager.shared.usesDPoP = false
        }
        if CommandLine.arguments.contains("--invalidateCurrentUserAccessTokenAtStart") {
            UserAccountManager.shared.currentUserAccount?.credentials.setValue("invalid-access-token", forKey: "accessToken")
        }
        #endif
        SalesforceManager.shared.appDisplayName = "Auth Flow Tester"
        UserAccountManager.shared.navigationPolicyForAction = { webView, action in
            if let url = action.request.url, url.absoluteString == "https://www.salesforce.com/us/company/privacy" {
                SFApplicationHelper.open(url, options: [:], completionHandler: nil)
                return .cancel
            }
            return .allow
        }
    }

    #if DEBUG
    /// Captures final SDK request User-Agents for UI tests only. Token requests also retain their
    /// query-free URL so tests can verify the host and path used by a refresh.
    /// This is enabled only for UI tests so production app behavior and diagnostics remain unchanged.
    private func configureTokenRequestUserAgentCaptureForUITesting() {
        Self.requestUserAgentCapture.reset()
        UserDefaults.standard.removeObject(forKey: Self.uiTestLastTokenRequestUserAgentDefaultsKey)
        UserDefaults.standard.removeObject(forKey: Self.uiTestLastTokenRequestUrlDefaultsKey)
        guard Self.requestUserAgentCaptureEnabled else { return }

        for name in [UserAccountManager.willLogoutUser, UserAccountManager.didLogInUser] {
            captureObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { notification in
                guard let account = notification.userInfo?[UserAccountManager.userInfoAccountKey] as? UserAccount,
                      let orgId = account.credentials.organizationId, !orgId.isEmpty,
                      let userId = account.credentials.userId, !userId.isEmpty else { return }
                let key = "\(orgId)/\(userId)"
                if notification.name == UserAccountManager.willLogoutUser {
                    Self.requestUserAgentCapture.retire(key)
                } else {
                    Self.requestUserAgentCapture.login(key)
                }
            })
        }

        // Replaces SFNetwork's process-global metrics sink (and any prior handler); DEBUG + explicit launch argument only.
        Network.metricsCollectedAction = { _, task, metrics in
            let request = RequestUserAgentCaptureStore.selectedRequest(
                transactionRequests: metrics.transactionMetrics.map(\.request),
                originalRequest: task.originalRequest
            )
            guard let url = request?.url,
                  let userAgent = request?.value(forHTTPHeaderField: "User-Agent") else {
                return
            }
            Self.requestUserAgentCapture.capture(url: url, taskDescription: task.taskDescription, userAgent: userAgent)
        }
    }

    /// Maps `--nativeLoginConfig=<json>` and `--authenticationMode=native|browser` onto the SDK's
    /// debug Login Options settings, so UI tests can select Native Login without driving the screen.
    private func applyNativeLoginLaunchArguments() {
        let settings = SalesforceManager.shared.debugLoginSettings
        if let json = Self.launchArgumentValue("--nativeLoginConfig=") {
            do {
                try settings.apply(json: json)
            } catch {
                SalesforceLogger.e(AppDelegate.self, message: "Ignoring --nativeLoginConfig: \(error.localizedDescription)")
            }
        }
        if let name = Self.launchArgumentValue("--authenticationMode=") {
            let modeJson = "{\"\(NativeLoginDebugSettings.JSONKeys.authenticationMode)\":\"\(name)\"}"
            do {
                try settings.apply(json: modeJson)
            } catch {
                SalesforceLogger.e(AppDelegate.self, message: "Ignoring --authenticationMode: \(error.localizedDescription)")
            }
        }
    }

    private static func launchArgumentValue(_ prefix: String) -> String? {
        CommandLine.arguments.last(where: { $0.hasPrefix(prefix) }).map { String($0.dropFirst(prefix.count)) }
    }
    #endif
    
    // MARK: - App delegate lifecycle

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.window = UIWindow(frame: UIScreen.main.bounds)

        // If you wish to register for push notifications, uncomment the line below.  Note that,
        // if you want to receive push notifications from Salesforce, you will also need to
        // implement the application:didRegisterForRemoteNotificationsWithDeviceToken: method (below).
        // self.registerForRemotePushNotifications()

        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Uncomment the code below to register your device token with the push notification manager
        // didRegisterForRemoteNotifications(deviceToken)
    }
    
    func didRegisterForRemoteNotifications(_ deviceToken: Data) {
        PushNotificationManager.sharedInstance().didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
        if let _ = UserAccountManager.shared.currentUserAccount?.credentials.accessToken {
            PushNotificationManager.sharedInstance().registerForSalesforceNotifications { (result) in
                switch (result) {
                case .success(let successFlag):
                    SalesforceLogger.d(AppDelegate.self, message: "Registration for Salesforce notifications status:  \(successFlag)")
                case .failure(let error):
                    SalesforceLogger.e(AppDelegate.self, message: "Registration for Salesforce notifications failed \(error)")
                }
            }
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error ) {
        // Respond to any push notification registration errors here.
    }
    
    // MARK: - Private methods

    /// Seeds AuthFlowTester's fixed UI-test servers after the SDK initializes.  The reset helper
    /// intentionally clears custom hosts, so it must run before the test login flow starts.
    /// Ordinary restarts seed missing entries without changing the selected host or session.
    private func seedUITestLoginHosts(selectDefaultHost: Bool) {
        guard let hosts = Bundle.main.object(forInfoDictionaryKey: Self.uiTestLoginHostsInfoKey) as? [[String: String]] else {
            return
        }

        let uiTestHosts = hosts.compactMap { entry -> UITestLoginHost? in
            guard let name = entry["name"], let host = entry["host"], !host.isEmpty else {
                return nil
            }
            return UITestLoginHost(name: name, host: host)
        }
        guard let defaultHost = uiTestHosts.first else {
            return
        }

        let storage = SFSDKLoginHostStorage.sharedInstance()
        for host in uiTestHosts where storage.loginHost(forHostAddress: host.host) == nil {
            storage.add(SalesforceLoginHost(name: host.name, host: host.host, deletable: false))
        }

        if selectDefaultHost {
            UserAccountManager.shared.loginHost = defaultHost.host
        }
    }

    func registerForRemotePushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            if granted {
                DispatchQueue.main.async {
                    PushNotificationManager.sharedInstance().registerForRemoteNotifications()
                }
            } else {
                SalesforceLogger.d(AppDelegate.self, message: "Push notification authorization denied")
            }
            
            if let error = error {
                SalesforceLogger.e(AppDelegate.self, message: "Push notification authorization error: \(error)")
            }
        }
    }
}
