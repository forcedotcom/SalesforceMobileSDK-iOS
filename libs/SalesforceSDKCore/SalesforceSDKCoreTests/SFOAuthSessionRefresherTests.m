/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFOAuthSessionRefresher+Internal.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFUserAccount+Internal.h"
#import "SFUserAccountManager+Internal.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFSDKOAuth2+Internal.h"
#import "SFSDKAppFeatureMarkers.h"
#import "SFSDKOAuthConstants.h"

// Expose the private initializer used in production code.
@interface SFSDKOAuthTokenEndpointResponse ()
- (instancetype)initWithDictionary:(NSDictionary *)nvPairs parseAdditionalFields:(NSArray<NSString *> *)additionalOAuthParameterKeys;
@end

static NSSet<NSString *> *SFSDKFeatureMarkersFromUserAgent(NSString *userAgent) {
    NSRange featurePrefixRange = [userAgent rangeOfString:@"ftr_"];
    if (featurePrefixRange.location == NSNotFound) return [NSSet set];
    NSString *featureSuffix = [userAgent substringFromIndex:NSMaxRange(featurePrefixRange)];
    NSString *featureString = [featureSuffix componentsSeparatedByString:@" "].firstObject ?: @"";
    return [NSSet setWithArray:[featureString componentsSeparatedByString:@"."]];
}

// Minimal SFSDKOAuthProtocol stub that immediately calls the completion block with a preset response.
@interface SFSDKOAuthClientStub : NSObject <SFSDKOAuthProtocol>
@property (nonatomic, strong) SFSDKOAuthTokenEndpointResponse *stubbedResponse;
@property (nonatomic, strong, nullable) SFSDKOAuthTokenEndpointRequest *capturedRefreshRequest;
@property (nonatomic, copy, nullable) void (^beforeCompletion)(void);
@end

@implementation SFSDKOAuthClientStub
- (void)accessTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq
                   completion:(void (^)(SFSDKOAuthTokenEndpointResponse *))completionBlock {
    self.capturedRefreshRequest = endpointReq;
    if (self.beforeCompletion) {
        self.beforeCompletion();
    }
    completionBlock(self.stubbedResponse);
}
- (void)accessTokenForApprovalCode:(SFSDKOAuthTokenEndpointRequest *)endpointReq
                        completion:(void (^)(SFSDKOAuthTokenEndpointResponse *))completionBlock {}
- (void)openIDTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq
                   completion:(void (^)(NSString *))completionBlock {}
- (void)revokeRefreshToken:(SFOAuthCredentials *)credentials reason:(SFLogoutReason)reason {}
@end

// TODO: Remove deprecated warning suppression when SFOAuthSessionRefresher is internal in Mobile SDK 15.0
SFSDK_USE_DEPRECATED_BEGIN

@interface SFOAuthSessionRefresher (Testing)
- (nullable SFUserAccount *)accountForCredentials;
@end

@interface SFSDKCountingOAuthSessionRefresher : SFOAuthSessionRefresher
@property (nonatomic, assign) NSUInteger accountLookupCount;
@end

@implementation SFSDKCountingOAuthSessionRefresher
- (SFUserAccount *)accountForCredentials {
    self.accountLookupCount += 1;
    return [super accountForCredentials];
}
@end

@interface SFOAuthSessionRefresherTests : XCTestCase

@property (nonatomic, strong) SFOAuthSessionRefresher *oauthSessionRefresher;
@end

@implementation SFOAuthSessionRefresherTests

- (void)setUp {
    [super setUp];
    [self setupCoordinatorFlow];
}

- (void)tearDown {
    [self tearDownCoordinatorFlow];
    [super tearDown];
}

