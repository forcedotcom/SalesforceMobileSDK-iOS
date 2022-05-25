//
//  CompositeRequestHelper.swift
//  MobileSync
//
//  Created by Wolfgang Mathurin on 5/23/22.
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
import SalesforceSDKCore

typealias OnSendCompleteCallback =  (Dictionary<String, CompositeRequestHelper.RecordResponse>) -> ()
typealias OnFailCallback = (Error) -> ()

@objc(SFCompositeRequestHelper)
class CompositeRequestHelper:NSObject {
    //
    // Types of request
    //
    enum RequestType: CaseIterable {
       case CREATE, UPDATE, UPSERT, DELETE
    }
    
    //
    // Response object abstracting away differences between /composite/batch and /commposite/sobject sub-responses
    //
    @objc(SFSDKRecordResponse)
    class RecordResponse: NSObject {
        @objc let success: Bool
        @objc let objectId: String?
        @objc let recordDoesNotExist: Bool
        @objc let relatedRecordDoesNotExist: Bool
        @objc let errorJson: Dictionary<String, Any>?
        @objc let json: Any
        
        private init(success:Bool, objectId:String?, recordDoesNotExist:Bool, relatedRecordDoesNotExist:Bool, errorJson: Dictionary<String, Any>?, json:Any) {
            self.success = success
            self.objectId = objectId
            self.recordDoesNotExist = recordDoesNotExist
            self.relatedRecordDoesNotExist = relatedRecordDoesNotExist
            self.errorJson = errorJson
            self.json = json
        }
        
        func description() ->  String {
            return SFJsonUtils.jsonRepresentation(json)
        }
        
        static func fromCompositeSubResponse(compositeSubResponse: CompositeSubResponse) -> RecordResponse {
            let success = RestClient.isStatusCodeSuccess(UInt(compositeSubResponse.httpStatusCode))
            var objectId:String? = nil
            var recordDoesNotExist = false
            var relatedRecordDoesNotExist = false
            var errorJson:Dictionary<String, Any>? = nil
            
            if (success) {
                if let body = compositeSubResponse.body as? Dictionary<String, Any> {
                    objectId = body["id"] as? String
                }
            } else {
                recordDoesNotExist = RestClient.isStatusCodeNotFound(UInt(compositeSubResponse.httpStatusCode))
                if let bodyArray = compositeSubResponse.body as? Array<Dictionary<String, Any>> {
                    errorJson = bodyArray[0]
                    let firstError = errorJson?["errorCode"] as? String
                    relatedRecordDoesNotExist = firstError == "ENTITY_IS_DELETED"
                }
            }
            
            return RecordResponse(success:success, objectId: objectId, recordDoesNotExist: recordDoesNotExist, relatedRecordDoesNotExist: relatedRecordDoesNotExist, errorJson: errorJson, json: compositeSubResponse.dict)
            
        }
        
        static func fromCollectionSubResponse(collectionSubResponse: CollectionSubResponse) -> RecordResponse {
            let success = collectionSubResponse.success
            let objectId = collectionSubResponse.objectId
            var recordDoesNotExist = false
            var relatedRecordDoesNotExist = false
            var errorJson:Dictionary<String, Any>? = nil

            if (!success && !collectionSubResponse.errors.isEmpty) {
                errorJson = collectionSubResponse.errors[0].json
                let error = collectionSubResponse.errors[0].statusCode
                recordDoesNotExist = error == "INVALID_CROSS_REFERENCE_KEY" || error == "ENTITY_IS_DELETED"
                relatedRecordDoesNotExist = error == "ENTITY_IS_DELETED" // XXX ambiguous
            }
            
            return RecordResponse(success:success, objectId: objectId, recordDoesNotExist: recordDoesNotExist, relatedRecordDoesNotExist: relatedRecordDoesNotExist, errorJson: errorJson, json: collectionSubResponse.json)
        }
    }

    //
    // Request object abstracting away differences between /composite/batch and /commposite/sobject sub-requests
    //
    @objc(SFSDKRecordRequest)
    class RecordRequest: NSObject {
        var referenceId: String?
        let requestType: RequestType
        let objectType: String
        let fields: Dictionary<String, Any>?
        let objectId: String?
        let externalId: String?
        let externalIdFieldName: String?
        
        private init(requestType:RequestType, objectType:String, fields:Dictionary<String, Any>?, objectId: String?, externalId: String?, externalIdFieldName: String?) {
            self.requestType = requestType
            self.objectType = objectType
            self.fields = fields
            self.objectId = objectId
            self.externalId = externalId
            self.externalIdFieldName = externalIdFieldName
        }
        
