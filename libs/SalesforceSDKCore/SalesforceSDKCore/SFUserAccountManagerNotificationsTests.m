//
//  SFUserAccountManagerNotificationsTests.m
//  SalesforceSDKCore
//
//  Created by Raj Rao on 4/3/17.
//  Copyright © 2017 salesforce.com. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "SFAuthenticationManager+Internal.h"
#import "SFUserAccountManager+Internal.h"
#import "SFUserAccountPersisterEphemeral.h"
#import "SFOAuthCoordinator+Internal.h"
static NSString * const kUserIdFormatString = @"005R0000000Dsl%lu";
static NSString * const kOrgIdFormatString = @"00D000000000062EA%lu";
static NSString * const kSFOAuthAccessToken = @"access_token";
static NSString * const kSFOAuthInstanceUrl = @"instance_url";
static NSString * const kSFOAuthCommunityId = @"sfdc_community_id";
static NSString * const kSFOAuthCommunityUrl = @"sfdc_community_url";

@interface SFUserAccountManagerNotificationsTests : XCTestCase {
    id<SFUserAccountPersister> _origAccountPersister;
    SFUserAccount *_user;
}

@property (nonatomic, strong) SFUserAccountManager *uam;

@end

@implementation SFUserAccountManagerNotificationsTests

- (void)setUp {
    [super setUp];
    self.uam = [SFUserAccountManager sharedInstance];
    _origAccountPersister = self.uam.accountPersister;
    self.uam.accountPersister = [SFUserAccountPersisterEphemeral new];
    _user = [self createNewUser:@"NOT-1-USER"];
    
}

- (void)tearDown {
    [self deleteUserAndVerify:_user];
    self.uam.accountPersister = _origAccountPersister;
    [super tearDown];
}

- (void)testNotificationNotPosted
{
    NSString *notificationName = SFUserAccountManagerDidChangeUserDataNotification;
    
    id observerMock = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:observerMock name:notificationName object:self.uam];
    NSDictionary *credentials = @{
                                  
                                  };
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:_user.credentials];
    SFAuthenticationManager * authenticationManager = [SFAuthenticationManager sharedManager];
    authenticationManager.coordinator = coordinator;
    
    [coordinator updateCredentials:credentials];
    XCTAssertTrue(coordinator.credentialsChangeSet==nil || [coordinator.credentialsChangeSet count] < 1,@"There should not be any changes to existing credentials");
    SFUserAccountChange changeSet = [authenticationManager userAccountChangeFromDict:coordinator.credentialsChangeSet];
    
    XCTAssertTrue(changeSet==SFUserAccountChangeUnknown,@"SFAuthenticationManager should not detect changes to known credential properties");
    
    [self.uam applyCredentials:coordinator.credentials withIdData:nil andChange:changeSet];
    
    [[NSNotificationCenter defaultCenter] removeObserver:observerMock];
}

- (void)testCommunityIdNotificationPosted
{
    NSString *notificationName = SFUserAccountManagerDidChangeUserDataNotification;
    
    id observerMock = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:observerMock name:notificationName object:self.uam];
    
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:_user.credentials];
    SFAuthenticationManager * authenticationManager = [SFAuthenticationManager sharedManager];
    authenticationManager.coordinator = coordinator;
    
    NSDictionary *expectedUserInfo = @{
                                       SFUserAccountManagerUserChangeKey: @(SFUserAccountChangeCommunityId),
                                       SFUserAccountManagerUserChangeUserIdKey: _user.accountIdentity.userId,
                                       SFUserAccountManagerUserChangeOrgIdKey: _user.accountIdentity.orgId
                                       };
    
    [[observerMock expect] notificationWithName:notificationName object:self.uam userInfo:expectedUserInfo];
    
    NSDictionary *credentials = @{kSFOAuthCommunityId:@"COMMUNITY_ID"
                                  };
    
    [coordinator updateCredentials:credentials];
    XCTAssertTrue(coordinator.credentialsChangeSet!=nil && [coordinator.credentialsChangeSet count] > 0,@"There should not be at least one change in credentials");
    SFUserAccountChange changeSet = [authenticationManager userAccountChangeFromDict:coordinator.credentialsChangeSet];
    
    XCTAssertTrue(changeSet==SFUserAccountChangeCommunityId,@"SFAuthenticationManager should detect change to properties");
    
    [self.uam applyCredentials:coordinator.credentials withIdData:nil andChange:changeSet];
    
    [observerMock verify];
    [[NSNotificationCenter defaultCenter] removeObserver:observerMock];
}

