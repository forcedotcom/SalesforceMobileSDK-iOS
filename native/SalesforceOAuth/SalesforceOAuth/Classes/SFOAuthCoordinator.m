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

#import <Security/Security.h>
#import "SFOAuthCredentials+Internal.h"
#import "SFOAuthCoordinator+Internal.h"

// Public constants

const NSTimeInterval kSFOAuthDefaultTimeout                     = 120.0; // seconds
NSString * const     kSFOAuthErrorDomain                        = @"com.salesforce.OAuth.ErrorDomain";

// Private constants

static NSString * const kSFOAuthEndPointAuthorize               = @"/services/oauth2/authorize";    // user agent flow
static NSString * const kSFOAuthEndPointToken                   = @"/services/oauth2/token";        // token refresh flow

static NSString * const kSFOAuthAccessToken                     = @"access_token";
static NSString * const kSFOAuthClientId                        = @"client_id";
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
static NSString * const kSFOAuthIssuedAt                        = @"issued_at";
static NSString * const kSFOAuthRedirectUri                     = @"redirect_uri";
static NSString * const kSFOAuthRefreshToken                    = @"refresh_token";
static NSString * const kSFOAuthResponseType                    = @"response_type";
static NSString * const kSFOAuthResponseTypeToken               = @"token";
static NSString * const kSFOAuthSignature                       = @"signature";

// Used for the IP bypass flow
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

static NSUInteger kSFOAuthReponseBufferLength                   = 512; // bytes

static NSString * const kHttpMethodPost                         = @"POST";
static NSString * const kHttpHeaderContentType                  = @"Content-Type";
static NSString * const kHttpPostContentType                    = @"application/x-www-form-urlencoded";


@implementation SFOAuthCoordinator

@synthesize credentials          = _credentials;
@synthesize delegate             = _delegate;
@synthesize timeout              = _timeout;
@synthesize view                 = _view;

// private

@synthesize authenticating       = _authenticating;
@synthesize connection           = _connection;
@synthesize responseData         = _responseData;
@synthesize initialRequestLoaded = _initialRequestLoaded;
@synthesize approvalCode         = _approvalCode;
@synthesize scopes               = _scopes;

- (id)init {
    SFOAuthCredentials *credentials = [[[SFOAuthCredentials alloc] init] autorelease];
    return [self initWithCredentials:credentials];
}

- (id)initWithCredentials:(SFOAuthCredentials *)credentials {
    self = [super init];
    if (self) {
        NSAssert(credentials != nil, @"credentials cannot be nil");
        self.credentials = credentials;
        self.authenticating = NO;
        _timeout = kSFOAuthDefaultTimeout;
        _view = nil;
    }
    
    // response data init'd in didReceiveResponse
    
    return self;
}

- (void)dealloc {
    self.credentials        = nil;
    self.connection         = nil;
    self.responseData       = nil;
    self.approvalCode       = nil;
    
    _view.delegate = nil;
    [_view release]; _view = nil;
    
    [super dealloc];
}

- (void)authenticate {
    NSAssert(nil != self.delegate, @"authenticate with nil delegate");
    if (self.authenticating) {
        NSLog(@"SFOAuthCoordinator:authenticate: Error: authenticate called while already authenticating. Call stopAuthenticating first.");
        return;
    }
    if (self.credentials.logLevel < kSFOAuthLogLevelWarning) {
        NSLog(@"SFOAuthCoordinator:authenticate: authenticating as %@ %@ refresh token on '%@://%@' ...", 
              self.credentials.clientId, (nil == self.credentials.refreshToken ? @"without" : @"with"), 
              self.credentials.protocol, self.credentials.domain);
    }
    
    self.authenticating = YES;
    
    // TODO: reachability
    
    if (self.credentials.refreshToken) {
        // clear any access token we may have and begin refresh flow
        [self.credentials revokeAccessToken];
        [self beginTokenRefreshFlow];
    } else {
        [self beginUserAgentFlow];
    }
}

- (BOOL)isAuthenticating {
    return self.authenticating;
}

- (void)stopAuthentication {
    [_view stopLoading];
    [self.connection cancel];
    self.connection = nil;
    self.authenticating = NO;
}

