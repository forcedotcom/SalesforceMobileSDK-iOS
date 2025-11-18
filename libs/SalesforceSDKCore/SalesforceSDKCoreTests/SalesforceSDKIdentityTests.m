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
#import "SFIdentityCoordinator.h"
#import "SFUserAccountManager.h"
#import "SFIdentityData.h"

@interface SFIdentityCoordinator ()

- (void)processResponse:(NSData *)data;

@end


@interface SalesforceSDKIdentityTests : XCTestCase
@end

@implementation SalesforceSDKIdentityTests

/**
 * Tests that identity data can be successfully processed
 */
- (void)testProcessIdentityData
{
    NSString *identityResponse = @"{\"id\":\"https://login.salesforce.com/id/some-org-id/some-user-id\",\"asserted_user\":true,\"user_id\":\"some-user-id\",\"organization_id\":\"some-org-id\",\"username\":\"user@example.com\",\"nick_name\":\"nickname\",\"display_name\":\"Example User\",\"email\":\"user@example.com\",\"email_verified\":true,\"first_name\":\"Example\",\"last_name\":\"User\",\"timezone\":\"America/Los_Angeles\",\"photos\":{\"picture\":\"https://example.com/profilephoto/full\",\"thumbnail\":\"https://example.com/profilephoto/thumb\"},\"addr_street\":null,\"addr_city\":null,\"addr_state\":null,\"addr_country\":null,\"addr_zip\":null,\"mobile_phone\":null,\"mobile_phone_verified\":false,\"is_lightning_login_user\":false,\"status\":{\"created_date\":null,\"body\":null},\"urls\":{\"enterprise\":\"https://example.my.salesforce.com/services/Soap/c/some-version/some-org-id\",\"metadata\":\"https://example.my.salesforce.com/services/Soap/m/some-version/some-org-id\",\"partner\":\"https://example.my.salesforce.com/services/Soap/u/some-version/some-org-id\",\"rest\":\"https://example.my.salesforce.com/services/data/vsome-version/\",\"sobjects\":\"https://example.my.salesforce.com/services/data/vsome-version/sobjects/\",\"search\":\"https://example.my.salesforce.com/services/data/vsome-version/search/\",\"query\":\"https://example.my.salesforce.com/services/data/vsome-version/query/\",\"recent\":\"https://example.my.salesforce.com/services/data/vsome-version/recent/\",\"tooling_soap\":\"https://example.my.salesforce.com/services/Soap/T/some-version/some-org-id\",\"tooling_rest\":\"https://example.my.salesforce.com/services/data/vsome-version/tooling/\",\"profile\":\"https://example.my.salesforce.com/some-user-id\",\"feeds\":\"https://example.my.salesforce.com/services/data/vsome-version/chatter/feeds\",\"groups\":\"https://example.my.salesforce.com/services/data/vsome-version/chatter/groups\",\"users\":\"https://example.my.salesforce.com/services/data/vsome-version/chatter/users\",\"feed_items\":\"https://example.my.salesforce.com/services/data/vsome-version/chatter/feed-items\",\"feed_elements\":\"https://example.my.salesforce.com/services/data/vsome-version/chatter/feed-elements\",\"custom_domain\":\"https://example.my.salesforce.com\"},\"active\":true,\"user_type\":\"STANDARD\",\"language\":\"en_US\",\"locale\":\"en_US\",\"utcOffset\":-28800000,\"last_modified_date\":\"2024-12-23T18:40:50Z\"}";

    
    SFIdentityCoordinator* coordinator = [[SFIdentityCoordinator alloc] init];
    NSData* identityResponseData = [identityResponse dataUsingEncoding:NSUTF8StringEncoding];
    [coordinator processResponse:identityResponseData];
    SFIdentityData *idData = coordinator.idData;
    
    
    // Basic identity fields
    XCTAssertEqualObjects(idData.idUrl, [NSURL URLWithString:@"https://login.salesforce.com/id/some-org-id/some-user-id"], @"idUrl should match");
    XCTAssertTrue(idData.assertedUser, @"assertedUser should be true");
    XCTAssertEqualObjects(idData.userId, @"some-user-id", @"userId should match");
    XCTAssertEqualObjects(idData.orgId, @"some-org-id", @"orgId should match");
    
    // User information
    XCTAssertEqualObjects(idData.username, @"user@example.com", @"username should match");
    XCTAssertEqualObjects(idData.nickname, @"nickname", @"nickname should match");
    XCTAssertEqualObjects(idData.displayName, @"Example User", @"displayName should match");
    XCTAssertEqualObjects(idData.email, @"user@example.com", @"email should match");
    XCTAssertEqualObjects(idData.firstName, @"Example", @"firstName should match");
    XCTAssertEqualObjects(idData.lastName, @"User", @"lastName should match");
    
    // Photos (NSURL* properties)
    XCTAssertEqualObjects(idData.pictureUrl, [NSURL URLWithString:@"https://example.com/profilephoto/full"], @"pictureUrl should match");
    XCTAssertEqualObjects(idData.thumbnailUrl, [NSURL URLWithString:@"https://example.com/profilephoto/thumb"], @"thumbnailUrl should match");
    
    // SOAP URLs
    XCTAssertEqualObjects(idData.enterpriseSoapUrl, @"https://example.my.salesforce.com/services/Soap/c/some-version/some-org-id", @"enterpriseSoapUrl should match");
    XCTAssertEqualObjects(idData.metadataSoapUrl, @"https://example.my.salesforce.com/services/Soap/m/some-version/some-org-id", @"metadataSoapUrl should match");
    XCTAssertEqualObjects(idData.partnerSoapUrl, @"https://example.my.salesforce.com/services/Soap/u/some-version/some-org-id", @"partnerSoapUrl should match");
    
    // REST URLs
    XCTAssertEqualObjects(idData.restUrl, @"https://example.my.salesforce.com/services/data/vsome-version/", @"restUrl should match");
    XCTAssertEqualObjects(idData.restSObjectsUrl, @"https://example.my.salesforce.com/services/data/vsome-version/sobjects/", @"restSObjectsUrl should match");
    XCTAssertEqualObjects(idData.restSearchUrl, @"https://example.my.salesforce.com/services/data/vsome-version/search/", @"restSearchUrl should match");
    XCTAssertEqualObjects(idData.restQueryUrl, @"https://example.my.salesforce.com/services/data/vsome-version/query/", @"restQueryUrl should match");
    XCTAssertEqualObjects(idData.restRecentUrl, @"https://example.my.salesforce.com/services/data/vsome-version/recent/", @"restRecentUrl should match");
    
    // Profile and Chatter URLs
    XCTAssertEqualObjects(idData.profileUrl, [NSURL URLWithString:@"https://example.my.salesforce.com/some-user-id"], @"profileUrl should match (NSURL)");
    XCTAssertEqualObjects(idData.chatterFeedsUrl, @"https://example.my.salesforce.com/services/data/vsome-version/chatter/feeds", @"chatterFeedsUrl should match");
    XCTAssertEqualObjects(idData.chatterGroupsUrl, @"https://example.my.salesforce.com/services/data/vsome-version/chatter/groups", @"chatterGroupsUrl should match");
    XCTAssertEqualObjects(idData.chatterUsersUrl, @"https://example.my.salesforce.com/services/data/vsome-version/chatter/users", @"chatterUsersUrl should match");
    XCTAssertEqualObjects(idData.chatterFeedItemsUrl, @"https://example.my.salesforce.com/services/data/vsome-version/chatter/feed-items", @"chatterFeedItemsUrl should match");
    
    // User status and preferences
    XCTAssertTrue(idData.isActive, @"isActive should be true");
    XCTAssertEqualObjects(idData.userType, @"STANDARD", @"userType should match");
    XCTAssertEqualObjects(idData.language, @"en_US", @"language should match");
    XCTAssertEqualObjects(idData.locale, @"en_US", @"locale should match");
    XCTAssertEqual(idData.utcOffset, -28800000, @"utcOffset should match");
    
    // Date parsing
    XCTAssertNotNil(idData.lastModifiedDate, @"lastModifiedDate should not be nil");
    // Note: lastModifiedDate is parsed from "2024-12-23T18:40:50Z", exact value comparison would need date formatter
}

@end

