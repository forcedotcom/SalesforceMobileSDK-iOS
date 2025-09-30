/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFSDKLogoutBlocker.h"
#import "SFOAuthCoordinator.h"
#import "SFOAuthCredentials.h"
#import "SFOAuthKeychainCredentials.h"
#import "SFOAuthCredentials+Internal.h"
#import "SalesforceOAuthUnitTestsCoordinatorDelegate.h"
#import "SalesforceOAuthUnitTests.h"
#import "SFSDKCryptoUtils.h"
#import "SFUserAccountManager.h"

static NSString * const kIdentifier = @"com.salesforce.ios.oauth.test";
static NSString * const kClientId   = @"SfdcMobileChatteriOS";

static NSString * const kTestAccessToken = @"AccessGranted!";
static NSString * const kTestRefreshToken = @"HowRefreshing";

@interface SFOAuthKeychainCredentials (Testing)

- (NSString *)decryptedTokenForService:(NSString *)service;
- (void)encryptToken:(NSString *)token forService:(NSString *)service;

@end

@implementation SalesforceOAuthUnitTests

+ (void)setUp
{
    [SFSDKLogoutBlocker block];
    [super setUp];
}
- (void)setUp {
    [super setUp];
    // Set-up code here.
}

- (void)tearDown {
    // Tear-down code here.
    [super tearDown];
}

/** Test the SFOAuthCredentials data model object
 */
- (void)testCredentials {
    
    NSString * const kAccessToken   = @"howAboutaNice";
    NSString * const kRefreshToken  = @"hawaiianPunch";
    NSString * const kUserId12      = @"00530000004c";          // 12 characters   00530000004cwSi
    NSString * const kUserId18      = @"00530000004cwSi123";    // 18 characters

    NSString * identifier       = kIdentifier;
    NSString * clientId         = kClientId;
    NSString * accessToken      = kAccessToken;
    NSString * refreshToken     = kRefreshToken;
    NSString * userId           = kUserId18;
    
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:identifier clientId:clientId encrypted:YES];
    identifier = nil;
    clientId = nil;
    
    // the access and refresh tokens should only be set explicitly for test purposes
    credentials.accessToken  = accessToken;     accessToken = nil;
    credentials.refreshToken = refreshToken;    refreshToken = nil;
    credentials.userId       = userId;          userId = nil;
    
    XCTAssertEqualObjects(credentials.identifier, kIdentifier, @"identifier must match initWithIdentifier arg");
    XCTAssertEqualObjects(credentials.clientId, kClientId, @"client ID must match initWithIdentifier arg");
    XCTAssertEqualObjects(credentials.accessToken, kAccessToken, @"access token mismatch");
    XCTAssertEqualObjects(credentials.refreshToken, kRefreshToken, @"refresh token mismatch");
    XCTAssertEqualObjects(credentials.userId, kUserId18, @"user ID (18) mismatch issue");
    
    credentials.userId = kUserId12;
    XCTAssertEqualObjects(credentials.userId, kUserId12, @"user ID (12) mismatch/truncation issue");
    
    [credentials revokeAccessToken];
    XCTAssertNil(credentials.accessToken, @"access token should be nil");
    
    [credentials revokeRefreshToken];
    XCTAssertNil(credentials.refreshToken, @"refresh token should be nil");
    // userId, instanceUrl, and issuedAt should all be nil after the refresh token is revoked
    XCTAssertNil(credentials.userId, @"userId should be nil");
    XCTAssertNil(credentials.issuedAt, @"instanceUrl should be nil");
    XCTAssertNil(credentials.issuedAt, @"issuedAt should be nil");
    
    credentials.accessToken = kAccessToken;
    credentials.refreshToken = kRefreshToken;
    XCTAssertEqualObjects(credentials.accessToken, kAccessToken, @"access token mismatch");
    XCTAssertEqualObjects(credentials.refreshToken, kRefreshToken, @"refresh token mismatch");
    
    [credentials revoke];
    XCTAssertNil(credentials.accessToken, @"access token should be nil");
    XCTAssertNil(credentials.accessToken, @"refresh token should be nil");
    
    credentials = nil;
}

/** Test the <NSCoding> implementation of <SFOAuthCredentials>
 */
