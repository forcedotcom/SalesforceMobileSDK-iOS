//
//  QueueSyncUpTests.swift
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

import XCTest
@testable import MobileSync
import SalesforceSDKCore
import SmartStore

/// Replaces the REST calls of `QueueSyncUpTarget`: records them and answers through `responder`.
/// The four overridden selectors are the private request helpers of `SFSyncUpTarget`, so the field map, the
/// external id upsert decision and the id exclusions of the real request code are exercised.
final class RecordingQueueTarget: QueueSyncUpTarget {
    struct Call {
        let method: String   // POST, UPSERT, PATCH, DELETE
        let objectType: String
        let objectId: String?
        let externalId: String?
        let fields: NSDictionary
        var label: String { return "\(method) \(objectType)" + (objectId.map { "/\($0)" } ?? "") }
    }
    typealias Response = Result<[AnyHashable: Any]?, NSError>

    private static let lock = NSLock()
    private static var recorded: [Call] = []
    private static var createdCount = 0
    /// Decides the answer to a call; defaults to success (with a new server id for creates).
    static var responder: (Call) -> Response = { _ in .success(nil) }
    /// Called before a call is answered (on the sync thread).
    static var onCall: (Call) -> Void = { _ in }
    /// Returns a semaphore to hold the answer to a call open: the call returns at once and is answered when it is signaled.
    static var holdAnswer: (Call) -> DispatchSemaphore? = { _ in nil }
    /// True: an upsert answers like a 201 (with the new id); false: like a 204 (no body).
    static var upsertCreates = true
    /// Answer of the id lookup that follows a 204 upsert (the external id value is in `externalId`).
    static var lookupResponder: (Call) -> Response = { _ in .success(["id": "existing_1"]) }

    static var calls: [Call] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        recorded = []
        createdCount = 0
        responder = { _ in .success(nil) }
        onCall = { _ in }
        holdAnswer = { _ in nil }
        upsertCreates = true
        lookupResponder = { _ in .success(["id": "existing_1"]) }
    }

    private func handle(_ call: Call, _ complete: @escaping ([AnyHashable: Any]?) -> Void, _ fail: @escaping (NSError?) -> Void) {
        Self.lock.lock()
        Self.recorded.append(call)
        let responder = Self.responder
        let onCall = Self.onCall
        let hold = Self.holdAnswer(call)
        Self.lock.unlock()
        onCall(call)
        let answer: () -> Void = {
            switch responder(call) {
            case .failure(let error):
                fail(error)
            case .success(let response):
                if let response = response {
                    complete(response)
                } else if call.method == "POST" || (call.method == "UPSERT" && Self.upsertCreates) {
                    Self.lock.lock()
                    Self.createdCount += 1
                    let n = Self.createdCount
                    Self.lock.unlock()
                    complete(["id": "srv_\(n)", "success": true])
                } else {
                    complete([:])
                }
            }
        }
        if let hold = hold {
            DispatchQueue.global().async { hold.wait(); answer() }
        } else {
            answer()
        }
    }

    override func lookupIdOnServer(_ objectType: String, externalIdField: String, externalId: String, onComplete: @escaping ([AnyHashable: Any]?) -> Void, onFail: @escaping (NSError) -> Void) {
        let call = Call(method: "LOOKUP", objectType: objectType, objectId: nil, externalId: externalId, fields: [externalIdField: externalId])
        Self.lock.lock()
        Self.recorded.append(call)
        let responder = Self.lookupResponder
        Self.lock.unlock()
        switch responder(call) {
        case .failure(let error): onFail(error)
        case .success(let response): onComplete(response)
        }
    }

    @objc(createOnServer:fields:completionBlock:failBlock:)
    func recordCreate(_ objectType: String, fields: NSDictionary, completionBlock: @escaping ([AnyHashable: Any]?) -> Void, failBlock: @escaping (NSError?) -> Void) {
        handle(Call(method: "POST", objectType: objectType, objectId: nil, externalId: nil, fields: fields), completionBlock, failBlock)
    }

    override func upsertOnServer(_ objectType: String, fields: NSDictionary, externalId: String, completionBlock: @escaping ([AnyHashable: Any]?) -> Void, failBlock: @escaping (NSError?) -> Void) {
        handle(Call(method: "UPSERT", objectType: objectType, objectId: nil, externalId: externalId, fields: fields), completionBlock, failBlock)
    }

    @objc(updateOnServer:objectId:fields:completionBlock:failBlock:)
    func recordUpdate(_ objectType: String, objectId: String, fields: NSDictionary, completionBlock: @escaping ([AnyHashable: Any]?) -> Void, failBlock: @escaping (NSError?) -> Void) {
        handle(Call(method: "PATCH", objectType: objectType, objectId: objectId, externalId: nil, fields: fields), completionBlock, failBlock)
    }

    @objc(deleteOnServer:objectId:completionBlock:failBlock:)
    func recordDelete(_ objectType: String, objectId: String, completionBlock: @escaping ([AnyHashable: Any]?) -> Void, failBlock: @escaping (NSError?) -> Void) {
        handle(Call(method: "DELETE", objectType: objectType, objectId: objectId, externalId: nil, fields: [:]), completionBlock, failBlock)
    }
}

/// Network-free tests of the queue replay (`QueueSyncUpTarget`, `QueueSyncUpTask`) and of the temp-id remapping.
class QueueSyncUpTests: XCTestCase {
    private static let storeName = "QueueSyncUpTests"
    private static let accounts = "accounts"
    private static let contacts = "contacts"

    private var store: SmartStore!
    private var syncManager: SyncManager!

    override func setUpWithError() throws {
        RecordingQueueTarget.reset()
        store = try XCTUnwrap(SmartStore.sharedGlobal(withName: QueueSyncUpTests.storeName))
        try registerRecordSoup(QueueSyncUpTests.accounts)
        try registerRecordSoup(QueueSyncUpTests.contacts)
        syncManager = try XCTUnwrap(SyncManager.sharedInstance(store: store))
    }

    override func tearDown() {
        SyncManager.removeSharedInstance(store: store)
        SmartStore.removeSharedGlobal(withName: QueueSyncUpTests.storeName)
        RecordingQueueTarget.reset()
        super.tearDown()
    }

    // MARK: helpers

    private func registerRecordSoup(_ soupName: String) throws {
        let paths = ["Id", "Name", kSyncTargetLocal, kSyncTargetLocallyCreated, kSyncTargetLocallyUpdated, kSyncTargetLocallyDeleted]
        let indices = paths.compactMap { SoupIndex(path: $0, indexType: kSoupIndexTypeString, columnName: nil) }
        try store.registerSoup(withName: soupName, withIndices: indices)
    }

    private func allRecords(_ soupName: String) throws -> [[String: Any]] {
        let querySpec = try XCTUnwrap(QuerySpec.buildAllQuerySpec(soupName: soupName, orderPath: SmartStore.soupEntryId, order: .ascending, pageSize: 1000))
        return try XCTUnwrap(store.query(using: querySpec, startingFromPageIndex: 0) as? [[String: Any]])
    }

    private func record(_ soupName: String, _ id: String) throws -> [String: Any]? {
        return try allRecords(soupName).first { $0["Id"] as? String == id }
    }

    private func queueEntries() throws -> [[String: Any]] {
        return try allRecords(SyncQueue.soupName).sorted { ($0["sequence"] as? Int ?? 0) < ($1["sequence"] as? Int ?? 0) }
    }

    private func flag(_ record: [String: Any]?, _ name: String) -> Bool? {
        return (record?[name] as? NSNumber)?.boolValue
    }

    private func assertClean(_ record: [String: Any]?, file: StaticString = #filePath, line: UInt = #line) {
        for name in [kSyncTargetLocal, kSyncTargetLocallyCreated, kSyncTargetLocallyUpdated, kSyncTargetLocallyDeleted] {
            XCTAssertEqual(flag(record, name), false, name, file: file, line: line)
        }
        XCTAssertNil(record?[kSyncTargetLastError], file: file, line: line)
    }

    /// A record as sync down leaves it: server id, no dirty flags.
    @discardableResult
    private func seedServerRecord(_ soupName: String, id: String, type: String, fields: [String: Any] = [:]) throws -> [String: Any] {
        var record = fields
        record["Id"] = id
        record["attributes"] = ["type": type]
        for name in [kSyncTargetLocal, kSyncTargetLocallyCreated, kSyncTargetLocallyUpdated, kSyncTargetLocallyDeleted] {
            record[name] = false
        }
        return try XCTUnwrap(store.upsert(entries: [record], forSoupNamed: soupName).first as? [String: Any])
    }

