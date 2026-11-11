/*
 SFSDKOAuth2.m
 SalesforceSDKCore
 
 Created by Raj Rao on 7/11/19.
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKOAuth2+Internal.h"
#import "SFSDKOAuthConstants.h"
#import "NSString+SFAdditions.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFNetwork+Internal.h"
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import <SalesforceSDKCommon/SFJsonUtils.h>
#import "NSData+SFAdditions.h"
#import <SalesforceSDKCore/SalesforceSDKCore-Swift.h>

NSString * const  kSFOAuthErrorDomain  = @"com.salesforce.OAuth.ErrorDomain";
const NSTimeInterval kSFOAuthDefaultTimeout  = 120.0; // seconds
NSString * const kSFSDKOAuthDPoPBoundKeyMismatchRecoveryKey = @"com.salesforce.mobilesdk.dpopBoundKeyMismatchRecovery";


@interface SFSDKOAuthTokenEndpointErrorResponse() {
    NSInteger _errorCode;
}
@property (nonatomic, readwrite) NSError *error;
- (instancetype)initWithError:(NSString *)errorType description:(NSString*)errorDescription;
- (instancetype)initWithError:(NSError *)error;
@end

@interface SFSDKOAuthTokenEndpointResponse()
- (instancetype)initWithDictionary:(NSDictionary *)nvPairs parseAdditionalFields:(NSArray<NSString *> *)additionalOAuthParameterKeys;
- (instancetype)initWithError:(NSError *)error;
@property (nonatomic,strong,readonly) NSMutableDictionary *values;
@property (nonatomic,strong) NSArray<NSString *> *additionalOAuthParameterKeys;
@property (nonatomic,strong,readwrite) NSString *refreshToken;
@end

@interface SFSDKOAuth2 ()
+ (BOOL)isServerDPoPBoundKeyMismatchError:(NSError *)error;
+ (BOOL)dpopProof:(NSString *)proof containsNonce:(NSString *)nonce;
@end

@implementation SFSDKOAuthTokenEndpointRequest
@end

@implementation SFSDKOAuthTokenEndpointErrorResponse

- (instancetype)initWithError:(NSString *)errorType description:(NSString*)errorDescription {
    if (self = [super init]) {
        _tokenEndpointErrorCode = errorType;
        _tokenEndpointErrorDescription = errorDescription;
        _error = [SFSDKOAuth2 errorWithType:errorType description:errorDescription];
        _errorCode = [SFOAuthErrorCodeHelper from:errorType];
    }
    return self;
}

- (instancetype)initWithError:(NSError *)error {
    if (self = [super init]) {
        _error = error;
    }
    return self;
}

@end

@implementation SFSDKOAuthTokenEndpointResponse

- (instancetype)initWithError:(NSError *)error {
    if (self = [super init]) {
        _error = [[SFSDKOAuthTokenEndpointErrorResponse alloc] initWithError:error];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)nvPairs parseAdditionalFields:(NSArray<NSString *> *)additionalOAuthParameterKeys {
    if (self = [super init]) {
        _values = [NSMutableDictionary dictionaryWithDictionary:nvPairs];
        _additionalOAuthParameterKeys = additionalOAuthParameterKeys;
        if (additionalOAuthParameterKeys) {
            NSMutableDictionary * parsedValues = [NSMutableDictionary dictionaryWithCapacity:_additionalOAuthParameterKeys.count];
            for (NSString * key in self.additionalOAuthParameterKeys) {
                id obj = nvPairs[key];
                if (obj) {
                    parsedValues[key] = obj;
                }
            }
            _additionalOAuthFields = parsedValues;
        }
        if ([nvPairs[kSFOAuthScope] isKindOfClass:[NSString class]]) {
            NSString *rawScope = nvPairs[kSFOAuthScope];
            _scopes = [rawScope componentsSeparatedByString:@" "];
        }
        if ([nvPairs[kSFOAuthError] isKindOfClass:[NSString class]]) {
            NSString *errorDescription = [nvPairs[kSFOAuthErrorDescription] isKindOfClass:[NSString class]]
                ? nvPairs[kSFOAuthErrorDescription]
                : @"";
            _error = [[SFSDKOAuthTokenEndpointErrorResponse alloc] initWithError:nvPairs[kSFOAuthError] description:errorDescription];
        }
    }
    return self;
}

- (BOOL)hasError {
    return (self.error != nil);
}

- (NSString *)accessToken {
    return self.values[kSFOAuthAccessToken];
}

- (NSString *)idToken {
    return self.values[kSFOAuthIdToken];
}

- (NSString *)refreshToken {
    return self.values[kSFOAuthRefreshToken];
}

- (void)setRefreshToken:(NSString *)refreshToken {
    [self.values setObject:refreshToken forKey:kSFOAuthRefreshToken];
}

- (NSDate *)issuedAt {
     return [SFSDKOAuth2 timestampStringToDate:self.values[kSFOAuthIssuedAt]];
}

- (NSURL *)instanceUrl {
    return [NSURL URLWithString:self.values[kSFOAuthInstanceUrl]];
}

- (NSURL *)apiInstanceUrl {
    return [NSURL URLWithString:self.values[kSFOAuthApiInstanceUrl]];
}

- (NSURL *)identityUrl {
    return [NSURL URLWithString:self.values[kSFOAuthId]];
}

- (NSString *)communityId {
     return self.values[kSFOAuthCommunityId];
}

- (NSString *)signature {
    return self.values[kSFOAuthSignature];
}

- (NSString *)lightningDomain {
    return self.values[kSFOAuthLightningDomain];
}

- (NSString *)lightningSid {
    return self.values[kSFOAuthLightningSID];
}

- (NSString *)vfDomain {
    return self.values[kSFOAuthVFDomain];
}

- (NSString *)vfSid {
    return self.values[kSFOAuthVFSID];
}

- (NSString *)contentDomain {
    return self.values[kSFOAuthContentDomain];
}

- (NSString *)contentSid {
    return self.values[kSFOAuthContentSID];
}

- (NSString *)csrfToken {
    return self.values[kSFOAuthCSRFToken];
}

- (NSString *)cookieClientSrc {
    return self.values[kSFOAuthCookieClientSrc];
}

- (NSString *)cookieSidClient {
    return self.values[kSFOAuthCookieSidClient];
}

- (NSString *)sidCookieName {
    return self.values[kSFOAuthSidCookieName];
}

- (NSString *)parentSid {
    return self.values[kSFOAuthParentSid];
}

- (NSString *)tokenFormat {
    return self.values[kSFOAuthTokenFormat];
}

- (NSString *)tokenType {
    return self.values[kSFOAuthTokenType];
}

- (NSString *)beaconChildConsumerKey {
    return self.values[kSFOAuthBeaconChildConsumerKey];
}

- (NSString *)beaconChildConsumerSecret {
    return self.values[kSFOAuthBeaconChildConsumerSecret];
}

- (NSURL *)communityUrl {
    if (_values[kSFOAuthCommunityUrl]) {
        return [NSURL URLWithString:self.values[kSFOAuthCommunityUrl]];
    }
    return nil;
}

- (NSDictionary *)asDictionary {
    return self.values;
}
@end

@implementation SFSDKOAuth2

- (void)accessTokenForApprovalCode:(SFSDKOAuthTokenEndpointRequest *)endpointReq completion:(void (^)(SFSDKOAuthTokenEndpointResponse *)) completionBlock {
    // Token endpoint requests can be reused. Clear refresh-specific state before a code exchange
    // so a prior refresh retry cannot affect its error handling.
    endpointReq.isRefreshTokenRequest = NO;
    endpointReq.dpopNonceRetryUsedExistingKey = NO;
    endpointReq.dpopNonceRetryUsedChallengeNonce = NO;
    NSMutableURLRequest *request = [self prepareBasicRequest:endpointReq];
    NSMutableString *params = [[NSMutableString alloc] initWithFormat:@"%@=%@&%@=%@&%@=%@&%@=%@",
                               kSFOAuthFormat, @"json",
                               kSFOAuthRedirectUri, endpointReq.redirectURI,
                               kSFOAuthClientId, endpointReq.clientID,
                               kSFOAuthDeviceId,[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    [params appendFormat:@"&%@=%@", kSFOAuthCodeVerifierParamName, endpointReq.codeVerifier];
    NSString *grantType = [[SalesforceSDKManager sharedManager] useHybridAuthentication] ? kSFOAuthGrantTypeHybridAuthorizationCode : kSFOAuthGrantTypeAuthorizationCode;
    [params appendFormat:@"&%@=%@&%@=%@", kSFOAuthGrantType, grantType, kSFOAuthApprovalCode, endpointReq.approvalCode];
    if (endpointReq.attestation) {
        [params appendFormat:@"&%@=%@", kSFOAuthAttestation, [endpointReq.attestation sfsdk_stringByURLEncoding]];
    }

    NSData *encodedBody = [params dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:encodedBody];

    __weak typeof(self) weakSelf = self;
    [self sendTokenEndpointRequest:request
                forEndpointRequest:endpointReq
             retryOnNonceChallenge:YES // this is a fresh request — one retry is allowed if the server sends back a use_dpop_nonce challenge.
                 dataResponseBlock:^(NSData *data, NSURLResponse *urlResponse, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        SFSDKOAuthTokenEndpointResponse *endpointResponse = nil;
        if (error) {
            NSURL *requestUrl = [request URL];
            NSString *errorUrlString = [NSString stringWithFormat:@"%@://%@%@", [requestUrl scheme], [requestUrl host], [requestUrl relativePath]];
            if (error.code == NSURLErrorTimedOut) {
                [SFSDKCoreLogger d:[strongSelf class] format:@"Attempt to get access token for approval code timed out after %f seconds.", endpointReq.timeout];
                endpointResponse = [[SFSDKOAuthTokenEndpointResponse alloc] initWithError:[NSError errorWithDomain:kSFOAuthErrorDomain code:kSFOAuthErrorTimeout userInfo:nil]];
            } else {
                endpointResponse = [[SFSDKOAuthTokenEndpointResponse alloc] initWithError:error];
            }
            [SFSDKCoreLogger d:[strongSelf class] format:@"SFOAuth2 session failed with error: error code: %ld, description: %@, URL: %@", (long)error.code, [error localizedDescription], errorUrlString];
            if (completionBlock) {
                completionBlock(endpointResponse);
            }
            return;
        }
        [strongSelf handleTokenEndpointResponse:completionBlock request:endpointReq data:data urlResponse:urlResponse];
    }];
}

/* Handle a 'token' endpoint (e.g. refresh, advanced auth) response.
 Example response:
 { "id":"https://login.salesforce.com/id/org-id/user-id",
 "issued_at":"1309481030001",
 "instance_url":"https://na1.salesforce.com",
 "signature":"signature-hash",
 "access_token":"access-token-value" }
 
 Example error response:
 { "error":"invalid_grant","error_description":"authentication failure - Invalid Password" }
 */
