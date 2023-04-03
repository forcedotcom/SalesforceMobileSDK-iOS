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

#import <SalesforceSDKCommon/SFJsonUtils.h>
#import <SalesforceSDKCommon/SFSDKSafeMutableDictionary.h>
#import "SFSDKOAuth2.h"
#import "SFRestAPI+Internal.h"
#import "SFRestRequest+Internal.h"
#import "SFSDKWebUtils.h"
#import "SalesforceSDKManager.h"
#import "SFSDKEventBuilderHelper.h"
#import "SFNetwork.h"
#import "SFOAuthSessionRefresher.h"
#import "NSString+SFAdditions.h"
#import "SFSDKCompositeRequest.h"
#import "SFSDKBatchRequest.h"
#import "SFFormatUtils.h"

NSString* const kSFRestDefaultAPIVersion = @"v55.0";
NSString* const kSFRestIfUnmodifiedSince = @"If-Unmodified-Since";
NSString* const kSFRestErrorDomain = @"com.salesforce.RestAPI.ErrorDomain";
NSString* const kSFDefaultContentType = @"application/json";
NSInteger const kSFRestErrorCode = 999;
NSInteger const kSFRestSOQLMinBatchSize = 200;
NSInteger const kSFRestSOQLMaxBatchSize = 2000;
NSInteger const kSFRestSOQLDefaultBatchSize = 2000;
NSString* const kSFRestQueryOptions = @"Sforce-Query-Options";
NSInteger const kSFRestCollectionRetrieveMaxSize = 2000;



static BOOL kIsTestRun;
static SFSDKSafeMutableDictionary *sfRestApiList = nil;

@interface SFRestAPI ()

@property (readwrite, assign) BOOL sessionRefreshInProgress;
@property (readwrite, assign) BOOL pendingRequestsBeingProcessed;
@property (nonatomic, strong) SFOAuthSessionRefresher *oauthSessionRefresher;
@property (nonatomic, strong, readwrite) SFUserAccount *user;

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

- (id)initWithUser:(SFUserAccount *)user {
    self = [super init];
    if (self) {
        self.user = user;
        _activeRequests = [SFSDKSafeMutableSet setWithCapacity:10];
        self.apiVersion = kSFRestDefaultAPIVersion;
        self.sessionRefreshInProgress = NO;
        self.pendingRequestsBeingProcessed = NO;
        self.requiresAuthentication = (user != nil && user.credentials.accessToken != nil);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUserDidLogout:)  name:kSFNotificationUserDidLogout object:nil];
    }
    return self;
}

- (void)dealloc {
    SFRelease(_activeRequests);
}

#pragma mark - Cleanup / cancel all

- (void)cleanup {
    [self.activeRequests removeAllObjects];
}

- (void)cancelAllRequests {
    [self.activeRequests enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        SFRestRequest *request = obj;
        [request cancel];
    }];
    [self.activeRequests removeAllObjects];
}

#pragma mark - singleton
static dispatch_once_t pred;

+ (SFRestAPI *)sharedGlobalInstance {
    dispatch_once(&pred, ^{
        sfRestApiList = [[SFSDKSafeMutableDictionary alloc] init];
    });
    @synchronized ([SFRestAPI class]) {
        NSString *key = SFKeyForGlobalScope();
        id sfRestApi = [sfRestApiList objectForKey:key];
        if (!sfRestApi) {
            sfRestApi = [[SFRestAPI alloc] initWithUser:nil];
            [sfRestApiList setObject:sfRestApi forKey:key];
        }
        return sfRestApi;
   }
}

+ (SFRestAPI *)sharedInstance {
    return [SFRestAPI sharedInstanceWithUser:[SFUserAccountManager sharedInstance].currentUser];
}

+ (SFRestAPI *)sharedInstanceWithUser:(SFUserAccount *)user {
    dispatch_once(&pred, ^{
        sfRestApiList = [[SFSDKSafeMutableDictionary alloc] init];
    });
    @synchronized ([SFRestAPI class]) {
        if (!user) {
            user = [SFUserAccountManager sharedInstance].currentUser;
        }
        if (!user) {
            return nil;
        }
        NSString *key = SFKeyForUserAndScope(user, SFUserAccountScopeCommunity);
        if (!key) {
            return nil;
        }
        id sfRestApi = [sfRestApiList objectForKey:key];
        if (!sfRestApi) {
            if (user.loginState != SFUserAccountLoginStateLoggedIn) {
                [SFSDKCoreLogger w:[self class] format:@"%@ A user account must be in the SFUserAccountLoginStateLoggedIn state in order to create a SFRestAPI instance for a user.", NSStringFromSelector(_cmd)];
                return nil;
            }
            sfRestApi = [[SFRestAPI alloc] initWithUser:user];
            [sfRestApiList setObject:sfRestApi forKey:key];
        }
        return sfRestApi;
    }
}

