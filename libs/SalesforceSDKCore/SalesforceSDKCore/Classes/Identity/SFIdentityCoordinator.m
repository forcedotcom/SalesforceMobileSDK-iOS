/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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
#import <CommonCrypto/CommonDigest.h>
#import "SFIdentityCoordinator+Internal.h"
#import "SFOAuthCredentials.h"
#import "SFOAuthSessionRefresher.h"
#import "SFUserAccountManager.h"
#import "SFNetwork.h"
#import "SFSDKAuthSession.h"
#import "SFIdentityData+Internal.h"
#import "SalesforceSDKCore/SalesforceSDKCore-Swift.h"

// Public constants

const NSTimeInterval kSFIdentityRequestDefaultTimeoutSeconds = 120.0;
NSString * const     kSFIdentityErrorDomain                  = @"com.salesforce.Identity.ErrorDomain";

// Private constants

NSString * const kHttpHeaderAuthorization             = @"Authorization";
NSString * const kHttpAuthHeaderFormatString          = @"Bearer %@";

static NSString * const kSFIdentityError                      = @"error";
static NSString * const kSFIdentityErrorDescription           = @"error_description";
static NSString * const kSFIdentityErrorTypeNoData            = @"no_data_returned";
static NSString * const kSFIdentityErrorTypeDataMalformed     = @"malformed_response";
static NSString * const kSFIdentityErrorTypeBadHttpResponse   = @"bad_http_response";
static NSString * const kSFIdentityErrorTypeMissingParameters = @"missing_parameters";
static NSString * const kSFIdentityErrorTypeAlreadyRetrieving = @"retrieval_in_progress";
static NSString * const kMissingParametersFormatString        = @"The following required parameters for the identity service were missing: %@";
static NSString * const kSFIdentityDataPropertyKey            = @"com.salesforce.keys.identity.data";

@interface SFIdentityCoordinator()

@property (nonatomic) NSString *networkIdentifier;

@end

@implementation SFIdentityCoordinator
@synthesize authSession = _authSession;
@synthesize credentials = _credentials;
@synthesize idData = _idData;
@synthesize delegate = _delegate;
@synthesize timeout = _timeout;
@synthesize retrievingData = _retrievingData;
@synthesize session = _session;
@synthesize oauthSessionRefresher = _oauthSessionRefresher;

#pragma mark - init / dealloc

- (id)initWithCredentials:(SFOAuthCredentials *)credentials
{
    self = [super init];
    if (self) {
        self.credentials = credentials;
        self.timeout = kSFIdentityRequestDefaultTimeoutSeconds;
        self.retrievingData = NO;
    }
    
    return self;
}

- (id)initWithAuthSession:(SFSDKAuthSession *)authSession {
    self = [super init];
    if (self) {
        self.authSession = authSession;
        self.credentials = authSession.credentials;
        self.timeout = kSFIdentityRequestDefaultTimeoutSeconds;
        self.retrievingData = NO;
    }
    
    return self;
}


#pragma mark - Identity data retrieval and processing

- (void)initiateIdentityDataRetrieval
{
    NSString *missingParameters = [self validateParameters];
    if ([missingParameters length] > 0) {
        NSError *missingParamsError = [self errorWithType:kSFIdentityErrorTypeMissingParameters description:missingParameters];
        [self notifyDelegateOfFailure:missingParamsError];
        return;
    }
    if (self.retrievingData) {
        NSString *alreadyRetrievingErrorMessage = @"Identity data retrieval already in progress.  Call cancelRetrieval to stop the transaction in progress.";
        [SFSDKCoreLogger d:[self class] format:alreadyRetrievingErrorMessage];
        NSError *alreadyRetrievingError = [self errorWithType:kSFIdentityErrorTypeAlreadyRetrieving description:alreadyRetrievingErrorMessage];
        [self notifyDelegateOfFailure:alreadyRetrievingError];
        return;
    }
    self.retrievingData = YES;
    
    [self sendRequest];
}

