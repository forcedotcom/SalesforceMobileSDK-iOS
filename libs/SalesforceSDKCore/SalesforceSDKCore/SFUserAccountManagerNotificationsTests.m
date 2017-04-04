//
//  SFUserAccountManagerNotificationsTests.m
//  SalesforceSDKCore
//
//  Created by Raj Rao on 4/3/17.
//  Copyright © 2017 salesforce.com. All rights reserved.
//
#import <objc/runtime.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "SFAuthenticationManager+Internal.h"
#import "SFUserAccountManager+Internal.h"
#import "SFUserAccountPersisterEphemeral.h"
#import "SFOAuthCoordinator+Internal.h"
#import "CSFNetwork+Internal.h"

static NSString * const kUserIdFormatString = @"005R0000000Dsl%lu";
static NSString * const kOrgIdFormatString = @"00D000000000062EA%lu";
static NSString * const kSFOAuthAccessToken = @"access_token";
static NSString * const kSFOAuthInstanceUrl = @"instance_url";
static NSString * const kSFOAuthCommunityId = @"sfdc_community_id";
static NSString * const kSFOAuthCommunityUrl = @"sfdc_community_url";


@interface CSFNetwork(SalesforceNetworkMock)
- (void)setupSalesforceObserver;
@property (nonatomic) void(^completionBlock)(BOOL) ;

@end

@implementation CSFNetwork(SalesforceNetworkMock)
@dynamic completionBlock;
NSString const *key = @"completionBlockKey";

- (void) setCompletionBlock:(void (^)(BOOL))completionBlock {
     objc_setAssociatedObject(self, &key, [completionBlock copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void (^)(BOOL)) completionBlock {
   return objc_getAssociatedObject(self, &key);
}

- (void)setupSalesforceObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userAccountManagerDidChangeCurrentUser:)
                                                 name:SFUserAccountManagerDidChangeUserDataNotification
                                               object:nil];
}

- (void)removeSalesforceObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark SFAuthenticationManagerDelegate
- (void)userAccountManagerDidChangeCurrentUser:(NSNotification*)notification {
    SFUserAccountManager *accountManager = (SFUserAccountManager*)notification.object;
    SFUserAccountChange change = (SFUserAccountChange)[notification.userInfo[SFUserAccountManagerUserChangeKey] integerValue];
    
    if ([accountManager isKindOfClass:[SFUserAccountManager class]]
        && (change & (SFUserAccountChangeCurrentUser|SFUserAccountChangeCommunityId))) {
        if ([accountManager.currentUserIdentity isEqual:self.account.accountIdentity] &&
            ![accountManager.currentCommunityId isEqualToString:self.defaultConnectCommunityId])
        {
            
            if (self.completionBlock)
                self.completionBlock(YES);
            return;
        }
    }
    if (self.completionBlock)
        self.completionBlock(NO);
}

@end

@interface MOCKCSFAction : CSFSalesforceAction
- (void)removeSalesforceObserver;
@property (nonatomic) void (^actionCompletionBlock)(BOOL,SFUserAccountChange);
@property (nonatomic, weak) CSFNetwork *enqueuedNetwork;

@end

@implementation MOCKCSFAction
@dynamic enqueuedNetwork;
@synthesize actionCompletionBlock = _actionCompletionBlock;

