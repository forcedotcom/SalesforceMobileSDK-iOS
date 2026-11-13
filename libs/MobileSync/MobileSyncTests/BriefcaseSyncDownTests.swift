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
import SmartStore

let briefcaseAccountInfo = BriefcaseObjectInfo(soupName: ACCOUNTS_SOUP, sobjectType: ACCOUNT_TYPE, fieldlist: [NAME, DESCRIPTION])
let briefcaseContactInfo = BriefcaseObjectInfo(soupName: CONTACTS_SOUP, sobjectType: CONTACT_TYPE, fieldlist: [LAST_NAME])

class BriefcaseSyncDownTests: SyncManagerTestCase {

    override func setUpWithError() throws {
        super.setUp()
        try cleanRecordsOnServer()
        createAccountsSoup()
        createContactsSoup()
    }
    
    override func tearDown() {
        dropAccountsSoup()
        dropContactsSoup()
        super.tearDown()
    }
    
    override func createRecordName(_ objectType: String!) -> String! {
        return "BriefcaseTest_\(objectType ?? "")_\(Date().timeIntervalSince1970)"
    }
    
    func testStartFetchWithMaxTimestamp() throws {
        let numberAccounts: UInt = 5
        
        // Make records older than timestamp
        let accounts = try XCTUnwrap(createRecords(onServer: numberAccounts, objectType: ACCOUNT_TYPE))
        XCTAssertEqual(Int(numberAccounts), accounts.count)
        
        let target = BriefcaseSyncDownTarget(infos: [briefcaseAccountInfo], countIdsPerRetrieve: 2000)
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let records = try startFetch(target: target, syncManager: syncManager, maxTimestamp: timestamp)
        XCTAssert(records.isEmpty)
        
        // Timestamp are rounded to the second so sleep so we need to sleep a bit
        // before creating new accounts
        Thread.sleep(forTimeInterval: 1.0)

        // Make records newer than timestamp
        let newAccounts = try XCTUnwrap(createRecords(onServer: numberAccounts, objectType: ACCOUNT_TYPE))
        XCTAssertEqual(Int(numberAccounts), newAccounts.count)
        let newRecords = try startFetch(target: target, syncManager: syncManager, maxTimestamp: timestamp)
        XCTAssertEqual(newRecords.count, Int(numberAccounts))
        for record in newRecords {
            let id = try XCTUnwrap(record[ID] as? String)
            let name = try XCTUnwrap(record[NAME] as? String)
            XCTAssertEqual(newAccounts[id], name)
        }
    }
    
    func testStartFetchWithoutMaxTimestamp() throws {
        let numberAccounts: UInt = 12
        let accounts = try XCTUnwrap(createRecords(onServer: numberAccounts, objectType: ACCOUNT_TYPE))
        XCTAssertEqual(Int(numberAccounts), accounts.count)
        
        let target = BriefcaseSyncDownTarget(infos: [briefcaseAccountInfo], countIdsPerRetrieve: 2000)
        let briefcaseRecords = try startFetch(target: target, syncManager: syncManager, maxTimestamp: 0)
        XCTAssertEqual(Int(numberAccounts), briefcaseRecords.count)
        
        for briefcaseRecord in briefcaseRecords {
            let id = try XCTUnwrap(briefcaseRecord[ID] as? String)
            let name = try XCTUnwrap(briefcaseRecord[NAME] as? String)
            XCTAssertEqual(accounts[id], name)
        }
    }
    
    func testSyncDownFetchingTwoObjectTypes() throws {
        try syncDownFetchingTwoObjectTypes(numberAccounts: 12, numberContacts: 12, idsPerRetrieve: 500, numberFetches: 1)
    }
    
    func testSyncDownFetchingTwoObjectTypesMultipleRetrieveCalls() throws {
        try syncDownFetchingTwoObjectTypes(numberAccounts: 12, numberContacts: 12, idsPerRetrieve: 3, numberFetches: 8)
    }
    