- (void)testInstanceUrlChangeNotificationPosted
{
    NSString *notificationName = SFUserAccountManagerDidChangeUserDataNotification;
    
    id observerMock = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:observerMock name:notificationName object:self.uam];
    
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:_user.credentials];
    SFAuthenticationManager * authenticationManager = [SFAuthenticationManager sharedManager];
    authenticationManager.coordinator = coordinator;
    
    NSDictionary *expectedUserInfo = @{
                                       SFUserAccountManagerUserChangeKey: @(SFUserAccountChangeInstanceURL),
                                       SFUserAccountManagerUserChangeUserIdKey: _user.accountIdentity.userId,
                                       SFUserAccountManagerUserChangeOrgIdKey: _user.accountIdentity.orgId
                                       };
    
    [[observerMock expect] notificationWithName:notificationName object:self.uam userInfo:expectedUserInfo];
    
    NSDictionary *credentials = @{
                                  kSFOAuthInstanceUrl:@"https://new.instance.url"
                                  };
    
    [coordinator updateCredentials:credentials];
    XCTAssertTrue(coordinator.credentialsChangeSet!=nil && [coordinator.credentialsChangeSet count] > 0,@"There should not be at least one change in credentials");
    SFUserAccountChange changeSet = [authenticationManager userAccountChangeFromDict:coordinator.credentialsChangeSet];
    
    XCTAssertTrue(changeSet==SFUserAccountChangeInstanceURL,@"SFAuthenticationManager should detect change to properties");
    
    [self.uam applyCredentials:coordinator.credentials withIdData:nil andChange:changeSet];
    
    [observerMock verify];
    [[NSNotificationCenter defaultCenter] removeObserver:observerMock];
}

- (void)testAccessTokenChangeNotificationPosted
{
    NSString *notificationName = SFUserAccountManagerDidChangeUserDataNotification;
    
    id observerMock = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:observerMock name:notificationName object:self.uam];
    
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:_user.credentials];
    SFAuthenticationManager * authenticationManager = [SFAuthenticationManager sharedManager];
    authenticationManager.coordinator = coordinator;
    
    NSDictionary *expecTedUserInfo = @{
                                       SFUserAccountManagerUserChangeKey: @(SFUserAccountChangeAccessToken),
                                       SFUserAccountManagerUserChangeUserIdKey: _user.accountIdentity.userId,
                                       SFUserAccountManagerUserChangeOrgIdKey: _user.accountIdentity.orgId
                                       };
    
    [[observerMock expect] notificationWithName:notificationName object:self.uam userInfo:expecTedUserInfo];
    
    NSDictionary *credentials = @{
                                  kSFOAuthAccessToken:@"new_access_token"
                                  };
    
    [coordinator updateCredentials:credentials];
    XCTAssertTrue(coordinator.credentialsChangeSet!=nil && [coordinator.credentialsChangeSet count] > 0,@"There should not be at least one change in credentials");
    SFUserAccountChange changeSet = [authenticationManager userAccountChangeFromDict:coordinator.credentialsChangeSet];
    
    XCTAssertTrue(changeSet==SFUserAccountChangeAccessToken,@"SFAuthenticationManager should detect change to properties");
    
    [self.uam applyCredentials:coordinator.credentials withIdData:nil andChange:changeSet];
    
    [observerMock verify];
    [[NSNotificationCenter defaultCenter] removeObserver:observerMock];
}

