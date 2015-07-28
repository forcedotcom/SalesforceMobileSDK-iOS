//
//  SFUserAccountManagerTests.m
//  SalesforceSDKCore
//
//  Created by Jean Bovet on 2/18/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SFUserAccountManager.h"
#import "SFUserAccount.h"
#import "SFDirectoryManager.h"

static NSString * const kUserIdFormatString = @"005R0000000Dsl%lu";
static NSString * const kOrgIdFormatString = @"00D000000000062EA%lu";

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
@interface SFUserAccountManagerTests : XCTestCase

@property (nonatomic, strong) SFUserAccountManager *uam;

- (SFUserAccount *)createNewUserWithIndex:(NSUInteger)index;
- (NSArray *)createAndVerifyUserAccounts:(NSUInteger)numAccounts;

@end

@implementation SFUserAccountManagerTests

- (void)setUp {
    [SFUserAccountManager sharedInstance].oauthClientId = @"fakeClientIdForTesting";

    // Delete the content of the global library directory
    NSString *globalLibraryDirectory = [[SFDirectoryManager sharedManager] directoryForUser:nil type:NSLibraryDirectory components:nil];
    [[[NSFileManager alloc] init] removeItemAtPath:globalLibraryDirectory error:nil];

    // Ensure the user account manager doesn't contain any account
    self.uam = [SFUserAccountManager sharedInstance];
    [self.uam clearAllAccountState];
    [super setUp];
}

- (void)testAccountIdentityEquality {
    NSDictionary *accountIdentityMatrix = @{
                                            @"MatchGroup1": @[
                                                    [[SFUserAccountIdentity alloc] initWithUserId:nil orgId:nil],
                                                    [[SFUserAccountIdentity alloc] initWithUserId:nil orgId:nil]
                                                    ],
                                            @"MatchGroup2": @[
                                                    [[SFUserAccountIdentity alloc] initWithUserId:nil orgId:@"OrgID1"],
                                                    [[SFUserAccountIdentity alloc] initWithUserId:nil orgId:@"OrgID1"]
                                                    ],
                                            @"MatchGroup3": @[
                                                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID1" orgId:nil],
                                                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID1" orgId:nil]
                                                    ],
                                            @"MatchGroup4": @[
                                                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID1" orgId:@"OrgID1"],
                                                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID1" orgId:@"OrgID1"]
                                                    ],
                                            @"MatchGroup5": @[
                                                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID2" orgId:@"OrgID2"],
                                                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID2" orgId:@"OrgID2"]
                                                    ]
                                            };
    NSArray *keys = [accountIdentityMatrix allKeys];
    for (NSUInteger i = 0; i < [keys count]; i++) {
        
        // Equality
        NSArray *equalIdentitiesArray = accountIdentityMatrix[keys[i]];
        for (NSUInteger j = 0; j < [equalIdentitiesArray count]; j++) {
            SFUserAccountIdentity *obj1 = equalIdentitiesArray[j];
            for (NSUInteger k = 0; k < [equalIdentitiesArray count]; k++) {
                SFUserAccountIdentity *obj2 = equalIdentitiesArray[k];
                XCTAssertEqualObjects(obj1, obj2, @"Account identity '%@' and '%@' should be equal", obj1, obj2);
            }
        }
        
        // Inequality
        for (NSUInteger j = 0; j < [equalIdentitiesArray count]; j++) {
            SFUserAccountIdentity *obj1 = equalIdentitiesArray[j];
            for (NSUInteger k = 0; k < [keys count]; k++) {
                if (k == i) continue;
                NSArray *unequalIdentitiesArray = accountIdentityMatrix[keys[k]];
                for (NSUInteger l = 0; l < [unequalIdentitiesArray count]; l++) {
                    SFUserAccountIdentity *obj2 = unequalIdentitiesArray[l];
                    XCTAssertFalse([obj1 isEqual:obj2], @"Account identity '%@' and '%@' should NOT be equal", obj1, obj2);
                }
            }
        }
    }
}