    func testCleanGhostsOneObjectType() throws {
        // Create accounts on server
        let numberAccounts: UInt = 4
        let accounts = try XCTUnwrap(createAccounts(onServer: numberAccounts))
        XCTAssertEqual(Int(numberAccounts), accounts.count)
        let accountIds = Array(accounts.keys)
        
        // Sync
        let target = BriefcaseSyncDownTarget(infos: [briefcaseAccountInfo])
        let syncId = trySyncDown(SyncMergeMode.leaveIfChanged, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(accounts.count), numberFetches: 1)
        checkDbExists(ACCOUNTS_SOUP, ids: accountIds, idField: ID)
        
        // Delete some accounts
        let deletedAccounts = Array(accountIds[0..<2])
        deleteAccounts(onServer: deletedAccounts)
        
        // Create more accounts locally
        let localAccounts = try XCTUnwrap(createAccountsLocally(["local_1", "local_2"]) as? [[String: Any]])
        let localAccountIds = localAccounts.compactMap { $0[ID] }
        XCTAssertEqual(localAccountIds.count, 2)
        
        // Clean ghosts
        let expectation = expectation(description: "clean ghosts")
        try syncManager.cleanResyncGhosts(forId: syncId as NSNumber) { _, _ in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 30)
        
        // Synced records and local records are still present while ghosts are deleted
        checkDbDeleted(ACCOUNTS_SOUP, ids: deletedAccounts, idField: ID)
        checkDbExists(ACCOUNTS_SOUP, ids: Array(accountIds[2...]), idField: ID)
        checkDbExists(ACCOUNTS_SOUP, ids: localAccountIds, idField: ID)
    }
    
    func testCleanGhostsTwoObjectTypes() throws {
        // Create accounts on server
        let numberRecords: UInt = 4
        let accounts = try XCTUnwrap(createAccounts(onServer: numberRecords))
        let contacts = try XCTUnwrap(createRecords(onServer: numberRecords, objectType: CONTACT_TYPE))
        XCTAssertEqual(Int(numberRecords), accounts.count)
        XCTAssertEqual(Int(numberRecords), contacts.count)
        let accountIds = Array(accounts.keys)
        let contactIds = Array(contacts.keys)

        // Sync
        let target = BriefcaseSyncDownTarget(infos: [briefcaseAccountInfo, briefcaseContactInfo])
        let syncId = trySyncDown(SyncMergeMode.leaveIfChanged, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(accounts.count + contacts.count), numberFetches: 1)
        checkDbExists(ACCOUNTS_SOUP, ids: Array(accountIds), idField: ID)
        checkDbExists(CONTACTS_SOUP, ids: Array(contactIds), idField: ID)

        // Delete some records
        let deletedAccounts = Array(accountIds[0..<2])
        deleteAccounts(onServer: deletedAccounts)
        let deletedContacts = Array(contactIds[2...])
        deleteRecords(onServer: deletedContacts, objectType: CONTACT_TYPE)

        // Create more accounts locally
        let localAccounts = try XCTUnwrap(createAccountsLocally(["local_1", "local_2"]) as? [[String: Any]])
        let localAccountIds = localAccounts.compactMap { $0[ID] }
        XCTAssertEqual(localAccountIds.count, 2)
        let localContacts = try XCTUnwrap(createContacts(forAccountsLocally: localAccountIds, numberOfContactsPerAccounts:2) as? [[String: Any]])
        let localContactIds = localContacts.compactMap { $0[ID] }
        XCTAssertEqual(localContactIds.count, 4)

        // Clean ghosts
        let expectation = expectation(description: "clean ghosts")
        try syncManager.cleanResyncGhosts(forId: syncId as NSNumber) { _, _ in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 30)

        // Synced records and local records are still present while ghosts are deleted
        checkDbDeleted(ACCOUNTS_SOUP, ids: deletedAccounts, idField: ID)
        checkDbDeleted(CONTACTS_SOUP, ids: deletedContacts, idField: ID)

        checkDbExists(ACCOUNTS_SOUP, ids: Array(accountIds[2...]), idField: ID)
        checkDbExists(CONTACTS_SOUP, ids: Array(contactIds[0..<2]), idField: ID)

        checkDbExists(ACCOUNTS_SOUP, ids: localAccountIds, idField: ID)
        checkDbExists(CONTACTS_SOUP, ids: localContactIds, idField: ID)
    }
    