        func asRestRequest() -> RestRequest? {
           switch (requestType) {
           case .CREATE:
               return RestClient.shared.requestForCreate(withObjectType: objectType, fields: fields, apiVersion: nil)
           case .UPDATE:
               return RestClient.shared.requestForUpdate(withObjectType: objectType, objectId: objectId!, fields: fields, apiVersion: nil)
           case .UPSERT:
               return RestClient.shared.requestForUpsert(withObjectType: objectType, externalIdField: externalIdFieldName!, externalId: externalId, fields: fields!, apiVersion: nil)
           case .DELETE:
               return RestClient.shared.requestForDelete(withObjectType: objectType, objectId: objectId!, apiVersion: nil)
           }
        }
        
        func  asDictForCollectionRequest() -> Dictionary<String, Any> {
            var record:Dictionary<String, Any> = Dictionary()
            record["attributes"] = ["type": objectType]
           if let fields = fields {
               for (fieldName, fieldValue) in fields {
                   record[fieldName] = fieldValue
               }
            }
            
            if (requestType == .UPDATE) {
                record["Id"] = objectId
            }
                        
            if (requestType == .UPSERT) {
                if let externalIdFieldName = externalIdFieldName {
                    record[externalIdFieldName] = externalId
                }
            }
            
            return record
        }
        
        @objc
        static func requestForCreate(objectType:String, fields:Dictionary<String, Any>) -> RecordRequest {
            return RecordRequest(requestType:.CREATE, objectType: objectType, fields: fields, objectId: nil, externalId: nil, externalIdFieldName: nil)
        }

        @objc
        static func requestForUpdate(objectType:String, objectId:String, fields:Dictionary<String, Any>) -> RecordRequest {
            return RecordRequest(requestType:.UPDATE, objectType: objectType, fields: fields, objectId: objectId, externalId: nil, externalIdFieldName: nil)
        }

        @objc
        static func requestForUpsert(objectType:String, externalIdFieldName:String, externalId:String, fields:Dictionary<String, Any>) -> RecordRequest {
            return RecordRequest(requestType:.UPSERT, objectType: objectType, fields: fields, objectId: nil, externalId: externalId, externalIdFieldName: externalIdFieldName)
        }

        @objc
        static func requestForDelete(objectType:String, objectId: String) -> RecordRequest {
            return RecordRequest(requestType:.DELETE, objectType: objectType, fields: nil, objectId: objectId, externalId: nil, externalIdFieldName: nil)
        }
        
        static func getRefIds(recordRequests:Array<RecordRequest>, requestType:RequestType) -> Array<String> {
            return recordRequests
                .filter { $0.requestType == requestType }
                .map { $0.referenceId! }
        }

        static func getIds(recordRequests:Array<RecordRequest>, requestType:RequestType) -> Array<String> {
            return recordRequests
                .filter { $0.requestType == requestType }
                .map { $0.objectId! }
        }

        static func getObjectTypes(recordRequests:Array<RecordRequest>, requestType:RequestType) -> Array<String> {
            return recordRequests
                .filter { $0.requestType == requestType }
                .map { $0.objectType }
        }
        
        static func getExternalIdFieldName(recordRequests:Array<RecordRequest>, requestType:RequestType) -> Array<String> {
            return recordRequests
                .filter { $0.requestType == requestType }
                .map { $0.externalIdFieldName! }
        }
        
        static func getArrayForCollectionRequest(recordRequests:Array<RecordRequest>, requestType:RequestType) -> Array<Dictionary<String, Any>> {
            return recordRequests
                .filter { $0.requestType == requestType }
                .map { $0.asDictForCollectionRequest() }
        }
        
