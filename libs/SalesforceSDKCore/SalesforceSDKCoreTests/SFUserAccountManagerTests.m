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
#import <OCMock/OCMock.h>
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFSDKAuthViewHandler.h"
#import "SFUserAccountManager+Internal.h"
#import "SFDefaultUserAccountPersister.h"
#import "SFSDKOAuthClient.h"
#import "SFSDKOAuthClientConfig.h"

static NSString * const kUserIdFormatString = @"005R0000000Dsl%lu";
static NSString * const kOrgIdFormatString = @"00D000000000062EA%lu";

@interface TestUserAccountManagerDelegate : NSObject <SFUserAccountManagerDelegate>

@property (nonatomic, strong) SFUserAccount *willSwitchOrigUserAccount;
@property (nonatomic, strong) SFUserAccount *willSwitchNewUserAccount;
@property (nonatomic, strong) SFUserAccount *didSwitchOrigUserAccount;
@property (nonatomic, strong) SFUserAccount *didSwitchNewUserAccount;
@property (nonatomic,strong) SFOAuthCredentials *willLoginCredentials;
@property (nonatomic,strong) SFUserAccount *didLoginUserAccount;
@property (nonatomic,strong) NSError *error;

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

- (BOOL)userAccountManager:(SFUserAccountManager *)userAccountManager error:(NSError *)error info:(SFOAuthInfo *)info {
    self.error = error;
    return NO;
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
@property (nonatomic, strong) SFSDKAuthViewHandler *authViewHandler;
@property (nonatomic, strong) SFSDKLoginViewControllerConfig *config;

- (SFUserAccount *)createNewUserWithIndex:(NSUInteger)index;
- (NSArray *)createAndVerifyUserAccounts:(NSUInteger)numAccounts;

@end

@implementation SFUserAccountManagerTests

- (void)setUp {
    [super setUp];
    // Delete the content of the global library directory
    NSString *globalLibraryDirectory = [[SFDirectoryManager sharedManager] directoryForUser:nil type:NSLibraryDirectory components:nil];
    [[[NSFileManager alloc] init] removeItemAtPath:globalLibraryDirectory error:nil];
    // Set the oauth client ID after deleting the content of the global library directory
    // to ensure the SFUserAccountManager sharedInstance loads from an empty directory
    self.uam = [SFUserAccountManager sharedInstance];
    
    // Ensure the user account manager doesn't contain any account
    NSArray *userAccounts = [[SFUserAccountManager sharedInstance] allUserAccounts];
    for (SFUserAccount *account in userAccounts) {
        if (account != [SFUserAccountManager sharedInstance].currentUser) {
            NSError *error = nil;
            [self.uam deleteAccountForUser:account error:&error];
        }
    }
    [self.uam clearAllAccountState];
    self.uam.currentUser = nil;
    self.authViewHandler = [SFUserAccountManager sharedInstance].authViewHandler;
    self.config = self.uam.loginViewControllerConfig;
}

- (void)tearDown {
    [SFUserAccountManager sharedInstance].authViewHandler = self.authViewHandler;
    self.uam.loginViewControllerConfig = self.config;
    [super tearDown];
}


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

- (void)testAccountIdentityEquality {
    NSDictionary *accountIdentityMatrix = @{
                                            @"MatchGroup1": @[
                                                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID1" orgId:@"OrgID1"],
                                                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID1" orgId:@"OrgID1"]
                                                    ],
                                            @"MatchGroup2": @[
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

#pragma clang diagnostic pop

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
    NSString *expectedLocation = [[SFDirectoryManager sharedManager] directoryForOrg:user.credentials.organizationId user:user.credentials.userId community:nil type:NSLibraryDirectory components:nil];
    expectedLocation = [expectedLocation stringByAppendingPathComponent:@"UserAccount.plist"];
    XCTAssertEqualObjects(expectedLocation, [SFDefaultUserAccountPersister userAccountPlistFileForUser:user], @"Mismatching user account paths");
    NSFileManager *fm = [[NSFileManager alloc] init];
    XCTAssertTrue([fm fileExistsAtPath:expectedLocation], @"Unable to find new UserAccount.plist");

    NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)0];
    XCTAssertEqualObjects(((SFUserAccountIdentity *)self.uam.allUserIdentities[0]).userId, userId, @"User ID doesn't match after reload");
     [self deleteUserAndVerify:user userDir:expectedLocation];
}

- (void)testMultipleAccounts {
    // Ensure we start with a clean state
    XCTAssertEqual([self.uam.allUserIdentities count], (NSUInteger)0, @"There should be no accounts");

    // Create 10 users
    [self createAndVerifyUserAccounts:10];
    NSFileManager *fm = [[NSFileManager alloc] init];

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
    
       // Remove and verify that allUserAccounts property implicitly loads the accounts from disk.
    [self.uam clearAllAccountState];
    NSError *error =nil;
    [self.uam loadAccounts:&error];
    XCTAssertNil(error, @"Accounts should have been loaded");
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
        NSString *location = [[SFDirectoryManager sharedManager] directoryForOrg:orgId user:userId community:nil type:NSLibraryDirectory components:nil];
        SFUserAccountIdentity *accountIdentity = [[SFUserAccountIdentity alloc] initWithUserId:userId orgId:orgId];
        
        SFUserAccount *userAccount = [self.uam userAccountForUserIdentity:accountIdentity];
        XCTAssertNotNil(userAccount, @"User acccount with User ID '%@' and Org ID '%@' should exist.", userId, orgId);
        XCTAssertTrue([fm fileExistsAtPath:location], @"User directory for User ID '%@' and Org ID '%@' should exist.", userId, orgId);
        
        [self deleteUserAndVerify:userAccount userDir:location];
    }
     XCTAssertEqual([self.uam allUserAccounts].count, (NSUInteger)0, @"There should be 0 accounts after delete");
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
    XCTAssertNotEqual(self.uam.currentUser, origUser, @"The current user should not be the original user.");
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

- (void)testIdentityDataModification {
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    self.uam.currentUser = accounts[0];
    SFIdentityData *idData = [self sampleIdentityData];
    [self.uam applyIdData:idData forUser:self.uam.currentUser];
    int origMobileAppPinLength = self.uam.currentUser.idData.mobileAppPinLength;
    int origMobileAppScreenLockTimeout = self.uam.currentUser.idData.mobileAppScreenLockTimeout;
    
    // Verify selective custom settings updates do not interfere with other previous identity data.
    NSDictionary *origCustomAttributes = self.uam.currentUser.idData.customAttributes;
    NSDictionary *origCustomPermissions = self.uam.currentUser.idData.customPermissions;
    NSMutableDictionary *mutableCustomAttributes = [origCustomAttributes mutableCopy];
    NSMutableDictionary *mutableCustomPermissions = [origCustomPermissions mutableCopy];
    mutableCustomAttributes[@"ANewCustomAttribute"] = @"ANewCustomAttributeValue";
    mutableCustomPermissions[@"ANewCustomPermission"] = @"ANewCustomPermissionValue";
    [self.uam applyIdDataCustomAttributes:mutableCustomAttributes forUser:self.uam.currentUser];
    [self.uam applyIdDataCustomPermissions:mutableCustomPermissions forUser:self.uam.currentUser];
    XCTAssertTrue([self.uam.currentUser.idData.customAttributes isEqualToDictionary:mutableCustomAttributes], @"Attributes dictionaries are not equal.");
    XCTAssertFalse([self.uam.currentUser.idData.customAttributes isEqualToDictionary:origCustomAttributes], @"Attributes dictionaries should not be equal.");
    XCTAssertTrue([self.uam.currentUser.idData.customPermissions isEqualToDictionary:mutableCustomPermissions], @"Permissions dictionaries are not equal.");
    XCTAssertFalse([self.uam.currentUser.idData.customPermissions isEqualToDictionary:origCustomPermissions], @"Permissions dictionaries should not be equal.");
    XCTAssertEqual(origMobileAppPinLength, self.uam.currentUser.idData.mobileAppPinLength, @"Mobile app pin length should not have changed.");
    XCTAssertEqual(origMobileAppScreenLockTimeout, self.uam.currentUser.idData.mobileAppScreenLockTimeout, @"Mobile app screen lock timeout should not have changed.");
    
    // Verify that re-applying the whole of the identity data, overwrites changes.
    idData = [self sampleIdentityData];
    [self.uam applyIdData:idData forUser:self.uam.currentUser];
    XCTAssertTrue([self.uam.currentUser.idData.customAttributes isEqualToDictionary:origCustomAttributes], @"Custom atttribute changes should have been overwritten with whole identity write.");
    XCTAssertFalse([self.uam.currentUser.idData.customAttributes isEqualToDictionary:mutableCustomAttributes], @"Attributes dictionaries should not be equal.");
    XCTAssertTrue([self.uam.currentUser.idData.customPermissions isEqualToDictionary:origCustomPermissions], @"Custom permission changes should have been overwritten with whole identity write.");
    XCTAssertFalse([self.uam.currentUser.idData.customAttributes isEqualToDictionary:mutableCustomPermissions], @"Permissions dictionaries should not be equal.");
}

- (void)testUserAccountManagerPersistentProperties {
    
    SFOAuthAdvancedAuthConfiguration oldAdvancedAuthConfiguration = [SFUserAccountManager sharedInstance].advancedAuthConfiguration;
    [SFUserAccountManager sharedInstance].advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    XCTAssertEqual([SFUserAccountManager sharedInstance].advancedAuthConfiguration, SFOAuthAdvancedAuthConfigurationRequire, @"SFUserAccountManager advancedAuthConfiguration should be set correctly");
    [SFUserAccountManager sharedInstance].advancedAuthConfiguration = oldAdvancedAuthConfiguration;
    XCTAssertEqual([SFUserAccountManager sharedInstance].advancedAuthConfiguration, oldAdvancedAuthConfiguration, @"SFUserAccountManager advancedAuthConfiguration should be set back correctly");
    
    NSArray *oldAdditionalOAuthParameterKeys = [SFUserAccountManager sharedInstance].additionalOAuthParameterKeys;
    NSArray *addlKeys = @[@"A", @"__B", @"123", @""];
    [SFUserAccountManager sharedInstance].additionalOAuthParameterKeys = addlKeys;
    XCTAssertNotNil([SFUserAccountManager sharedInstance].additionalOAuthParameterKeys,"SFUserAccountManager additionalOAuthParameterKeys should not be nil");
    XCTAssertTrue([[SFUserAccountManager sharedInstance].additionalOAuthParameterKeys count] == [addlKeys count],"SFUserAccountManager additionalOAuthParameterKeys should not be nil");
    [SFUserAccountManager sharedInstance].additionalOAuthParameterKeys = oldAdditionalOAuthParameterKeys;
    
    NSDictionary *oldAdditionalTokenRefreshParams = [SFUserAccountManager sharedInstance].additionalTokenRefreshParams;
    NSDictionary *addlRefreshParams = @ {@"A":@"A",@"B":@"B", @"C":@"C"};
    [SFUserAccountManager sharedInstance].additionalTokenRefreshParams = addlRefreshParams;
    XCTAssertNotNil([SFUserAccountManager sharedInstance].additionalTokenRefreshParams,"SFUserAccountManager additionalTokenRefreshParams should not be nil");
    XCTAssertTrue([[SFUserAccountManager sharedInstance].additionalTokenRefreshParams count] == [addlRefreshParams count],"SFUserAccountManager additionalOAuthParameterKeys should not be nil");
    [SFUserAccountManager sharedInstance].additionalTokenRefreshParams = oldAdditionalTokenRefreshParams;
    
    NSString *oldLoginHost = [SFUserAccountManager sharedInstance].loginHost;;
    NSString *newLoginHost = @"https://sample.test";
    [SFUserAccountManager sharedInstance].loginHost = newLoginHost;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].loginHost, newLoginHost, @"SFUserAccountManager loginHost should be set correctly");
    [SFUserAccountManager sharedInstance].loginHost = oldLoginHost;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].loginHost, oldLoginHost, @"SFUserAccountManager loginHost should be set back correctly");
    
    NSString *oldOauthCompletionUrl = [SFUserAccountManager sharedInstance].oauthCompletionUrl;;
    NSString *newOauthCompletionUrl = @"new://new.url";
    [SFUserAccountManager sharedInstance].oauthCompletionUrl = newOauthCompletionUrl;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].oauthCompletionUrl, newOauthCompletionUrl, @"SFUserAccountManager oauthCompletionUrl should be set correctly");
    [SFUserAccountManager sharedInstance].oauthCompletionUrl = oldOauthCompletionUrl;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].oauthCompletionUrl, oldOauthCompletionUrl, @"SFUserAccountManager oauthCompletionUrl should be set back correctly");
    
    NSString *oldOauthClientId = [SFUserAccountManager sharedInstance].oauthClientId;;
    NSString *newOauthClientId = @"NEW_OAUTH_CLIENT_ID";
    [SFUserAccountManager sharedInstance].oauthClientId = newOauthClientId;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].oauthClientId, newOauthClientId, @"SFUserAccountManager oAuthClientId should be set correctly");
    [SFUserAccountManager sharedInstance].oauthClientId = oldOauthClientId;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].oauthClientId, oldOauthClientId, @"SFUserAccountManager oAuthClientId should be set back correctly");
    
    NSString *oldBrandLoginPath = [SFUserAccountManager sharedInstance].brandLoginPath;;
    NSString *newBrandLoginPath = @"NEW_BRAND";
    [SFUserAccountManager sharedInstance].brandLoginPath = newBrandLoginPath;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].brandLoginPath, newBrandLoginPath, @"SFUserAccountManager brandLoginPath should be set correctly");
    [SFUserAccountManager sharedInstance].brandLoginPath = oldBrandLoginPath;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].brandLoginPath, oldBrandLoginPath, @"SFUserAccountManager brandLoginPath should be set back correctly");
}

