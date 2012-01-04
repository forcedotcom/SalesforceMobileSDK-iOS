/* 
 * Copyright (c) 2011, salesforce.com, inc.
 * Author: Jonathan Hersh jhersh@salesforce.com
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided 
 * that the following conditions are met:
 * 
 *    Redistributions of source code must retain the above copyright notice, this list of conditions and the 
 *    following disclaimer.
 *  
 *    Redistributions in binary form must reproduce the above copyright notice, this list of conditions and 
 *    the following disclaimer in the documentation and/or other materials provided with the distribution. 
 *    
 *    Neither the name of salesforce.com, inc. nor the names of its contributors may be used to endorse or 
 *    promote products derived from this software without specific prior written permission.
 *  
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED 
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR 
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import "SFRestAPI.h"

@interface SFRestAPI (Blocks) <SFRestDelegate>

// Block types
typedef void (^SFVRestFailBlock) (NSError *e);
typedef void (^SFVRestJSONDictionaryResponseBlock) (NSDictionary *dict);

/**
 * Internal function for sending REST requests.
 * @param request the SFRestRequest to be sent
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 */
- (void) sendRESTRequest:(SFRestRequest *)request 
               failBlock:(SFVRestFailBlock)failBlock 
           completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;


// Various request types.

/**
 * Executes a SOQL query.
 * @param query the SOQL query to be executed
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 */
- (SFRestRequest *) performSOQLQuery:(NSString *)query 
                           failBlock:(SFVRestFailBlock)failBlock 
                       completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

/**
 * Executes a SOSL search.
 * @param query the SOQL query to be executed
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 */
- (SFRestRequest *) performSOSLSearch:(NSString *)search 
                            failBlock:(SFVRestFailBlock)failBlock 
                        completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

/**
 * Executes a global describe.
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 */
- (SFRestRequest *) performDescribeGlobalWithFailBlock:(SFVRestFailBlock)failBlock 
                              completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

/**
 * Executes a describe on a single sObject.
 * @param objectType the API name of the object to describe.
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 */
- (SFRestRequest *) performDescribeWithObjectType:(NSString *)objectType 
                             failBlock:(SFVRestFailBlock)failBlock 
                         completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

/**
 * Executes a metadata describe on a single sObject.
 * @param objectType the API name of the object to describe.
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 */
- (SFRestRequest *) performMetadataWithObjectType:(NSString *)objectType 
                             failBlock:(SFVRestFailBlock)failBlock 
                         completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

/**
 * Executes a retrieve for a single record.
 * @param objectType the API name of the object to retrieve
 * @param objectId the record ID of the record to retrieve
 * @param fieldList an array of fields on this record to retrieve
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 */
- (SFRestRequest *) performRetrieveWithObjectType:(NSString *)objectType 
                              objectId:(NSString *)objectId 
                             fieldList:(NSArray *)fieldList 
                             failBlock:(SFVRestFailBlock)failBlock 
                         completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

/**
 * Executes a DML update for a single record.
 * @param objectType the API name of the object to update
 * @param objectId the record ID of the object
 * @param fields a dictionary of fields to update.
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 */
- (SFRestRequest *) performUpdateWithObjectType:(NSString *)objectType 
                            objectId:(NSString *)objectId 
                              fields:(NSDictionary *)fields 
                           failBlock:(SFVRestFailBlock)failBlock 
                       completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

/**
 * Executes a DML upsert for a single record.
 * @param objectType the API name of the object to update
 * @param externalIdField the API name of the external ID field to use for updating
 * @param externalId the actual external Id
 * @param fields a dictionary of fields to include in the upsert
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 */
- (SFRestRequest *) performUpsertWithObjectType:(NSString *)objectType 
                     externalIdField:(NSString *)externalIdField 
                          externalId:(NSString *)externalId 
                              fields:(NSDictionary *)fields 
                           failBlock:(SFVRestFailBlock)failBlock 
                       completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

/**
 * Executes a DML delete on a single record
 * @param objectType the API name of the object to delete
 * @param objectId the actual Id of the record to delete
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 */
- (SFRestRequest *) performDeleteWithObjectType:(NSString *)objectType 
                            objectId:(NSString *)objectId 
                           failBlock:(SFVRestFailBlock)failBlock 
                       completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

/**
 * Executes a DML insert.
 * @param objectType the API name of the object to insert
 * @param fields a dictionary of fields to use in the insert.
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 */
- (SFRestRequest *) performCreateWithObjectType:(NSString *)objectType 
                              fields:(NSDictionary *)fields 
                           failBlock:(SFVRestFailBlock)failBlock 
                       completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

/**
 * Executes a request to list REST API resources
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 */
- (SFRestRequest *) performRequestForResourcesWithFailBlock:(SFVRestFailBlock)failBlock 
                                   completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

/**
 * Executes a request to list REST API versions
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 */
- (SFRestRequest *) performRequestForVersionsWithFailBlock:(SFVRestFailBlock)failBlock 
                                  completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

@end
