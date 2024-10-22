//
//  SyncTarget.swift
//  MobileSync
//
//  Created by Brianna Birman on 5/23/22.
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

extension SyncTarget {
    // Internal value from SyncTarget.m
    static let pageSize = 2000
}

extension SyncDownTarget {
    // Adapted from internal methods in SyncDownTarget.m

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
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: query, pageSize: UInt(SyncTarget.pageSize))  else { return NSOrderedSet() }

        let ids = NSMutableOrderedSet()
        var pageIndex: UInt = 0
        var hasMore = true
        while let results = try syncManager.store.query(using: querySpec, startingFromPageIndex: pageIndex) as? [[Any]], hasMore {
            hasMore = (results.count == UInt(SyncTarget.pageSize))
            pageIndex += 1
            ids.addObjects(from: results.flatMap { $0 })
        }
        return ids
    }
}
