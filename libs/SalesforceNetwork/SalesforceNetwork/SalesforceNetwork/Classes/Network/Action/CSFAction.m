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

#import <objc/runtime.h>

#import <SalesforceSDKCore/SalesforceSDKCore.h>

#import "CSFAction+Internal.h"
#import "CSFNetwork+Internal.h"
#import "CSFActionModel.h"
#import "CSFTokenRefresh.h"
#import "CSFParameterStorage_Internal.h"
#import "NSMutableURLRequest+SalesforceNetwork.h"

NSString * const CSFActionSecurityTokenKey = @"securityToken"; // CSRF security token key

NSString * const CSFDefaultLocale = @"en-us";
NSString * const CSFNetworkErrorActionKey = @"action";
NSString * const CSFNetworkErrorAuthenticationFailureKey = @"isAuthenticationFailure";

NSTimeInterval const CSFActionDefaultTimeOut = 3 * 60; // 3 minutes

@interface CSFAction () {
    BOOL _ready;
    BOOL _executing;
    BOOL _finished;
    
    CSFParameterStorage *_parameters;
    NSMutableDictionary *_HTTPHeaders;
    NSData  *_jsonData;
    BOOL _enqueueIfNoNetwork;
}

@end

@implementation CSFAction

+ (NSURL*)urlForAction:(CSFAction*)action error:(NSError**)error {
    if (!action) {
        return nil;
    }
    
    NSMutableString *baseUrlString = [NSMutableString stringWithString:[action.enqueuedNetwork.account.credentials.apiUrl absoluteString]];
    NSMutableString *path = [NSMutableString stringWithFormat:@"%@%@", action.basePath, action.verb];
    
    // Make sure path is not empty
    if (baseUrlString.length == 0) {
        *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                     code:CSFNetworkURLCredentialsError
                                 userInfo:@{ NSLocalizedDescriptionKey: @"Network action must have an API URL",
                                             CSFNetworkErrorActionKey: action }];
        return nil;
    } else if (path.length == 0) {
        *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                     code:CSFNetworkURLCredentialsError
                                 userInfo:@{ NSLocalizedDescriptionKey: @"Network action must have a valid path",
                                             CSFNetworkErrorActionKey: action }];
        return nil;
    }
    
    if (![baseUrlString hasSuffix:@"/"]) [baseUrlString appendString:@"/"];
    if ([path hasPrefix:@"/"]) [path deleteCharactersInRange:NSMakeRange(0, 1)];
    NSString *urlString = [baseUrlString stringByAppendingString:path];
    NSURL *url = [NSURL URLWithString:urlString];
    return url;
}

- (NSDictionary *)headersForAction {
    NSMutableArray *preferredLanguages = [[NSLocale preferredLanguages] mutableCopy];
    if (![preferredLanguages containsObject:CSFDefaultLocale]) {
        [preferredLanguages addObject:CSFDefaultLocale];
    }
    
    NSMutableDictionary *httpHeaders = [self.allHTTPHeaderFields mutableCopy];
    httpHeaders[@"Accept-Encoding"] = @"gzip";
    httpHeaders[@"Accept-Language"] = [preferredLanguages componentsJoinedByString:@", "];
    
    CSFNetwork *network = self.enqueuedNetwork;
    NSString *userAgent = network.userAgent;
    if (nil != userAgent) {
        httpHeaders[@"User-Agent"] = userAgent;
    }

    return httpHeaders;
}

