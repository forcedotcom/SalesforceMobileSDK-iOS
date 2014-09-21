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
    SFSDKPostLaunchCallbackBlock _origPostLaunchAction;
    SFSDKLaunchErrorCallbackBlock _origLaunchErrorAction;
    SFSDKLogoutCallbackBlock _origPostLogoutAction;
    SFSDKSwitchUserCallbackBlock _origSwitchUserAction;
    SFSDKAppForegroundCallbackBlock _origPostAppForegroundAction;
    SFUserAccount *_origCurrentUser;
    id<SalesforceSDKManagerFlow> _origSdkManagerFlow;
    SFTestSDKManagerFlow *_currentSdkManagerFlow;
}

@end

@implementation SalesforceSDKManagerTests

+ (void)setUp
{
    [SFLogger setLogLevel:SFLogLevelDebug];
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
    __block BOOL errorBlockCalled = NO;
    __block NSError *launchError = nil;
    [SalesforceSDKManager sharedManager].launchErrorAction = ^(NSError *error, SFSDKLaunchAction launchAction) {
        launchError = error;
        errorBlockCalled = YES;
    };
    BOOL didLaunch = [[SalesforceSDKManager sharedManager] launch];
    BOOL launchCompleted = [_currentSdkManagerFlow waitForLaunchCompletion];
    XCTAssertTrue(didLaunch, @"Failed to start launch.");
    XCTAssertTrue(launchCompleted, @"Launch failed to complete.");
    XCTAssertTrue(errorBlockCalled, @"There should have been validation errors.");
    XCTAssertEqual([launchError domain], kSalesforceSDKManagerErrorDomain, @"Wrong error domain.");
    XCTAssertEqual([launchError code], kSalesforceSDKManagerErrorInvalidLaunchParameters, @"Wrong error code.");
    XCTAssertEqual([[launchError userInfo][kSalesforceSDKManagerErrorDetailsKey] count], 3UL, @"There should have been three fatal validation errors.");
    
    // Set Connected App ID
    [SalesforceSDKManager sharedManager].connectedAppId = @"test_connected_app_id";
    errorBlockCalled = NO;
    launchError = nil;
    didLaunch = [[SalesforceSDKManager sharedManager] launch];
    launchCompleted = [_currentSdkManagerFlow waitForLaunchCompletion];
    XCTAssertTrue(didLaunch, @"Failed to start launch.");
    XCTAssertTrue(launchCompleted, @"Launch failed to complete.");
    XCTAssertTrue(errorBlockCalled, @"There should have been validation errors.");
    XCTAssertEqual([launchError domain], kSalesforceSDKManagerErrorDomain, @"Wrong error domain.");
    XCTAssertEqual([launchError code], kSalesforceSDKManagerErrorInvalidLaunchParameters, @"Wrong error code.");
    XCTAssertEqual([[launchError userInfo][kSalesforceSDKManagerErrorDetailsKey] count], 2UL, @"There should have been two fatal validation errors.");
    
    // Set Callback URI
    [SalesforceSDKManager sharedManager].connectedAppCallbackUri = @"test_connected_app_callback_uri";
    errorBlockCalled = NO;
    launchError = nil;
    didLaunch = [[SalesforceSDKManager sharedManager] launch];
    launchCompleted = [_currentSdkManagerFlow waitForLaunchCompletion];
    XCTAssertTrue(didLaunch, @"Failed to start launch.");
    XCTAssertTrue(launchCompleted, @"Launch failed to complete.");
    XCTAssertTrue(errorBlockCalled, @"There should have been validation errors.");
    XCTAssertEqual([launchError domain], kSalesforceSDKManagerErrorDomain, @"Wrong error domain.");
    XCTAssertEqual([launchError code], kSalesforceSDKManagerErrorInvalidLaunchParameters, @"Wrong error code.");
    XCTAssertEqual([[launchError userInfo][kSalesforceSDKManagerErrorDetailsKey] count], 1UL, @"There should have been one fatal validation error.");
    
    // Set auth scopes
    [SalesforceSDKManager sharedManager].authScopes = @[ @"web", @"api" ];
    errorBlockCalled = NO;
    launchError = nil;
    didLaunch = [[SalesforceSDKManager sharedManager] launch];
    launchCompleted = [_currentSdkManagerFlow waitForLaunchCompletion];
    XCTAssertTrue(didLaunch, @"Failed to start launch.");
    XCTAssertTrue(launchCompleted, @"Launch failed to complete.");
    XCTAssertFalse(errorBlockCalled, @"There should not have been validation errors.");
    XCTAssertNil(launchError, @"There should be no error.");
}