- (void)testMultipleChangesNotificationPosted
{
    NSString *notificationName = SFUserAccountManagerDidChangeUserDataNotification;
    
    id observerMock = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:observerMock name:notificationName object:self.uam];
    
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:_user.credentials];
    SFAuthenticationManager * authenticationManager = [SFAuthenticationManager sharedManager];
    authenticationManager.coordinator = coordinator;
    SFUserAccountChange expectedChange = (SFUserAccountChangeCommunityId|SFUserAccountChangeInstanceURL|SFUserAccountChangeAccessToken);
    NSDictionary *expecTedUserInfo = @{
                                       SFUserAccountManagerUserChangeKey: @(expectedChange),
                                       SFUserAccountManagerUserChangeUserIdKey: _user.accountIdentity.userId,
                                       SFUserAccountManagerUserChangeOrgIdKey: _user.accountIdentity.orgId
                                       };
    
    [[observerMock expect] notificationWithName:notificationName object:self.uam userInfo:expecTedUserInfo];
    
    NSDictionary *credentials = @{
                                  kSFOAuthCommunityId:@"COMMUNITY_ID_1",
                                  kSFOAuthAccessToken:@"new_access_token_1",
                                  kSFOAuthInstanceUrl:@"https://new.instance.url1"
                                  };
    
    [coordinator updateCredentials:credentials];
    XCTAssertTrue(coordinator.credentialsChangeSet!=nil && [coordinator.credentialsChangeSet count] > 1,@"There should notmore than one change in credentials");
    SFUserAccountChange changeSet = [authenticationManager userAccountChangeFromDict:coordinator.credentialsChangeSet];
    
    XCTAssertTrue(changeSet==expectedChange,@"SFAuthenticationManager should detect change to properties");
    
    [self.uam applyCredentials:coordinator.credentials withIdData:nil andChange:changeSet];
    
    [observerMock verify];
    [[NSNotificationCenter defaultCenter] removeObserver:observerMock];
}

- (void)testNewUserChangeNotificationPosted
{
    NSString *notificationName = SFUserAccountManagerDidChangeUserDataNotification;
    
    id observerMock = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:observerMock name:notificationName object:self.uam];
    
    SFOAuthCredentials *newUsercredentials = [SFOAuthCredentials new];
    newUsercredentials.userId = [NSString stringWithFormat:kUserIdFormatString, (NSUInteger)2];
    newUsercredentials.organizationId =_user.credentials.organizationId;
    newUsercredentials.instanceUrl = [NSURL URLWithString:@"http://a.new.url"];
    newUsercredentials.communityId = @"NEW_COMMUNITY_ID";
    
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:newUsercredentials];
    SFAuthenticationManager * authenticationManager = [SFAuthenticationManager sharedManager];
    authenticationManager.coordinator = coordinator;
    SFUserAccountChange expectedChange = SFUserAccountChangeNewUser;
    NSDictionary *expecTedUserInfo = @{
                                       SFUserAccountManagerUserChangeKey: @(expectedChange),
                                       SFUserAccountManagerUserChangeUserIdKey: newUsercredentials.userId,
                                       SFUserAccountManagerUserChangeOrgIdKey: newUsercredentials.organizationId
                                       };
    
    [[observerMock expect] notificationWithName:notificationName object:self.uam userInfo:expecTedUserInfo];
    
    NSDictionary *credentials = @{
                                  kSFOAuthAccessToken:@"new_access_token_1"
                                  };
    
    [coordinator updateCredentials:credentials];
    XCTAssertTrue(coordinator.credentialsChangeSet!=nil && [coordinator.credentialsChangeSet count] > 0,@"There should be changes in credentials");
    SFUserAccountChange changeSet = [authenticationManager userAccountChangeFromDict:coordinator.credentialsChangeSet];
    
    XCTAssertTrue(changeSet==SFUserAccountChangeAccessToken,@"SFAuthenticationManager should detect a change in access token");
    
    [self.uam applyCredentials:coordinator.credentials withIdData:nil andChange:changeSet];
    
    [observerMock verify];
    [[NSNotificationCenter defaultCenter] removeObserver:observerMock];
}