+ (NSError *)errorInResponseDataForAction:(CSFAction*)action {
    NSError *error = nil;
    
    if ([action.outputContent isKindOfClass:[NSArray class]]) {
        NSArray *jsonResponse = (NSArray*)action.outputContent;
        if (jsonResponse.count == 1) {
            NSDictionary *errorDictionary = jsonResponse[0];
            if ([errorDictionary isKindOfClass:[NSDictionary class]]) {
                NSString *potentialErrorCode = errorDictionary[@"errorCode"];
                NSString *potentialErrorMessage  = errorDictionary[@"message"];
                if (potentialErrorCode && potentialErrorMessage) {
                    NSDictionary *errorDictionary = @{ NSLocalizedDescriptionKey: potentialErrorMessage,
                                                       NSLocalizedFailureReasonErrorKey: potentialErrorCode,
                                                       CSFNetworkErrorActionKey: action };
                    error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                                code:CSFNetworkAPIError
                                            userInfo:errorDictionary];
                }
            }
        }
    }
    return error;
}

+ (instancetype)actionWithHTTPMethod:(NSString*)method onURL:(NSURL*)url withResponseBlock:(CSFActionResponseBlock)responseBlock {
    CSFAction *action = [[self alloc] initWithResponseBlock:responseBlock];
    
    NSString *baseString = nil;
    if (url.port) {
        baseString = [NSString stringWithFormat:@"%@://%@:%@", url.scheme, url.host, url.port];
    } else {
        baseString = [NSString stringWithFormat:@"%@://%@", url.scheme, url.host];
    }
    
    action.baseURL = [NSURL URLWithString:baseString];
    action.verb = url.path;
    action.method = method;
    return action;
}

#pragma mark -
#pragma mark object lifecycle

- (instancetype)initWithResponseBlock:(CSFActionResponseBlock)responseBlock {
    self = [super init];
    if (self) {
        _maxRetryCount = 1;
        _timeoutInterval = CSFActionDefaultTimeOut;
        _jsonData = nil;
        _enqueueIfNoNetwork = YES; // YES by default
        _executionCapType = CSFActionExecutionCapTypeUnlimited;
        _method = @"GET";
        _authRefreshClass = [CSFTokenRefresh class];
        _requiresAuthentication = YES;
        self.credentialsReady = YES;
        self.responseBlock = responseBlock;
    }
    return self;
}

#pragma mark -
#pragma mark implementation

- (CSFParameterStorage *)parameters {
    if (!_parameters) {
        _parameters = [[CSFParameterStorage alloc] init];
        _parameters.HTTPMethod = self.method;
    }
	        
    return _parameters;
}

- (void)setURL:(NSURL*)url {
    NSURL *localURL = CSFNotNullURL(url);
    
    // For example, given this URL:
    // /services/data/v24.0/chatter/feeds/news/005300000054oU6AAI/feed-items?page=2012-04-26T04%3A50%3A14Z%2C0D53000000qpC2ZCAU&pageSize=20
    // We decompose in:
    // path -> /services/data/v24.0/chatter/feeds/news/005300000054oU6AAI/feed-items
    // query -> page=2012-04-26T04%3A50%3A14Z%2C0D53000000qpC2ZCAU&pageSize=20
    
    NSString *path = [localURL path];
    self.verb = path;
    
    NSString *query = [localURL query];
    for (NSString *param in [query componentsSeparatedByString:@"&"]) {
        NSArray *tuple = [param componentsSeparatedByString:@"="];
        if (tuple.count == 2) {
            self.parameters[tuple[0]] = CSFURLDecode(tuple[1]);
        }
    }
}

- (void)setVerb:(NSString *)verb {
    if (_verb != verb) {
        NSString *localVerb = CSFNotNullString(verb);
        
        NSRange questionRange = [localVerb rangeOfString:@"?"];
        if (questionRange.location != NSNotFound) {
            NSString *queryString = [localVerb substringFromIndex:NSMaxRange(questionRange)];
            for (NSString *param in [queryString componentsSeparatedByString:@"&"]) {
                NSArray *tuple = [param componentsSeparatedByString:@"="];
                if (tuple.count == 2) {
                    self.parameters[tuple[0]] = CSFURLDecode(tuple[1]);
                }
            }

            _verb = [localVerb substringToIndex:questionRange.location];
        } else {
            _verb = [localVerb copy];
        }
    }
}