- (void)accessTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq completion:(void (^)(SFSDKOAuthTokenEndpointResponse *)) completionBlock {
    if (endpointReq.nativeRequestIsCurrent && ![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self accessTokenForRefresh:endpointReq completion:completionBlock]; });
        return;
    }
    if (endpointReq.nativeRequestIsCurrent && !endpointReq.nativeRequestIsCurrent()) {
        if (completionBlock) {
            completionBlock([[SFSDKOAuthTokenEndpointResponse alloc] initWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]]);
        }
        return;
    }
    endpointReq.isRefreshTokenRequest = YES;
    endpointReq.dpopNonceRetryUsedExistingKey = NO;
    endpointReq.dpopNonceRetryUsedChallengeNonce = NO;
    SFSDKDPoPDecorationFailure dpopFailure = SFSDKDPoPDecorationFailureOther;
    NSMutableURLRequest *request = [self prepareBasicRequest:endpointReq dpopFailure:&dpopFailure];

    // Never send a refresh without the bound DPoP key. Confirmed absence requires re-auth;
    // an indeterminate Keychain read is transient and must preserve the current session.
    if (dpopFailure == SFSDKDPoPDecorationFailureBoundKeyMissing ||
        dpopFailure == SFSDKDPoPDecorationFailureBoundKeyUnavailable) {
        [SFSDKCoreLogger e:[self class] format:@"%@: aborting refresh — DPoP bound key unusable (failure=%ld).", NSStringFromSelector(_cmd), (long)dpopFailure];
        if (completionBlock) {
            completionBlock([[SFSDKOAuthTokenEndpointResponse alloc] initWithError:[self errorForDPoPDecorationFailure:dpopFailure]]);
        }
        return;
    }

    NSMutableString *params = [[NSMutableString alloc] initWithFormat:@"%@=%@&%@=%@&%@=%@&%@=%@",
                               kSFOAuthFormat, @"json",
                               kSFOAuthRedirectUri, endpointReq.redirectURI,
                               kSFOAuthClientId, endpointReq.clientID,
                               kSFOAuthDeviceId,[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    NSURL *targetURL = endpointReq.serverURL;
    NSString *targetHost = targetURL.host ?: @"<unknown>";
    [SFSDKCoreLogger i:[self class] format:@"%@: Initiating refresh token flow to host: %@", NSStringFromSelector(_cmd), targetHost];
    NSString *grantType = [[SalesforceSDKManager sharedManager] useHybridAuthentication] ? kSFOAuthGrantTypeHybridRefresh : kSFOAuthGrantTypeRefresh;
    [params appendFormat:@"&%@=%@&%@=%@", kSFOAuthGrantType, grantType, kSFOAuthRefreshToken, endpointReq.refreshToken];
    for (NSString * key in endpointReq.additionalTokenRefreshParams) {
        [params appendFormat:@"&%@=%@", [key sfsdk_stringByURLEncoding], [endpointReq.additionalTokenRefreshParams[key] sfsdk_stringByURLEncoding]];
    }
    if (endpointReq.attestation) {
        [params appendFormat:@"&%@=%@", kSFOAuthAttestation, [endpointReq.attestation sfsdk_stringByURLEncoding]];
    }
    NSData *encodedBody = [params dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:encodedBody];

    __weak typeof(self) weakSelf = self;
    NSString *className = NSStringFromClass([self class]);
    [self sendTokenEndpointRequest:request
                forEndpointRequest:endpointReq
             retryOnNonceChallenge:YES
                 dataResponseBlock:^(NSData *data, NSURLResponse *urlResponse, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        SFSDKOAuthTokenEndpointResponse *endpointResponse = nil;
        if (error) {
            NSURL *requestUrl = [request URL];
            NSString *errorUrlString = [NSString stringWithFormat:@"%@://%@%@", [requestUrl scheme], [requestUrl host], [requestUrl relativePath]];
            
            if ([error.domain isEqualToString:kSFOAuthErrorDomain]) {
                endpointResponse = [[SFSDKOAuthTokenEndpointResponse alloc] initWithError:error];
            } else {
                NSUInteger code = [SFSDKOAuth2 sfErrorCodeFromError:error.code];
                endpointResponse = [[SFSDKOAuthTokenEndpointResponse alloc] initWithError:[NSError errorWithDomain:kSFOAuthErrorDomain code:code userInfo:nil]];
            }
            
            if (error.code == NSURLErrorTimedOut) {
                [SFSDKCoreLogger d:[SFSDKOAuth2 class] format:@"Refresh attempt timed out after %f seconds.", endpointReq.timeout];
            }
            
            [SFSDKCoreLogger d:[SFSDKOAuth2 class] format:@"SFOAuth2 session failed with error: error code: %ld, description: %@, URL: %@", (long)error.code, [error localizedDescription], errorUrlString];
            if (completionBlock) {
                completionBlock(endpointResponse);
            }
            return;
        }
        
        [SFSDKEventBuilderHelper createAndStoreEvent:@"tokenRefresh" userAccount:[SFUserAccountManager sharedInstance].currentUser className:className attributes:nil];
        if (strongSelf) {
            [strongSelf handleTokenEndpointResponse:completionBlock request:endpointReq data:data urlResponse:urlResponse];
        } else {
            [SFSDKCoreLogger d:[SFSDKOAuth2 class] format:@"Token endpoint response handler skipped because self was deallocated."];
            if (completionBlock) {
                completionBlock(nil);
            }
        }
    }];
}

- (void)openIDTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq completion:(void (^)(NSString *))completionBlock {
    [self accessTokenForRefresh:endpointReq completion:^(SFSDKOAuthTokenEndpointResponse *authTokenEndpointResponse) {
        NSString *idToken = authTokenEndpointResponse.idToken;
        if (completionBlock) {
            completionBlock(idToken);
        }
    }];
}

#pragma mark - private

- (NSURLSession *)createURLSessionWithIdentifier:(NSString *)identifier {
    SFNetwork *network = [SFNetwork sharedEphemeralInstanceWithIdentifier:identifier];
    return network.activeSession;
}

- (NSMutableURLRequest *)prepareBasicRequest:(SFSDKOAuthTokenEndpointRequest *)endpointReq {
    return [self prepareBasicRequest:endpointReq dpopFailure:NULL];
}

- (NSMutableURLRequest *)prepareBasicRequest:(SFSDKOAuthTokenEndpointRequest *)endpointReq
                                 dpopFailure:(SFSDKDPoPDecorationFailure *)outFailure {
    NSString *protocolHost = endpointReq.serverURL.absoluteString;
    NSMutableString *url = [[NSMutableString alloc] initWithFormat:@"%@%@", protocolHost, kSFOAuthEndPointToken];
    if (![url hasPrefix:@"http"]) {
        [url insertString:@"https://" atIndex:0];
    }
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]
                                                                cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                            timeoutInterval:endpointReq.timeout];
    [request setHTTPMethod:kHttpMethodPost];
    [request setValue:kHttpPostContentType forHTTPHeaderField:kHttpHeaderContentType];
    if (endpointReq.userAgent.length > 0) {
        [request setValue:endpointReq.userAgent forHTTPHeaderField:@"User-Agent"];
    }
    [request setHTTPShouldHandleCookies:NO];
    [self attachDPoPHeaderIfNeeded:request scope:endpointReq.credentialsIdentifier tokenType:endpointReq.tokenType failure:outFailure];
    return request;
}