    private func newAccount(_ name: String, extra: [String: Any] = [:]) -> [String: Any] {
        var record: [String: Any] = ["attributes": ["type": "Account"], "Name": name]
        record.merge(extra) { _, new in new }
        return record
    }

    private func newContact(_ name: String, extra: [String: Any] = [:]) -> [String: Any] {
        var record: [String: Any] = ["attributes": ["type": "Contact"], "LastName": name]
        record.merge(extra) { _, new in new }
        return record
    }

    private func createAccount(_ name: String, extra: [String: Any] = [:]) throws -> String {
        let saved = try syncManager.createLocal(soupName: QueueSyncUpTests.accounts, record: newAccount(name, extra: extra))
        return try XCTUnwrap(saved["Id"] as? String)
    }

    private func restError(_ code: Int, _ body: [String: Any] = ["error": "rejected"]) -> NSError {
        return NSError(domain: SFRestErrorDomain, code: code, userInfo: body)
    }

    private func labels() -> [String] {
        return RecordingQueueTarget.calls.map { $0.label }
    }

    /// Runs a queue sync and waits for its final state.
    @discardableResult
    private func runQueueSync(target: QueueSyncUpTarget? = nil, name: String? = nil, file: StaticString = #filePath, line: UInt = #line) throws -> SyncState {
        let expectation = self.expectation(description: "queue sync finished")
        let options = SyncOptions.newSyncOptions(forSyncUp: [], mergeMode: .overwrite)
        var finished = false
        var started: SyncState?
        started = try syncManager.syncUp(target: target ?? RecordingQueueTarget(), options: options, soupName: SyncQueue.soupName, syncName: name) { sync in
            if (sync.status == .done || sync.status == .failed || sync.status == .stopped) && !finished {
                finished = true
                expectation.fulfill()
            }
        }
        XCTAssertNotNil(started, file: file, line: line)
        wait(for: [expectation], timeout: 30)
        return try finalState(of: started)
    }

    private func reSync(id: Int? = nil, name: String? = nil) throws -> SyncState {
        let expectation = self.expectation(description: "resync finished")
        var finished = false
        let onUpdate: SyncUpdateBlock = { sync in
            if (sync.status == .done || sync.status == .failed || sync.status == .stopped) && !finished {
                finished = true
                expectation.fulfill()
            }
        }
        let started: SyncState?
        if let name = name {
            started = try syncManager.reSync(named: name, onUpdate: onUpdate)
        } else {
            started = try syncManager.reSync(id: NSNumber(value: try XCTUnwrap(id)), onUpdate: onUpdate)
        }
        wait(for: [expectation], timeout: 30)
        return try finalState(of: started)
    }

    private func finalState(of sync: SyncState?) throws -> SyncState {
        let sync = try XCTUnwrap(sync)
        return try XCTUnwrap(syncManager.syncStatus(forId: NSNumber(value: sync.syncId)))
    }

    // MARK: target

    func test_givenQueueTarget_whenSerializedAndRebuilt_thenSameClassAndExternalIdKept() throws {
        let target = QueueSyncUpTarget()
        target.externalIdFieldName = "ExtId__c"

        let dict = target.asDict()
        let rebuilt = try XCTUnwrap(SyncUpTarget.build(dict: dict as? [AnyHashable: Any]))

        XCTAssertEqual(dict[kSFSyncTargetiOSImplKey] as? String, "SFQueueSyncUpTarget")
        XCTAssertTrue(rebuilt is QueueSyncUpTarget)
        XCTAssertEqual(rebuilt.externalIdFieldName, "ExtId__c")
        XCTAssertTrue(rebuilt.createFieldlist.isEmpty)
        XCTAssertTrue(rebuilt.updateFieldlist.isEmpty)
        XCTAssertTrue(QueueSyncUpTarget.build(dict: nil) is QueueSyncUpTarget)
    }

    func test_givenQueueTargetAndFlaggedRecord_whenGetIdsOfRecordsToSyncUp_thenEmpty() throws {
        var flagged = newAccount("flagged")
        flagged["Id"] = "local_1"
        flagged[kSyncTargetLocal] = true
        flagged[kSyncTargetLocallyCreated] = true
        _ = store.upsert(entries: [flagged], forSoupNamed: QueueSyncUpTests.accounts)

        XCTAssertTrue(QueueSyncUpTarget().getIdsOfRecords(toSyncUp: syncManager, soupName: QueueSyncUpTests.accounts).isEmpty)
    }

