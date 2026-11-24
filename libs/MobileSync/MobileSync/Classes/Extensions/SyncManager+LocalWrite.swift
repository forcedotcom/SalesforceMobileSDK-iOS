//
//  SyncManager+LocalWrite.swift
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

/// Codes of the errors raised by the local write API, in the `kSFMobileSyncErrorDomain` domain
/// (900 to 904 are used by the sync manager).
enum LocalWriteError: Int {
    case soupNotFound = 905
    case idIndexMissing = 906
    case invalidRecord = 907
    case invalidId = 908
    case recordAlreadyExists = 909
    case recordNotFound = 910
    case multipleRecordsFound = 911
    case recordAlreadyDeleted = 912
    case invalidChanges = 913
    case storeFailure = 914

    func error(_ message: String) -> NSError {
        return NSError(domain: kSFMobileSyncErrorDomain, code: rawValue, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private let idField = "Id"
private let attributesField = "attributes"
private let typeField = "type"
private let displayField = "__display__"
private let soupFieldPrefix = "_soup"

/// Fields owned by the SDK: never part of the `changes` of a queue entry, and rejected in the `changes` of `updateLocal`.
private let internalFields: Set<String> = [
    idField, attributesField, displayField,
    kSyncTargetLocal, kSyncTargetLocallyCreated, kSyncTargetLocallyUpdated, kSyncTargetLocallyDeleted,
    kSyncTargetLastError, kSyncTargetSyncId
]

private func isInternalField(_ field: String) -> Bool {
    return internalFields.contains(field) || field.hasPrefix(soupFieldPrefix)
}

/// Same interpretation as `-[SFSyncTarget isLocallyDeleted:]` and the other flag checks (`boolValue` in Objective-C):
/// `true`, 1 and strings such as "1" or "true" are set; null, absent and other types are not.
private func isFlagSet(_ record: [String: Any], _ flag: String) -> Bool {
    switch record[flag] {
    case let number as NSNumber: return number.boolValue
    case let string as String: return (string as NSString).boolValue
    default: return false
    }
}

extension SyncManager {

    /// Creates a record locally: inserts it in the soup, flagged as locally created, and appends a `CREATE`
    /// entry to the sync-up queue (`mobilesync_queue`). Both writes happen in one SmartStore transaction:
    /// both succeed or neither does.
    ///
    /// The soup must exist and index `Id`. The record must carry its object type in `attributes.type`.
    /// Its `Id` is either absent (a new local id is generated) or a local id that is not used yet: not by a record of any soup
    /// with an `Id` index and not by a queue entry of another soup (local ids are unique in the whole store, because
    /// replaying a create rewrites the references to its local id store-wide).
    /// The entry's `changes` hold all the fields of the record except the internal ones (`Id`, `attributes`,
    /// `_soup*` keys, dirty flags, `__last_error__`, `__sync_id__`, `__display__`).
    ///
    /// A record soup must use either this queue or flag-based sync up, never both: these calls set the dirty
    /// flags that flag-based sync-up targets read; `QueueSyncUpTarget` replays the queue.
    ///
    /// This call is blocking: do not call it from the main thread for large volumes. The dictionary passed in
    /// is not modified.
    ///
    /// - Parameters:
    ///   - soupName: name of the soup that holds the record.
    ///   - record: the record to create.
    /// - Returns: the saved record (with its `Id`, flags and `_soupEntryId`).
    /// - Throws: an `NSError` in `kSFMobileSyncErrorDomain` (codes 905 and up) if the call is invalid, or the
    ///   SmartStore error that made the transaction fail. Nothing is written in that case.
    @objc(createLocalInSoup:record:error:)
    @discardableResult
    public func createLocal(soupName: String, record: [String: Any]) throws -> [String: Any] {
        // The soups that have an Id index: a caller-supplied local id must be unused in all of them.
        // Read here, the store cannot be called from the transaction block.
        var otherSoups: [String] = []
        if record[idField] is String {
            otherSoups = store.allSoupNames().filter { name in
                name != soupName && name != SyncQueue.soupName && store.indices(forSoupNamed: name).contains(where: { $0.path == idField })
            }
        }
        return try performLocalWrite(soupName: soupName) { transaction in
            guard let sobjectType = Self.sobjectType(of: record), !sobjectType.isEmpty else {
                throw LocalWriteError.invalidRecord.error("The record must have its object type in \(attributesField).\(typeField)")
            }
            if record.keys.contains(where: { $0.hasPrefix(soupFieldPrefix) }) {
                throw LocalWriteError.invalidRecord.error("The record must not contain \(soupFieldPrefix)* fields")
            }
            guard JSONSerialization.isValidJSONObject(record) else {
                throw LocalWriteError.invalidRecord.error("The record cannot be serialized to JSON")
            }

            // Id: absent (new local id) or a local id not in the soup yet
            var recordId: String
            let givenId = record[idField]
            if givenId == nil || givenId is NSNull {
                recordId = SyncTarget.createLocalId()
                while try Self.lookupEntryId(transaction, soupName, recordId) != nil {
                    recordId = SyncTarget.createLocalId()
                }
            } else {
                guard let id = givenId as? String, SyncTarget.isLocalId(id) else {
                    throw LocalWriteError.invalidId.error("\(idField) must be absent or a local id")
                }
                if try Self.lookupEntryId(transaction, soupName, id) != nil {
                    throw LocalWriteError.recordAlreadyExists.error("A record with \(idField) \(id) already exists in \(soupName)")
                }
                try Self.checkUnusedInOtherSoups(transaction, id, soupName: soupName, otherSoups: otherSoups)
                recordId = id
            }

            var toSave = record
            toSave[idField] = recordId
            toSave[kSyncTargetLocal] = true
            toSave[kSyncTargetLocallyCreated] = true
            toSave[kSyncTargetLocallyUpdated] = false
            toSave[kSyncTargetLocallyDeleted] = false
            toSave[kSyncTargetLastError] = nil

            let saved = try Self.save(transaction, soupName, toSave)
            let changes = record.filter { !isInternalField($0.key) }
            try Self.appendEntry(transaction, soupName: soupName, recordId: recordId, sobjectType: sobjectType, kind: .create, changes: changes)
            return saved
        }
    }

    /// Updates a record locally: merges `changes` into the stored record, flags it as locally updated
    /// (`__locally_created__` is preserved), and appends an `UPDATE` entry holding only the given fields to the
    /// sync-up queue (`mobilesync_queue`). Both writes happen in one SmartStore transaction.
    ///
    /// To clear a field, pass `NSNull()` as its value. `changes` must not be empty and must not contain internal
    /// fields (`Id`, `attributes`, `_soup*` keys, dirty flags, `__last_error__`, `__sync_id__`, `__display__`).
    /// The record can be a locally created record or one that came from sync down (its server id is accepted).
    ///
    /// A record soup must use either this queue or flag-based sync up, never both: these calls set the dirty
    /// flags that flag-based sync-up targets read; `QueueSyncUpTarget` replays the queue.
    ///
    /// This call is blocking: do not call it from the main thread for large volumes.
    ///
    /// - Parameters:
    ///   - soupName: name of the soup that holds the record.
    ///   - id: the `Id` of the record to update.
    ///   - changes: the fields to change and their new values.
    /// - Returns: the saved (merged) record.
    /// - Throws: an `NSError` in `kSFMobileSyncErrorDomain` (codes 905 and up) if the call is invalid (e.g. the
    ///   record does not exist or is already flagged deleted), or the SmartStore error that made the transaction
    ///   fail. Nothing is written in that case.
    @objc(updateLocalInSoup:id:changes:error:)
    @discardableResult
    public func updateLocal(soupName: String, id: String, changes: [String: Any]) throws -> [String: Any] {
        return try performLocalWrite(soupName: soupName) { transaction in
            guard !changes.isEmpty else {
                throw LocalWriteError.invalidChanges.error("changes must not be empty")
            }
            if let field = changes.keys.sorted().first(where: isInternalField) {
                throw LocalWriteError.invalidChanges.error("changes must not contain the internal field \(field)")
            }
            guard JSONSerialization.isValidJSONObject(changes) else {
                throw LocalWriteError.invalidChanges.error("changes cannot be serialized to JSON")
            }
            var record = try Self.existingRecord(transaction, soupName, id)
            if isFlagSet(record, kSyncTargetLocallyDeleted) {
                throw LocalWriteError.recordAlreadyDeleted.error("The record \(id) in \(soupName) is already deleted")
            }
            for (field, value) in changes {
                record[field] = value
            }
            record[kSyncTargetLocal] = true
            record[kSyncTargetLocallyUpdated] = true
            let saved = try Self.save(transaction, soupName, record)
            try Self.appendEntry(transaction, soupName: soupName, recordId: id, sobjectType: Self.sobjectType(of: record), kind: .update, changes: changes)
            return saved
        }
    }

    /// Deletes a record locally: keeps the record in its soup, flagged as locally deleted, and appends a
    /// `DELETE` entry to the sync-up queue (`mobilesync_queue`). Both writes happen in one SmartStore
    /// transaction.
    ///
    /// A record soup must use either this queue or flag-based sync up, never both: these calls set the dirty
    /// flags that flag-based sync-up targets read; `QueueSyncUpTarget` replays the queue.
    ///
    /// This call is blocking: do not call it from the main thread for large volumes.
    ///
    /// - Parameters:
    ///   - soupName: name of the soup that holds the record.
    ///   - id: the `Id` of the record to delete.
    /// - Returns: the saved (flagged) record.
    /// - Throws: an `NSError` in `kSFMobileSyncErrorDomain` (codes 905 and up) if the call is invalid (e.g. the
    ///   record does not exist or is already flagged deleted), or the SmartStore error that made the transaction
    ///   fail. Nothing is written in that case.
    @objc(deleteLocalInSoup:id:error:)
    @discardableResult
    public func deleteLocal(soupName: String, id: String) throws -> [String: Any] {
        return try performLocalWrite(soupName: soupName) { transaction in
            var record = try Self.existingRecord(transaction, soupName, id)
            if isFlagSet(record, kSyncTargetLocallyDeleted) {
                throw LocalWriteError.recordAlreadyDeleted.error("The record \(id) in \(soupName) is already deleted")
            }
            record[kSyncTargetLocal] = true
            record[kSyncTargetLocallyDeleted] = true
            let saved = try Self.save(transaction, soupName, record)
            try Self.appendEntry(transaction, soupName: soupName, recordId: id, sobjectType: Self.sobjectType(of: record), kind: .delete, changes: nil)
            return saved
        }
    }

    // MARK: - Helpers

    /// Checks the soups, then runs `work` in one SmartStore transaction. An error thrown by `work` rolls the
    /// transaction back and is thrown to the caller.
    private func performLocalWrite(soupName: String, work: (SmartStore.Transaction) throws -> [String: Any]) throws -> [String: Any] {
        guard store.soupExists(forName: soupName) else {
            throw LocalWriteError.soupNotFound.error("Soup \(soupName) does not exist")
        }
        guard store.indices(forSoupNamed: soupName).contains(where: { $0.path == idField }) else {
            throw LocalWriteError.idIndexMissing.error("Soup \(soupName) must have an index on \(idField)")
        }
        // The cached sync manager does not register the queue again if an app dropped all soups.
        // Cannot be done inside the transaction.
        SyncQueue.setupQueueSoupIfNeeded(store)

        var result: [String: Any]?
        try store.performTransaction { transaction in
            do {
                result = try work(transaction)
            } catch {
                transaction.fail(with: error as NSError)
            }
        }
        guard let saved = result else {
            throw LocalWriteError.storeFailure.error("The local write did not produce a record")
        }
        return saved
    }

    private static func lookupEntryId(_ transaction: SmartStore.Transaction, _ soupName: String, _ id: String) throws -> NSNumber? {
        do {
            return try transaction.lookupSoupEntryId(soupNamed: soupName, fieldPath: idField, fieldValue: id)
        } catch let error as NSError where error.domain == SmartStore.errorDomain && error.code == 1 {
            throw LocalWriteError.multipleRecordsFound.error("More than one record with \(idField) \(id) in \(soupName)")
        }
    }

    /// Local ids used as references between records (a `parentRef`, a lookup in `changes`) are replaced store-wide when the
    /// create is replayed, so a local id must be unique in the whole store, not only in its soup.
    private static func checkUnusedInOtherSoups(_ transaction: SmartStore.Transaction, _ id: String, soupName: String, otherSoups: [String]) throws {
        for other in otherSoups {
            if (try? transaction.lookupSoupEntryId(soupNamed: other, fieldPath: idField, fieldValue: id)) != nil {
                throw LocalWriteError.recordAlreadyExists.error("The local id \(id) is already used in \(other): local ids must be unique in the store")
            }
        }
        let queue = SyncQueue.soupName
        let smartSql = "SELECT COUNT(*) FROM {\(queue)} WHERE {\(queue):\(SyncQueue.recordIdField)} = ? AND {\(queue):\(SyncQueue.soupNameField)} != ?"
        if let spec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 1),
           let rows = try? transaction.query(using: spec, startingFromPageIndex: 0, whereArgs: [id, soupName]) as? [[Any]],
           let count = (rows.first?.first as? NSNumber)?.intValue, count > 0 {
            throw LocalWriteError.recordAlreadyExists.error("The local id \(id) is already used by a queue entry of another soup: local ids must be unique in the store")
        }
    }

    private static func existingRecord(_ transaction: SmartStore.Transaction, _ soupName: String, _ id: String) throws -> [String: Any] {
        guard let entryId = try lookupEntryId(transaction, soupName, id) else {
            throw LocalWriteError.recordNotFound.error("No record with \(idField) \(id) in \(soupName)")
        }
        guard let record = try transaction.retrieve(usingSoupEntryIds: [entryId], fromSoupNamed: soupName).first as? [String: Any] else {
            throw LocalWriteError.recordNotFound.error("No record with \(idField) \(id) in \(soupName)")
        }
        return record
    }

    private static func sobjectType(of record: [String: Any]) -> String? {
        return (record[attributesField] as? [String: Any])?[typeField] as? String
    }

    /// Inserts the record if it has no `_soupEntryId` (never overwrites another entry), updates it otherwise.
    private static func save(_ transaction: SmartStore.Transaction, _ soupName: String, _ record: [String: Any]) throws -> [String: Any] {
        let saved = try transaction.upsert(entries: [record], forSoupNamed: soupName, withExternalIdPath: SmartStore.soupEntryId)
        guard let result = saved.first as? [String: Any] else {
            throw LocalWriteError.storeFailure.error("The record was not saved in \(soupName)")
        }
        return result
    }

    private static func appendEntry(_ transaction: SmartStore.Transaction, soupName: String, recordId: String, sobjectType: String?, kind: SyncQueue.Kind, changes: [String: Any]?) throws {
        let sequence = try SyncQueue.nextSequence(in: transaction)
        let entry = SyncQueue.buildEntry(sequence: sequence, soupName: soupName, recordId: recordId, sobjectType: sobjectType, kind: kind, changes: changes)
        let saved = try transaction.upsert(entries: [entry], forSoupNamed: SyncQueue.soupName, withExternalIdPath: SmartStore.soupEntryId)
        if saved.isEmpty {
            throw LocalWriteError.storeFailure.error("The entry was not saved in \(SyncQueue.soupName)")
        }
    }
}
