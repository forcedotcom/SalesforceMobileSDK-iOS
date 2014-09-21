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

- (void)setUp
{
    [super setUp];
    [SFLogger setLogLevel:SFLogLevelDebug];
    
    XCTAssertFalse([SalesforceSDKManager isLaunching], @"SalesforceSDKManager should not be launching at the beginning of the test.");
    
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
    [SalesforceSDKManager setLaunchErrorAction:^(NSError *error, SFSDKLaunchAction launchAction) {
        launchError = error;
        errorBlockCalled = YES;
    }];
    BOOL didLaunch = [SalesforceSDKManager launch];
    BOOL launchCompleted = [_currentSdkManagerFlow waitForLaunchCompletion];
    XCTAssertTrue(didLaunch, @"Failed to start launch.");
    XCTAssertTrue(launchCompleted, @"Launch failed to complete.");
    XCTAssertTrue(errorBlockCalled, @"There should have been validation errors.");
    XCTAssertEqual([launchError domain], kSalesforceSDKManagerErrorDomain, @"Wrong error domain.");
    XCTAssertEqual([launchError code], kSalesforceSDKManagerErrorInvalidLaunchParameters, @"Wrong error code.");
    XCTAssertEqual([[launchError userInfo][kSalesforceSDKManagerErrorDetailsKey] count], 3UL, @"There should have been three fatal validation errors.");
    
    // Set Connected App ID
    [SalesforceSDKManager setConnectedAppId:@"test_connected_app_id"];
    errorBlockCalled = NO;
    launchError = nil;
    didLaunch = [SalesforceSDKManager launch];
    launchCompleted = [_currentSdkManagerFlow waitForLaunchCompletion];
    XCTAssertTrue(didLaunch, @"Failed to start launch.");
    XCTAssertTrue(launchCompleted, @"Launch failed to complete.");
    XCTAssertTrue(errorBlockCalled, @"There should have been validation errors.");
    XCTAssertEqual([launchError domain], kSalesforceSDKManagerErrorDomain, @"Wrong error domain.");
    XCTAssertEqual([launchError code], kSalesforceSDKManagerErrorInvalidLaunchParameters, @"Wrong error code.");
    XCTAssertEqual([[launchError userInfo][kSalesforceSDKManagerErrorDetailsKey] count], 2UL, @"There should have been two fatal validation errors.");
    
    // Set Callback URI
    [SalesforceSDKManager setConnectedAppCallbackUri:@"test_connected_app_callback_uri"];
    errorBlockCalled = NO;
    launchError = nil;
    didLaunch = [SalesforceSDKManager launch];
    launchCompleted = [_currentSdkManagerFlow waitForLaunchCompletion];
    XCTAssertTrue(didLaunch, @"Failed to start launch.");
    XCTAssertTrue(launchCompleted, @"Launch failed to complete.");
    XCTAssertTrue(errorBlockCalled, @"There should have been validation errors.");
    XCTAssertEqual([launchError domain], kSalesforceSDKManagerErrorDomain, @"Wrong error domain.");
    XCTAssertEqual([launchError code], kSalesforceSDKManagerErrorInvalidLaunchParameters, @"Wrong error code.");
    XCTAssertEqual([[launchError userInfo][kSalesforceSDKManagerErrorDetailsKey] count], 1UL, @"There should have been one fatal validation error.");
    
    // Set auth scopes
    [SalesforceSDKManager setAuthScopes:@[ @"web", @"api" ]];
    errorBlockCalled = NO;
    launchError = nil;
    didLaunch = [SalesforceSDKManager launch];
    launchCompleted = [_currentSdkManagerFlow waitForLaunchCompletion];
    XCTAssertTrue(didLaunch, @"Failed to start launch.");
    XCTAssertTrue(launchCompleted, @"Launch failed to complete.");
    XCTAssertFalse(errorBlockCalled, @"There should not have been validation errors.");
    XCTAssertNil(launchError, @"There should be no error.");
}

