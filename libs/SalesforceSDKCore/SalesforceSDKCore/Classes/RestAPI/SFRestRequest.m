/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
 
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
#import "SalesforceSDKConstants.h"
#import "SFJsonUtils.h"

NSString * const kSFDefaultRestEndpoint = @"/services/data";

@implementation SFRestRequest

- (id)initWithMethod:(SFRestMethod)method path:(NSString *)path queryParams:(NSDictionary *)queryParams {
    self = [super init];
    if (self) {
        self.method = method;
        self.path = path;
        self.queryParams = queryParams;
        self.endpoint = kSFDefaultRestEndpoint;
        self.requiresAuthentication = YES;
        self.request = [[NSMutableURLRequest alloc] init];
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

#pragma mark - Custom request body

- (void)setCustomRequestBodyString:(NSString *)bodyString contentType:(NSString *)contentType {
    if (bodyString == nil) bodyString = @"";
    [self setCustomRequestBodyData:[bodyString dataUsingEncoding:NSUTF8StringEncoding] contentType:contentType];
}

- (void)setCustomRequestBodyDictionary:(NSDictionary *)bodyDictionary contentType:(NSString *)contentType {
    if (bodyDictionary) {
        self.requestBodyAsDictionary = bodyDictionary;
        NSData *body = [SFJsonUtils JSONDataRepresentation:bodyDictionary options:0];
        if (body) {
            [self setCustomRequestBodyData:body contentType:contentType];
        }
    }
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

# pragma mark - send and cancel

- (NSURLRequest *)prepareRequestForSend {
    SFUserAccount *user = [SFUserAccountManager sharedInstance].currentUser;
    if (user) {
        NSString *baseUrl = user.credentials.apiUrl.absoluteString;

        // Performs sanity checks on the path against the endpoint value.
        if (self.endpoint.length > 0 && [self.path hasPrefix:self.endpoint]) {
            self.path = [self.path substringFromIndex:self.endpoint.length];
        }

        // Puts the pieces together and constructs a full URL.
        NSMutableString *fullUrl = [[NSMutableString alloc] initWithString:baseUrl];
        if (![fullUrl hasSuffix:@"/"]) {
            [fullUrl appendString:@"/"];
        }

        // 'endpoint' could be empty for a custom endpoint like 'apexrest'.
        NSMutableString *endpoint = [[NSMutableString alloc] initWithString:self.endpoint];
        if (endpoint.length > 0) {
            if ([endpoint hasPrefix:@"/"]) {
                [endpoint deleteCharactersInRange:NSMakeRange(0, 1)];
            }
            if (![endpoint hasSuffix:@"/"]) {
                [endpoint appendString:@"/"];
            }
            [fullUrl appendString:endpoint];
        }
        NSMutableString *path = [[NSMutableString alloc] initWithString:self.path];
        if ([path hasPrefix:@"/"]) {
            [path deleteCharactersInRange:NSMakeRange(0, 1)];
        }
        [fullUrl appendString:path];
        NSURLComponents *components = [NSURLComponents componentsWithString:fullUrl];

        // Adds query parameters to the request if any are set.
        if (self.queryParams) {
            NSMutableArray<NSURLQueryItem *> *queryItems = [[NSMutableArray alloc] init];
            for (NSString *key in self.queryParams.allKeys) {
                if (key != nil) {
                    NSURLQueryItem *query = [NSURLQueryItem queryItemWithName:key value:self.queryParams[key]];
                    [queryItems addObject:query];
                }
            }
            components.queryItems = queryItems;
        }
        self.request = [[NSMutableURLRequest alloc] initWithURL:components.URL];

        // Sets HTTP method on the request.
        [self.request setHTTPMethod:[SFRestRequest httpMethodFromSFRestMethod:self.method]];

        // Sets OAuth Bearer token header on the request.
        NSString *bearer = [NSString stringWithFormat:@"Bearer %@", user.credentials.accessToken];
        [self.request setValue:bearer forHTTPHeaderField:@"Authorization"];

        // Adds custom headers to the request if any are set.
        if (self.customHeaders) {
            for (NSString *key in self.customHeaders.allKeys) {
                if (key != nil) {
                    NSString *value = self.customHeaders[key];
                    [self.request setValue:value forHTTPHeaderField:key];
                }
            }
        }

        // Sets HTTP body if body exists.
        if (self.requestBodyStreamBlock != nil) {
            if (self.requestContentType != nil) {
                [self.request setValue:self.requestContentType forHTTPHeaderField:@"Content-Type"];
                self.request.HTTPBodyStream = self.requestBodyStreamBlock();
            }
        }
        return self.request;
    }
    return nil;
}

- (void)cancel {
    if (self.sessionDataTask) {
        [self.sessionDataTask cancel];
    }
}

- (void)setHeaderValue:(NSString *)value forHeaderName:(NSString *)name {
    if (!self.customHeaders) {
        self.customHeaders = [[NSMutableDictionary alloc] init];
    }
    [self.customHeaders setValue:value forKey:name];
}

#pragma mark - Upload

- (void)addPostFileData:(NSData *)fileData description:(NSString *)description fileName:(NSString *)fileName mimeType:(NSString *)mimeType {
    NSString *mpeBoundary = @"************************";
    NSString *mpeSeparator = @"--";
    NSString *newline = @"\r\n";
    NSString *bodyContentDisposition = [NSString stringWithFormat:@"Content-Disposition: form-data; name=fileData; filename=\"%@\"", fileName];
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"%@%@%@", mpeSeparator, mpeBoundary, newline] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: application/json; charset=UTF-8%@", newline] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"json\"%@", newline] dataUsingEncoding:NSUTF8StringEncoding]];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (fileName) {
        params[@"title"] = fileName;
    }
    if (description) {
        params[@"desc"] = description;
    }
    NSError *parsingError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&parsingError];
    if (jsonData && !parsingError) {
        [body appendData:jsonData];
    }
    [body appendData:[[NSString stringWithFormat:@"%@%@%@", mpeSeparator, mpeBoundary, newline] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[bodyContentDisposition dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[newline dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[newline dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:fileData];
    [body appendData:[newline dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@%@%@%@", mpeSeparator, mpeBoundary, mpeSeparator, newline] dataUsingEncoding:NSUTF8StringEncoding]];
    [self setCustomRequestBodyData:body contentType:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", mpeBoundary]];
    [self.request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [self.request setHTTPShouldHandleCookies:NO];
    [self setHeaderValue:@"Keep-Alive" forHeaderName:@"Connection"];
}

+ (BOOL)isNetworkError:(NSError *)error {
    switch (error.code) {
        case kCFURLErrorNotConnectedToInternet:
        case kCFURLErrorCannotFindHost:
        case kCFURLErrorCannotConnectToHost:
        case kCFURLErrorNetworkConnectionLost:
        case kCFURLErrorDNSLookupFailed:
        case kCFURLErrorResourceUnavailable:
        case kCFURLErrorTimedOut:
            return YES;
            break;
        default:
            return NO;
    }
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

@end