+ (void)removeSharedInstanceWithUser:(SFUserAccount *)user {
    @synchronized ([SFRestAPI class]) {
        if (!user) {
            user = [SFUserAccountManager sharedInstance].currentUser;
        }
        if (!user) {
            return;
        }
        NSString *userKey = SFKeyForUserAndScope(user, SFUserAccountScopeUser);

        // Remove all sub-instances (community users) for this user as well.
        NSArray *keys = sfRestApiList.allKeys;
        if(userKey) {
            for( NSString *key in keys) {
                if([key hasPrefix:userKey]) {
                    [sfRestApiList removeObject:key];
                }
            }
        }
    }
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

- (BOOL)forceTimeoutRequest:(SFRestRequest *)req {
    BOOL found = NO;
    SFRestRequest *toCancel = (nil != req ? req : [self.activeRequests anyObject]);
    if (nil != toCancel) {
        found = YES;
        [self notifyDelegateOfFailure:toCancel.requestDelegate request:toCancel data:nil rawResponse:nil error:nil];
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
    return [SalesforceSDKManager sharedManager].userAgentString(qualifier);
}

#pragma mark - send method

- (void)send:(SFRestRequest *)request requestDelegate:(nullable id<SFRestRequestDelegate>)requestDelegate {
    [self send:request requestDelegate:requestDelegate shouldRetry:self.requiresAuthentication && request.requiresAuthentication];
}

- (void)send:(SFRestRequest *)request requestDelegate:(id<SFRestRequestDelegate>)requestDelegate shouldRetry:(BOOL)shouldRetry {
    if (requestDelegate != nil) {
        request.requestDelegate = requestDelegate;
    }
    if (!self.requiresAuthentication) {
        NSAssert(!request.requiresAuthentication , @"Use SFRestAPI sharedInstance for authenticated requests");
    }

    // Adds this request to the list of active requests if it's not already on the list.
    [self.activeRequests addObject:request];
    __weak __typeof(self) weakSelf = self;
    if (self.user.credentials.accessToken == nil && self.user.credentials.refreshToken == nil && self.requiresAuthentication) {
        [SFSDKCoreLogger i:[self class] format:@"No auth credentials found. Authenticating before sending request: %@", request.description];
        [[SFUserAccountManager sharedInstance] loginWithCompletion:^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            strongSelf.user = userAccount;
            [strongSelf enqueueRequest:request requestDelegate:requestDelegate shouldRetry:shouldRetry];
        } failure:^(SFOAuthInfo *authInfo, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [SFSDKCoreLogger e:[strongSelf class] format:@"Authentication failed in SFRestAPI: %@. Logging out.", error];
            NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
            attributes[@"errorCode"] = [NSNumber numberWithInteger:error.code];
            attributes[@"errorDescription"] = error.localizedDescription;
            [SFSDKEventBuilderHelper createAndStoreEvent:@"userLogout" userAccount:nil className:NSStringFromClass([strongSelf class]) attributes:attributes];
            [[SFUserAccountManager sharedInstance] logout];
        }];
    } else {
        [self enqueueRequest:request requestDelegate:requestDelegate shouldRetry:shouldRetry];
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

- (void)enqueueRequest:(SFRestRequest *)request requestDelegate:(id<SFRestRequestDelegate>)requestDelegate shouldRetry:(BOOL)shouldRetry {
    __weak __typeof(self) weakSelf = self;
    NSURLRequest *finalRequest = [request prepareRequestForSend:self.user];
    if (finalRequest) {
        SFNetwork *network;
        __block NSString *instanceIdentifier;
        if (request.serviceHostType == SFSDKRestServiceHostTypeCustom) {
            instanceIdentifier = [SFNetwork uniqueInstanceIdentifier];
            network = [self networkForRequest:request identifier:instanceIdentifier];
        } else {
            network = [self networkForRequest:request];
        }
        NSURLSessionDataTask *dataTask = [network sendRequest:finalRequest dataResponseBlock:^(NSData *data, NSURLResponse *response, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [SFNetwork removeSharedInstanceForIdentifier:instanceIdentifier];

            // Network error.
            if (error) {
                [SFSDKCoreLogger d:[strongSelf class] format:@"REST request failed with error: Error Code: %ld, Description: %@, URL: %@", (long) error.code, error.localizedDescription, finalRequest.URL];
                id dataForDelegate = [strongSelf prepareDataForDelegate:data request:request response:response];
                [strongSelf notifyDelegateOfFailure:requestDelegate request:request data:dataForDelegate rawResponse:response error:error];
                return;
            }

            // Timeout.
            if (!response) {
                [strongSelf notifyDelegateOfFailure:requestDelegate request:request data:nil rawResponse:nil error:nil];
                return;
            }
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];

            // 2xx indicates success.
            if ([SFRestAPI isStatusCodeSuccess:statusCode]) {
                id dataForDelegate = [strongSelf prepareDataForDelegate:data request:request response:response];
                [strongSelf notifyDelegateOfSuccess:requestDelegate request:request data:dataForDelegate rawResponse:response];
            } else {
                if (shouldRetry && statusCode == 401) {

                    // 401 indicates refresh is required.
                    [strongSelf replayRequest:request response:response requestDelegate:requestDelegate];
                } else {

                    // Other status codes indicate failure.
                    NSError *errorForDelegate = [strongSelf prepareErrorForDelegate:data response:response];
                    id dataForDelegate = [strongSelf prepareDataForDelegate:data request:request response:response];
                    [strongSelf notifyDelegateOfFailure:requestDelegate request:request data:dataForDelegate rawResponse:response error:errorForDelegate];
                }
            }
        }];
        request.sessionDataTask = dataTask;
    }
}

- (SFNetwork *)networkForRequest:(SFRestRequest *)request {
    if (request.networkServiceType == SFNetworkServiceTypeBackground) {
        return [SFNetwork sharedBackgroundInstance];
    } else {
        return [SFNetwork sharedEphemeralInstance];
    }
}

- (SFNetwork *)networkForRequest:(SFRestRequest *)request identifier:(NSString *)identifier {
    if (request.networkServiceType == SFNetworkServiceTypeBackground) {
        return [SFNetwork sharedBackgroundInstanceWithIdentifier:identifier];
    } else {
        return [SFNetwork sharedEphemeralInstanceWithIdentifier:identifier];
    }
}

- (id) prepareDataForDelegate:(NSData *)data request:(SFRestRequest *)request response:(NSURLResponse *)response {

    // No parsing.
    if (!request.parseResponse) {
        return data;
    }

    // Parsing.
    else {
        NSDictionary *jsonDict = [SFJsonUtils objectFromJSONData:data];

        // Parsing succeeded.
        if (jsonDict) {
            return jsonDict;
        }

        // Parsing failed.
        else {
            return data.length == 0 ? nil : data;
        }
    }
}

- (NSError*) prepareErrorForDelegate:(NSData *)data response:(NSURLResponse *)response {
    NSDictionary *errorDict = nil;
    NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];

    // Parse error from data if any.
    if (data) {
        NSObject* errorObj = [SFJsonUtils objectFromJSONData:data];

        // Parsing succeeded.
        if (errorObj) {
            if ([errorObj isKindOfClass:[NSDictionary class]]) {
                errorDict = (NSDictionary*) errorObj;
            } else {
                errorDict = [NSDictionary dictionaryWithObject:errorObj forKey:@"error"];
            }
        }

        // Parsing failed.
        else {
            errorDict = [NSDictionary dictionaryWithObject:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] forKey:@"error"];
        }
    }
    return [[NSError alloc] initWithDomain:kSFRestErrorDomain code:statusCode userInfo:errorDict];
}

