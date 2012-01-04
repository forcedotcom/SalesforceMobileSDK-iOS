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

#import "SFVRestAsync.h"

@implementation SFVRestAsync

SYNTHESIZE_SINGLETON_FOR_CLASS(SFVRestAsync);

#pragma mark - caching requests

- (void)emptyCaches {
    [activeRequests removeAllObjects];
    activeRequests = nil;
}

- (void)cacheRequest:(SFRestRequest *)request failBlock:(SFVRestFailBlock)failBlock completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock {
    if( !activeRequests )
        activeRequests = [[NSMutableArray alloc] init];
    
    NSMutableArray *newReq = [NSMutableArray arrayWithCapacity:CachedNumThingsToCache];
    
    for( int i = 0; i < CachedNumThingsToCache; i++ ) {
        switch( i ) {
            case CachedRequest:
                [newReq addObject:request];
                break;
            case CachedFailBlock:
                [newReq addObject:( failBlock ? [failBlock copy] : [NSNumber numberWithInt:0] )];
                break;
            case CachedCompleteBlock:
                [newReq addObject:( completeBlock ? [completeBlock copy] : [NSNumber numberWithInt:0] )];
                break;
            default: break;
        }
    }
    
    [activeRequests addObject:newReq];
}

- (NSArray *)requestArrayForRequest:(SFRestRequest *)request {
    if( !activeRequests )
        return nil;
    
    for( NSArray *req in activeRequests )
        if( [[req objectAtIndex:CachedRequest] isEqual:request] )
            return req;
    
    return nil;
}

- (void)removeRequest:(SFRestRequest *)request {
    if( !activeRequests )
        return;
    
    int toRemove = -1;
    
    for( int i = 0; i < [activeRequests count]; i++ )
        if( [[[activeRequests objectAtIndex:i] objectAtIndex:CachedRequest] isEqual:request] ) {
            toRemove = i;
            break;
        }
    
    if( toRemove != -1 )
        [activeRequests removeObjectAtIndex:toRemove];
}

#pragma mark - error handling

+ (NSError *)errorWithDescription:(NSString *)description {    
    NSArray *objArray = [NSArray arrayWithObjects:description, @"", @"", nil];
    NSArray *keyArray = [NSArray arrayWithObjects:NSLocalizedDescriptionKey, NSUnderlyingErrorKey, NSFilePathErrorKey, nil];
    
    NSDictionary *eDict = [NSDictionary dictionaryWithObjects:objArray
                                                      forKeys:keyArray];
    
    NSError *err = [[NSError alloc] initWithDomain:@"SFVError"
                                              code:42
                                          userInfo:eDict];
    
    return [err autorelease];
}

#pragma mark - sending requests

- (void) sendRESTRequest:(SFRestRequest *)request failBlock:(SFVRestFailBlock)failBlock completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock {
    [self cacheRequest:request failBlock:failBlock completeBlock:completeBlock];
    [[SFRestAPI sharedInstance] send:request delegate:self];
}

#pragma mark - various request types

- (void)performSOQLQuery:(NSString *)query failBlock:(SFVRestFailBlock)failBlock completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:query];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
}

- (void)performSOSLQuery:(NSString *)query failBlock:(SFVRestFailBlock)failBlock completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForSearch:query];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
}

- (void)performDescribeGlobalWithFailBlock:(SFVRestFailBlock)failBlock completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
}

- (void)performUpdateWithObjectType:(NSString *)objectType objectId:(NSString *)objectId fields:(NSDictionary *)fields failBlock:(SFVRestFailBlock)failBlock completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:objectType objectId:objectId fields:fields];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
}

- (void)performUpsertWithObjectType:(NSString *)objectType externalIdField:(NSString *)externalIdField externalId:(NSString *)externalId fields:(NSDictionary *)fields failBlock:(SFVRestFailBlock)failBlock completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForUpsertWithObjectType:objectType
                                                                        externalIdField:externalIdField
                                                                             externalId:externalId
                                                                                 fields:fields];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
}

- (void)performCreateWithObjectType:(NSString *)objectType fields:(NSDictionary *)fields failBlock:(SFVRestFailBlock)failBlock completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:objectType fields:fields];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
}

- (void)performDeleteWithObjectType:(NSString *)objectType objectId:(NSString *)objectId failBlock:(SFVRestFailBlock)failBlock completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:objectType objectId:objectId];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
}

- (void)performDescribeWithObjectType:(NSString *)objectType failBlock:(SFVRestFailBlock)failBlock completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForDescribeWithObjectType:objectType];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
}

- (void)performMetadataWithObjectType:(NSString *)objectType failBlock:(SFVRestFailBlock)failBlock completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForMetadataWithObjectType:objectType];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
}

- (void)performRetrieveWithObjectType:(NSString *)objectType objectId:(NSString *)objectId fieldList:(NSArray *)fieldList failBlock:(SFVRestFailBlock)failBlock completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:objectType 
                                                                                 objectId:objectId 
                                                                                fieldList:[[[NSSet setWithArray:fieldList] allObjects] componentsJoinedByString:@","]];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
}

- (void)performRequestForResourcesWithFailBlock:(SFVRestFailBlock)failBlock completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForResources];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
}

- (void)performRequestForVersionsWithFailBlock:(SFVRestFailBlock)failBlock completeBlock:(SFVRestJSONDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForVersions];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
}

#pragma mark - response delegate

- (void) sendActionForRequest:(SFRestRequest *)request success:(BOOL)success withObject:(id)object {
    NSArray *req = [self requestArrayForRequest:request];
    
    if( !req ) 
        return;
    
    if( success && ![[req objectAtIndex:CachedCompleteBlock] isKindOfClass:[NSNumber class]] )
        ((SFVRestJSONDictionaryResponseBlock)[req objectAtIndex:CachedCompleteBlock])(object);
    else if( !success && ![[req objectAtIndex:CachedFailBlock] isKindOfClass:[NSNumber class]] )
        ((SFVRestFailBlock)[req objectAtIndex:CachedFailBlock])(object);
    
    [self removeRequest:request];
}

- (void)request:(SFRestRequest *)request didFailLoadWithError:(NSError *)error {        
    [self sendActionForRequest:request success:NO withObject:error];
}

- (void)requestDidCancelLoad:(SFRestRequest *)request {    
    [self sendActionForRequest:request success:NO withObject:[[self class] errorWithDescription:@"Cancelled Load."]];
}

- (void)requestDidTimeout:(SFRestRequest *)request {    
    [self sendActionForRequest:request success:NO withObject:[[self class] errorWithDescription:@"Timed out."]];
}

- (void)request:(SFRestRequest *)request didLoadResponse:(id)jsonResponse {    
    [self sendActionForRequest:request success:YES withObject:jsonResponse];
}

@end
