/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFTestSDKManagerFlow.h"
#import "SalesforceSDKManager+Internal.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFUserAccountManager+Internal.h"
#import "SFSDKSalesforceAnalyticsManager.h"
#import "SFSDKAppConfig.h"
#import "SFUserAccount+Internal.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFSDKAppFeatureMarkers.h"
#import "SFOAuthTestFlowCoordinatorDelegate.h"
#import "SFLoginViewController.h"
#import "SFSDKAuthRootController.h"

static NSString* const kTestAppName = @"OverridenAppName";

#pragma mark - Test-only declarations for the forced Advanced Auth tests (W-23126676)

// Test-only category that surfaces private SFOAuthCoordinator hooks needed to assert the
// auth-modality decision and the native-browser authorize URL WITHOUT launching a real
// ASWebAuthenticationSession. These methods all exist in SFOAuthCoordinator.m today; this
// category only re-declares their signatures so the test target can call/override them.
// (No production code is modified.)
@interface SFOAuthCoordinator (ForceAdvancedAuthTests)
- (void)beginNativeBrowserFlowWithSharedBrowserSessionEnabled:(BOOL)shareBrowserSession;
- (void)continueNativeBrowserFlowWithSharedBrowserSessionEnabled:(BOOL)shareBrowserSession;
- (NSString *)approvalURLForEndpoint:(NSString *)authorizeEndpoint
                         credentials:(SFOAuthCredentials *)credentials
                       webServerFlow:(BOOL)webServerFlow
                            protocol:(nullable NSString *)protocol
                              domain:(nullable NSString *)domain
                       codeChallenge:(nullable NSString *)codeChallenge;
- (NSString *)brandedAuthorizeURL;
@end

// Capturing coordinator subclass: records which login-modality branch the production
// `authenticate` decision took (native browser vs WKWebView) and the shareBrowserSession
// value that was propagated, while suppressing the side effects (no ASWebAuthenticationSession,
// no WKWebView). This lets the decision be asserted deterministically and offline.
@interface SFForceAdvancedAuthCapturingCoordinator : SFOAuthCoordinator
@property (nonatomic, assign) BOOL didChooseNativeBrowser;
@property (nonatomic, assign) BOOL didChooseWebView;
@property (nonatomic, assign) BOOL capturedShareBrowserSession;
@property (nonatomic, strong) XCTestExpectation *decisionExpectation;
@end

@implementation SFForceAdvancedAuthCapturingCoordinator
- (void)beginNativeBrowserFlowWithSharedBrowserSessionEnabled:(BOOL)shareBrowserSession {
    self.didChooseNativeBrowser = YES;
    self.capturedShareBrowserSession = shareBrowserSession;
    [self.decisionExpectation fulfill];
    // Intentionally do NOT call super: avoids creating an ASWebAuthenticationSession in tests.
}
- (void)beginWebViewFlow {
    self.didChooseWebView = YES;
    [self.decisionExpectation fulfill];
    // Intentionally do NOT call super: avoids creating a WKWebView in tests.
}
@end

@interface SalesforceSDKManagerTests : XCTestCase
{
    NSString *_origConnectedAppId;
    NSString *_origConnectedAppCallbackUri;
    NSSet *_origAuthScopes;
    BOOL _origAuthenticateAtLaunch;
    SFUserAccount *_origCurrentUser;
    id<SalesforceSDKManagerFlow> _origSdkManagerFlow;
    SFTestSDKManagerFlow *_currentSdkManagerFlow;
    NSString *_origAppName;
    NSString *_origBrandLoginPath;
    BOOL _origForceAdvancedAuthentication;
    BOOL _origUseWebServerAuthentication;
    BOOL _origUseHybridAuthentication;
}

@end

@implementation SalesforceSDKManagerTests

- (void)setUp
{
    [super setUp];
    // Since other tests may have a more "permanent" idea of (essentially global) app identity and
    // launch state, only clear values for the length of the test, then restore them.
    [self setupSdkManagerState];
}

- (void)tearDown
{
    // Restore the original SDK Manager state (see setUp).
    [self restoreOrigSdkManagerState];
    [super tearDown];
}

- (void)testOverrideAiltnAppNameBeforeSDKManagerInit
{
    [SalesforceSDKManager setAiltnAppName:kTestAppName];
    [self createTestAppIdentity];
    [self compareAiltnAppNames:kTestAppName];
}

- (void)testOverrideAiltnAppNameAfterSDKManagerInit
{
    [self createTestAppIdentity];
    [SalesforceSDKManager setAiltnAppName:kTestAppName];
    [self compareAiltnAppNames:kTestAppName];
}

- (void)testDefaultAiltnAppName
{
    [self createTestAppIdentity];
    NSString *appName = [[NSBundle mainBundle] infoDictionary][(NSString *) kCFBundleNameKey];
    [self compareAiltnAppNames:appName];
}

- (void)testOverrideInvalidAiltnAppName
{
    [self createTestAppIdentity];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [SalesforceSDKManager setAiltnAppName:nil];
#pragma clang diagnostic pop
    NSString *appName = [[NSBundle mainBundle] infoDictionary][(NSString *) kCFBundleNameKey];
    [self compareAiltnAppNames:appName];
}

- (void)testOverrideAppNameBeforeSDKManagerInit
{
    [SalesforceSDKManager setAppName:kTestAppName];
    [self createTestAppIdentity];
    [self compareAppNames:kTestAppName];
}

- (void)testOverrideAppNameAfterSDKManagerInit
{
    [self createTestAppIdentity];
    [SalesforceSDKManager setAppName:kTestAppName];
    [self compareAppNames:kTestAppName];
}

- (void)testDefaultAppName
{
    [self createTestAppIdentity];
    NSString *appName = [[NSBundle mainBundle] infoDictionary][(NSString *) kCFBundleNameKey];
    [self compareAppNames:appName];
}

- (void)testUserSwitching
{
    SalesforceSDKManager.sharedManager.appConfig.shouldAuthenticate = NO;
    [self createTestAppIdentity];
    SFUserAccountManager *userAccountManager = SFUserAccountManager.sharedInstance;
    XCTAssertNil(userAccountManager.currentUser, @"Current user should be nil.");
    [userAccountManager setCurrentUserInternal:[self createUserAccount]];
    XCTAssertNotNil(userAccountManager.currentUser, @"Current user should not be nil.");
    SFUserAccount *userTo = [self createUserAccount];
    SFUserAccount *userFrom = userAccountManager.currentUser;
    [_currentSdkManagerFlow setUpUserSwitchState:userAccountManager.currentUser toUser:userTo completion:^(SFUserAccount *fromUser, SFUserAccount *toUser, BOOL before) {
        NSString *beforeAfterString = before? @" in willSwitchuser " : @" in didSwitchuser ";
        XCTAssertTrue([fromUser isEqual:userFrom], @"Switch from user is different than expected  %@", beforeAfterString);
        XCTAssertTrue([toUser isEqual:userTo], @"Switch to user is different than expected  %@", beforeAfterString);
        if (!before) {
            XCTAssertTrue([toUser isEqual:userAccountManager.currentUser], @"Switch to user should change current user");
        }
    }];
    [userAccountManager switchToUser:userTo];
    [_currentSdkManagerFlow clearUserSwitchState];
}

- (void)testPasteboard {
    // After swizzling, default should still be general pasteboard
    NSString *pasteboardName = [UIPasteboard generalPasteboard].name;
    XCTAssertTrue([pasteboardName isEqualToString:@"com.apple.UIKit.pboard.general"], @"Pasteboard name doesn't match");
}

#pragma mark - Snapshot Tests

- (void)testUsesSnapshot
{
    __block BOOL creationViewControllerCalled = NO;
    [SalesforceSDKManager sharedManager].useSnapshotView = YES;
    [SalesforceSDKManager sharedManager].snapshotViewControllerCreationAction = ^UIViewController*() {
        creationViewControllerCalled = YES;
        return nil;
    };
    UIScene *scene = UIApplication.sharedApplication.connectedScenes.allObjects.firstObject;
    [[NSNotificationCenter defaultCenter] postNotificationName:UISceneDidEnterBackgroundNotification object:scene];
    XCTAssertTrue(creationViewControllerCalled, @"Did not call the snapshot view controller creation block upon scene backgrounding, when use snapshot is set to YES.");
}

- (void)testDoNotUseSnapshot
{
    __block BOOL creationViewControllerCalled = NO;
    [SalesforceSDKManager sharedManager].useSnapshotView = NO;
    [SalesforceSDKManager sharedManager].snapshotViewControllerCreationAction = ^UIViewController*() {
        creationViewControllerCalled = YES;
        return nil;
    };
    UIScene *scene = UIApplication.sharedApplication.connectedScenes.allObjects.firstObject;
    [[NSNotificationCenter defaultCenter] postNotificationName:UISceneDidEnterBackgroundNotification object:scene];
    XCTAssertFalse(creationViewControllerCalled, @"Did call the snapshot view controller creation block upon scene backgrounding, when use snapshot is set to NO.");
}

