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

#import <Security/Security.h>
#import <WebKit/WebKit.h>
#import "SFOAuthCredentials+Internal.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFOAuthInfo.h"
#import "SFSDKAuthConfigUtil.h"
#import "SFSDKCryptoUtils.h"
#import "NSData+SFSDKUtils.h"
#import "NSString+SFAdditions.h"
#import "SFApplicationHelper.h"
#import "NSURL+SFStringUtils.h"
#import "SFUserAccountManager.h"
#import "SFSDKLoginHostStorage.h"
#import "SFSDKLoginHost.h"
#import "SFSDKEventBuilderHelper.h"
#import "SFSDKAppFeatureMarkers.h"
#import "SalesforceSDKManager.h"
#import "SFSDKWebViewStateManager.h"
#import "SFNetwork.h"
#import "NSURL+SFAdditions.h"
#import <SalesforceAnalytics/NSUserDefaults+SFAdditions.h>

// Public constants

const NSTimeInterval kSFOAuthDefaultTimeout                     = 120.0; // seconds
NSString * const     kSFOAuthErrorDomain                        = @"com.salesforce.OAuth.ErrorDomain";

// Private constants

static NSString * const kSFOAuthEndPointAuthorize               = @"/services/oauth2/authorize";    // user agent flow
static NSString * const kSFOAuthEndPointToken                   = @"/services/oauth2/token";        // token refresh flow

// Advanced auth constants
static NSUInteger const kSFOAuthCodeVerifierByteLength          = 128;
static NSString * const kSFOAuthCodeVerifierParamName           = @"code_verifier";
static NSString * const kSFOAuthCodeChallengeParamName          = @"code_challenge";
static NSString * const kSFOAuthResponseTypeCode                = @"code";

static NSString * const kSFOAuthAccessToken                     = @"access_token";
static NSString * const kSFOAuthClientId                        = @"client_id";
static NSString * const kSFOAuthDeviceId                        = @"device_id";
static NSString * const kSFOAuthCustomPermissions               = @"custom_permissions";
static NSString * const kSFOAuthDisplay                         = @"display";
static NSString * const kSFOAuthDisplayTouch                    = @"touch";
static NSString * const kSFOAuthError                           = @"error";
static NSString * const kSFOAuthErrorDescription                = @"error_description";
static NSString * const kSFOAuthFormat                          = @"format";
static NSString * const kSFOAuthFormatJson                      = @"json";
static NSString * const kSFOAuthGrantType                       = @"grant_type";
static NSString * const kSFOAuthGrantTypeRefreshToken           = @"refresh_token";
static NSString * const kSFOAuthId                              = @"id";
static NSString * const kSFOAuthInstanceUrl                     = @"instance_url";
static NSString * const kSFOAuthCommunityId                     = @"sfdc_community_id";
static NSString * const kSFOAuthCommunityUrl                    = @"sfdc_community_url";
static NSString * const kSFOAuthIssuedAt                        = @"issued_at";
static NSString * const kSFOAuthRedirectUri                     = @"redirect_uri";
static NSString * const kSFOAuthRefreshToken                    = @"refresh_token";
static NSString * const kSFOAuthResponseType                    = @"response_type";
static NSString * const kSFOAuthResponseTypeToken               = @"token";
static NSString * const kSFOAuthScope                           = @"scope";
static NSString * const kSFOAuthSignature                       = @"signature";

// Used for the IP bypass flow, Advanced auth flow
static NSString * const kSFOAuthApprovalCode                    = @"code";
static NSString * const kSFOAuthGrantTypeAuthorizationCode      = @"authorization_code";
static NSString * const kSFOAuthResponseTypeActivatedClientCode = @"activated_client_code";
static NSString * const kSFOAuthResponseClientSecret            = @"client_secret";

// OAuth Error Descriptions
// see https://na1.salesforce.com/help/doc/en/remoteaccess_oauth_refresh_token_flow.htm

static NSString * const kSFOAuthErrorTypeMalformedResponse          = @"malformed_response";
static NSString * const kSFOAuthErrorTypeAccessDenied               = @"access_denied";
static NSString * const KSFOAuthErrorTypeInvalidClientId            = @"invalid_client_id"; // invalid_client_id:'client identifier invalid'
                                                                                            // this may be returned when the refresh token is revoked
                                                                                            // TODO: needs clarification
static NSString * const kSFOAuthErrorTypeInvalidClient              = @"invalid_client";    // invalid_client:'invalid client credentials'
                                                                                            // this is returned when refresh token is revoked
static NSString * const kSFOAuthErrorTypeInvalidClientCredentials   = @"invalid_client_credentials"; // this is documented but hasn't been witnessed
static NSString * const kSFOAuthErrorTypeInvalidGrant               = @"invalid_grant";
static NSString * const kSFOAuthErrorTypeInvalidRequest             = @"invalid_request";
static NSString * const kSFOAuthErrorTypeInactiveUser               = @"inactive_user";
static NSString * const kSFOAuthErrorTypeInactiveOrg                = @"inactive_org";
static NSString * const kSFOAuthErrorTypeRateLimitExceeded          = @"rate_limit_exceeded";
static NSString * const kSFOAuthErrorTypeUnsupportedResponseType    = @"unsupported_response_type";
static NSString * const kSFOAuthErrorTypeTimeout                    = @"auth_timeout";
static NSString * const kSFOAuthErrorTypeWrongVersion               = @"wrong_version";     // credentials do not match current Connected App version in the org
static NSString * const kSFOAuthErrorTypeBrowserLaunchFailed        = @"browser_launch_failed";
static NSString * const kSFOAuthErrorTypeUnknownAdvancedAuthConfig  = @"unknown_advanced_auth_config";
static NSString * const kSFOAuthErrorTypeJWTLaunchFailed            = @"jwt_launch_failed";

static NSUInteger kSFOAuthReponseBufferLength                   = 512; // bytes

static NSString * const kHttpMethodPost                         = @"POST";
static NSString * const kHttpHeaderContentType                  = @"Content-Type";
static NSString * const kHttpPostContentType                    = @"application/x-www-form-urlencoded";
static NSString * const kHttpHeaderUserAgent                    = @"User-Agent";
static NSString * const kOAuthUserAgentUserDefaultsKey          = @"UserAgent";
static NSString * const kSFAppFeatureSafariBrowserForLogin      = @"BW";
static NSString * const kSFECParameter = @"ec";

@implementation SFOAuthCoordinator

@synthesize credentials          = _credentials;
@synthesize delegate             = _delegate;
@synthesize timeout              = _timeout;
@synthesize view                 = _view;

// private

