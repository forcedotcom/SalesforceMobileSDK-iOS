//
//  SyncQueueTests.swift
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

/// Network-free tests of the queue soup (registration, sequence allocation, entries) on a global store.
class SyncQueueTests: XCTestCase {
    private static let storeName = "SyncQueueTests"
    private var store: SmartStore!

    override func setUpWithError() throws {
        store = try XCTUnwrap(SmartStore.sharedGlobal(withName: SyncQueueTests.storeName))
    }

    override func tearDown() {
        SyncManager.removeSharedInstance(store: store)
        SmartStore.removeSharedGlobal(withName: SyncQueueTests.storeName)
        super.tearDown()
    }

    // MARK: helpers

    private func indexPaths(_ soupName: String) -> [String] {
        return store.indices(forSoupNamed: soupName).map { $0.path }
    }

    private func allocateSequenceAndInsert(soupName: String, recordId: String) throws -> Int {
        var sequence = 0
        try store.performTransaction { transaction in
            do {
                sequence = try SyncQueue.nextSequence(in: transaction)
                let entry = SyncQueue.buildEntry(sequence: sequence, soupName: soupName, recordId: recordId, sobjectType: "Account", kind: .create, changes: ["Name": "n"])
                _ = try transaction.upsert(entries: [entry], forSoupNamed: SyncQueue.soupName, withExternalIdPath: SmartStore.soupEntryId)
            } catch {
                transaction.fail(with: error as NSError)
            }
        }
        return sequence
    }

    private func queueEntries() throws -> [[String: Any]] {
        let querySpec = try XCTUnwrap(QuerySpec.buildAllQuerySpec(soupName: SyncQueue.soupName, orderPath: SyncQueue.sequenceField, order: .ascending, pageSize: 1000))
        return try XCTUnwrap(store.query(using: querySpec, startingFromPageIndex: 0) as? [[String: Any]])
    }

    // MARK: registration

    func test_givenNewStore_whenSyncManagerCreated_thenQueueSoupIsRegisteredWithAllIndexes() throws {
        XCTAssertFalse(store.soupExists(forName: SyncQueue.soupName))

        _ = try XCTUnwrap(SyncManager.sharedInstance(store: store))

        XCTAssertTrue(store.soupExists(forName: SyncQueue.soupName))
        XCTAssertEqual(indexPaths(SyncQueue.soupName), ["sequence", "soupName", "recordId", "sobjectType", "kind", "changes", "base", "status", "lastError", "attempts", "parentRef"])
        XCTAssertTrue(store.soupExists(forName: kSFSyncStateSyncsSoupName), "syncs soup must still be registered")
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenQueueSoupIndexTypes_whenRegistered_thenSequenceAndAttemptsAreIntegerAndJsonFieldsAreJson1() {
        SyncQueue.setupQueueSoupIfNeeded(store)

        let types = Dictionary(uniqueKeysWithValues: store.indices(forSoupNamed: SyncQueue.soupName).map { ($0.path, $0.indexType) })
        XCTAssertEqual(types["sequence"], kSoupIndexTypeInteger)
        XCTAssertEqual(types["attempts"], kSoupIndexTypeInteger)
        for path in ["soupName", "recordId", "sobjectType", "kind", "status", "parentRef"] {
            XCTAssertEqual(types[path], kSoupIndexTypeString, path)
        }
        for path in ["changes", "base", "lastError"] {
            XCTAssertEqual(types[path], kSoupIndexTypeJSON1, path)
        }
    }

    func test_givenQueueSoupWithEntries_whenSetupCalledAgain_thenSoupAndEntriesAreUntouched() throws {
        SyncQueue.setupQueueSoupIfNeeded(store)
        _ = try allocateSequenceAndInsert(soupName: "accounts", recordId: "local_1")

        SyncQueue.setupQueueSoupIfNeeded(store)

        XCTAssertEqual(indexPaths(SyncQueue.soupName).count, 11)
        XCTAssertEqual(try queueEntries().count, 1)
    }

    func test_givenQueueSoupWithWrongIndexCount_whenSetup_thenSoupIsAlteredAndDataKept() throws {
        let oldSpecs = try XCTUnwrap(SoupIndex(path: "sequence", indexType: kSoupIndexTypeString, columnName: nil))
        try store.registerSoup(withName: SyncQueue.soupName, withIndices: [oldSpecs])
        _ = store.upsert(entries: [["sequence": 7, "soupName": "accounts", "recordId": "local_1"]], forSoupNamed: SyncQueue.soupName)

        SyncQueue.setupQueueSoupIfNeeded(store)

        XCTAssertEqual(indexPaths(SyncQueue.soupName).count, 11)
        XCTAssertEqual(store.indices(forSoupNamed: SyncQueue.soupName).first?.indexType, kSoupIndexTypeInteger)
        let entries = try queueEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?["recordId"] as? String, "local_1")
    }