- (void)attachDPoPHeaderIfNeeded:(NSMutableURLRequest *)request scope:(NSString *)scope tokenType:(nullable NSString *)tokenType {
    [self attachDPoPHeaderIfNeeded:request scope:scope tokenType:tokenType failure:NULL];
}

- (NSError *)errorForDPoPDecorationFailure:(SFSDKDPoPDecorationFailure)failure {
    if (failure == SFSDKDPoPDecorationFailureBoundKeyMissing) {
        return [SFSDKOAuth2 errorWithType:@"invalid_grant"
                               description:@"DPoP bound key missing for refresh; re-authentication required."];
    }
    return [NSError errorWithDomain:kSFOAuthErrorDomain
                               code:kSFOAuthErrorRefreshFailed
                           userInfo:@{NSLocalizedDescriptionKey: @"DPoP bound key is temporarily unavailable for refresh; retry after Keychain access is restored."}];
}

// Classifies a DPoP decoration failure so the refresh path can fail fast instead of silently
// sending a refresh with no proof (or a proof signed by a freshly-minted, server-unacceptable key).
// On `boundKeyMissing` the bound key is confirmed gone → the caller must fail the refresh as
// invalid_grant and route to re-auth. On `boundKeyUnavailable` (e.g. device locked) the key may
// still exist → do not send a mis-signed request, but treat as transient. For
// any other (non-key) decoration error, preserve the legacy "log and proceed without a proof".
- (void)attachDPoPHeaderIfNeeded:(NSMutableURLRequest *)request
                           scope:(NSString *)scope
                       tokenType:(nullable NSString *)tokenType
                         failure:(SFSDKDPoPDecorationFailure *)outFailure {
    if (outFailure) { *outFailure = SFSDKDPoPDecorationFailureOther; }
    if (scope.length == 0) return;
    NSError *err = nil;
    [SFSDKDPoPRequestDecorator decorateRequest:request scope:scope tokenType:tokenType accessToken:nil error:&err];
    if (err) {
        SFSDKDPoPDecorationFailure failure = [SFSDKDPoPRequestDecorator classifyDecorationError:err];
        if (outFailure) { *outFailure = failure; }
        switch (failure) {
            case SFSDKDPoPDecorationFailureBoundKeyMissing:
                [SFSDKCoreLogger e:[self class] format:@"DPoP attach: bound key missing; refusing to send a mis-signed refresh. Routing to re-auth."];
                break;
            case SFSDKDPoPDecorationFailureBoundKeyUnavailable:
                [SFSDKCoreLogger w:[self class] format:@"DPoP attach: bound key temporarily unavailable (indeterminate Keychain read); refresh not sent. A later caller-initiated refresh can retry after Keychain access is restored."];
                break;
            case SFSDKDPoPDecorationFailureOther:
            default:
                [SFSDKCoreLogger e:[self class] format:@"DPoP attach failed (code=%ld); proceeding without DPoP header.", (long)err.code];
                break;
        }
        return;
    }
    // Diagnostic: if a proof was attached, record the scope + PUBLIC jkt thumbprint the refresh is
    // being signed with. Compare against the /authorize binding log (emitted by SFOAuthCoordinator)
    // to detect key-scope drift — a refresh whose scope/jkt differs from the originally bound pair
    // means the key was looked up under a different identifier than it was created under. Low-
    // frequency (token endpoint only, not resource calls) and non-PII: thumbprint is the public jkt;
    // no key material/tokens.
    if ([request valueForHTTPHeaderField:kHttpHeaderDPoP].length > 0) {
        SFSDKDPoPKeyPair *boundPair = [SFSDKDPoPKeyStore.shared existingKeyPairForScope:scope];
        if (boundPair) {
            NSError *tpErr = nil;
            NSString *jkt = [SFSDKDPoPProofBuilder jwkThumbprintWithPublicKey:boundPair.publicKey error:&tpErr];
            if (jkt.length > 0 && !tpErr) {
                [SFSDKCoreLogger i:[self class] format:@"DPoP binding at refresh: scope=%@ jkt=%@", scope, jkt];
            }
        }
    }
}