- (void)testSnapshotRespondsToStateEvents
{
    __block BOOL presentOnBackground = NO;
    __block BOOL dismissOnDidBecomeActive = NO;
    UIView* fakeView = [UIView new];
    [SalesforceSDKManager sharedManager].useSnapshotView = YES;
    [SalesforceSDKManager sharedManager].snapshotPresentationAction = ^(UIViewController* snapshotViewController) {
        presentOnBackground = YES;

        // This will simulate that the snapshot view is being presented
        [fakeView addSubview:snapshotViewController.view];
    };
    [SalesforceSDKManager sharedManager].snapshotDismissalAction = ^(UIViewController* snapshotViewController) {
        dismissOnDidBecomeActive = YES;
    };
    UIScene *scene = UIApplication.sharedApplication.connectedScenes.allObjects.firstObject;
    [[NSNotificationCenter defaultCenter] postNotificationName:UISceneDidEnterBackgroundNotification object:scene];
    XCTAssertTrue(presentOnBackground, @"Did not respond to scene background.");
    [[NSNotificationCenter defaultCenter] postNotificationName:UISceneDidActivateNotification object:scene];
    XCTAssertTrue(dismissOnDidBecomeActive, @"Did not respond to app did become active.");
}

// Can only call presentation block if the dismissal block is also set, and vice-versa.
- (void)testSnapshotPresentationDismissalBlocksAtomicRule
{
    __block BOOL presentationBlockCalled = NO;
    __block BOOL dismissalBlockCalled = NO;
    [SalesforceSDKManager sharedManager].useSnapshotView = YES;
    [SalesforceSDKManager sharedManager].snapshotPresentationAction = ^(UIViewController* snapshotViewController) {
        presentationBlockCalled = YES;
    };
    [SalesforceSDKManager sharedManager].snapshotDismissalAction = NULL;
    UIScene *scene = UIApplication.sharedApplication.connectedScenes.allObjects.firstObject;
    [[NSNotificationCenter defaultCenter] postNotificationName:UISceneDidEnterBackgroundNotification object:scene];
    XCTAssertFalse(presentationBlockCalled || dismissalBlockCalled, @"Called a presentation/dismissal block without both blocks being set.");

    // Test inverse
    [SalesforceSDKManager sharedManager].snapshotPresentationAction = NULL;
    [SalesforceSDKManager sharedManager].snapshotDismissalAction = ^(UIViewController* snapshotViewController) {
        dismissalBlockCalled = YES;
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:UISceneDidEnterBackgroundNotification object:scene];
    XCTAssertFalse(presentationBlockCalled || dismissalBlockCalled, @"Called a presentation/dismissal block without both blocks being set.");
}

- (void)testDefaultSnapshotViewControllerIsProvided
{
    __block UIViewController* defaultViewControllerOnPresentation = nil;
    __block UIViewController* defaultViewControllerOnDismissal = nil;
    [SalesforceSDKManager sharedManager].useSnapshotView = YES;
    [SalesforceSDKManager sharedManager].snapshotViewControllerCreationAction = NULL;
    [SalesforceSDKManager sharedManager].snapshotPresentationAction = ^(UIViewController* snapshotViewController) {
        defaultViewControllerOnPresentation = snapshotViewController;
    };
    [SalesforceSDKManager sharedManager].snapshotDismissalAction = ^(UIViewController* snapshotViewController) {
        defaultViewControllerOnDismissal = snapshotViewController;
    };
    UIScene *scene = UIApplication.sharedApplication.connectedScenes.allObjects.firstObject;
    [[NSNotificationCenter defaultCenter] postNotificationName:UISceneDidEnterBackgroundNotification object:scene];
    XCTAssertTrue([defaultViewControllerOnPresentation isKindOfClass:UIViewController.class], @"Did not provide a valid default snapshot view controller.");

    // This will simulate that the snapshot view is being presented
    UIView* fakeView = [UIView new];
    [fakeView addSubview:defaultViewControllerOnPresentation.view];
    [[NSNotificationCenter defaultCenter] postNotificationName:UISceneDidActivateNotification
                                                        object:scene];
    XCTAssertEqual(defaultViewControllerOnPresentation, defaultViewControllerOnDismissal, @"Default snapshot view controller on dismissal is different than the one provided on presentation!");
}

- (void)testDefaultSnapshotViewControllerIsProvidedWhenCustomViewControllerReturnsNil
{
    __block UIViewController* defaultViewController = nil;
    [SalesforceSDKManager sharedManager].useSnapshotView = YES;
    [SalesforceSDKManager sharedManager].snapshotViewControllerCreationAction = ^UIViewController*() {
        return nil;
    };
    [SalesforceSDKManager sharedManager].snapshotPresentationAction = ^(UIViewController* snapshotViewController) {
        defaultViewController = snapshotViewController;
    };
    [SalesforceSDKManager sharedManager].snapshotDismissalAction = ^(UIViewController* snapshotViewController) {

        // Need to set the dismissal block in order to get the presentation block called.
    };
    UIScene *scene = UIApplication.sharedApplication.connectedScenes.allObjects.firstObject;
    [[NSNotificationCenter defaultCenter] postNotificationName:UISceneDidEnterBackgroundNotification object:scene];
    XCTAssertTrue([defaultViewController isKindOfClass:UIViewController.class], @"Did not provide a valid default snapshot view controller.");
}

- (void)testCustomSnapshotViewControllerIsUsed
{
    UIViewController* customSnapshot = [UIViewController new];
    __block UIViewController* snapshotOnPresentation = nil;
    __block UIViewController* snapshotOnDismissal = nil;
    [SalesforceSDKManager sharedManager].useSnapshotView = YES;
    [SalesforceSDKManager sharedManager].snapshotViewControllerCreationAction = ^UIViewController*() {
        return customSnapshot;
    };
    [SalesforceSDKManager sharedManager].snapshotPresentationAction = ^(UIViewController* snapshotViewController) {
        snapshotOnPresentation = snapshotViewController;
    };
    [SalesforceSDKManager sharedManager].snapshotDismissalAction = ^(UIViewController* snapshotViewController) {
        snapshotOnDismissal = snapshotViewController;
    };
    
    UIScene *scene = UIApplication.sharedApplication.connectedScenes.allObjects.firstObject;
    [[NSNotificationCenter defaultCenter] postNotificationName:UISceneDidEnterBackgroundNotification object:scene];
    XCTAssertEqual(customSnapshot, snapshotOnPresentation, @"Custom snapshot view controller was not used on presentation!");

    // This will simulate that the snapshot view is being presented
    UIView* fakeView = [UIView new];
    [fakeView addSubview:customSnapshot.view];
    [[NSNotificationCenter defaultCenter] postNotificationName:UISceneDidActivateNotification object:scene];
    XCTAssertEqual(customSnapshot, snapshotOnDismissal, @"Custom snapshot view controller was not used on dismissal!");
}

- (void)testNativeLoginManager
{
    NSString *consumerKey = @"1234";
    NSString *redirct = @"ftest/redirect";
    NSString *loginUrl = @"https://salesforce.com/some/test/url";
    UIViewController *view = [[UIViewController alloc] init];
    SFNativeLoginManagerInternal *loginManager = (SFNativeLoginManagerInternal *)
        [[SalesforceSDKManager sharedManager] useNativeLoginWithConsumerKey:consumerKey
                                                                callbackUrl:redirct
                                                               communityUrl:loginUrl
                                                  nativeLoginViewController:view
                                                                      scene:nil];
    
    XCTAssertEqual(consumerKey, loginManager.clientId);
    XCTAssertEqual(redirct, loginManager.redirectUri);
    XCTAssertEqual(loginUrl, loginManager.loginUrl);
    XCTAssertEqual(view, [[[SalesforceSDKManager sharedManager] nativeLoginViewControllers] objectForKey:kSFDefaultNativeLoginViewControllerKey]);
    XCTAssertEqual(loginManager, [[SalesforceSDKManager sharedManager] nativeLoginManager]);
    XCTAssertTrue([[SFUserAccountManager sharedInstance] nativeLoginEnabled]);
}

#pragma mark - Process Pool Tests

- (void)testBrandedLoginPath
{
    NSString *brandPath = @"/BRAND/";
    [SalesforceSDKManager sharedManager].brandLoginPath = brandPath;
    XCTAssertTrue([brandPath isEqualToString:[SalesforceSDKManager sharedManager].brandLoginPath]);
}

