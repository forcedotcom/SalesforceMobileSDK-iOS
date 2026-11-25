//
//  LocalWriteTests.swift
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

import XCTest
@testable import MobileSync
import SmartStore

/// Network-free tests of the local write API (`createLocal`, `updateLocal`, `deleteLocal`) on a global store.
class LocalWriteTests: XCTestCase {
    private static let storeName = "LocalWriteTests"
    private static let accounts = "accounts"
    private static let contacts = "contacts"

    private var store: SmartStore!
    private var syncManager: SyncManager!

    override func setUpWithError() throws {
        store = try XCTUnwrap(SmartStore.sharedGlobal(withName: LocalWriteTests.storeName))
        try registerRecordSoup(LocalWriteTests.accounts)
        try registerRecordSoup(LocalWriteTests.contacts)
        syncManager = try XCTUnwrap(SyncManager.sharedInstance(store: store))
    }

    override func tearDown() {
        LocalIdGenerator.generate = { SyncTarget.createLocalId() }
        SyncManager.removeSharedInstance(store: store)
        SmartStore.removeSharedGlobal(withName: LocalWriteTests.storeName)
        super.tearDown()
    }

    // MARK: helpers

    private func registerRecordSoup(_ soupName: String, withIdIndex: Bool = true) throws {
        var paths = ["Name", kSyncTargetLocal, kSyncTargetLocallyCreated, kSyncTargetLocallyUpdated, kSyncTargetLocallyDeleted]
        if withIdIndex {
            paths.insert("Id", at: 0)
        }
        let indices = paths.compactMap { SoupIndex(path: $0, indexType: kSoupIndexTypeString, columnName: nil) }
        try store.registerSoup(withName: soupName, withIndices: indices)
    }

    private func account(_ name: String, extra: [String: Any] = [:]) -> [String: Any] {
        var record: [String: Any] = ["attributes": ["type": "Account"], "Name": name]
        record.merge(extra) { _, new in new }
        return record
    }

    private func allRecords(_ soupName: String) throws -> [[String: Any]] {
        let querySpec = try XCTUnwrap(QuerySpec.buildAllQuerySpec(soupName: soupName, orderPath: SmartStore.soupEntryId, order: .ascending, pageSize: 1000))
        return try XCTUnwrap(store.query(using: querySpec, startingFromPageIndex: 0) as? [[String: Any]])
    }

    private func queueEntries() throws -> [[String: Any]] {
        return try allRecords(SyncQueue.soupName).sorted { ($0["sequence"] as? Int ?? 0) < ($1["sequence"] as? Int ?? 0) }
    }

    private func flag(_ record: [String: Any], _ name: String) -> Bool? {
        return (record[name] as? NSNumber)?.boolValue
    }

    private func assertFlags(_ record: [String: Any], created: Bool, updated: Bool, deleted: Bool, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(flag(record, kSyncTargetLocal), true, "local", file: file, line: line)
        XCTAssertEqual(flag(record, kSyncTargetLocallyCreated), created, "created", file: file, line: line)
        XCTAssertEqual(flag(record, kSyncTargetLocallyUpdated), updated, "updated", file: file, line: line)
        XCTAssertEqual(flag(record, kSyncTargetLocallyDeleted), deleted, "deleted", file: file, line: line)
    }

    /// Snapshot of both soups, to check that a failed call changed nothing.
    private func snapshot() throws -> (records: [NSDictionary], accounts: [NSDictionary], queue: [NSDictionary]) {
        return (try allRecords(LocalWriteTests.accounts).map { $0 as NSDictionary },
                try allRecords(LocalWriteTests.contacts).map { $0 as NSDictionary },
                try queueEntries().map { $0 as NSDictionary })
    }

