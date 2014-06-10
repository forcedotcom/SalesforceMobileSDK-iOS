/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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

#import "SFOAuthCoordinator.h"
#import "SFOAuthCredentials.h"
#import "SFOAuthCredentials+Internal.h"
#import "SalesforceOAuthUnitTestsCoordinatorDelegate.h"
#import "SalesforceOAuthUnitTests.h"
#import <SalesforceSecurity/SFSDKCryptoUtils.h>

static NSString * const kIdentifier = @"com.salesforce.ios.oauth.test";
static NSString * const kClientId   = @"SfdcMobileChatteriOS";

@interface SalesforceOAuthUnitTests ()

- (void)verifySuccessfulTokenUpdate:(NSString *)accessToken refreshToken:(NSString *)refreshToken;
- (void)verifyUnsuccessfulTokenUpdate;

@end

@implementation SalesforceOAuthUnitTests

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
    NSString * const kUserId15      = @"00530000004cwSi";       // 15 characters
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
    
    STAssertEqualObjects(credentials.identifier, kIdentifier, @"identifier must match initWithIdentifier arg");
    STAssertEqualObjects(credentials.clientId, kClientId, @"client ID must match initWithIdentifier arg");
    STAssertEqualObjects(credentials.accessToken, kAccessToken, @"access token mismatch");
    STAssertEqualObjects(credentials.refreshToken, kRefreshToken, @"refresh token mismatch");
    STAssertEqualObjects(credentials.userId, kUserId15, @"user ID (18) mismatch/truncation issue");
    
    credentials.userId = kUserId12;
    STAssertEqualObjects(credentials.userId, kUserId12, @"user ID (12) mismatch/truncation issue");
    
    [credentials revokeAccessToken];
    STAssertNil(credentials.accessToken, @"access token should be nil");
    
    [credentials revokeRefreshToken];
    STAssertNil(credentials.refreshToken, @"refresh token should be nil");
    // userId, instanceUrl, and issuedAt should all be nil after the refresh token is revoked
    STAssertNil(credentials.userId, @"userId should be nil");
    STAssertNil(credentials.issuedAt, @"instanceUrl should be nil");
    STAssertNil(credentials.issuedAt, @"issuedAt should be nil");
    
    credentials.accessToken = kAccessToken;
    credentials.refreshToken = kRefreshToken;
    STAssertEqualObjects(credentials.accessToken, kAccessToken, @"access token mismatch");
    STAssertEqualObjects(credentials.refreshToken, kRefreshToken, @"refresh token mismatch");
    
    [credentials revoke];
    STAssertNil(credentials.accessToken, @"access token should be nil");
    STAssertNil(credentials.accessToken, @"refresh token should be nil");
    
    credentials = nil;
}

/** Test the case of instantiating the credentials using alloc/init, in which case the identifier and clientId will both be nil.
 The credentials class requires the identifier to be set for nearly all operations, therefore under these circumstances most 
 public methods will raise an exception.
 */
- (void)testCredentialsDefaultInstantiation {
    
    NSString * identifier       = nil;
    NSString * clientId         = nil;
    NSString * accessToken      = nil;
    NSString * refreshToken     = nil;
    NSString * userId           = nil;
    NSString * activationCode   = nil;
    
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] init];
    
    STAssertNotNil(credentials, @"credentials object should not be nil");
    STAssertThrows(accessToken = credentials.accessToken, @"should raise exception if no identifier is set");
    STAssertThrows(credentials.accessToken = nil, @"should raise exception if no identifier is set");
    STAssertNoThrow(credentials.clientId = nil, @"should not raise exception if no identifier is set and should allow a nil argument");
    STAssertNoThrow(clientId = credentials.clientId, @"should not raise exception if no identifier is set");
    STAssertNoThrow(identifier = credentials.identifier, @"should not raise exception if no identifier is set");
    STAssertNoThrow(credentials.identifier = nil, @"should not raise exception if set to nil");
    STAssertNoThrow(credentials.identityUrl = nil, @"should not raise exception if set to nil");
    STAssertThrows(refreshToken = credentials.refreshToken, @"should raise exception if no identifier is set");
    STAssertThrows(credentials.refreshToken = nil, @"should raise exception if no identifier is set");
    STAssertThrows(activationCode = credentials.activationCode, @"should raise exception if no identifier is set");
    STAssertThrows(credentials.activationCode = nil, @"should raise exception if no identifier is set");
    STAssertNoThrow(userId = credentials.userId, @"should not raise exception if no identifier is set");
    STAssertNoThrow(credentials.userId = nil, @"should not raise exception if no identifier is set and should allow a nil argument");
    STAssertThrows([credentials revokeAccessToken], @"should raise exception if no identifier is set");
    STAssertThrows([credentials revokeRefreshToken], @"should raise exception if no identifier is set");
    STAssertThrows([credentials revokeActivationCode], @"should raise exception if no identifier is set");
    
    credentials = nil;
}