- (void)revokeAuthentication {
    [self stopAuthentication];
    [self.credentials revoke];
}

#pragma mark - Private Methods

- (void)beginUserAgentFlow {
    
    if (nil == _view) {
        // lazily create web view if needed
        _view = [[UIWebView  alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    }
    _view.delegate = self;
    
    self.initialRequestLoaded = NO;
    
    // notify delegate will be begin authentication in our (web) vew
    if ([self.delegate respondsToSelector:@selector(oauthCoordinator:willBeginAuthenticationWithView:)]) {
        [self.delegate oauthCoordinator:self willBeginAuthenticationWithView:_view];
    }
    
    // optional query params: 
    //     state - opaque state value to be passed back
    //     immediate - determines whether the user should be prompted for login and approval (default false)
    
    NSAssert(nil != self.credentials.domain, @"credentials.domain is required");
    NSAssert(nil != self.credentials.clientId, @"credentials.clientId is required");
    NSAssert(nil != self.credentials.redirectUri, @"credentials.redirectUri is required");

    NSMutableString *approvalUrl = [[NSMutableString alloc] initWithFormat:@"%@://%@%@?%@=%@&%@=%@&%@=%@",
                                    self.credentials.protocol, self.credentials.domain, kSFOAuthEndPointAuthorize,
                                    kSFOAuthClientId, self.credentials.clientId,
                                    kSFOAuthRedirectUri, self.credentials.redirectUri,
                                    kSFOAuthDisplay, kSFOAuthDisplayTouch];

    // If an activation code is available (IP bypass flow), then use the "activated client" response type.
    if (self.credentials.activationCode) {
        [approvalUrl appendFormat:@"&%@=%@", kSFOAuthResponseType, kSFOAuthResponseTypeActivatedClientCode];
    } else {
        [approvalUrl appendFormat:@"&%@=%@", kSFOAuthResponseType, kSFOAuthResponseTypeToken];        
    }
        
    if ([self.scopes count] > 0) {
        //append scopes
        [approvalUrl appendString:@"&scope="];
        NSMutableString *scopeStr = [[NSMutableString alloc] initWithFormat:@"refresh_token"];

        //stringByAddingPercentEscapesUsingEncoding
        for (NSString *scope in self.scopes) {
            if (![scope isEqualToString:@"refresh_token"]) {
                [scopeStr appendFormat:@" %@",scope];
            }
        }
        
        NSString *finalScopeStr = [scopeStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [scopeStr release];
        [approvalUrl appendString:finalScopeStr];
    }
    
    if (self.credentials.logLevel < kSFOAuthLogLevelInfo) {
        NSLog(@"SFOAuthCoordinator:beginUserAgentFlow with %@", approvalUrl);
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:approvalUrl]];
	[request setHTTPShouldHandleCookies:NO]; // don't use shared cookies
	[approvalUrl release];
	
	[_view loadRequest:request];
}

- (void)beginTokenRefreshFlow {
    
    self.responseData = [NSMutableData dataWithLength:512];
    NSString *url = [[NSString alloc] initWithFormat:@"%@://%@%@", 
                                                     self.credentials.protocol, 
                                                     self.credentials.domain, 
                                                     kSFOAuthEndPointToken];
	
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url] 
                                                                cachePolicy:NSURLRequestReloadIgnoringCacheData 
                                                            timeoutInterval:self.timeout];
	[request setHTTPMethod:kHttpMethodPost];
	[request setValue:kHttpPostContentType forHTTPHeaderField:kHttpHeaderContentType];
	[request setTimeoutInterval:self.timeout];
    [request setHTTPShouldHandleCookies:NO];
	[url release];
    
    NSMutableString *params = [[NSMutableString alloc] initWithFormat:@"%@=%@&%@=%@&%@=%@",
                                                                      kSFOAuthFormat, kSFOAuthFormatJson,
                                                                      kSFOAuthRedirectUri, self.credentials.redirectUri,
                                                                      kSFOAuthClientId, self.credentials.clientId];
    NSMutableString *logString = [NSMutableString stringWithString:params];
    
    // If an activation code is available (IP bypass flow), then provide the activation code in the request
    if (self.credentials.activationCode) {
        [params appendFormat:@"&%@=%@", kSFOAuthResponseClientSecret, self.credentials.activationCode];
    }

    // If there is an approval code (IP bypass flow), use it once to get the refresh token.
    if (self.approvalCode) {
        [params appendFormat:@"&%@=%@&%@=%@", kSFOAuthGrantType, kSFOAuthGrantTypeAuthorizationCode, kSFOAuthApprovalCode, self.approvalCode];
        [logString appendFormat:@"&%@=%@&%@=REDACTED", kSFOAuthGrantType, kSFOAuthGrantTypeAuthorizationCode, kSFOAuthApprovalCode];
        // Discard the approval code.
        self.approvalCode = nil;
    } else {
        [params appendFormat:@"&%@=%@&%@=%@", kSFOAuthGrantType, kSFOAuthGrantTypeRefreshToken, kSFOAuthRefreshToken, self.credentials.refreshToken];
        [logString appendFormat:@"&%@=%@&%@=REDACTED", kSFOAuthGrantType, kSFOAuthGrantTypeRefreshToken, kSFOAuthRefreshToken];
    }
	
    if (self.credentials.logLevel < kSFOAuthLogLevelInfo) {
        NSLog(@"SFOAuthCoordinator:beginTokenRefreshFlow with %@", logString);
    }

	NSData *encodedBody = [params dataUsingEncoding:NSUTF8StringEncoding];
	[params release];
	
	[request setHTTPBody:encodedBody];
	NSURLConnection *urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    self.connection = urlConnection;
	[request release];
    [urlConnection release];
}

