//
//  BriefcaseSyncDownTarget.swift
//  MobileSync
//
//  Created by Brianna Birman on 4/6/22.
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
import Combine

struct TypedId: Hashable {
    let id: String
    let objectInfo: BriefcaseObjectInfo
}

struct TypedIds {
    var ids: [TypedId]
    var objectTypeToIds: [BriefcaseObjectInfo: [String]] {
        return Dictionary(grouping: ids) { $0.objectInfo }
            .mapValues { $0.map { $0.id } }
        
    }
    func sliceCount(sliceSize: Int) -> Int {
        return Int((Double(ids.count) / Double(sliceSize)).rounded(.up))
    }
    
    func slice(sliceIndex: Int, sliceSize: Int) -> TypedIds {
        let minimumIndex = sliceIndex*sliceSize
        let maxIndex = min(minimumIndex + sliceSize, ids.count)
        return TypedIds(Array(ids[minimumIndex..<maxIndex]))
    }

    init(_ ids: [TypedId]) {
        self.ids = ids
    }
}

enum BriefcaseSyncDownError: Error {
    case unknownResponse
}

@objc(SFBriefcaseSyncDownTarget)
public class BriefcaseSyncDownTarget: SyncDownTarget {
    private static let pageSize: UInt = 2000
    private static let countIdsPerRetrieve = "countIdsPerRetrieve"
    private static let infos = "infos"
    private static let maxCountIdsPerRetrieve = 2000
    
    private var relayToken: String? = nil
    private var maxTimeStamp: Int64 = 0
    private var infosMap: [String: BriefcaseObjectInfo] = [:]
    private var fetchedTypedIds: TypedIds?
    private let countIdsPerRetrieve: Int
    private var sliceIndex = 0
    private var cancellableSet: Set<AnyCancellable> = []

    override required public init(dict: [AnyHashable : Any]) {
        if let infos = dict[BriefcaseSyncDownTarget.infos]  {
            do {
                let json = try JSONSerialization.data(withJSONObject: infos)
                infosMap = try JSONDecoder().decode([String: BriefcaseObjectInfo].self, from: json)
            } catch {
                SalesforceLogger.log(BriefcaseSyncDownTarget.self, level: .error, message: "Error decoding briefcase info: \(error)")
            }
        }
        
        countIdsPerRetrieve = dict[BriefcaseSyncDownTarget.countIdsPerRetrieve] as? Int ?? BriefcaseSyncDownTarget.maxCountIdsPerRetrieve
        super.init(dict: dict)
        
        self.queryType = QueryType.briefcase
        ParentChildrenSyncHelper.registerAppFeature()
    }
    
    @objc public convenience init(infos: [BriefcaseObjectInfo]) {
        self.init(infos: infos, countIdsPerRetrieve: BriefcaseSyncDownTarget.maxCountIdsPerRetrieve)
    }
    
    internal init(infos: [BriefcaseObjectInfo], countIdsPerRetrieve: Int) {
        for info in infos {
            infosMap[info.sobjectType] = info
        }
        self.countIdsPerRetrieve = countIdsPerRetrieve
        ParentChildrenSyncHelper.registerAppFeature()
        super.init()
        self.queryType = QueryType.briefcase
    }
    
    override public class func new(fromDict dict: [AnyHashable : Any]) -> Self? {
        return self.init(dict: dict)
    }
    
    override public func asDict() -> NSMutableDictionary {
        let dict = super.asDict()
        do {
            let data = try JSONEncoder().encode(infosMap)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            dict[BriefcaseSyncDownTarget.infos] = json
        } catch {
            SalesforceLogger.log(BriefcaseSyncDownTarget.self, level: .error, message: "Error encoding briefcase info: \(error)")
        }
        dict[BriefcaseSyncDownTarget.countIdsPerRetrieve] = countIdsPerRetrieve
        return dict
    }

    override public func startFetch(syncManager: SyncManager, maxTimeStamp: Int64, onFail errorBlock: @escaping SyncDownErrorBlock, onComplete completeBlock: @escaping SyncDownCompletionBlock) {
        self.maxTimeStamp = maxTimeStamp
        relayToken = nil
        totalSize = 0
        getIdsFromBriefcasesAndFetchFromServer(syncManager: syncManager, relayToken: relayToken, onFail: errorBlock, onComplete: completeBlock)
    }
    
    override public func continueFetch(syncManager: SyncManager, onFail errorBlock: @escaping SyncDownErrorBlock, onComplete completeBlock: SyncDownCompletionBlock? = nil) {
        if fetchedTypedIds != nil {
            fetchRecordsFromServer(errorBlock: errorBlock, completeBlock: completeBlock)
        } else if let relayToken = relayToken {
            getIdsFromBriefcasesAndFetchFromServer(syncManager: syncManager, relayToken: relayToken, onFail: errorBlock, onComplete: completeBlock)
        } else {
            completeBlock?(nil)
        }
    }
    
    override public func getIdsToSkip(_ syncManager: SyncManager, soupName: String) -> NSOrderedSet {
        let ids = infosMap.values.flatMap { info in
            return super.getIdsToSkip(syncManager, soupName: info.soupName)
        }
        return NSOrderedSet(array: ids)
    }
    
