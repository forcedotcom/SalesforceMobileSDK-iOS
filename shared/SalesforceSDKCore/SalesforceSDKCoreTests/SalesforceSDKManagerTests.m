//
//  SalesforceSDKManagerTests.m
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 9/20/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SalesforceSDKManager.h"
#import "SFUserAccountManager.h"

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
}

@end

@implementation SalesforceSDKManagerTests

- (void)setUp
{
    [super setUp];
    
    XCTAssertFalse([SalesforceSDKManager isLaunching], @"SalesforceSDKManager should not be launching at the beginning of the test.");
    
    // Since other tests may have a more "permanent" idea of (essentially global) app identity and
    // launch state, only clear values for the length of the test, then restore them.
    [self clearSdkManagerState];
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
    __block NSArray *errorDetails;
    [SalesforceSDKManager setLaunchErrorAction:^(NSError *error, SFSDKLaunchAction launchAction) {
        errorBlockCalled = YES;
        errorDetails = [error userInfo][kSalesforceSDKManagerErrorDetailsKey];
    }];
    [SalesforceSDKManager launch];
    XCTAssertTrue(errorBlockCalled, @"There should have been validation errors.");
    XCTAssertEqual([errorDetails count], 3UL, @"There should have been three fatal validation errors.");
    
    // Set Connected App ID
    [SalesforceSDKManager setConnectedAppId:@"test_connected_app_id"];
    errorBlockCalled = NO;
    errorDetails = nil;
    [SalesforceSDKManager launch];
    XCTAssertTrue(errorBlockCalled, @"There should have been validation errors.");
    XCTAssertEqual([errorDetails count], 2UL, @"There should have been three fatal validation errors.");
    
    // Set Callback URI
    [SalesforceSDKManager setConnectedAppCallbackUri:@"test_connected_app_callback_uri"];
    errorBlockCalled = NO;
    errorDetails = nil;
    [SalesforceSDKManager launch];
    XCTAssertTrue(errorBlockCalled, @"There should have been validation errors.");
    XCTAssertEqual([errorDetails count], 1UL, @"There should have been three fatal validation errors.");
    
    // Set auth scopes
    [SalesforceSDKManager setAuthScopes:@[ @"web", @"api" ]];
    errorBlockCalled = NO;
    errorDetails = nil;
    [SalesforceSDKManager launch];
    XCTAssertFalse(errorBlockCalled, @"There should not have been validation errors.");
    XCTAssertNil(errorDetails, @"There should be no error details.");
}

#pragma mark - Private helpers

- (void)clearSdkManagerState
{
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
