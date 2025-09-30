//
//  SecItemOperations.swift
//  SalesforceSDKCommon
//
//  Created by Brianna Birman on 7/2/25.
//  Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
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

@objc(SFSDKSecItemOperations)
public class SecItemOperations: NSObject {
    
    @objc(copyMatching:result:)
    public static func copyMatching(_ query: [String: Any], _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        return SecItemCopyMatching(msdkTaggedQuery(query), result)
    }
    
    @objc(add:result:)
    public static func add(_ query: [String: Any], _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        return SecItemAdd(msdkTaggedQuery(query), result)
    }
    
    @objc
    public static func delete(_ query: [String: Any]) -> OSStatus {
        return SecItemDelete(msdkTaggedQuery(query))
    }
    
    @objc(update:attributesToUpdate:)
    public static func update(_ query: [String: Any], _ attributesToUpdate: [String: Any]) -> OSStatus {
        return SecItemUpdate(msdkTaggedQuery(query), attributesToUpdate as CFDictionary)
    }
    
    static func msdkTaggedQuery(_ query: [String: Any]) -> CFDictionary {
        var query = query
        query[String(kSecAttrCreator)] = String(KeychainItemManager.tag)
        return query as CFDictionary
    }
   
}
