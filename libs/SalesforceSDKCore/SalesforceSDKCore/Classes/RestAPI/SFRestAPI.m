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

#import "SFRestAPI+Internal.h"
#import "SFRestRequest+Internal.h"
#import "SFUserAccount.h"
#import "SFAuthenticationManager.h"
#import "SFSDKWebUtils.h"
#import "SalesforceSDKManager.h"
#import "SFSDKEventBuilderHelper.h"
#import "SFNetwork.h"
#import "SFOAuthSessionRefresher.h"
#import "NSString+SFAdditions.h"
#import "SFJsonUtils.h"

NSString* const kSFRestDefaultAPIVersion = @"v39.0";
NSString* const kSFRestIfUnmodifiedSince = @"If-Unmodified-Since";
NSString* const kSFRestErrorDomain = @"com.salesforce.RestAPI.ErrorDomain";
NSString* const kSFDefaultContentType = @"application/json";
NSInteger const kSFRestErrorCode = 999;

// singleton instance
static SFRestAPI *_instance;
static dispatch_once_t _sharedInstanceGuard;
static BOOL kIsTestRun;

@interface SFRestAPI ()

@property (readwrite, assign) BOOL sessionRefreshInProgress;
@property (readwrite, assign) BOOL pendingRequestsBeingProcessed;
@property (nonatomic, strong) SFOAuthSessionRefresher *oauthSessionRefresher;

@end

@implementation SFRestAPI

@synthesize apiVersion = _apiVersion;
@synthesize activeRequests = _activeRequests;

__strong static NSDateFormatter *httpDateFormatter = nil;

+ (void) initialize {
    if (self == [SFRestAPI class]) {
        httpDateFormatter = [NSDateFormatter new];
        httpDateFormatter.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'";
    }
}

#pragma mark - init/setup

- (id)init {
    self = [super init];
    if (self) {
        _activeRequests = [[NSMutableSet alloc] initWithCapacity:10];
        self.apiVersion = kSFRestDefaultAPIVersion;
        self.sessionRefreshInProgress = NO;
        self.pendingRequestsBeingProcessed = NO;
        [[SFUserAccountManager sharedInstance] addDelegate:self];
        if (!kIsTestRun) {
            [SFSDKWebUtils configureUserAgent:[SFRestAPI userAgentString]];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cleanup) name:kSFUserLogoutNotification object:[SFAuthenticationManager sharedManager]];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSFUserLogoutNotification object:[SFAuthenticationManager sharedManager]];
    SFRelease(_activeRequests);
}

#pragma mark - Cleanup / cancel all

- (void) cleanup {
    [_activeRequests removeAllObjects];
}

- (void)cancelAllRequests {
    @synchronized(self) {
        for (SFRestRequest *request in _activeRequests) {
            [request cancel];
        }
        [_activeRequests removeAllObjects];
    }
}

#pragma mark - singleton

+ (SFRestAPI *)sharedInstance {
    dispatch_once(&_sharedInstanceGuard, 
                  ^{ 
                      _instance = [[SFRestAPI alloc] init];
                  });
    return _instance;
}

+ (void) setIsTestRun:(BOOL)isTestRun {
    kIsTestRun = isTestRun;
}

+ (BOOL) getIsTestRun {
    return kIsTestRun;
}

#pragma mark - Internal

- (void)removeActiveRequestObject:(SFRestRequest *)request {
    if (request != nil) {
        [self.activeRequests removeObject:request];
    }
}

- (BOOL)forceTimeoutRequest:(SFRestRequest*)req {
    BOOL found = NO;
    SFRestRequest *toCancel = (nil != req ? req : [self.activeRequests anyObject]);
    if (nil != toCancel) {
        found = YES;
        [self notifyDelegateOfTimeout:toCancel.delegate request:toCancel];
    }
    return found;
}

#pragma mark - Properties

/**
 Set a user agent string based on the mobile SDK version.
 We are building a user agent of the form:
 SalesforceMobileSDK/1.0 iPhone OS/3.2.0 (iPad) AppName/AppVersion Native uid_<device id> [Current User Agent]
 */
+ (NSString *)userAgentString {
    return [SFRestAPI userAgentString:@""];
}

+ (NSString *)userAgentString:(NSString*)qualifier {
    NSString *returnString = @"";
    if ([SalesforceSDKManager sharedManager].userAgentString != NULL) {
        returnString = [SalesforceSDKManager sharedManager].userAgentString(qualifier);
    }
    return returnString;
}