- (void)testTempUserMatchesTempIdentity {
    SFUserAccount *tempUserAccount = self.uam.temporaryUser;
    SFUserAccountIdentity *tempUserIdentity = self.uam.temporaryUserIdentity;
    XCTAssertEqualObjects(tempUserAccount.accountIdentity, tempUserIdentity, @"Temporary user identities not equal.");
}

- (void)testAccountIdentityUpdateFromCredentialsUpdate {
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    SFUserAccount *user = accounts[0];
    XCTAssertEqual(user.accountIdentity.userId, user.credentials.userId, @"Account identity UserID and credentials User ID should be equal.");
    XCTAssertEqual(user.accountIdentity.orgId, user.credentials.organizationId, @"Account identity UserID and credentials User ID should be equal.");
    
    // Changed credentials IDs.
    user.credentials.userId = @"NewUserId";
    user.credentials.organizationId = @"NewOrgId";
    XCTAssertEqual(user.accountIdentity.userId, @"NewUserId", @"Updated User ID in credentials not reflected in account identity.");
    XCTAssertEqual(user.accountIdentity.orgId, @"NewOrgId", @"Updated Org ID in credentials not reflected in account identity.");
    
    // Swap out credentials entirely.
    NSString *newCredentialsIdentifier = [NSString stringWithFormat:@"%@_1", user.credentials.identifier];
    SFOAuthCredentials *newCreds = [[SFOAuthCredentials alloc] initWithIdentifier:newCredentialsIdentifier clientId:user.credentials.clientId encrypted:YES];
    newCreds.userId = @"NewCredsUserId";
    newCreds.organizationId = @"NewCredsOrgId";
    user.credentials = newCreds;
    XCTAssertEqual(user.accountIdentity.userId, @"NewCredsUserId", @"User ID in new credentials not reflected in account identity.");
    XCTAssertEqual(user.accountIdentity.orgId, @"NewCredsOrgId", @"Org ID in new credentials not reflected in account identity.");
}

- (void)testSingleAccount {
    // Ensure we start with a clean state
    XCTAssertEqual([self.uam.allUserIdentities count], (NSUInteger)0, @"There should be no accounts");
    
    // Create a single user
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    SFUserAccount *user = accounts[0];
    // Check if the UserAccount.plist is stored at the right location
    NSError *error = nil;
    XCTAssertTrue([self.uam saveAccounts:&error], @"Unable to save user accounts: %@", error);
    
    NSString *expectedLocation = [[SFDirectoryManager sharedManager] directoryForOrg:user.credentials.organizationId user:user.credentials.userId community:nil type:NSLibraryDirectory components:nil];
    expectedLocation = [expectedLocation stringByAppendingPathComponent:@"UserAccount.plist"];
    XCTAssertEqualObjects(expectedLocation, [SFUserAccountManager userAccountPlistFileForUser:user], @"Mismatching user account paths");
    NSFileManager *fm = [[NSFileManager alloc] init];
    XCTAssertTrue([fm fileExistsAtPath:expectedLocation], @"Unable to find new UserAccount.plist");
    
    // Now remove all the users and re-load
    [self.uam clearAllAccountState];
    XCTAssertEqual([self.uam.allUserIdentities count], (NSUInteger)0, @"There should be no accounts");

    XCTAssertTrue([self.uam loadAccounts:&error], @"Unable to load user accounts: %@", error);
    NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)0];
    XCTAssertEqualObjects(((SFUserAccountIdentity *)self.uam.allUserIdentities[0]).userId, userId, @"User ID doesn't match after reload");
}