    func testIdsToSkip() throws {
        let numberOfRecords = 12
        let syncResult = try syncDownFetchingTwoObjectTypes(numberAccounts: numberOfRecords, numberContacts: numberOfRecords, idsPerRetrieve: 500, numberFetches: 1)
        XCTAssertEqual(numberOfRecords, syncResult.accountIds.count)
        XCTAssertEqual(numberOfRecords, syncResult.contactIds.count)
        let target = try XCTUnwrap(syncManager.syncStatus(forId: syncResult.syncId as NSNumber)?.target as? SyncDownTarget)
        
        // No dirty records
        var idsToSkip = target.getIdsToSkip(syncManager, soupName: "")
        XCTAssert(idsToSkip.set.isEmpty)
        
        // Make local changes
        let deleteAccountIds = Array(syncResult.accountIds[0..<2])
        let deleteContactIds = Array(syncResult.contactIds[2..<4])
        deleteAccountsLocally(deleteAccountIds)
        deleteRecordsLocally(deleteContactIds, soupName: CONTACTS_SOUP)
        
        // Verify dirty records are returned
        idsToSkip = target.getIdsToSkip(syncManager, soupName: "")
        XCTAssertTrue(Set(deleteAccountIds).isSubset(of: idsToSkip.set))
        XCTAssertTrue(Set(deleteContactIds).isSubset(of: idsToSkip.set))
    }
    
    func startFetch(target: SyncDownTarget, syncManager: SyncManager, maxTimestamp: Int64) throws -> [[String: Any]] {
        let expectation = expectation(description: "fetch")
        var result: [Any]?
        target.startFetch(syncManager: syncManager, maxTimeStamp: maxTimestamp) { error in
            XCTFail("Fetch failed with error: \(error?.localizedDescription ?? "")")
            expectation.fulfill()
        } onComplete: { records in
            result = records
            expectation.fulfill()
        }
        waitForExpectations(timeout: 30)
        guard let records = result as? [[String: Any]] else {
            XCTFail("Unable to parse record response")
            return []
        }
        return records
    }
    
    func cleanRecordsOnServer() throws {
        try deleteRecordsByCriteriaFromServer(objectType: ACCOUNT_TYPE, criteria: "Name like 'BriefcaseTest_%' AND CreatedById = '\(RestClient.shared.userAccount.accountIdentity.userId)'")
        try deleteRecordsByCriteriaFromServer(objectType: CONTACT_TYPE, criteria: "LastName like 'BriefcaseTest_%' AND CreatedById = '\(RestClient.shared.userAccount.accountIdentity.userId)'")
    }
    
    func deleteRecordsByCriteriaFromServer(objectType: String, criteria: String) throws {
        let ids = try idsOnServer(objectType: objectType, criteria: criteria)
        deleteRecords(onServer: ids, objectType: objectType)
    }
    
    func idsOnServer(objectType: String, criteria: String) throws -> [String]  {
        let query = "SELECT Id FROM \(objectType) WHERE \(criteria)"
        let request = RestClient.shared.request(forQuery: query, apiVersion: nil)
        let records = try XCTUnwrap(sendSyncRequest(request)?["records"] as? [[String: Any]])
        
        
        return records.compactMap({ record in
            return record[ID] as? String
        })
    }
    
    @discardableResult
    func syncDownFetchingTwoObjectTypes(numberAccounts: Int, numberContacts: Int, idsPerRetrieve: Int, numberFetches: Int) throws -> (syncId: Int, accountIds: [String], contactIds: [String]) {
        let accounts = try XCTUnwrap(createRecords(onServer: UInt(numberAccounts), objectType: ACCOUNT_TYPE))
        XCTAssertEqual(numberAccounts, accounts.count)
        
        let contacts = try XCTUnwrap(createRecords(onServer: UInt(numberContacts), objectType: CONTACT_TYPE))
        XCTAssertEqual(numberContacts, contacts.count)
        
        let target = BriefcaseSyncDownTarget(infos: [briefcaseAccountInfo, briefcaseContactInfo], countIdsPerRetrieve: idsPerRetrieve)

        let syncId = trySyncDown(SyncMergeMode.leaveIfChanged, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(contacts.count + accounts.count), numberFetches: UInt(numberFetches))
        let accountIds = Array(accounts.keys)
        let contactIds = Array(contacts.keys)
        checkDbExists(ACCOUNTS_SOUP, ids: accountIds, idField: ID)
        checkDbExists(CONTACTS_SOUP, ids: contactIds, idField: ID)
        return (syncId: syncId, accountIds: accountIds, contactIds: contactIds)
    }
}

// MARK: - Paging and error handling tests (no server needed)

/// RestClient returning canned responses
private class CannedResponsesRestClient: RestClient {
    var responder: (RestRequest) -> Result<Any, Error> = { _ in .success([:]) }
    private let lock = NSLock()
    private var recordedRequests: [RestRequest] = []