- (void)setMethod:(NSString *)method {
    if (_method != method) {
        _method = [method copy];
        _parameters.HTTPMethod = method;
    }
}

- (NSDictionary*)allHTTPHeaderFields {
    return [NSDictionary dictionaryWithDictionary:_HTTPHeaders];
}

- (NSString *)valueForHTTPHeaderField:(NSString *)field {
    return [_HTTPHeaders valueForKey:field];
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if (!_HTTPHeaders) {
        _HTTPHeaders = [NSMutableDictionary new];
    }

    _HTTPHeaders[field] = value;
}

- (void)removeValueForHTTPHeaderField:(NSString *)field {
    [_HTTPHeaders removeObjectForKey:field];
}

- (NSUInteger)hash {
    NSUInteger result = 17;
    result ^= [self.verb hash] + result * 37;
    result ^= [self.method hash] + result * 37;
    result ^= [self.allHTTPHeaderFields hash] + result * 37;
    if (_parameters) {
        result ^= [_parameters hash] + result * 37;
    }
    return result;
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[CSFAction class]]) {
        return [self isEqualToAction:(CSFAction *)object];
    } else {
        return NO;
    }
}

- (BOOL)isEqualToAction:(CSFAction *)action {
    if (!action || self.enqueuedNetwork != action.enqueuedNetwork) {
        return NO;
    }
    
    BOOL isEqual = [self.verb isEqualToString:action.verb];
    isEqual = isEqual && [self.method isEqualToString:action.method];
    isEqual = (isEqual && ((!_parameters && !action->_parameters) ||
                           [_parameters isEqual:action.parameters]));

    // intentionally ignoring userData and completionBlock, as both are difficult to compare
    
    return isEqual;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, %@ \"%@\"%@>",
            [self class], self, self.method, self.verb, (self.isProgrammatic ? @" (programmatic)" : @"")];
}

- (NSString*)basePath {
    return @"";
}

#pragma mark Implementation override methods

- (NSURLSessionTask*)sessionTaskToProcessRequest:(NSURLRequest*)request session:(NSURLSession*)session {
    return [session dataTaskWithRequest:request];
}

- (void)sessionDownloadTask:(NSURLSessionDownloadTask*)task didFinishDownloadingToURL:(NSURL *)location {
    if ([self isCancelled]) {
        return;
    }
    
    // Do something ...
}

- (void)sessionTask:(NSURLSessionTask*)task didCompleteWithError:(NSError*)error {
    if ([self isCancelled]) {
        self.responseData = nil;
        return;
    }
    
    if (error) {
        // Error from URLSession:task:didCompleteWithError: is generally an error with the request itself
        // (as opposed to an error returned from the service).
        if ([self shouldRetryWithError:error]) {
            [self retry];
        } else {
            [self completeOperationWithError:[NSError errorWithDomain:CSFNetworkErrorDomain
                                                                 code:CSFNetworkHTTPResponseError
                                                             userInfo:@{ NSLocalizedDescriptionKey: @"HTTP request returned an error",
                                                                         CSFNetworkErrorActionKey: self,
                                                                         NSUnderlyingErrorKey: error }]];
        }
    } else if (![task.response isKindOfClass:[NSHTTPURLResponse class]]) {
        [self completeOperationWithError:[NSError errorWithDomain:CSFNetworkErrorDomain
                                                             code:CSFNetworkURLResponseInvalidError
                                                         userInfo:@{ NSLocalizedDescriptionKey: @"Unexpected URL response type returned.",
                                                                     CSFNetworkErrorActionKey: self }]];
    } else {
        [self completeOperationWithResponse:(NSHTTPURLResponse *)task.response];
    }
}

- (void)sessionDataTask:(NSURLSessionDataTask*)task didReceiveData:(NSData*)data {
    if ([self isCancelled]) {
        self.responseData = nil;
        return;
    }
    
    if (self.responseData == nil) {
        self.responseData = [NSMutableData dataWithCapacity:[data length]];
    }
    [self.responseData appendData:data];
}

