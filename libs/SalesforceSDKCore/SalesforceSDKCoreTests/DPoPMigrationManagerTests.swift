//
//  DPoPMigrationManagerTests.swift
//  SalesforceSDKCoreTests
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

import XCTest
@testable import SalesforceSDKCore

class DPoPMigrationManagerTests: XCTestCase {

    private var user: UserAccount?
    private var upgradeCalls = 0
    private var pendingSuccess: ((UserAccount) -> Void)?
    private var pendingFailure: ((Error) -> Void)?
    private var manager: DPoPMigrationManager!

    private struct TestError: Error {}

    override func setUp() {
        super.setUp()
        user = nil
        upgradeCalls = 0
        pendingSuccess = nil
        pendingFailure = nil
        manager = DPoPMigrationManager(currentUser: { [unowned self] in self.user },
                                       upgrade: { [unowned self] _, success, failure in
            self.upgradeCalls += 1
            self.pendingSuccess = success
            self.pendingFailure = failure
        })
    }

    override func tearDown() {
        manager = nil
        user = nil
        super.tearDown()
    }

    private func makeUser(tokenType: String?, userId: String = "user0") throws -> UserAccount {
        let credentials = try XCTUnwrap(OAuthCredentials(identifier: "dpop-migration-test-\(userId)", clientId: "fakeClientId", encrypted: true))
        credentials.userId = userId
        credentials.organizationId = "org0"
        credentials.tokenType = tokenType
        return UserAccount(credentials: credentials)
    }

    // MARK: - No-op cases

    func test_givenNoCurrentUser_whenMigrateIfNeeded_thenNotNeededAndNoUpgrade() async {
        let outcome = await manager.migrateIfNeeded()
        guard case .notNeeded = outcome else { return XCTFail("Expected .notNeeded, got \(outcome)") }
        XCTAssertEqual(upgradeCalls, 0)
        XCTAssertFalse(manager.isMigrationNeeded)
    }

    func test_givenDPoPBoundUser_whenMigrateIfNeeded_thenNotNeededAndNoUpgrade() async throws {
        user = try makeUser(tokenType: "DPoP")
        XCTAssertFalse(manager.isMigrationNeeded)
        let outcome = await manager.migrateIfNeeded()
        guard case .notNeeded = outcome else { return XCTFail("Expected .notNeeded, got \(outcome)") }
        XCTAssertEqual(upgradeCalls, 0)
    }

    func test_givenLowercaseDPoPTokenType_whenMigrateIfNeeded_thenNotNeeded() async throws {
        user = try makeUser(tokenType: "dpop")
        let outcome = await manager.migrateIfNeeded()
        guard case .notNeeded = outcome else { return XCTFail("Expected .notNeeded, got \(outcome)") }
        XCTAssertEqual(upgradeCalls, 0)
    }

    // MARK: - Upgrade

    func test_givenBearerUser_whenIsMigrationNeeded_thenTrue() throws {
        user = try makeUser(tokenType: "Bearer")
        XCTAssertTrue(manager.isMigrationNeeded)
        user = try makeUser(tokenType: nil)
        XCTAssertTrue(manager.isMigrationNeeded)
    }

    func test_givenBearerUserAndUpgradeSucceeds_whenMigrateIfNeeded_thenMigrated() throws {
        user = try makeUser(tokenType: "Bearer")
        let done = expectation(description: "completion")
        manager.migrateIfNeeded { outcome in
            if case .migrated = outcome {} else { XCTFail("Expected .migrated, got \(outcome)") }
            done.fulfill()
        }
        XCTAssertEqual(upgradeCalls, 1)
        pendingSuccess?(try! makeUser(tokenType: "DPoP"))
        wait(for: [done], timeout: 5)
    }