    var requests: [RestRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    var primingRequests: [RestRequest] {
        return requests.filter { $0.path.hasSuffix("priming-records") }
    }

    override func send(_ request: RestRequest, failureBlock: @escaping RestRequestFailBlock, successBlock: @escaping RestResponseBlock) {
        lock.lock()
        recordedRequests.append(request)
        lock.unlock()
        let urlResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, mimeType: "application/json", expectedContentLength: 0, textEncodingName: "utf-8")
        switch responder(request) {
        case .success(let json):
            // Mimics the parsing done by the real client
            if request.parseResponse {
                successBlock(json, urlResponse)
            } else {
                successBlock(try? JSONSerialization.data(withJSONObject: json), urlResponse)
            }
        case .failure(let error):
            failureBlock(nil, error, urlResponse)
        }
    }
}

class BriefcaseSyncDownPagingTests: XCTestCase {
    private static let storeName = "BriefcaseSyncDownPagingTests"
    private var store: SmartStore!
    private var syncManager: SyncManager!
    private var restClient: CannedResponsesRestClient!

    private struct PrimingPage {
        let ids: [(type: String, id: String)]
        let relayToken: String?
    }

    private struct Batches {
        var ids: [[String]] = []
        var finalCompletionReceived = false
    }

    override func setUpWithError() throws {
        store = try XCTUnwrap(SmartStore.sharedGlobal(withName: BriefcaseSyncDownPagingTests.storeName))
        syncManager = try XCTUnwrap(SyncManager.sharedInstance(store: store))
        restClient = CannedResponsesRestClient()
        let client = restClient!
        BriefcaseSyncDownTarget.defaultRestClientProvider = { client }
    }

    override func tearDown() {
        BriefcaseSyncDownTarget.defaultRestClientProvider = { RestClient.shared }
        SyncManager.removeSharedInstance(store: store)
        SmartStore.removeSharedGlobal(withName: BriefcaseSyncDownPagingTests.storeName)
        super.tearDown()
    }

    // MARK: helpers

    private func makeTarget(infos: [BriefcaseObjectInfo] = [briefcaseAccountInfo], countIdsPerRetrieve: Int = 2000) -> BriefcaseSyncDownTarget {
        let target = BriefcaseSyncDownTarget(infos: infos, countIdsPerRetrieve: countIdsPerRetrieve)
        let client = restClient!
        target.restClientProvider = { client }
        return target
    }

    private func primingJson(_ page: PrimingPage) -> [String: Any] {
        var primingRecords: [String: Any] = [:]
        for (type, id) in page.ids {
            var byRecordType = primingRecords[type] as? [String: Any] ?? [:]
            var records = byRecordType["012000000000000AAA"] as? [[String: Any]] ?? []
            records.append(["id": id, "systemModstamp": "2021-08-23T18:42:32.000Z"])
            byRecordType["012000000000000AAA"] = records
            primingRecords[type] = byRecordType
        }
        var json: [String: Any] = ["primingRecords": primingRecords, "ruleErrors": [], "stats": [:]]
        if let relayToken = page.relayToken {
            json["relayToken"] = relayToken
        }
        return json
    }

    /// Serves the given priming pages (selected by the relay token of the request) and successful collection retrieves
    private func serve(pages: [PrimingPage], firstToken: String? = nil) {
        var pagesByToken: [String: PrimingPage] = [:]
        var previousToken: String? = firstToken
        for page in pages {
            pagesByToken[previousToken ?? ""] = page
            previousToken = page.relayToken
        }
        restClient.responder = { [weak self] request in
            guard let self = self else { return .failure(BriefcaseSyncDownError.unknownResponse) }
            if request.path.hasSuffix("priming-records") {
                let token = request.queryParams?["relayToken"] as? String ?? ""
                return pagesByToken[token].map { .success(self.primingJson($0)) } ?? .failure(BriefcaseSyncDownError.unknownResponse)
            }
            return .success(self.retrievedRecords(for: request))
        }
    }

    private func requestedIds(_ request: RestRequest) -> [String] {
        let body = (request as AnyObject).value(forKey: "requestBodyAsDictionary") as? [String: Any]
        return body?["ids"] as? [String] ?? []
    }

    private func requestedType(_ request: RestRequest) -> String {
        return request.path.components(separatedBy: "/").last ?? ""
    }

