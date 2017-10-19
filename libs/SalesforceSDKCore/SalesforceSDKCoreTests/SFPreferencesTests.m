/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFPreferences.h"
#import "SFUserAccount.h"
#import "SFUserAccountManager+Internal.h"
#import "SFAuthenticationManager.h"
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
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"happy-user" clientId:[SFUserAccountManager  sharedInstance].oauthClientId encrypted:YES];
    SFUserAccount *user =[[SFUserAccount alloc] initWithCredentials:credentials];
    NSError *error = nil;
    BOOL success = [[SFUserAccountManager sharedInstance] saveAccountForUser:user error:&error];
    XCTAssertNil(error, @"Should be able to create user account");
        
    user.credentials.identityUrl = [NSURL URLWithString:@"https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0"];
    success = [[SFUserAccountManager sharedInstance] saveAccountForUser:user error:&error];
    XCTAssertNil(error, @"Should be able to update user account");
    
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
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:user error:nil];
}

- (void)testUserLevelPreferences {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"happy-user" clientId:[SFUserAccountManager  sharedInstance].oauthClientId encrypted:YES];
    SFUserAccount *user =[[SFUserAccount alloc] initWithCredentials:credentials];
    user.credentials.identityUrl = [NSURL URLWithString:@"https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0"];
 
    NSError *error = nil;
    [[SFUserAccountManager sharedInstance] saveAccountForUser:user error:&error];
    XCTAssertNil(error, @"Should be able to create user account");
 
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
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:user error:nil];
}

- (void)testCommunityLevelPreferences {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"happy-user" clientId:[SFUserAccountManager  sharedInstance].oauthClientId encrypted:YES];
    SFUserAccount *user = [[SFUserAccount alloc] initWithCredentials:credentials];
    user.credentials.identityUrl = [NSURL URLWithString:@"https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0"];
    NSError *error = nil;
    [[SFUserAccountManager sharedInstance] saveAccountForUser:user error:&error];
    XCTAssertNil(error, @"Should be able to create user account");
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
     [[SFUserAccountManager sharedInstance] deleteAccountForUser:user error:nil];
}

@end
