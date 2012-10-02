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

#import "RKRequestDelegateWrapper.h"
#import "RestKit.h"
#import "SFJsonUtils.h"
#import "SFRestRequest.h"
#import "SFSessionRefresher.h"
#import "SFAccountManager.h"

NSString * const kSFMobileSDKVersion = @"1.3.1";
NSString* const kSFRestDefaultAPIVersion = @"v23.0";
NSString* const kSFRestErrorDomain = @"com.salesforce.RestAPI.ErrorDomain";
NSInteger const kSFRestErrorCode = 999;
NSString * const kSFMobileSDKNativeDesignator = @"Native";


// singleton instance
static SFRestAPI *_instance;
static dispatch_once_t _sharedInstanceGuard;

@implementation SFRestAPI

@synthesize apiVersion=_apiVersion;
@synthesize activeRequests=_activeRequests;
@synthesize sessionRefresher = _sessionRefresher;

#pragma mark - init/setup

- (id)init {
    self = [super init];
    if (self) {
        _activeRequests = [[NSMutableSet alloc] initWithCapacity:4];
        _sessionRefresher = [[SFSessionRefresher alloc] init];
        self.apiVersion = kSFRestDefaultAPIVersion;
        _accountMgr = [SFAccountManager sharedInstance];
        
        // Note that rkClient is created on demand.
    }
    return self;
}

- (void)dealloc {
    [_sessionRefresher release]; _sessionRefresher = nil;
    [_rkClient release]; _rkClient = nil;
    [_activeRequests release]; _activeRequests = nil;
    [super dealloc];
}

#pragma mark - singleton


+ (SFRestAPI *)sharedInstance {
    dispatch_once(&_sharedInstanceGuard, 
                  ^{ 
                      _instance = [[SFRestAPI alloc] init];
                  });
    return _instance;
}

#pragma mark - Internal

- (void)removeActiveRequestObject:(RKRequestDelegateWrapper *)request {
    [self.activeRequests removeObject:request]; //this will typically release the request
}

- (BOOL)forceTimeoutRequest:(SFRestRequest*)req {
    BOOL found = NO;
    RKRequestDelegateWrapper *toCancel = nil;
    if (nil != req) {
        for (RKRequestDelegateWrapper *wrap in self.activeRequests) {
            if ([wrap.request isEqual:req]) {
                toCancel = wrap;
                break;
            }
        }
    } else {
        toCancel = [self.activeRequests anyObject];
    }
    
    if (nil != toCancel) {
        found = YES;
        [toCancel requestDidTimeout:nil];
    }

    return found;
}

#pragma mark - Properties

- (RKClient *)rkClient {    
    if (nil == _rkClient) {
        if (nil != _accountMgr.credentials.instanceUrl) {
            _rkClient = [[RKClient alloc] initWithBaseURL:_accountMgr.credentials.instanceUrl];
            _rkClient.cachePolicy = RKRequestCachePolicyNone;
            [_rkClient setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
            [_rkClient setValue:[[self class] userAgentString] forHTTPHeaderField:@"User-Agent"];

            // Authorization header (access token) is now set the moment before we actually send the request.
        }
    } else {
        // Make sure the instance URL is up-to-date.
        RKURL *freshBaseUrl = [RKURL URLWithBaseURL:_accountMgr.credentials.instanceUrl];
        _rkClient.baseURL = freshBaseUrl;
    }
    return _rkClient;
}

/**
 Set a user agent string based on the mobile SDK version.
 We are building a user agent of the form:
 SalesforceMobileSDK/1.0 iPhone OS/3.2.0 (iPad) AppName/AppVersion Native [Current User Agent]
 */
+ (NSString *)userAgentString {
    
    // Get the current user agent.  Yes, this is hack-ish.  Alternatives are more hackish.  UIWebView
    // really doesn't want you to know about its HTTP headers.
#ifndef UNIT_TESTS
    UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    NSString *currentUserAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
    [webView release];
#else
    NSString *currentUserAgent = @"Unit test runner";
#endif
    
    UIDevice *curDevice = [UIDevice currentDevice];
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];

    NSString *myUserAgent = [NSString stringWithFormat:
                             @"SalesforceMobileSDK/%@ %@/%@ (%@) %@/%@ %@ %@",
                             kSFMobileSDKVersion,
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


#pragma mark - ajax methods

- (void)send:(SFRestRequest *)request delegate:(id<SFRestDelegate>)delegate {
    NSLog(@"SFRestAPI::send: %@", request);

    if (nil != delegate) {
        request.delegate = delegate;
    }
    
    RKRequestDelegateWrapper *wrappedDelegate = [RKRequestDelegateWrapper wrapperWithRequest:request];
    [self.activeRequests addObject:wrappedDelegate];
    [wrappedDelegate send];
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
                                 [NSDictionary dictionaryWithObjectsAndKeys:fieldList, @"fields", nil] 
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
    NSDictionary *queryParams = [NSDictionary dictionaryWithObjectsAndKeys:soql, @"q", nil];
    NSString *path = [NSString stringWithFormat:@"/%@/query", self.apiVersion];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

- (SFRestRequest *)requestForSearch:(NSString *)sosl {
    NSDictionary *queryParams = [NSDictionary dictionaryWithObjectsAndKeys:sosl, @"q", nil];
    NSString *path = [NSString stringWithFormat:@"/%@/search", self.apiVersion];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:queryParams];
}

@end
