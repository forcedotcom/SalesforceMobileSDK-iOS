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

#import "RKRequestDelegateWrapper.h"
#import "RKReachabilityObserver.h"
#import "RestKit.h"
#import "SBJSON.h"
#import "SBJsonParser.h"
#import "SFOAuthCoordinator.h"
#import "SFOAuthCredentials.h"
#import "SFRestAPI+Internal.h"
#import "SFRestRequest.h"
#import "TestRequestListener.h"
#import "TestSetupUtils.h"


@interface SalesforceSDKTests (Private)
- (NSString *)sendSyncRequest:(SFRestRequest *)request;
@end


@implementation SalesforceSDKTests

- (void)setUp
{
    // Set-up code here.
    [_requestListener release]; _requestListener = nil;
    [TestSetupUtils ensureCredentialsLoaded];
    [super setUp];
}

- (void)tearDown
{
    // Tear-down code here.    
    [super tearDown];
}


#pragma mark - help methods


- (NSString *)sendSyncRequest:(SFRestRequest *)request {
    [_requestListener release]; //in case there's any existing one hanging around
    _requestListener = [[TestRequestListener alloc] initWithRestRequest:request];
    
    [[SFRestAPI sharedInstance] send:request delegate:nil];
    [_requestListener waitForCompletion];
    
    return _requestListener.returnStatus;
}



#pragma mark - tests

- (void)testSingletonStartup {
    //this destroys the singleton created in setUp
    [TestSetupUtils clearSFRestAPISingleton];
    @try {
        SFRestAPI *api = [SFRestAPI sharedInstance];
        STAssertNotNil(api, @"[SFRestAPI sharedInstance] should never return nil");
        STAssertNil(api.coordinator, @"SFRestAPI.coordinator should be initially nil");
        STAssertNil(api.rkClient ,  @"SFRestAPI.rkClient should be initially nil");

    }
    @finally {
        [TestSetupUtils clearSFRestAPISingleton];
    }
    
    
}


// simple: just invoke requestForVersions
- (void)testGetVersions {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForVersions];
    [self sendSyncRequest:request];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

- (void)testGetVersion_SetDelegate {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForVersions];

    [_requestListener release]; //in case there's any existing one hanging around
    _requestListener = [[TestRequestListener alloc] initWithRestRequest:request];
    
    //exercises overwriting the delegate at send time
    [[SFRestAPI sharedInstance] send:request delegate:_requestListener];
    [_requestListener waitForCompletion];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForResources
- (void)testGetResources {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources];
    [self sendSyncRequest:request];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForDescribeGlobal
- (void)testGetDescribeGlobal {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    [self sendSyncRequest:request];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForDescribeGlobal, force a cancel & timeout
- (void)testGetDescribeGlobal_Cancel {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    
    [_requestListener release]; //in case there's any existing one hanging around
    _requestListener = [[TestRequestListener alloc] initWithRestRequest:request];
    [[SFRestAPI sharedInstance] send:request delegate:nil];

    [[[RKClient sharedClient] requestQueue] cancelAllRequests]; //blow them all away
    
    [_requestListener waitForCompletion];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidCancel, @"request should have been cancelled");

}

// simple: just invoke requestForDescribeGlobal, force a timeout
- (void)testGetDescribeGlobal_Timeout {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    
    [_requestListener release]; //in case there's any existing one hanging around
    _requestListener = [[TestRequestListener alloc] initWithRestRequest:request];
    [[SFRestAPI sharedInstance] send:request delegate:nil];
    
    RKRequestDelegateWrapper *activeRequest =  [[[SFRestAPI sharedInstance] activeRequests] anyObject];
    STAssertNotNil(activeRequest, @"should have activeRequest");
    [activeRequest requestDidTimeout:nil];
    [_requestListener waitForCompletion];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidTimeout, @"request should have timed out");
 
    //this cleans up the singleton RKClient
    [[[RKClient sharedClient] requestQueue] cancelAllRequests];

}

// simple: just invoke requestForMetadataWithObjectType:@"Contact"
- (void)testGetMetadataWithObjectType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForMetadataWithObjectType:@"Contact"];
    [self sendSyncRequest:request];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForDescribeWithObjectType:@"Contact"
