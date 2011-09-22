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

#import "SalesforceSDKTests.h"

#import "RKReachabilityObserver.h"
#import "RestKit.h"
#import "SBJSON.h"
#import "SBJsonParser.h"
#import "SFOAuthCoordinator.h"
#import "SFOAuthCredentials.h"
#import "SFRestAPI+Internal.h"
#import "SFRestRequest.h"
#import "TestRequestListener.h"

//TODO cleanup this stuff before publishing
// -------------
#define DEFAULT_HOST @"na1-blitz02.soma.salesforce.com"
#define DEFAULT_CLIENT_ID @"3MVG9PhR6g6B7ps5qYgHpH7_y81rzx5N627yUg6rhQpEHUyz1ugyEV93J7yD3RKbyx0ANlspDFYy8EwGsY2p5"
#define DEFAULT_REDIRECT_URL @"sfdc:///axm/detect/oauth/done"
// -------------


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



- (void)setUp
{
    // Set-up code here.
    [_requestListener release]; _requestListener = nil;
    if (nil == [[SFRestAPI sharedInstance] coordinator]) {
        [[self class] readTokenFile];
    }
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
    NSString *accessToken = @"fubar"; //[dictResponse objectForKey:@"access_token"];
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


- (NSString *)sendSyncRequest:(SFRestRequest *)request {
    _requestListener = [[TestRequestListener alloc] initWithRestRequest:request];
    //TODO replace local response handling with TestRequestListener
    
    self.apiJsonResponse = nil;
    self.apiError = nil;
    self.apiErrorRequest = nil;
    self.apiReturnStatus = kTestRequestStatusWaiting;
    
    [[SFRestAPI sharedInstance] send:request delegate:self];
    while ([self.apiReturnStatus isEqualToString:kTestRequestStatusWaiting]) {
        NSLog(@"## sleeping...");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    return self.apiReturnStatus;
}

#pragma mark - SFRestDelegate

- (void)request:(SFRestRequest *)request didLoadResponse:(id)jsonResponse {
    self.apiJsonResponse = jsonResponse;
    self.apiReturnStatus = kTestRequestStatusDidLoad;
}

- (void)request:(SFRestRequest*)request didFailLoadWithError:(NSError*)error {
    self.apiError = error;
    self.apiReturnStatus = kTestRequestStatusDidFail;
}

- (void)requestDidCancelLoad:(SFRestRequest *)request {
    self.apiErrorRequest = request;
    self.apiReturnStatus = kTestRequestStatusDidCancel;
}

- (void)requestDidTimeout:(SFRestRequest *)request {
    self.apiErrorRequest = request;
    self.apiReturnStatus = kTestRequestStatusDidTimeout;
}


#pragma mark - tests

- (void)testSingletonStartup {
    //this destroys the singleton created in setUp
    [SFRestAPI clearSharedInstance];
    @try {
        SFRestAPI *api = [SFRestAPI sharedInstance];
        STAssertNotNil(api, @"[SFRestAPI sharedInstance] should never return nil");
        STAssertNil(api.coordinator, @"SFRestAPI.coordinator should be initially nil");
        STAssertNil(api.rkClient ,  @"SFRestAPI.rkClient should be initially nil");
    }
    @finally {
        [SFRestAPI clearSharedInstance];
    }
}


// simple: just invoke requestForVersions
- (void)testGetVersions {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForVersions];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForResources
- (void)testGetResources {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForDescribeGlobal
- (void)testGetDescribeGlobal {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForMetadataWithObjectType:@"Contact"
- (void)testGetMetadataWithObjectType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForMetadataWithObjectType:@"Contact"];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForDescribeWithObjectType:@"Contact"
- (void)testGetDescribeWithObjectType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeWithObjectType:@"Contact"];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
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
    STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");

    // make sure we got an id
    NSString *contactId = [[[(NSDictionary *)self.apiJsonResponse objectForKey:@"id"] retain] autorelease];
    STAssertNotNil(contactId, @"id not present");
    
    @try {
        // try to retrieve object with id
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:contactId fieldList:nil];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
        STAssertEqualObjects(lastName, [(NSDictionary *)self.apiJsonResponse objectForKey:@"LastName"], @"invalid last name");
        STAssertEqualObjects(@"John", [(NSDictionary *)self.apiJsonResponse objectForKey:@"FirstName"], @"invalid first name");
        
        // try to retrieve again, passing a list of fields
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:contactId fieldList:@"LastName, FirstName"];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
        STAssertEqualObjects(lastName, [(NSDictionary *)self.apiJsonResponse objectForKey:@"LastName"], @"invalid last name");
        STAssertEqualObjects(@"John", [(NSDictionary *)self.apiJsonResponse objectForKey:@"FirstName"], @"invalid first name");
        
        // now query object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSArray *records = [(NSDictionary *)self.apiJsonResponse objectForKey:@"records"];
        STAssertEquals((int)[records count], 1, @"expected just one query result");
        
        // now search object
        request = [[SFRestAPI sharedInstance] requestForSearch:[NSString stringWithFormat:@"Find {%@}", soslLastName]];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
        records = (NSArray *)self.apiJsonResponse;
        STAssertEquals((int)[records count], 1, @"expected just one search result");
    }
    @finally {
        // now delete object
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"Contact" objectId:contactId];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
    }
    
    // well, let's do another query just to be sure
    request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSArray *records = [(NSDictionary *)self.apiJsonResponse objectForKey:@"records"];
    STAssertEquals((int)[records count], 0, @"expected no result");

    // now search object
    request = [[SFRestAPI sharedInstance] requestForSearch:[NSString stringWithFormat:@"Find {%@}", soslLastName]];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
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
    STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // make sure we got an id
    NSString *contactId = [[[(NSDictionary *)self.apiJsonResponse objectForKey:@"id"] retain] autorelease];
    STAssertNotNil(contactId, @"id not present");
    NSLog(@"## contact created with id: %@", contactId);
    
    @try {
        // now query object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSArray *records = [(NSDictionary *)self.apiJsonResponse objectForKey:@"records"];
        STAssertEquals((int)[records count], 1, @"expected just one query result");
        
        // modify object
        NSDictionary *updatedFields = [NSDictionary dictionaryWithObjectsAndKeys:
                                       updatedLastName, @"LastName", 
                                       nil];
        request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:@"Contact" objectId:contactId fields:updatedFields];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");        
        
        // query updated object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", updatedLastName]]; 
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
        records = [(NSDictionary *)self.apiJsonResponse objectForKey:@"records"];
        STAssertEquals((int)[records count], 1, @"expected just one query result");

        // let's make sure the old object is not there anymore
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
        records = [(NSDictionary *)self.apiJsonResponse objectForKey:@"records"];
        STAssertEquals((int)[records count], 0, @"expected no result");
    }
    @finally {
        // now delete object
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"Contact" objectId:contactId];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
    }
    
    // well, let's do another query just to be sure
    request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", updatedLastName]];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSArray *records = [(NSDictionary *)self.apiJsonResponse objectForKey:@"records"];
    STAssertEquals((int)[records count], 0, @"expected no result");
}