    private func assertFails(code: LocalWriteError, file: StaticString = #filePath, line: UInt = #line, _ call: () throws -> Any) throws {
        let before = try snapshot()
        XCTAssertThrowsError(try call(), file: file, line: line) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, kSFMobileSyncErrorDomain, file: file, line: line)
            XCTAssertEqual(nsError.code, code.rawValue, "\(nsError)", file: file, line: line)
            XCTAssertNotNil(nsError.userInfo[NSLocalizedDescriptionKey], file: file, line: line)
        }
        let after = try snapshot()
        XCTAssertEqual(before.records, after.records, "records changed", file: file, line: line)
        XCTAssertEqual(before.accounts, after.accounts, "records changed", file: file, line: line)
        XCTAssertEqual(before.queue, after.queue, "queue changed", file: file, line: line)
    }

    /// Makes every insert in the queue soup fail, after the record write succeeded: a SQLite BEFORE INSERT
    /// trigger on the queue soup's table raises ABORT. SmartStore's internals (store queue, soup table name)
    /// are reached through the Objective-C runtime, so no production code is exposed for this.
    private func makeQueueInsertsFail() throws {
        let queue = try XCTUnwrap(store.value(forKey: "storeQueue") as AnyObject?)
        var created = false
        let work: @convention(block) (AnyObject) -> Void = { [store] database in
            guard let store = store,
                  let table = store.perform(NSSelectorFromString("tableNameForSoup:withDb:"), with: SyncQueue.soupName, with: database)?.takeUnretainedValue() as? String else {
                return
            }
            let sql = "CREATE TRIGGER fail_queue_insert BEFORE INSERT ON \(table) BEGIN SELECT RAISE(ABORT, 'injected failure'); END"
            _ = database.perform(NSSelectorFromString("executeStatements:"), with: sql)
            created = true
        }
        _ = queue.perform(NSSelectorFromString("inDatabase:"), with: work)
        XCTAssertTrue(created, "trigger could not be created")
    }

    // MARK: createLocal

    func test_givenRecord_whenCreateLocal_thenRecordAndCreateEntryAreSaved() throws {
        let saved = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("Acme", extra: ["Phone": "123"]))

        let id = try XCTUnwrap(saved["Id"] as? String)
        XCTAssertTrue(SyncTarget.isLocalId(id))
        XCTAssertEqual(saved["Name"] as? String, "Acme")
        assertFlags(saved, created: true, updated: false, deleted: false)
        XCTAssertNil(saved[kSyncTargetLastError])
        XCTAssertNotNil(saved[SmartStore.soupEntryId])

        let stored = try allRecords(LocalWriteTests.accounts)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?["Id"] as? String, id)

        let entries = try queueEntries()
        XCTAssertEqual(entries.count, 1)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry["sequence"] as? Int, 1)
        XCTAssertEqual(entry["soupName"] as? String, LocalWriteTests.accounts)
        XCTAssertEqual(entry["recordId"] as? String, id)
        XCTAssertEqual(entry["sobjectType"] as? String, "Account")
        XCTAssertEqual(entry["kind"] as? String, "CREATE")
        XCTAssertEqual(entry["status"] as? String, "PENDING")
        XCTAssertEqual(entry["attempts"] as? Int, 0)
        XCTAssertEqual(entry["changes"] as? NSDictionary, ["Name": "Acme", "Phone": "123"])
        XCTAssertNil(entry["lastError"])
        XCTAssertNil(entry["base"])
        XCTAssertNil(entry["parentRef"])
    }

    func test_givenLocalId_whenCreateLocal_thenGivenIdIsUsed() throws {
        let saved = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("Acme", extra: ["Id": "local_42"]))

        XCTAssertEqual(saved["Id"] as? String, "local_42")
        XCTAssertEqual(try queueEntries().first?["recordId"] as? String, "local_42")
    }

    func test_givenRecordWithInternalFields_whenCreateLocal_thenChangesExcludeThem() throws {
        let record = account("Acme", extra: [
            "Id": "local_1", "__sync_id__": 5, "__display__": "x", kSyncTargetLastError: "boom",
            kSyncTargetLocallyDeleted: true, kSyncTargetLocallyUpdated: true
        ])

        let saved = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: record)

        assertFlags(saved, created: true, updated: false, deleted: false)
        XCTAssertNil(saved[kSyncTargetLastError], "last error cleared")
        XCTAssertEqual(try queueEntries().first?["changes"] as? NSDictionary, ["Name": "Acme"])
    }

    func test_givenRecord_whenCreateLocal_thenCallerDictionaryIsNotModified() throws {
        let record = account("Acme")
        let copy = record as NSDictionary

        _ = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: record)

        XCTAssertEqual(record as NSDictionary, copy)
    }

    func test_givenFlagsStoredAsStringIndexes_whenCreateLocal_thenFlagQueriesMatch() throws {
        _ = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("Acme"))

        let created = try XCTUnwrap(QuerySpec.buildExactQuerySpec(soupName: LocalWriteTests.accounts, path: kSyncTargetLocallyCreated, matchKey: "1", orderPath: "Name", order: .ascending, pageSize: 10))
        let updated = try XCTUnwrap(QuerySpec.buildExactQuerySpec(soupName: LocalWriteTests.accounts, path: kSyncTargetLocallyUpdated, matchKey: "0", orderPath: "Name", order: .ascending, pageSize: 10))
        XCTAssertEqual(try store.query(using: created, startingFromPageIndex: 0).count, 1)
        XCTAssertEqual(try store.query(using: updated, startingFromPageIndex: 0).count, 1)
    }

    func test_givenTwoCreates_whenCreateLocalWithoutId_thenIdsAreDistinctAndSequencesIncrease() throws {
        let first = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("A"))
        let second = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("B"))

        XCTAssertNotEqual(first["Id"] as? String, second["Id"] as? String)
        XCTAssertEqual(try queueEntries().compactMap { $0["sequence"] as? Int }, [1, 2])
    }

    // MARK: createLocal errors

    func test_givenMissingSoup_whenCreateLocal_thenFailsWithSoupNotFound() throws {
        try assertFails(code: .soupNotFound) { try syncManager.createLocal(soupName: "nope", record: account("A")) }
    }

    func test_givenSoupWithoutIdIndex_whenWriteApis_thenFailWithIdIndexMissing() throws {
        try registerRecordSoup("noid", withIdIndex: false)

        try assertFails(code: .idIndexMissing) { try syncManager.createLocal(soupName: "noid", record: account("A")) }
        try assertFails(code: .idIndexMissing) { try syncManager.updateLocal(soupName: "noid", id: "x", changes: ["Name": "B"]) }
        try assertFails(code: .idIndexMissing) { try syncManager.deleteLocal(soupName: "noid", id: "x") }
    }

    func test_givenRecordWithoutObjectType_whenCreateLocal_thenFailsWithInvalidRecord() throws {
        try assertFails(code: .invalidRecord) { try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: ["Name": "A"]) }
    }

    func test_givenRecordWithSoupKey_whenCreateLocal_thenFailsWithInvalidRecord() throws {
        let first = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("A"))
        let entryId = try XCTUnwrap(first[SmartStore.soupEntryId])

        try assertFails(code: .invalidRecord) { try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("B", extra: [SmartStore.soupEntryId: entryId])) }
    }

    func test_givenRecordNotSerializableToJson_whenCreateLocal_thenFailsWithInvalidRecord() throws {
        try assertFails(code: .invalidRecord) { try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("A", extra: ["When": Date()])) }
    }

    func test_givenServerId_whenCreateLocal_thenFailsWithInvalidId() throws {
        try assertFails(code: .invalidId) { try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("A", extra: ["Id": "001000000000001AAA"])) }
        try assertFails(code: .invalidId) { try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("A", extra: ["Id": 12])) }
    }

    func test_givenExistingLocalId_whenCreateLocal_thenFailsAndExistingRecordIsNotOverwritten() throws {
        try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("Original", extra: ["Id": "local_1"]))

        try assertFails(code: .recordAlreadyExists) { try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("Other", extra: ["Id": "local_1"])) }

        XCTAssertEqual(try allRecords(LocalWriteTests.accounts).first?["Name"] as? String, "Original")
    }

    func test_givenSeveralRecordsWithSameId_whenCreateLocal_thenFailsWithMultipleRecordsFound() throws {
        _ = store.upsert(entries: [["Id": "local_9", "Name": "a"], ["Id": "local_9", "Name": "b"]], forSoupNamed: LocalWriteTests.accounts)

        try assertFails(code: .multipleRecordsFound) { try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("A", extra: ["Id": "local_9"])) }
    }

    // MARK: updateLocal

    func test_givenLocallyCreatedRecord_whenUpdateLocal_thenMergedFlagsKeepCreatedAndEntryHasOnlyChanges() throws {
        let created = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("Acme", extra: ["Phone": "123"]))
        let id = try XCTUnwrap(created["Id"] as? String)

        let saved = try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: id, changes: ["Phone": "456", "Fax": "789"])

        XCTAssertEqual(saved["Name"] as? String, "Acme")
        XCTAssertEqual(saved["Phone"] as? String, "456")
        XCTAssertEqual(saved["Fax"] as? String, "789")
        assertFlags(saved, created: true, updated: true, deleted: false)
        XCTAssertEqual(saved[SmartStore.soupEntryId] as? NSNumber, created[SmartStore.soupEntryId] as? NSNumber, "same entry updated")
        XCTAssertEqual(try allRecords(LocalWriteTests.accounts).count, 1)

        let entry = try XCTUnwrap(try queueEntries().last)
        XCTAssertEqual(entry["sequence"] as? Int, 2)
        XCTAssertEqual(entry["kind"] as? String, "UPDATE")
        XCTAssertEqual(entry["recordId"] as? String, id)
        XCTAssertEqual(entry["sobjectType"] as? String, "Account")
        XCTAssertEqual(entry["changes"] as? NSDictionary, ["Phone": "456", "Fax": "789"])
    }

    func test_givenServerRecord_whenUpdateLocal_thenUpdatedFlagSetAndCreatedNotSet() throws {
        _ = store.upsert(entries: [["Id": "001000000000001AAA", "Name": "Server", "attributes": ["type": "Account"]]], forSoupNamed: LocalWriteTests.accounts)

        let saved = try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: "001000000000001AAA", changes: ["Name": "Edited"])

        XCTAssertEqual(saved["Name"] as? String, "Edited")
        XCTAssertEqual(flag(saved, kSyncTargetLocal), true)
        XCTAssertEqual(flag(saved, kSyncTargetLocallyUpdated), true)
        XCTAssertNotEqual(flag(saved, kSyncTargetLocallyCreated), true)
        XCTAssertEqual(try queueEntries().first?["sobjectType"] as? String, "Account")
    }

    func test_givenNullChange_whenUpdateLocal_thenFieldIsClearedAndEntryHoldsNull() throws {
        let created = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("Acme", extra: ["Phone": "123"]))
        let id = try XCTUnwrap(created["Id"] as? String)

        let saved = try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: id, changes: ["Phone": NSNull()])

        XCTAssertTrue(saved["Phone"] is NSNull)
        XCTAssertTrue((try queueEntries().last?["changes"] as? [String: Any])?["Phone"] is NSNull)
    }

    func test_givenRecordWithoutObjectType_whenUpdateLocal_thenEntrySobjectTypeIsAbsent() throws {
        _ = store.upsert(entries: [["Id": "001", "Name": "Server"]], forSoupNamed: LocalWriteTests.accounts)

        _ = try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: "001", changes: ["Name": "Edited"])

        XCTAssertNil(try queueEntries().first?["sobjectType"])
    }

    // MARK: updateLocal errors

    func test_givenMissingRecord_whenUpdateLocalOrDeleteLocal_thenFailsWithRecordNotFound() throws {
        try assertFails(code: .recordNotFound) { try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: "local_1", changes: ["Name": "B"]) }
        try assertFails(code: .recordNotFound) { try syncManager.deleteLocal(soupName: LocalWriteTests.accounts, id: "local_1") }
    }

    func test_givenMissingSoup_whenUpdateLocalOrDeleteLocal_thenFailsWithSoupNotFound() throws {
        try assertFails(code: .soupNotFound) { try syncManager.updateLocal(soupName: "nope", id: "x", changes: ["Name": "B"]) }
        try assertFails(code: .soupNotFound) { try syncManager.deleteLocal(soupName: "nope", id: "x") }
    }

    func test_givenEmptyChanges_whenUpdateLocal_thenFailsWithInvalidChanges() throws {
        let created = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("Acme"))
        let id = try XCTUnwrap(created["Id"] as? String)

        try assertFails(code: .invalidChanges) { try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: id, changes: [:]) }
    }

    func test_givenInternalFieldInChanges_whenUpdateLocal_thenFailsWithInvalidChanges() throws {
        let created = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("Acme"))
        let id = try XCTUnwrap(created["Id"] as? String)

        for field in ["Id", "attributes", "_soupEntryId", "_soupLastModifiedDate", "__local__", "__locally_created__", "__locally_updated__", "__locally_deleted__", "__last_error__", "__sync_id__", "__display__"] {
            try assertFails(code: .invalidChanges) { try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: id, changes: ["Name": "B", field: "x"]) }
        }
    }

    func test_givenChangesNotSerializableToJson_whenUpdateLocal_thenFailsWithInvalidChanges() throws {
        let created = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("Acme"))
        let id = try XCTUnwrap(created["Id"] as? String)

        try assertFails(code: .invalidChanges) { try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: id, changes: ["When": Date()]) }
    }

    func test_givenDeletedRecord_whenUpdateLocalOrDeleteLocal_thenFailsWithRecordAlreadyDeleted() throws {
        let created = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("Acme"))
        let id = try XCTUnwrap(created["Id"] as? String)
        try syncManager.deleteLocal(soupName: LocalWriteTests.accounts, id: id)

        try assertFails(code: .recordAlreadyDeleted) { try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: id, changes: ["Name": "B"]) }
        try assertFails(code: .recordAlreadyDeleted) { try syncManager.deleteLocal(soupName: LocalWriteTests.accounts, id: id) }
    }

    func test_givenRecordDeletedFlagStoredAsString_whenUpdateLocalOrDeleteLocal_thenFailsWithRecordAlreadyDeleted() throws {
        for (index, value) in ["1", "true", "TRUE", "yes"].enumerated() {
            let id = "001_string_\(index)"
            _ = store.upsert(entries: [["Id": id, "Name": "Server", "attributes": ["type": "Account"], kSyncTargetLocallyDeleted: value]], forSoupNamed: LocalWriteTests.accounts)

            try assertFails(code: .recordAlreadyDeleted) { try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: id, changes: ["Name": "B"]) }
            try assertFails(code: .recordAlreadyDeleted) { try syncManager.deleteLocal(soupName: LocalWriteTests.accounts, id: id) }
        }
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenRecordDeletedFlagStoredAsStringZero_whenUpdateLocal_thenSucceeds() throws {
        _ = store.upsert(entries: [["Id": "001", "Name": "Server", "attributes": ["type": "Account"], kSyncTargetLocallyDeleted: "0"]], forSoupNamed: LocalWriteTests.accounts)

        let saved = try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: "001", changes: ["Name": "B"])

        XCTAssertEqual(saved["Name"] as? String, "B")
    }

    func test_givenSeveralRecordsWithSameId_whenUpdateLocal_thenFailsWithMultipleRecordsFound() throws {
        _ = store.upsert(entries: [["Id": "dup", "Name": "a"], ["Id": "dup", "Name": "b"]], forSoupNamed: LocalWriteTests.accounts)

        try assertFails(code: .multipleRecordsFound) { try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: "dup", changes: ["Name": "c"]) }
    }

    // MARK: deleteLocal

    func test_givenLocallyUpdatedRecord_whenDeleteLocal_thenRecordKeptFlaggedDeletedAndEntryHasNoChanges() throws {
        let created = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("Acme"))
        let id = try XCTUnwrap(created["Id"] as? String)
        try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: id, changes: ["Name": "B"])

        let saved = try syncManager.deleteLocal(soupName: LocalWriteTests.accounts, id: id)

        assertFlags(saved, created: true, updated: true, deleted: true)
        XCTAssertEqual(saved["Name"] as? String, "B")
        XCTAssertEqual(try allRecords(LocalWriteTests.accounts).count, 1)
        let entry = try XCTUnwrap(try queueEntries().last)
        XCTAssertEqual(entry["sequence"] as? Int, 3)
        XCTAssertEqual(entry["kind"] as? String, "DELETE")
        XCTAssertEqual(entry["recordId"] as? String, id)
        XCTAssertEqual(entry["sobjectType"] as? String, "Account")
        XCTAssertNil(entry["changes"])
        XCTAssertEqual(entry["status"] as? String, "PENDING")
    }

    func test_givenServerRecord_whenDeleteLocal_thenFlaggedDeletedOnly() throws {
        _ = store.upsert(entries: [["Id": "001", "Name": "Server", "attributes": ["type": "Account"]]], forSoupNamed: LocalWriteTests.accounts)

        let saved = try syncManager.deleteLocal(soupName: LocalWriteTests.accounts, id: "001")

        XCTAssertEqual(flag(saved, kSyncTargetLocal), true)
        XCTAssertEqual(flag(saved, kSyncTargetLocallyDeleted), true)
        XCTAssertNotEqual(flag(saved, kSyncTargetLocallyCreated), true)
        XCTAssertNotEqual(flag(saved, kSyncTargetLocallyUpdated), true)
    }

    // MARK: ordering

    func test_givenWritesToAThenBThenA_whenQueriedBySequence_thenThreeEntriesInWriteOrder() throws {
        let a = try XCTUnwrap(try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("A"))["Id"] as? String)
        let b = try XCTUnwrap(try syncManager.createLocal(soupName: LocalWriteTests.contacts, record: ["attributes": ["type": "Contact"], "Name": "B"])["Id"] as? String)
        try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: a, changes: ["Name": "A2"])

        let entries = try queueEntries()
        XCTAssertEqual(entries.compactMap { $0["sequence"] as? Int }, [1, 2, 3])
        XCTAssertEqual(entries.compactMap { $0["recordId"] as? String }, [a, b, a])
        XCTAssertEqual(entries.compactMap { $0["soupName"] as? String }, [LocalWriteTests.accounts, LocalWriteTests.contacts, LocalWriteTests.accounts])
        XCTAssertEqual(entries.compactMap { $0["kind"] as? String }, ["CREATE", "CREATE", "UPDATE"])
    }

    func test_givenMoreThanTenWrites_whenQueriedBySequence_thenSequencesAreNumericallyOrdered() throws {
        let id = try XCTUnwrap(try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("A"))["Id"] as? String)
        for i in 2...12 {
            try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: id, changes: ["Name": "A\(i)"])
        }

        let querySpec = try XCTUnwrap(QuerySpec.buildAllQuerySpec(soupName: SyncQueue.soupName, orderPath: SyncQueue.sequenceField, order: .ascending, pageSize: 100))
        let entries = try XCTUnwrap(store.query(using: querySpec, startingFromPageIndex: 0) as? [[String: Any]])
        XCTAssertEqual(entries.compactMap { $0["sequence"] as? Int }, Array(1...12))
        XCTAssertEqual(entries.last?["changes"] as? NSDictionary, ["Name": "A12"])
    }

    // MARK: queue soup lifecycle

    func test_givenQueueSoupDroppedAfterManagerCreated_whenCreateLocal_thenQueueSoupIsRegisteredAgain() throws {
        store.removeSoup(SyncQueue.soupName)

        _ = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("A"))

        XCTAssertEqual(try queueEntries().count, 1)
    }

    // MARK: atomicity

    func test_givenQueueInsertFailing_whenCreateLocal_thenNoRecordIsSaved() throws {
        try makeQueueInsertsFail()

        XCTAssertThrowsError(try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("A")))

        XCTAssertEqual(try allRecords(LocalWriteTests.accounts).count, 0)
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenQueueInsertFailing_whenUpdateLocal_thenRecordIsUnchanged() throws {
        let created = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("Acme"))
        let id = try XCTUnwrap(created["Id"] as? String)
        let before = try snapshot()
        try makeQueueInsertsFail()

        XCTAssertThrowsError(try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: id, changes: ["Name": "B"]))

        let after = try snapshot()
        XCTAssertEqual(before.records, after.records)
        XCTAssertEqual(before.queue, after.queue)
        XCTAssertEqual(flag(try XCTUnwrap(allRecords(LocalWriteTests.accounts).first), kSyncTargetLocallyUpdated), false)
    }

    func test_givenQueueInsertFailing_whenDeleteLocal_thenRecordIsNotFlaggedDeleted() throws {
        let created = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("Acme"))
        let id = try XCTUnwrap(created["Id"] as? String)
        try makeQueueInsertsFail()

        XCTAssertThrowsError(try syncManager.deleteLocal(soupName: LocalWriteTests.accounts, id: id))

        XCTAssertEqual(flag(try XCTUnwrap(allRecords(LocalWriteTests.accounts).first), kSyncTargetLocallyDeleted), false)
        XCTAssertEqual(try queueEntries().count, 1)
    }

    func test_givenFailedWrite_whenNextWrite_thenSequenceNumberIsNotConsumed() throws {
        try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("A"))
        try assertFails(code: .recordNotFound) { try syncManager.updateLocal(soupName: LocalWriteTests.accounts, id: "missing", changes: ["Name": "B"]) }

        try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("C"))

        XCTAssertEqual(try queueEntries().compactMap { $0["sequence"] as? Int }, [1, 2])
    }

    // MARK: Objective-C selectors

    func test_givenObjectiveCSelectors_whenResolved_thenWriteApisAreExposed() {
        XCTAssertTrue(syncManager.responds(to: NSSelectorFromString("createLocalInSoup:record:error:")))
        XCTAssertTrue(syncManager.responds(to: NSSelectorFromString("updateLocalInSoup:id:changes:error:")))
        XCTAssertTrue(syncManager.responds(to: NSSelectorFromString("deleteLocalInSoup:id:error:")))
    }

    // MARK: generated local ids are unique store-wide

    /// Makes the generator answer `ids` in order (then fresh ids).
    private func generate(_ ids: [String]) {
        var remaining = ids
        LocalIdGenerator.generate = { remaining.isEmpty ? SyncTarget.createLocalId() : remaining.removeFirst() }
    }

    func test_givenGeneratedIdUsedByRecordOfAnotherSoup_whenCreateLocal_thenAnotherIdGenerated() throws {
        _ = try XCTUnwrap(store.upsert(entries: [["Id": "local_taken", "attributes": ["type": "Contact"], "Name": "c"]], forSoupNamed: LocalWriteTests.contacts))
        generate(["local_taken", "local_free"])

        let saved = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("acme"))

        XCTAssertEqual(saved["Id"] as? String, "local_free")
        XCTAssertEqual(try queueEntries().map { $0["recordId"] as? String }, ["local_free"])
    }

    func test_givenGeneratedIdUsedByQueueEntryOfAnotherSoup_whenCreateLocal_thenAnotherIdGenerated() throws {
        let foreign = SyncQueue.buildEntry(sequence: 1, soupName: LocalWriteTests.contacts, recordId: "local_taken", sobjectType: "Contact", kind: .update, changes: ["Name": "x"])
        _ = try XCTUnwrap(store.upsert(entries: [foreign], forSoupNamed: SyncQueue.soupName))
        generate(["local_taken", "local_taken", "local_free"])

        let saved = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("acme"))

        XCTAssertEqual(saved["Id"] as? String, "local_free")
    }

    func test_givenGeneratedIdUsedInSameSoup_whenCreateLocal_thenAnotherIdGenerated() throws {
        try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("first", extra: ["Id": "local_taken"]))
        generate(["local_taken", "local_free"])

        let saved = try syncManager.createLocal(soupName: LocalWriteTests.accounts, record: account("second"))

        XCTAssertEqual(saved["Id"] as? String, "local_free")
    }
}