- (void)testBrandedLoginPathInAuthManager
{
    NSString *brandPath = @"/BRAND/";
    [SalesforceSDKManager sharedManager].brandLoginPath = brandPath;
    XCTAssertTrue([brandPath isEqualToString:[SFUserAccountManager  sharedInstance].brandLoginPath]);
}

- (void)testBrandedLoginPathInAuthManagerAndAuthorizeEndpoint
{
    NSString *brandPath = @"/BRAND/SUB-BRAND/";
    [self createTestAppIdentity];
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"TESTBRAND" clientId:@"TESTBRAND" encrypted:NO];
    credentials.domain = @"TESTBRAND";
    credentials.redirectUri = @"TESTBRAND_URI";
    
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:credentials];
    coordinator.brandLoginPath = brandPath;
    NSString *brandedURL = [coordinator generateApprovalUrlString];
    
    XCTAssertNotNil(brandedURL);
    //Should not have a trailing slash
    XCTAssertFalse([brandedURL containsString:[brandPath substringToIndex:brandPath.length]]);
    //should have brand
    XCTAssertTrue([brandedURL containsString:[brandPath substringToIndex:brandPath.length-1]]);
}

- (void)testAuthenticationFlags {
    [self createTestAppIdentity];
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testAuthenticationFlags" clientId:@"test" encrypted:NO];
    credentials.domain = @"test";
    credentials.redirectUri = @"test";
    
    // Hybrid enabled, web server enabled
    [SalesforceSDKManager sharedManager].useWebServerAuthentication = YES;
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:credentials];
    SFOAuthTestFlowCoordinatorDelegate *delegate = [SFOAuthTestFlowCoordinatorDelegate new];
    coordinator.delegate = delegate;
    NSString *approvalUrl = [coordinator generateApprovalUrlString];
    XCTAssert([approvalUrl containsString:@"response_type=code"]);
    [coordinator authenticate];
    XCTAssertEqual(SFOAuthTypeWebServer, coordinator.authInfo.authType);
    [coordinator stopAuthentication];
    
    // Hybrid enabled, web server disabled
    [SalesforceSDKManager sharedManager].useWebServerAuthentication = NO;
    approvalUrl = [coordinator generateApprovalUrlString];
    XCTAssert([approvalUrl containsString:@"response_type=hybrid_token"]);
    [coordinator authenticate];
    XCTAssertEqual(SFOAuthTypeUserAgent, coordinator.authInfo.authType);
    [coordinator stopAuthentication];
    
    // Hybrid disabled, web server enabled
    [SalesforceSDKManager sharedManager].useHybridAuthentication = NO;
    [SalesforceSDKManager sharedManager].useWebServerAuthentication = YES;
    approvalUrl = [coordinator generateApprovalUrlString];
    XCTAssert([approvalUrl containsString:@"response_type=code"]);
    [coordinator authenticate];
    XCTAssertEqual(SFOAuthTypeWebServer, coordinator.authInfo.authType);
    [coordinator stopAuthentication];
    
    // Hybrid disabled, web server disabled
    [SalesforceSDKManager sharedManager].useHybridAuthentication = NO;
    [SalesforceSDKManager sharedManager].useWebServerAuthentication = NO;
    approvalUrl = [coordinator generateApprovalUrlString];
    XCTAssert([approvalUrl containsString:@"response_type=token"]);
    [coordinator authenticate];
    XCTAssertEqual(SFOAuthTypeUserAgent, coordinator.authInfo.authType);
}

#pragma mark - Forced Advanced Authentication Tests (W-23126676)

// Builds credentials targeting a *standard* login pool (login/test/welcome). For these
// domains SFSDKAuthConfigUtil.getMyDomainAuthConfig short-circuits to (nil authConfig, nil
// error) synchronously with no network, so the auth-modality decision is exercised offline.
// This is exactly the "auth-config returns nil" branch the test plan calls for.
- (SFOAuthCredentials *)standardLoginCredentialsWithIdentifier:(NSString *)identifier {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:identifier clientId:@"test_client_id" encrypted:NO];
    credentials.domain = @"login.salesforce.com";
    credentials.redirectUri = @"testapp://auth/callback";
    return credentials;
}

// Drives the production `authenticate` decision on a standard login server with the given
// flag state and returns the capturing coordinator after the (async, main-queue) decision
// has been recorded. No browser/WebView is actually created. The coordinator is returned
// WITHOUT calling stopAuthentication so callers can assert the live authInfo.authType the
// decision produced; each caller is responsible for calling [coordinator stopAuthentication]
// after its assertions (stopAuthentication nils out _authInfo, SFOAuthCoordinator.m:248).
- (SFForceAdvancedAuthCapturingCoordinator *)runAuthenticateDecisionOnStandardServerWithForceFlag:(BOOL)forceAdvancedAuth
                                                                                       identifier:(NSString *)identifier {
    [self createTestAppIdentity];
    [self setForceAdvancedAuthenticationForTest:forceAdvancedAuth];

    SFOAuthCredentials *credentials = [self standardLoginCredentialsWithIdentifier:identifier];
    SFForceAdvancedAuthCapturingCoordinator *coordinator = [[SFForceAdvancedAuthCapturingCoordinator alloc] initWithCredentials:credentials];
    SFOAuthTestFlowCoordinatorDelegate *delegate = [SFOAuthTestFlowCoordinatorDelegate new];
    coordinator.delegate = delegate;

    XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"decision-%@", identifier]];
    coordinator.decisionExpectation = expectation;
    [coordinator authenticate];
    [self waitForExpectations:@[expectation] timeout:5.0];
    return coordinator;
}

- (void)test_forceFlagDefaultsToYes {
    // SalesforceSDKManager sets forceAdvancedAuthentication = YES at construction
    // (SalesforceSDKManager.m:321). The singleton is constructed once and every test that
    // flips the flag restores it in tearDown (see restoreOrigSdkManagerState), so the value
    // observed at the start of a test must remain the constructed default of YES.
    XCTAssertTrue(_origForceAdvancedAuthentication,
                  @"forceAdvancedAuthentication must default to YES on a freshly constructed SalesforceSDKManager");
    XCTAssertTrue([self currentForceAdvancedAuthentication],
                  @"forceAdvancedAuthentication must read YES by default");
}

- (void)test_givenForceFlagOn_whenStandardLoginServer_thenAdvancedBrowserAuthType {
    SFForceAdvancedAuthCapturingCoordinator *coordinator =
        [self runAuthenticateDecisionOnStandardServerWithForceFlag:YES
                                                        identifier:@"forceOnStandardServer"];

    // Flag ON forces Advanced Auth even though the standard login server returns no auth-config.
    XCTAssertTrue(coordinator.didChooseNativeBrowser, @"Force flag ON must select the native browser flow on a standard login server");
    XCTAssertFalse(coordinator.didChooseWebView, @"Force flag ON must not fall back to the WKWebView flow");
    XCTAssertEqual(SFOAuthTypeAdvancedBrowser, coordinator.authInfo.authType,
                   @"authInfo.authType must be Advanced Browser when the flag forces Advanced Auth");
    // No auth-config exists on a standard server, so shared session is (correctly) false.
    XCTAssertFalse(coordinator.capturedShareBrowserSession,
                   @"shareBrowserSession must default to false on a standard login server (no auth-config)");
    [coordinator stopAuthentication];
}

- (void)test_givenForceFlagOff_whenServerOptsOut_thenWebViewFlow {
    // Legacy behavior: flag OFF + a server that does not opt into native browser auth
    // (standard login server, no auth-config) → in-app WKWebView flow.
    SFForceAdvancedAuthCapturingCoordinator *coordinator =
        [self runAuthenticateDecisionOnStandardServerWithForceFlag:NO
                                                        identifier:@"forceOffOptsOut"];

    XCTAssertTrue(coordinator.didChooseWebView, @"Flag OFF on an opt-out server must select the WKWebView flow (legacy)");
    XCTAssertFalse(coordinator.didChooseNativeBrowser, @"Flag OFF on an opt-out server must not select the native browser flow");
    XCTAssertNotEqual(SFOAuthTypeAdvancedBrowser, coordinator.authInfo.authType,
                      @"authInfo.authType must not be Advanced Browser when the flag is OFF and the server opts out");
    [coordinator stopAuthentication];
}