- (void)testMultipleAccounts {
    // Ensure we start with a clean state
    XCTAssertEqual([self.uam.allUserIdentities count], (NSUInteger)0, @"There should be no accounts");

    // Create 10 users
    [self createAndVerifyUserAccounts:10];
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSError *error = nil;
    XCTAssertTrue([self.uam saveAccounts:&error], @"Unable to save user accounts: %@", error);

    // Ensure all directories have been correctly created
    {
        for (NSUInteger index=0; index<10; index++) {
            NSString *orgId = [NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index];
            NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)index];
            NSString *location = [[SFDirectoryManager sharedManager] directoryForOrg:orgId user:userId community:nil type:NSLibraryDirectory components:nil];
            location = [location stringByAppendingPathComponent:@"UserAccount.plist"];
            XCTAssertTrue([fm fileExistsAtPath:location], @"Unable to find new UserAccount.plist at %@", location);
        }
    }
    
    // Remove and re-load all accounts
    {
        [self.uam clearAllAccountState];
        XCTAssertEqual([self.uam.allUserIdentities count], (NSUInteger)0, @"There should be no accounts");

        XCTAssertTrue([self.uam loadAccounts:&error], @"Unable to load user accounts: %@", error);
        
        for (NSUInteger index=0; index<10; index++) {
            XCTAssertEqualObjects(((SFUserAccountIdentity *)self.uam.allUserIdentities[index]).userId, ([NSString stringWithFormat:kUserIdFormatString, (unsigned long)index]), @"User ID doesn't match");
            XCTAssertEqualObjects(((SFUserAccountIdentity *)self.uam.allUserIdentities[index]).orgId, ([NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index]), @"Org ID doesn't match");
        }
    }
    
    // Remove and verify that allUserAccounts property implicitly loads the accounts from disk.
    [self.uam clearAllAccountState];
    XCTAssertEqual([self.uam.allUserIdentities count], (NSUInteger)0, @"There should be no accounts.");
    XCTAssertEqual([self.uam.allUserAccounts count], (NSUInteger)10, @"Should still be 10 accounts on disk.");
    XCTAssertEqual([self.uam.allUserIdentities count], (NSUInteger)10, @"There should now be 10 accounts in memory.");
    
    // Now make sure each account has a different access token to ensure
    // they are not overlapping in the keychain.
    for (NSUInteger index=0; index<10; index++) {
        SFUserAccount *user = [self.uam userAccountForUserIdentity:self.uam.allUserIdentities[index]];
        XCTAssertEqualObjects(user.credentials.accessToken, ([NSString stringWithFormat:@"accesstoken-%lu", (unsigned long)index]), @"Access token mismatch");
    }
    
    // Remove each account and verify that its user folder is gone.
    for (NSUInteger index = 0; index < 10; index++) {
        NSString *orgId = [NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index];
        NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)index];
        NSString *location = [[SFDirectoryManager sharedManager] directoryForOrg:orgId user:userId community:nil type:NSLibraryDirectory components:nil];
        SFUserAccountIdentity *accountIdentity = [[SFUserAccountIdentity alloc] initWithUserId:userId orgId:orgId];
        
        SFUserAccount *userAccount = [self.uam userAccountForUserIdentity:accountIdentity];
        XCTAssertNotNil(userAccount, @"User acccount with User ID '%@' and Org ID '%@' should exist.", userId, orgId);
        XCTAssertTrue([fm fileExistsAtPath:location], @"User directory for User ID '%@' and Org ID '%@' should exist.", userId, orgId);
        
        [self deleteUserAndVerify:userAccount userDir:location];
    }
}

- (void)testTemporaryAccount {
    SFUserAccount *tempAccount1 = [self.uam userAccountForUserIdentity:self.uam.temporaryUserIdentity];
    XCTAssertNil(tempAccount1, @"Temp account should not be defined here.");
    SFUserAccount *tempAccount2 = self.uam.temporaryUser;
    XCTAssertNotNil(tempAccount2, @"Temp account should be created through the temporaryUser property.");
    tempAccount1 = [self.uam userAccountForUserIdentity:self.uam.temporaryUserIdentity];
    XCTAssertEqual(tempAccount1, tempAccount2, @"Temp account references should be equal.");
}

