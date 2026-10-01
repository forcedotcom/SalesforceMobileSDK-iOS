/*
 SFOAuthCredentialsTests.m
 SalesforceSDKCoreTests
 
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFOAuthCredentials.h"
#import "SFOAuthCredentials+Internal.h"

@interface SFOAuthCredentialsTests : XCTestCase

@end

@implementation SFOAuthCredentialsTests

- (void)testUpdateCredentialsNotEncryptedNotStored {
    [self tryUpdateCredentials:FALSE storageType:SFOAuthCredentialsStorageTypeNone];
}

- (void)testUpdateCredentialsEncryptedNotStored {
    [self tryUpdateCredentials:TRUE storageType:SFOAuthCredentialsStorageTypeNone];
}

- (void)testUpdateCredentialsNotEncryptedStored {
    [self tryUpdateCredentials:FALSE storageType:SFOAuthCredentialsStorageTypeKeychain];
}

- (void)testUpdateCredentialsEncryptedStored {
    [self tryUpdateCredentials:TRUE storageType:SFOAuthCredentialsStorageTypeKeychain];
}


- (void)tryUpdateCredentials:(BOOL)encrypted storageType:(SFOAuthCredentialsStorageType)storageType {
    // Creating SFOAuthCredentials
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"test_auth_creds" clientId:@"test_client_id" encrypted:encrypted storageType:storageType];

    // Prepare dictionary with credentials
    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
    [params setObject:@"test-auth-token" forKey:@"access_token"];
    [params setObject:@"test-refresh-token" forKey:@"refresh_token"];
    [params setObject:@"https://instance.salesforce.com" forKey:@"instance_url"];
    [params setObject:@"https://api.salesforce.com" forKey:@"api_instance_url"];
    [params setObject:@"api refresh_token" forKey:@"scope"];
    [params setObject:@"https://id.salesforce.com" forKey:@"id"];
    [params setObject:@"test-community-id" forKey:@"sfdc_community_id"];
    [params setObject:@"https://community.salesforce.com" forKey:@"sfdc_community_url"];
    [params setObject:@"test-lightning-domain" forKey:@"lightning_domain"];
    [params setObject:@"test-lightning-sid" forKey:@"lightning_sid"];
    [params setObject:@"test-vf-domain" forKey:@"visualforce_domain"];
    [params setObject:@"test-vf-sid" forKey:@"visualforce_sid"];
    [params setObject:@"test-content-domain" forKey:@"content_domain"];
    [params setObject:@"test-content-sid" forKey:@"content_sid"];
    [params setObject:@"test-csrf-token" forKey:@"csrf_token"];
    [params setObject:@"test-cookie-client-src" forKey:@"cookie-clientSrc"];
    [params setObject:@"test-cookie-sid-client" forKey:@"cookie-sid_Client"];
    [params setObject:@"test-sid-cookie-name" forKey:@"sidCookieName"];
    [params setObject:@"test-parent-sid" forKey:@"parent_sid"];
    [params setObject:@"test-token-format" forKey:@"token_format"];
    [params setObject:@"test-token-type" forKey:@"token_type"];
    [params setObject:@"test-beacon-child-consumer-key" forKey:@"auto_installed_app_org_consumer_key"];
    [params setObject:@"test-beacon-child-consumer-secret" forKey:@"auto_installed_app_org_consumer_secret"];
    [creds updateCredentials:params];
    
    // Check updated SFOAuthCredentials
    XCTAssertEqualObjects(creds.accessToken, @"test-auth-token");
    XCTAssertEqualObjects(creds.refreshToken, @"test-refresh-token");
    XCTAssertEqualObjects(creds.instanceUrl.absoluteString, @"https://instance.salesforce.com");
    XCTAssertEqualObjects(creds.apiInstanceUrl.absoluteString, @"https://api.salesforce.com");
    XCTAssertEqualObjects(creds.scopes, (@[@"api", @"refresh_token"]));
    XCTAssertEqualObjects(creds.identityUrl.absoluteString, @"https://id.salesforce.com");
    XCTAssertEqualObjects(creds.communityId, @"test-community-id");
    XCTAssertEqualObjects(creds.communityUrl.absoluteString, @"https://community.salesforce.com");
    XCTAssertEqualObjects(creds.lightningDomain, @"test-lightning-domain");
    XCTAssertEqualObjects(creds.lightningSid, @"test-lightning-sid");
    XCTAssertEqualObjects(creds.vfDomain, @"test-vf-domain");
    XCTAssertEqualObjects(creds.vfSid, @"test-vf-sid");
    XCTAssertEqualObjects(creds.contentDomain, @"test-content-domain");
    XCTAssertEqualObjects(creds.contentSid, @"test-content-sid");
    XCTAssertEqualObjects(creds.csrfToken, @"test-csrf-token");
    XCTAssertEqualObjects(creds.cookieClientSrc, @"test-cookie-client-src");
    XCTAssertEqualObjects(creds.cookieSidClient, @"test-cookie-sid-client");
    XCTAssertEqualObjects(creds.sidCookieName, @"test-sid-cookie-name");
    XCTAssertEqualObjects(creds.parentSid, @"test-parent-sid");
    XCTAssertEqualObjects(creds.tokenFormat, @"test-token-format");
    XCTAssertEqualObjects(creds.tokenType, @"test-token-type");
    XCTAssertEqualObjects(creds.beaconChildConsumerKey, @"test-beacon-child-consumer-key");
    XCTAssertEqualObjects(creds.beaconChildConsumerSecret, @"test-beacon-child-consumer-secret");
}

- (void)testMainSid_withNonJwtFormat_returnsAccessToken {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"test-main-sid" clientId:@"test-client" encrypted:NO storageType:SFOAuthCredentialsStorageTypeNone];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:@"test-access-token" forKey:@"access_token"];
    [params setObject:@"test-parent-sid" forKey:@"parent_sid"];
    [params setObject:@"access_token" forKey:@"token_format"];
    [creds updateCredentials:params];
    XCTAssertEqualObjects(creds.mainSid, @"test-access-token");
}

- (void)testMainSid_withJwtFormat_returnsParentSid {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"test-main-sid-jwt" clientId:@"test-client" encrypted:NO storageType:SFOAuthCredentialsStorageTypeNone];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:@"test-access-token" forKey:@"access_token"];
    [params setObject:@"test-parent-sid" forKey:@"parent_sid"];
    [params setObject:@"jwt" forKey:@"token_format"];
    [creds updateCredentials:params];
    XCTAssertEqualObjects(creds.mainSid, @"test-parent-sid");
}

- (void)test_givenDPoPTokenType_whenUpdateCredentials_thenUiSidCaptured {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"test-uisid-dpop" clientId:@"test-client" encrypted:NO storageType:SFOAuthCredentialsStorageTypeNone];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:@"test-access-token" forKey:@"access_token"];
    [params setObject:@"test-ui-sid" forKey:@"ui_sid"];
    [params setObject:@"DPoP" forKey:@"token_type"];
    [creds updateCredentials:params];
    XCTAssertEqualObjects(creds.uiSid, @"test-ui-sid");
}

- (void)test_givenNonDPoPTokenType_whenUpdateCredentials_thenUiSidNotCaptured {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"test-uisid-nondpop" clientId:@"test-client" encrypted:NO storageType:SFOAuthCredentialsStorageTypeNone];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:@"test-access-token" forKey:@"access_token"];
    [params setObject:@"test-ui-sid" forKey:@"ui_sid"];
    [params setObject:@"bearer" forKey:@"token_type"];
    [creds updateCredentials:params];
    XCTAssertNil(creds.uiSid);
}

- (void)test_givenUiSidPresent_whenGetMainSid_thenReturnsUiSid {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"test-mainsid-uisid" clientId:@"test-client" encrypted:NO storageType:SFOAuthCredentialsStorageTypeNone];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:@"test-access-token" forKey:@"access_token"];
    [params setObject:@"test-parent-sid" forKey:@"parent_sid"];
    [params setObject:@"jwt" forKey:@"token_format"];
    [params setObject:@"test-ui-sid" forKey:@"ui_sid"];
    [params setObject:@"DPoP" forKey:@"token_type"];
    [creds updateCredentials:params];
    XCTAssertEqualObjects(creds.mainSid, @"test-ui-sid");
}

- (void)test_givenUiSidAbsent_whenGetMainSid_thenFallsBackToExistingLogic {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"test-mainsid-fallback" clientId:@"test-client" encrypted:NO storageType:SFOAuthCredentialsStorageTypeNone];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:@"test-access-token" forKey:@"access_token"];
    [params setObject:@"test-parent-sid" forKey:@"parent_sid"];
    [params setObject:@"jwt" forKey:@"token_format"];
    [creds updateCredentials:params];
    XCTAssertNil(creds.uiSid);
    XCTAssertEqualObjects(creds.mainSid, @"test-parent-sid");
}

- (void)test_givenRefreshUpdatedOtherInstance_whenMergeCredentials_thenFieldsAndChangeSetAreCopied {
    // `target` stands in for the credentials a coordinator holds; `refreshed` stands in for the
    // coalesced in-flight instance the shared token refresher ran -updateCredentials: on.
    SFOAuthCredentials *target = [[SFOAuthCredentials alloc] initWithIdentifier:@"merge_creds" clientId:@"client_id" encrypted:NO storageType:SFOAuthCredentialsStorageTypeNone];
    target.accessToken = @"old-access-token";
    target.refreshToken = @"old-refresh-token";
    [target resetCredentialsChangeSet];

    SFOAuthCredentials *refreshed = [[SFOAuthCredentials alloc] initWithIdentifier:@"merge_creds" clientId:@"client_id" encrypted:NO storageType:SFOAuthCredentialsStorageTypeNone];
    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
    params[@"access_token"] = @"new-access-token";
    params[@"refresh_token"] = @"new-refresh-token";
    params[@"instance_url"] = @"https://new-instance.salesforce.com";
    params[@"sfdc_community_id"] = @"new-community-id";
    [refreshed updateCredentials:params]; // populates refreshed.credentialsChangeSet via setPropertyForKey:

    [target mergeCredentialsFromCredentials:refreshed];

    // Fields are copied into the target instance in place.
    XCTAssertEqualObjects(target.accessToken, @"new-access-token", @"merge should copy the rotated access token");
    XCTAssertEqualObjects(target.refreshToken, @"new-refresh-token", @"merge should copy the rotated refresh token");
    XCTAssertEqualObjects(target.instanceUrl.absoluteString, @"https://new-instance.salesforce.com", @"merge should copy the instance URL");
    XCTAssertEqualObjects(target.communityId, @"new-community-id", @"merge should copy the community id");

    // The refresh delta is carried over so -[SFUserAccountManager applyCredentials:] still posts the
    // SFUserAccountDataChange notification after a coalesced, coordinator-driven refresh.
    XCTAssertTrue([target hasPropertyValueChangedForKey:@"accessToken"], @"merge should carry over the access-token change");
    XCTAssertTrue([target hasPropertyValueChangedForKey:@"instanceUrl"], @"merge should carry over the instance-url change");
    XCTAssertTrue([target hasPropertyValueChangedForKey:@"communityId"], @"merge should carry over the community-id change");
}

- (void)test_givenNilOrSameInstance_whenMergeCredentials_thenNoOp {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"merge_noop" clientId:@"client_id" encrypted:NO storageType:SFOAuthCredentialsStorageTypeNone];
    creds.accessToken = @"token";
    [creds resetCredentialsChangeSet];

    [creds mergeCredentialsFromCredentials:nil];
    [creds mergeCredentialsFromCredentials:creds];

    XCTAssertEqualObjects(creds.accessToken, @"token", @"a nil/self merge must not alter fields");
    XCTAssertFalse([creds hasPropertyValueChangedForKey:@"accessToken"], @"a nil/self merge must not record changes");
}

- (void)test_givenPopulatedCredentials_whenCopy_thenAllFieldsCopied {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"copy_creds" clientId:@"client_id" encrypted:NO storageType:SFOAuthCredentialsStorageTypeNone];
    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
    params[@"access_token"] = @"copy-access-token";
    params[@"refresh_token"] = @"copy-refresh-token";
    params[@"instance_url"] = @"https://copy-instance.salesforce.com";
    params[@"sfdc_community_id"] = @"copy-community-id";
    params[@"token_type"] = @"copy-token-type";
    [creds updateCredentials:params];

    SFOAuthCredentials *copied = [creds copy];

    // copyWithZone: now routes through the shared copyFieldsFromCredentials: helper; confirm the
    // identity and session fields still round-trip.
    XCTAssertEqualObjects(copied.identifier, creds.identifier);
    XCTAssertEqualObjects(copied.clientId, creds.clientId);
    XCTAssertEqualObjects(copied.accessToken, @"copy-access-token");
    XCTAssertEqualObjects(copied.refreshToken, @"copy-refresh-token");
    XCTAssertEqualObjects(copied.instanceUrl.absoluteString, @"https://copy-instance.salesforce.com");
    XCTAssertEqualObjects(copied.communityId, @"copy-community-id");
    XCTAssertEqualObjects(copied.tokenType, @"copy-token-type");
}

- (void)test_givenExistingUiSid_whenUpdateCredentialsWithBearerTokenType_thenUiSidCleared {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"test-uisid-stale" clientId:@"test-client" encrypted:NO storageType:SFOAuthCredentialsStorageTypeNone];

    NSMutableDictionary *dpopParams = [NSMutableDictionary dictionary];
    [dpopParams setObject:@"dpop-access-token" forKey:@"access_token"];
    [dpopParams setObject:@"test-ui-sid" forKey:@"ui_sid"];
    [dpopParams setObject:@"DPoP" forKey:@"token_type"];
    [creds updateCredentials:dpopParams];
    XCTAssertEqualObjects(creds.uiSid, @"test-ui-sid", @"Precondition: uiSid must be set after DPoP login");

    NSMutableDictionary *bearerParams = [NSMutableDictionary dictionary];
    [bearerParams setObject:@"bearer-access-token" forKey:@"access_token"];
    [bearerParams setObject:@"bearer" forKey:@"token_type"];
    [creds updateCredentials:bearerParams];

    XCTAssertNil(creds.uiSid, @"uiSid must be cleared after DPoP-to-Bearer downgrade");
    XCTAssertEqualObjects(creds.mainSid, @"bearer-access-token", @"mainSid must return access token after uiSid is cleared");
}

@end
