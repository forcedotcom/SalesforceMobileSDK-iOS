//
//  AdditionalActionsViewController.swift
//  SmartSyncExplorerSwift
//
//  Created by Nicholas McDonald on 2/3/18.
//  Copyright © 2018 Salesforce. All rights reserved.
//

import UIKit

class AdditionalActionsViewController: UITableViewController {
    
    var onLogoutSelected: (() -> ())?
    var onSwitchUserSelected : (() -> ())?
    var onDBInspectorSelected : (() -> ())?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "reuseId")
        self.tableView.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseId", for: indexPath)
        
        cell.textLabel?.font = UIFont.appRegularFont(12.0)
        cell.textLabel?.textColor = UIColor.labelText
        
        if indexPath.row == 0 {
            cell.textLabel?.text = "Logout"
        } else if indexPath.row == 1 {
            cell.textLabel?.text = "Switch User"
        } else if indexPath.row == 2 {
            cell.textLabel?.text = "Inspect DB"
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            self.onLogoutSelected?()
        } else if indexPath.row == 1 {
            self.onSwitchUserSelected?()
        } else if indexPath.row == 2 {
            self.onDBInspectorSelected?()
        }
    }

}