@synthesize authenticating              = _authenticating;
@synthesize session                     = _session;
@synthesize responseData                = _responseData;
@synthesize initialRequestLoaded        = _initialRequestLoaded;
@synthesize approvalCode                = _approvalCode;
@synthesize scopes                      = _scopes;
@synthesize advancedAuthConfiguration   = _advancedAuthConfiguration;
@synthesize advancedAuthState           = _advancedAuthState;
@synthesize codeVerifier                = _codeVerifier;
@synthesize authInfo                    = _authInfo;
@synthesize oauthCoordinatorFlow        = _oauthCoordinatorFlow;
@synthesize userAgentForAuth            = _userAgentForAuth;
@synthesize origWebUserAgent            = _origWebUserAgent;


- (id)init {
    return [self initWithCredentials:nil];
}

- (id)initWithCredentials:(SFOAuthCredentials *)credentials {
    self = [super init];
    if (self) {
        self.oauthCoordinatorFlow = self;
        self.credentials = credentials;
        self.authenticating = NO;
        _timeout = kSFOAuthDefaultTimeout;
        _view = nil;
    }
    
    // response data is initialized in didReceiveResponse
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _approvalCode = nil;
    _session = nil;
    _credentials = nil;
    _responseData = nil;
    _scopes = nil;
    _view = nil;
}

- (void)authenticate {
    NSAssert(nil != self.credentials, @"credentials cannot be nil");
    NSAssert(self.credentials.clientId.length > 0, @"credentials.clientId cannot be nil or empty");
    NSAssert(self.credentials.identifier.length > 0, @"credentials.identifier cannot be nil or empty");
    NSAssert(self.credentials.domain.length > 0, @"credentials.domain cannot be nil or empty.");
    NSAssert(nil != self.delegate, @"cannot authenticate with nil delegate");

    if (self.authenticating) {
        [SFSDKCoreLogger d:[self class] format:@"%@ Error: authenticate called while already authenticating. Call stopAuthenticating first.", NSStringFromSelector(_cmd)];
        return;
    }
    [SFSDKCoreLogger d:[self class] format:@"%@ authenticating as %@ %@ refresh token on '%@://%@' ...",
         NSStringFromSelector(_cmd),
         self.credentials.clientId, (nil == self.credentials.refreshToken ? @"without" : @"with"),
         self.credentials.protocol, self.credentials.domain];
    self.authenticating = YES;
    if (self.credentials.refreshToken) {
        self.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeRefresh];
    } else {
        self.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent];
    }
    
    // Don't try to authenticate if there is no network available
    if ([self.delegate respondsToSelector:@selector(oauthCoordinatorIsNetworkAvailable:)] &&
        ![self.delegate oauthCoordinatorIsNetworkAvailable:self]) {
        [SFSDKCoreLogger d:[self class] format:@"Network is not available, so bypassing login"];
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
        [self notifyDelegateOfFailure:error authInfo:self.authInfo];
        return;
    }
    
    if (self.credentials.refreshToken) {
        // clear any access token we may have and begin refresh flow
        [self notifyDelegateOfBeginAuthentication];
        [self.oauthCoordinatorFlow beginTokenEndpointFlow:SFOAuthTokenEndpointFlowRefresh];
    } else if (self.credentials.jwt) {
        // JWT token existence means we're doing JWT token exchange.
        self.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeJwtTokenExchange];
        [self notifyDelegateOfBeginAuthentication];
        [self.oauthCoordinatorFlow beginJwtTokenExchangeFlow];
    } else {
        __weak typeof(self) weakSelf = self;
        switch (self.advancedAuthConfiguration) {
            case SFOAuthAdvancedAuthConfigurationNone: {
                [self notifyDelegateOfBeginAuthentication];
                [self.oauthCoordinatorFlow beginUserAgentFlow];
                break;
            }
            case SFOAuthAdvancedAuthConfigurationAllow: {

                /*
                 * If advanced auth mode is allowed, we have to get auth configuration settings
                 * from the org, where available, and initiate advanced auth flows, if configured.
                 */
                [SFSDKAuthConfigUtil getMyDomainAuthConfig:^(SFOAuthOrgAuthConfiguration *authConfig, NSError *error) {
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (authConfig.useNativeBrowserForAuth) {
                        strongSelf.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeAdvancedBrowser];
                        [strongSelf notifyDelegateOfBeginAuthentication];
                        [strongSelf.oauthCoordinatorFlow beginNativeBrowserFlow];
                    } else {
                        [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureSafariBrowserForLogin];
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        [strongSelf notifyDelegateOfBeginAuthentication];
                        [strongSelf.oauthCoordinatorFlow beginUserAgentFlow];
                    }
                } oauthCredentials:self.credentials];
                break;
            }
            case SFOAuthAdvancedAuthConfigurationRequire: {

                // Advanced auth mode is required. Begin the advanced browser flow.
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    strongSelf.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeAdvancedBrowser];
                    [strongSelf notifyDelegateOfBeginAuthentication];
                    [strongSelf.oauthCoordinatorFlow beginNativeBrowserFlow];
                });
                break;
            }
            default: {

                // Unknown advanced auth state.
                NSError *unknownConfigError = [[self class] errorWithType:kSFOAuthErrorTypeUnknownAdvancedAuthConfig
                                                              description:[NSString stringWithFormat:@"Unknown advanced auth config: %lu", (unsigned long)self.advancedAuthConfiguration]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf notifyDelegateOfFailure:unknownConfigError authInfo:weakSelf.authInfo];
                });
                break;
            }
        }
    }
}

- (void)authenticateWithCredentials:(SFOAuthCredentials *)credentials {
    self.credentials = credentials;
    [self authenticate];
}

- (BOOL)isAuthenticating {
    return self.authenticating;
}

- (void)stopAuthentication {
    [_view stopLoading];
    [self.session invalidateAndCancel];
    _session = nil;
    
    self.authenticating = NO;
}

- (void)revokeAuthentication {
    [self stopAuthentication];
    [self.credentials revoke];
}

- (BOOL)handleIDPAuthenticationResponse:(NSURL *)appUrlResponse {
    self.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeIDP];
   
    NSString *query = [appUrlResponse query];
    
    if ([query length] == 0) {
        [SFSDKCoreLogger i:[self class] format:@"%@ URL has no query string.", NSStringFromSelector(_cmd)];
        return NO;
    }

    NSString *codeVal = [appUrlResponse valueForParameterName:@"code"];
    if ([codeVal length] == 0) {
        [SFSDKCoreLogger i:[self class] format:@"%@ URL has no '%@' parameter value.", NSStringFromSelector(_cmd), kSFOAuthResponseTypeCode];
        return NO;
    }
    self.approvalCode = codeVal;
    [SFSDKCoreLogger i:[self class] format:@"%@ Received advanced authentication response.  Beginning token exchange.", NSStringFromSelector(_cmd)];
    self.advancedAuthState = SFOAuthAdvancedAuthStateTokenRequestInitiated;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.oauthCoordinatorFlow beginTokenEndpointFlow:SFOAuthTokenEndpointFlowAdvancedBrowser];
    });
    return YES;
}