- (void)replayRequest:(SFRestRequest *)request response:(NSURLResponse *)response requestDelegate:(id<SFRestRequestDelegate>)requestDelegate {
    [SFSDKCoreLogger i:[self class] format:@"%@: REST request failed due to expired credentials. Attempting to refresh credentials.", NSStringFromSelector(_cmd)];

    /*
     * Sends the session refresh request if an OAuth session is not being refreshed.
     * Otherwise, wait for the current session refresh call to complete before sending.
     */
    @synchronized (self) {
        if (!self.sessionRefreshInProgress) {
            self.sessionRefreshInProgress = YES;
            SFOAuthSessionRefresher *sessionRefresher = [self sessionRefresherForUser:self.user];
            __weak __typeof(self) weakSelf = self;
            [sessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                [SFSDKCoreLogger i:[strongSelf class] format:@"%@: Credentials refresh successful. Replaying original REST request.", NSStringFromSelector(_cmd)];
                strongSelf.sessionRefreshInProgress = NO;
                strongSelf.oauthSessionRefresher = nil;
                @synchronized (strongSelf) {
                    if (!strongSelf.pendingRequestsBeingProcessed) {
                        strongSelf.pendingRequestsBeingProcessed = YES;
                        [strongSelf resendActiveRequestsRequiringAuthentication];
                    }
                }
            } error:^(NSError *refreshError) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                [SFSDKCoreLogger e:[strongSelf class] format:@"Failed to refresh expired session. Error: %@", refreshError];
                [strongSelf notifyDelegateOfFailure:requestDelegate request:request data:nil rawResponse:response error:refreshError];
                strongSelf.pendingRequestsBeingProcessed = YES;
                [strongSelf flushPendingRequestQueue:refreshError rawResponse:response];
                strongSelf.sessionRefreshInProgress = NO;
                strongSelf.oauthSessionRefresher = nil;
                if ([refreshError.domain isEqualToString:kSFOAuthErrorDomain] && refreshError.code == kSFOAuthErrorInvalidGrant) {
                    [SFSDKCoreLogger i:[strongSelf class] format:@"%@ Invalid grant error received, triggering logout.", NSStringFromSelector(_cmd)];

                    // Make sure we call logout on the main thread.
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [strongSelf createAndStoreLogoutEvent:refreshError user:strongSelf.user];
                        [[SFUserAccountManager sharedInstance] logoutUser:strongSelf.user];
                    });
                }
            }];
        }
    }
}

