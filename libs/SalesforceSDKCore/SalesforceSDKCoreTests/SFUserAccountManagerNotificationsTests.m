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

#import <objc/runtime.h>
#import <XCTest/XCTest.h>
#import "SFUserAccountConstants.h"
#import "SFUserAccountManager+Internal.h"
#import "SFUserAccountPersisterEphemeral.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFOAuthCredentials+Internal.h"

static NSString * const kUserIdFormatString = @"005R0000000Dsl%lu";
static NSString * const kOrgIdFormatString = @"00D000000000062EA%lu";
static NSString * const kSFOAuthAccessToken = @"access_token";
static NSString * const kSFOAuthInstanceUrl = @"instance_url";
static NSString * const kSFOAuthCommunityId = @"sfdc_community_id";
static NSString * const kSFOAuthCommunityUrl = @"sfdc_community_url";

@interface SFUserAccountManagerNotificationsTests : XCTestCase {
    id<SFUserAccountPersister> _origAccountPersister;
    SFUserAccount *_user;
    SFUserAccount *_origCurrentUser;
}

@property (nonatomic, strong) SFUserAccountManager *uam;

@end

@implementation SFUserAccountManagerNotificationsTests

- (void)setUp
{
    [super setUp];
    self.uam = [SFUserAccountManager sharedInstance];
    _origAccountPersister = self.uam.accountPersister;
    _origCurrentUser = self.uam.currentUser;
    self.uam.accountPersister = [SFUserAccountPersisterEphemeral new];
    _user = [self createNewUser:1];
}

- (void)tearDown
{
    [self deleteUserAndVerify:_user];
    self.uam.accountPersister = _origAccountPersister;
    self.uam.currentUser = _origCurrentUser;
    [super tearDown];
}

- (void)testCommunityIdNotificationPosted
{
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:_user.credentials];
    NSDictionary *credentials = @{kSFOAuthCommunityId:@"COMMUNITY_ID"
                                  };
    [self expectationForNotification:SFUserAccountManagerDidChangeUserDataNotification object:nil   handler:^BOOL(NSNotification * notification) {
        SFUserAccountDataChange change = [notification.userInfo[SFUserAccountManagerUserChangeKey] intValue];
        return ( change &  SFUserAccountDataChangeCommunityId)==SFUserAccountDataChangeCommunityId;
    }];
    [coordinator updateCredentials:credentials];
    XCTAssertTrue(coordinator.credentials.credentialsChangeSet!=nil && [coordinator.credentials.credentialsChangeSet count] > 0,@"There should be at least one change in credentials");
    XCTAssertTrue([coordinator.credentials hasPropertyValueChangedForKey:@"communityId"],@"SFUserAccountManager should detect change to properties");
    [self.uam applyCredentials:coordinator.credentials withIdData:nil];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}


- (void)testInstanceUrlChangeNotificationPosted
{
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:_user.credentials];
    
    [self expectationForNotification:SFUserAccountManagerDidChangeUserDataNotification object:nil   handler:^BOOL(NSNotification * notification) {
        SFUserAccountDataChange change = [notification.userInfo[SFUserAccountManagerUserChangeKey] intValue];
        return ( change &  SFUserAccountDataChangeInstanceURL)==SFUserAccountDataChangeInstanceURL;
    }];
    
    NSDictionary *credentials = @{
                                  kSFOAuthInstanceUrl:@"https://new.instance.url"
                                  };
    [coordinator updateCredentials:credentials];
    XCTAssertTrue(coordinator.credentials.credentialsChangeSet!=nil && [coordinator.credentials.credentialsChangeSet count] > 0,@"There should be at least one change in credentials");
    XCTAssertTrue([coordinator.credentials hasPropertyValueChangedForKey:@"instanceUrl"],@"SFUserAccountManager should detect change to instanceUrl");
    [self.uam applyCredentials:coordinator.credentials];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testAccessTokenChangeNotificationPosted
{
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:_user.credentials];
   
    [self expectationForNotification:SFUserAccountManagerDidChangeUserDataNotification object:nil   handler:^BOOL(NSNotification * notification) {
        SFUserAccountDataChange change = [notification.userInfo[SFUserAccountManagerUserChangeKey] intValue];
        return ( change &  SFUserAccountDataChangeAccessToken)==SFUserAccountDataChangeAccessToken;
    }];
    NSDictionary *credentials = @{
                                  kSFOAuthAccessToken:@"new_access_token"
                                  };
    [coordinator updateCredentials:credentials];
    XCTAssertTrue(coordinator.credentials.credentialsChangeSet!=nil && [coordinator.credentials.credentialsChangeSet count] > 0,@"There should be at least one change in credentials");
    XCTAssertTrue([coordinator.credentials hasPropertyValueChangedForKey:@"accessToken"],@"SFUserAccountManager should detect change to instanceUrl");
    [self.uam applyCredentials:coordinator.credentials];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testMultipleChangesNotificationPosted
{
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:_user.credentials];
    SFUserAccountDataChange expectedChange = (SFUserAccountDataChangeCommunityId|SFUserAccountDataChangeInstanceURL|SFUserAccountDataChangeAccessToken);
    
    [self expectationForNotification:SFUserAccountManagerDidChangeUserDataNotification object:nil   handler:^BOOL(NSNotification * notification) {
        SFUserAccountDataChange change = [notification.userInfo[SFUserAccountManagerUserChangeKey] intValue];
        return ( change &  expectedChange)==expectedChange;
    }];
    
   NSDictionary *credentials = @{
                                  kSFOAuthCommunityId:@"COMMUNITY_ID_1",
                                  kSFOAuthAccessToken:@"new_access_token_1",
                                  kSFOAuthInstanceUrl:@"https://new.instance.url1"
                                  };
    [coordinator updateCredentials:credentials];
    XCTAssertTrue(coordinator.credentials.credentialsChangeSet!=nil && [coordinator.credentials.credentialsChangeSet count] > 0,@"There should be at least one change in credentials");
    XCTAssertTrue([coordinator.credentials  hasPropertyValueChangedForKey:@"accessToken"],@"SFUserAccountManager should detect change to accessToken");
    XCTAssertTrue([coordinator.credentials hasPropertyValueChangedForKey:@"communityId"],@"SFUserAccountManager should detect change to communityId");
    XCTAssertTrue([coordinator.credentials hasPropertyValueChangedForKey:@"instanceUrl"],@"SFUserAccountManager should detect change to instanceUrl");
    [self.uam applyCredentials:coordinator.credentials];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
   
}

- (void)testNewUserChangeNotificationPosted
{
    [self expectationForNotification:SFUserAccountManagerDidChangeUserNotification object:nil   handler:^BOOL(NSNotification * notification) {
        return YES;
    }];
    
    SFOAuthCredentials *newUsercredentials = [SFOAuthCredentials new];
    newUsercredentials.userId = [NSString stringWithFormat:kUserIdFormatString, (NSUInteger)2];
    newUsercredentials.organizationId =_user.credentials.organizationId;
    newUsercredentials.instanceUrl = [NSURL URLWithString:@"http://a.new.url"];
    newUsercredentials.communityId = @"NEW_COMMUNITY_ID";
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:newUsercredentials];
    NSDictionary *credentials = @{
                                  kSFOAuthAccessToken:@"new_access_token_1"
                                  };
    [coordinator updateCredentials:credentials];
    [self.uam applyCredentials:coordinator.credentials];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (SFUserAccount*)createNewUser:(NSUInteger) index
{
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

