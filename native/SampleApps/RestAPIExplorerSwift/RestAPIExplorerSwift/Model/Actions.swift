//
//  Actions.swift
//  RestAPIExplorerSwift
//
//  Created by Nicholas McDonald on 1/10/18.
//  Copyright © 2018 Salesforce. All rights reserved.
//

import Foundation

enum ActionType {
    case versions
    case resources
    case describeGlobal
    case metadataWithObjectType
    case describeWithObjectType
    case retrieveWithObjectType
    case createWithObjectType
    case upsertWithObjectType
    case updateWithObjectType
    case deleteWithObjectType
    case query
    case search
    case searchScopeAndOrder
    case searchResultLayout
    case ownedFilesList
    case filesInUserGroups
    case filesSharedWithUser
    case fileDetails
    case batchFileDetails
    case fileShares
    case addFileShare
    case deleteFileShare
    case currentUserInfo
    case logout
    case switchUser
    case exportCredentials
}

struct Action {
    let type:ActionType
    let method:String
    let objectTypes:String?
}