- (void)testLogin {
    
    SFOAuthCredentials *credentials = [self populateAuthCredentialsFromConfigFileForClass:self.class];
    XCTestExpectation *refreshExpectation = [self expectationWithDescription:@"refresh"];
    __block SFUserAccount *user = nil;
    [[SFUserAccountManager sharedInstance]
     refreshCredentials:credentials
     completion:^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
         [refreshExpectation fulfill];
         user = userAccount;
     } failure:^(SFOAuthInfo *authInfo, NSError *error) {
     }];
   
    [self waitForExpectations:@[refreshExpectation] timeout:20];
    
}
- (void)testWillLoginNotificationPosted
{
    SFOAuthCredentials *credentials = [self populateAuthCredentialsFromConfigFileForClass:self.class];
    
    NSString *notificationName = kSFNotificationUserWillLogIn;
    
    id observerMock = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:observerMock name:notificationName object:[SFUserAccountManager sharedInstance]];
    
    
    
    __block SFSDKTestRequestListener *authListener = [[SFSDKTestRequestListener alloc] init];
    __block SFUserAccount *user = nil;
    
    [[observerMock expect]
     notificationWithName:notificationName
     object:[SFUserAccountManager sharedInstance]
     userInfo:[OCMArg checkWithBlock:
               ^BOOL(NSDictionary *userInfo) {
                   return userInfo[kSFNotificationUserInfoCredentialsKey]!=nil;
               }]];
    
    [[SFUserAccountManager sharedInstance]
     refreshCredentials:credentials
     completion:^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
         authListener.returnStatus = kTestRequestStatusDidLoad;
         user = userAccount;
     } failure:^(SFOAuthInfo *authInfo, NSError *error) {
         authListener.lastError = error;
         authListener.returnStatus = kTestRequestStatusDidFail;
     }];
    [authListener waitForCompletion];
    [observerMock verify];
    
    [[NSNotificationCenter defaultCenter] removeObserver:observerMock];
}