- (void)testGetDescribeWithObjectType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeWithObjectType:@"Contact"];
    [self sendSyncRequest:request];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
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
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // make sure we got an id
    NSString *contactId = [[[(NSDictionary *)_requestListener.jsonResponse objectForKey:@"id"] retain] autorelease];
    STAssertNotNil(contactId, @"id not present");
    
    @try {
        // try to retrieve object with id
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:contactId fieldList:nil];
        [self sendSyncRequest:request];
        STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        STAssertEqualObjects(lastName, [(NSDictionary *)_requestListener.jsonResponse objectForKey:@"LastName"], @"invalid last name");
        STAssertEqualObjects(@"John", [(NSDictionary *)_requestListener.jsonResponse objectForKey:@"FirstName"], @"invalid first name");
        
        // try to retrieve again, passing a list of fields
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:contactId fieldList:@"LastName, FirstName"];
        [self sendSyncRequest:request];
        STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        STAssertEqualObjects(lastName, [(NSDictionary *)_requestListener.jsonResponse objectForKey:@"LastName"], @"invalid last name");
        STAssertEqualObjects(@"John", [(NSDictionary *)_requestListener.jsonResponse objectForKey:@"FirstName"], @"invalid first name");
        
        // now query object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
        [self sendSyncRequest:request];
        STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSArray *records = [(NSDictionary *)_requestListener.jsonResponse objectForKey:@"records"];
        STAssertEquals((int)[records count], 1, @"expected just one query result");
        
        // now search object
        request = [[SFRestAPI sharedInstance] requestForSearch:[NSString stringWithFormat:@"Find {%@}", soslLastName]];
        [self sendSyncRequest:request];
        STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        records = (NSArray *)_requestListener.jsonResponse;
        STAssertEquals((int)[records count], 1, @"expected just one search result");
    }
    @finally {
        // now delete object
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"Contact" objectId:contactId];
        [self sendSyncRequest:request];
        STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    }
    
    // well, let's do another query just to be sure
    request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
    [self sendSyncRequest:request];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSArray *records = [(NSDictionary *)_requestListener.jsonResponse objectForKey:@"records"];
    STAssertEquals((int)[records count], 0, @"expected no result");

    // now search object
    request = [[SFRestAPI sharedInstance] requestForSearch:[NSString stringWithFormat:@"Find {%@}", soslLastName]];
    [self sendSyncRequest:request];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    records = (NSArray *)_requestListener.jsonResponse;
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
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // make sure we got an id
    NSString *contactId = [[[(NSDictionary *)_requestListener.jsonResponse objectForKey:@"id"] retain] autorelease];
    STAssertNotNil(contactId, @"id not present");
    NSLog(@"## contact created with id: %@", contactId);
    
    @try {
        // now query object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
        [self sendSyncRequest:request];
        STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSArray *records = [(NSDictionary *)_requestListener.jsonResponse objectForKey:@"records"];
        STAssertEquals((int)[records count], 1, @"expected just one query result");
        
        // modify object
        NSDictionary *updatedFields = [NSDictionary dictionaryWithObjectsAndKeys:
                                       updatedLastName, @"LastName", 
                                       nil];
        request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:@"Contact" objectId:contactId fields:updatedFields];
        [self sendSyncRequest:request];
        STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");        
        
        // query updated object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", updatedLastName]]; 
        [self sendSyncRequest:request];
        STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        records = [(NSDictionary *)_requestListener.jsonResponse objectForKey:@"records"];
        STAssertEquals((int)[records count], 1, @"expected just one query result");

        // let's make sure the old object is not there anymore
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
        [self sendSyncRequest:request];
        STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        records = [(NSDictionary *)_requestListener.jsonResponse objectForKey:@"records"];
        STAssertEquals((int)[records count], 0, @"expected no result");
    }
    @finally {
        // now delete object
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"Contact" objectId:contactId];
        [self sendSyncRequest:request];
        STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    }
    
    // well, let's do another query just to be sure
    request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", updatedLastName]];
    [self sendSyncRequest:request];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSArray *records = [(NSDictionary *)_requestListener.jsonResponse objectForKey:@"records"];
    STAssertEquals((int)[records count], 0, @"expected no result");
}


