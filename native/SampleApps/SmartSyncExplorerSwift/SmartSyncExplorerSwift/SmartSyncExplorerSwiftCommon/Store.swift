//
//  Store.swift
//  Test
//
//  Created by David Vieser on 9/27/17.
//  Copyright © 2017 Salesforce. All rights reserved.
//

import Foundation
import SalesforceSDKCore
import SalesforceSwiftSDK
import SmartStore
import SmartSync

typealias SyncCompletion = ((SFSyncState?) -> Void)?

class Store<objectType: StoreProtocol> {

    private final let pageSize: UInt = 100
    
    init() {
        // use the following to clear db during debug
        self.store.removeAllSoups()
        self.store.clearSoup(objectType.objectName)
        self.store.removeSoup(objectType.objectName)
    }

    let sqlQueryString: String = SFRestAPI.soqlQuery(withFields: objectType.createFields, sObject: objectType.objectName, whereClause: nil, groupBy: nil, having: nil, orderBy: [objectType.orderPath], limit: 100)!
    
    let queryString: String = "SELECT \(objectType.selectFieldsString()) FROM {\(objectType.objectName)} WHERE {\(objectType.objectName):\(Record.Field.locallyDeleted.rawValue)} != 1 ORDER BY {\(objectType.objectName):\(objectType.orderPath)} ASC"
    
    
    lazy final var smartSync: SFSmartSyncSyncManager = SFSmartSyncSyncManager.sharedInstance(for: store)!
    
    final var store: SFSmartStore {
        
        let store = SFSmartStore.sharedStore(withName: kDefaultSmartStoreName) as! SFSmartStore
        SFSyncState.setupSyncsSoupIfNeeded(store)
        if (!store.soupExists(objectType.objectName)) {
            let indexSpecs: [AnyObject] = SFSoupIndex.asArraySoupIndexes(objectType.indexes) as [AnyObject]
            do {
                try store.registerSoup(objectType.objectName, withIndexSpecs: indexSpecs, error: ())
            } catch let error as NSError {
                SalesforceSwiftLogger.log(type(of:self), level:.error, message: "\(objectType.objectName) failed to register soup: \(error.localizedDescription)")
            }
        }
        return store
    }
    
    var count: UInt {
        guard let query: SFQuerySpec = SFQuerySpec.newSmartQuerySpec(queryString, withPageSize: 1) else {
            return 0
        }
        var error: NSError? = nil
        let results: UInt = store.count(with: query, error: &error)
        if let error = error {
            SalesforceSwiftLogger.log(type(of:self), level:.debug, message:"fetch \(objectType.objectName) failed: \(error.localizedDescription)")
            return 0
        }
        return results
    }
    
    func createEntryLocally<T:StoreProtocol>(entry: T) {
        var record: T = entry
        record.local = true
        record.locallyCreated = true
        self.upsertEntries(record: record)
    }
    
    func updateEntryLocally<T:StoreProtocol>(entry: T) {
        var record: T = entry
        record.local = true
        record.locallyUpdated = true
        self.upsertEntries(record: record)
    }
    
    func deleteEntryLocally<T:StoreProtocol>(entry: T) {
        var record: T = entry
        record.objectType = T.objectName
        record.locallyDeleted = true
        self.upsertEntries(record: record)
    }
    
    func undeleteEntryLocally<T:StoreProtocol>(entry: T) {
        var record: T = entry
        record.objectType = T.objectName
        record.locallyDeleted = false
        self.upsertEntries(record: record)
    }

    func upsertEntries(jsonResponse: Any, completion: SyncCompletion = nil) {
        let dataRows = (jsonResponse as! NSDictionary)["records"] as! [NSDictionary]
        SalesforceSwiftLogger.log(type(of:self), level:.debug, message:"request:didLoadResponse: #records: \(dataRows.count)")
        self.store.upsertEntries(dataRows, toSoup: objectType.objectName)
        completion?(nil)
    }
    
    func upsertEntries<T:StoreProtocol>(record: T, completion: SyncCompletion = nil) {
        self.store.upsertEntries([record.data], toSoup: T.objectName)
        completion?(nil)
    }
    
    func deleteEntryAndSync<T:StoreProtocol>(entry: T, completion: SyncCompletion = nil) {
        var record: T = entry
        record.locallyDeleted = true
        self.syncEntry(entry: record, completion: completion)
    }

    func createEntryAndSync<T:StoreProtocol>(entry: T, completion: SyncCompletion = nil) {
        var record: T = entry
        record.locallyCreated = true
        self.syncEntry(entry: record, completion: completion)
    }

