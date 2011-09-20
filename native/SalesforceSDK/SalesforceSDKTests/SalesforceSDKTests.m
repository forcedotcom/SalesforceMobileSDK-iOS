//
//  SalesforceSDKTests.m
//  SalesforceSDKTests
//
//  Created by Didier Prophete on 7/20/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import "SalesforceSDKTests.h"

#import "RKReachabilityObserver.h"
#import "RestKit.h"
#import "SBJSON.h"
#import "SBJsonParser.h"
#import "SFOAuthCoordinator.h"
#import "SFOAuthCredentials.h"
#import "SFRestAPI.h"
#import "SFRestRequest.h"


#define DEFAULT_HOST @"na1-blitz02.soma.salesforce.com"
#define DEFAULT_CLIENT_ID @"3MVG9PhR6g6B7ps5qYgHpH7_y81rzx5N627yUg6rhQpEHUyz1ugyEV93J7yD3RKbyx0ANlspDFYy8EwGsY2p5"
#define DEFAULT_REDIRECT_URL @"sfdc:///axm/detect/oauth/done"

// easier than an enum to NSLog...
NSString* const kWaiting = @"waiting";
NSString* const kDidLoad = @"didLoad";
NSString* const kDidFail = @"didFail";
NSString* const kDidCancel = @"didCancel";
NSString* const kDidTimeout = @"didTimeout";


@interface SalesforceSDKTests (private)
+ (NSString *)urlEncodeValue:(NSString *)str;
+ (void)readTokenFile;
- (NSString *)sendSyncRequest:(SFRestRequest *)request;
@end

@implementation SalesforceSDKTests

@synthesize apiJsonResponse;
@synthesize apiError;
@synthesize apiErrorRequest;
@synthesize apiReturnStatus;

+(void)initialize {
    [self readTokenFile];
}

- (void)setUp
{
    // Set-up code here.
    [super setUp];
}

- (void)tearDown
{
    // Tear-down code here.    
    [super tearDown];
}


#pragma mark - help methods

+ (void)readTokenFile {
    // so, the shell script run at build time will have fetched the refresh token, etc...
    NSString *tokenPath = [[NSBundle bundleForClass:self] pathForResource:@"token" ofType:@"json"];
    NSData *tokenJson = [[NSFileManager defaultManager] contentsAtPath:tokenPath];
    
    SBJsonParser *parser = [[SBJsonParser alloc] init];
    id jsonResponse = [parser objectWithData:tokenJson];
    [parser release];
    
    NSDictionary *dictResponse = (NSDictionary *)jsonResponse;
    NSString *accessToken = [dictResponse objectForKey:@"access_token"];
    NSString *refreshToken = [dictResponse objectForKey:@"refresh_token"];
    NSString *instanceUrl = [dictResponse objectForKey:@"instance_url"];

    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:DEFAULT_CLIENT_ID];
    credentials.domain = DEFAULT_HOST;
    credentials.redirectUri = DEFAULT_REDIRECT_URL;
    credentials.instanceUrl = [NSURL URLWithString:instanceUrl];
    credentials.accessToken = accessToken;
    credentials.refreshToken = refreshToken;
    
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:credentials];
    [credentials release];
    
    [[SFRestAPI sharedInstance] setCoordinator:coordinator];
    [coordinator release];
}

// return true if request did load
- (NSString *)sendSyncRequest:(SFRestRequest *)request {
    self.apiJsonResponse = nil;
    self.apiError = nil;
    self.apiErrorRequest = nil;
    self.apiReturnStatus = kWaiting;
    
    [[SFRestAPI sharedInstance] send:request delegate:self];
    while ([self.apiReturnStatus isEqualToString:kWaiting]) {
        NSLog(@"## sleeping...");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    return self.apiReturnStatus;
}

#pragma mark - SFRestDelegate

- (void)request:(SFRestRequest *)request didLoadResponse:(id)jsonResponse {
    self.apiJsonResponse = jsonResponse;
    self.apiReturnStatus = kDidLoad;
}

- (void)request:(SFRestRequest*)request didFailLoadWithError:(NSError*)error {
    self.apiError = error;
    self.apiReturnStatus = kDidFail;
}

- (void)requestDidCancelLoad:(SFRestRequest *)request {
    self.apiErrorRequest = request;
    self.apiReturnStatus = kDidCancel;
}

- (void)requestDidTimeout:(SFRestRequest *)request {
    self.apiErrorRequest = request;
    self.apiReturnStatus = kDidTimeout;
}


#pragma mark - tests

// simple: just invoke requestForVersions
- (void)testGetVersions {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForVersions];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
}

// simple: just invoke requestForResources
- (void)testGetResources {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
}

// simple: just invoke requestForResources
- (void)testGetDescribeGlobal {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
}

// simple: just invoke requestForMetadataWithObjectType:@"Contact"
- (void)testGetMetadataWithObjectType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForMetadataWithObjectType:@"Contact"];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
}

// simple: just invoke requestForDescribeWithObjectType:@"Contact"
- (void)testGetDescribeWithObjectType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeWithObjectType:@"Contact"];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
}

