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
#import "SFSDKURLHandlerManager.h"
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import <SalesforceSDKCommon/SFJsonUtils.h>
#import "SFSDKOAuth2+Internal.h"
#import "SFSDKOAuthConstants.h"
#import "SFSDKAuthSession.h"
#import "SFSDKAuthRequest.h"
@interface SFOAuthCoordinator()

@property (nonatomic) NSString *networkIdentifier;

@end

@implementation SFOAuthCoordinator

@synthesize credentials          = _credentials;
@synthesize delegate             = _delegate;
@synthesize timeout              = _timeout;
@synthesize view                 = _view;
@synthesize asWebAuthenticationSession = _asWebAuthenticationSession;

// private

@synthesize authenticating              = _authenticating;
@synthesize session                     = _session;
@synthesize responseData                = _responseData;
@synthesize initialRequestLoaded        = _initialRequestLoaded;
@synthesize approvalCode                = _approvalCode;
@synthesize scopes                      = _scopes;
@synthesize advancedAuthState           = _advancedAuthState;
@synthesize codeVerifier                = _codeVerifier;
@synthesize authInfo                    = _authInfo;
@synthesize userAgentForAuth            = _userAgentForAuth;
@synthesize origWebUserAgent            = _origWebUserAgent;


- (id)init {
    return [self initWithCredentials:nil];
}

- (id)initWithCredentials:(SFOAuthCredentials *)credentials {
    self = [super init];
    if (self) {
        self.credentials = credentials;
        self.authenticating = NO;
        _timeout = kSFOAuthDefaultTimeout;
        _view = nil;
        _authClient = [[SFSDKOAuth2 alloc] init];
    }
    return self;
}

- (instancetype)initWithAuthSession:(SFSDKAuthSession *)authSession {
    self = [super init];
    if (self) {
        self.authSession = authSession;
        self.credentials = authSession.credentials;
        self.authenticating = NO;
        _timeout = kSFOAuthDefaultTimeout;
        _view = nil;
        _authClient = [[SFSDKOAuth2 alloc] init];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [SFNetwork removeSharedInstanceForIdentifier:self.networkIdentifier];
    self.networkIdentifier = nil;
    _approvalCode = nil;
    _session = nil;
    _credentials = nil;
    _responseData = nil;
    _scopes = nil;
    _view = nil;
    _authSession = nil;
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
        [self beginTokenEndpointFlow:SFOAuthTokenEndpointFlowRefresh];
    } else if (self.credentials.jwt) {
        // JWT token existence means we're doing JWT token exchange.
        self.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeJwtTokenExchange];
        [self notifyDelegateOfBeginAuthentication];
        [self beginJwtTokenExchangeFlow];
    } else {
        __weak typeof(self) weakSelf = self;
        if (self.useBrowserAuth) {
            [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureSafariBrowserForLogin];
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                strongSelf.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeAdvancedBrowser];
                [strongSelf notifyDelegateOfBeginAuthentication];
                [strongSelf beginNativeBrowserFlow];
            });
        } else {
            [SFSDKAuthConfigUtil getMyDomainAuthConfig:^(SFOAuthOrgAuthConfiguration *authConfig, NSError *error) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Ignore any errors why retrieving authconfig. Default to WKWebView
                    // Errors should have already been logged.
                    if (authConfig.useNativeBrowserForAuth) {
                         [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureSafariBrowserForLogin];
                        strongSelf.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeAdvancedBrowser];
                        [strongSelf notifyDelegateOfBeginAuthentication];
                        [strongSelf beginNativeBrowserFlow];
                    } else {
                        [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureSafariBrowserForLogin];
                        [strongSelf notifyDelegateOfBeginAuthentication];
                        [strongSelf beginUserAgentFlow];
                    }
                });
            } loginDomain:self.credentials.domain];
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
    self.networkIdentifier = nil;
    
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
        [self beginTokenEndpointFlow:SFOAuthTokenEndpointFlowAdvancedBrowser];
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
    NSDictionary *queryDict = [SFSDKOAuth2 parseQueryString:query decodeParams:NO];
    NSString *codeVal = queryDict[kSFOAuthResponseTypeCode];
    if ([codeVal length] == 0) {
        [SFSDKCoreLogger i:[self class] format:@"%@ URL has no '%@' parameter value.", NSStringFromSelector(_cmd), kSFOAuthResponseTypeCode];
        return NO;
    }
    self.approvalCode = codeVal;
    [SFSDKCoreLogger i:[self class] format:@"%@ Received advanced authentication response.  Beginning token exchange.", NSStringFromSelector(_cmd)];
    self.advancedAuthState = SFOAuthAdvancedAuthStateTokenRequestInitiated;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self beginTokenEndpointFlow:SFOAuthTokenEndpointFlowAdvancedBrowser];
    });
    return YES;
}