- (BOOL)handleAdvancedAuthenticationResponse:(NSURL *)appUrlResponse {
     self.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeAdvancedBrowser];
    NSString *appUrlResponseString = [appUrlResponse absoluteString];
    if (![[appUrlResponseString lowercaseString] hasPrefix:[self.credentials.redirectUri lowercaseString]]) {
        [SFSDKCoreLogger i:[self class] format:@"%@ URL does not match redirect URI.", NSStringFromSelector(_cmd)];
        return NO;
    }
    NSString *query = [appUrlResponse query];
    if ([query length] == 0) {
        [SFSDKCoreLogger i:[self class] format:@"%@ URL has no query string.", NSStringFromSelector(_cmd)];
        return NO;
    }
    NSDictionary *queryDict = [[self class] parseQueryString:query decodeParams:NO];
    NSString *codeVal = queryDict[kSFOAuthResponseTypeCode];
    if ([codeVal length] == 0) {
        [SFSDKCoreLogger i:[self class] format:@"%@ URL has no '%@' parameter value.", NSStringFromSelector(_cmd), kSFOAuthResponseTypeCode];
        return NO;
    }
    self.approvalCode = codeVal;
    [SFSDKCoreLogger i:[self class] format:@"%@ Received advanced authentication response.  Beginning token exchange.", NSStringFromSelector(_cmd)];
    self.advancedAuthState = SFOAuthAdvancedAuthStateTokenRequestInitiated;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.oauthCoordinatorFlow beginTokenEndpointFlow:SFOAuthTokenEndpointFlowAdvancedBrowser];
    });
    return YES;
}

#pragma mark - Properties

- (WKWebView *)view {
    if (_view == nil) {
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        config.processPool = SFSDKWebViewStateManager.sharedProcessPool;
        _view = [[WKWebView alloc] initWithFrame:[[UIScreen mainScreen] bounds] configuration:config];
        _view.navigationDelegate = self;
        _view.autoresizesSubviews = YES;
        _view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
         _view.clipsToBounds = YES;
        _view.translatesAutoresizingMaskIntoConstraints = NO;
        _view.customUserAgent = [SalesforceSDKManager sharedManager].userAgentString(@"");
        _view.UIDelegate = self;
    }
    return _view;
}


#pragma mark - Private Methods

- (void)notifyDelegateOfFailure:(NSError*)error authInfo:(SFOAuthInfo *)info
{
    self.authenticating = NO;
    self.advancedAuthState = SFOAuthAdvancedAuthStateNotStarted;
    if ([self.delegate respondsToSelector:@selector(oauthCoordinator:didFailWithError:authInfo:)]) {
        [self.delegate oauthCoordinator:self didFailWithError:error authInfo:info];
    } else if ([self.delegate respondsToSelector:@selector(oauthCoordinator:didFailWithError:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.delegate oauthCoordinator:self didFailWithError:error];
#pragma clang diagnostic pop
    }
    self.authInfo = nil;
}

- (void)notifyDelegateOfSuccess:(SFOAuthInfo *)authInfo
{
    self.authenticating = NO;
    self.advancedAuthState = SFOAuthAdvancedAuthStateNotStarted;
    if ([self.delegate respondsToSelector:@selector(oauthCoordinatorDidAuthenticate:authInfo:)]) {
        [self.delegate oauthCoordinatorDidAuthenticate:self authInfo:authInfo];
    } else if ([self.delegate respondsToSelector:@selector(oauthCoordinatorDidAuthenticate:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.delegate oauthCoordinatorDidAuthenticate:self];
#pragma clang diagnostic pop
    }
    self.authInfo = nil;
}

- (void)notifyDelegateOfBeginAuthentication
{
    if ([self.delegate respondsToSelector:@selector(oauthCoordinatorWillBeginAuthentication:authInfo:)]) {
        [self.delegate oauthCoordinatorWillBeginAuthentication:self authInfo:self.authInfo];
    }
}

- (void)beginNativeBrowserFlow {
    if ([self.delegate respondsToSelector:@selector(oauthCoordinator:willBeginBrowserAuthentication:)]) {
        __weak typeof(self) weakSelf = self;
        [self.delegate oauthCoordinator:self willBeginBrowserAuthentication:^(BOOL proceed) {
            if (proceed) {
                [weakSelf continueNativeBrowserFlow];
            }
        }];
    } else {
        // If delegate does not implement the method, simply continue with the browser flow.
        [self continueNativeBrowserFlow];
    }
}

- (void)continueNativeBrowserFlow {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self continueNativeBrowserFlow];
        });
        return;
    }
    
    // E.g. https://login.salesforce.com/services/oauth2/authorize
    //      ?client_id=<Connected App ID>&redirect_uri=<Connected App Redirect URI>&display=touch
    //      &response_type=code
    NSMutableString *approvalUrl = [[NSMutableString alloc] initWithFormat:@"%@://%@%@?%@=%@&%@=%@&%@=%@&%@=%@&state=%@",
                                    self.credentials.protocol, self.credentials.domain, [self brandedAuthorizeURL],
                                    kSFOAuthClientId, self.credentials.clientId,
                                    kSFOAuthRedirectUri, self.credentials.redirectUri,
                                    kSFOAuthDisplay, kSFOAuthDisplayTouch,
                                    kSFOAuthResponseType, kSFOAuthResponseTypeCode,self.credentials.identifier];
    
    // OAuth scopes
    NSString *scopeString = [self scopeQueryParamString];
    if (scopeString != nil) {
        [approvalUrl appendString:scopeString];
    }
    
    // Code verifier challenge:
    //   - self.codeVerifier is a base64url-encoded random data string
    //   - The code challenge sent here is an SHA-256 hash of self.codeVerifier, also base64url-encoded
    //   - Later, self.codeVerifier will be sent to the service, to be used to compare against the initial code challenge sent here.
    self.codeVerifier = [[SFSDKCryptoUtils randomByteDataWithLength:kSFOAuthCodeVerifierByteLength] msdkBase64UrlString];
    NSString *codeChallengeString = [[[self.codeVerifier dataUsingEncoding:NSUTF8StringEncoding] msdkSha256Data] msdkBase64UrlString];
    [approvalUrl appendFormat:@"&%@=%@", kSFOAuthCodeChallengeParamName, codeChallengeString];
    
    // Launch the native browser.
    [SFSDKCoreLogger d:[self class] format:@"%@: Initiating native browser flow with URL %@", NSStringFromSelector(_cmd), approvalUrl];
    NSURL *nativeBrowserUrl = [NSURL URLWithString:approvalUrl];
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureSafariBrowserForLogin];
    SFSafariViewController *svc = [[SFSafariViewController alloc] initWithURL:nativeBrowserUrl];
    svc.delegate = self;
    self.advancedAuthState = SFOAuthAdvancedAuthStateBrowserRequestInitiated;
    [self.delegate oauthCoordinator:self didBeginAuthenticationWithSafariViewController:svc];
}

