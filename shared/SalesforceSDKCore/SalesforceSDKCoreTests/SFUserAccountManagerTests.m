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

@interface TestUserAccountManagerDelegate : NSObject <SFUserAccountManagerDelegate>

@property (nonatomic, strong) SFUserAccount *willSwitchOrigUserAccount;
@property (nonatomic, strong) SFUserAccount *willSwitchNewUserAccount;
@property (nonatomic, strong) SFUserAccount *didSwitchOrigUserAccount;
@property (nonatomic, strong) SFUserAccount *didSwitchNewUserAccount;

@end

@implementation TestUserAccountManagerDelegate

- (id)init {
    self = [super init];
    if (self) {
        [[SFUserAccountManager sharedInstance] addDelegate:self];
    }
    return self;
}

- (void)dealloc {
    [[SFUserAccountManager sharedInstance] removeDelegate:self];
}

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
        willSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser {
    self.willSwitchOrigUserAccount = fromUser;
    self.willSwitchNewUserAccount = toUser;
}

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         didSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser {
    self.didSwitchOrigUserAccount = fromUser;
    self.didSwitchNewUserAccount = toUser;
}

@end

/** Unit tests for the SFUserAccountManager
 */
@interface SFUserAccountManagerTests : SenTestCase

@property (nonatomic, strong) SFUserAccountManager *uam;

- (SFUserAccount *)createNewUserWithIndex:(NSUInteger)index;
- (NSArray *)createAndVerifyUserAccounts:(NSUInteger)numAccounts;

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
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    SFUserAccount *user = accounts[0];
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
    [self createAndVerifyUserAccounts:10];
    
    NSError *error = nil;
    STAssertTrue([self.uam saveAccounts:&error], @"Unable to save user accounts: %@", error);

    // Ensure all directories have been correctly created
    {
        for (NSUInteger index=0; index<10; index++) {
            NSString *orgId = [NSString stringWithFormat:@"00D000000000062EA%lu", (unsigned long)index];
            NSString *userId = [NSString stringWithFormat:@"005R0000000Dsl%lu", (unsigned long)index];
            NSString *location = [[SFDirectoryManager sharedManager] directoryForOrg:orgId user:userId community:nil type:NSLibraryDirectory components:nil];
            location = [location stringByAppendingPathComponent:@"UserAccount.plist"];
            STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:location], @"Unable to find new UserAccount.plist at %@", location);
        }
    }
    
    // Remove and re-load all accounts
    {
        [self.uam clearAllAccountState];
        STAssertEquals([self.uam.allUserIds count], (NSUInteger)0, @"There should be no accounts");

        STAssertTrue([self.uam loadAccounts:&error], @"Unable to load user accounts: %@", error);
        
        for (NSUInteger index=0; index<10; index++) {
            // Note: we always use index 0 because of the way the allUserIds are sorted out
            STAssertEqualObjects(self.uam.allUserIds[9-index], ([NSString stringWithFormat:@"005R0000000Dsl%lu", (unsigned long)index]), @"User ID doesn't match");
        }
    }
    
    // Remove and verify that allUserAccounts property implicitly loads the accounts from disk.
    [self.uam clearAllAccountState];
    STAssertEquals([self.uam.allUserIds count], (NSUInteger)0, @"There should be no accounts.");
    STAssertEquals([self.uam.allUserAccounts count], (NSUInteger)10, @"Should still be 10 accounts on disk.");
    STAssertEquals([self.uam.allUserIds count], (NSUInteger)10, @"There should now be 10 accounts in memory.");
    
    // Now make sure each account has a different access token to ensure
    // they are not overlapping in the keychain.
    for (NSUInteger index=0; index<10; index++) {
        SFUserAccount *user = [self.uam userAccountForUserId:self.uam.allUserIds[9-index]];
        STAssertEqualObjects(user.credentials.accessToken, ([NSString stringWithFormat:@"accesstoken-%lu", (unsigned long)index]), @"Access token mismatch");
    }
    
    // Remove each account and verify that its user folder is gone.
    for (NSUInteger index = 0; index < 10; index++) {
        NSString *orgId = [NSString stringWithFormat:@"00D000000000062EA%lu", (unsigned long)index];
        NSString *userId = [NSString stringWithFormat:@"005R0000000Dsl%lu", (unsigned long)index];
        NSString *location = [[SFDirectoryManager sharedManager] directoryForOrg:orgId user:userId community:nil type:NSLibraryDirectory components:nil];
        
        STAssertNotNil([self.uam userAccountForUserId:userId], @"User acccount with ID '%@' should exist.", userId);
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:location], @"User directory for ID '%@' should exist.", userId);
        
        NSError *deleteAccountError = nil;
        [self.uam deleteAccountForUserId:userId error:&deleteAccountError];
        STAssertNil(deleteAccountError, @"Error deleting account with ID '%@': %@", userId, [deleteAccountError localizedDescription]);
        STAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:location], @"User directory for ID '%@' should be removed.", userId);
    }
}