- (void)removeSalesforceObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)userAccountManagerDidChangeUserDataNotification:(NSNotification*)notification {
    SFUserAccountManager *accountManager = (SFUserAccountManager*)notification.object;
    
    if ([accountManager isKindOfClass:[SFUserAccountManager class]]) {
        
        NSString *userId = notification.userInfo[SFUserAccountManagerUserChangeUserIdKey];
        NSString *orgId = notification.userInfo[SFUserAccountManagerUserChangeOrgIdKey];
        SFUserAccountIdentity *identity = [[SFUserAccountIdentity alloc] initWithUserId:userId orgId:orgId];
        SFUserAccountChange change = (SFUserAccountChange)[notification.userInfo[SFUserAccountManagerUserChangeKey] integerValue];
        
        if ([self requiresAuthentication] && [self.enqueuedNetwork.account.accountIdentity isEqual:identity]) {
            if (change & SFUserAccountChangeCommunityId) {
                self.actionCompletionBlock(YES,change);
                return;
            }
            SFUserAccountChange credsChanged = SFUserAccountChangeInstanceURL | SFUserAccountChangeAccessToken;
            if ((change & credsChanged) == credsChanged) {
                self.actionCompletionBlock(YES,change);
                return;
            }
           
        }
    }
    self.actionCompletionBlock(NO,SFUserAccountChangeUnknown);
}
@end

@interface SFUserAccountManagerNotificationsTests : XCTestCase {
    id<SFUserAccountPersister> _origAccountPersister;
    SFUserAccount *_user;
    SFUserAccount *_origCurrentUser;
}
@property (nonatomic, strong) SFUserAccountManager *uam;

@end

@implementation SFUserAccountManagerNotificationsTests

- (void)setUp {
    [super setUp];
    self.uam = [SFUserAccountManager sharedInstance];
    _origAccountPersister = self.uam.accountPersister;
    _origCurrentUser = self.uam.currentUser;
    self.uam.accountPersister = [SFUserAccountPersisterEphemeral new];
    _user = [self createNewUser:1];
}

- (void)tearDown {
    [self deleteUserAndVerify:_user];
    self.uam.accountPersister = _origAccountPersister;
    self.uam.currentUser = _origCurrentUser;
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

- (void)testNotficationReceivedForSetCurrentUserWithCSFNetwork {
    
    SFOAuthCredentials *credentials1 = [[SFOAuthCredentials alloc] initWithIdentifier:@"the-identifier"
                                                                            clientId:@"the-client"
                                                                           encrypted:NO
                                                                         storageType:SFOAuthCredentialsStorageTypeNone];

    SFOAuthCredentials *credentials2 = [[SFOAuthCredentials alloc] initWithIdentifier:@"the-identifier-1"
                                                                            clientId:@"the-client-1"
                                                                           encrypted:NO
                                                                         storageType:SFOAuthCredentialsStorageTypeNone];
    SFUserAccount *user1 = [[SFUserAccountManager sharedInstance]  createUserAccount:credentials1];
    user1.credentials.accessToken = @"AccessToken";
    user1.credentials.refreshToken = @"RefreshToken";
    user1.credentials.instanceUrl = [NSURL URLWithString:@"http://example.org"];
    user1.credentials.identityUrl = [NSURL URLWithString:@"https://example.org/id/orgID/userID"];
    user1.credentials.communityId = @"OLD_COMMUNITY_ID";
    NSError *error = nil;
    [[SFUserAccountManager sharedInstance] saveAccountForUser:user1 error:&error];
    XCTAssertNil(error);
   
    SFUserAccount *user2 = [[SFUserAccountManager sharedInstance]  createUserAccount:credentials2];
    user2.credentials.accessToken = @"AccessToken1";
    user2.credentials.refreshToken = @"RefreshToken1";
    user2.credentials.instanceUrl = [NSURL URLWithString:@"http://example1.org/"];
    user2.credentials.identityUrl = [NSURL URLWithString:@"https://example1.org/id/orgID/userID-1"];
    [[SFUserAccountManager sharedInstance] saveAccountForUser:user2 error:&error];

    XCTAssertNil(error);
    XCTestExpectation *expectation = [self expectationWithDescription:@"user changed"];
    
    CSFNetwork *network = [[CSFNetwork alloc] initWithUserAccount:user1];
    
    //[network setupSalesforceObserver];
    network.completionBlock = ^(BOOL communityIdChanged) {
         // ignore the communityIdChanged flag here only applies the for same user
        [expectation fulfill];
    };
   
    self.uam.currentUser = user2;
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        XCTAssertNil(error);
        [network removeSalesforceObserver];
    }];
    [self deleteUserAndVerify:user1];
    [self deleteUserAndVerify:user2];
    
}