- (void)testCredentialsCoding {
    
    NSData *data;
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
    
    SFOAuthKeychainCredentials *credsIn = [[SFOAuthKeychainCredentials alloc] initWithIdentifier:kIdentifier clientId:kClientId encrypted:YES];
    credsIn.domain          = @"login.salesforce.com";
    credsIn.redirectUri     = @"unittest:///redirect/uri/callback";
    credsIn.organizationId  = @"org";
    credsIn.identityUrl     = [NSURL URLWithString:@"https://login.salesforce.com/ID/orgID/eighteenCharUsrXYZ"];
    credsIn.instanceUrl     = [NSURL URLWithString:@"http://www.salesforce.com"];
    credsIn.apiInstanceUrl  = [NSURL URLWithString:@"http://api.salesforce.com"];
    credsIn.issuedAt        = [NSDate date];
    credsIn.contentDomain   = @"mobilesdk.my.salesforce.com";
    credsIn.contentSid      = @"contentsid";
    credsIn.lightningDomain = @"mobilesdk.lightning.force.com";
    credsIn.lightningSid    = @"lightningsid";
    credsIn.vfDomain        = @"mobilesdk.vf.force.com";
    credsIn.vfSid           = @"vfsid";
    credsIn.csrfToken       = @"csrf-token-test";
    credsIn.cookieClientSrc = @"cookie-client-src-test";
    credsIn.cookieSidClient = @"cookie-sid-client";
    credsIn.sidCookieName   = @"sid-cookie-name";
    credsIn.parentSid       = @"parent-sid";
    credsIn.tokenFormat     = @"token-format";
    credsIn.beaconChildConsumerKey = @"beacon-child-consumer-key";
    credsIn.beaconChildConsumerSecret = @"beacon-child-consumer-secret";

    credsIn.additionalOAuthFields = @{
        @"abc": @"def"
    };
    
    NSString *expectedUserId = @"eighteenCharUsrXYZ"; // derived from identityUrl
    
    [archiver encodeObject:credsIn forKey:@"creds"];
    [archiver finishEncoding];
    data = archiver.encodedData;
    archiver = nil;
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
    unarchiver.requiresSecureCoding = YES;
    SFOAuthCredentials *credsOut = [unarchiver decodeObjectOfClass:[SFOAuthCredentials class] forKey:@"creds"];
    unarchiver = nil;
    
    XCTAssertNotNil(credsOut, @"couldn't unarchive credentials");
    
    XCTAssertEqualObjects(credsIn.identifier,          credsOut.identifier,          @"identifier mismatch");
    XCTAssertEqualObjects(credsIn.clientId,            credsOut.clientId,            @"clientId mismatch");
    XCTAssertEqualObjects(credsIn.domain,              credsOut.domain,              @"domain mismatch");
    XCTAssertEqualObjects(credsIn.redirectUri,         credsOut.redirectUri,         @"redirectUri mismatch");
    XCTAssertEqualObjects(credsIn.organizationId,      credsOut.organizationId,      @"organizationId mismatch");
    XCTAssertEqualObjects(credsIn.identityUrl,         credsOut.identityUrl,         @"identityUrl mismatch");
    XCTAssertEqualObjects(expectedUserId,              credsOut.userId,              @"userId mismatch");
    XCTAssertEqualObjects(credsIn.instanceUrl,         credsOut.instanceUrl,         @"instanceUrl mismatch");
    XCTAssertEqualObjects(credsIn.apiInstanceUrl,      credsOut.apiInstanceUrl,      @"apiInstanceUrl mismatch");
    XCTAssertEqualObjects(credsIn.issuedAt,            credsOut.issuedAt,            @"issuedAt mismatch");
    XCTAssertEqualObjects(credsIn.contentDomain,       credsOut.contentDomain,       @"contentDomain mismatch");
    XCTAssertEqualObjects(credsIn.contentSid,          credsOut.contentSid,          @"contentSid mismatch");
    XCTAssertEqualObjects(credsIn.lightningDomain,     credsOut.lightningDomain,     @"lightningDomain mismatch");
    XCTAssertEqualObjects(credsIn.lightningSid,        credsOut.lightningSid,        @"lightningSid mismatch");
    XCTAssertEqualObjects(credsIn.vfDomain,            credsOut.vfDomain,            @"vfDomain mismatch");
    XCTAssertEqualObjects(credsIn.vfSid,               credsOut.vfSid,               @"vfSid mismatch");
    XCTAssertEqualObjects(credsIn.csrfToken,           credsOut.csrfToken,           @"csrfToken mismatch");
    XCTAssertEqualObjects(credsIn.cookieClientSrc,     credsOut.cookieClientSrc,     @"cookieClientSrc mismatch");
    XCTAssertEqualObjects(credsIn.cookieSidClient,     credsOut.cookieSidClient,     @"cookieSidClient mismatch");
    XCTAssertEqualObjects(credsIn.sidCookieName,       credsOut.sidCookieName,       @"sidCookieName mismatch");
    XCTAssertEqualObjects(credsIn.parentSid,           credsOut.parentSid,           @"parentSid mismatch");
    XCTAssertEqualObjects(credsIn.tokenFormat,         credsOut.tokenFormat,         @"tokenFormat mismatch");
    XCTAssertEqualObjects(credsIn.beaconChildConsumerKey,    credsOut.beaconChildConsumerKey,    @"beaconChildConsumerKey mismatch");
    XCTAssertEqualObjects(credsIn.beaconChildConsumerSecret, credsOut.beaconChildConsumerSecret, @"beaconChildConsumerSecret mismatch");
    XCTAssertEqualObjects(credsIn.additionalOAuthFields, credsOut.additionalOAuthFields, @"additionalFields mismatch");
    
    credsIn = nil;
}