    private func getIdsFromBriefcasesAndFetchFromServer(syncManager: SyncManager, relayToken: String?, onFail errorBlock: @escaping SyncDownErrorBlock, onComplete completeBlock: SyncDownCompletionBlock?) {
        idsFromBriefcases(syncManager: syncManager, maxTimeStamp: maxTimeStamp as NSNumber, relayToken: relayToken)
            .sink { result in
                if case .failure(let error) = result {
                   errorBlock(error)
                }
            } receiveValue: { [weak self] (typedIds, relayToken) in
                guard let self = self else { return }
                self.fetchedTypedIds = typedIds
                self.totalSize = UInt(typedIds.ids.count) // TODO: This only works with one page of results but stats are always returning 1000
                self.fetchRecordsFromServer(errorBlock: errorBlock, completeBlock: completeBlock)
            }
            .store(in: &cancellableSet)
    }
    
    private func requestForRecordIds(_ ids: [String], objectInfo: BriefcaseObjectInfo) -> RestRequest {
        var fieldList = Set(objectInfo.fieldlist)
        fieldList.insert(objectInfo.idFieldName)
        fieldList.insert(objectInfo.modificationDateFieldName)
        
        return RestClient.shared.request(forCollectionRetrieve: objectInfo.sobjectType, objectIds: ids, fieldList: Array(fieldList), apiVersion: nil)
    }

    private func fetchRecordsFromServer(errorBlock: @escaping SyncDownErrorBlock, completeBlock: SyncDownCompletionBlock?) {
        guard let typedIdBatch = fetchedTypedIds?.slice(sliceIndex: sliceIndex, sliceSize: countIdsPerRetrieve) else {
            SalesforceLogger.log(BriefcaseSyncDownTarget.self, level: .error, message: "Fetch records called but there are no record IDs to fetch")
            completeBlock?(nil)
            return
        }
        
        let group = DispatchGroup()
        var allRecords: [Any] = []
        typedIdBatch.objectTypeToIds.forEach { (objectType, recordIds) in
            let request = requestForRecordIds(recordIds, objectInfo: objectType)
            group.enter()
            NetworkUtils.sendRequest(withMobileSyncUserAgent: request) { response, error, urlResponse in
                errorBlock(error)
            } successBlock: { response, urlResponse in
                if let records = response as? [[String: Any]] {
                    allRecords.append(contentsOf: records)
                    group.leave()
                } else {
                    errorBlock(nil)
                }
            }
        }
        
        group.notify(queue: DispatchQueue.global()) { [weak self] in
            guard let self = self else { return }
            self.sliceIndex += 1
            if let fetchedTypedIds = self.fetchedTypedIds, self.sliceIndex >= fetchedTypedIds.sliceCount(sliceSize: self.countIdsPerRetrieve) {
                self.fetchedTypedIds = nil
                self.sliceIndex = 0
            }
            completeBlock?(allRecords)
        }
    }