/** Test the <NSCoding> implementation of <SFOAuthCredentials>
 */
- (void)testCredentialsCoding {
    
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    
    SFOAuthCredentials *credsIn = [[SFOAuthCredentials alloc] initWithIdentifier:kIdentifier clientId:kClientId encrypted:YES];
    credsIn.domain          = @"login.salesforce.com";
    credsIn.redirectUri     = @"sfdc:///axm/detect/oauth/done";
    credsIn.organizationId  = @"org";
    credsIn.identityUrl     = [NSURL URLWithString:@"https://login.salesforce.com/ID/orgID/eighteenCharUsrXYZ"];
    credsIn.instanceUrl     = [NSURL URLWithString:@"http://www.salesforce.com"];
    credsIn.issuedAt        = [NSDate date];
    
    NSString *expectedUserId = @"eighteenCharUsr"; // derived from identityUrl, 18 character ID's are truncated to 15 chars
    
    [archiver encodeObject:credsIn forKey:@"creds"];
    [archiver finishEncoding];
    archiver = nil;
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    SFOAuthCredentials * credsOut = [unarchiver decodeObjectForKey:@"creds"];
    unarchiver = nil;
    
    STAssertNotNil(credsOut, @"couldn't unarchive credentials");
    
    STAssertEqualObjects(credsIn.identifier,        credsOut.identifier,        @"identifier mismatch");
    STAssertEqualObjects(credsIn.clientId,          credsOut.clientId,          @"clientId mismatch");
    STAssertEqualObjects(credsIn.domain,            credsOut.domain,            @"domain mismatch");
    STAssertEqualObjects(credsIn.redirectUri,       credsOut.redirectUri,       @"redirectUri mismatch");
    STAssertEqualObjects(credsIn.organizationId,    credsOut.organizationId,    @"organizationId mismatch");
    STAssertEqualObjects(credsIn.identityUrl,       credsOut.identityUrl,       @"identityUrl mistmatch");
    STAssertEqualObjects(expectedUserId,            credsOut.userId,            @"userId mismatch");
    STAssertEqualObjects(credsIn.instanceUrl,       credsOut.instanceUrl,       @"instanceUrl mismatch");
    STAssertEqualObjects(credsIn.issuedAt,          credsOut.issuedAt,          @"issuedAt mismatch");
    
    credsIn = nil;
}

/** Test the SFOAuthCoordinator
 */
- (void)testCoordinator {
    
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:kIdentifier clientId:kClientId encrypted:YES];
    STAssertNotNil(creds, @"credentials should not be nil");
    creds.domain = @"localhost";
    creds.redirectUri = @"sfdc://expected/to/fail";
    creds.refreshToken = @"refresh-token";
    
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    STAssertNotNil(coordinator, @"coordinator should not be nil");
    SalesforceOAuthUnitTestsCoordinatorDelegate *delegate = [[SalesforceOAuthUnitTestsCoordinatorDelegate alloc] init];
    STAssertNotNil(delegate, @"delegate should not be nil");
    coordinator.delegate = delegate;
    STAssertNoThrow([coordinator authenticate], @"authenticate should not raise an exception");
    STAssertTrue([coordinator isAuthenticating], @"authenticating should return true");
    [coordinator stopAuthentication];
    STAssertFalse([coordinator isAuthenticating], @"authenticating should return false");
    
    coordinator = nil;
    delegate = nil;
}

/**
 Test the case of instantiating the SFOAuthCoordinator using alloc/init, in which case the credentials property will be nil
 and therefore calling the authenticate method will raise an exception. Calling authenticateWithCredentials with a nil
 argument should also raise an exception.
 */
