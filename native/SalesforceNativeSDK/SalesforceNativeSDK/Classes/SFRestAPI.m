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
#import "SalesforceSDKConstants.h"
#import "SFOAuthCoordinator.h"
#import "SFSessionRefresher.h"
#import "SFAccountManager.h"
#import "SFAuthenticationManager.h"
#import "SFSDKWebUtils.h"
#import "SFNetworkEngine.h"

NSString* const kSFRestDefaultAPIVersion = @"v28.0";
NSString* const kSFRestErrorDomain = @"com.salesforce.RestAPI.ErrorDomain";
NSInteger const kSFRestErrorCode = 999;
NSString * const kSFMobileSDKNativeDesignator = @"Native";


// singleton instance
static SFRestAPI *_instance;
static dispatch_once_t _sharedInstanceGuard;

@implementation SFRestAPI

@synthesize apiVersion=_apiVersion;
@synthesize sessionRefresher = _sessionRefresher;

#pragma mark - init/setup

- (id)init {
    self = [super init];
    if (self) {
        self.apiVersion = kSFRestDefaultAPIVersion;
        _sessionRefresher = [[SFSessionRefresher alloc] init];
        _accountMgr = [SFAccountManager sharedInstance];
        _networkEngine = [SFNetworkEngine sharedInstance];
        _networkEngine.delegate = self;
        [SFSDKWebUtils configureUserAgent:[SFRestAPI userAgentString]];
    }
    return self;
}

- (void)dealloc {
    SFRelease(_sessionRefresher);
}

#pragma mark - singleton


+ (SFRestAPI *)sharedInstance {
    dispatch_once(&_sharedInstanceGuard, 
                  ^{ 
                      _instance = [[SFRestAPI alloc] init];
                  });
    return _instance;
}

#pragma mark - Properties

- (SFOAuthCoordinator *)coordinator
{
    return _accountMgr.coordinator;
}

- (void)setCoordinator:(SFOAuthCoordinator *)coordinator
{
    _accountMgr.coordinator = coordinator;
    _networkEngine.coordinator = [self createNetworkCoordinator:coordinator];
}

/**
 Set a user agent string based on the mobile SDK version.
 We are building a user agent of the form:
 SalesforceMobileSDK/1.0 iPhone OS/3.2.0 (iPad) AppName/AppVersion Native [Current User Agent]
 */
+ (NSString *)userAgentString {
    
    // Get the current user agent.  Yes, this is hack-ish.  Alternatives are more hackish.  UIWebView
    // really doesn't want you to know about its HTTP headers.
    NSString *currentUserAgent = [SFSDKWebUtils currentUserAgentForApp];
    
    UIDevice *curDevice = [UIDevice currentDevice];
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];

    NSString *myUserAgent = [NSString stringWithFormat:
                             @"SalesforceMobileSDK/%@ %@/%@ (%@) %@/%@ %@ %@",
                             SALESFORCE_SDK_VERSION,
                             [curDevice systemName],
                             [curDevice systemVersion],
                             [curDevice model],
                             appName,
                             appVersion,
                             kSFMobileSDKNativeDesignator,
                             currentUserAgent
                             ];
    
    return myUserAgent;
}

#pragma mark - SFNetworkEngine Delegate

- (SFNetworkCoordinator *)createNetworkCoordinator:(SFOAuthCoordinator *)oAuthCoordinator {
    SFNetworkCoordinator *networkCoordinator = [[SFNetworkCoordinator alloc] init];
    networkCoordinator.host = [oAuthCoordinator.credentials.instanceUrl host];
    networkCoordinator.organizationId = oAuthCoordinator.credentials.organizationId;
    networkCoordinator.userId = oAuthCoordinator.credentials.userId;
    networkCoordinator.accessToken = oAuthCoordinator.credentials.accessToken;
    NSNumber *port = [oAuthCoordinator.credentials.instanceUrl port];
    return networkCoordinator;
}


- (void)refreshSessionForNetworkEngine:(SFNetworkEngine *)networkEngine {
    [_sessionRefresher refreshAccessToken];
}

#pragma mark - send method


- (void)send:(SFNetworkOperation *)request delegate:(id<SFNetworkOperationDelegate>)delegate {
    [request setDelegate:delegate];
    [[self networkEngine] enqueueOperation:request];
}

#pragma mark - factory method for sobject rest apis

- (SFNetworkOperation *)requestForVersions {
    NSString *path = @"/";
    return [[self networkEngine] get:path params:nil];
}

- (SFNetworkOperation *)requestForResources {
    NSString *path = [NSString stringWithFormat:@"/%@", self.apiVersion];
    return [[self networkEngine] get:path params:nil];
}

- (SFNetworkOperation *)requestForDescribeGlobal {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects", self.apiVersion];
    return [[self networkEngine] get:path params:nil];
}

- (SFNetworkOperation *)requestForMetadataWithObjectType:(NSString *)objectType {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@", self.apiVersion, objectType];
    return [[self networkEngine] get:path params:nil];
}

- (SFNetworkOperation *)requestForDescribeWithObjectType:(NSString *)objectType {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/describe", self.apiVersion, objectType];
    return [[self networkEngine] get:path params:nil];
}

- (SFNetworkOperation *)requestForRetrieveWithObjectType:(NSString *)objectType
                                           objectId:(NSString *)objectId 
                                          fieldList:(NSString *)fieldList {
    NSDictionary *queryParams = (fieldList ?
                                 [NSDictionary dictionaryWithObjectsAndKeys:fieldList, @"fields", nil] 
                                 : nil);
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@", self.apiVersion, objectType, objectId];
    return [[self networkEngine] get:path params:queryParams];
}

- (SFNetworkOperation *)requestForCreateWithObjectType:(NSString *)objectType
                                           fields:(NSDictionary *)fields {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@", self.apiVersion, objectType];
    return [[self networkEngine] post:path params:fields];
}

- (SFNetworkOperation *)requestForUpdateWithObjectType:(NSString *)objectType
                                         objectId:(NSString *)objectId 
                                           fields:(NSDictionary *)fields {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@", self.apiVersion, objectType, objectId];
    return [[self networkEngine] patch:path params:fields];
}

- (SFNetworkOperation *)requestForUpsertWithObjectType:(NSString *)objectType
                                  externalIdField:(NSString *)externalIdField 
                                       externalId:(NSString *)externalId 
                                           fields:(NSDictionary *)fields {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@/%@", self.apiVersion, objectType, externalIdField, externalId];
    return [[self networkEngine] patch:path params:fields];
}

- (SFNetworkOperation *)requestForDeleteWithObjectType:(NSString *)objectType
                                         objectId:(NSString *)objectId {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/%@/%@", self.apiVersion, objectType, objectId];
    return [[self networkEngine] delete:path params:nil];
}

- (SFNetworkOperation *)requestForQuery:(NSString *)soql {
    NSDictionary *queryParams = [NSDictionary dictionaryWithObjectsAndKeys:soql, @"q", nil];
    NSString *path = [NSString stringWithFormat:@"/%@/query", self.apiVersion];
    return [[self networkEngine] get:path params:queryParams];
}

- (SFNetworkOperation *)requestForSearch:(NSString *)sosl {
    NSDictionary *queryParams = [NSDictionary dictionaryWithObjectsAndKeys:sosl, @"q", nil];
    NSString *path = [NSString stringWithFormat:@"/%@/search", self.apiVersion];
    return [[self networkEngine] get:path params:queryParams];
}

@end