    private func retrievedRecords(for request: RestRequest) -> [[String: Any]] {
        let type = requestedType(request)
        return requestedIds(request).map { ["attributes": ["type": type], "Id": $0, "Name": "name-\($0)"] }
    }

    private func idsOf(_ records: [Any]?) -> [String] {
        return (records as? [[String: Any]])?.compactMap { $0["Id"] as? String } ?? []
    }

    /// Calls startFetch then continueFetch until completion is called with nil
    private func fetchEverything(target: BriefcaseSyncDownTarget, maxTimestamp: Int64 = 0) -> Batches {
        var batches = Batches()
        var maxCalls = 20
        var first = true
        while !batches.finalCompletionReceived && maxCalls > 0 {
            maxCalls -= 1
            let expectation = expectation(description: "fetch")
            let onFail: SyncDownErrorBlock = { error in
                XCTFail("Fetch failed with error: \(error?.localizedDescription ?? "")")
                expectation.fulfill()
            }
            let onComplete: SyncDownCompletionBlock = { records in
                if let records = records {
                    batches.ids.append(self.idsOf(records))
                } else {
                    batches.finalCompletionReceived = true
                }
                expectation.fulfill()
            }
            if first {
                target.startFetch(syncManager: syncManager, maxTimeStamp: maxTimestamp, onFail: onFail, onComplete: onComplete)
                first = false
            } else {
                target.continueFetch(syncManager: syncManager, onFail: onFail, onComplete: onComplete)
            }
            waitForExpectations(timeout: 10)
        }
        return batches
    }

    // MARK: paging

    func test_givenTwoPagesOfPrimingRecords_whenStartFetchThenContinueFetch_thenRecordsFromBothPagesReturned() {
        serve(pages: [PrimingPage(ids: [(ACCOUNT_TYPE, "001A"), (ACCOUNT_TYPE, "001B")], relayToken: "token-1"),
                      PrimingPage(ids: [(ACCOUNT_TYPE, "001C")], relayToken: nil)])
        let target = makeTarget()

        let batches = fetchEverything(target: target)

        XCTAssertEqual(batches.ids.count, 2)
        XCTAssertEqual(Set(batches.ids.first ?? []), ["001A", "001B"])
        XCTAssertEqual(batches.ids.last, ["001C"])
        XCTAssertTrue(batches.finalCompletionReceived)
        let primingRequests = restClient.primingRequests
        XCTAssertEqual(primingRequests.count, 2)
        XCTAssertNil(primingRequests.first?.queryParams?["relayToken"])
        XCTAssertEqual(primingRequests.last?.queryParams?["relayToken"] as? String, "token-1")
    }

    func test_givenThreePagesAndSmallCountIdsPerRetrieve_whenContinueFetchRepeatedly_thenAllSlicesAndPagesFetchedOnce() {
        serve(pages: [PrimingPage(ids: [(ACCOUNT_TYPE, "001A"), (ACCOUNT_TYPE, "001B"), (ACCOUNT_TYPE, "001C")], relayToken: "token-1"),
                      PrimingPage(ids: [(ACCOUNT_TYPE, "001D"), (ACCOUNT_TYPE, "001E")], relayToken: "token-2"),
                      PrimingPage(ids: [(ACCOUNT_TYPE, "001F")], relayToken: nil)])
        let target = makeTarget(countIdsPerRetrieve: 2)

        let batches = fetchEverything(target: target)

        XCTAssertEqual(batches.ids.map { $0.count }, [2, 1, 2, 1])
        XCTAssertEqual(batches.ids.flatMap { $0 }.sorted(), ["001A", "001B", "001C", "001D", "001E", "001F"])
        XCTAssertTrue(batches.finalCompletionReceived)
        XCTAssertEqual(restClient.primingRequests.map { $0.queryParams?["relayToken"] as? String }, [nil, "token-1", "token-2"])
    }

    func test_givenRelayTokenAndMaxTimestamp_whenContinueFetch_thenPrimingRequestHasBothParams() {
        serve(pages: [PrimingPage(ids: [(ACCOUNT_TYPE, "001A")], relayToken: "token-1"),
                      PrimingPage(ids: [(ACCOUNT_TYPE, "001B")], relayToken: nil)])
        let target = makeTarget()

        _ = fetchEverything(target: target, maxTimestamp: 1629744152000)

        let primingRequests = restClient.primingRequests
        XCTAssertEqual(primingRequests.count, 2)
        XCTAssertNotNil(primingRequests.first?.queryParams?["changedAfterTimestamp"])
        XCTAssertNil(primingRequests.first?.queryParams?["relayToken"])
        XCTAssertNotNil(primingRequests.last?.queryParams?["changedAfterTimestamp"])
        XCTAssertEqual(primingRequests.last?.queryParams?["relayToken"] as? String, "token-1")
    }

