/*
Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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

#import "SFSDKCompositeRequest+Internal.h"
#import "SFRestRequest+Internal.h"
#import "SFRestAPI.h"

@implementation SFSDKCompositeSubRequest

-(instancetype)initWithReferenceId:(NSString *)referenceId {
    if (self = [super init]) {
        _referenceId = referenceId;
    }
    return self;
}

-(instancetype)initWithRequest:(SFRestRequest *)request referenceId:(NSString *)referenceId  {
    if (self = [super init]) {
        _referenceId = referenceId;
        self.method = request.method;
        self.path = request.path;
        self.baseURL = request.baseURL;
        self.endpoint = request.endpoint;
        self.requiresAuthentication = request.requiresAuthentication;
        self.customHeaders = request.customHeaders;
        self.requestBodyStreamBlock = request.requestBodyStreamBlock;
        self.parseResponse = request.parseResponse;
        self.queryParams = request.queryParams;
        self.requestContentType = request.requestContentType;
        self.networkServiceType = request.networkServiceType;
        self.serviceHostType = request.serviceHostType;
        self.requestBodyAsDictionary = request.requestBodyAsDictionary;
        self.requestDelegate = request.requestDelegate;
    }
    return self;
}
@end

@interface SFSDKCompositeRequest(){
    NSMutableArray *_requests;
}
@property (assign, nonatomic, readwrite) BOOL allOrNone;
@property (assign, nonatomic, readwrite) NSString *apiVersion;
@end

@implementation SFSDKCompositeRequest

-(instancetype) init {
    if (self = [super init]) {
        _requests = [[NSMutableArray alloc] init];
    }
    return self;
}

-(NSArray<SFSDKCompositeSubRequest *> *)allSubRequests {
    return [NSArray arrayWithArray:_requests];
}


-(void)addRequest:(SFSDKCompositeSubRequest *)subRequest {
    [_requests addObject:subRequest];
}

- (nullable NSURLRequest *)prepareRequestForSend:(nonnull SFUserAccount *)user {
    NSMutableArray *requestsArrayJson = [NSMutableArray new];
    NSArray<SFSDKCompositeSubRequest *> *subRequests = self.allSubRequests;
    for (int i = 0; i < subRequests.count; i++) {
        SFSDKCompositeSubRequest *subRequest = subRequests[i];
        SFSDKCompositeSubRequest *request = subRequest;

        NSMutableDictionary<NSString *, id> *requestJson = [NSMutableDictionary new];
        requestJson[@"referenceId"] = subRequest.referenceId;
        requestJson[@"method"] = [SFRestRequest httpMethodFromSFRestMethod:request.method];
        
        // queryParams belong in url
        if (request.method == SFRestMethodGET || request.method == SFRestMethodDELETE) {
            requestJson[@"url"] = [NSString stringWithFormat:@"%@%@%@", request.endpoint, request.path, [SFRestRequest toQueryString:request.queryParams]];
        }
        
        // queryParams belongs in body
        else {
            requestJson[@"url"] = [NSString stringWithFormat:@"%@%@", request.endpoint, request.path];
            requestJson[@"body"] = request.requestBodyAsDictionary;
        }
        [requestsArrayJson addObject:requestJson];
    }
    NSMutableDictionary<NSString *, id> *compositeRequestJson = [NSMutableDictionary new];
    compositeRequestJson[@"compositeRequest"] = requestsArrayJson;
    compositeRequestJson[@"allOrNone"] = [NSNumber numberWithBool:self.allOrNone];
    self.path = [NSString stringWithFormat:@"/%@/composite", self.apiVersion ?: kSFRestDefaultAPIVersion];
    [super setCustomRequestBodyDictionary:compositeRequestJson contentType:@"application/json"];
    super.serviceHostType = SFSDKRestServiceHostTypeInstance;
    super.method = SFRestMethodPOST;
    super.baseURL = nil;
    super.queryParams = nil;
    super.endpoint = kSFDefaultRestEndpoint;
    super.parseResponse = YES;
    return [super prepareRequestForSend:user];
}

//override with NOOP
-(void)setMethod:(SFRestMethod)method{
    //:NOOP
}

-(void)setNetworkServiceType:(SFSDKNetworkServiceType)networkServiceType{
   //:NOOP
}

-(void)setServiceHostType:(SFSDKRestServiceHostType)serviceHostType{
   //:NOOP
}

-(void)setQueryParams:(NSMutableDictionary<NSString *,id> *)queryParams {
  //:NOOP
}

-(void)addPostFileData:(NSData *)fileData paramName:(NSString *)paramName fileName:(NSString *)fileName mimeType:(NSString *)mimeType params:(NSDictionary *)params{
   //:NOOP
}

@end

@interface SFSDKCompositeRequestBuilder() {
    BOOL _allOrNone;
}
@property (nonatomic, strong) NSMutableArray<SFSDKCompositeSubRequest *> *allSubRequests;
@end

@implementation SFSDKCompositeRequestBuilder

-(instancetype)init {
    if (self=[super init]) {
        self.allSubRequests = [[NSMutableArray alloc] init];
        
    }
    return self;
}

-(SFSDKCompositeRequestBuilder *)setAllOrNone:(BOOL)allOrNone {
    _allOrNone = allOrNone;
    return self;
}

-(SFSDKCompositeRequestBuilder *)addRequest:(SFRestRequest *)request referenceId:(NSString *)referenceId {
    SFSDKCompositeSubRequest *subRequest = [[SFSDKCompositeSubRequest alloc] initWithRequest:request referenceId:referenceId];
    [self.allSubRequests addObject:subRequest];
    return self;
}

-(SFSDKCompositeRequestBuilder *)addRequest:(SFSDKCompositeSubRequest *)subRequest{
    [self.allSubRequests addObject:subRequest];
    return self;
}

-(SFSDKCompositeRequest *)buildCompositeRequest:(NSString *)apiVersion {
    SFSDKCompositeRequest *compRequest = [[SFSDKCompositeRequest alloc] init];
    compRequest.apiVersion = apiVersion;
    compRequest.allOrNone = _allOrNone;
    compRequest.requiresAuthentication = YES;
    [self.allSubRequests enumerateObjectsUsingBlock:^(SFSDKCompositeSubRequest *obj, NSUInteger idx, BOOL *stop) {
        [compRequest addRequest:obj];
    }];
    return compRequest;
}


@end
