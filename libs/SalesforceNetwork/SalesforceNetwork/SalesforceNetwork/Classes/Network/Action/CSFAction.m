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

CSFActionTiming kCSFActionTimingTotalTimeKey = @"total";
CSFActionTiming kCSFActionTimingNetworkTimeKey = @"network";
CSFActionTiming kCSFActionTimingStartDelayKey = @"startDelay";
CSFActionTiming kCSFActionTimingPostProcessingKey = @"postProcessing";

@interface CSFAction () {
    BOOL _ready;
    BOOL _executing;
    BOOL _finished;
    BOOL _completeCalled;
    
    CSFParameterStorage *_parameters;
    NSMutableDictionary *_HTTPHeaders;
    NSMutableDictionary *_timingValues;
    NSData  *_jsonData;
    BOOL _enqueueIfNoNetwork;
}

@property (nonatomic, strong, readonly) NSMutableDictionary *timingValues;

@end

@implementation CSFAction

+ (NSSet*)keyPathsForValuesAffectingIsDuplicateAction {
    return [NSSet setWithObject:@"duplicateParentAction"];
}

- (NSURL*)urlForActionWithError:(NSError**)error {
    NSURL *baseURL = self.baseURL;
    if (!baseURL) {
        NetworkWarn(@"Network action must have a base URL defined.");

        if (error) {
            *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                         code:CSFNetworkURLCredentialsError
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Network action must have a base URL defined",
                                             CSFNetworkErrorActionKey: self }];
        }
        return nil;
    }
    
    NSMutableString *path = [NSMutableString stringWithFormat:@"%@%@", self.basePath, self.verb];
    
    // Make sure path is not empty
    if (!path || path.length == 0) {
        NetworkWarn(@"Network action must have a valid path.");
        if (error) {
            *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                         code:CSFNetworkURLCredentialsError
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Network action must have a valid path",
                                             CSFNetworkErrorActionKey: self }];
        }
        return nil;
    }
    
    if ([baseURL.absoluteString hasSuffix:@"/"] && [path hasPrefix:@"/"]) {
        [path deleteCharactersInRange:NSMakeRange(0, 1)];
    }
    
    NSURL *url = [NSURL URLWithString:path relativeToURL:baseURL];
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
    NSMutableString *relativePath = [NSMutableString stringWithString:url.path];
    if (url.query != nil) {
        [relativePath appendString:@"?"];
        [relativePath appendString:url.query];
    }
    action.verb = relativePath;
    action.method = method;
    return action;
}

#pragma mark -
#pragma mark object lifecycle

- (instancetype)init {
    self = [super init];
    return self;
}

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

- (void)dealloc {
    if (self.downloadLocation) {
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:self.downloadLocation.path]) {
            NSError *error = nil;
            if (![fm removeItemAtURL:self.downloadLocation error:&error]) {
                NetworkError(@"Error removing temporary download file: %@", error);
            }
        }
    }
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

- (NSMutableDictionary *)timingValues {
    if (!_timingValues) {
        _timingValues = [NSMutableDictionary new];
    }
    return _timingValues;
}

- (NSURL*)url {
    NSError *error = nil;
    NSURL *url = [self urlForActionWithError:&error];
    if (error) {
        NetworkWarn(@"Error composing URL: %@", error);
    }
    return url;
}