- (void)testSwitchToNewUser {
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    SFUserAccount *origUser = accounts[0];
    self.uam.currentUser = origUser;
    TestUserAccountManagerDelegate *acctDelegate = [[TestUserAccountManagerDelegate alloc] init];
    [self.uam switchToNewUser];
    XCTAssertEqual(acctDelegate.willSwitchOrigUserAccount, origUser, @"origUser is not equal.");
    XCTAssertNil(acctDelegate.willSwitchNewUserAccount, @"New user should be nil.");
    XCTAssertEqual(acctDelegate.didSwitchOrigUserAccount, origUser, @"origUser is not equal.");
    XCTAssertNil(acctDelegate.didSwitchNewUserAccount, @"New user should be nil.");
    XCTAssertEqual(self.uam.currentUser, self.uam.temporaryUser, @"The current user should be set to the temporary user.");
}

- (void)testSwitchToUser {
    NSArray *accounts = [self createAndVerifyUserAccounts:2];
    SFUserAccount *origUser = accounts[0];
    SFUserAccount *newUser = accounts[1];
    self.uam.currentUser = origUser;
    TestUserAccountManagerDelegate *acctDelegate = [[TestUserAccountManagerDelegate alloc] init];
    [self.uam switchToUser:newUser];
    XCTAssertEqual(acctDelegate.willSwitchOrigUserAccount, origUser, @"origUser is not equal.");
    XCTAssertEqual(acctDelegate.willSwitchNewUserAccount, newUser, @"New user should be the same as the argument to switchToUser.");
    XCTAssertEqual(acctDelegate.didSwitchOrigUserAccount, origUser, @"origUser is not equal.");
    XCTAssertEqual(acctDelegate.didSwitchNewUserAccount, newUser, @"New user should be the same as the argument to switchToUser.");
    XCTAssertEqual(self.uam.currentUser, newUser, @"The current user should be set to newUser.");
}

- (void)testPlaintextToEncryptedAccountUpgrade {
    // Create and store plaintext user account (old format).
    SFUserAccount *user = [self createAndVerifyUserAccounts:1][0];
    NSString *userFilePath = [SFUserAccountManager userAccountPlistFileForUser:user];
    XCTAssertTrue([NSKeyedArchiver archiveRootObject:user toFile:userFilePath], @"Could not write plaintext user data to '%@'", userFilePath);
    
    NSError *loadAccountsError = nil;
    XCTAssertTrue([self.uam loadAccounts:&loadAccountsError], @"Error loading accounts: %@", [loadAccountsError localizedDescription]);
    
    // Verify user information is still available after a new load.
    NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)0];
    NSString *orgId = [NSString stringWithFormat:kOrgIdFormatString, (unsigned long)0];
    SFUserAccountIdentity *accountIdentity = [[SFUserAccountIdentity alloc] initWithUserId:userId orgId:orgId];
    SFUserAccount *account = [self.uam userAccountForUserIdentity:accountIdentity];
    XCTAssertNotNil(account, @"User acccount with User ID '%@' and Org ID '%@' should exist.", userId, orgId);
    NSFileManager *fm = [[NSFileManager alloc] init];
    XCTAssertTrue([fm fileExistsAtPath:userFilePath], @"User directory for User ID '%@' and Org ID '%@' should exist.", userId, orgId);
    
    // Verify that the user data is now encrypted on the filesystem.
    XCTAssertThrows([NSKeyedUnarchiver unarchiveObjectWithFile:userFilePath], @"User account data for User ID '%@' and Org ID '%@' should now be encrypted.", userId, orgId);
    
    // Remove account.
    [self deleteUserAndVerify:account userDir:userFilePath];
}

