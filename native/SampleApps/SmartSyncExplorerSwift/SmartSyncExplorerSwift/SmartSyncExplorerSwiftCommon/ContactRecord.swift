/*
 ContactRecord.swift
 SmartSyncExplorerSwift

 Created by Nicholas McDonald on 1/31/18.

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

import Foundation
import SmartStore

class ContactRecord: Record, StoreProtocol {
    static let objectName: String = "Contact"
    
    enum Field: String {
        case firstName = "FirstName"
        case lastName = "LastName"
        case mobilePhone = "MobilePhone"
        case homePhone = "HomePhone"
        case title = "Title"
        case email = "Email"
        case department = "Department"
        
        static let allFields = [firstName.rawValue,
                                lastName.rawValue,
                                mobilePhone.rawValue,
                                homePhone.rawValue,
                                title.rawValue,
                                email.rawValue,
                                department.rawValue
        ]
    }
    
    var firstName: String? {
        get {return data[Field.firstName.rawValue] as? String }
        set {data[Field.firstName.rawValue] = newValue}
    }
    var lastName: String? {
        get {return data[Field.lastName.rawValue] as? String}
        set {data[Field.lastName.rawValue] = newValue}
    }
    var mobilePhone: String? {
        get {return data[Field.mobilePhone.rawValue] as? String}
        set {data[Field.mobilePhone.rawValue] = newValue}
    }
    var homePhone: String? {
        get {return data[Field.homePhone.rawValue] as? String}
        set {data[Field.homePhone.rawValue] = newValue}
    }
    var title: String? {
        get {return data[Field.title.rawValue] as? String}
        set {data[Field.title.rawValue] = newValue}
    }
    var email: String? {
        get {return data[Field.email.rawValue] as? String}
        set {data[Field.email.rawValue] = newValue}
    }
    var department: String? {
        get {return data[Field.department.rawValue] as? String}
        set {data[Field.department.rawValue] = newValue}
    }
    
    override static var indexes: [[String: String]] {
        return super.indexes + [
            ["path": Field.firstName.rawValue, "type" : kSoupIndexTypeString],
            ["path": Field.lastName.rawValue, "type" : kSoupIndexTypeString],
            ["path": Field.mobilePhone.rawValue, "type" : kSoupIndexTypeString],
            ["path": Field.homePhone.rawValue, "type" : kSoupIndexTypeString],
            ["path": Field.title.rawValue, "type" : kSoupIndexTypeString],
            ["path": Field.email.rawValue, "type" : kSoupIndexTypeString],
            ["path": Field.department.rawValue, "type" : kSoupIndexTypeString]
        ]
    }
    
    override static var readFields: [String] {
        return super.readFields + Field.allFields
    }
    override static var createFields: [String] {
        return super.createFields + Field.allFields
    }
    override static var updateFields: [String] {
        return super.updateFields + Field.allFields
    }
    
    static var orderPath: String = Field.firstName.rawValue
    
    override static var dataSpec: [RecordDataSpec] {
        return super.dataSpec + [RecordDataSpec(fieldName:Field.firstName.rawValue, isSearchable:true),
                                 RecordDataSpec(fieldName:Field.lastName.rawValue, isSearchable:true),
                                 RecordDataSpec(fieldName:Field.title.rawValue, isSearchable:true),
                                 RecordDataSpec(fieldName:Field.mobilePhone.rawValue, isSearchable:false),
                                 RecordDataSpec(fieldName:Field.email.rawValue, isSearchable:false),
                                 RecordDataSpec(fieldName:Field.department.rawValue, isSearchable:false),
                                 RecordDataSpec(fieldName:Field.homePhone.rawValue, isSearchable:false)]
    }
    
    required init(data: [Any]) {
        super.init(data: data)
        self.objectType = ContactRecord.objectName
    }
    
    required init() {
        super.init()
        self.objectType = ContactRecord.objectName
    }
}
