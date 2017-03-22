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
#import "SFRestAPISalesforceAction.h"
#import "SFSDKWebUtils.h"
#import "SalesforceSDKManager.h"
#import "SFSDKEventBuilderHelper.h"
#import "SalesforceSDKCore.h"

NSString* const kSFRestDefaultAPIVersion = @"v39.0";
NSString* const kSFRestIfUnmodifiedSince = @"If-Unmodified-Since";
NSString* const kSFRestErrorDomain = @"com.salesforce.RestAPI.ErrorDomain";
NSInteger const kSFRestErrorCode = 999;


// singleton instance
static SFRestAPI *_instance;
static dispatch_once_t _sharedInstanceGuard;
static BOOL kIsTestRun;

@implementation SFRestAPI

@synthesize apiVersion=_apiVersion;
@synthesize activeRequests=_activeRequests;
@synthesize currentNetwork=_currentNetwork;

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
        _activeRequests = [[NSMutableSet alloc] initWithCapacity:4];
        self.apiVersion = kSFRestDefaultAPIVersion;
        _accountMgr = [SFUserAccountManager sharedInstance];
        [_accountMgr addDelegate:self];
        _authMgr = [SFAuthenticationManager sharedManager];
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
    [self.activeRequests removeObject:request]; //this will typically release the request
}

- (BOOL)forceTimeoutRequest:(SFRestRequest*)req {
    BOOL found = NO;
    SFRestRequest *toCancel = (nil != req ? req : [self.activeRequests anyObject]);
    
    if (nil != toCancel) {
        found = YES;
        if ([toCancel.delegate respondsToSelector:@selector(requestDidTimeout:)]) {
            [toCancel.delegate requestDidTimeout:toCancel];
            [self removeActiveRequestObject:toCancel];
        }
    }
    
    return found;
}

#pragma mark - Properties

- (SFOAuthCoordinator *)coordinator
{
    return _authMgr.coordinator;
}

- (void)setCoordinator:(SFOAuthCoordinator *)coordinator
{
    _authMgr.coordinator = coordinator;
}

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

- (CSFNetwork *)currentNetwork {
    return [CSFNetwork currentNetwork];
}

#pragma mark - SFUserAccountManagerDelegate

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
        willSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser {
    [self cleanup];
}

#pragma mark - send method


- (SFRestAPISalesforceAction *)send:(SFRestRequest *)request delegate:(id<SFRestDelegate>)delegate {
    
    if (nil != delegate) {
        request.delegate = delegate;
    }
    
    [self.activeRequests addObject:request];

    // If there are no demonstrable auth credentials, login before sending.
    CSFNetwork *currentNetwork = self.currentNetwork;
    SFUserAccount *user = currentNetwork.account;
    if (user.credentials.accessToken == nil && user.credentials.refreshToken == nil && request.requiresAuthentication) {
        [self log:SFLogLevelInfo msg:@"No auth credentials found.  Authenticating before sending request."];
        [[SFAuthenticationManager sharedManager] loginWithCompletion:^(SFOAuthInfo *authInfo) {
            [request prepareRequestForSend];
            [currentNetwork executeAction:request.action];
        } failure:^(SFOAuthInfo *authInfo, NSError *error) {
            [self log:SFLogLevelError format:@"Authentication failed in SFRestAPI: %@.  Logging out.", error];
            NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
            attributes[@"errorCode"] = [NSNumber numberWithInteger:error.code];
            attributes[@"errorDescription"] = error.localizedDescription;
            [SFSDKEventBuilderHelper createAndStoreEvent:@"userLogout" userAccount:nil className:NSStringFromClass([self class]) attributes:attributes];
            [[SFAuthenticationManager sharedManager] logout];
        }];
    } else {
        // Auth credentials exist.  Just send the request.
        [request prepareRequestForSend];
        [currentNetwork executeAction:request.action];
    }
    return request.action;
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
    return [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:fields];
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
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPATCH path:path queryParams:fields];
    if (ifUnmodifiedSinceDate) [request setHeaderValue:[SFRestAPI getHttpStringFomFromDate:ifUnmodifiedSinceDate] forHeaderName:kSFRestIfUnmodifiedSince];
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
    return [SFRestRequest requestWithMethod:method
                                       path:path
                                queryParams:fields];
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

- (SFRestRequest *) batchRequest:(NSArray<SFRestRequest*>*) requests haltOnError:(BOOL) haltOnError {
    NSMutableArray *requestsArrayJson = [NSMutableArray new];
    for (SFRestRequest *request in requests) {
        NSMutableDictionary<NSString *, id> *requestJson = [NSMutableDictionary new];
        requestJson[@"method"] = [SFRestRequest httpMethodFromSFRestMethod:request.method];
        // queryParams belong in url
        if (request.method == SFRestMethodGET || request.method == SFRestMethodDELETE) {
            // Note: It would be better to build the correct path in the first place (like we do on android)
            NSMutableString* params = [NSMutableString new];
            if (request.queryParams) {
                [params appendString:@"?"];
                for (NSString *paramName in [request.queryParams allKeys]) {
                    [params appendString:paramName];
                    [params appendString:@"="];
                    [params appendString:[request.queryParams[paramName] stringByURLEncoding]];
                }
            }
            requestJson[@"url"] = [request.path stringByAppendingString:params];
        }
        // queryParams belongs in body
        else {
            requestJson[@"url"] = request.path;
            requestJson[@"richInput"] = request.queryParams;
        }
        [requestsArrayJson addObject:requestJson];
    }
    NSMutableDictionary<NSString *, id> *batchRequestJson = [NSMutableDictionary new];
    batchRequestJson[@"batchRequests"] = requestsArrayJson;
    batchRequestJson[@"haltOnError"] = [NSNumber numberWithBool:haltOnError];

    NSString *path = [NSString stringWithFormat:@"/%@/composite/batch", self.apiVersion];

    return [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:batchRequestJson];
}

@end