#pragma mark - SFUserAccountManagerDelegate

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
        willSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser {
    [self cleanup];
}

#pragma mark - send method

- (void)send:(SFRestRequest *)request delegate:(id<SFRestDelegate>)delegate {
    [self send:request delegate:delegate shouldRetry:YES];
}

- (void)send:(SFRestRequest *)request delegate:(id<SFRestDelegate>)delegate shouldRetry:(BOOL)shouldRetry {
    if (nil != delegate) {
        request.delegate = delegate;
    }

    // If there are no demonstrable auth credentials, login before sending.
    SFUserAccount *user = [SFUserAccountManager sharedInstance].currentUser;

    // Adds this request to the list of active requests if it's not already on the list.
    [self.activeRequests addObject:request];
    __weak __typeof(self) weakSelf = self;
    if (user.credentials.accessToken == nil && user.credentials.refreshToken == nil && request.requiresAuthentication) {
        [SFSDKCoreLogger i:[self class] format:@"No auth credentials found. Authenticating before sending request."];
        [[SFAuthenticationManager sharedManager] loginWithCompletion:^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf enqueueRequest:request delegate:delegate shouldRetry:shouldRetry];
            [SFUserAccountManager sharedInstance].currentUser = userAccount;
        } failure:^(SFOAuthInfo *authInfo, NSError *error) {
            [SFSDKCoreLogger e:[self class] format:@"Authentication failed in SFRestAPI: %@. Logging out.", error];
            NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
            attributes[@"errorCode"] = [NSNumber numberWithInteger:error.code];
            attributes[@"errorDescription"] = error.localizedDescription;
            [SFSDKEventBuilderHelper createAndStoreEvent:@"userLogout" userAccount:nil className:NSStringFromClass([self class]) attributes:attributes];
            [[SFAuthenticationManager sharedManager] logout];
        }];
    } else {
        [self enqueueRequest:request delegate:delegate shouldRetry:shouldRetry];
    }
}

- (SFOAuthSessionRefresher *)sessionRefresherForUser:(SFUserAccount *)user {
    @synchronized (self) {

        /*
         * Session refresher should be a class level property because it gets de-allocated before
         * the callback is triggered otherwise, leading to a timeout or cancellation.
         */
        if (!self.oauthSessionRefresher) {
            self.oauthSessionRefresher = [[SFOAuthSessionRefresher alloc] initWithCredentials:user.credentials];
        }
    }
    return self.oauthSessionRefresher;
}

- (void)enqueueRequest:(SFRestRequest *)request delegate:(id<SFRestDelegate>)delegate shouldRetry:(BOOL)shouldRetry {
    __weak __typeof(self) weakSelf = self;
    NSURLRequest *finalRequest = [request prepareRequestForSend];
    if (finalRequest) {
        SFNetwork *network = [[SFNetwork alloc] init];
        NSURLSessionDataTask *dataTask = [network sendRequest:finalRequest dataResponseBlock:^(NSData *data, NSURLResponse *response, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (error) {
                [SFSDKCoreLogger d:[strongSelf class] format:@"REST request failed with error: Error Code: %ld, Description: %@, URL: %@", (long) error.code, error.localizedDescription, finalRequest.URL];

                // Checks if the request was canceled.
                if (error.code == -999) {
                    [strongSelf notifyDelegateOfCancel:delegate request:request];
                } else {
                    [strongSelf notifyDelegateOfFailure:delegate request:request error:error];
                }
                return;
            }
            if (!response) {
                [strongSelf notifyDelegateOfTimeout:delegate request:request];
            }
            [strongSelf replayRequestIfRequired:data response:response error:error request:request delegate:delegate shouldRetry:shouldRetry];
        }];
        request.sessionDataTask = dataTask;
    }
}