- (void)beginUserAgentFlow {
    
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self beginUserAgentFlow];
        });
        return;
    }
    
    self.initialRequestLoaded = NO;
    
    // notify delegate will be begin authentication in our (web) vew
    if ([self.delegate respondsToSelector:@selector(oauthCoordinator:willBeginAuthenticationWithView:)]) {
        [self.delegate oauthCoordinator:self willBeginAuthenticationWithView:self.view];
    }
    
    NSString *approvalUrlString = [self generateApprovalUrlString];
    [self loadWebViewWithUrlString:approvalUrlString cookie:NO];
}

- (void)beginJwtTokenExchangeFlow {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self beginJwtTokenExchangeFlow];
        });
        return;
    }
    NSAssert(self.credentials.jwt.length > 0, @"JWT token should be present at this point.");
    [self swapJWTWithCompletionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            [SFSDKCoreLogger e:[self class] format:@"Fail to swap JWT for access token: %@", error.localizedDescription];
            [self notifyDelegateOfFailure:error authInfo:self.authInfo];
            return;
        }
        self.credentials.jwt = nil;
        NSError *jsonError = nil;
        id json = nil;
        json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError != nil) {
            NSError *error = [[self class] errorWithType:kSFOAuthErrorTypeJWTLaunchFailed
                                                 description:@"Error parsing JWT token exchange response."
                                             underlyingError:jsonError];
                [self notifyDelegateOfFailure:error authInfo:self.authInfo];
            return;
        }
        if (![json isKindOfClass:[NSDictionary class]]) {
            NSString *errorDesc = [NSString stringWithFormat:@"Expected NSDictionary for JWT token response, received %@ instance.", NSStringFromClass([json class])];
                NSError *error = [[self class] errorWithType:kSFOAuthErrorTypeJWTLaunchFailed
                                                 description:errorDesc];
            [self notifyDelegateOfFailure:error authInfo:self.authInfo];
            return;
        }
        NSDictionary *dict = (NSDictionary *)json;
        if (nil != dict[kSFOAuthError]) {
            NSError *error = [[self class] errorWithType:dict[kSFOAuthError] description:dict[kSFOAuthErrorDescription]];
            [self notifyDelegateOfFailure:error authInfo:self.authInfo];
            return;
        }
        [self updateCredentials:dict];
        if (self.credentials.accessToken && self.credentials.apiUrl) {
            NSString *baseUrlString = [self.credentials.apiUrl absoluteString];
            NSString *approvalUrlString = [self generateApprovalUrlString];
            NSString *escapedApprovalUrlString = [approvalUrlString stringByURLEncoding];
            NSString *frontDoorUrlString = [NSString stringWithFormat:@"%@/secur/frontdoor.jsp?sid=%@&retURL=%@", baseUrlString, self.credentials.accessToken, escapedApprovalUrlString];
            [self loadWebViewWithUrlString:frontDoorUrlString cookie:YES];
        }
    }];
}

- (void)swapJWTWithCompletionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler  {
    NSString *url = [[NSString alloc] initWithFormat:@"%@://%@%@", self.credentials.protocol,
                     self.credentials.domain,
                     kSFOAuthEndPointToken];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:self.timeout];
    NSString *grantType = @"urn:ietf:params:oauth:grant-type:jwt-bearer";
    NSString *bodyStr = [[@"grant_type=" stringByAppendingString:[grantType stringByURLEncoding]] stringByAppendingString:[NSString stringWithFormat:@"&assertion=%@", self.credentials.jwt]];
    NSData *body = [bodyStr dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:body];
    [request setHTTPMethod:kHttpMethodPost];
    [request setValue:kHttpPostContentType forHTTPHeaderField:kHttpHeaderContentType];
    
    [[self.session dataTaskWithRequest:request completionHandler:completionHandler] resume];
}

// IDP related
- (void)beginIDPFlow:(SFOAuthCredentials *)spAppCredentials {
    self.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeIDP];
    self.spAppCredentials = spAppCredentials;
    self.initialRequestLoaded = NO;
    // notify delegate will be begin authentication in our (web) vew
    if (self.credentials.accessToken && self.credentials.apiUrl) {
        NSString *baseUrlString = [self.credentials.apiUrl absoluteString];
        NSString *approvalUrlString = [self generateCodeApprovalUrlString:spAppCredentials];
        NSString *codeChallengeString = spAppCredentials.challengeString;
        approvalUrlString = [NSString stringWithFormat:@"%@&%@=%@", approvalUrlString, kSFOAuthCodeChallengeParamName, codeChallengeString];
        NSString *escapedApprovalUrlString = [approvalUrlString stringByURLEncoding];
        NSString *frontDoorUrlString = [NSString stringWithFormat:@"%@/secur/frontdoor.jsp?sid=%@&retURL=%@", baseUrlString, self.credentials.accessToken, escapedApprovalUrlString];
        [self loadWebViewWithUrlString:frontDoorUrlString cookie:YES];
    }
}

- (void)loadWebViewWithUrlString:(NSString *)urlString cookie:(BOOL)enableCookie {
    NSURL *urlToLoad = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:urlToLoad];
    [request setHTTPShouldHandleCookies:enableCookie];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData]; // don't use cache
    [SFSDKCoreLogger d:[self class] format:@"%@ Loading web view for '%@' auth flow, with URL: %@", NSStringFromSelector(_cmd), self.authInfo.authTypeDescription, [urlToLoad redactedAbsoluteString:@[ @"sid" ]]];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view loadRequest:request];
    });
}

