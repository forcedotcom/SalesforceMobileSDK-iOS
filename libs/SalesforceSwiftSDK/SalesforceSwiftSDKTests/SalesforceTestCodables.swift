/*
 SalesforceTestCodables
 Created by Raj Rao on 12/07/17.
 
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

public struct Attributes : Codable {
    let type : String?
    let url : String?
    
    enum CodingKeys: String, CodingKey {
        case type = "type"
        case url = "url"
    }
    
    public init(from decoder: Decoder) throws {
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

public struct QueryResponse<T:QueryResponseRecord> : Codable {
    let totalSize : Int?
    let done : Bool?
    let records : [T]?
    
    enum CodingKeys: String, CodingKey {
        case totalSize = "totalSize"
        case done = "done"
        case records = "records"
    }
    
    public init(from decoder: Decoder) throws {
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

public class SearchResponseRecord : Codable {
    let attributes : Attributes?
    let id : String?
    
    enum CodingKeys: String, CodingKey {
        case attributes
        case id = "Id"
    }
    
    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        attributes = try Attributes(from: decoder)
        id = try values.decodeIfPresent(String.self, forKey: .id)
    }
}

public struct SearchResponse<T:SearchResponseRecord> : Codable {
    let searchRecords : [T]?
    
    enum CodingKeys: String, CodingKey {
        case searchRecords = "searchRecords"
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        searchRecords = try values.decodeIfPresent([T].self, forKey: .searchRecords)
    }
    
}

class SampleRecord : QueryResponseRecord {
    let id : String?
    let firstName : String?
    let lastName : String?
    
    enum SampleRecordCodingKeys: String, CodingKey {
        case id = "Id"
        case firstName = "FirstName"
        case lastName = "LastName"
    }
    
    required init(from decoder: Decoder) throws {
        let values =  try decoder.container(keyedBy: SampleRecordCodingKeys.self)
        self.id = try values.decodeIfPresent(String.self, forKey: .id)
        self.firstName = try values.decodeIfPresent(String.self, forKey: .firstName)
        self.lastName = try values.decodeIfPresent(String.self, forKey: .lastName)
        try super.init(from: decoder)
    }
}

class SearchRecord : SearchResponseRecord {
    let firstName : String?
    let lastName : String?
    
    enum SampleRecordCodingKeys: String, CodingKey {
        case firstName = "FirstName"
        case lastName = "LastName"
    }
    
    required init(from decoder: Decoder) throws {
        let values =  try decoder.container(keyedBy: SampleRecordCodingKeys.self)
        self.firstName = try values.decodeIfPresent(String.self, forKey: .firstName)
        self.lastName = try values.decodeIfPresent(String.self, forKey: .lastName)
        try super.init(from: decoder)
    }
}

public struct CompositeSubResponse : Decodable {
    
    let body : [String:Any]?
    let httpHeaders : [String:Any]?
    let httpStatusCode : Int?
    let referenceId : String?
    
    enum CodingKeys: String, CodingKey {
        case body
        case httpHeaders
        case httpStatusCode = "httpStatusCode"
        case referenceId = "referenceId"
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        //FIXME: need to add a KeyedCodingContainer with dynamic keys to address nested dictionary
        body =  ["":""] //try values.decodeIfPresent([String: Any].self,forKey: .body)
        httpHeaders = ["":""]  //try values.decodeIfPresent([String: Any].self, forKey: .httpHeaders)
        httpStatusCode = try values.decodeIfPresent(Int.self, forKey: .httpStatusCode)
        referenceId = try values.decodeIfPresent(String.self, forKey: .referenceId)
    }
}

public struct CompositeResponse : Decodable {
    
    let subResponses : [CompositeSubResponse]?
    
    enum CodingKeys: String, CodingKey {
        case compositeResponse = "compositeResponse"
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        subResponses = try values.decodeIfPresent([CompositeSubResponse].self, forKey: .compositeResponse)
    }
}
