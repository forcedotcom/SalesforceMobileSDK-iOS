//
//  QueueSyncUpTask.swift
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

import Foundation
import SalesforceSDKCore
import SmartStore

private let idField = "Id"

/// Task that runs a sync up whose target is a `QueueSyncUpTarget`: replays the pending entries of the sync-up
/// queue strictly one at a time, in `sequence` order.
///
/// Outcomes per entry:
/// - success: the entry is removed and the record cleaned (a created record gets its server id, which is also
///   written in the pending entries that refer to it, see `rewritePendingEntries`);
/// - record-level error (HTTP 4xx, or a missing record / soup / object type): the error is written in the entry
///   (`lastError`, `attempts` + 1) and in the record (`__last_error__`), the sync goes on with the next entry;
/// - transport error (no response, 5xx, `REQUEST_LIMIT_EXCEEDED`): `attempts` + 1, the sync fails and the entry
///   stays at the head of the queue; the next sync retries it.
@objc(SFQueueSyncUpTask)
public class QueueSyncUpTask: SFSyncTask {
    private let queueSync: SyncState
    private var queueTarget: QueueSyncUpTarget?
    private var entryIds: [NSNumber] = []
    /// `localId -> serverId` of the records created during this run.
    private(set) var idMap: [String: String] = [:]

    private var store: SmartStore { return syncManager.store }

    @objc public override init(_ syncManager: SyncManager, sync: SyncState, update: SyncUpdateBlock?) {
        self.queueSync = sync
        super.init(syncManager, sync: sync, update: update)
    }

    // MARK: Loop

    public override func run() {
        if shouldStop() {
            return
        }
        guard let target = queueSync.target as? QueueSyncUpTarget else {
            return failSync(queueSync, failureMessage: "The target of a queue sync must be a QueueSyncUpTarget", error: QueueSyncUpTarget.recordError("Wrong target"))
        }
        queueTarget = target
        SyncQueue.setupQueueSoupIfNeeded(store)
        do {
            entryIds = try pendingEntryIds()
        } catch {
            return failSync(queueSync, failureMessage: "Could not read the sync-up queue", error: error as NSError)
        }
        queueSync.totalSize = entryIds.count
        replay(from: 0)
    }

    /// Replays the entries from `start`. Entries that complete without a server call are handled in the loop;
    /// after a request, the callback calls this method again for the next entry.
    private func replay(from start: Int) {
        guard let target = queueTarget else { return }
        var index = start
        while true {
            updateSync(queueSync, countSynched: UInt(index))
            if queueSync.isDone() || shouldStop() {
                return
            }

            let loaded: (entry: QueueEntry, recordExists: Bool)?
            do {
                loaded = try load(entryId: entryIds[index])
            } catch {
                return failSync(queueSync, failureMessage: "Could not read a queue entry", error: error as NSError)
            }
            // Entry removed or parked since the start of the run
            guard let (entry, recordExists) = loaded else {
                index += 1
                continue
            }

            // Entry that cannot be replayed: record-level error
            if let problem = problem(with: entry, recordExists: recordExists) {
                if !recordFailure(entry, error: QueueSyncUpTarget.recordError(problem)) { return }
                index += 1
                continue
            }

            // Delete of a record that never reached the server: nothing to send
            if entry.kind == .delete && SyncTarget.isLocalId(entry.recordId) {
                if !handle(complete(entry, response: nil), entry: entry) { return }
                index += 1
                continue
            }

            let next = index + 1
            target.sendRequest(syncManager, entry: entry, onComplete: { [self] response in
                if handle(complete(entry, response: response), entry: entry) {
                    replay(from: next)
                }
            }, onFail: { [self] error in
                if QueueSyncUpTarget.isTransportError(error) {
                    bumpAttempts(entry, error: error)
                    failSync(queueSync, failureMessage: "Server call failed for queue entry \(entry.sequence)", error: error)
                } else if entry.kind == .delete && QueueSyncUpTarget.isNotFound(error) {
                    // Already deleted on the server
                    if handle(complete(entry, response: nil), entry: entry) {
                        replay(from: next)
                    }
                } else if recordFailure(entry, error: error) {
                    replay(from: next)
                }
            })
            return
        }
    }

