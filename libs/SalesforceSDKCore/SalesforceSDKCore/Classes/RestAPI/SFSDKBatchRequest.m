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

#import "SFSDKBatchRequest.h"
#import "SFRestRequest+Internal.h"
@interface SFSDKBatchRequest()
@property (nonatomic, readwrite) NSArray<SFRestRequest *> *batchRequests;
@property (nonatomic, readwrite) BOOL haltOnError;
@property (nonatomic, readwrite) NSString *apiVersion;
-(instancetype) initWithRequests:(NSArray<SFRestRequest *>*)requests;
@end

@implementation SFSDKBatchRequest 

-(instancetype) initWithRequests:(NSArray<SFRestRequest *>*)requests {
    if (self = [super init]) {
        _batchRequests = [NSArray arrayWithArray:requests];
    }
    return self;
}

-(nullable NSURLRequest *)prepareRequestForSend:(nonnull SFUserAccount *)user {
    NSMutableArray *requestsArrayJson = [NSMutableArray new];
    for (SFRestRequest *request in self.batchRequests) {
        NSMutableDictionary<NSString *, id> *requestJson = [NSMutableDictionary new];
        requestJson[@"method"] = [SFRestRequest httpMethodFromSFRestMethod:request.method];
        
        // queryParams belong in url
        if (request.method == SFRestMethodGET || request.method == SFRestMethodDELETE) {
            requestJson[@"url"] = [NSString stringWithFormat:@"%@%@", request.path, [SFRestRequest   toQueryString:request.queryParams]];
        }
        
        // queryParams belongs in body
        else {
            requestJson[@"url"] = request.path;
            requestJson[@"richInput"] = request.requestBodyAsDictionary;
        }
        [requestsArrayJson addObject:requestJson];
    }
    NSMutableDictionary<NSString *, id> *batchRequestJson = [NSMutableDictionary new];
    batchRequestJson[@"batchRequests"] = requestsArrayJson;
    batchRequestJson[@"haltOnError"] = [NSNumber numberWithBool:self.haltOnError];
    NSString *path = [NSString stringWithFormat:@"/%@/composite/batch", self.apiVersion];
    super.path = path;
    super.serviceHostType = SFSDKRestServiceHostTypeInstance;
    super.method = SFRestMethodPOST;
    super.baseURL = nil;
    super.queryParams = nil;
    super.endpoint = kSFDefaultRestEndpoint;
    super.parseResponse = YES;
    [super setCustomRequestBodyDictionary:batchRequestJson contentType:@"application/json"];
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

@interface SFSDKBatchRequestBuilder() {
    BOOL _haltOnError;
}
@property (nonatomic, strong) NSMutableArray<SFRestRequest *> *allSubRequests;
@end

@implementation SFSDKBatchRequestBuilder

-(instancetype)init {
    if (self=[super init]) {
        self.allSubRequests = [[NSMutableArray alloc] init];
        
    }
    return self;
}

-(SFSDKBatchRequestBuilder *)setHaltOnError:(BOOL)haltOnError {
    _haltOnError = haltOnError;
    return self;
}

-(SFSDKBatchRequestBuilder *)addRequest:(SFRestRequest *)subRequest {
    [self.allSubRequests addObject:subRequest];
    return self;
}

-(SFSDKBatchRequest *)buildBatchRequest:(NSString *)apiVersion {
    SFSDKBatchRequest *batchRequest = [[SFSDKBatchRequest alloc] initWithRequests:[NSArray arrayWithArray: self.allSubRequests]];
    batchRequest.apiVersion = apiVersion;
    batchRequest.haltOnError = _haltOnError;
    batchRequest.requiresAuthentication = YES;
    return batchRequest;
}

@end
