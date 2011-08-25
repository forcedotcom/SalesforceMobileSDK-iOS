//
//  SFOAuthCoordinator.h
//  SalesforceOAuth
//
//  Created by Steve Holly on 17/06/2011.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

// TODO:
// - handle setting credentials property during authentication
// - detect when the web view loads an oauth error document

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
//static NSString * const kSFOAuthResponseTypeActivatedClientCode = @"activated_client_code"; // used for the old email flow

// OAuth Error Descriptions
// see https://eu1.salesforce.com/help/doc/en/remoteaccess_oauth_refresh_token_flow.htm

static NSString * const kSFOAuthErrorTypeMalformedResponse          = @"malformed_response";
static NSString * const kSFOAuthErrorTypeAccessDenied               = @"access_denied";
static NSString * const KSFOAuthErrorTypeInvalidClientId            = @"invalid_client_id"; // invalid_client_id:'client identifier invalid'
                                                                                            // this may be returned when the refresh token is revoked
                                                                                            // TODO: needs clarification
static NSString * const kSFOAuthErrorTypeInvalidClient              = @"invalid_client";    // invalid_client:'invalid client credentials'
                                                                                            // this is returned when refresh token is revoked on core
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
@synthesize userAgentFlowTimer   = _userAgentFlowTimer;


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
    
    [self.userAgentFlowTimer invalidate];
    self.userAgentFlowTimer = nil;
    
    _view.delegate = nil;
    [_view release]; _view = nil;
    
    [super dealloc];
}

- (void)authenticate {
    NSAssert(nil != self.delegate, @"authenticate with nil delegate");
    if (self.authenticating) {
        NSLog(@"SFOAuthCoordinator:authenticate: Warning: authenticate called while already authenticating. Call stopAuthenticating first.");
        return;
    }
    NSLog(@"SFOAuthCoordinator:authenticate: authenticating %@ refresh token on '%@://%@' ...", 
          (nil == self.credentials.refreshToken ? @"without" : @"with"), self.credentials.protocol, self.credentials.domain);
    
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
    [self stopUserAgentFlowTimer];
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
    if ([self.delegate respondsToSelector:@selector(willBeginAuthenticationWithView:)]) {
        [self.delegate oauthCoordinator:self willBeginAuthenticationWithView:_view];
    }
    
    // optional query params: 
    //     state - opaque state value to be passed back
    //     immediate - determines whether the user should be prompted for login and approval (default false)
    
    // TODO: retrieve approvalUrl from credentials object
    
    NSAssert(nil != self.credentials.domain,@"credentials.domain is required");
    NSAssert(nil != self.credentials.clientId,@"credentials.clientId is required");
    NSAssert(nil != self.credentials.redirectUri,@"credentials.redirectUri is required");

    NSString *approvalUrl = [[NSString alloc] initWithFormat:@"%@://%@%@?%@=%@&%@=%@&%@=%@&%@=%@",
                             self.credentials.protocol, self.credentials.domain, kSFOAuthEndPointAuthorize,
                             kSFOAuthResponseType, kSFOAuthResponseTypeToken,
                             kSFOAuthDisplay, kSFOAuthDisplayTouch,
                             kSFOAuthClientId, self.credentials.clientId,
                             kSFOAuthRedirectUri, self.credentials.redirectUri];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:approvalUrl]];
	[request setHTTPShouldHandleCookies:NO]; // don't use shared cookies
	[approvalUrl release];
	
	[_view loadRequest:request];
    [self startUserAgentFlowTimer];
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
    
    // TODO: approval code: "grant_type=authorization_code&code=%@"
    
    [params appendFormat:@"&%@=%@&%@=%@", kSFOAuthGrantType, kSFOAuthGrantTypeRefreshToken, kSFOAuthRefreshToken, self.credentials.refreshToken];
	
	
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
        {"id":"https://login-blitz02.soma.salesforce.com/id/00DD0000000FH84MAG/005D0000001GZXmIAO",
         "issued_at":"1309481030001",
         "instance_url":"https://na1-blitz02.soma.salesforce.com",
         "signature":"YEguoQhgIvJ3apLALB93vRsq/pUxwG2klsyHp9zX9Wg=",
         "access_token":"00DD0000000FH84!AQwAQKS7WDhWO9k6YrhbiWBZiDAZC5RzN2dpleOKGKf5dFsatyAN8kck7mtrNvxRGIgN.wE.Z0ZN_No7h6HNqrq828nL6E2J"}
    
    Example error response:
        {"error":"invalid_grant","error_description":"authentication failure - Invalid Password"}
 */