- (void)testLoginNotificationPosted
{
    SFOAuthCredentials *credentials = [self populateAuthCredentialsFromConfigFileForClass:self.class];
    
    NSString *notificationName = kSFNotificationUserDidLogIn;
    
    id observerMock = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:observerMock name:notificationName object:[SFUserAccountManager sharedInstance]];
    
    
    
    __block SFSDKTestRequestListener *authListener = [[SFSDKTestRequestListener alloc] init];
    __block SFUserAccount *user = nil;
    
    [[observerMock expect]
     notificationWithName:notificationName
     object:[SFUserAccountManager sharedInstance]
     userInfo:[OCMArg checkWithBlock:
               ^BOOL(NSDictionary *userInfo) {
                   return userInfo[kSFNotificationUserInfoAccountKey]!=nil;
               }]];
    
    [[SFUserAccountManager sharedInstance]
     refreshCredentials:credentials
     completion:^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
         authListener.returnStatus = kTestRequestStatusDidLoad;
         user = userAccount;
     } failure:^(SFOAuthInfo *authInfo, NSError *error) {
         authListener.lastError = error;
         authListener.returnStatus = kTestRequestStatusDidFail;
     }];
    [authListener waitForCompletion];
    [observerMock verify];
    
    [[NSNotificationCenter defaultCenter] removeObserver:observerMock];
}