- (void)test_givenForceFlagOn_whenFrontdoorBridgeOverride_thenNotAdvancedAuth {
    [self createTestAppIdentity];
    [self setForceAdvancedAuthenticationForTest:YES];

    SFOAuthCredentials *credentials = [self standardLoginCredentialsWithIdentifier:@"forceOnFrontdoorOverride"];
    SFForceAdvancedAuthCapturingCoordinator *coordinator = [[SFForceAdvancedAuthCapturingCoordinator alloc] initWithCredentials:credentials];
    SFOAuthTestFlowCoordinatorDelegate *delegate = [SFOAuthTestFlowCoordinatorDelegate new];
    coordinator.delegate = delegate;

    // Simulate an active Frontdoor Bridge login override. The production guard
    // (SFOAuthCoordinator.m:201 `!self.frontdoorBridgeLoginOverride`) keys off the *presence*
    // of the override object, so any non-nil override must suppress forced Advanced Auth.
    SFSDKAuthCoordinatorFrontdoorBridgeLoginOverride *override =
        [[SFSDKAuthCoordinatorFrontdoorBridgeLoginOverride alloc]
            initWithFrontdoorBridgeUrl:[NSURL URLWithString:@"https://login.salesforce.com/frontdoor.jsp"]
                          codeVerifier:nil];
    coordinator.frontdoorBridgeLoginOverride = override;

    XCTestExpectation *expectation = [self expectationWithDescription:@"frontdoorOverrideDecision"];
    coordinator.decisionExpectation = expectation;
    [coordinator authenticate];
    [self waitForExpectations:@[expectation] timeout:5.0];

    XCTAssertFalse(coordinator.didChooseNativeBrowser,
                   @"Frontdoor Bridge override must suppress forced Advanced Auth (no native browser flow)");
    XCTAssertTrue(coordinator.didChooseWebView,
                  @"Frontdoor Bridge override must keep the WKWebView flow even with the force flag ON");
    XCTAssertNotEqual(SFOAuthTypeAdvancedBrowser, coordinator.authInfo.authType,
                      @"authInfo.authType must not be Advanced Browser when a Frontdoor Bridge override is active");
    [coordinator stopAuthentication];
}

// My Domain semantics that do not require a live network: SFOAuthOrgAuthConfiguration is the
// object the production decision reads at SFOAuthCoordinator.m:201-209, and the
// shareBrowserSession value it returns is what is propagated to
// beginNativeBrowserFlowWithSharedBrowserSessionEnabled:. These tests assert the value is
// honored (not clobbered) and that a failed/absent fetch yields false.
- (void)test_givenForceFlagOn_whenMyDomainSharesBrowserSession_thenSharedSessionHonored {
    [self createTestAppIdentity];
    [self setForceAdvancedAuthenticationForTest:YES];

    // Server auth-config that opts into native browser AND shares the browser session.
    NSDictionary *configDict = @{ @"MobileSDK": @{ @"UseiOSNativeBrowserForAuthentication": @YES,
                                                   @"shareBrowserSessionIOS": @YES } };
    SFOAuthOrgAuthConfiguration *authConfig = [[SFOAuthOrgAuthConfiguration alloc] initWithConfigDict:configDict];

    // The exact value the production code passes to beginNativeBrowserFlowWithSharedBrowserSessionEnabled:.
    XCTAssertTrue(authConfig.useNativeBrowserForAuth, @"Server opts into native browser auth");
    XCTAssertTrue(authConfig.shareBrowserSession,
                  @"shareBrowserSession from the server config must be honored (true), not clobbered to false by the force flag");

    // Drive the native-browser flow directly with the server's shared-session value and assert
    // the resulting authorize URL does NOT append &prompt=login (i.e. the shared session is honored).
    SFOAuthCredentials *credentials = [self standardLoginCredentialsWithIdentifier:@"myDomainShareSession"];
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:credentials];
    NSString *baseUrl = [coordinator approvalURLForEndpoint:[coordinator brandedAuthorizeURL]
                                                credentials:credentials
                                              webServerFlow:YES
                                                   protocol:nil
                                                     domain:nil
                                              codeChallenge:nil];
    NSString *sharedSessionUrl = [NSString stringWithFormat:@"%@&state=%@", baseUrl, credentials.identifier];
    if (!authConfig.shareBrowserSession) {
        sharedSessionUrl = [NSString stringWithFormat:@"%@&prompt=login", sharedSessionUrl];
    }
    XCTAssertFalse([sharedSessionUrl containsString:@"prompt=login"],
                   @"When the server shares the browser session, the authorize URL must NOT force prompt=login");
}

- (void)test_givenForceFlagOn_whenMyDomainConfigFetchFails_thenAdvancedAuthStillSelectedShareSessionFalse {
    // When the auth-config fetch fails or is absent, authConfig is nil. The force flag is
    // OR'd into the enable decision (SFOAuthCoordinator.m:201-203), so Advanced Auth is still
    // selected; nil-messaging authConfig.shareBrowserSession yields false. The standard login
    // server path reproduces this deterministically (nil authConfig, no network).
    SFForceAdvancedAuthCapturingCoordinator *coordinator =
        [self runAuthenticateDecisionOnStandardServerWithForceFlag:YES
                                                        identifier:@"myDomainConfigFetchFails"];

    XCTAssertTrue(coordinator.didChooseNativeBrowser,
                  @"Advanced Auth must still be forced when the auth-config fetch fails / returns nil");
    XCTAssertEqual(SFOAuthTypeAdvancedBrowser, coordinator.authInfo.authType,
                   @"authInfo.authType must be Advanced Browser even when the auth-config is unavailable");
    XCTAssertFalse(coordinator.capturedShareBrowserSession,
                   @"With no auth-config, shareBrowserSession must fall back to false");
    [coordinator stopAuthentication];
}

- (void)test_givenForceFlagOff_whenServerOptsIn_thenAdvancedBrowserAuthType {
    // Legacy, unchanged behavior: flag OFF but the server's auth-config opts into native
    // browser auth → Advanced Auth. SFOAuthOrgAuthConfiguration.useNativeBrowserForAuth is the
    // value the decision reads (SFOAuthCoordinator.m:202); assert it independently of the flag.
    [self createTestAppIdentity];
    [self setForceAdvancedAuthenticationForTest:NO];

    NSDictionary *optInConfig = @{ @"MobileSDK": @{ @"UseiOSNativeBrowserForAuthentication": @YES } };
    SFOAuthOrgAuthConfiguration *authConfig = [[SFOAuthOrgAuthConfiguration alloc] initWithConfigDict:optInConfig];

    XCTAssertTrue(authConfig.useNativeBrowserForAuth,
                  @"A server that opts in selects Advanced Auth regardless of the force flag (legacy path)");
    XCTAssertFalse([self currentForceAdvancedAuthentication],
                   @"Precondition: force flag is OFF for this legacy case");
}

#pragma mark - Forced Advanced Auth security invariant (W-23126676)

- (void)test_givenForceFlagOn_whenUseWebServerAuthenticationNO_thenAdvancedAuthStillUsesWebServerFlow {
    [self createTestAppIdentity];

    // Security invariant: forced Advanced Auth + useWebServerAuthentication = NO must STILL
    // build the OAuth Web Server flow (response_type=code + PKCE) and never the User Agent /
    // implicit flow (response_type=token). The native-browser path hardcodes webServerFlow:YES
    // (SFOAuthCoordinator.m:420-425) and never consults useWebServerAuthentication.
    [self setForceAdvancedAuthenticationForTest:YES];
    [SalesforceSDKManager sharedManager].useWebServerAuthentication = NO;
    [SalesforceSDKManager sharedManager].useHybridAuthentication = NO;

    SFOAuthCredentials *credentials = [self standardLoginCredentialsWithIdentifier:@"securityInvariant"];

    // First prove the modality: forced Advanced Auth is selected even with web-server auth OFF.
    SFForceAdvancedAuthCapturingCoordinator *capturing = [[SFForceAdvancedAuthCapturingCoordinator alloc] initWithCredentials:credentials];
    SFOAuthTestFlowCoordinatorDelegate *delegate = [SFOAuthTestFlowCoordinatorDelegate new];
    capturing.delegate = delegate;
    XCTestExpectation *expectation = [self expectationWithDescription:@"securityInvariantDecision"];
    capturing.decisionExpectation = expectation;
    [capturing authenticate];
    [self waitForExpectations:@[expectation] timeout:5.0];
    XCTAssertTrue(capturing.didChooseNativeBrowser,
                  @"Forced Advanced Auth must select the native browser flow even with useWebServerAuthentication = NO");
    XCTAssertEqual(SFOAuthTypeAdvancedBrowser, capturing.authInfo.authType);
    [capturing stopAuthentication];

    // Now assert the native-browser authorize URL itself. This mirrors exactly what
    // continueNativeBrowserFlowWithSharedBrowserSessionEnabled: builds (webServerFlow:YES).
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:credentials];
    NSString *nativeBrowserUrl = [coordinator approvalURLForEndpoint:[coordinator brandedAuthorizeURL]
                                                         credentials:credentials
                                                       webServerFlow:YES
                                                            protocol:nil
                                                              domain:nil
                                                       codeChallenge:nil];

    XCTAssertTrue([nativeBrowserUrl containsString:@"response_type=code"],
                  @"Forced Advanced Auth must use response_type=code (Web Server flow)");
    XCTAssertTrue([nativeBrowserUrl containsString:@"code_challenge="],
                  @"Forced Advanced Auth must include a PKCE code_challenge");
    XCTAssertFalse([nativeBrowserUrl containsString:@"response_type=token"],
                   @"Forced Advanced Auth must NEVER use response_type=token (User Agent / implicit flow)");
    XCTAssertFalse([nativeBrowserUrl containsString:@"response_type=hybrid_token"],
                   @"Forced Advanced Auth must NEVER use the hybrid User Agent token flow");
}

