//
//  AppDelegate.swift
//  FileExplorer
//
//  Created by Wolfgang Mathurin on 7/28/14.
//  Copyright (c) 2014 salesforce. All rights reserved.
//

import Foundation
import UIKit

// Fill these in when creating a new Connected Application on Force.com
let RemoteAccessConsumerKey = "3MVG9Iu66FKeHhINkB1l7xt7kR8czFcCTUhgoA8Ol2Ltf1eYHOU4SqQRSEitYFDUpqRWcoQ2.dBv_a1Dyu5xa";
let OAuthRedirectURI        = "testsfdc:///mobilesdk/detect/oauth/done";
let scopes = ["api"];

@UIApplicationMain
class AppDelegate : UIResponder, UIApplicationDelegate, SFAuthenticationManagerDelegate, SFUserAccountManagerDelegate
{
    var window: UIWindow?
    let initialLoginSuccessBlock: SFOAuthFlowSuccessCallbackBlock?
    let initialLoginFailureBlock: SFOAuthFlowFailureCallbackBlock?
    
    init()
    {
        super.init()
        SFLogger.setLogLevel(SFLogLevelDebug)
        
        // These SFAccountManager settings are the minimum required to identify the Connected App.
        SFUserAccountManager.sharedInstance().oauthClientId = RemoteAccessConsumerKey
        SFUserAccountManager.sharedInstance().oauthCompletionUrl = OAuthRedirectURI
        SFUserAccountManager.sharedInstance().scopes = NSSet(array:scopes)
        
        // Auth manager delegate, for receiving logout and login host change events.
        SFAuthenticationManager.sharedManager().addDelegate(self)
        SFUserAccountManager.sharedInstance().addDelegate(self)
        
        // Blocks to execute once authentication has completed.  You could define these at the different boundaries where
        // authentication is initiated, if you have specific logic for each case.
        self.initialLoginSuccessBlock = {
            [weak self] info in
            self!.setupRootViewController()
        }
        
        self.initialLoginFailureBlock = {
            info, error in
            SFAuthenticationManager.sharedManager().logout()
        }
    }

    deinit
    {
        SFAuthenticationManager.sharedManager().removeDelegate(self)
        SFUserAccountManager.sharedInstance().removeDelegate(self)
    }
    
    // MARK: - App delegate lifecycle
    
    func application(application: UIApplication!, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]!) -> Bool
    {
        self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
        self.initializeAppViewState();
        
        //
        // If you wish to register for push notifications, uncomment the line below.  Note that,
        // if you want to receive push notifications from Salesforce, you will also need to
        // implement the application:didRegisterForRemoteNotificationsWithDeviceToken: method (below).
        //
        // SFPushNotificationManager.sharedInstance().registerForRemoteNotifications()
        
        SFAuthenticationManager.sharedManager().loginWithCompletion(self.initialLoginSuccessBlock, failure: self.initialLoginFailureBlock)
        
        return true
    }
    
    func application(application: UIApplication!, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData!)
    {
        //
        // Uncomment the code below to register your device token with the push notification manager
        //
        //
        // SFPushNotificationManager.sharedInstance().didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
        // if (SFAccountManager.sharedInstance().credentials.accessToken != nil)
        // {
        //    SFPushNotificationManager.sharedInstance().registerForSalesforceNotifications()
        // }
    }
    
    
    func application(application: UIApplication!, didFailToRegisterForRemoteNotificationsWithError error: NSError!)
    {
        // Respond to any push notification registration errors here.
    }

    // MARK: - Private methods
    func initializeAppViewState()
    {
        self.window!.rootViewController = InitialViewController(nibName: nil, bundle: nil)
        self.window!.makeKeyAndVisible()
    }
    
    func setupRootViewController()
    {
        let rootVC = RootViewController(nibName: nil, bundle: nil)
        let navVC = UINavigationController(rootViewController: rootVC)
        self.window!.rootViewController = navVC
    }
    
    // MARK: - SFAuthenticationManagerDelegate
    func authManagerDidLogout(manager: SFAuthenticationManager!)
    {
        self.log(SFLogLevelDebug, msg: "SFAuthenticationManagerDelegate")
        self.initializeAppViewState()
        
        // Multi-user pattern:
        // - If there are two or more existing accounts after logout, let the user choose the account
        //   to switch to.
        // - If there is one existing account, automatically switch to that account.
        // - If there are no further authenticated accounts, present the login screen.
        //
        // Alternatively, you could just go straight to re-initializing your app state, if you know
        // your app does not support multiple accounts.  The logic below will work either way.
        
        let allAccounts = SFUserAccountManager.sharedInstance().allUserAccounts
        if (allAccounts.count > 1)
        {
            let userSwitchVc = SFDefaultUserManagementViewController(completionBlock: {
                [unowned self] action in
                self.window!.rootViewController.dismissViewControllerAnimated(true, completion: nil)
                })
            self.window!.rootViewController.presentViewController(userSwitchVc, animated: true, completion: nil)
        }
        else if (SFUserAccountManager.sharedInstance().allUserAccounts.count == 1)
        {
            SFUserAccountManager.sharedInstance().currentUser = SFUserAccountManager.sharedInstance().allUserAccounts[0] as SFUserAccount
            SFAuthenticationManager.sharedManager().loginWithCompletion(self.initialLoginSuccessBlock, failure: self.initialLoginFailureBlock)
        }
        else {
            SFAuthenticationManager.sharedManager().loginWithCompletion(self.initialLoginSuccessBlock, failure: self.initialLoginFailureBlock)
        }
    }
    
    // MARK: - SFUserAccountManagerDelegate
    func userAccountManager(userAccountManager: SFUserAccountManager!, didSwitchFromUser fromUser: SFUserAccount!, toUser: SFUserAccount!)
    {
        self.log(SFLogLevelDebug, msg: "SFUserAccountManager changed from user \(fromUser.userName) to \(toUser.userName).  Resetting app.")
        self.initializeAppViewState()
        SFAuthenticationManager.sharedManager().loginWithCompletion(self.initialLoginSuccessBlock, failure: self.initialLoginFailureBlock)
    }
}