-(void)flushPendingRequestQueue:(NSError *)error rawResponse:(NSURLResponse *)rawResponse {
    @synchronized (self) {
        NSSet *pendingRequests = [self.activeRequests asSet];
        for (SFRestRequest *request in pendingRequests) {
            [self notifyDelegateOfFailure:request.requestDelegate request:request data:nil rawResponse:rawResponse error:error];
        }
        self.pendingRequestsBeingProcessed = NO;
    }
}

- (void)resendActiveRequestsRequiringAuthentication {
    @synchronized (self) {
        NSSet *pendingRequests = [self.activeRequests asSet];
        for (SFRestRequest *request in pendingRequests) {
            [self send:request requestDelegate:request.requestDelegate shouldRetry:NO];
        }
        self.pendingRequestsBeingProcessed = NO;
    }
}

- (void)notifyDelegateOfSuccess:(id<SFRestRequestDelegate>)delegate request:(SFRestRequest *)request data:(id)data rawResponse:(NSURLResponse *)rawResponse {
    if ([delegate respondsToSelector:@selector(request:didSucceed:rawResponse:)]) {
        [delegate request:request didSucceed:data rawResponse:rawResponse];
    }
    [self removeActiveRequestObject:request];
}

- (void)notifyDelegateOfFailure:(id<SFRestRequestDelegate>)delegate request:(SFRestRequest *)request data:(id)data rawResponse:(NSURLResponse *)rawResponse error:(NSError *)error {
    if ([delegate respondsToSelector:@selector(request:didFail:rawResponse:error:)]) {
        [delegate request:request didFail:data rawResponse:rawResponse error:error];
    }
    [self removeActiveRequestObject:request];
}

- (void)createAndStoreLogoutEvent:(NSError *)error user:(SFUserAccount*)user {
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    attributes[@"errorCode"] = [NSNumber numberWithInteger:error.code];
    attributes[@"errorDescription"] = error.localizedDescription;
    [SFSDKEventBuilderHelper createAndStoreEvent:@"userLogout" userAccount:user className:NSStringFromClass([self class]) attributes:attributes];
}

#pragma mark - SFRestRequest factory methods

- (SFRestRequest *)requestForUserInfo {
    NSString *path = @"/services/oauth2/userinfo";
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodGET serviceHostType:SFSDKRestServiceHostTypeLogin path:path queryParams:nil];
    request.endpoint = @"";
    return request;
}

