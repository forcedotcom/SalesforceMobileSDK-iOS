//
//  BriefcaseSyncDownTests.swift
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

import XCTest
@testable import MobileSync
import SalesforceSDKCore
import SmartStore

/// Live-org tests of the queue replay (`QueueSyncUpTarget`): real REST requests, no test doubles.
/// Needs `shared/test/test_credentials.json`. Everything created on the server is deleted in `tearDown`.
class QueueSyncUpOrgTests: SyncManagerTestCase {
    private var prefix = ""

    override func setUpWithError() throws {
        super.setUp()
        prefix = "QueueOrgTest_\(Int(Date().timeIntervalSince1970 * 1000))_\(Int.random(in: 100...999))_"
        createAccountsSoup()
        createContactsSoup()
        // the queue soup outlives the tests: start each one with an empty queue
        SyncQueue.setupQueueSoupIfNeeded(store)
        store.clearSoup(SyncQueue.soupName)
    }

    override func tearDown() {
        cleanServer()
        store.clearSoup(SyncQueue.soupName)
        dropAccountsSoup()
        dropContactsSoup()
        super.tearDown()
    }

    // MARK: helpers

    struct Answer {
        let status: Int
        let body: Any?
    }

    /// Sends a request and returns the real HTTP status and the parsed body (success or failure).
    private func send(_ request: RestRequest) -> Answer {
        let done = expectation(description: "rest call")
        var answer = Answer(status: -1, body: nil)
        RestClient.shared.send(request, failureBlock: { body, error, raw in
            answer = Answer(status: (raw as? HTTPURLResponse)?.statusCode ?? (error as NSError?)?.code ?? -1, body: body ?? (error as NSError?)?.userInfo)
            done.fulfill()
        }, successBlock: { body, raw in
            answer = Answer(status: (raw as? HTTPURLResponse)?.statusCode ?? -1, body: body)
            done.fulfill()
        })
        wait(for: [done], timeout: 60)
        return answer
    }

    private func cleanServer() {
        for (type, field) in [(CONTACT_TYPE, "LastName"), (ACCOUNT_TYPE, "Name")] {
            let query = send(RestClient.shared.request(forQuery: "SELECT Id FROM \(type) WHERE \(field) LIKE '\(prefix)%'", apiVersion: nil))
            let ids = ((query.body as? [String: Any])?["records"] as? [[String: Any]])?.compactMap { $0["Id"] as? String } ?? []
            for id in ids {
                _ = send(RestClient.shared.requestForDelete(withObjectType: type, objectId: id, apiVersion: nil))
            }
        }
    }

    private func serverRecord(_ type: String, _ id: String, fields: String) -> (Answer, [String: Any]?) {
        let answer = send(RestClient.shared.requestForRetrieve(withObjectType: type, objectId: id, fieldList: fields, apiVersion: nil))
        return (answer, answer.body as? [String: Any])
    }