// Sends a token-endpoint request, harvesting DPoP-Nonce headers from the response and
// retrying exactly once if the server returns a use_dpop_nonce / 401-with-DPoP-Nonce
// challenge (RFC 9449 §8). When DPoP is disabled this is a thin pass-through.
- (void)sendTokenEndpointRequest:(NSMutableURLRequest *)request
              forEndpointRequest:(SFSDKOAuthTokenEndpointRequest *)endpointReq
           retryOnNonceChallenge:(BOOL)retryOnNonceChallenge
               dataResponseBlock:(void (^)(NSData *, NSURLResponse *, NSError *))block {
    __block NSString *networkIdentifier = [SFNetwork uniqueInstanceIdentifier];
    SFNetwork *network = [SFNetwork sharedEphemeralInstanceWithIdentifier:networkIdentifier];
    __weak typeof(self) weakSelf = self;
    NSString *ownerKey = endpointReq.ownerKey;
    [network sendRequest:request ownerKey:ownerKey dataResponseBlock:^(NSData *data, NSURLResponse *urlResponse, NSError *error) {
        [SFNetwork removeSharedInstanceForIdentifier:networkIdentifier];
        void (^processResponse)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        // Reset and native proof/nonce/credential side effects share the main queue.
        // Transport cancellation alone cannot reject a response already queued for delivery.
        if (endpointReq.nativeRequestIsCurrent && !endpointReq.nativeRequestIsCurrent()) {
            block(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]);
            return;
        }
        if (error == nil && endpointReq.credentialsIdentifier.length > 0) {
            [SFSDKDPoPRequestDecorator harvestNonceFromResponse:urlResponse
                                                     requestURL:request.URL
                                                          scope:endpointReq.credentialsIdentifier];
            NSInteger statusCode = 0;
            if ([urlResponse isKindOfClass:[NSHTTPURLResponse class]]) {
                statusCode = ((NSHTTPURLResponse *)urlResponse).statusCode;
            }
#if DEBUG
            // Temporary diagnostic for the former mint-on-miss state. Log only normalized server
            // signals, not the OAuth response body, refresh token, or DPoP proof.
            if (statusCode >= 400 && [request valueForHTTPHeaderField:kHttpHeaderDPoP].length > 0) {
                id parsedOAuthErrorResponse = [SFJsonUtils objectFromJSONData:data];
                NSDictionary *oauthErrorResponse = [parsedOAuthErrorResponse isKindOfClass:[NSDictionary class]]
                    ? parsedOAuthErrorResponse
                    : nil;
                BOOL hasOAuthError = [oauthErrorResponse[kSFOAuthError] isKindOfClass:[NSString class]];
                NSString *oauthError = hasOAuthError ? oauthErrorResponse[kSFOAuthError] : nil;
                NSString *oauthErrorDescription = [oauthErrorResponse[kSFOAuthErrorDescription] isKindOfClass:[NSString class]]
                    ? oauthErrorResponse[kSFOAuthErrorDescription]
                    : @"";
                BOOL isBoundKeyMismatch = [oauthError isEqualToString:@"invalid_dpop_proof"]
                    && [oauthErrorDescription isEqualToString:@"dpop thumbprint invalid for token"];
                [SFSDKCoreLogger w:[strongSelf class]
                              format:@"DPoP token response diagnostic: status=%ld has_oauth_error=%@ bound_key_mismatch=%@",
                 (long)statusCode, hasOAuthError ? @"true" : @"false", isBoundKeyMismatch ? @"true" : @"false"];
            }
#endif
            id parsedOAuthErrorResponse = statusCode == 400 ? [SFJsonUtils objectFromJSONData:data] : nil;
            NSDictionary *oauthErrorResponse = [parsedOAuthErrorResponse isKindOfClass:[NSDictionary class]]
                ? parsedOAuthErrorResponse
                : nil;
            BOOL hasMalformedOAuthErrorFields = statusCode == 400
                && (!oauthErrorResponse
                    || (oauthErrorResponse[kSFOAuthError] && ![oauthErrorResponse[kSFOAuthError] isKindOfClass:[NSString class]])
                    || (oauthErrorResponse[kSFOAuthErrorDescription] && ![oauthErrorResponse[kSFOAuthErrorDescription] isKindOfClass:[NSString class]])
                    || (oauthErrorResponse[kSFOAuthScope] && ![oauthErrorResponse[kSFOAuthScope] isKindOfClass:[NSString class]]));
            NSString *oauthError = [oauthErrorResponse[kSFOAuthError] isKindOfClass:[NSString class]]
                ? oauthErrorResponse[kSFOAuthError]
                : nil;
            BOOL isNonceChallenge = statusCode == 400
                ? [oauthError isEqualToString:@"use_dpop_nonce"]
                : [SFSDKDPoPRequestDecorator isNonceChallengeWithStatusCode:statusCode body:data response:urlResponse];
            if (retryOnNonceChallenge && !hasMalformedOAuthErrorFields && isNonceChallenge) {
                [SFSDKCoreLogger i:[strongSelf class] format:@"DPoP nonce challenge received; retrying token-endpoint request once."];
                NSString *challengedNonce = [urlResponse isKindOfClass:[NSHTTPURLResponse class]]
                    ? [(NSHTTPURLResponse *)urlResponse valueForHTTPHeaderField:@"DPoP-Nonce"]
                    : nil;
                BOOL isBoundKeyRecoveryChallenge = endpointReq.isRefreshTokenRequest
                    && statusCode == 400
                    && [oauthError isEqualToString:@"use_dpop_nonce"]
                    && challengedNonce.length > 0;
                [request setValue:nil forHTTPHeaderField:kHttpHeaderDPoP];
                SFSDKDPoPDecorationFailure dpopFailure = SFSDKDPoPDecorationFailureOther;
                [strongSelf attachDPoPHeaderIfNeeded:request
                                                 scope:endpointReq.credentialsIdentifier
                                             tokenType:endpointReq.tokenType
                                               failure:&dpopFailure];
                if (dpopFailure == SFSDKDPoPDecorationFailureBoundKeyMissing ||
                    dpopFailure == SFSDKDPoPDecorationFailureBoundKeyUnavailable) {
                    block(nil, nil, [strongSelf errorForDPoPDecorationFailure:dpopFailure]);
                    return;
                }
                endpointReq.dpopNonceRetryUsedExistingKey = [request valueForHTTPHeaderField:kHttpHeaderDPoP].length > 0;
                endpointReq.dpopNonceRetryUsedChallengeNonce = endpointReq.dpopNonceRetryUsedExistingKey
                    && isBoundKeyRecoveryChallenge
                    && [[self class] dpopProof:[request valueForHTTPHeaderField:kHttpHeaderDPoP]
                                  containsNonce:challengedNonce];
                [strongSelf sendTokenEndpointRequest:request
                                  forEndpointRequest:endpointReq
                               retryOnNonceChallenge:NO // already retried once; don't retry again.
                                   dataResponseBlock:block];
                return;
            }
        }
        block(data, urlResponse, error);
        };
        if (endpointReq.nativeRequestIsCurrent && ![NSThread isMainThread]) {
            dispatch_async(dispatch_get_main_queue(), processResponse);
        } else {
            processResponse();
        }
    }];
}

