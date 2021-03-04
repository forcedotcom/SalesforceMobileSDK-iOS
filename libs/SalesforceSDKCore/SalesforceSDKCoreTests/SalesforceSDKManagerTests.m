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

static NSString* const kTestAppName = @"OverridenAppName";

@interface SalesforceSDKManagerTests : XCTestCase
{
    NSString *_origConnectedAppId;
    NSString *_origConnectedAppCallbackUri;
    NSSet *_origAuthScopes;
    BOOL _origAuthenticateAtLaunch;
    BOOL _origHasVerifiedPasscodeAtStartup;
    SFUserAccount *_origCurrentUser;
    id<SalesforceSDKManagerFlow> _origSdkManagerFlow;
    SFTestSDKManagerFlow *_currentSdkManagerFlow;
    NSString *_origAppName;
    WKProcessPool *_origProcessPool;
    NSString *_origBrandLoginPath;
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
    XCTestExpectation *willSwitchExpectation = [self expectationWithDescription:@"willSwitch"];
    XCTestExpectation *didSwitchExpectation = [self expectationWithDescription:@"didSwitch"];
    [_currentSdkManagerFlow setUpUserSwitchState:userAccountManager.currentUser toUser:userTo completion:^(SFUserAccount *fromUser, SFUserAccount *toUser, BOOL before) {
        NSString *beforeAfterString = before? @" in willSwitchuser " : @" in didSwitchuser ";
        XCTAssertTrue([fromUser isEqual:userFrom], @"Switch from user is different than expected  %@", beforeAfterString);
        XCTAssertTrue([toUser isEqual:userTo], @"Switch to user is different than expected  %@", beforeAfterString);
        if (before) {
            [willSwitchExpectation fulfill];
        }else {
            XCTAssertTrue([toUser isEqual:userAccountManager.currentUser], @"Switch to user should change current user");
            [didSwitchExpectation fulfill];
        }
    }];
    [userAccountManager switchToUser:userTo];
    [self waitForExpectations:@[willSwitchExpectation, didSwitchExpectation] timeout:20];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:UISceneDidActivateNotification object:scene];
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
    _currentSdkManagerFlow = [[SFTestSDKManagerFlow alloc] init];
    _origSdkManagerFlow = [SalesforceSDKManager sharedManager].sdkManagerFlow; [SalesforceSDKManager sharedManager].sdkManagerFlow = _currentSdkManagerFlow;
    _origConnectedAppId = [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey; [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = @"";
    _origConnectedAppCallbackUri = [SalesforceSDKManager sharedManager].appConfig.oauthRedirectURI; [SalesforceSDKManager sharedManager].appConfig.oauthRedirectURI = @"";
    _origAuthScopes = [SalesforceSDKManager sharedManager].appConfig.oauthScopes; [SalesforceSDKManager sharedManager].appConfig.oauthScopes = [NSSet set];
    _origAuthenticateAtLaunch = [SalesforceSDKManager sharedManager].appConfig.shouldAuthenticate; [SalesforceSDKManager sharedManager].appConfig.shouldAuthenticate = YES;
    _origCurrentUser = [SFUserAccountManager sharedInstance].currentUser;
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
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
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:_origCurrentUser];
    SalesforceSDKManager.ailtnAppName = _origAppName;
    SFSDKWebViewStateManager.sharedProcessPool = _origProcessPool;
    [SalesforceSDKManager sharedManager].brandLoginPath = _origBrandLoginPath;
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

@end
