//
//  SalesforceSDKManagerTests.m
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 9/20/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SFTestSDKManagerFlow.h"
#import "SalesforceSDKManager+Internal.h"
#import "SFUserAccountManager.h"

static NSTimeInterval const kTimeDelaySecsBetweenLaunchSteps = 0.5;

@interface SalesforceSDKManagerTests : XCTestCase
{
    NSString *_origConnectedAppId;
    NSString *_origConnectedAppCallbackUri;
    NSArray *_origAuthScopes;
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
}

@end

@implementation SalesforceSDKManagerTests

+ (void)setUp
{
    [SFLogger sharedLogger].logLevel = SFLogLevelDebug;
}

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
    XCTAssertEqual([[_launchError userInfo][kSalesforceSDKManagerErrorDetailsKey] count], 3UL, @"There should have been three fatal validation errors.");
    
    // Set Connected App ID
    [SalesforceSDKManager sharedManager].connectedAppId = @"test_connected_app_id";
    [self launchAndVerify:YES failMessage:@"Failed to start launch."];
    [self verifyLaunchErrorState:YES];
    XCTAssertEqual([_launchError domain], kSalesforceSDKManagerErrorDomain, @"Wrong error domain.");
    XCTAssertEqual([_launchError code], kSalesforceSDKManagerErrorInvalidLaunchParameters, @"Wrong error code.");
    XCTAssertEqual([[_launchError userInfo][kSalesforceSDKManagerErrorDetailsKey] count], 2UL, @"There should have been two fatal validation errors.");
    
    // Set Callback URI
    [SalesforceSDKManager sharedManager].connectedAppCallbackUri = @"test_connected_app_callback_uri";
    [self launchAndVerify:YES failMessage:@"Failed to start launch."];
    [self verifyLaunchErrorState:YES];
    XCTAssertEqual([_launchError domain], kSalesforceSDKManagerErrorDomain, @"Wrong error domain.");
    XCTAssertEqual([_launchError code], kSalesforceSDKManagerErrorInvalidLaunchParameters, @"Wrong error code.");
    XCTAssertEqual([[_launchError userInfo][kSalesforceSDKManagerErrorDetailsKey] count], 1UL, @"There should have been one fatal validation error.");
    
    // Set auth scopes
    [SalesforceSDKManager sharedManager].authScopes = @[ @"web", @"api" ];
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
}

- (void)testAuthBypass
{
    XCTAssertNil([SFUserAccountManager sharedInstance].currentUser, @"Current user should be nil.");
    
    [SalesforceSDKManager sharedManager].authenticateAtLaunch = NO;
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

#pragma mark - Private helpers

- (void)createStandardPostLaunchBlock
{
    [SalesforceSDKManager sharedManager].postLaunchAction = ^(SFSDKLaunchAction launchActions) {
        _postLaunchBlockCalled = YES;
        _postLaunchActions = launchActions;
    };
}

- (void)createStandardLaunchErrorBlock
{
    [SalesforceSDKManager sharedManager].launchErrorAction = ^(NSError *error, SFSDKLaunchAction launchAction) {
        _launchError = error;
        _launchErrorBlockCalled = YES;
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
    [SalesforceSDKManager sharedManager].connectedAppId = @"test_connected_app_id";
    [SalesforceSDKManager sharedManager].connectedAppCallbackUri = @"test_connected_app_callback_uri";
    [SalesforceSDKManager sharedManager].authScopes = @[ @"web", @"api" ];
}

- (SFUserAccount *)createUserAccount
{
    u_int32_t userIdentifier = arc4random();
    SFUserAccount *user = [[SFUserAccount alloc] initWithIdentifier:[NSString stringWithFormat:@"identifier-%u", userIdentifier]];
    NSString *userId = [NSString stringWithFormat:@"user_%u", userIdentifier];
    NSString *orgId = [NSString stringWithFormat:@"org_%u", userIdentifier];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://login.salesforce.com/id/%@/%@", orgId, userId]];
    return user;
}

- (void)setupSdkManagerState
{
    _currentSdkManagerFlow = [[SFTestSDKManagerFlow alloc] initWithStepTimeDelaySecs:kTimeDelaySecsBetweenLaunchSteps];
    _origSdkManagerFlow = [SalesforceSDKManager sharedManager].sdkManagerFlow; [SalesforceSDKManager sharedManager].sdkManagerFlow = _currentSdkManagerFlow;
    
    _origConnectedAppId = [SalesforceSDKManager sharedManager].connectedAppId; [SalesforceSDKManager sharedManager].connectedAppId = nil;
    _origConnectedAppCallbackUri = [SalesforceSDKManager sharedManager].connectedAppCallbackUri; [SalesforceSDKManager sharedManager].connectedAppCallbackUri = nil;
    _origAuthScopes = [SalesforceSDKManager sharedManager].authScopes; [SalesforceSDKManager sharedManager].authScopes = nil;
    _origAuthenticateAtLaunch = [SalesforceSDKManager sharedManager].authenticateAtLaunch; [SalesforceSDKManager sharedManager].authenticateAtLaunch = YES;
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
}

- (void)restoreOrigSdkManagerState
{
    [SalesforceSDKManager sharedManager].sdkManagerFlow = _origSdkManagerFlow;
    [SalesforceSDKManager sharedManager].connectedAppId = _origConnectedAppId;
    [SalesforceSDKManager sharedManager].connectedAppCallbackUri = _origConnectedAppCallbackUri;
    [SalesforceSDKManager sharedManager].authScopes = _origAuthScopes;
    [SalesforceSDKManager sharedManager].authenticateAtLaunch = _origAuthenticateAtLaunch;
    [SalesforceSDKManager sharedManager].hasVerifiedPasscodeAtStartup = _origHasVerifiedPasscodeAtStartup;
    [SalesforceSDKManager sharedManager].postLaunchAction = _origPostLaunchAction;
    [SalesforceSDKManager sharedManager].launchErrorAction = _origLaunchErrorAction;
    [SalesforceSDKManager sharedManager].postLogoutAction = _origPostLogoutAction;
    [SalesforceSDKManager sharedManager].switchUserAction = _origSwitchUserAction;
    [SalesforceSDKManager sharedManager].postAppForegroundAction = _origPostAppForegroundAction;
    [SFUserAccountManager sharedInstance].currentUser = _origCurrentUser;
}

@end