- (void)testCredentialsCopying {
    NSString *domainToCheck = @"login.salesforce.com";
    NSString *redirectUriToCheck = @"redirectUri://done";
    NSString *jwtToCheck = @"jwtToken";
    NSString *refreshTokenToCheck = @"refreshToken";
    NSString *accessTokenToCheck = @"accessToken";
    NSString *orgIdToCheck = @"orgID";
    NSURL *instanceUrlToCheck = [NSURL URLWithString:@"https://na1.salesforce.com"];
    NSURL *apiInstanceUrlToCheck = [NSURL URLWithString:@"https://api.salesforce.com"];
    NSString *communityIdToCheck = @"communityID";
    NSURL *communityUrlToCheck = [NSURL URLWithString:@"https://mycomm.my.salesforce.com/customers"];
    NSDate *issuedAtToCheck = [NSDate date];
    NSURL *identityUrlToCheck = [NSURL URLWithString:@"https://login.salesforce.com/id/someOrg/someUser"];
    NSString *userIdToCheck = @"userID";
    NSString *contentDomainToCheck = @"mobilesdk.my.salesforce.com";
    NSString *contentSidToCheck = @"contentsid";
    NSString *lightningDomainToCheck = @"mobilesdk.lightning.force.com";
    NSString *lightningSidToCheck = @"lightningsid";
    NSString *vfDomainToCheck = @"mobilesdk.vf.force.com";
    NSString *vfSidToCheck = @"vfsid";
    NSString *csrfTokenToCheck = @"csrf-token-test";
    NSString *cookieClientSrcToCheck = @"cookie-client-src-test";
    NSString *cookieSidClientToCheck = @"cookie-sid-client";
    NSString *sidCookieNameToCheck = @"sid-cookie-name";
    NSString *parentSidToCheck = @"parent-sid";
    NSString *tokenFormatToCheck = @"token-format";
    NSString *beaconChildConsumerKeyCheck = @"beacon-child-consumer-key";
    NSString *beaconChildConsumerSecretCheck = @"beacon-child-consumer-secret";
    NSDictionary *additionalFieldsToCheck = @{ @"field1": @"field1Val" };
    
    SFOAuthCredentials *origCreds = [[SFOAuthCredentials alloc] initWithIdentifier:kIdentifier clientId:kClientId encrypted:YES];
    origCreds.domain = domainToCheck;
    origCreds.redirectUri = redirectUriToCheck;
    origCreds.jwt = jwtToCheck;
    origCreds.refreshToken = refreshTokenToCheck;
    origCreds.accessToken = accessTokenToCheck;
    origCreds.instanceUrl = instanceUrlToCheck;
    origCreds.apiInstanceUrl = apiInstanceUrlToCheck;
    origCreds.communityId = communityIdToCheck;
    origCreds.communityUrl = communityUrlToCheck;
    origCreds.issuedAt = issuedAtToCheck;
    origCreds.contentDomain = contentDomainToCheck;
    origCreds.contentSid = contentSidToCheck;
    origCreds.lightningDomain = lightningDomainToCheck;
    origCreds.lightningSid = lightningSidToCheck;
    origCreds.vfDomain = vfDomainToCheck;
    origCreds.vfSid = vfSidToCheck;
    origCreds.csrfToken = csrfTokenToCheck;
    origCreds.cookieClientSrc = cookieClientSrcToCheck;
    origCreds.cookieSidClient = cookieSidClientToCheck;
    origCreds.sidCookieName = sidCookieNameToCheck;
    origCreds.parentSid = parentSidToCheck;
    origCreds.tokenFormat = tokenFormatToCheck;
    origCreds.beaconChildConsumerKey = beaconChildConsumerKeyCheck;
    origCreds.beaconChildConsumerSecret = beaconChildConsumerSecretCheck;

    // NB: Intentionally ordering the setting of these, because setting the identity URL automatically
    // sets the OrgID and UserID.  This ensures the values stay in sync.
    origCreds.identityUrl = identityUrlToCheck;
    origCreds.organizationId = orgIdToCheck;
    origCreds.userId = userIdToCheck;
    
    origCreds.additionalOAuthFields = additionalFieldsToCheck;
    
    SFOAuthCredentials *copiedCreds = [origCreds copy];
    
    origCreds.domain = nil;
    origCreds.redirectUri = nil;
    origCreds.jwt = nil;
    origCreds.refreshToken = nil;
    origCreds.accessToken = nil;
    origCreds.organizationId = nil;
    origCreds.instanceUrl = nil;
    origCreds.apiInstanceUrl = nil;
    origCreds.communityId = nil;
    origCreds.communityUrl = nil;
    origCreds.issuedAt = nil;
    origCreds.identityUrl = nil;
    origCreds.userId = nil;
    origCreds.contentDomain = nil;
    origCreds.contentSid = nil;
    origCreds.lightningDomain = nil;
    origCreds.lightningSid = nil;
    origCreds.vfDomain = nil;
    origCreds.vfSid = nil;
    origCreds.csrfToken = nil;
    origCreds.cookieClientSrc = nil;
    origCreds.cookieSidClient = nil;
    origCreds.sidCookieName = nil;
    origCreds.parentSid = nil;
    origCreds.tokenFormat = nil;
    origCreds.beaconChildConsumerKey = nil;
    origCreds.beaconChildConsumerSecret = nil;
    origCreds.additionalOAuthFields = nil;
    
    XCTAssertNotEqual(origCreds, copiedCreds);
    XCTAssertEqual(copiedCreds.domain, domainToCheck);
    XCTAssertNotEqual(origCreds.domain, copiedCreds.domain);
    XCTAssertEqual(copiedCreds.redirectUri, redirectUriToCheck);
    XCTAssertNotEqual(origCreds.redirectUri, copiedCreds.redirectUri);
    XCTAssertEqual(copiedCreds.jwt, jwtToCheck);
    XCTAssertNotEqual(origCreds.jwt, copiedCreds.jwt);
    
    // NB: Fields stored in keychain cannot be distinct after copy and change
    XCTAssertNotEqual(copiedCreds.refreshToken, refreshTokenToCheck);
    XCTAssertEqual(origCreds.refreshToken, copiedCreds.refreshToken);
    XCTAssertNotEqual(copiedCreds.accessToken, accessTokenToCheck);
    XCTAssertEqual(origCreds.accessToken, copiedCreds.accessToken);
    XCTAssertNotEqual(copiedCreds.lightningSid, lightningSidToCheck);
    XCTAssertEqual(origCreds.lightningSid, copiedCreds.lightningSid);
    XCTAssertNotEqual(copiedCreds.vfSid, vfSidToCheck);
    XCTAssertEqual(origCreds.vfSid, copiedCreds.vfSid);
    XCTAssertNotEqual(copiedCreds.contentSid, contentSidToCheck);
    XCTAssertEqual(origCreds.contentSid, copiedCreds.contentSid);
    XCTAssertNotEqual(copiedCreds.csrfToken, csrfTokenToCheck);
    XCTAssertEqual(origCreds.csrfToken, copiedCreds.csrfToken);
    XCTAssertNotEqual(copiedCreds.parentSid, parentSidToCheck);
    XCTAssertEqual(origCreds.parentSid, copiedCreds.parentSid);
    XCTAssertNotEqual(copiedCreds.beaconChildConsumerKey, beaconChildConsumerKeyCheck);
    XCTAssertEqual(origCreds.beaconChildConsumerKey, copiedCreds.beaconChildConsumerKey);
    XCTAssertNotEqual(copiedCreds.beaconChildConsumerSecret, beaconChildConsumerSecretCheck);
    XCTAssertEqual(origCreds.beaconChildConsumerSecret, copiedCreds.beaconChildConsumerSecret);

    XCTAssertEqual(copiedCreds.organizationId, orgIdToCheck);
    XCTAssertNotEqual(origCreds.organizationId, copiedCreds.organizationId);
    XCTAssertEqual(copiedCreds.instanceUrl, instanceUrlToCheck);
    XCTAssertNotEqual(origCreds.instanceUrl, copiedCreds.instanceUrl);
    XCTAssertEqual(copiedCreds.apiInstanceUrl, apiInstanceUrlToCheck);
    XCTAssertNotEqual(origCreds.apiInstanceUrl, copiedCreds.apiInstanceUrl);
    XCTAssertEqual(copiedCreds.communityId, communityIdToCheck);
    XCTAssertNotEqual(origCreds.communityId, copiedCreds.communityId);
    XCTAssertEqual(copiedCreds.communityUrl, communityUrlToCheck);
    XCTAssertNotEqual(origCreds.communityUrl, copiedCreds.communityUrl);
    XCTAssertEqual(copiedCreds.issuedAt, issuedAtToCheck);
    XCTAssertNotEqual(origCreds.issuedAt, copiedCreds.issuedAt);
    XCTAssertEqual(copiedCreds.identityUrl, identityUrlToCheck);
    XCTAssertNotEqual(origCreds.identityUrl, copiedCreds.identityUrl);
    XCTAssertEqual(copiedCreds.userId, userIdToCheck);
    XCTAssertNotEqual(origCreds.userId, copiedCreds.userId);
    XCTAssertEqual(copiedCreds.contentDomain, contentDomainToCheck);
    XCTAssertNotEqual(origCreds.contentDomain, copiedCreds.contentDomain);
    XCTAssertEqual(copiedCreds.lightningDomain, lightningDomainToCheck);
    XCTAssertNotEqual(origCreds.lightningDomain, copiedCreds.lightningDomain);
    XCTAssertEqual(copiedCreds.vfDomain, vfDomainToCheck);
    XCTAssertNotEqual(origCreds.vfDomain, copiedCreds.vfDomain);
    XCTAssertEqual(copiedCreds.cookieClientSrc, cookieClientSrcToCheck);
    XCTAssertNotEqual(origCreds.cookieClientSrc, copiedCreds.cookieClientSrc);
    XCTAssertEqual(copiedCreds.cookieSidClient, cookieSidClientToCheck);
    XCTAssertNotEqual(origCreds.cookieSidClient, copiedCreds.cookieSidClient);
    XCTAssertEqual(copiedCreds.sidCookieName, sidCookieNameToCheck);
    XCTAssertNotEqual(origCreds.sidCookieName, copiedCreds.sidCookieName);
    XCTAssertEqual(copiedCreds.tokenFormat, tokenFormatToCheck);
    XCTAssertNotEqual(origCreds.tokenFormat, copiedCreds.tokenFormat);
    XCTAssertEqual(copiedCreds.additionalOAuthFields, additionalFieldsToCheck);
    XCTAssertNotEqual(origCreds.additionalOAuthFields, copiedCreds.additionalOAuthFields);
}