- (void)setUrl:(NSURL *)url {
    NSURL *localURL = CSFNotNullURL(url);
    
    // For example, given this URL:
    // /services/data/v24.0/chatter/feeds/news/005300000054oU6AAI/feed-items?page=2012-04-26T04%3A50%3A14Z%2C0D53000000qpC2ZCAU&pageSize=20
    // We decompose in:
    // path -> /services/data/v24.0/chatter/feeds/news/005300000054oU6AAI/feed-items
    // query -> page=2012-04-26T04%3A50%3A14Z%2C0D53000000qpC2ZCAU&pageSize=20
    
    NSString *path = [localURL path];
    NSString *baseUrlString = [url absoluteString];
    NSRange pathRange = [baseUrlString rangeOfString:path];
    if (pathRange.location != NSNotFound && pathRange.location > 0) {
        self.baseURL = [NSURL URLWithString:[baseUrlString substringToIndex:pathRange.location]];
    }

    self.verb = path;
    
    NSString *query = [localURL query];
    for (NSString *param in [query componentsSeparatedByString:@"&"]) {
        NSArray *tuple = [param componentsSeparatedByString:@"="];
        if (tuple.count == 2) {
            self.parameters[tuple[0]] = CSFURLDecode(tuple[1]);
        }
    }
}

- (void)setURL:(NSURL*)url {
    [self setUrl:url];
}

- (void)setBaseURL:(NSURL *)baseURL {
    if (_baseURL != baseURL) {
        // Ensure that the base URL always contains a trailing slash so that relative paths can be handled properly
        if (baseURL && NSMaxRange([baseURL.path rangeOfString:@"/" options:NSBackwardsSearch]) < baseURL.path.length - 1) {
            NSMutableString *urlString = [baseURL.absoluteString mutableCopy];
            [urlString appendString:@"/"];
            _baseURL = [NSURL URLWithString:urlString];
        } else {
            _baseURL = [baseURL copy];
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

- (BOOL)isDuplicateAction {
    return (self.duplicateParentAction != nil);
}

- (BOOL)shouldReportProgressToParent {
    return YES;
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
    return [NSString stringWithFormat:@"<%@: %p, %@ \"%@\" (%.2f)%@>",
            [self class],
            self,
            self.method,
            self.verb,
            [self intervalForTimingKey:kCSFActionTimingTotalTimeKey],
            (self.isProgrammatic ? @" (programmatic)" : @"")];
}

- (NSString*)basePath {
    return @"";
}

- (void)triggerActionAfterTokenRefresh {
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

#pragma mark Implementation override methods

- (NSURLSessionTask*)sessionTaskToProcessRequest:(NSURLRequest*)request session:(NSURLSession*)session {
    return [session dataTaskWithRequest:request];
}

- (void)sessionDownloadTask:(NSURLSessionDownloadTask*)task didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    [self updateProgress];
}

- (void)sessionUploadTask:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    [self updateProgress];
}

- (void)sessionDownloadTask:(NSURLSessionDownloadTask*)task didFinishDownloadingToURL:(NSURL *)location {
    NSURL *temporaryUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]]];
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:temporaryUrl error:&error]) {
        NetworkError(@"Error moving temporary file: %@", error);
        temporaryUrl = location;
    }
    
    self.downloadLocation = location;
    [self updateProgress];
}