- (void)testOneLaunchAtATime
{
    __block BOOL postLaunchBlockCalled = NO;
    [SalesforceSDKManager sharedManager].postLaunchAction = ^(SFSDKLaunchAction launchActions) {
        postLaunchBlockCalled = YES;
    };
    [SalesforceSDKManager sharedManager].connectedAppId = @"test_connected_app_id";
    [SalesforceSDKManager sharedManager].connectedAppCallbackUri = @"test_connected_app_callback_uri";
    [SalesforceSDKManager sharedManager].authScopes = @[ @"web", @"api" ];
    BOOL didLaunch = [[SalesforceSDKManager sharedManager] launch];
    XCTAssertTrue(didLaunch, @"Failed to start launch.");
    didLaunch = [[SalesforceSDKManager sharedManager] launch];
    XCTAssertFalse(didLaunch, @"Second concurrent launch should not be allowed.");
    BOOL launchCompleted = [_currentSdkManagerFlow waitForLaunchCompletion];
    XCTAssertTrue(launchCompleted, @"Launch failed to complete.");
    XCTAssertTrue(postLaunchBlockCalled, @"Launch should have succeeded.");
}

#pragma mark - Private helpers

- (void)setupSdkManagerState
{
    _currentSdkManagerFlow = [[SFTestSDKManagerFlow alloc] initWithStepTimeDelaySecs:kTimeDelaySecsBetweenLaunchSteps];
    _origSdkManagerFlow = [SalesforceSDKManager sharedManager].sdkManagerFlow; [SalesforceSDKManager sharedManager].sdkManagerFlow = _currentSdkManagerFlow;
    
    _origConnectedAppId = [SalesforceSDKManager sharedManager].connectedAppId; [SalesforceSDKManager sharedManager].connectedAppId = nil;
    _origConnectedAppCallbackUri = [SalesforceSDKManager sharedManager].connectedAppCallbackUri; [SalesforceSDKManager sharedManager].connectedAppCallbackUri = nil;
    _origAuthScopes = [SalesforceSDKManager sharedManager].authScopes; [SalesforceSDKManager sharedManager].authScopes = nil;
    _origAuthenticateAtLaunch = [SalesforceSDKManager sharedManager].authenticateAtLaunch; [SalesforceSDKManager sharedManager].authenticateAtLaunch = YES;
    _origPostLaunchAction = [SalesforceSDKManager sharedManager].postLaunchAction; [SalesforceSDKManager sharedManager].postLaunchAction = NULL;
    _origLaunchErrorAction = [SalesforceSDKManager sharedManager].launchErrorAction; [SalesforceSDKManager sharedManager].launchErrorAction = NULL;
    _origPostLogoutAction = [SalesforceSDKManager sharedManager].postLogoutAction; [SalesforceSDKManager sharedManager].postLogoutAction = NULL;
    _origSwitchUserAction = [SalesforceSDKManager sharedManager].switchUserAction; [SalesforceSDKManager sharedManager].switchUserAction = NULL;
    _origPostAppForegroundAction = [SalesforceSDKManager sharedManager].postAppForegroundAction; [SalesforceSDKManager sharedManager].postAppForegroundAction = NULL;
    _origCurrentUser = [SFUserAccountManager sharedInstance].currentUser; [SFUserAccountManager sharedInstance].currentUser = nil;
}

- (void)restoreOrigSdkManagerState
{
    [SalesforceSDKManager sharedManager].sdkManagerFlow = _origSdkManagerFlow;
    [SalesforceSDKManager sharedManager].connectedAppId = _origConnectedAppId;
    [SalesforceSDKManager sharedManager].connectedAppCallbackUri = _origConnectedAppCallbackUri;
    [SalesforceSDKManager sharedManager].authScopes = _origAuthScopes;
    [SalesforceSDKManager sharedManager].authenticateAtLaunch = _origAuthenticateAtLaunch;
    [SalesforceSDKManager sharedManager].postLaunchAction = _origPostLaunchAction;
    [SalesforceSDKManager sharedManager].launchErrorAction = _origLaunchErrorAction;
    [SalesforceSDKManager sharedManager].postLogoutAction = _origPostLogoutAction;
    [SalesforceSDKManager sharedManager].switchUserAction = _origSwitchUserAction;
    [SalesforceSDKManager sharedManager].postAppForegroundAction = _origPostAppForegroundAction;
    [SFUserAccountManager sharedInstance].currentUser = _origCurrentUser;
}

@end
