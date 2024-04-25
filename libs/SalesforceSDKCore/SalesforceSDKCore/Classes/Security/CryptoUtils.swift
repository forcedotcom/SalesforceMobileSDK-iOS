//
//  CryptoUtils.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 3/4/24.
//  Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
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
import Security

public extension SFSDKCryptoUtils {
    static let errorDomain = "com.salesforce.crypto"
    
    @objc(encryptData:key:algorithm:error:)
    class func encrypt(data: Data, key: SecKey, algorithm: SecKeyAlgorithm) throws -> Data {
        var unmanagedError: Unmanaged<CFError>?
        if let encryptedCFData = SecKeyCreateEncryptedData(key, algorithm, data as CFData, &unmanagedError) {
           return encryptedCFData as Data
        } else if let unmanagedError = unmanagedError {
            throw unmanagedError.takeRetainedValue() as Error
        } else {
            throw NSError(domain: errorDomain, code: -1)
        }
    }
    
    @objc(decryptData:key:algorithm:error:)
    class func decrypt(data: Data, key: SecKey, algorithm: SecKeyAlgorithm) throws -> Data {
        var unmanagedError: Unmanaged<CFError>?
        if let decryptedCFData = SecKeyCreateDecryptedData(key, algorithm, data as CFData, &unmanagedError) {
           return decryptedCFData as Data
        } else if let unmanagedError = unmanagedError {
            throw unmanagedError.takeRetainedValue() as Error
        } else {
            throw NSError(domain: errorDomain, code: -1)
        }
    }
}