#pragma mark NSOperation implementation

- (void)start {
    if ([self isCancelled]) {
        [self completeOperationWithError:[NSError errorWithDomain:CSFNetworkErrorDomain
                                                             code:CSFNetworkCancelledError
                                                         userInfo:@{ NSLocalizedDescriptionKey: @"Operation was cancelled",
                                                                     CSFNetworkErrorActionKey: self }]];
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    _executing = YES;
    [self didChangeValueForKey:@"isExecuting"];

    // If this is a duplicate action, the parent must have just completed, so we can safely process our response based
    // on the result of that parent.  By calling the completion handler, the response will automatically be sent,
    // and the appropriate callbacks triggered.
    if (self.duplicateParentAction) {
        [self completeOperationWithError:self.duplicateParentAction.error];
        return;
    }
    
    // Create NSURLRequest from the Action
    NSError *error =  nil;
    NSURLRequest *request = [self createURLRequest:&error];
    
    NSHTTPURLResponse *overrideResponse = nil;
    NSData *overrideData = nil;
    if (error) {
        [self completeOperationWithError:error];
    } else if ([self overrideRequest:request withResponseData:&overrideData andHTTPResponse:&overrideResponse]) {
        // If some internal process has already updated and created outputContent, handle that immediately.
        // This is useful for unit tests or mock data sources.
        self.responseData = [NSMutableData dataWithData:overrideData];
        [self completeOperationWithResponse:overrideResponse];
    } else {
        NSURLSession *session = self.enqueuedNetwork.ephemeralSession;
        _sessionTask = [self sessionTaskToProcessRequest:request session:session];
        [_sessionTask resume];
    }
}

- (void)cancel {
    [super cancel];
    [self.sessionTask cancel];
    
    [self completeOperationWithError:[NSError errorWithDomain:CSFNetworkErrorDomain
                                                         code:CSFNetworkCancelledError
                                                     userInfo:@{ NSLocalizedDescriptionKey: @"Operation was cancelled",
                                                                 CSFNetworkErrorActionKey: self }]];
}

- (BOOL)isAsynchronous {
    return YES;
}

- (BOOL)isReady {
    BOOL result = YES;
    
    if (self.duplicateParentAction) {
        result = [self.duplicateParentAction isFinished];
    } else if (!self.credentialsReady) {
        result = NO;
    } else {
        if ([self.authRefreshClass isSubclassOfClass:[CSFAuthRefresh class]]) {
            result = ![self.authRefreshClass isRefreshing];
        }
    }
    
    return result;
}

- (BOOL)isExecuting {
    return _executing;
}

- (BOOL)isFinished {
    return _finished;
}

#pragma mark Accessors

- (NSHTTPURLResponse*)httpResponse {
    NSHTTPURLResponse *result = _httpResponse;
    if (!result && _duplicateParentAction && _duplicateParentAction != self) {
        result = _duplicateParentAction.httpResponse;
    }
    return result;
}

- (id)outputContent {
    id result = _outputContent;
    if (!result && _duplicateParentAction && _duplicateParentAction != self) {
        result = _duplicateParentAction.outputContent;
    }
    return result;
}

- (NSError *)error {
    NSError *result = _error;
    if (!result && _duplicateParentAction && _duplicateParentAction != self) {
        result = _duplicateParentAction.error;
    }
    return result;
}

- (BOOL)shouldCacheResponse {
    BOOL result = YES;
    
    CSFNetwork *network = self.enqueuedNetwork;
    if (_shouldCacheResponse) {
        result = [_shouldCacheResponse boolValue];
    } else if (network) {
        result = network.offlineCacheEnabled;
    }
    
    return result;
}

- (void)setCacheResponse:(BOOL)cacheResponse {
    // NOTE: Use a NSNumber for the boolean so we can distinguish between unset, YES, or NO.
    //       If unset, we use the network engine's defaults.
    _shouldCacheResponse = @(cacheResponse);
}

- (void)setAuthRefreshClass:(Class)authRefreshClass {
    if (_authRefreshClass != authRefreshClass) {
        NSAssert(authRefreshClass == nil || [authRefreshClass isSubclassOfClass:[CSFAuthRefresh class]],
                 @"%@ ERROR: '%@' is not a subclass of %@.",
                 NSStringFromSelector(_cmd),
                 NSStringFromClass(authRefreshClass),
                 NSStringFromClass([CSFAuthRefresh class]));
        _authRefreshClass = authRefreshClass;
    }
}

#pragma mark Response handling

- (BOOL)overrideRequest:(NSURLRequest*)request withResponseData:(NSData**)data andHTTPResponse:(NSHTTPURLResponse**)response {
    return NO;
}

- (BOOL)shouldRetryWithError:(NSError*)error {
    BOOL result = NO;
    
    if (self.retryCount < self.maxRetryCount) {
        if ([error.domain isEqualToString:NSURLErrorDomain]) {
            // Look up the error codes here: http://nshipster.com/nserror/
            switch (error.code) {
                case kCFErrorHTTPConnectionLost:
                case kCFErrorHTTPProxyConnectionFailure:
                case kCFURLErrorCannotFindHost:
                case kCFURLErrorCannotConnectToHost:
                case kCFURLErrorNetworkConnectionLost:
                case kCFURLErrorDNSLookupFailed:
                case kCFURLErrorNotConnectedToInternet:
                    result = YES;
                    break;
            }
        }
    }
    
    return result;
}

- (void)retry {
    if (self.retryCount < self.maxRetryCount) {
        self.retryCount++;
        [self start];
    }
}

- (void)completeOperationWithError:(NSError *)error {
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    _executing = NO;
    _finished = YES;
    self.error = error;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    
    self.responseData = nil;
    
    if (self.responseBlock) {
        self.responseBlock(self, self.error);
    }
}

- (id)contentFromData:(NSData*)data fromResponse:(NSHTTPURLResponse*)response error:(NSError**)error {
    id content = nil;
    
    NSError *jsonParseError = nil;
    if ([self.responseData length] > 0) {
        content = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonParseError];
    }
    
    // If it's an error here, it's a basic parsing error.
    if (jsonParseError && error) {
        *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                         code:CSFNetworkJSONInvalidError
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Processing response content failed",
                                                 NSUnderlyingErrorKey: jsonParseError,
                                                 CSFNetworkErrorActionKey: self }];
    }
    
    return content;
}

