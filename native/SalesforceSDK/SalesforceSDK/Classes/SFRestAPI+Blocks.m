//
//  SFRestAPI+Blocks.m
//  SalesforceSDK
//
//  Created by Jonathan Hersh on 1/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SFRestAPI+Blocks.h"
#import <objc/runtime.h>

// Pattern demonstrated in the Apple documentation. We use a static key
// whose address will be used by the objc_setAssociatedObject (no need to have a value).
static char FailBlockKey;
static char CompleteBlockKey;

@implementation SFRestAPI (Blocks)

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
    // Copy blocks into the request instance
    objc_setAssociatedObject(request, &FailBlockKey, failBlock, OBJC_ASSOCIATION_COPY);
    objc_setAssociatedObject(request, &CompleteBlockKey, completeBlock, OBJC_ASSOCIATION_COPY);
    
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
    if( success ) {
        SFVRestJSONDictionaryResponseBlock block = (SFVRestJSONDictionaryResponseBlock)objc_getAssociatedObject(request, &CompleteBlockKey);
        
        if (block)
            block(object);
    } else if( !success ) {
        SFVRestFailBlock block = (SFVRestFailBlock)objc_getAssociatedObject(request, &FailBlockKey);
        
        if (block)
            block(object);
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

- (void)request:(SFRestRequest *)request didLoadResponse:(id)jsonResponse {    
    [self sendActionForRequest:request success:YES withObject:jsonResponse];
}

@end