/** Test the SFOAuthCoordinator
 */
- (void)testCoordinator {
    
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:[[SFUserAccountManager sharedInstance] currentUser].credentials];
    XCTAssertNotNil(coordinator, @"coordinator should not be nil");
    SalesforceOAuthUnitTestsCoordinatorDelegate *delegate = [[SalesforceOAuthUnitTestsCoordinatorDelegate alloc] init];
    XCTAssertNotNil(delegate, @"delegate should not be nil");
    coordinator.delegate = delegate;
    XCTAssertNoThrow([coordinator authenticate], @"authenticate should not raise an exception");
    XCTAssertTrue([coordinator isAuthenticating], @"authenticating should return true");
    [coordinator stopAuthentication];
    XCTAssertFalse([coordinator isAuthenticating], @"authenticating should return false");

    [coordinator revokeAuthentication];
    coordinator = nil;
    delegate = nil;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

/**
 Test the case of instantiating the SFOAuthCoordinator using alloc/init, in which case the credentials property will be nil
 and therefore calling the authenticate method will raise an exception. Calling authenticateWithCredentials with a nil
 argument should also raise an exception.
 */
- (void)testCoordinatorDefaultInstantiation {
    
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] init];
    XCTAssertNotNil(coordinator, @"coordinator should not be nil");

    XCTAssertThrows([coordinator authenticate], @"authenticate with nil credentials should raise an exception");
    XCTAssertThrows([coordinator authenticateWithCredentials:nil], @"authenticate with nil credentials should raise an exception");
    
    coordinator = nil;
}

