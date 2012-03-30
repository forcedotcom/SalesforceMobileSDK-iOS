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
typedef void (^SFRestFailBlock) (NSError *e);
typedef void (^SFRestDictionaryResponseBlock) (NSDictionary *dict);
typedef void (^SFRestArrayResponseBlock) (NSArray *arr);

+ (NSError *)errorWithDescription:(NSString *)description;


/**
 * Send a request you've already built, using blocks to return status.
 * @param request the SFRestRequest to be sent
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 */
- (void) sendRESTRequest:(SFRestRequest *)request failBlock:(SFRestFailBlock)failBlock completeBlock:(id)completeBlock;    

// Various request types.

/**
 * Executes a SOQL query.
 * @param query the SOQL query to be executed
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 * @return the newly sent SFRestRequest
 */
- (SFRestRequest *) performSOQLQuery:(NSString *)query 
                           failBlock:(SFRestFailBlock)failBlock 
                       completeBlock:(SFRestDictionaryResponseBlock)completeBlock;

/**
 * Executes a SOSL search.
 * @param search the SOSL search to be executed
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 * @return the newly sent SFRestRequest
 */
- (SFRestRequest *) performSOSLSearch:(NSString *)search 
                            failBlock:(SFRestFailBlock)failBlock 
                        completeBlock:(SFRestArrayResponseBlock)completeBlock;

/**
 * Executes a global describe.
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 * @return the newly sent SFRestRequest
 */
- (SFRestRequest *) performDescribeGlobalWithFailBlock:(SFRestFailBlock)failBlock 
                                         completeBlock:(SFRestDictionaryResponseBlock)completeBlock;

/**
 * Executes a describe on a single sObject.
 * @param objectType the API name of the object to describe.
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 * @return the newly sent SFRestRequest
 */
- (SFRestRequest *) performDescribeWithObjectType:(NSString *)objectType 
                                        failBlock:(SFRestFailBlock)failBlock 
                                    completeBlock:(SFRestDictionaryResponseBlock)completeBlock;

/**
 * Executes a metadata describe on a single sObject.
 * @param objectType the API name of the object to describe.
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 * @return the newly sent SFRestRequest
 */
- (SFRestRequest *) performMetadataWithObjectType:(NSString *)objectType 
                                        failBlock:(SFRestFailBlock)failBlock 
                                    completeBlock:(SFRestDictionaryResponseBlock)completeBlock;

/**
 * Executes a retrieve for a single record.
 * @param objectType the API name of the object to retrieve
 * @param objectId the record ID of the record to retrieve
 * @param fieldList an array of fields on this record to retrieve
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 * @return the newly sent SFRestRequest
 */
- (SFRestRequest *) performRetrieveWithObjectType:(NSString *)objectType 
                                         objectId:(NSString *)objectId 
                                        fieldList:(NSArray *)fieldList 
                                        failBlock:(SFRestFailBlock)failBlock 
                                    completeBlock:(SFRestDictionaryResponseBlock)completeBlock;

/**
 * Executes a DML update for a single record.
 * @param objectType the API name of the object to update
 * @param objectId the record ID of the object
 * @param fields a dictionary of fields to update.
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 * @return the newly sent SFRestRequest
 */
- (SFRestRequest *) performUpdateWithObjectType:(NSString *)objectType 
                                       objectId:(NSString *)objectId 
                                         fields:(NSDictionary *)fields 
                                      failBlock:(SFRestFailBlock)failBlock 
                                  completeBlock:(SFRestDictionaryResponseBlock)completeBlock;

/**
 * Executes a DML upsert for a single record.
 * @param objectType the API name of the object to update
 * @param externalIdField the API name of the external ID field to use for updating
 * @param externalId the actual external Id
 * @param fields a dictionary of fields to include in the upsert
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 * @return the newly sent SFRestRequest
 */
- (SFRestRequest *) performUpsertWithObjectType:(NSString *)objectType 
                                externalIdField:(NSString *)externalIdField 
                                     externalId:(NSString *)externalId 
                                         fields:(NSDictionary *)fields 
                                      failBlock:(SFRestFailBlock)failBlock 
                                  completeBlock:(SFRestDictionaryResponseBlock)completeBlock;

/**
 * Executes a DML delete on a single record
 * @param objectType the API name of the object to delete
 * @param objectId the actual Id of the record to delete
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 * @return the newly sent SFRestRequest
 */
- (SFRestRequest *) performDeleteWithObjectType:(NSString *)objectType 
                                       objectId:(NSString *)objectId 
                                      failBlock:(SFRestFailBlock)failBlock 
                                  completeBlock:(SFRestDictionaryResponseBlock)completeBlock;

/**
 * Executes a DML insert.
 * @param objectType the API name of the object to insert
 * @param fields a dictionary of fields to use in the insert.
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 * @return the newly sent SFRestRequest
 */
- (SFRestRequest *) performCreateWithObjectType:(NSString *)objectType 
                                         fields:(NSDictionary *)fields 
                                      failBlock:(SFRestFailBlock)failBlock 
                                  completeBlock:(SFRestDictionaryResponseBlock)completeBlock;

/**
 * Executes a request to list REST API resources
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 * @return the newly sent SFRestRequest
 */
- (SFRestRequest *) performRequestForResourcesWithFailBlock:(SFRestFailBlock)failBlock 
                                              completeBlock:(SFRestDictionaryResponseBlock)completeBlock;

/**
 * Executes a request to list REST API versions
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 * @return the newly sent SFRestRequest
 */
- (SFRestRequest *) performRequestForVersionsWithFailBlock:(SFRestFailBlock)failBlock 
                                             completeBlock:(SFRestDictionaryResponseBlock)completeBlock;

@end
