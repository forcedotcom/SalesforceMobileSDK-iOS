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

public class SearchRecord : Codable {
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