- (void)testNotficationReceivedForCommunityIdChangeWithCSFNetwork {
    _user.credentials.communityId = @"NEW_COMMUNITY_ID";
    self.uam.currentUser = _user;

    XCTestExpectation *expectation = [self expectationWithDescription:@"user changed"];
    CSFNetwork *network = [[CSFNetwork alloc] initWithUserAccount:_user];
    network.defaultConnectCommunityId = @"OLD_COMMUNITY_ID";
    
    //[network setupSalesforceObserver];
    network.completionBlock = ^(BOOL communityIdChanged) {
        if (communityIdChanged)
            [expectation fulfill];
    };
    
    [self.uam applyCredentials:_user.credentials withIdData:nil andChange:SFUserAccountChangeCommunityId];
    
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        XCTAssertNil(error);
        [network removeSalesforceObserver];
    }];
}

- (void)testNotficationReceivedForCommunityIdChangeWithCSFAction {
    _user.credentials.communityId = @"NEW_COMMUNITY_ID";
    self.uam.currentUser = _user;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"user changed"];
    CSFNetwork *network = [[CSFNetwork alloc] initWithUserAccount:_user];
    network.defaultConnectCommunityId = @"OLD_COMMUNITY_ID";
    
    MOCKCSFAction *action = [MOCKCSFAction new];
    action.enqueuedNetwork = network;
    action.requiresAuthentication = YES;
    action.actionCompletionBlock = ^(BOOL success,SFUserAccountChange change) {
        if (change & SFUserAccountChangeCommunityId)
            [expectation fulfill];
    };
    
    [self.uam applyCredentials:_user.credentials withIdData:nil andChange:SFUserAccountChangeCommunityId];
    
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        XCTAssertNil(error);
        [network removeSalesforceObserver];
    }];
}

- (void)testNotficationReceivedForCredentialsChangeWithCSFAction {
    _user.credentials.communityId = @"NEW_COMMUNITY_ID";
    _user.credentials.accessToken = @"__CHANGED_ACCESS_TOKEN";
    _user.credentials.instanceUrl = [NSURL URLWithString:@"http://changed.instance.url"];
    self.uam.currentUser = _user;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"user changed"];
    CSFNetwork *network = [[CSFNetwork alloc] initWithUserAccount:_user];
    network.defaultConnectCommunityId = @"OLD_COMMUNITY_ID";
    
    MOCKCSFAction *action = [MOCKCSFAction new];
    action.enqueuedNetwork = network;
    action.requiresAuthentication = YES;
    action.actionCompletionBlock = ^(BOOL success,SFUserAccountChange change) {
        if (change & (SFUserAccountChangeAccessToken|SFUserAccountChangeInstanceURL))
            [expectation fulfill];
    };
    
    [self.uam applyCredentials:_user.credentials withIdData:nil andChange:SFUserAccountChangeAccessToken|SFUserAccountChangeInstanceURL];
    
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        XCTAssertNil(error);
        [network removeSalesforceObserver];
    }];
}

- (SFUserAccount*)createNewUser:(NSUInteger) index {
  
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc]initWithIdentifier:[NSString stringWithFormat:@"identifier-%lu",index] clientId:@"fakeClientIdForTesting" encrypted:YES];
    
    credentials.accessToken = nil;
    credentials.refreshToken = nil;
    credentials.instanceUrl = nil;

    SFUserAccount *user =[[SFUserAccount alloc] initWithCredentials:credentials];
    NSString *userId = [NSString stringWithFormat:kUserIdFormatString, index];
    NSString *orgId = [NSString stringWithFormat:kOrgIdFormatString, index];
    credentials.communityId = orgId;
    credentials.userId = userId;
    
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