- (void)completeOperationWithResponse:(NSHTTPURLResponse *)response {
    self.httpResponse = response;
    
    NSError *error = nil;
    self.outputContent = [self contentFromData:self.responseData fromResponse:response error:&error];
    self.responseData = nil;
    
    // Check to see if this action should be saved somewhere
    BOOL isCaching = NO;
    
    if (error) {
        // If the error is due to authentication failure, the refresh process will continue the original request/response process.
        if ([error.userInfo[CSFNetworkErrorAuthenticationFailureKey] boolValue]) {
            BOOL authRefreshDidLaunch = [self tryAuthRefresh];
            if (authRefreshDidLaunch) {
                return;
            }
        }
    } else {
        CSFNetwork *network = self.enqueuedNetwork;
        if (self.modelClass && CSFClassOrAncestorConformsToProtocol(self.modelClass, @protocol(CSFActionModel))) {
            NSMutableDictionary *context = [NSMutableDictionary new];
            
            NSURL *serverUrl = network.account.credentials.instanceUrl;
            if (serverUrl) {
                context[@"serverURL"] = serverUrl;
            }
            self.outputModel = [[(Class)self.modelClass alloc] initWithJSON:self.outputContent context:context];
        }
        
        if ([self shouldCacheResponse]) {
            NSMutableArray *availableCaches = [NSMutableArray new];
            for (NSObject<CSFNetworkOutputCache> *outputCache in network.outputCaches) {
                if ([outputCache respondsToSelector:@selector(shouldCacheOutputFromAction:)] &&
                    ![outputCache shouldCacheOutputFromAction:self])
                {
                    continue;
                }
                
                if ([outputCache respondsToSelector:@selector(cacheOutputFromAction:completionBlock:)]) {
                    [availableCaches addObject:outputCache];
                }
            }
            
            // If we have caches interested in storing this result, enumerate them and call the completion block when we're finished
            if (availableCaches.count > 0) {
                isCaching = YES;

                NSMutableArray *errors = [NSMutableArray arrayWithCapacity:availableCaches.count];
                dispatch_group_t dispatchGroup = dispatch_group_create();
                dispatch_queue_t dispatchQueue = dispatch_queue_create([self.verb UTF8String], DISPATCH_QUEUE_CONCURRENT);

                for (NSObject<CSFNetworkOutputCache> *outputCache in availableCaches) {
                    dispatch_group_enter(dispatchGroup);
                    dispatch_async(dispatchQueue, ^{
                        [outputCache cacheOutputFromAction:self completionBlock:^(NSError *error) {
                            if (error) {
                                [errors addObject:error];
                            }

                            dispatch_group_leave(dispatchGroup);
                        }];
                    });
                }
                
                // When all cache operations have completed, mark this action as finished and call the completion block with
                // the appropriate error, if any occurred.
                dispatch_group_notify(dispatchGroup, dispatchQueue, ^{
                    NSError *error = nil;
                    
                    if (errors.count == 1) {
                        error = [errors firstObject];
                    } else if (errors.count > 0) {
                        error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                                    code:CSFNetworkCacheError
                                                userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"One or more errors occurred while caching", @"Cache error"),
                                                            NSUnderlyingErrorKey: errors }];
                    }
                    
                    [self completeOperationWithError:error];
                });
            }
        }
    }
    
    // If we're not caching this response, return / complete the operation immediately
    if (!isCaching) {
        [self completeOperationWithError:error];
    }
}

