//
//  EncryptStream.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 8/31/21.
//  Copyright (c) 2021-present, salesforce.com, inc. All rights reserved.
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

import Foundation
import CryptoKit

enum CryptStream {
    static let chunkSize = 512
    static let sealedBoxSize = chunkSize + 28 // Overhead for each block: 12 byte nonce + 16 byte authentication tag
}

@objc(SFSDKEncryptStream)
public class EncryptStream: OutputStream {
    private var key: SymmetricKey?
    private let stream: OutputStream
    private var remainder: Data?
    
    override public var streamStatus: Stream.Status {
        return stream.streamStatus
    }

    override public var hasSpaceAvailable: Bool {
        return stream.hasSpaceAvailable
    }

    override public init(toMemory: ()) {
        stream = OutputStream(toMemory: toMemory)
        super.init(toMemory: toMemory)
    }

    override public init(toBuffer buffer: UnsafeMutablePointer<UInt8>, capacity: Int) {
        stream = OutputStream(toBuffer: buffer, capacity: capacity)
        super.init(toBuffer: buffer, capacity: capacity)
    }

    override public init?(url: URL, append shouldAppend: Bool) {
        guard let outputStream = OutputStream(url: url, append: shouldAppend) else {
            return nil
        }
        self.stream = outputStream
        super.init(url: url, append: shouldAppend)
    }

    public convenience init?(toFileAtPath path: String, append shouldAppend: Bool) {
        let url = URL(fileURLWithPath: path)
        self.init(url: url, append: shouldAppend)
    }

    /// Setup for encryption. Always call this method before using this stream.
    /// - Parameters:
    ///   - key: Encryption key to use
    @objc(setupEncryptionKey:) @available(swift, obsoleted: 1.0) // Objective-c only wrapper
    public func setupEncryptionKey(key: Data) {
        self.key = SymmetricKey(data: key)
    }

    /// Setup for encryption. Always call this method before using this stream.
    /// - Parameters:
    ///   - key: Encryption key to use
    public func setupEncryptionKey(key: SymmetricKey) {
        self.key = key
    }

    override public func property(forKey key: Stream.PropertyKey) -> Any? {
        return self.stream.property(forKey: key)
    }
    
    override public func open () {
        assert(key != nil, "EncryptStream - you must call setupEncryptionKey first")
        self.stream.open()
    }

    override public func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        guard let key = key else { return -1 }
        
        var bufferSlice = UnsafeBufferPointer<UInt8>(start: buffer, count: len).prefix(len)
        while (!bufferSlice.isEmpty) {
            let dataBlock: Data
            let sliceSize: Int
            if let remainder = remainder {
                let slice = bufferSlice.prefix(CryptStream.chunkSize - remainder.count)
                sliceSize = slice.count
                dataBlock = remainder + Data(slice)
                self.remainder = nil
            } else {
                let slice = bufferSlice.prefix(CryptStream.chunkSize)
                sliceSize = slice.count
                dataBlock = Data(slice)
            }

            if dataBlock.count == CryptStream.chunkSize {
                do {
                    let encryptedData = try Encryptor.encrypt(data: dataBlock, using: key)
                    stream.write([UInt8](encryptedData), maxLength: encryptedData.count)
                    bufferSlice = bufferSlice.dropFirst(sliceSize)
                } catch {
                    SalesforceLogger.e(EncryptStream.self, message: "Error encrypting data: \(error)")
                    return -1
                }
            } else {
                remainder = dataBlock
                break
            }
        }
        return len
    }

    override public func close() {
        defer { stream.close() }
        guard let key = key else { return }

        do {
            if let remainder = remainder {
                let encryptedData = try Encryptor.encrypt(data: remainder, using: key)
                stream.write([UInt8](encryptedData), maxLength: encryptedData.count)
            }
        } catch {
            SalesforceLogger.e(EncryptStream.self, message: "Error encrypting data to stream: \(error)")
        }
    }
}
