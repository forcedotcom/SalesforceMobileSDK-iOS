/*
 SFSDKLoginHostTests.m
 SalesforceSDKCore
 
 Created by Kunal Chitalia on 3/28/16.
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFLoginViewController.h"
#import "SFSDKLoginHostListViewController.h"
#import "SFSDKLoginHostStorage.h"
#import "SFSDKLoginHost.h"
#import "SFUserAccountManager.h"
#import "SalesforceSDKManager.h"
#import <SalesforceSDKCore/SalesforceSDKCore-Swift.h>

// Expose private method for testing
@interface SFLoginViewController (Testing)
- (SFSDKLoginHostListViewController *)createLoginHostListViewController;
@end

// Expose the forced-advanced-auth chrome helpers for testing.
@interface SFSDKLoginHostListViewController (Testing)
- (BOOL)shouldShowBackButton;
- (UIBarButtonItem *)createBackButton;
- (void)handleBackButtonAction;
- (void)backToPreviousHost:(id)sender;
- (nullable UIBarButtonItem *)loginOptionsButton;
- (void)delegateDidChangeLoginOptions;
@end

// Spy delegate to observe the change-login-options callback.
@interface SFSDKLoginHostTestDelegate : NSObject <SFSDKLoginHostDelegate>
@property (nonatomic, assign) BOOL didChangeLoginOptionsCalled;
@end

@implementation SFSDKLoginHostTestDelegate
- (void)hostListViewControllerDidChangeLoginOptions:(SFSDKLoginHostListViewController *)hostListViewController {
    self.didChangeLoginOptionsCalled = YES;
}
@end

@interface SFSDKLoginHostTests : XCTestCase

@property (nonatomic, strong) NSString *productionUrl;
@property (nonatomic, strong) NSString *sandboxUrl;
@property (nonatomic, strong) NSString *doesNotExistUrl;
@property (nonatomic, strong) NSString *customName;
@property (nonatomic, strong) NSString *customUrl;
@property (nonatomic, strong) NSString *customName2;
@property (nonatomic, strong) NSString *customUrl2;

// Saved global state restored in tearDown so the forced-advanced-auth chrome tests below
// (which toggle dev support, the web-auth fallback flag, and biometric lock) don't leak state.
@property (nonatomic, assign) BOOL originalDevSupportEnabled;
@property (nonatomic, assign) BOOL originalShouldFallbackToWebAuthentication;
@property (nonatomic, assign) BOOL originalBiometricLocked;
@property (nonatomic, copy, nullable) NSString *originalIdpAppURIScheme;

@end

@implementation SFSDKLoginHostTests

- (void)setUp {
    [super setUp];
    self.productionUrl = @"login.salesforce.com";
    self.sandboxUrl = @"test.salesforce.com";
    self.doesNotExistUrl = @"doesnotexist.salesforce.com";
    self.customName = @"New";
    self.customUrl = @"https://new.com";
    self.customName2 = @"New2";
    self.customUrl2 = @"https://new2.com";

    self.originalDevSupportEnabled = [SalesforceSDKManager sharedManager].isDevSupportEnabled;
    self.originalShouldFallbackToWebAuthentication = [SFUserAccountManager sharedInstance].shouldFallbackToWebAuthentication;
    self.originalBiometricLocked = [SFBiometricAuthenticationManagerInternal shared].locked;
    self.originalIdpAppURIScheme = [SFUserAccountManager sharedInstance].idpAppURIScheme;
}

- (void)tearDown {
    SFSDKLoginHostStorage *loginHostStorage = [SFSDKLoginHostStorage sharedInstance];
    [loginHostStorage removeAllLoginHosts];

    [SalesforceSDKManager sharedManager].isDevSupportEnabled = self.originalDevSupportEnabled;
    [SFUserAccountManager sharedInstance].shouldFallbackToWebAuthentication = self.originalShouldFallbackToWebAuthentication;
    [SFBiometricAuthenticationManagerInternal shared].locked = self.originalBiometricLocked;
    [SFUserAccountManager sharedInstance].idpAppURIScheme = self.originalIdpAppURIScheme;
    [[SFUserAccountManager sharedInstance] stopCurrentAuthentication:nil];
    [super tearDown];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

- (void)testLoginHost{
    NSString *name = @"dummyname";
    NSString *host = @"dummyhost";
    BOOL deletable = YES;
    
    SFSDKLoginHost *loginHost = [SFSDKLoginHost hostWithName:name host:host deletable:deletable];
    
    XCTAssertEqualObjects(host, loginHost.host, @"%@ Should be equal to %@", host, loginHost.host);
    XCTAssertEqualObjects(name, loginHost.name, @"%@ Should be equal to %@", name, loginHost.name);
    XCTAssertEqual(deletable, loginHost.deletable, @"%d Should be equal to %d", deletable, loginHost.deletable);
    
    //Only testing name to be nil as host can never be nil and deletable will always have a YES or NO value
    loginHost = [SFSDKLoginHost hostWithName:nil host:host deletable:deletable];
    
    XCTAssertNotNil(loginHost.name, @"Name shoud not be nil");
    
}

#pragma clang diagnostic pop

- (void)testSetupNavigationBar {
    SFLoginViewController *loginViewController = [[SFLoginViewController alloc] init];
    //Test default values
    XCTAssertNotNil(loginViewController.navBarColor, "Nav bar color should not be nil");
    XCTAssertNotNil(loginViewController.navBarTintColor, "Nav bar tint color should not be nil");
    XCTAssertNil(loginViewController.navBarFont, "Nav bar font should be nil");
    XCTAssertEqual(YES, loginViewController.showNavbar, "Show Nav bar should be set to yes by default");
    XCTAssertEqual(YES, loginViewController.showSettingsIcon, "Show Settings Icon should be set to yes by default");
    
}

- (void) testGetLoginHosts {
    SFSDKLoginHostStorage *loginHostStorage = [SFSDKLoginHostStorage sharedInstance];
    SFSDKLoginHost *loginHost = [loginHostStorage loginHostForHostAddress:self.productionUrl];
    
    XCTAssertEqualObjects(@"Production", loginHost.name, @"%@ Should be equal to %@", @"Production", loginHost.name);
    XCTAssertEqualObjects(self.productionUrl, loginHost.host, @"%@ Should be equal to %@", self.productionUrl, loginHost.host);
    
    loginHost = [loginHostStorage loginHostForHostAddress:self.sandboxUrl];
    
    XCTAssertEqualObjects(@"Sandbox", loginHost.name, @"%@ Should be equal to %@", @"Sandbox", loginHost.name);
    XCTAssertEqualObjects(self.sandboxUrl, loginHost.host, @"%@ Should be equal to %@", self.sandboxUrl, loginHost.host);
    
    loginHost = [loginHostStorage loginHostForHostAddress:self.doesNotExistUrl];
    XCTAssertNil(loginHost, "Login host should be nil");
}

- (void) testAddCustomServer {
    SFSDKLoginHostStorage *loginHostStorage = [SFSDKLoginHostStorage sharedInstance];
    SFSDKLoginHost *loginHost = [loginHostStorage loginHostForHostAddress:self.productionUrl];
    
    XCTAssertEqualObjects(@"Production", loginHost.name, @"%@ Should be equal to %@", @"Production", loginHost.name);
    XCTAssertEqualObjects(self.productionUrl, loginHost.host, @"%@ Should be equal to %@", self.productionUrl, loginHost.host);
    
    [loginHostStorage addLoginHost:[SFSDKLoginHost hostWithName:self.customName host:self.customUrl deletable:YES]];
    
    loginHost = [loginHostStorage loginHostForHostAddress:self.customUrl];
    
    XCTAssertEqualObjects(self.customName, loginHost.name, @"%@ Should be equal to %@", self.customName, loginHost.name);
    XCTAssertEqualObjects(self.customUrl, loginHost.host, @"%@ Should be equal to %@", self.customUrl, loginHost.host);
}

- (void) testAddMultipleCustomServers {
    SFSDKLoginHostStorage *loginHostStorage = [SFSDKLoginHostStorage sharedInstance];
    XCTAssertEqual(2, [loginHostStorage numberOfLoginHosts], "Number of login hosts should be equal to 2");
    
    [loginHostStorage addLoginHost:[SFSDKLoginHost hostWithName:self.customName host:self.customUrl deletable:YES]];
    SFSDKLoginHost *loginHost = [loginHostStorage loginHostForHostAddress:self.customUrl];
    XCTAssertEqual(3, [loginHostStorage numberOfLoginHosts], "Number of login hosts should be equal to 3");
    XCTAssertEqualObjects(self.customName, loginHost.name, @"%@ Should be equal to %@", self.customName, loginHost.name);
    XCTAssertEqualObjects(self.customUrl, loginHost.host, @"%@ Should be equal to %@", self.customUrl, loginHost.host);
    
    [loginHostStorage addLoginHost:[SFSDKLoginHost hostWithName:self.customName2 host:self.customUrl2 deletable:YES]];
    loginHost = [loginHostStorage loginHostForHostAddress:self.customUrl2];
    XCTAssertEqual(4, [loginHostStorage numberOfLoginHosts], "Number of login hosts should be equal to 4");
    XCTAssertEqualObjects(self.customName2, loginHost.name, @"%@ Should be equal to %@", self.customName2, loginHost.name);
    XCTAssertEqualObjects(self.customUrl2, loginHost.host, @"%@ Should be equal to %@", self.customUrl2, loginHost.host);
}

- (void) testLoginHostListViewControllerCreatesUniqueInstances {
    // This test verifies the fix for the swipe dismissal race condition crash.
    // Each call to createLoginHostListViewController should return a fresh instance,
    // preventing the "nested navigation controllers" error when rapidly opening/closing
    // the connection screen with swipe gestures.

    SFLoginViewController *loginViewController = [[SFLoginViewController alloc] init];

    // Create multiple instances
    SFSDKLoginHostListViewController *instance1 = [loginViewController createLoginHostListViewController];
    SFSDKLoginHostListViewController *instance2 = [loginViewController createLoginHostListViewController];
    SFSDKLoginHostListViewController *instance3 = [loginViewController createLoginHostListViewController];

    // Verify each call creates a unique instance (different memory addresses)
    XCTAssertNotNil(instance1, "First instance should not be nil");
    XCTAssertNotNil(instance2, "Second instance should not be nil");
    XCTAssertNotNil(instance3, "Third instance should not be nil");

    XCTAssertNotEqual(instance1, instance2, "First and second instances should be different objects");
    XCTAssertNotEqual(instance2, instance3, "Second and third instances should be different objects");
    XCTAssertNotEqual(instance1, instance3, "First and third instances should be different objects");

    // Verify each instance is properly configured with config and delegate
    XCTAssertNotNil(instance1.config, "First instance should have config");
    XCTAssertNotNil(instance2.config, "Second instance should have config");
    XCTAssertNotNil(instance3.config, "Third instance should have config");

    XCTAssertEqual((SFLoginViewController *)instance1.delegate, loginViewController, "First instance delegate should be set to loginViewController");
    XCTAssertEqual((SFLoginViewController *)instance2.delegate, loginViewController, "Second instance delegate should be set to loginViewController");
    XCTAssertEqual((SFLoginViewController *)instance3.delegate, loginViewController, "Third instance delegate should be set to loginViewController");
}

#pragma mark - Forced Advanced Auth Chrome

// viewDidLoad: with the flag off, the gear is absent and Cancel (not the back button) is the
// left item, matching the pre-existing behavior for the transient "Choose Connection" sub-sheet.
- (void)test_givenChromeFlagOff_whenViewLoads_thenNoGearAndCancelShown {
    SFSDKLoginHostListViewController *vc = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
    vc.presentedAsLoginScreen = NO;
    [SalesforceSDKManager sharedManager].isDevSupportEnabled = YES;

    [vc loadViewIfNeeded];

    XCTAssertNil([vc loginOptionsButton], @"Gear should be nil when the chrome flag is off");
    XCTAssertEqualObjects(vc.navigationItem.leftBarButtonItem.accessibilityIdentifier, nil,
                          @"Left item should be the system Cancel button (no back-button identifier) when the chrome flag is off");
    XCTAssertNotNil(vc.navigationItem.leftBarButtonItem, @"Cancel button should be shown when the chrome flag is off and Cancel is not hidden");
}

// viewDidLoad: with the flag on and dev support on, the gear is added to the right bar items.
- (void)test_givenChromeFlagOnAndDevSupportOn_whenViewLoads_thenGearShownInRightItems {
    SFSDKLoginHostListViewController *vc = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
    vc.presentedAsLoginScreen = YES;
    [SalesforceSDKManager sharedManager].isDevSupportEnabled = YES;

    [vc loadViewIfNeeded];

    UIBarButtonItem *gear = [vc loginOptionsButton];
    XCTAssertNotNil(gear, @"Gear should be created when the chrome flag and dev support are on");
    XCTAssertEqualObjects(gear.accessibilityIdentifier, @"settings", @"Gear should carry the 'settings' accessibility identifier");

    BOOL gearInRightItems = NO;
    for (UIBarButtonItem *item in vc.navigationItem.rightBarButtonItems) {
        if ([item.accessibilityIdentifier isEqualToString:@"settings"]) {
            gearInRightItems = YES;
        }
    }
    XCTAssertTrue(gearInRightItems, @"Right bar items should include the gear when the chrome flag and dev support are on");
}

// loginOptionsButton returns nil when dev support is off even though the chrome flag is on.
- (void)test_givenChromeFlagOnAndDevSupportOff_whenLoginOptionsButton_thenNil {
    SFSDKLoginHostListViewController *vc = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
    vc.presentedAsLoginScreen = YES;
    [SalesforceSDKManager sharedManager].isDevSupportEnabled = NO;

    XCTAssertNil([vc loginOptionsButton], @"Gear should be nil when dev support is disabled");
}

// shouldShowBackButton returns NO when the app is biometric-locked, regardless of other state.
- (void)test_givenBiometricLocked_whenShouldShowBackButton_thenNo {
    [SFBiometricAuthenticationManagerInternal shared].locked = YES;
    [SFUserAccountManager sharedInstance].shouldFallbackToWebAuthentication = YES; // would otherwise be YES

    SFSDKLoginHostListViewController *vc = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];

    XCTAssertFalse([vc shouldShowBackButton], @"Back button must be hidden while the app is biometric-locked");
}

// shouldShowBackButton returns YES when a web-auth fallback flow is in progress.
- (void)test_givenWebAuthFallback_whenShouldShowBackButton_thenYes {
    [SFBiometricAuthenticationManagerInternal shared].locked = NO;
    [SFUserAccountManager sharedInstance].shouldFallbackToWebAuthentication = YES;

    SFSDKLoginHostListViewController *vc = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];

    XCTAssertTrue([vc shouldShowBackButton], @"Back button should show while a web-auth fallback flow is in progress");
}

// shouldShowBackButton falls through to the account-based decision when the app is unlocked and
// no idp / web-auth fallback flow is in progress. With no logged-in user in the test environment,
// there is nothing to return to, so the back button should not show.
- (void)test_givenUnlockedNoFlowNoAccount_whenShouldShowBackButton_thenNo {
    [SFBiometricAuthenticationManagerInternal shared].locked = NO;
    [SFUserAccountManager sharedInstance].shouldFallbackToWebAuthentication = NO;

    SFSDKLoginHostListViewController *vc = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];

    // idp is disabled by default in the test environment; with no current user the account-based
    // branch returns NO.
    XCTAssertFalse([SFUserAccountManager sharedInstance].idpEnabled, @"Test precondition: idp should be disabled");
    XCTAssertFalse([vc shouldShowBackButton], @"Back button should not show when unlocked with no flow and no account to return to");
}

// With the chrome flag on and shouldShowBackButton true, viewDidLoad installs the back button
// as the left item (an image-only button, i.e. not the system Cancel button which has a title).
- (void)test_givenChromeFlagOnAndBackButtonEligible_whenViewLoads_thenBackButtonIsLeftItem {
    [SFBiometricAuthenticationManagerInternal shared].locked = NO;
    [SFUserAccountManager sharedInstance].shouldFallbackToWebAuthentication = YES;

    SFSDKLoginHostListViewController *vc = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
    vc.presentedAsLoginScreen = YES;

    [vc loadViewIfNeeded];

    UIBarButtonItem *leftItem = vc.navigationItem.leftBarButtonItem;
    XCTAssertNotNil(leftItem, @"A left bar button item should be installed");
    XCTAssertNotNil(leftItem.image, @"The back button should be image-based");
    XCTAssertEqual(leftItem.action, @selector(backToPreviousHost:), @"The left item should be the back button targeting backToPreviousHost:");
}

// createBackButton produces an image-based button wired to backToPreviousHost:.
- (void)test_whenCreateBackButton_thenImageButtonTargetsBackAction {
    SFSDKLoginHostListViewController *vc = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];

    UIBarButtonItem *backButton = [vc createBackButton];

    XCTAssertNotNil(backButton, @"createBackButton should return a bar button item");
    XCTAssertNotNil(backButton.image, @"Back button should have an image");
    XCTAssertEqual(backButton.action, @selector(backToPreviousHost:), @"Back button should target backToPreviousHost:");
}

// backToPreviousHost: routes to handleBackButtonAction, which stops the current authentication.
// With no active auth session, no web-auth fallback, and no idp, this is a safe no-op that
// returns cleanly.
- (void)test_whenBackToPreviousHost_thenHandlesWithoutCrashing {
    [SFUserAccountManager sharedInstance].shouldFallbackToWebAuthentication = NO;
    SFSDKLoginHostListViewController *vc = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
    [vc loadViewIfNeeded];

    XCTAssertNoThrow([vc backToPreviousHost:nil], @"Tapping back should stop authentication and dismiss without throwing");
}

// handleBackButtonAction consumes the web-auth fallback flag (sets it to NO) so the next login
// attempt returns to the fallback surface instead of re-launching the browser.
- (void)test_givenWebAuthFallback_whenHandleBackButtonAction_thenFallbackConsumed {
    [SFUserAccountManager sharedInstance].shouldFallbackToWebAuthentication = YES;
    SFSDKLoginHostListViewController *vc = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
    [vc loadViewIfNeeded];

    [vc handleBackButtonAction];

    XCTAssertFalse([SFUserAccountManager sharedInstance].shouldFallbackToWebAuthentication,
                   @"handleBackButtonAction should consume the web-auth fallback flag");
}

// shouldShowBackButton returns YES via the idp branch when an idp app URI scheme is configured,
// even without a logged-in account to return to.
- (void)test_givenIdpEnabled_whenShouldShowBackButton_thenYes {
    [SFBiometricAuthenticationManagerInternal shared].locked = NO;
    [SFUserAccountManager sharedInstance].shouldFallbackToWebAuthentication = NO;
    [SFUserAccountManager sharedInstance].idpAppURIScheme = @"testidp";
    XCTAssertTrue([SFUserAccountManager sharedInstance].idpEnabled, @"Test precondition: idp should be enabled");

    SFSDKLoginHostListViewController *vc = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];

    XCTAssertTrue([vc shouldShowBackButton], @"Back button should show when an idp flow is enabled");
}

// handleBackButtonAction takes the idp branch (dismisses the presented view controller rather than
// the whole auth window) when an idp app URI scheme is configured. With no active auth session this
// is a safe no-op that returns cleanly.
- (void)test_givenIdpEnabled_whenHandleBackButtonAction_thenHandlesWithoutCrashing {
    [SFUserAccountManager sharedInstance].shouldFallbackToWebAuthentication = NO;
    [SFUserAccountManager sharedInstance].idpAppURIScheme = @"testidp";
    XCTAssertTrue([SFUserAccountManager sharedInstance].idpEnabled, @"Test precondition: idp should be enabled");

    SFSDKLoginHostListViewController *vc = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
    [vc loadViewIfNeeded];

    XCTAssertNoThrow([vc handleBackButtonAction], @"Back button in the idp path should dismiss without throwing");
}

// delegateDidChangeLoginOptions forwards to the delegate when it implements the optional method.
- (void)test_givenDelegate_whenDelegateDidChangeLoginOptions_thenDelegateNotified {
    SFSDKLoginHostListViewController *vc = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
    SFSDKLoginHostTestDelegate *spy = [[SFSDKLoginHostTestDelegate alloc] init];
    vc.delegate = spy;

    [vc delegateDidChangeLoginOptions];

    XCTAssertTrue(spy.didChangeLoginOptionsCalled, @"Delegate should be notified when login options change");
}

// delegateDidChangeLoginOptions is a safe no-op when no delegate is set.
- (void)test_givenNoDelegate_whenDelegateDidChangeLoginOptions_thenNoCrash {
    SFSDKLoginHostListViewController *vc = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
    vc.delegate = nil;

    XCTAssertNoThrow([vc delegateDidChangeLoginOptions], @"Should not throw when no delegate is set");
}

@end