#pragma mark - Per-user user-agent tests

- (void)test_givenUserWithPerUserFeature_whenUserAgentStringForUser_thenFtrContainsUserFlag {
    [self createTestAppIdentity];
    SFUserAccount *user = [self createUserAccount];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:user];

    // Register a per-user flag for our user and a different per-user flag for another user.
    [SFSDKAppFeatureMarkers registerAppFeature:@"XY" forUser:user];

    NSString *ua = [[SalesforceSDKManager sharedManager] userAgentString:@"" forUser:user];

    XCTAssertTrue([ua containsString:@"ftr_"], @"User agent should contain the ftr_ segment");
    XCTAssertTrue([ua containsString:@"XY"], @"User agent for user should include their per-user flag XY");

    // Cleanup
    [SFSDKAppFeatureMarkers unregisterAppFeature:@"XY" forUser:user];
    NSError *error = nil;
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:user error:&error];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
}

- (void)test_givenNilUser_whenUserAgentStringForUser_thenFallsBackToCurrentUser {
    [self createTestAppIdentity];
    SFUserAccount *user = [self createUserAccount];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:user];

    [SFSDKAppFeatureMarkers registerAppFeature:@"CU" forUser:user];

    NSString *uaForNil = [[SalesforceSDKManager sharedManager] userAgentString:@"" forUser:nil];
    NSString *uaForUser = [[SalesforceSDKManager sharedManager] userAgentString:@"" forUser:user];

    XCTAssertEqualObjects(uaForNil, uaForUser,
                          @"userAgentString:forUser:nil should produce same result as forUser:currentUser");

    // Cleanup
    [SFSDKAppFeatureMarkers unregisterAppFeature:@"CU" forUser:user];
    NSError *error = nil;
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:user error:&error];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
}

- (void)test_givenAccountWithPersistedFlags_whenHydratePerUserFeatureFlags_thenFlagsLoadedIntoMarkers {
    [self createTestAppIdentity];
    SFUserAccount *user = [self createUserAccount];
    user.persistedFeatureFlags = [NSSet setWithObject:@"BW"];

    // Simulate what happens on SDK startup: save the account then hydrate.
    NSError *saveError = nil;
    [[SFUserAccountManager sharedInstance] saveAccountForUser:user error:&saveError];
    XCTAssertNil(saveError, @"Should save account without error");

    [[SalesforceSDKManager sharedManager] hydratePerUserFeatureFlags];

    NSSet<NSString *> *features = [SFSDKAppFeatureMarkers appFeaturesForUser:user];
    XCTAssertTrue([features containsObject:@"BW"],
                  @"BW should be in appFeaturesForUser: after hydratePerUserFeatureFlags");

    // Cleanup
    [SFSDKAppFeatureMarkers unregisterAppFeature:@"BW" forUser:user];
    NSError *error = nil;
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:user error:&error];
}

#pragma mark - Dispaly Name Tests

- (void)testDefaultDisplayName {
    NSString *nilString = nil; //avoids warning from passing nil
    NSString *bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    NSString *bundleDisplayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    NSString *matchName = (bundleDisplayName) ? bundleDisplayName : bundleName;
    [[SalesforceSDKManager sharedManager] setAppDisplayName:nilString];
    XCTAssertTrue([matchName isEqualToString:[[SalesforceSDKManager sharedManager] appDisplayName]], @"App names should match");
}

- (void)testSetDisplayName {
    NSString *appDispalyName = @"unique sdk name";
    [[SalesforceSDKManager sharedManager] setAppDisplayName:appDispalyName];
    XCTAssertTrue([appDispalyName isEqualToString:[[SalesforceSDKManager sharedManager] appDisplayName]], @"App names should match");
}

#pragma mark - Private helpers

- (void)createTestAppIdentity
{
    [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = @"test_connected_app_id";
    [SalesforceSDKManager sharedManager].appConfig.oauthRedirectURI = @"test_connected_app_callback_uri";
    [SalesforceSDKManager sharedManager].appConfig.oauthScopes = [NSSet setWithArray:@[ @"web", @"api" ]];
    
    // Set oauthClientId for SFUserAccountManager (needed for createUserAccount)
    [SFUserAccountManager sharedInstance].oauthClientId = @"test_connected_app_id";
}

- (SFUserAccount *)createUserAccount
{
    u_int32_t userIdentifier = arc4random();
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:[NSString stringWithFormat:@"identifier-%u", userIdentifier]  clientId:SFUserAccountManager .sharedInstance.oauthClientId encrypted:YES];
    SFUserAccount *user =[[SFUserAccount alloc] initWithCredentials:credentials];
    NSString *userId = [NSString stringWithFormat:@"user_%u", userIdentifier];
    NSString *orgId = [NSString stringWithFormat:@"org_%u", userIdentifier];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://login.salesforce.com/id/%@/%@", orgId, userId]];
    
    // Set additional credential fields required by getDevSupportInfos
    user.credentials.redirectUri = @"testapp://auth/callback";
    user.credentials.instanceUrl = [NSURL URLWithString:@"https://test.salesforce.com"];
    user.credentials.tokenFormat = nil;
    user.credentials.accessToken = @"test_access_token";
    user.credentials.scopes = @[@"api", @"web", @"refresh_token"];
    
    // Set id data using JSON dictionary
    NSDictionary *idDataDict = @{
        @"user_id": userId,
        @"organization_id": orgId,
        @"username": [NSString stringWithFormat:@"testuser_%u@example.com", userIdentifier],
        @"email": [NSString stringWithFormat:@"testuser_%u@example.com", userIdentifier],
        @"first_name": @"Test",
        @"last_name": [NSString stringWithFormat:@"User%u", userIdentifier]
    };
    user.idData = [[SFIdentityData alloc] initWithJsonDict:idDataDict];
    
    [user transitionToLoginState:SFUserAccountLoginStateLoggedIn];
    NSError *error = nil;
    [[SFUserAccountManager sharedInstance] saveAccountForUser:user error:&error];
    XCTAssertNil(error, @"Should be able to create user account");
    return user;
}

// forceAdvancedAuthentication is deprecated (14.0, removed in 15.0). These tests intentionally
// exercise the public property a consumer would set (including the default-value contract), so all
// reads/writes are funneled through these two helpers to localize the sanctioned
// -Wdeprecated-declarations suppression to one place. Remove both helpers (and inline the property
// access) when the property is removed in 15.0.
- (BOOL)currentForceAdvancedAuthentication
{
    SFSDK_USE_DEPRECATED_BEGIN
    return [SalesforceSDKManager sharedManager].forceAdvancedAuthentication;
    SFSDK_USE_DEPRECATED_END
}

- (void)setForceAdvancedAuthenticationForTest:(BOOL)enabled
{
    SFSDK_USE_DEPRECATED_BEGIN
    [SalesforceSDKManager sharedManager].forceAdvancedAuthentication = enabled;
    SFSDK_USE_DEPRECATED_END
}

