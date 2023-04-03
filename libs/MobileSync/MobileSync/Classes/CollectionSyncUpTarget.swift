//
//  CollectionSyncUpTarget.swift
//  MobileSync
//
//  Created by Wolfgang Mathurin on 5/26/22.
//  Copyright (c) 2022-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import SalesforceSDKCore

public typealias SyncUpRecordsNewerThanServerBlock = ([AnyHashable: Any]) -> ()
typealias FetchLastModDatesBlock = ([NSNumber: RecordModDate?]) -> ()

//
// Subclass of SyncUpTarget that batches create/update/delete operations by using sobject collection apis
//
@objc(SFCollectionSyncUpTarget)
public class CollectionSyncUpTarget: BatchSyncUpTarget {
    
    static let maxRecordsCollectionAPI:UInt = 200
    
    override public class func build(dict: [AnyHashable: Any]?) -> Self {
        return self.init(dict: dict ?? Dictionary())
    }
        
    override public convenience init() {
        self.init(createFieldlist:nil, updateFieldlist:nil, maxBatchSize:nil)
    }

    override public convenience init(createFieldlist: [String]?, updateFieldlist: [String]?) {
        self.init(createFieldlist:createFieldlist, updateFieldlist:updateFieldlist, maxBatchSize:nil)
    }
    
    // Construct CollectionSyncUpTarget with a different maxBatchSize and id/modifiedDate/externalId fields
    override public init(createFieldlist: [String]?, updateFieldlist: [String]?, maxBatchSize:NSNumber?) {
        super.init(createFieldlist:createFieldlist, updateFieldlist:updateFieldlist, maxBatchSize: maxBatchSize)
    }
 
    // Construct SyncUpTarget from json
    override required public init(dict: [AnyHashable: Any]) {
        super.init(dict: dict);
    }

    override func maxAPIBatchSize() -> UInt {
        return CollectionSyncUpTarget.maxRecordsCollectionAPI
    }
    
    override func sendRecordRequests(_ syncManager:SyncManager, recordRequests:[RecordRequest],
                            onComplete: @escaping OnSendCompleteCallback, onFail: @escaping OnFailCallback) {
        
        CompositeRequestHelper.sendAsCollectionRequests(syncManager, allOrNone: false, recordRequests: recordRequests, onComplete: onComplete, onFail: onFail)
    }
    
    public override func areNewerThanServer(_ syncManager:SyncManager,
                                            records:[[AnyHashable: Any]],
                                            resultBlock:@escaping SyncUpRecordsNewerThanServerBlock) {
        
        var storeIdToNewerThanServer = [NSNumber: Bool]()
        var nonLocallyCreatedRecords = [[AnyHashable: Any]]()
        for record in records {
            if (isLocallyCreated(record) || record[idFieldName] == nil) {
                storeIdToNewerThanServer[record[SmartStore.soupEntryId] as! NSNumber] = true
            } else {
                nonLocallyCreatedRecords.append(record)
            }
        }
        
        fetchLastModifiedDates(syncManager, records: nonLocallyCreatedRecords) { [weak self] recordIdToLastModifiedDate in
            guard let self = self else { return }
            for record in nonLocallyCreatedRecords {
                let storeId = record[SmartStore.soupEntryId] as! NSNumber
                let localModDate = RecordModDate(
                    timestamp: record[self.modificationDateFieldName] as? String,
                    isDeleted: self.isLocallyDeleted(record))
                let remoteModDate = recordIdToLastModifiedDate[storeId] as? RecordModDate
                storeIdToNewerThanServer[storeId] = self.isNewerThanServer(localModDate, remoteModDate: remoteModDate)
            }

            resultBlock(storeIdToNewerThanServer)
        }
    }
    
    func getRecordType(_ record:[AnyHashable: Any]) -> String? {
        return SFJsonUtils.project(intoJson: record, path: MobileSync.kObjectTypeField) as? String
    }
    
    func fetchLastModifiedDates(_ syncManager:SyncManager,
                                records:[[AnyHashable: Any]],
                                completeBlock: @escaping FetchLastModDatesBlock) {

        var recordIdToLastModifiedDate = [NSNumber: RecordModDate?]()

        let totalSize = records.count
        
        if (totalSize == 0) {
            completeBlock(recordIdToLastModifiedDate)
            return
        }
            
        var batchStoreIds = [NSNumber]()
        var batchServerIds = [String]()
        
        guard let objectType = getRecordType(records[0]) else {
            MobileSyncLogger.default.e(CollectionSyncUpTarget.self, message:"Record does not have an sobject type")
            completeBlock(recordIdToLastModifiedDate)
            return
        }

        let group = DispatchGroup()
        
        for i in 0...totalSize-1 {
            let record = records[i]
            if (getRecordType(record) != objectType) {
                MobileSyncLogger.default.e(CollectionSyncUpTarget.self, message:"All records should have same sobject type")
                completeBlock(recordIdToLastModifiedDate)
                return
            }

            batchStoreIds.append(record[SmartStore.soupEntryId] as! NSNumber)
            batchServerIds.append(record[idFieldName] as! String)

            // Process batch if max batch size reached or at the end of records
            if (batchServerIds.count == SalesforceSDKCore.SFRestCollectionRetrieveMaxSize
                || i == totalSize - 1) {
                
                let request = RestClient.shared.request(forCollectionRetrieve: objectType, objectIds: batchServerIds, fieldList: [modificationDateFieldName], apiVersion: nil)
                
                group.enter()
                NetworkUtils.sendRequest(withMobileSyncUserAgent: request) { response, error, urlResponse in                    
                    group.leave()
                } successBlock: { response, urlResponse in
                    if let recordsFromResponse = response as? [Any] {
                        for j in 0...recordsFromResponse.count-1 {
                            let storeId = batchStoreIds[j]
                            if let recordFromResponse = recordsFromResponse[j] as? [AnyHashable: Any] {
                                recordIdToLastModifiedDate[storeId] = RecordModDate(
                                    timestamp: recordFromResponse[self.modificationDateFieldName] as? String,
                                    isDeleted: false)
                                
                            } else {
                                recordIdToLastModifiedDate[storeId] = RecordModDate(timestamp: nil, isDeleted: true)
                            }
                        }
                    }
                    group.leave()
                }
            }
        }
                
        group.notify(queue: DispatchQueue.global()) {
            completeBlock(recordIdToLastModifiedDate)
        }
    }
}
