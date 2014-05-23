//
//  SFPreferencesTests.m
//  SalesforceSDKCore
//
//  Created by Jean Bovet on 2/20/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "SFPreferences.h"
#import "SFUserAccount.h"
#import "SFUserAccountManager.h"
#import "SFDirectoryManager.h"

/** Class that tests the various scoped preferences
 */
@interface SFPreferencesTests : SenTestCase

@end

@implementation SFPreferencesTests

- (void)testGlobalPreference {
    SFPreferences *prefs = [SFPreferences globalPreferences];
    STAssertNotNil(prefs, @"Preferences must exist");
    
    NSString *expectedPath = [[SFDirectoryManager sharedManager] directoryForOrg:nil user:nil community:nil type:NSLibraryDirectory components:nil];
    expectedPath = [expectedPath stringByAppendingPathComponent:@"Preferences.plist"];
    STAssertEqualObjects(prefs.path, expectedPath, @"Preferences path mismatch");
    
    // Make sure the same instance is returned each time
    STAssertEquals(prefs, [SFPreferences globalPreferences], @"Shared instance mismatch");
}

- (void)testOrgLevelPreferences {
    SFUserAccount *user = [[SFUserAccount alloc] initWithIdentifier:@"happy-user"];
    user.credentials.identityUrl = [NSURL URLWithString:@"https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0"];
    [SFUserAccountManager sharedInstance].currentUser = user;

    SFPreferences *prefs = [SFPreferences currentOrgLevelPreferences];
    STAssertNotNil(prefs, @"Preferences must exist");
    
    NSString *expectedPath = [[SFDirectoryManager sharedManager] directoryForOrg:@"00D000000000062EA0" user:nil community:nil type:NSLibraryDirectory components:nil];
    expectedPath = [expectedPath stringByAppendingPathComponent:@"Preferences.plist"];
    STAssertEqualObjects(prefs.path, expectedPath, @"Preferences path mismatch");
    
    // Make sure the same instance is returned each time
    STAssertEquals(prefs, [SFPreferences currentOrgLevelPreferences], @"Shared instance mismatch");
    
    // Check that the other scoped instances don't match
    STAssertFalse(prefs == [SFPreferences globalPreferences], @"Preferences instance should be different");
}

- (void)testUserLevelPreferences {
    SFUserAccount *user = [[SFUserAccount alloc] initWithIdentifier:@"happy-user"];
    user.credentials.identityUrl = [NSURL URLWithString:@"https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0"];
    [SFUserAccountManager sharedInstance].currentUser = user;
    
    SFPreferences *prefs = [SFPreferences currentUserLevelPreferences];
    STAssertNotNil(prefs, @"Preferences must exist");
    
    NSString *expectedPath = [[SFDirectoryManager sharedManager] directoryForOrg:@"00D000000000062EA0" user:@"005R0000000Dsl0" community:nil type:NSLibraryDirectory components:nil];
    expectedPath = [expectedPath stringByAppendingPathComponent:@"Preferences.plist"];
    STAssertEqualObjects(prefs.path, expectedPath, @"Preferences path mismatch");
    
    // Make sure the same instance is returned each time
    STAssertEquals(prefs, [SFPreferences currentUserLevelPreferences], @"Shared instance mismatch");
    
    // Check that the other scoped instances don't match
    STAssertFalse(prefs == [SFPreferences currentOrgLevelPreferences], @"Preferences instance should be different");
    STAssertFalse(prefs == [SFPreferences globalPreferences], @"Preferences instance should be different");
}

- (void)testCommunityLevelPreferences {
    SFUserAccount *user = [[SFUserAccount alloc] initWithIdentifier:@"happy-user"];
    user.credentials.identityUrl = [NSURL URLWithString:@"https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0"];
    [SFUserAccountManager sharedInstance].currentUser = user;
    
    SFPreferences *prefs = [SFPreferences currentCommunityLevelPreferences];
    STAssertNotNil(prefs, @"Preferences must exist");
    
    NSString *expectedPath = [[SFDirectoryManager sharedManager] directoryForOrg:@"00D000000000062EA0" user:@"005R0000000Dsl0" community:nil type:NSLibraryDirectory components:nil];
    expectedPath = [expectedPath stringByAppendingPathComponent:@"Preferences.plist"];
    STAssertEqualObjects(prefs.path, expectedPath, @"Preferences path mismatch");
    
    // Make sure the same instance is returned each time
    STAssertEquals(prefs, [SFPreferences currentCommunityLevelPreferences], @"Shared instance mismatch");
    
    // Check that the other scoped instances don't match
    STAssertFalse(prefs == [SFPreferences currentUserLevelPreferences], @"Preferences instance should be different");
    STAssertFalse(prefs == [SFPreferences currentOrgLevelPreferences], @"Preferences instance should be different");
    STAssertFalse(prefs == [SFPreferences globalPreferences], @"Preferences instance should be different");
}

@end
