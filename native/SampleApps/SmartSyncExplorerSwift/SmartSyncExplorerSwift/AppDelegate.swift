/*
 AppDelegate.swift
 SmartSyncExplorerSwift

 Created by Nicholas McDonald on 1/16/18.
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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
import SalesforceSwiftSDK
import MobileCoreServices
import SalesforceSDKCore.SFPushNotificationManager
import SalesforceSDKCore.SFDefaultUserManagementViewController
import SalesforceSDKCore.SalesforceSDKManager
import SalesforceSDKCore.SFUserAccountManager
import SalesforceSDKCore.SFSDKAppConfig
import SalesforceSDKCore.SFSDKWindowManager
import SmartSync.SmartSyncSDKManager
import SalesforceAnalytics.SFSDKDatasharingHelper
import SalesforceAnalytics.NSUserDefaults_SFAdditions
import SmartSyncExplorerCommon.SmartSyncExplorerConfig


// Fill these in when creating a new Connected Application on Force.com
//let RemoteAccessConsumerKey = "3MVG9Iu66FKeHhINkB1l7xt7kR8czFcCTUhgoA8Ol2Ltf1eYHOU4SqQRSEitYFDUpqRWcoQ2.dBv_a1Dyu5xa"
//let OAuthRedirectURI        = "testsfdc:///mobilesdk/detect/oauth/done"

let RemoteAccessConsumerKey = "3MVG9g9rbsTkKnAWkkUnzOrokwAGv9LB5W9tdPJEcQM9xMhNTQnnYHvCwjnjc3zQG5hQ_krRCb52wn0TU2kZH"
let OAuthRedirectURI        = "com.salesforce.mobilesdk.sample.smartsyncexplorer://oauth2/success"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    override init() {
        super.init()
        
        guard let config = SmartSyncExplorerConfig.sharedInstance() else { return }
        SFSDKDatasharingHelper.sharedInstance().appGroupName = config.appGroupName
        SFSDKDatasharingHelper.sharedInstance().appGroupEnabled = config.appGroupsEnabled
        
        SalesforceSwiftSDKManager.setInstanceClass(SmartSyncSDKManager.self)
        SalesforceSDKManager.shared().appConfig?.remoteAccessConsumerKey = config.remoteAccessConsumerKey
        SalesforceSDKManager.shared().appConfig?.oauthRedirectURI = config.oauthRedirectURI
        SalesforceSDKManager.shared().appConfig?.oauthScopes = NSSet(array: config.oauthScopes) as! Set<AnyHashable>
        
        SalesforceSDKManager.shared().add(self)
        
        /*
         // scheme of idpApp
         SFUserAccountManager.sharedInstance().advancedAuthConfiguration = .none
         SalesforceSwiftSDKManager.shared().idpAppURIScheme = "sampleidpapp"
         // user friendly display name
         SalesforceSwiftSDKManager.shared().appDisplayName = "RestAPIExplorerSwift"
         
         // Use the following code to replace the login flow selection dialog
         SalesforceSwiftSDKManager.shared().idpLoginFlowSelectionBlock = {
         let controller = IDPLoginNavViewController()
         return controller as UIViewController & SFSDKLoginFlowSelectionView
         }
         */
        
        SalesforceSDKManager.shared().postLaunchAction = { [unowned self] (launchActionList: SFSDKLaunchAction) -> Void in
            //
            // If you wish to register for push notifications, uncomment the line below.  Note that,
            // if you want to receive push notifications from Salesforce, you will also need to
            // implement the application:didRegisterForRemoteNotificationsWithDeviceToken: method (below).
            //
            //SFPushNotificationManager.sharedInstance().registerForRemoteNotifications()
            //
            
            self.setUserLoginStatus(true)
            let launchActionString = SalesforceSDKManager.launchActionsStringRepresentation(launchActionList)
            SalesforceSwiftLogger.log(type(of:self), level:.info, message:"Post-launch: launch actions taken: \(launchActionString)")
            self.setupRootViewController()
        }
        
        SalesforceSDKManager.shared().postLogoutAction = { [unowned self] in
            self.setUserLoginStatus(false)
            self.handleSdkManagerLogout()
        }
        
        SalesforceSDKManager.shared().switchUserAction = { [unowned self] (fromUser: SFUserAccount?, toUser: SFUserAccount?) -> () in
            self.setUserLoginStatus(false)
            self.handleUserSwitch(fromUser, toUser: toUser)
        }
        
        SalesforceSDKManager.shared().launchErrorAction = { [unowned self] (error: Error, launchActionList: SFSDKLaunchAction) in
            SFSDKLogger.log(type(of:self), level:.error, message:"Error during SDK launch: \(error.localizedDescription)")
            self.initializeAppViewState()
            SalesforceSDKManager.shared().launch()
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool
    {
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.initializeAppViewState();
        
        // If you wish to register for push notifications, uncomment the line below.  Note that,
        // if you want to receive push notifications from Salesforce, you will also need to
        // implement the application:didRegisterForRemoteNotificationsWithDeviceToken: method (below).
        //
        // SFPushNotificationManager.sharedInstance().registerForRemoteNotifications()
        
        //Uncomment the code below to see how you can customize the color, textcolor, font and fontsize of the navigation bar
        //var loginViewConfig = SFSDKLoginViewControllerConfig()
        //Set showSettingsIcon to NO if you want to hide the settings icon on the nav bar
        //loginViewConfig.showSettingsIcon = false
        //Set showNavBar to NO if you want to hide the top bar
        //loginViewConfig.showNavbar = true
        //loginViewConfig.navBarColor = UIColor(red: 0.051, green: 0.765, blue: 0.733, alpha: 1.0)
        //loginViewConfig.navBarTextColor = UIColor.white
        //loginViewConfig.navBarFont = UIFont(name: "Helvetica", size: 16.0)
        //SFUserAccountManager.sharedInstance().loginViewControllerConfig = loginViewConfig
        
        SalesforceSDKManager.shared().launch()
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    {
        //
        // Uncomment the code below to register your device token with the push notification manager
        //
        //
        // SFPushNotificationManager.sharedInstance().didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
        // if (SFUserAccountManager.sharedInstance().currentUser?.credentials.accessToken != nil)
        // {
        //    SFPushNotificationManager.sharedInstance().registerForSalesforceNotifications()
        // }
    }
    
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error )
    {
        // Respond to any push notification registration errors here.
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        
        // If you're using advanced authentication:
        // --Configure your app to handle incoming requests to your
        //   OAuth Redirect URI custom URL scheme.
        // --Uncomment the following line and delete the original return statement:
        
//        return  SFUserAccountManager.sharedInstance().handleAdvancedAuthenticationResponse(url, options: options)
        return false;
    }
    
    // MARK: - Private methods
    
    func setUserLoginStatus(_ loggedIn:Bool) {
        UserDefaults.msdk().set(loggedIn, forKey: "userLoggedIn")
        UserDefaults.msdk().synchronize()
        SFSDKLogger.log(type(of:self), level: .debug, message: "userLoggedIn: \(loggedIn)")
    }
    
    func initializeAppViewState()
    {
        if (!Thread.isMainThread) {
            DispatchQueue.main.async {
                self.initializeAppViewState()
            }
            return
        }
        
        self.window!.rootViewController = InitialViewController(nibName: nil, bundle: nil)
        self.window!.makeKeyAndVisible()
    }
    
    func setupRootViewController()
    {
        let rootVC = RootViewController(nibName: nil, bundle: nil)
        let navVC = UINavigationController(rootViewController: rootVC)
        self.window!.rootViewController = navVC
    }
    
    func resetViewState(_ postResetBlock: @escaping () -> ())
    {
        if let rootViewController = self.window!.rootViewController {
            if let _ = rootViewController.presentedViewController {
                rootViewController.dismiss(animated: false, completion: postResetBlock)
                return
            }
        }
        
        postResetBlock()
    }
    
    func handleSdkManagerLogout()
    {
        SFSDKLogger.log(type(of:self), level:.debug, message: "SFUserAccountManager logged out.  Resetting app.")
        self.resetViewState { () -> () in
            self.initializeAppViewState()
            
            // Multi-user pattern:
            // - If there are two or more existing accounts after logout, let the user choose the account
            //   to switch to.
            // - If there is one existing account, automatically switch to that account.
            // - If there are no further authenticated accounts, present the login screen.
            //
            // Alternatively, you could just go straight to re-initializing your app state, if you know
            // your app does not support multiple accounts.  The logic below will work either way.
            
            var numberOfAccounts : Int;
            let allAccounts = SFUserAccountManager.sharedInstance().allUserAccounts()
            numberOfAccounts = (allAccounts!.count);
            
            if numberOfAccounts > 1 {
                let userSwitchVc = SFDefaultUserManagementViewController(completionBlock: {
                    action in
                    self.window!.rootViewController!.dismiss(animated:true, completion: nil)
                })
                if let actualRootViewController = self.window!.rootViewController {
                    actualRootViewController.present(userSwitchVc, animated: true, completion: nil)
                }
            } else {
                if (numberOfAccounts == 1) {
                    SFUserAccountManager.sharedInstance().currentUser = allAccounts![0]
                }
                SalesforceSDKManager.shared().launch()
            }
        }
    }
    
    func handleUserSwitch(_ fromUser: SFUserAccount?, toUser: SFUserAccount?)
    {
        let fromUserName = (fromUser != nil) ? fromUser?.userName : "<none>"
        let toUserName = (toUser != nil) ? toUser?.userName : "<none>"
        SFSDKLogger.log(type(of:self), level:.debug, message:"SFUserAccountManager changed from user \(String(describing: fromUserName)) to \(String(describing: toUserName)).  Resetting app.")
        self.resetViewState { () -> () in
            self.initializeAppViewState()
            SalesforceSDKManager.shared().launch()
        }
    }
}

extension AppDelegate: SalesforceSDKManagerDelegate {
    
    func sdkManagerWillResignActive() {
        if SalesforceSwiftSDKManager.shared().useSnapshotView {
            SFSDKWindowManager.shared().activeWindow()?.window?.endEditing(true)
        }
    }
}