- (void)cancelRetrieval
{
    [self.session invalidateAndCancel];
    [self cleanupData];
}

#pragma mark - Private methods

- (NSString *)validateParameters
{
    NSMutableString *invalidParameters = [NSMutableString string];
    if ([self.credentials.accessToken length] == 0) {
        [invalidParameters appendString:@"access token"];
    }
    if ([[self.credentials.identityUrl absoluteString] length] == 0) {
        if ([invalidParameters length] > 0) [invalidParameters appendString:@", "];
        [invalidParameters appendString:@"identity URL"];
    }
    
    NSString *invalidParametersError = nil;
    if ([invalidParameters length] > 0) {
        invalidParametersError = [NSString stringWithFormat:kMissingParametersFormatString, invalidParameters];
    }
    
    return invalidParametersError;
}

- (void)sendRequest
{
    // TEMP debug — fingerprint the access token at request-build time so we can
    // tell whether refresh is actually swapping the in-flight token.
    NSString *atFingerprint = self.credentials.accessToken.length >= 8
        ? [self.credentials.accessToken substringToIndex:8]
        : (self.credentials.accessToken ?: @"<nil>");
    [SFSDKCoreLogger i:[self class] format:@"Identity sendRequest probe: accessToken[0..8]=%@ len=%lu", atFingerprint, (unsigned long)self.credentials.accessToken.length];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.credentials.identityUrl
                                                                cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                            timeoutInterval:self.timeout];
    [request setHTTPMethod:@"GET"];
    NSError *authError = nil;
    BOOL ok = [SFSDKDPoPRequestDecorator applyAuthHeaders:request
                                                    scope:self.credentials.identifier
                                              accessToken:self.credentials.accessToken
                                                tokenType:self.credentials.tokenType
                                                    error:&authError];
    if (!ok) {
        [SFSDKCoreLogger e:[self class] format:@"SFIdentityCoordinator: Failed to stamp authorization headers: %@", authError.localizedDescription];
    }
    [request setTimeoutInterval:self.timeout];
    [request setHTTPShouldHandleCookies:NO];
    // TEMP debug — confirm what headers actually go on the wire.
    NSString *authHdr = [request valueForHTTPHeaderField:@"Authorization"];
    NSString *dpopHdr = [request valueForHTTPHeaderField:@"DPoP"];
    NSString *authPreview = authHdr ? [NSString stringWithFormat:@"%@…(%lu chars)", [authHdr substringToIndex:MIN((NSUInteger)10, authHdr.length)], (unsigned long)authHdr.length] : @"<nil>";
    NSString *dpopPreview = dpopHdr ? [NSString stringWithFormat:@"<%lu chars, %lu segments>", (unsigned long)dpopHdr.length, (unsigned long)[[dpopHdr componentsSeparatedByString:@"."] count]] : @"<nil>";
    [SFSDKCoreLogger i:[self class] format:@"Identity outbound probe: tokenType=%@ Authorization=%@ DPoP=%@", self.credentials.tokenType ?: @"<nil>", authPreview, dpopPreview];
    [SFSDKCoreLogger d:[self class] format:@"SFIdentityCoordinator:Starting identity request at %@", self.credentials.identityUrl.absoluteString];

    // TEMP debug — fire-and-forget userinfo probes alongside the identity call,
    // using the same DPoP-bound credentials. Runs once per process so the loop
    // doesn't drown logs. Two probes:
    //   1. identityHost (login.test1...) — same host as failing /id/ call
    //   2. instanceHost (orgfarm-...my.pc-rnd...) — the my-domain that minted the token
    // Comparing the two pinpoints whether the login-host sfdcedge proxy is the
    // culprit independent of org/connected-app config.
    static dispatch_once_t userinfoProbeOnce;
    dispatch_once(&userinfoProbeOnce, ^{
        NSURLComponents *idComps = [NSURLComponents componentsWithURL:self.credentials.identityUrl resolvingAgainstBaseURL:NO];
        idComps.path = @"/services/oauth2/userinfo";
        idComps.query = nil;
        NSURL *userinfoUrl = idComps.URL;
        NSMutableURLRequest *uiReq = [[NSMutableURLRequest alloc] initWithURL:userinfoUrl
                                                                  cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                              timeoutInterval:self.timeout];
        [uiReq setHTTPMethod:@"GET"];
        [uiReq setHTTPShouldHandleCookies:NO];
        NSError *uiAuthErr = nil;
        BOOL uiOk = [SFSDKDPoPRequestDecorator applyAuthHeaders:uiReq
                                                          scope:self.credentials.identifier
                                                    accessToken:self.credentials.accessToken
                                                      tokenType:self.credentials.tokenType
                                                          error:&uiAuthErr];
        [SFSDKCoreLogger i:[self class] format:@"Userinfo probe (identityHost): stamping ok=%d err=%@ url=%@", uiOk, uiAuthErr ?: @"<nil>", userinfoUrl.absoluteString];

        // TEMP debug — decode the DPoP proof and access token (if JWT) so we can
        // share claims with backend without leaking secrets. Logs only structural
        // metadata: header alg/typ, payload claims (htm/htu/iat/jti/ath length),
        // and embedded jwk shape. Does not log the proof signature.
        NSString * (^b64urlDecode)(NSString *) = ^NSString *(NSString *seg) {
            NSString *s = [seg stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
            s = [s stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
            NSUInteger pad = (4 - (s.length % 4)) % 4;
            for (NSUInteger i = 0; i < pad; i++) s = [s stringByAppendingString:@"="];
            NSData *d = [[NSData alloc] initWithBase64EncodedString:s options:0];
            return d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : nil;
        };
        NSDictionary * (^parseJwtJson)(NSString *) = ^NSDictionary *(NSString *json) {
            if (!json) return nil;
            NSError *jerr = nil;
            id parsed = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&jerr];
            return [parsed isKindOfClass:[NSDictionary class]] ? parsed : nil;
        };

        NSString *dpopProof = [uiReq valueForHTTPHeaderField:@"DPoP"];
        NSArray<NSString *> *segs = [dpopProof componentsSeparatedByString:@"."];
        if (segs.count == 3) {
            NSDictionary *hdr = parseJwtJson(b64urlDecode(segs[0]));
            NSDictionary *payload = parseJwtJson(b64urlDecode(segs[1]));
            NSDictionary *jwk = hdr[@"jwk"];
            NSString *ath = payload[@"ath"];

            // RFC 7638 JWK thumbprint for EC keys: base64url(SHA-256(canonical))
            // canonical = {"crv":"<crv>","kty":"EC","x":"<x>","y":"<y>"} (lex-ordered, no whitespace)
            NSString *jkt = @"<nil>";
            if ([jwk[@"kty"] isEqualToString:@"EC"] && jwk[@"crv"] && jwk[@"x"] && jwk[@"y"]) {
                NSString *canonical = [NSString stringWithFormat:@"{\"crv\":\"%@\",\"kty\":\"EC\",\"x\":\"%@\",\"y\":\"%@\"}",
                    jwk[@"crv"], jwk[@"x"], jwk[@"y"]];
                NSData *canonBytes = [canonical dataUsingEncoding:NSUTF8StringEncoding];
                unsigned char digest[CC_SHA256_DIGEST_LENGTH];
                CC_SHA256(canonBytes.bytes, (CC_LONG)canonBytes.length, digest);
                NSData *digestData = [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
                NSString *b64 = [digestData base64EncodedStringWithOptions:0];
                b64 = [b64 stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
                b64 = [b64 stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
                b64 = [b64 stringByReplacingOccurrencesOfString:@"=" withString:@""];
                jkt = b64;
            }

            [SFSDKCoreLogger i:[self class]
                format:@"Userinfo probe DPoP proof: alg=%@ typ=%@ jwk.kty=%@ jwk.crv=%@ jwk.x.len=%lu jwk.y.len=%lu computed.jkt=%@ htm=%@ htu=%@ iat=%@ jti=%@ ath=%@ nonce=%@",
                hdr[@"alg"] ?: @"<nil>",
                hdr[@"typ"] ?: @"<nil>",
                jwk[@"kty"] ?: @"<nil>",
                jwk[@"crv"] ?: @"<nil>",
                (unsigned long)((NSString *)jwk[@"x"]).length,
                (unsigned long)((NSString *)jwk[@"y"]).length,
                jkt,
                payload[@"htm"] ?: @"<nil>",
                payload[@"htu"] ?: @"<nil>",
                payload[@"iat"] ?: @"<nil>",
                payload[@"jti"] ?: @"<nil>",
                ath ?: @"<nil>",
                payload[@"nonce"] ?: @"<nil>"];
        } else {
            [SFSDKCoreLogger i:[self class] format:@"Userinfo probe DPoP proof: unexpected segment count=%lu", (unsigned long)segs.count];
        }

        // Try decoding the access token as a JWT (it may be opaque; that's OK).
        NSArray<NSString *> *atSegs = [self.credentials.accessToken componentsSeparatedByString:@"."];
        if (atSegs.count == 3) {
            NSDictionary *atPayload = parseJwtJson(b64urlDecode(atSegs[1]));
            NSDictionary *cnf = atPayload[@"cnf"];
            [SFSDKCoreLogger i:[self class]
                format:@"Userinfo probe access token: jwt=yes iss=%@ aud=%@ sub=%@ scope=%@ cnf.jkt=%@",
                atPayload[@"iss"] ?: @"<nil>",
                atPayload[@"aud"] ?: @"<nil>",
                atPayload[@"sub"] ?: @"<nil>",
                atPayload[@"scope"] ?: @"<nil>",
                cnf[@"jkt"] ?: @"<nil>"];
        } else {
            [SFSDKCoreLogger i:[self class] format:@"Userinfo probe access token: jwt=no segments=%lu (opaque, cnf.jkt unavailable on client)", (unsigned long)atSegs.count];
        }

        NSString * (^pickReqId)(NSDictionary *) = ^NSString *(NSDictionary *uiHdrs) {
            for (NSString *key in uiHdrs.allKeys) {
                if ([key caseInsensitiveCompare:@"Sfdc-Request-Id"] == NSOrderedSame ||
                    [key caseInsensitiveCompare:@"X-Sfdc-Request-Id"] == NSOrderedSame ||
                    [key caseInsensitiveCompare:@"X-Request-Id"] == NSOrderedSame) {
                    return uiHdrs[key];
                }
            }
            return @"<nil>";
        };

        NSString *uiId = [SFNetwork uniqueInstanceIdentifier];
        SFNetwork *uiNet = [SFNetwork sharedEphemeralInstanceWithIdentifier:uiId];
        [uiNet sendRequest:uiReq dataResponseBlock:^(NSData *uiData, NSURLResponse *uiResp, NSError *uiErr) {
            NSInteger uiStatus = [(NSHTTPURLResponse *)uiResp statusCode];
            NSDictionary *uiHdrs = [(NSHTTPURLResponse *)uiResp allHeaderFields];
            NSString *uiBody = uiData ? [[NSString alloc] initWithData:uiData encoding:NSUTF8StringEncoding] : @"<nil>";
            [SFSDKCoreLogger i:[self class] format:@"Userinfo probe (identityHost) response: status=%ld request-id=%@ err=%@ body=%@",
                (long)uiStatus, pickReqId(uiHdrs), uiErr ?: @"<nil>", uiBody];
            [SFSDKCoreLogger i:[self class] format:@"Userinfo probe (identityHost) headers dump: %@", uiHdrs];
            [SFNetwork removeSharedInstanceForIdentifier:uiId];
        }];

        // TEMP debug — second userinfo probe, this time at the my-domain
        // (instance_url) that minted the token. If this one returns 200 while the
        // identityHost one returns 403 sfdcedge, the issue is the login-host edge
        // proxy not honoring DPoP-bound tokens, not the SDK or the access token.
        NSURL *instanceUrl = self.credentials.instanceUrl;
        if (instanceUrl) {
            NSURLComponents *instComps = [NSURLComponents componentsWithURL:instanceUrl resolvingAgainstBaseURL:NO];
            instComps.path = @"/services/oauth2/userinfo";
            instComps.query = nil;
            NSURL *instUserinfoUrl = instComps.URL;
            NSMutableURLRequest *instReq = [[NSMutableURLRequest alloc] initWithURL:instUserinfoUrl
                                                                        cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                                    timeoutInterval:self.timeout];
            [instReq setHTTPMethod:@"GET"];
            [instReq setHTTPShouldHandleCookies:NO];
            NSError *instAuthErr = nil;
            BOOL instOk = [SFSDKDPoPRequestDecorator applyAuthHeaders:instReq
                                                                scope:self.credentials.identifier
                                                          accessToken:self.credentials.accessToken
                                                            tokenType:self.credentials.tokenType
                                                                error:&instAuthErr];
            [SFSDKCoreLogger i:[self class] format:@"Userinfo probe (instanceHost): stamping ok=%d err=%@ url=%@", instOk, instAuthErr ?: @"<nil>", instUserinfoUrl.absoluteString];

            NSString *instId = [SFNetwork uniqueInstanceIdentifier];
            SFNetwork *instNet = [SFNetwork sharedEphemeralInstanceWithIdentifier:instId];
            [instNet sendRequest:instReq dataResponseBlock:^(NSData *instData, NSURLResponse *instResp, NSError *instErr) {
                NSInteger instStatus = [(NSHTTPURLResponse *)instResp statusCode];
                NSDictionary *instHdrs = [(NSHTTPURLResponse *)instResp allHeaderFields];
                NSString *instBody = instData ? [[NSString alloc] initWithData:instData encoding:NSUTF8StringEncoding] : @"<nil>";
                NSString *instServer = @"<nil>";
                for (NSString *key in instHdrs.allKeys) {
                    if ([key caseInsensitiveCompare:@"Server"] == NSOrderedSame) {
                        instServer = instHdrs[key];
                        break;
                    }
                }
                [SFSDKCoreLogger i:[self class] format:@"Userinfo probe (instanceHost) response: status=%ld server=%@ request-id=%@ err=%@ body=%@",
                    (long)instStatus, instServer, pickReqId(instHdrs), instErr ?: @"<nil>", instBody];
                [SFSDKCoreLogger i:[self class] format:@"Userinfo probe (instanceHost) headers dump: %@", instHdrs];
                [SFNetwork removeSharedInstanceForIdentifier:instId];
            }];
        } else {
            [SFSDKCoreLogger i:[self class] format:@"Userinfo probe (instanceHost): skipped, instanceUrl=<nil>"];
        }
    });
    __weak __typeof(self) weakSelf = self;
    self.networkIdentifier = [SFNetwork uniqueInstanceIdentifier];
    SFNetwork *network = [SFNetwork sharedEphemeralInstanceWithIdentifier:self.networkIdentifier];
    self.session = network.activeSession;
    [SFSDKDPoPRequestDecorator sendRequestWithNonceRetry:request
                                                   scope:self.credentials.identifier ?: @""
                                     accessTokenProvider:^NSString * _Nullable {
        return weakSelf.credentials.accessToken;
    }
                                               tokenType:self.credentials.tokenType
                                                 network:network
                                            taskReceiver:nil
                                       dataResponseBlock:^(NSData *data, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (error) {
            [SFSDKCoreLogger d:[self class] format:@"SFIdentityCoordinator session failed with error: %@", error];
            [strongSelf notifyDelegateOfFailure:error];
            return;
        }

        // The connection can succeed, but the actual HTTP response is a failure.  Check for that.
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 401 || statusCode == 403) {
            // TEMP debug — characterize the error response. Surface request-id
            // candidates so backend can correlate; dump all headers as a backstop.
            NSDictionary *hdrs = [(NSHTTPURLResponse *)response allHeaderFields];
            NSString *bodyStr = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"<nil>";
            id (^pickHeader)(NSArray<NSString *> *) = ^id(NSArray<NSString *> *names) {
                for (NSString *name in names) {
                    for (NSString *key in hdrs.allKeys) {
                        if ([key caseInsensitiveCompare:name] == NSOrderedSame) {
                            return hdrs[key];
                        }
                    }
                }
                return @"<nil>";
            };
            [SFSDKCoreLogger i:[self class] format:@"Identity error probe: status=%ld www-authenticate=%@ dpop-nonce=%@ sfdc-request-id=%@ x-request-id=%@ body=%@",
                (long)statusCode,
                pickHeader(@[@"WWW-Authenticate"]),
                pickHeader(@[@"DPoP-Nonce"]),
                pickHeader(@[@"Sfdc-Request-Id", @"X-Sfdc-Request-Id", @"Request-Id"]),
                pickHeader(@[@"X-Request-Id", @"X-Trace-Id", @"X-Correlation-Id"]),
                bodyStr];
            [SFSDKCoreLogger i:[self class] format:@"Identity error probe headers dump: %@", hdrs];
            // The session timed out.  Identity service tends to send 403s for session timeouts.  Try to refresh.
            [SFSDKCoreLogger i:[self class] format:@"%@: Identity request failed due to expired credentials.  Attempting to refresh credentials.", NSStringFromSelector(_cmd)];
            strongSelf.oauthSessionRefresher = [[SFOAuthSessionRefresher alloc] initWithCredentials:strongSelf.credentials];
            // TEMP debug — snapshot the token *before* refresh into a local copy.
            // The refresher mutates strongSelf.credentials in place, so reading
            // `accessToken` inside the completion compares post-refresh-to-post-refresh.
            NSString *preRefreshAt = [strongSelf.credentials.accessToken copy];
            [strongSelf.oauthSessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
                [SFSDKCoreLogger d:[strongSelf class] format:@"%@: Credentials refresh successful.  Replaying original identity request.", NSStringFromSelector(_cmd)];
                NSString *postRefreshAt = updatedCredentials.accessToken;
                NSString *oldFp = preRefreshAt.length >= 8 ? [preRefreshAt substringToIndex:8] : (preRefreshAt ?: @"<nil>");
                NSString *newFp = postRefreshAt.length >= 8 ? [postRefreshAt substringToIndex:8] : (postRefreshAt ?: @"<nil>");
                [SFSDKCoreLogger i:[strongSelf class] format:@"Identity refresh probe: pre[0..8]=%@ (len=%lu) post[0..8]=%@ (len=%lu) same=%d sameInstance=%d",
                    oldFp, (unsigned long)preRefreshAt.length,
                    newFp, (unsigned long)postRefreshAt.length,
                    [preRefreshAt isEqualToString:postRefreshAt],
                    (updatedCredentials == strongSelf.credentials)];
                strongSelf.credentials = updatedCredentials;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [strongSelf sendRequest];
                });
            } error:^(NSError *refreshError) {
                [SFSDKCoreLogger e:[strongSelf class] format:@"SFIdentityCoordinator failed to refresh expired session. Error: %@", refreshError];
                [strongSelf notifyDelegateOfFailure:refreshError];
            }];
        } else if (statusCode != 200) {
            // Some other HTTP error.
            NSError *httpError = [self errorWithType:kSFIdentityErrorTypeBadHttpResponse
                                         description:[NSString stringWithFormat:@"Unexpected HTTP response code from the identity service: %ld", (long)statusCode]];
            [strongSelf notifyDelegateOfFailure:httpError];
        } else {
            // Successful response.  Process the return data.
            [strongSelf processResponse:data];
        }
    }];
}