#pragma clang diagnostic pop

/** Test multiple identifiers.
 At this point, the test just ensures that the identifier is different then the client id.
 */
- (void)testMultipleUsers {
    
    NSString * const kUserA_Identifier   = @"userA";
    NSString * const kUserB_Identifier   = @"userB";    

    SFOAuthCredentials *ca = [[SFOAuthCredentials alloc] initWithIdentifier:kUserA_Identifier clientId:kClientId encrypted:YES];
    SFOAuthCredentials *cb = [[SFOAuthCredentials alloc] initWithIdentifier:kUserB_Identifier clientId:kClientId encrypted:YES];

    XCTAssertFalse([ca.identifier isEqual:ca.clientId], @"identifier and client id for user A must be different");
    XCTAssertFalse([cb.identifier isEqual:cb.clientId], @"identifier and client id for user B must be different");
    
    XCTAssertEqualObjects(ca.identifier, kUserA_Identifier, @"identifier for user A must match");
    XCTAssertEqualObjects(ca.clientId, kClientId, @"client id for user A must match");
    
    XCTAssertEqualObjects(cb.identifier, kUserB_Identifier, @"identifier for user B must match");
    XCTAssertEqualObjects(cb.clientId, kClientId, @"client id for user B must match");
    
    ca.clientId = @"testClientID";
    XCTAssertEqualObjects(ca.identifier, kUserA_Identifier, @"identifier must still match after changing clientId");
}