- (void)replayRequestIfRequired:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error request:(SFRestRequest *)request delegate:(id<SFRestDelegate>)delegate shouldRetry:(BOOL)shouldRetry {

    // Checks if the access token has expired.
    NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
    if (statusCode == 401 || statusCode == 403) {
        if (shouldRetry) {
            [SFSDKCoreLogger i:[self class] format:@"%@: REST request failed due to expired credentials. Attempting to refresh credentials.", NSStringFromSelector(_cmd)];
            SFUserAccount *user = [SFUserAccountManager sharedInstance].currentUser;

            /*
             * Sends the session refresh request if an OAuth session is not being refreshed.
             * Otherwise, wait for the current session refresh call to complete before sending.
             */
            @synchronized (self) {
                if (!self.sessionRefreshInProgress) {
                    self.sessionRefreshInProgress = YES;
                    SFOAuthSessionRefresher *sessionRefresher = [self sessionRefresherForUser:user];
                    __weak __typeof(self) weakSelf = self;
                    [sessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        [SFSDKCoreLogger i:[strongSelf class] format:@"%@: Credentials refresh successful. Replaying original REST request.", NSStringFromSelector(_cmd)];
                        strongSelf.sessionRefreshInProgress = NO;
                        strongSelf.oauthSessionRefresher = nil;
                        @synchronized (strongSelf) {
                            if (!strongSelf.pendingRequestsBeingProcessed) {
                                strongSelf.pendingRequestsBeingProcessed = YES;
                                [strongSelf sendPendingRequests];
                            }
                        }
                    } error:^(NSError *refreshError) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        [SFSDKCoreLogger e:[strongSelf class] format:@"Failed to refresh expired session. Error: %@", refreshError];
                        [strongSelf notifyDelegateOfFailure:delegate request:request error:refreshError];
                        strongSelf.pendingRequestsBeingProcessed = YES;
                        [strongSelf flushPendingRequestQueue:refreshError];
                        strongSelf.sessionRefreshInProgress = NO;
                        strongSelf.oauthSessionRefresher = nil;
                        if ([refreshError.domain isEqualToString:kSFOAuthErrorDomain] && refreshError.code == kSFOAuthErrorInvalidGrant) {
                            [SFSDKCoreLogger i:[strongSelf class] format:@"%@ Invalid grant error received, triggering logout.", NSStringFromSelector(_cmd)];
    
                            // Make sure we call logout on the main thread.
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [strongSelf createAndStoreLogoutEvent:error user:user];
                                [[SFAuthenticationManager sharedManager] logoutUser:user];
                            });
                        }
                    }];
                }
            }
        } else {
            NSError *retryError = [[NSError alloc] initWithDomain:response.URL.absoluteString code:statusCode userInfo:nil];
            [self notifyDelegateOfFailure:delegate request:request error:retryError];
        }
    } else {

        // 2xx indicates success.
        if (statusCode >= 200 && statusCode <= 299) {
            if (request.parseResponse) {
                NSError *parsingError;
                NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parsingError];
                if (parsingError) {
                    if (data.length == 0) {
                        data = nil;
                    }
                    [self notifyDelegateOfResponse:delegate request:request data:data];
                } else {
                    [self notifyDelegateOfResponse:delegate request:request data:jsonDict];
                }
            } else {
                [self notifyDelegateOfResponse:delegate request:request data:data];
            }
        } else {
            if (!error) {
                NSDictionary *errorDict = nil;
                id errorObj = nil;
                if (data) {
                    NSError *parsingError;
                    errorObj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parsingError];
                    if (!parsingError) {
                        if ([errorObj isKindOfClass:[NSDictionary class]]) {
                            errorDict = errorObj;
                        } else {
                            errorDict = [NSDictionary dictionaryWithObject:errorObj forKey:@"error"];
                        }
                    } else {
                        errorDict = [NSDictionary dictionaryWithObject:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] forKey:@"error"];
                    }
                }
                error = [[NSError alloc] initWithDomain:response.URL.absoluteString code:statusCode userInfo:errorDict];
            }
            [self notifyDelegateOfFailure:delegate request:request error:error];
        }
    }
}

-(void)flushPendingRequestQueue:(NSError *)error {
    @synchronized (self) {
        NSSet *pendingRequests = [self.activeRequests copy];
        for (SFRestRequest *request in pendingRequests) {
            [self notifyDelegateOfFailure:request.delegate request:request error:error];
        }
        self.pendingRequestsBeingProcessed = NO;
    }
}

- (void)sendPendingRequests {
    @synchronized (self) {
        NSSet *pendingRequests = [self.activeRequests copy];
        for (SFRestRequest *request in pendingRequests) {
            [self send:request delegate:request.delegate shouldRetry:NO];
        }
        self.pendingRequestsBeingProcessed = NO;
    }
}

- (void)notifyDelegateOfResponse:(id<SFRestDelegate>)delegate request:(SFRestRequest *)request data:(id)data {
    if ([delegate respondsToSelector:@selector(request:didLoadResponse:)]) {
        [delegate request:request didLoadResponse:data];
    }
    [self removeActiveRequestObject:request];
}

