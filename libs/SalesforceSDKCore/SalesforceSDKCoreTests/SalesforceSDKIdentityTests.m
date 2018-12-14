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

#import "SalesforceSDKIdentityTests.h"
#import "SFSDKTestRequestListener.h"
#import "TestSetupUtils.h"
#import "SFOAuthCoordinator.h"
#import "SFIdentityCoordinator.h"
#import "SFUserAccountManager.h"
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
 * Does a cursory pass on the identity data, to sanity check values.
 */
- (void)validateIdentityData;
@end

static NSException *authException = nil;

@implementation SalesforceSDKIdentityTests

#pragma mark - Test / class setup

+ (void)setUp
{
    @try {
        [TestSetupUtils populateAuthCredentialsFromConfigFileForClass:[self class]];
        [TestSetupUtils synchronousAuthRefresh];
    }
    @catch (NSException *exception) {
        authException = exception;
    }
    [super setUp];
}

- (void)setUp
{
    if (authException) {
        XCTFail(@"Setting up authentication failed: %@", authException);
    }
    
    // Set-up code here.
    _requestListener = nil;
    
    [super setUp];
}

#pragma mark - Helper methods

- (void)sendSyncIdentityRequest
{
    
    SFIdentityCoordinator *idCoordinator = [[SFIdentityCoordinator alloc] initWithCredentials:[SFUserAccountManager sharedInstance].currentUser.credentials];
    _requestListener = nil;
    _requestListener = [[SFSDKTestRequestListener alloc] init];
    idCoordinator.delegate = _requestListener;
    [idCoordinator initiateIdentityDataRetrieval];
    [_requestListener waitForCompletion];
}

#pragma mark - Tests

/**
 * Tests that identity data can be successfully retrieved with valid credentials.
 */
- (void)testRetrieveIdentitySuccess
{
    [self sendSyncIdentityRequest];
    XCTAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"Identity request failed.");
    [self validateIdentityData];
}

#pragma mark - Private helper methods

- (void)validateIdentityData
{
    SFIdentityData *idData = [SFUserAccountManager sharedInstance].currentUser.idData;
    XCTAssertNotNil(idData, @"Identity data is nil.");
    XCTAssertNotNil(idData.dictRepresentation, @"idData.dictRepresentation should not be nil.");
    XCTAssertNotNil(idData.idUrl, @"idUrl should not be nil.");
    XCTAssertTrue(idData.assertedUser, @"assertedUser should be true.");
    XCTAssertNotNil(idData.userId, @"userId should not be nil.");
    XCTAssertNotNil(idData.orgId, @"orgId should not be nil.");
    XCTAssertNotNil(idData.username, @"username should not be nil.");
    XCTAssertNotNil(idData.nickname, @"nickname should not be nil.");
    XCTAssertNotNil(idData.displayName, @"displayName should not be nil.");
    XCTAssertNotNil(idData.email, @"email should not be nil.");
    XCTAssertNotNil(idData.firstName, @"firstName should not be nil.");
    XCTAssertNotNil(idData.lastName, @"lastName should not be nil.");
    XCTAssertNotNil(idData.pictureUrl, @"pictureUrl should not be nil.");
    XCTAssertNotNil(idData.thumbnailUrl, @"thumbnailUrl should not be nil.");
    XCTAssertNotNil(idData.enterpriseSoapUrl, @"enterpriseSoapUrl should not be nil.");
    XCTAssertNotNil(idData.metadataSoapUrl, @"metadataSoapUrl should not be nil.");
    XCTAssertNotNil(idData.partnerSoapUrl, @"partnerSoapUrl should not be nil.");
    XCTAssertNotNil(idData.restUrl, @"restUrl should not be nil.");
    XCTAssertNotNil(idData.restSObjectsUrl, @"restSObjectsUrl should not be nil.");
    XCTAssertNotNil(idData.restSearchUrl, @"restSearchUrl should not be nil.");
    XCTAssertNotNil(idData.restQueryUrl, @"restQueryUrl should not be nil.");
    XCTAssertNotNil(idData.restRecentUrl, @"restRecentUrl should not be nil.");
    XCTAssertNotNil(idData.profileUrl, @"profileUrl should not be nil.");
    XCTAssertNotNil(idData.chatterFeedsUrl, @"chatterFeedsUrl should not be nil.");
    XCTAssertNotNil(idData.chatterGroupsUrl, @"chatterGroupsUrl should not be nil.");
    XCTAssertNotNil(idData.chatterUsersUrl, @"chatterUsersUrl should not be nil.");
    XCTAssertNotNil(idData.chatterFeedItemsUrl, @"chatterFeedItemsUrl should not be nil.");
    XCTAssertTrue(idData.isActive, @"isActive should be true.");
    XCTAssertNotNil(idData.userType, @"userType should not be nil.");
    XCTAssertNotNil(idData.language, @"language should not be nil.");
    XCTAssertNotNil(idData.locale, @"locale should not be nil.");
    XCTAssertFalse(idData.utcOffset == -1, @"No value determined for utcOffset.");
    XCTAssertNotNil(idData.lastModifiedDate, @"lastModifiedDate should not be nil.");
}

@end