- (SFRestRequest *)requestForVersions {
    NSString *path = @"/";
    SFRestRequest* request = [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
    request.requiresAuthentication = NO;
    return request;
}

- (SFRestRequest *)requestForResources:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@", [self computeAPIVersion:apiVersion]];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
}

- (SFRestRequest *)requestForDescribeGlobal:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects", [self computeAPIVersion:apiVersion]];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
}

- (SFRestRequest *)requestForMetadataWithObjectType:(NSString *)objectType apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@", [self computeAPIVersion:apiVersion], objectType];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
}

- (SFRestRequest *)requestForDescribeWithObjectType:(NSString *)objectType apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/describe", [self computeAPIVersion:apiVersion], objectType];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
}

- (SFRestRequest *)requestForLayoutWithObjectType:(NSString *)objectType layoutType:(NSString *)layoutType apiVersion:(NSString *)apiVersion {
    return [self requestForLayoutWithObjectAPIName:objectType formFactor:nil layoutType:layoutType mode:nil recordTypeId:nil apiVersion:apiVersion];
}

- (SFRestRequest *)requestForLayoutWithObjectAPIName:(NSString *)objectAPIName formFactor:(NSString *)formFactor layoutType:(NSString *)layoutType mode:(NSString *)mode recordTypeId:(NSString *)recordTypeId apiVersion:(NSString *)apiVersion {
    NSMutableDictionary *queryParams = [[NSMutableDictionary alloc] init];
    if (formFactor) {
        queryParams[@"formFactor"] = formFactor;
    }
    if (layoutType) {
        queryParams[@"layoutType"] = layoutType;
    }
    if (mode) {
        queryParams[@"mode"] = mode;
    }
    if (recordTypeId) {
        queryParams[@"recordTypeId"] = recordTypeId;
    }
    NSString *path = [NSString stringWithFormat:@"/%@/ui-api/layout/%@", [self computeAPIVersion:apiVersion], objectAPIName];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest *)requestForRetrieveWithObjectType:(NSString *)objectType
                                           objectId:(NSString *)objectId
                                          fieldList:(NSString *)fieldList
                                         apiVersion:(NSString *)apiVersion {
    NSDictionary *queryParams = (fieldList ?
                                 @{@"fields": fieldList}
                                 : nil);
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@", [self computeAPIVersion:apiVersion], objectType, objectId];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest *)requestForCreateWithObjectType:(NSString *)objectType
                                           fields:(NSDictionary *)fields
                                       apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@", [self computeAPIVersion:apiVersion], objectType];
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:nil];
    return [self addBodyForPostRequest:fields request:request];
}

- (SFRestRequest *)requestForUpdateWithObjectType:(NSString *)objectType
                                         objectId:(NSString *)objectId
                                           fields:(NSDictionary *)fields
                                       apiVersion:(NSString *)apiVersion {
    return [self requestForUpdateWithObjectType:objectType objectId:objectId fields:fields ifUnmodifiedSinceDate:nil apiVersion:[self computeAPIVersion:apiVersion]];
}

- (SFRestRequest *)requestForUpdateWithObjectType:(NSString *)objectType
                                         objectId:(NSString *)objectId
                                           fields:(NSDictionary *)fields
                            ifUnmodifiedSinceDate:(NSDate *)ifUnmodifiedSinceDate
                                       apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@", [self computeAPIVersion:apiVersion], objectType, objectId];
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
                                           fields:(NSDictionary *)fields
                                       apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@/%@",
                      [self computeAPIVersion:apiVersion],
                      objectType,
                      externalIdField,
                      externalId == nil ? @"" : externalId];
    SFRestMethod method = externalId == nil ? SFRestMethodPOST : SFRestMethodPATCH;
    SFRestRequest *request = [SFRestRequest requestWithMethod:method path:path queryParams:nil];
    return [self addBodyForPostRequest:fields request:request];
}

- (SFRestRequest *)requestForDeleteWithObjectType:(NSString *)objectType
                                         objectId:(NSString *)objectId
                                       apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@", [self computeAPIVersion:apiVersion], objectType, objectId];
    return [SFRestRequest requestWithMethod:SFRestMethodDELETE path:path queryParams:nil];
}