- (void)beginTokenEndpointFlow:(SFOAuthTokenEndpointFlow)flowType {
    
    self.responseData = [NSMutableData dataWithLength:512];
    NSString *refreshDomain = self.credentials.communityId ? self.credentials.communityUrl.absoluteString : self.credentials.domain;
    NSString *protocolHost = self.credentials.communityId ? refreshDomain : [NSString stringWithFormat:@"%@://%@", self.credentials.protocol, refreshDomain];
    NSString *url = [[NSString alloc] initWithFormat:@"%@%@",
                     protocolHost,
                     kSFOAuthEndPointToken];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]
                                                                cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                            timeoutInterval:self.timeout];
    [request setHTTPMethod:kHttpMethodPost];
    [request setValue:kHttpPostContentType forHTTPHeaderField:kHttpHeaderContentType];
    if (self.userAgentForAuth != nil) {
        [request setValue:self.userAgentForAuth forHTTPHeaderField:kHttpHeaderUserAgent];
    }
    [request setHTTPShouldHandleCookies:NO];
    
    NSMutableString *params = [[NSMutableString alloc] initWithFormat:@"%@=%@&%@=%@&%@=%@&%@=%@",
                               kSFOAuthFormat, kSFOAuthFormatJson,
                               kSFOAuthRedirectUri, self.credentials.redirectUri,
                               kSFOAuthClientId, self.credentials.clientId,
                               kSFOAuthDeviceId,[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    NSMutableString *logString = [NSMutableString stringWithString:params];
    
    // If there is an approval code (Advanced Auth flow), use it once to get the tokens.
    if (self.approvalCode) {
        [SFSDKCoreLogger i:[self class] format:@"%@: Initiating authorization code flow.", NSStringFromSelector(_cmd)];
        [params appendFormat:@"&%@=%@&%@=%@", kSFOAuthGrantType, kSFOAuthGrantTypeAuthorizationCode, kSFOAuthApprovalCode, self.approvalCode];
        [logString appendFormat:@"&%@=%@&%@=REDACTED", kSFOAuthGrantType, kSFOAuthGrantTypeAuthorizationCode, kSFOAuthApprovalCode];
        
        // If this is the advanced authentication flow, we need to add the code verifier parameter and some form
        // of a client secret as well.
        if (self.authInfo.authType == SFOAuthTypeAdvancedBrowser ||
            self.authInfo.authType == SFOAuthTypeIDP) {
            [params appendFormat:@"&%@=%@", kSFOAuthCodeVerifierParamName, self.codeVerifier];
            [logString appendFormat:@"&%@=REDACTED", kSFOAuthCodeVerifierParamName];
        }
        
        // Discard the approval code.
        self.approvalCode = nil;
    } else {
        // Assume Refresh token flow.
        [SFSDKCoreLogger i:[self class] format:@"%@: Initiating refresh token flow.", NSStringFromSelector(_cmd)];
        [params appendFormat:@"&%@=%@&%@=%@", kSFOAuthGrantType, kSFOAuthGrantTypeRefreshToken, kSFOAuthRefreshToken, self.credentials.refreshToken];
        [logString appendFormat:@"&%@=%@&%@=REDACTED", kSFOAuthGrantType, kSFOAuthGrantTypeRefreshToken, kSFOAuthRefreshToken ];
        for(NSString * key in self.additionalTokenRefreshParams) {
            [params appendFormat:@"&%@=%@", [key stringByURLEncoding], [self.additionalTokenRefreshParams[key] stringByURLEncoding]];
        }
    }
    [SFSDKCoreLogger d:[self class] format:@"%@ with %@", NSStringFromSelector(_cmd), logString];
    NSData *encodedBody = [params dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:encodedBody];
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSURL *requestUrl = [request URL];
            NSString *errorUrlString = [NSString stringWithFormat:@"%@://%@%@", [requestUrl scheme], [requestUrl host], [requestUrl relativePath]];
            if(error.code == NSURLErrorTimedOut) {
                [SFSDKCoreLogger d:[self class] format:@"Refresh attempt timed out after %f seconds.", self.timeout];
                [self stopAuthentication];
                error = [[self class] errorWithType:kSFOAuthErrorTypeTimeout
                                        description:@"The token refresh process timed out."];
            }
            [SFSDKCoreLogger d:[self class] format:@"SFOAuthCoordinator session failed with error: error code: %ld, description: %@, URL: %@", (long)error.code, [error localizedDescription], errorUrlString];
            [self notifyDelegateOfFailure:error authInfo:self.authInfo];
            return;
        }
        // reset the response data for a new refresh response
        self.responseData = [NSMutableData dataWithCapacity:kSFOAuthReponseBufferLength];
        [self.responseData appendData:data];
        [self.oauthCoordinatorFlow handleTokenEndpointResponse:self.responseData];
    }] resume];
}

/* Handle a 'token' endpoint (e.g. refresh, advanced auth) response.
    Example response:
    { "id":"https://login.salesforce.com/id/00DD0000000FH54SBH/005D0000001GZXmIAO",
      "issued_at":"1309481030001",
      "instance_url":"https://na1.salesforce.com",
      "signature":"YEguoQhgIvJ3apLALB93vRsq/pUxwG2klsyHp9zX9Wg=",
      "access_token":"00DD0000000FH84!AQwAQKS7WDhWO9k6YrhbiWBZiDAZC5RzN2dpleOKGKf5dFsatyAN8kck7mtrNvxRGIgN.wE.Z0ZN_No7h6HNqrq828nL6E2J" }
    
    Example error response:
        { "error":"invalid_grant","error_description":"authentication failure - Invalid Password" }
 */
