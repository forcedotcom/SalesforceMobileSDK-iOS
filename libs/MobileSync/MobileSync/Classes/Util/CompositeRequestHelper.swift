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

class CompositeRequestHelper {

   /**
    * Send record requests using a composite batch request
    */
    static func sendAsCompositeBatchRequest(syncManager: SyncManager, allOrNone: Bool, recordRequests: Array<RecordRequest>) -> Dictionary<String, RecordResponse>  {
        
        let compositeRequestBuilder = CompositeRequestBuilder().setAllOrNone(allOrNone)
        for recordRequest in recordRequests {
            if let restRequest = recordRequest.asRestRequest() {
                compositeRequestBuilder.add(restRequest, referenceId: recordRequest.referenceId!)
            }
        }
//        let request = compositeRequestBuilder.buildCompositeRequest(nil)
//
//        NetworkUtils.sendRequest(withMobileSyncUserAgent: request) { response, error, urlResponse in
//            errorBlock(error)
//        } successBlock: { response, urlResponse in
//            if let records = response as? [[String: Any]] {
//                allRecords.append(contentsOf: records)
//                group.leave()
//            } else {
//                errorBlock(nil)
//            }
//        }
        
        return Dictionary() // FIXME
    }
        
//        RestResponse response = syncManager.sendSyncWithMobileSyncUserAgent(compositeRequest);
//        if (!response.isSuccess()) {
//            throw new SyncManager.MobileSyncException("sendCompositeRequest:" + response);
//        }
//        CompositeResponse compositeResponse = new CompositeResponse(response.asJSONObject());
//        Map<String, RecordResponse> refIdToRecordResponses = new LinkedHashMap<>();
//        for (CompositeSubResponse subResponse : compositeResponse.subResponses) {
//            RecordResponse recordResponse = RecordResponse.fromCompositeSubResponse(subResponse);
//            refIdToRecordResponses.put(subResponse.referenceId, recordResponse);
//        }
//        return refIdToRecordResponses;
//   }

   /**
    * Send record requests using sobject collection requests
    */
//   public static Map<String, RecordResponse> sendAsCollectionRequests(SyncManager syncManager, boolean allOrNone, List<RecordRequest> recordRequests) throws JSONException, IOException {
//       Map<String, RecordResponse> refIdToRecordResponses = new LinkedHashMap<>();
//
//       for (RequestType requestType : RequestType.values()) {
//           List<String> refIds = RecordRequest.getRefIds(recordRequests, requestType);
//           if (refIds.size() > 0) {
//               RestRequest request = RecordRequest
//                   .getCollectionRequest(syncManager.apiVersion, allOrNone, recordRequests, requestType);
//               RestResponse response = syncManager.sendSyncWithMobileSyncUserAgent(request);
//               if (!response.isSuccess()) {
//                   throw new SyncManager.MobileSyncException(
//                       "sendAsCollectionRequests:" + response);
//               } else {
//                   List<CollectionSubResponse> subResponses = new CollectionResponse(
//                       response.asJSONArray()).subResponses;
//                   for (int i = 0; i < subResponses.size(); i++) {
//                       String refId = refIds.get(i);
//                       RecordResponse recordResponse = RecordResponse.fromCollectionSubResponse(subResponses.get(i));
//                       refIdToRecordResponses.put(refId, recordResponse);
//                   }
//               }
//           }
//       }
//
//       return refIdToRecordResponses;
//   }
//
//   /**
//    * Return ref id to server id map if successful
//    */
//   public static Map<String, String> parseIdsFromResponses(Map<String, RecordResponse> refIdToRecordResponse) throws JSONException {
//       Map<String, String> refIdToServerId = new HashMap<>();
//       for (Map.Entry<String, RecordResponse> entry : refIdToRecordResponse.entrySet()) {
//           String refId = entry.getKey();
//           RecordResponse recordResponse = entry.getValue();
//           if (recordResponse.id != null) {
//               refIdToServerId.put(refId, recordResponse.id);
//           }
//       }
//       return refIdToServerId;
//   }
//
//   /**
//    * Update id field with server id
//    */
//   public static void updateReferences(JSONObject record, String fieldWithRefId, Map<String, String> refIdToServerId) throws JSONException {
//       String refId = JSONObjectHelper.optString(record, fieldWithRefId);
//       if (refId != null && refIdToServerId.containsKey(refId)) {
//           record.put(fieldWithRefId, refIdToServerId.get(refId));
//       }
//   }

    /**
    * Response object abstracting away differences between /composite/batch and /commposite/sobject sub-responses
    */
    @objc(SFSDKRecordResponse)
    class RecordResponse: NSObject {
        let success: Bool
        let recordId: String?
        let recordDoesNotExist: Bool
        let relatedRecordDoesNotExist: Bool
        let json: Any
        
        private init(success:Bool, recordId:String?, recordDoesNotExist:Bool, relatedRecordDoesNotExist:Bool, json:Any) {
            self.success = success
            self.recordId = recordId
            self.recordDoesNotExist = recordDoesNotExist
            self.relatedRecordDoesNotExist = relatedRecordDoesNotExist
            self.json = json
        }
        