//exercise upsert on an externalIdField that does not exist
- (void)testUpsert {
        
    //create an account name based on timestamp
    NSTimeInterval secs = [NSDate timeIntervalSinceReferenceDate];
    NSString *acctName = [NSString stringWithFormat:@"GenAccount %.2f",secs];
    NSDictionary *fields = [NSDictionary dictionaryWithObjectsAndKeys:
                            acctName,@"Name",
                            nil];
    
    //create a unique account number
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef uuidStr = CFUUIDCreateString(kCFAllocatorDefault, uuid);

    
    SFRestRequest *request = [[SFRestAPI sharedInstance]
                              requestForUpsertWithObjectType:@"Account"
                              externalIdField:@"bogusField__c" //this field shouldn't be defined in the test org
                              externalId: (NSString*)uuidStr
                              fields:fields
                              ];
    
    [self sendSyncRequest:request];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidFail, @"request should have failed");
    NSDictionary *errDict = _requestListener.lastError.userInfo;
    NSString *restErrCode = [errDict objectForKey:@"errorCode"];
    STAssertTrue([restErrCode isEqualToString:@"NOT_FOUND"],@"got unexpected restErrCode: %@",restErrCode);

}

// issue invalid SOQL and test for errors
- (void)testSOQLError {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:nil];
    [self sendSyncRequest:request];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidFail , @"request was supposed to fail");
    STAssertEqualObjects(_requestListener.lastError.domain, kSFRestErrorDomain, @"invalid domain");
    STAssertEquals(_requestListener.lastError.code, kSFRestErrorCode, @"invalid code");
}

// issue invalid retrieve and test for errors
- (void)testRetrieveError {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:@"bogus_contact_id" fieldList:nil];
    [self sendSyncRequest:request];
    STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
    STAssertEqualObjects(_requestListener.lastError.domain, kSFRestErrorDomain, @"invalid domain");
    STAssertEquals(_requestListener.lastError.code, kSFRestErrorCode, @"invalid code");
}

// - sets an invalid accessToken
// - issue a valid REST request
// - make sure the SDK will:
//   - do a oauth token exchange to get a new valid accessToken
//   - reissue the REST request
// - make sure the query gets replayed properly (and succeed)
- (void)testInvalidAccessTokenWithValidRequest {
    // save valid token
    NSString *validAccessToken = [[SFRestAPI sharedInstance].coordinator.credentials.accessToken copy];
    @try {
        // save invalid token
        NSString *invalidAccessToken = @"xyz";
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = invalidAccessToken;
        
        // request (valid)
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources];
        [self sendSyncRequest:request];
        STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSLog(@"latest access token: %@", [SFRestAPI sharedInstance].coordinator.credentials.accessToken);
        
        // let's make sure we have another access token
        NSString *newAccessToken = [SFRestAPI sharedInstance].coordinator.credentials.accessToken;
        STAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"access token wasn't refreshed");
    }
    @finally {
        // restore token
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = validAccessToken;    
        [validAccessToken release];
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
        STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");

        // let's make sure we have another access token
        NSString *newAccessToken = [SFRestAPI sharedInstance].coordinator.credentials.accessToken;
        STAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"access token wasn't refreshed");
    }
    @finally {
        // restore token
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = validAccessToken;      
    }
}

// - sets an invalid accessToken
// - sets an invalid refreshToken
// - issue a valid REST request
// - ensure all requests are failed with the proper error
- (void)testInvalidAccessAndRefreshToken {
    // save valid tokens
    NSString *validAccessToken = [SFRestAPI sharedInstance].coordinator.credentials.accessToken;
    NSString *validRefreshToken = [SFRestAPI sharedInstance].coordinator.credentials.refreshToken;
    @try {
        // set invalid tokens
        NSString *invalidAccessToken = @"xyz";
        NSString *invalidRefreshToken = @"xyz";
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = invalidAccessToken;
        [SFRestAPI sharedInstance].coordinator.credentials.refreshToken = invalidRefreshToken;
        
        // request (valid)
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources];
        [self sendSyncRequest:request];
        STAssertEqualObjects(_requestListener.returnStatus, kTestRequestStatusDidFail, @"request should have failed");
        STAssertEqualObjects(_requestListener.lastError.domain, kSFOAuthErrorDomain, @"invalid domain");
        STAssertEquals(_requestListener.lastError.code, kSFRestErrorCode, @"invalid code");
        STAssertNotNil(_requestListener.lastError.userInfo, nil);
    }
    @finally {
        // restore tokens
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = validAccessToken;
        [SFRestAPI sharedInstance].coordinator.credentials.refreshToken = validRefreshToken;     
    }
}