    func test_givenMaxTimestampZero_whenStartFetch_thenPrimingRequestHasNoChangedAfterTimestamp() {
        serve(pages: [PrimingPage(ids: [(ACCOUNT_TYPE, "001A")], relayToken: nil)])
        let target = makeTarget()

        _ = fetchEverything(target: target, maxTimestamp: 0)

        XCTAssertEqual(restClient.primingRequests.count, 1)
        XCTAssertNil(restClient.primingRequests.first?.queryParams?["changedAfterTimestamp"])
    }

    func test_givenMultiplePagesAndNoRelayTokenOnLastPage_whenContinueFetch_thenCompletesWithNil() {
        serve(pages: [PrimingPage(ids: [(ACCOUNT_TYPE, "001A")], relayToken: "token-1"),
                      PrimingPage(ids: [(ACCOUNT_TYPE, "001B")], relayToken: nil)])
        let target = makeTarget()

        let batches = fetchEverything(target: target)
        XCTAssertTrue(batches.finalCompletionReceived)
        let priming = restClient.primingRequests.count

        // Nothing more to fetch
        let expectation = expectation(description: "continueFetch")
        target.continueFetch(syncManager: syncManager, onFail: { _ in XCTFail("Unexpected failure") }) { records in
            XCTAssertNil(records)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10)
        XCTAssertEqual(restClient.primingRequests.count, priming)
    }

    func test_givenTwoPages_whenFetchingBothPages_thenTotalSizeIsCountOfAllDiscoveredIds() {
        serve(pages: [PrimingPage(ids: [(ACCOUNT_TYPE, "001A"), (ACCOUNT_TYPE, "001B")], relayToken: "token-1"),
                      PrimingPage(ids: [(ACCOUNT_TYPE, "001C")], relayToken: nil)])
        let target = makeTarget()

        _ = fetchEverything(target: target)

        XCTAssertEqual(target.totalSize, 3)
    }

    func test_givenTargetAlreadyUsed_whenStartFetchAgain_thenFetchRestartsFromFirstPage() {
        serve(pages: [PrimingPage(ids: [(ACCOUNT_TYPE, "001A"), (ACCOUNT_TYPE, "001B"), (ACCOUNT_TYPE, "001C")], relayToken: "token-1"),
                      PrimingPage(ids: [(ACCOUNT_TYPE, "001D")], relayToken: nil)])
        let target = makeTarget(countIdsPerRetrieve: 2)

        // Start a fetch but abandon it after the first slice
        let expectation = expectation(description: "first slice")
        target.startFetch(syncManager: syncManager, maxTimeStamp: 0, onFail: { _ in XCTFail("Unexpected failure") }) { _ in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10)

        let batches = fetchEverything(target: target)
        XCTAssertEqual(batches.ids.flatMap { $0 }.sorted(), ["001A", "001B", "001C", "001D"])
    }

    // MARK: through SyncManager (sync lifecycle)

