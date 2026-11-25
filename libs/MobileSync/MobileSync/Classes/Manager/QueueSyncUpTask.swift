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
/// - record-level error (HTTP 4xx other than 401, 408 and 429, or a missing record / soup / object type): the error is
///   written in the entry (`lastError`, `attempts` + 1) and in the record (`__last_error__`). The later entries of the
///   same record, and those that refer to it (`parentRef`, a `changes` value equal to its id), are deferred for the rest
///   of the run (kept pending, nothing sent, no attempt counted), so an older edit never lands after a newer one. The
///   sync goes on with the unrelated records;
/// - transport error (no response, 401, 408, 429, 5xx, `REQUEST_LIMIT_EXCEEDED`): `attempts` + 1, the sync fails and
///   the entry stays at the head of the queue; the next sync retries it.
///
/// One queue replay runs at a time per store: a second one waits until the first is finished.
@objc(SFQueueSyncUpTask)
public class QueueSyncUpTask: SFSyncTask {
    private let queueSync: SyncState
    private var queueTarget: QueueSyncUpTarget?
    private var entryIds: [NSNumber] = []
    /// `(soupName, localId) -> serverId` of the records created during this run.
    private(set) var idMap: [RecordKey: String] = [:]
    /// Records that have a rejected or deferred entry in this run: their later entries are deferred.
    private var blockedRecords = Set<RecordKey>()
    private var blockedIds = Set<String>()
    /// Server ids of the blocked records, by object type: an upsert create that resolves to one of them waits.
    private var blockedServerIds: [String: Set<String>] = [:]
    /// Object types whose rejected upsert create could not be resolved to a destination: until the end of the run, their
    /// entries for any server id wait.
    private var conservativeTypes = Set<String>()
    /// Upserts (object type, external id field, value) of the blocked creates: they have no server id to compare.
    private var blockedUpserts = Set<UpsertKey>()
    /// Answers of the destination lookups of this run: a value is looked up once, until a write succeeds.
    private var destinations: [UpsertKey: Destination] = [:]

    struct UpsertKey: Hashable {
        let sobjectType: String
        let field: String
        let value: String
    }

    struct RecordKey: Hashable {
        let soupName: String
        let id: String
    }

    private var store: SmartStore { return syncManager.store }

    @objc public override init(_ syncManager: SyncManager, sync: SyncState, update: SyncUpdateBlock?) {
        self.queueSync = sync
        super.init(syncManager, sync: sync, update: update)
    }

    // MARK: Loop

    public override func run() {
        if QueueReplayGate.acquire(for: ObjectIdentifier(store), task: self) {
            start()
        }
    }

    /// Terminal status (done, failed, stopped): the next queue replay of the store can start.
    public override func updateSync(_ sync: SyncState, countSynched: UInt) {
        super.updateSync(sync, countSynched: countSynched)
        switch sync.status {
        case .done, .failed, .stopped:
            if let next = QueueReplayGate.release(for: ObjectIdentifier(store), task: self) {
                DispatchQueue.global().async { next.start() }
            }
        default:
            break
        }
    }

    fileprivate func start() {
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

            // An earlier entry of the record (or of a record it refers to) was rejected: this one waits for the next run
            if isDeferred(entry) {
                if upsertKey(of: entry) != nil { return deferUpsert(entry, next: index + 1) }
                block(entry)
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
            // An upsert may update the record behind a blocked entry: resolve its destination first
            if !blockedRecords.isEmpty, upsertKey(of: entry) != nil, let type = entry.sobjectType {
                resolveUpsertDestination(entry, type: type, next: next)
            } else {
                send(entry, next: next)
            }
            return
        }
    }

    /// What the id lookup of an upsert destination found.
    private enum Destination {
        case found(String)
        case notFound
        case inconclusive
    }

