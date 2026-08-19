/*
 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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
#import "SFSDKOAuth2.h"
#import "SFSDKOAuth2+Internal.h"

/**
 Tests for token refresh behavior that ensures instanceUrl is used when available,
 eliminating unnecessary login-pool redirects and improving performance for both
 Bearer and DPoP authentication flows.

 These tests validate the precedence logic: community URL first, then instanceUrl,
 then fallback to domain. They also confirm code exchange (first login) is unaffected.
 */
@interface SFSDKOAuth2RefreshInstanceUrlTests : XCTestCase

@end

@implementation SFSDKOAuth2RefreshInstanceUrlTests

#pragma mark - Unit Tests for overrideDomainIfNeeded

/**
 Test that overrideDomainIfNeeded returns instanceUrl when it is populated and
 communityId is nil. This is the happy path for refresh tokens after successful login.
 */
- (void)test_givenInstanceUrlPopulated_whenOverrideDomainIfNeededCalled_thenReturnsInstanceUrl {
    // Given: Credentials with instanceUrl populated (post-login state)
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"test_refresh_instance"
                                                                       clientId:@"test_client_id"
                                                                      encrypted:NO
                                                                    storageType:SFOAuthCredentialsStorageTypeNone];

    // Simulate post-login state by updating credentials with token endpoint response
    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
    [params setObject:@"test-access-token" forKey:@"access_token"];
    [params setObject:@"test-refresh-token" forKey:@"refresh_token"];
    [params setObject:@"https://mydomain.my.salesforce.com" forKey:@"instance_url"];
    [params setObject:@"https://id.salesforce.com/id/00Dxx0000000000/005xx000000000" forKey:@"id"];
    [creds updateCredentials:params];

    // When: overrideDomainIfNeeded is called
    NSURL *result = [creds overrideDomainIfNeeded];

    // Then: Should return instanceUrl, not domain
    XCTAssertNotNil(result, @"overrideDomainIfNeeded should return a URL");
    XCTAssertEqualObjects(result.absoluteString, @"https://mydomain.my.salesforce.com",
                         @"Expected instanceUrl to be used when populated");
    XCTAssertEqualObjects(result.host, @"mydomain.my.salesforce.com",
                         @"Expected instance URL host, not login pool domain");
}

/**
 Test that overrideDomainIfNeeded falls back to domain when instanceUrl is nil.
 This simulates either code exchange (first login) or edge cases where instanceUrl
 is not yet populated.
 */
- (void)test_givenInstanceUrlNil_whenOverrideDomainIfNeededCalled_thenReturnsDomain {
    // Given: Credentials without instanceUrl (pre-login or code exchange state)
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"test_fallback"
                                                                       clientId:@"test_client_id"
                                                                      encrypted:NO
                                                                    storageType:SFOAuthCredentialsStorageTypeNone];

    // Explicitly verify instanceUrl is nil (should be default state)
    XCTAssertNil(creds.instanceUrl, @"instanceUrl should be nil in initial state");

    // When: overrideDomainIfNeeded is called
    NSURL *result = [creds overrideDomainIfNeeded];

    // Then: Should fall back to protocol://domain
    XCTAssertNotNil(result, @"overrideDomainIfNeeded should return a URL");
    XCTAssertEqualObjects(result.absoluteString, @"https://login.salesforce.com",
                         @"Expected fallback to domain when instanceUrl is nil");
    XCTAssertEqualObjects(result.host, @"login.salesforce.com",
                         @"Expected login pool domain when instanceUrl is nil");
}

/**
 Test that communityUrl takes precedence over instanceUrl when communityId is set.
 Community-based authentication has its own token endpoint and must not be changed
 by the instanceUrl logic.
 */
- (void)test_givenCommunityIdSet_whenOverrideDomainIfNeededCalled_thenReturnsCommunityUrlRegardlessOfInstanceUrl {
    // Given: Credentials with both communityUrl and instanceUrl populated
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"test_community"
                                                                       clientId:@"test_client_id"
                                                                      encrypted:NO
                                                                    storageType:SFOAuthCredentialsStorageTypeNone];

    // Simulate community login by setting both community and instance URLs
    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
    [params setObject:@"test-access-token" forKey:@"access_token"];
    [params setObject:@"test-refresh-token" forKey:@"refresh_token"];
    [params setObject:@"https://mydomain.my.salesforce.com" forKey:@"instance_url"];
    [params setObject:@"0DB000000000001" forKey:@"sfdc_community_id"];
    [params setObject:@"https://mycommunity.force.com" forKey:@"sfdc_community_url"];
    [params setObject:@"https://id.salesforce.com/id/00Dxx0000000000/005xx000000000" forKey:@"id"];
    [creds updateCredentials:params];

    // When: overrideDomainIfNeeded is called
    NSURL *result = [creds overrideDomainIfNeeded];

    // Then: Should return communityUrl, not instanceUrl or domain
    XCTAssertNotNil(result, @"overrideDomainIfNeeded should return a URL");
    XCTAssertEqualObjects(result.absoluteString, @"https://mycommunity.force.com",
                         @"Expected communityUrl to take precedence over instanceUrl");
    XCTAssertEqualObjects(result.host, @"mycommunity.force.com",
                         @"Expected community host, not instance or login pool");
}