- (void)handleRefreshResponse {
    NSString *responseString = [[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding];
    NSError * error = nil;
    id json = nil;
    
#if SFOAUTH_LOG_TOKENS
    NSLog(@"SFOAuthCoordinator:receivedRefreshResponse: %@", responseString);
#endif

    Class NSJSONClass = NSClassFromString(@"NSJSONSerialization");
    Class SBJSONClass = NSClassFromString(@"SBJsonParser");
    if (nil != NSJSONClass) {
        json = [NSJSONClass JSONObjectWithData:self.responseData options:0 error:&error];
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
                error = [parser performSelector:selectorError];
            }
        }
        [parser release];
    }
    if (nil == error && [json isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)json;
        if (nil != [dict objectForKey:kSFOAuthError]) {
            NSError *error = [[self class] errorWithType:[dict objectForKey:kSFOAuthError] description:[dict objectForKey:kSFOAuthErrorDescription]];
            [self.delegate oauthCoordinator:self didFailWithError:error];
        } else {
            // we already have the refresh token
            self.credentials.identityUrl    = [NSURL URLWithString:[dict objectForKey:kSFOAuthId]];
            self.credentials.accessToken    = [dict objectForKey:kSFOAuthAccessToken];
            self.credentials.instanceUrl    = [NSURL URLWithString:[dict objectForKey:kSFOAuthInstanceUrl]];
            self.credentials.issuedAt       = [[self class] timestampStringToDate:[dict objectForKey:kSFOAuthIssuedAt]];
            
            [self.delegate oauthCoordinatorDidAuthenticate:self];
        }
    } else {
        // failed to parse JSON
        NSError *error = [[self class] errorWithType:kSFOAuthErrorTypeMalformedResponse description:@"failed to parse response JSON"];
        NSMutableDictionary *errorDict = [NSMutableDictionary dictionaryWithDictionary:error.userInfo];
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

/* Start the watchdog timer used for the 'user-agent flow' only. */
- (void)startUserAgentFlowTimer {
    //NSLog(@"SFOAuthCoordinator:startUserAgentFlowTimer: timer started (%f seconds)", self.timeout);
    [self.userAgentFlowTimer invalidate];
    self.userAgentFlowTimer = [NSTimer scheduledTimerWithTimeInterval:self.timeout
                                                               target:self
                                                             selector:@selector(userAgentFlowTimerFired:)
                                                             userInfo:nil
                                                              repeats:NO];
}

/* Stop the watchdog timer used for the 'user-agent flow' only. */
- (void)stopUserAgentFlowTimer {
    //NSLog(@"SFOAuthCoordinator:stopUserAgentFlowTimer: timer stopped");
    [self.userAgentFlowTimer performSelectorOnMainThread:@selector(invalidate) withObject:nil waitUntilDone:YES];
    self.userAgentFlowTimer = nil;
}

/* Called if we timeout in the UIWebView during the user-agent flow. The timer is reset after every UIWebViewDelegate 
   call to shouldStartLoadWithRequest.
 */
- (void)userAgentFlowTimerFired:(NSTimer *)timer {
    NSLog(@"SFOAuthCoordinator:userAgentFlowTimerFired: timeout after %f seconds", self.timeout);
    
    NSString *typeString = @"timeout";
    NSString *description = [NSString stringWithFormat:@"useragent flow timed out after %.2f seconds", self.timeout];
    NSString *localized = [NSString stringWithFormat:@"%@ %@ : %@", kSFOAuthErrorDomain, typeString, description];
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"SFOAuthErrorTimeout", kSFOAuthError,
                                                                    typeString, kSFOAuthErrorDescription,
                                                                    localized,   NSLocalizedDescriptionKey,
                                                                    nil];
    NSError *error = [[NSError alloc] initWithDomain:kSFOAuthErrorDomain code:kSFOAuthErrorTimeout userInfo:dict];
    
    [_view stopLoading];
    [self.delegate oauthCoordinator:self didFailWithError:error];
    [error release];
    self.authenticating = NO;
}

#pragma mark - UIWebViewDelegate (User-Agent Token Flow)

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
#if SFOAUTH_LOG_TOKENS
    NSLog(@"SFOAuthCoordinator:webView:shouldStartLoadWithRequest: (navType=%u): %@ ", navigationType, request);