- (void)notifyDelegateOfFailure:(id<SFRestDelegate>)delegate request:(SFRestRequest *)request error:(NSError *)error {
    if ([delegate respondsToSelector:@selector(request:didFailLoadWithError:)]) {
        [delegate request:request didFailLoadWithError:error];
    }
    [self removeActiveRequestObject:request];
}

- (void)notifyDelegateOfCancel:(id<SFRestDelegate>)delegate request:(SFRestRequest *)request {
    if ([delegate respondsToSelector:@selector(requestDidCancelLoad:)]) {
        [delegate requestDidCancelLoad:request];
    }
    [self removeActiveRequestObject:request];
}

- (void)notifyDelegateOfTimeout:(id<SFRestDelegate>)delegate request:(SFRestRequest *)request {
    if ([delegate respondsToSelector:@selector(requestDidTimeout:)]) {
        [delegate requestDidTimeout:request];
    }
    [self removeActiveRequestObject:request];
}

- (void)createAndStoreLogoutEvent:(NSError *)error user:(SFUserAccount*)user {
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    attributes[@"errorCode"] = [NSNumber numberWithInteger:error.code];
    attributes[@"errorDescription"] = error.localizedDescription;
    [SFSDKEventBuilderHelper createAndStoreEvent:@"userLogout" userAccount:user className:NSStringFromClass([self class]) attributes:attributes];
}

# pragma mark - helper method for conditional requests

+ (NSString *)getHttpStringFomFromDate:(NSDate *)date {
    if (date == nil) return nil;
    return [httpDateFormatter stringFromDate:date];
}

#pragma mark - SFRestRequest factory methods

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
                                 @{@"fields": fieldList}
                                 : nil);
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@", self.apiVersion, objectType, objectId];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest *)requestForCreateWithObjectType:(NSString *)objectType
                                           fields:(NSDictionary *)fields {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@", self.apiVersion, objectType];
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:nil];
    return [self addBodyForPostRequest:fields request:request];
}

- (SFRestRequest *)requestForUpdateWithObjectType:(NSString *)objectType
                                         objectId:(NSString *)objectId
                                           fields:(NSDictionary *)fields {
    return [self requestForUpdateWithObjectType:objectType objectId:objectId fields:fields ifUnmodifiedSinceDate:nil];
}

- (SFRestRequest *)requestForUpdateWithObjectType:(NSString *)objectType
                                         objectId:(NSString *)objectId
                                           fields:(NSDictionary *)fields
                            ifUnmodifiedSinceDate:(NSDate *) ifUnmodifiedSinceDate {

    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@", self.apiVersion, objectType, objectId];
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPATCH path:path queryParams:nil];
    request = [self addBodyForPostRequest:fields request:request];
    if (ifUnmodifiedSinceDate) {
        [request setHeaderValue:[SFRestAPI getHttpStringFomFromDate:ifUnmodifiedSinceDate] forHeaderName:kSFRestIfUnmodifiedSince];
    }
    return request;
}

- (SFRestRequest *)requestForUpsertWithObjectType:(NSString *)objectType
                                  externalIdField:(NSString *)externalIdField
                                       externalId:(NSString *)externalId
                                           fields:(NSDictionary *)fields {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@/%@",
                                                self.apiVersion,
                                                objectType,
                                                externalIdField,
                                                externalId == nil ? @"" : externalId];
    SFRestMethod method = externalId == nil ? SFRestMethodPOST : SFRestMethodPATCH;
    SFRestRequest *request = [SFRestRequest requestWithMethod:method path:path queryParams:nil];
    return [self addBodyForPostRequest:fields request:request];
}

- (SFRestRequest *)requestForDeleteWithObjectType:(NSString *)objectType
                                         objectId:(NSString *)objectId {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@", self.apiVersion, objectType, objectId];
    return [SFRestRequest requestWithMethod:SFRestMethodDELETE path:path queryParams:nil];
}

- (SFRestRequest *)requestForQuery:(NSString *)soql {
    NSDictionary *queryParams = nil;
    if (soql) {
        queryParams = @{@"q": soql};
    }
    NSString *path = [NSString stringWithFormat:@"/%@/query", self.apiVersion];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest *)requestForQueryAll:(NSString *)soql {
    NSDictionary *queryParams = nil;
    if (soql) {
        queryParams = @{@"q": soql};
    }
    NSString *path = [NSString stringWithFormat:@"/%@/queryAll", self.apiVersion];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest *)requestForSearch:(NSString *)sosl {
    NSDictionary *queryParams = nil;
    if (sosl) {
        queryParams = @{@"q": sosl};
    }
    NSString *path = [NSString stringWithFormat:@"/%@/search", self.apiVersion];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest *)requestForSearchScopeAndOrder {
    NSString *path = [NSString stringWithFormat:@"/%@/search/scopeOrder", self.apiVersion];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
}

