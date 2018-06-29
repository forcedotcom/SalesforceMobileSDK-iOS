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
#import "SFAuthenticationManager+Internal.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFUserAccountManager+Internal.h"
#import "SFSDKSalesforceAnalyticsManager.h"
#import "SFSDKAppConfig.h"
#import "SFUserAccount+Internal.h"

static NSTimeInterval const kTimeDelaySecsBetweenLaunchSteps = 0.5;
static NSString* const kTestAppName = @"OverridenAppName";

@interface SalesforceSDKManagerTests : XCTestCase
{
    NSString *_origConnectedAppId;
    NSString *_origConnectedAppCallbackUri;
    NSSet *_origAuthScopes;
    BOOL _origAuthenticateAtLaunch;
    BOOL _origHasVerifiedPasscodeAtStartup;
    SFSDKPostLaunchCallbackBlock _origPostLaunchAction;
    SFSDKLaunchErrorCallbackBlock _origLaunchErrorAction;
    SFSDKLogoutCallbackBlock _origPostLogoutAction;
    SFSDKSwitchUserCallbackBlock _origSwitchUserAction;
    SFSDKAppForegroundCallbackBlock _origPostAppForegroundAction;
    SFUserAccount *_origCurrentUser;
    id<SalesforceSDKManagerFlow> _origSdkManagerFlow;
    SFTestSDKManagerFlow *_currentSdkManagerFlow;
    BOOL _postLaunchBlockCalled;
    SFSDKLaunchAction _postLaunchActions;
    BOOL _launchErrorBlockCalled;
    NSError *_launchError;
    NSString *_origAppName;
    WKProcessPool *_origProcessPool;
    NSString *_origBrandLoginPath;
}

@end

@implementation SalesforceSDKManagerTests

