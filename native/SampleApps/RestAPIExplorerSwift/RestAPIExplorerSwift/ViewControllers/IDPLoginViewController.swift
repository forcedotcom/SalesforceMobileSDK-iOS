//
//  IDPLoginViewController.swift
//  RestAPIExplorerSwift
//
//  Created by Nicholas McDonald on 1/15/18.
//  Copyright © 2018 Salesforce. All rights reserved.
//

import UIKit
import SalesforceSDKCore.SFSDKLoginHostListViewController
import SalesforceSDKCore.SFSDKResourceUtils
import SalesforceSDKCore.SFUserAccountManager
import SalesforceSDKCore.SFSDKLoginHost

@objc protocol IDPLoginViewControllerDelegate: NSObjectProtocol {
    @objc optional func loginUsingIDP()
    @objc optional func loginUsingApp()
}

class IDPLoginViewController: UIViewController {

    weak var loginSelectionDelegate:IDPLoginViewControllerDelegate?
    fileprivate var loginHostViewController:SFSDKLoginHostListViewController?
    fileprivate lazy var loginHostListViewController:SFSDKLoginHostListViewController = {
        let l = SFSDKLoginHostListViewController(style: .plain)
        l.delegate = self
        return l
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.white

        self.navigationController?.navigationBar.barTintColor = UIColor.appDarkBlue
        self.navigationController?.navigationBar.isTranslucent = false
        UIApplication.shared.statusBarStyle = .lightContent
        
        guard let font = UIFont.appRegularFont(20) else { return }
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white, NSAttributedStringKey.font: font]
        self.title = "Log in"
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(container)
        container.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        container.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        container.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 1.0, constant: -100).isActive = true
        
        let selectLabel = UILabel()
        selectLabel.translatesAutoresizingMaskIntoConstraints = false
        selectLabel.text = "Select a login flow"
        selectLabel.font = UIFont.appRegularFont(20)
        selectLabel.textAlignment = .center
        
        let idpLabel = UILabel()
        idpLabel.translatesAutoresizingMaskIntoConstraints = false
        idpLabel.text = "Use the IDP option if you prefer to share your credentials between multiple apps"
        idpLabel.font = UIFont.appRegularFont(16)
        
        let idpButton = UIButton(type: .custom)
        idpButton.translatesAutoresizingMaskIntoConstraints = false
        idpButton.setTitle("Log in Using IDP Application", for: .normal)
        idpButton.titleLabel?.font = UIFont.appRegularFont(16)
        idpButton.backgroundColor = UIColor.appButton
        idpButton.layer.cornerRadius = 4.0
        idpButton.addTarget(self, action: #selector(loginIDPAction), for: .touchUpInside)
        
        let appLabel = UILabel()
        appLabel.translatesAutoresizingMaskIntoConstraints = false
        appLabel.text = "Use this option if you prefer to use your credentials for this app only."
        appLabel.font = UIFont.appRegularFont(16)
        
        let appButton = UIButton(type: .custom)
        appButton.translatesAutoresizingMaskIntoConstraints = false
        appButton.setTitle("Log in Using App", for: .normal)
        appButton.titleLabel?.font = UIFont.appRegularFont(16)
        appButton.backgroundColor = UIColor.appButton
        appButton.layer.cornerRadius = 4.0
        appButton.addTarget(self, action: #selector(loginLocalAction), for: .touchUpInside)
        
        container.addSubview(selectLabel)
        container.addSubview(idpLabel)
        container.addSubview(idpButton)
        container.addSubview(appLabel)
        container.addSubview(appButton)
        
        selectLabel.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
        selectLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor).isActive = true
        
        idpLabel.topAnchor.constraint(equalTo: selectLabel.bottomAnchor, constant:60).isActive = true
        idpLabel.leftAnchor.constraint(equalTo: container.leftAnchor).isActive = true
        idpLabel.rightAnchor.constraint(equalTo: container.rightAnchor).isActive = true
        
        idpButton.topAnchor.constraint(equalTo: idpLabel.bottomAnchor, constant:14).isActive = true
        idpButton.leftAnchor.constraint(equalTo: container.leftAnchor).isActive = true
        idpButton.rightAnchor.constraint(equalTo: container.rightAnchor).isActive = true
        idpButton.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        
        appLabel.topAnchor.constraint(equalTo: idpButton.bottomAnchor, constant:60).isActive = true
        appLabel.leftAnchor.constraint(equalTo: container.leftAnchor).isActive = true
        appLabel.rightAnchor.constraint(equalTo: container.rightAnchor).isActive = true
        
        appButton.topAnchor.constraint(equalTo: appLabel.bottomAnchor, constant:14).isActive = true
        appButton.leftAnchor.constraint(equalTo: container.leftAnchor).isActive = true
        appButton.rightAnchor.constraint(equalTo: container.rightAnchor).isActive = true
        appButton.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        appButton.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
    }
    
    func showSettingsIcon() {
        let image = SFSDKResourceUtils.imageNamed("login-window-gear").withRenderingMode(.alwaysTemplate)
        let barButton = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(showLoginHost))
        barButton.accessibilityLabel = SFSDKResourceUtils.localizedString("LOGIN_CHOOSE_SERVER")
        self.navigationController?.navigationBar.topItem?.rightBarButtonItem = barButton
        self.navigationController?.navigationBar.topItem?.rightBarButtonItem?.tintColor = UIColor.white
    }

    @objc func showLoginHost() {
        self.showHostListView()
    }
    
    @objc func loginIDPAction() {
        guard let d = self.loginSelectionDelegate else {return}
        d.loginUsingIDP?()
    }
    
    @objc func loginLocalAction() {
        guard let d = self.loginSelectionDelegate else {return}
        d.loginUsingApp?()
    }
    
    func showHostListView() {
        let navController = UINavigationController(rootViewController: self.loginHostListViewController)
        navController.modalPresentationStyle = .pageSheet
        self.present(navController, animated: true, completion: nil)
    }
    
    func hideHostListView(_ animated:Bool) {
        self.dismiss(animated: animated, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension IDPLoginViewController: SFSDKLoginHostDelegate {
    func hostListViewControllerDidAddLoginHost(_ hostListViewController: SFSDKLoginHostListViewController) {
        self.hideHostListView(false)
    }
    
    func hostListViewControllerDidSelectLoginHost(_ hostListViewController: SFSDKLoginHostListViewController) {
        self.hideHostListView(false)
    }
    
    func hostListViewControllerDidCancelLoginHost(_ hostListViewController: SFSDKLoginHostListViewController) {
        self.hideHostListView(true)
    }
    
    func hostListViewController(_ hostListViewController: SFSDKLoginHostListViewController, didChange newLoginHost: SFSDKLoginHost) {
        SFUserAccountManager.sharedInstance().loginHost = newLoginHost.host
        SFUserAccountManager.sharedInstance().switchToNewUser()
    }
}