- (void)testBadInputData {
    __block NSError *inputError = nil;
    
    // Invalid Instance URL
    XCTestExpectation *invalidInputExpectation = [self expectationWithDescription:@"Refresh with invalid Instance URL"];
    NSURL *origUrl = self.oauthSessionRefresher.credentials.instanceUrl;
    self.oauthSessionRefresher.credentials.instanceUrl = nil;
    [self.oauthSessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
        [invalidInputExpectation fulfill];
    } error:^(NSError *refreshError) {
        inputError = refreshError;
        [invalidInputExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2.0 handler:^(NSError *error) {
        XCTAssertNil(error, @"Error waiting for completion: %@", error);
        XCTAssertNotNil(inputError, @"Should have received an input error for bad Instance URL.");
        XCTAssertTrue(inputError.code == SFOAuthSessionRefreshErrorCodeInvalidCredentials, @"Wrong error code for input error");
        self.oauthSessionRefresher.credentials.instanceUrl = origUrl;
    }];
    
    // Invalid Client ID
    inputError = nil;
    invalidInputExpectation = [self expectationWithDescription:@"Refresh with invalid Client ID"];
    NSString *origClientId = self.oauthSessionRefresher.credentials.clientId;
    self.oauthSessionRefresher.credentials.clientId = nil;
    [self.oauthSessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
        [invalidInputExpectation fulfill];
    } error:^(NSError *refreshError) {
        inputError = refreshError;
        [invalidInputExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2.0 handler:^(NSError *error) {
        XCTAssertNil(error, @"Error waiting for completion: %@", error);
        XCTAssertNotNil(inputError, @"Should have received an input error for bad Client ID.");
        XCTAssertTrue(inputError.code == SFOAuthSessionRefreshErrorCodeInvalidCredentials, @"Wrong error code for input error");
        self.oauthSessionRefresher.credentials.clientId = origClientId;
    }];
    
    // Invalid Refresh Token
    inputError = nil;
    invalidInputExpectation = [self expectationWithDescription:@"Refresh with invalid Refresh Token"];
    NSString *origRefreshToken = self.oauthSessionRefresher.credentials.refreshToken;
    self.oauthSessionRefresher.credentials.refreshToken = nil;
    self.oauthSessionRefresher.credentials.instanceUrl = origUrl;  // Nil'ed out as side effect of nil refresh token in SFOAuthCredentials.
    [self.oauthSessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
        [invalidInputExpectation fulfill];
    } error:^(NSError *refreshError) {
        inputError = refreshError;
        [invalidInputExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2.0 handler:^(NSError *error) {
        XCTAssertNil(error, @"Error waiting for completion: %@", error);
        XCTAssertNotNil(inputError, @"Should have received an input error for bad Refresh Token.");
        XCTAssertTrue(inputError.code == SFOAuthSessionRefreshErrorCodeInvalidCredentials, @"Wrong error code for input error");
        self.oauthSessionRefresher.credentials.refreshToken = origRefreshToken;
    }];
}

- (void)testFailedRefresh {
    __block NSError *refreshFailsError = nil;
    XCTestExpectation *refreshAccessTokenExpectation = [self expectationWithDescription:@"Refresh Access Token fails"];
    [self.oauthSessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
        [refreshAccessTokenExpectation fulfill];
    } error:^(NSError *refreshError) {
        refreshFailsError = refreshError;
        [refreshAccessTokenExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2.0 handler:^(NSError *error) {
        XCTAssertNil(error, @"Error waiting for completion: %@", error);
        XCTAssertNotNil(refreshFailsError, @"Should have received an error refreshing the access token.");
    }];
}

- (void)test_givenRotatedRefreshToken_whenRefreshSucceeds_thenRTFlagRegisteredPerUser {
    // Arrange: register a user account whose credentials match the refresher's.
    SFOAuthCredentials *creds = self.oauthSessionRefresher.credentials;
    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:creds];
    [[SFUserAccountManager sharedInstance] saveAccountForUser:account error:nil];

    NSString *newRefreshToken = [NSString stringWithFormat:@"rotated_token_%u", arc4random()];
    NSDictionary *responseDict = @{
        kSFOAuthAccessToken: @"new_access_token",
        kSFOAuthRefreshToken: newRefreshToken,
    };
    SFSDKOAuthTokenEndpointResponse *response = [[SFSDKOAuthTokenEndpointResponse alloc]
                                                  initWithDictionary:responseDict
                                                  parseAdditionalFields:nil];
    SFSDKOAuthClientStub *stub = [[SFSDKOAuthClientStub alloc] init];
    stub.stubbedResponse = response;
    SFAuthClientFactoryBlock originalFactory = [SFUserAccountManager sharedInstance].authClient;
    [SFUserAccountManager sharedInstance].authClient = ^{ return stub; };

    // Pre-condition: RT flag not set
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureRTR forUser:account];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Refresh with rotated token"];
    [self.oauthSessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
        [expectation fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Refresh should not fail: %@", error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    // Assert: RT flag registered for the user
    NSSet *features = [SFSDKAppFeatureMarkers appFeaturesForUser:account];
    XCTAssertTrue([features containsObject:kSFAppFeatureRTR],
                  @"RT flag should be registered after refresh token rotation");

    // Assert: timestamp was stamped
    XCTAssertNotNil(account.credentials.lastTokenRotationDate, @"Expected rotation timestamp to be stamped");
    XCTAssertLessThan(fabs([account.credentials.lastTokenRotationDate timeIntervalSinceNow]), 5.0,
                      @"Rotation timestamp should be within 5 seconds of now");
    XCTAssertEqual(((SFSDKCountingOAuthSessionRefresher *)self.oauthSessionRefresher).accountLookupCount, 2,
                   @"A rotated refresh should perform one request-time and one post-response lookup");

    // Cleanup
    [SFUserAccountManager sharedInstance].authClient = originalFactory;
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureRTR forUser:account];
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:account error:nil];
}

- (void)test_givenDPoPBoundCredential_whenRefresh_thenEndpointRequestCarriesTokenTypeAndScope {
    // Given: a DPoP-bound credential (tokenType = "DPoP") with a scope identifier
    SFOAuthCredentials *creds = self.oauthSessionRefresher.credentials;
    creds.tokenType = @"DPoP";
    NSString *expectedScope = creds.identifier;

    NSDictionary *responseDict = @{ kSFOAuthAccessToken: @"new_access_token",
                                    kSFOAuthRefreshToken: creds.refreshToken };
    SFSDKOAuthTokenEndpointResponse *response = [[SFSDKOAuthTokenEndpointResponse alloc]
                                                  initWithDictionary:responseDict
                                                  parseAdditionalFields:nil];
    SFSDKOAuthClientStub *stub = [[SFSDKOAuthClientStub alloc] init];
    stub.stubbedResponse = response;
    SFAuthClientFactoryBlock originalFactory = [SFUserAccountManager sharedInstance].authClient;
    [SFUserAccountManager sharedInstance].authClient = ^{ return stub; };

    // When: refresh runs
    XCTestExpectation *expectation = [self expectationWithDescription:@"Refresh carries DPoP tokenType"];
    [self.oauthSessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
        [expectation fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Refresh should not fail: %@", error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    // Then: the outbound endpoint request carries both signals the DPoP layer needs
    XCTAssertNotNil(stub.capturedRefreshRequest, @"Stub should have captured the refresh request");
    XCTAssertEqualObjects(stub.capturedRefreshRequest.tokenType, @"DPoP",
                          @"Refresher must forward credentials.tokenType so DPoP gating survives a global-flag flip");
    XCTAssertEqualObjects(stub.capturedRefreshRequest.credentialsIdentifier, expectedScope,
                          @"Refresher must forward credentials.identifier as the DPoP scope");

    // Cleanup
    [SFUserAccountManager sharedInstance].authClient = originalFactory;
}

- (void)test_givenCredentialOwnerDiffersFromCurrentUser_whenRefresh_thenEndpointRequestCarriesOwnerUserAgent {
    SFUserAccountManager *accountManager = [SFUserAccountManager sharedInstance];
    SFUserAccount *originalCurrentUser = accountManager.currentUser;

    SFOAuthCredentials *ownerCredentials = self.oauthSessionRefresher.credentials;
    SFUserAccount *ownerAccount = [[SFUserAccount alloc] initWithCredentials:ownerCredentials];
    [accountManager saveAccountForUser:ownerAccount error:nil];
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureRTR forUser:ownerAccount];
    [SFSDKAppFeatureMarkers registerAppFeature:@"OW" forUser:ownerAccount];

    SFOAuthCredentials *currentCredentials = [[SFOAuthCredentials alloc]
                                               initWithIdentifier:[NSString stringWithFormat:@"CurrentCredentials_%u", arc4random()]
                                               clientId:@"current-client-id"
                                               encrypted:YES];
    currentCredentials.userId = @"005000000000002";
    currentCredentials.organizationId = @"00D000000000002";
    currentCredentials.instanceUrl = [NSURL URLWithString:@"https://cs2.salesforce.com"];
    currentCredentials.accessToken = @"current-access-token";
    currentCredentials.refreshToken = @"current-refresh-token";
    SFUserAccount *currentAccount = [[SFUserAccount alloc] initWithCredentials:currentCredentials];
    [accountManager saveAccountForUser:currentAccount error:nil];
    [SFSDKAppFeatureMarkers registerAppFeature:@"CU" forUser:currentAccount];
    [accountManager setCurrentUserInternal:currentAccount];

    NSDictionary *responseDict = @{ kSFOAuthAccessToken: @"new_access_token",
                                    kSFOAuthRefreshToken: ownerCredentials.refreshToken };
    SFSDKOAuthTokenEndpointResponse *response = [[SFSDKOAuthTokenEndpointResponse alloc]
                                                  initWithDictionary:responseDict
                                                  parseAdditionalFields:nil];
    SFSDKOAuthClientStub *stub = [[SFSDKOAuthClientStub alloc] init];
    stub.stubbedResponse = response;
    SFAuthClientFactoryBlock originalFactory = accountManager.authClient;
    accountManager.authClient = ^{ return stub; };

    XCTestExpectation *expectation = [self expectationWithDescription:@"Refresh carries credential-owner User-Agent"];
    [self.oauthSessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
        [expectation fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Refresh should not fail: %@", error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    NSString *userAgent = stub.capturedRefreshRequest.userAgent;
    XCTAssertNotNil(userAgent, @"Refresh endpoint request must carry an explicit credential-owner User-Agent");
    NSSet<NSString *> *featureMarkers = SFSDKFeatureMarkersFromUserAgent(userAgent);
    XCTAssertTrue([featureMarkers containsObject:@"OW"], @"Owner marker should be present in %@", userAgent);
    XCTAssertTrue([featureMarkers containsObject:@"RT"], @"Persisted RT marker should be present in %@", userAgent);
    XCTAssertFalse([featureMarkers containsObject:@"CU"], @"Ambient current-user marker must not leak into %@", userAgent);

    accountManager.authClient = originalFactory;
    [accountManager setCurrentUserInternal:originalCurrentUser];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureRTR forUser:ownerAccount];
    [SFSDKAppFeatureMarkers unregisterAppFeature:@"OW" forUser:ownerAccount];
    [SFSDKAppFeatureMarkers unregisterAppFeature:@"CU" forUser:currentAccount];
    [accountManager deleteAccountForUser:ownerAccount error:nil];
    [accountManager deleteAccountForUser:currentAccount error:nil];
}

- (void)test_givenUnchangedRefreshToken_whenRefreshSucceeds_thenRTFlagNotRegistered {
    // Arrange: same refresh token in response — no rotation
    SFOAuthCredentials *creds = self.oauthSessionRefresher.credentials;
    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:creds];
    [[SFUserAccountManager sharedInstance] saveAccountForUser:account error:nil];

    // Pre-seed a known prior timestamp
    account.credentials.lastTokenRotationDate = [NSDate dateWithTimeIntervalSince1970:1234567890];

    NSDictionary *responseDict = @{
        kSFOAuthAccessToken: @"new_access_token",
        kSFOAuthRefreshToken: creds.refreshToken,  // same token — no rotation
    };
    SFSDKOAuthTokenEndpointResponse *response = [[SFSDKOAuthTokenEndpointResponse alloc]
                                                  initWithDictionary:responseDict
                                                  parseAdditionalFields:nil];
    SFSDKOAuthClientStub *stub = [[SFSDKOAuthClientStub alloc] init];
    stub.stubbedResponse = response;
    SFAuthClientFactoryBlock originalFactory = [SFUserAccountManager sharedInstance].authClient;
    [SFUserAccountManager sharedInstance].authClient = ^{ return stub; };

    XCTestExpectation *expectation = [self expectationWithDescription:@"Refresh without rotation"];
    [self.oauthSessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
        [expectation fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Refresh should not fail: %@", error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    // Assert: RT flag NOT registered
    NSSet *features = [SFSDKAppFeatureMarkers appFeaturesForUser:account];
    XCTAssertFalse([features containsObject:kSFAppFeatureRTR],
                   @"RT flag should not be registered when refresh token did not rotate");

    // Assert: timestamp preserved
    XCTAssertEqualWithAccuracy([account.credentials.lastTokenRotationDate timeIntervalSince1970], 1234567890, 0.001,
                               @"Rotation timestamp must be preserved when no rotation occurred");
    XCTAssertEqual(((SFSDKCountingOAuthSessionRefresher *)self.oauthSessionRefresher).accountLookupCount, 2,
                   @"An unchanged refresh should perform one request-time and one post-response lookup");

    // Cleanup
    [SFUserAccountManager sharedInstance].authClient = originalFactory;
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:account error:nil];
}

- (void)test_givenAccountRemovedDuringRefresh_whenRotatedTokenSucceeds_thenNotificationOmitsAccount {
    SFOAuthCredentials *credentials = self.oauthSessionRefresher.credentials;
    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:credentials];
    SFUserAccountManager *accountManager = [SFUserAccountManager sharedInstance];
    [accountManager saveAccountForUser:account error:nil];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureRTR forUser:account];

    NSDictionary *responseDictionary = @{
        kSFOAuthAccessToken: @"new_access_token",
        kSFOAuthRefreshToken: [NSString stringWithFormat:@"rotated_token_%u", arc4random()],
    };
    SFSDKOAuthTokenEndpointResponse *response = [[SFSDKOAuthTokenEndpointResponse alloc]
                                                  initWithDictionary:responseDictionary
                                                  parseAdditionalFields:nil];
    SFSDKOAuthClientStub *stub = [[SFSDKOAuthClientStub alloc] init];
    stub.stubbedResponse = response;
    stub.beforeCompletion = ^{
        [accountManager deleteAccountForUser:account error:nil];
    };
    SFAuthClientFactoryBlock originalFactory = accountManager.authClient;
    accountManager.authClient = ^{ return stub; };

    __block NSDictionary *notificationUserInfo = nil;
    id observer = [[NSNotificationCenter defaultCenter]
                   addObserverForName:kSFNotificationUserDidRefreshToken
                   object:accountManager
                   queue:nil
                   usingBlock:^(NSNotification *notification) {
        notificationUserInfo = notification.userInfo;
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Refresh after account removal"];
    [self.oauthSessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
        [expectation fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Refresh should still complete after account removal: %@", error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    XCTAssertNotNil(notificationUserInfo, @"A successful refresh should still post its notification");
    XCTAssertNil(notificationUserInfo[kSFNotificationUserInfoAccountKey],
                 @"A removed account must not be carried across the asynchronous refresh");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeaturesForUser:account] containsObject:kSFAppFeatureRTR],
                   @"RTR must not be registered for an account removed during refresh");
    XCTAssertEqual(((SFSDKCountingOAuthSessionRefresher *)self.oauthSessionRefresher).accountLookupCount, 2,
                   @"Account removal should be observed by the single post-response lookup");

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    accountManager.authClient = originalFactory;
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureRTR forUser:account];
}

#pragma mark - Private methods

- (void)setupCoordinatorFlow {
    NSString *credsIdentifier = [NSString stringWithFormat:@"CredsIdentifier_%u", arc4random()];
    NSString *credsClientId = [NSString stringWithFormat:@"CredsClientId_%u", arc4random()];
    NSString *credsAccessToken = [NSString stringWithFormat:@"CredsAccessToken_%u", arc4random()];
    NSString *credsRefreshToken = [NSString stringWithFormat:@"CredsRefreshToken_%u", arc4random()];
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:credsIdentifier clientId:credsClientId encrypted:YES];
    creds.redirectUri = [NSString stringWithFormat:@"sfdcUnitTest:///redirect_uri_%u", arc4random()];
    creds.instanceUrl = [NSURL URLWithString:@"https://cs1.salesforce.com"];
    creds.accessToken = credsAccessToken;
    creds.refreshToken = credsRefreshToken;
    // Set userId and orgId as valid 15-char Salesforce entity IDs so matchesCredentials: can compare them.
    // (sfsdk_entityId18 returns nil for non-conforming strings, making isEqualToString:nil == NO.)
    creds.userId = @"005000000000001";
    creds.organizationId = @"00D000000000001";
    self.oauthSessionRefresher = [[SFSDKCountingOAuthSessionRefresher alloc] initWithCredentials:creds];
}

- (void)tearDownCoordinatorFlow {
    [self.oauthSessionRefresher.credentials revoke];
    self.oauthSessionRefresher = nil;
}

@end

SFSDK_USE_DEPRECATED_END
