/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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
#import "SFDefaultUserAccountPersister.h"
#import "SFUserAccountPersisterEphemeral.h"
#import "SFUserAccountManager+Internal.h"

static NSString * const kUserIdFormatString = @"005R0000000Dsl%lu";
static NSString * const kOrgIdFormatString = @"00D000000000062EA%lu";

@interface SFUserAccountManagerPersisterTests : XCTestCase {
    id<SFUserAccountPersister> _origAccountPersister;
}

@property (nonatomic, strong) SFUserAccountManager *uam;
@end

@interface TestUserAccountManagerPersisterDelegate : NSObject <SFUserAccountManagerDelegate>

@property (nonatomic, strong) SFUserAccount *willSwitchOrigUserAccount;
@property (nonatomic, strong) SFUserAccount *willSwitchNewUserAccount;
@property (nonatomic, strong) SFUserAccount *didSwitchOrigUserAccount;
@property (nonatomic, strong) SFUserAccount *didSwitchNewUserAccount;

@end

@implementation TestUserAccountManagerPersisterDelegate

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

@implementation SFUserAccountManagerPersisterTests

- (void)setUp {
    [super setUp];
    self.uam = [SFUserAccountManager sharedInstance];
    _origAccountPersister = self.uam.accountPersister;
    self.uam.accountPersister = [SFUserAccountPersisterEphemeral new];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [SFUserAccountManager sharedInstance].accountPersister = _origAccountPersister;
    [super tearDown];
    
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
   
    [self.uam clearAllAccountState];
    // Ensure we start with a clean state
    XCTAssertTrue(self.uam.allUserIdentities.count==0, @"There should be no accounts");

    // Create a single user
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    SFUserAccount *user = accounts[0];
    XCTAssertTrue(self.uam.allUserIdentities.count==1, @"There should be 1 account");
    
    NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)0];
    XCTAssertEqualObjects(((SFUserAccountIdentity *)self.uam.allUserIdentities[0]).userId, userId, @"User ID doesn't match after reload");
    [self deleteUserAndVerify:user];
    XCTAssertTrue(self.uam.allUserIdentities.count==0, @"There should be 0 accounts after delete");
}

- (void)testMultipleAccounts {
    // Ensure we start with a clean state
    [self.uam clearAllAccountState];
    XCTAssertEqual([self.uam.allUserIdentities count], (NSUInteger)0, @"There should be no accounts");

    // Create 10 users
    [self createAndVerifyUserAccounts:10];
    XCTAssertEqual([self.uam allUserAccounts].count, (NSUInteger)10, @"There should be 10 accounts");
    
    // Now make sure each account has a different access token to ensure
    // they are not overlapping in the keychain.
    NSMutableSet *allTokens = [NSMutableSet new];
    NSArray *allIdentities = self.uam.allUserIdentities;
    for (NSUInteger index=0; index<10; index++) {
        SFUserAccount *user = [self.uam userAccountForUserIdentity:allIdentities[index]];
        if (![allTokens containsObject:user.credentials.accessToken]) {
            [allTokens addObject:user.credentials.accessToken];
        }
    }
    XCTAssertEqual(allTokens.count,10, @"Should not contain overlapping tokens");

    // Remove each account and verify that its user folder is gone.
    for (NSUInteger index = 0; index < 10; index++) {
        NSString *orgId = [NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index];
        NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)index];
       
        SFUserAccountIdentity *accountIdentity = [[SFUserAccountIdentity alloc] initWithUserId:userId orgId:orgId];

        SFUserAccount *userAccount = [self.uam userAccountForUserIdentity:accountIdentity];
        XCTAssertNotNil(userAccount, @"User acccount with User ID '%@' and Org ID '%@' should exist.", userId, orgId);
        [self deleteUserAndVerify:userAccount];
    }
     XCTAssertEqual([self.uam allUserAccounts].count, (NSUInteger)0, @"There should be 0 accounts after delete");
}

- (void)testSwitchToUser {
    NSArray *accounts = [self createAndVerifyUserAccounts:2];
    SFUserAccount *origUser = accounts[0];
    SFUserAccount *newUser = accounts[1];
    self.uam.currentUser = origUser;
    TestUserAccountManagerPersisterDelegate *acctDelegate = [[TestUserAccountManagerPersisterDelegate alloc] init];
    [self.uam switchToUser:newUser];
    XCTAssertEqual(acctDelegate.willSwitchOrigUserAccount, origUser, @"origUser is not equal.");
    XCTAssertEqual(acctDelegate.willSwitchNewUserAccount, newUser, @"New user should be the same as the argument to switchToUser.");
    XCTAssertEqual(acctDelegate.didSwitchOrigUserAccount, origUser, @"origUser is not equal.");
    XCTAssertEqual(acctDelegate.didSwitchNewUserAccount, newUser, @"New user should be the same as the argument to switchToUser.");
    XCTAssertEqual(self.uam.currentUser, newUser, @"The current user should be set to newUser.");
    [self deleteUserAndVerify:origUser];
    [self deleteUserAndVerify:newUser];
    XCTAssertEqual([self.uam allUserAccounts].count, (NSUInteger)0, @"There should be 0 accounts after delete");
}