    private func createOnServer(_ type: String, _ fields: [String: Any]) throws -> String {
        let answer = send(RestClient.shared.requestForCreate(withObjectType: type, fields: fields, apiVersion: nil))
        XCTAssertEqual(answer.status, 201)
        return try XCTUnwrap((answer.body as? [String: Any])?["id"] as? String)
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

    private func account(_ name: String, extra: [String: Any] = [:]) -> [String: Any] {
        var record: [String: Any] = ["attributes": ["type": ACCOUNT_TYPE], NAME: name]
        record.merge(extra) { _, new in new }
        return record
    }

    /// Puts a record that exists on the server in the soup, as sync down leaves it.
    private func seedServerRecord(_ soupName: String, id: String, type: String, fields: [String: Any]) throws {
        var record = fields
        record["Id"] = id
        record["attributes"] = ["type": type]
        for name in [kSyncTargetLocal, kSyncTargetLocallyCreated, kSyncTargetLocallyUpdated, kSyncTargetLocallyDeleted] {
            record[name] = false
        }
        _ = try store.upsert(entries: [record], forSoupNamed: soupName)
    }

    /// Runs a queue sync against the org and waits for its final state.
    @discardableResult
    private func runQueueSync(target: QueueSyncUpTarget = QueueSyncUpTarget(), name: String? = nil) throws -> SyncState {
        let finished = expectation(description: "queue sync finished")
        let options = SyncOptions.newSyncOptions(forSyncUp: [], mergeMode: .overwrite)
        var done = false
        let started = try syncManager.syncUp(target: target, options: options, soupName: SyncQueue.soupName, syncName: name) { sync in
            if (sync.status == .done || sync.status == .failed || sync.status == .stopped) && !done {
                done = true
                finished.fulfill()
            }
        }
        wait(for: [finished], timeout: 120)
        let sync = try XCTUnwrap(started)
        return try XCTUnwrap(syncManager.syncStatus(forId: NSNumber(value: sync.syncId)))
    }

    private func idsOnServer(_ type: String, field: String, value: String) -> [String] {
        let query = send(RestClient.shared.request(forQuery: "SELECT Id FROM \(type) WHERE \(field) = '\(value)'", apiVersion: nil))
        return ((query.body as? [String: Any])?["records"] as? [[String: Any]])?.compactMap { $0["Id"] as? String } ?? []
    }

    // MARK: 1. CREATE, UPDATE, DELETE of one record

    func test_givenCreateUpdateDeleteQueued_whenReplayed_thenServerAndLocalStateFollow() throws {
        let name = prefix + "a"
        let created = try syncManager.createLocal(soupName: ACCOUNTS_SOUP, record: account(name))
        let localId = try XCTUnwrap(created[ID] as? String)
        XCTAssertTrue(SyncTarget.isLocalId(localId))

        // CREATE replayed alone
        var sync = try runQueueSync()
        XCTAssertEqual(sync.status, .done)
        let ids = idsOnServer(ACCOUNT_TYPE, field: "Name", value: name)
        XCTAssertEqual(ids.count, 1, "the account exists on the server")
        let serverId = try XCTUnwrap(ids.first)
        XCTAssertNil(try record(ACCOUNTS_SOUP, localId))
        assertClean(try record(ACCOUNTS_SOUP, serverId))
        XCTAssertEqual(try queueEntries().count, 0)

        // UPDATE replayed
        let updatedName = name + "_upd"
        try syncManager.updateLocal(soupName: ACCOUNTS_SOUP, id: serverId, changes: [NAME: updatedName])
        XCTAssertEqual(try queueEntries().count, 1)
        sync = try runQueueSync()
        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(serverRecord(ACCOUNT_TYPE, serverId, fields: "Name").1?[NAME] as? String, updatedName)
        let afterUpdate = try record(ACCOUNTS_SOUP, serverId)
        XCTAssertEqual(afterUpdate?[NAME] as? String, updatedName)
        assertClean(afterUpdate)
        XCTAssertEqual(try queueEntries().count, 0)

        // DELETE replayed
        try syncManager.deleteLocal(soupName: ACCOUNTS_SOUP, id: serverId)
        sync = try runQueueSync()
        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(serverRecord(ACCOUNT_TYPE, serverId, fields: "Name").0.status, 404, "the account is deleted on the server")
        XCTAssertNil(try record(ACCOUNTS_SOUP, serverId))
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenCreateAndUpdateQueuedTogether_whenReplayed_thenFinalStateOnServerAndClean() throws {
        let name = prefix + "b"
        let created = try syncManager.createLocal(soupName: ACCOUNTS_SOUP, record: account(name))
        let localId = try XCTUnwrap(created[ID] as? String)
        try syncManager.updateLocal(soupName: ACCOUNTS_SOUP, id: localId, changes: [NAME: name + "_upd"])
        XCTAssertEqual(try queueEntries().count, 2)

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        let ids = idsOnServer(ACCOUNT_TYPE, field: "Name", value: name + "_upd")
        XCTAssertEqual(ids.count, 1)
        XCTAssertEqual(idsOnServer(ACCOUNT_TYPE, field: "Name", value: name).count, 0)
        let local = try XCTUnwrap(try record(ACCOUNTS_SOUP, try XCTUnwrap(ids.first)))
        XCTAssertEqual(local[NAME] as? String, name + "_upd")
        assertClean(local)
        XCTAssertEqual(try allRecords(ACCOUNTS_SOUP).count, 1)
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenCreateAndDeleteQueuedTogether_whenReplayed_thenNothingSentAndRecordRemoved() throws {
        let name = prefix + "c"
        let localId = try XCTUnwrap(try syncManager.createLocal(soupName: ACCOUNTS_SOUP, record: account(name))[ID] as? String)
        try syncManager.deleteLocal(soupName: ACCOUNTS_SOUP, id: localId)

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(idsOnServer(ACCOUNT_TYPE, field: "Name", value: name).count, 0)
        XCTAssertEqual(try allRecords(ACCOUNTS_SOUP).count, 0)
        XCTAssertEqual(try queueEntries().count, 0)
    }

    func test_givenDeleteOfRecordAlreadyDeletedOnServer_whenReplayed_thenTreatedAsSuccess() throws {
        let id = try createOnServer(ACCOUNT_TYPE, [NAME: prefix + "d"])
        try seedServerRecord(ACCOUNTS_SOUP, id: id, type: ACCOUNT_TYPE, fields: [NAME: prefix + "d"])
        let deleted = send(RestClient.shared.requestForDelete(withObjectType: ACCOUNT_TYPE, objectId: id, apiVersion: nil))
        XCTAssertEqual(deleted.status, 204)
        try syncManager.deleteLocal(soupName: ACCOUNTS_SOUP, id: id)

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        XCTAssertNil(try record(ACCOUNTS_SOUP, id))
        XCTAssertEqual(try queueEntries().count, 0)
        // what the server says about the second delete
        let again = send(RestClient.shared.requestForDelete(withObjectType: ACCOUNT_TYPE, objectId: id, apiVersion: nil))
        print("LIVE-ORG: DELETE of an already deleted account answers \(again.status) \(String(describing: again.body))")
        XCTAssertEqual(again.status, 404)
    }

    // MARK: 2. Temp-id remapping

    func test_givenContactReferencingLocalAccount_whenReplayedInOneSync_thenContactHasServerAccountId() throws {
        let accountName = prefix + "e"
        let contactName = prefix + "contact"
        let accountLocalId = try XCTUnwrap(try syncManager.createLocal(soupName: ACCOUNTS_SOUP, record: account(accountName))[ID] as? String)
        let contact: [String: Any] = ["attributes": ["type": CONTACT_TYPE], LAST_NAME: contactName, ACCOUNT_ID: accountLocalId]
        let contactLocalId = try XCTUnwrap(try syncManager.createLocal(soupName: CONTACTS_SOUP, record: contact)[ID] as? String)

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        let accountId = try XCTUnwrap(idsOnServer(ACCOUNT_TYPE, field: "Name", value: accountName).first)
        let contactId = try XCTUnwrap(idsOnServer(CONTACT_TYPE, field: "LastName", value: contactName).first)
        XCTAssertEqual(serverRecord(CONTACT_TYPE, contactId, fields: "AccountId").1?[ACCOUNT_ID] as? String, accountId)
        XCTAssertNil(try record(CONTACTS_SOUP, contactLocalId))
        let localContact = try XCTUnwrap(try record(CONTACTS_SOUP, contactId))
        // Finding (reported, not asserted): the replay rewrites the queue entries and the record's Id, but not the
        // lookup field of the local record, which keeps the temp id
        print("LIVE-ORG: local contact AccountId after the replay: \(String(describing: localContact[ACCOUNT_ID])) (server account id \(accountId))")
        assertClean(localContact)
        assertClean(try record(ACCOUNTS_SOUP, accountId))
        XCTAssertEqual(try queueEntries().count, 0)
    }

    // MARK: 3. Record-level errors

    func test_givenRejectedUpdate_whenReplayed_thenLastErrorSetLaterEntriesDeferredAndOthersReplay() throws {
        let rejectedId = try createOnServer(ACCOUNT_TYPE, [NAME: prefix + "f1"])
        let otherId = try createOnServer(ACCOUNT_TYPE, [NAME: prefix + "f2"])
        try seedServerRecord(ACCOUNTS_SOUP, id: rejectedId, type: ACCOUNT_TYPE, fields: [NAME: prefix + "f1"])
        try seedServerRecord(ACCOUNTS_SOUP, id: otherId, type: ACCOUNT_TYPE, fields: [NAME: prefix + "f2"])
        // Name longer than 255 characters: the server answers 400 STRING_TOO_LONG
        try syncManager.updateLocal(soupName: ACCOUNTS_SOUP, id: rejectedId, changes: [NAME: String(repeating: "x", count: 300)])
        try syncManager.updateLocal(soupName: ACCOUNTS_SOUP, id: rejectedId, changes: ["Description": "later"])
        try syncManager.updateLocal(soupName: ACCOUNTS_SOUP, id: otherId, changes: [NAME: prefix + "f2_upd"])

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done)
        let entries = try queueEntries()
        XCTAssertEqual(entries.count, 2, "the rejected entry and the deferred one remain")
        XCTAssertEqual(entries.map { $0["recordId"] as? String }, [rejectedId, rejectedId])
        XCTAssertEqual(entries[0]["attempts"] as? Int, 1)
        XCTAssertNotNil(entries[0]["lastError"])
        print("LIVE-ORG: lastError of a rejected UPDATE: \(String(describing: entries[0]["lastError"]))")
        XCTAssertEqual(entries[1]["attempts"] as? Int, 0, "deferred: not sent, not counted")
        XCTAssertNil(entries[1]["lastError"])
        XCTAssertEqual(serverRecord(ACCOUNT_TYPE, rejectedId, fields: "Name,Description").1?["Description"] as? String ?? "", "")
        XCTAssertEqual(serverRecord(ACCOUNT_TYPE, otherId, fields: "Name").1?[NAME] as? String, prefix + "f2_upd")
        let rejectedLocal = try record(ACCOUNTS_SOUP, rejectedId)
        XCTAssertEqual(flag(rejectedLocal, kSyncTargetLocallyUpdated), true)
        XCTAssertNotNil(rejectedLocal?[kSyncTargetLastError])
        assertClean(try record(ACCOUNTS_SOUP, otherId))
    }

    func test_givenUpdateOfNonexistentServerId_whenReplayed_thenRecordLevelError() throws {
        let id = try createOnServer(ACCOUNT_TYPE, [NAME: prefix + "g"])
        try seedServerRecord(ACCOUNTS_SOUP, id: id, type: ACCOUNT_TYPE, fields: [NAME: prefix + "g"])
        let gone = send(RestClient.shared.requestForDelete(withObjectType: ACCOUNT_TYPE, objectId: id, apiVersion: nil))
        XCTAssertEqual(gone.status, 204)
        try syncManager.updateLocal(soupName: ACCOUNTS_SOUP, id: id, changes: [NAME: prefix + "g_upd"])

        let sync = try runQueueSync()

        XCTAssertEqual(sync.status, .done, "a 404 on an UPDATE is a record-level error")
        let entry = try XCTUnwrap(try queueEntries().first)
        XCTAssertEqual(entry["attempts"] as? Int, 1)
        XCTAssertNotNil(entry["lastError"])
        print("LIVE-ORG: lastError of an UPDATE of a deleted record: \(String(describing: entry["lastError"]))")
    }

    // MARK: 4. Upsert with an external id

    /// An external id field that can be written, on Account or Contact.
    private func findExternalIdField() -> (type: String, field: String)? {
        for type in [ACCOUNT_TYPE, CONTACT_TYPE] {
            let describe = send(RestClient.shared.requestForDescribe(withObjectType: type, apiVersion: nil))
            let fields = (describe.body as? [String: Any])?["fields"] as? [[String: Any]] ?? []
            for field in fields where field["externalId"] as? Bool == true && field["createable"] as? Bool == true && field["name"] as? String != "Id" {
                if let name = field["name"] as? String { return (type, name) }
            }
        }
        return nil
    }

    func test_givenExternalIdField_whenCreatedTwiceThroughQueue_thenSecondRunUpdatesExistingRecord() throws {
        guard let (type, field) = findExternalIdField() else {
            throw XCTSkip("No createable external id field on Account or Contact in the test org: the upsert case is not run (no metadata is created)")
        }
        print("LIVE-ORG: external id field used: \(type).\(field)")
        let soup = type == ACCOUNT_TYPE ? ACCOUNTS_SOUP : CONTACTS_SOUP
        let nameField = type == ACCOUNT_TYPE ? NAME : LAST_NAME
        let extValue = prefix + "ext"
        func record(_ name: String) -> [String: Any] { return ["attributes": ["type": type], nameField: prefix + name, field: extValue] }
        let target = QueueSyncUpTarget()
        target.externalIdFieldName = field

        _ = try syncManager.createLocal(soupName: soup, record: record("first"))
        var sync = try runQueueSync(target: target)
        XCTAssertEqual(sync.status, .done)
        let serverId = try XCTUnwrap(idsOnServer(type, field: field, value: extValue).first)
        XCTAssertEqual(try queueEntries().count, 0)
        assertClean(try self.record(soup, serverId))

        // What the server answers to a repeated upsert (same request as the replay sends)
        let direct = send(RestClient.shared.requestForUpsert(withObjectType: type, externalIdField: field, externalId: extValue, fields: [nameField: prefix + "direct"], apiVersion: nil))
        print("LIVE-ORG: repeated upsert answers \(direct.status) \(String(describing: direct.body))")
        XCTAssertEqual(direct.status, 204)

        _ = try syncManager.createLocal(soupName: soup, record: record("second"))
        sync = try runQueueSync(target: target)

        XCTAssertEqual(sync.status, .done)
        XCTAssertEqual(idsOnServer(type, field: field, value: extValue), [serverId], "still one record on the server")
        XCTAssertEqual(serverRecord(type, serverId, fields: nameField).1?[nameField] as? String, prefix + "second")
        XCTAssertEqual(try queueEntries().count, 0)
        XCTAssertEqual(try allRecords(soup).count, 1, "the local row of the second create was merged onto the existing server id")
        assertClean(try self.record(soup, serverId))
    }
}
