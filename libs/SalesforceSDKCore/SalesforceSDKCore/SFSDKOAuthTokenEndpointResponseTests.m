/*
 SFSDKOAuthTokenEndpointResponseTests.m
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
#import "SFSDKOAuth2.h"

@interface SFSDKOAuthTokenEndpointResponse ()

- (instancetype)initWithDictionary:(NSDictionary *)nvPairs parseAdditionalFields:(NSArray<NSString *> *)additionalOAuthParameterKeys;

@end

@interface SFSDKOAuthTokenEndpointResponseTests : XCTestCase

@end

@implementation SFSDKOAuthTokenEndpointResponseTests

- (void)testInitWithDictionary {
    // Prepeare dictionary simulating response from token end point
    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
    [params setObject:@"test-auth-token" forKey:@"access_token"];
    [params setObject:@"test-refresh-token" forKey:@"refresh_token"];
    [params setObject:@"https://instance.salesforce.com" forKey:@"instance_url"];
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
    [params setObject:@"test-beacon-child-consumer-key" forKey:@"beacon_child_consumer_key"];
    [params setObject:@"test-beacon-child-consumer-secret" forKey:@"beacon_child_consumer_secret"];

    // Additional fields
    NSArray<NSString *>* additionalFields = @[ @"additional-1", @"additional-2" ];
    for (NSString *field in additionalFields) {
        NSString *value = [NSString stringWithFormat:@"test-%@", field];
        [params setObject:value forKey:field];
    }
    
    // Create SFSDKOAuthTokenEndpointResponse with initWithDictionary
    SFSDKOAuthTokenEndpointResponse* response = [[SFSDKOAuthTokenEndpointResponse alloc] initWithDictionary:params parseAdditionalFields:additionalFields];
    
    // Check regular fields
    XCTAssertEqualObjects(response.accessToken, @"test-auth-token");
    XCTAssertEqualObjects(response.refreshToken, @"test-refresh-token");
    XCTAssertEqualObjects(response.instanceUrl.absoluteString, @"https://instance.salesforce.com");
    XCTAssertEqualObjects(response.identityUrl.absoluteString, @"https://id.salesforce.com");
    XCTAssertEqualObjects(response.communityId, @"test-community-id");
    XCTAssertEqualObjects(response.communityUrl.absoluteString, @"https://community.salesforce.com");
    XCTAssertEqualObjects(response.lightningDomain, @"test-lightning-domain");
    XCTAssertEqualObjects(response.lightningSid, @"test-lightning-sid");
    XCTAssertEqualObjects(response.vfDomain, @"test-vf-domain");
    XCTAssertEqualObjects(response.vfSid, @"test-vf-sid");
    XCTAssertEqualObjects(response.contentDomain, @"test-content-domain");
    XCTAssertEqualObjects(response.contentSid, @"test-content-sid");
    XCTAssertEqualObjects(response.csrfToken, @"test-csrf-token");
    XCTAssertEqualObjects(response.cookieClientSrc, @"test-cookie-client-src");
    XCTAssertEqualObjects(response.cookieSidClient, @"test-cookie-sid-client");
    XCTAssertEqualObjects(response.sidCookieName, @"test-sid-cookie-name");
    XCTAssertEqualObjects(response.parentSid, @"test-parent-sid");
    XCTAssertEqualObjects(response.tokenFormat, @"test-token-format");
    XCTAssertEqualObjects(response.beaconChildConsumerKey, @"test-beacon-child-consumer-key");
    XCTAssertEqualObjects(response.beaconChildConsumerSecret, @"test-beacon-child-consumer-secret");

    // Check additional fields
    for (NSString *field in additionalFields) {
        NSString *value = [NSString stringWithFormat:@"test-%@", field];
        XCTAssertEqualObjects(response.additionalOAuthFields[field], value);
    }

}

@end
