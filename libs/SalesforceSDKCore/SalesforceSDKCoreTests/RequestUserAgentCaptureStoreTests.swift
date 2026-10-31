/*
 RequestUserAgentCaptureStoreTests.swift
 SalesforceSDKCoreTests

 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
 */

import XCTest
@testable @_spi(Internal) import SalesforceSDKCore

#if DEBUG
final class RequestUserAgentCaptureStoreTests: XCTestCase {
    private let owner = "org/user"
    private let url = URL(string: "https://example.invalid/services/data/v66.0?private=value")!
    private let ownerPrefix = "com.salesforce.sdk.request-owner:"

    func test_givenSmallCapacity_whenCapturing_thenOnlyNewestEntriesRemain() {
        let store = RequestUserAgentCaptureStore(capacity: 2)

        for index in 1...3 {
            _ = store.capture(url: url, taskDescription: "\(ownerPrefix)\(owner)", userAgent: "ua-\(index)", onSnapshot: { _ in })
        }

        XCTAssertEqual(store.snapshot.map(\.sequence), [2, 3])
        XCTAssertEqual(store.snapshot.map(\.userAgent), ["ua-2", "ua-3"])
        XCTAssertTrue(store.snapshot.allSatisfy { $0.path == "/services/data/v66.0" })
    }

    func test_givenRetiredOwner_whenCaptureArrives_thenEntryIsRejectedUntilLogin() {
        let store = RequestUserAgentCaptureStore()
        _ = store.capture(url: url, taskDescription: "\(ownerPrefix)\(owner)", userAgent: "before", onSnapshot: { _ in })

        var retiredSnapshot: [RequestUserAgentCaptureEntry] = []
        store.retire(owner) { retiredSnapshot = $0 }
        XCTAssertTrue(retiredSnapshot.isEmpty)
        XCTAssertNil(store.capture(url: url, taskDescription: "\(ownerPrefix)\(owner)", userAgent: "late", onSnapshot: { _ in }))
        store.login(owner)
        let result = store.capture(url: url, taskDescription: "\(ownerPrefix)\(owner)", userAgent: "after", onSnapshot: { _ in })

        XCTAssertEqual(result?.sequence, 2)
        XCTAssertEqual(store.snapshot.map(\.userAgent), ["after"])
    }

    func test_givenMultipleOwners_whenOneIsRetired_thenOtherEntriesRemain() {
        let store = RequestUserAgentCaptureStore()
        _ = store.capture(url: url, taskDescription: "\(ownerPrefix)\(owner)", userAgent: "owner", onSnapshot: { _ in })
        _ = store.capture(url: url, taskDescription: "\(ownerPrefix)org/other", userAgent: "other", onSnapshot: { _ in })
        _ = store.capture(url: url, taskDescription: nil, userAgent: "unknown", onSnapshot: { _ in })

        var retiredSnapshot: [RequestUserAgentCaptureEntry] = []
        store.retire(owner) { retiredSnapshot = $0 }
        XCTAssertEqual(retiredSnapshot.map(\.userKey), ["org/other", "unknown"])
    }

    func test_givenReset_whenCaptureArrives_thenSequenceRestarts() {
        let store = RequestUserAgentCaptureStore()
        _ = store.capture(url: url, taskDescription: "\(ownerPrefix)\(owner)", userAgent: "before", onSnapshot: { _ in })

        var resetSnapshot: [RequestUserAgentCaptureEntry] = []
        store.reset { resetSnapshot = $0 }
        XCTAssertTrue(resetSnapshot.isEmpty)
        XCTAssertEqual(store.capture(url: url, taskDescription: "\(ownerPrefix)\(owner)", userAgent: "after", onSnapshot: { _ in })?.sequence, 1)
    }

    func test_givenValidAndMalformedDictionaries_whenDecoded_thenOnlyValidEntryBuilds() {
        let entry = RequestUserAgentCaptureEntry(path: "/services/oauth2/token", userKey: owner, userAgent: "ua", sequence: 7)

        XCTAssertEqual(RequestUserAgentCaptureEntry(dictionary: entry.dictionary), entry)
        XCTAssertNil(RequestUserAgentCaptureEntry(dictionary: ["path": "/services/oauth2/token"]))
    }

    func test_givenTaskDescription_whenParsingOwner_thenOnlyExpectedMetadataIsAccepted() {
        XCTAssertEqual(RequestUserAgentCaptureStore.ownerKey(from: "\(ownerPrefix)\(owner)"), owner)
        XCTAssertNil(RequestUserAgentCaptureStore.ownerKey(from: "unrelated task metadata"))
        XCTAssertNil(RequestUserAgentCaptureStore.ownerKey(from: ownerPrefix))
    }

    func test_givenNetworkOwnerMetadata_whenParsingTaskDescription_thenStoreReturnsSameOwner() {
        let identifier = Network.uniqueInstanceIdentifier()
        let network = Network.sharedEphemeralInstance(withIdentifier: identifier)
        let request = NSMutableURLRequest(url: url)
        let task = network.dataTask(for: request, ownerKey: owner, dataResponseBlock: nil)
        addTeardownBlock {
            task.cancel()
            Network.removeSharedInstance(forIdentifier: identifier)
        }

        XCTAssertEqual(RequestUserAgentCaptureStore.ownerKey(from: task.taskDescription), owner)
    }

    func test_givenTransactionRequests_whenSelectingRequest_thenLastTransactionWinsOrOriginalRequestIsUsed() {
        let originalRequest = URLRequest(url: URL(string: "https://example.invalid/original")!)
        let redirectedRequest = URLRequest(url: URL(string: "https://example.invalid/redirected")!)

        XCTAssertEqual(
            RequestUserAgentCaptureStore.selectedRequest(transactionRequests: [originalRequest, redirectedRequest], originalRequest: originalRequest)?.url,
            redirectedRequest.url
        )
        XCTAssertEqual(
            RequestUserAgentCaptureStore.selectedRequest(transactionRequests: [], originalRequest: originalRequest)?.url,
            originalRequest.url
        )
    }

    func test_givenTokenRequest_whenCapturing_thenLegacyFieldsAreDerivedInTheStoreMutation() {
        let store = RequestUserAgentCaptureStore()
        var capturedUserAgent: String?
        var capturedURL: String?

        _ = store.capture(
            url: URL(string: "https://example.invalid/services/oauth2/token?private=value")!,
            taskDescription: "\(ownerPrefix)\(owner)",
            userAgent: "ua",
            onSnapshot: { _ in },
            onTokenRequest: { userAgent, url in
                capturedUserAgent = userAgent
                capturedURL = url
            }
        )

        XCTAssertEqual(capturedUserAgent, "ua")
        XCTAssertEqual(capturedURL, "https://example.invalid/services/oauth2/token")
    }
}
#endif