- (SFRestRequest *)requestForSearchResultLayout:(NSString*)objectList {
    NSDictionary *queryParams = @{@"q": objectList};
    NSString *path = [NSString stringWithFormat:@"/%@/search/layout", self.apiVersion];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest *)batchRequest:(NSArray<SFRestRequest*>*) requests haltOnError:(BOOL) haltOnError {
    NSMutableArray *requestsArrayJson = [NSMutableArray new];
    for (SFRestRequest *request in requests) {
        NSMutableDictionary<NSString *, id> *requestJson = [NSMutableDictionary new];
        requestJson[@"method"] = [SFRestRequest httpMethodFromSFRestMethod:request.method];

        // queryParams belong in url
        if (request.method == SFRestMethodGET || request.method == SFRestMethodDELETE) {
            requestJson[@"url"] = [NSString stringWithFormat:@"%@%@", request.path, [self toQueryString:request.queryParams]];
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
    batchRequestJson[@"haltOnError"] = [NSNumber numberWithBool:haltOnError];
    NSString *path = [NSString stringWithFormat:@"/%@/composite/batch", self.apiVersion];
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:nil];
    return [self addBodyForPostRequest:batchRequestJson request:request];
}

- (SFRestRequest *)compositeRequest:(NSArray<SFRestRequest*>*) requests refIds:(NSArray<NSString*>*)refIds allOrNone:(BOOL) allOrNone {
    NSMutableArray *requestsArrayJson = [NSMutableArray new];
    for (int i=0; i<requests.count; i++) {
        SFRestRequest *request = requests[i];
        NSString *refId = refIds[i];
        NSMutableDictionary<NSString *, id> *requestJson = [NSMutableDictionary new];
        requestJson[@"referenceId"] = refId;
        requestJson[@"method"] = [SFRestRequest httpMethodFromSFRestMethod:request.method];

        // queryParams belong in url
        if (request.method == SFRestMethodGET || request.method == SFRestMethodDELETE) {
            requestJson[@"url"] = [NSString stringWithFormat:@"%@%@%@", request.endpoint, request.path, [self toQueryString:request.queryParams]];
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
    compositeRequestJson[@"allOrNone"] = [NSNumber numberWithBool:allOrNone];
    NSString *path = [NSString stringWithFormat:@"/%@/composite", self.apiVersion];
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:nil];
    return [self addBodyForPostRequest:compositeRequestJson request:request];
}

- (SFRestRequest *)requestForSObjectTree:(NSString *)objectType objectTrees:(NSArray<SFSObjectTree*>*)objectTrees {
    NSMutableArray<NSDictionary<NSString *, id> *>* jsonTrees = [NSMutableArray new];
    for (SFSObjectTree * objectTree in objectTrees) {
        [jsonTrees addObject:[objectTree asJSON]];
    }
    NSDictionary<NSString *, id> * requestJson = @{@"records": jsonTrees};
    NSString *path = [NSString stringWithFormat:@"/%@/composite/tree/%@", self.apiVersion, objectType];
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:nil];
    return [self addBodyForPostRequest:requestJson request:request];
}

- (NSString *)toQueryString:(NSDictionary *)components {
    NSMutableString *params = [NSMutableString new];
    if (components) {
        [params appendString:@"?"];
        for (NSString *paramName in [components allKeys]) {
            [params appendString:paramName];
            [params appendString:@"="];
            [params appendString:[components[paramName] stringByURLEncoding]];
        }
    }
    return params;
}

- (SFRestRequest *)addBodyForPostRequest:(NSDictionary *)params request:(SFRestRequest *)request {
    [request setCustomRequestBodyDictionary:params contentType:kSFDefaultContentType];
    return request;
}

+ (BOOL) isStatusCodeSuccess:(NSUInteger) statusCode {
    return statusCode >= 200 && statusCode < 300;
}

+ (BOOL) isStatusCodeNotFound:(NSUInteger) statusCode {
    return statusCode  == 404;
}

@end