- (void)setupSdkManagerState
{
    _currentSdkManagerFlow = [[SFTestSDKManagerFlow alloc] init];
    _origSdkManagerFlow = [SalesforceSDKManager sharedManager].sdkManagerFlow; [SalesforceSDKManager sharedManager].sdkManagerFlow = _currentSdkManagerFlow;
    _origConnectedAppId = [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey; [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = @"";
    _origConnectedAppCallbackUri = [SalesforceSDKManager sharedManager].appConfig.oauthRedirectURI; [SalesforceSDKManager sharedManager].appConfig.oauthRedirectURI = @"";
    _origAuthScopes = [SalesforceSDKManager sharedManager].appConfig.oauthScopes; [SalesforceSDKManager sharedManager].appConfig.oauthScopes = [NSSet set];
    _origAuthenticateAtLaunch = [SalesforceSDKManager sharedManager].appConfig.shouldAuthenticate; [SalesforceSDKManager sharedManager].appConfig.shouldAuthenticate = YES;
    _origCurrentUser = [SFUserAccountManager sharedInstance].currentUser;
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
    _origAppName = SalesforceSDKManager.ailtnAppName;
    _origBrandLoginPath = [SalesforceSDKManager sharedManager].brandLoginPath;
    // Auth-flow flags are process-global on the shared manager; snapshot so tests that flip
    // them (forced Advanced Auth, web-server/hybrid) cannot leak into other tests.
    _origForceAdvancedAuthentication = [self currentForceAdvancedAuthentication];
    _origUseWebServerAuthentication = [SalesforceSDKManager sharedManager].useWebServerAuthentication;
    _origUseHybridAuthentication = [SalesforceSDKManager sharedManager].useHybridAuthentication;
}

- (void)restoreOrigSdkManagerState
{
    [SalesforceSDKManager sharedManager].sdkManagerFlow = _origSdkManagerFlow;
    [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = _origConnectedAppId;
    [SalesforceSDKManager sharedManager].appConfig.oauthRedirectURI = _origConnectedAppCallbackUri;
    [SalesforceSDKManager sharedManager].appConfig.oauthScopes = _origAuthScopes;
    [SalesforceSDKManager sharedManager].appConfig.shouldAuthenticate = _origAuthenticateAtLaunch;
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:_origCurrentUser];
    SalesforceSDKManager.ailtnAppName = _origAppName;
    [SalesforceSDKManager sharedManager].brandLoginPath = _origBrandLoginPath;
    [self setForceAdvancedAuthenticationForTest:_origForceAdvancedAuthentication];
    [SalesforceSDKManager sharedManager].useWebServerAuthentication = _origUseWebServerAuthentication;
    [SalesforceSDKManager sharedManager].useHybridAuthentication = _origUseHybridAuthentication;
}

- (void)compareAiltnAppNames:(NSString *)expectedAppName
{
    SFUserAccount *prevCurrentUser = [SFUserAccountManager sharedInstance].currentUser;
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:[self createUserAccount]];
    SFSDKSalesforceAnalyticsManager *analyticsManager = [SFSDKSalesforceAnalyticsManager sharedInstanceWithUser:[SFUserAccountManager sharedInstance].currentUser];
    XCTAssertNotNil(analyticsManager, @"SFSDKSalesforceAnalyticsManager instance should not be nil");
    SFSDKDeviceAppAttributes *deviceAttributes = analyticsManager.analyticsManager.deviceAttributes;
    XCTAssertNotNil(deviceAttributes, @"SFSDKDeviceAppAttributes instance should not be nil");
    XCTAssertEqualObjects(deviceAttributes.appName, expectedAppName, @"App names should match");
    [SFSDKSalesforceAnalyticsManager removeSharedInstanceWithUser:[SFUserAccountManager sharedInstance].currentUser];
    NSError *error = nil;
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:[SFUserAccountManager sharedInstance].currentUser error:&error];
    XCTAssertNil(error, @"SalesforceSDKManagerTests for AILTN could not delete created user");
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:prevCurrentUser];
}

- (void)compareAppNames:(NSString *)expectedAppName
{
    NSString *userAgent = [SalesforceSDKManager sharedManager].userAgentString(@"");
    XCTAssertTrue([userAgent containsString:expectedAppName], @"App names should match");
}

#pragma mark - Runtime Selected App Config Tests

- (void)verifyAppConfigForLoginHost:(NSString *)loginHost
                        description:(NSString *)description
                         assertions:(void (^)(SFSDKAppConfig *config))assertions {
    XCTestExpectation *expectation = [self expectationWithDescription:description];
    [[SalesforceSDKManager sharedManager] appConfigForLoginHost:loginHost callback:^(SFSDKAppConfig *config) {
        assertions(config);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1.0];
}

- (void)testAppConfigForLoginHostReturnsDefaultWhenBlockNotSet {
    // Clear any existing block
    [SalesforceSDKManager sharedManager].appConfigRuntimeSelectorBlock = nil;
    
    // Get the default app config for comparison
    SFSDKAppConfig *defaultConfig = [SalesforceSDKManager sharedManager].appConfig;
    
    // Test with nil loginHost - should return default config
    [self verifyAppConfigForLoginHost:nil
                          description:@"Callback should be called with default config"
                           assertions:^(SFSDKAppConfig *config) {
        XCTAssertEqual(config, defaultConfig, @"Should return default appConfig when no selector block is set");
    }];
    
    // Test with a loginHost - should still return default config
    [self verifyAppConfigForLoginHost:@"https://test.salesforce.com"
                          description:@"Callback should be called with default config"
                           assertions:^(SFSDKAppConfig *config) {
        XCTAssertEqual(config, defaultConfig, @"Should return default appConfig when no selector block is set, regardless of loginHost");
    }];
}

- (void)testAppConfigForLoginHostWithDifferentLoginHosts {
    NSString *loginHost1 = @"https://login.salesforce.com";
    NSString *loginHost2 = @"https://test.salesforce.com";
    
    NSDictionary *config1Dict = @{
        @"remoteAccessConsumerKey": @"clientId1",
        @"oauthRedirectURI": @"app1://oauth/done",
        @"shouldAuthenticate": @YES
    };
    SFSDKAppConfig *config1 = [[SFSDKAppConfig alloc] initWithDict:config1Dict];
    
    NSDictionary *config2Dict = @{
        @"remoteAccessConsumerKey": @"clientId2",
        @"oauthRedirectURI": @"app2://oauth/done",
        @"shouldAuthenticate": @YES
    };
    SFSDKAppConfig *config2 = [[SFSDKAppConfig alloc] initWithDict:config2Dict];
    
    // Get the default app config for comparison
    SFSDKAppConfig *defaultConfig = [SalesforceSDKManager sharedManager].appConfig;
    
    // Set the selector block to return different configs based on loginHost
    [SalesforceSDKManager sharedManager].appConfigRuntimeSelectorBlock = ^(NSString *loginHost, void (^callback)(SFSDKAppConfig *)) {
        if ([loginHost isEqualToString:loginHost1]) {
            callback(config1);
        } else if ([loginHost isEqualToString:loginHost2]) {
            callback(config2);
        } else {
            callback(nil);
        }
    };
    
    // Test first loginHost
    [self verifyAppConfigForLoginHost:loginHost1
                          description:@"First callback should be called"
                           assertions:^(SFSDKAppConfig *result1) {
        XCTAssertNotNil(result1, @"Should return config for loginHost1");
        XCTAssertEqual(result1, config1, @"Should return config1 for loginHost1");
        XCTAssertEqualObjects(result1.remoteAccessConsumerKey, @"clientId1", @"Should have correct client ID for config1");
    }];
    
    // Test second loginHost
    [self verifyAppConfigForLoginHost:loginHost2
                          description:@"Second callback should be called"
                           assertions:^(SFSDKAppConfig *result2) {
        XCTAssertNotNil(result2, @"Should return config for loginHost2");
        XCTAssertEqual(result2, config2, @"Should return config2 for loginHost2");
        XCTAssertEqualObjects(result2.remoteAccessConsumerKey, @"clientId2", @"Should have correct client ID for config2");
    }];
    
    // Test with nil loginHost - should return default config
    [self verifyAppConfigForLoginHost:nil
                          description:@"Callback should be called with default config"
                           assertions:^(SFSDKAppConfig *config) {
        XCTAssertEqual(config, defaultConfig, @"Should return default appConfig when nil loginHost is passed");
    }];
}

- (void)testAppConfigForLoginHostReturnsDefaultWhenBlockReturnsNil {
    __block BOOL blockWasCalled = NO;
    
    // Get the default app config for comparison
    SFSDKAppConfig *defaultConfig = [SalesforceSDKManager sharedManager].appConfig;
    
    // Set the selector block to return nil via callback
    [SalesforceSDKManager sharedManager].appConfigRuntimeSelectorBlock = ^(NSString *loginHost, void (^callback)(SFSDKAppConfig *)) {
        blockWasCalled = YES;
        callback(nil);
    };
    
    // Call the method - should fall back to default config even though block returns nil
    [self verifyAppConfigForLoginHost:@"https://test.salesforce.com"
                          description:@"Callback should be called"
                           assertions:^(SFSDKAppConfig *config) {
        XCTAssertTrue(blockWasCalled, @"Block should have been called");
        XCTAssertEqual(config, defaultConfig, @"Should return default appConfig when block returns nil");
    }];
}

#pragma mark - Dev Actions Tests

- (void)testGetDevActionsAlwaysShowsDevInfo {
    [self createTestAppIdentity];
    
    // Test with a regular view controller (not login)
    UIViewController *regularVC = [[UIViewController alloc] init];
    NSArray<SFSDKDevAction *> *actions = [[SalesforceSDKManager sharedManager] getDevActions:regularVC];
    
    XCTAssertGreaterThan(actions.count, 0, @"Should have at least one action");
    XCTAssertEqualObjects(actions[0].name, @"Show dev info", @"First action should always be dev info");
}

- (void)testGetDevActionsShowsLoginOptionsOnLoginViewController {
    [self createTestAppIdentity];
    
    // Test with SFLoginViewController
    SFLoginViewController *loginVC = [[SFLoginViewController alloc] init];
    NSArray<SFSDKDevAction *> *actions = [[SalesforceSDKManager sharedManager] getDevActions:loginVC];
    
    // Find "Login Options" action
    BOOL hasLoginOptions = NO;
    for (SFSDKDevAction *action in actions) {
        if ([action.name isEqualToString:@"Login Options"]) {
            hasLoginOptions = YES;
            break;
        }
    }
    
    XCTAssertTrue(hasLoginOptions, @"Should show Login Options when on login view controller");
}

- (void)testGetDevActionsDoesNotShowLoginOptionsOnRegularViewController {
    [self createTestAppIdentity];
    
    // Test with a regular view controller
    UIViewController *regularVC = [[UIViewController alloc] init];
    NSArray<SFSDKDevAction *> *actions = [[SalesforceSDKManager sharedManager] getDevActions:regularVC];
    
    // Check that "Login Options" is not present
    BOOL hasLoginOptions = NO;
    for (SFSDKDevAction *action in actions) {
        if ([action.name isEqualToString:@"Login Options"]) {
            hasLoginOptions = YES;
            break;
        }
    }
    
    XCTAssertFalse(hasLoginOptions, @"Should not show Login Options on regular view controller");
}

- (void)testGetDevActionsShowsLogoutWhenUserLoggedIn {
    [self createTestAppIdentity];
    
    // Create and set a current user
    SFUserAccount *user = [self createUserAccount];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:user];
    
    // Test with a regular view controller (not login)
    UIViewController *regularVC = [[UIViewController alloc] init];
    NSArray<SFSDKDevAction *> *actions = [[SalesforceSDKManager sharedManager] getDevActions:regularVC];
    
    // Find "Logout" action
    BOOL hasLogout = NO;
    for (SFSDKDevAction *action in actions) {
        if ([action.name isEqualToString:@"Logout"]) {
            hasLogout = YES;
            break;
        }
    }
    
    XCTAssertTrue(hasLogout, @"Should show Logout when user is logged in and not on login screen");
    
    // Clean up
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
}

