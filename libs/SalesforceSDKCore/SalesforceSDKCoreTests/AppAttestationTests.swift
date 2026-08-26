//
//  AppAttestationTests.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 4/17/26.
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
import DeviceCheck
import CryptoKit
@testable import SalesforceSDKCore

class AppAttestationTests: XCTestCase {

    private var originalAppAttestationEnabled = false

    override func setUp() {
        super.setUp()
        originalAppAttestationEnabled = UserAccountManager.shared.appAttestationEnabled
        _ = KeychainHelper.remove(service: AppAttestation.appAttestKeyName, account: nil)
    }

    override func tearDown() {
        UserAccountManager.shared.appAttestationEnabled = originalAppAttestationEnabled
        _ = KeychainHelper.remove(service: AppAttestation.appAttestKeyName, account: nil)
        super.tearDown()
    }

    // MARK: - AttestationObject Tests

    func test_givenValidAttestationData_whenEncodingAttestationObject_thenReturnsBase64EncodedJSON() throws {
        let attestationId = "testId"
        let attestationData = "testData".data(using: .utf8)!.base64EncodedString()

        let attestationObject = AppAttestation.AttestationObject(
            attestationId: attestationId,
            attestationData: attestationData
        )

        let jsonData = try JSONEncoder().encode(attestationObject)
        let base64String = jsonData.base64EncodedString()

        XCTAssertFalse(base64String.isEmpty, "Base64 encoded string should not be empty")

        // Verify we can decode it back
        let decodedData = try XCTUnwrap(Data(base64Encoded: base64String))
        let decodedObject = try JSONDecoder().decode(AppAttestation.AttestationObject.self, from: decodedData)

        XCTAssertEqual(decodedObject.attestationId, attestationId)
        XCTAssertEqual(decodedObject.attestationData, attestationData)
    }

    // MARK: - Challenge Hash Tests

    func test_givenChallengeString_whenGeneratingHash_thenReturnsSHA256Hash() throws {
        let challenge = "testChallenge"
        let challengeData = try XCTUnwrap(challenge.data(using: .utf8))
        let hash = Data(SHA256.hash(data: challengeData))

        // SHA256 always produces 32 bytes
        XCTAssertEqual(hash.count, 32, "SHA256 hash should be 32 bytes")
    }


    // MARK: - Error Handling Tests

    func test_givenEmptyChallenge_whenGeneratingHash_thenReturnsValidHash() throws {
        let challenge = ""
        let challengeData = try XCTUnwrap(challenge.data(using: .utf8))
        let hash = Data(SHA256.hash(data: challengeData))

        XCTAssertEqual(hash.count, 32, "SHA256 hash should still be 32 bytes for empty input")
    }

    // MARK: - URL Encoding Tests

    func test_givenAttestationObjectWithSpecialCharacters_whenURLEncoding_thenProperlyEncoded() {
        let attestationObject = "test+string/with=special&chars"
        let encoded = attestationObject.sfsdk_stringByURLEncoding()

        XCTAssertNotEqual(attestationObject, encoded, "Encoded string should differ from original")
        XCTAssertTrue(encoded.contains("%"), "Encoded string should contain percent encoding")
    }

    func test_givenBase64EncodedData_whenURLEncoding_thenProperlyHandlesPaddingAndSpecialChars() {
        let testData = "test data".data(using: .utf8)!
        let base64String = testData.base64EncodedString()
        let encoded = base64String.sfsdk_stringByURLEncoding()

        // Base64 can contain +, /, = which should be encoded
        XCTAssertFalse(encoded.contains("+") || encoded.contains("/") || encoded.contains("="),
                       "Encoded string should not contain unencoded special characters")
    }

    // MARK: - JSON Encoding/Decoding Tests

    func test_givenAttestationObject_whenEncodingAndDecoding_thenPreservesData() throws {
        let original = AppAttestation.AttestationObject(
            attestationId: "testId123",
            attestationData: "dGVzdERhdGE="
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppAttestation.AttestationObject.self, from: encoded)

        XCTAssertEqual(original.attestationId, decoded.attestationId)
        XCTAssertEqual(original.attestationData, decoded.attestationData)
    }

    func test_givenMalformedJSON_whenDecodingAttestationObject_thenThrowsError() {
        let malformedJSON = "{\"attestationId\":\"test\"}".data(using: .utf8)!

        XCTAssertThrowsError(
            try JSONDecoder().decode(AppAttestation.AttestationObject.self, from: malformedJSON),
            "Decoding incomplete JSON should throw error"
        ) { error in
            XCTAssertTrue(error is DecodingError, "Should be a DecodingError")
        }
    }

    // MARK: - Integration-Style Tests (Note: These require mocking DCAppAttestService)