    /// Looks up the record that the upsert `entry` would update (once per object type, field and value in a run).
    /// A transport-class failure, or a 2xx answer without a usable id, fails the sync: `bump` says whether the entry gets
    /// its attempt (not when it already got one from the rejection that led here); `then` is not called.
    private func lookupDestination(_ entry: QueueEntry, bump: Bool, then: @escaping (Destination) -> Void) {
        guard let target = queueTarget, let key = upsertKey(of: entry) else { return then(.notFound) }
        if let known = destinations[key] { return then(known) }
        let fail: (NSError) -> Void = { [self] error in
            if bump { bumpAttempts(entry, error: error) }
            failSync(queueSync, failureMessage: "Id lookup failed for queue entry \(entry.sequence)", error: error)
        }
        target.lookupIdOnServer(key.sobjectType, externalIdField: key.field, externalId: key.value, onComplete: { [self] response in
            if let id = response?[kCreatedId] as? String, QueueSyncUpTarget.isNonBlank(id) {
                destinations[key] = .found(id)
                then(.found(id))
            } else {
                fail(QueueSyncUpTarget.recordError("The id lookup of the upsert destination returned no usable id"))
            }
        }, onFail: { [self] error in
            if QueueSyncUpTarget.isTransportError(error) {
                fail(error)
                return
            }
            let destination: Destination = QueueSyncUpTarget.isNotFound(error) ? .notFound : .inconclusive
            destinations[key] = destination
            then(destination)
        })
    }

    /// The destination of an upsert that is deferred or rejected: later entries addressing it wait.
    private func blockDestination(_ destination: Destination, type: String) {
        switch destination {
        case .found(let id): blockedServerIds[type, default: []].insert(id)
        case .inconclusive: conservativeTypes.insert(type)
        case .notFound: break
        }
    }

    /// Defers `entry` for the rest of the run. An upsert create has a destination that a later entry may address:
    /// it is blocked too, so that a newer edit cannot reach the server before the deferred upsert.
    private func deferUpsert(_ entry: QueueEntry, next: Int) {
        block(entry)
        // Nothing follows: there is no later entry to protect
        guard next < entryIds.count, let type = entry.sobjectType else { return replay(from: next) }
        lookupDestination(entry, bump: true) { [self] destination in
            blockDestination(destination, type: type)
            replay(from: next)
        }
    }

    /// Resolves the destination of the upsert `entry` before it is sent while a block is active. Defers the entry if
    /// the destination is a blocked record (or if the answer is inconclusive), sends it otherwise.
    private func resolveUpsertDestination(_ entry: QueueEntry, type: String, next: Int) {
        lookupDestination(entry, bump: true) { [self] destination in
            switch destination {
            case .found(let id) where blockedServerIds[type]?.contains(id) == true:
                block(entry)
                replay(from: next)
            case .inconclusive:
                blockDestination(destination, type: type)
                block(entry)
                replay(from: next)
            default:
                send(entry, next: next)
            }
        }
    }

    /// A rejected upsert create has no server id, but its destination may be a record that later entries address:
    /// look it up and block that record. Without an answer, the entries of the type for any server id wait.
    private func resolveRejectedUpsert(_ entry: QueueEntry, next: Int) {
        // Nothing follows: there is no later entry to protect
        guard next < entryIds.count, let type = entry.sobjectType, upsertKey(of: entry) != nil else { return replay(from: next) }
        lookupDestination(entry, bump: false) { [self] destination in
            blockDestination(destination, type: type)
            replay(from: next)
        }
    }

