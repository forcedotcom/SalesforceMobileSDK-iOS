import Foundation

/*
 SmartStire.swift
 SalesforceSDKCore
 
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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


import Combine

struct Constants {
    static let PAGE_SIZE: UInt = 65536
}

/**
  Error used by Combine friendly query:smartSql method in SmartStore extension below
 */
public enum QueryError: Error {
    case error(_ error: Error?)
    case unknown
}

/**
SmartStore extension
*/
extension SmartStore {
    /**
      Runs a query and return a Result<>
      @param smartSql:String the query smart sql
      @return a Result<[Any], QueryError>
    */
    func query(_ smartSql: String) -> Result<[Any], QueryError> {
        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: Constants.PAGE_SIZE)!
        
        do {
            let results = try self.query(using: querySpec, startingFromPageIndex: 0)
            return .success(results)
        } catch let error {
            return .failure(.error(error))
        }
    }
}

/**
SmartStore extension for iOS 13 and above
*/
@available(iOS 13.0, watchOS 6.0, *)
extension SmartStore {
    
    /**
        Runs a query and return a Future<> publisher to consume the result
        @param smartSql:String the query smart sql
        @return a Future<[Any], QueryError> publisher
     */
    func publisher(_ smartSql: String) -> Future<[Any], QueryError> {
        Future<[Any], QueryError> { promise in
            let result = self.query(smartSql)
            switch result {
                case .success(let results):
                    promise(.success(results))
                case .failure(let error):
                    promise(.failure(error))
            }
        }
    }
    
}