- (void)testDefaultTokenEncryption {
    NSString *accessToken = @"AllAccessPass$";
    NSString *refreshToken = @"RefreshFRESHexciting!";
    NSString *lightningSid = @"lighting-sid-test";
    NSString *vfSid = @"vf-sid-test";
    NSString *contentSid = @"content-sid-test";
    NSString *csrfToken = @"csrf-test";

    SFOAuthKeychainCredentials *credentials = [[SFOAuthKeychainCredentials alloc] initWithIdentifier:kIdentifier clientId:kClientId encrypted:YES];
    credentials.accessToken = accessToken;
    credentials.refreshToken = refreshToken;
    credentials.lightningSid = lightningSid;
    credentials.vfSid = vfSid;
    credentials.contentSid = contentSid;
    credentials.csrfToken = csrfToken;
   
    NSString *accessTokenVerify = [credentials decryptedTokenForService:kSFOAuthServiceAccess];
    XCTAssertEqualObjects(accessToken, accessTokenVerify, @"Access token should decrypt to the same value.");

    NSString *refreshTokenVerify = [credentials decryptedTokenForService:kSFOAuthServiceRefresh];
    XCTAssertEqualObjects(refreshToken, refreshTokenVerify, @"Refresh token should decrypt to the same value.");
    
    NSString *lightningSidVerify = [credentials decryptedTokenForService:kSFOAuthServiceLightningSid];
    XCTAssertEqualObjects(lightningSid, lightningSidVerify, @"Lightning sid should decrypt to the same value.");

    NSString *contentSidVerify = [credentials decryptedTokenForService:kSFOAuthServiceContentSid];
    XCTAssertEqualObjects(contentSid, contentSidVerify, @"content sid should decrypt to the same value.");

    NSString *vfSidVerify = [credentials decryptedTokenForService:kSFOAuthServiceVfSid];
    XCTAssertEqualObjects(vfSid, vfSidVerify, @"vf sid should decrypt to the same value.");

    NSString *csrfTokenVerify = [credentials decryptedTokenForService:kSFOAuthServiceCsrf];
    XCTAssertEqualObjects(csrfToken, csrfTokenVerify, @"csrf token should decrypt to the same value.");
    
    [credentials revoke];
}

@end