// - create object (requestForCreateWithObjectType)
// - retrieve new object using object id (with all fields)
// - retrieve new object using object id (with only a few fields)
// - query new object (requestForQuery) and make sure we just got 1 object
// - search new object (requestForSearch) and make sure we just got 1 object
// - delete object (requestForDeleteWithObjectType)
// - query new object (requestForQuery) and make sure we don't get anything
// - search new object (requestForSearch) and make sure we don't get anything
- (void)testCreateQuerySearchDelete {
    // create object
    NSString *lastName = [NSString stringWithFormat:@"Doe-%@", [NSDate date]];
    NSString *soslLastName = [[[lastName stringByReplacingOccurrencesOfString:@"-" withString:@"\\-"] 
                               stringByReplacingOccurrencesOfString:@":" withString:@"\\:"]
                              stringByReplacingOccurrencesOfString:@"+" withString:@"\\+"];

    NSDictionary *fields = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"John", @"FirstName", 
                             lastName, @"LastName", 
                             nil];

    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:@"Contact" fields:fields];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");

    // make sure we got an id
    NSString *contactId = [[[(NSDictionary *)self.apiJsonResponse objectForKey:@"id"] retain] autorelease];
    STAssertNotNil(contactId, @"id not present");
    
    @try {
        // try to retrieve object with id
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:contactId fieldList:nil];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
        STAssertEqualObjects(lastName, [(NSDictionary *)self.apiJsonResponse objectForKey:@"LastName"], @"invalid last name");
        STAssertEqualObjects(@"John", [(NSDictionary *)self.apiJsonResponse objectForKey:@"FirstName"], @"invalid first name");
        
        // try to retrieve again, passing a list of fields
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:contactId fieldList:@"LastName, FirstName"];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
        STAssertEqualObjects(lastName, [(NSDictionary *)self.apiJsonResponse objectForKey:@"LastName"], @"invalid last name");
        STAssertEqualObjects(@"John", [(NSDictionary *)self.apiJsonResponse objectForKey:@"FirstName"], @"invalid first name");
        
        // now query object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
        NSArray *records = [(NSDictionary *)self.apiJsonResponse objectForKey:@"records"];
        STAssertEquals((int)[records count], 1, @"expected just one query result");
        
        // now search object
        request = [[SFRestAPI sharedInstance] requestForSearch:[NSString stringWithFormat:@"Find {%@}", soslLastName]];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
        records = (NSArray *)self.apiJsonResponse;
        STAssertEquals((int)[records count], 1, @"expected just one search result");
    }
    @finally {
        // now delete object
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"Contact" objectId:contactId];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
    }
    
    // well, let's do another query just to be sure
    request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
    NSArray *records = [(NSDictionary *)self.apiJsonResponse objectForKey:@"records"];
    STAssertEquals((int)[records count], 0, @"expected no result");

    // now search object
    request = [[SFRestAPI sharedInstance] requestForSearch:[NSString stringWithFormat:@"Find {%@}", soslLastName]];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
    records = (NSArray *)self.apiJsonResponse;
    STAssertEquals((int)[records count], 0, @"expected no result");
}

// - create object (requestForCreateWithObjectType)
// - query new object (requestForQuery) and make sure we just got 1 object
// - update object
// - query updated object (requestForQuery) and make sure we just got 1 object
// - query old object (requestForSearch) and make sure we don't get anything
// - delete object (requestForDeleteWithObjectType)
// - query updated object (requestForSearch) and make sure we don't get anything
- (void)testCreateUpdateQuerySearchDelete {
    // create object
    NSString *lastName = [NSString stringWithFormat:@"Doe-%@", [NSDate date]];
    NSString *updatedLastName = [lastName stringByAppendingString:@"xyz"];
    
    NSDictionary *fields = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"John", @"FirstName", 
                            lastName, @"LastName", 
                            nil];
    
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:@"Contact" fields:fields];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
    
    // make sure we got an id
    NSString *contactId = [[[(NSDictionary *)self.apiJsonResponse objectForKey:@"id"] retain] autorelease];
    STAssertNotNil(contactId, @"id not present");
    NSLog(@"## contact created with id: %@", contactId);
    
    @try {
        // now query object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
        NSArray *records = [(NSDictionary *)self.apiJsonResponse objectForKey:@"records"];
        STAssertEquals((int)[records count], 1, @"expected just one query result");
        
        // modify object
        NSDictionary *updatedFields = [NSDictionary dictionaryWithObjectsAndKeys:
                                       updatedLastName, @"LastName", 
                                       nil];
        request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:@"Contact" objectId:contactId fields:updatedFields];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");        
        
        // query updated object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", updatedLastName]]; 
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
        records = [(NSDictionary *)self.apiJsonResponse objectForKey:@"records"];
        STAssertEquals((int)[records count], 1, @"expected just one query result");

        // let's make sure the old object is not there anymore
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
        records = [(NSDictionary *)self.apiJsonResponse objectForKey:@"records"];
        STAssertEquals((int)[records count], 0, @"expected no result");
    }
    @finally {
        // now delete object
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"Contact" objectId:contactId];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
    }
    
    // well, let's do another query just to be sure
    request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", updatedLastName]];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
    NSArray *records = [(NSDictionary *)self.apiJsonResponse objectForKey:@"records"];
    STAssertEquals((int)[records count], 0, @"expected no result");
}