- (void)handleTokenEndpointResponse:(void (^)(SFSDKOAuthTokenEndpointResponse *))completionBlock request:(SFSDKOAuthTokenEndpointRequest *)endpointReq data:(NSData *)data urlResponse:(NSURLResponse *)response {
    SFSDKOAuthTokenEndpointResponse *endpointResponse = nil;

    // Resets the response data for a new refresh response.
    NSMutableData *responseData = [NSMutableData dataWithCapacity:kSFOAuthReponseBufferLength];
    [responseData appendData:data];
    id parsedJSON = [SFJsonUtils objectFromJSONData:responseData];
    NSDictionary *json = [parsedJSON isKindOfClass:[NSDictionary class]] ? parsedJSON : nil;
    BOOL hasMalformedOAuthErrorFields = json
        && ((json[kSFOAuthError] && ![json[kSFOAuthError] isKindOfClass:[NSString class]])
            || (json[kSFOAuthErrorDescription] && ![json[kSFOAuthErrorDescription] isKindOfClass:[NSString class]])
            || (json[kSFOAuthScope] && ![json[kSFOAuthScope] isKindOfClass:[NSString class]]));
    if (json && !hasMalformedOAuthErrorFields) {
        endpointResponse  = [[SFSDKOAuthTokenEndpointResponse alloc] initWithDictionary:json  parseAdditionalFields:endpointReq.additionalOAuthParameterKeys];
        NSInteger statusCode = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? ((NSHTTPURLResponse *)response).statusCode
            : 0;
        if (endpointReq.isRefreshTokenRequest
            && endpointReq.dpopNonceRetryUsedExistingKey
            && endpointReq.dpopNonceRetryUsedChallengeNonce
            && statusCode == 400
            && endpointResponse.hasError
            && [[self class] isServerDPoPBoundKeyMismatchError:endpointResponse.error.error]) {
            NSMutableDictionary *userInfo = [endpointResponse.error.error.userInfo mutableCopy];
            userInfo[kSFSDKOAuthDPoPBoundKeyMismatchRecoveryKey] = @YES;
            endpointResponse.error.error = [NSError errorWithDomain:endpointResponse.error.error.domain
                                                                 code:endpointResponse.error.error.code
                                                             userInfo:userInfo];
        }
        if (!endpointResponse.hasError){
           // Adds the refresh token to the response for consistency.
            id jsonRefreshToken = json[kSFOAuthRefreshToken];
            if (![jsonRefreshToken isKindOfClass:[NSString class]] || [jsonRefreshToken length] < 1) {
               if (endpointReq.refreshToken) {
                   [endpointResponse setRefreshToken:endpointReq.refreshToken];
               } else {
                  [SFSDKCoreLogger e:[self class] format:@"%@ :Token endpoint call was made without the existence of a refresh token.", NSStringFromSelector(_cmd)];
               }
           }
        }
    } else {
        NSError* jsonError = [SFJsonUtils lastError];
        [SFSDKCoreLogger d:[self class] format:@"%@: JSON parse error: %@", NSStringFromSelector(_cmd), jsonError];
        NSError *error = [[self class] errorWithType:@"malformed_response" description:@"failed to parse response JSON"];
        NSMutableDictionary *errorDict = jsonError.userInfo
            ? [NSMutableDictionary dictionaryWithDictionary:jsonError.userInfo]
            : [NSMutableDictionary dictionary];
        errorDict[kSFOAuthError] = @"malformed_response";
        errorDict[NSLocalizedDescriptionKey] = @"failed to parse response JSON";
        if (error) {
            errorDict[NSUnderlyingErrorKey] = error;
        }
        NSError *finalError = [NSError errorWithDomain:kSFOAuthErrorDomain code:error.code userInfo:errorDict];
        endpointResponse = [[SFSDKOAuthTokenEndpointResponse alloc]initWithError:finalError];
    }
    if (completionBlock) {
        completionBlock(endpointResponse);
    }
}

