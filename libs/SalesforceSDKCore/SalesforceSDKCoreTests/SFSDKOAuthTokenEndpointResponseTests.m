/*
 SFSDKOAuthTokenEndpointResponseTests.m
 SalesforceSDKCoreTests
 
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
 
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

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "SFSDKOAuth2+Internal.h"
#import "SFSDKCoreLogger.h"
#import "SFNetwork.h"
#import "SFNetwork+Internal.h"
#import "SalesforceSDKManager.h"
#import <SalesforceSDKCommon/SalesforceSDKCommon-Swift.h>
#import <SalesforceSDKCore/SalesforceSDKCore-Swift.h>

@interface SFSDKOAuthTokenEndpointResponse ()

- (instancetype)initWithDictionary:(NSDictionary *)nvPairs parseAdditionalFields:(NSArray<NSString *> *)additionalOAuthParameterKeys;
- (NSDictionary *)asDictionary;

@end

@interface SFSDKOAuth2 (NonceRetryTesting)
- (void)sendTokenEndpointRequest:(NSMutableURLRequest *)request
              forEndpointRequest:(SFSDKOAuthTokenEndpointRequest *)endpointReq
           retryOnNonceChallenge:(BOOL)retryOnNonceChallenge
               dataResponseBlock:(void (^)(NSData *, NSURLResponse *, NSError *))block;
@end

@interface SFLogger (NonceRetryLoggingTest)
+ (void)clearAllComponents;
@end

@interface SFSDKOAuthNonceRetryLogReceiver : NSObject <SFLogReceiver>
@property (nonatomic, strong) NSMutableArray<NSString *> *messages;
@end

@implementation SFSDKOAuthNonceRetryLogReceiver

- (instancetype)init {
    if (self = [super init]) {
        _messages = [NSMutableArray new];
    }
    return self;
}

- (void)receiveWithLevel:(SFLogLevel)level cls:(Class)cls component:(NSString *)component message:(NSString *)message {
    [self.messages addObject:message];
}

@end

@interface SFSDKOAuthNonceRetryLogReceiverFactory : NSObject <SFLogReceiverFactory>
@property (nonatomic, strong) SFSDKOAuthNonceRetryLogReceiver *receiver;
@end

@implementation SFSDKOAuthNonceRetryLogReceiverFactory

- (instancetype)initWithReceiver:(SFSDKOAuthNonceRetryLogReceiver *)receiver {
    if (self = [super init]) {
        _receiver = receiver;
    }
    return self;
}

- (id<SFLogReceiver>)createWithComponentName:(NSString *)componentName {
    return self.receiver;
}

@end

@interface SFSDKOAuthNonceRetryNoOpLogReceiver : NSObject <SFLogReceiver>
@end

@implementation SFSDKOAuthNonceRetryNoOpLogReceiver

- (void)receiveWithLevel:(SFLogLevel)level cls:(Class)cls component:(NSString *)component message:(NSString *)message {
}

@end

@interface SFSDKOAuthNonceRetryNoOpLogReceiverFactory : NSObject <SFLogReceiverFactory>
@property (nonatomic, strong) SFSDKOAuthNonceRetryNoOpLogReceiver *receiver;
@end

@implementation SFSDKOAuthNonceRetryNoOpLogReceiverFactory

- (instancetype)init {
    if (self = [super init]) {
        _receiver = [[SFSDKOAuthNonceRetryNoOpLogReceiver alloc] init];
    }
    return self;
}

- (id<SFLogReceiver>)createWithComponentName:(NSString *)componentName {
    return self.receiver;
}

@end

@interface SFSDKOAuthNonceRetryNetworkStub : SFNetwork
@property (nonatomic, strong) NSMutableArray<NSURLRequest *> *capturedRequests;
@property (nonatomic, strong) NSMutableArray<NSString *> *capturedOwnerKeys;
@property (nonatomic, copy, nullable) void (^firstRequestBlock)(void);
@property (nonatomic, assign) NSInteger firstResponseStatusCode;
@property (nonatomic, copy, nullable) NSString *firstResponseBody;
@property (nonatomic, assign) NSInteger secondResponseStatusCode;
@property (nonatomic, copy, nullable) NSString *secondResponseBody;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *firstResponseHeaders;
@end

@implementation SFSDKOAuthNonceRetryNetworkStub

- (instancetype)init {
    self = [super init];
    if (self) {
        _capturedRequests = [NSMutableArray new];
        _capturedOwnerKeys = [NSMutableArray new];
        _firstResponseStatusCode = 400;
        _firstResponseBody = @"{\"error\":\"use_dpop_nonce\"}";
        _secondResponseStatusCode = 200;
        _secondResponseBody = @"{\"access_token\":\"refreshed-access-token\"}";
        _firstResponseHeaders = @{ @"DPoP-Nonce": @"retry-nonce" };
    }
    return self;
}

- (NSURLSessionDataTask *)sendRequest:(NSURLRequest *)urlRequest ownerKey:(NSString *)ownerKey dataResponseBlock:(SFDataResponseBlock)dataResponseBlock {
    [self.capturedOwnerKeys addObject:ownerKey ?: @""];
    return [self sendRequest:urlRequest dataResponseBlock:dataResponseBlock];
}

- (NSURLSessionDataTask *)sendRequest:(NSURLRequest *)urlRequest dataResponseBlock:(SFDataResponseBlock)dataResponseBlock {
    [self.capturedRequests addObject:[urlRequest copy]];
    BOOL isFirstAttempt = self.capturedRequests.count == 1;
    if (isFirstAttempt && self.firstRequestBlock) {
        self.firstRequestBlock();
    }
    NSInteger statusCode = isFirstAttempt ? self.firstResponseStatusCode : self.secondResponseStatusCode;
    NSDictionary *headers = isFirstAttempt ? self.firstResponseHeaders : @{};
    NSString *body = isFirstAttempt ? self.firstResponseBody : self.secondResponseBody;
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:urlRequest.URL
                                                             statusCode:statusCode
                                                            HTTPVersion:@"HTTP/1.1"
                                                           headerFields:headers];
    dataResponseBlock([body dataUsingEncoding:NSUTF8StringEncoding], response, nil);
    return [[NSURLSession sharedSession] dataTaskWithRequest:urlRequest];
}

@end

static SFSDKOAuthNonceRetryNetworkStub *sNonceRetryNetworkStub;

@interface SFNetwork (OAuthNonceRetryTesting)
+ (instancetype)sfsdk_test_sharedEphemeralInstanceWithIdentifier:(NSString *)identifier;
@end

@implementation SFNetwork (OAuthNonceRetryTesting)

+ (instancetype)sfsdk_test_sharedEphemeralInstanceWithIdentifier:(NSString *)identifier {
    return sNonceRetryNetworkStub;
}

@end

@interface SFSDKOAuthTokenEndpointResponseTests : XCTestCase
@property (nonatomic, assign) BOOL networkFactorySwizzled;
@property (nonatomic, assign) BOOL logReceiverFactoryInstalled;
@end

@implementation SFSDKOAuthTokenEndpointResponseTests

- (void)tearDown {
    if (self.logReceiverFactoryInstalled) {
        [SFLogger setLogReceiverFactory:[[SFSDKOAuthNonceRetryNoOpLogReceiverFactory alloc] init]];
        [SFLogger clearAllComponents];
        self.logReceiverFactoryInstalled = NO;
    }
    if (self.networkFactorySwizzled) {
        [self swapNetworkFactoryForNonceRetryTest];
        self.networkFactorySwizzled = NO;
    }
    sNonceRetryNetworkStub = nil;
    [super tearDown];
}

- (void)swapNetworkFactoryForNonceRetryTest {
    Method original = class_getClassMethod([SFNetwork class], @selector(sharedEphemeralInstanceWithIdentifier:));
    Method replacement = class_getClassMethod([SFNetwork class], @selector(sfsdk_test_sharedEphemeralInstanceWithIdentifier:));
    method_exchangeImplementations(original, replacement);
}

- (void)testInitWithDictionary {
    // Prepeare dictionary simulating response from token end point
    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
    [params setObject:@"test-auth-token" forKey:@"access_token"];
    [params setObject:@"test-refresh-token" forKey:@"refresh_token"];
    [params setObject:@"https://instance.salesforce.com" forKey:@"instance_url"];
    [params setObject:@"https://api.salesforce.com" forKey:@"api_instance_url"];
    [params setObject:@"api refresh_token" forKey:@"scope"];
    [params setObject:@"https://id.salesforce.com" forKey:@"id"];
    [params setObject:@"test-community-id" forKey:@"sfdc_community_id"];
    [params setObject:@"https://community.salesforce.com" forKey:@"sfdc_community_url"];
    [params setObject:@"test-lightning-domain" forKey:@"lightning_domain"];
    [params setObject:@"test-lightning-sid" forKey:@"lightning_sid"];
    [params setObject:@"test-vf-domain" forKey:@"visualforce_domain"];
    [params setObject:@"test-vf-sid" forKey:@"visualforce_sid"];
    [params setObject:@"test-content-domain" forKey:@"content_domain"];
    [params setObject:@"test-content-sid" forKey:@"content_sid"];
    [params setObject:@"test-csrf-token" forKey:@"csrf_token"];
    [params setObject:@"test-cookie-client-src" forKey:@"cookie-clientSrc"];
    [params setObject:@"test-cookie-sid-client" forKey:@"cookie-sid_Client"];
    [params setObject:@"test-sid-cookie-name" forKey:@"sidCookieName"];
    [params setObject:@"test-parent-sid" forKey:@"parent_sid"];
    [params setObject:@"test-token-format" forKey:@"token_format"];
    [params setObject:@"test-token-type" forKey:@"token_type"];
    [params setObject:@"test-beacon-child-consumer-key" forKey:@"auto_installed_app_org_consumer_key"];
    [params setObject:@"test-beacon-child-consumer-secret" forKey:@"auto_installed_app_org_consumer_secret"];

    // Additional fields
    NSArray<NSString *>* additionalFields = @[ @"additional-1", @"additional-2" ];
    for (NSString *field in additionalFields) {
        NSString *value = [NSString stringWithFormat:@"test-%@", field];
        [params setObject:value forKey:field];
    }
    
    // Create SFSDKOAuthTokenEndpointResponse with initWithDictionary
    SFSDKOAuthTokenEndpointResponse* response = [[SFSDKOAuthTokenEndpointResponse alloc] initWithDictionary:params parseAdditionalFields:additionalFields];
    
    // Check regular fields
    XCTAssertEqualObjects(response.accessToken, @"test-auth-token");
    XCTAssertEqualObjects(response.refreshToken, @"test-refresh-token");
    XCTAssertEqualObjects(response.instanceUrl.absoluteString, @"https://instance.salesforce.com");
    XCTAssertEqualObjects(response.apiInstanceUrl.absoluteString, @"https://api.salesforce.com");
    XCTAssertEqualObjects(response.scopes, (@[@"api", @"refresh_token"]));
    XCTAssertEqualObjects(response.identityUrl.absoluteString, @"https://id.salesforce.com");
    XCTAssertEqualObjects(response.communityId, @"test-community-id");
    XCTAssertEqualObjects(response.communityUrl.absoluteString, @"https://community.salesforce.com");
    XCTAssertEqualObjects(response.lightningDomain, @"test-lightning-domain");
    XCTAssertEqualObjects(response.lightningSid, @"test-lightning-sid");
    XCTAssertEqualObjects(response.vfDomain, @"test-vf-domain");
    XCTAssertEqualObjects(response.vfSid, @"test-vf-sid");
    XCTAssertEqualObjects(response.contentDomain, @"test-content-domain");
    XCTAssertEqualObjects(response.contentSid, @"test-content-sid");
    XCTAssertEqualObjects(response.csrfToken, @"test-csrf-token");
    XCTAssertEqualObjects(response.cookieClientSrc, @"test-cookie-client-src");
    XCTAssertEqualObjects(response.cookieSidClient, @"test-cookie-sid-client");
    XCTAssertEqualObjects(response.sidCookieName, @"test-sid-cookie-name");
    XCTAssertEqualObjects(response.parentSid, @"test-parent-sid");
    XCTAssertEqualObjects(response.tokenFormat, @"test-token-format");
    XCTAssertEqualObjects(response.tokenType, @"test-token-type");
    XCTAssertEqualObjects(response.beaconChildConsumerKey, @"test-beacon-child-consumer-key");
    XCTAssertEqualObjects(response.beaconChildConsumerSecret, @"test-beacon-child-consumer-secret");

    // Check additional fields
    for (NSString *field in additionalFields) {
        NSString *value = [NSString stringWithFormat:@"test-%@", field];
        XCTAssertEqualObjects(response.additionalOAuthFields[field], value);
    }

}

- (void)test_givenSuccessResponseWithNonStringScope_whenInitialized_thenDropsScopeBeforeCredentialUpdate {
    NSDictionary *params = @{
        @"access_token": @"test-auth-token",
        @"scope": NSNull.null
    };
    SFSDKOAuthTokenEndpointResponse *response = [[SFSDKOAuthTokenEndpointResponse alloc] initWithDictionary:params parseAdditionalFields:nil];

    XCTAssertFalse(response.hasError);
    XCTAssertNil(response.scopes);
    XCTAssertNil([response asDictionary][@"scope"],
                 @"A malformed optional scope must not reach SFOAuthCredentials string handling");
}

// With useDPoP == NO, the prepared token-endpoint request must be byte-identical
// to the pre-DPoP baseline — no DPoP header, same URL/method/headers, even when a
// credentialsIdentifier is set on the endpoint request.
- (void)test_givenUseDPoPDisabled_whenPrepareBasicRequest_thenNoDPoPHeaderAndCanonicalShape {
    BOOL prior = [[SalesforceSDKManager sharedManager] useDPoP];
    [[SalesforceSDKManager sharedManager] setUseDPoP:NO];

    SFSDKOAuthTokenEndpointRequest *endpointReq = [[SFSDKOAuthTokenEndpointRequest alloc] init];
    endpointReq.serverURL = [NSURL URLWithString:@"https://login.salesforce.com"];
    endpointReq.timeout = 60.0;
    endpointReq.credentialsIdentifier = @"some-credentials-id";

    SFSDKOAuth2 *oauth = [[SFSDKOAuth2 alloc] init];
    NSMutableURLRequest *request = [oauth prepareBasicRequest:endpointReq];

    XCTAssertEqualObjects(request.HTTPMethod, @"POST");
    XCTAssertEqualObjects(request.URL.absoluteString, @"https://login.salesforce.com/services/oauth2/token");
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Content-Type"], @"application/x-www-form-urlencoded");
    XCTAssertNil([request valueForHTTPHeaderField:@"DPoP"]);
    XCTAssertFalse(request.HTTPShouldHandleCookies);

    [[SalesforceSDKManager sharedManager] setUseDPoP:prior];
}

- (void)test_givenExplicitUserAgent_whenPrepareBasicRequest_thenHeaderIsPreserved {
    SFSDKOAuthTokenEndpointRequest *endpointReq = [[SFSDKOAuthTokenEndpointRequest alloc] init];
    endpointReq.serverURL = [NSURL URLWithString:@"https://login.salesforce.com"];
    endpointReq.timeout = 60.0;

    endpointReq.userAgent = @"SalesforceMobileSDK/Test ftr_A2.OT.RT";

    NSMutableURLRequest *request = [[[SFSDKOAuth2 alloc] init] prepareBasicRequest:endpointReq];
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"User-Agent"],
                          @"SalesforceMobileSDK/Test ftr_A2.OT.RT");
}

- (void)test_givenNoExplicitUserAgent_whenPrepareBasicRequest_thenHeaderRemainsUnsetForNetworkFallback {
    SFSDKOAuthTokenEndpointRequest *endpointReq = [[SFSDKOAuthTokenEndpointRequest alloc] init];
    endpointReq.serverURL = [NSURL URLWithString:@"https://login.salesforce.com"];
    endpointReq.timeout = 60.0;

    NSMutableURLRequest *request = [[[SFSDKOAuth2 alloc] init] prepareBasicRequest:endpointReq];
    XCTAssertNil([request valueForHTTPHeaderField:@"User-Agent"],
                 @"Requests without explicit context should retain SFNetwork's fallback behavior");
}

- (void)test_givenExplicitUserAgent_whenDPoPNonceChallengeRetries_thenBothAttemptsPreserveHeader {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *expectedUserAgent = @"SalesforceMobileSDK/Test ftr_A2.OT.RT";
    SFSDKOAuthTokenEndpointRequest *endpointReq = [[SFSDKOAuthTokenEndpointRequest alloc] init];
    endpointReq.credentialsIdentifier = [NSString stringWithFormat:@"nonce-retry-%@", NSUUID.UUID.UUIDString];
    endpointReq.userAgent = expectedUserAgent;
    NSString *expectedOwnerKey = @"00D000000000001/005000000000001";
    endpointReq.ownerKey = expectedOwnerKey;

    NSMutableURLRequest *request = [NSMutableURLRequest
                                    requestWithURL:[NSURL URLWithString:@"https://login.salesforce.com/services/oauth2/token"]];
    [request setValue:expectedUserAgent forHTTPHeaderField:@"User-Agent"];

    XCTestExpectation *completion = [self expectationWithDescription:@"Nonce retry completes"];
    [[[SFSDKOAuth2 alloc] init] sendTokenEndpointRequest:request
                                     forEndpointRequest:endpointReq
                                  retryOnNonceChallenge:YES
                                      dataResponseBlock:^(NSData *data, NSURLResponse *response, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(((NSHTTPURLResponse *)response).statusCode, 200);
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 2,
                   @"A DPoP nonce challenge should produce exactly one retry");
#if DEBUG
    XCTAssertEqualObjects(sNonceRetryNetworkStub.capturedOwnerKeys, (@[expectedOwnerKey, expectedOwnerKey]));
#else
    XCTAssertEqualObjects(sNonceRetryNetworkStub.capturedOwnerKeys, (@[@"", @""]));
#endif
    for (NSURLRequest *capturedRequest in sNonceRetryNetworkStub.capturedRequests) {
        XCTAssertEqualObjects([capturedRequest valueForHTTPHeaderField:@"User-Agent"], expectedUserAgent,
                              @"The explicit User-Agent must be reused unchanged on the nonce retry");
    }
}

- (void)test_givenBoundKeyDisappearsAfterNonceChallenge_whenRefreshRetries_thenFailsWithoutSecondRequest {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-boundmissing-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    SFSDKDPoPKeyPair *keyPair = [SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError];
    XCTAssertNotNil(keyPair);
    XCTAssertNil(keyError);
    sNonceRetryNetworkStub.firstRequestBlock = ^{
        [SFSDKDPoPKeyStore.shared deleteForScope:scope];
    };

    SFSDKOAuthTokenEndpointRequest *endpointReq = [[SFSDKOAuthTokenEndpointRequest alloc] init];
    endpointReq.credentialsIdentifier = scope;
    endpointReq.tokenType = @"DPoP";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://login.salesforce.com/services/oauth2/token"]];
    NSError *decorationError = nil;
    [SFSDKDPoPRequestDecorator decorateRequest:request
                                          scope:scope
                                      tokenType:@"DPoP"
                                    accessToken:nil
                                          error:&decorationError];
    XCTAssertNil(decorationError);

    XCTestExpectation *completion = [self expectationWithDescription:@"nonce retry fails locally"];
    [[[SFSDKOAuth2 alloc] init] sendTokenEndpointRequest:request
                                     forEndpointRequest:endpointReq
                                  retryOnNonceChallenge:YES
                                      dataResponseBlock:^(NSData *data, NSURLResponse *response, NSError *error) {
        XCTAssertEqualObjects(error.domain, kSFOAuthErrorDomain);
        XCTAssertEqual(error.code, kSFOAuthErrorInvalidGrant);
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 1u,
                   @"A nonce retry must not create a second task after the bound key disappears");
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (SFSDKOAuthTokenEndpointRequest *)refreshRequestForDPoPScope:(NSString *)scope {
    SFSDKOAuthTokenEndpointRequest *endpointReq = [[SFSDKOAuthTokenEndpointRequest alloc] init];
    endpointReq.clientID = @"test_client_id";
    endpointReq.refreshToken = @"test-refresh-token";
    endpointReq.redirectURI = @"test://callback";
    endpointReq.serverURL = [NSURL URLWithString:@"https://login.salesforce.com"];
    endpointReq.credentialsIdentifier = scope;
    endpointReq.tokenType = @"DPoP";
    endpointReq.timeout = 5.0;
    return endpointReq;
}

- (NSString *)nonceClaimFromDPoPProof:(NSString *)proof {
    NSString *payloadSegment = [proof componentsSeparatedByString:@"."][1];
    NSString *base64 = [[payloadSegment stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
                        stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    NSUInteger paddingLength = (4 - (base64.length % 4)) % 4;
    base64 = [base64 stringByPaddingToLength:base64.length + paddingLength withString:@"=" startingAtIndex:0];
    NSData *payloadData = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil];
    return payload[@"nonce"];
}

- (void)test_givenInvalidDPoPProofBeforeNonceRetry_whenRefreshCompletes_thenMarksTerminalRefreshFailure {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.firstResponseBody = @"{\"error\":\"invalid_dpop_proof\",\"error_description\":\"dpop thumbprint invalid for token\"}";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-unmarked-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);

    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        XCTAssertEqualObjects(response.error.error.userInfo[kSFOAuthError], @"invalid_dpop_proof");
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 1u);
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenBoundDPoPRefresh_whenProofAttached_thenLogsScopeAndPublicJktWithoutSecrets {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.firstResponseStatusCode = 200;
    sNonceRetryNetworkStub.firstResponseBody = @"{\"access_token\":\"refreshed-access-token\"}";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    SFSDKOAuthNonceRetryLogReceiver *logReceiver = [[SFSDKOAuthNonceRetryLogReceiver alloc] init];
    [SFLogger setLogReceiverFactory:[[SFSDKOAuthNonceRetryLogReceiverFactory alloc] initWithReceiver:logReceiver]];
    [SFLogger clearAllComponents];
    self.logReceiverFactoryInstalled = YES;

    NSString *scope = [NSString stringWithFormat:@"refresh-log-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    SFSDKDPoPKeyPair *keyPair = [SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError];
    XCTAssertNotNil(keyPair);
    XCTAssertNil(keyError);
    NSString *expectedJkt = [SFSDKDPoPProofBuilder jwkThumbprintWithPublicKey:keyPair.publicKey error:&keyError];
    XCTAssertNotNil(expectedJkt);
    XCTAssertNil(keyError);

    SFSDKOAuthTokenEndpointRequest *endpointReq = [self refreshRequestForDPoPScope:scope];
    endpointReq.refreshToken = @"refresh-token-that-must-not-be-logged";
    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:endpointReq completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertFalse(response.hasError);
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    NSString *proof = [sNonceRetryNetworkStub.capturedRequests.firstObject valueForHTTPHeaderField:@"DPoP"];
    XCTAssertNotNil(proof, @"The refresh diagnostic is valid only after a proof is attached");
    NSString *expectedMessage = [NSString stringWithFormat:@"DPoP binding at refresh: scope=%@ jkt=%@", scope, expectedJkt];
    XCTAssertTrue([logReceiver.messages containsObject:expectedMessage]);
    for (NSString *message in logReceiver.messages) {
        XCTAssertFalse([message containsString:endpointReq.refreshToken]);
        XCTAssertFalse([message containsString:proof]);
    }
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenDPoPRefreshWithoutBoundKey_whenProofIsNotAttached_thenDoesNotLogRefreshBinding {
    SFSDKOAuthNonceRetryLogReceiver *logReceiver = [[SFSDKOAuthNonceRetryLogReceiver alloc] init];
    [SFLogger setLogReceiverFactory:[[SFSDKOAuthNonceRetryLogReceiverFactory alloc] initWithReceiver:logReceiver]];
    [SFLogger clearAllComponents];
    self.logReceiverFactoryInstalled = YES;

    NSString *scope = [NSString stringWithFormat:@"refresh-log-missing-%@", NSUUID.UUID.UUIDString];
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
    XCTestExpectation *completion = [self expectationWithDescription:@"local refresh failure"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    for (NSString *message in logReceiver.messages) {
        XCTAssertFalse([message containsString:@"DPoP binding at refresh:"],
                       @"A failed proof attachment must not produce a refresh binding diagnostic");
    }
}

- (void)test_givenInvalidDPoPProofAfterNonceRetry_whenRefreshCompletes_thenPreservesOAuthError {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.secondResponseStatusCode = 400;
    sNonceRetryNetworkStub.secondResponseBody = @"{\"error\":\"invalid_dpop_proof\",\"error_description\":\"dpop thumbprint invalid for token\"}";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-marked-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);

    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        XCTAssertEqualObjects(response.error.error.userInfo[kSFOAuthError], @"invalid_dpop_proof");
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 2u);
    for (NSURLRequest *request in sNonceRetryNetworkStub.capturedRequests) {
        XCTAssertNotNil([request valueForHTTPHeaderField:@"DPoP"]);
    }
    XCTAssertEqualObjects([self nonceClaimFromDPoPProof:[sNonceRetryNetworkStub.capturedRequests[1] valueForHTTPHeaderField:@"DPoP"]],
                          @"retry-nonce");
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenNonceRetryReturnsCasedAndPaddedInvalidDPoPProof_whenRefreshCompletes_thenPreservesOAuthError {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.secondResponseStatusCode = 400;
    sNonceRetryNetworkStub.secondResponseBody = @"{\"error\":\"invalid_dpop_proof\",\"error_description\":\"  DPOP THUMBPRINT INVALID FOR TOKEN  \"}";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-normalized-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);

    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        XCTAssertEqualObjects(response.error.error.userInfo[NSLocalizedDescriptionKey], @"  DPOP THUMBPRINT INVALID FOR TOKEN  ");
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 2u);
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenNonceRetryReturnsAnyInvalidDPoPProofDescription_whenRefreshCompletes_thenMarksTerminalRefreshFailure {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.secondResponseStatusCode = 400;
    NSString *unrecognizedDescription = @"server-controlled-unrecognized-description";
    sNonceRetryNetworkStub.secondResponseBody = [NSString stringWithFormat:@"{\"error\":\"invalid_dpop_proof\",\"error_description\":\"%@\"}", unrecognizedDescription];
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    SFSDKOAuthNonceRetryLogReceiver *logReceiver = [[SFSDKOAuthNonceRetryLogReceiver alloc] init];
    [SFLogger setLogReceiverFactory:[[SFSDKOAuthNonceRetryLogReceiverFactory alloc] initWithReceiver:logReceiver]];
    [SFLogger clearAllComponents];
    self.logReceiverFactoryInstalled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-unrecognized-description-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);

    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        XCTAssertEqualObjects(response.error.error.userInfo[NSLocalizedDescriptionKey], unrecognizedDescription);
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 2u);
    for (NSString *message in logReceiver.messages) {
        XCTAssertFalse([message containsString:unrecognizedDescription],
                       @"The terminal decision must not log an untrusted server description");
    }
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenNonceChallengeBodyContainsOnlySubstring_whenRefreshCompletes_thenPreservesOAuthError {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.firstResponseBody = @"{\"error\":\"not_use_dpop_nonce\"}";
    sNonceRetryNetworkStub.secondResponseStatusCode = 400;
    sNonceRetryNetworkStub.secondResponseBody = @"{\"error\":\"invalid_dpop_proof\",\"error_description\":\"dpop thumbprint invalid for token\"}";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-substring-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);

    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        XCTAssertEqualObjects(response.error.error.userInfo[kSFOAuthError], @"not_use_dpop_nonce");
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 1u);
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenNonceChallengeBodyIsNotJSONObject_whenRefreshCompletes_thenReturnsMalformedResponseWithoutRetry {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.firstResponseBody = @"[\"use_dpop_nonce\"]";
    sNonceRetryNetworkStub.secondResponseStatusCode = 400;
    sNonceRetryNetworkStub.secondResponseBody = @"{\"error\":\"invalid_dpop_proof\",\"error_description\":\"dpop thumbprint invalid for token\"}";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-malformed-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);

    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        XCTAssertEqualObjects(response.error.error.userInfo[kSFOAuthError], @"malformed_response");
        XCTAssertNil(response.error.error.userInfo[@"response_data"]);
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 1u);
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenNonceChallengeHasOptionalNonStringDescription_whenRefreshCompletes_thenRetries {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.firstResponseBody = @"{\"error\":\"use_dpop_nonce\",\"error_description\":null}";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-initial-fields-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);

    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertFalse(response.hasError);
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 2u);
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenRetryResponseIsNotJSONObject_whenRefreshCompletes_thenReturnsMalformedResponse {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.secondResponseStatusCode = 400;
    sNonceRetryNetworkStub.secondResponseBody = @"[]";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-final-array-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);

    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        XCTAssertEqualObjects(response.error.error.userInfo[kSFOAuthError], @"malformed_response");
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 2u);
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenRetryResponseHasNonStringOAuthErrorFields_whenRefreshCompletes_thenReturnsMalformedResponse {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.secondResponseStatusCode = 400;
    sNonceRetryNetworkStub.secondResponseBody = @"{\"error\":{},\"error_description\":{}}";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-final-fields-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);

    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        XCTAssertEqualObjects(response.error.error.userInfo[kSFOAuthError], @"malformed_response");
        XCTAssertNil(response.error.error.userInfo[@"response_data"]);
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 2u);
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenMalformedOAuthErrorContainsToken_whenRefreshCompletes_thenDoesNotExposeResponseData {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.secondResponseStatusCode = 400;
    sNonceRetryNetworkStub.secondResponseBody = @"{\"error\":null,\"access_token\":\"secret-access-token\",\"refresh_token\":\"secret-refresh-token\"}";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-token-bearing-malformed-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);

    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        XCTAssertEqualObjects(response.error.error.userInfo[kSFOAuthError], @"malformed_response");
        XCTAssertNil(response.error.error.userInfo[@"response_data"]);
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 2u);
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenRetryResponseOmitsErrorDescription_whenRefreshCompletes_thenMarksTerminalRefreshFailure {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.secondResponseStatusCode = 400;
    sNonceRetryNetworkStub.secondResponseBody = @"{\"error\":\"invalid_dpop_proof\"}";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-no-description-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);

    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        XCTAssertEqualObjects(response.error.error.userInfo[kSFOAuthError], @"invalid_dpop_proof");
        XCTAssertEqualObjects(response.error.error.userInfo[NSLocalizedDescriptionKey], @"");
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 2u);
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenRetryResponseHasNonStringScope_whenRefreshCompletes_thenMarksTerminalRefreshFailure {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.secondResponseStatusCode = 400;
    sNonceRetryNetworkStub.secondResponseBody = @"{\"error\":\"invalid_dpop_proof\",\"scope\":null}";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-final-scope-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);

    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        XCTAssertEqualObjects(response.error.error.userInfo[kSFOAuthError], @"invalid_dpop_proof");
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 2u);
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenHeaderOnlyNonceChallenge_whenRefreshCompletes_thenDoesNotRetry {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.firstResponseBody = @"";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-header-only-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);

    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        XCTAssertEqualObjects(response.error.error.userInfo[kSFOAuthError], @"malformed_response");
        XCTAssertNil(response.error.error.userInfo[@"response_data"]);
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 1u,
                   @"RFC 9449 token-endpoint nonce challenges require an OAuth JSON error body");
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenUseDPoPNonceWithoutNonceHeader_whenRefreshCompletes_thenMarksTerminalRefreshFailure {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.firstResponseHeaders = @{};
    sNonceRetryNetworkStub.secondResponseStatusCode = 400;
    sNonceRetryNetworkStub.secondResponseBody = @"{\"error\":\"invalid_dpop_proof\",\"error_description\":\"dpop thumbprint invalid for token\"}";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-no-header-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);

    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        XCTAssertEqualObjects(response.error.error.userInfo[kSFOAuthError], @"invalid_dpop_proof");
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 2u);
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenInvalidDPoPProofWithNon400Response_whenRefreshCompletes_thenMarksTerminalRefreshFailure {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.secondResponseStatusCode = 500;
    sNonceRetryNetworkStub.secondResponseBody = @"{\"error\":\"invalid_dpop_proof\",\"error_description\":\"dpop thumbprint invalid for token\"}";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-non400-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);

    XCTestExpectation *completion = [self expectationWithDescription:@"refresh completes"];
    [[[SFSDKOAuth2 alloc] init] accessTokenForRefresh:[self refreshRequestForDPoPScope:scope] completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        XCTAssertEqualObjects(response.error.error.userInfo[kSFOAuthError], @"invalid_dpop_proof");
        [completion fulfill];
    }];
    [self waitForExpectations:@[completion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 2u);
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

- (void)test_givenEndpointRequestReusedForApprovalCode_whenInvalidDPoPProofCompletes_thenPreservesOAuthError {
    sNonceRetryNetworkStub = [[SFSDKOAuthNonceRetryNetworkStub alloc] init];
    sNonceRetryNetworkStub.secondResponseStatusCode = 400;
    sNonceRetryNetworkStub.secondResponseBody = @"{\"error\":\"invalid_dpop_proof\",\"error_description\":\"dpop thumbprint invalid for token\"}";
    [self swapNetworkFactoryForNonceRetryTest];
    self.networkFactorySwizzled = YES;

    NSString *scope = [NSString stringWithFormat:@"nonce-retry-reused-request-%@", NSUUID.UUID.UUIDString];
    NSError *keyError = nil;
    XCTAssertNotNil([SFSDKDPoPKeyStore.shared keyPairForScope:scope error:&keyError]);
    XCTAssertNil(keyError);
    SFSDKOAuthTokenEndpointRequest *endpointReq = [self refreshRequestForDPoPScope:scope];
    SFSDKOAuth2 *oauth = [[SFSDKOAuth2 alloc] init];

    XCTestExpectation *refreshCompletion = [self expectationWithDescription:@"refresh completes"];
    [oauth accessTokenForRefresh:endpointReq completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertEqualObjects(response.error.error.userInfo[kSFOAuthError], @"invalid_dpop_proof");
        [refreshCompletion fulfill];
    }];
    [self waitForExpectations:@[refreshCompletion] timeout:2.0];

    [sNonceRetryNetworkStub.capturedRequests removeAllObjects];
    sNonceRetryNetworkStub.firstResponseBody = @"{\"error\":\"invalid_dpop_proof\",\"error_description\":\"dpop thumbprint invalid for token\"}";
    endpointReq.approvalCode = @"test-approval-code";
    endpointReq.codeVerifier = @"test-code-verifier";
    XCTestExpectation *approvalCodeCompletion = [self expectationWithDescription:@"approval code completes"];
    [oauth accessTokenForApprovalCode:endpointReq completion:^(SFSDKOAuthTokenEndpointResponse *response) {
        XCTAssertTrue(response.hasError);
        XCTAssertEqualObjects(response.error.error.userInfo[kSFOAuthError], @"invalid_dpop_proof");
        [approvalCodeCompletion fulfill];
    }];
    [self waitForExpectations:@[approvalCodeCompletion] timeout:2.0];

    XCTAssertEqual(sNonceRetryNetworkStub.capturedRequests.count, 1u);
    [SFSDKDPoPKeyStore.shared deleteForScope:scope];
}

@end