- (SFRestRequest *)requestForQuery:(NSString *)soql apiVersion:(NSString *)apiVersion {
    NSDictionary *queryParams = nil;
    if (soql) {
        queryParams = @{@"q": soql};
    }
    NSString *path = [NSString stringWithFormat:@"/%@/query", [self computeAPIVersion:apiVersion]];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest *)requestForQuery:(NSString *)soql apiVersion:(NSString *)apiVersion batchSize:(NSInteger)batchSize {
    SFRestRequest* request = [self requestForQuery:soql apiVersion:apiVersion];
    NSUInteger validatedBatchSize = MAX(MIN(batchSize, kSFRestSOQLMaxBatchSize), kSFRestSOQLMinBatchSize);
    if (batchSize != kSFRestSOQLDefaultBatchSize) {
        [request setHeaderValue:[NSString stringWithFormat:@"batchSize=%lu", validatedBatchSize] forHeaderName:kSFRestQueryOptions];
    }
    return request;
}

- (SFRestRequest *)requestForQueryAll:(NSString *)soql apiVersion:(NSString *)apiVersion {
    NSDictionary *queryParams = nil;
    if (soql) {
        queryParams = @{@"q": soql};
    }
    NSString *path = [NSString stringWithFormat:@"/%@/queryAll", [self computeAPIVersion:apiVersion]];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest *)requestForSearch:(NSString *)sosl apiVersion:(NSString *)apiVersion {
    NSDictionary *queryParams = nil;
    if (sosl) {
        queryParams = @{@"q": sosl};
    }
    NSString *path = [NSString stringWithFormat:@"/%@/search", [self computeAPIVersion:apiVersion]];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest *)requestForSearchScopeAndOrder:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/search/scopeOrder", [self computeAPIVersion:apiVersion]];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
}

- (SFRestRequest *)requestForSearchResultLayout:(NSString *)objectList apiVersion:(NSString *)apiVersion {
    NSDictionary *queryParams = @{@"q": objectList};
    NSString *path = [NSString stringWithFormat:@"/%@/search/layout", [self computeAPIVersion:apiVersion]];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest *)batchRequest:(NSArray<SFRestRequest *> *)requests haltOnError:(BOOL)haltOnError apiVersion:(NSString *)apiVersion {
    SFSDKBatchRequestBuilder *builder = [[SFSDKBatchRequestBuilder alloc] init];
    for (int i = 0; i < requests.count; i++) {
        [builder addRequest:requests[i]];
    }
    [builder setHaltOnError:haltOnError];
    return [builder buildBatchRequest:[self computeAPIVersion:apiVersion]];
}

- (SFRestRequest *)compositeRequest:(NSArray<SFRestRequest*>*)requests refIds:(NSArray<NSString*>*)refIds allOrNone:(BOOL)allOrNone apiVersion:(NSString *)apiVersion {
    SFSDKCompositeRequestBuilder *builder = [[SFSDKCompositeRequestBuilder alloc] init];
    for (int i = 0; i < requests.count; i++) {
        [builder addRequest:requests[i] referenceId:refIds[i]];
    }
    [builder setAllOrNone:allOrNone];
    return [builder buildCompositeRequest:[self computeAPIVersion:apiVersion]];
}

- (SFRestRequest *)requestForSObjectTree:(NSString *)objectType objectTrees:(NSArray<SFSObjectTree *> *)objectTrees apiVersion:(NSString *)apiVersion {
    NSMutableArray<NSDictionary<NSString *, id> *>* jsonTrees = [NSMutableArray new];
    for (SFSObjectTree * objectTree in objectTrees) {
        [jsonTrees addObject:[objectTree asJSON]];
    }
    NSDictionary<NSString *, id> * requestJson = @{@"records": jsonTrees};
    NSString *path = [NSString stringWithFormat:@"/%@/composite/tree/%@", [self computeAPIVersion:apiVersion], objectType];
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:nil];
    return [self addBodyForPostRequest:requestJson request:request];
}

