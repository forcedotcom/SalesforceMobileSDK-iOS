//
//  SFRestAPI.m
//  salesforce
//
//  Created by Didier Prophete on 7/11/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import "SFRestAPI.h"

#import "RKRequestDelegateWrapper.h"
#import "RestKit.h"
#import "SBJson.h"
#import "SFOAuthCoordinator.h"
#import "SFRestRequest.h"

NSString* const kSFRestDefaultAPIVersion = @"v22.0";
NSString* const kSFRestErrorDomain = @"com.salesforce.RestAPI.ErrorDomain";
NSInteger const kSFRestErrorCode = 999;


// singleton instance
static SFRestAPI *_instance;

@interface SFRestAPI (private)
- (id)initWithCoordinator:(SFOAuthCoordinator *)coordinator;
@end

@implementation SFRestAPI

@synthesize coordinator=_coordinator;
@synthesize apiVersion=_apiVersion;
@synthesize rkClient=_rkClient;

#pragma mark - init/setup

- (id)initWithCoordinator:(SFOAuthCoordinator *)coordinator {
    self = [super init];
    if (self) {
        self.coordinator = coordinator;
        self.apiVersion = kSFRestDefaultAPIVersion;
        self.rkClient = [RKClient clientWithBaseURL:[_coordinator.credentials.instanceUrl absoluteString]];
        [_rkClient setValue:[NSString stringWithFormat:@"OAuth %@", _coordinator.credentials.accessToken] forHTTPHeaderField:@"Authorization"];
        [_rkClient setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }
    return self;
}

- (void)dealloc {
    self.coordinator = nil;
    self.rkClient = nil;
    [super dealloc];
}

#pragma mark - singleton

+ (id)APIWithCoordinator:(SFOAuthCoordinator *)coordinator {
    [_instance release];
    _instance = [[SFRestAPI alloc] initWithCoordinator:coordinator];
    return _instance;
}

+ (SFRestAPI *)sharedInstance {
    return _instance;
}

#pragma mark - ajax methods

- (void)send:(SFRestRequest *)request delegate:(id<SFRestDelegate>)delegate {
    NSLog(@"SFRestAPI::send:delegate: %@", request);

    RKRequestDelegateWrapper *wrappedDelegate = [RKRequestDelegateWrapper wrapperWithDelegate:delegate request:request];
    [wrappedDelegate send];
}

- (SFRestRequest *)requestForVersions {
    NSString *path = @"/";
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
}

- (SFRestRequest *)requestForResources {
    NSString *path = [NSString stringWithFormat:@"/%@", self.apiVersion];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
}

- (SFRestRequest *)requestForDescribeGlobal {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects", self.apiVersion];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
}

- (SFRestRequest *)requestForMetadataWithObjectType:(NSString *)objectType {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@", self.apiVersion, objectType];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
}

- (SFRestRequest *)requestForDescribeWithObjectType:(NSString *)objectType {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/describe", self.apiVersion, objectType];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
}

- (SFRestRequest *)requestForRetrieveWithObjectType:(NSString *)objectType 
                                           objectId:(NSString *)objectId 
                                          fieldList:(NSString *)fieldList {
    NSDictionary *queryParams = (fieldList ?
                                 [NSDictionary dictionaryWithObjectsAndKeys:fieldList, @"fields", nil] 
                                 : nil);
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@", self.apiVersion, objectType, objectId];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest *)requestForCreateWithObjectType:(NSString *)objectType
                                           fields:(NSDictionary *)fields {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@", self.apiVersion, objectType];
    return [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:fields];
}

- (SFRestRequest *)requestForUpdateWithObjectType:(NSString *)objectType 
                                         objectId:(NSString *)objectId 
                                           fields:(NSDictionary *)fields {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@", self.apiVersion, objectType, objectId];
    return [SFRestRequest requestWithMethod:SFRestMethodPATCH path:path queryParams:fields];
}

- (SFRestRequest *)requestForUpsertWithObjectType:(NSString *)objectType
                                  externalIdField:(NSString *)externalIdField 
                                       externalId:(NSString *)externalId 
                                           fields:(NSDictionary *)fields {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@/%@", self.apiVersion, objectType, externalIdField, externalId];
    return [SFRestRequest requestWithMethod:SFRestMethodPATCH path:path queryParams:fields];
}

- (SFRestRequest *)requestForDeleteWithObjectType:(NSString *)objectType
                                         objectId:(NSString *)objectId {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@", self.apiVersion, objectType, objectId];
    return [SFRestRequest requestWithMethod:SFRestMethodDELETE path:path queryParams:nil];
}

- (SFRestRequest *)requestForQuery:(NSString *)soql {
    NSDictionary *queryParams = [NSDictionary dictionaryWithObjectsAndKeys:soql, @"q", nil];
    NSString *path = [NSString stringWithFormat:@"/%@/query", self.apiVersion];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest *)requestForSearch:(NSString *)sosl {
    NSDictionary *queryParams = [NSDictionary dictionaryWithObjectsAndKeys:sosl, @"q", nil];
    NSString *path = [NSString stringWithFormat:@"/%@/search", self.apiVersion];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

@end