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
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFUserAccountManager+Internal.h"

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

    // Delete the content of the global library directory
    NSString *globalLibraryDirectory = [[SFDirectoryManager sharedManager] directoryForUser:nil type:NSLibraryDirectory components:nil];
    [[[NSFileManager alloc] init] removeItemAtPath:globalLibraryDirectory error:nil];

    // Set the oauth client ID after deleting the content of the global library directory
    // to ensure the SFUserAccountManager sharedInstance loads from an empty directory
    self.uam = [SFUserAccountManager sharedInstance];
    self.uam.oauthClientId = @"fakeClientIdForTesting";

    // Ensure the user account manager doesn't contain any account
    [self.uam clearAllAccountState];
    [self.uam disableAnonymousAccount];
    self.uam.currentUser = nil;
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

- (void)testAnonymousUser {
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    SFUserAccount *origUser = accounts[0];
    XCTAssertNil(self.uam.anonymousUser, @"Anonymous user shouldn't exist yet");
    XCTAssertNil(self.uam.currentUser, @"Current user shouldn't be set yet");
    [self.uam setupAnonymousUser:YES autocreateAnonymousUser:NO];
    XCTAssertNil(self.uam.anonymousUser, @"Anonymous user shouldn't exist yet");
    [self.uam setupAnonymousUser:YES autocreateAnonymousUser:YES];
    XCTAssertNotNil(self.uam.anonymousUser, @"Anonymous user should exist now");
    XCTAssertTrue(self.uam.currentUser == self.uam.anonymousUser, @"Current user should be the anonymous user");
    self.uam.currentUser = origUser;
    XCTAssertTrue(self.uam.anonymousUser.isAnonymousUser, @"Anonymous user should be who he is");
    XCTAssertFalse(self.uam.anonymousUser.isTemporaryUser, @"Anonymous user shouldn't be temporary");
    XCTAssertFalse(self.uam.currentUser.isAnonymousUser, @"Current user shouldn't be anonymous");
    XCTAssertFalse(self.uam.currentUser.isTemporaryUser, @"Current user shouldn't be temporary");
}

- (void)testAnonymousUserFromPreviousVersion {
    XCTAssertNil(self.uam.anonymousUser, @"Anonymous user shouldn't exist yet");
    XCTAssertNil(self.uam.currentUser, @"Current user shouldn't be set yet");
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    SFUserAccount *origUser = accounts[0];
    self.uam.currentUser = origUser;
    [self.uam setupAnonymousUser:YES autocreateAnonymousUser:NO];
    XCTAssertNil(self.uam.anonymousUser, @"Anonymous user shouldn't exist yet");
    [self.uam setupAnonymousUser:YES autocreateAnonymousUser:YES];
    XCTAssertNotNil(self.uam.anonymousUser, @"Anonymous user should exist now");
    XCTAssertTrue(self.uam.currentUser == origUser, @"Current user should be the anonymous user");
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
    @try {
        // On iOS9, unarchiveObjectWithFile should return nil
        id res = [NSKeyedUnarchiver unarchiveObjectWithFile:userFilePath];
        XCTAssertNil(res, @"User account data for User ID '%@' and Org ID '%@' should now be encrypted.", userId, orgId);
    }
    @catch(NSException *e) {
        // Before iOS9, unarchiveObjectWithFile should throw an exception
        XCTAssertNotNil(e, @"User account data for User ID '%@' and Org ID '%@' should now be encrypted.", userId, orgId);
    }
    
    // Remove account.
    [self deleteUserAndVerify:account userDir:userFilePath];
}