#pragma mark - Properties

- (WKWebView *)view {
    if (_view == nil) {
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        config.processPool = SFSDKWebViewStateManager.sharedProcessPool;
        UIWindowScene *scene = (UIWindowScene *)self.authSession.oauthRequest.scene;
        CGRect viewBounds = scene? scene.coordinateSpace.bounds : [UIScreen mainScreen].bounds;
        _view = [[WKWebView alloc] initWithFrame:viewBounds configuration:config];
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
        dispatch_async(dispatch_get_main_queue(), ^{
           [self.delegate oauthCoordinator:self didFailWithError:error authInfo:info];
        });
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
    __weak typeof(self) weakSelf = self;
    _asWebAuthenticationSession = [[ASWebAuthenticationSession alloc] initWithURL:nativeBrowserUrl callbackURLScheme:[NSURL URLWithString:self.credentials.redirectUri].scheme completionHandler:^(NSURL *callbackURL, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!error && [[SFSDKURLHandlerManager sharedInstance] canHandleRequest:callbackURL options:nil]) {
            NSDictionary *options = @{kSFIDPSceneIdKey : self.authSession.sceneId};
            [[SFSDKURLHandlerManager sharedInstance] processRequest:callbackURL options:options];
        } else {
            [strongSelf.delegate oauthCoordinatorDidCancelBrowserAuthentication:strongSelf];
        }
    }];
    _asWebAuthenticationSession.prefersEphemeralWebBrowserSession = [SalesforceSDKManager sharedManager].useEphemeralSessionForAdvancedAuth;
    [self.delegate oauthCoordinator:self didBeginAuthenticationWithSession:_asWebAuthenticationSession];
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
    [self loadWebViewWithUrlString:approvalUrlString cookie:YES];
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
        id json = nil;
        json = [SFJsonUtils objectFromJSONData:data];
        if (json == nil) {
            NSError *error = [SFSDKOAuth2 errorWithType:kSFOAuthErrorTypeJWTLaunchFailed
                                                 description:@"Error parsing JWT token exchange response."
                                             underlyingError:[SFJsonUtils lastError]];
                [self notifyDelegateOfFailure:error authInfo:self.authInfo];
            return;
        }
        if (![json isKindOfClass:[NSDictionary class]]) {
            NSString *errorDesc = [NSString stringWithFormat:@"Expected NSDictionary for JWT token response, received %@ instance.", NSStringFromClass([json class])];
                NSError *error = [SFSDKOAuth2 errorWithType:kSFOAuthErrorTypeJWTLaunchFailed
                                                 description:errorDesc];
            [self notifyDelegateOfFailure:error authInfo:self.authInfo];
            return;
        }
        NSDictionary *dict = (NSDictionary *)json;
        if (nil != dict[kSFOAuthError]) {
            NSError *error = [SFSDKOAuth2 errorWithType:dict[kSFOAuthError] description:dict[kSFOAuthErrorDescription]];
            [self notifyDelegateOfFailure:error authInfo:self.authInfo];
            return;
        }
        [self.credentials updateCredentials:dict];
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
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:self.timeout];
    NSString *grantType = @"urn:ietf:params:oauth:grant-type:jwt-bearer";
    NSString *bodyStr = [[@"grant_type=" stringByAppendingString:[grantType stringByURLEncoding]] stringByAppendingString:[NSString stringWithFormat:@"&assertion=%@", self.credentials.jwt]];
    NSData *body = [bodyStr dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:body];
    [request setHTTPMethod:kHttpMethodPost];
    [request setValue:kHttpPostContentType forHTTPHeaderField:kHttpHeaderContentType];
    
    [[self.session dataTaskWithRequest:request completionHandler:completionHandler] resume];
}