- (void)notifyDelegateOfSuccess
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(identityCoordinatorRetrievedData:)]) {
            [self.delegate identityCoordinatorRetrievedData:self];
        }
        [self cleanupData];
    });
}

- (void)notifyDelegateOfFailure:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(identityCoordinator:didFailWithError:)]) {
            [self.delegate identityCoordinator:self didFailWithError:error];
        }
        [self cleanupData];
    });
}

- (void)dealloc
{
    [SFNetwork removeSharedInstanceForIdentifier:self.networkIdentifier];
    self.networkIdentifier = nil;
    self.session = nil;
    self.credentials = nil;
    self.idData = nil;
    self.oauthSessionRefresher = nil;
}

- (void)cleanupData
{
    [SFNetwork removeSharedInstanceForIdentifier:self.networkIdentifier];
    self.networkIdentifier = nil;
    self.session = nil;
    self.oauthSessionRefresher = nil;
    self.retrievingData = NO;
}

- (void)processResponse:(NSData *)data
{
    NSError *error = nil;
    if (data == nil) {
        error = [self errorWithType:kSFIdentityErrorTypeNoData description:@"No identity data returned in response."];
        [self notifyDelegateOfFailure:error];
        return;
    }
    
    NSDictionary *idJsonData = (NSDictionary *)[SFJsonUtils objectFromJSONData:data];
    if (idJsonData == nil) {
        error = [self errorWithType:kSFIdentityErrorTypeDataMalformed description:@"Unable to parse identity response data."];
        [self notifyDelegateOfFailure:error];
        return;
    }
    
    NSMutableDictionary *mutableIdJsonData = [[NSMutableDictionary alloc] initWithDictionary:idJsonData];
    if (self.authSession.nativeLogin) {
        [mutableIdJsonData setObject:[NSNumber numberWithBool:YES] forKey:@"native_login"];
    }
    SFIdentityData *idData = [[SFIdentityData alloc] initWithJsonDict:mutableIdJsonData];
     self.idData = idData;
    
    [self notifyDelegateOfSuccess];
}