- (void)testCurrentUserChangeNotificationPosted
{
    NSString *notificationName = SFUserAccountManagerDidChangeUserDataNotification;
    
    id observerMock = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:observerMock name:notificationName object:self.uam];
    
    SFOAuthCredentials *newUsercredentials = [SFOAuthCredentials new];
    newUsercredentials.userId = [NSString stringWithFormat:kUserIdFormatString, (NSUInteger)2];
    newUsercredentials.organizationId =_user.credentials.organizationId;
    newUsercredentials.instanceUrl = [NSURL URLWithString:@"http://a.new.url"];
    newUsercredentials.communityId = @"NEW_COMMUNITY_ID";
    
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:newUsercredentials];
    SFAuthenticationManager * authenticationManager = [SFAuthenticationManager sharedManager];
    authenticationManager.coordinator = coordinator;
    SFUserAccountChange expectedChange = SFUserAccountChangeNewUser;
    NSDictionary *expecTedUserInfo = @{
                                       SFUserAccountManagerUserChangeKey: @(expectedChange),
                                       SFUserAccountManagerUserChangeUserIdKey: newUsercredentials.userId,
                                       SFUserAccountManagerUserChangeOrgIdKey: newUsercredentials.organizationId
                                       };
    
    [[observerMock expect] notificationWithName:notificationName object:self.uam userInfo:expecTedUserInfo];
    
    NSDictionary *credentials = @{
                                  kSFOAuthAccessToken:@"new_access_token_1"
                                  };
    
    [coordinator updateCredentials:credentials];
    XCTAssertTrue(coordinator.credentialsChangeSet!=nil && [coordinator.credentialsChangeSet count] > 0,@"There should be changes in credentials");
    SFUserAccountChange changeSet = [authenticationManager userAccountChangeFromDict:coordinator.credentialsChangeSet];
    
    XCTAssertTrue(changeSet==SFUserAccountChangeAccessToken,@"SFAuthenticationManager should detect a change in access token");
    
    [self.uam applyCredentials:coordinator.credentials withIdData:nil andChange:changeSet];
    
    [observerMock verify];
    
    // now onto current user
    expectedChange = SFUserAccountChangeCurrentUser|SFUserAccountChangeOrgId|SFUserAccountChangeUserId;
    expecTedUserInfo = @{
                         SFUserAccountManagerUserChangeKey: @(expectedChange),
                         SFUserAccountManagerUserChangeUserIdKey: _user.accountIdentity.userId,
                         SFUserAccountManagerUserChangeOrgIdKey: _user.accountIdentity.orgId
                         };
    
    [[observerMock expect] notificationWithName:notificationName object:self.uam userInfo:expecTedUserInfo];
    self.uam.currentUser = _user;
    [observerMock verify];
    [[NSNotificationCenter defaultCenter] removeObserver:observerMock];
    
}


- (SFUserAccount*)createNewUser:(NSString *) identifier {
    
    NSUInteger index = 1;
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc]initWithIdentifier:[NSString stringWithFormat:@"identifier-%lu",index] clientId:@"fakeClientIdForTesting" encrypted:YES];
    
    credentials.accessToken = nil;
    credentials.refreshToken = nil;
    credentials.instanceUrl = nil;
    credentials.communityId = nil;
    credentials.userId = nil;
    
    
    SFUserAccount *user =[[SFUserAccount alloc] initWithCredentials:credentials];
    NSString *userId = [NSString stringWithFormat:kUserIdFormatString, index];
    NSString *orgId = [NSString stringWithFormat:kOrgIdFormatString, index];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://login.salesforce.com/id/%@/%@", orgId, userId]];
    
    NSError *saveAccountError = nil;
    [self.uam saveAccountForUser:user error:&saveAccountError];
    
    XCTAssertNil(saveAccountError, @"User Should have been created for Notifications Test");
    return user;
}

- (void)deleteUserAndVerify:(SFUserAccount *) user {
    SFUserAccountIdentity *identity = user.accountIdentity;
    NSError *deleteAccountError = nil;
    [self.uam deleteAccountForUser:user error:&deleteAccountError];
    XCTAssertNil(deleteAccountError, @"Error deleting account with User ID '%@' and Org ID '%@': %@", identity.userId, identity.orgId, [deleteAccountError localizedDescription]);
    SFUserAccount *inMemoryAccount = [self.uam userAccountForUserIdentity:identity];
    XCTAssertNil(inMemoryAccount, @"deleteUser should have removed user account with User ID '%@' and OrgID '%@' from the list of users.", identity.userId, identity.orgId);
}

@end