- (void)testOneLaunchAtATime
{
    __block BOOL postLaunchBlockCalled = NO;
    [SalesforceSDKManager setPostLaunchAction:^(SFSDKLaunchAction launchActions) {
        postLaunchBlockCalled = YES;
    }];
    [SalesforceSDKManager setConnectedAppId:@"test_connected_app_id"];
    [SalesforceSDKManager setConnectedAppCallbackUri:@"test_connected_app_callback_uri"];
    [SalesforceSDKManager setAuthScopes:@[ @"web", @"api" ]];
    BOOL didLaunch = [SalesforceSDKManager launch];
    XCTAssertTrue(didLaunch, @"Failed to start launch.");
    didLaunch = [SalesforceSDKManager launch];
    XCTAssertFalse(didLaunch, @"Second concurrent launch should not be allowed.");
    BOOL launchCompleted = [_currentSdkManagerFlow waitForLaunchCompletion];
    XCTAssertTrue(launchCompleted, @"Launch failed to complete.");
    XCTAssertTrue(postLaunchBlockCalled, @"Launch should have succeeded.");
}

#pragma mark - Private helpers

- (void)setupSdkManagerState
{
    _currentSdkManagerFlow = [[SFTestSDKManagerFlow alloc] initWithStepTimeDelaySecs:kTimeDelaySecsBetweenLaunchSteps];
    _origSdkManagerFlow = [SalesforceSDKManager sdkManagerFlow]; [SalesforceSDKManager setSdkManagerFlow:_currentSdkManagerFlow];
    
    _origConnectedAppId = [SalesforceSDKManager connectedAppId]; [SalesforceSDKManager setConnectedAppId:nil];
    _origConnectedAppCallbackUri = [SalesforceSDKManager connectedAppCallbackUri]; [SalesforceSDKManager setConnectedAppCallbackUri:nil];
    _origAuthScopes = [SalesforceSDKManager authScopes]; [SalesforceSDKManager setAuthScopes:nil];
    _origAuthenticateAtLaunch = [SalesforceSDKManager authenticateAtLaunch]; [SalesforceSDKManager setAuthenticateAtLaunch:YES];
    _origPostLaunchAction = [SalesforceSDKManager postLaunchAction]; [SalesforceSDKManager setPostLaunchAction:NULL];
    _origLaunchErrorAction = [SalesforceSDKManager launchErrorAction]; [SalesforceSDKManager setLaunchErrorAction:NULL];
    _origPostLogoutAction = [SalesforceSDKManager postLogoutAction]; [SalesforceSDKManager setPostLogoutAction:NULL];
    _origSwitchUserAction = [SalesforceSDKManager switchUserAction]; [SalesforceSDKManager setSwitchUserAction:NULL];
    _origPostAppForegroundAction = [SalesforceSDKManager postAppForegroundAction]; [SalesforceSDKManager setPostAppForegroundAction:NULL];
    _origCurrentUser = [SFUserAccountManager sharedInstance].currentUser; [SFUserAccountManager sharedInstance].currentUser = nil;
}

- (void)restoreOrigSdkManagerState
{
    [SalesforceSDKManager setSdkManagerFlow:_origSdkManagerFlow];
    [SalesforceSDKManager setConnectedAppId:_origConnectedAppId];
    [SalesforceSDKManager setConnectedAppCallbackUri:_origConnectedAppCallbackUri];
    [SalesforceSDKManager setAuthScopes:_origAuthScopes];
    [SalesforceSDKManager setAuthenticateAtLaunch:_origAuthenticateAtLaunch];
    [SalesforceSDKManager setPostLaunchAction:_origPostLaunchAction];
    [SalesforceSDKManager setLaunchErrorAction:_origLaunchErrorAction];
    [SalesforceSDKManager setPostLogoutAction:_origPostLogoutAction];
    [SalesforceSDKManager setSwitchUserAction:_origSwitchUserAction];
    [SalesforceSDKManager setPostAppForegroundAction:_origPostAppForegroundAction];
    [SFUserAccountManager sharedInstance].currentUser = _origCurrentUser;
}

@end