- (void)testCoordinatorDefaultInstantiation {
    
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] init];
    STAssertNotNil(coordinator, @"coordinator should not be nil");

    STAssertThrows([coordinator authenticate], @"authenticate with nil credentials should raise an exception");
    STAssertThrows([coordinator authenticateWithCredentials:nil], @"authenticate with nil credentials should raise an exception");
    
    coordinator = nil;
}

/** Test multiple identifiers.
 At this point, the test just ensures that the identifier is different then the client id.
 */
- (void)testMultipleUsers {
    
    NSString * const kUserA_Identifier   = @"userA";
    NSString * const kUserB_Identifier   = @"userB";    

    SFOAuthCredentials *ca = [[SFOAuthCredentials alloc] initWithIdentifier:kUserA_Identifier clientId:kClientId encrypted:YES];
    SFOAuthCredentials *cb = [[SFOAuthCredentials alloc] initWithIdentifier:kUserB_Identifier clientId:kClientId encrypted:YES];

    STAssertFalse([ca.identifier isEqual:ca.clientId], @"identifier and client id for user A must be different");
    STAssertFalse([cb.identifier isEqual:cb.clientId], @"identifier and client id for user B must be different");
    
    STAssertEqualObjects(ca.identifier, kUserA_Identifier, @"identifier for user A must match");
    STAssertEqualObjects(ca.clientId, kClientId, @"client id for user A must match");
    
    STAssertEqualObjects(cb.identifier, kUserB_Identifier, @"identifier for user B must match");
    STAssertEqualObjects(cb.clientId, kClientId, @"client id for user B must match");
    
    ca.clientId = @"testClientID";
    STAssertEqualObjects(ca.identifier, kUserA_Identifier, @"identifier must still match after changing clientId");
}

/**
 Test the various token encryption-and-decryption facilities.
 */
- (void)testTokenEncryptionDecryption
{
    NSString *accessToken = @"gimmeAccess!";
    NSString *refreshToken = @"IWannaRefresh!";
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:kIdentifier clientId:kClientId encrypted:YES];
    
    NSDictionary *keyDict = @{
                              @"mac":
                                  @[ [credentials keyMacForService:kSFOAuthServiceAccess], [credentials keyMacForService:kSFOAuthServiceRefresh] ],
                              @"vendorId":
                                  @[ [credentials keyVendorIdForService:kSFOAuthServiceAccess], [credentials keyVendorIdForService:kSFOAuthServiceRefresh] ],
                              @"baseAppId":
                                  @[ [credentials keyBaseAppIdForService:kSFOAuthServiceAccess], [credentials keyBaseAppIdForService:kSFOAuthServiceRefresh] ],
                              @"keyStore":
                                  @[ [credentials keyStoreKeyForService:kSFOAuthServiceAccess], [credentials keyStoreKeyForService:kSFOAuthServiceRefresh] ]
                              };
    
    for (NSString *encTypeKey in [keyDict allKeys]) {
        NSArray *encTypeArray = keyDict[encTypeKey];
        
        // Same keys for supported encryption and decryption
        NSString *retrievedAccessToken;
        NSString *retrievedRefreshToken;
        if ([encTypeKey isEqualToString:@"keyStore"]) {
            [credentials setAccessToken:accessToken withSFEncryptionKey:encTypeArray[0]];
            [credentials setRefreshToken:refreshToken withSFEncryptionKey:encTypeArray[1]];
            retrievedAccessToken = [credentials accessTokenWithSFEncryptionKey:encTypeArray[0]];
            retrievedRefreshToken = [credentials refreshTokenWithSFEncryptionKey:encTypeArray[1]];
        } else {
            [credentials setAccessToken:accessToken withKey:encTypeArray[0]];
            [credentials setRefreshToken:refreshToken withKey:encTypeArray[1]];
            retrievedAccessToken = [credentials accessTokenWithKey:encTypeArray[0]];
            retrievedRefreshToken = [credentials refreshTokenWithKey:encTypeArray[1]];
        }
        STAssertEqualObjects(accessToken, retrievedAccessToken, @"Access tokens do not match between storage and retrieval for '%@'.", encTypeKey);
        STAssertEqualObjects(refreshToken, retrievedRefreshToken, @"Refresh tokens do not match between storage and retrieval for '%@'.", encTypeKey);
        
        // Different keys between encryption and decryption (i.e. failed decryption)
        NSData *badDecryptKey = [@"grarBogusKey!" dataUsingEncoding:NSUTF8StringEncoding];
        if ([encTypeKey isEqualToString:@"keyStore"]) {
            [credentials setAccessToken:accessToken withSFEncryptionKey:encTypeArray[0]];
            [credentials setRefreshToken:refreshToken withSFEncryptionKey:encTypeArray[1]];
            NSData *badIv = [SFSDKCryptoUtils randomByteDataWithLength:32];
            SFEncryptionKey *badEncryptionKey = [[SFEncryptionKey alloc] initWithData:badDecryptKey initializationVector:badIv];
            retrievedAccessToken = [credentials accessTokenWithSFEncryptionKey:badEncryptionKey];
            retrievedRefreshToken = [credentials refreshTokenWithSFEncryptionKey:badEncryptionKey];
        } else {
            [credentials setAccessToken:accessToken withKey:encTypeArray[0]];
            [credentials setRefreshToken:refreshToken withKey:encTypeArray[1]];
            retrievedAccessToken = [credentials accessTokenWithKey:badDecryptKey];
            retrievedRefreshToken = [credentials refreshTokenWithKey:badDecryptKey];
        }
        STAssertEqualObjects(retrievedAccessToken, @"", @"Access token should be an empty string if it couldn't be decrypted.");
        STAssertEqualObjects(retrievedRefreshToken, @"", @"Refresh token should be an empty string if it couldn't be decrypted.");
    }
    
    [credentials revoke];
}

