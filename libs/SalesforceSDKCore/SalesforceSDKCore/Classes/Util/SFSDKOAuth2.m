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
#import "SFNetwork.h"
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import <SalesforceSDKCommon/SFJsonUtils.h>
#import "NSData+SFAdditions.h"

NSString * const  kSFOAuthErrorDomain  = @"com.salesforce.OAuth.ErrorDomain";
const NSTimeInterval kSFOAuthDefaultTimeout  = 120.0; // seconds

@interface SFSDKOAuthTokenEndpointErrorResponse()
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

@implementation SFSDKOAuthTokenEndpointRequest
@end

@implementation SFSDKOAuthTokenEndpointErrorResponse

- (instancetype)initWithError:(NSString *)errorType description:(NSString*)errorDescription {
    if (self = [super init]) {
        _tokenEndpointErrorCode = errorType;
        _tokenEndpointErrorDescription = errorDescription;
        _error = [SFSDKOAuth2 errorWithType:errorType description:errorDescription];
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
        if (nvPairs[kSFOAuthScope]) {
            NSString *rawScope = nvPairs[kSFOAuthScope];
            _scopes = [rawScope componentsSeparatedByString:@" "];
        }
        if (nvPairs[kSFOAuthError]) {
            _error = [[SFSDKOAuthTokenEndpointErrorResponse alloc] initWithError:nvPairs[kSFOAuthError] description:nvPairs[kSFOAuthErrorDescription]];
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
    NSMutableURLRequest *request = [self prepareBasicRequest:endpointReq];
    NSMutableString *params = [[NSMutableString alloc] initWithFormat:@"%@=%@&%@=%@&%@=%@&%@=%@",
                               kSFOAuthFormat, @"json",
                               kSFOAuthRedirectUri, endpointReq.redirectURI,
                               kSFOAuthClientId, endpointReq.clientID,
                               kSFOAuthDeviceId,[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    [params appendFormat:@"&%@=%@", kSFOAuthCodeVerifierParamName, endpointReq.codeVerifier];
    [params appendFormat:@"&%@=%@&%@=%@", kSFOAuthGrantType, kSFOAuthGrantTypeAuthorizationCode, kSFOAuthApprovalCode, endpointReq.approvalCode];
    NSData *encodedBody = [params dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:encodedBody];
    __block NSString *instanceIdentifier = [SFNetwork uniqueInstanceIdentifier];
    NSURLSession *session = [self createURLSessionWithIdentifier:instanceIdentifier];
    __weak typeof(self) weakSelf = self;
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *urlResponse, NSError *error) {
        [SFNetwork removeSharedInstanceForIdentifier:instanceIdentifier];
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
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionBlock) {
                    completionBlock(endpointResponse);
                }
            });
            return;
        }
        [strongSelf handleTokenEndpointResponse:completionBlock request:endpointReq data:data urlResponse:urlResponse];
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
- (void)accessTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq completion:(void (^)(SFSDKOAuthTokenEndpointResponse *)) completionBlock {
    NSMutableURLRequest *request = [self prepareBasicRequest:endpointReq];
    NSMutableString *params = [[NSMutableString alloc] initWithFormat:@"%@=%@&%@=%@&%@=%@&%@=%@",
                               kSFOAuthFormat, @"json",
                               kSFOAuthRedirectUri, endpointReq.redirectURI,
                               kSFOAuthClientId, endpointReq.clientID,
                               kSFOAuthDeviceId,[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    [SFSDKCoreLogger i:[self class] format:@"%@: Initiating refresh token flow.", NSStringFromSelector(_cmd)];
    [params appendFormat:@"&%@=%@&%@=%@", kSFOAuthGrantType, kSFOAuthGrantTypeHybridRefresh, kSFOAuthRefreshToken, endpointReq.refreshToken];
    for (NSString * key in endpointReq.additionalTokenRefreshParams) {
        [params appendFormat:@"&%@=%@", [key stringByURLEncoding], [endpointReq.additionalTokenRefreshParams[key] stringByURLEncoding]];
    }
    NSData *encodedBody = [params dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:encodedBody];
    __block NSString *instanceIdentifier = [SFNetwork uniqueInstanceIdentifier];
    NSURLSession *session = [self createURLSessionWithIdentifier:instanceIdentifier];

    __weak typeof(self) weakSelf = self;
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *urlResponse, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        SFSDKOAuthTokenEndpointResponse *endpointResponse = nil;
        [SFNetwork removeSharedInstanceForIdentifier:instanceIdentifier];
        if (error) {
            NSURL *requestUrl = [request URL];
            NSString *errorUrlString = [NSString stringWithFormat:@"%@://%@%@", [requestUrl scheme], [requestUrl host], [requestUrl relativePath]];
            
            NSUInteger code = [SFSDKOAuth2 sfErrorCodeFromError:error.code];
            endpointResponse = [[SFSDKOAuthTokenEndpointResponse alloc] initWithError:[NSError errorWithDomain:kSFOAuthErrorDomain code:code userInfo:nil]];
            
            if (error.code == NSURLErrorTimedOut) {
                [SFSDKCoreLogger d:[strongSelf class] format:@"Refresh attempt timed out after %f seconds.", endpointReq.timeout];
            }
            
            [SFSDKCoreLogger d:[strongSelf class] format:@"SFOAuth2 session failed with error: error code: %ld, description: %@, URL: %@", (long)error.code, [error localizedDescription], errorUrlString];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionBlock) {
                    completionBlock(endpointResponse);
                }
            });
            return;
        }
        [strongSelf handleTokenEndpointResponse:completionBlock request:endpointReq data:data urlResponse:urlResponse];
    }] resume];
}