    func test_givenBearerUserAndUpgradeFails_whenMigrateIfNeeded_thenFailedWithError() throws {
        user = try makeUser(tokenType: "Bearer")
        let done = expectation(description: "completion")
        manager.migrateIfNeeded { outcome in
            if case .failed(let error) = outcome {
                XCTAssertTrue(error is TestError)
            } else {
                XCTFail("Expected .failed, got \(outcome)")
            }
            done.fulfill()
        }
        pendingFailure?(TestError())
        wait(for: [done], timeout: 5)
    }

    func test_givenFailedUpgrade_whenMigrateIfNeededAgain_thenRetries() throws {
        user = try makeUser(tokenType: "Bearer")
        let first = expectation(description: "first")
        manager.migrateIfNeeded { _ in first.fulfill() }
        pendingFailure?(TestError())
        wait(for: [first], timeout: 5)

        let second = expectation(description: "second")
        manager.migrateIfNeeded { outcome in
            if case .migrated = outcome {} else { XCTFail("Expected .migrated, got \(outcome)") }
            second.fulfill()
        }
        XCTAssertEqual(upgradeCalls, 2)
        pendingSuccess?(try! makeUser(tokenType: "DPoP"))
        wait(for: [second], timeout: 5)
    }

    // MARK: - Concurrency and threading

    func test_givenUpgradeInFlight_whenConcurrentCallers_thenSingleUpgradeAndAllCompleteOnce() throws {
        user = try makeUser(tokenType: "Bearer")
        let callerCount = 5
        let done = expectation(description: "all complete")
        done.expectedFulfillmentCount = callerCount
        done.assertForOverFulfill = true
        for _ in 0..<callerCount {
            manager.migrateIfNeeded { outcome in
                if case .failed(let error) = outcome {
                    XCTAssertTrue(error is TestError)
                } else {
                    XCTFail("Expected .failed, got \(outcome)")
                }
                done.fulfill()
            }
        }
        XCTAssertEqual(upgradeCalls, 1)
        pendingFailure?(TestError())
        wait(for: [done], timeout: 5)
        XCTAssertEqual(upgradeCalls, 1)
    }

    func test_givenCallersOnBackgroundQueues_whenMigrateIfNeeded_thenSingleUpgradeAndCompletionsOnMain() throws {
        user = try makeUser(tokenType: "Bearer")
        let callerCount = 4
        let done = expectation(description: "all complete")
        done.expectedFulfillmentCount = callerCount
        let queued = expectation(description: "all queued")
        queued.expectedFulfillmentCount = callerCount
        for _ in 0..<callerCount {
            DispatchQueue.global().async {
                self.manager.migrateIfNeeded { _ in
                    XCTAssertTrue(Thread.isMainThread)
                    done.fulfill()
                }
                DispatchQueue.main.async { queued.fulfill() }
            }
        }
        // Each queued fulfill runs after that caller's own hop to main, so all callers are registered.
        wait(for: [queued], timeout: 5)
        XCTAssertEqual(upgradeCalls, 1)
        let upgraded = try makeUser(tokenType: "DPoP")
        DispatchQueue.global().async { self.pendingSuccess?(upgraded) }
        wait(for: [done], timeout: 5)
    }

    func test_givenSDKCallbackOnBackgroundThread_whenUpgradeCompletes_thenCompletionOnMain() throws {
        user = try makeUser(tokenType: "Bearer")
        let done = expectation(description: "completion")
        manager.migrateIfNeeded { _ in
            XCTAssertTrue(Thread.isMainThread)
            done.fulfill()
        }
        let upgraded = try makeUser(tokenType: "DPoP")
        DispatchQueue.global().async { self.pendingSuccess?(upgraded) }
        wait(for: [done], timeout: 5)
    }

    func test_givenNoUserAndBackgroundCaller_whenMigrateIfNeeded_thenCompletionOnMain() {
        let done = expectation(description: "completion")
        DispatchQueue.global().async {
            self.manager.migrateIfNeeded { _ in
                XCTAssertTrue(Thread.isMainThread)
                done.fulfill()
            }
        }
        wait(for: [done], timeout: 5)
    }

    // MARK: - Review regressions