// issue invalid SOQL and test for errors
- (void)testSOQLError {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:nil];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kDidFail, @"request was supposed to fail");
    STAssertEqualObjects(self.apiError.domain, kSFRestErrorDomain, @"invalid domain");
    STAssertEquals(self.apiError.code, kSFRestErrorCode, @"invalid code");
}

// issue invalid retrieve and test for errors
- (void)testRetrieveError {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:@"xyz" fieldList:nil];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kDidFail, @"request was supposed to fail");
    STAssertEqualObjects(self.apiError.domain, kSFRestErrorDomain, @"invalid domain");
    STAssertEquals(self.apiError.code, kSFRestErrorCode, @"invalid code");
}

// - sets an invalid accessToken
// - issue a valid REST request
// - make sure the SDK will:
//   - do a oauth token exchange to get a new valid accessToken
//   - reissue the REST request
// - make sure the query gets replayed properly (and succeed)
- (void)testInvalidAccessTokenWithValidRequest {
    // save valid token
    NSString *validAccessToken = [SFRestAPI sharedInstance].coordinator.credentials.accessToken;
    @try {
        // save invalid token
        NSString *invalidAccessToken = @"xyz";
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = invalidAccessToken;
        [[SFRestAPI sharedInstance].rkClient setValue:[NSString stringWithFormat:@"OAuth %@", invalidAccessToken] forHTTPHeaderField:@"Authorization"];
        
        // request (valid)
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kDidLoad, @"request failed");
        
        // let's make sure we have another access token
        NSString *newAccessToken = [SFRestAPI sharedInstance].coordinator.credentials.accessToken;
        STAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"token wasnt changed");
        STAssertTrue([newAccessToken isEqualToString:validAccessToken], @"token wasnt changed");
    }
    @finally {
        // restore token
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = validAccessToken;
        [[SFRestAPI sharedInstance].rkClient setValue:[NSString stringWithFormat:@"OAuth %@", validAccessToken] forHTTPHeaderField:@"Authorization"];        
    }
}


// - sets an invalid accessToken
// - issue an invalid REST request
// - make sure the SDK will:
//   - do a oauth token exchange to get a new valid accessToken
//   - reissue the REST request
// - make sure the query gets replayed properly (and fail)
- (void)testInvalidAccessTokenWithInvalidRequest {
    // save valid token
    NSString *validAccessToken = [SFRestAPI sharedInstance].coordinator.credentials.accessToken;
    @try {
        // save invalid token
        NSString *invalidAccessToken = @"xyz";
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = invalidAccessToken;
        [[SFRestAPI sharedInstance].rkClient setValue:[NSString stringWithFormat:@"OAuth %@", invalidAccessToken] forHTTPHeaderField:@"Authorization"];
        
        // request (invalid)
        SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:nil];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kDidFail, @"request was supposed to fail");

        // let's make sure we have another access token
        NSString *newAccessToken = [SFRestAPI sharedInstance].coordinator.credentials.accessToken;
        STAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"token wasnt changed");
        STAssertTrue([newAccessToken isEqualToString:validAccessToken], @"token wasnt changed");
    }
    @finally {
        // restore token
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = validAccessToken;
        [[SFRestAPI sharedInstance].rkClient setValue:[NSString stringWithFormat:@"OAuth %@", validAccessToken] forHTTPHeaderField:@"Authorization"];        
    }
}

// - sets an invalid accessToken
// - sets an invalid refreshToken
// - issue a valid REST request
// - make sure the token exchange failed
- (void)testInvalidAccessAndRefreshToken {
    // save valid token
    NSString *validAccessToken = [SFRestAPI sharedInstance].coordinator.credentials.accessToken;
    NSString *validRefreshToken = [SFRestAPI sharedInstance].coordinator.credentials.refreshToken;
    @try {
        // save invalid token
        NSString *invalidAccessToken = @"xyz";
        NSString *invalidRefreshToken = @"xyz";
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = invalidAccessToken;
        [SFRestAPI sharedInstance].coordinator.credentials.refreshToken = invalidRefreshToken;
        [[SFRestAPI sharedInstance].rkClient setValue:[NSString stringWithFormat:@"OAuth %@", invalidAccessToken] forHTTPHeaderField:@"Authorization"];
        
        // request (valid)
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kDidFail, @"request should have fail");
        STAssertEqualObjects(self.apiError.domain, kSFOAuthErrorDomain, @"invalid domain");
        STAssertEquals(self.apiError.code, kSFRestErrorCode, @"invalid code");
        STAssertNotNil(self.apiError.userInfo, nil);
    }
    @finally {
        // restore token
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = validAccessToken;
        [SFRestAPI sharedInstance].coordinator.credentials.refreshToken = validRefreshToken;
        [[SFRestAPI sharedInstance].rkClient setValue:[NSString stringWithFormat:@"OAuth %@", validAccessToken] forHTTPHeaderField:@"Authorization"];        
    }
}
@end