- (void)handleTokenEndpointResponse:(NSMutableData *) data {
    self.responseData = data;
    NSString *responseString = [[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding];
    NSError *jsonError = nil;
    id json = nil;
    json = [NSJSONSerialization JSONObjectWithData:self.responseData options:0 error:&jsonError];
    if (nil == jsonError && [json isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)json;
        if (nil != dict[kSFOAuthError]) {
            NSError *error = [[self class] errorWithType:dict[kSFOAuthError] description:dict[kSFOAuthErrorDescription]];
            [self notifyDelegateOfFailure:error authInfo:self.authInfo];
        } else {
            if (dict[kSFOAuthRefreshToken]) {
                // Refresh token is available. This happens when the IP bypass flow is used.
                self.credentials.refreshToken = dict[kSFOAuthRefreshToken];
            } else {
                // In a non-IP flow, we already have the refresh token here.
            }
            [self updateCredentials:dict];
            [self notifyDelegateOfSuccess:self.authInfo];
        }
    } else {
        // failed to parse JSON
        [SFSDKCoreLogger d:[self class] format:@"%@: JSON parse error: %@", NSStringFromSelector(_cmd), jsonError];
        NSError *error = [[self class] errorWithType:kSFOAuthErrorTypeMalformedResponse description:@"failed to parse response JSON"];
        NSMutableDictionary *errorDict = [NSMutableDictionary dictionaryWithDictionary:jsonError.userInfo];
        if (responseString) {
            errorDict[@"response_data"] = responseString;
        }
        if (error) {
            errorDict[NSUnderlyingErrorKey] = error;
        }
        NSError *finalError = [NSError errorWithDomain:kSFOAuthErrorDomain code:error.code userInfo:errorDict];
        [self notifyDelegateOfFailure:finalError authInfo:self.authInfo];
    }
}

- (NSError *)checkFrontdoorResponseForErrors:(NSURL *)requestUrl {
    NSError *error = nil;
    NSString *ecValue = [requestUrl valueForParameterName:kSFECParameter];
    BOOL foundValidEcValue = ([ecValue isEqualToString:@"301"] || [ecValue isEqualToString:@"302"]);
    NSString *errorCode = [requestUrl valueForParameterName:kSFOAuthError];
    NSString *errorDescription = [requestUrl valueForParameterName:kSFOAuthErrorDescription];
    if (foundValidEcValue) {
        [SFSDKCoreLogger d:[self class] format:@"%@ IDP Authcode redirect response encountered an ec=301 or 302 redirect: %@", NSStringFromSelector(_cmd), requestUrl];
        error = [[self class] errorWithType:kSFOAuthErrorTypeMalformedResponse description:@"IDP Authcode redirect response encountered an ec=301 or 302 redirect"];
    } else if (errorCode) {
        error = [[self class] errorWithType:errorCode
                                description:errorDescription];
    } else if (![requestUrl fragment] && ![requestUrl query]){
        [SFSDKCoreLogger d:[self class] format:@"%@ Error: IDP Authcode response has no payload: %@", NSStringFromSelector(_cmd), requestUrl];
        error = [[self class] errorWithType:kSFOAuthErrorTypeMalformedResponse description:@"IDP Authcode redirect response has no payload"];
    }
    return error;
}

- (void)handleIDPAuthCodeResponse:(NSURL *)requestUrl {
    NSString *response = nil;
    NSError *error = [self checkFrontdoorResponseForErrors:requestUrl];
    // all error cases should be handled by the above call
    if (error) {
        NSError *finalError;
        // add any additional relevant info to the userInfo dictionary
        if (kSFOAuthErrorInvalidClientId == error.code) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:error.userInfo];
            dict[kSFOAuthClientId] = self.credentials.clientId;
            finalError = [NSError errorWithDomain:error.domain code:error.code userInfo:dict];
        } else {
            finalError = error;
        }
        [self notifyDelegateOfFailure:finalError authInfo:self.authInfo];
    } else {
        // Should have a valid reponse here.Must be a fragment or query. No Errors in response,no ec=*
        response = [requestUrl fragment]?:[requestUrl query];
        NSDictionary *params = [[self class] parseQueryString:response decodeParams:NO];
        self.spAppCredentials.authCode = params[kSFOAuthApprovalCode];
        if ([self.delegate respondsToSelector:@selector(oauthCoordinatorDidFetchAuthCode:authInfo:)]) {
            [self.delegate oauthCoordinatorDidFetchAuthCode:self authInfo:self.authInfo];
        }
        
    }
}

- (void)handleUserAgentResponse:(NSURL *)requestUrl {
    NSString *response = nil;
    
    // Check for a response in the URL fragment first, then fall back to the query string.
    if ([requestUrl fragment]) {
        response = [requestUrl fragment];
    } else if ([requestUrl query]) {
        response = [requestUrl query];
    } else {
        [SFSDKCoreLogger d:[self class] format:@"%@ Error: response has no payload: %@", NSStringFromSelector(_cmd), requestUrl];
        NSError *error = [[self class] errorWithType:kSFOAuthErrorTypeMalformedResponse description:@"redirect response has no payload"];
        [self notifyDelegateOfFailure:error authInfo:self.authInfo];
        response = nil;
    }
    if (response) {
        NSDictionary *params = [[self class] parseQueryString:response];
        NSString *error = params[kSFOAuthError];
        if (nil == error) {
            [self updateCredentials:params];
            self.credentials.refreshToken   = params[kSFOAuthRefreshToken];
            [self notifyDelegateOfSuccess:self.authInfo];
        } else {
            NSError *finalError;
            NSError *error = [[self class] errorWithType:params[kSFOAuthError]
                                             description:params[kSFOAuthErrorDescription]];
            
            // add any additional relevant info to the userInfo dictionary
            if (kSFOAuthErrorInvalidClientId == error.code) {
                NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:error.userInfo];
                dict[kSFOAuthClientId] = self.credentials.clientId;
                finalError = [NSError errorWithDomain:error.domain code:error.code userInfo:dict];
            } else {
                finalError = error;
            }
            [self notifyDelegateOfFailure:finalError authInfo:self.authInfo];
        }
    }
}

- (NSString *)generateApprovalUrlString {
    return [self generateApprovalUrlString:self.credentials];
}

