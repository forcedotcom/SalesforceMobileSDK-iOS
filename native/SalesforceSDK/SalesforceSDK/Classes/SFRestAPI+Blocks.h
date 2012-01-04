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

// Sending requests
- (void) sendRESTRequest:(SFRestRequest *)request 
               failBlock:(SFVRestFailBlock)failBlock 
           completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;


// Various request types.

- (void) performSOQLQuery:(NSString *)query 
                failBlock:(SFVRestFailBlock)failBlock 
            completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

- (void) performSOSLQuery:(NSString *)query 
                failBlock:(SFVRestFailBlock)failBlock 
            completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

- (void) performDescribeGlobalWithFailBlock:(SFVRestFailBlock)failBlock 
                              completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

- (void) performDescribeWithObjectType:(NSString *)objectType 
                             failBlock:(SFVRestFailBlock)failBlock 
                         completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

- (void) performMetadataWithObjectType:(NSString *)objectType 
                             failBlock:(SFVRestFailBlock)failBlock 
                         completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

- (void) performRetrieveWithObjectType:(NSString *)objectType 
                              objectId:(NSString *)objectId 
                             fieldList:(NSArray *)fieldList 
                             failBlock:(SFVRestFailBlock)failBlock 
                         completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

- (void) performUpdateWithObjectType:(NSString *)objectType 
                            objectId:(NSString *)objectId 
                              fields:(NSDictionary *)fields 
                           failBlock:(SFVRestFailBlock)failBlock 
                       completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

- (void) performUpsertWithObjectType:(NSString *)objectType 
                     externalIdField:(NSString *)externalIdField 
                          externalId:(NSString *)externalId 
                              fields:(NSDictionary *)fields 
                           failBlock:(SFVRestFailBlock)failBlock 
                       completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

- (void) performDeleteWithObjectType:(NSString *)objectType 
                            objectId:(NSString *)objectId 
                           failBlock:(SFVRestFailBlock)failBlock 
                       completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

- (void) performCreateWithObjectType:(NSString *)objectType 
                              fields:(NSDictionary *)fields 
                           failBlock:(SFVRestFailBlock)failBlock 
                       completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

- (void) performRequestForResourcesWithFailBlock:(SFVRestFailBlock)failBlock 
                                   completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

- (void) performRequestForVersionsWithFailBlock:(SFVRestFailBlock)failBlock 
                                  completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock;

@end