    func allIdsFromBriefcases(syncManager: SyncManager, completion: @escaping (Result<(TypedIds), Error>) -> Void) {
        let briefcasePagePublisher = CurrentValueSubject<(NSNumber?, String?), Error>((NSNumber(value: maxTimeStamp), nil))
        briefcasePagePublisher
            .flatMap {
                return self.idsFromBriefcases(syncManager: syncManager, maxTimeStamp: nil, relayToken: $0.1)
                    .handleEvents(receiveOutput: { (ids: TypedIds?, relayToken: String?) in
                        if let relayToken = relayToken {
                            briefcasePagePublisher.send((nil, relayToken))
                        } else {
                            briefcasePagePublisher.send(completion: .finished)
                        }
                    })
            }.reduce(TypedIds([]), { allTypedIds, response in
                return (TypedIds(response.0.ids + allTypedIds.ids))
            })
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    completion(.failure(error))
                }
            }, receiveValue: { typedIds in
                completion(.success(typedIds))
            })
            .store(in: &cancellableSet)
    }
    
    private func idsFromBriefcases(syncManager: SyncManager, maxTimeStamp: NSNumber?, relayToken: String?) -> AnyPublisher<(TypedIds, String?), Error> {
        let request = RestClient.shared.request(forPrimingRecords: relayToken, changedAfterTimestamp: maxTimeStamp, apiVersion: nil)
        // Setting the MobileSync user agent because this publisher isn't using SFMobileSyncNetworkUtils
        request.setHeaderValue(RestClient.userAgentString("MobileSync"), forHeaderName: "User-Agent")
        return RestClient.shared.publisher(for: request).tryMap { response -> (TypedIds, String?) in
            guard let response = try response.asJson() as? [AnyHashable: Any] else {
                throw BriefcaseSyncDownError.unknownResponse
            }
            let primingResponse = PrimingRecordsResponse(response)
            let typedIdArray = self.infosMap.values.flatMap { (objectInfo: BriefcaseObjectInfo) -> [TypedId] in
                guard let recordLists = primingResponse.primingRecords[objectInfo.sobjectType]?.values else { return [] }
                return recordLists.flatMap { records in
                    return records.map { TypedId(id: $0.objectId, objectInfo: objectInfo) }
                }
            }

            let typedIds = TypedIds(typedIdArray)
            return (typedIds, primingResponse.relayToken)
        }
        .eraseToAnyPublisher()
     }

    override public func cleanGhosts(syncManager: SyncManager, soupName: String, syncId: NSNumber, onFail errorBlock: @escaping SyncDownErrorBlock, onComplete completeBlock: @escaping SyncDownCompletionBlock) {
        
        allIdsFromBriefcases(syncManager: syncManager) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let typedIds):
                do {
                    let ghosts = try self.cleanGhosts(typedIds: typedIds, syncManager: syncManager, syncId: syncId)
                    completeBlock(ghosts)
                } catch {
                    errorBlock(error)
                }
            case .failure(let error):
                errorBlock(error)
            }
        }
    }
    
    private func cleanGhosts(typedIds: TypedIds, syncManager: SyncManager, syncId: NSNumber) throws -> [Any]  {
        // Cleaning up ghosts one object type at a time
        return try typedIds.objectTypeToIds.flatMap { (objectInfo, records) -> [String] in
            let predicate = self.buildSyncIdPredicateIfIndexed(syncManager: syncManager, soupName: objectInfo.soupName, syncId: syncId)
            let localIds = try self.nonDirtyRecordsIds(syncManager: syncManager, soupName: objectInfo.soupName, idField: objectInfo.idFieldName, additionalPredicate: predicate).mutableCopy() as? NSMutableOrderedSet
            localIds?.removeObjects(in: records)
            if let ghosts = localIds?.array as? [String], !ghosts.isEmpty {
                try self.deleteRecordsFromLocalStore(syncManager: syncManager, soupName: objectInfo.soupName, ids: ghosts, idField: objectInfo.idFieldName)
                return ghosts
            }
            return []
        }
    }

    // Overriding because records could be in different soups
    override public func cleanAndSaveRecordsToLocalStore(syncManager: SyncManager, soupName: String, records: [Any], syncId: NSNumber) {
        guard let records = records as? [[String: Any]] else { return }
        
        let soupRecords = Dictionary(grouping: records) { record -> String? in
            return briefcaseInfo(for: record)?.soupName
        }
        
        soupRecords.forEach { (soupName: String?, soupRecords: [[String : Any]]) in
            guard let soupName = soupName else { return }
            super.cleanAndSaveRecordsToLocalStore(syncManager: syncManager, soupName: soupName, records: soupRecords, syncId: syncId)
        }
    }
    
    func briefcaseInfo(for record: [String: Any]) -> BriefcaseObjectInfo? {
        if let attributes = record["attributes"] as? [String: Any],
           let objectType = attributes["type"] as? String {
            return infosMap[objectType]
        }
        return nil
    }
    
    // MARK: - Adapted from internal methods in SyncDownTarget.m
    
    func buildSyncIdPredicateIfIndexed(syncManager: SyncManager, soupName: String, syncId: NSNumber) -> String {
        let indexSpecs = syncManager.store.indices(forSoupNamed: soupName)
        for indexSpec in indexSpecs {
            if indexSpec.path == kSyncTargetSyncId {
                return "AND {\(soupName):\(kSyncTargetSyncId)} = \(syncId.stringValue)"
            }
        }
        return ""
    }
    
    func deleteRecordsFromLocalStore(syncManager: SyncManager, soupName: String, ids: [String], idField: String) throws {
        if !ids.isEmpty {
            let smartSql = "SELECT {\(soupName):\(SmartStore.soupEntryId)} FROM {\(soupName)} WHERE {\(soupName):\(idField)} IN ('\(ids.joined(separator: "','"))')"
            if let spec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(ids.count)) {
                try syncManager.store.removeEntries(usingQuerySpec: spec, forSoupNamed: soupName)
            }
        }
    }
    
    func nonDirtyRecordsIds(syncManager: SyncManager, soupName: String, idField: String, additionalPredicate: String) throws -> NSOrderedSet {
        let sql = "SELECT {\(soupName):\(idField)} FROM {\(soupName)} WHERE {\(soupName):\(kSyncTargetLocal)} = '0' \(additionalPredicate) ORDER BY {\(soupName):\(idField)} ASC"
        
       return try idsWithQuery(sql, syncManager: syncManager)
    }
    
    func idsWithQuery(_ query: String, syncManager: SyncManager) throws -> NSOrderedSet {
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: query, pageSize: BriefcaseSyncDownTarget.pageSize) else { return NSOrderedSet() }

        let ids = NSMutableOrderedSet()
        var pageIndex: UInt = 0
        var hasMore = true
        while let results = try syncManager.store.query(using: querySpec, startingFromPageIndex: pageIndex) as? [[Any]], hasMore {
            hasMore = (results.count == BriefcaseSyncDownTarget.pageSize)
            pageIndex += 1
            ids.addObjects(from: results.flatMap { $0 })
        }
        return ids
    }
}