    func test_givenTwoPagesOfPrimingRecords_whenSyncDown_thenRecordsFromBothPagesSavedAndSyncDoneAfterLastPage() throws {
        let soupName = "BriefcasePagingAccounts"
        let indexSpecs: [SoupIndex?] = [SoupIndex(path: ID, indexType: kSoupIndexTypeString, columnName: nil),
                          SoupIndex(path: kSyncTargetLocal, indexType: kSoupIndexTypeString, columnName: nil),
                          SoupIndex(path: kSyncTargetSyncId, indexType: kSoupIndexTypeInteger, columnName: nil)]
        XCTAssertNoThrow(try store.registerSoup(withName: soupName, withIndices: indexSpecs.compactMap { $0 }))
        defer { store.removeSoup(soupName) }
        let info = BriefcaseObjectInfo(soupName: soupName, sobjectType: ACCOUNT_TYPE, fieldlist: [NAME])
        serve(pages: [PrimingPage(ids: [(ACCOUNT_TYPE, "001A"), (ACCOUNT_TYPE, "001B"), (ACCOUNT_TYPE, "001C")], relayToken: "token-1"),
                      PrimingPage(ids: [(ACCOUNT_TYPE, "001D"), (ACCOUNT_TYPE, "001E")], relayToken: "token-2"),
                      PrimingPage(ids: [(ACCOUNT_TYPE, "001F")], relayToken: nil)])
        let target = makeTarget(infos: [info], countIdsPerRetrieve: 2)

        let doneExpectation = expectation(description: "sync done")
        doneExpectation.assertForOverFulfill = false
        var statuses: [SyncStatus] = []
        let lock = NSLock()
        let syncState = syncManager.syncDown(target: target, soupName: soupName) { sync in
            lock.lock()
            statuses.append(sync.status)
            lock.unlock()
            if sync.status == .done || sync.status == .failed {
                doneExpectation.fulfill()
            }
        }
        XCTAssertNotNil(syncState)
        waitForExpectations(timeout: 10)

        lock.lock()
        let finalStatuses = statuses
        lock.unlock()
        XCTAssertEqual(finalStatuses.last, .done)
        XCTAssertEqual(finalStatuses.filter { $0 == .done }.count, 1)
        let query = QuerySpec.buildAllQuerySpec(soupName: soupName, orderPath: ID, order: .ascending, pageSize: 100)
        let saved = (try? store.query(using: query, startingFromPageIndex: 0) as? [[String: Any]]) ?? []
        XCTAssertEqual(saved.compactMap { $0[ID] as? String }, ["001A", "001B", "001C", "001D", "001E", "001F"])
        XCTAssertEqual(restClient.primingRequests.count, 3)
    }

    // MARK: errors

    func test_givenTwoObjectTypesAndBothRetrievesFail_whenFetch_thenErrorBlockCalledOnceAndCompleteNotCalled() {
        serve(pages: [PrimingPage(ids: [(ACCOUNT_TYPE, "001A"), (CONTACT_TYPE, "003A")], relayToken: nil)])
        let primingResponder = restClient.responder
        restClient.responder = { request in
            return request.path.hasSuffix("priming-records") ? primingResponder(request) : .failure(NSError(domain: "test", code: 42))
        }
        let target = makeTarget(infos: [briefcaseAccountInfo, briefcaseContactInfo])
        let errorExpectation = expectation(description: "error")
        errorExpectation.assertForOverFulfill = true
        let completeExpectation = expectation(description: "complete")
        completeExpectation.isInverted = true
        var errors: [Error?] = []

        target.startFetch(syncManager: syncManager, maxTimeStamp: 0, onFail: { error in
            errors.append(error)
            errorExpectation.fulfill()
        }, onComplete: { _ in
            completeExpectation.fulfill()
        })

        wait(for: [errorExpectation, completeExpectation], timeout: 2)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(((errors.first ?? nil) as NSError?)?.code, 42)
    }

    func test_givenNonArrayCollectionRetrieveResponse_whenFetch_thenErrorBlockCalledWithUnknownResponse() {
        serve(pages: [PrimingPage(ids: [(ACCOUNT_TYPE, "001A")], relayToken: nil)])
        let primingResponder = restClient.responder
        restClient.responder = { request in
            return request.path.hasSuffix("priming-records") ? primingResponder(request) : .success(["unexpected": "dictionary"])
        }
        let target = makeTarget()
        let errorExpectation = expectation(description: "error")
        errorExpectation.assertForOverFulfill = true
        var errors: [Error?] = []

        target.startFetch(syncManager: syncManager, maxTimeStamp: 0, onFail: { error in
            errors.append(error)
            errorExpectation.fulfill()
        }, onComplete: { _ in
            XCTFail("Unexpected completion")
        })

        waitForExpectations(timeout: 10)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual((errors.first ?? nil) as? BriefcaseSyncDownError, .unknownResponse)
    }

    func test_givenPrimingRecordsFailure_whenStartFetch_thenErrorBlockCalledOnce() {
        restClient.responder = { _ in .failure(NSError(domain: "test", code: 43)) }
        let target = makeTarget()
        let errorExpectation = expectation(description: "error")
        errorExpectation.assertForOverFulfill = true
        var errorCount = 0

        target.startFetch(syncManager: syncManager, maxTimeStamp: 0, onFail: { _ in
            errorCount += 1
            errorExpectation.fulfill()
        }, onComplete: { _ in
            XCTFail("Unexpected completion")
        })

        waitForExpectations(timeout: 10)
        XCTAssertEqual(errorCount, 1)
    }
}
