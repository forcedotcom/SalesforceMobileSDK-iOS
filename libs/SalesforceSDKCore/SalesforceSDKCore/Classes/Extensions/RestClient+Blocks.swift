//
//  RestClient+Blocks.swift
//  SalesforceSDKCore
//
//  Created by Riley Crebs on 5/6/25.
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

import Foundation

// MARK: - Swift Block Definitions (for clarity in Swift)
public typealias SFRestRequestFailBlock = (_ response: Any?, _ error: Error?, _ rawResponse: URLResponse?) -> Void
public typealias SFRestDictionaryResponseBlock = (_ dict: [String: Any]?, _ rawResponse: URLResponse?) -> Void
public typealias SFRestArrayResponseBlock = (_ array: [Any]?, _ rawResponse: URLResponse?) -> Void
public typealias SFRestDataResponseBlock = (_ data: Data?, _ rawResponse: URLResponse?) -> Void
public typealias SFRestResponseBlock = (_ response: Any?, _ rawResponse: URLResponse?) -> Void
public typealias SFRestCompositeResponseBlock = (_ response: CompositeResponse, _ rawResponse: URLResponse?) -> Void
public typealias SFRestBatchResponseBlock = (_ response: BatchResponse, _ rawResponse: URLResponse?) -> Void

// MARK: - RestClient Extension
@objc extension RestClient {

    /** Creates an error object with the given description.
     @param description Description
     */
    @objc(errorWithDescription:)
    public static func error(withDescription description: String) -> NSError {
        let userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: description,
            NSFilePathErrorKey: ""
        ]
        return NSError(domain: "API Error", code: 42, userInfo: userInfo)
    }

    /**
     * Sends a request you've already built, using blocks to return status.
     *
     * @param request SFRestRequest to be sent.
     * @param failureBlock Block to be executed when the request fails (timeout, cancel, or error).
     * @param successBlock Block to be executed when the request successfully completes.
     */
    @objc(sendRequest:failureBlock:successBlock:)
    public func sendRequest(_ request: RestRequest,
                            failureBlock: @escaping SFRestRequestFailBlock,
                            successBlock: @escaping SFRestResponseBlock) {
        self.send(request, failureBlock: failureBlock, successBlock: successBlock)
    }


    /**
     * Sends a request you've already built, using blocks to return status.
     *
     * @param request Composite request to be sent.
     * @param failureBlock Block to be executed when the request fails (timeout, cancel, or error).
     * @param successBlock Block to be executed when the request successfully completes.
     */
    @objc(sendCompositeRequest:failureBlock:successBlock:)
    public func sendCompositeRequest(_ request: CompositeRequest,
                                     failureBlock: @escaping SFRestRequestFailBlock,
                                     successBlock: @escaping SFRestCompositeResponseBlock) {
        self.sendRequest(request, failureBlock: failureBlock) { response, rawResponse in
            do {
                guard let dict = response as? [AnyHashable: Any] else {
                    let errFunc: (String) -> NSError = RestClient.error(withDescription:)
                    throw errFunc("CompositeResponse format invalid")
                }
                let compositeResponse = CompositeResponse(dict)
                successBlock(compositeResponse, rawResponse)
            } catch {
                failureBlock(response, error, rawResponse)
            }
        }
    }

    /**
     * Sends a request you've already built, using blocks to return status.
     *
     * @param request Batch request to be sent.
     * @param failureBlock Block to be executed when the request fails (timeout, cancel, or error).
     * @param successBlock Block to be executed when the request successfully completes.
     */
    @objc(sendBatchRequest:failureBlock:successBlock:)
    public func sendBatchRequest(_ request: BatchRequest,
                                 failureBlock: @escaping SFRestRequestFailBlock,
                                 successBlock: @escaping SFRestBatchResponseBlock) {
        self.sendRequest(request, failureBlock: failureBlock) { response, rawResponse in
            do {
                guard let dict = response as? [AnyHashable: Any] else {
                    let errFunc: (String) -> NSError = RestClient.error(withDescription:)
                    throw errFunc("BatchResponse format invalid")
                }
                let batchResponse = BatchResponse(dict)
                successBlock(batchResponse, rawResponse)
            } catch {
                failureBlock(response, error, rawResponse)
            }
        }
    }
}
