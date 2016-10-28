//
//  SFPreferencesTests.m
//  SalesforceSDKCore
//
//  Created by Jean Bovet on 2/20/14.
//  Copyright (c) 2014-present, salesforce.com. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SFPreferences.h"
#import "SFUserAccount.h"
#import "SFUserAccountManager.h"
#import "SFDirectoryManager.h"

/** Class that tests the various scoped preferences
 */
@interface SFPreferencesTests : XCTestCase

@end

@implementation SFPreferencesTests

- (void)testGlobalPreference {
    SFPreferences *prefs = [SFPreferences globalPreferences];
    XCTAssertNotNil(prefs, @"Preferences must exist");
    
    NSString *expectedPath = [[SFDirectoryManager sharedManager] directoryForOrg:nil user:nil community:nil type:NSLibraryDirectory components:nil];
    expectedPath = [expectedPath stringByAppendingPathComponent:@"Preferences.plist"];
    XCTAssertEqualObjects(prefs.path, expectedPath, @"Preferences path mismatch");
    
    // Make sure the same instance is returned each time
    XCTAssertEqual(prefs, [SFPreferences globalPreferences], @"Shared instance mismatch");
}

- (void)testOrgLevelPreferences {
    SFUserAccount *user = [[SFUserAccount alloc] initWithIdentifier:@"happy-user"];
    user.credentials.identityUrl = [NSURL URLWithString:@"https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0"];
    [SFUserAccountManager sharedInstance].currentUser = user;

    SFPreferences *prefs = [SFPreferences currentOrgLevelPreferences];
    XCTAssertNotNil(prefs, @"Preferences must exist");
    
    NSString *expectedPath = [[SFDirectoryManager sharedManager] directoryForOrg:@"00D000000000062EA0" user:nil community:nil type:NSLibraryDirectory components:nil];
    expectedPath = [expectedPath stringByAppendingPathComponent:@"Preferences.plist"];
    XCTAssertEqualObjects(prefs.path, expectedPath, @"Preferences path mismatch");
    
    // Make sure the same instance is returned each time
    XCTAssertEqual(prefs, [SFPreferences currentOrgLevelPreferences], @"Shared instance mismatch");
    
    // Check that the other scoped instances don't match
    XCTAssertFalse(prefs == [SFPreferences globalPreferences], @"Preferences instance should be different");
}

- (void)testUserLevelPreferences {
    SFUserAccount *user = [[SFUserAccount alloc] initWithIdentifier:@"happy-user"];
    user.credentials.identityUrl = [NSURL URLWithString:@"https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0"];
    [SFUserAccountManager sharedInstance].currentUser = user;
    
    SFPreferences *prefs = [SFPreferences currentUserLevelPreferences];
    XCTAssertNotNil(prefs, @"Preferences must exist");
    
    NSString *expectedPath = [[SFDirectoryManager sharedManager] directoryForOrg:@"00D000000000062EA0" user:@"005R0000000Dsl0" community:nil type:NSLibraryDirectory components:nil];
    expectedPath = [expectedPath stringByAppendingPathComponent:@"Preferences.plist"];
    XCTAssertEqualObjects(prefs.path, expectedPath, @"Preferences path mismatch");
    
    // Make sure the same instance is returned each time
    XCTAssertEqual(prefs, [SFPreferences currentUserLevelPreferences], @"Shared instance mismatch");
    
    // Check that the other scoped instances don't match
    XCTAssertFalse(prefs == [SFPreferences currentOrgLevelPreferences], @"Preferences instance should be different");
    XCTAssertFalse(prefs == [SFPreferences globalPreferences], @"Preferences instance should be different");
}

- (void)testCommunityLevelPreferences {
    SFUserAccount *user = [[SFUserAccount alloc] initWithIdentifier:@"happy-user"];
    user.credentials.identityUrl = [NSURL URLWithString:@"https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0"];
    [SFUserAccountManager sharedInstance].currentUser = user;
    
    SFPreferences *prefs = [SFPreferences currentCommunityLevelPreferences];
    XCTAssertNotNil(prefs, @"Preferences must exist");
    
    NSString *expectedPath = [[SFDirectoryManager sharedManager] directoryForOrg:@"00D000000000062EA0" user:@"005R0000000Dsl0" community:nil type:NSLibraryDirectory components:nil];
    expectedPath = [expectedPath stringByAppendingPathComponent:@"internal"];
    expectedPath = [expectedPath stringByAppendingPathComponent:@"Preferences.plist"];
    XCTAssertEqualObjects(prefs.path, expectedPath, @"Preferences path mismatch");
    
    // Make sure the same instance is returned each time
    XCTAssertEqual(prefs, [SFPreferences currentCommunityLevelPreferences], @"Shared instance mismatch");
    
    // Check that the other scoped instances don't match
    XCTAssertFalse(prefs == [SFPreferences currentUserLevelPreferences], @"Preferences instance should be different");
    XCTAssertFalse(prefs == [SFPreferences currentOrgLevelPreferences], @"Preferences instance should be different");
    XCTAssertFalse(prefs == [SFPreferences globalPreferences], @"Preferences instance should be different");
}

@end