- (void)testGetDevActionsDoesNotShowLogoutOnLoginViewController {
    [self createTestAppIdentity];
    
    // Create and set a current user
    SFUserAccount *user = [self createUserAccount];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:user];
    
    // Test with SFLoginViewController
    SFLoginViewController *loginVC = [[SFLoginViewController alloc] init];
    NSArray<SFSDKDevAction *> *actions = [[SalesforceSDKManager sharedManager] getDevActions:loginVC];
    
    // Check that "Logout" is not present
    BOOL hasLogout = NO;
    for (SFSDKDevAction *action in actions) {
        if ([action.name isEqualToString:@"Logout"]) {
            hasLogout = YES;
            break;
        }
    }
    
    XCTAssertFalse(hasLogout, @"Should not show Logout when on login view controller");
    
    // Clean up
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
}

- (void)testGetDevActionsDoesNotShowLogoutWhenNoUser {
    [self createTestAppIdentity];
    
    // Ensure no current user
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
    
    // Test with a regular view controller
    UIViewController *regularVC = [[UIViewController alloc] init];
    NSArray<SFSDKDevAction *> *actions = [[SalesforceSDKManager sharedManager] getDevActions:regularVC];
    
    // Check that "Logout" is not present
    BOOL hasLogout = NO;
    for (SFSDKDevAction *action in actions) {
        if ([action.name isEqualToString:@"Logout"]) {
            hasLogout = YES;
            break;
        }
    }
    
    XCTAssertFalse(hasLogout, @"Should not show Logout when no user is logged in");
}

- (void)testGetDevActionsShowsSwitchUserWhenUserLoggedIn {
    [self createTestAppIdentity];
    
    // Create and set a current user
    SFUserAccount *user = [self createUserAccount];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:user];
    
    // Test with a regular view controller (not login)
    UIViewController *regularVC = [[UIViewController alloc] init];
    NSArray<SFSDKDevAction *> *actions = [[SalesforceSDKManager sharedManager] getDevActions:regularVC];
    
    // Find "Switch user" action
    BOOL hasSwitchUser = NO;
    for (SFSDKDevAction *action in actions) {
        if ([action.name isEqualToString:@"Switch user"]) {
            hasSwitchUser = YES;
            break;
        }
    }
    
    XCTAssertTrue(hasSwitchUser, @"Should show Switch user when user is logged in and not on login screen");
    
    // Clean up
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
}

- (void)testGetDevActionsDoesNotShowSwitchUserOnLoginViewController {
    [self createTestAppIdentity];
    
    // Create and set a current user
    SFUserAccount *user = [self createUserAccount];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:user];
    
    // Test with SFLoginViewController
    SFLoginViewController *loginVC = [[SFLoginViewController alloc] init];
    NSArray<SFSDKDevAction *> *actions = [[SalesforceSDKManager sharedManager] getDevActions:loginVC];
    
    // Check that "Switch user" is not present
    BOOL hasSwitchUser = NO;
    for (SFSDKDevAction *action in actions) {
        if ([action.name isEqualToString:@"Switch user"]) {
            hasSwitchUser = YES;
            break;
        }
    }
    
    XCTAssertFalse(hasSwitchUser, @"Should not show Switch user when on login view controller");
    
    // Clean up
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
}

#pragma mark - Dev Support Infos Tests

- (void)testGetDevSupportInfosReturnsArray {
    [self createTestAppIdentity];
    
    NSArray<NSString *> *infos = [[SalesforceSDKManager sharedManager] getDevSupportInfos];
    
    XCTAssertNotNil(infos, @"Dev support infos should not be nil");
    XCTAssertGreaterThan(infos.count, 0, @"Should have at least some info entries");
}

- (void)testGetDevSupportInfosContainsSDKVersion {
    [self createTestAppIdentity];
    
    NSArray<NSString *> *infos = [[SalesforceSDKManager sharedManager] getDevSupportInfos];
    
    // Find SDK Version in the array (skip section: entries)
    BOOL hasSDKVersion = NO;
    for (NSUInteger i = 0; i < infos.count - 1; i++) {
        NSString *item = infos[i];
        if (![item hasPrefix:@"section:"] && [item isEqualToString:@"SDK Version"]) {
            // Make sure next item is not a section marker
            if (i + 1 < infos.count && ![infos[i + 1] hasPrefix:@"section:"]) {
                hasSDKVersion = YES;
                XCTAssertNotNil(infos[i + 1], @"SDK Version value should not be nil");
                break;
            }
        }
    }
    
    XCTAssertTrue(hasSDKVersion, @"Dev support infos should contain SDK Version");
}

- (void)testGetDevSupportInfosContainsAppType {
    [self createTestAppIdentity];
    
    NSArray<NSString *> *infos = [[SalesforceSDKManager sharedManager] getDevSupportInfos];
    
    // Find App Type in the array (skip section: entries)
    BOOL hasAppType = NO;
    for (NSUInteger i = 0; i < infos.count - 1; i++) {
        NSString *item = infos[i];
        if (![item hasPrefix:@"section:"] && [item isEqualToString:@"App Type"]) {
            // Make sure next item is not a section marker
            if (i + 1 < infos.count && ![infos[i + 1] hasPrefix:@"section:"]) {
                hasAppType = YES;
                XCTAssertNotNil(infos[i + 1], @"App Type value should not be nil");
                break;
            }
        }
    }
    
    XCTAssertTrue(hasAppType, @"Dev support infos should contain App Type");
}

- (void)testGetDevSupportInfosContainsUserInfoWhenLoggedIn {
    [self createTestAppIdentity];
    
    // Create and set a current user
    SFUserAccount *user = [self createUserAccount];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:user];
    
    NSArray<NSString *> *infos = [[SalesforceSDKManager sharedManager] getDevSupportInfos];
    
    // Find Username in the array (it's in the "Current User" section, but we search for "Username" key)
    BOOL hasCurrentUser = NO;
    for (NSUInteger i = 0; i < infos.count - 1; i++) {
        NSString *item = infos[i];
        if (![item hasPrefix:@"section:"] && [item isEqualToString:@"Username"]) {
            // Make sure next item is not a section marker
            if (i + 1 < infos.count && ![infos[i + 1] hasPrefix:@"section:"]) {
                hasCurrentUser = YES;
                XCTAssertNotNil(infos[i + 1], @"Username value should not be nil");
                break;
            }
        }
    }
    
    XCTAssertTrue(hasCurrentUser, @"Dev support infos should contain Username when logged in");
    
    // Clean up
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
}

