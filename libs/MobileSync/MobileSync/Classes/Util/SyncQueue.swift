//
//  SyncQueue.swift
//  MobileSync
//
//  Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
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
import SmartStore

/// The sync-up queue: a soup (`mobilesync_queue`, one per store) holding the ordered list of local changes
/// written through the local write API of `SyncManager` (`createLocal`, `updateLocal`, `deleteLocal`).
///
/// The queue soup is registered when the sync manager of a store is created. Apps that never call the
/// write API only get an empty soup.
@objc(SFSDKSyncQueue)
public final class SyncQueue: NSObject {

    /// Name of the queue soup.
    @objc public static let soupName = "mobilesync_queue"

    // MARK: Entry fields

    static let sequenceField = "sequence"
    static let soupNameField = "soupName"
    static let recordIdField = "recordId"
    static let sobjectTypeField = "sobjectType"
    static let kindField = "kind"
    static let changesField = "changes"
    /// Reserved for conflict detection, never written yet.
    static let baseField = "base"
    static let statusField = "status"
    static let lastErrorField = "lastError"
    static let attemptsField = "attempts"
    /// Reserved for parent / child records, never written yet.
    static let parentRefField = "parentRef"

    /// Kind of change recorded by an entry.
    enum Kind: String {
        case create = "CREATE"
        case update = "UPDATE"
        case delete = "DELETE"
    }

    /// Status of an entry.
    enum Status: String {
        case pending = "PENDING"
        case parked = "PARKED"
    }

    /// Index specs of the queue soup.
    static var indexSpecs: [SoupIndex] {
        let specs: [(String, String)] = [
            (sequenceField, kSoupIndexTypeInteger),
            (soupNameField, kSoupIndexTypeString),
            (recordIdField, kSoupIndexTypeString),
            (sobjectTypeField, kSoupIndexTypeString),
            (kindField, kSoupIndexTypeString),
            (changesField, kSoupIndexTypeJSON1),
            (baseField, kSoupIndexTypeJSON1),
            (statusField, kSoupIndexTypeString),
            (lastErrorField, kSoupIndexTypeJSON1),
            (attemptsField, kSoupIndexTypeInteger),
            (parentRefField, kSoupIndexTypeString)
        ]
        return specs.compactMap { SoupIndex(path: $0.0, indexType: $0.1, columnName: nil) }
    }

    // MARK: Registration

    /// Registers the queue soup in the given store if it is missing. If it exists with a different number of
    /// index specs, it is altered (with re-indexing) to match the expected specs.
    /// - Parameter store: the store that holds the queue soup.
    @objc(setupQueueSoupIfNeeded:)
    public static func setupQueueSoupIfNeeded(_ store: SmartStore) {
        let specs = indexSpecs
        let exists = store.soupExists(forName: soupName)
        if exists && store.indices(forSoupNamed: soupName).count == specs.count {
            return
        }
        if exists {
            store.alterSoup(named: soupName, indexSpecs: specs, reIndexData: true)
        } else {
            try? store.registerSoup(withName: soupName, withIndices: specs)
        }
    }

    // MARK: Sequence and entries

    /// Allocates the next sequence number: the maximum existing one plus one, or 1 when the queue is empty.
    /// Must be called inside the transaction that inserts the entry (it sees the transaction's own writes).
    static func nextSequence(in transaction: SmartStore.Transaction) throws -> Int {
        let smartSql = "SELECT MAX({\(soupName):\(sequenceField)}) FROM {\(soupName)}"
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 1) else {
            throw LocalWriteError.storeFailure.error("Could not build the sequence query")
        }
        let rows = try transaction.query(using: querySpec, startingFromPageIndex: 0, whereArgs: nil)
        // MAX of no rows still returns one row holding NULL
        let max = ((rows.first as? [Any])?.first as? NSNumber)?.intValue ?? 0
        return max + 1
    }

    /// Builds a pending queue entry.
    static func buildEntry(sequence: Int, soupName: String, recordId: String, sobjectType: String?, kind: Kind, changes: [String: Any]?) -> [String: Any] {
        var entry: [String: Any] = [
            sequenceField: sequence,
            soupNameField: soupName,
            recordIdField: recordId,
            kindField: kind.rawValue,
            statusField: Status.pending.rawValue,
            attemptsField: 0
        ]
        if let sobjectType = sobjectType {
            entry[sobjectTypeField] = sobjectType
        }
        if let changes = changes {
            entry[changesField] = changes
        }
        return entry
    }
}