// IDP related
- (void)beginIDPFlow {
    self.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeIDP];
    self.initialRequestLoaded = NO;
    // notify delegate will be begin authentication in our (web) vew
    if (self.credentials.accessToken && self.credentials.apiUrl) {
        NSString *baseUrlString = [self.credentials.apiUrl absoluteString];
        NSString *approvalUrlString = [self generateCodeApprovalUrlString:self.spAppCredentials];
        NSString *codeChallengeString = self.spAppCredentials.challengeString;
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
- (void)updateCredentials:(NSDictionary *) params {
    [self.credentials updateCredentials:params];
}

- (void)beginTokenEndpointFlow:(SFOAuthTokenEndpointFlow)flowType {
    self.responseData = [NSMutableData dataWithLength:512];
    SFSDKOAuthTokenEndpointRequest *request = [[SFSDKOAuthTokenEndpointRequest alloc] init];
    request.additionalOAuthParameterKeys = self.additionalOAuthParameterKeys;
    request.additionalTokenRefreshParams = self.additionalTokenRefreshParams;
    request.clientID = self.credentials.clientId;
    request.refreshToken = self.credentials.refreshToken;
    request.redirectURI = self.credentials.redirectUri;
    request.serverURL = [self.credentials overrideDomainIfNeeded];
    request.userAgentForAuth = self.userAgentForAuth;
     __weak typeof (self) weakSelf = self;
    if (self.approvalCode) {
        [SFSDKCoreLogger i:[self class] format:@"%@: Initiating authorization code flow.", NSStringFromSelector(_cmd)];
        request.approvalCode = self.approvalCode;
        request.codeVerifier = self.codeVerifier;
        [self.authClient accessTokenForApprovalCode:request completion:^(SFSDKOAuthTokenEndpointResponse * response) {
             __strong typeof (weakSelf) strongSelf = weakSelf;
            [strongSelf handleResponse:response];
        }];
    } else {
        // Assumes refresh token flow.
        [SFSDKCoreLogger i:[self class] format:@"%@: Initiating refresh token flow.", NSStringFromSelector(_cmd)];
        [self.authClient accessTokenForRefresh:request  completion:^(SFSDKOAuthTokenEndpointResponse * response) {
            __strong typeof (weakSelf) strongSelf = weakSelf;
            [SFSDKEventBuilderHelper createAndStoreEvent:@"tokenRefresh" userAccount:[SFUserAccountManager sharedInstance].currentUser className:NSStringFromClass([strongSelf class]) attributes:nil];
            [strongSelf handleResponse:response];
        }];
    }
}
         
- (void)handleResponse:(SFSDKOAuthTokenEndpointResponse *)response {
     if (!response.hasError) {
          [self.credentials updateCredentials:[response asDictionary]];
          if (response.additionalOAuthFields)
            self.credentials.additionalOAuthFields = response.additionalOAuthFields;
          [self notifyDelegateOfSuccess:self.authInfo];
     } else {
         if (response.error.error) {
             if (response.error.error.code == NSURLErrorTimedOut) {
                 [SFSDKCoreLogger d:[self class] format:@"Refresh attempt timed out after %f seconds.", self.timeout];
                 [self stopAuthentication];
             }
             [self notifyDelegateOfFailure:response.error.error authInfo:self.authInfo];
             self.responseData = [NSMutableData dataWithCapacity:kSFOAuthReponseBufferLength];
         }
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
        error = [SFSDKOAuth2 errorWithType:kSFOAuthErrorTypeMalformedResponse description:@"IDP Authcode redirect response encountered an ec=301 or 302 redirect"];
    } else if (errorCode) {
        error = [SFSDKOAuth2 errorWithType:errorCode description:errorDescription];
    } else if (![requestUrl fragment] && ![requestUrl query]){
        [SFSDKCoreLogger d:[self class] format:@"%@ Error: IDP Authcode response has no payload: %@", NSStringFromSelector(_cmd), requestUrl];
        error = [SFSDKOAuth2 errorWithType:kSFOAuthErrorTypeMalformedResponse description:@"IDP Authcode redirect response has no payload"];
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
        NSDictionary *params = [SFSDKOAuth2 parseQueryString:response decodeParams:NO];
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
        NSError *error = [SFSDKOAuth2 errorWithType:kSFOAuthErrorTypeMalformedResponse description:@"redirect response has no payload"];
        [self notifyDelegateOfFailure:error authInfo:self.authInfo];
        response = nil;
    }
    if (response) {
        NSDictionary *params = [SFSDKOAuth2 parseQueryString:response];
        NSString *error = params[kSFOAuthError];
        if (nil == error) {
            [self.credentials updateCredentials:params];
            self.credentials.refreshToken   = params[kSFOAuthRefreshToken];
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
            [self notifyDelegateOfSuccess:self.authInfo];
        } else {
            NSError *finalError;
            NSError *error = [SFSDKOAuth2 errorWithType:params[kSFOAuthError]
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
    
    [approvalUrlString appendFormat:@"&%@=%@", kSFOAuthResponseType, kSFOAuthResponseTypeHybridToken];
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
        self.networkIdentifier = [SFNetwork uniqueInstanceIdentifier];
        SFNetwork *network = [SFNetwork sharedEphemeralInstanceWithIdentifier:self.networkIdentifier];
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

@end