- (NSString *)generateApprovalUrlString:(SFOAuthCredentials *)credentials {
    NSAssert(nil != credentials.domain, @"credentials.domain is required");
    NSAssert(nil != credentials.clientId, @"credentials.clientId is required");
    NSAssert(nil != credentials.redirectUri, @"credentials.redirectUri is required");
    NSMutableString *approvalUrlString = [[NSMutableString alloc] initWithFormat:@"%@://%@%@?%@=%@&%@=%@&%@=%@&%@=%@", credentials.protocol,
                                          credentials.domain, [self brandedAuthorizeURL],
                                          kSFOAuthClientId, credentials.clientId,
                                          kSFOAuthRedirectUri, credentials.redirectUri,
                                          kSFOAuthDisplay, kSFOAuthDisplayTouch,
                                          kSFOAuthDeviceId,[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    
    [approvalUrlString appendFormat:@"&%@=%@", kSFOAuthResponseType, kSFOAuthResponseTypeToken];
    NSString *scopeString = [self scopeQueryParamString];
    if (scopeString != nil) {
        [approvalUrlString appendString:scopeString];
    }
    return approvalUrlString;
}

- (NSString *)generateCodeApprovalUrlString:(SFOAuthCredentials *)spAppCredentials {
    NSAssert(nil != self.credentials.domain, @"credentials.domain is required");
    NSAssert(nil != spAppCredentials.clientId, @"credentials.clientId is required");
    NSAssert(nil != spAppCredentials.redirectUri, @"credentials.redirectUri is required");
    NSMutableString *approvalUrlString = [[NSMutableString alloc] initWithFormat:@"%@://%@%@?%@=%@&%@=%@&%@=%@&%@=%@&%@=%@",
                                          @"https",
                                          self.credentials.domain,
                                          kSFOAuthEndPointAuthorize,
                                          kSFOAuthClientId,spAppCredentials.clientId,
                                          kSFOAuthRedirectUri,spAppCredentials.redirectUri,
                                          kSFOAuthDisplay,kSFOAuthDisplayTouch,
                                          kSFOAuthResponseType,kSFOAuthResponseTypeCode,
                                          kSFOAuthDeviceId,[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    
    NSString *scopeString = [self scopeQueryParamString];
    if (scopeString != nil) {
        [approvalUrlString appendString:scopeString];
    }
    return approvalUrlString;
}

- (NSString *)scopeQueryParamString {
    NSMutableSet *scopes = (self.scopes.count > 0 ? [NSMutableSet setWithSet:self.scopes] : [NSMutableSet set]);
    [scopes addObject:kSFOAuthRefreshToken];
    NSString *scopeStr = [[[scopes allObjects] componentsJoinedByString:@" "] stringByURLEncoding];
    return [NSString stringWithFormat:@"&%@=%@", kSFOAuthScope, scopeStr];
}

/** Update the credentials using the provided oauth parameters.
 This method only update the following parameters:
 - identityUrl
 - accessToken
 - instanceUrl
 - issuedAt
 - communityId
 - communityUrl
 */
- (void) updateCredentials:(NSDictionary *) params {

    if (params[kSFOAuthAccessToken]) {
        [self.credentials setPropertyForKey:@"accessToken" withValue:params[kSFOAuthAccessToken]];
    }

    if (params[kSFOAuthIssuedAt]) {
        self.credentials.issuedAt = [[self class] timestampStringToDate:params[kSFOAuthIssuedAt]];
    }

    if (params[kSFOAuthInstanceUrl]) {
         [self.credentials setPropertyForKey:@"instanceUrl" withValue:[NSURL URLWithString:params[kSFOAuthInstanceUrl]]];
    }

    if (params[kSFOAuthId]) {
        [self.credentials setPropertyForKey:@"identityUrl" withValue:[NSURL URLWithString:params[kSFOAuthId]]];
    }

    if (params[kSFOAuthCommunityId]) {
        [self.credentials setPropertyForKey:@"communityId" withValue:params[kSFOAuthCommunityId]];
    }

    if (params[kSFOAuthCommunityUrl]) {
        [self.credentials setPropertyForKey:@"communityUrl" withValue:[NSURL URLWithString:params[kSFOAuthCommunityUrl]]];
    }

    // Parse additional flags
    if(self.additionalOAuthParameterKeys.count > 0) {
        NSMutableDictionary * parsedValues = [NSMutableDictionary dictionaryWithCapacity:self.additionalOAuthParameterKeys.count];
        for(NSString * key in self.additionalOAuthParameterKeys) {
            id obj = params[key];
            if(obj) {
                parsedValues[key] = obj;
            }
        }
        self.credentials.additionalOAuthFields = parsedValues;
    }

}

+ (NSString *)advancedAuthStateDesc:(SFOAuthAdvancedAuthState)authState
{
    switch (authState) {
        case SFOAuthAdvancedAuthStateBrowserRequestInitiated:
            return @"SFOAuthAdvancedAuthStateBrowserRequestInitiated";
            break;
        case SFOAuthAdvancedAuthStateNotStarted:
            return @"SFOAuthAdvancedAuthStateNotStarted";
            break;
        case SFOAuthAdvancedAuthStateTokenRequestInitiated:
            return @"SFOAuthAdvancedAuthStateTokenRequestInitiated";
        default:
            return [NSString stringWithFormat:@"Unknown auth state (%lu)", (unsigned long)authState];
    }
}

- (NSURLSession*)session {
    if (_session == nil) {
        SFNetwork *network = [[SFNetwork alloc] initWithEphemeralSession];
        _session = network.activeSession;
    }
    return _session;
}

#pragma mark - WKNavigationDelegate (User-Agent Token Flow)
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    NSString *requestUrl = [url absoluteString];
    if ([self isRedirectURL:requestUrl]) {
        [self handleUserAgentResponse:url];
        decisionHandler(WKNavigationActionPolicyCancel);
    } else if ([self isSPAppRedirectURL:requestUrl]){
        [self handleIDPAuthCodeResponse:url];
        decisionHandler(WKNavigationActionPolicyCancel);
    }else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    NSURL *url = [webView URL];
    [SFSDKCoreLogger i:[self class] format:@"%@ host=%@ : path=%@", NSStringFromSelector(_cmd), url.host, url.path];
    if ([self.delegate respondsToSelector:@selector(oauthCoordinator:didStartLoad:)]) {
        [self.delegate oauthCoordinator:self didStartLoad:webView];
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self sfwebView:webView didFailLoadWithError:error];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    if ([self.delegate respondsToSelector:@selector(oauthCoordinator:didFinishLoad:error:)]) {
        [self.delegate oauthCoordinator:self didFinishLoad:webView error:nil];
    }
    if (!self.initialRequestLoaded) {
        self.initialRequestLoaded = YES;
        [self.delegate oauthCoordinator:self didBeginAuthenticationWithView:self.view];
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self sfwebView:webView didFailLoadWithError:error];
}

- (BOOL) isRedirectURL:(NSString *) requestUrlString
{
    return (self.credentials.redirectUri && [[requestUrlString lowercaseString] hasPrefix:[self.credentials.redirectUri lowercaseString]]);
}

- (BOOL) isSPAppRedirectURL:(NSString *)requestUrlString
{
    return (self.spAppCredentials.redirectUri && [[requestUrlString lowercaseString] hasPrefix:[self.spAppCredentials.redirectUri lowercaseString]]);
}

- (void)sfwebView:(WKWebView *)webView didFailLoadWithError:(NSError *)error
{
    
    // Report all errors other than -999 (operation couldn't be completed), which is not catastrophic.
    // Typical errors encountered (many others are possible):
    // WebKitErrorDomain:
    //      -999 The operation couldn't be completed.
    // NSURLErrorDomain:
    //      -999 The operation couldn't be completed.
    //     -1001 The request timed out.
    
    if ([self.delegate respondsToSelector:@selector(oauthCoordinator:didFinishLoad:error:)]) {
        [self.delegate oauthCoordinator:self didFinishLoad:webView error:error];
    }
    
    NSURL *requestUrl = [webView URL];
    NSString *errorUrlString = [NSString stringWithFormat:@"%@://%@%@", [requestUrl scheme], [requestUrl host], [requestUrl relativePath]];
    if (-999 == error.code) {
        // -999 errors (operation couldn't be completed) occur during normal execution, therefore only log for debugging
        [SFSDKCoreLogger d:[self class] format:@"SFOAuthCoordinator:didFailLoadWithError: error code: %ld, description: %@, URL: %@", (long)error.code, [error localizedDescription], errorUrlString];
    } else {
        [SFSDKCoreLogger d:[self class] format:@"SFOAuthCoordinator:didFailLoadWithError: error code: %ld, description: %@, URL: %@", (long)error.code, [error localizedDescription], errorUrlString];
        [self notifyDelegateOfFailure:error authInfo:self.authInfo];
    }
}

#pragma mark - WKUIDelegate
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    if ([self.delegate respondsToSelector:@selector(oauthCoordinator:displayAlertMessage:completion:)]) {
        [self.delegate oauthCoordinator:self displayAlertMessage:message completion:completionHandler];
    } else {
        [SFSDKCoreLogger w:[self class] format:@"WKWebView did want to display an alert but no delegate responded to it"];
    }
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler {
    if ([self.delegate respondsToSelector:@selector(oauthCoordinator:displayAlertMessage:completion:)]) {
        [self.delegate oauthCoordinator:self displayConfirmationMessage:message completion:completionHandler];
    } else {
        [SFSDKCoreLogger w:[self class] format:@"WKWebView did want to display a confirmation alert but no delegate responded to it"];
    }
}

#pragma mark - SFSafariViewControllerDelegate
-(void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    [self.delegate oauthCoordinatorDidCancelBrowserAuthentication:self];
}

- (NSString *)brandedAuthorizeURL{
    NSMutableString *brandedAuthorizeURL = [NSMutableString stringWithFormat:@"%@",kSFOAuthEndPointAuthorize];
    if (self.brandLoginPath && ![self.brandLoginPath isEmptyOrWhitespaceAndNewlines]) {
        NSMutableString *urlString = [NSMutableString stringWithString:self.brandLoginPath];
        // get rid of leading and trailing slash
        if ([urlString hasPrefix:@"/"])
            [urlString deleteCharactersInRange:NSMakeRange(0, 1)];

        if ([urlString hasSuffix:@"/"])
            [urlString deleteCharactersInRange:NSMakeRange(urlString.length - 1, 1)];

        [brandedAuthorizeURL appendFormat:@"/%@",urlString];
    }
    return brandedAuthorizeURL;
}
#pragma mark - Utilities

+ (NSDictionary *)parseQueryString:(NSString *)query {
    return [self parseQueryString:query decodeParams:YES];
}

+ (NSDictionary *)parseQueryString:(NSString *)query decodeParams:(BOOL)decodeParams {
    NSArray *pairs = [query componentsSeparatedByString:@"&"]; // TODO: support semicolon delimiter also
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:pairs.count];
    for (NSString *pair in pairs) {
        NSArray *keyValue = [pair componentsSeparatedByString:@"="];
        NSString *key = keyValue[0];
        NSString *value = keyValue[1];
        if (decodeParams) {
            key = [[key
                    stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByRemovingPercentEncoding];
            value = [[value
                      stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByRemovingPercentEncoding];
        }
        dict[key] = value;
    }
    NSDictionary *result = [NSDictionary dictionaryWithDictionary:dict];
    return result;
}

+ (NSError *)errorWithType:(NSString *)type description:(NSString *)description {
    return [self errorWithType:type description:description underlyingError:nil];
}

+ (NSError *)errorWithType:(NSString *)type description:(NSString *)description underlyingError:(NSError *)underlyingError {
    NSAssert(type, @"error type can't be nil");
    
    NSInteger code = kSFOAuthErrorUnknown;
    if ([type isEqualToString:kSFOAuthErrorTypeAccessDenied]) {
        code = kSFOAuthErrorAccessDenied;
    } else if ([type isEqualToString:kSFOAuthErrorTypeMalformedResponse]) {
        code = kSFOAuthErrorMalformed;
    } else if ([type isEqualToString:KSFOAuthErrorTypeInvalidClientId]) {
        code = kSFOAuthErrorInvalidClientId;
    } else if ([type isEqualToString:kSFOAuthErrorTypeInvalidClient]) {
        code = kSFOAuthErrorInvalidClientCredentials;
    } else if ([type isEqualToString:kSFOAuthErrorTypeInvalidClientCredentials]) {
        code = kSFOAuthErrorInvalidClientCredentials;
    } else if ([type isEqualToString:kSFOAuthErrorTypeInvalidGrant]) {
        code = kSFOAuthErrorInvalidGrant;
    } else if ([type isEqualToString:kSFOAuthErrorTypeInvalidRequest]) {
        code = kSFOAuthErrorInvalidRequest;
    } else if ([type isEqualToString:kSFOAuthErrorTypeInactiveUser]) {
        code = kSFOAuthErrorInactiveUser;
    }  else if ([type isEqualToString:kSFOAuthErrorTypeInactiveOrg]) {
        code = kSFOAuthErrorInactiveOrg;
    }  else if ([type isEqualToString:kSFOAuthErrorTypeRateLimitExceeded]) {
        code = kSFOAuthErrorRateLimitExceeded;
    }  else if ([type isEqualToString:kSFOAuthErrorTypeUnsupportedResponseType]) {
        code = kSFOAuthErrorUnsupportedResponseType;
    } else if ([type isEqualToString:kSFOAuthErrorTypeTimeout]) {
        code = kSFOAuthErrorTimeout;
    } else if ([type isEqualToString:kSFOAuthErrorTypeWrongVersion]) {
        code = kSFOAuthErrorWrongVersion;
    } else if ([type isEqualToString:kSFOAuthErrorTypeBrowserLaunchFailed]) {
        code = kSFOAuthErrorBrowserLaunchFailed;
    } else if ([type isEqualToString:kSFOAuthErrorTypeUnknownAdvancedAuthConfig]) {
        code = kSFOAuthErrorUnknownAdvancedAuthConfig;
    } else if ([type isEqualToString:kSFOAuthErrorTypeJWTLaunchFailed]) {
        code = kSFOAuthErrorJWTInvalidGrant;
    }

    NSMutableDictionary *userInfoDict = [NSMutableDictionary dictionaryWithDictionary:@{kSFOAuthError: type,
                                                                                        NSLocalizedDescriptionKey: description}];
    if (underlyingError != nil) {
        userInfoDict[NSUnderlyingErrorKey] = underlyingError;
    }
    NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain code:code userInfo:userInfoDict];
    return error;
}

// Convert from a Unix timestamp string in milliseconds (returned in the OAuth response) to an NSDate
+ (NSDate *)timestampStringToDate:(NSString *)timestamp {
    NSDate *d = nil;
    if (timestamp != nil) {
        NSTimeInterval unixTimeInSecs = [timestamp longLongValue] / 1000; // convert from millis to secs
        d = [NSDate dateWithTimeIntervalSince1970:unixTimeInSecs];
    }
    return d;
}

@end