- (void)setUp
{
    [super setUp];
    XCTAssertFalse([SalesforceSDKManager sharedManager].isLaunching, @"SalesforceSDKManager should not be launching at the beginning of the test.");

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

- (void)testValidateInput
{

    // Set nothing, validate errors.
    [self createStandardLaunchErrorBlock];
    [self launchAndVerify:YES failMessage:@"Failed to start launch."];
    [self verifyLaunchErrorState:YES];
    XCTAssertEqual([_launchError domain], kSalesforceSDKManagerErrorDomain, @"Wrong error domain.");
    XCTAssertEqual([_launchError code], kSalesforceSDKManagerErrorInvalidLaunchParameters, @"Wrong error code.");
    XCTAssertEqual([[_launchError userInfo][kSalesforceSDKManagerErrorDetailsKey] count], 1UL, @"There should have been one fatal validation error.");
    
    // Set Connected App ID
    [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = @"test_connected_app_id";
    [self launchAndVerify:YES failMessage:@"Failed to start launch."];
    [self verifyLaunchErrorState:YES];
    XCTAssertEqual([_launchError domain], kSalesforceSDKManagerErrorDomain, @"Wrong error domain.");
    XCTAssertEqual([_launchError code], kSalesforceSDKManagerErrorInvalidLaunchParameters, @"Wrong error code.");
    XCTAssertEqual([[_launchError userInfo][kSalesforceSDKManagerErrorDetailsKey] count], 1UL, @"There should have been one fatal validation error.");
    
    // Set Callback URI
    [SalesforceSDKManager sharedManager].appConfig.oauthRedirectURI = @"test_connected_app_callback_uri";
    [self launchAndVerify:YES failMessage:@"Failed to start launch."];
    [self verifyLaunchErrorState:YES];
    XCTAssertEqual([_launchError domain], kSalesforceSDKManagerErrorDomain, @"Wrong error domain.");
    XCTAssertEqual([_launchError code], kSalesforceSDKManagerErrorInvalidLaunchParameters, @"Wrong error code.");
    XCTAssertEqual([[_launchError userInfo][kSalesforceSDKManagerErrorDetailsKey] count], 1UL, @"There should have been one fatal validation error.");
    
    // Set auth scopes
    [SalesforceSDKManager sharedManager].appConfig.oauthScopes = [NSSet setWithArray:@[ @"web", @"api" ]];
    [self launchAndVerify:YES failMessage:@"Failed to start launch."];
    [self verifyLaunchErrorState:NO];
}

- (void)testOneLaunchAtATime
{
    [self createStandardPostLaunchBlock];
    [self createTestAppIdentity];
    [self launchAndVerify:YES failMessage:@"Initial launch attempt should have been successful."];
    [self launchAndVerify:NO failMessage:@"Second concurrent launch should not be allowed."];
    [self verifyPostLaunchState];
}

- (void)testOverrideAiltnAppNameBeforeSDKManagerLaunch
{
    [SalesforceSDKManager setAiltnAppName:kTestAppName];
    [self createStandardPostLaunchBlock];
    [self createTestAppIdentity];
    [self launchAndVerify:YES failMessage:@"Launch attempt should have been successful."];
    [self verifyPostLaunchState];
    [self compareAiltnAppNames:kTestAppName];
}

- (void)testOverrideAiltnAppNameAfterSDKManagerInit
{
    [self createStandardPostLaunchBlock];
    [self createTestAppIdentity];
    [self launchAndVerify:YES failMessage:@"Launch attempt should have been successful."];
    [self verifyPostLaunchState];
    [SalesforceSDKManager setAiltnAppName:kTestAppName];
    [self compareAiltnAppNames:kTestAppName];
}

- (void)testDefaultAiltnAppName
{
    [self createStandardPostLaunchBlock];
    [self createTestAppIdentity];
    [self launchAndVerify:YES failMessage:@"Launch attempt should have been successful."];
    [self verifyPostLaunchState];
    NSString *appName = [[NSBundle mainBundle] infoDictionary][(NSString *) kCFBundleNameKey];
    [self compareAiltnAppNames:appName];
}

- (void)testOverrideInvalidAiltnAppName
{
    [SFUserAccountManager sharedInstance].currentUser = [self createUserAccount];
    [self createStandardPostLaunchBlock];
    [self createTestAppIdentity];
    [self launchAndVerify:YES failMessage:@"Launch attempt should have been successful."];
    [self verifyPostLaunchState];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [SalesforceSDKManager setAiltnAppName:nil];
#pragma clang diagnostic pop
    NSString *appName = [[NSBundle mainBundle] infoDictionary][(NSString *) kCFBundleNameKey];
    [self compareAiltnAppNames:appName];
}

- (void)testPasscodeVerificationAtLaunch
{
    [self createStandardPostLaunchBlock];
    [self createTestAppIdentity];
    [self launchAndVerify:YES failMessage:@"Launch attempt should have been successful."];
    [self verifyPostLaunchState];
    BOOL passcodeVerifiedOnInitialLaunch = ((_postLaunchActions & SFSDKLaunchActionPasscodeVerified) == SFSDKLaunchActionPasscodeVerified);
    XCTAssertTrue(passcodeVerifiedOnInitialLaunch, @"Passcode should have been verified on initial launch. Actual state: %@", [SalesforceSDKManager launchActionsStringRepresentation:_postLaunchActions]);
    [self launchAndVerify:YES failMessage:@"Launch attempt should have been successful."];
    [self verifyPostLaunchState];
    passcodeVerifiedOnInitialLaunch = ((_postLaunchActions & SFSDKLaunchActionPasscodeVerified) == SFSDKLaunchActionPasscodeVerified);
    XCTAssertFalse(passcodeVerifiedOnInitialLaunch, @"Passcode should NOT have been verified on subsequent launches.");
}

- (void)testAuthAtLaunch
{
    XCTAssertNil([SFUserAccountManager sharedInstance].currentUser, @"Current user should be nil.");
    [self createStandardPostLaunchBlock];
    [self createTestAppIdentity];
    [SFUserAccountManager sharedInstance].currentUser = [self createUserAccount];
    [self launchAndVerify:YES failMessage:@"Launch attempt should have been successful."];
    [self verifyPostLaunchState];
    BOOL userAuthenticatedAtLaunch = ((_postLaunchActions & SFSDKLaunchActionAuthenticated) == SFSDKLaunchActionAuthenticated);
    BOOL userAlreadyAuthenticated = ((_postLaunchActions & SFSDKLaunchActionAlreadyAuthenticated) == SFSDKLaunchActionAlreadyAuthenticated);
    BOOL authBypassed = ((_postLaunchActions & SFSDKLaunchActionAuthBypassed) == SFSDKLaunchActionAuthBypassed);
    XCTAssertTrue(userAuthenticatedAtLaunch, @"User without credentials should have been authenticated at launch.");
    XCTAssertFalse(userAlreadyAuthenticated, @"User without credentials should not have generated an already-authenticated status.");
    XCTAssertFalse(authBypassed, @"User without credentials should not have generated an auth-bypassed status.");
    [SFUserAccountManager sharedInstance].currentUser.credentials.accessToken = @"test_access_token";
    [self launchAndVerify:YES failMessage:@"Launch attempt should have been successful."];
    [self verifyPostLaunchState];
    userAuthenticatedAtLaunch = ((_postLaunchActions & SFSDKLaunchActionAuthenticated) == SFSDKLaunchActionAuthenticated);
    userAlreadyAuthenticated = ((_postLaunchActions & SFSDKLaunchActionAlreadyAuthenticated) == SFSDKLaunchActionAlreadyAuthenticated);
    authBypassed = ((_postLaunchActions & SFSDKLaunchActionAuthBypassed) == SFSDKLaunchActionAuthBypassed);
    XCTAssertFalse(userAuthenticatedAtLaunch, @"User with credentials should not have been authenticated at launch.");
    XCTAssertTrue(userAlreadyAuthenticated, @"User with credentials should have generated an already-authenticated status.");
    XCTAssertFalse(authBypassed, @"User with credentials should not have generated an auth-bypassed status.");
    NSError *error = nil;
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:[SFUserAccountManager sharedInstance].currentUser error:&error];
    XCTAssertNil(error, @"SalesforceSDKManagerTests for testAuthAtLaunch could not delete created user");
}

- (void)testAuthBypass
{
    XCTAssertNil([SFUserAccountManager sharedInstance].currentUser, @"Current user should be nil.");
    [SalesforceSDKManager sharedManager].appConfig.shouldAuthenticate = NO;
    [self createStandardPostLaunchBlock];
    [self createTestAppIdentity];
    [SFUserAccountManager sharedInstance].currentUser = [self createUserAccount];
    [self launchAndVerify:YES failMessage:@"Launch attempt should have been successful."];
    [self verifyPostLaunchState];
    BOOL userAuthenticatedAtLaunch = ((_postLaunchActions & SFSDKLaunchActionAuthenticated) == SFSDKLaunchActionAuthenticated);
    BOOL userAlreadyAuthenticated = ((_postLaunchActions & SFSDKLaunchActionAlreadyAuthenticated) == SFSDKLaunchActionAlreadyAuthenticated);
    BOOL authBypassed = ((_postLaunchActions & SFSDKLaunchActionAuthBypassed) == SFSDKLaunchActionAuthBypassed);
    XCTAssertFalse(userAuthenticatedAtLaunch, @"User should not generate an authenticated status at launch when bypass is configured.");
    XCTAssertFalse(userAlreadyAuthenticated, @"User should not generate an already-authenticated status when bypass is configured.");
    XCTAssertTrue(authBypassed, @"Launch should have generated an auth-bypassed status.");
    [SFUserAccountManager sharedInstance].currentUser.credentials.accessToken = @"test_access_token";
    userAuthenticatedAtLaunch = ((_postLaunchActions & SFSDKLaunchActionAuthenticated) == SFSDKLaunchActionAuthenticated);
    userAlreadyAuthenticated = ((_postLaunchActions & SFSDKLaunchActionAlreadyAuthenticated) == SFSDKLaunchActionAlreadyAuthenticated);
    authBypassed = ((_postLaunchActions & SFSDKLaunchActionAuthBypassed) == SFSDKLaunchActionAuthBypassed);
    XCTAssertFalse(userAuthenticatedAtLaunch, @"User should not generate an authenticated status at launch when bypass is configured.");
    XCTAssertFalse(userAlreadyAuthenticated, @"User should not generate an already-authenticated status when bypass is configured.");
    XCTAssertTrue(authBypassed, @"Launch should have generated an auth-bypassed status.");
}

- (void)testUserSwitching
{
    [SalesforceSDKManager sharedManager].appConfig.shouldAuthenticate = NO;
    [self createStandardPostLaunchBlock];
    [self createTestAppIdentity];
    XCTAssertNil([SFUserAccountManager sharedInstance].currentUser, @"Current user should be nil.");
    [SFUserAccountManager sharedInstance].currentUser = [self createUserAccount];
    XCTAssertNotNil([SFUserAccountManager sharedInstance].currentUser, @"Current user should not be nil.");
    SFUserAccount *userTo = [self createUserAccount];
    SFUserAccount *userFrom = [SFUserAccountManager sharedInstance].currentUser;
    XCTestExpectation *willSwitchExpectation = [self expectationWithDescription:@"willSwitch"];
    XCTestExpectation *didSwitchExpectation = [self expectationWithDescription:@"didSwitch"];
    __weak typeof (self) weakSelf = self;
    [_currentSdkManagerFlow setUpUserSwitchState:[SFUserAccountManager sharedInstance].currentUser toUser:userTo completion:^(SFUserAccount *fromUser, SFUserAccount *toUser,BOOL before) {
        __strong typeof (weakSelf) self = weakSelf;
        NSString *beforeAfterString = before?@" in willSwitchuser " :@" in didSwitchuser ";
        XCTAssertTrue([fromUser isEqual:userFrom],@"Switch from user is different than expected  %@",beforeAfterString);
        XCTAssertTrue([toUser isEqual:userTo],@"Switch to user is different than expected  %@",beforeAfterString);
        if( before ) {
            [willSwitchExpectation fulfill];
        }else {
            XCTAssertTrue([toUser isEqual:[SFUserAccountManager sharedInstance].currentUser],@"Switch to user  should change current user");
            [didSwitchExpectation fulfill];
        }
    }];
    [[SFUserAccountManager sharedInstance] switchToUser:userTo];
    [self waitForExpectations:@[willSwitchExpectation, didSwitchExpectation] timeout:20];
    [_currentSdkManagerFlow clearUserSwitchState];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    XCTAssertTrue(creationViewControllerCalled, @"Did not call the snapshot view controller creation block upon application resigning active, when use snapshot is set to YES.");
}

- (void)testDoNotUseSnapshot
{
    __block BOOL creationViewControllerCalled = NO;
    [SalesforceSDKManager sharedManager].useSnapshotView = NO;
    [SalesforceSDKManager sharedManager].snapshotViewControllerCreationAction = ^UIViewController*() {
        creationViewControllerCalled = YES;
        return nil;
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    XCTAssertFalse(creationViewControllerCalled, @"Did call the snapshot view controller creation block upon application resigning active, when use snapshot is set to NO.");
}

- (void)testSnapshotRespondsToStateEvents
{
    __block BOOL presentOnResignActive = NO;
    __block BOOL dismissOnDidBecomeActive = NO;
    UIView* fakeView = [UIView new];
    [SalesforceSDKManager sharedManager].useSnapshotView = YES;
    [SalesforceSDKManager sharedManager].snapshotPresentationAction = ^(UIViewController* snapshotViewController) {
        presentOnResignActive = YES;

        // This will simulate that the snapshot view is being presented
        [fakeView addSubview:snapshotViewController.view];
    };
    [SalesforceSDKManager sharedManager].snapshotDismissalAction = ^(UIViewController* snapshotViewController) {
        dismissOnDidBecomeActive = YES;
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    XCTAssertTrue(presentOnResignActive, @"Did not respond to app resign active.");
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    XCTAssertFalse(presentationBlockCalled || dismissalBlockCalled, @"Called a presentation/dismissal block without both blocks being set.");

    // Test inverse
    [SalesforceSDKManager sharedManager].snapshotPresentationAction = NULL;
    [SalesforceSDKManager sharedManager].snapshotDismissalAction = ^(UIViewController* snapshotViewController) {
        dismissalBlockCalled = YES;
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification object:nil];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    XCTAssertTrue([defaultViewControllerOnPresentation isKindOfClass:UIViewController.class], @"Did not provide a valid default snapshot view controller.");

    // This will simulate that the snapshot view is being presented
    UIView* fakeView = [UIView new];
    [fakeView addSubview:defaultViewControllerOnPresentation.view];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification object:nil];
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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    XCTAssertEqual(customSnapshot, snapshotOnPresentation, @"Custom snapshot view controller was not used on presentation!");

    // This will simulate that the snapshot view is being presented
    UIView* fakeView = [UIView new];
    [fakeView addSubview:customSnapshot.view];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    XCTAssertEqual(customSnapshot, snapshotOnDismissal, @"Custom snapshot view controller was not used on dismissal!");
}

#pragma mark - Process Pool Tests

- (void)testDefaultProcessPoolIsNotNil
{
    XCTAssertNotNil(SFSDKWebViewStateManager.sharedProcessPool);
}

- (void)testProcessPoolCannotBeNil
{
    XCTAssertNotNil(SFSDKWebViewStateManager.sharedProcessPool);
    SFSDKWebViewStateManager.sharedProcessPool = nil;
    XCTAssertNotNil(SFSDKWebViewStateManager.sharedProcessPool);
}

- (void)testProcessPoolIsAssignable
{
    WKProcessPool *newPool = [[WKProcessPool alloc] init];
    SFSDKWebViewStateManager.sharedProcessPool = newPool;
    XCTAssertEqualObjects(newPool, SFSDKWebViewStateManager.sharedProcessPool);
}

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
SFSDK_USE_DEPRECATED_BEGIN
- (void)testBrandedLoginPathInAuthManagerAndAuthorizeEndpoint
{
    NSString *brandPath = @"/BRAND/SUB-BRAND/";
    [SalesforceSDKManager sharedManager].brandLoginPath = brandPath;
    
    [self createTestAppIdentity];
    
    SFOAuthCredentials *credentials = [[SFAuthenticationManager sharedManager] createOAuthCredentials];
    [[SFAuthenticationManager sharedManager] setupWithCredentials:credentials];
    
    NSString *brandedURL = [[SFAuthenticationManager sharedManager].coordinator generateApprovalUrlString];
    
    XCTAssertNotNil(brandedURL);
    
    XCTAssertTrue([brandPath isEqualToString:[SFAuthenticationManager sharedManager].brandLoginPath]);
    
    //Should not have a trailing slash
    XCTAssertFalse([brandedURL containsString:[brandPath substringToIndex:brandPath.length]]);
    //should have brand
    XCTAssertTrue([brandedURL containsString:[brandPath substringToIndex:brandPath.length-1]]);
}
SFSDK_USE_DEPRECATED_END
#pragma mark - Private helpers

- (void)createStandardPostLaunchBlock
{
    [SalesforceSDKManager sharedManager].postLaunchAction = ^(SFSDKLaunchAction launchActions) {
        self->_postLaunchBlockCalled = YES;
        self->_postLaunchActions = launchActions;
    };
}

- (void)createStandardLaunchErrorBlock
{
    [SalesforceSDKManager sharedManager].launchErrorAction = ^(NSError *error, SFSDKLaunchAction launchAction) {
        self->_launchError = error;
        self->_launchErrorBlockCalled = YES;
    };
}

- (void)launchAndVerify:(BOOL)launchShouldSucceed failMessage:(NSString *)failMessage
{
    _postLaunchActions = SFSDKLaunchActionNone;
    _postLaunchBlockCalled = NO;
    _launchErrorBlockCalled = NO;
    _launchError = nil;
    BOOL didLaunch = [[SalesforceSDKManager sharedManager] launch];
    XCTAssertEqual(didLaunch, launchShouldSucceed, @"%@", failMessage);
}

- (void)verifyPostLaunchState
{
    BOOL launchCompleted = [_currentSdkManagerFlow waitForLaunchCompletion];
    XCTAssertTrue(launchCompleted, @"Launch failed to complete.");
    XCTAssertTrue(_postLaunchBlockCalled, @"Launch should have gone to post-launch.");
}

- (void)verifyLaunchErrorState:(BOOL)shouldReachErrorState
{
    BOOL launchCompleted = [_currentSdkManagerFlow waitForLaunchCompletion];
    XCTAssertTrue(launchCompleted, @"Launch failed to complete.");
    XCTAssertTrue(_launchErrorBlockCalled == shouldReachErrorState, @"Invalid launch error state.");
    XCTAssertEqual(_launchError != nil, shouldReachErrorState, @"Launch error not consistent with expected launch error state.");
}

- (void)createTestAppIdentity
{
    [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = @"test_connected_app_id";
    [SalesforceSDKManager sharedManager].appConfig.oauthRedirectURI = @"test_connected_app_callback_uri";
    [SalesforceSDKManager sharedManager].appConfig.oauthScopes = [NSSet setWithArray:@[ @"web", @"api" ]];
}

- (SFUserAccount *)createUserAccount
{
    u_int32_t userIdentifier = arc4random();
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:[NSString stringWithFormat:@"identifier-%u", userIdentifier]  clientId:SFUserAccountManager .sharedInstance.oauthClientId encrypted:YES];
    SFUserAccount *user =[[SFUserAccount alloc] initWithCredentials:credentials];
    NSString *userId = [NSString stringWithFormat:@"user_%u", userIdentifier];
    NSString *orgId = [NSString stringWithFormat:@"org_%u", userIdentifier];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://login.salesforce.com/id/%@/%@", orgId, userId]];
    [user transitionToLoginState:SFUserAccountLoginStateLoggedIn];
    NSError *error = nil;
    [[SFUserAccountManager sharedInstance] saveAccountForUser:user error:&error];
    XCTAssertNil(error, @"Should be able to create user account");
    return user;
}

- (void)setupSdkManagerState
{
    _currentSdkManagerFlow = [[SFTestSDKManagerFlow alloc] initWithStepTimeDelaySecs:kTimeDelaySecsBetweenLaunchSteps];
    _origSdkManagerFlow = [SalesforceSDKManager sharedManager].sdkManagerFlow; [SalesforceSDKManager sharedManager].sdkManagerFlow = _currentSdkManagerFlow;
    _origConnectedAppId = [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey; [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = @"";
    _origConnectedAppCallbackUri = [SalesforceSDKManager sharedManager].appConfig.oauthRedirectURI; [SalesforceSDKManager sharedManager].appConfig.oauthRedirectURI = @"";
    _origAuthScopes = [SalesforceSDKManager sharedManager].appConfig.oauthScopes; [SalesforceSDKManager sharedManager].appConfig.oauthScopes = [NSSet set];
    _origAuthenticateAtLaunch = [SalesforceSDKManager sharedManager].appConfig.shouldAuthenticate; [SalesforceSDKManager sharedManager].appConfig.shouldAuthenticate = YES;
    _origHasVerifiedPasscodeAtStartup = [SalesforceSDKManager sharedManager].hasVerifiedPasscodeAtStartup; [SalesforceSDKManager sharedManager].hasVerifiedPasscodeAtStartup = NO;
    _origPostLaunchAction = [SalesforceSDKManager sharedManager].postLaunchAction; [SalesforceSDKManager sharedManager].postLaunchAction = NULL;
    _origLaunchErrorAction = [SalesforceSDKManager sharedManager].launchErrorAction; [SalesforceSDKManager sharedManager].launchErrorAction = NULL;
    _origPostLogoutAction = [SalesforceSDKManager sharedManager].postLogoutAction; [SalesforceSDKManager sharedManager].postLogoutAction = NULL;
    _origSwitchUserAction = [SalesforceSDKManager sharedManager].switchUserAction; [SalesforceSDKManager sharedManager].switchUserAction = NULL;
    _origPostAppForegroundAction = [SalesforceSDKManager sharedManager].postAppForegroundAction; [SalesforceSDKManager sharedManager].postAppForegroundAction = NULL;
    _origCurrentUser = [SFUserAccountManager sharedInstance].currentUser; [SFUserAccountManager sharedInstance].currentUser = nil;
    _postLaunchBlockCalled = NO;
    _postLaunchActions = SFSDKLaunchActionNone;
    _launchErrorBlockCalled = NO;
    _launchError = nil;
    _origAppName = SalesforceSDKManager.ailtnAppName;
    _origProcessPool = SFSDKWebViewStateManager.sharedProcessPool;
    _origBrandLoginPath = [SalesforceSDKManager sharedManager].brandLoginPath;
}

- (void)restoreOrigSdkManagerState
{
    [SalesforceSDKManager sharedManager].sdkManagerFlow = _origSdkManagerFlow;
    [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = _origConnectedAppId;
    [SalesforceSDKManager sharedManager].appConfig.oauthRedirectURI = _origConnectedAppCallbackUri;
    [SalesforceSDKManager sharedManager].appConfig.oauthScopes = _origAuthScopes;
    [SalesforceSDKManager sharedManager].appConfig.shouldAuthenticate = _origAuthenticateAtLaunch;
    [SalesforceSDKManager sharedManager].hasVerifiedPasscodeAtStartup = _origHasVerifiedPasscodeAtStartup;
    [SalesforceSDKManager sharedManager].postLaunchAction = _origPostLaunchAction;
    [SalesforceSDKManager sharedManager].launchErrorAction = _origLaunchErrorAction;
    [SalesforceSDKManager sharedManager].postLogoutAction = _origPostLogoutAction;
    [SalesforceSDKManager sharedManager].switchUserAction = _origSwitchUserAction;
    [SalesforceSDKManager sharedManager].postAppForegroundAction = _origPostAppForegroundAction;
    [SFUserAccountManager sharedInstance].currentUser = _origCurrentUser;
    SalesforceSDKManager.ailtnAppName = _origAppName;
    SFSDKWebViewStateManager.sharedProcessPool = _origProcessPool;
    [SalesforceSDKManager sharedManager].brandLoginPath = _origBrandLoginPath;
}

- (void)compareAiltnAppNames:(NSString *)expectedAppName
{
    SFUserAccount *prevCurrentUser = [SFUserAccountManager sharedInstance].currentUser;
    [SFUserAccountManager sharedInstance].currentUser = [self createUserAccount];
    SFSDKSalesforceAnalyticsManager *analyticsManager = [SFSDKSalesforceAnalyticsManager sharedInstanceWithUser:[SFUserAccountManager sharedInstance].currentUser];
    XCTAssertNotNil(analyticsManager, @"SFSDKSalesforceAnalyticsManager instance should not be nil");
    SFSDKDeviceAppAttributes *deviceAttributes = analyticsManager.analyticsManager.deviceAttributes;
    XCTAssertNotNil(deviceAttributes, @"SFSDKDeviceAppAttributes instance should not be nil");
    XCTAssertEqualObjects(deviceAttributes.appName, expectedAppName, @"App names should match");
    [SFSDKSalesforceAnalyticsManager removeSharedInstanceWithUser:[SFUserAccountManager sharedInstance].currentUser];
     NSError *error = nil;
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:[SFUserAccountManager sharedInstance].currentUser error:&error];
    XCTAssertNil(error, @"SalesforceSDKManagerTests for ailtn could not delete created user");
    [SFUserAccountManager sharedInstance].currentUser = prevCurrentUser;
}

@end
