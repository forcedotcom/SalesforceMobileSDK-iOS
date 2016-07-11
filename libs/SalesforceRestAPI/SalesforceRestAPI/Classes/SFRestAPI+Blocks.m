/* 
 * Copyright (c) 2011, salesforce.com, inc.
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

#import "SFRestAPI+Blocks.h"
#import "SFRestAPI+Files.h"
#import <objc/runtime.h>

// Pattern demonstrated in the Apple documentation. We use a static key
// whose address will be used by the objc_setAssociatedObject (no need to have a value).
static char FailBlockKey;
static char CompleteBlockKey;

@implementation SFRestAPI (Blocks)

#pragma mark - error handling

+ (NSError *)errorWithDescription:(NSString *)description {    
    NSArray *objArray = @[description, @""];
    NSArray *keyArray = @[NSLocalizedDescriptionKey, NSFilePathErrorKey];
    
    NSDictionary *eDict = [NSDictionary dictionaryWithObjects:objArray
                                                      forKeys:keyArray];
    
    NSError *err = [[NSError alloc] initWithDomain:@"API Error"
                                              code:42 // life, the universe, and everything
                                          userInfo:eDict];
    
    return err;
}

#pragma mark - sending requests


- (void) sendRESTRequest:(SFRestRequest *)request failBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestResponseBlock)completeBlock {
    // Copy blocks into the request instance
    objc_setAssociatedObject(request, &FailBlockKey, failBlock, OBJC_ASSOCIATION_COPY);
    objc_setAssociatedObject(request, &CompleteBlockKey, completeBlock, OBJC_ASSOCIATION_COPY);
    
    [self send:request delegate:self];
}

#pragma mark - various request types

- (SFRestRequest *) performSOQLQuery:(NSString *)query failBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [self requestForQuery:query];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
    
    return request;
}

- (SFRestRequest *) performSOQLQueryAll:(NSString *)query failBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [self requestForQueryAll:query];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
    
    return request;
}

- (SFRestRequest *) performSOSLSearch:(NSString *)search failBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestArrayResponseBlock)completeBlock {
    SFRestRequest *request = [self requestForSearch:search];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
    
    return request;
}

- (SFRestRequest *) performDescribeGlobalWithFailBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [self requestForDescribeGlobal];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
    
    return request;
}

- (SFRestRequest *) performUpdateWithObjectType:(NSString *)objectType objectId:(NSString *)objectId fields:(NSDictionary *)fields failBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [self requestForUpdateWithObjectType:objectType objectId:objectId fields:fields];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
    
    return request;
}

- (SFRestRequest *) performUpsertWithObjectType:(NSString *)objectType externalIdField:(NSString *)externalIdField externalId:(NSString *)externalId fields:(NSDictionary *)fields failBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [self requestForUpsertWithObjectType:objectType
                                                                        externalIdField:externalIdField
                                                                             externalId:externalId
                                                                                 fields:fields];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
    
    return request;
}

- (SFRestRequest *) performCreateWithObjectType:(NSString *)objectType fields:(NSDictionary *)fields failBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [self requestForCreateWithObjectType:objectType fields:fields];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
    
    return request;
}

- (SFRestRequest *) performDeleteWithObjectType:(NSString *)objectType objectId:(NSString *)objectId failBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [self requestForDeleteWithObjectType:objectType objectId:objectId];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
    
    return request;
}

- (SFRestRequest *) performDescribeWithObjectType:(NSString *)objectType failBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [self requestForDescribeWithObjectType:objectType];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
    
    return request;
}

- (SFRestRequest *) performMetadataWithObjectType:(NSString *)objectType failBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [self requestForMetadataWithObjectType:objectType];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
    
    return request;
}

- (SFRestRequest *) performRetrieveWithObjectType:(NSString *)objectType objectId:(NSString *)objectId fieldList:(NSArray *)fieldList failBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestDictionaryResponseBlock)completeBlock {
    NSString *fields = fieldList ? [[[NSSet setWithArray:fieldList] allObjects] componentsJoinedByString:@","] : nil;
    SFRestRequest *request = [self requestForRetrieveWithObjectType:objectType
                                                                                 objectId:objectId 
                                                                                fieldList:fields];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
    
    return request;
}

- (SFRestRequest *) performRequestForResourcesWithFailBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [self requestForResources];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
    
    return request;
}

- (SFRestRequest *) performRequestForVersionsWithFailBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [self requestForVersions];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
    
    return request;
}

- (SFRestRequest *) performRequestForFileRendition:(NSString *)sfdcId
                                           version:(NSString *)version
                                     renditionType:(NSString *)renditionType
                                              page:(NSUInteger)page
                                         failBlock:(SFRestFailBlock)failBlock
                                     completeBlock:(SFRestDataResponseBlock)completeBlock {
    
    SFRestRequest *request = [self requestForFileRendition:sfdcId version:version renditionType:renditionType page:page];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
    
    return request;
}

- (SFRestRequest *) performRequestForSearchScopeAndOrderWithFailBlock:(SFRestFailBlock)failBlock
                                           completeBlock:(SFRestArrayResponseBlock)completeBlock {
    SFRestRequest *request = [self requestForSearchScopeAndOrder];
    [self sendRESTRequest:request failBlock:failBlock completeBlock:completeBlock];
    return request;
}

- (SFRestRequest *) performRequestForSearchResultLayout:(NSString*)objectList
                                              failBlock:(SFRestFailBlock)failBlock
                                          completeBlock:(SFRestArrayResponseBlock)completeBlock {
    
    SFRestRequest *request = [self requestForSearchResultLayout:objectList];
    [self sendRESTRequest:request failBlock:failBlock completeBlock:completeBlock];
    return request;
}



- (SFRestRequest *) performRequestWithMethod:(SFRestMethod)method path:(NSString*)path queryParams:(NSDictionary*)queryParams failBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestDictionaryResponseBlock)completeBlock {
    SFRestRequest *request = [SFRestRequest requestWithMethod:method path:path queryParams:queryParams];
    [self sendRESTRequest:request
                failBlock:failBlock
            completeBlock:completeBlock];
    return request;
}

#pragma mark - response delegate

- (void) sendActionForRequest:(SFRestRequest *)request success:(BOOL)success withObject:(id)object {
    if( success ) {
        // This block def basically generalizes the SFRestDictionaryResponseBlock and SFRestArrayResponseBlock
        // block typedefs, so that we can handle either.
        void (^successBlock)(id);
        successBlock = (void (^) (id))objc_getAssociatedObject(request, &CompleteBlockKey);
        if( successBlock )
            successBlock( object );
    } else {
        SFRestFailBlock failBlock = (SFRestFailBlock)objc_getAssociatedObject(request, &FailBlockKey);
        
        if( failBlock )
            failBlock( object );
    }
    
    // Remove both blocks from the request
    objc_setAssociatedObject( request, &FailBlockKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject( request, &CompleteBlockKey, nil, OBJC_ASSOCIATION_ASSIGN);
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

- (void)request:(SFRestRequest *)request didLoadResponse:(id)dataResponse {    
    [self sendActionForRequest:request success:YES withObject:dataResponse];
}

@end