- (void)revokeRefreshToken:(SFOAuthCredentials *)credentials reason:(SFLogoutReason)reason {
    if (credentials.refreshToken != nil) {
        NSString *ownerKey = nil;
#if DEBUG
        SFUserAccount *account = [[SFUserAccountManager sharedInstance] accountForCredentials:credentials];
        ownerKey = [SFNetwork ownerKeyForOrgId:account.credentials.organizationId userId:account.credentials.userId];
#endif
        NSMutableURLRequest *request = [SFSDKOAuth2 requestForRevokeRefreshToken:credentials reason:reason];

        __block NSString *networkIdentifier = [SFNetwork uniqueInstanceIdentifier];
        SFNetwork *network = [SFNetwork sharedEphemeralInstanceWithIdentifier:networkIdentifier];
        [network sendRequest:request ownerKey:ownerKey dataResponseBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            [SFNetwork removeSharedInstanceForIdentifier:networkIdentifier];
        }];
    }
    [credentials revoke];
}

#pragma mark - Utilities

+ (NSMutableURLRequest *)requestForRevokeRefreshToken:(SFOAuthCredentials *)credentials reason:(SFLogoutReason)reason {
    NSString *host = [NSString stringWithFormat:@"%@://%@%@",
                      credentials.protocol, credentials.domain, kSFRevokePath];
    NSURL *url = [NSURL URLWithString:host];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:kHttpMethodPost];
    [request setValue:kHttpPostContentType forHTTPHeaderField:kHttpHeaderContentType];
    [request setHTTPShouldHandleCookies:NO];
    
    NSString *params = [NSString stringWithFormat:@"token=%@&revoke_reason=%@",
                        [credentials.refreshToken sfsdk_stringByURLEncoding],
                        [SFSDKOAuth2 stringValueForLogoutReason:reason]];
    NSData *encodedBody = [params dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:encodedBody];
    
    return request;
}