- (NSError *)errorWithType:(NSString *)type description:(NSString *)description {
    NSAssert(type, @"error type can't be nil");
    
    NSInteger intCode = kSFIdentityErrorUnknown;
    NSNumber *numCode = (self.typeToCodeDict)[type];
    if (numCode != nil) {
        intCode = [numCode integerValue];
    }
    
    NSDictionary *dict = @{kSFIdentityError: type,
                          kSFIdentityErrorDescription: description,
                          NSLocalizedDescriptionKey: description};
    NSError *error = [NSError errorWithDomain:kSFIdentityErrorDomain code:intCode userInfo:dict];
    return error;
}

#pragma mark - Properties

- (NSDictionary *)typeToCodeDict
{
    static NSDictionary *_typeToCodeDict = nil;
    if (_typeToCodeDict == nil) {
        _typeToCodeDict = @{ kSFIdentityErrorTypeNoData: @(kSFIdentityErrorNoData),
                             kSFIdentityErrorTypeDataMalformed: @(kSFIdentityErrorDataMalformed),
                             kSFIdentityErrorTypeBadHttpResponse: @(kSFIdentityErrorBadHttpResponse),
                             kSFIdentityErrorTypeMissingParameters: @(kSFIdentityErrorMissingParameters),
                             kSFIdentityErrorTypeAlreadyRetrieving: @(kSFIdentityErrorAlreadyRetrieving)
                             };
    }
    
    return _typeToCodeDict;
}

@end