// - set an invalid access token (simulate expired)
// - make multiple simultaneous requests
// - requests will fail in some arbitrary order
// - ensure that a new access token is retrieved using refresh token
// - ensure that all requests eventually succeed
//
-(void)testInvalidAccessToken_MultipleRequests {
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
       
        //send multiple requests, all of which should fail with "unauthorized" initially,
        //but then be replayed after an access token refresh
        [[SFRestAPI sharedInstance] send:request0 delegate:nil];
        [[SFRestAPI sharedInstance] send:request1 delegate:nil];
        [[SFRestAPI sharedInstance] send:request2 delegate:nil];
        [[SFRestAPI sharedInstance] send:request3 delegate:nil];
        [[SFRestAPI sharedInstance] send:request4 delegate:nil];
        
        //wait for requests to complete in some arbitrary order
        [listener4 waitForCompletion];
        [listener1 waitForCompletion];
        [listener3 waitForCompletion];
        [listener2 waitForCompletion];
        [listener0 waitForCompletion];
        
        STAssertEqualObjects(listener0.returnStatus, kTestRequestStatusDidLoad, @"request0 failed");
        STAssertEqualObjects(listener1.returnStatus, kTestRequestStatusDidLoad, @"request1 failed");
        STAssertEqualObjects(listener2.returnStatus, kTestRequestStatusDidLoad, @"request2 failed");
        STAssertEqualObjects(listener3.returnStatus, kTestRequestStatusDidLoad, @"request3 failed");
        STAssertEqualObjects(listener4.returnStatus, kTestRequestStatusDidLoad, @"request4 failed");
        
        // let's make sure we have a new access token
        NSString *newAccessToken = [SFRestAPI sharedInstance].coordinator.credentials.accessToken;
        STAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"access token wasn't refreshed");
    }
    @finally {
        // restore token
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = validAccessToken;
    }
}

// - sets an invalid accessToken
// - sets an invalid refreshToken
// - issue multiple valid requests
// - make sure the token exchange failed
// - ensure all requests are failed with the proper error code
- (void)testInvalidAccessAndRefreshToken_MultipleRequests {
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
        
        //wait for requests to complete in some arbitrary order
        [listener4 waitForCompletion];
        [listener1 waitForCompletion];
        [listener3 waitForCompletion];
        [listener2 waitForCompletion];
        [listener0 waitForCompletion];
        
        STAssertEqualObjects(listener0.returnStatus, kTestRequestStatusDidFail, @"request0 should have failed");
        STAssertEqualObjects(listener0.lastError.domain, kSFOAuthErrorDomain, @"invalid error domain");
        STAssertEquals(listener0.lastError.code, kSFRestErrorCode, @"invalid error code");
        STAssertNotNil(listener0.lastError.userInfo,@"userInfo should not be nil");
        
        STAssertEqualObjects(listener1.returnStatus, kTestRequestStatusDidFail, @"request1 should have failed");
        STAssertEqualObjects(listener1.lastError.domain, kSFOAuthErrorDomain, @"invalid  error domain");
        STAssertEquals(listener1.lastError.code, kSFRestErrorCode, @"invalid error code");
        STAssertNotNil(listener1.lastError.userInfo,@"userInfo should not be nil");

        STAssertEqualObjects(listener2.returnStatus, kTestRequestStatusDidFail, @"request2 should have failed");
        STAssertEqualObjects(listener2.lastError.domain, kSFOAuthErrorDomain, @"invalid  error domain");
        STAssertEquals(listener2.lastError.code, kSFRestErrorCode, @"invalid error code");
        STAssertNotNil(listener2.lastError.userInfo,@"userInfo should not be nil");

        STAssertEqualObjects(listener3.returnStatus, kTestRequestStatusDidFail, @"request3 should have failed");
        STAssertEqualObjects(listener3.lastError.domain, kSFOAuthErrorDomain, @"invalid  error domain");
        STAssertEquals(listener3.lastError.code, kSFRestErrorCode, @"invalid error code");
        STAssertNotNil(listener3.lastError.userInfo,@"userInfo should not be nil");

        STAssertEqualObjects(listener4.returnStatus, kTestRequestStatusDidFail, @"request4 should have failed");
        STAssertEqualObjects(listener4.lastError.domain, kSFOAuthErrorDomain, @"invalid  error domain");
        STAssertEquals(listener4.lastError.code, kSFRestErrorCode, @"invalid error code");
        STAssertNotNil(listener4.lastError.userInfo,@"userInfo should not be nil");
    }
    @finally {
        // restore tokens
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = validAccessToken;
        [SFRestAPI sharedInstance].coordinator.credentials.refreshToken = validRefreshToken;     
    }
}

@end