    private func send(_ entry: QueueEntry, next: Int) {
        guard let target = queueTarget else { return }
        target.sendRequest(syncManager, entry: entry, onComplete: { [self] response in
            // The write changed the server: an earlier answer of a destination lookup may be stale
            destinations.removeAll()
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
                resolveRejectedUpsert(entry, next: next)
            }
        })
    }

    private func isDeferred(_ entry: QueueEntry) -> Bool {
        if blockedRecords.isEmpty { return false }
        // A delete of a record that never reached the server sends nothing and drops all its entries: never deferred
        if entry.kind == .delete && SyncTarget.isLocalId(entry.recordId) { return false }
        if blockedRecords.contains(RecordKey(soupName: entry.soupName, id: entry.recordId)) { return true }
        // A server record is one record, whichever soup holds the row: a rejected entry on it blocks the later ones
        if !SyncTarget.isLocalId(entry.recordId), let type = entry.sobjectType {
            if blockedServerIds[type]?.contains(entry.recordId) == true { return true }
            if conservativeTypes.contains(type) { return true }
        }
        if let key = upsertKey(of: entry), blockedUpserts.contains(key) { return true }
        if let parent = entry.parentRef, blockedIds.contains(parent) { return true }
        return entry.changes.values.contains { ($0 as? String).map { blockedIds.contains($0) } ?? false }
    }

    private func block(_ entry: QueueEntry) {
        blockedRecords.insert(RecordKey(soupName: entry.soupName, id: entry.recordId))
        blockedIds.insert(entry.recordId)
        if let type = entry.sobjectType {
            if !SyncTarget.isLocalId(entry.recordId) { blockedServerIds[type, default: []].insert(entry.recordId) }
            if let key = upsertKey(of: entry) { blockedUpserts.insert(key) }
        }
    }

    private func upsertKey(of entry: QueueEntry) -> UpsertKey? {
        guard let type = entry.sobjectType, let field = queueTarget?.upsertField(of: entry), let value = queueTarget?.upsertExternalId(of: entry) else { return nil }
        return UpsertKey(sobjectType: type, field: field, value: value)
    }

    private func problem(with entry: QueueEntry, recordExists: Bool) -> String? {
        if entry.kind == nil { return "Unknown entry kind" }
        if entry.sobjectType?.isEmpty ?? true { return "The entry has no object type" }
        if !soupExists(entry.soupName) { return "Soup \(entry.soupName) does not exist" }
        if !recordExists { return "No record with \(idField) \(entry.recordId) in \(entry.soupName)" }
        return queueTarget?.externalIdProblem(of: entry)
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
            if let mapped = QueueSyncUpTarget.remapped(raw, own: ownMap(inSoup: entry.soupName), refs: refMap), let mappedEntry = QueueEntry(mapped) {
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

    /// Local ids replaced in this run in `soupName` (for the `recordId` of an entry of that soup).
    private func ownMap(inSoup soupName: String) -> [String: String] {
        return Dictionary(uniqueKeysWithValues: idMap.filter { $0.key.soupName == soupName }.map { ($0.key.id, $0.value) })
    }

    /// Local ids replaced in this run, any soup (local ids used in references are unique store-wide).
    private var refMap: [String: String] {
        return Dictionary(idMap.map { ($0.key.id, $0.value) }, uniquingKeysWith: { first, _ in first })
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
            if !(serverId.map { QueueSyncUpTarget.isNonBlank($0) } ?? false) {
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
            idMap[RecordKey(soupName: entry.soupName, id: entry.recordId)] = serverId
        }
        return .done
    }

    /// Temp-id remapping, in one transaction with the removal of the replayed entry: the record gets the server id
    /// (in place, by soup entry id) and is cleaned, and the pending entries that refer to the local id are rewritten.
    private func completeCreate(_ transaction: SmartStore.Transaction, _ entry: QueueEntry, serverId: String) throws {
        let localId = entry.recordId
        try transaction.remove(entryIds: [entry.entryId], forSoupNamed: SyncQueue.soupName)
        try rewritePendingEntries(transaction, from: localId, to: serverId, replayed: entry)
        if var record = try record(transaction, entry.soupName, localId) {
            var duplicate = false
            // A row with the server id can already exist (sync down, or an upsert that updated an existing record):
            // it is replaced by the rewritten local row, which keeps the fields that the upsert did not touch
            if let localEntryId = try recordEntryId(transaction, entry.soupName, localId),
               let existing = try recordEntryId(transaction, entry.soupName, serverId), existing != localEntryId {
                if let cached = try self.record(transaction, entry.soupName, serverId) {
                    for (name, value) in cached where record[name] == nil && !name.hasPrefix("_soup") && name != kSyncTargetLastError {
                        record[name] = value
                    }
                }
                try transaction.remove(entryIds: [existing], forSoupNamed: entry.soupName)
                duplicate = true
            }
            record[idField] = serverId
            if duplicate {
                // The later edits queued for the server record were made on the removed row: apply them, in queue
                // order, over the surviving one
                for later in try pendingEntries(transaction, entry.soupName, serverId) where later.kind == .update && later.sequence > entry.sequence {
                    record.merge(later.changes) { _, new in new }
                }
            }
            // The entries of the record now carry the server id: they decide whether the record stays dirty
            let remaining = try pendingKinds(transaction, entry.soupName, serverId)
            settle(&record, pending: remaining)
            if duplicate && remaining.contains(SyncQueue.Kind.delete.rawValue) { record[kSyncTargetLocallyDeleted] = true }
            try upsert(transaction, record, into: entry.soupName)
        } else {
            // The app removed the record meanwhile: the create succeeded on the server, only the entries are rewritten
            MobileSyncLogger.default.w(QueueSyncUpTask.self, message: "Record \(localId) is no longer in \(entry.soupName)")
        }
    }

    /// Replaces `localId` by `serverId` in the `recordId` of the entries of the soup of the replayed create, and in the
    /// `parentRef` and `changes` values of the entries of any soup (local ids are unique store-wide)
    /// and in their `changes` values that are exactly `localId` (top-level strings only).
    private func rewritePendingEntries(_ transaction: SmartStore.Transaction, from localId: String, to serverId: String, replayed: QueueEntry) throws {
        let queue = SyncQueue.soupName
        // The LIKE only preselects; the exact match is checked in `remapped`
        let smartSql = "SELECT {\(queue):_soup} FROM {\(queue)} WHERE {\(queue):\(SyncQueue.recordIdField)} = ? OR {\(queue):\(SyncQueue.parentRefField)} = ? OR {\(queue):\(SyncQueue.changesField)} LIKE ?"
        let pageSize: UInt = 1000
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: pageSize) else {
            throw LocalWriteError.storeFailure.error("Could not build the queue query")
        }
        // The changes are stored as JSON: the id is searched as it is serialized (quotes, backslashes and slashes escaped)
        let args: [Any] = [localId, localId, "%\(QueueSyncUpTask.jsonString(localId))%"]
        var rewritten: [[String: Any]] = []
        var page: UInt = 0
        while true {
            let rows = try transaction.query(using: querySpec, startingFromPageIndex: page, whereArgs: args) as? [[Any]] ?? []
            for case let raw as [String: Any] in rows.compactMap({ $0.first }) {
                if let id = raw[SmartStore.soupEntryId] as? NSNumber, id == replayed.entryId { continue }
                // The record id of an entry is only replaced in the soup of the replayed create
                let own = (raw[SyncQueue.soupNameField] as? String) == replayed.soupName ? [localId: serverId] : [:]
                if let mapped = QueueSyncUpTarget.remapped(raw, own: own, refs: [localId: serverId]) {
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

    /// `value` as a JSON string literal, with its quotes.
    private static func jsonString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]), let array = String(data: data, encoding: .utf8) else {
            return "\"\(value)\""
        }
        return String(array.dropFirst().dropLast())
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

    /// All the entries (pending or parked) of a record, paging through the result.
    private func entryIds(_ transaction: SmartStore.Transaction, _ soupName: String, _ recordId: String) throws -> [NSNumber] {
        let queue = SyncQueue.soupName
        let smartSql = "SELECT {\(queue):\(SmartStore.soupEntryId)} FROM {\(queue)} WHERE {\(queue):\(SyncQueue.soupNameField)} = ? AND {\(queue):\(SyncQueue.recordIdField)} = ? ORDER BY {\(queue):\(SmartStore.soupEntryId)} ASC"
        let pageSize: UInt = 1000
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: pageSize) else {
            throw LocalWriteError.storeFailure.error("Could not build the queue query")
        }
        var ids: [NSNumber] = []
        var page: UInt = 0
        while true {
            let rows = try transaction.query(using: querySpec, startingFromPageIndex: page, whereArgs: [soupName, recordId])
            ids.append(contentsOf: rows.compactMap { ($0 as? [Any])?.first as? NSNumber })
            if rows.count < pageSize { return ids }
            page += 1
        }
    }

    /// The entries (pending or parked) of a record, in queue order.
    private func pendingEntries(_ transaction: SmartStore.Transaction, _ soupName: String, _ recordId: String) throws -> [QueueEntry] {
        let queue = SyncQueue.soupName
        let smartSql = "SELECT {\(queue):_soup} FROM {\(queue)} WHERE {\(queue):\(SyncQueue.soupNameField)} = ? AND {\(queue):\(SyncQueue.recordIdField)} = ? ORDER BY {\(queue):\(SyncQueue.sequenceField)} ASC"
        let pageSize: UInt = 1000
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: pageSize) else {
            throw LocalWriteError.storeFailure.error("Could not build the queue query")
        }
        var entries: [QueueEntry] = []
        var page: UInt = 0
        while true {
            let rows = try transaction.query(using: querySpec, startingFromPageIndex: page, whereArgs: [soupName, recordId])
            entries.append(contentsOf: rows.compactMap { (($0 as? [Any])?.first as? [String: Any]).flatMap { QueueEntry($0) } })
            if rows.count < pageSize { return entries }
            page += 1
        }
    }

    /// Kinds of the entries (pending or parked) that remain in the queue for a record.
    private func pendingKinds(_ transaction: SmartStore.Transaction, _ soupName: String, _ recordId: String) throws -> Set<String> {
        let queue = SyncQueue.soupName
        let smartSql = "SELECT DISTINCT {\(queue):\(SyncQueue.kindField)} FROM {\(queue)} WHERE {\(queue):\(SyncQueue.soupNameField)} = ? AND {\(queue):\(SyncQueue.recordIdField)} = ?"
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 1000) else {
            throw LocalWriteError.storeFailure.error("Could not build the queue query")
        }
        let rows = try transaction.query(using: querySpec, startingFromPageIndex: 0, whereArgs: [soupName, recordId])
        return Set(rows.compactMap { ($0 as? [Any])?.first as? String })
    }

    private func completeDelete(_ transaction: SmartStore.Transaction, _ entry: QueueEntry) throws {
        // The record is gone: every other entry for it goes too (earlier entries of a record that never reached the
        // server, or leftovers of one that did)
        var ids = try entryIds(transaction, entry.soupName, entry.recordId)
        if !ids.contains(entry.entryId) { ids.append(entry.entryId) }
        try transaction.remove(entryIds: ids, forSoupNamed: SyncQueue.soupName)
        if soupExists(entry.soupName), let recordId = try recordEntryId(transaction, entry.soupName, entry.recordId) {
            try transaction.remove(entryIds: [recordId], forSoupNamed: entry.soupName)
        }
    }

    /// Record-level error: written in the entry (`lastError`, `attempts` + 1, still pending) and in the record
    /// (`__last_error__`). The sync goes on. Returns false (and fails the sync) if the store cannot be written.
    private func recordFailure(_ entry: QueueEntry, error: NSError) -> Bool {
        // The later entries of the record, and those that refer to it, wait for the next run
        block(entry)
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

/// One queue replay at a time per store. The holder keeps it from its first read of the queue until it is done,
/// failed or stopped (so through the last request and the local commit); the others wait and then read the queue
/// as the holder left it.
private enum QueueReplayGate {
    private static let lock = NSLock()
    private static var holders: [ObjectIdentifier: QueueSyncUpTask] = [:]
    private static var waiting: [ObjectIdentifier: [QueueSyncUpTask]] = [:]

    /// Returns true if `task` now holds the gate; otherwise `task` is queued and started by `release`.
    static func acquire(for store: ObjectIdentifier, task: QueueSyncUpTask) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if holders[store] == nil {
            holders[store] = task
            return true
        }
        waiting[store, default: []].append(task)
        return false
    }

    /// Releases the gate if `task` holds it. Returns the task that holds it now, if any: the caller starts it.
    static func release(for store: ObjectIdentifier, task: QueueSyncUpTask) -> QueueSyncUpTask? {
        lock.lock()
        defer { lock.unlock() }
        guard holders[store] === task else { return nil }
        if var queue = waiting[store], !queue.isEmpty {
            let next = queue.removeFirst()
            waiting[store] = queue.isEmpty ? nil : queue
            holders[store] = next
            return next
        }
        holders[store] = nil
        return nil
    }
}
