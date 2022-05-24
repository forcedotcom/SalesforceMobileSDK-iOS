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
    class RecordResponse {
        let success: Bool
        let recordId: String
        let recordDoesNotExist: Bool
        let relatedRecordDoesNotExist: Bool
        let json: Dictionary<String, Any>
        
        init(success:Bool, recordId:String, recordDoesNotExist:Bool, relatedRecordDoesNotExist:Bool, json:Dictionary<String, Any>) {
            self.success = success
            self.recordId = recordId
            self.recordDoesNotExist = recordDoesNotExist
            self.relatedRecordDoesNotExist = relatedRecordDoesNotExist
            self.json = json
        }

    //   private RecordResponse(boolean success, String id, boolean recordDoesNotExist, boolean relatedRecordDoesNotExist, JSONObject json) {
    //       this.success = success;
    //       this.id = id;
    //       this.recordDoesNotExist = recordDoesNotExist;
    //       this.relatedRecordDoesNotExist = relatedRecordDoesNotExist;
    //       this.json = json;
    //   }
    //
    //   @Override
    //   public String toString() {
    //       return json.toString();
    //   }
    //
    //   static RecordResponse fromCompositeSubResponse(CompositeSubResponse compositeSubResponse) throws JSONException {
    //       boolean success = compositeSubResponse.isSuccess();
    //       String id = null;
    //       String refId = compositeSubResponse.referenceId;
    //       boolean recordDoesNotExist = false;
    //       boolean relatedRecordDoesNotExist = false;
    //       if (success) {
    //           JSONObject responseBodyResponse = compositeSubResponse.bodyAsJSONObject();
    //           if (responseBodyResponse != null) {
    //               id = JSONObjectHelper.optString(responseBodyResponse, Constants.LID);
    //           }
    //       } else {
    //           recordDoesNotExist = compositeSubResponse.httpStatusCode == HttpURLConnection.HTTP_NOT_FOUND;
    //           JSONArray bodyArray = compositeSubResponse.bodyAsJSONArray();
    //           JSONObject firstError = bodyArray != null && bodyArray.length() > 0 ? bodyArray.getJSONObject(0) : null;
    //           relatedRecordDoesNotExist = firstError != null ? "ENTITY_IS_DELETED".equals(firstError.getString("errorCode")) : false;
    //       }
    //       return new RecordResponse(success, id, recordDoesNotExist, relatedRecordDoesNotExist, compositeSubResponse.json);
    //   }
    //
    //   static RecordResponse fromCollectionSubResponse(CollectionSubResponse collectionSubResponse) {
    //       boolean success = collectionSubResponse.success;
    //       String id = collectionSubResponse.id;
    //       boolean recordDoesNotExist = false;
    //       boolean relatedRecordDoesNotExist = false;
    //       if (!collectionSubResponse.success && !collectionSubResponse.errors.isEmpty()) {
    //           String error = collectionSubResponse.errors.get(0).statusCode;
    //           recordDoesNotExist = "INVALID_CROSS_REFERENCE_KEY".equals(error)
    //               || "ENTITY_IS_DELETED".equals(error);
    //           relatedRecordDoesNotExist = "ENTITY_IS_DELETED".equals(error); // XXX ambiguous
    //       }
    //       return new RecordResponse(success, id, recordDoesNotExist, relatedRecordDoesNotExist, collectionSubResponse.json);
    //   }
    }

    /**
    * Request object abstracting away differences between /composite/batch and /commposite/sobject sub-requests
    */
    class RecordRequest {
        let referenceId: String?
        let requestType: RequestType
        let objectType: String
        let fields: Dictionary<String, Any>?
        let recordId: String?
        let externalId: String?
        let externalIdFieldName: String?
        
        init(requestType:RequestType, objectType:String, fields:Dictionary<String, Any>, recordId: String, externalId: String, externalIdFieldName: String) {
            self.requestType = requestType
            self.objectType = objectType
            self.fields = fields
            self.recordId = recordId
            self.externalId = externalId
            self.externalIdFieldName = externalIdFieldName
        }
        
    //   private RecordRequest(RequestType requestType, String objectType, Map<String, Object> fields, String id, String externalId, String externalIdFieldName) {
    //       this.requestType = requestType;
    //       this.objectType = objectType;
    //       this.fields = fields;
    //       this.id = id;
    //       this.externalId = externalId;
    //       this.externalIdFieldName = externalIdFieldName;
    //   }
    //
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
           // We should never get here
           return nil
        }
    //
    //   JSONObject asJSONObjectForCollectionRequest() throws JSONException {
    //       JSONObject record = new JSONObject();
    //       JSONObject attributes = new JSONObject();
    //       attributes.put(Constants.LTYPE, objectType);
    //       record.put(Constants.ATTRIBUTES, attributes);
    //       if (fields != null) {
    //           for (Map.Entry<String, Object> entry : fields.entrySet()) {
    //               record.put(entry.getKey(), entry.getValue());
    //           }
    //       }
    //
    //       if (requestType == RequestType.UPDATE) {
    //           record.put(Constants.ID, id);
    //       }
    //
    //       if (requestType == RequestType.UPSERT) {
    //           record.put(externalIdFieldName, externalId);
    //       }
    //
    //       return record;
    //   }
    //
    //   static RecordRequest requestForCreate(String objectType, Map<String, Object> fields) {
    //       return new RecordRequest(RequestType.CREATE, objectType, fields, null, null, null);
    //   }
    //
    //   static RecordRequest requestForUpdate(String objectType, String id, Map<String, Object> fields) {
    //       return new RecordRequest(RequestType.UPDATE, objectType, fields, id, null, null);
    //   }
    //
    //   static RecordRequest requestForUpsert(String objectType, String externalIdFieldName, String externalId, Map<String, Object> fields) {
    //       return new RecordRequest(RequestType.UPSERT, objectType, fields, null, externalId, externalIdFieldName);
    //   }
    //
    //   static RecordRequest requestForDelete(String objectType, String id) {
    //       return new RecordRequest(RequestType.DELETE, objectType, null, id, null, null);
    //   }
    //
    //   static List<String> getRefIds(List<RecordRequest> recordRequests, RequestType requestType) {
    //       List<String> refIds = new LinkedList<>();
    //       for (RecordRequest recordRequest : recordRequests) {
    //           if (recordRequest.requestType == requestType) {
    //               refIds.add(recordRequest.referenceId);
    //           }
    //       }
    //       return refIds;
    //   }
    //
    //   static List<String> getIds(List<RecordRequest> recordRequests, RequestType requestType) {
    //       List<String> ids = new LinkedList<>();
    //       for (RecordRequest recordRequest : recordRequests) {
    //           if (recordRequest.requestType == requestType) {
    //               ids.add(recordRequest.id);
    //           }
    //       }
    //       return ids;
    //   }
    //
    //   static List<String> getObjectTypes(List<RecordRequest> recordRequests, RequestType requestType) {
    //       List<String> objectTypes = new LinkedList<>();
    //       for (RecordRequest recordRequest : recordRequests) {
    //           if (recordRequest.requestType == requestType) {
    //               objectTypes.add(recordRequest.objectType);
    //           }
    //       }
    //       return objectTypes;
    //   }
    //
    //   static List<String> getExternalIdFieldNames(List<RecordRequest> recordRequests, RequestType requestType) {
    //       List<String> externalIdFieldNames = new LinkedList<>();
    //       for (RecordRequest recordRequest : recordRequests) {
    //           if (recordRequest.requestType == requestType) {
    //               externalIdFieldNames.add(recordRequest.externalIdFieldName);
    //           }
    //       }
    //       return externalIdFieldNames;
    //   }
    //
    //   static JSONArray getJSONArrayForCollectionRequest(List<RecordRequest> recordRequests, RequestType requestType)
    //       throws JSONException {
    //       JSONArray jsonArray = new JSONArray();
    //       for (RecordRequest recordRequest : recordRequests) {
    //           if (recordRequest.requestType == requestType) {
    //               jsonArray.put(recordRequest.asJSONObjectForCollectionRequest());
    //           }
    //       }
    //       return jsonArray;
    //   }
    //
    //   static RestRequest getCollectionRequest(String apiVersion, boolean allOrNone, List<RecordRequest> recordRequests, RequestType requestType)
    //       throws JSONException, UnsupportedEncodingException {
    //       switch(requestType) {
    //           case CREATE:
    //               return RestRequest.getRequestForCollectionCreate(apiVersion, allOrNone, getJSONArrayForCollectionRequest(recordRequests, RequestType.CREATE));
    //           case UPDATE:
    //               return RestRequest.getRequestForCollectionUpdate(apiVersion, allOrNone, getJSONArrayForCollectionRequest(recordRequests, RequestType.UPDATE));
    //           case UPSERT:
    //               JSONArray records = getJSONArrayForCollectionRequest(recordRequests, RequestType.UPSERT);
    //
    //               if (records.length() > 0) {
    //                   List<String> objectTypes = getObjectTypes(recordRequests, RequestType.UPSERT);
    //                   List<String> externalIdFieldNames = getExternalIdFieldNames(recordRequests, RequestType.UPSERT);
    //
    //                   if (objectTypes.size() == 0 || externalIdFieldNames.size() == 0) {
    //                       throw new SyncManager.MobileSyncException("Missing sobjectType or externalIdFieldName");
    //                   }
    //
    //                   if (new HashSet<>(objectTypes).size() > 1) {
    //                       throw new SyncManager.MobileSyncException("All records must have same sobjectType");
    //                   }
    //
    //                   String objectType = objectTypes.get(0);
    //                   String externalIdFieldName = externalIdFieldNames.get(0);
    //
    //                   return RestRequest
    //                       .getRequestForCollectionUpsert(apiVersion,
    //                           objectType,
    //                           externalIdFieldName,
    //                           allOrNone,
    //                           records);
    //               }
    //           case DELETE:
    //               return RestRequest.getRequestForCollectionDelete(apiVersion, getIds(recordRequests, RequestType.DELETE));
    //       }
    //
    //       // We should never get here
    //       return null;
    //   }
    }

    enum RequestType {
       case CREATE, UPDATE,UPSERT, DELETE
    }
}