    func test_givenSyncsSoup_whenQueueSoupSetup_thenSyncsSoupIsUntouched() {
        SyncState.setupSyncsSoupIfNeeded(store)
        let before = indexPaths(kSFSyncStateSyncsSoupName)

        SyncQueue.setupQueueSoupIfNeeded(store)

        XCTAssertEqual(indexPaths(kSFSyncStateSyncsSoupName), before)
    }

    // MARK: sequence

    func test_givenEmptyQueue_whenNextSequence_thenOne() throws {
        SyncQueue.setupQueueSoupIfNeeded(store)

        XCTAssertEqual(try allocateSequenceAndInsert(soupName: "accounts", recordId: "local_1"), 1)
    }

    func test_givenEntriesForSeveralSoups_whenNextSequence_thenMonotonicAcrossSoups() throws {
        SyncQueue.setupQueueSoupIfNeeded(store)

        let sequences = try [
            allocateSequenceAndInsert(soupName: "accounts", recordId: "local_1"),
            allocateSequenceAndInsert(soupName: "contacts", recordId: "local_2"),
            allocateSequenceAndInsert(soupName: "accounts", recordId: "local_3")
        ]

        XCTAssertEqual(sequences, [1, 2, 3])
        XCTAssertEqual(try queueEntries().compactMap { $0["soupName"] as? String }, ["accounts", "contacts", "accounts"])
    }

    func test_givenRolledBackTransaction_whenNextSequence_thenNumberWasNotConsumed() throws {
        SyncQueue.setupQueueSoupIfNeeded(store)
        XCTAssertEqual(try allocateSequenceAndInsert(soupName: "accounts", recordId: "local_1"), 1)

        var rolledBackSequence = 0
        // A requested rollback (no error) is reported by Swift as a generic error
        XCTAssertThrowsError(try store.performTransaction { transaction in
            do {
                rolledBackSequence = try SyncQueue.nextSequence(in: transaction)
                let entry = SyncQueue.buildEntry(sequence: rolledBackSequence, soupName: "accounts", recordId: "local_x", sobjectType: nil, kind: .delete, changes: nil)
                _ = try transaction.upsert(entries: [entry], forSoupNamed: SyncQueue.soupName, withExternalIdPath: SmartStore.soupEntryId)
            } catch {
                transaction.fail(with: error as NSError)
            }
            transaction.rollback()
        })

        XCTAssertEqual(rolledBackSequence, 2)
        XCTAssertEqual(try allocateSequenceAndInsert(soupName: "accounts", recordId: "local_2"), 2)
    }

    func test_givenMoreThanTenEntries_whenQueriedBySequence_thenOrderIsNumeric() throws {
        SyncQueue.setupQueueSoupIfNeeded(store)

        for i in 1...12 {
            XCTAssertEqual(try allocateSequenceAndInsert(soupName: "accounts", recordId: "local_\(i)"), i)
        }

        XCTAssertEqual(try queueEntries().compactMap { $0["sequence"] as? Int }, Array(1...12))
    }

    // MARK: entry

    func test_givenCreateEntry_whenBuilt_thenFieldsAreSetAndReservedFieldsAbsent() {
        let entry = SyncQueue.buildEntry(sequence: 4, soupName: "accounts", recordId: "local_1", sobjectType: "Account", kind: .create, changes: ["Name": "n"])

        XCTAssertEqual(entry["sequence"] as? Int, 4)
        XCTAssertEqual(entry["soupName"] as? String, "accounts")
        XCTAssertEqual(entry["recordId"] as? String, "local_1")
        XCTAssertEqual(entry["sobjectType"] as? String, "Account")
        XCTAssertEqual(entry["kind"] as? String, "CREATE")
        XCTAssertEqual(entry["changes"] as? [String: String], ["Name": "n"])
        XCTAssertEqual(entry["status"] as? String, "PENDING")
        XCTAssertEqual(entry["attempts"] as? Int, 0)
        XCTAssertNil(entry["lastError"])
        XCTAssertNil(entry["base"])
        XCTAssertNil(entry["parentRef"])
    }

    func test_givenDeleteEntryWithoutChangesOrType_whenBuilt_thenChangesAndTypeAbsent() {
        let entry = SyncQueue.buildEntry(sequence: 1, soupName: "accounts", recordId: "001", sobjectType: nil, kind: .delete, changes: nil)

        XCTAssertEqual(entry["kind"] as? String, "DELETE")
        XCTAssertNil(entry["changes"])
        XCTAssertNil(entry["sobjectType"])
    }
}
