/*
 ActionsTableViewController.swift
 RestAPIExplorerSwift
 
 Created by Nicholas McDonald on 1/9/18.
 
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

protocol ActionTableViewDelegate: class {
    func userDidSelectAction(_ action:Action)
}

class ActionTableViewController: UIViewController {
    weak var delegate:ActionTableViewDelegate?
    let actions:[Action]
    fileprivate var tableView = UITableView(frame: .zero, style: .plain)
    
    init() {
        let versions = Action(type: ActionType.versions, method: "versions", objectTypes:nil)
        let resources = Action(type: ActionType.resources, method: "resources", objectTypes:nil)
        let describeGlobal = Action(type: ActionType.describeGlobal, method: "describeGlobal", objectTypes:nil)
        let metadata = Action(type: ActionType.metadataWithObjectType, method: "metadataWithObjectType", objectTypes:"objectType")
        let describe = Action(type: ActionType.describeWithObjectType, method: "describeWithObjectType:", objectTypes:"objectType")
        let retrieve = Action(type: ActionType.retrieveWithObjectType, method: "retrieveWithObjectType:objectId:fieldList", objectTypes:"objectType, objectId, fieldList")
        let create = Action(type: ActionType.createWithObjectType, method: "createWithObjectType:fields", objectTypes:"objectType, fields")
        let upsert = Action(type: ActionType.upsertWithObjectType, method: "upsertWithObjectType:externalField:externalId:fields", objectTypes:"objectType, externalField, externalId, fields")
        let update = Action(type: ActionType.updateWithObjectType, method: "updateWithObjectType:externalField:externalId:fields", objectTypes:"objectType, objectId, fields")
        let delete = Action(type: ActionType.deleteWithObjectType, method: "deleteWithObjectType:objectId", objectTypes:"objectType, objectId")
        let query = Action(type: ActionType.query, method: "query:", objectTypes:"query")
        let search = Action(type: ActionType.search, method: "search:", objectTypes:"search")
        let searchScope = Action(type: ActionType.searchScopeAndOrder, method: "searchScopeAndOrder:", objectTypes:nil)
        let searchResultLayout = Action(type: ActionType.searchResultLayout, method: "searchResultLayout:", objectTypes:"objectList")
        let ownedFiles = Action(type: ActionType.ownedFilesList, method: "ownedFilesList:page", objectTypes:"userId, page")
        let filesInUserGroups = Action(type: ActionType.filesInUserGroups, method: "filesInUserGroups:page", objectTypes:"userId, page")
        let filesShared = Action(type: ActionType.filesSharedWithUser, method: "filesSharedWithUser:page", objectTypes:"userId, page")
        let fileDetails = Action(type: ActionType.fileDetails, method: "fileDetails:forVersions", objectTypes:"objectId, version")
        let batchFileDetails = Action(type: ActionType.batchFileDetails, method: "batchFileDetails:", objectTypes:"objectIdList")
        let fileShares = Action(type: ActionType.fileShares, method: "fileShares:page", objectTypes:"objectId, page")
        let addFileShare = Action(type: ActionType.addFileShare, method: "addFileShare:entityId:shareType", objectTypes:"objectId, entityId, sharedType")
        let deleteFileShare = Action(type: ActionType.deleteFileShare, method: "deleteFileShares:", objectTypes:"objectId")
        let currentUserInfo = Action(type: ActionType.currentUserInfo, method: "current user info", objectTypes:nil)
        let logout = Action(type: ActionType.logout, method: "logout", objectTypes:nil)
        let switchUser = Action(type: ActionType.switchUser, method: "switch user", objectTypes:nil)
        let exportCredentials = Action(type: ActionType.exportCredentials, method: "Export Credentials to pasteboard", objectTypes:nil)
        
        
        self.actions = [versions, resources, describeGlobal, metadata, describe, retrieve, create, upsert, update, delete, query, search, searchScope, searchResultLayout, ownedFiles, filesInUserGroups, filesShared, fileDetails, batchFileDetails, fileShares, addFileShare, deleteFileShare, currentUserInfo, logout, switchUser, exportCredentials]
        
        super.init(nibName: nil, bundle: nil)
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.tableView.register(ActionTableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableView.separatorInset = UIEdgeInsets.zero
        self.view.addSubview(self.tableView)
        
        self.tableView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        self.tableView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        self.tableView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        self.tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
    }
}

extension ActionTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let d = self.delegate {
            let action = self.actions[indexPath.row]
            d.userDidSelectAction(action)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

extension ActionTableViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let action = self.actions[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ActionTableViewCell
        cell.actionLabel.text = action.method
        if let types = action.objectTypes {
            cell.objectLabel.text = "params: " + types
        } else {
            cell.objectLabel.text = "no params"
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.actions.count
    }
}