    func test_givenUpgradeReturnsBearerCredentials_whenMigrateIfNeeded_thenFailedNotDPoPBound() throws {
        user = try makeUser(tokenType: "Bearer")
        let done = expectation(description: "completion")
        manager.migrateIfNeeded { outcome in
            if case .failed(let error) = outcome, case DPoPMigrationError.notDPoPBound = error {} else {
                XCTFail("Expected .failed(.notDPoPBound), got \(outcome)")
            }
            done.fulfill()
        }
        pendingSuccess?(try! makeUser(tokenType: "Bearer"))
        wait(for: [done], timeout: 5)
    }

    func test_givenUpgradeInFlightForUserA_whenCurrentUserSwitchesToBAndMigrates_thenBFailsAndANotAffected() throws {
        user = try makeUser(tokenType: "Bearer", userId: "userA")
        let a = expectation(description: "A completes")
        manager.migrateIfNeeded { outcome in
            if case .migrated = outcome {} else { XCTFail("Expected A .migrated, got \(outcome)") }
            a.fulfill()
        }
        user = try makeUser(tokenType: "Bearer", userId: "userB")
        let b = expectation(description: "B completes")
        manager.migrateIfNeeded { outcome in
            if case .failed(let error) = outcome, case DPoPMigrationError.anotherMigrationInProgress = error {} else {
                XCTFail("Expected B .failed(.anotherMigrationInProgress), got \(outcome)")
            }
            b.fulfill()
        }
        XCTAssertEqual(upgradeCalls, 1)
        pendingSuccess?(try makeUser(tokenType: "DPoP", userId: "userA"))
        wait(for: [a, b], timeout: 5)
    }

    func test_givenUpgradeInFlight_whenAuthenticationStopped_thenWaitersCancelledAndNextCallRetries() throws {
        user = try makeUser(tokenType: "Bearer")
        let waiters = expectation(description: "waiters cancelled")
        waiters.expectedFulfillmentCount = 2
        waiters.assertForOverFulfill = true
        for _ in 0..<2 {
            manager.migrateIfNeeded { outcome in
                if case .failed(let error) = outcome, case DPoPMigrationError.cancelled = error {} else {
                    XCTFail("Expected .failed(.cancelled), got \(outcome)")
                }
                waiters.fulfill()
            }
        }
        NotificationCenter.default.post(name: UserAccountManager.didStopAuthentication, object: nil)
        wait(for: [waiters], timeout: 5)

        // Callbacks of the abandoned upgrade are ignored; a new call starts a fresh upgrade.
        let abandonedSuccess = pendingSuccess
        let retry = expectation(description: "retry")
        manager.migrateIfNeeded { outcome in
            if case .migrated = outcome {} else { XCTFail("Expected .migrated, got \(outcome)") }
            retry.fulfill()
        }
        XCTAssertEqual(upgradeCalls, 2)
        abandonedSuccess?(try makeUser(tokenType: "Bearer"))
        pendingSuccess?(try makeUser(tokenType: "DPoP"))
        wait(for: [retry], timeout: 5)
    }

    func test_givenMigrationAuthSessionActive_whenStopCurrentAuthentication_thenWaiterCancelled() throws {
        user = try makeUser(tokenType: "Bearer")
        let request = SFSDKAuthRequest()
        request.oauthClientId = "testClientId"
        request.oauthCompletionUrl = "test://callback"
        request.loginHost = "test.salesforce.com"
        let session = SFSDKAuthSession(request, credentials: nil)
        session.isAuthenticating = true
        UserAccountManager.shared.authSessions[session.sceneId as NSString] = session

        let done = expectation(description: "cancelled")
        manager.migrateIfNeeded { outcome in
            if case .failed(let error) = outcome, case DPoPMigrationError.cancelled = error {} else {
                XCTFail("Expected .failed(.cancelled), got \(outcome)")
            }
            done.fulfill()
        }
        UserAccountManager.shared.stopCurrentAuthentication()
        wait(for: [done], timeout: 5)
    }
}
