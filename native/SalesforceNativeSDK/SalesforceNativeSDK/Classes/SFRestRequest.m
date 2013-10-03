/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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

#import "SFRestRequest.h"
#import "SFRestAPI+Internal.h"
#import <SalesforceSDKCore/SalesforceSDKConstants.h>
#import <SalesforceSDKCore/SFJsonUtils.h>

NSString * const kSFDefaultRestEndpoint = @"/services/data";

/**
 * Object to encapsulate post file details
 */
@interface SFRestRequestPostFile : NSObject {
}

@property (nonatomic, strong) NSData* fileData;
@property (nonatomic, strong) NSString* fileName;
@property (nonatomic, strong) NSString* paramName;
@property (nonatomic, strong) NSString* mimeType;

@end

@implementation SFRestRequestPostFile

@synthesize fileData=_fileData;
@synthesize paramName=_paramName;
@synthesize fileName=_fileName;
@synthesize mimeType=_mimeType;

- (id)initWithFileData:(NSData *)fileData paramName:(NSString *)paramName fileName:(NSString *)fileName mimeType:(NSString *)mimeType {
    self = [super init];
    if (self) {
        self.fileData = fileData;
        self.paramName = paramName;
        self.fileName = fileName;
        self.mimeType = mimeType;
    }
    return self;
}

- (void)dealloc {
    SFRelease(_fileData);
    SFRelease(_paramName);
    SFRelease(_fileName);
    SFRelease(_mimeType);
}


@end

@interface SFRestRequest () {

    // upload
    SFRestRequestPostFile *_postFile;
}

@end


@implementation SFRestRequest

@synthesize queryParams=_queryParams;
@synthesize path=_path;
@synthesize method=_method;
@synthesize delegate=_delegate;
@synthesize endpoint=_endpoint;
@synthesize parseResponse=_parseResponse;
@synthesize networkOperation=_networkOperation;

- (id)initWithMethod:(SFRestMethod)method path:(NSString *)path queryParams:(NSDictionary *)queryParams {
    self = [super init];
    if (self) {
        self.method = method;
        self.path = path;
        self.queryParams = queryParams;
        self.endpoint = kSFDefaultRestEndpoint;
        self.parseResponse = YES;
    }
    return self;
}

- (void)dealloc {
    _delegate = nil;
    SFRelease(_queryParams);
    SFRelease(_endpoint);
    SFRelease(_networkOperation);
    SFRelease(_postFile);
}

+ (id)requestWithMethod:(SFRestMethod)method path:(NSString *)path queryParams:(NSDictionary *)queryParams {
    return [[SFRestRequest alloc] initWithMethod:method path:path queryParams:queryParams];
}

-(NSString *)description {
    NSString *methodName;
    switch (_method) {
        case SFRestMethodGET: methodName = @"GET"; break;
        case SFRestMethodPOST: methodName = @"POST"; break;
        case SFRestMethodPUT: methodName = @"PUT"; break;
        case SFRestMethodDELETE: methodName = @"DELETE"; break;
        case SFRestMethodHEAD: methodName = @"HEAD"; break;
        case SFRestMethodPATCH: methodName = @"PATCH"; break;
        default:
            methodName = @"Unset";break;
    }
    NSString *paramStr = _queryParams ? [SFJsonUtils JSONRepresentation:_queryParams] : @"[]";
    return [NSString stringWithFormat:
            @"<SFRestRequest %p \n"
            "endpoint: %@ \n"
            "method: %@ \n"
            "path: %@ \n"
            "queryParams: %@ \n"
            ">",self, _endpoint, methodName, _path, paramStr];
}

# pragma mark - send and cancel

- (SFNetworkOperation*) send:(SFNetworkEngine*) networkEngine {
    NSString *url = [NSString stringWithString:_path];
    NSString *reqEndpoint = _endpoint;
    if (![url hasPrefix:reqEndpoint]) {
        url = [NSString stringWithFormat:@"%@%@", reqEndpoint, url];
    }
    
    switch(_method) {
        case SFRestMethodGET: _networkOperation = [networkEngine get:url params:_queryParams]; break;
        case SFRestMethodPOST: _networkOperation = [networkEngine post:url params:_queryParams]; break;
        case SFRestMethodPUT: _networkOperation = [networkEngine put:url params:_queryParams]; break;
        case SFRestMethodDELETE: _networkOperation = [networkEngine delete:url params:_queryParams]; break;
        case SFRestMethodHEAD: _networkOperation = [networkEngine head:url params:_queryParams]; break;
        case SFRestMethodPATCH: _networkOperation = [networkEngine patch:url params:_queryParams]; break;
    }

    // File upload
    if (nil != _postFile) {
        [_networkOperation addPostFileData:_postFile.fileData paramName:_postFile.paramName fileName:_postFile.fileName mimeType:_postFile.mimeType];
        
    }
    // Post/Patch or Put (but not a file upload)
    else if (_method == SFRestMethodPOST || _method == SFRestMethodPATCH || _method == SFRestMethodPUT) {
        SFNetworkOperationEncodingBlock jsonEncodingBlock = ^(NSDictionary *postDataDict) {
            return [SFJsonUtils JSONRepresentation:postDataDict];
        };
        [_networkOperation setCustomPostDataEncodingHandler:jsonEncodingBlock forType:@"application/json"];
    }
    
    _networkOperation.delegate = self;
    [networkEngine enqueueOperation:_networkOperation];
    
    return _networkOperation;
}

- (void) cancel
{
    [_networkOperation cancel];
}

#pragma mark - Upload

- (void)addPostFileData:(NSData *)fileData paramName:(NSString *)paramName fileName:(NSString *)fileName mimeType:(NSString *)mimeType {
    _postFile = [[SFRestRequestPostFile alloc] initWithFileData:fileData paramName:paramName fileName:fileName mimeType:mimeType];
}

#pragma mark - SFNetworkOperationDelegate

- (void)networkOperationDidFinish:(SFNetworkOperation *)networkOperation {
    if ([_delegate respondsToSelector:@selector(request:didLoadResponse:)]) {
        id dataResponse = _parseResponse ? [networkOperation responseAsJSON] : [networkOperation responseAsData];
        [_delegate request:self didLoadResponse:dataResponse];
    }
    [[SFRestAPI sharedInstance] removeActiveRequestObject:self];
}

- (void)networkOperation:(SFNetworkOperation*)networkOperation didFailWithError:(NSError*)error {
    if ([_delegate respondsToSelector:@selector(request:didFailLoadWithError:)]) {
        [_delegate request:self didFailLoadWithError:error];
    }
    [[SFRestAPI sharedInstance] removeActiveRequestObject:self];
}

- (void)networkOperationDidCancel:(SFNetworkOperation *)networkOperation {
    if ([_delegate respondsToSelector:@selector(requestDidCancelLoad:)]) {
        [_delegate requestDidCancelLoad:self];
    }
    [[SFRestAPI sharedInstance] removeActiveRequestObject:self];
}

- (void)networkOperationDidTimeout:(SFNetworkOperation *)networkOperation {
    if ([_delegate respondsToSelector:@selector(requestDidTimeout:)]) {
        [_delegate requestDidTimeout:self];
    }
    [[SFRestAPI sharedInstance] removeActiveRequestObject:self];
}


@end
