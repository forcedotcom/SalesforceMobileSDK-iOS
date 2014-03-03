//
//  SFUserAccountManagerTests.m
//  SalesforceSDKCore
//
//  Created by Jean Bovet on 2/18/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "SFUserAccountManager.h"
#import "SFUserAccount.h"
#import "SFDirectoryManager.h"

/** Unit tests for the SFUserAccountManager
 */
@interface SFUserAccountManagerTests : SenTestCase

@property (nonatomic, strong) SFUserAccountManager *uam;

@end

@implementation SFUserAccountManagerTests

- (void)setUp {
    [SFUserAccountManager sharedInstance].oauthClientId = @"fakeClientIdForTesting";

    // Delete the content of the global library directory
    NSString *globalLibraryDirectory = [[SFDirectoryManager sharedManager] directoryForUser:nil type:NSLibraryDirectory components:nil];
    [[NSFileManager defaultManager] removeItemAtPath:globalLibraryDirectory error:nil];

    // Ensure the user account manager doesn't contain any account
    self.uam = [SFUserAccountManager sharedInstance];
    [self.uam clearAllAccountState];
    
    [super setUp];
}

- (void)testSingleAccount {
    // Ensure we start with a clean state
    STAssertEquals(self.uam.allUserIds.count, (NSUInteger)0, @"There should be no accounts");
    
    // Create a single user
    SFUserAccount *user = [self createNewUserWithIndex:0];
    STAssertNotNil(user.credentials, @"User credentials shouldn't be nil");
    
    [self.uam addAccount:user];
    STAssertEqualObjects(self.uam.allUserIds[0], @"005R0000000Dsl0", @"User ID doesn't match");
    
    // Check if the UserAccount.plist is stored at the right location
    NSError *error = nil;
    STAssertTrue([self.uam saveAccounts:&error], @"Unable to save user accounts: %@", error);
    
    NSString *expectedLocation = [[SFDirectoryManager sharedManager] directoryForOrg:user.credentials.organizationId user:user.credentials.userId community:nil type:NSLibraryDirectory components:nil];
    expectedLocation = [expectedLocation stringByAppendingPathComponent:@"UserAccount.plist"];
    STAssertEqualObjects(expectedLocation, [SFUserAccountManager userAccountPlistFileForUser:user], @"Mismatching user account paths");
    STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:expectedLocation], @"Unable to find new UserAccount.plist");
    
    // Now remove all the users and re-load
    [self.uam clearAllAccountState];
    STAssertEquals(self.uam.allUserIds.count, (NSUInteger)0, @"There should be no accounts");

    STAssertTrue([self.uam loadAccounts:&error], @"Unable to load user accounts: %@", error);
    STAssertEqualObjects(self.uam.allUserIds[0], @"005R0000000Dsl0", @"User ID doesn't match after reload");
}

- (void)testMultipleAccounts {
    // Ensure we start with a clean state
    STAssertEquals(self.uam.allUserIds.count, (NSUInteger)0, @"There should be no accounts");

    // Create 10 users
    for (NSUInteger index=0; index<10; index++) {
        SFUserAccount *user = [self createNewUserWithIndex:index];
        user.credentials.accessToken = [NSString stringWithFormat:@"accesstoken-%d", index];
        STAssertNotNil(user.credentials, @"User credentials shouldn't be nil");
        
        [self.uam addAccount:user];
        // Note: we always use index 0 because of the way the allUserIds are sorted out
        STAssertEqualObjects(self.uam.allUserIds[0], ([NSString stringWithFormat:@"005R0000000Dsl%d", index]), @"User ID doesn't match");
    }
    
    NSError *error = nil;
    STAssertTrue([self.uam saveAccounts:&error], @"Unable to save user accounts: %@", error);

    // Ensure all directories have been correctly created
    {
        for (NSUInteger index=0; index<10; index++) {
            NSString *orgId = [NSString stringWithFormat:@"00D000000000062EA%d", index];
            NSString *userId = [NSString stringWithFormat:@"005R0000000Dsl%d", index];
            NSString *location = [[SFDirectoryManager sharedManager] directoryForOrg:orgId user:userId community:nil type:NSLibraryDirectory components:nil];
            location = [location stringByAppendingPathComponent:@"UserAccount.plist"];
            STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:location], @"Unable to find new UserAccount.plist at %@", location);
        }
    }
    
    // Remove and re-load all accounts
    {
        [self.uam clearAllAccountState];
        STAssertEquals(self.uam.allUserIds.count, (NSUInteger)0, @"There should be no accounts");

        STAssertTrue([self.uam loadAccounts:&error], @"Unable to load user accounts: %@", error);
        
        for (NSUInteger index=0; index<10; index++) {
            // Note: we always use index 0 because of the way the allUserIds are sorted out
            STAssertEqualObjects(self.uam.allUserIds[9-index], ([NSString stringWithFormat:@"005R0000000Dsl%d", index]), @"User ID doesn't match");
        }
    }
    
    // Now make sure each account have different access token to ensure
    // they are not overlapping in the keychain
    for (NSUInteger index=0; index<10; index++) {
        SFUserAccount *user = [self.uam userAccountForUserId:self.uam.allUserIds[9-index]];
        STAssertEqualObjects(user.credentials.accessToken, ([NSString stringWithFormat:@"accesstoken-%d", index]), @"Access token mismatch");
    }
}

#pragma mark - Helper methods

- (SFUserAccount*)createNewUserWithIndex:(NSUInteger)index {
    STAssertTrue(index < 10, @"Supports only index up to 9");
    SFUserAccount *user = [[SFUserAccount alloc] initWithIdentifier:[NSString stringWithFormat:@"identifier-%d", index]];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://login.salesforce.com/id/00D000000000062EA%d/005R0000000Dsl%d", index, index]];
    return user;
}

@end
