/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFContentSoqlSyncDownTarget.h"
#import <SmartSync/SFSmartSyncSyncManager.h>
#import <SmartSync/SFSmartSyncConstants.h>
#import <SmartSync/SFSmartSyncNetworkUtils.h>
#import <SalesforceSDKCore/SFOAuthCredentials.h>

// SOAP request
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
#define SOAP_ENDPOINT @"/services/Soap/u/36.0"
#define SOAP_PATH @""

// Soal request mime type
#define XML_MIME_TYPE @"text/xml"

// Soap custom header
#define SOAP_ACTION @"SOAPAction"
#define SOAP_ACTION_VALUE @"\"\""

// SOAP response
#define RESULT @"result"
#define RECORDS @"records"
#define SF @"sf:"
#define QUERY_LOCATOR @"queryLocator"
#define SIZE @"size"
#define DONE @"done"
#define TYPE @"type"

// Params for SFSoapSoqlRequest
#define SESSION_ID @"sessionId"
#define QUERY @"query"
#define IS_LOCATOR @"query"

typedef void (^SFSoapSoqlResponseParseComplete) ();

@interface SFSoapSoqlResponse : NSObject <NSXMLParserDelegate>

@property (nonatomic, strong) NSXMLParser *xmlParser;
@property (nonatomic, strong) NSMutableArray* records;
@property (nonatomic)         NSUInteger totalSize;
@property (nonatomic)         BOOL queryDone;
@property (nonatomic, strong) NSString *queryLocator;

@property (nonatomic, strong) NSMutableDictionary *record;
@property (nonatomic, strong) NSString *currentElement;
@property (nonatomic, strong) NSMutableString *foundValue;
@property (nonatomic)         BOOL inResult;
@property (nonatomic)         BOOL inRecord;
@property (nonatomic, strong) SFSoapSoqlResponseParseComplete completeBlock;

-(void)parse:(NSData*)data completeBlock:(SFSoapSoqlResponseParseComplete)completeBlock;

@end

@implementation SFSoapSoqlResponse

-(void)parse:(NSData*)data completeBlock:(SFSoapSoqlResponseParseComplete)completeBlock
{
    self.completeBlock = completeBlock;
    self.xmlParser = [[NSXMLParser alloc] initWithData:data];
    self.xmlParser.delegate = self;
    [self.xmlParser parse];
}

-(void)parserDidStartDocument:(NSXMLParser *)parser
{
    self.records = [[NSMutableArray alloc] init];
}

-(void)parserDidEndDocument:(NSXMLParser *)parser
{
    self.completeBlock(self.records, self.totalSize, self.queryLocator);
}

-(void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    NSLog(@"%@", [parseError localizedDescription]);
}

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    
    if ([elementName isEqualToString:RESULT]) {
        self.inResult = YES;
    }
    else if ([elementName isEqualToString:RECORDS]) {
        self.inRecord = YES;
        self.record = [NSMutableDictionary new];
    }
    self.currentElement = elementName;
}

-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName{
    
    if ([elementName isEqualToString:RESULT]) {
        self.inResult = NO;
    }
    else if (self.inResult && [elementName isEqualToString:RECORDS]){
        self.inRecord = NO;
        [self.records addObject:self.record];
    }
    else if (self.inResult && [elementName isEqualToString:DONE]) {
        self.queryDone = [self.foundValue boolValue];
    }
    else if (self.inResult && [elementName isEqualToString:QUERY_LOCATOR]){
        self.queryLocator = self.queryDone ? nil : self.foundValue;
    }
    else if (self.inResult && [elementName isEqualToString:SIZE]) {
        self.totalSize = [self.foundValue integerValue];
    }
    else if (self.inRecord && [elementName hasPrefix:SF]) {
        NSString* attributeName = [elementName substringFromIndex:[SF length]];
        if ([attributeName isEqualToString:TYPE]) {
            self.record[kAttributes] = @{ TYPE : self.foundValue };
        }
        else {
            self.record[attributeName] = self.foundValue;
        }
    }
    self.foundValue = [NSMutableString new];
}

-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{
    [self.foundValue appendString:string];
}

@end

@interface SFSoapSoqlRequest : SFRestRequest

@property (nonatomic, strong) NSString *query;
@property (nonatomic, strong) NSString *queryLocator;

- (id)initWithQuery:(NSString*) query;
- (id)initWithQueryLocator:(NSString*) queryLocator;

@end

