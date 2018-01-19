//
//  ViewController.swift
//  SmartSyncExplorerSwift
//
//  Created by Nicholas McDonald on 1/16/18.
//  Copyright © 2018 Salesforce. All rights reserved.
//

import UIKit
import SalesforceSDKCore.SFDefaultUserManagementViewController
import SalesforceSDKCore.SFUserAccountManager
import SalesforceSDKCore.SFSecurityLockout
import SalesforceSDKCore.SalesforceSDKManager
import SmartStore.SFSmartStoreInspectorViewController
import SmartSyncExplorerCommon

class RootViewController: UIViewController {
    
    fileprivate let dataManager = SObjectDataManager(dataSpec: ContactSObjectData.dataSpec())
    fileprivate var isSearching = false
    fileprivate var searchText:String = ""
    fileprivate let tableView = UITableView(frame: .zero, style: .plain)
    fileprivate let searchController = UISearchController(searchResultsController: nil)

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(clearPopoversForPasscode),
                                               name: NSNotification.Name(rawValue: kSFPasscodeFlowWillBegin),
                                               object: nil)
        
        self.navigationController?.navigationBar.barTintColor = UIColor.appDarkBlue
        self.navigationController?.navigationBar.isTranslucent = false
        UIApplication.shared.statusBarStyle = .lightContent
        
        guard let font = UIFont.appRegularFont(20) else { return }
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white, NSAttributedStringKey.font: font]
        self.title = "RestAPI Explorer"
        
        guard let settings = UIImage(named: "setting")?.withRenderingMode(.alwaysOriginal),
            let sync = UIImage(named: "sync")?.withRenderingMode(.alwaysOriginal),
            let add = UIImage(named: "plusButton")?.withRenderingMode(.alwaysOriginal) else { return }
        let settingsButton = UIBarButtonItem(image: settings, style: .plain, target: self, action: #selector(didPressSettingsButton))
        let syncButton = UIBarButtonItem(image: sync, style: .plain, target: self, action: #selector(didPressSyncUpDown))
        let addButton = UIBarButtonItem(image: add, style: .plain, target: self, action: #selector(didPressAddContact))
        self.navigationItem.rightBarButtonItems = [settingsButton, syncButton, addButton]
        
        self.searchController.searchResultsUpdater = self
        self.searchController.dimsBackgroundDuringPresentation = true
        self.definesPresentationContext = true
        
        self.tableView.tableHeaderView = self.searchController.searchBar
        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier:"cell")
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.view.addSubview(self.tableView)
        
        let safe = self.view.safeAreaLayoutGuide
        self.tableView.leftAnchor.constraint(equalTo: safe.leftAnchor).isActive = true
        self.tableView.rightAnchor.constraint(equalTo: safe.rightAnchor).isActive = true
        self.tableView.topAnchor.constraint(equalTo: safe.topAnchor).isActive = true
        self.tableView.bottomAnchor.constraint(equalTo: safe.bottomAnchor).isActive = true
        
        let completion: (() -> Void) = { [weak self] in
            self?.refreshList()
        }
        self.dataManager?.refreshLocalData(completion)
        
        if let data = self.dataManager?.dataRows {
            if data.count == 0 {
                self.dataManager?.refreshRemoteData(completion)
            }
        } else {
            self.dataManager?.refreshRemoteData(completion)
        }
    }

    @objc func didPressSettingsButton() {
        
    }
    
    @objc func didPressAddContact() {
        
    }
    
    @objc func didPressSyncUpDown() {
        
    }
    
    @objc func clearPopoversForPasscode() {
        SFSDKLogger.log(type(of: self), level: .debug, message: "Passcode screen loading. Clearing popovers")
        
        // TODO
    }
    
    fileprivate func refreshList() {
        self.dataManager?.filter(onSearchTerm: self.searchText, completion: { [unowned self] in
            self.tableView.reloadData()
            if self.isSearching && self.searchController.searchBar.isFirstResponder {
                self.searchController.searchBar.becomeFirstResponder()
            }
        })
    }
    
    fileprivate func nameStringFromContact(_ obj:ContactSObjectData) -> String {
        let firstName = obj.firstName
        let lastName = obj.lastName
        
        if firstName == nil && lastName == nil {
            return ""
        } else if firstName == nil && lastName != nil {
            return lastName!
        } else if firstName != nil && lastName == nil {
            return firstName!
        } else {
            return "\(firstName!) \(lastName!)"
        }
    }
    
    fileprivate func titleStringFromContact(_ obj:ContactSObjectData) -> String {
        return ""
    }
    
    fileprivate func initialsStringFromContact(_ obj:ContactSObjectData) -> String {
        return ""
    }
    
    fileprivate func colorFromContact(_ obj:ContactSObjectData) -> UIColor {
        return UIColor.white
    }
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension RootViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        
    }
}

extension RootViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
}

extension RootViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let data = self.dataManager?.dataRows {
            print("returning \(data.count) dataRows")
            return data.count
        } else {
            print("no data rows")
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        if let data = self.dataManager?.dataRows {
            if let obj = data[indexPath.row] as? ContactSObjectData {
                cell.textLabel?.text = self.nameStringFromContact(obj)
            }
        }
        cell.textLabel?.text = "\(indexPath.row)"
        return cell
    }
}