    private func problem(with entry: QueueEntry, recordExists: Bool) -> String? {
        if entry.kind == nil { return "Unknown entry kind" }
        if entry.sobjectType?.isEmpty ?? true { return "The entry has no object type" }
        if !soupExists(entry.soupName) { return "Soup \(entry.soupName) does not exist" }
        if !recordExists { return "No record with \(idField) \(entry.recordId) in \(entry.soupName)" }
        return nil
    }

    /// Fails the sync if the outcome is a store failure. Returns true if the sync can go on.
    private func handle(_ outcome: Outcome, entry: QueueEntry) -> Bool {
        switch outcome {
        case .done:
            return true
        case .recordError(let error):
            return recordFailure(entry, error: error)
        case .unexpected(let error):
            bumpAttempts(entry, error: error)
            failSync(queueSync, failureMessage: "Unexpected answer for queue entry \(entry.sequence)", error: error)
            return false
        case .storeFailure(let error):
            failSync(queueSync, failureMessage: "Could not update the store after queue entry \(entry.sequence)", error: error)
            return false
        }
    }

    // MARK: Reads

    /// Ids of the pending entries, in replay order.
    private func pendingEntryIds() throws -> [NSNumber] {
        let queue = SyncQueue.soupName
        let smartSql = "SELECT {\(queue):\(SmartStore.soupEntryId)} FROM {\(queue)} WHERE {\(queue):\(SyncQueue.statusField)} = '\(SyncQueue.Status.pending.rawValue)' ORDER BY {\(queue):\(SyncQueue.sequenceField)} ASC"
        let pageSize: UInt = 1000
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: pageSize) else {
            throw LocalWriteError.storeFailure.error("Could not build the queue query")
        }
        var ids: [NSNumber] = []
        var page: UInt = 0
        while true {
            let rows = try store.query(using: querySpec, startingFromPageIndex: page) as? [[Any]] ?? []
            ids.append(contentsOf: rows.compactMap { $0.first as? NSNumber })
            if rows.count < pageSize { return ids }
            page += 1
        }
    }

    /// Reads an entry (it is re-read right before it is replayed, because the remapping rewrites later entries) and
    /// whether its record exists. Returns nil if the entry is gone or no longer pending.
    private func load(entryId: NSNumber) throws -> (entry: QueueEntry, recordExists: Bool)? {
        var loaded: QueueEntry?
        try transact { transaction in
            guard let raw = try transaction.retrieve(usingSoupEntryIds: [entryId], fromSoupNamed: SyncQueue.soupName).first as? [String: Any],
                  var entry = QueueEntry(raw),
                  entry.status == SyncQueue.Status.pending.rawValue else {
                return
            }
            // Safety net: map the local ids that this run has already replaced
            if let mapped = QueueSyncUpTarget.remapped(raw, using: idMap), let mappedEntry = QueueEntry(mapped) {
                entry = mappedEntry
            }
            loaded = entry
        }
        guard let entry = loaded else { return nil }
        // The store is not used inside a transaction block: check the soup before the lookup
        refreshSoupExists(entry.soupName)
        var exists = false
        if soupExists(entry.soupName) {
            try transact { transaction in
                exists = try recordEntryId(transaction, entry.soupName, entry.recordId) != nil
            }
        }
        return (entry, exists)
    }

    /// Soups known to exist (`SmartStore.soupExists` must not be called from a transaction block).
    private var existingSoups = Set<String>()

    private func refreshSoupExists(_ soupName: String) {
        if store.soupExists(forName: soupName) {
            existingSoups.insert(soupName)
        } else {
            existingSoups.remove(soupName)
        }
    }

    private func soupExists(_ soupName: String) -> Bool {
        return existingSoups.contains(soupName)
    }

    private func recordEntryId(_ transaction: SmartStore.Transaction, _ soupName: String, _ id: String) throws -> NSNumber? {
        return try transaction.lookupSoupEntryId(soupNamed: soupName, fieldPath: idField, fieldValue: id)
    }

    private func record(_ transaction: SmartStore.Transaction, _ soupName: String, _ id: String) throws -> [String: Any]? {
        guard soupExists(soupName), let entryId = try recordEntryId(transaction, soupName, id) else {
            return nil
        }
        return try transaction.retrieve(usingSoupEntryIds: [entryId], fromSoupNamed: soupName).first as? [String: Any]
    }

    // MARK: Writes

    enum Outcome {
        case done
        case recordError(NSError)
        case unexpected(NSError)
        case storeFailure(NSError)
    }

    /// Runs `work` in one SmartStore transaction; an error thrown by `work` rolls it back and is thrown to the caller.
    private func transact(_ work: (SmartStore.Transaction) throws -> Void) throws {
        try store.performTransaction { transaction in
            do {
                try work(transaction)
            } catch {
                transaction.fail(with: error as NSError)
            }
        }
    }

    private func clean(_ record: inout [String: Any]) {
        record[kSyncTargetLocal] = false
        record[kSyncTargetLocallyCreated] = false
        record[kSyncTargetLocallyUpdated] = false
        record[kSyncTargetLocallyDeleted] = false
        record[kSyncTargetLastError] = nil
    }

    private func upsert(_ transaction: SmartStore.Transaction, _ record: [String: Any], into soupName: String) throws {
        let saved = try transaction.upsert(entries: [record], forSoupNamed: soupName, withExternalIdPath: SmartStore.soupEntryId)
        if saved.isEmpty {
            throw LocalWriteError.storeFailure.error("The entry was not saved in \(soupName)")
        }
    }

    /// The server accepted the entry: removes it and updates the record (and, for a create, the references to it).
    private func complete(_ entry: QueueEntry, response: [AnyHashable: Any]?) -> Outcome {
        var serverId: String?
        if entry.kind == .create {
            serverId = response?[kCreatedId] as? String
            if serverId?.isEmpty ?? true {
                return .unexpected(QueueSyncUpTarget.recordError("The server did not return the id of the created record"))
            }
        }
        do {
            try transact { transaction in
                switch entry.kind {
                case .create:
                    guard let serverId = serverId else { return }
                    try completeCreate(transaction, entry, serverId: serverId)
                case .update:
                    try completeUpdate(transaction, entry)
                case .delete:
                    try completeDelete(transaction, entry)
                case .none:
                    break
                }
            }
        } catch {
            return .storeFailure(error as NSError)
        }
        if entry.kind == .create, let serverId = serverId, SyncTarget.isLocalId(entry.recordId) {
            idMap[entry.recordId] = serverId
        }
        return .done
    }

    /// Temp-id remapping, in one transaction with the removal of the replayed entry: the record gets the server id
    /// (in place, by soup entry id) and is cleaned, and the pending entries that refer to the local id are rewritten.
    private func completeCreate(_ transaction: SmartStore.Transaction, _ entry: QueueEntry, serverId: String) throws {
        let localId = entry.recordId
        try transaction.remove(entryIds: [entry.entryId], forSoupNamed: SyncQueue.soupName)
        try rewritePendingEntries(transaction, from: localId, to: serverId, replayed: entry.entryId)
        if var record = try record(transaction, entry.soupName, localId) {
            // A row with the server id can already exist (sync down, or an upsert that updated an existing record):
            // it is replaced by the rewritten local row
            if let localEntryId = try recordEntryId(transaction, entry.soupName, localId),
               let existing = try recordEntryId(transaction, entry.soupName, serverId), existing != localEntryId {
                try transaction.remove(entryIds: [existing], forSoupNamed: entry.soupName)
            }
            record[idField] = serverId
            // The entries of the record now carry the server id: they decide whether the record stays dirty
            settle(&record, pending: try pendingKinds(transaction, entry.soupName, serverId))
            try upsert(transaction, record, into: entry.soupName)
        } else {
            // The app removed the record meanwhile: the create succeeded on the server, only the entries are rewritten
            MobileSyncLogger.default.w(QueueSyncUpTask.self, message: "Record \(localId) is no longer in \(entry.soupName)")
        }
    }

    /// Replaces `localId` by `serverId` in the `recordId` and `parentRef` of the pending entries (any record soup)
    /// and in their `changes` values that are exactly `localId` (top-level strings only).
    private func rewritePendingEntries(_ transaction: SmartStore.Transaction, from localId: String, to serverId: String, replayed: NSNumber) throws {
        let queue = SyncQueue.soupName
        // The LIKE only preselects (local ids contain no JSON escapes); the exact match is checked in `remapped`
        let smartSql = "SELECT {\(queue):_soup} FROM {\(queue)} WHERE {\(queue):\(SyncQueue.recordIdField)} = ? OR {\(queue):\(SyncQueue.parentRefField)} = ? OR {\(queue):\(SyncQueue.changesField)} LIKE ?"
        let pageSize: UInt = 1000
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: pageSize) else {
            throw LocalWriteError.storeFailure.error("Could not build the queue query")
        }
        let args: [Any] = [localId, localId, "%\"\(localId)\"%"]
        var rewritten: [[String: Any]] = []
        var page: UInt = 0
        while true {
            let rows = try transaction.query(using: querySpec, startingFromPageIndex: page, whereArgs: args) as? [[Any]] ?? []
            for case let raw as [String: Any] in rows.compactMap({ $0.first }) {
                if let id = raw[SmartStore.soupEntryId] as? NSNumber, id == replayed { continue }
                if let mapped = QueueSyncUpTarget.remapped(raw, using: [localId: serverId]) {
                    rewritten.append(mapped)
                }
            }
            if rows.count < pageSize { break }
            page += 1
        }
        if !rewritten.isEmpty {
            try upsert(transaction, rewritten, into: queue)
        }
    }

    private func upsert(_ transaction: SmartStore.Transaction, _ records: [[String: Any]], into soupName: String) throws {
        let saved = try transaction.upsert(entries: records, forSoupNamed: soupName, withExternalIdPath: SmartStore.soupEntryId)
        if saved.count != records.count {
            throw LocalWriteError.storeFailure.error("The entries were not saved in \(soupName)")
        }
    }

    /// The record is cleaned only if no other entry for it remains: otherwise it stays dirty for the remaining entries.
    private func completeUpdate(_ transaction: SmartStore.Transaction, _ entry: QueueEntry) throws {
        try transaction.remove(entryIds: [entry.entryId], forSoupNamed: SyncQueue.soupName)
        guard var record = try record(transaction, entry.soupName, entry.recordId) else { return }
        settle(&record, pending: try pendingKinds(transaction, entry.soupName, entry.recordId))
        try upsert(transaction, record, into: entry.soupName)
    }

    /// Flags of a record whose entry was just replayed: clean if `pending` (the kinds of the entries that remain for the
    /// record) is empty, otherwise dirty as the remaining entries need (a pending delete stays flagged).
    private func settle(_ record: inout [String: Any], pending: Set<String>) {
        if pending.isEmpty {
            clean(&record)
        } else {
            // __last_error__ belongs to a failed entry that remains: it is kept
            record[kSyncTargetLocal] = true
            record[kSyncTargetLocallyCreated] = false
            record[kSyncTargetLocallyUpdated] = pending.contains(SyncQueue.Kind.update.rawValue)
        }
    }

    private func entryIds(_ transaction: SmartStore.Transaction, _ soupName: String, _ recordId: String) throws -> [NSNumber] {
        let queue = SyncQueue.soupName
        let smartSql = "SELECT {\(queue):\(SmartStore.soupEntryId)} FROM {\(queue)} WHERE {\(queue):\(SyncQueue.soupNameField)} = ? AND {\(queue):\(SyncQueue.recordIdField)} = ?"
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 1000) else {
            throw LocalWriteError.storeFailure.error("Could not build the queue query")
        }
        let rows = try transaction.query(using: querySpec, startingFromPageIndex: 0, whereArgs: [soupName, recordId])
        return rows.compactMap { ($0 as? [Any])?.first as? NSNumber }
    }

    /// Kinds of the entries (pending or parked) that remain in the queue for a record.
    private func pendingKinds(_ transaction: SmartStore.Transaction, _ soupName: String, _ recordId: String) throws -> Set<String> {
        let queue = SyncQueue.soupName
        let smartSql = "SELECT {\(queue):\(SyncQueue.kindField)} FROM {\(queue)} WHERE {\(queue):\(SyncQueue.soupNameField)} = ? AND {\(queue):\(SyncQueue.recordIdField)} = ?"
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 1000) else {
            throw LocalWriteError.storeFailure.error("Could not build the queue query")
        }
        let rows = try transaction.query(using: querySpec, startingFromPageIndex: 0, whereArgs: [soupName, recordId])
        return Set(rows.compactMap { ($0 as? [Any])?.first as? String })
    }

    private func completeDelete(_ transaction: SmartStore.Transaction, _ entry: QueueEntry) throws {
        try transaction.remove(entryIds: [entry.entryId], forSoupNamed: SyncQueue.soupName)
        if SyncTarget.isLocalId(entry.recordId) {
            // The record never reached the server: its earlier entries (failed create or updates) are dropped too
            try transaction.remove(entryIds: try entryIds(transaction, entry.soupName, entry.recordId), forSoupNamed: SyncQueue.soupName)
        }
        if soupExists(entry.soupName), let recordId = try recordEntryId(transaction, entry.soupName, entry.recordId) {
            try transaction.remove(entryIds: [recordId], forSoupNamed: entry.soupName)
        }
    }

    /// Record-level error: written in the entry (`lastError`, `attempts` + 1, still pending) and in the record
    /// (`__last_error__`). The sync goes on. Returns false (and fails the sync) if the store cannot be written.
    private func recordFailure(_ entry: QueueEntry, error: NSError) -> Bool {
        let lastError = QueueSyncUpTarget.lastError(error)
        do {
            try transact { transaction in
                var raw = entry.raw
                raw[SyncQueue.lastErrorField] = lastError
                raw[SyncQueue.attemptsField] = entry.attempts + 1
                try upsert(transaction, raw, into: SyncQueue.soupName)
                if var record = try record(transaction, entry.soupName, entry.recordId),
                   let data = try? JSONSerialization.data(withJSONObject: lastError),
                   let json = String(data: data, encoding: .utf8) {
                    record[kSyncTargetLastError] = json
                    try upsert(transaction, record, into: entry.soupName)
                }
            }
        } catch {
            failSync(queueSync, failureMessage: "Could not record the error of queue entry \(entry.sequence)", error: error as NSError)
            return false
        }
        return true
    }

    /// Transport error: `attempts` + 1, the entry stays pending at the head of the queue.
    private func bumpAttempts(_ entry: QueueEntry, error: NSError) {
        do {
            try transact { transaction in
                var raw = entry.raw
                raw[SyncQueue.lastErrorField] = QueueSyncUpTarget.lastError(error)
                raw[SyncQueue.attemptsField] = entry.attempts + 1
                try upsert(transaction, raw, into: SyncQueue.soupName)
            }
        } catch {
            MobileSyncLogger.default.e(QueueSyncUpTask.self, message: "Could not update the attempts of queue entry \(entry.sequence): \(error)")
        }
    }
}