        static func getCollectionRequest(recordRequests:Array<RecordRequest>, requestType:RequestType, allOrNone: Bool) -> RestRequest? {
            switch (requestType) {
            case .CREATE:
                return RestClient.shared.request(forCollectionCreate: allOrNone,
                                                 records: getArrayForCollectionRequest(recordRequests: recordRequests, requestType: .CREATE),
                                                 apiVersion: nil)
            case .UPDATE:
                return RestClient.shared.request(forCollectionUpdate: allOrNone,
                                                 records: getArrayForCollectionRequest(recordRequests: recordRequests, requestType: .UPDATE),
                                                 apiVersion: nil)
            case .UPSERT:
                let records = getArrayForCollectionRequest(recordRequests: recordRequests, requestType: .UPSERT)
                if (!records.isEmpty) {
                    let objectTypes = getObjectTypes(recordRequests: recordRequests, requestType: .UPSERT)
                    let externalIdFieldNames = getExternalIdFieldName(recordRequests: recordRequests, requestType: .UPSERT)
                    
                    if (objectTypes.isEmpty || externalIdFieldNames.isEmpty) {
                        // throw new SyncManager.MobileSyncException("Missing sobjectType or externalIdFieldName")
                    }
                    
                    if (Set(objectTypes).count > 1) {
                        // throw new SyncManager.MobileSyncException("All records must have same sobjectType");
                    }
                    
                    let objectType = objectTypes.first!
                    let externalIdFieldName = externalIdFieldNames.first!
                    
                    return RestClient.shared.request(forCollectionUpsert: objectType, externalIdField: externalIdFieldName, allOrNone: allOrNone, records: records, apiVersion: nil)
                }
            case .DELETE:
                return RestClient.shared.request(forCollectionDelete: getIds(recordRequests: recordRequests, requestType: .DELETE),
                                                 apiVersion: nil)
            }
            
            return nil
        }
    }

    // Send record requests using a composite batch request
    @objc
    static func sendAsCompositeBatchRequest(_ syncManager: SyncManager, allOrNone: Bool, recordRequests: Array<RecordRequest>, onComplete: @escaping OnSendCompleteCallback, onFail: @escaping OnFailCallback) {
        
        let request = RestClient.shared.compositeRequest(recordRequests.map { $0.asRestRequest()! },
                                                         refIds: recordRequests.map { $0.referenceId! },
                                                         allOrNone: allOrNone,
                                                         apiVersion: nil)
  
        NetworkUtils.sendRequest(withMobileSyncUserAgent: request) { response, error, urlResponse in
            onFail(error!)
        } successBlock: { response, urlResponse in
            if let response  = response as? Dictionary<String, Any> {
                var refIdToRecordResponse = Dictionary<String, RecordResponse>()
                let compositeResponse = CompositeResponse(response)
                compositeResponse.subResponses.forEach {
                    refIdToRecordResponse[$0.referenceId] = RecordResponse.fromCompositeSubResponse(compositeSubResponse:$0)
                }
                onComplete(refIdToRecordResponse)
            }
        }
    }
        
    // Send record requests using sobject collection requests
    @objc
    static func sendAsCollectionRequests(_ syncManager: SyncManager, allOrNone: Bool, recordRequests: Array<RecordRequest>, onComplete: @escaping OnSendCompleteCallback, onFail: @escaping OnFailCallback)  {
        

        let group = DispatchGroup()
        var refIdToRecordResponse = Dictionary<String, RecordResponse>()
        for requestType in RequestType.allCases {
            let refIds = RecordRequest.getRefIds(recordRequests: recordRequests, requestType: requestType)
            if (!refIds.isEmpty) {
                let request = RecordRequest.getCollectionRequest(recordRequests: recordRequests, requestType: requestType, allOrNone: allOrNone)!
                group.enter()
                NetworkUtils.sendRequest(withMobileSyncUserAgent: request) { response, error, urlResponse in
                    onFail(error!)
                } successBlock: { response, urlResponse in
                    if let response  = response as? Array<Dictionary<String, Any>> {
                        let collectionResponse = CollectionResponse(response)
                        for (i, subResponse) in collectionResponse.subResponses.enumerated() {
                            let refId = refIds[i]
                            refIdToRecordResponse[refId] = RecordResponse.fromCollectionSubResponse(collectionSubResponse:subResponse)
                        }
                        group.leave()
                    }
                }
            }
        }
        
        group.notify(queue: DispatchQueue.global()) {
            onComplete(refIdToRecordResponse)
        }
    }
    
    // Return ref id to server id map if successful
    @objc
    static func parseIdsFromResponses(_ refIdToRecordResponse:Dictionary<String, RecordResponse>) -> Dictionary<String, String> {
        return refIdToRecordResponse.mapValues { $0.objectId! }
    }
    
    // Update id field with server id
    @objc
    static func updateReferences(_ record: Dictionary<String, Any>, fieldWithRefId:String, refIdToServerId:Dictionary<String, String>) -> Dictionary<String, Any> {
        var updatedRecord = Dictionary<String, Any>()
        for (fieldName, fieldValue) in record {
            if fieldName == fieldWithRefId {
                if let refId = fieldValue as? String, let serverId = refIdToServerId[refId] {
                    updatedRecord[fieldName] = serverId
                }
            } else {
                updatedRecord[fieldName] = fieldValue
            }
        }
        return updatedRecord
    }
}