+ (NSString *)stringValueForLogoutReason:(SFLogoutReason)reason {
    switch(reason) {
        case SFLogoutReasonCorruptState:
            return @"corrupt_state";
        case SFLogoutReasonCorruptStateAppConfigurationSettings:
            return @"corrupt_state_app_configuration_settings";
        case SFLogoutReasonCorruptStateAppProviderErrorInvalidUser:
            return @"corrupt_state_app_provider_error_invalid_user";
        case SFLogoutReasonCorruptStateAppInvalidRestClient:
            return @"corrupt_state_app_invalid_restclient";
        case SFLogoutReasonCorruptStateAppOther:
            return @"corrupt_state_app_other";
        case SFLogoutReasonCorruptStateMSDK:
            return @"corrupt_state_msdk";
        case SFLogoutReasonUserInitiated:
            return @"user_logout";
        case SFLogoutReasonUnknown:
            return @"unknown";
        case SFLogoutReasonUnexpected:
            return @"unexpected";
        case SFLogoutReasonTokenExpired:
            return @"refresh_token_expired";
        case SFLogoutReasonSSDKPolicy:
            return @"ssdk_logout_policy";
        case SFLogoutReasonTimeout:
            return @"timeout";
        case SFLogoutReasonUnexpectedResponse:
            return @"unexpected_response";
        case SFLogoutReasonRefreshTokenRotated:
            return @"refresh_token_rotated";
        case SFLogoutReasonAppAttestationFailed:
            return @"app_attestation_failed";
    }
}

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
    if ([type isEqualToString:@"access_denied"]) {
        code = kSFOAuthErrorAccessDenied;
    } else if ([type isEqualToString:@"malformed_response"]) {
        code = kSFOAuthErrorMalformed;
    } else if ([type isEqualToString:@"invalid_client_id"]) {
        code = kSFOAuthErrorInvalidClientId;
    } else if ([type isEqualToString:@"invalid_client"]) {
        code = kSFOAuthErrorInvalidClientCredentials;
    } else if ([type isEqualToString:@"invalid_client_credentials"]) {
        code = kSFOAuthErrorInvalidClientCredentials;
    } else if ([type isEqualToString:@"invalid_grant"]) {
        code = kSFOAuthErrorInvalidGrant;
    } else if ([type isEqualToString:@"invalid_request"]) {
        code = kSFOAuthErrorInvalidRequest;
    } else if ([type isEqualToString:@"inactive_user"]) {
        code = kSFOAuthErrorInactiveUser;
    } else if ([type isEqualToString:@"inactive_org"]) {
        code = kSFOAuthErrorInactiveOrg;
    } else if ([type isEqualToString:@"rate_limit_exceeded"]) {
        code = kSFOAuthErrorRateLimitExceeded;
    } else if ([type isEqualToString:@"unsupported_response_type"]) {
        code = kSFOAuthErrorUnsupportedResponseType;
    } else if ([type isEqualToString:@"auth_timeout"]) {
        code = kSFOAuthErrorTimeout;
    } else if ([type isEqualToString:@"wrong_version"]) {
        code = kSFOAuthErrorWrongVersion;
    } else if ([type isEqualToString:@"browser_launch_failed"]) {
        code = kSFOAuthErrorBrowserLaunchFailed;
    } else if ([type isEqualToString:@"unknown_advanced_auth_config"]) {
        code = kSFOAuthErrorUnknownAdvancedAuthConfig;
    } else if ([type isEqualToString:@"jwt_launch_failed"]) {
        code = kSFOAuthErrorJWTInvalidGrant;
    }
    NSMutableDictionary *userInfoDict = [NSMutableDictionary dictionaryWithDictionary:@{kSFOAuthError: type, NSLocalizedDescriptionKey: description}];
    if (underlyingError != nil) {
        userInfoDict[NSUnderlyingErrorKey] = underlyingError;
    }
    NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain code:code userInfo:userInfoDict];
    return error;
}