- (void)testDefaultTokenEncryption
{
    NSString *accessToken = @"AllAccessPass$";
    NSString *refreshToken = @"RefreshFRESHexciting!";
    
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:kIdentifier clientId:kClientId encrypted:YES];
    credentials.accessToken = accessToken;
    credentials.refreshToken = refreshToken;
    
    NSString *accessTokenVerify = [credentials accessTokenWithSFEncryptionKey:[credentials keyStoreKeyForService:kSFOAuthServiceAccess]];
    STAssertEqualObjects(accessToken, accessTokenVerify, @"Access token should decrypt to the same value.");
    NSString *refreshTokenVerify = [credentials refreshTokenWithSFEncryptionKey:[credentials keyStoreKeyForService:kSFOAuthServiceRefresh]];
    STAssertEqualObjects(refreshToken, refreshTokenVerify, @"Refresh token should decrypt to the same value.");
    SFOAuthCredsEncryptionType encType = [[NSUserDefaults standardUserDefaults] integerForKey:kSFOAuthEncryptionTypeKey];
    STAssertEquals(encType, kSFOAuthCredsEncryptionTypeKeyStore, @"Encryption type should be key store.");
    
    [credentials revoke];
}

/**
 Test the different token encryption update scenarios.
 */
- (void)testUpdateTokenEncryption
{
    NSString *accessToken = @"AccessGranted!";
    NSString *refreshToken = @"HowRefreshing";
    
    // Set MAC-key tokens, resetting update state to pre-update.
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:kIdentifier clientId:kClientId encrypted:YES];
    [credentials setAccessToken:accessToken withKey:[credentials keyMacForService:kSFOAuthServiceAccess]];
    [credentials setRefreshToken:refreshToken withKey:[credentials keyMacForService:kSFOAuthServiceRefresh]];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSFOAuthEncryptionTypeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // New credentials instantiation should convert the existing credentials to latest encryption scheme.
    [self verifySuccessfulTokenUpdate:accessToken refreshToken:refreshToken];
    
    // Set vendorId-key tokens, resetting update state to pre-update.
    credentials = [[SFOAuthCredentials alloc] initWithIdentifier:kIdentifier clientId:kClientId encrypted:YES];
    [credentials setAccessToken:accessToken withKey:[credentials keyVendorIdForService:kSFOAuthServiceAccess]];
    [credentials setRefreshToken:refreshToken withKey:[credentials keyVendorIdForService:kSFOAuthServiceRefresh]];
    [[NSUserDefaults standardUserDefaults] setInteger:kSFOAuthCredsEncryptionTypeIdForVendor forKey:kSFOAuthEncryptionTypeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // New credentials instantiation should convert the existing credentials to latest encryption scheme.
    [self verifySuccessfulTokenUpdate:accessToken refreshToken:refreshToken];
    
    // Set base app id tokens, resetting update state to pre-update.
    credentials = [[SFOAuthCredentials alloc] initWithIdentifier:kIdentifier clientId:kClientId encrypted:YES];
    [credentials setAccessToken:accessToken withKey:[credentials keyBaseAppIdForService:kSFOAuthServiceAccess]];
    [credentials setRefreshToken:refreshToken withKey:[credentials keyBaseAppIdForService:kSFOAuthServiceRefresh]];
    [[NSUserDefaults standardUserDefaults] setInteger:kSFOAuthCredsEncryptionTypeBaseAppId forKey:kSFOAuthEncryptionTypeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // New credentials instantiation should convert the existing credentials to latest encryption scheme.
    [self verifySuccessfulTokenUpdate:accessToken refreshToken:refreshToken];
    
    // Test update with bad MAC-key tokens (post-iOS7 scenario).
    NSString *badMacAddress = @"2F:00:00:00:00:00";
    credentials = [[SFOAuthCredentials alloc] initWithIdentifier:kIdentifier clientId:kClientId encrypted:YES];
    [credentials setAccessToken:accessToken withKey:[credentials keyWithSeed:badMacAddress service:kSFOAuthServiceAccess]];
    [credentials setRefreshToken:refreshToken withKey:[credentials keyWithSeed:badMacAddress service:kSFOAuthServiceRefresh]];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSFOAuthEncryptionTypeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // New credentials instantiation should nil out the tokens, since they can't be converted in iOS7 and later.
    [self verifyUnsuccessfulTokenUpdate];
    
    // Test update with bad vendorId-key tokens (identifierForVendor inexplicably changes).
    NSString *badVendorId = @"2F:00:00:00:00:00";  // Not even a vendorId format.  Guaranteed to be bad.
    credentials = [[SFOAuthCredentials alloc] initWithIdentifier:kIdentifier clientId:kClientId encrypted:YES];
    [credentials setAccessToken:accessToken withKey:[credentials keyWithSeed:badVendorId service:kSFOAuthServiceAccess]];
    [credentials setRefreshToken:refreshToken withKey:[credentials keyWithSeed:badVendorId service:kSFOAuthServiceRefresh]];
    [[NSUserDefaults standardUserDefaults] setInteger:kSFOAuthCredsEncryptionTypeIdForVendor forKey:kSFOAuthEncryptionTypeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // New credentials instantiation should nil out the tokens, since they can't be converted in iOS7 and later.
    [self verifyUnsuccessfulTokenUpdate];
    
    [credentials revoke];
}

#pragma mark - Private methods

- (void)verifySuccessfulTokenUpdate:(NSString *)accessToken refreshToken:(NSString *)refreshToken
{
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:kIdentifier clientId:kClientId encrypted:YES];
    NSString *accessTokenVerify = [credentials accessTokenWithSFEncryptionKey:[credentials keyStoreKeyForService:kSFOAuthServiceAccess]];
    STAssertEqualObjects(accessToken, accessTokenVerify, @"Access token should have been updated to key store encryption.");
    NSString *refreshTokenVerify = [credentials refreshTokenWithSFEncryptionKey:[credentials keyStoreKeyForService:kSFOAuthServiceRefresh]];
    STAssertEqualObjects(refreshToken, refreshTokenVerify, @"Refresh token should have been updated to key store encryption.");
    SFOAuthCredsEncryptionType encType = [[NSUserDefaults standardUserDefaults] integerForKey:kSFOAuthEncryptionTypeKey];
    STAssertEquals(encType, kSFOAuthCredsEncryptionTypeKeyStore, @"Encryption type should have been updated to key store.");
}

- (void)verifyUnsuccessfulTokenUpdate
{
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:kIdentifier clientId:kClientId encrypted:YES];
    NSString *accessTokenVerify = credentials.accessToken;
    STAssertNil(accessTokenVerify, @"Access token should be nil, since it cannot be converted with bad inputs.");
    NSString *refreshTokenVerify = credentials.refreshToken;
    STAssertNil(refreshTokenVerify, @"Refresh token should be nil, since it cannot be converted with bad inputs.");
    SFOAuthCredsEncryptionType encType = [[NSUserDefaults standardUserDefaults] integerForKey:kSFOAuthEncryptionTypeKey];
    STAssertEquals(encType, kSFOAuthCredsEncryptionTypeKeyStore, @"Encryption type still should have been updated to key store.");
}

@end