// issue invalid SOQL and test for errors
- (void)testSOQLError {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:nil];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidFail , @"request was supposed to fail");
    STAssertEqualObjects(self.apiError.domain, kSFRestErrorDomain, @"invalid domain");
    STAssertEquals(self.apiError.code, kSFRestErrorCode, @"invalid code");
}

// issue invalid retrieve and test for errors
- (void)testRetrieveError {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:@"xyz" fieldList:nil];
    [self sendSyncRequest:request];
    STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
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
        
        // request (valid)
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSLog(@"latest access token: %@", [SFRestAPI sharedInstance].coordinator.credentials.accessToken);
        
        // let's make sure we have another access token
        NSString *newAccessToken = [SFRestAPI sharedInstance].coordinator.credentials.accessToken;
        STAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"token wasnt changed");
        STAssertTrue([newAccessToken isEqualToString:validAccessToken], @"token wasnt changed");
    }
    @finally {
        // restore token
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = validAccessToken;       
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
        
        // request (invalid)
        SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:nil];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");

        // let's make sure we have another access token
        NSString *newAccessToken = [SFRestAPI sharedInstance].coordinator.credentials.accessToken;
        STAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"token wasnt changed");
        STAssertTrue([newAccessToken isEqualToString:validAccessToken], @"token wasnt changed");
    }
    @finally {
        // restore token
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = validAccessToken;      
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
        
        // request (valid)
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources];
        [self sendSyncRequest:request];
        STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidFail, @"request should have failed");
        STAssertEqualObjects(self.apiError.domain, kSFOAuthErrorDomain, @"invalid domain");
        STAssertEquals(self.apiError.code, kSFRestErrorCode, @"invalid code");
        STAssertNotNil(self.apiError.userInfo, nil);
    }
    @finally {
        // restore token
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = validAccessToken;
        [SFRestAPI sharedInstance].coordinator.credentials.refreshToken = validRefreshToken;     
    }
}