- (void)testSwitchToSameUser {
    SFUserAccount *newUser = self.uam.currentUser = [self createAndVerifyUserAccounts:1][0];
    TestUserAccountManagerPersisterDelegate *acctDelegate = [[TestUserAccountManagerPersisterDelegate alloc] init];
    [self.uam switchToUser:newUser];
    XCTAssertNil(acctDelegate.willSwitchOrigUserAccount, @"No switchToUser action should be taken for same accounts.");
    XCTAssertNil(acctDelegate.willSwitchNewUserAccount, @"No switchToUser action should be taken for same accounts.");
    XCTAssertNil(acctDelegate.didSwitchOrigUserAccount, @"No switchToUser action should be taken for same accounts.");
    XCTAssertNil(acctDelegate.didSwitchNewUserAccount, @"No switchToUser action should be taken for same accounts.");
    
    // Should create a new user with the same identity (but won't persist it).
    SFUserAccount *newUserSameIdentity = [self createNewUserWithIndex:0];
    [self.uam switchToUser:newUserSameIdentity];
    XCTAssertNil(acctDelegate.willSwitchOrigUserAccount, @"No switchToUser action should be taken for accounts with same identity.");
    XCTAssertNil(acctDelegate.willSwitchNewUserAccount, @"No switchToUser action should be taken for accounts with same identity.");
    XCTAssertNil(acctDelegate.didSwitchOrigUserAccount, @"No switchToUser action should be taken for accounts with same identity.");
    XCTAssertNil(acctDelegate.didSwitchNewUserAccount, @"No switchToUser action should be taken for accounts with same identity.");
    
    [self deleteUserAndVerify:newUser];
    XCTAssertEqual([self.uam allUserAccounts].count, (NSUInteger)0, @"There should be 0 accounts after delete");
}

#pragma mark - Helper methods

- (NSArray *)createAndVerifyUserAccounts:(NSUInteger)numAccounts {
    XCTAssertTrue(numAccounts > 0, @"You must create at least one account.");
    NSMutableArray *accounts = [NSMutableArray array];
    for (NSUInteger index = 0; index < numAccounts; index++) {
        SFUserAccount *user = [self createNewUserWithIndex:index];
        user.credentials.accessToken = [NSString stringWithFormat:@"accesstoken-%lu", (unsigned long)index];
        XCTAssertNotNil(user.credentials, @"User credentials shouldn't be nil");
        NSError *error = nil;
        [[SFUserAccountManager sharedInstance] saveAccountForUser:user error:&error];
        XCTAssertNil(error, @"Should be able to create user account");
        // Note: we always use index 0 because of the way the allUserIds are sorted out
        SFUserAccount *userAccount = [self.uam userAccountForUserIdentity:user.accountIdentity];
        XCTAssertEqualObjects(userAccount.accountIdentity.userId, ([NSString stringWithFormat:kUserIdFormatString, (unsigned long)index]), @"User ID doesn't match");
        XCTAssertEqualObjects(userAccount.accountIdentity.orgId, ([NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index]), @"Org ID doesn't match");
        // Add to the output array.
        [accounts addObject:user];
    }

    return accounts;
}

- (SFUserAccount*)createNewUserWithIndex:(NSUInteger)index {
    XCTAssertTrue(index < 10, @"Supports only index up to 9");
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:[NSString stringWithFormat:@"identifier-%lu", (unsigned long)index] clientId:[SFAuthenticationManager sharedManager].oauthClientId encrypted:YES];
    SFUserAccount *user =[[SFUserAccount alloc] initWithCredentials:credentials];
    NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)index];
    NSString *orgId = [NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://login.salesforce.com/id/%@/%@", orgId, userId]];
    return user;
}

- (void)deleteUserAndVerify:(SFUserAccount *)user {
    SFUserAccountIdentity *identity = user.accountIdentity;
    NSError *deleteAccountError = nil;
    [self.uam deleteAccountForUser:user error:&deleteAccountError];
    XCTAssertNil(deleteAccountError, @"Error deleting account with User ID '%@' and Org ID '%@': %@", identity.userId, identity.orgId, [deleteAccountError localizedDescription]);
    SFUserAccount *inMemoryAccount = [self.uam userAccountForUserIdentity:identity];
    XCTAssertNil(inMemoryAccount, @"deleteUser should have removed user account with User ID '%@' and OrgID '%@' from the list of users.", identity.userId, identity.orgId);
}

@end