- (void)testAuthHandler {

    XCTestExpectation *expectation = [self expectationWithDescription:@"testAuthHandler"];
    SFSDKAuthViewHandler *authViewHandler = [[SFSDKAuthViewHandler alloc] initWithDisplayBlock:^(SFSDKAuthViewHolder *holder) {
        [expectation fulfill];
    } dismissBlock:^{
        [expectation fulfill];
    }];
    [[SFUserAccountManager sharedInstance] setAuthViewHandler:authViewHandler];
    XCTAssertNotNil(authViewHandler);
    XCTAssertNotNil(authViewHandler.authViewDismissBlock);
    XCTAssertNotNil(authViewHandler.authViewDisplayBlock);
    XCTAssertTrue([SFUserAccountManager sharedInstance].authViewHandler == authViewHandler);
    
    SFOAuthCredentials *credentials = [self populateAuthCredentialsFromConfigFileForClass:self.class];
    credentials.refreshToken = nil;
    SFSDKOAuthClient *client = [[SFUserAccountManager sharedInstance] fetchOAuthClient:credentials completion:nil failure:nil];
    [client refreshCredentials];
    [self waitForExpectations:[NSArray arrayWithObject:expectation] timeout:20];
    [[SFUserAccountManager sharedInstance] disposeOAuthClient:client];
}