@implementation SFSoapSoqlRequest

- (id)initWithQuery:(NSString*)query
{
    self = [[self class] requestWithMethod:SFRestMethodPOST path:SOAP_PATH queryParams:nil];
    if (self) {
        self.endpoint = SOAP_ENDPOINT;
        self.query = query;
        self.queryLocator = nil;
    }
    return self;
}

- (id)initWithQueryLocator:(NSString*)queryLocator
{
    self = [[self class] requestWithMethod:SFRestMethodPOST path:@"" queryParams:nil];
    if (self) {
        self.endpoint = SOAP_ENDPOINT;
        self.query = nil;
        self.queryLocator = queryLocator;
    }
    return self;
}

- (NSURLRequest *)prepareRequestForSend:(SFUserAccount *)user
{
    NSString *sessionId = user.credentials.accessToken;
    NSString *body;
    if (self.queryLocator) {
        body = [NSString stringWithFormat:QUERY_MORE_TEMPLATE, self.queryLocator];
    } else {
        body = [NSString stringWithFormat:QUERY_TEMPLATE, self.query];
    }
    NSString *soapBody = [NSString stringWithFormat:REQUEST_TEMPLATE, sessionId, body];
    [self setCustomRequestBodyString:soapBody contentType:XML_MIME_TYPE];
    [self setHeaderValue:SOAP_ACTION_VALUE forHeaderName:SOAP_ACTION];
    return [super prepareRequestForSend:user];
}

@end

@interface SFContentSoqlSyncDownTarget ()

@property (nonatomic, strong, readwrite) NSString* queryLocator;

@end

@implementation SFContentSoqlSyncDownTarget


#pragma mark - Factory methods

+ (SFContentSoqlSyncDownTarget*) newSyncTarget:(NSString*)query {
    SFContentSoqlSyncDownTarget* syncTarget = [[SFContentSoqlSyncDownTarget alloc] init];
    syncTarget.query = query;
    return syncTarget;
}


# pragma mark - Data fetching

- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock
{
    __weak typeof(self) weakSelf = self;
    
    NSString* queryToRun = [self getQueryToRun:maxTimeStamp];
    [[SFRestAPI sharedInstance] performRequestForResourcesWithFailBlock:^(NSError *e, NSURLResponse *rawResponse) {
        errorBlock(e);
    } completeBlock:^(NSDictionary* d, NSURLResponse *rawResponse) { // cheap call to refresh session
        SFRestRequest* request = [[SFSoapSoqlRequest alloc] initWithQuery:queryToRun];
        [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request failBlock:^(NSError *e, NSURLResponse *rawResponse) {
            errorBlock(e);
        } completeBlock:^(NSData * response, NSURLResponse *rawResponse) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf parseRestResponse:response parseCompletion:^(SFSoapSoqlResponse *soapSoqlResponse) {
                strongSelf.queryLocator = soapSoqlResponse.queryLocator;
                strongSelf.totalSize = soapSoqlResponse.totalSize;
                completeBlock(soapSoqlResponse.records);
            }];
            
        }];
    }];
}

- (void) continueFetch:(SFSmartSyncSyncManager *)syncManager
            errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
         completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock
{
    if (self.queryLocator) {
        __weak typeof(self) weakSelf = self;
        SFSoapSoqlRequest* request = [[SFSoapSoqlRequest alloc] initWithQueryLocator:self.queryLocator];
        [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request failBlock:^(NSError *e, NSURLResponse *rawResponse) {
            errorBlock(e);
        } completeBlock:^(NSData *response, NSURLResponse *rawResponse) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf parseRestResponse:response parseCompletion:^(SFSoapSoqlResponse *soapSoqlResponse) {
                strongSelf.queryLocator = soapSoqlResponse.queryLocator;
                completeBlock(soapSoqlResponse.records);
            }];
        }];
    } else {
        completeBlock(nil);
    }
}

#pragma mark - Utility methods

- (void)parseRestResponse:(NSData *)responseData parseCompletion:(void (^)(SFSoapSoqlResponse *))parseCompletionBlock
{
    if (responseData != nil) {
        SFSoapSoqlResponse *soapSoqlResponse = [[SFSoapSoqlResponse alloc] init];
        [soapSoqlResponse parse:responseData completeBlock:^{
            if (parseCompletionBlock != NULL) {
                parseCompletionBlock(soapSoqlResponse);
            }
        }];
    }
}

@end
