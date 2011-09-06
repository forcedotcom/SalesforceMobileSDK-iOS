//
//  SFOAuthTest.m
//  SalesforceOAuth
//
//  Created by Steve Holly on 7/18/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import "SenTestCase_additions.h"
#import "SFOAuthCoordinator.h"
#import "SFOAuthCredentials.h"
#import "SalesforceOAuthUnitTestsCoordinatorDelegate.h"
#import "SalesforceOAuthUnitTests.h"

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
    NSString * const kCredsId       = @"SFOAuthCredentialsTest";
    NSString * const kAccessToken   = @"howAboutaNice";
    NSString * const kRefreshToken  = @"hawaiianPunch";
    NSString * const kUserId12      = @"00530000004c";          // 12 characters   00530000004cwSi
    NSString * const kUserId15      = @"00530000004cwSi";       // 15 characters
    NSString * const kUserId18      = @"00530000004cwSi123";    // 18 characters

    NSString * credsId      = kCredsId;
    NSString * accessToken  = kAccessToken;
    NSString * refreshToken = kRefreshToken;
    NSString * userId       = kUserId18;
    
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:credsId];
    credsId = nil;
    
    // the access and refresh tokens should only be set explicitly for test purposes
    credentials.accessToken  = accessToken;     accessToken = nil;
    credentials.refreshToken = refreshToken;    refreshToken = nil;
    credentials.userId       = userId;          userId = nil;
    
    STAssertEqualObjects(credentials.clientId, kCredsId, @"client ID must match initWithIdentifier arg");
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
}

/** Test the <NSCoding> implementation of <SFOAuthCredentials>
 */
- (void)testCredentialsCoding {
    
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    
    SFOAuthCredentials *credsIn = [[SFOAuthCredentials alloc] initWithIdentifier:@"SfdcMobileChatteriPad"];
    credsIn.protocol        = @"https";
    credsIn.domain          = @"login.salesforce.com";
    credsIn.redirectUri     = @"sfdc:///axm/detect/oauth/done";
    credsIn.organizationId  = @"org";
    credsIn.identityUrl     = [NSURL URLWithString:@"https://login.salesforce.com/ID/orgID/eighteenCharUsrXYZ"];
    credsIn.instanceUrl     = [NSURL URLWithString:@"http://www.salesforce.com"];
    credsIn.issuedAt        = [NSDate date];
    
    NSString *expectedUserId = @"eighteenCharUsr"; // derived from identityUrl, 18 character ID's are truncated to 15 chars
    
    [archiver encodeObject:credsIn forKey:@"creds"];
    [archiver finishEncoding];
    [archiver release]; archiver = nil;
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    SFOAuthCredentials * credsOut = [unarchiver decodeObjectForKey:@"creds"];
    [unarchiver release]; unarchiver = nil;
    
    STAssertNotNil(credsOut, @"couldn't unarchive credentials");
    
    STAssertEqualObjects(credsIn.protocol,          credsOut.protocol,          @"protocol mismatch");
    STAssertEqualObjects(credsIn.domain,            credsOut.domain,            @"domain mismatch");
    STAssertEqualObjects(credsIn.redirectUri,       credsOut.redirectUri,       @"redirectUri mismatch");
    STAssertEqualObjects(credsIn.organizationId,    credsOut.organizationId,    @"organizationId mismatch");
    STAssertEqualObjects(credsIn.identityUrl,       credsOut.identityUrl,       @"identityUrl mistmatch");
    STAssertEqualObjects(expectedUserId,            credsOut.userId,            @"userId mismatch");
    STAssertEqualObjects(credsIn.instanceUrl,       credsOut.instanceUrl,       @"instanceUrl mismatch");
    STAssertEqualObjects(credsIn.issuedAt,          credsOut.issuedAt,          @"issuedAt mismatch");
    
    [credsIn release]; credsIn = nil;
}

/** Test the SFOAuthCoordinator
 */
- (void)testCoordinator {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"SfdcMobileChatteriPad"];
    creds.protocol = @"http";
    creds.domain = @"localhost";
    creds.redirectUri = @"sfdc://expected/to/fail";
    creds.refreshToken = @"refresh-token";
    
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    SalesforceOAuthUnitTestsCoordinatorDelegate *delegate = [[SalesforceOAuthUnitTestsCoordinatorDelegate alloc] init];
    coordinator.delegate = delegate;
    [coordinator authenticate];
    STAssertTrue([coordinator isAuthenticating], @"authenticating should return true");
    [coordinator stopAuthentication];
    STAssertFalse([coordinator isAuthenticating], @"authenticating should return false");
    
    [coordinator release];  coordinator = nil;
    [delegate release];     delegate = nil;
}

@end