- (void)testLoginViewControllerCustomizations {
    
    SFSDKLoginViewControllerConfig *config = [[SFSDKLoginViewControllerConfig alloc] init];
    
    //test defaults
    XCTAssertNotNil(config);
    XCTAssertNil(config.navBarFont);
    XCTAssertNotNil(config.navBarColor);
    XCTAssertTrue(config.showNavbar == YES);
    XCTAssertTrue(config.showSettingsIcon == YES);
    
    config.navBarColor = [UIColor redColor];
    config.navBarFont = [UIFont systemFontOfSize:10.0f];
    config.showNavbar = NO;
    config.showSettingsIcon = NO;
    
    XCTAssertTrue(config.navBarColor == [UIColor redColor], @"SFSDKLoginViewController config nav bar color should have changed" );
    XCTAssertTrue(config.navBarFont == [UIFont systemFontOfSize:10.0f], @"SFSDKLoginViewController config nav bar font should have changed" );
    XCTAssertFalse(config.showNavbar, @"SFSDKLoginViewController nav bar should have been disabled");
    XCTAssertFalse(config.showSettingsIcon, @"SFSDKLoginViewController nav bar settings icon should have been disabled");
    
    [SFUserAccountManager sharedInstance].loginViewControllerConfig = config;
    
    SFOAuthCredentials *credentials = [self populateAuthCredentialsFromConfigFileForClass:self.class];
    credentials.refreshToken = nil;
    
    SFSDKOAuthClient *client = [[SFUserAccountManager sharedInstance] fetchOAuthClient:credentials completion:nil failure:nil];
    XCTAssertTrue(client.config.loginViewControllerConfig == config);
    [[SFUserAccountManager sharedInstance] disposeOAuthClient:client];
}

