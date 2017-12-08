/*
 SalesforceCodables
 Created by Raj Rao on 11/29/17.
 
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

struct Field : Codable {
    let aggregatable : Bool?
    let autoNumber : Bool?
    let byteLength : Int?
    let calculated : Bool?
    let calculatedFormula : String?
    let cascadeDelete : Bool?
    let caseSensitive : Bool?
    let compoundFieldName : String?
    let controllerName : String?
    let createable : Bool?
    let custom : Bool?
    let defaultValue : String?
    let defaultValueFormula : String?
    let defaultedOnCreate : Bool?
    let dependentPicklist : Bool?
    let deprecatedAndHidden : Bool?
    let digits : Int?
    let displayLocationInDecimal : Bool?
    let encrypted : Bool?
    let externalId : Bool?
    let extraTypeInfo : String?
    let filterable : Bool?
    let filteredLookupInfo : String?
    let groupable : Bool?
    let highScaleNumber : Bool?
    let htmlFormatted : Bool?
    let idLookup : Bool?
    let inlineHelpText : String?
    let label : String?
    let length : Int?
    let mask : String?
    let maskType : String?
    let name : String?
    let nameField : Bool?
    let namePointing : Bool?
    let nillable : Bool?
    let permissionable : Bool?
    let picklistValues : [String]?
    let precision : Int?
    let queryByDistance : Bool?
    let referenceTargetField : String?
    let referenceTo : [String]?
    let relationshipName : String?
    let relationshipOrder : String?
    let restrictedDelete : Bool?
    let restrictedPicklist : Bool?
    let scale : Int?
    let soapType : String?
    let sortable : Bool?
    let type : String?
    let unique : Bool?
    let updateable : Bool?
    let writeRequiresMasterRead : Bool?
    
    enum CodingKeys: String, CodingKey {
        case aggregatable = "aggregatable"
        case autoNumber = "autoNumber"
        case byteLength = "byteLength"
        case calculated = "calculated"
        case calculatedFormula = "calculatedFormula"
        case cascadeDelete = "cascadeDelete"
        case caseSensitive = "caseSensitive"
        case compoundFieldName = "compoundFieldName"
        case controllerName = "controllerName"
        case createable = "createable"
        case custom = "custom"
        case defaultValue = "defaultValue"
        case defaultValueFormula = "defaultValueFormula"
        case defaultedOnCreate = "defaultedOnCreate"
        case dependentPicklist = "dependentPicklist"
        case deprecatedAndHidden = "deprecatedAndHidden"
        case digits = "digits"
        case displayLocationInDecimal = "displayLocationInDecimal"
        case encrypted = "encrypted"
        case externalId = "externalId"
        case extraTypeInfo = "extraTypeInfo"
        case filterable = "filterable"
        case filteredLookupInfo = "filteredLookupInfo"
        case groupable = "groupable"
        case highScaleNumber = "highScaleNumber"
        case htmlFormatted = "htmlFormatted"
        case idLookup = "idLookup"
        case inlineHelpText = "inlineHelpText"
        case label = "label"
        case length = "length"
        case mask = "mask"
        case maskType = "maskType"
        case name = "name"
        case nameField = "nameField"
        case namePointing = "namePointing"
        case nillable = "nillable"
        case permissionable = "permissionable"
        case picklistValues = "picklistValues"
        case precision = "precision"
        case queryByDistance = "queryByDistance"
        case referenceTargetField = "referenceTargetField"
        case referenceTo = "referenceTo"
        case relationshipName = "relationshipName"
        case relationshipOrder = "relationshipOrder"
        case restrictedDelete = "restrictedDelete"
        case restrictedPicklist = "restrictedPicklist"
        case scale = "scale"
        case soapType = "soapType"
        case sortable = "sortable"
        case type = "type"
        case unique = "unique"
        case updateable = "updateable"
        case writeRequiresMasterRead = "writeRequiresMasterRead"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        aggregatable = try values.decodeIfPresent(Bool.self, forKey: .aggregatable)
        autoNumber = try values.decodeIfPresent(Bool.self, forKey: .autoNumber)
        byteLength = try values.decodeIfPresent(Int.self, forKey: .byteLength)
        calculated = try values.decodeIfPresent(Bool.self, forKey: .calculated)
        calculatedFormula = try values.decodeIfPresent(String.self, forKey: .calculatedFormula)
        cascadeDelete = try values.decodeIfPresent(Bool.self, forKey: .cascadeDelete)
        caseSensitive = try values.decodeIfPresent(Bool.self, forKey: .caseSensitive)
        compoundFieldName = try values.decodeIfPresent(String.self, forKey: .compoundFieldName)
        controllerName = try values.decodeIfPresent(String.self, forKey: .controllerName)
        createable = try values.decodeIfPresent(Bool.self, forKey: .createable)
        custom = try values.decodeIfPresent(Bool.self, forKey: .custom)
        defaultValue = try values.decodeIfPresent(String.self, forKey: .defaultValue)
        defaultValueFormula = try values.decodeIfPresent(String.self, forKey: .defaultValueFormula)
        defaultedOnCreate = try values.decodeIfPresent(Bool.self, forKey: .defaultedOnCreate)
        dependentPicklist = try values.decodeIfPresent(Bool.self, forKey: .dependentPicklist)
        deprecatedAndHidden = try values.decodeIfPresent(Bool.self, forKey: .deprecatedAndHidden)
        digits = try values.decodeIfPresent(Int.self, forKey: .digits)
        displayLocationInDecimal = try values.decodeIfPresent(Bool.self, forKey: .displayLocationInDecimal)
        encrypted = try values.decodeIfPresent(Bool.self, forKey: .encrypted)
        externalId = try values.decodeIfPresent(Bool.self, forKey: .externalId)
        extraTypeInfo = try values.decodeIfPresent(String.self, forKey: .extraTypeInfo)
        filterable = try values.decodeIfPresent(Bool.self, forKey: .filterable)
        filteredLookupInfo = try values.decodeIfPresent(String.self, forKey: .filteredLookupInfo)
        groupable = try values.decodeIfPresent(Bool.self, forKey: .groupable)
        highScaleNumber = try values.decodeIfPresent(Bool.self, forKey: .highScaleNumber)
        htmlFormatted = try values.decodeIfPresent(Bool.self, forKey: .htmlFormatted)
        idLookup = try values.decodeIfPresent(Bool.self, forKey: .idLookup)
        inlineHelpText = try values.decodeIfPresent(String.self, forKey: .inlineHelpText)
        label = try values.decodeIfPresent(String.self, forKey: .label)
        length = try values.decodeIfPresent(Int.self, forKey: .length)
        mask = try values.decodeIfPresent(String.self, forKey: .mask)
        maskType = try values.decodeIfPresent(String.self, forKey: .maskType)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        nameField = try values.decodeIfPresent(Bool.self, forKey: .nameField)
        namePointing = try values.decodeIfPresent(Bool.self, forKey: .namePointing)
        nillable = try values.decodeIfPresent(Bool.self, forKey: .nillable)
        permissionable = try values.decodeIfPresent(Bool.self, forKey: .permissionable)
        picklistValues = try values.decodeIfPresent([String].self, forKey: .picklistValues)
        precision = try values.decodeIfPresent(Int.self, forKey: .precision)
        queryByDistance = try values.decodeIfPresent(Bool.self, forKey: .queryByDistance)
        referenceTargetField = try values.decodeIfPresent(String.self, forKey: .referenceTargetField)
        referenceTo = try values.decodeIfPresent([String].self, forKey: .referenceTo)
        relationshipName = try values.decodeIfPresent(String.self, forKey: .relationshipName)
        relationshipOrder = try values.decodeIfPresent(String.self, forKey: .relationshipOrder)
        restrictedDelete = try values.decodeIfPresent(Bool.self, forKey: .restrictedDelete)
        restrictedPicklist = try values.decodeIfPresent(Bool.self, forKey: .restrictedPicklist)
        scale = try values.decodeIfPresent(Int.self, forKey: .scale)
        soapType = try values.decodeIfPresent(String.self, forKey: .soapType)
        sortable = try values.decodeIfPresent(Bool.self, forKey: .sortable)
        type = try values.decodeIfPresent(String.self, forKey: .type)
        unique = try values.decodeIfPresent(Bool.self, forKey: .unique)
        updateable = try values.decodeIfPresent(Bool.self, forKey: .updateable)
        writeRequiresMasterRead = try values.decodeIfPresent(Bool.self, forKey: .writeRequiresMasterRead)
    }
}

struct UrlList : Codable {
    let compactLayouts : String?
    let rowTemplate : String?
    let approvalLayouts : String?
    let uiDetailTemplate : String?
    let uiEditTemplate : String?
    let defaultValues : String?
    let listviews : String?
    let describe : String?
    let uiNewRecord : String?
    let quickActions : String?
    let layouts : String?
    let sobject : String?
    
    enum CodingKeys: String, CodingKey {
        case compactLayouts = "compactLayouts"
        case rowTemplate = "rowTemplate"
        case approvalLayouts = "approvalLayouts"
        case uiDetailTemplate = "uiDetailTemplate"
        case uiEditTemplate = "uiEditTemplate"
        case defaultValues = "defaultValues"
        case listviews = "listviews"
        case describe = "describe"
        case uiNewRecord = "uiNewRecord"
        case quickActions = "quickActions"
        case layouts = "layouts"
        case sobject = "sobject"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        compactLayouts = try values.decodeIfPresent(String.self, forKey: .compactLayouts)
        rowTemplate = try values.decodeIfPresent(String.self, forKey: .rowTemplate)
        approvalLayouts = try values.decodeIfPresent(String.self, forKey: .approvalLayouts)
        uiDetailTemplate = try values.decodeIfPresent(String.self, forKey: .uiDetailTemplate)
        uiEditTemplate = try values.decodeIfPresent(String.self, forKey: .uiEditTemplate)
        defaultValues = try values.decodeIfPresent(String.self, forKey: .defaultValues)
        listviews = try values.decodeIfPresent(String.self, forKey: .listviews)
        describe = try values.decodeIfPresent(String.self, forKey: .describe)
        uiNewRecord = try values.decodeIfPresent(String.self, forKey: .uiNewRecord)
        quickActions = try values.decodeIfPresent(String.self, forKey: .quickActions)
        layouts = try values.decodeIfPresent(String.self, forKey: .layouts)
        sobject = try values.decodeIfPresent(String.self, forKey: .sobject)
    }
}


struct ChildRelationship : Codable {
    
    let cascadeDelete : Bool?
    let childSObject : String?
    let deprecatedAndHidden : Bool?
    let field : String?
    let junctionIdListNames : [String]?
    let junctionReferenceTo : [String]?
    let relationshipName : String?
    let restrictedDelete : Bool?
    
    enum CodingKeys: String, CodingKey {
        case cascadeDelete = "cascadeDelete"
        case childSObject = "childSObject"
        case deprecatedAndHidden = "deprecatedAndHidden"
        case field = "field"
        case junctionIdListNames = "junctionIdListNames"
        case junctionReferenceTo = "junctionReferenceTo"
        case relationshipName = "relationshipName"
        case restrictedDelete = "restrictedDelete"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        cascadeDelete = try values.decodeIfPresent(Bool.self, forKey: .cascadeDelete)
        childSObject = try values.decodeIfPresent(String.self, forKey: .childSObject)
        deprecatedAndHidden = try values.decodeIfPresent(Bool.self, forKey: .deprecatedAndHidden)
        field = try values.decodeIfPresent(String.self, forKey: .field)
        junctionIdListNames = try values.decodeIfPresent([String].self, forKey: .junctionIdListNames)
        junctionReferenceTo = try values.decodeIfPresent([String].self, forKey: .junctionReferenceTo)
        relationshipName = try values.decodeIfPresent(String.self, forKey: .relationshipName)
        restrictedDelete = try values.decodeIfPresent(Bool.self, forKey: .restrictedDelete)
    }
    
}

struct SupportedScopes : Codable {
    let label : String?
    let name : String?
    
    enum CodingKeys: String, CodingKey {
        
        case label = "label"
        case name = "name"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        label = try values.decodeIfPresent(String.self, forKey: .label)
        name = try values.decodeIfPresent(String.self, forKey: .name)
    }
    
}

struct RecordTypeInfos : Codable {
    let available : Bool?
    let defaultRecordTypeMapping : Bool?
    let master : Bool?
    let name : String?
    let recordTypeId : String?
    let urls : UrlList?
    
    enum CodingKeys: String, CodingKey {
        case available = "available"
        case defaultRecordTypeMapping = "defaultRecordTypeMapping"
        case master = "master"
        case name = "name"
        case recordTypeId = "recordTypeId"
        case urls
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        available = try values.decodeIfPresent(Bool.self, forKey: .available)
        defaultRecordTypeMapping = try values.decodeIfPresent(Bool.self, forKey: .defaultRecordTypeMapping)
        master = try values.decodeIfPresent(Bool.self, forKey: .master)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        recordTypeId = try values.decodeIfPresent(String.self, forKey: .recordTypeId)
        urls = try UrlList(from: decoder)
    }
    
}

struct DescribeResponse : Codable {
    let actionOverrides : [String]?
    let activateable : Bool?
    let childRelationships : [ChildRelationship]?
    let compactLayoutable : Bool?
    let createable : Bool?
    let custom : Bool?
    let customSetting : Bool?
    let deletable : Bool?
    let deprecatedAndHidden : Bool?
    let feedEnabled : Bool?
    let fields : [Field]?
    let hasSubtypes : Bool?
    let isSubtype : Bool?
    let keyPrefix : Int?
    let label : String?
    let labelPlural : String?
    let layoutable : Bool?
    let listviewable : String?
    let lookupLayoutable : String?
    let mergeable : Bool?
    let mruEnabled : Bool?
    let name : String?
    let namedLayoutInfos : [String]?
    let networkScopeFieldName : String?
    let queryable : Bool?
    let recordTypeInfos : [RecordTypeInfos]?
    let replicateable : Bool?
    let retrieveable : Bool?
    let searchLayoutable : Bool?
    let searchable : Bool?
    let supportedScopes : [SupportedScopes]?
    let triggerable : Bool?
    let undeletable : Bool?
    let updateable : Bool?
    let urls : UrlList?
    
    enum CodingKeys: String, CodingKey {
        
        case actionOverrides = "actionOverrides"
        case activateable = "activateable"
        case childRelationships = "childRelationships"
        case compactLayoutable = "compactLayoutable"
        case createable = "createable"
        case custom = "custom"
        case customSetting = "customSetting"
        case deletable = "deletable"
        case deprecatedAndHidden = "deprecatedAndHidden"
        case feedEnabled = "feedEnabled"
        case fields = "fields"
        case hasSubtypes = "hasSubtypes"
        case isSubtype = "isSubtype"
        case keyPrefix = "keyPrefix"
        case label = "label"
        case labelPlural = "labelPlural"
        case layoutable = "layoutable"
        case listviewable = "listviewable"
        case lookupLayoutable = "lookupLayoutable"
        case mergeable = "mergeable"
        case mruEnabled = "mruEnabled"
        case name = "name"
        case namedLayoutInfos = "namedLayoutInfos"
        case networkScopeFieldName = "networkScopeFieldName"
        case queryable = "queryable"
        case recordTypeInfos = "recordTypeInfos"
        case replicateable = "replicateable"
        case retrieveable = "retrieveable"
        case searchLayoutable = "searchLayoutable"
        case searchable = "searchable"
        case supportedScopes = "supportedScopes"
        case triggerable = "triggerable"
        case undeletable = "undeletable"
        case updateable = "updateable"
        case urls
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        actionOverrides = try values.decodeIfPresent([String].self, forKey: .actionOverrides)
        activateable = try values.decodeIfPresent(Bool.self, forKey: .activateable)
        childRelationships = try values.decodeIfPresent([ChildRelationship].self, forKey: .childRelationships)
        compactLayoutable = try values.decodeIfPresent(Bool.self, forKey: .compactLayoutable)
        createable = try values.decodeIfPresent(Bool.self, forKey: .createable)
        custom = try values.decodeIfPresent(Bool.self, forKey: .custom)
        customSetting = try values.decodeIfPresent(Bool.self, forKey: .customSetting)
        deletable = try values.decodeIfPresent(Bool.self, forKey: .deletable)
        deprecatedAndHidden = try values.decodeIfPresent(Bool.self, forKey: .deprecatedAndHidden)
        feedEnabled = try values.decodeIfPresent(Bool.self, forKey: .feedEnabled)
        fields = try values.decodeIfPresent([Field].self, forKey: .fields)
        hasSubtypes = try values.decodeIfPresent(Bool.self, forKey: .hasSubtypes)
        isSubtype = try values.decodeIfPresent(Bool.self, forKey: .isSubtype)
        keyPrefix = try values.decodeIfPresent(Int.self, forKey: .keyPrefix)
        label = try values.decodeIfPresent(String.self, forKey: .label)
        labelPlural = try values.decodeIfPresent(String.self, forKey: .labelPlural)
        layoutable = try values.decodeIfPresent(Bool.self, forKey: .layoutable)
        listviewable = try values.decodeIfPresent(String.self, forKey: .listviewable)
        lookupLayoutable = try values.decodeIfPresent(String.self, forKey: .lookupLayoutable)
        mergeable = try values.decodeIfPresent(Bool.self, forKey: .mergeable)
        mruEnabled = try values.decodeIfPresent(Bool.self, forKey: .mruEnabled)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        namedLayoutInfos = try values.decodeIfPresent([String].self, forKey: .namedLayoutInfos)
        networkScopeFieldName = try values.decodeIfPresent(String.self, forKey: .networkScopeFieldName)
        queryable = try values.decodeIfPresent(Bool.self, forKey: .queryable)
        recordTypeInfos = try values.decodeIfPresent([RecordTypeInfos].self, forKey: .recordTypeInfos)
        replicateable = try values.decodeIfPresent(Bool.self, forKey: .replicateable)
        retrieveable = try values.decodeIfPresent(Bool.self, forKey: .retrieveable)
        searchLayoutable = try values.decodeIfPresent(Bool.self, forKey: .searchLayoutable)
        searchable = try values.decodeIfPresent(Bool.self, forKey: .searchable)
        supportedScopes = try values.decodeIfPresent([SupportedScopes].self, forKey: .supportedScopes)
        triggerable = try values.decodeIfPresent(Bool.self, forKey: .triggerable)
        undeletable = try values.decodeIfPresent(Bool.self, forKey: .undeletable)
        updateable = try values.decodeIfPresent(Bool.self, forKey: .updateable)
        urls = try UrlList(from: decoder)
    }
}

struct SObject : Codable {
    let activateable : Bool?
    let createable : Bool?
    let custom : Bool?
    let customSetting : Bool?
    let deletable : Bool?
    let deprecatedAndHidden : Bool?
    let feedEnabled : Bool?
    let hasSubtypes : Bool?
    let isSubtype : Bool?
    let keyPrefix : String?
    let label : String?
    let labelPlural : String?
    let layoutable : Bool?
    let mergeable : Bool?
    let mruEnabled : Bool?
    let name : String?
    let queryable : Bool?
    let replicateable : Bool?
    let retrieveable : Bool?
    let searchable : Bool?
    let triggerable : Bool?
    let undeletable : Bool?
    let updateable : Bool?
    let urls : UrlList?
    
    enum CodingKeys: String, CodingKey {
        case activateable = "activateable"
        case createable = "createable"
        case custom = "custom"
        case customSetting = "customSetting"
        case deletable = "deletable"
        case deprecatedAndHidden = "deprecatedAndHidden"
        case feedEnabled = "feedEnabled"
        case hasSubtypes = "hasSubtypes"
        case isSubtype = "isSubtype"
        case keyPrefix = "keyPrefix"
        case label = "label"
        case labelPlural = "labelPlural"
        case layoutable = "layoutable"
        case mergeable = "mergeable"
        case mruEnabled = "mruEnabled"
        case name = "name"
        case queryable = "queryable"
        case replicateable = "replicateable"
        case retrieveable = "retrieveable"
        case searchable = "searchable"
        case triggerable = "triggerable"
        case undeletable = "undeletable"
        case updateable = "updateable"
        case urls
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        activateable = try values.decodeIfPresent(Bool.self, forKey: .activateable)
        createable = try values.decodeIfPresent(Bool.self, forKey: .createable)
        custom = try values.decodeIfPresent(Bool.self, forKey: .custom)
        customSetting = try values.decodeIfPresent(Bool.self, forKey: .customSetting)
        deletable = try values.decodeIfPresent(Bool.self, forKey: .deletable)
        deprecatedAndHidden = try values.decodeIfPresent(Bool.self, forKey: .deprecatedAndHidden)
        feedEnabled = try values.decodeIfPresent(Bool.self, forKey: .feedEnabled)
        hasSubtypes = try values.decodeIfPresent(Bool.self, forKey: .hasSubtypes)
        isSubtype = try values.decodeIfPresent(Bool.self, forKey: .isSubtype)
        keyPrefix = try values.decodeIfPresent(String.self, forKey: .keyPrefix)
        label = try values.decodeIfPresent(String.self, forKey: .label)
        labelPlural = try values.decodeIfPresent(String.self, forKey: .labelPlural)
        layoutable = try values.decodeIfPresent(Bool.self, forKey: .layoutable)
        mergeable = try values.decodeIfPresent(Bool.self, forKey: .mergeable)
        mruEnabled = try values.decodeIfPresent(Bool.self, forKey: .mruEnabled)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        queryable = try values.decodeIfPresent(Bool.self, forKey: .queryable)
        replicateable = try values.decodeIfPresent(Bool.self, forKey: .replicateable)
        retrieveable = try values.decodeIfPresent(Bool.self, forKey: .retrieveable)
        searchable = try values.decodeIfPresent(Bool.self, forKey: .searchable)
        triggerable = try values.decodeIfPresent(Bool.self, forKey: .triggerable)
        undeletable = try values.decodeIfPresent(Bool.self, forKey: .undeletable)
        updateable = try values.decodeIfPresent(Bool.self, forKey: .updateable)
        urls = try UrlList(from: decoder)
    }
    
}

struct DescribeGlobalResponse : Codable {
    let encoding : String?
    let maxBatchSize : Int?
    let sobjects : [SObject]?
    
    enum CodingKeys: String, CodingKey {
        case encoding = "encoding"
        case maxBatchSize = "maxBatchSize"
        case sobjects = "sobjects"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        encoding = try values.decodeIfPresent(String.self, forKey: .encoding)
        maxBatchSize = try values.decodeIfPresent(Int.self, forKey: .maxBatchSize)
        sobjects = try values.decodeIfPresent([SObject].self, forKey: .sobjects)
    }
}

struct Attributes : Codable {
    let type : String?
    let url : String?
    
    enum CodingKeys: String, CodingKey {
        case type = "type"
        case url = "url"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decodeIfPresent(String.self, forKey: .type)
        url = try values.decodeIfPresent(String.self, forKey: .url)
    }
}

public class QueryResponseRecord : Codable {
    let attributes : Attributes?
    
    enum CodingKeys: String, CodingKey {
        case attributes
    }
    
    required public init(from decoder: Decoder) throws {
        let values =  try decoder.container(keyedBy: CodingKeys.self)
        attributes = try values.decodeIfPresent(Attributes.self, forKey: .attributes)
    }
}

struct QueryResponse<T:QueryResponseRecord> : Codable {
    let totalSize : Int?
    let done : Bool?
    let records : [T]?
    
    enum CodingKeys: String, CodingKey {
        case totalSize = "totalSize"
        case done = "done"
        case records = "records"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        totalSize = try values.decodeIfPresent(Int.self, forKey: .totalSize)
        done = try values.decodeIfPresent(Bool.self, forKey: .done)
        records = try values.decodeIfPresent([T].self, forKey: .records)
        
        // Decode records
        if var allRecords = try? values.nestedUnkeyedContainer(forKey: .records) {
            while (!allRecords.isAtEnd) {
                let record = try allRecords.decode(T.self)
                records?.append(record)
            }
        }
    }
}

struct SearchRecord : Codable {
    let attributes : Attributes?
    let id : String?
    
    enum CodingKeys: String, CodingKey {
        
        case attributes
        case id = "Id"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        attributes = try Attributes(from: decoder)
        id = try values.decodeIfPresent(String.self, forKey: .id)
    }
    
}

struct SearchResponse : Codable {
    let searchRecords : [SearchRecord]?
    
    enum CodingKeys: String, CodingKey {
        case searchRecords = "searchRecords"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        searchRecords = try values.decodeIfPresent([SearchRecord].self, forKey: .searchRecords)
    }
}
