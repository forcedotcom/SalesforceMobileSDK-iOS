/*
 AppDelegate.swift
 RestAPIExplorerSwift
 
 Created by Nicholas McDonald on 1/3/18.
 
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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
import SalesforceSDKCore
import MobileCoreServices
import UniformTypeIdentifiers

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    override init() {
        
        super.init()
      
        SalesforceManager.initializeSDK()
        SalesforceManager.shared.appDisplayName = "Rest API Explorer"
        
        //Uncomment following block to enable IDP Login flow.
        //SalesforceManager.shared.identityProviderURLScheme = "sampleidpapp"
    }
    
    // MARK: - App delegate lifecycle
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.window = UIWindow(frame: UIScreen.main.bounds)
        
        // If you wish to register for push notifications, uncomment the line below.  Note that,
        // if you want to receive push notifications from Salesforce, you will also need to
        // implement the application:didRegisterForRemoteNotificationsWithDeviceToken: method (below).
        // self.registerForRemotePushNotifications()
        
        // Uncomment the code below to see how you can customize the color, textcolor,
        // font and fontsize of the navigation bar
        // self.customizeLoginView()
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

    func customizeLoginView() {
        let loginViewConfig = SalesforceLoginViewControllerConfig()

        // Set showSettingsIcon to NO if you want to hide the settings icon on the nav bar
        loginViewConfig.showsSettingsIcon = false
        // Set showNavBar to false if you want to hide the top bar
        loginViewConfig.showsNavigationBar = false
        loginViewConfig.navigationBarColor = UIColor(red: 0.051, green: 0.765, blue: 0.733, alpha: 1.0)
        loginViewConfig.navigationTitleColor = UIColor.white
        loginViewConfig.navigationBarFont = UIFont(name: "Helvetica", size: 16.0)
        UserAccountManager.shared.loginViewControllerConfig = loginViewConfig
    }

    func exportTestingCredentials() {
        guard let creds = UserAccountManager.shared.currentUserAccount?.credentials,
              let idData = UserAccountManager.shared.currentUserAccount?.idData,
              let instance = creds.instanceUrl,
              let identity = creds.identityUrl
        else {
                return
        }
        
        var config = [
            "test_client_id": SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey,
            "test_login_domain": UserAccountManager.shared.loginHost,
            "test_redirect_uri": SalesforceManager.shared.bootConfig?.oauthRedirectURI,
            "refresh_token": creds.refreshToken,
            "instance_url": instance.absoluteString,
            "identity_url": identity.absoluteString,
            "access_token": "__NOT_REQUIRED__",
            "organization_id": creds.organizationId,
            "username": idData.username,
            "user_id": creds.userId,
            "display_name": idData.displayName,
            "photo_url": idData.pictureUrl?.absoluteString
        ]
        if let community = creds.communityUrl {
            config["community_url"] = community.absoluteString
        }
    
        let configJSON = SFJsonUtils.jsonRepresentation(config)
        let board = UIPasteboard.general
        board.setValue(configJSON, forPasteboardType: UTType.utf8PlainText.identifier)
    }
}