    func test_givenTransportAndRecordErrors_whenClassified_thenOnlyTargetAndClientHttpErrorsAreRecordLevel() {
        // transport: no response, authentication, cancelled, unparseable, 408, 429, 5xx, request limit
        XCTAssertTrue(QueueSyncUpTarget.isTransportError(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost)))
        XCTAssertTrue(QueueSyncUpTarget.isTransportError(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)))
        XCTAssertTrue(QueueSyncUpTarget.isTransportError(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        XCTAssertTrue(QueueSyncUpTarget.isTransportError(NSError(domain: "com.salesforce.OAuth.ErrorDomain", code: 1)))
        XCTAssertTrue(QueueSyncUpTarget.isTransportError(NSError(domain: NSCocoaErrorDomain, code: 3840)))
        XCTAssertTrue(QueueSyncUpTarget.isTransportError(restError(408)))
        XCTAssertTrue(QueueSyncUpTarget.isTransportError(restError(429)))
        XCTAssertTrue(QueueSyncUpTarget.isTransportError(restError(500)))
        XCTAssertTrue(QueueSyncUpTarget.isTransportError(restError(503)))
        XCTAssertTrue(QueueSyncUpTarget.isTransportError(restError(403, ["error": [["errorCode": "REQUEST_LIMIT_EXCEEDED", "message": "limit"]]])))
        // record level: HTTP errors below 500, and the errors of the target itself
        XCTAssertFalse(QueueSyncUpTarget.isTransportError(restError(300)))
        XCTAssertFalse(QueueSyncUpTarget.isTransportError(restError(400)))
        XCTAssertFalse(QueueSyncUpTarget.isTransportError(restError(403, ["error": "INSUFFICIENT_ACCESS"])))
        XCTAssertFalse(QueueSyncUpTarget.isTransportError(restError(404)))
        XCTAssertFalse(QueueSyncUpTarget.isTransportError(NSError(domain: kSFMobileSyncErrorDomain, code: 907)))
    }

    // MARK: remapping (unit)

    func test_givenIdMap_whenRemapped_thenOnlyExactTopLevelValuesAndIdsAreReplaced() throws {
        let raw: [String: Any] = [
            "recordId": "local_1",
            "parentRef": "local_1",
            "changes": [
                "AccountId": "local_1",
                "Name": "local_1 and more",
                "Other": "local_2",
                "Count": 3,
                "Nested": ["AccountId": "local_1"]
            ]
        ]

        let mapped = try XCTUnwrap(QueueSyncUpTarget.remapped(raw, using: ["local_1": "srv_1"]))

        XCTAssertEqual(mapped["recordId"] as? String, "srv_1")
        XCTAssertEqual(mapped["parentRef"] as? String, "srv_1")
        let changes = try XCTUnwrap(mapped["changes"] as? [String: Any])
        XCTAssertEqual(changes["AccountId"] as? String, "srv_1")
        XCTAssertEqual(changes["Name"] as? String, "local_1 and more")
        XCTAssertEqual(changes["Other"] as? String, "local_2", "unknown local ids are left as they are")
        XCTAssertEqual(changes["Count"] as? Int, 3)
        XCTAssertEqual((changes["Nested"] as? [String: Any])?["AccountId"] as? String, "local_1", "nested values are not touched")
        XCTAssertNil(QueueSyncUpTarget.remapped(raw, using: ["local_9": "srv_9"]))
        XCTAssertNil(QueueSyncUpTarget.remapped(raw, using: [:]))
    }

    // MARK: replay order and requests

    func test_givenEditsOnTwoSoups_whenSynced_thenReplayedInSequenceOrderAsABA() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try seedServerRecord(QueueSyncUpTests.contacts, id: "con1", type: "Contact", fields: ["LastName": "c"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "a1"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.contacts, id: "con1", changes: ["LastName": "c1"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "a2"])

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(sync.totalSize, 3)
        XCTAssertEqual(sync.progress, 100)
        XCTAssertEqual(labels(), ["PATCH Account/acc1", "PATCH Contact/con1", "PATCH Account/acc1"])
        XCTAssertEqual(RecordingQueueTarget.calls.map { $0.fields }, [["Name": "a1"], ["LastName": "c1"], ["Name": "a2"]] as [NSDictionary])
        XCTAssertEqual(try queueEntries().count, 0)
        let account = try record(QueueSyncUpTests.accounts, "acc1")
        XCTAssertEqual(account?["Name"] as? String, "a2")
        assertClean(account)
    }

    func test_givenCreateUpdateAndDelete_whenSynced_thenPostPatchAndDeleteWithChangesOnly() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a", "Phone": "1"])
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc2", type: "Account", fields: ["Name": "b"])
        _ = try createAccount("new", extra: ["Industry": "Tech"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "changed"])
        try syncManager.deleteLocal(soupName: QueueSyncUpTests.accounts, id: "acc2")

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["POST Account", "PATCH Account/acc1", "DELETE Account/acc2"])
        XCTAssertEqual(RecordingQueueTarget.calls[0].fields, ["Name": "new", "Industry": "Tech"])
        XCTAssertEqual(RecordingQueueTarget.calls[1].fields, ["Name": "changed"], "only the changed field is sent")
        XCTAssertNil(try record(QueueSyncUpTests.accounts, "acc2"), "deleted record is removed from its soup")
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenExternalIdFieldName_whenCreateReplayed_thenUpsertOnExternalId() throws {
        _ = try createAccount("new", extra: ["ExtId__c": "ext-1"])
        let target = RecordingQueueTarget()
        target.externalIdFieldName = "ExtId__c"

        let sync = try runQueueSync(target: target)

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["UPSERT Account"])
        XCTAssertEqual(RecordingQueueTarget.calls[0].externalId, "ext-1")
        XCTAssertEqual(RecordingQueueTarget.calls[0].fields, ["Name": "new", "ExtId__c": "ext-1"])
    }

    func test_givenCreateWithoutIdInResponse_whenSynced_thenSyncFailsWithAttemptAndErrorOnEntry() throws {
        let localId = try createAccount("new")
        RecordingQueueTarget.responder = { _ in .success([:]) }

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .failed)
        let entry = try XCTUnwrap(try queueEntries().first)
        XCTAssertEqual(entry["attempts"] as? Int, 1)
        XCTAssertNotNil(entry["lastError"])
        XCTAssertEqual(flag(try record(QueueSyncUpTests.accounts, localId), kSyncTargetLocallyCreated), true)
    }

    // MARK: upsert answers

    private func upsertTarget() -> RecordingQueueTarget {
        let target = RecordingQueueTarget()
        target.externalIdFieldName = "ExtId__c"
        return target
    }

    func test_givenUpsertAnswers201WithId_whenSynced_thenIdFromBodyAndNoLookup() throws {
        let localId = try createAccount("new", extra: ["ExtId__c": "ext-1"])
        RecordingQueueTarget.responder = { _ in .success(["id": "created_1", "success": true]) }

        let sync = try runQueueSync(target: upsertTarget())

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["UPSERT Account"])
        XCTAssertNil(try record(QueueSyncUpTests.accounts, localId))
        let account = try record(QueueSyncUpTests.accounts, "created_1")
        XCTAssertEqual(account?["Name"] as? String, "new")
        assertClean(account)
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenUpsertAnswers204_whenSynced_thenIdLookedUpByExternalIdAndRecordRemapped() throws {
        let localAccount = try createAccount("acme", extra: ["ExtId__c": "ext-1"])
        _ = try syncManager.createLocal(soupName: QueueSyncUpTests.contacts, record: newContact("smith", extra: ["AccountId": localAccount]))
        RecordingQueueTarget.upsertCreates = false

        let sync = try runQueueSync(target: upsertTarget())

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["UPSERT Account", "LOOKUP Account", "POST Contact"])
        XCTAssertEqual(RecordingQueueTarget.calls[1].externalId, "ext-1")
        XCTAssertEqual(RecordingQueueTarget.calls[2].fields["AccountId"] as? String, "existing_1")
        let accounts = try allRecords(QueueSyncUpTests.accounts)
        XCTAssertEqual(accounts.map { $0["Id"] as? String }, ["existing_1"])
        assertClean(accounts.first)
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenUpsertAnswers204AndLookupFailsWith400_whenSynced_thenRecordLevelErrorAndSyncGoesOn() throws {
        let localId = try createAccount("acme", extra: ["ExtId__c": "ext-1"])
        RecordingQueueTarget.upsertCreates = false
        RecordingQueueTarget.lookupResponder = { _ in .failure(self.restError(400)) }

        let sync = try runQueueSync(target: upsertTarget())

        XCTAssertEqual(sync.status, .done)
        let entry = try XCTUnwrap(try queueEntries().first)
        XCTAssertEqual(entry["attempts"] as? Int, 1)
        XCTAssertEqual(entry["recordId"] as? String, localId)
        XCTAssertNotNil(try record(QueueSyncUpTests.accounts, localId)?[kSyncTargetLastError])
    }

    func test_givenUpsertAnswers204AndLookupFailsWith503_whenSynced_thenSyncFailsEntryStaysAtHead() throws {
        _ = try createAccount("acme", extra: ["ExtId__c": "ext-1"])
        RecordingQueueTarget.upsertCreates = false
        RecordingQueueTarget.lookupResponder = { _ in .failure(self.restError(503)) }

        let sync = try runQueueSync(target: upsertTarget())

        XCTAssertEqual(sync.status, .failed)
        XCTAssertEqual(try queueEntries().first?["attempts"] as? Int, 1)
    }

    func test_givenUpsertAnswers300_whenSynced_thenRecordLevelError() throws {
        _ = try createAccount("acme", extra: ["ExtId__c": "ext-1"])
        RecordingQueueTarget.responder = { _ in .failure(self.restError(300, ["error": "several records match"])) }

        let sync = try runQueueSync(target: upsertTarget())

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["UPSERT Account"])
        XCTAssertEqual(try queueEntries().first?["attempts"] as? Int, 1)
    }

    // MARK: flags while later entries remain

    /// Flags (`__local__`, created, updated, deleted) of the account as they are when each request is sent.
    private func recordFlagsAtEachCall() -> () -> [[Bool?]] {
        var snapshots: [[Bool?]] = []
        RecordingQueueTarget.onCall = { [self] _ in
            let accounts = (try? allRecords(QueueSyncUpTests.accounts)) ?? []
            let account = accounts.first
            snapshots.append([kSyncTargetLocal, kSyncTargetLocallyCreated, kSyncTargetLocallyUpdated, kSyncTargetLocallyDeleted].map { flag(account, $0) })
        }
        return { snapshots }
    }

    func test_givenCreateThenUpdate_whenSynced_thenDirtyAfterCreateAndCleanAfterUpdate() throws {
        let localId = try createAccount("acme")
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: localId, changes: ["Phone": "555"])
        let snapshots = recordFlagsAtEachCall()

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["POST Account", "PATCH Account/srv_1"])
        // at the second request the create is done: id rewritten, still dirty for the update
        XCTAssertEqual(snapshots()[1], [true, false, true, false])
        let accounts = try allRecords(QueueSyncUpTests.accounts)
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0]["Id"] as? String, "srv_1")
        assertClean(accounts[0])
    }

    func test_givenCreateThenDelete_whenSynced_thenStaysDeletedFlaggedUntilDeleteReplays() throws {
        let localId = try createAccount("acme")
        try syncManager.deleteLocal(soupName: QueueSyncUpTests.accounts, id: localId)
        let snapshots = recordFlagsAtEachCall()

        _ = try runQueueSync()

        XCTAssertEqual(labels(), ["POST Account", "DELETE Account/srv_1"])
        XCTAssertEqual(snapshots()[1], [true, false, false, true])
        XCTAssertEqual(try allRecords(QueueSyncUpTests.accounts).count, 0)
    }

    func test_givenCreateAndTwoUpdates_whenSynced_thenCleanOnlyAfterTheLastUpdate() throws {
        let localId = try createAccount("acme")
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: localId, changes: ["Phone": "1"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: localId, changes: ["Phone": "2"])
        let snapshots = recordFlagsAtEachCall()

        _ = try runQueueSync()

        XCTAssertEqual(labels(), ["POST Account", "PATCH Account/srv_1", "PATCH Account/srv_1"])
        XCTAssertEqual(snapshots()[1], [true, false, true, false])
        XCTAssertEqual(snapshots()[2], [true, false, true, false])
        let accounts = try allRecords(QueueSyncUpTests.accounts)
        XCTAssertEqual(accounts.count, 1)
        assertClean(accounts[0])
    }

    func test_givenCreateWithNoOtherEntry_whenSynced_thenCleanAfterCreate() throws {
        _ = try createAccount("acme")

        _ = try runQueueSync()

        let accounts = try allRecords(QueueSyncUpTests.accounts)
        XCTAssertEqual(accounts.count, 1)
        assertClean(accounts[0])
    }

    func test_givenFailedCreateAndUpdateThenDelete_whenSynced_thenAllEntriesOfTheRecordDropped() throws {
        let localId = try createAccount("acme")
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: localId, changes: ["Phone": "1"])
        let other = try createAccount("other")
        try syncManager.deleteLocal(soupName: QueueSyncUpTests.accounts, id: localId)
        RecordingQueueTarget.responder = { call in
            call.fields["Name"] as? String == "acme" ? .failure(self.restError(400)) : .success(nil)
        }

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(try queueEntries().count, 0)
        XCTAssertNil(try record(QueueSyncUpTests.accounts, localId))
        XCTAssertNil(try record(QueueSyncUpTests.accounts, other), "the other record was created and got its server id")
        XCTAssertEqual(try allRecords(QueueSyncUpTests.accounts).count, 1)
    }

    func test_givenCreateSucceedsAndRowWithServerIdExists_whenSynced_thenNoSecondRow() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "srv_1", type: "Account", fields: ["Name": "from sync down"])
        _ = try createAccount("acme")

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        let accounts = try allRecords(QueueSyncUpTests.accounts)
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0]["Id"] as? String, "srv_1")
        XCTAssertEqual(accounts[0]["Name"] as? String, "acme")
        assertClean(accounts[0])
    }

    func test_givenTransportError_whenSynced_thenEntryHasLastErrorAndAttempt() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "x"])
        RecordingQueueTarget.responder = { _ in .failure(self.restError(503, ["error": "unavailable"])) }

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .failed)
        let entry = try XCTUnwrap(try queueEntries().first)
        XCTAssertEqual(entry["attempts"] as? Int, 1)
        XCTAssertEqual((entry["lastError"] as? [String: Any])?["error"] as? String, "unavailable")
        XCTAssertEqual(entry["status"] as? String, "PENDING")
    }

    func test_givenStopRequestedDuringReplay_whenRestarted_thenStoppedThenRemainingEntriesReplayed() throws {
        for id in ["acc1", "acc2", "acc3"] {
            try seedServerRecord(QueueSyncUpTests.accounts, id: id, type: "Account", fields: ["Name": "a"])
            try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: id, changes: ["Name": "x"])
        }
        RecordingQueueTarget.onCall = { [self] call in
            if call.objectId == "acc1" { syncManager.stop() }
        }

        let stopped = try runQueueSync()

        XCTAssertEqual(stopped.status, .stopped)
        XCTAssertEqual(labels(), ["PATCH Account/acc1"])
        XCTAssertEqual(try queueEntries().map { $0["recordId"] as? String }, ["acc2", "acc3"])

        RecordingQueueTarget.onCall = { _ in }
        let expectation = self.expectation(description: "restarted sync done")
        var fulfilled = false
        XCTAssertNoThrow(try syncManager.restart(restartStoppedSyncs: true) { sync in
            if sync.status == .done && !fulfilled {
                fulfilled = true
                expectation.fulfill()
            }
        })
        wait(for: [expectation], timeout: 30)

        XCTAssertEqual(labels(), ["PATCH Account/acc1", "PATCH Account/acc2", "PATCH Account/acc3"])
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenLocalIdThatIsPrefixOfAnother_whenCreateReplayed_thenOnlyExactIdRemapped() throws {
        let short = try syncManager.createLocal(soupName: QueueSyncUpTests.accounts, record: newAccount("short", extra: ["Id": "local_1"]))
        let long = try syncManager.createLocal(soupName: QueueSyncUpTests.accounts, record: newAccount("long", extra: ["Id": "local_10"]))
        XCTAssertEqual(short["Id"] as? String, "local_1")
        XCTAssertEqual(long["Id"] as? String, "local_10")
        _ = try syncManager.createLocal(soupName: QueueSyncUpTests.contacts, record: newContact("c1", extra: ["AccountId": "local_1", "Other": "local_10"]))
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "local_10", changes: ["Phone": "10"])

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        // creates: short -> srv_1, long -> srv_2, then the contact (srv_3), then the update of the long one
        XCTAssertEqual(labels(), ["POST Account", "POST Account", "POST Contact", "PATCH Account/srv_2"])
        XCTAssertEqual(RecordingQueueTarget.calls[2].fields["AccountId"] as? String, "srv_1")
        XCTAssertEqual(RecordingQueueTarget.calls[2].fields["Other"] as? String, "srv_2")
    }

    // MARK: success handling

    func test_givenCreateSucceeds_whenSynced_thenServerIdSetRecordCleanAndNoSecondRow() throws {
        let localId = try createAccount("new")

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        let rows = try allRecords(QueueSyncUpTests.accounts)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["Id"] as? String, "srv_1")
        XCTAssertEqual(rows[0]["Name"] as? String, "new")
        assertClean(rows[0])
        XCTAssertNil(try record(QueueSyncUpTests.accounts, localId))
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenUpdateWithLaterEntryForSameRecord_whenLaterFails_thenRecordStaysDirty() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "a1"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "a2"])
        var recordAfterFirst: [String: Any]?
        RecordingQueueTarget.onCall = { [self] call in
            if RecordingQueueTarget.calls.count == 2 {
                // the first update was acknowledged: the record must still be dirty for the second one
                recordAfterFirst = try? record(QueueSyncUpTests.accounts, "acc1")
            }
        }
        RecordingQueueTarget.responder = { call in
            return RecordingQueueTarget.calls.count == 2 ? .failure(self.restError(400)) : .success(nil)
        }

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(flag(recordAfterFirst, kSyncTargetLocallyUpdated), true)
        let account = try record(QueueSyncUpTests.accounts, "acc1")
        XCTAssertEqual(flag(account, kSyncTargetLocallyUpdated), true)
        XCTAssertNotNil(account?[kSyncTargetLastError])
        XCTAssertEqual(try queueEntries().count, 1)
    }

    func test_givenEarlierEntryFailed_whenSynced_thenLaterEntryDeferredAndRecordDirtyWithErrorUntilEarlierEntrySucceeds() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "a1"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "a2"])
        RecordingQueueTarget.responder = { call in
            call.fields["Name"] as? String == "a1" ? .failure(self.restError(400, ["error": "bad a1"])) : .success(nil)
        }

        let first = try runQueueSync()

        XCTAssertEqual(first.status, .done)
        var account = try record(QueueSyncUpTests.accounts, "acc1")
        XCTAssertEqual(flag(account, kSyncTargetLocal), true)
        XCTAssertEqual(flag(account, kSyncTargetLocallyUpdated), true)
        XCTAssertTrue((account?[kSyncTargetLastError] as? String)?.contains("bad a1") ?? false, "the error of the remaining entry is kept")
        var entries = try queueEntries()
        XCTAssertEqual(entries.count, 2, "a2 is deferred, not sent")
        XCTAssertNotNil(entries[0]["lastError"])
        XCTAssertEqual(entries[0]["attempts"] as? Int, 1)
        XCTAssertEqual(entries[1]["attempts"] as? Int, 0)
        XCTAssertNil(entries[1]["lastError"])
        XCTAssertEqual(RecordingQueueTarget.calls.map { $0.fields["Name"] as? String }, ["a1"])

        RecordingQueueTarget.responder = { _ in .success(nil) }
        let second = try runQueueSync()

        XCTAssertEqual(second.status, .done)
        XCTAssertEqual(RecordingQueueTarget.calls.map { $0.fields["Name"] as? String }, ["a1", "a1", "a2"])
        account = try record(QueueSyncUpTests.accounts, "acc1")
        assertClean(account)
        entries = try queueEntries()
        XCTAssertEqual(entries.count, 0)
    }

    func test_givenParkedEntryOfSameRecord_whenOtherEntrySucceeds_thenRecordStaysDirty() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "a1"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "a2"])
        var parked = try XCTUnwrap(try queueEntries().first)
        parked["status"] = "PARKED"
        _ = store.upsert(entries: [parked], forSoupNamed: SyncQueue.soupName)

        _ = try runQueueSync()

        XCTAssertEqual(labels(), ["PATCH Account/acc1"])
        XCTAssertEqual(flag(try record(QueueSyncUpTests.accounts, "acc1"), kSyncTargetLocallyUpdated), true)
    }

    func test_givenDeleteReturns404_whenSynced_thenTreatedAsSuccess() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account")
        try syncManager.deleteLocal(soupName: QueueSyncUpTests.accounts, id: "acc1")
        RecordingQueueTarget.responder = { _ in .failure(self.restError(404)) }

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertNil(try record(QueueSyncUpTests.accounts, "acc1"))
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenUpdateReturns404_whenSynced_thenRecordLevelError() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "a1"])
        RecordingQueueTarget.responder = { _ in .failure(self.restError(404)) }

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(try queueEntries().first?["attempts"] as? Int, 1)
    }

    // MARK: errors

    func test_givenRecordLevelErrorOnSecondEntry_whenSynced_thenSyncDoneErrorRecordedAndNextEntryRuns() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc2", type: "Account", fields: ["Name": "b"])
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc3", type: "Account", fields: ["Name": "c"])
        for id in ["acc1", "acc2", "acc3"] {
            try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: id, changes: ["Name": "x"])
        }
        RecordingQueueTarget.responder = { call in
            call.objectId == "acc2" ? .failure(self.restError(400, ["error": "validation failed"])) : .success(nil)
        }

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["PATCH Account/acc1", "PATCH Account/acc2", "PATCH Account/acc3"])
        let entries = try queueEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0]["recordId"] as? String, "acc2")
        XCTAssertEqual(entries[0]["attempts"] as? Int, 1)
        XCTAssertEqual(entries[0]["status"] as? String, "PENDING")
        XCTAssertEqual((entries[0]["lastError"] as? [String: Any])?["error"] as? String, "validation failed")
        let failed = try record(QueueSyncUpTests.accounts, "acc2")
        XCTAssertTrue((failed?[kSyncTargetLastError] as? String)?.contains("validation failed") ?? false)
        XCTAssertEqual(flag(failed, kSyncTargetLocallyUpdated), true)
        assertClean(try record(QueueSyncUpTests.accounts, "acc3"))
    }

    func test_givenTransportErrorOnSecondEntry_whenSynced_thenSyncFailsEntryStaysAtHeadAndReSyncResumes() throws {
        for id in ["acc1", "acc2", "acc3"] {
            try seedServerRecord(QueueSyncUpTests.accounts, id: id, type: "Account", fields: ["Name": "a"])
            try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: id, changes: ["Name": "x"])
        }
        RecordingQueueTarget.responder = { call in
            call.objectId == "acc2" ? .failure(self.restError(503)) : .success(nil)
        }

        let failed = try runQueueSync(name: "queueSync")

        XCTAssertEqual(failed.status, .failed)
        XCTAssertEqual(labels(), ["PATCH Account/acc1", "PATCH Account/acc2"], "later entries are not sent")
        var entries = try queueEntries()
        XCTAssertEqual(entries.map { $0["recordId"] as? String }, ["acc2", "acc3"])
        XCTAssertEqual(entries[0]["attempts"] as? Int, 1)
        XCTAssertEqual(entries[1]["attempts"] as? Int, 0)

        RecordingQueueTarget.responder = { _ in .success(nil) }
        let resumed = try reSync(name: "queueSync")

        XCTAssertEqual(resumed.status, .done)
        XCTAssertEqual(resumed.totalSize, 2)
        XCTAssertEqual(labels(), ["PATCH Account/acc1", "PATCH Account/acc2", "PATCH Account/acc2", "PATCH Account/acc3"])
        entries = try queueEntries()
        XCTAssertEqual(entries.count, 0)
    }

    func test_givenNetworkErrorOrRequestLimit_whenSynced_thenSyncFails() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "x"])
        let errors = [
            NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost),
            restError(403, ["error": [["errorCode": "REQUEST_LIMIT_EXCEEDED"]]])
        ]
        for (i, error) in errors.enumerated() {
            RecordingQueueTarget.responder = { _ in .failure(error) }

            let sync = try runQueueSync()

            XCTAssertEqual(sync.status, .failed)
            XCTAssertEqual(try queueEntries().first?["attempts"] as? Int, i + 1)
        }
    }

    func test_givenEntryWithMissingRecordOrObjectType_whenSynced_thenRecordLevelErrorAndNextEntryRuns() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "x"])
        // entry of a record that is not in its soup, and entries without object type or of an unknown soup
        let orphans: [[String: Any]] = [
            SyncQueue.buildEntry(sequence: 0, soupName: QueueSyncUpTests.accounts, recordId: "gone", sobjectType: "Account", kind: .update, changes: ["Name": "n"]),
            SyncQueue.buildEntry(sequence: 0, soupName: QueueSyncUpTests.accounts, recordId: "acc1", sobjectType: nil, kind: .update, changes: ["Name": "n"]),
            SyncQueue.buildEntry(sequence: 0, soupName: "no_such_soup", recordId: "x", sobjectType: "Account", kind: .update, changes: ["Name": "n"])
        ]
        var sequence = 100
        for var orphan in orphans {
            orphan["sequence"] = sequence
            sequence += 1
            _ = store.upsert(entries: [orphan], forSoupNamed: SyncQueue.soupName)
        }

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["PATCH Account/acc1"])
        let entries = try queueEntries()
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.map { $0["attempts"] as? Int }, [1, 1, 1])
    }

    func test_givenParkedAndPendingEntries_whenSynced_thenParkedSkippedAndTotalSizeCountsPending() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc2", type: "Account", fields: ["Name": "a"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "x"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc2", changes: ["Name": "x"])
        var parked = try XCTUnwrap(try queueEntries().first)
        parked["status"] = "PARKED"
        _ = store.upsert(entries: [parked], forSoupNamed: SyncQueue.soupName)

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(sync.totalSize, 1)
        XCTAssertEqual(labels(), ["PATCH Account/acc2"])
        XCTAssertEqual(try queueEntries().count, 1)
    }

    func test_givenEmptyQueue_whenSynced_thenDoneWithNothingSent() throws {
        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(sync.totalSize, 0)
        XCTAssertTrue(RecordingQueueTarget.calls.isEmpty)
    }

    // MARK: opt-in

    func test_givenFlaggedRecordWithoutEntry_whenQueueSynced_thenItIsNeverSent() throws {
        var flagged = newAccount("flagged")
        flagged["Id"] = "local_flagged"
        flagged[kSyncTargetLocal] = true
        flagged[kSyncTargetLocallyCreated] = true
        flagged[kSyncTargetLocallyUpdated] = false
        flagged[kSyncTargetLocallyDeleted] = false
        _ = store.upsert(entries: [flagged], forSoupNamed: QueueSyncUpTests.accounts)
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "x"])

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["PATCH Account/acc1"])
        XCTAssertEqual(flag(try record(QueueSyncUpTests.accounts, "local_flagged"), kSyncTargetLocallyCreated), true)
    }

    func test_givenQueueEntriesAndFlagBasedTarget_whenSynced_thenQueueIsUntouched() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "x"])
        let expectation = self.expectation(description: "flag-based sync finished")
        let options = SyncOptions.newSyncOptions(forSyncUp: ["Name"], mergeMode: .overwrite)
        var finished = false
        // the record is flagged as updated by the write API, but a flag-based sync of another soup has nothing to do
        let started = syncManager.syncUp(target: CollectionSyncUpTarget(), options: options, soupName: QueueSyncUpTests.contacts) { sync in
            if sync.isDone() && !finished {
                finished = true
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 30)

        XCTAssertNotNil(started)
        XCTAssertEqual(try queueEntries().count, 1)
        XCTAssertTrue(RecordingQueueTarget.calls.isEmpty)
    }

    // MARK: names and reSync

    func test_givenNamedQueueSync_whenReSyncedByIdAndByName_thenTargetRebuiltAndQueueReplayed() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "x"])
        let first = try runQueueSync(name: "myQueueSync")
        XCTAssertEqual(first.status, .done)
        XCTAssertEqual(first.name, "myQueueSync")
        XCTAssertEqual(first.soupName, SyncQueue.soupName)

        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "y"])
        let byId = try reSync(id: first.syncId)
        XCTAssertEqual(byId.status, .done)
        XCTAssertTrue(byId.target is QueueSyncUpTarget)

        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "z"])
        let byName = try reSync(name: "myQueueSync")
        XCTAssertEqual(byName.status, .done)

        XCTAssertEqual(RecordingQueueTarget.calls.map { $0.fields }, [["Name": "x"], ["Name": "y"], ["Name": "z"]] as [NSDictionary])
        XCTAssertEqual(try queueEntries().count, 0)
    }

    // MARK: temp-id remapping

    func test_givenCreateOfAThenCreateReferencingA_whenSynced_thenReferenceSentWithServerId() throws {
        let localAccount = try createAccount("acme")
        _ = try syncManager.createLocal(soupName: QueueSyncUpTests.contacts, record: newContact("smith", extra: ["AccountId": localAccount, "Note": "\(localAccount) is the account"]))
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: localAccount, changes: ["Phone": "555"])
        var queueAtContactCreate: [[String: Any]] = []
        RecordingQueueTarget.onCall = { [self] call in
            if call.objectType == "Contact" {
                queueAtContactCreate = (try? queueEntries()) ?? []
            }
        }

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["POST Account", "POST Contact", "PATCH Account/srv_1"])
        XCTAssertEqual(RecordingQueueTarget.calls[1].fields["AccountId"] as? String, "srv_1")
        XCTAssertEqual(RecordingQueueTarget.calls[1].fields["Note"] as? String, "\(localAccount) is the account", "only exact values are remapped")
        XCTAssertEqual(RecordingQueueTarget.calls[2].fields, ["Phone": "555"])
        // while the contact was sent, the pending entries were already rewritten in the queue
        XCTAssertEqual(queueAtContactCreate.map { $0["recordId"] as? String }.last, "srv_1")
        // soup: the account was rewritten in place
        let accounts = try allRecords(QueueSyncUpTests.accounts)
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0]["Id"] as? String, "srv_1")
        assertClean(accounts[0])
        XCTAssertEqual(accounts[0]["Phone"] as? String, "555")
        let contacts = try allRecords(QueueSyncUpTests.contacts)
        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(contacts[0]["Id"] as? String, "srv_2")
        assertClean(contacts[0])
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenCreateThenDeleteOfSameRecord_whenSynced_thenDeleteUsesServerIdAndRecordRemoved() throws {
        let localAccount = try createAccount("acme")
        try syncManager.deleteLocal(soupName: QueueSyncUpTests.accounts, id: localAccount)

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["POST Account", "DELETE Account/srv_1"])
        XCTAssertEqual(try allRecords(QueueSyncUpTests.accounts).count, 0)
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenCreateFails_whenSynced_thenEntriesReferringToItAreDeferredNotSent() throws {
        let localAccount = try createAccount("acme")
        _ = try syncManager.createLocal(soupName: QueueSyncUpTests.contacts, record: newContact("smith", extra: ["AccountId": localAccount]))
        RecordingQueueTarget.responder = { call in
            call.objectType == "Account" ? .failure(self.restError(400, ["error": "bad account"])) : .failure(self.restError(400, ["error": "bad lookup"]))
        }

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["POST Account"], "the contact refers to the account that was rejected")
        XCTAssertEqual(try queueEntries().map { $0["attempts"] as? Int }, [1, 0])
        XCTAssertNil(try queueEntries()[1]["lastError"])
        XCTAssertNil(try record(QueueSyncUpTests.contacts, try XCTUnwrap(try allRecords(QueueSyncUpTests.contacts).first?["Id"] as? String))?[kSyncTargetLastError])
        XCTAssertNotNil(try record(QueueSyncUpTests.accounts, localAccount), "the record keeps its local id")
    }

    func test_givenDeleteOfRecordWhoseCreateFailed_whenSynced_thenNoServerCallAndRecordRemoved() throws {
        let localAccount = try createAccount("acme")
        try syncManager.deleteLocal(soupName: QueueSyncUpTests.accounts, id: localAccount)
        RecordingQueueTarget.responder = { _ in .failure(self.restError(400)) }

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["POST Account"], "a record that never reached the server is not deleted on the server")
        XCTAssertEqual(try allRecords(QueueSyncUpTests.accounts).count, 0)
        XCTAssertEqual(try queueEntries().count, 0, "the failed create is dropped with the delete")
    }

    // MARK: write order across retries

    func test_givenOlderEditRejectedOnce_whenReSynced_thenNewerNeverSentBeforeOlderSucceeds() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "older"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "newer"])
        var rejectOlder = true
        var serverName = "a"
        var applied: [String] = []
        RecordingQueueTarget.responder = { call in
            let name = call.fields["Name"] as? String ?? ""
            if name == "older" && rejectOlder {
                rejectOlder = false
                return .failure(self.restError(400, ["error": "rejected once"]))
            }
            serverName = name
            applied.append(name)
            return .success(nil)
        }

        let first = try runQueueSync(name: "q")

        XCTAssertEqual(first.status, .done)
        XCTAssertEqual(RecordingQueueTarget.calls.map { $0.fields["Name"] as? String }, ["older"], "newer is not sent while older is rejected")
        XCTAssertEqual(serverName, "a")
        let entries = try queueEntries()
        XCTAssertEqual(entries.map { $0["attempts"] as? Int }, [1, 0])
        XCTAssertNotNil(entries[0]["lastError"])
        XCTAssertNil(entries[1]["lastError"], "the deferred entry is untouched")
        var account = try record(QueueSyncUpTests.accounts, "acc1")
        XCTAssertEqual(flag(account, kSyncTargetLocal), true)
        XCTAssertEqual(flag(account, kSyncTargetLocallyUpdated), true)
        XCTAssertNotNil(account?[kSyncTargetLastError])
        XCTAssertEqual(account?["Name"] as? String, "newer")

        let second = try reSync(name: "q")

        XCTAssertEqual(second.status, .done)
        XCTAssertEqual(applied, ["older", "newer"])
        XCTAssertEqual(RecordingQueueTarget.calls.map { $0.fields["Name"] as? String }, ["older", "older", "newer"], "older is not re-sent after newer")
        XCTAssertEqual(serverName, "newer")
        account = try record(QueueSyncUpTests.accounts, "acc1")
        assertClean(account)
        XCTAssertEqual(account?["Name"] as? String, "newer")
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenRejectedEntry_whenSynced_thenOtherRecordsStillReplayed() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc2", type: "Account", fields: ["Name": "b"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "a1"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc2", changes: ["Name": "b1"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "a2"])
        RecordingQueueTarget.responder = { call in call.objectId == "acc1" ? .failure(self.restError(400)) : .success(nil) }

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["PATCH Account/acc1", "PATCH Account/acc2"])
        XCTAssertEqual(try queueEntries().map { $0["attempts"] as? Int }, [1, 0])
        assertClean(try record(QueueSyncUpTests.accounts, "acc2"))
    }

    func test_givenServerDeleteSucceeds_whenSynced_thenAllOtherEntriesOfTheRecordAreRemoved() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "a1"])
        try syncManager.deleteLocal(soupName: QueueSyncUpTests.accounts, id: "acc1")
        // the update is parked: it is not replayed, but it must not outlive the record
        var parked = try XCTUnwrap(try queueEntries().first)
        parked[SyncQueue.statusField] = SyncQueue.Status.parked.rawValue
        _ = try XCTUnwrap(store.upsert(entries: [parked], forSoupNamed: SyncQueue.soupName, withExternalIdPath: SmartStore.soupEntryId))

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["DELETE Account/acc1"])
        XCTAssertEqual(try queueEntries().count, 0)
        XCTAssertEqual(try allRecords(QueueSyncUpTests.accounts).count, 0)
    }

    // MARK: cross-soup local ids

    func test_givenLocalIdUsedInAnotherSoup_whenCreateLocal_thenRejected() throws {
        let saved = try syncManager.createLocal(soupName: QueueSyncUpTests.accounts, record: newAccount("acme", extra: ["Id": "local_shared"]))
        XCTAssertEqual(saved["Id"] as? String, "local_shared")

        XCTAssertThrowsError(try syncManager.createLocal(soupName: QueueSyncUpTests.contacts, record: newContact("smith", extra: ["Id": "local_shared"]))) { error in
            XCTAssertEqual((error as NSError).domain, kSFMobileSyncErrorDomain)
            XCTAssertEqual((error as NSError).code, LocalWriteError.recordAlreadyExists.rawValue)
        }
        XCTAssertEqual(try allRecords(QueueSyncUpTests.contacts).count, 0)
        XCTAssertEqual(try queueEntries().count, 1, "nothing written by the rejected call")
    }

    func test_givenLocalIdUsedByQueueEntryOfAnotherSoup_whenCreateLocal_thenRejected() throws {
        try syncManager.createLocal(soupName: QueueSyncUpTests.accounts, record: newAccount("acme", extra: ["Id": "local_shared"]))
        // the record is gone but its entry is still queued
        let account = try XCTUnwrap(try record(QueueSyncUpTests.accounts, "local_shared"))
        try store.remove(entryIds: [try XCTUnwrap(account[SmartStore.soupEntryId] as? NSNumber)], forSoupNamed: QueueSyncUpTests.accounts)

        XCTAssertThrowsError(try syncManager.createLocal(soupName: QueueSyncUpTests.contacts, record: newContact("smith", extra: ["Id": "local_shared"]))) { error in
            XCTAssertEqual((error as NSError).code, LocalWriteError.recordAlreadyExists.rawValue)
        }
        XCTAssertEqual(try queueEntries().count, 1)
    }

    func test_givenSameLocalIdInTwoSoups_whenCreateReplayed_thenOnlyOwnSoupEntriesRemapped() throws {
        // two soups cannot get the same local id through createLocal: the entry of the other soup is written directly
        let localAccount = try createAccount("acme")
        let foreign = SyncQueue.buildEntry(sequence: 1000, soupName: QueueSyncUpTests.contacts, recordId: localAccount, sobjectType: "Contact", kind: .update, changes: ["LastName": "x"])
        _ = try XCTUnwrap(store.upsert(entries: [foreign], forSoupNamed: SyncQueue.soupName))

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["POST Account"], "the entry of the contacts soup has no record: rejected, not sent")
        let entries = try queueEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0][SyncQueue.soupNameField] as? String, QueueSyncUpTests.contacts)
        XCTAssertEqual(entries[0][SyncQueue.recordIdField] as? String, localAccount, "not remapped")
        XCTAssertEqual(try allRecords(QueueSyncUpTests.accounts).first?["Id"] as? String, "srv_1")
    }

    // MARK: one replay at a time

    func test_givenFirstRequestHeldOpen_whenSecondQueueSyncStarted_thenEachEntrySentOnce() throws {
        _ = try createAccount("acme")
        let accountId = try XCTUnwrap(try allRecords(QueueSyncUpTests.accounts).first?["Id"] as? String)
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: accountId, changes: ["Phone": "555"])
        let release = DispatchSemaphore(value: 0)
        var firstHeld = false
        RecordingQueueTarget.holdAnswer = { call in
            if call.method == "POST" && !firstHeld {
                firstHeld = true
                return release
            }
            return nil
        }
        let firstDone = expectation(description: "first finished")
        let secondDone = expectation(description: "second finished")
        let options = SyncOptions.newSyncOptions(forSyncUp: [], mergeMode: .overwrite)
        var firstFinished = false, secondFinished = false
        _ = try syncManager.syncUp(target: RecordingQueueTarget(), options: options, soupName: SyncQueue.soupName, syncName: nil) { sync in
            if sync.status == .done && !firstFinished { firstFinished = true; firstDone.fulfill() }
        }
        while RecordingQueueTarget.calls.isEmpty { Thread.sleep(forTimeInterval: 0.01) }
        _ = try syncManager.syncUp(target: RecordingQueueTarget(), options: options, soupName: SyncQueue.soupName, syncName: nil) { sync in
            if sync.status == .done && !secondFinished { secondFinished = true; secondDone.fulfill() }
        }
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(labels(), ["POST Account"], "the second sync waits: no second POST while the first request is open")

        release.signal()
        wait(for: [firstDone, secondDone], timeout: 30)

        XCTAssertEqual(labels(), ["POST Account", "PATCH Account/srv_1"])
        XCTAssertEqual(try queueEntries().count, 0)
    }

    // MARK: authentication failure

    func test_given401_whenSynced_thenSyncFailsAndSecondEntryUntouched() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc2", type: "Account", fields: ["Name": "b"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "a1"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc2", changes: ["Name": "b1"])
        RecordingQueueTarget.responder = { _ in .failure(self.restError(401, ["error": "expired"])) }

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .failed)
        XCTAssertEqual(labels(), ["PATCH Account/acc1"])
        let entries = try queueEntries()
        XCTAssertEqual(entries.map { $0["attempts"] as? Int }, [1, 0])
        XCTAssertNotNil(entries[0]["lastError"])
        XCTAssertNil(entries[1]["lastError"])
    }

    // MARK: more than one page of entries

    func test_givenMoreThanAThousandParkedEdits_whenLocalIdRecordDeleted_thenNoEntryLeftBehind() throws {
        let localAccount = try createAccount("acme")
        try syncManager.deleteLocal(soupName: QueueSyncUpTests.accounts, id: localAccount)
        let extra = (0..<1100).map { i -> [String: Any] in
            var entry = SyncQueue.buildEntry(sequence: 1000 + i, soupName: QueueSyncUpTests.accounts, recordId: localAccount, sobjectType: "Account", kind: .update, changes: ["Name": "n\(i)"])
            entry[SyncQueue.statusField] = SyncQueue.Status.parked.rawValue
            return entry
        }
        _ = try XCTUnwrap(store.upsert(entries: extra, forSoupNamed: SyncQueue.soupName))
        RecordingQueueTarget.responder = { _ in .failure(self.restError(400)) }

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["POST Account"])
        XCTAssertEqual(try queueEntries().count, 0)
        XCTAssertEqual(try allRecords(QueueSyncUpTests.accounts).count, 0)
    }

    func test_givenMoreThanAThousandRemainingEntries_whenOneReplayed_thenFlagsCoverEveryRemainingKind() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "a1"])
        var extra = (0..<1100).map { i -> [String: Any] in
            var entry = SyncQueue.buildEntry(sequence: 1000 + i, soupName: QueueSyncUpTests.accounts, recordId: "acc1", sobjectType: "Account", kind: .delete, changes: nil)
            entry[SyncQueue.statusField] = SyncQueue.Status.parked.rawValue
            return entry
        }
        var lastOne = SyncQueue.buildEntry(sequence: 5000, soupName: QueueSyncUpTests.accounts, recordId: "acc1", sobjectType: "Account", kind: .update, changes: ["Name": "later"])
        lastOne[SyncQueue.statusField] = SyncQueue.Status.parked.rawValue
        extra.append(lastOne)
        _ = try XCTUnwrap(store.upsert(entries: extra, forSoupNamed: SyncQueue.soupName))

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(flag(try record(QueueSyncUpTests.accounts, "acc1"), kSyncTargetLocallyUpdated), true, "a parked UPDATE remains, past the first page")
        XCTAssertEqual(flag(try record(QueueSyncUpTests.accounts, "acc1"), kSyncTargetLocal), true)
    }

    // MARK: upsert creates and quoted ids

    func test_givenOlderUpdateRejectedAndNewerUpsertCreateOfSameRecord_whenSyncedAndRetried_thenNewerWins() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a", "ExtId__c": "e1"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "older"])
        // the upsert updates the existing acc1 on the server (204: no body, then the id lookup)
        _ = try syncManager.createLocal(soupName: QueueSyncUpTests.accounts, record: newAccount("newer", extra: ["ExtId__c": "e1"]))
        let target = RecordingQueueTarget()
        target.externalIdFieldName = "ExtId__c"
        RecordingQueueTarget.upsertCreates = false
        RecordingQueueTarget.lookupResponder = { _ in .success(["id": "acc1"]) }
        var rejectOlder = true
        var serverName = "a"
        RecordingQueueTarget.responder = { call in
            let name = call.fields["Name"] as? String ?? ""
            if name == "older" && rejectOlder {
                rejectOlder = false
                return .failure(self.restError(400))
            }
            serverName = name
            return .success(nil)
        }

        let first = try runQueueSync(target: target, name: "q")

        XCTAssertEqual(first.status, .done)
        XCTAssertEqual(labels(), ["PATCH Account/acc1"], "the upsert create may update acc1: it waits")
        XCTAssertEqual(serverName, "a")

        let second = try reSync(name: "q")

        XCTAssertEqual(second.status, .done)
        XCTAssertEqual(labels(), ["PATCH Account/acc1", "PATCH Account/acc1", "UPSERT Account", "LOOKUP Account"])
        XCTAssertEqual(serverName, "newer")
        let accounts = try allRecords(QueueSyncUpTests.accounts)
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0]["Id"] as? String, "acc1")
        XCTAssertEqual(accounts[0]["Name"] as? String, "newer")
        assertClean(accounts[0])
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenRejectedEntryOfAType_whenSynced_thenPlainCreateOfSameTypeStillSent() throws {
        try seedServerRecord(QueueSyncUpTests.accounts, id: "acc1", type: "Account", fields: ["Name": "a"])
        try syncManager.updateLocal(soupName: QueueSyncUpTests.accounts, id: "acc1", changes: ["Name": "older"])
        _ = try createAccount("plain")
        RecordingQueueTarget.responder = { call in call.method == "PATCH" ? .failure(self.restError(400)) : .success(nil) }

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(labels(), ["PATCH Account/acc1", "POST Account"], "a create without external id cannot hit an existing record")
    }

    func test_givenTempIdWithQuoteAndSlash_whenRunStoppedAfterCreateAndResumed_thenReferenceSentWithServerId() throws {
        let tempId = "local_q\"1/x\\y"
        _ = try syncManager.createLocal(soupName: QueueSyncUpTests.accounts, record: newAccount("acme", extra: ["Id": tempId]))
        _ = try syncManager.createLocal(soupName: QueueSyncUpTests.contacts, record: newContact("smith", extra: ["AccountId": tempId]))
        var contactAttempts = 0
        RecordingQueueTarget.responder = { call in
            if call.objectType == "Contact" {
                contactAttempts += 1
                if contactAttempts == 1 { return .failure(self.restError(503)) }
            }
            return .success(nil)
        }

        let first = try runQueueSync(name: "q")

        XCTAssertEqual(first.status, .failed)
        XCTAssertEqual(labels(), ["POST Account", "POST Contact"])
        XCTAssertEqual(try queueEntries().count, 1)
        XCTAssertEqual(try queueEntries()[0]["changes"] as? [String: String], ["AccountId": "srv_1", "LastName": "smith"], "the queue was rewritten before the run stopped")

        let second = try reSync(name: "q")

        XCTAssertEqual(second.status, .done)
        XCTAssertEqual(labels(), ["POST Account", "POST Contact", "POST Contact"])
        XCTAssertEqual(RecordingQueueTarget.calls[2].fields["AccountId"] as? String, "srv_1")
        XCTAssertEqual(try queueEntries().count, 0)
    }
}