- (void)testDelegateSetUnset {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForVersions];
    request.delegate = self;
    self.apiJsonResponse = nil;
    self.apiError = nil;
    self.apiErrorRequest = nil;
    self.apiReturnStatus = kTestRequestStatusWaiting;
    
    //delegate is already set on the request directly
    [[SFRestAPI sharedInstance] send:request delegate:nil];
    while ([self.apiReturnStatus isEqualToString:kTestRequestStatusWaiting]) {
        NSLog(@"## sleeping...");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    //now unset the delegate and ensure we don't get called back
    request.delegate = nil;
    self.apiJsonResponse = nil;
    self.apiError = nil;
    self.apiErrorRequest = nil;
    self.apiReturnStatus = kTestRequestStatusWaiting;
    
    [[SFRestAPI sharedInstance] send:request delegate:nil];
    //no delegate means we'll never receive a callback
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
    STAssertEqualObjects(self.apiReturnStatus, kTestRequestStatusWaiting, @"received a callback when we shouldn't have");

}


// - set an invalid access token (simulate expired)
// - make multiple simultaneous requests
// - requests will fail in some arbitrary order
// - ensure that a new access token is retrieved using refresh token
// - ensure that all requests eventually succeed
//
-(void)testMultipleTransactionOauthFailures {
    // save valid token
    NSString *validAccessToken = [SFRestAPI sharedInstance].coordinator.credentials.accessToken;
    @try {
        // save invalid token
        NSString *invalidAccessToken = @"xyz";
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = invalidAccessToken;
        
        // request (valid)
        SFRestRequest* request0 = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
        TestRequestListener *listener0 = [[[TestRequestListener alloc] initWithRestRequest:request0] autorelease];
        
        SFRestRequest* request1 = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
        TestRequestListener *listener1 = [[[TestRequestListener alloc] initWithRestRequest:request1] autorelease];
        
        SFRestRequest* request2 = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
        TestRequestListener *listener2 = [[[TestRequestListener alloc] initWithRestRequest:request2] autorelease];

        SFRestRequest* request3 = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
        TestRequestListener *listener3 = [[[TestRequestListener alloc] initWithRestRequest:request3] autorelease];
        
        SFRestRequest* request4 = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
        TestRequestListener *listener4 = [[[TestRequestListener alloc] initWithRestRequest:request4] autorelease];
       
        //send multiple requests, all of which should fail with "unauthorized" 
        [[SFRestAPI sharedInstance] send:request0 delegate:nil];
        [[SFRestAPI sharedInstance] send:request1 delegate:nil];
        [[SFRestAPI sharedInstance] send:request2 delegate:nil];
        [[SFRestAPI sharedInstance] send:request3 delegate:nil];
        [[SFRestAPI sharedInstance] send:request4 delegate:nil];
        
        NSDate *startTime = [NSDate date] ;
        while ([listener0.returnStatus isEqualToString:kTestRequestStatusWaiting] || 
               [listener1.returnStatus isEqualToString:kTestRequestStatusWaiting] ||
               [listener2.returnStatus isEqualToString:kTestRequestStatusWaiting] ||
               [listener3.returnStatus isEqualToString:kTestRequestStatusWaiting] ||
               [listener4.returnStatus isEqualToString:kTestRequestStatusWaiting] 
               ) {
            NSLog(@"## sleeping...");
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
            if (elapsed > 120.0) {
                STAssertTrue(elapsed < 120.0, @"Transactions took too long to complete");
                break;
            }
        }
        
        STAssertEqualObjects(listener0.returnStatus, kTestRequestStatusDidLoad, @"request0 failed");
        STAssertEqualObjects(listener1.returnStatus, kTestRequestStatusDidLoad, @"request1 failed");
        STAssertEqualObjects(listener2.returnStatus, kTestRequestStatusDidLoad, @"request2 failed");
        STAssertEqualObjects(listener3.returnStatus, kTestRequestStatusDidLoad, @"request3 failed");
        STAssertEqualObjects(listener4.returnStatus, kTestRequestStatusDidLoad, @"request4 failed");
        
        // let's make sure we have a new access token
        NSString *newAccessToken = [SFRestAPI sharedInstance].coordinator.credentials.accessToken;

        STAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"token wasn't changed");
        STAssertTrue([newAccessToken isEqualToString:validAccessToken], @"credentials.accessToken mismatch");
        
    }
    @finally {
        // restore token
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = validAccessToken;
    }
}

@end