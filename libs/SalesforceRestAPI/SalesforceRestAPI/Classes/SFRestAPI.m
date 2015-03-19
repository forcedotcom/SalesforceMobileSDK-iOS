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

#import "SFRestAPI+Internal.h"
#import <SalesforceSDKCore/SalesforceSDKConstants.h>
#import <SalesforceOAuth/SFOAuthCoordinator.h>
#import "SFSessionRefresher.h"
#import <SalesforceSDKCore/SFUserAccount.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFSDKWebUtils.h>
#import <SalesforceSDKCore/SalesforceSDKManager.h>

NSString* const kSFRestDefaultAPIVersion = @"v33.0";
NSString* const kSFRestErrorDomain = @"com.salesforce.RestAPI.ErrorDomain";
NSInteger const kSFRestErrorCode = 999;


// singleton instance
static SFRestAPI *_instance;
static dispatch_once_t _sharedInstanceGuard;
static BOOL kIsTestRun;

@implementation SFRestAPI

@synthesize apiVersion=_apiVersion;
@synthesize activeRequests=_activeRequests;
@synthesize sessionRefresher = _sessionRefresher;
@synthesize networkCoordinatorNeedsRefresh = _networkCoordinatorNeedsRefresh;

#pragma mark - init/setup

- (id)init {
    self = [super init];
    if (self) {
        _activeRequests = [[NSMutableSet alloc] initWithCapacity:4];
        _sessionRefresher = [[SFSessionRefresher alloc] init];
        self.apiVersion = kSFRestDefaultAPIVersion;
        _accountMgr = [SFUserAccountManager sharedInstance];
        [_accountMgr addDelegate:self];
        _authMgr = [SFAuthenticationManager sharedManager];
        _networkEngine = [SFNetworkEngine sharedInstance];
        _networkEngine.delegate = self;
        [[SFAuthenticationManager sharedManager] addDelegate:self];
        [self setupNetworkCoordinator];
        if (!kIsTestRun) {
            [SFSDKWebUtils configureUserAgent:[SFRestAPI userAgentString]];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cleanup) name:kSFUserLogoutNotification object:[SFAuthenticationManager sharedManager]];
    }
    return self;
}

- (void)dealloc {
    [[SFAuthenticationManager sharedManager] removeDelegate:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSFUserLogoutNotification object:[SFAuthenticationManager sharedManager]];
    SFRelease(_sessionRefresher);
    SFRelease(_activeRequests);
}

#pragma mark - Cleanup / cancel all

- (void) cleanup {
    [_activeRequests removeAllObjects];
    self.networkCoordinatorNeedsRefresh = YES;
    [[SFNetworkEngine sharedInstance] cleanup];
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
        [toCancel networkOperationDidTimeout:nil];
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
    [self setupNetworkCoordinator];
}

/**
 Set a user agent string based on the mobile SDK version.
 We are building a user agent of the form:
 SalesforceMobileSDK/1.0 iPhone OS/3.2.0 (iPad) AppName/AppVersion Native [Current User Agent]
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

#pragma mark - SFNetworkEngine Delegate

- (void) setupNetworkCoordinator {
    if (_authMgr.coordinator != nil) {
        _networkEngine.coordinator = [self createNetworkCoordinator:_authMgr.coordinator];
    }
    self.networkCoordinatorNeedsRefresh = NO;
}

- (SFNetworkCoordinator *)createNetworkCoordinator:(SFOAuthCoordinator *)oAuthCoordinator {
    SFNetworkCoordinator *networkCoordinator = [[SFNetworkCoordinator alloc] init];
    networkCoordinator.host = [oAuthCoordinator.credentials.apiUrl host];
    networkCoordinator.organizationId = oAuthCoordinator.credentials.organizationId;
    networkCoordinator.userId = oAuthCoordinator.credentials.userId;
    networkCoordinator.accessToken = oAuthCoordinator.credentials.accessToken;
    networkCoordinator.portNumber = [oAuthCoordinator.credentials.instanceUrl port];
    networkCoordinator.apiUrl = oAuthCoordinator.credentials.apiUrl.absoluteString;
    return networkCoordinator;
}

- (void)refreshSessionForNetworkEngine:(SFNetworkEngine *)networkEngine {
    [_sessionRefresher refreshAccessToken];
}

#pragma mark - SFUserAccountManagerDelegate

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
        willSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser {
    [self cleanup];
}

#pragma mark - SFAuthenticationManagerDelegate

- (void)authManagerDidAuthenticate:(SFAuthenticationManager *)manager credentials:(SFOAuthCredentials *)credentials authInfo:(SFOAuthInfo *)info {
    self.networkCoordinatorNeedsRefresh = YES;
}

#pragma mark - send method


- (SFNetworkOperation*)send:(SFRestRequest *)request delegate:(id<SFRestDelegate>)delegate {
    
    if (nil != delegate) {
        request.delegate = delegate;
    }
    
    if (self.networkCoordinatorNeedsRefresh) {
        [self setupNetworkCoordinator];
    }
    
    [self.activeRequests addObject:request];

    SFNetworkOperation* networkOperation = nil;
    // If there are no demonstrable auth credentials, login before sending.
    SFUserAccount *user = _accountMgr.currentUser;
    if (user.credentials.accessToken == nil && user.credentials.refreshToken == nil) {
        [self log:SFLogLevelInfo msg:@"No auth credentials found.  Authenticating before sending request."];
        [[SFAuthenticationManager sharedManager] loginWithCompletion:^(SFOAuthInfo *authInfo) {
            [self setupNetworkCoordinator];
            [request send:_networkEngine];
        } failure:^(SFOAuthInfo *authInfo, NSError *error) {
            [self log:SFLogLevelError format:@"Authentication failed in SFRestAPI: %@.  Logging out.", error];
            [[SFAuthenticationManager sharedManager] logout];
        }];
    } else {
        // Auth credentials exist.  Just send the request.
        networkOperation = [request send:_networkEngine];
    }
    return networkOperation;
}

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
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@", self.apiVersion, objectType, objectId];
    return [SFRestRequest requestWithMethod:SFRestMethodPATCH path:path queryParams:fields];
}

- (SFRestRequest *)requestForUpsertWithObjectType:(NSString *)objectType
                                  externalIdField:(NSString *)externalIdField
                                       externalId:(NSString *)externalId
                                           fields:(NSDictionary *)fields {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@/%@", self.apiVersion, objectType, externalIdField, externalId];
    return [SFRestRequest requestWithMethod:SFRestMethodPATCH path:path queryParams:fields];
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
    NSDictionary *queryParams = @{@"q": soql};
    NSString *path = [NSString stringWithFormat:@"/%@/queryAll", self.apiVersion];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest *)requestForSearch:(NSString *)sosl {
    NSDictionary *queryParams = @{@"q": sosl};
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

@end