/// Exercises the real request building of `QueueSyncUpTarget` (no override of the request helpers): the REST client
/// is replaced by a stub that records the requests and answers them.
class QueueSyncUpRequestTests: XCTestCase {
    private typealias FailBlock = @convention(block) (Any?, NSError?, URLResponse?) -> Void
    private typealias SuccessBlock = @convention(block) (Any?, URLResponse?) -> Void
    private typealias SendBlock = @convention(block) (AnyObject, AnyObject?, @escaping FailBlock, @escaping SuccessBlock) -> Void

    private static let storeName = "QueueSyncUpRequestTests"
    private static let accounts = "accounts"
    private let selector = NSSelectorFromString("send:failureBlock:successBlock:")

    private var store: SmartStore!
    private var syncManager: SyncManager!
    private var originalImp: IMP?
    private var originalUser: UserAccount?
    private var requests: [(method: RestRequest.Method, path: String, query: [String: Any], body: [String: Any]?)] = []
    private var answer: (RestRequest) -> (Any?, NSError?) = { _ in (nil, nil) }

    override func setUpWithError() throws {
        SmartStore.removeSharedGlobal(withName: QueueSyncUpRequestTests.storeName)
        // the REST client only exists for a logged in user; the requests are never sent over the network
        originalUser = UserAccountManager.shared.currentUserAccount
        let credentials = try XCTUnwrap(OAuthCredentials(identifier: "queue-sync-up-request-tests", clientId: "fakeClientId", encrypted: true))
        credentials.setValue("queueSyncUpRequestTestsUser", forKey: "userId")
        credentials.setValue("queueSyncUpRequestTestsOrg", forKey: "organizationId")
        let user = UserAccount(credentials: credentials)
        user.setValue(UserAccount.LoginState.loggedIn.rawValue, forKey: "loginState")
        UserAccountManager.shared.currentUserAccount = user
        store = try XCTUnwrap(SmartStore.sharedGlobal(withName: QueueSyncUpRequestTests.storeName))
        let paths = ["Id", kSyncTargetLocal, kSyncTargetLocallyCreated, kSyncTargetLocallyUpdated, kSyncTargetLocallyDeleted]
        try store.registerSoup(withName: QueueSyncUpRequestTests.accounts, withIndices: paths.compactMap { SoupIndex(path: $0, indexType: kSoupIndexTypeString, columnName: nil) })
        syncManager = try XCTUnwrap(SyncManager.sharedInstance(store: store))
        let method = try XCTUnwrap(class_getInstanceMethod(RestClient.self, selector))
        originalImp = method_getImplementation(method)
        let block: SendBlock = { [unowned self] _, requestObject, failure, success in
            guard let request = requestObject as? RestRequest else { return failure(nil, NSError(domain: "test", code: 1), nil) }
            let body = request.value(forKey: "requestBodyAsDictionary") as? [String: Any]
            requests.append((request.method, request.path, request.queryParams as? [String: Any] ?? [:], body))
            let (response, error) = answer(request)
            if let error = error { failure(response, error, nil) } else { success(response, nil) }
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    override func tearDown() {
        if let imp = originalImp, let method = class_getInstanceMethod(RestClient.self, selector) {
            method_setImplementation(method, imp)
        }
        SyncManager.removeSharedInstance(store: store)
        SmartStore.removeSharedGlobal(withName: QueueSyncUpRequestTests.storeName)
        UserAccountManager.shared.currentUserAccount = originalUser
        super.tearDown()
    }

    private func run(_ target: QueueSyncUpTarget) throws -> SyncState {
        let expectation = self.expectation(description: "sync finished")
        var finished = false
        let started = try syncManager.syncUp(target: target, options: SyncOptions.newSyncOptions(forSyncUp: [], mergeMode: .overwrite), soupName: SyncQueue.soupName, syncName: nil) { sync in
            if (sync.status == .done || sync.status == .failed) && !finished {
                finished = true
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 30)
        return try XCTUnwrap(syncManager.syncStatus(forId: NSNumber(value: try XCTUnwrap(started).syncId)))
    }

    private func seedServerRecord(_ id: String) throws {
        let record: [String: Any] = ["Id": id, "attributes": ["type": "Account"], "Name": "a",
                                     kSyncTargetLocal: false, kSyncTargetLocallyCreated: false, kSyncTargetLocallyUpdated: false, kSyncTargetLocallyDeleted: false]
        _ = store.upsert(entries: [record], forSoupNamed: QueueSyncUpRequestTests.accounts)
    }

    func test_givenCreateUpdateDelete_whenSynced_thenPostPatchDeleteRequestsWithChangesOnly() throws {
        try seedServerRecord("001A")
        try seedServerRecord("001B")
        _ = try syncManager.createLocal(soupName: QueueSyncUpRequestTests.accounts, record: ["attributes": ["type": "Account"], "Name": "new"])
        try syncManager.updateLocal(soupName: QueueSyncUpRequestTests.accounts, id: "001A", changes: ["Name": "changed"])
        try syncManager.deleteLocal(soupName: QueueSyncUpRequestTests.accounts, id: "001B")
        answer = { request in request.method == .POST ? (["id": "001N", "success": true], nil) : (nil, nil) }

        let sync = try run(QueueSyncUpTarget())

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(requests.map { $0.method }, [.POST, .PATCH, .DELETE])
        XCTAssertTrue(requests[0].path.hasSuffix("/sobjects/Account"), requests[0].path)
        XCTAssertEqual(requests[0].body as? [String: String], ["Name": "new"])
        XCTAssertTrue(requests[1].path.hasSuffix("/sobjects/Account/001A"), requests[1].path)
        XCTAssertEqual(requests[1].body as? [String: String], ["Name": "changed"])
        XCTAssertTrue(requests[2].path.hasSuffix("/sobjects/Account/001B"), requests[2].path)
    }

    func test_givenUpsertAnswers204_whenSynced_thenPathsHaveEncodedExternalIdAndLookupGetsId() throws {
        let externalId = "a/b?c#d e%f"
        _ = try syncManager.createLocal(soupName: QueueSyncUpRequestTests.accounts, record: ["attributes": ["type": "Account"], "Name": "new", "ExtId__c": externalId])
        answer = { request in
            request.method == .GET ? (["attributes": ["type": "Account"], "Id": "001X"], nil) : (nil, nil)
        }
        let target = QueueSyncUpTarget()
        target.externalIdFieldName = "ExtId__c"

        let sync = try run(target)

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(requests.map { $0.method }, [.PATCH, .GET])
        let encoded = "a%2Fb%3Fc%23d%20e%25f"
        XCTAssertTrue(requests[0].path.hasSuffix("/sobjects/Account/ExtId__c/\(encoded)"), requests[0].path)
        XCTAssertEqual(requests[0].body as? [String: String], ["Name": "new", "ExtId__c": externalId])
        XCTAssertTrue(requests[1].path.hasSuffix("/sobjects/Account/ExtId__c/\(encoded)"), requests[1].path)
        XCTAssertEqual(requests[1].query as? [String: String], ["fields": "Id"])
        let accounts = try XCTUnwrap(store.query(using: XCTUnwrap(QuerySpec.buildAllQuerySpec(soupName: QueueSyncUpRequestTests.accounts, orderPath: SmartStore.soupEntryId, order: .ascending, pageSize: 10)), startingFromPageIndex: 0) as? [[String: Any]])
        XCTAssertEqual(accounts.map { $0["Id"] as? String }, ["001X"])
    }

    func test_givenUpsertAnswers201_whenSynced_thenIdFromBodyAndNoLookup() throws {
        _ = try syncManager.createLocal(soupName: QueueSyncUpRequestTests.accounts, record: ["attributes": ["type": "Account"], "Name": "new", "ExtId__c": "e1"])
        answer = { _ in (["id": "001Y", "success": true], nil) }
        let target = QueueSyncUpTarget()
        target.externalIdFieldName = "ExtId__c"

        let sync = try run(target)

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(requests.map { $0.method }, [.PATCH])
    }
}
