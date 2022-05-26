//
//  BriefcaseObjectInfo.swift
//  MobileSync
//
//  Created by Brianna Birman on 5/23/22.
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

import Foundation

@objc(SFBriefcaseObjectInfo)
public class BriefcaseObjectInfo: NSObject, Codable {
    @objc let sobjectType: String
    @objc let fieldlist: [String]
    @objc let idFieldName: String
    @objc let modificationDateFieldName: String
    @objc let soupName: String

    @objc public convenience init(soupName: String, sobjectType: String, fieldlist: [String]) {
        self.init(soupName: soupName, sobjectType: sobjectType, fieldlist: fieldlist, idFieldName: nil, modificationDateFieldName: nil)
    }

    @objc public init(soupName: String, sobjectType: String, fieldlist: [String], idFieldName: String?, modificationDateFieldName: String?) {
        self.soupName = soupName
        self.sobjectType = sobjectType
        self.fieldlist = fieldlist
        self.idFieldName = idFieldName ?? kId
        self.modificationDateFieldName = modificationDateFieldName ?? kLastModifiedDate
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.soupName = try container.decode(String.self, forKey: .soupName)
        self.sobjectType = try container.decode(String.self, forKey: .sobjectType)
        self.fieldlist = try container.decode([String].self, forKey: .fieldlist)
        self.idFieldName = try container.decodeIfPresent(String.self, forKey: .idFieldName) ?? kId
        self.modificationDateFieldName = try container.decodeIfPresent(String.self, forKey: .modificationDateFieldName) ?? kLastModifiedDate
    }
}
