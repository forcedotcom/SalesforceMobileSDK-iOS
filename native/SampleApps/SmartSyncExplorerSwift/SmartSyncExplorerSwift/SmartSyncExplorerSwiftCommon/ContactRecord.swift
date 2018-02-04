//
//  ContactRecord.swift
//  SmartSyncExplorerSwift
//
//  Created by Nicholas McDonald on 1/31/18.
//  Copyright © 2018 Salesforce. All rights reserved.
//

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