- (void)testActiveIdentityUpgrade {

    // Ensure we start with a clean state
    NSUInteger allUserIdenties = [self.uam.allUserIdentities count];
    XCTAssertEqual(allUserIdenties, 0, @"There should be no accounts");

    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    SFUserAccount *newAccount = ((SFUserAccount *)accounts[0]);
    [self.uam switchToUser:newAccount];
    SFUserAccountIdentity *accountIdentity = newAccount.accountIdentity;
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

- (void)testIdentityDataModification {
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    self.uam.currentUser = accounts[0];
    SFIdentityData *idData = [self sampleIdentityData];
    [self.uam applyIdData:idData];
    int origMobileAppPinLength = self.uam.currentUser.idData.mobileAppPinLength;
    int origMobileAppScreenLockTimeout = self.uam.currentUser.idData.mobileAppScreenLockTimeout;
    
    // Verify selective custom settings updates do not interfere with other previous identity data.
    NSDictionary *origCustomAttributes = self.uam.currentUser.idData.customAttributes;
    NSDictionary *origCustomPermissions = self.uam.currentUser.idData.customPermissions;
    NSMutableDictionary *mutableCustomAttributes = [origCustomAttributes mutableCopy];
    NSMutableDictionary *mutableCustomPermissions = [origCustomPermissions mutableCopy];
    mutableCustomAttributes[@"ANewCustomAttribute"] = @"ANewCustomAttributeValue";
    mutableCustomPermissions[@"ANewCustomPermission"] = @"ANewCustomPermissionValue";
    [self.uam applyIdDataCustomAttributes:mutableCustomAttributes];
    [self.uam applyIdDataCustomPermissions:mutableCustomPermissions];
    XCTAssertTrue([self.uam.currentUser.idData.customAttributes isEqualToDictionary:mutableCustomAttributes], @"Attributes dictionaries are not equal.");
    XCTAssertFalse([self.uam.currentUser.idData.customAttributes isEqualToDictionary:origCustomAttributes], @"Attributes dictionaries should not be equal.");
    XCTAssertTrue([self.uam.currentUser.idData.customPermissions isEqualToDictionary:mutableCustomPermissions], @"Permissions dictionaries are not equal.");
    XCTAssertFalse([self.uam.currentUser.idData.customPermissions isEqualToDictionary:origCustomPermissions], @"Permissions dictionaries should not be equal.");
    XCTAssertEqual(origMobileAppPinLength, self.uam.currentUser.idData.mobileAppPinLength, @"Mobile app pin length should not have changed.");
    XCTAssertEqual(origMobileAppScreenLockTimeout, self.uam.currentUser.idData.mobileAppScreenLockTimeout, @"Mobile app screen lock timeout should not have changed.");
    
    // Verify that re-applying the whole of the identity data, overwrites changes.
    idData = [self sampleIdentityData];
    [self.uam applyIdData:idData];
    XCTAssertTrue([self.uam.currentUser.idData.customAttributes isEqualToDictionary:origCustomAttributes], @"Custom atttribute changes should have been overwritten with whole identity write.");
    XCTAssertFalse([self.uam.currentUser.idData.customAttributes isEqualToDictionary:mutableCustomAttributes], @"Attributes dictionaries should not be equal.");
    XCTAssertTrue([self.uam.currentUser.idData.customPermissions isEqualToDictionary:origCustomPermissions], @"Custom permission changes should have been overwritten with whole identity write.");
    XCTAssertFalse([self.uam.currentUser.idData.customAttributes isEqualToDictionary:mutableCustomPermissions], @"Permissions dictionaries should not be equal.");
}

- (void)testGuestUserCreation {
    NSString *guestUserId = @"005000000000000";
    NSString *guestOrgId  = @"00D000000000000";
    NSURL *communityURL = [NSURL URLWithString:@"https://somecommunity.salesforce.com"];
    SFUserAccount *account = [[SFUserAccount alloc] initWithGuestUser];
    account.credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"the-identifier"
                                                                clientId:@"the-client"
                                                               encrypted:YES
                                                             storageType:SFOAuthCredentialsStorageTypeNone];
    account.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://does.not.matter.not-real/id/%@/%@", guestOrgId, guestUserId]];
    account.credentials.instanceUrl = communityURL;
    account.credentials.communityUrl = communityURL;
    
    // Set access token to make network happy
    account.credentials.accessToken = [NSUUID UUID].UUIDString;
    [self.uam addAccount:account];
    
    NSError *localError = nil;
    if (![self.uam saveAccounts:&localError]) {
        XCTAssertNil(localError);
    }
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

- (SFIdentityData *)sampleIdentityData {
    NSDictionary *sampleIdDataDict = @{
                                       @"mobile_phone" : @"+1 4155551234",
                                       @"first_name" : @"Test",
                                       @"mobile_phone_verified" : @YES,
                                       @"active" : @YES,
                                       @"utcOffset" : @(-28800000),
                                       @"username" : @"testuser@fake.salesforce.org",
                                       @"last_modified_date" : @"2013-04-19T22:12:04.000+0000",
                                       @"id" : @"https://test.salesforce.com/id/00DS0000000IDdtWAH/005S0000004y9JkCAF",
                                       @"locale" : @"en_US",
                                       @"urls" : @{
                                               @"users" : @"https://cs1.salesforce.com/services/data/v{version}/chatter/users",
                                               @"search" : @"https://cs1.salesforce.com/services/data/v{version}/search/",
                                               @"metadata" : @"https://cs1.salesforce.com/services/Soap/m/{version}/00DS0000000IDdt",
                                               @"query" : @"https://cs1.salesforce.com/services/data/v{version}/query/",
                                               @"enterprise" : @"https://cs1.salesforce.com/services/Soap/c/{version}/00DS0000000IDdt",
                                               @"profile" : @"https://cs1.salesforce.com/005S0000004y9JkCAF",
                                               @"sobjects" : @"https://cs1.salesforce.com/services/data/v{version}/sobjects/",
                                               @"groups" : @"https://cs1.salesforce.com/services/data/v{version}/chatter/groups",
                                               @"rest" : @"https://cs1.salesforce.com/services/data/v{version}/",
                                               @"feed_items" : @"https://cs1.salesforce.com/services/data/v{version}/chatter/feed-items",
                                               @"recent" : @"https://cs1.salesforce.com/services/data/v{version}/recent/",
                                               @"feeds" : @"https://cs1.salesforce.com/services/data/v{version}/chatter/feeds",
                                               @"partner" : @"https://cs1.salesforce.com/services/Soap/u/{version}/00DS0000000IDdt"
                                               },
                                       @"addr_zip" : @"94105",
                                       @"addr_country" : @"US",
                                       @"asserted_user" : @YES,
                                       @"email_verified" : @YES,
                                       @"nick_name" : @"testuser1.3664094337872896E12",
                                       @"user_id" : @"005S0000004y9JkCAF",
                                       @"is_app_installed" : @YES,
                                       @"user_type" : @"STANDARD",
                                       @"addr_street" : @"123 Test User Ln",
                                       @"timezone" : @"America/Los_Angeles",
                                       @"mobile_policy" : @{
                                               @"pin_length" : @"4",
                                               @"screen_lock" : @"10"
                                               },
                                       @"organization_id" : @"00DS0000000IDdtWAH",
                                       @"addr_city" : @"Testville",
                                       @"addr_state" : @"CA",
                                       @"language" : @"en_US",
                                       @"last_name" : @"User",
                                       @"display_name" : @"Test User",
                                       @"photos" : @{
                                               @"thumbnail" : @"https://c.cs1.content.force.com/profilephoto/729S00000009ZdF/T",
                                               @"picture" : @"https://c.cs1.content.force.com/profilephoto/729S00000009ZdF/F"
                                               },
                                       @"email" : @"testuser@salesforce.nonexistentemail",
                                       @"custom_attributes" : @{
                                               @"TestAttribute1" : @"TestVal1",
                                               @"TestAttribute2" : @"TestVal2"
                                               },
                                       @"custom_permissions": @{
                                               @"CustomPerm1" : @"CustomVal1",
                                               @"CustomPerm2" : @"CustomVal2"
                                               },
                                       @"status" : @{
                                               @"body" : [NSNull null],
                                               @"created_date" : [NSNull null]
                                               }
                                       };
    SFIdentityData *idData = [[SFIdentityData alloc] initWithJsonDict:sampleIdDataDict];
    return idData;
}

@end