- (SFRestRequest*) requestForPrimingRecords:(nullable NSString *)relayToken changedAfterTimestamp:(nullable NSNumber *)timestamp apiVersion:(nullable NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/connect/briefcase/priming-records", [self computeAPIVersion:apiVersion]];
    
    NSDictionary *queryParams = nil;
    if (relayToken != nil) {
        queryParams = @{@"relayToken": relayToken};
    }
    if (timestamp) {
        NSString *isoTimestamp = [SFFormatUtils getIsoStringFromMillis:timestamp.longLongValue];
        if (isoTimestamp) {
            queryParams = @{@"changedAfterTimestamp": isoTimestamp};
        }
    }

    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest*) requestForCollectionCreate:(BOOL)allOrNone records:(NSArray<NSDictionary*>*)records apiVersion:(nullable NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/composite/sobjects", [self computeAPIVersion:apiVersion]];
    NSDictionary* requestJson = @{@"allOrNone": [NSNumber numberWithBool:allOrNone], @"records": records};
    SFRestRequest* request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:nil];
    return [self addBodyForPostRequest:requestJson request:request];
}

- (SFRestRequest*) requestForCollectionRetrieve:(NSString*)objectType objectIds:(NSArray<NSString*>*)objectIds fieldList:(NSArray<NSString*>*)fieldList apiVersion:(nullable NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/composite/sobjects/%@", [self computeAPIVersion:apiVersion], objectType];
    NSDictionary* requestJson = @{@"ids": objectIds, @"fields": fieldList};
    SFRestRequest* request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:nil];
    return [self addBodyForPostRequest:requestJson request:request];

}

- (SFRestRequest*) requestForCollectionUpdate:(BOOL)allOrNone records:(NSArray<NSDictionary*>*)records apiVersion:(nullable NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/composite/sobjects", [self computeAPIVersion:apiVersion]];
    NSDictionary* requestJson = @{@"allOrNone": [NSNumber numberWithBool:allOrNone], @"records": records};
    SFRestRequest* request = [SFRestRequest requestWithMethod:SFRestMethodPATCH path:path queryParams:nil];
    return [self addBodyForPostRequest:requestJson request:request];

}

- (SFRestRequest*) requestForCollectionUpsert:(BOOL)allOrNone objectType:(NSString*)objectType externalIdField:(NSString*)externalIdField records:(NSArray<NSDictionary*>*)records apiVersion:(nullable NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/composite/sobjects/%@/%@", [self computeAPIVersion:apiVersion], objectType, externalIdField];
    NSDictionary* requestJson = @{@"allOrNone": [NSNumber numberWithBool:allOrNone], @"records": records};
    SFRestRequest* request = [SFRestRequest requestWithMethod:SFRestMethodPATCH path:path queryParams:nil];
    return [self addBodyForPostRequest:requestJson request:request];
}

- (SFRestRequest*) requestForCollectionDelete:(BOOL)allOrNone objectIds:(NSArray<NSString*>*)objectIds apiVersion:(nullable NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/composite/sobjects", [self computeAPIVersion:apiVersion]];
    NSDictionary* queryParams = @{@"allOrNone": allOrNone ? @"true" : @"false",
                                  @"ids": [objectIds componentsJoinedByString:@","]};
    return [SFRestRequest requestWithMethod:SFRestMethodDELETE path:path queryParams:queryParams];
}


# pragma mark - Helper methods

- (NSString *)toQueryString:(NSDictionary *)components {
    NSMutableString *params = [NSMutableString new];
    if (components) {
        NSMutableArray *parts = [NSMutableArray array];
        [params appendString:@"?"];
        for (NSString *paramName in [components allKeys]) {
          NSString* paramValue = components[paramName];
          NSString *part = [NSString stringWithFormat:@"%@=%@", [paramName stringByURLEncoding], [paramValue stringByURLEncoding]];
          [parts addObject:part];
        }
        [params appendString:[parts componentsJoinedByString:@"&"]];
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

+ (NSString *)getHttpStringFomFromDate:(NSDate *)date {
    if (date == nil) return nil;
    return [httpDateFormatter stringFromDate:date];
}

#pragma mark - SFUserAccountManagerDelegate
- (void)handleUserDidLogout:(NSNotification *)notification {
    SFUserAccount *user = notification.userInfo[kSFNotificationUserInfoAccountKey];
    [self handleLogoutForUser:user];
}

- (void)handleLogoutForUser:(SFUserAccount *)user {
    NSString *key = SFKeyForUserAndScope(user, SFUserAccountScopeCommunity);
    id sfRestApi = [sfRestApiList objectForKey:key];
    if (sfRestApi) {
        [sfRestApi cleanup];
    }
    [[self class] removeSharedInstanceWithUser:user];
}

- (NSString *)computeAPIVersion:(NSString *)apiVersion {
    return (apiVersion != nil ? apiVersion : self.apiVersion);
}

@end
