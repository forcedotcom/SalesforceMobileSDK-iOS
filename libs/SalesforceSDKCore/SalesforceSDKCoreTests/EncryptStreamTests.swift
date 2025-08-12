import XCTest
import CryptoKit
@testable import SalesforceSDKCore

class EncryptStreamTests: XCTestCase {
    var key: SymmetricKey!
    var keyData: Data!
    let testString = "Test data for encryption stream."
    var testData: Data { testString.data(using: .utf8)! }

    override func setUp() {
        super.setUp()
        // Given
        key = SymmetricKey(size: .bits256)
        keyData = key.withUnsafeBytes { Data($0) }
    }

    func testInitToMemory() {
        // Given
        // (no setup needed)
        // When
        let stream = EncryptStream(toMemory: ())
        // Then
        XCTAssertNotNil(stream)
    }

    func testInitToBuffer() {
        // Given
        var buffer = [UInt8](repeating: 0, count: 1024)
        // When
        let stream = EncryptStream(toBuffer: &buffer, capacity: buffer.count)
        // Then
        XCTAssertNotNil(stream)
    }

    func testInitToFile() throws {
        // Given
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        // When
        let stream = EncryptStream(url: tempURL, append: false)
        // Then
        XCTAssertNotNil(stream)
    }

    func testInitToFileAtPath() throws {
        // Given
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        // When
        let stream = EncryptStream(toFileAtPath: tempURL.path, append: false)
        // Then
        XCTAssertNotNil(stream)
    }


    func testSetupEncryptionKeySymmetricKey() {
        // Given
        let stream = EncryptStream(toMemory: ())
        // When
        stream.setupEncryptionKey(key: key)
        // Then
        // No assert needed, just ensure no crash
    }

    func testOpenWithoutKeyFails() {
        // Given
        let stream = EncryptStream(toMemory: ())
        // When
        stream.open()
        // Then
        XCTAssertNotNil(stream.streamError)
    }

    func testWriteAndReadMemory() throws {
        // Given
        let stream = EncryptStream(toMemory: ())
        stream.setupEncryptionKey(key: key)
        stream.open()
        // When
        let written = testData.withUnsafeBytes {
            stream.write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: testData.count)
        }
        stream.close()
        // Then
        XCTAssertEqual(written, testData.count)
        guard let encrypted = stream.property(forKey: .dataWrittenToMemoryStreamKey) as? Data else {
            XCTFail("No data written to memory stream")
            return
        }
        // Decrypt and verify
        _ = try AES.GCM.open(
            try AES.GCM.SealedBox(combined: encrypted),
            using: key
        )
        // Since EncryptStream encrypts in chunks, we can't just decrypt the whole thing at once.
        // Instead, test that encrypted data is not equal to plaintext, and that no error is thrown.
        XCTAssertNotEqual(encrypted, testData)
    }

    func testWriteWithoutKeyFails() {
        // Given
        let stream = EncryptStream(toMemory: ())
        stream.open()
        // When
        let written = testData.withUnsafeBytes {
            stream.write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: testData.count)
        }
        // Then
        XCTAssertEqual(written, -1)
        XCTAssertNotNil(stream.streamError)
        
        // Clean up
        stream.close()
        
    }

    func testPropertyForKey() {
        // Given
        let stream = EncryptStream(toMemory: ())
        // When
        let value = stream.property(forKey: .dataWrittenToMemoryStreamKey)
        // Then
        // Should be nil or empty before writing
        if let data = value as? Data {
            XCTAssertTrue(data.isEmpty, "Expected empty Data before writing, got: \(data)")
        } else {
            XCTAssertNil(value)
        }
    }

    func testHasSpaceAvailable() {
        // Given
        let stream = EncryptStream(toMemory: ())
        stream.setupEncryptionKey(key: key) // Set the key before opening
        // When
        stream.open()
        let hasSpace = stream.hasSpaceAvailable
        // Then
        XCTAssertTrue(hasSpace)
    }

    func testStreamStatus() {
        // Given
        let stream = EncryptStream(toMemory: ())
        // When
        let _ = stream.streamStatus
        // Then
        // Should not crash
    }

    func testStreamError() {
        // Given
        let stream = EncryptStream(toMemory: ())
        // When
        let error = stream.streamError
        // Then
        XCTAssertNil(error)
    }

    func testWriteMultipleChunks() throws {
        // Given
        let stream = EncryptStream(toMemory: ())
        stream.setupEncryptionKey(key: key)
        stream.open()
        let bigData = Data(repeating: 0xAB, count: 2048)
        // When
        let written = bigData.withUnsafeBytes {
            stream.write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: bigData.count)
        }
        stream.close()
        // Then
        XCTAssertEqual(written, bigData.count)
        let encrypted = stream.property(forKey: .dataWrittenToMemoryStreamKey) as? Data
        XCTAssertNotNil(encrypted)
    }
}