    func syncEntry<T:StoreProtocol>(entry: T, completion: SyncCompletion = nil) {
        var record: T = entry
        record.objectType = T.objectName
        self.store.upsertEntries([record.data], toSoup: T.objectName)
        self.syncUp() { syncState in
            self.syncDown(completion: completion)
        }
    }

    func syncDown<T:StoreProtocol>(child: T, completion: SyncCompletion = nil ) {
        let parentInfo = SFParentInfo.new(withSObjectType: objectType.objectName, soupName: objectType.objectName)
        let childInfo = SFChildrenInfo.new(withSObjectType: type(of: child).objectName, soupName: type(of: child).objectName)
        let target: SFParentChildrenSyncDownTarget = SFParentChildrenSyncDownTarget.newSyncTarget(with: parentInfo, parentFieldlist: objectType.createFields, parentSoqlFilter: "", childrenInfo: childInfo, childrenFieldlist: type(of: child).createFields, relationshipType: .relationpshipMasterDetail)
        let options: SFSyncOptions = SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged)
        self.smartSync.syncDown(with: target, options: options, soupName: objectType.objectName, update: completion ?? { _ in return })
    }
    
    func syncUp<T:StoreProtocol>(child: T,completion: SyncCompletion = nil) {
        let parentInfo = SFParentInfo.new(withSObjectType: objectType.objectName, soupName: objectType.objectName)
        let childInfo = SFChildrenInfo.new(withSObjectType: type(of: child).objectName, soupName: type(of: child).objectName)
        let options: SFSyncOptions = SFSyncOptions.newSyncOptions(forSyncUp: objectType.readFields, mergeMode: .leaveIfChanged)
        let target = SFParentChildrenSyncUpTarget.newSyncTarget(with: parentInfo, parentCreateFieldlist: [], parentUpdateFieldlist: objectType.updateFields, childrenInfo: childInfo, childrenCreateFieldlist: type(of: child).createFields, childrenUpdateFieldlist: type(of: child).updateFields, relationshipType: .relationpshipMasterDetail)
        self.smartSync.syncUp(with: target, options: options, soupName: objectType.objectName, update: completion ?? { _ in return })
    }
    
    func syncDown(completion: SyncCompletion = nil) {
        let target: SFSoqlSyncDownTarget = SFSoqlSyncDownTarget.newSyncTarget(sqlQueryString)
        let options: SFSyncOptions = SFSyncOptions.newSyncOptions(forSyncDown: .overwrite)
        smartSync.syncDown(with: target, options: options, soupName: objectType.objectName, update: completion ?? { _ in return })
    }
    
    func syncUp(completion: SyncCompletion = nil) {
        let updateBlock: SFSyncSyncManagerUpdateBlock = { [unowned self] (syncState: SFSyncState?) in
            if let syncState = syncState {
                if syncState.isDone() || syncState.hasFailed() {
                    DispatchQueue.main.async {
                        if syncState.hasFailed() {
                            SalesforceSwiftLogger.log(type(of:self), level:.error, message:"syncUp \(objectType.objectName) failed")
                        }
                        else {
                            SalesforceSwiftLogger.log(type(of:self), level:.debug, message:"syncUp \(objectType.objectName) done")
                        }
                    }
                    completion?(syncState)
                }
            }
        }
        
        DispatchQueue.main.async(execute: {
            let options: SFSyncOptions = SFSyncOptions.newSyncOptions(forSyncUp: objectType.readFields, mergeMode: .leaveIfChanged)
            let target = SFSyncUpTarget.init(createFieldlist: objectType.createFields, updateFieldlist: objectType.updateFields)
            self.smartSync.syncUp(with: target, options: options, soupName: objectType.objectName, update: updateBlock)
        })
    }
 
    func getRecord(index: Int) -> objectType {
        let query:SFQuerySpec = SFQuerySpec.newSmartQuerySpec(queryString, withPageSize: 1)!
        var error: NSError? = nil
        let results: [Any] = store.query(with: query, pageIndex: UInt(index), error: &error)
        guard error == nil else {
            SalesforceSwiftLogger.log(type(of:self), level:.error, message:"fetch \(objectType.objectName) failed: \(error!.localizedDescription)")
            return objectType()
        }
        return objectType.from(results)
    }
    
    func getRecords() -> [objectType] {
        let query:SFQuerySpec = SFQuerySpec.newSmartQuerySpec(queryString, withPageSize: pageSize)!
        var error: NSError? = nil
        let results: [Any] = store.query(with: query, pageIndex: 0, error: &error)
        guard error == nil else {
            SalesforceSwiftLogger.log(type(of:self), level:.error, message:"fetch \(objectType.objectName) failed: \(error!.localizedDescription)")
            return []
        }
        return objectType.from(results)
    }
}