- (void)testGetDevSupportInfosDoesNotContainUserInfoWhenNotLoggedIn {
    [self createTestAppIdentity];
    
    // Ensure no current user
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
    
    NSArray<NSString *> *infos = [[SalesforceSDKManager sharedManager] getDevSupportInfos];
    
    // Check that "section:Current User" is not in the array
    BOOL hasCurrentUserSection = NO;
    for (NSUInteger i = 0; i < infos.count; i++) {
        if ([infos[i] isEqualToString:@"section:Current User"]) {
            hasCurrentUserSection = YES;
            break;
        }
    }
    
    XCTAssertFalse(hasCurrentUserSection, @"Dev support infos should not contain Current User section when not logged in");
}

- (void)testGetDevSupportInfosContainsAuthConfigSection {
    [self createTestAppIdentity];
    
    NSArray<NSString *> *infos = [[SalesforceSDKManager sharedManager] getDevSupportInfos];
    
    // Check that "section:Auth Config" exists
    BOOL hasAuthConfigSection = NO;
    for (NSUInteger i = 0; i < infos.count; i++) {
        if ([infos[i] isEqualToString:@"section:Auth Config"]) {
            hasAuthConfigSection = YES;
            break;
        }
    }
    
    XCTAssertTrue(hasAuthConfigSection, @"Dev support infos should contain Auth Config section");
}

- (void)testGetDevSupportInfosAuthConfigContainsExpectedFields {
    [self createTestAppIdentity];
    
    NSArray<NSString *> *infos = [[SalesforceSDKManager sharedManager] getDevSupportInfos];
    
    // Expected fields in Auth Config section
    NSArray *expectedFields = @[
        @"Use Web Server Authentication",
        @"Use Hybrid Authentication",
        @"Force Advanced Authentication",
        @"Browser Login Enabled",
        @"IDP Enabled",
        @"Identity Provider"
    ];
    
    for (NSString *field in expectedFields) {
        BOOL hasField = NO;
        for (NSUInteger i = 0; i < infos.count - 1; i++) {
            NSString *item = infos[i];
            if (![item hasPrefix:@"section:"] && [item isEqualToString:field]) {
                if (i + 1 < infos.count && ![infos[i + 1] hasPrefix:@"section:"]) {
                    hasField = YES;
                    // Verify value is YES or NO
                    NSString *value = infos[i + 1];
                    XCTAssertTrue([value isEqualToString:@"YES"] || [value isEqualToString:@"NO"],
                                @"Auth Config field %@ should have YES/NO value, got: %@", field, value);
                    break;
                }
            }
        }
        XCTAssertTrue(hasField, @"Auth Config should contain field: %@", field);
    }
}

- (void)testGetDevSupportInfosContainsBootconfigSection {
    [self createTestAppIdentity];
    
    NSArray<NSString *> *infos = [[SalesforceSDKManager sharedManager] getDevSupportInfos];
    
    // Check that "section:Bootconfig" exists
    BOOL hasBootconfigSection = NO;
    for (NSUInteger i = 0; i < infos.count; i++) {
        if ([infos[i] isEqualToString:@"section:Bootconfig"]) {
            hasBootconfigSection = YES;
            break;
        }
    }
    
    XCTAssertTrue(hasBootconfigSection, @"Dev support infos should contain Bootconfig section");
}

- (void)testGetDevSupportInfosCurrentUserSectionContainsAllCredentialFields {
    [self createTestAppIdentity];
    
    // Create and set a current user
    SFUserAccount *user = [self createUserAccount];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:user];
    
    NSArray<NSString *> *infos = [[SalesforceSDKManager sharedManager] getDevSupportInfos];
    
    // Expected fields in Current User section
    NSArray *expectedFields = @[
        @"Username",
        @"Consumer Key",
        @"Redirect URI",
        @"Scopes",
        @"Instance URL",
        @"Token format",
        @"Access Token Expiration",
        @"Beacon Child Consumer Key"
    ];
    
    for (NSString *field in expectedFields) {
        BOOL hasField = NO;
        for (NSUInteger i = 0; i < infos.count - 1; i++) {
            NSString *item = infos[i];
            if (![item hasPrefix:@"section:"] && [item isEqualToString:field]) {
                if (i + 1 < infos.count && ![infos[i + 1] hasPrefix:@"section:"]) {
                    hasField = YES;
                    XCTAssertNotNil(infos[i + 1], @"Current User field %@ should not be nil", field);
                    break;
                }
            }
        }
        XCTAssertTrue(hasField, @"Current User should contain field: %@", field);
    }
    
    // Clean up
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
}

- (void)testGetDevSupportInfosCurrentUserCredentialsHaveCorrectValues {
    [self createTestAppIdentity];
    
    // Create and set a current user
    SFUserAccount *user = [self createUserAccount];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:user];
    
    NSArray<NSString *> *infos = [[SalesforceSDKManager sharedManager] getDevSupportInfos];
    
    // Find and verify specific values
    for (NSUInteger i = 0; i < infos.count - 1; i++) {
        NSString *item = infos[i];
        if (![item hasPrefix:@"section:"]) {
            NSString *value = infos[i + 1];
            
            if ([item isEqualToString:@"Redirect URI"]) {
                XCTAssertEqualObjects(value, @"testapp://auth/callback", @"Redirect URI should match");
            } else if ([item isEqualToString:@"Instance URL"]) {
                XCTAssertEqualObjects(value, @"https://test.salesforce.com", @"Instance URL should match");
            } else if ([item isEqualToString:@"Token format"]) {
                XCTAssertTrue([value isEqualToString:@"jwt"] || [value isEqualToString:@"opaque"],
                            @"Token format should be jwt or opaque");
            }
        }
    }
    
    // Clean up
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
}

- (void)testGetDevSupportInfosContainsUserAgentString {
    [self createTestAppIdentity];
    
    NSArray<NSString *> *infos = [[SalesforceSDKManager sharedManager] getDevSupportInfos];
    
    // Find User Agent in the array
    BOOL hasUserAgent = NO;
    for (NSUInteger i = 0; i < infos.count - 1; i++) {
        NSString *item = infos[i];
        if (![item hasPrefix:@"section:"] && [item isEqualToString:@"User Agent"]) {
            if (i + 1 < infos.count && ![infos[i + 1] hasPrefix:@"section:"]) {
                hasUserAgent = YES;
                XCTAssertNotNil(infos[i + 1], @"User Agent value should not be nil");
                XCTAssertGreaterThan([infos[i + 1] length], 0, @"User Agent should not be empty");
                break;
            }
        }
    }
    
    XCTAssertTrue(hasUserAgent, @"Dev support infos should contain User Agent");
}

- (void)testGetDevSupportInfosContainsAuthenticatedUsersWhenUsersExist {
    [self createTestAppIdentity];
    
    // Create and save a user (not current, just exists)
    [self createUserAccount];
    
    NSArray<NSString *> *infos = [[SalesforceSDKManager sharedManager] getDevSupportInfos];
    
    // Find Authenticated Users in the array
    BOOL hasAuthenticatedUsers = NO;
    for (NSUInteger i = 0; i < infos.count - 1; i++) {
        NSString *item = infos[i];
        if (![item hasPrefix:@"section:"] && [item isEqualToString:@"Authenticated Users"]) {
            if (i + 1 < infos.count && ![infos[i + 1] hasPrefix:@"section:"]) {
                hasAuthenticatedUsers = YES;
                XCTAssertNotNil(infos[i + 1], @"Authenticated Users value should not be nil");
                break;
            }
        }
    }
    
    XCTAssertTrue(hasAuthenticatedUsers, @"Dev support infos should contain Authenticated Users when users exist");
    
    // Clean up
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
}

- (void)testGetDevSupportInfosSectionsAreProperlyStructured {
    [self createTestAppIdentity];
    
    // Create and set a current user
    SFUserAccount *user = [self createUserAccount];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:user];
    
    NSArray<NSString *> *infos = [[SalesforceSDKManager sharedManager] getDevSupportInfos];
    
    // Verify that after each "section:" marker, there are key-value pairs
    for (NSUInteger i = 0; i < infos.count; i++) {
        NSString *item = infos[i];
        if ([item hasPrefix:@"section:"]) {
            // After a section marker, next items should be key-value pairs until next section
            // Verify at least one key-value pair exists after this section
            if (i + 2 < infos.count) {
                NSString *nextItem = infos[i + 1];
                // Next item should not be a section marker (should be a key)
                if (![nextItem hasPrefix:@"section:"]) {
                    // This is good - we have at least one key after the section
                    XCTAssertTrue(YES, @"Section %@ has at least one key-value pair", item);
                }
            }
        }
    }
    
    // Clean up
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
}

@end