#pragma mark - Integration Tests with SFSDKOAuth2.prepareBasicRequest

/**
 Test that when instanceUrl is populated, prepareBasicRequest builds a token endpoint
 URL whose host is the instanceUrl host (not the login pool). This exercises the full
 request construction path the production refresh flow uses.
 */
- (void)test_givenInstanceUrlPopulated_whenPrepareBasicRequestCalled_thenRequestURLUsesInstanceUrlHost {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"test_refresh_integration"
                                                                       clientId:@"test_client_id"
                                                                      encrypted:NO
                                                                    storageType:SFOAuthCredentialsStorageTypeNone];

    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
    [params setObject:@"test-access-token" forKey:@"access_token"];
    [params setObject:@"test-refresh-token" forKey:@"refresh_token"];
    [params setObject:@"https://mydomain.my.salesforce.com" forKey:@"instance_url"];
    [params setObject:@"https://id.salesforce.com/id/00Dxx0000000000/005xx000000000" forKey:@"id"];
    [creds updateCredentials:params];

    SFSDKOAuthTokenEndpointRequest *endpointReq = [[SFSDKOAuthTokenEndpointRequest alloc] init];
    endpointReq.clientID = creds.clientId;
    endpointReq.refreshToken = creds.refreshToken;
    endpointReq.redirectURI = creds.redirectUri ?: @"test://callback";
    endpointReq.serverURL = [creds overrideDomainIfNeeded];

    NSMutableURLRequest *request = [[[SFSDKOAuth2 alloc] init] prepareBasicRequest:endpointReq];

    XCTAssertNotNil(request.URL, @"prepareBasicRequest should produce a URL");
    XCTAssertEqualObjects(request.URL.host, @"mydomain.my.salesforce.com",
                         @"Refresh request should target instanceUrl.host to avoid redirect");
    XCTAssertEqualObjects(request.URL.path, @"/services/oauth2/token",
                         @"Token endpoint path should be appended correctly");
}

/**
 Test that when instanceUrl is nil, prepareBasicRequest falls back to domain.
 This validates backward compatibility with pre-existing behavior.
 */
- (void)test_givenInstanceUrlNil_whenPrepareBasicRequestCalled_thenRequestURLUsesDomainHost {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"test_refresh_fallback"
                                                                       clientId:@"test_client_id"
                                                                      encrypted:NO
                                                                    storageType:SFOAuthCredentialsStorageTypeNone];

    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
    [params setObject:@"test-refresh-token" forKey:@"refresh_token"];
    [creds updateCredentials:params];

    XCTAssertNil(creds.instanceUrl, @"instanceUrl should be nil for this test");

    SFSDKOAuthTokenEndpointRequest *endpointReq = [[SFSDKOAuthTokenEndpointRequest alloc] init];
    endpointReq.clientID = creds.clientId;
    endpointReq.refreshToken = creds.refreshToken;
    endpointReq.redirectURI = @"test://callback";
    endpointReq.serverURL = [creds overrideDomainIfNeeded];

    NSMutableURLRequest *request = [[[SFSDKOAuth2 alloc] init] prepareBasicRequest:endpointReq];

    XCTAssertNotNil(request.URL, @"prepareBasicRequest should produce a URL");
    XCTAssertEqualObjects(request.URL.host, @"login.salesforce.com",
                         @"Refresh request should fall back to domain when instanceUrl is nil");
    XCTAssertEqualObjects(request.URL.path, @"/services/oauth2/token",
                         @"Token endpoint path should be appended correctly");
}

/**
 Test that code exchange (first login) continues to target domain, not instanceUrl.
 At code exchange time, instanceUrl is not yet known, so the SDK must target the
 login pool. Validates that the fix does not break code exchange.
 */
- (void)test_givenInstanceUrlNil_whenPrepareBasicRequestCalledForCodeExchange_thenRequestURLUsesDomainHost {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"test_code_exchange"
                                                                       clientId:@"test_client_id"
                                                                      encrypted:NO
                                                                    storageType:SFOAuthCredentialsStorageTypeNone];

    XCTAssertNil(creds.instanceUrl, @"instanceUrl must be nil during code exchange");
    XCTAssertNil(creds.refreshToken, @"refreshToken must be nil during code exchange");

    SFSDKOAuthTokenEndpointRequest *endpointReq = [[SFSDKOAuthTokenEndpointRequest alloc] init];
    endpointReq.clientID = creds.clientId;
    endpointReq.approvalCode = @"test_approval_code";
    endpointReq.codeVerifier = @"test_code_verifier";
    endpointReq.redirectURI = @"test://callback";
    endpointReq.serverURL = [creds overrideDomainIfNeeded];

    NSMutableURLRequest *request = [[[SFSDKOAuth2 alloc] init] prepareBasicRequest:endpointReq];

    XCTAssertNotNil(request.URL, @"prepareBasicRequest should produce a URL");
    XCTAssertEqualObjects(request.URL.host, @"login.salesforce.com",
                         @"Code exchange must target domain since instanceUrl is not yet known");
    XCTAssertEqualObjects(request.URL.path, @"/services/oauth2/token",
                         @"Token endpoint path should be appended correctly");
}

@end