- (BOOL)tryAuthRefresh {
    BOOL refreshLaunched = YES;
    if (self.requiresAuthentication) {
        if (self.authRefreshClass == nil) {
            NSLog(@"[%@ %@] WARNING: authRefreshClass property not set.  Cannot refresh credentials", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
            refreshLaunched = NO;
        } else {
            self.authRefreshInstance = [(CSFAuthRefresh *)[self.authRefreshClass alloc] initWithNetwork:self.enqueuedNetwork];
            __weak CSFAction *weakSelf = self;
            [self.authRefreshInstance refreshAuthWithCompletionBlock:^(CSFOutput *output, NSError *error) {
                __strong CSFAction *strongSelf = weakSelf;
                if (error) {
                    [strongSelf completeOperationWithError:error];
                } else {
                    [strongSelf start];
                }
            }];
        }
    } else {
        NSLog(@"[%@ %@] WARNING: Unauthorized response, but requiresAuthentication not set.  Cannot replay original request.",
              NSStringFromClass([self class]), NSStringFromSelector(_cmd));
        refreshLaunched = NO;
    }
    
    return refreshLaunched;
}

#pragma mark URL query handling

- (NSURLRequest*)createURLRequest:(NSError**)error {
    NSURL *url = [[self class] urlForAction:self error:error];
    
    NSMutableURLRequest *request = nil;
    if (url) {
        request = [NSMutableURLRequest requestWithURL:url
                                          cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                      timeoutInterval:self.timeoutInterval];
        request.HTTPMethod = self.method;
        request.allHTTPHeaderFields = [self headersForAction];
        
        if (_parameters && ![request bindParameters:self.parameters error:error]) {
            request = nil;
        }
    }
    
    return request;
}

@end
