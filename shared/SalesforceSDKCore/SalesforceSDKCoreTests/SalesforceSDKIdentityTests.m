/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

#import "SalesforceSDKIdentityTests.h"
#import "SFSDKTestRequestListener.h"
#import "TestSetupUtils.h"
#import <SalesforceOAuth/SFOAuthCoordinator.h>
#import "SFIdentityCoordinator.h"
#import "SFAccountManager.h"
#import "SFIdentityData.h"

/**
 * Private interface for this tests module.
 */
@interface SalesforceSDKIdentityTests ()
/**
 * Synchronous wrapper around the asynchronous request to the identity service.
 */
- (void)sendSyncIdentityRequest;

/**
 * Takes the OAuth credentials from the test file configuration, and retrieves a
 * bona fide set of SFOAuthCredentials from the service.  The ID requests need a
 * valid access token and identity URL.
 */
- (void)bootstrapAuthCredentials;

/**
 * Does a cursory pass on the identity data, to sanity check values.
 */
- (void)validateIdentityData;
@end

@implementation SalesforceSDKIdentityTests

#pragma mark - Test / class setup

- (void)setUp
{
    // Set-up code here.
    _requestListener = nil;
    [self bootstrapAuthCredentials];
    
    [super setUp];
}

- (void)dealloc
{
    _requestListener = nil;
}

#pragma mark - Helper methods

- (void)sendSyncIdentityRequest
{
    SFAccountManager *accountMgr = [SFAccountManager sharedInstance];
    _requestListener = [[SFSDKTestRequestListener alloc] initWithServiceType:SFAccountManagerServiceTypeIdentity];
    [accountMgr.idCoordinator initiateIdentityDataRetrieval];
    [_requestListener waitForCompletion];
}

- (void)bootstrapAuthCredentials
{
    [TestSetupUtils populateAuthCredentialsFromConfigFile];
    
    // With credentials bootstrapped, get an actual set of credentials (we'll need
    // an access token and identity URL for these tests.
    SFAccountManager *accountMgr = [SFAccountManager sharedInstance];
    _requestListener = nil;
    _requestListener = [[SFSDKTestRequestListener alloc] initWithServiceType:SFAccountManagerServiceTypeOAuth];
    [accountMgr.coordinator authenticate];
    [_requestListener waitForCompletion];
    if ([_requestListener.returnStatus isEqualToString:kTestRequestStatusDidFail]) {
        STFail([NSString stringWithFormat:@"OAuth refresh did not succeed: %@", _requestListener.lastError]);
    }
}

#pragma mark - Tests

/**
 * Tests that identity data can be successfully retrieved with valid credentials.
 */
- (void)testRetrieveIdentitySuccess
{
    [self sendSyncIdentityRequest];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"Identity request failed.");
    [self validateIdentityData];
    [SFAccountManager sharedInstance].idData = nil;
}

/**
 * Test that an error state is returned if the identity data is requested with invalid credentials.
 */
- (void)testRetrieveIdentityFailure
{
    SFAccountManager *accountMgr = [SFAccountManager sharedInstance];
    SFIdentityCoordinator *idCoord = accountMgr.idCoordinator;
    NSString *origAccessToken = [idCoord.credentials.accessToken copy];
    idCoord.credentials.accessToken = @"";
    [self sendSyncIdentityRequest];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidFail, @"Identity request should not have succeeded.");
    NSError *error = _requestListener.lastError;
    STAssertTrue([error.domain isEqualToString:kSFIdentityErrorDomain], [NSString stringWithFormat:@"Error domain should have been '%@'.  Got '%@'", kSFIdentityErrorDomain, error.domain]);
    STAssertTrue(error.code == kSFIdentityErrorBadHttpResponse, [NSString stringWithFormat:@"Expected error code %d.  Got %d", kSFIdentityErrorBadHttpResponse, error.code]);
    idCoord.credentials.accessToken = origAccessToken;
}

#pragma mark - Private helper methods

- (void)validateIdentityData
{
    SFIdentityData *idData = [SFAccountManager sharedInstance].idData;
    STAssertNotNil(idData, @"Identity data is nil.");
    STAssertNotNil(idData.dictRepresentation, @"idData.dictRepresentation should not be nil.");
    STAssertNotNil(idData.idUrl, @"idUrl should not be nil.");
    STAssertTrue(idData.assertedUser, @"assertedUser should be true.");
    STAssertNotNil(idData.userId, @"userId should not be nil.");
    STAssertNotNil(idData.orgId, @"orgId should not be nil.");
    STAssertNotNil(idData.username, @"username should not be nil.");
    STAssertNotNil(idData.nickname, @"nickname should not be nil.");
    STAssertNotNil(idData.displayName, @"displayName should not be nil.");
    STAssertNotNil(idData.email, @"email should not be nil.");
    STAssertNotNil(idData.firstName, @"firstName should not be nil.");
    STAssertNotNil(idData.lastName, @"lastName should not be nil.");
    STAssertNotNil(idData.pictureUrl, @"pictureUrl should not be nil.");
    STAssertNotNil(idData.thumbnailUrl, @"thumbnailUrl should not be nil.");
    STAssertNotNil(idData.enterpriseSoapUrl, @"enterpriseSoapUrl should not be nil.");
    STAssertNotNil(idData.metadataSoapUrl, @"metadataSoapUrl should not be nil.");
    STAssertNotNil(idData.partnerSoapUrl, @"partnerSoapUrl should not be nil.");
    STAssertNotNil(idData.restUrl, @"restUrl should not be nil.");
    STAssertNotNil(idData.restSObjectsUrl, @"restSObjectsUrl should not be nil.");
    STAssertNotNil(idData.restSearchUrl, @"restSearchUrl should not be nil.");
    STAssertNotNil(idData.restQueryUrl, @"restQueryUrl should not be nil.");
    STAssertNotNil(idData.restRecentUrl, @"restRecentUrl should not be nil.");
    STAssertNotNil(idData.profileUrl, @"profileUrl should not be nil.");
    STAssertNotNil(idData.chatterFeedsUrl, @"chatterFeedsUrl should not be nil.");
    STAssertNotNil(idData.chatterGroupsUrl, @"chatterGroupsUrl should not be nil.");
    STAssertNotNil(idData.chatterUsersUrl, @"chatterUsersUrl should not be nil.");
    STAssertNotNil(idData.chatterFeedItemsUrl, @"chatterFeedItemsUrl should not be nil.");
    STAssertTrue(idData.isActive, @"isActive should be true.");
    STAssertNotNil(idData.userType, @"userType should not be nil.");
    STAssertNotNil(idData.language, @"language should not be nil.");
    STAssertNotNil(idData.locale, @"locale should not be nil.");
    STAssertFalse(idData.utcOffset == -1, @"No value determined for utcOffset.");
    STAssertNotNil(idData.lastModifiedDate, @"lastModifiedDate should not be nil.");
}

@end