        static func fromCompositeSubResponse(compositeSubResponse: CompositeSubResponse) -> RecordResponse {
            let success = RestClient.isStatusCodeSuccess(UInt(compositeSubResponse.httpStatusCode))
            var recordId:String? = nil
            var recordDoesNotExist = false
            var relatedRecordDoesNotExist = false
            
            if (success) {
                if let body = compositeSubResponse.body as? Dictionary<String, Any> {
                    recordId = body["id"] as? String
                }
            } else {
                recordDoesNotExist = RestClient.isStatusCodeNotFound(UInt(compositeSubResponse.httpStatusCode))
                if let bodyArray = compositeSubResponse.body as? Array<Dictionary<String, Any>> {
                    let firstError = bodyArray[0]["errorCode"] as? String
                    relatedRecordDoesNotExist = firstError == "ENTITY_IS_DELETED"
                }
            }
            
            return RecordResponse(success:success, recordId: recordId, recordDoesNotExist: recordDoesNotExist, relatedRecordDoesNotExist: relatedRecordDoesNotExist, json: compositeSubResponse.dict)
            
        }
        
        static func fromCollectionSubResponse(collectionSubResponse: CollectionSubResponse) -> RecordResponse {
            let success = collectionSubResponse.success
            let recordId = collectionSubResponse.objectId
            var recordDoesNotExist = false
            var relatedRecordDoesNotExist = false
            
            if (!success && !collectionSubResponse.errors.isEmpty) {
                let error = collectionSubResponse.errors[0].statusCode
                recordDoesNotExist = error == "INVALID_CROSS_REFERENCE_KEY" || error == "ENTITY_IS_DELETED"
                relatedRecordDoesNotExist = error == "ENTITY_IS_DELETED" // XXX ambiguous
            }
            
            return RecordResponse(success:success, recordId: recordId, recordDoesNotExist: recordDoesNotExist, relatedRecordDoesNotExist: relatedRecordDoesNotExist, json: collectionSubResponse.json)
        }
    }

    /**
    * Request object abstracting away differences between /composite/batch and /commposite/sobject sub-requests
    */
    @objc(SFSDKRecordRequest)
    class RecordRequest: NSObject {
        var referenceId: String?
        let requestType: RequestType
        let objectType: String
        let fields: Dictionary<String, Any>?
        let recordId: String?
        let externalId: String?
        let externalIdFieldName: String?
        
        private init(requestType:RequestType, objectType:String, fields:Dictionary<String, Any>?, recordId: String?, externalId: String?, externalIdFieldName: String?) {
            self.requestType = requestType
            self.objectType = objectType
            self.fields = fields
            self.recordId = recordId
            self.externalId = externalId
            self.externalIdFieldName = externalIdFieldName
        }
        
        func asRestRequest() -> RestRequest? {
           switch (requestType) {
           case .CREATE:
               return RestClient.shared.requestForCreate(withObjectType: objectType, fields: fields, apiVersion: nil)
           case .UPDATE:
               return RestClient.shared.requestForUpdate(withObjectType: objectType, objectId: recordId!, fields: fields, apiVersion: nil)
           case .UPSERT:
               return RestClient.shared.requestForUpsert(withObjectType: objectType, externalIdField: externalIdFieldName!, externalId: externalId, fields: fields!, apiVersion: nil)
           case .DELETE:
               return RestClient.shared.requestForDelete(withObjectType: objectType, objectId: recordId!, apiVersion: nil)
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
                record["Id"] = recordId
            }
                        
            if (requestType == .UPSERT) {
                if let externalIdFieldName = externalIdFieldName {
                    record[externalIdFieldName] = externalId
                }
            }
            
            return record
        }
        
        static func requestForCreate(objectType:String, fields:Dictionary<String, Any>) -> RecordRequest {
            return RecordRequest(requestType:.CREATE, objectType: objectType, fields: fields, recordId: nil, externalId: nil, externalIdFieldName: nil)
        }

        static func requestForUpdate(objectType:String, recordId:String, fields:Dictionary<String, Any>) -> RecordRequest {
            return RecordRequest(requestType:.UPDATE, objectType: objectType, fields: fields, recordId: recordId, externalId: nil, externalIdFieldName: nil)
        }

        static func requestForUpsert(objectType:String, externalIdFieldName:String, externalId:String, fields:Dictionary<String, Any>) -> RecordRequest {
            return RecordRequest(requestType:.UPSERT, objectType: objectType, fields: fields, recordId: nil, externalId: externalId, externalIdFieldName: externalIdFieldName)
        }

        static func requestForUpdate(objectType:String, recordId: String) -> RecordRequest {
            return RecordRequest(requestType:.DELETE, objectType: objectType, fields: nil, recordId: recordId, externalId: nil, externalIdFieldName: nil)
        }
        
        static func getRefIds(recordRequests:Array<RecordRequest>, requestType:RequestType) -> Array<String> {
            return recordRequests
                .filter { $0.requestType == requestType }
                .map { $0.referenceId! }
        }

        static func getIds(recordRequests:Array<RecordRequest>, requestType:RequestType) -> Array<String> {
            return recordRequests
                .filter { $0.requestType == requestType }
                .map { $0.recordId! }
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

    enum RequestType {
       case CREATE, UPDATE,UPSERT, DELETE
    }
}

