/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SFContentSoqlSyncTarget.h"
#import <SmartSync/SFSmartSyncSyncManager.h>
#import <SmartSync/SFSmartSyncConstants.h>


#define REQUEST_TEMPLATE @"<?xml version=\"1.0\"?>"\
"<se:Envelope xmlns:se=\"http://schemas.xmlsoap.org/soap/envelope/\">"\
"<se:Header xmlns:sfns=\"urn:partner.soap.sforce.com\">"\
"<sfns:SessionHeader><sessionId>%@</sessionId></sfns:SessionHeader>"\
"</se:Header>"\
"<se:Body>%@</se:Body>"\
"</se:Envelope>"

#define QUERY_TEMPLATE @"<query xmlns=\"urn:partner.soap.sforce.com\" xmlns:ns1=\"sobject.partner.soap.sforce.com\">"\
"<queryString>%@</queryString></query>"


#define QUERY_MORE_TEMPLATE @"<queryMore xmlns=\"urn:partner.soap.sforce.com\" xmlns:ns1=\"sobject.partner.soap.sforce.com\">"\
"<queryLocator>%@</queryLocator>"\
"</queryMore>"

#define SESSION_ID @"sessionId"
#define QUERY @"query"
#define IS_LOCATOR @"query"
#define XML_MIME_TYPE @"text/xml"
#define SOAP_ACTION @"SOAPAction"
#define SOAP_ACTION_VALUE @"\"\""


@interface SFSoapSoqlRequest : SFRestRequest

@property (nonatomic, strong) NSString *query;
@property (nonatomic) BOOL isLocator;

- (id)initWithQuery:(NSString*) query;
- (id)initWithQueryLocator:(NSString*) queryLocator;

@end

@implementation SFSoapSoqlRequest

- (id)initWithQuery:(NSString*)query
{
    self = [super init];
    if (self) {
        self.method = SFRestMethodPOST;
        self.path = @"";
        self.endpoint = @"/services/Soap/u/32.0";
        self.parseResponse = NO;
        self.isLocator = NO;
        self.query = query;
        
    }
    return self;
}

- (id)initWithQueryLocator:(NSString*)queryLocator
{
    self = [super init];
    if (self) {
        self.method = SFRestMethodPOST;
        self.path = @"";
        self.endpoint = @"/services/Soap/u/32.0";
        self.parseResponse = NO;
        self.isLocator = YES;
        self.query = queryLocator;
    }
    return self;
}


- (SFNetworkOperation*) send:(SFNetworkEngine*) networkEngine {
    NSString *url = [NSString stringWithFormat:@"%@%@", self.endpoint, self.path];
    // FIXME get session id
    [networkEngine post:url params:@{ SESSION_ID:@"", QUERY:self.query, IS_LOCATOR:self.isLocator ? @YES : @NO} ];
    
    SFNetworkOperationEncodingBlock enncodingBlock = ^(NSDictionary *postDataDict) {
        NSString* template = postDataDict[IS_LOCATOR] ? QUERY_MORE_TEMPLATE : QUERY_TEMPLATE;
        return [NSString stringWithFormat:REQUEST_TEMPLATE, postDataDict[SESSION_ID], [NSString stringWithFormat:template, postDataDict[QUERY]]];
    };
    [self.networkOperation setCustomPostDataEncodingHandler:enncodingBlock forType:XML_MIME_TYPE];

    // Add any custom headers to the network operation.
    if (self.customHeaders != nil) {
        [self.customHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [self.networkOperation setHeaderValue:obj forKey:key];
        }];
        [self.networkOperation setHeaderValue:SOAP_ACTION forKey:SOAP_ACTION_VALUE];
    }
    
    self.networkOperation.delegate = self;
    [networkEngine enqueueOperation:self.networkOperation];
    
    return self.networkOperation;
}

@end

@interface SFContentSoqlSyncTarget ()

@property (nonatomic, strong, readwrite) NSString* queryLocator;

@end

@implementation SFContentSoqlSyncTarget

#pragma mark - Factory methods

+ (SFContentSoqlSyncTarget*) newSyncTarget:(NSString*)query {
    SFContentSoqlSyncTarget* syncTarget = [[SFContentSoqlSyncTarget alloc] init];
    syncTarget.queryType = SFSyncTargetQueryTypeCustom;
    syncTarget.query = query;
    return syncTarget;
}


#pragma mark - From/to dictionary

+ (SFContentSoqlSyncTarget*) newFromDict:(NSDictionary*)dict {
    SFContentSoqlSyncTarget* syncTarget = nil;
    if (dict != nil && [dict count] != 0) {
        syncTarget = [[SFContentSoqlSyncTarget alloc] init];
        syncTarget.queryType = SFSyncTargetQueryTypeCustom;
        syncTarget.query = dict[kSFSoqlSyncTargetQuery];
    }
    return syncTarget;
}

- (NSDictionary*) asDict {
    return @{
             kSFSyncTargetQueryType: [SFSyncTarget queryTypeToString:self.queryType],
             kSFSoqlSyncTargetQuery: self.query,
             kSFSyncTargetiOSImpl: NSStringFromClass([self class])
             };
}

# pragma mark - Data fetching

- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
         errorBlock:(SFSyncTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncTargetFetchCompleteBlock)completeBlock
{
    
    __weak SFContentSoqlSyncTarget* weakSelf = self;
    
    // Resync?
    NSString* queryToRun = self.query;
    if (maxTimeStamp > 0) {
        queryToRun = [SFSoqlSyncTarget addFilterForReSync:self.query maxTimeStamp:maxTimeStamp];
    }
    
    SFRestRequest* request = [[SFSoapSoqlRequest alloc] initWithQuery:queryToRun];
    [syncManager sendRequestWithSmartSyncUserAgent:request failBlock:errorBlock completeBlock:^(id data) {
        // FIXME
        // weakSelf.totalSize = [d[kResponseTotalSize] integerValue];
        // weakSelf.nextRecordsUrl = d[kResponseNextRecordsUrl];
        // completeBlock(d[kResponseRecords]);
        completeBlock(nil);

    }];
}

- (void) continueFetch:(SFSmartSyncSyncManager *)syncManager
            errorBlock:(SFSyncTargetFetchErrorBlock)errorBlock
         completeBlock:(SFSyncTargetFetchCompleteBlock)completeBlock
{
    if (self.queryLocator) {
        __weak SFContentSoqlSyncTarget* weakSelf = self;
        SFRestRequest* request = [[SFSoapSoqlRequest alloc] initWithQueryLocator:self.queryLocator];
        [syncManager sendRequestWithSmartSyncUserAgent:request failBlock:errorBlock completeBlock:^(id data) {
            // FIXME
            // weakSelf.nextRecordsUrl = d[kResponseNextRecordsUrl];
            // completeBlock(d[kResponseRecords]);
            completeBlock(nil);
        }];
    }
    else {
        completeBlock(nil);
    }
}

@end
