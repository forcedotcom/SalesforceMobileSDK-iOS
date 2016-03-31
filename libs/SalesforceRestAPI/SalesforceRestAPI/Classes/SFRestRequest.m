/*
 Copyright (c) 2011-2015, salesforce.com, inc. All rights reserved.
 
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

#import "SFRestRequest+Internal.h"
#import "SFRestAPI+Internal.h"
#import "SFRestAPISalesforceAction.h"
#import <SalesforceSDKCore/SalesforceSDKConstants.h>
#import <SalesforceSDKCore/SFJsonUtils.h>
#import <SalesforceNetwork/CSFSalesforceAction.h>
#import <SalesforceNetwork/CSFDefines.h>
#import <SalesforceNetwork/CSFParameterStorage.h>

NSString * const kSFDefaultRestEndpoint = @"/services/data";

@implementation SFRestRequest

- (id)initWithMethod:(SFRestMethod)method path:(NSString *)path queryParams:(NSDictionary *)queryParams {
    SFRestAPISalesforceAction *action = [self actionFromMethod:method path:path];
    return [self initWithSalesforceAction:action queryParams:queryParams];
}

- (instancetype)initWithSalesforceAction:(SFRestAPISalesforceAction *)action queryParams:(NSDictionary *)queryParams {
    self = [super init];
    if (self) {
        self.action = action;
        self.queryParams = queryParams;
    }
    return self;
}

+ (instancetype)requestWithMethod:(SFRestMethod)method path:(NSString *)path queryParams:(NSDictionary *)queryParams {
    return [[self alloc] initWithMethod:method path:path queryParams:queryParams];
}

- (NSString *)description {
    NSString *methodName;
    switch (self.method) {
        case SFRestMethodGET: methodName = @"GET"; break;
        case SFRestMethodPOST: methodName = @"POST"; break;
        case SFRestMethodPUT: methodName = @"PUT"; break;
        case SFRestMethodDELETE: methodName = @"DELETE"; break;
        case SFRestMethodHEAD: methodName = @"HEAD"; break;
        case SFRestMethodPATCH: methodName = @"PATCH"; break;
        default:
            methodName = @"Unset";break;
    }
    NSString *paramStr = self.queryParams ? [SFJsonUtils JSONRepresentation:self.queryParams] : @"[]";
    return [NSString stringWithFormat:
            @"<SFRestRequest %p \n"
            "endpoint: %@ \n"
            "method: %@ \n"
            "path: %@ \n"
            "queryParams: %@ \n"
            ">",self, self.endpoint, methodName, self.path, paramStr];
}

- (SFRestAPISalesforceAction *)actionFromMethod:(SFRestMethod)method path:(NSString *)path {
    __weak SFRestRequest *weakSelf = self;
    SFRestAPISalesforceAction *action = [[SFRestAPISalesforceAction alloc] initWithResponseBlock:^(CSFAction *action, NSError *error) {
        __strong SFRestRequest *strongSelf = weakSelf;
        [strongSelf handleCSFActionResponse:action error:error];
    }];
    
    action.method = [[self class] httpMethodFromSFRestMethod:method];
    
    NSString *apiVersion = nil;
    NSString *actionVerb = nil;
    [[self class] makeAPIVersionAndActionVerbFromPath:path apiVersion:&apiVersion actionVerb:&actionVerb];
    action.apiVersion = apiVersion;
    action.verb = actionVerb;
    
    return action;
}

#pragma mark - Properties

- (SFRestMethod)method {
    return [[self class] sfRestMethodFromHTTPMethod:self.action.method];
}

- (void)setMethod:(SFRestMethod)method {
    self.action.method = [[self class] httpMethodFromSFRestMethod:method];
}

- (NSString *)path {
    NSString *apiVersion = (self.action.apiVersion == nil ? @"" : self.action.apiVersion);
    NSString *actionVerb = (self.action.verb == nil ? @"" : self.action.verb);
    NSString *returnPath = [NSString stringWithFormat:@"%@%@", apiVersion, actionVerb];
    if (![returnPath hasPrefix:@"/"]) returnPath = [NSString stringWithFormat:@"/%@", returnPath];
    return returnPath;
}

- (void)setPath:(NSString *)path {
    NSString *apiVersion = nil;
    NSString *actionVerb = nil;
    [[self class] makeAPIVersionAndActionVerbFromPath:path apiVersion:&apiVersion actionVerb:&actionVerb];
    self.action.apiVersion = apiVersion;
    self.action.verb = actionVerb;
}

- (NSString *)endpoint {
    return self.action.pathPrefix;
}

- (void)setEndpoint:(NSString *)endpoint {
    self.action.pathPrefix = endpoint;
}

- (BOOL)parseResponse {
    return self.action.parseResponse;
}

- (void)setParseResponse:(BOOL)parseResponse {
    self.action.parseResponse = parseResponse;
}

- (BOOL)requiresAuthentication {
    return self.action.requiresAuthentication;
}

- (void)setRequiresAuthentication:(BOOL)requiresAuthentication {
    self.action.requiresAuthentication = requiresAuthentication;
}

#pragma mark - Custom request body

- (void)setCustomRequestBodyString:(NSString *)bodyString contentType:(NSString *)contentType {
    if (bodyString == nil) bodyString = @"";
    [self setCustomRequestBodyData:[bodyString dataUsingEncoding:NSUTF8StringEncoding] contentType:contentType];
}

- (void)setCustomRequestBodyData:(NSData *)bodyData contentType:(NSString *)contentType {
    if (bodyData == nil) bodyData = [NSData data];
    NSInputStream *(^bodyStreamBlock)(void) = ^{
        return [NSInputStream inputStreamWithData:bodyData];
    };
    [self setCustomRequestBodyStream:bodyStreamBlock contentType:contentType];
}

- (void)setCustomRequestBodyStream:(NSInputStream* (^)(void))bodyInputStreamBlock contentType:(NSString *)contentType {
    if (bodyInputStreamBlock != nil) {
        self.requestBodyStreamBlock = bodyInputStreamBlock;
        if ([contentType length] > 0) {
            self.requestContentType = contentType;
        }
    }
}

#pragma mark - Custom headers

- (NSDictionary *)customHeaders
{
    return self.action.allHTTPHeaderFields;
}

- (void)setCustomHeaders:(NSDictionary *)customHeaders
{
    for (NSString *key in [customHeaders allKeys]) {
        [self setHeaderValue:customHeaders[key] forHeaderName:key];
    }
}

- (void)setHeaderValue:(NSString *)value forHeaderName:(NSString *)name
{
    if (name == nil)
        return;
    
    if ([value length] > 0) {
        [self.action setValue:value forHTTPHeaderField:name];
    } else {
        // TODO: Network SDK doesn't have a header removal mechanism at this point.
    }
}

# pragma mark - send and cancel

- (void)prepareRequestForSend
{
    // We need to do some jujitsu to figure out how best to form up the request, based on the way the
    // request is configured.
    
    // Sanity check the path against the endpoint value.
    if (self.endpoint.length > 0 && [self.path hasPrefix:self.endpoint]) {
        self.path = [self.path substringFromIndex:self.endpoint.length];
    }
    
    // Custom request body overrides default behavior.
    if (self.requestBodyStreamBlock != nil) {
        self.action.parameters.bodyStreamBlock = self.requestBodyStreamBlock;
        if ([self.requestContentType length] > 0) {
            [self setHeaderValue:self.requestContentType forHeaderName:@"Content-Type"];
        }
        return;
    }
    
    // If there are no query params, there's nothing left to do here.
    if ([[self.queryParams allKeys] count] == 0) {
        return;
    }
    
    // Otherwise, determine request data delivery model.
    if (self.method != SFRestMethodGET && self.method != SFRestMethodDELETE) {
        // It's POSTish.  The Network SDK handles content-based requests more or less automatically,
        // but if you want to post a JSON object or other data, you have to manage the contents yourself.
        if (self.action.parameters.parameterStyle != CSFParameterStyleMultipart) {
            // Standard POST data.  We'll assume we can just send it as JSON.
            NSData *bodyData = [SFJsonUtils JSONDataRepresentation:self.queryParams];
            if (bodyData == nil) {
                [self log:SFLogLevelError format:@"%@: Error serializing request data to NSData object: %@",
                 NSStringFromSelector(_cmd),
                 [[SFJsonUtils lastError] localizedDescription]];
                return;
            }
            NSInputStream *(^bodyStreamBlock)(void) = ^{
                return [NSInputStream inputStreamWithData:bodyData];
            };
            self.action.parameters.bodyStreamBlock = bodyStreamBlock;
            [self setHeaderValue:@"application/json" forHeaderName:@"Content-Type"];
            [self setHeaderValue:[NSString stringWithFormat:@"%lu", (unsigned long)bodyData.length] forHeaderName:@"Content-Length"];
        } else {
            [self convertQueryParamsToActionParams];
        }
    } else {
        [self convertQueryParamsToActionParams];
    }
}

- (void)cancel
{
    [self.action cancel];
}

#pragma mark - Upload

- (void)addPostFileData:(NSData *)fileData paramName:(NSString *)paramName fileName:(NSString *)fileName mimeType:(NSString *)mimeType {
    [self.action.parameters setObject:fileData forKey:paramName filename:fileName mimeType:mimeType];
}

#pragma mark - SalesforceNetwork helpers

- (void)handleCSFActionResponse:(CSFAction *)action error:(NSError *)error {
    if (error != nil) {
        if (error.code == CSFNetworkCancelledError) {
            if ([self.delegate respondsToSelector:@selector(requestDidCancelLoad:)]) {
                [self.delegate requestDidCancelLoad:self];
            }
        } else if (error.code == NSURLErrorTimedOut) {
            if ([self.delegate respondsToSelector:@selector(requestDidTimeout:)]) {
                [self.delegate requestDidTimeout:self];
            }
        } else {
            if ([self.delegate respondsToSelector:@selector(request:didFailLoadWithError:)]) {
                [self.delegate request:self didFailLoadWithError:error];
            }
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(request:didLoadResponse:)]) {
            [self.delegate request:self didLoadResponse:action.outputContent];
        }
    }
    
    [[SFRestAPI sharedInstance] removeActiveRequestObject:self];
}

#pragma mark - Util method

- (void)convertQueryParamsToActionParams {
    NSDictionary *paramsCopy = [self.queryParams copy];
    for (NSString *param in [paramsCopy allKeys]) {
        [self.action.parameters setObject:paramsCopy[param] forKey:param];
    }
}

+ (BOOL)isNetworkError:(NSError *)error {
    return [CSFSalesforceAction isNetworkError:error];
}

+ (NSString *)httpMethodFromSFRestMethod:(SFRestMethod)restMethod {
    NSString *methodName;
    switch (restMethod) {
        case SFRestMethodGET: methodName = @"GET"; break;
        case SFRestMethodPOST: methodName = @"POST"; break;
        case SFRestMethodPUT: methodName = @"PUT"; break;
        case SFRestMethodDELETE: methodName = @"DELETE"; break;
        case SFRestMethodHEAD: methodName = @"HEAD"; break;
        case SFRestMethodPATCH: methodName = @"PATCH"; break;
        default: methodName = @"Unset"; break;
    }
    return methodName;
}

+ (SFRestMethod)sfRestMethodFromHTTPMethod:(NSString *)httpMethod {
    SFRestMethod restMethodName = SFRestMethodGET;
    httpMethod = [httpMethod lowercaseString];
    if ([httpMethod isEqualToString:@"get"]) restMethodName = SFRestMethodGET;
    else if ([httpMethod isEqualToString:@"post"]) restMethodName = SFRestMethodPOST;
    else if ([httpMethod isEqualToString:@"put"]) restMethodName = SFRestMethodPUT;
    else if ([httpMethod isEqualToString:@"delete"]) restMethodName = SFRestMethodDELETE;
    else if ([httpMethod isEqualToString:@"head"]) restMethodName = SFRestMethodHEAD;
    else if ([httpMethod isEqualToString:@"patch"]) restMethodName = SFRestMethodPATCH;
    
    return restMethodName;
}

+ (void)makeAPIVersionAndActionVerbFromPath:(NSString *)path
                                 apiVersion:(NSString **)apiVersion
                                 actionVerb:(NSString **)actionVerb  {
    if ([path length] == 0) {
        *apiVersion = @"";
        *actionVerb = @"";
        return;
    }
    
    if (![path hasPrefix:@"/"]) path = [NSString stringWithFormat:@"/%@", path];
    
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^/(v\\d+\\.0)/(.*)$"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    if (error != nil) {
        [SFLogger log:self level:SFLogLevelError format:@"%@ Regular expression error evaluating REST API path '%@': %@",
         NSStringFromSelector(_cmd), path, [error localizedDescription]];
        *apiVersion = @"";
        *actionVerb = @"";
        return;
    }
    
    // Number of ranges should be 0 or 3, since it's an all-or-nothing regular expression.  3 because
    // capture range "0" is the whole string.
    NSTextCheckingResult *matchResult = [regex firstMatchInString:path options:0 range:NSMakeRange(0, [path length])];
    if (matchResult.numberOfRanges == 0) {
        // No match.  Assume no API version, take the whole string as the action verb.
        *apiVersion = @"";
        *actionVerb = path;
    } else {
        // Match.  We can split out the API version and the action verb.
        *apiVersion = [path substringWithRange:[matchResult rangeAtIndex:1]];
        NSString *actionVerbMatch = [path substringWithRange:[matchResult rangeAtIndex:2]];
        *actionVerb = [NSString stringWithFormat:@"/%@", actionVerbMatch];
    }
}

@end