+ (BOOL)isDPoPBoundKeyMismatchError:(NSError *)error {
    return [error.userInfo[kSFSDKOAuthDPoPBoundKeyMismatchRecoveryKey] boolValue]
        && [self isServerDPoPBoundKeyMismatchError:error];
}

+ (BOOL)dpopProof:(NSString *)proof containsNonce:(NSString *)nonce {
    NSArray<NSString *> *segments = [proof componentsSeparatedByString:@"."];
    if (segments.count != 3 || nonce.length == 0) {
        return NO;
    }
    NSString *payloadBase64 = [[segments[1] stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
                               stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    NSUInteger paddingLength = (4 - (payloadBase64.length % 4)) % 4;
    payloadBase64 = [payloadBase64 stringByPaddingToLength:payloadBase64.length + paddingLength
                                                withString:@"="
                                           startingAtIndex:0];
    NSData *payloadData = [[NSData alloc] initWithBase64EncodedString:payloadBase64 options:0];
    id parsedPayload = payloadData ? [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil] : nil;
    NSDictionary *payload = [parsedPayload isKindOfClass:[NSDictionary class]] ? parsedPayload : nil;
    return [payload[@"nonce"] isKindOfClass:[NSString class]] && [payload[@"nonce"] isEqualToString:nonce];
}

+ (BOOL)isServerDPoPBoundKeyMismatchError:(NSError *)error {
    return [error.domain isEqualToString:kSFOAuthErrorDomain]
        && [error.userInfo[kSFOAuthError] isKindOfClass:[NSString class]]
        && [error.userInfo[NSLocalizedDescriptionKey] isKindOfClass:[NSString class]]
        && [error.userInfo[kSFOAuthError] isEqualToString:@"invalid_dpop_proof"]
        && [error.userInfo[NSLocalizedDescriptionKey] isEqualToString:@"dpop thumbprint invalid for token"];
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

+ (NSUInteger)sfErrorCodeFromError:(NSInteger)code {
   
    switch (code) {
        case NSURLErrorTimedOut:
            return kSFOAuthErrorTimeout;
            break;
            
        case NSURLErrorCancelled:
            return kSFOAuthErrorRequestCancelled;
            break;
        
        default:
            return kSFOAuthErrorRefreshFailed;
    }
}

@end