    func test_givenValidInputs_whenCreatingAttestationObjectComponents_thenComponentsAreValid() throws {
        // This tests the data transformation logic without actual attestation
        let attestationId = "testId"
        let mockAttestationData = Data([0x01, 0x02, 0x03, 0x04])
        let base64Attestation = mockAttestationData.base64EncodedString()

        let attestationObject = AppAttestation.AttestationObject(
            attestationId: attestationId,
            attestationData: base64Attestation
        )

        let jsonData = try JSONEncoder().encode(attestationObject)
        let base64EncodedObject = jsonData.base64EncodedString()

        // Verify the structure
        XCTAssertFalse(base64EncodedObject.isEmpty)

        // Verify it can be decoded
        let decodedData = try XCTUnwrap(Data(base64Encoded: base64EncodedObject))
        let decodedObject = try JSONDecoder().decode(AppAttestation.AttestationObject.self, from: decodedData)

        XCTAssertEqual(decodedObject.attestationId, attestationId)
        XCTAssertEqual(decodedObject.attestationData, base64Attestation)
    }

    // MARK: - Edge Cases

    func test_givenVeryLongAttestationId_whenEncodingAttestationObject_thenSucceeds() throws {
        let longId = String(repeating: "a", count: 1000)
        let attestationData = "testData".data(using: .utf8)!.base64EncodedString()

        let attestationObject = AppAttestation.AttestationObject(
            attestationId: longId,
            attestationData: attestationData
        )

        XCTAssertNoThrow(try JSONEncoder().encode(attestationObject))
    }

    func test_givenVeryLargeAttestationData_whenEncodingAttestationObject_thenSucceeds() throws {
        let largeData = Data(repeating: 0xFF, count: 10000)
        let attestationData = largeData.base64EncodedString()

        let attestationObject = AppAttestation.AttestationObject(
            attestationId: "testId",
            attestationData: attestationData
        )

        XCTAssertNoThrow(try JSONEncoder().encode(attestationObject))
    }

    func test_givenUnicodeCharacters_whenEncodingAttestationId_thenSucceeds() throws {
        let unicodeId = "测试🎉αβγ"
        let attestationData = "testData".data(using: .utf8)!.base64EncodedString()

        let attestationObject = AppAttestation.AttestationObject(
            attestationId: unicodeId,
            attestationData: attestationData
        )

        let jsonData = try JSONEncoder().encode(attestationObject)
        let decoded = try JSONDecoder().decode(AppAttestation.AttestationObject.self, from: jsonData)

        XCTAssertEqual(decoded.attestationId, unicodeId)
    }


    // MARK: - Constants Tests

    func test_appAttestKeyName_hasExpectedValue() {
        XCTAssertEqual(AppAttestation.appAttestKeyName, "com.salesforce.mobilesdk.attestation",
                      "App attest key name constant should match expected value")
    }

    // MARK: - Gating Logic Tests (shouldAttemptAttestation)

    func test_givenAllConditionsMet_whenCheckingShouldAttempt_thenReturnsTrue() {
        UserAccountManager.shared.appAttestationEnabled = true
        let result = AppAttestation.shouldAttemptAttestation(for: "mydomain.my.salesforce.com", consumerKey: "consumerKey123", isDeviceSupported: true)
        XCTAssertTrue(result, "Should return true when all conditions are met")
    }

    func test_givenAttestationDisabled_whenCheckingShouldAttempt_thenReturnsFalse() {
        UserAccountManager.shared.appAttestationEnabled = false
        let result = AppAttestation.shouldAttemptAttestation(for: "mydomain.my.salesforce.com", consumerKey: "consumerKey123", isDeviceSupported: true)
        XCTAssertFalse(result, "Should return false when attestation is disabled")
    }

    func test_givenDeviceNotSupported_whenCheckingShouldAttempt_thenReturnsFalse() {
        UserAccountManager.shared.appAttestationEnabled = true
        let result = AppAttestation.shouldAttemptAttestation(for: "mydomain.my.salesforce.com", consumerKey: "consumerKey123", isDeviceSupported: false)
        XCTAssertFalse(result, "Should return false when device does not support App Attest")
    }

    func test_givenLoginSalesforceDomain_whenCheckingShouldAttempt_thenReturnsFalse() {
        UserAccountManager.shared.appAttestationEnabled = true
        let result = AppAttestation.shouldAttemptAttestation(for: "login.salesforce.com", consumerKey: "consumerKey123", isDeviceSupported: true)
        XCTAssertFalse(result, "Should return false for login.salesforce.com (login pool)")
    }