- (void)testActiveIdentityUpgrade {
    // Ensure we start with a clean state
    XCTAssertEqual([self.uam.allUserIdentities count], (NSUInteger)0, @"There should be no accounts");
    
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    SFUserAccountIdentity *accountIdentity = ((SFUserAccount *)accounts[0]).accountIdentity;
    SFUserAccountIdentity *activeIdentity = self.uam.activeUserIdentity;
    XCTAssertEqualObjects(accountIdentity, activeIdentity, @"Active identity should be account identity.");
    
    NSError *error = nil;
    XCTAssertTrue([self.uam saveAccounts:&error], @"Unable to save user accounts: %@", error);
    
    // Setup legacy active user id
    NSString *userId = accountIdentity.userId;
    [self.uam clearAllAccountState];
    self.uam.activeUserIdentity = nil;
    [[NSUserDefaults standardUserDefaults] setObject:userId forKey:@"LastUserId"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Reload accounts, verify updates.
    XCTAssertTrue([self.uam loadAccounts:&error], @"Load accounts failed: %@", [error localizedDescription]);
    SFUserAccount *verifyAccount = [self.uam userAccountForUserIdentity:accountIdentity];
    XCTAssertNotNil(verifyAccount, @"Original account should have been reloaded.");
    SFUserAccountIdentity *verifyActiveUserIdentity = self.uam.activeUserIdentity;
    XCTAssertEqualObjects(verifyAccount.accountIdentity, verifyActiveUserIdentity, @"Active user identity should have been upgraded from legacy data.");
    XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:@"LastUserId"], @"Legacy active user ID should have been removed.");
}

#pragma mark - Helper methods

- (NSArray *)createAndVerifyUserAccounts:(NSUInteger)numAccounts {
    XCTAssertTrue(numAccounts > 0, @"You must create at least one account.");
    NSMutableArray *accounts = [NSMutableArray array];
    for (NSUInteger index = 0; index < numAccounts; index++) {
        SFUserAccount *user = [self createNewUserWithIndex:index];
        user.credentials.accessToken = [NSString stringWithFormat:@"accesstoken-%lu", (unsigned long)index];
        XCTAssertNotNil(user.credentials, @"User credentials shouldn't be nil");
        
        [self.uam addAccount:user];
        // Note: we always use index 0 because of the way the allUserIds are sorted out
        XCTAssertEqualObjects(((SFUserAccountIdentity *)self.uam.allUserIdentities[[self.uam.allUserIdentities count] - 1]).userId, ([NSString stringWithFormat:kUserIdFormatString, (unsigned long)index]), @"User ID doesn't match");
        XCTAssertEqualObjects(((SFUserAccountIdentity *)self.uam.allUserIdentities[[self.uam.allUserIdentities count] - 1]).orgId, ([NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index]), @"Org ID doesn't match");
        
        // Add to the output array.
        [accounts addObject:user];
    }
    
    return accounts;
}

- (SFUserAccount*)createNewUserWithIndex:(NSUInteger)index {
    XCTAssertTrue(index < 10, @"Supports only index up to 9");
    SFUserAccount *user = [[SFUserAccount alloc] initWithIdentifier:[NSString stringWithFormat:@"identifier-%lu", (unsigned long)index]];
    NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)index];
    NSString *orgId = [NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://login.salesforce.com/id/%@/%@", orgId, userId]];
    return user;
}

- (void)deleteUserAndVerify:(SFUserAccount *)user userDir:(NSString *)userDir {
    SFUserAccountIdentity *identity = user.accountIdentity;
    NSError *deleteAccountError = nil;
    [self.uam deleteAccountForUser:user error:&deleteAccountError];
    XCTAssertNil(deleteAccountError, @"Error deleting account with User ID '%@' and Org ID '%@': %@", identity.userId, identity.orgId, [deleteAccountError localizedDescription]);
    NSFileManager *fm = [[NSFileManager alloc] init];
    XCTAssertFalse([fm fileExistsAtPath:userDir], @"User directory for User ID '%@' and Org ID '%@' should be removed.", identity.userId, identity.orgId);
    SFUserAccount *inMemoryAccount = [self.uam userAccountForUserIdentity:identity];
    XCTAssertNil(inMemoryAccount, @"deleteUser should have removed user account with User ID '%@' and OrgID '%@' from the list of users.", identity.userId, identity.orgId);
}

@end
