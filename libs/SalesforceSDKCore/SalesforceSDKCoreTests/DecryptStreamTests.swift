import XCTest
import CryptoKit
@testable import SalesforceSDKCore

class DecryptStreamTests: XCTestCase {
    var key: SymmetricKey!
    var keyData: Data!
    let testString = "Test data for decryption stream."
    var testData: Data { testString.data(using: .utf8)! }
    var encryptedData: Data!

    override func setUp() {
        super.setUp()
        // Given
        key = SymmetricKey(size: .bits256)
        keyData = key.withUnsafeBytes { Data($0) }
        // Encrypt test data using EncryptStream for decryption tests
        let encryptStream = EncryptStream(toMemory: ())
        encryptStream.setupEncryptionKey(key: key)
        encryptStream.open()
        _ = testData.withUnsafeBytes {
            encryptStream.write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: testData.count)
        }
        encryptStream.close()
        encryptedData = encryptStream.property(forKey: .dataWrittenToMemoryStreamKey) as? Data
    }

    func testInitWithData() {
        // Given
        // When
        let stream = DecryptStream(data: encryptedData)
        // Then
        XCTAssertNotNil(stream)
    }

    func testInitWithURL() throws {
        // Given
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try encryptedData.write(to: tempURL)
        // When
        let stream = DecryptStream(url: tempURL)
        // Then
        XCTAssertNotNil(stream)
    }

    func testInitWithFileAtPath() throws {
        // Given
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try encryptedData.write(to: tempURL)
        // When
        let stream = DecryptStream(fileAtPath: tempURL.path)
        // Then
        XCTAssertNotNil(stream)
    }

    func testSetupEncryptionKeySymmetricKey() {
        // Given
        let stream = DecryptStream(data: encryptedData)
        // When
        stream.setupEncryptionKey(key: key)
        // Then
        // No assert needed, just ensure no crash
    }

    func testOpenWithoutKeyFails() {
        // Given
        let stream = DecryptStream(data: encryptedData)
        // When
        stream.open()
        // Then
        XCTAssertNotNil(stream.streamError)
    }

    func testReadAndDecryptMemory() {
        // Given
        let stream = DecryptStream(data: encryptedData)
        stream.setupEncryptionKey(key: key)
        stream.open()
        var buffer = [UInt8](repeating: 0, count: testData.count)
        // When
        let read = stream.read(&buffer, maxLength: buffer.count)
        stream.close()
        // Then
        XCTAssertEqual(read, testData.count)
        let output = Data(buffer)
        XCTAssertEqual(output, testData)
    }

    func testPropertyForKey() {
        // Given
        let stream = DecryptStream(data: encryptedData)
        // When
        let value = stream.property(forKey: .dataWrittenToMemoryStreamKey)
        // Then
        // Should be nil or empty before reading
        if let data = value as? Data {
            XCTAssertTrue(data.isEmpty, "Expected empty Data before reading, got: \(data)")
        } else {
            XCTAssertNil(value)
        }
    }

    func testHasBytesAvailable() {
        // Given
        let stream = DecryptStream(data: encryptedData)
        stream.setupEncryptionKey(key: key)
        stream.open()
        // When
        let hasBytes = stream.hasBytesAvailable
        // Then
        XCTAssertTrue(hasBytes)
    }

    func testStreamStatus() {
        // Given
        let stream = DecryptStream(data: encryptedData)
        // When
        let _ = stream.streamStatus
        // Then
        // Should not crash
    }

    func testStreamError() {
        // Given
        let stream = DecryptStream(data: encryptedData)
        // When
        let error = stream.streamError
        // Then
        XCTAssertNil(error)
    }

    func testReadMultipleChunks() {
        // Given
        let bigData = Data(repeating: 0xAB, count: 2048)
        let encryptStream = EncryptStream(toMemory: ())
        encryptStream.setupEncryptionKey(key: key)
        encryptStream.open()
        _ = bigData.withUnsafeBytes {
            encryptStream.write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: bigData.count)
        }
        encryptStream.close()
        let encrypted = encryptStream.property(forKey: .dataWrittenToMemoryStreamKey) as? Data
        let stream = DecryptStream(data: encrypted ?? Data())
        stream.setupEncryptionKey(key: key)
        stream.open()
        var buffer = [UInt8](repeating: 0, count: bigData.count)
        // When
        let read = stream.read(&buffer, maxLength: buffer.count)
        stream.close()
        // Then
        XCTAssertEqual(read, bigData.count)
        let output = Data(buffer)
        XCTAssertEqual(output, bigData)
    }

    func testReadWithoutKeyFails() {
        // Given
        let stream = DecryptStream(data: encryptedData)
        stream.open()
        var buffer = [UInt8](repeating: 0, count: testData.count)
        // When
        let read = stream.read(&buffer, maxLength: buffer.count)
        // Then
        XCTAssertEqual(read, -1)
        XCTAssertNotNil(stream.streamError)
        // Clean up
        stream.close()
    }
}