    func test_givenTestSalesforceDomain_whenCheckingShouldAttempt_thenReturnsFalse() {
        UserAccountManager.shared.appAttestationEnabled = true
        let result = AppAttestation.shouldAttemptAttestation(for: "test.salesforce.com", consumerKey: "consumerKey123", isDeviceSupported: true)
        XCTAssertFalse(result, "Should return false for test.salesforce.com (login pool)")
    }

    func test_givenWelcomeDiscoveryDomain_whenCheckingShouldAttempt_thenReturnsFalse() {
        UserAccountManager.shared.appAttestationEnabled = true
        let result = AppAttestation.shouldAttemptAttestation(for: "welcome.salesforce.com/discovery", consumerKey: "consumerKey123", isDeviceSupported: true)
        XCTAssertFalse(result, "Should return false for welcome.salesforce.com/discovery (login pool)")
    }

    func test_givenNilDomain_whenCheckingShouldAttempt_thenReturnsFalse() {
        UserAccountManager.shared.appAttestationEnabled = true
        let result = AppAttestation.shouldAttemptAttestation(for: nil, consumerKey: "consumerKey123", isDeviceSupported: true)
        XCTAssertFalse(result, "Should return false when domain is nil")
    }

    func test_givenEmptyDomain_whenCheckingShouldAttempt_thenReturnsFalse() {
        UserAccountManager.shared.appAttestationEnabled = true
        let result = AppAttestation.shouldAttemptAttestation(for: "", consumerKey: "consumerKey123", isDeviceSupported: true)
        XCTAssertFalse(result, "Should return false when domain is empty")
    }

    func test_givenEmptyConsumerKey_whenCheckingShouldAttempt_thenReturnsFalse() {
        UserAccountManager.shared.appAttestationEnabled = true
        let result = AppAttestation.shouldAttemptAttestation(for: "mydomain.my.salesforce.com", consumerKey: "", isDeviceSupported: true)
        XCTAssertFalse(result, "Should return false when consumer key is empty")
    }

    func test_givenNilConsumerKey_whenCheckingShouldAttempt_thenReturnsFalse() {
        UserAccountManager.shared.appAttestationEnabled = true
        let result = AppAttestation.shouldAttemptAttestation(for: "mydomain.my.salesforce.com", consumerKey: nil, isDeviceSupported: true)
        XCTAssertFalse(result, "Should return false when consumer key is nil")
    }

    // MARK: - existingKeyId Tests

    func test_givenNoKeychainData_whenCallingExistingKeyId_thenReturnsNil() throws {
        let result = try AppAttestation.existingKeyId(for: "device123")
        XCTAssertNil(result, "Should return nil when no keychain entry exists")
    }

    func test_givenMatchingAttestationId_whenCallingExistingKeyId_thenReturnsKeyId() throws {
        let attestationId = "device123"
        let keyId = "storedKey456"
        let item = AppAttestation.AttestationKeychainItem(attestationId: attestationId, keyId: keyId)
        let data = try JSONEncoder().encode(item)
        _ = KeychainHelper.write(service: AppAttestation.appAttestKeyName, data: data, account: nil)

        let result = try AppAttestation.existingKeyId(for: attestationId)
        XCTAssertEqual(result, keyId)
    }

    func test_givenMismatchedAttestationId_whenCallingExistingKeyId_thenReturnsNilAndRemovesEntry() throws {
        let item = AppAttestation.AttestationKeychainItem(attestationId: "oldDevice", keyId: "oldKey")
        let data = try JSONEncoder().encode(item)
        _ = KeychainHelper.write(service: AppAttestation.appAttestKeyName, data: data, account: nil)

        let result = try AppAttestation.existingKeyId(for: "newDevice")
        XCTAssertNil(result, "Should return nil when attestationId doesn't match")

        // Verify the stale entry was removed
        let readResult = KeychainHelper.read(service: AppAttestation.appAttestKeyName, account: nil)
        XCTAssertNil(readResult.data, "Stale keychain entry should have been removed")
    }

    func test_givenCorruptedKeychainData_whenCallingExistingKeyId_thenReturnsNil() throws {
        let corruptData = "not json".data(using: .utf8)!
        _ = KeychainHelper.write(service: AppAttestation.appAttestKeyName, data: corruptData, account: nil)

        let result = try AppAttestation.existingKeyId(for: "device123")
        XCTAssertNil(result, "Should return nil when keychain data can't be decoded")
    }

    func test_givenPartialJSON_whenCallingExistingKeyId_thenReturnsNil() throws {
        // Valid JSON but missing required keyId field
        let partialData = "{\"attestationId\":\"device123\"}".data(using: .utf8)!
        _ = KeychainHelper.write(service: AppAttestation.appAttestKeyName, data: partialData, account: nil)

        let result = try AppAttestation.existingKeyId(for: "device123")
        XCTAssertNil(result, "Should return nil when keychain data is missing required fields")
    }

}
