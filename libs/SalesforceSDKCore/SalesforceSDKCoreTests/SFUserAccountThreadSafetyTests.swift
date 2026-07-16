/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import XCTest
@testable import SalesforceSDKCore

class UserAccountThreadSafetyTests: XCTestCase {
    var account: UserAccount!
    var poolA: [NotificationType]!
    var poolB: [NotificationType]!

    override func setUp() {
        super.setUp()

        let credentials = OAuthCredentials(identifier: "thread-safety-test", clientId: "test-client-id", encrypted: true)!
        credentials.userId = "005R0000000ThreadSafety"
        credentials.organizationId = "00D000000ThreadSafety"
        credentials.identityUrl = URL(string: "https://login.salesforce.com/id/00D000000ThreadSafety/005R0000000ThreadSafety")
        account = UserAccount(credentials: credentials)

        poolA = (0..<50).map { i in
            NotificationType(type: "type-A-\(i)", apiName: "TypeA\(i)", label: "Type A \(i)", actionGroups: nil)
        }

        poolB = (0..<50).map { i in
            NotificationType(type: "type-B-\(i)", apiName: "TypeB\(i)", label: "Type B \(i)", actionGroups: nil)
        }
    }

    override func tearDown() {
        account = nil
        poolA = nil
        poolB = nil
        super.tearDown()
    }

    func test_notificationTypes_concurrent_reads_and_writes_do_not_crash() {
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)

        for _ in 0..<8 {
            group.enter()
            queue.async {
                for i in 0..<10000 {
                    self.account.notificationTypes = (i % 2 == 0) ? self.poolA : self.poolB
                }
                group.leave()
            }

            group.enter()
            queue.async {
                for _ in 0..<10000 {
                    let snapshot = self.account.notificationTypes
                    _ = snapshot?.count
                }
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 30)
        XCTAssertEqual(.success, result, "Concurrent reads and writes timed out")
    }

    func test_setNotificationTypes_takes_a_snapshot() {
        var mutableArray: [NotificationType] = []

        let type1 = NotificationType(type: "type1", apiName: "Type1", label: "Type One", actionGroups: nil)
        let type2 = NotificationType(type: "type2", apiName: "Type2", label: "Type Two", actionGroups: nil)
        mutableArray.append(type1)
        mutableArray.append(type2)

        account.notificationTypes = mutableArray

        let snapshotAfterSet = account.notificationTypes
        XCTAssertEqual(snapshotAfterSet?.count, 2)

        let type3 = NotificationType(type: "type3", apiName: "Type3", label: "Type Three", actionGroups: nil)
        mutableArray.append(type3)

        let snapshotAfterMutate = account.notificationTypes
        XCTAssertEqual(snapshotAfterMutate?.count, 2, "Snapshot should remain unchanged after external mutation")
    }

    func test_notificationTypes_returns_assigned_value_after_drain() {
        let arrayA = [NotificationType(type: "approval", apiName: "Approval", label: "Approval Request", actionGroups: nil)]

        account.notificationTypes = arrayA
        let readA = account.notificationTypes
        XCTAssertEqual(readA?.count, arrayA.count)
        XCTAssertEqual(readA?.first?.type, arrayA.first?.type)

        let arrayB = [
            NotificationType(type: "task", apiName: "Task", label: "Task Assignment", actionGroups: nil),
            NotificationType(type: "case", apiName: "Case", label: "Case Update", actionGroups: nil)
        ]

        account.notificationTypes = arrayB
        let readB = account.notificationTypes
        XCTAssertEqual(readB?.count, arrayB.count)
        XCTAssertEqual(readB?.first?.type, arrayB.first?.type)
    }

    func test_encodeWithCoder_under_contention_does_not_throw() {
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)

        group.enter()
        queue.async {
            for i in 0..<5000 {
                self.account.notificationTypes = (i % 2 == 0) ? self.poolA : self.poolB
            }
            group.leave()
        }

        var lastEncodedData: Data?

        for _ in 0..<500 {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: account!, requiringSecureCoding: true)
                XCTAssertFalse(data.isEmpty, "Encode should succeed under contention")
                lastEncodedData = data
            } catch {
                XCTFail("Encode should not throw exception: \(error)")
            }
        }

        let result = group.wait(timeout: .now() + 30)
        XCTAssertEqual(.success, result, "Background write thread timed out")

        if let data = lastEncodedData {
            do {
                let decoded = try NSKeyedUnarchiver.unarchivedObject(ofClass: UserAccount.self, from: data)
                XCTAssertNotNil(decoded, "Should decode last encoded account")

                if let types = decoded?.notificationTypes {
                    XCTAssertFalse(types.isEmpty, "Decoded notificationTypes should not be empty under contention")
                }
            } catch {
                XCTFail("Decode should not error: \(error)")
            }
        }
    }
}