- (void)openIDTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq completion:(void (^)(NSString *))completionBlock {
    [self accessTokenForRefresh:endpointReq completion:^(SFSDKOAuthTokenEndpointResponse *authTokenEndpointResponse) {
        NSString *idToken = authTokenEndpointResponse.idToken;
        if (completionBlock) {
            completionBlock(idToken);
        }
    }];
}

#pragma mark - SFSDKOAuthSessionManaging
- (NSURLSession *)createURLSessionWithIdentifier:(NSString *)identifier {
    SFNetwork *network = [SFNetwork sharedEphemeralInstanceWithIdentifier:identifier];
    return network.activeSession;
}

#pragma mark - private
- (NSMutableURLRequest *)prepareBasicRequest:(SFSDKOAuthTokenEndpointRequest *)endpointReq {
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
    if (endpointReq.userAgentForAuth != nil) {
        [request setValue:endpointReq.userAgentForAuth forHTTPHeaderField:kHttpHeaderUserAgent];
    }
    [request setHTTPShouldHandleCookies:NO];
    return request;
}

- (void)handleTokenEndpointResponse:(void (^)(SFSDKOAuthTokenEndpointResponse *))completionBlock request:(SFSDKOAuthTokenEndpointRequest *)endpointReq data:(NSData *)data urlResponse:(NSURLResponse *)response {
    SFSDKOAuthTokenEndpointResponse *endpointResponse = nil;

    // Resets the response data for a new refresh response.
    NSMutableData *responseData = [NSMutableData dataWithCapacity:kSFOAuthReponseBufferLength];
    [responseData appendData:data];
    NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    NSDictionary *json = [SFJsonUtils objectFromJSONData:responseData];
    if (json) {
        endpointResponse  = [[SFSDKOAuthTokenEndpointResponse alloc] initWithDictionary:json  parseAdditionalFields:endpointReq.additionalOAuthParameterKeys];
        if (!endpointResponse.hasError){
           // Adds the refresh token to the response for consistency.
           NSString *jsonRefreshToken = [json objectForKey:kSFOAuthRefreshToken];
           if (jsonRefreshToken == nil || jsonRefreshToken.length < 1 ) {
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
        NSError *error = [[self class] errorWithType:kSFOAuthErrorTypeMalformedResponse description:@"failed to parse response JSON"];
        NSMutableDictionary *errorDict = [NSMutableDictionary dictionaryWithDictionary:jsonError.userInfo];
        if (responseString) {
            errorDict[@"response_data"] = responseString;
        }
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

- (void)revokeRefreshToken:(SFOAuthCredentials *)credentials {
    if (credentials.refreshToken != nil) {
        NSString *host = [NSString stringWithFormat:@"%@://%@%@?token=%@",
                        credentials.protocol, credentials.domain,
                        kSFRevokePath, credentials.refreshToken];
        NSURL *url = [NSURL URLWithString:host];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
        [request setHTTPMethod:@"GET"];
        [request setHTTPShouldHandleCookies:NO];

        __block NSString *networkIdentifier = [SFNetwork uniqueInstanceIdentifier];
        SFNetwork *network = [SFNetwork sharedEphemeralInstanceWithIdentifier:networkIdentifier];
        [network sendRequest:request dataResponseBlock:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            [SFNetwork removeSharedInstanceForIdentifier:networkIdentifier];
        }];
    }
    [credentials revoke];
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
    NSMutableDictionary *userInfoDict = [NSMutableDictionary dictionaryWithDictionary:@{kSFOAuthError: type, NSLocalizedDescriptionKey: description}];
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