#else
    NSLog(@"SFOAuthCoordinator:webView:shouldStartLoadWithRequest: (navType=%u): host=%@ : path=%@", 
          navigationType, request.URL.host, request.URL.path);
#endif
    
    BOOL result = YES;
    NSURL *requestUrl = [request URL];
    NSString *requestUrlString = [requestUrl absoluteString];
	
    if ([requestUrlString hasPrefix:self.credentials.redirectUri]) {
		[self stopUserAgentFlowTimer];
        
        result = NO; // we're finished, don't load this request
        NSString *response = nil;
        
        // Check for a response in the URL fragment first, then fall back to the query string.
        
        if ([requestUrl fragment]) {
            response = [requestUrl fragment];
        } else if ([requestUrl query]) {
            response = [requestUrl query];
        } else {
            NSLog(@"SFOAuthCoordinator:webView:shouldStartLoadWithRequest: response has no payload: %@", requestUrlString);
            
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
                
                [self.delegate oauthCoordinatorDidAuthenticate:self];
            } else {
                NSError *finalError;
                NSError *error = [[self class] errorWithType:[params objectForKey:kSFOAuthError] 
                                                 description:[params objectForKey:kSFOAuthErrorDescription]];
                
                // add any additional relevant info to the userInfo dictionary
                
                if (kSFOAuthErrorInvalidClientId == error.code) {
                    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:error.userInfo];
                    [dict setObject:self.credentials.clientId forKey:@"client_id"];
                    finalError = [NSError errorWithDomain:error.domain code:error.code userInfo:dict];
                } else {
                    finalError = error;
                }
                [self.delegate oauthCoordinator:self didFailWithError:finalError];
            }
        }
        self.authenticating = NO;
	} else {
        [self performSelectorOnMainThread:@selector(startUserAgentFlowTimer) withObject:nil waitUntilDone:YES];
    }
    return result;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    NSURL *url = webView.request.URL;
    
#if SFOAUTH_LOG_TOKENS
    NSLog(@"SFOAuthCoordinator:webViewDidStartLoad: URL: %@ ", url);
#else
    NSLog(@"SFOAuthCoordinator:webViewDidStartLoad: host=%@ : path=%@", url.host, url.path);
#endif
    
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (!self.initialRequestLoaded) {
        self.initialRequestLoaded = YES;
        [self.delegate oauthCoordinator:self didBeginAuthenticationWithView:self.view];
        NSAssert((nil != [self.view superview]),@"No superview for oauth web view after didBeginAuthenticationWithView");
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    // TODO: translate NSURLError's into SFOAuth errors
    // TODO: Can we really continue for WebKitErrorDomain -999 ?
    // TODO: This may be too aggressive. Are there other errors that should be ignored?
    
    // report all errors other than -999 (operation couldn't be completed, which is not catastrophic)
    // typical errors encountered (many others are possible):
    // WebKitErrorDomain:
    //      -999 The operation couldn't be completed.
    // NSURLErrorDomain:
    //      -999 The operation couldn't be completed.
    //     -1001 The request timed out.
    
    if (-999 != error.code) { 
        NSLog(@"SFOAuthCoordinator:didFailLoadWithError %@ on URL: %@", error, webView.request.URL);
        [self stopUserAgentFlowTimer];
        [self.delegate oauthCoordinator:self didFailWithError:error];
        self.authenticating = NO;
    }
#if SFOAUTH_LOG_VERBOSE
    else {
        NSLog(@"SFOAuthCoordinator:didFailLoadWithError: %@ on URL: %@", error, webView.request.URL);
    }
#endif
}

#pragma mark - NSURLConnectionDelegate (Refresh Token Flow)

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	NSLog(@"SFOAuthCoordinator:connection:didFailWithError: %@", error);
    
    // TODO: convert NSURLError to SFOAuth error
    
    [self.delegate oauthCoordinator:self didFailWithError:error];
    self.authenticating = NO;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
	if (nil != response) {
        if (![[request HTTPMethod] isEqualToString:kHttpMethodPost]) {
            // convert the request to a post method if it's not
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

// Convert from the Unix timestamp string in milliseconds returned in the OAuth response to an NSDate
+ (NSDate *)timestampStringToDate:(NSString *)timestamp {
    NSDate *d = nil;
    if (timestamp != nil) {
        NSTimeInterval unixTimeInSecs = [timestamp longLongValue] / 1000; // convert from millis to secs
        d = [NSDate dateWithTimeIntervalSince1970:unixTimeInSecs];
    }
    return d;
}

@end
