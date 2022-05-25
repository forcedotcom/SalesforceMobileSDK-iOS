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