- (void)testLoginViewCustomizationsBackwardCompatibility {
    
    SFLoginViewController *controller = [SFLoginViewController sharedInstance];
    SFSDKLoginViewControllerConfig *origConfig = controller.config;
    
    controller.navBarColor = [UIColor redColor];
    controller.navBarFont = [UIFont systemFontOfSize:10.0f];
    controller.showNavbar = YES;
    controller.showSettingsIcon = NO;
    
    
    SFSDKLoginViewControllerConfig *config = controller.config;
    
    //test defaults
    XCTAssertNotNil(config);
   
    XCTAssertTrue(config.navBarColor == [UIColor redColor], @"SFSDKLoginViewController config nav bar color should have changed" );
    XCTAssertTrue(config.navBarFont == [UIFont systemFontOfSize:10.0f], @"SFSDKLoginViewController config nav bar font should have changed" );
    XCTAssertTrue(config.showNavbar, @"SFSDKLoginViewController nav bar should have been disabled");
    XCTAssertFalse(config.showSettingsIcon, @"SFSDKLoginViewController nav bar settings icon should have been disabled");
    
    [SFUserAccountManager sharedInstance].loginViewControllerConfig = config;
    
    SFOAuthCredentials *credentials = [self populateAuthCredentialsFromConfigFileForClass:self.class];
    credentials.refreshToken = nil;
    
    SFSDKOAuthClient *client = [[SFUserAccountManager sharedInstance] fetchOAuthClient:credentials completion:nil failure:nil];
    XCTAssertTrue(client.config.loginViewControllerConfig == config);
    [[SFUserAccountManager sharedInstance] disposeOAuthClient:client];
    controller.config = origConfig;
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
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc]initWithIdentifier:[NSString stringWithFormat:@"identifier-%lu", (unsigned long)index] clientId:@"fakeClientIdForTesting" encrypted:YES];
    SFUserAccount *user =[[SFUserAccount alloc] initWithCredentials:credentials];
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

- (SFOAuthCredentials *)populateAuthCredentialsFromConfigFileForClass:(Class)testClass
{
    NSString *tokenPath = [[NSBundle bundleForClass:testClass] pathForResource:@"test_credentials" ofType:@"json"];
    NSAssert(nil != tokenPath, @"Test config file not found!");
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSData *tokenJson = [fm contentsAtPath:tokenPath];
    id jsonResponse = [SFJsonUtils objectFromJSONData:tokenJson];
    NSAssert(jsonResponse != nil, @"Error parsing JSON from config file: %@", [SFJsonUtils lastError]);
    NSDictionary *dictResponse = (NSDictionary *)jsonResponse;
    SFSDKTestCredentialsData *credsData = [[SFSDKTestCredentialsData alloc] initWithDict:dictResponse];
    NSAssert1(nil != credsData.refreshToken &&
              nil != credsData.clientId &&
              nil != credsData.redirectUri &&
              nil != credsData.loginHost &&
              nil != credsData.identityUrl &&
              nil != credsData.instanceUrl, @"config credentials are missing! %@",
              dictResponse);
    
    //check whether the test config file has never been edited
    NSAssert(![credsData.refreshToken isEqualToString:@"__INSERT_TOKEN_HERE__"],
             @"You need to obtain credentials for your test org and replace test_credentials.json");
    [SFUserAccountManager sharedInstance].currentUser = nil;
    [SFUserAccountManager sharedInstance].oauthClientId = credsData.clientId;
    [SFUserAccountManager sharedInstance].oauthCompletionUrl = credsData.redirectUri;
    [SFUserAccountManager sharedInstance].scopes = [NSSet setWithObjects:@"web", @"api", nil];
    [SFUserAccountManager sharedInstance].loginHost = credsData.loginHost;
    SFOAuthCredentials *credentials = [[SFUserAccountManager sharedInstance] newClientCredentials];
    credentials.instanceUrl = [NSURL URLWithString:credsData.instanceUrl];
    credentials.identityUrl = [NSURL URLWithString:credsData.identityUrl];
    NSString *communityUrlString = credsData.communityUrl;
    if (communityUrlString.length > 0) {
        credentials.communityUrl = [NSURL URLWithString:communityUrlString];
    }
    credentials.accessToken = credsData.accessToken;
    credentials.refreshToken = credsData.refreshToken;
    return credentials;
}


@end