/* Handle a 'token refresh flow' response.
    Example response:
    { "id":"https://login.salesforce.com/id/00DD0000000FH54SBH/005D0000001GZXmIAO",
      "issued_at":"1309481030001",
      "instance_url":"https://na1.salesforce.com",
      "signature":"YEguoQhgIvJ3apLALB93vRsq/pUxwG2klsyHp9zX9Wg=",
      "access_token":"00DD0000000FH84!AQwAQKS7WDhWO9k6YrhbiWBZiDAZC5RzN2dpleOKGKf5dFsatyAN8kck7mtrNvxRGIgN.wE.Z0ZN_No7h6HNqrq828nL6E2J" }
    
    Example error response:
        { "error":"invalid_grant","error_description":"authentication failure - Invalid Password" }
 */
- (void)handleRefreshResponse {
    NSString *responseString = [[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding];
    NSError * jsonError = nil;
    id json = nil;

    Class NSJSONClass = NSClassFromString(@"NSJSONSerialization");
    Class SBJSONClass = NSClassFromString(@"SBJsonParser");
    if (nil != NSJSONClass) {
        json = [NSJSONClass JSONObjectWithData:self.responseData options:0 error:&jsonError];
    } else if (nil != SBJSONClass) {
        id parser = [[SBJSONClass alloc] init];
        
        // older versions of the SBJSON library implement objectWithString instead of objectWithData
        // therefore we try objectWithData first and fallback to objectWithString
        
        SEL selectorObjectWithData = @selector(objectWithData:);
        SEL selectorObjectWithString = @selector(objectWithString:);
        if ([parser respondsToSelector:selectorObjectWithData]) {
            json = [parser performSelector:selectorObjectWithData withObject:self.responseData];
        } else if ([parser respondsToSelector:selectorObjectWithString]) {
            json = [parser performSelector:selectorObjectWithString withObject:responseString];
        }
        if (!json) {
            SEL selectorError = @selector(error);
            if ([parser respondsToSelector:selectorError]) {
                jsonError = [parser performSelector:selectorError];
            }
        }
        [parser release];
    } else {
        NSLog(@"Both SBJsonParser and NSJSONSerialization are missing");
        NSAssert(NO,@"Either SBJsonParser or NSJSONSerialization must be available!");
    }
    
    if (nil == jsonError && [json isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)json;
        if (nil != [dict objectForKey:kSFOAuthError]) {
            NSError *error = [[self class] errorWithType:[dict objectForKey:kSFOAuthError] description:[dict objectForKey:kSFOAuthErrorDescription]];
            [self.delegate oauthCoordinator:self didFailWithError:error];
        } else {
            if ([dict objectForKey:kSFOAuthRefreshToken]) {
                // Refresh token is available. This happens when the IP bypass flow is used.
                self.credentials.refreshToken = [dict objectForKey:kSFOAuthRefreshToken];
            } else {
                // In a non-IP flow, we already have the refresh token here.
            }
            self.credentials.identityUrl    = [NSURL URLWithString:[dict objectForKey:kSFOAuthId]];
            self.credentials.accessToken    = [dict objectForKey:kSFOAuthAccessToken];
            self.credentials.instanceUrl    = [NSURL URLWithString:[dict objectForKey:kSFOAuthInstanceUrl]];
            self.credentials.issuedAt       = [[self class] timestampStringToDate:[dict objectForKey:kSFOAuthIssuedAt]];
                        
            [self.delegate oauthCoordinatorDidAuthenticate:self];
        }
    } else {
        // failed to parse JSON
        NSLog(@"JSON parse error: %@",jsonError);
        NSError *error = [[self class] errorWithType:kSFOAuthErrorTypeMalformedResponse description:@"failed to parse response JSON"];
        NSMutableDictionary *errorDict = [NSMutableDictionary dictionaryWithDictionary:jsonError.userInfo];
        if (responseString) {
            [errorDict setObject:responseString forKey:@"response_data"];
        }
        if (error) {
            [errorDict setObject:error forKey:NSUnderlyingErrorKey];
        }
        NSError *finalError = [NSError errorWithDomain:kSFOAuthErrorDomain code:error.code userInfo:errorDict];
        [self.delegate oauthCoordinator:self didFailWithError:finalError];
    }
    [responseString release];
    self.authenticating = NO;
}

#pragma mark - UIWebViewDelegate (User-Agent Token Flow)

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    if (self.credentials.logLevel < kSFOAuthLogLevelWarning) {
        NSLog(@"SFOAuthCoordinator:webView:shouldStartLoadWithRequest: (navType=%u): host=%@ : path=%@", 
              navigationType, request.URL.host, request.URL.path);
    }
    
    BOOL result = YES;
    NSURL *requestUrl = [request URL];
    NSString *requestUrlString = [requestUrl absoluteString];

    if ([requestUrlString hasPrefix:self.credentials.redirectUri]) {
        
        result = NO; // we're finished, don't load this request
        NSString *response = nil;
        
        // Check for a response in the URL fragment first, then fall back to the query string.
        
        if ([requestUrl fragment]) {
            response = [requestUrl fragment];
        } else if ([requestUrl query]) {
            response = [requestUrl query];
        } else {
            NSLog(@"SFOAuthCoordinator:webView:shouldStartLoadWithRequest: Error: response has no payload: %@", requestUrlString);
            
            NSError *error = [[self class] errorWithType:kSFOAuthErrorTypeMalformedResponse description:@"redirect response has no payload"];
            [self.delegate oauthCoordinator:self didFailWithError:error];
            response = nil;
        }
        
        if (response) {            
            NSDictionary *params = [[self class] parseQueryString:response];
            NSString *error = [params objectForKey:kSFOAuthError];
            if (nil == error) {
                self.credentials.identityUrl    = [NSURL URLWithString:[params objectForKey:kSFOAuthId]];
                self.credentials.accessToken    = [params objectForKey:kSFOAuthAccessToken];
                self.credentials.refreshToken   = [params objectForKey:kSFOAuthRefreshToken];
                self.credentials.instanceUrl    = [NSURL URLWithString:[params objectForKey:kSFOAuthInstanceUrl]];
                self.credentials.issuedAt       = [[self class] timestampStringToDate:[params objectForKey:kSFOAuthIssuedAt]];
                                
                self.approvalCode = [params objectForKey:kSFOAuthApprovalCode];
                if (self.approvalCode) {
                    // If there is an approval code, then proceed to get the access/refresh token (IP bypass flow).
                    [self beginTokenRefreshFlow];
                } else {
                    // Otherwise, we are done with the authentication.
                    [self.delegate oauthCoordinatorDidAuthenticate:self];                    
                }
            } else {
                NSError *finalError;
                NSError *error = [[self class] errorWithType:[params objectForKey:kSFOAuthError] 
                                                 description:[params objectForKey:kSFOAuthErrorDescription]];
                
                // add any additional relevant info to the userInfo dictionary
                
                if (kSFOAuthErrorInvalidClientId == error.code) {
                    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:error.userInfo];
                    [dict setObject:self.credentials.clientId forKey:kSFOAuthClientId];
                    finalError = [NSError errorWithDomain:error.domain code:error.code userInfo:dict];
                } else {
                    finalError = error;
                }
                [self.delegate oauthCoordinator:self didFailWithError:finalError];
            }
        }
        self.authenticating = NO;
	}
    
    return result;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    NSURL *url = webView.request.URL;
    
    if (self.credentials.logLevel < kSFOAuthLogLevelWarning) {
        NSLog(@"SFOAuthCoordinator:webViewDidStartLoad: host=%@ : path=%@", url.host, url.path);
    }
    
    if ([self.delegate respondsToSelector:@selector(oauthCoordinator:didStartLoad:)]) {
        [self.delegate oauthCoordinator:self didStartLoad:webView];        
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if ([self.delegate respondsToSelector:@selector(oauthCoordinator:didFinishLoad:error:)]) {
        [self.delegate oauthCoordinator:self didFinishLoad:webView error:nil];
    }
    if (!self.initialRequestLoaded) {
        self.initialRequestLoaded = YES;
        [self.delegate oauthCoordinator:self didBeginAuthenticationWithView:self.view];
        NSAssert((nil != [self.view superview]), @"No superview for oauth web view after didBeginAuthenticationWithView");
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    
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

    if (-999 == error.code) { 
        // -999 errors (operation couldn't be completed) occur during normal execution, therefore only log for debugging
        if (self.credentials.logLevel < kSFOAuthLogLevelInfo) {
            NSLog(@"SFOAuthCoordinator:didFailLoadWithError: %@ on URL: %@", error, webView.request.URL);
        }
    } else {
        NSLog(@"SFOAuthCoordinator:didFailLoadWithError %@ on URL: %@", error, webView.request.URL);
        [self.delegate oauthCoordinator:self didFailWithError:error];
        self.authenticating = NO;
    }
}

#pragma mark - NSURLConnectionDelegate (Refresh Token Flow)

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	NSLog(@"SFOAuthCoordinator:connection:didFailWithError: %@", error);
    
    [self.delegate oauthCoordinator:self didFailWithError:error];
    self.authenticating = NO;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection 
             willSendRequest:(NSURLRequest *)request 
            redirectResponse:(NSURLResponse *)response {
    
	if (nil != response) {
        if (![[request HTTPMethod] isEqualToString:kHttpMethodPost]) {
            // convert the request to a post method if necessary
            NSMutableURLRequest *newRequest = [request mutableCopy];
            [newRequest setHTTPMethod:kHttpMethodPost];
            request = [newRequest autorelease];
        }
	}
	return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	// reset the response data for a new refresh response
    self.responseData = [NSMutableData dataWithCapacity:kSFOAuthReponseBufferLength];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[self.responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[self handleRefreshResponse];
}

#pragma mark - Utilities

+ (NSDictionary *)parseQueryString:(NSString *)query {
    NSArray *pairs = [query componentsSeparatedByString:@"&"]; // TODO: support semicolon delimiter also
	NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:pairs.count];
	for (NSString *pair in pairs) {
        NSArray *keyValue = [pair componentsSeparatedByString:@"="];
		NSString *key = [[keyValue objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		NSString *value = [[keyValue objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		[dict setObject:value forKey:key];
	}
	NSDictionary *result = [NSDictionary dictionaryWithDictionary:dict];
	[dict release];
	return result;
}

+ (NSError *)errorWithType:(NSString *)type description:(NSString *)description {
    NSAssert(type, @"error type can't be nil");
    
    NSString *localized = [NSString stringWithFormat:@"%@ %@ : %@", kSFOAuthErrorDomain, type, description];
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
    }
    
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:type,        kSFOAuthError,
                                                                    description, kSFOAuthErrorDescription,
                                                                    localized,   NSLocalizedDescriptionKey,
                                                                    nil];
    NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain code:code userInfo:dict];
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
