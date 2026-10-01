/*
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
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFOAuthCoordinator+Internal.h"
#import "SFUserAccount+Internal.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFSDKAuthSession.h"
#import "SFSDKAuthRequest.h"
#import "SFOAuthTestFlowCoordinatorDelegate.h"
#import "SFSDKAppFeatureMarkers.h"
#import "SalesforceSDKManager+Internal.h"
#import "SFSDKOAuth2+Internal.h"
#import "SFUserAccountManager+Internal.h"
#import "SFOAuthSessionRefresher.h"
#import "SFOAuthSessionRefresher+Internal.h"
#import "SFSDKTokenRefreshCoordinator.h"
#import "SFSDKResourceUtils.h"
#import "SFSDKOAuthConstants.h"

/// Expose the private designated initializer so tests can build a canned token-endpoint response.
@interface SFSDKOAuthTokenEndpointResponse ()
- (instancetype)initWithDictionary:(NSDictionary *)nvPairs parseAdditionalFields:(NSArray<NSString *> *)additionalOAuthParameterKeys;
@end

/// OAuth client stub for the coordinator tests. The authorization-code (login) branch still calls
/// `accessTokenForApprovalCode:` directly, so that returns a canned response. The refresh branch now
/// routes through the shared `SFSDKTokenRefreshCoordinator` and must NOT touch `authClient` anymore,
/// so `accessTokenForRefresh:` records the illegal call (and deliberately never completes, which also
/// surfaces as a test timeout) to guard the reroute. Named distinctly from the refresher test's stub
/// to avoid a duplicate-symbol clash within the shared test target.
@interface SFSDKCoordinatorRefreshClientStub : NSObject <SFSDKOAuthProtocol>
@property (nonatomic, strong) SFSDKOAuthTokenEndpointResponse *approvalCodeResponse;
@property (atomic, assign) BOOL accessTokenForRefreshCalled;
@property (atomic, assign) NSInteger accessTokenForApprovalCodeCount;
@end

@implementation SFSDKCoordinatorRefreshClientStub
- (void)accessTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq
                   completion:(void (^)(SFSDKOAuthTokenEndpointResponse *))completionBlock {
    // The coordinator refresh branch must never call authClient directly after the reroute.
    self.accessTokenForRefreshCalled = YES;
}
- (void)accessTokenForApprovalCode:(SFSDKOAuthTokenEndpointRequest *)endpointReq
                        completion:(void (^)(SFSDKOAuthTokenEndpointResponse *))completionBlock {
    self.accessTokenForApprovalCodeCount++;
    completionBlock(self.approvalCodeResponse);
}
- (void)openIDTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq
                   completion:(void (^)(NSString *))completionBlock {}
- (void)revokeRefreshToken:(SFOAuthCredentials *)credentials reason:(SFLogoutReason)reason {}
@end

/// Mock `SFOAuthSessionRefresher` injected through `SFSDKTokenRefreshCoordinator.refresherFactory`.
/// Lets the coordinator-reroute tests drive the shared refresh path without a network: it counts
/// invocations, can force an error, can simulate refresh-token rotation (stamping
/// `lastTokenRotationDate` and registering the RT marker exactly like the real refresher), and can
/// return a credentials instance other than the one it was created with (to exercise the coalesced
/// in-flight case). Named distinctly from `SingleUseTokenMockRefresher` to avoid a duplicate symbol.
@interface SFSDKCoordinatorMockRefresher : SFOAuthSessionRefresher
@property (atomic, assign) NSInteger refreshCallCount;
@property (nonatomic, strong, nullable) NSError *forcedError;
/// When set, the success completion returns this instance instead of `self.credentials`.
@property (nonatomic, strong, nullable) SFOAuthCredentials *overrideCompletionCredentials;
/// When set, simulate a rotating response: adopt this refresh token, stamp the rotation date, and
/// register the RT feature marker for the credential owner (mirrors SFOAuthSessionRefresher).
@property (nonatomic, copy, nullable) NSString *rotatedRefreshToken;
@end

@implementation SFSDKCoordinatorMockRefresher

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)refreshSessionWithCompletion:(void (^)(SFOAuthCredentials *))completionBlock error:(void (^)(NSError *))errorBlock {
    self.refreshCallCount++;
    if (self.forcedError) {
        if (errorBlock) {
            errorBlock(self.forcedError);
        }
        return;
    }
    SFOAuthCredentials *result = self.overrideCompletionCredentials ?: self.credentials;
    result.accessToken = @"mock_new_access_token";
    if (self.rotatedRefreshToken) {
        result.refreshToken = self.rotatedRefreshToken;
        result.lastTokenRotationDate = [NSDate date];
        SFUserAccount *account = [[SFUserAccountManager sharedInstance] accountForCredentials:result];
        if (account) {
            [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureRTR forUser:account];
        }
    }
    if (completionBlock) {
        completionBlock(result);
    }
}
#pragma clang diagnostic pop

@end

/// Forward-declares the private refresh/login entry point so the login-path test can drive it
/// directly without standing up a full web auth flow.
@interface SFOAuthCoordinator (CoordinatorRTRTests)
- (void)beginTokenEndpointFlow;
@end

@interface SFOAuthCoordinatorTests : XCTestCase

// SFOAuthCoordinator.authSession is weak; production code keeps it alive via
// SFUserAccountManager's authSessions store, so tests must retain it here for as long as
// the coordinator under test needs to read authSession.oauthRequest (e.g. computeAuthTrigger).
@property (nonatomic, strong) SFSDKAuthSession *retainedAuthSession;

@end

@implementation SFOAuthCoordinatorTests

- (void)tearDown {
    // Several tests install a mock refresher on the process-wide shared coordinator; always clear it
    // so unrelated tests fall back to the real refresher.
    [SFSDKTokenRefreshCoordinator sharedInstance].refresherFactory = nil;
    [super tearDown];
}

/// Builds the injected mock refresher. Isolates the deprecated `initWithCredentials:` call.
- (SFSDKCoordinatorMockRefresher *)makeMockRefresherForCredentials:(SFOAuthCredentials *)creds {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [[SFSDKCoordinatorMockRefresher alloc] initWithCredentials:creds];
#pragma clang diagnostic pop
}

- (void)testMigrateRefreshTokenSetup {
    // Create test credentials
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testIdentifier" clientId:@"testClientId" encrypted:NO];
    credentials.redirectUri = @"testapp://callback";
    credentials.domain = @"test.salesforce.com";
    credentials.accessToken = @"testAccessToken";
    credentials.refreshToken = @"testRefreshToken";
    credentials.instanceUrl = [NSURL URLWithString:@"https://test.salesforce.com"];
    
    // Create a test user account (not fully logged in to avoid actual API calls)
    SFUserAccount *userAccount = [[SFUserAccount alloc] initWithCredentials:credentials];
    
    // Create auth request and session
    SFSDKAuthRequest *authRequest = [[SFSDKAuthRequest alloc] init];
    authRequest.oauthClientId = @"newClientId";
    authRequest.oauthCompletionUrl = @"newapp://callback";
    authRequest.loginHost = @"login.salesforce.com";
    
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] initWith:authRequest credentials:nil];
    
    // Track whether callbacks are invoked
    __block BOOL failureCallbackInvoked = NO;
    __block SFOAuthInfo *capturedAuthInfo = nil;
    __block NSError *capturedError = nil;
    
    authSession.authFailureCallback = ^(SFOAuthInfo *authInfo, NSError *error) {
        failureCallbackInvoked = YES;
        capturedAuthInfo = authInfo;
        capturedError = error;
    };
    
    // Create coordinator
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithAuthSession:authSession];
    coordinator.credentials = credentials;
    
    // Verify initial state
    XCTAssertNotNil(coordinator.credentials);
    XCTAssertEqualObjects(coordinator.credentials.clientId, @"testClientId");
    
    // Call migrateRefreshToken - this will attempt to make a REST API call
    // which will fail because the user is not properly logged in
    [coordinator migrateRefreshToken:userAccount];
    
    // Wait a bit for the async failure callback
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for failure callback"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:2.0];
    
    // Verify that the auth info was set to the correct type
    // This happens synchronously before the REST call
    XCTAssertNotNil(coordinator.authInfo, @"Auth info should be set");
    XCTAssertEqual(coordinator.authInfo.authType, SFOAuthTypeRefreshTokenMigration, @"Auth type should be refresh token migration");
    
    // Verify initialRequestLoaded was set to false
    XCTAssertFalse(coordinator.initialRequestLoaded, @"Initial request loaded should be false");
    
    // Verify the failure callback was invoked (because the user isn't logged in properly)
    XCTAssertTrue(failureCallbackInvoked, @"Failure callback should be invoked when REST API fails");
    XCTAssertNotNil(capturedError, @"Should have captured an error");
    XCTAssertEqual(capturedAuthInfo.authType, SFOAuthTypeRefreshTokenMigration, @"AuthInfo type should be refresh token migration");
}

// Must match kSFSDKAuthSessionUnscopedSceneIdPrefix in SFSDKAuthSession.m.
static NSString * const kExpectedUnscopedSceneIdPrefix = @"com.salesforce.mobilesdk.unscopedAuthSession-";

// A session created before any UIScene connects must still expose a non-nil sceneId, otherwise the
// advanced-auth browser callback crashes and the session is dropped from the authSessions store.
- (void)test_givenNoConnectedScene_whenAuthSessionCreated_thenSceneIdIsNonNilWithUnscopedPrefix {
    SFSDKAuthRequest *authRequest = [[SFSDKAuthRequest alloc] init];
    authRequest.oauthClientId = @"testClientId";
    authRequest.oauthCompletionUrl = @"testapp://callback";
    authRequest.loginHost = @"login.salesforce.com";
    XCTAssertNil(authRequest.scene, @"Precondition: no scene connected yet");

    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] initWith:authRequest credentials:nil];

    XCTAssertNotNil(authSession.sceneId, @"sceneId must be non-nil so the advanced-auth callback options dictionary is safe to build and the session is stored under a valid key");
    XCTAssertTrue([authSession.sceneId hasPrefix:kExpectedUnscopedSceneIdPrefix], @"A scene-less session should get the synthesized unscoped scene id, got: %@", authSession.sceneId);
}

// Two scene-less sessions must get distinct sceneIds so they cannot collide on a single authSessions[]
// key, and each sceneId must be stable for the session's lifetime.
- (void)test_givenTwoNoSceneAuthSessions_whenCreated_thenSceneIdsAreDistinctAndStable {
    SFSDKAuthRequest *request1 = [[SFSDKAuthRequest alloc] init];
    request1.oauthClientId = @"testClientId";
    request1.oauthCompletionUrl = @"testapp://callback";
    request1.loginHost = @"login.salesforce.com";

    SFSDKAuthRequest *request2 = [[SFSDKAuthRequest alloc] init];
    request2.oauthClientId = @"testClientId";
    request2.oauthCompletionUrl = @"testapp://callback";
    request2.loginHost = @"login.salesforce.com";

    SFSDKAuthSession *session1 = [[SFSDKAuthSession alloc] initWith:request1 credentials:nil];
    SFSDKAuthSession *session2 = [[SFSDKAuthSession alloc] initWith:request2 credentials:nil];

    XCTAssertNotNil(session1.sceneId);
    XCTAssertNotNil(session2.sceneId);
    XCTAssertNotEqualObjects(session1.sceneId, session2.sceneId, @"Two scene-less sessions must get distinct scene ids so they cannot collide on a single authSessions[] key");
    // Frozen for the session's lifetime: reading again yields the same value.
    XCTAssertEqualObjects(session1.sceneId, session1.sceneId, @"sceneId must be stable for the session's lifetime");
}

// Helper to build a coordinator whose browser-callback options we can inspect.
- (SFOAuthCoordinator *)browserFlowCoordinator {
    SFSDKAuthRequest *authRequest = [[SFSDKAuthRequest alloc] init];
    authRequest.oauthClientId = @"testClientId";
    authRequest.oauthCompletionUrl = @"testapp://callback";
    authRequest.loginHost = @"login.salesforce.com";
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] initWith:authRequest credentials:nil];
    return [[SFOAuthCoordinator alloc] initWithAuthSession:authSession];
}

// Helper to build a coordinator backed by an auth session whose oauthRequest flags
// (loginAsAdmin, useBrowserAuth) can be set before asserting on the native browser approval URL.
// Returns authSession.oauthCoordinator (not a freshly-initWithAuthSession: instance): SFSDKAuthSession
// already builds and configures its own coordinator in -initCoordinator, including setting
// useBrowserAuth from oauthRequest.useBrowserAuth/loginAsAdmin — a second coordinator built directly
// via initWithAuthSession: would skip that configuration. authSession is retained on self for the
// test's duration since SFOAuthCoordinator.authSession is weak (production keeps it alive via
// SFUserAccountManager's authSessions store).
- (SFOAuthCoordinator *)browserFlowCoordinatorWithLoginAsAdmin:(BOOL)loginAsAdmin useBrowserAuth:(BOOL)useBrowserAuth {
    SFSDKAuthRequest *authRequest = [[SFSDKAuthRequest alloc] init];
    authRequest.oauthClientId = @"testClientId";
    authRequest.oauthCompletionUrl = @"testapp://callback";
    authRequest.loginHost = @"login.salesforce.com";
    authRequest.loginAsAdmin = loginAsAdmin;
    authRequest.useBrowserAuth = useBrowserAuth;
    self.retainedAuthSession = [[SFSDKAuthSession alloc] initWith:authRequest credentials:nil];
    return self.retainedAuthSession.oauthCoordinator;
}

#pragma mark - auth_trigger / sdkInfo Tests

- (void)test_givenForceAdvancedAuthentication_whenBuildingNativeBrowserApprovalUrl_thenContainsForceAdvancedAuthTriggerAndSdkInfo {
    BOOL original = [SalesforceSDKManager sharedManager].sdk_forceAdvancedAuthentication;
    [SalesforceSDKManager sharedManager].sdk_forceAdvancedAuthentication = YES;

    SFOAuthCoordinator *coordinator = [self browserFlowCoordinatorWithLoginAsAdmin:NO useBrowserAuth:NO];

    NSString *approvalUrl = [coordinator nativeBrowserApprovalUrlWithSharedBrowserSessionEnabled:YES];

    XCTAssertTrue([approvalUrl containsString:@"auth_trigger=force_advanced_auth"], @"Expected force_advanced_auth trigger, got: %@", approvalUrl);
    NSString *expectedSdkInfo = [[[SalesforceSDKManager sharedManager] sdkUserAgentString:@"" forUser:nil] sfsdk_stringByURLEncoding];
    NSString *expectedSdkInfoParam = [NSString stringWithFormat:@"sdkInfo=%@", expectedSdkInfo];
    XCTAssertTrue([approvalUrl containsString:expectedSdkInfoParam], @"Expected encoded sdkInfo, got: %@", approvalUrl);

    [SalesforceSDKManager sharedManager].sdk_forceAdvancedAuthentication = original;
}

- (void)test_givenNoTriggerSignalsSet_whenBuildingNativeBrowserApprovalUrl_thenContainsOrgConfigTrigger {
    BOOL original = [SalesforceSDKManager sharedManager].sdk_forceAdvancedAuthentication;
    [SalesforceSDKManager sharedManager].sdk_forceAdvancedAuthentication = NO;

    SFOAuthCoordinator *coordinator = [self browserFlowCoordinatorWithLoginAsAdmin:NO useBrowserAuth:NO];

    NSString *approvalUrl = [coordinator nativeBrowserApprovalUrlWithSharedBrowserSessionEnabled:YES];

    XCTAssertTrue([approvalUrl containsString:@"auth_trigger=org_config"], @"Expected org_config trigger, got: %@", approvalUrl);

    [SalesforceSDKManager sharedManager].sdk_forceAdvancedAuthentication = original;
}

- (void)test_givenLoginAsAdmin_whenBuildingNativeBrowserApprovalUrl_thenContainsLoginForAdminTrigger {
    BOOL original = [SalesforceSDKManager sharedManager].sdk_forceAdvancedAuthentication;
    [SalesforceSDKManager sharedManager].sdk_forceAdvancedAuthentication = YES; // lower priority than loginAsAdmin

    SFOAuthCoordinator *coordinator = [self browserFlowCoordinatorWithLoginAsAdmin:YES useBrowserAuth:NO];

    NSString *approvalUrl = [coordinator nativeBrowserApprovalUrlWithSharedBrowserSessionEnabled:YES];

    XCTAssertTrue([approvalUrl containsString:@"auth_trigger=login_for_admin"], @"Expected login_for_admin trigger to take priority, got: %@", approvalUrl);

    [SalesforceSDKManager sharedManager].sdk_forceAdvancedAuthentication = original;
}

- (void)test_givenMdmUseBrowserAuth_whenBuildingNativeBrowserApprovalUrl_thenContainsMdmTrigger {
    BOOL original = [SalesforceSDKManager sharedManager].sdk_forceAdvancedAuthentication;
    [SalesforceSDKManager sharedManager].sdk_forceAdvancedAuthentication = YES; // lower priority than MDM

    SFOAuthCoordinator *coordinator = [self browserFlowCoordinatorWithLoginAsAdmin:NO useBrowserAuth:YES];

    NSString *approvalUrl = [coordinator nativeBrowserApprovalUrlWithSharedBrowserSessionEnabled:YES];

    XCTAssertTrue([approvalUrl containsString:@"auth_trigger=mdm"], @"Expected mdm trigger to take priority over force_advanced_auth, got: %@", approvalUrl);

    [SalesforceSDKManager sharedManager].sdk_forceAdvancedAuthentication = original;
}

- (void)test_givenWebViewFlow_whenGeneratingApprovalUrl_thenDoesNotContainAuthTriggerOrSdkInfo {
    SFOAuthCoordinator *coordinator = [self browserFlowCoordinator];
    coordinator.useBrowserAuth = NO;

    NSString *approvalUrl = [coordinator generateApprovalUrlString];

    XCTAssertFalse([approvalUrl containsString:@"auth_trigger="], @"WebView-path approval URL must not contain auth_trigger, got: %@", approvalUrl);
    XCTAssertFalse([approvalUrl containsString:@"sdkInfo="], @"WebView-path approval URL must not contain sdkInfo, got: %@", approvalUrl);
}

- (void)test_givenNativeBrowserFlow_whenBuildingApprovalUrl_thenSdkInfoIsProperlyPercentEncoded {
    SFOAuthCoordinator *coordinator = [self browserFlowCoordinatorWithLoginAsAdmin:NO useBrowserAuth:NO];

    NSString *approvalUrl = [coordinator nativeBrowserApprovalUrlWithSharedBrowserSessionEnabled:YES];

    NSString *rawUserAgent = [[SalesforceSDKManager sharedManager] sdkUserAgentString:@"" forUser:nil];
    NSString *encodedUserAgent = [rawUserAgent sfsdk_stringByURLEncoding];
    NSString *encodedSdkInfoParam = [NSString stringWithFormat:@"sdkInfo=%@", encodedUserAgent];
    XCTAssertTrue([approvalUrl containsString:encodedSdkInfoParam], @"sdkInfo value should be percent-encoded exactly once, got: %@", approvalUrl);
    // The SDK user agent always contains spaces (e.g. "SalesforceMobileSDK/..."); assert those are
    // encoded away rather than appearing raw in the query string.
    XCTAssertTrue([rawUserAgent containsString:@" "], @"Precondition: user agent string should contain spaces to make this a meaningful encoding check");
    NSString *rawSdkInfoParam = [NSString stringWithFormat:@"sdkInfo=%@", rawUserAgent];
    XCTAssertFalse([approvalUrl containsString:rawSdkInfoParam], @"sdkInfo value must not appear unencoded in the approval URL");
}

- (void)test_givenNativeBrowserFlow_whenBuildingApprovalUrl_thenSdkInfoExcludesWebViewUserAgent {
    SFOAuthCoordinator *coordinator = [self browserFlowCoordinatorWithLoginAsAdmin:NO useBrowserAuth:NO];

    NSString *approvalUrl = [coordinator nativeBrowserApprovalUrlWithSharedBrowserSessionEnabled:YES];

    NSString *fullUserAgent = [[SalesforceSDKManager sharedManager] userAgentString:@"" forUser:nil];
    NSString *sdkOnlyUserAgent = [[SalesforceSDKManager sharedManager] sdkUserAgentString:@"" forUser:nil];
    XCTAssertNotEqualObjects(fullUserAgent, sdkOnlyUserAgent,
                              @"Precondition: userAgentString:forUser: should append a trailing WebView UA that sdkUserAgentString:forUser: omits");

    NSString *fullUserAgentEncodedParam = [NSString stringWithFormat:@"sdkInfo=%@", [fullUserAgent sfsdk_stringByURLEncoding]];
    XCTAssertFalse([approvalUrl containsString:fullUserAgentEncodedParam],
                    @"sdkInfo must not include the WebView user agent — the native browser's own UA is captured server-side, got: %@", approvalUrl);
}

// When a scene is connected, the advanced-auth browser callback must key its options dictionary by
// the scene id so the URL handler routes the response to the originating scene.
- (void)test_givenSceneId_whenBuildingBrowserCallbackOptions_thenOptionsAreKeyedBySceneId {
    SFOAuthCoordinator *coordinator = [self browserFlowCoordinator];

    NSDictionary *options = [coordinator browserCallbackOptionsForSceneId:@"scene-42"];

    XCTAssertEqualObjects(options[kSFIDPSceneIdKey], @"scene-42", @"A non-nil sceneId must be carried under kSFIDPSceneIdKey so the callback routes to the originating scene");
    XCTAssertEqual(options.count, (NSUInteger)1, @"Only the scene id key should be present");
}

// When no scene id is available (e.g. login started before a UIScene connected, or the weak
// authSession deallocated before the callback), the options must be an empty dictionary rather than
// crashing on a nil insert; the URL handler then falls back to the default scene.
- (void)test_givenNilSceneId_whenBuildingBrowserCallbackOptions_thenOptionsAreEmptyAndDoNotCrash {
    SFOAuthCoordinator *coordinator = [self browserFlowCoordinator];

    NSDictionary *options = [coordinator browserCallbackOptionsForSceneId:nil];

    XCTAssertNotNil(options, @"Options must never be nil");
    XCTAssertEqual(options.count, (NSUInteger)0, @"A nil sceneId must yield an empty options dictionary so nil is never inserted and the handler falls back to the default scene");
}

#pragma mark - App Attestation Feature Flag Tests

- (void)test_givenAttestationEnabled_whenAuthenticateCalled_thenAAFlagRegisteredGlobally {
    // Arrange
    BOOL originalValue = [SFUserAccountManager sharedInstance].appAttestationEnabled;
    [SFUserAccountManager sharedInstance].appAttestationEnabled = YES;
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation];

    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"testAttest" clientId:@"testClient" encrypted:NO];
    creds.domain = @"mydomain.my.salesforce.com";
    creds.refreshToken = @"testRefreshToken";
    creds.redirectUri = @"testapp://callback";
    creds.instanceUrl = [NSURL URLWithString:@"https://mydomain.my.salesforce.com"];

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    SFOAuthTestFlowCoordinatorDelegate *delegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    delegate.isNetworkAvailable = NO; // Prevent actual network calls
    coordinator.delegate = delegate;

    // Act
    [coordinator authenticate];

    // Assert: AA flag should be registered globally
    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureAppAttestation],
                  @"AA flag should be registered globally when attestation is enabled");

    // Cleanup
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation];
    [SFUserAccountManager sharedInstance].appAttestationEnabled = originalValue;
    [creds revoke];
}

- (void)test_givenAttestationDisabled_whenAuthenticateCalled_thenAAFlagNotRegistered {
    // Arrange
    BOOL originalValue = [SFUserAccountManager sharedInstance].appAttestationEnabled;
    [SFUserAccountManager sharedInstance].appAttestationEnabled = NO;
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation];

    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"testAttest2" clientId:@"testClient2" encrypted:NO];
    creds.domain = @"mydomain.my.salesforce.com";
    creds.refreshToken = @"testRefreshToken";
    creds.redirectUri = @"testapp://callback";
    creds.instanceUrl = [NSURL URLWithString:@"https://mydomain.my.salesforce.com"];

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    SFOAuthTestFlowCoordinatorDelegate *delegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    delegate.isNetworkAvailable = NO; // Prevent actual network calls
    coordinator.delegate = delegate;

    // Act
    [coordinator authenticate];

    // Assert: AA flag should NOT be registered
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureAppAttestation],
                   @"AA flag should not be registered when attestation is disabled");

    // Cleanup
    [SFUserAccountManager sharedInstance].appAttestationEnabled = originalValue;
    [creds revoke];
}

#pragma mark - App Attestation Forces Web Server Flow Tests

- (void)test_givenAttestationEnabled_andWebServerFlowDisabled_whenAuthenticateCalled_thenUsesWebServerFlowType {
    // Arrange
    BOOL originalAttestation = [SFUserAccountManager sharedInstance].appAttestationEnabled;
    BOOL originalWebServer = [[SalesforceSDKManager sharedManager] sdk_useWebServerAuthentication];
    [SFUserAccountManager sharedInstance].appAttestationEnabled = YES;
    [SalesforceSDKManager sharedManager].sdk_useWebServerAuthentication = NO;

    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"testFlowType" clientId:@"testClient" encrypted:NO];
    creds.domain = @"mydomain.my.salesforce.com";
    creds.redirectUri = @"testapp://callback";
    creds.instanceUrl = [NSURL URLWithString:@"https://mydomain.my.salesforce.com"];
    // No refresh token — forces the auth type selection path (not refresh flow)

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    coordinator.useBrowserAuth = NO;
    SFOAuthTestFlowCoordinatorDelegate *delegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    delegate.isNetworkAvailable = NO;
    coordinator.delegate = delegate;

    // Act
    [coordinator authenticate];

    // Assert: should select web server flow despite useWebServerAuthentication = NO
    XCTAssertEqual(coordinator.authInfo.authType, SFOAuthTypeWebServer,
                   @"Auth type should be WebServer when attestation is enabled, even if useWebServerAuthentication is NO");

    // Cleanup
    [SFUserAccountManager sharedInstance].appAttestationEnabled = originalAttestation;
    [SalesforceSDKManager sharedManager].sdk_useWebServerAuthentication = originalWebServer;
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation];
    [creds revoke];
}

- (void)test_givenAttestationDisabled_andWebServerFlowDisabled_whenAuthenticateCalled_thenUsesUserAgentFlowType {
    // Arrange
    BOOL originalAttestation = [SFUserAccountManager sharedInstance].appAttestationEnabled;
    BOOL originalWebServer = [[SalesforceSDKManager sharedManager] sdk_useWebServerAuthentication];
    [SFUserAccountManager sharedInstance].appAttestationEnabled = NO;
    [SalesforceSDKManager sharedManager].sdk_useWebServerAuthentication = NO;

    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"testFlowType2" clientId:@"testClient2" encrypted:NO];
    creds.domain = @"mydomain.my.salesforce.com";
    creds.redirectUri = @"testapp://callback";
    creds.instanceUrl = [NSURL URLWithString:@"https://mydomain.my.salesforce.com"];
    // No refresh token — forces the auth type selection path

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    coordinator.useBrowserAuth = NO;
    SFOAuthTestFlowCoordinatorDelegate *delegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    delegate.isNetworkAvailable = NO;
    coordinator.delegate = delegate;

    // Act
    [coordinator authenticate];

    // Assert: should use user agent flow when both attestation and web server are off
    XCTAssertEqual(coordinator.authInfo.authType, SFOAuthTypeUserAgent,
                   @"Auth type should be UserAgent when both attestation and useWebServerAuthentication are disabled");

    // Cleanup
    [SFUserAccountManager sharedInstance].appAttestationEnabled = originalAttestation;
    [SalesforceSDKManager sharedManager].sdk_useWebServerAuthentication = originalWebServer;
    [creds revoke];
}

- (void)test_givenAttestationEnabled_whenGeneratingApprovalUrl_thenContainsResponseTypeCode {
    // Arrange
    BOOL originalAttestation = [SFUserAccountManager sharedInstance].appAttestationEnabled;
    BOOL originalWebServer = [[SalesforceSDKManager sharedManager] sdk_useWebServerAuthentication];
    [SFUserAccountManager sharedInstance].appAttestationEnabled = YES;
    [SalesforceSDKManager sharedManager].sdk_useWebServerAuthentication = NO;

    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"testApprovalUrl" clientId:@"testClient" encrypted:NO];
    creds.domain = @"mydomain.my.salesforce.com";
    creds.redirectUri = @"testapp://callback";
    creds.instanceUrl = [NSURL URLWithString:@"https://mydomain.my.salesforce.com"];

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    coordinator.useBrowserAuth = NO;

    // Act
    NSString *approvalUrl = [coordinator generateApprovalUrlString];

    // Assert: URL should contain response_type=code (web server flow)
    XCTAssertTrue([approvalUrl containsString:@"response_type=code"],
                  @"Approval URL should use response_type=code when attestation is enabled; got: %@", approvalUrl);
    XCTAssertFalse([approvalUrl containsString:@"response_type=token"],
                   @"Approval URL should NOT use response_type=token when attestation is enabled; got: %@", approvalUrl);

    // Cleanup
    [SFUserAccountManager sharedInstance].appAttestationEnabled = originalAttestation;
    [SalesforceSDKManager sharedManager].sdk_useWebServerAuthentication = originalWebServer;
    [creds revoke];
}

- (void)test_givenAttestationDisabled_andWebServerFlowDisabled_whenGeneratingApprovalUrl_thenDoesNotContainResponseTypeCode {
    // Arrange
    BOOL originalAttestation = [SFUserAccountManager sharedInstance].appAttestationEnabled;
    BOOL originalWebServer = [[SalesforceSDKManager sharedManager] sdk_useWebServerAuthentication];
    [SFUserAccountManager sharedInstance].appAttestationEnabled = NO;
    [SalesforceSDKManager sharedManager].sdk_useWebServerAuthentication = NO;

    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"testApprovalUrl2" clientId:@"testClient2" encrypted:NO];
    creds.domain = @"mydomain.my.salesforce.com";
    creds.redirectUri = @"testapp://callback";
    creds.instanceUrl = [NSURL URLWithString:@"https://mydomain.my.salesforce.com"];

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    coordinator.useBrowserAuth = NO;

    // Act
    NSString *approvalUrl = [coordinator generateApprovalUrlString];

    // Assert: URL should NOT contain response_type=code (user agent flow uses token or hybrid_token)
    XCTAssertFalse([approvalUrl containsString:@"response_type=code"],
                   @"Approval URL should NOT use response_type=code when attestation and web server flow are both disabled; got: %@", approvalUrl);

    // Cleanup
    [SFUserAccountManager sharedInstance].appAttestationEnabled = originalAttestation;
    [SalesforceSDKManager sharedManager].sdk_useWebServerAuthentication = originalWebServer;
    [creds revoke];
}

#pragma mark - Coordinator refresh reroute through the shared token-refresh coordinator

/// Builds refresh-capable test credentials with a unique identifier (used as the shared coordinator's
/// coalescing key) and a saved user account.
- (SFOAuthCredentials *)makeSavedRefreshCredentialsReturningAccount:(SFUserAccount **)outAccount {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:[NSString stringWithFormat:@"testCoordinatorReroute_%u", arc4random()] clientId:@"testClient" encrypted:NO];
    creds.domain = @"mydomain.my.salesforce.com";
    creds.refreshToken = @"originalRefreshToken";
    creds.redirectUri = @"testapp://callback";
    creds.instanceUrl = [NSURL URLWithString:@"https://mydomain.my.salesforce.com"];
    creds.userId = @"005000000000001";
    creds.organizationId = @"00D000000000001";

    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:creds];
    [[SFUserAccountManager sharedInstance] saveAccountForUser:account error:nil];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureRTR forUser:account];
    if (outAccount) {
        *outAccount = account;
    }
    return creds;
}

// the coordinator's refresh branch must now go through the shared single-flight
// SFSDKTokenRefreshCoordinator (which coalesces one token request per credential identifier), not
// through authClient. This is the core of the fix: closing the only refresh path that bypassed the
// gate. We assert the injected shared-coordinator refresher ran and authClient's refresh was never
// touched.
- (void)test_givenRefreshCredentials_whenCoordinatorRefreshes_thenRoutesThroughSharedCoordinatorNotAuthClient {
    SFUserAccount *account = nil;
    SFOAuthCredentials *creds = [self makeSavedRefreshCredentialsReturningAccount:&account];

    SFSDKCoordinatorMockRefresher *mock = [self makeMockRefresherForCredentials:creds];
    [SFSDKTokenRefreshCoordinator sharedInstance].refresherFactory = ^SFOAuthSessionRefresher *(SFOAuthCredentials *c) {
        return mock;
    };

    SFSDKCoordinatorRefreshClientStub *stub = [[SFSDKCoordinatorRefreshClientStub alloc] init];
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    coordinator.authClient = stub;
    SFOAuthTestFlowCoordinatorDelegate *delegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    delegate.isNetworkAvailable = YES;
    coordinator.delegate = delegate;

    NSPredicate *finished = [NSPredicate predicateWithFormat:@"didAuthenticateCalled == YES OR didFailWithErrorCalled == YES"];
    [self expectationForPredicate:finished evaluatedWithObject:delegate handler:nil];
    [coordinator authenticate];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertTrue(delegate.didAuthenticateCalled, @"Coordinator refresh should complete successfully; error: %@", delegate.didFailWithError);
    XCTAssertEqual(mock.refreshCallCount, 1, @"Refresh must be driven exactly once through the shared token-refresh coordinator");
    XCTAssertFalse(stub.accessTokenForRefreshCalled, @"Coordinator refresh must NOT call authClient directly anymore (it previously bypassed the single-flight gate)");

    // Cleanup
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:account error:nil];
}

// a coordinator-driven refresh whose response rotates the refresh token registers the RT
// feature marker for the credential owner (via the shared refresher), fixing the original symptom.
- (void)test_givenRotatedRefreshToken_whenCoordinatorRefreshes_thenRTFlagRegisteredForOwner {
    SFUserAccount *account = nil;
    SFOAuthCredentials *creds = [self makeSavedRefreshCredentialsReturningAccount:&account];

    SFSDKCoordinatorMockRefresher *mock = [self makeMockRefresherForCredentials:creds];
    mock.rotatedRefreshToken = [NSString stringWithFormat:@"rotated_token_%u", arc4random()];
    [SFSDKTokenRefreshCoordinator sharedInstance].refresherFactory = ^SFOAuthSessionRefresher *(SFOAuthCredentials *c) {
        return mock;
    };

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    SFOAuthTestFlowCoordinatorDelegate *delegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    delegate.isNetworkAvailable = YES;
    coordinator.delegate = delegate;

    NSPredicate *finished = [NSPredicate predicateWithFormat:@"didAuthenticateCalled == YES OR didFailWithErrorCalled == YES"];
    [self expectationForPredicate:finished evaluatedWithObject:delegate handler:nil];
    [coordinator authenticate];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertTrue(delegate.didAuthenticateCalled, @"Coordinator refresh should complete successfully; error: %@", delegate.didFailWithError);
    NSSet *features = [SFSDKAppFeatureMarkers appFeaturesForUser:account];
    XCTAssertTrue([features containsObject:kSFAppFeatureRTR],
                  @"RT flag must be registered for the owner after a rotating coordinator refresh (now via the shared refresher)");

    // Cleanup
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureRTR forUser:account];
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:account error:nil];
}

// a refresh that fails with app-attestation-failed must still reach the coordinator delegate
// with the attestation-failed semantics preserved — the error path reconstructs the SFOAuthErrorCode
// from userInfo[kSFOAuthError] and injects the localized attestation message, matching the
// code-exchange branch.
- (void)test_givenAttestationFailedRefresh_whenCoordinatorRefreshes_thenDelegateReceivesAttestationError {
    SFUserAccount *account = nil;
    SFOAuthCredentials *creds = [self makeSavedRefreshCredentialsReturningAccount:&account];

    SFSDKCoordinatorMockRefresher *mock = [self makeMockRefresherForCredentials:creds];
    mock.forcedError = [NSError errorWithDomain:kSFOAuthErrorDomain
                                           code:kSFOAuthErrorAccessDenied
                                       userInfo:@{ kSFOAuthError: @"app_attest_failed" }];
    [SFSDKTokenRefreshCoordinator sharedInstance].refresherFactory = ^SFOAuthSessionRefresher *(SFOAuthCredentials *c) {
        return mock;
    };

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    SFOAuthTestFlowCoordinatorDelegate *delegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    delegate.isNetworkAvailable = YES;
    coordinator.delegate = delegate;

    NSPredicate *finished = [NSPredicate predicateWithFormat:@"didAuthenticateCalled == YES OR didFailWithErrorCalled == YES"];
    [self expectationForPredicate:finished evaluatedWithObject:delegate handler:nil];
    [coordinator authenticate];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertTrue(delegate.didFailWithErrorCalled, @"An attestation-failed refresh must surface via the failure delegate callback");
    XCTAssertFalse(delegate.didAuthenticateCalled, @"A failed refresh must not report success");
    NSString *expectedMessage = [SFSDKResourceUtils localizedString:@"appAttestationFailedError"];
    XCTAssertEqualObjects(delegate.didFailWithError.userInfo[NSLocalizedDescriptionKey], expectedMessage,
                          @"Attestation-failed refresh must carry the localized attestation message, like the code-exchange path");
    XCTAssertEqualObjects(delegate.didFailWithError.userInfo[kSFOAuthError], @"app_attest_failed",
                          @"The original server error wire string must be preserved in userInfo");

    // Cleanup
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:account error:nil];
}

// Timeout classification: the shared refresh path surfaces a timeout as
// kSFOAuthErrorDomain/kSFOAuthErrorTimeout (not NSURLErrorTimedOut). The coordinator's refresh error
// path must recognize that and still deliver the timeout to the delegate with its domain/code intact.
- (void)test_givenTimeoutRefresh_whenCoordinatorRefreshes_thenDelegateReceivesTimeoutError {
    SFUserAccount *account = nil;
    SFOAuthCredentials *creds = [self makeSavedRefreshCredentialsReturningAccount:&account];

    SFSDKCoordinatorMockRefresher *mock = [self makeMockRefresherForCredentials:creds];
    mock.forcedError = [NSError errorWithDomain:kSFOAuthErrorDomain
                                           code:kSFOAuthErrorTimeout
                                       userInfo:@{ NSLocalizedDescriptionKey: @"The refresh request timed out." }];
    [SFSDKTokenRefreshCoordinator sharedInstance].refresherFactory = ^SFOAuthSessionRefresher *(SFOAuthCredentials *c) {
        return mock;
    };

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    SFOAuthTestFlowCoordinatorDelegate *delegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    delegate.isNetworkAvailable = YES;
    coordinator.delegate = delegate;

    NSPredicate *finished = [NSPredicate predicateWithFormat:@"didAuthenticateCalled == YES OR didFailWithErrorCalled == YES"];
    [self expectationForPredicate:finished evaluatedWithObject:delegate handler:nil];
    [coordinator authenticate];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertTrue(delegate.didFailWithErrorCalled, @"A timed-out refresh must surface via the failure delegate callback");
    XCTAssertFalse(delegate.didAuthenticateCalled, @"A timed-out refresh must not report success");
    XCTAssertEqualObjects(delegate.didFailWithError.domain, kSFOAuthErrorDomain,
                          @"Timeout error domain must be preserved to the delegate");
    XCTAssertEqual(delegate.didFailWithError.code, kSFOAuthErrorTimeout,
                   @"Timeout must be classified as kSFOAuthErrorTimeout (the shared path's timeout code), not left as NSURLErrorTimedOut");

    // Cleanup
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:account error:nil];
}

// when the shared coordinator coalesces this refresh onto an in-flight refresh keyed to a
// DIFFERENT SFOAuthCredentials instance, the coordinator must adopt the returned instance so its own
// self.credentials reflects the refreshed tokens before success is reported.
- (void)test_givenCoalescedResultFromOtherCredentialsInstance_whenCoordinatorRefreshCompletes_thenSelfCredentialsAdopted {
    SFUserAccount *account = nil;
    SFOAuthCredentials *creds = [self makeSavedRefreshCredentialsReturningAccount:&account];

    // Simulate the coalesced-winner's own credentials object (same identifier, different instance).
    SFOAuthCredentials *otherInstance = [[SFOAuthCredentials alloc] initWithIdentifier:creds.identifier clientId:creds.clientId encrypted:NO];
    otherInstance.domain = creds.domain;
    otherInstance.instanceUrl = creds.instanceUrl;
    otherInstance.refreshToken = @"coalesced_refresh_token";

    SFSDKCoordinatorMockRefresher *mock = [self makeMockRefresherForCredentials:creds];
    mock.overrideCompletionCredentials = otherInstance;
    [SFSDKTokenRefreshCoordinator sharedInstance].refresherFactory = ^SFOAuthSessionRefresher *(SFOAuthCredentials *c) {
        return mock;
    };

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    SFOAuthTestFlowCoordinatorDelegate *delegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    delegate.isNetworkAvailable = YES;
    coordinator.delegate = delegate;

    NSPredicate *finished = [NSPredicate predicateWithFormat:@"didAuthenticateCalled == YES OR didFailWithErrorCalled == YES"];
    [self expectationForPredicate:finished evaluatedWithObject:delegate handler:nil];
    [coordinator authenticate];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertTrue(delegate.didAuthenticateCalled, @"Coordinator refresh should complete successfully; error: %@", delegate.didFailWithError);
    XCTAssertEqual(coordinator.credentials, otherInstance,
                   @"Coordinator must adopt the coalesced result instance returned by the shared coordinator");
    XCTAssertEqualObjects(coordinator.credentials.accessToken, @"mock_new_access_token",
                          @"self.credentials must carry the refreshed access token before success is reported");

    // Cleanup
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:account error:nil];
}

// the authorization-code (login) branch is unchanged — it still exchanges the code directly via
// authClient's accessTokenForApprovalCode:, never touches the shared refresh coordinator, and does
// not register RT.
- (void)test_givenApprovalCode_whenCoordinatorCompletesLogin_thenCodeExchangedDirectlyAndNoRT {
    BOOL originalAttestation = [SFUserAccountManager sharedInstance].appAttestationEnabled;
    [SFUserAccountManager sharedInstance].appAttestationEnabled = NO;

    SFUserAccount *account = nil;
    SFOAuthCredentials *creds = [self makeSavedRefreshCredentialsReturningAccount:&account];

    // Guard: if the login branch ever reaches the shared refresh coordinator, this fails the test.
    __block BOOL refresherFactoryInvoked = NO;
    [SFSDKTokenRefreshCoordinator sharedInstance].refresherFactory = ^SFOAuthSessionRefresher *(SFOAuthCredentials *c) {
        refresherFactoryInvoked = YES;
        return nil;
    };

    SFSDKOAuthTokenEndpointResponse *response = [[SFSDKOAuthTokenEndpointResponse alloc]
        initWithDictionary:@{ kSFOAuthAccessToken: @"login_access_token", kSFOAuthRefreshToken: @"login_refresh_token" }
        parseAdditionalFields:nil];
    SFSDKCoordinatorRefreshClientStub *stub = [[SFSDKCoordinatorRefreshClientStub alloc] init];
    stub.approvalCodeResponse = response;

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    coordinator.authClient = stub;
    coordinator.approvalCode = @"testApprovalCode";
    SFOAuthTestFlowCoordinatorDelegate *delegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    delegate.isNetworkAvailable = YES;
    coordinator.delegate = delegate;

    NSPredicate *finished = [NSPredicate predicateWithFormat:@"didAuthenticateCalled == YES OR didFailWithErrorCalled == YES"];
    [self expectationForPredicate:finished evaluatedWithObject:delegate handler:nil];
    [coordinator beginTokenEndpointFlow];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertTrue(delegate.didAuthenticateCalled, @"Approval-code login should complete successfully; error: %@", delegate.didFailWithError);
    XCTAssertEqual(stub.accessTokenForApprovalCodeCount, 1, @"Login must exchange the code directly via authClient");
    XCTAssertFalse(refresherFactoryInvoked, @"Login must not route through the shared refresh coordinator");
    NSSet *features = [SFSDKAppFeatureMarkers appFeaturesForUser:account];
    XCTAssertFalse([features containsObject:kSFAppFeatureRTR], @"An approval-code login must not register the RT marker");

    // Cleanup
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:account error:nil];
    [SFUserAccountManager sharedInstance].appAttestationEnabled = originalAttestation;
}

@end