- (void)sessionTask:(NSURLSessionTask*)task didCompleteWithError:(NSError*)error {
    if ([self isCancelled]) {
        self.responseData = nil;
        return;
    }
    
    [self updateProgress];

    if (error) {
        NetworkDebug(@"Received an error while processing %@: %@", self, error);

        if ([error.domain isEqualToString:NSURLErrorDomain] &&
            error.code == kCFURLErrorSecureConnectionFailed)
        {
            // Note: It would be possible to further detect the stream error key to identify the exact reason
            //       the handshake failed, but the userInfo key `_kCFStreamErrorCodeKey` isn't exposed as a
            //       public API.  Therefore, we cannot directly compare it to the `errSSLPeerHandshakeFail`
            //       or else we might get flagged as using a private API.  So we'll just use the
            //       `kCFURLErrorSecureConnectionFailed` error code by itself, which may falsely print the
            //       following error for non-ATS SSL errors.
            NetworkError(@"An SSL error occurred while communicating with the server, you may need to review your application's App Transport Security settings");
        }

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
        NetworkWarn(@"Received a non-HTTP response");
        [self completeOperationWithError:[NSError errorWithDomain:CSFNetworkErrorDomain
                                                             code:CSFNetworkURLResponseInvalidError
                                                         userInfo:@{ NSLocalizedDescriptionKey: @"Unexpected URL response type returned.",
                                                                     CSFNetworkErrorActionKey: self }]];
    } else {
        NetworkVerbose(@"Successfully completed request");
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
    [self updateProgress];
}

- (void)updateProgress {
    NSURLSessionTask *task = self.downloadTask ?: self.sessionTask;
    NSProgress *progress = self.progress;
    
    int64_t total = task.countOfBytesExpectedToSend + task.countOfBytesExpectedToReceive;
    if (progress.totalUnitCount != total) {
        progress.totalUnitCount = total;
    }
    
    int64_t current = task.countOfBytesSent + task.countOfBytesReceived;
    if (progress.completedUnitCount != current) {
        progress.completedUnitCount = current;
    }
}

#pragma mark NSOperation implementation

- (void)start {
    self.timingValues[@"startTime"] = [NSDate date];
    
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
    
    if (self.requiresAuthentication) {
        BOOL isTokenBeingRefreshed = NO;
        if ([self.authRefreshClass isSubclassOfClass:[CSFAuthRefresh class]]) {
            isTokenBeingRefreshed = [self.authRefreshClass isRefreshing];
        }
        
        if (isTokenBeingRefreshed) {
            [self triggerActionAfterTokenRefresh];
            return;
        }
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
        CSFNetwork *network = self.enqueuedNetwork;
        NSURLSession *session = network.ephemeralSession;
        #if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
        if ([self requireBackgroundSession]) {
            session = network.backgroundSession;
        }
        #endif
        
        _sessionTask = [self sessionTaskToProcessRequest:request session:session];
        [_sessionTask resume];
        [self updateProgress];
    }
}

- (void)cancel {
    [super cancel];
    NetworkVerbose(@"In-flight action cancelled");
    [self.sessionTask cancel];
    [self.progress cancel];
    [self completeOperationWithError:[NSError errorWithDomain:CSFNetworkErrorDomain
                                                         code:CSFNetworkCancelledError
                                                     userInfo:@{ NSLocalizedDescriptionKey: @"Operation was cancelled",
                                                                 CSFNetworkErrorActionKey: self }]];
}

- (BOOL)isAsynchronous {
    return YES;
}

- (BOOL)isReady {
    BOOL result = [super isReady];
    
    if (result) {
        // we do the following additional checking
        // only if [super isReady] returns true
        if (!self.credentialsReady) {
            result = NO;
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

- (NSData *)outputData {
    return [NSData dataWithData:self.responseData];
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

- (void)setEnqueuedNetwork:(CSFNetwork *)enqueuedNetwork {
    if (_enqueuedNetwork != enqueuedNetwork) {
        _enqueuedNetwork = enqueuedNetwork;
        self.timingValues[@"enqueuedTime"] = [NSDate date];
        
        if (enqueuedNetwork) {
            _progress = [[NSProgress alloc] initWithParent:[NSProgress currentProgress]
                                                  userInfo:@{ NSProgressFileOperationKindKey: NSProgressFileOperationKindReceiving }];
            _progress.totalUnitCount = -1;
            _progress.cancellable = YES;
            _progress.pausable = NO;
        }
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
    if (_completeCalled) {
        return;
    }
    else {
        _completeCalled = YES;
    }

    if (self.isExecuting) {
        [self willChangeValueForKey:@"isExecuting"];
        [self willChangeValueForKey:@"isFinished"];
        _executing = NO;
        _finished = YES;
        [self didChangeValueForKey:@"isExecuting"];
        [self didChangeValueForKey:@"isFinished"];
    }
    
    self.error = error;
    self.responseData = nil;
    self.timingValues[@"endTime"] = [NSDate date];

    if (self.responseBlock) {
        self.responseBlock(self, self.error);
    }
}

- (id)contentFromData:(NSData*)data fromResponse:(NSHTTPURLResponse*)response error:(NSError**)error {
    id content = nil;
    BOOL requestSucceeded = (response.statusCode >= 200 && response.statusCode < 300);

    // try to parse response if response is not an error or response status code is between the specified status code range
    // 2xx is for successful request
    // 4xx is for client error that may contains valuable error information in response
    NSError *jsonParseError = nil;
    if ([self.responseData length] > 0) {
        content = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonParseError];
    }
    
    // Surface error back if we run into JSON parsing error on a successful HTTP response
    if (jsonParseError && error && requestSucceeded) {
        NetworkWarn(@"Error while parsing response; it doesn't appear to be JSON");
        
        *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                     code:CSFNetworkJSONInvalidError
                                 userInfo:@{ NSLocalizedDescriptionKey: @"Processing response content failed",
                                             NSUnderlyingErrorKey: jsonParseError,
                                             CSFNetworkErrorActionKey: self }];
    }
    return content;
}

- (void)completeOperationWithResponse:(NSHTTPURLResponse *)response {
    self.timingValues[@"responseTime"] = [NSDate date];
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
            if ([self.outputContent isKindOfClass:self.modelClass]) {
                self.outputModel = self.outputContent;
            } else {
                NSMutableDictionary *context = [NSMutableDictionary new];
                
                NSURL *serverUrl = network.account.credentials.instanceUrl;
                if (serverUrl) {
                    context[@"serverURL"] = serverUrl;
                }
                self.outputModel = [[(Class)self.modelClass alloc] initWithJSON:self.outputContent context:context];
            }
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
                                NetworkInfo(@"Error caching response in %@: %@", NSStringFromClass(outputCache.class), error);
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
            NetworkWarn(@"authRefreshClass property not set.  Cannot refresh credentials");
            refreshLaunched = NO;
        } else {
            [self triggerActionAfterTokenRefresh];
        }
    } else {
        NetworkWarn(@"Unauthorized response, but requiresAuthentication not set.  Cannot replay original request.");
        refreshLaunched = NO;
    }
    
    return refreshLaunched;
}

#pragma mark URL query handling

- (NSURLRequest*)createURLRequest:(NSError**)error {
    NSURL *url = [self urlForActionWithError:error];
    
    NSMutableURLRequest *request = nil;
    if (url) {
        request = [NSMutableURLRequest requestWithURL:url
                                          cachePolicy:NSURLRequestReloadIgnoringCacheData
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

@implementation CSFAction (Timing)

- (NSTimeInterval)intervalForTimingKey:(CSFActionTiming)key {
    NSTimeInterval result = 0;
    
    NSDate *firstDate = nil, *secondDate = nil;
    if (!key || [key isEqualToString:kCSFActionTimingTotalTimeKey]) {
        firstDate = self.timingValues[@"enqueuedTime"];
        secondDate = self.timingValues[@"endTime"] ?: [NSDate date];
    } else if ([key isEqualToString:kCSFActionTimingNetworkTimeKey]) {
        firstDate = self.timingValues[@"startTime"];
        secondDate = self.timingValues[@"responseTime"] ?: [NSDate date];
    } else if ([key isEqualToString:kCSFActionTimingStartDelayKey]) {
        firstDate = self.timingValues[@"enqueuedTime"];
        secondDate = self.timingValues[@"startTime"] ?: [NSDate date];
    } else if ([key isEqualToString:kCSFActionTimingPostProcessingKey]) {
        firstDate = self.timingValues[@"responseTime"];
        secondDate = self.timingValues[@"endTime"] ?: [NSDate date];
    }
    
    if (firstDate && secondDate) {
        result = secondDate.timeIntervalSinceReferenceDate - firstDate.timeIntervalSinceReferenceDate;
    }
    
    return result;
}

@end