- (void)testTemporaryAccount {
    SFUserAccount *tempAccount1 = [self.uam userAccountForUserId:SFUserAccountManagerTemporaryUserAccountId];
    STAssertNil(tempAccount1, @"Temp account should not be defined here.");
    SFUserAccount *tempAccount2 = self.uam.temporaryUser;
    STAssertNotNil(tempAccount2, @"Temp account should be created through the temporaryUser property.");
    tempAccount1 = [self.uam userAccountForUserId:SFUserAccountManagerTemporaryUserAccountId];
    STAssertEquals(tempAccount1, tempAccount2, @"Temp account references should be equal.");
}

- (void)testSwitchToNewUser {
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    SFUserAccount *origUser = accounts[0];
    self.uam.currentUser = origUser;
    TestUserAccountManagerDelegate *acctDelegate = [[TestUserAccountManagerDelegate alloc] init];
    [self.uam switchToNewUser];
    STAssertEquals(acctDelegate.willSwitchOrigUserAccount, origUser, @"origUser is not equal.");
    STAssertNil(acctDelegate.willSwitchNewUserAccount, @"New user should be nil.");
    STAssertEquals(acctDelegate.didSwitchOrigUserAccount, origUser, @"origUser is not equal.");
    STAssertNil(acctDelegate.didSwitchNewUserAccount, @"New user should be nil.");
    STAssertEquals(self.uam.currentUser, self.uam.temporaryUser, @"The current user should be set to the temporary user.");
}

- (void)testSwitchToUser {
    NSArray *accounts = [self createAndVerifyUserAccounts:2];
    SFUserAccount *origUser = accounts[0];
    SFUserAccount *newUser = accounts[1];
    self.uam.currentUser = origUser;
    TestUserAccountManagerDelegate *acctDelegate = [[TestUserAccountManagerDelegate alloc] init];
    [self.uam switchToUser:newUser];
    STAssertEquals(acctDelegate.willSwitchOrigUserAccount, origUser, @"origUser is not equal.");
    STAssertEquals(acctDelegate.willSwitchNewUserAccount, newUser, @"New user should be the same as the argument to switchToUser.");
    STAssertEquals(acctDelegate.didSwitchOrigUserAccount, origUser, @"origUser is not equal.");
    STAssertEquals(acctDelegate.didSwitchNewUserAccount, newUser, @"New user should be the same as the argument to switchToUser.");
    STAssertEquals(self.uam.currentUser, newUser, @"The current user should be set to newUser.");
}

- (void)testPlaintextToEncryptedAccountUpgrade {
    // Create and store plaintext user account (old format).
    SFUserAccount *user = [self createAndVerifyUserAccounts:1][0];
    NSString *userFilePath = [SFUserAccountManager userAccountPlistFileForUser:user];
    STAssertTrue([NSKeyedArchiver archiveRootObject:user toFile:userFilePath], @"Could not write plaintext user data to '%@'", userFilePath);
    
    NSError *loadAccountsError = nil;
    STAssertTrue([self.uam loadAccounts:&loadAccountsError], @"Error loading accounts: %@", [loadAccountsError localizedDescription]);
    
    // Verify user information is still available after a new load.
    NSString *userId = @"005R0000000Dsl0";
    STAssertNotNil([self.uam userAccountForUserId:userId], @"User acccount with ID '%@' should exist.", userId);
    STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:userFilePath], @"User directory for ID '%@' should exist.", userId);
    
    // Verify that the user data is now encrypted on the filesystem.
    STAssertThrows([NSKeyedUnarchiver unarchiveObjectWithFile:userFilePath], @"User account data for '%@' should now be encrypted.", userId);
    
    // Remove account.
    NSError *deleteAccountError = nil;
    [self.uam deleteAccountForUserId:userId error:&deleteAccountError];
    STAssertNil(deleteAccountError, @"Error deleting account with ID '%@': %@", userId, [deleteAccountError localizedDescription]);
    STAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:userFilePath], @"User directory for ID '%@' should be removed.", userId);
}

#pragma mark - Helper methods

- (NSArray *)createAndVerifyUserAccounts:(NSUInteger)numAccounts {
    STAssertTrue(numAccounts > 0, @"You must create at least one account.");
    NSMutableArray *accounts = [NSMutableArray array];
    for (NSUInteger index = 0; index < numAccounts; index++) {
        SFUserAccount *user = [self createNewUserWithIndex:index];
        user.credentials.accessToken = [NSString stringWithFormat:@"accesstoken-%lu", (unsigned long)index];
        STAssertNotNil(user.credentials, @"User credentials shouldn't be nil");
        
        [self.uam addAccount:user];
        // Note: we always use index 0 because of the way the allUserIds are sorted out
        STAssertEqualObjects(self.uam.allUserIds[0], ([NSString stringWithFormat:@"005R0000000Dsl%lu", (unsigned long)index]), @"User ID doesn't match");
        
        // Add to the output array.
        [accounts addObject:user];
    }
    
    return accounts;
}

- (SFUserAccount*)createNewUserWithIndex:(NSUInteger)index {
    STAssertTrue(index < 10, @"Supports only index up to 9");
    SFUserAccount *user = [[SFUserAccount alloc] initWithIdentifier:[NSString stringWithFormat:@"identifier-%lu", (unsigned long)index]];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://login.salesforce.com/id/00D000000000062EA%lu/005R0000000Dsl%lu", (unsigned long)index, (unsigned long)index]];
    return user;
}

@end
