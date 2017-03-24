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

#import "SalesforceRestAPITests.h"

#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFRestAPI+Internal.h"
#import "SFNativeRestRequestListener.h"

@interface SalesforceRestAPITests ()
{
    SFUserAccount *_currentUser;
}
@property (nonatomic, strong) XCTestExpectation *currentExpectation;

@end

static NSException *authException = nil;

@implementation SalesforceRestAPITests

+ (void)setUp
{
    @try {
        [SFLogger sharedLogger].logLevel = SFLogLevelDebug;
        [TestSetupUtils populateAuthCredentialsFromConfigFileForClass:[self class]];
        [TestSetupUtils synchronousAuthRefresh];
    }
    @catch (NSException *exception) {
        [self log:SFLogLevelDebug format:@"Populating auth from config failed: %@", exception];
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
    _currentUser = [SFUserAccountManager sharedInstance].currentUser;
    [super setUp];
}

- (void)tearDown
{
    // Tear-down code here.
    [[SFRestAPI sharedInstance] cleanup];
    [NSThread sleepForTimeInterval:0.1];  // Some test runs were failing, saying the run didn't complete.  This seems to fix that.
    [super tearDown];
}

#pragma mark - help methods


- (SFNativeRestRequestListener *)sendSyncRequest:(SFRestRequest *)request {
    SFNativeRestRequestListener *listener = [[SFNativeRestRequestListener alloc] initWithRequest:request];
    [[SFRestAPI sharedInstance] send:request delegate:nil];
    [listener waitForCompletion];
    
    return listener;
}

- (void)changeOauthTokens:(NSString *)accessToken refreshToken:(NSString *)refreshToken {
    _currentUser.credentials.accessToken = accessToken;
    if (nil != refreshToken) _currentUser.credentials.refreshToken = refreshToken;
}

#pragma mark - tests
// simple: just invoke requestForVersions
- (void)testGetVersions {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForVersions];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

- (void)testGetVersion_SetDelegate {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForVersions];
    SFNativeRestRequestListener *listener = [[SFNativeRestRequestListener alloc] initWithRequest:request];
    
    //exercises overwriting the delegate at send time
    [[SFRestAPI sharedInstance] send:request delegate:listener];
    [listener waitForCompletion];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: make sure fully-defined paths in the request are honored too.
- (void)testFullRequestPath {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources];
    request.path = [NSString stringWithFormat:@"%@%@", kSFDefaultRestEndpoint, request.path];
    [self log:SFLogLevelDebug format:@"request.path: %@", request.path];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: make sure that user-defined endpoints are respected
- (void)testUserDefinedEndpoint {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources];
    [request setEndpoint:@"/my/custom/endpoint"];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request should have failed");
}

// simple: just invoke requestForResources
- (void)testGetResources {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForDescribeGlobal
- (void)testGetDescribeGlobal {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForDescribeGlobal, force a cancel & timeout
- (void)testGetDescribeGlobal_Cancel {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    SFNativeRestRequestListener *listener = [[SFNativeRestRequestListener alloc] initWithRequest:request];
    [[SFRestAPI sharedInstance] send:request delegate:nil];

    [[SFRestAPI sharedInstance] cancelAllRequests];
    [listener waitForCompletion];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidCancel, @"request should have been cancelled");

}


// simple: just invoke requestForDescribeGlobal, force a timeout
- (void)testGetDescribeGlobal_Timeout {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    SFNativeRestRequestListener *listener = [[SFNativeRestRequestListener alloc] initWithRequest:request];
    [[SFRestAPI sharedInstance] send:request delegate:nil];
    
    BOOL found = [[SFRestAPI sharedInstance] forceTimeoutRequest:request];
    XCTAssertTrue(found , @"Could not find request to force a timeout");
    
    [listener waitForCompletion];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidTimeout, @"request should have timed out");
 }

// simple: just invoke requestForMetadataWithObjectType:@"Contact"
- (void)testGetMetadataWithObjectType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForMetadataWithObjectType:@"Contact"];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForDescribeWithObjectType:@"Contact"
- (void)testGetDescribeWithObjectType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeWithObjectType:@"Contact"];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForSearchScopeAndOrder
- (void)testGetSearchScopeAndOrder {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForSearchScopeAndOrder];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForSearchResultLayout:@"Account"
- (void)testGetSearchResultLayout {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForSearchResultLayout:@"Account"];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}



// attempt to create a Contact with none of the required fields (should fail)
- (void)testCreateBogusContact {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:@"Contact" fields:nil];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request should have failed");
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
    NSTimeInterval timecode = [NSDate timeIntervalSinceReferenceDate];
    //use a SOSL-safe format here to avoid problems with escaping characters for SOSL
    NSString *lastName = [NSString stringWithFormat:@"Doe%f", timecode];
    //We updated lastName so that it's already SOSL-safe: if you change lastName, you may need to escape SOSL-unsafe characters!
    
    NSDictionary *fields = @{@"FirstName": @"John", 
                             @"LastName": lastName};

    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:@"Contact" fields:fields];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // make sure we got an id
    NSString *contactId = ((NSDictionary *)listener.dataResponse)[@"id"];
    XCTAssertNotNil(contactId, @"id not present");
    
    @try {
        // try to retrieve object with id
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:contactId fieldList:nil];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        XCTAssertEqualObjects(lastName, ((NSDictionary *)listener.dataResponse)[@"LastName"], @"invalid last name");
        XCTAssertEqualObjects(@"John", ((NSDictionary *)listener.dataResponse)[@"FirstName"], @"invalid first name");
        
        // try to retrieve again, passing a list of fields
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:contactId fieldList:@"LastName, FirstName"];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        XCTAssertEqualObjects(lastName, ((NSDictionary *)listener.dataResponse)[@"LastName"], @"invalid last name");
        XCTAssertEqualObjects(@"John", ((NSDictionary *)listener.dataResponse)[@"FirstName"], @"invalid first name");
        
        // Raw data will not be converted to JSON if that's what's returned, regardless of parseResponse.
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:contactId fieldList:nil];
        request.parseResponse = NO;
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        XCTAssertTrue([listener.dataResponse isKindOfClass:[NSData class]], @"Should be NSData when parseResponse is no.");
        
        // Raw data will be converted to JSON if that's what's returned, when parseResponse is YES by default
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:contactId fieldList:nil];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        XCTAssertTrue([listener.dataResponse isKindOfClass:[NSDictionary class]], @"Should be parsed JSON for JSON response.");
        NSDictionary *responseAsJson = listener.dataResponse;
        XCTAssertEqualObjects(lastName, responseAsJson[@"LastName"], @"invalid last name");
        XCTAssertEqualObjects(@"John", responseAsJson[@"FirstName"], @"invalid first name");
        
        // now query object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSArray *records = ((NSDictionary *)listener.dataResponse)[@"records"];
        XCTAssertEqual((int)[records count], 1, @"expected just one query result");
        
        // now search object
        // Record is not available for search right away - so waiting a bit to prevent the test from flapping
        [NSThread sleepForTimeInterval:5.0f];
        request = [[SFRestAPI sharedInstance] requestForSearch:[NSString stringWithFormat:@"Find {%@}", lastName]];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        records = (NSArray *)listener.dataResponse;
        XCTAssertEqual((int)[records count], 1, @"expected just one search result");
    }
    @finally {
        // now delete object
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"Contact" objectId:contactId];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    }
    
    // well, let's do another query just to be sure
    request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSArray *records = ((NSDictionary *)listener.dataResponse)[@"records"];
    XCTAssertEqual((int)[records count], 0, @"expected no result");
    
    // check the deleted object is here
    request = [[SFRestAPI sharedInstance] requestForQueryAll:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSArray* records2 = ((NSDictionary *)listener.dataResponse)[@"records"];
    XCTAssertEqual((int)[records2 count], 1, @"expected just one query result");

    // now search object
    request = [[SFRestAPI sharedInstance] requestForSearch:[NSString stringWithFormat:@"Find {%@}", lastName]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    records = (NSArray *)listener.dataResponse;
    XCTAssertEqual((int)[records count], 0, @"expected no result");
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
    
    NSDictionary *fields = @{@"FirstName": @"John", 
                            @"LastName": lastName};
    
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:@"Contact" fields:fields];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // make sure we got an id
    NSString *contactId = ((NSDictionary *)listener.dataResponse)[@"id"];
    XCTAssertNotNil(contactId, @"id not present");
    [self log:SFLogLevelDebug format:@"## contact created with id: %@", contactId];
    
    @try {
        // now query object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSArray *records = ((NSDictionary *)listener.dataResponse)[@"records"];
        XCTAssertEqual((int)[records count], 1, @"expected just one query result");
        
        // modify object
        NSDictionary *updatedFields = @{@"LastName": updatedLastName};
        request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:@"Contact" objectId:contactId fields:updatedFields];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        
        // query updated object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", updatedLastName]]; 
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        records = ((NSDictionary *)listener.dataResponse)[@"records"];
        XCTAssertEqual((int)[records count], 1, @"expected just one query result");

        // let's make sure the old object is not there anymore
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        records = ((NSDictionary *)listener.dataResponse)[@"records"];
        XCTAssertEqual((int)[records count], 0, @"expected no result");
    }
    @finally {
        // now delete object
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"Contact" objectId:contactId];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    }
    
    // well, let's do another query just to be sure
    request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", updatedLastName]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSArray *records = ((NSDictionary *)listener.dataResponse)[@"records"];
    XCTAssertEqual((int)[records count], 0, @"expected no result");
}


//exercise upsert on an externalIdField that does not exist
- (void)testUpsert {
        
    //create an account name based on timestamp
    NSTimeInterval secs = [NSDate timeIntervalSinceReferenceDate];
    NSString *acctName = [NSString stringWithFormat:@"GenAccount %.2f",secs];
    NSDictionary *fields = @{@"Name": acctName};
    
    //create a unique account number
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef uuidStr = CFUUIDCreateString(kCFAllocatorDefault, uuid);

    
    SFRestRequest *request = [[SFRestAPI sharedInstance]
                              requestForUpsertWithObjectType:@"Account"
                              externalIdField:@"bogusField__c" //this field shouldn't be defined in the test org
                              externalId: (__bridge NSString*)uuidStr
                              fields:fields
                              ];
    
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request should have failed");
    NSDictionary *errDict = listener.lastError.userInfo;
    NSString *restErrCode = errDict[NSLocalizedFailureReasonErrorKey];
    XCTAssertTrue([restErrCode isEqualToString:@"NOT_FOUND"],@"got unexpected restErrCode: %@",restErrCode);

}

// issue invalid SOQL and test for errors
- (void)testSOQLError {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:(NSString* _Nonnull)nil];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail , @"request was supposed to fail");
    XCTAssertEqualObjects(listener.lastError.domain, CSFNetworkErrorDomain, @"invalid domain");
    XCTAssertEqual(listener.lastError.code, 400, @"invalid code");
}

// issue invalid retrieve and test for errors
- (void)testRetrieveError {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:@"bogus_contact_id" fieldList:nil];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
    XCTAssertEqualObjects(listener.lastError.domain, CSFNetworkErrorDomain, @"invalid domain");
    XCTAssertEqual(listener.lastError.code, 404, @"invalid code");
    
    // even when parseJson is NO, errors should still be returned as well-formed JSON
    request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:@"bogus_contact_id" fieldList:nil];
    request.parseResponse = NO;
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
    XCTAssertEqualObjects(listener.lastError.domain, CSFNetworkErrorDomain, @"invalid domain");
    XCTAssertEqual(listener.lastError.code, 404, @"invalid code");
}

#pragma mark - testing files calls

// simple: just invoke requestForOwnedFilesList
- (void)testOwnedFilesList {
    // with nil for userId
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForOwnedFilesList:nil page:0];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    // with actual user id
    request = [[SFRestAPI sharedInstance] requestForOwnedFilesList:_currentUser.credentials.userId page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForFilesInUsersGroups
- (void)testFilesInUsersGroups {
    // with nil for userId
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForFilesInUsersGroups:nil page:0];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    // with actual user id
    request = [[SFRestAPI sharedInstance] requestForFilesInUsersGroups:_currentUser.credentials.userId page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForFilesSharedWithUser
- (void)testFilesSharedWithUser {
    // with nil for userId
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForFilesSharedWithUser:nil page:0];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    // with actual user id
    request = [[SFRestAPI sharedInstance] requestForFilesSharedWithUser:_currentUser.credentials.userId page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// Upload file / download content / download rendition (expect 403) / delete file / download again (expect 404)
- (void) testUploadDownloadDeleteFile {
    // upload file
    NSDictionary *fileAttrs = [self uploadFile];

    // download content
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForFileContents:fileAttrs[@"id"] version:nil];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqualObjects(listener.dataResponse, fileAttrs[@"data"], @"wrong content");

    // download rendition (expect 200/success)
    request = [[SFRestAPI sharedInstance] requestForFileRendition:fileAttrs[@"id"] version:nil renditionType:@"PDF" page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // delete
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[@"id"]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // download content again (expect 404)
    request = [[SFRestAPI sharedInstance] requestForFileContents:fileAttrs[@"id"] version:nil];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
    XCTAssertEqual(listener.lastError.code, 404, @"invalid code");
}

// Upload file / get details / delete file / get details again (expect 404)
- (void) testUploadDetailsDeleteFile {
    // upload file
    NSDictionary *fileAttrs = [self uploadFile];

    // get details
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForFileDetails:fileAttrs[@"id"] forVersion:nil];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    [self compareFileAttributes:listener.dataResponse expectedAttrs:fileAttrs];
   
    // delete
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[@"id"]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // get details again (expect 404)
    request = [[SFRestAPI sharedInstance] requestForFileDetails:fileAttrs[@"id"] forVersion:nil];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
    XCTAssertEqual(listener.lastError.code, 404, @"invalid code");
}

// Upload files / get batch details / delete files / get batch details again (expect 404)
- (void) testUploadBatchDetailsDeleteFiles {
    // upload first file
    NSDictionary *fileAttrs = [self uploadFile];
    
    // upload second file
    NSDictionary *fileAttrs2 = [self uploadFile];
    
    // get batch details
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForBatchFileDetails:@[fileAttrs[@"id"], fileAttrs2[@"id"]]];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual([listener.dataResponse[@"results"][0][@"statusCode"] intValue], 200, @"expected 200");
    [self compareFileAttributes:listener.dataResponse[@"results"][0][@"result"] expectedAttrs:fileAttrs];
    XCTAssertEqual([listener.dataResponse[@"results"][1][@"statusCode"] intValue], 200, @"expected 200");
    [self compareFileAttributes:listener.dataResponse[@"results"][1][@"result"] expectedAttrs:fileAttrs2];
    
    // delete first file
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[@"id"]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // get batch details (expect 404 for first file)
    request = [[SFRestAPI sharedInstance] requestForBatchFileDetails:@[fileAttrs[@"id"], fileAttrs2[@"id"]]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual([listener.dataResponse[@"results"][0][@"statusCode"] intValue], 404, @"expected 404");
    XCTAssertEqual([listener.dataResponse[@"results"][1][@"statusCode"] intValue], 200, @"expected 200");
    [self compareFileAttributes:listener.dataResponse[@"results"][1][@"result"] expectedAttrs:fileAttrs2];
    
    // delete second file
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs2[@"id"]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // get batch details (expect 404 for both files)
    request = [[SFRestAPI sharedInstance] requestForBatchFileDetails:@[fileAttrs[@"id"], fileAttrs2[@"id"]]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual([listener.dataResponse[@"results"][0][@"statusCode"] intValue], 404, @"expected 404");
    XCTAssertEqual([listener.dataResponse[@"results"][1][@"statusCode"] intValue], 404, @"expected 404");
}

// Upload files / get owned files / delete files / get owned files again
- (void) testUploadOwnedFilesDelete {
    // upload first file
    NSDictionary *fileAttrs = [self uploadFile];
    
    // get owned files
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForOwnedFilesList:nil page:0];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    [self compareFileAttributes:listener.dataResponse[@"files"][0] expectedAttrs:fileAttrs];
    
    // upload other file
    NSDictionary *fileAttrs2 = [self uploadFile];

    // get owned files
    request = [[SFRestAPI sharedInstance] requestForOwnedFilesList:nil page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    [self compareMultipleFileAttributes:@[ listener.dataResponse[@"files"][0], listener.dataResponse[@"files"][1] ]
                               expected:@[ fileAttrs, fileAttrs2 ]];

    // delete second file
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs2[@"id"]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // get owned files
    request = [[SFRestAPI sharedInstance] requestForOwnedFilesList:nil page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    [self compareFileAttributes:listener.dataResponse[@"files"][0] expectedAttrs:fileAttrs];
    
    // delete first file
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[@"id"]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// Upload file / share file / get file shares and shared files / unshare file / get file shares and shared files / delete file
- (void) testUploadShareFileSharesSharedFilesUnshareDelete {
    // upload file
    NSDictionary *fileAttrs = [self uploadFile];
    
    // get id of other user
    NSString *otherUserId = [self getOtherUser];
    
    // get file shares
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForFileShares:fileAttrs[@"id"] page:0];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual((int)[listener.dataResponse[@"shares"] count], 1, @"expected one share");
    XCTAssertEqualObjects([listener.dataResponse[@"shares"][0][@"entity"][@"id"] substringToIndex:15], _currentUser.credentials.userId, @"expected share with current user");
    XCTAssertEqualObjects(listener.dataResponse[@"shares"][0][@"sharingType"], @"I", @"wrong sharing type");

    // get count files shared with other user
    request = [[SFRestAPI sharedInstance] requestForFilesSharedWithUser:otherUserId page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    int countFilesSharedWithOtherUser = (int)[listener.dataResponse[@"files"] count];
    
    // share file with other user
    request = [[SFRestAPI sharedInstance] requestForAddFileShare:fileAttrs[@"id"] entityId:otherUserId shareType:@"V"];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSString *shareId = listener.dataResponse[@"id"];
    
    // get file shares again
    request = [[SFRestAPI sharedInstance] requestForFileShares:fileAttrs[@"id"] page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSMutableDictionary* actualUserIdToType = [NSMutableDictionary new];
    for (int i=0; i < [listener.dataResponse[@"shares"] count]; i++) {
        NSDictionary* share = listener.dataResponse[@"shares"][i];
        NSString* shareEntityId = [(NSString*) share[@"entity"][@"id"] substringToIndex:15];
        NSString* shareType = share[@"sharingType"];
        actualUserIdToType[shareEntityId] = shareType;
    }
    NSString* otherUserId15 = [otherUserId substringToIndex:15];
    XCTAssertEqual([actualUserIdToType count], 2, @"expected two shares");
    XCTAssertTrue([[actualUserIdToType allKeys] containsObject:_currentUser.credentials.userId], @"expected share with current user");
    XCTAssertEqualObjects(actualUserIdToType[_currentUser.credentials.userId], @"I", @"wrong sharing type for current user");
    XCTAssertTrue([[actualUserIdToType allKeys] containsObject:otherUserId15], @"expected shared with other user");
    XCTAssertEqualObjects(actualUserIdToType[otherUserId15], @"V", @"wrong sharing type for other user");
    
    // get count files shared with other user
    request = [[SFRestAPI sharedInstance] requestForFilesSharedWithUser:otherUserId page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual((int)[listener.dataResponse[@"files"] count], countFilesSharedWithOtherUser + 1, @"expected one more file shared with other user");
    
    // unshare file from other user
    request = [[SFRestAPI sharedInstance] requestForDeleteFileShare:shareId];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // get files shares again
    request = [[SFRestAPI sharedInstance] requestForFileShares:fileAttrs[@"id"] page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual((int)[listener.dataResponse[@"shares"] count], 1, @"expected one share");
    XCTAssertEqualObjects([listener.dataResponse[@"shares"][0][@"entity"][@"id"] substringToIndex:15], _currentUser.credentials.userId, @"expected share with current user");
    XCTAssertEqualObjects(listener.dataResponse[@"shares"][0][@"sharingType"], @"I", @"wrong sharing type");
    
    // get count files shared with other user
    request = [[SFRestAPI sharedInstance] requestForFilesSharedWithUser:otherUserId page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual((int)[listener.dataResponse[@"files"] count], countFilesSharedWithOtherUser, @"expected one less file shared with other user");
    
    // delete file
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[@"id"]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

- (void)testGzip {
    NSString *soql = [NSString stringWithFormat:@"SELECT Id FROM User WHERE Id != '%@'", _currentUser.credentials.userId];
    // query
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:soql];
    [request setHeaderValue:@"gzip" forHeaderName:@"Accept-Encoding"];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    [listener waitForCompletion];
    XCTAssertTrue([request.action.httpResponse.allHeaderFields[@"Content-Encoding"] isEqualToString:@"gzip"]);
}


#pragma mark - files tests helpers
// Return id of another user in org
- (NSString *) getOtherUser {
    NSString *soql = [NSString stringWithFormat:@"SELECT Id FROM User WHERE Id != '%@'", _currentUser.credentials.userId];
    
    // query
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:soql];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];

    // check response
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    return listener.dataResponse[@"records"][0][@"Id"];
}

// Upload file / check response / return new file attributes (id, title, description, data, mimeType, contentSize)
- (NSDictionary *) uploadFile {
    NSTimeInterval timecode = [NSDate timeIntervalSinceReferenceDate];
    NSString *fileTitle = [NSString stringWithFormat:@"FileName%f.txt", timecode];
    NSString *fileDescription = [NSString stringWithFormat:@"FileDescription%f", timecode];
    NSString *fileDataStr = [NSString stringWithFormat:@"FileData%f", timecode];
    NSData *fileData = [fileDataStr dataUsingEncoding:NSUTF8StringEncoding];
    NSString *fileMimeType = @"text/plain";
    NSNumber *fileSize = [NSNumber numberWithLong:[fileData length]];
    
    // upload
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForUploadFile:fileData name:fileTitle description:fileDescription mimeType:fileMimeType];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    
    // check response
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqualObjects(listener.dataResponse[@"title"], fileTitle, @"wrong title");
    XCTAssertEqualObjects(listener.dataResponse[@"description"], fileDescription, @"wrong description");
    XCTAssertEqual([listener.dataResponse[@"contentSize"] intValue], [fileSize intValue], @"wrong content size");
    XCTAssertEqualObjects(listener.dataResponse[@"mimeType"], fileMimeType, @"wrong mime type");
    
    // get id
    NSString *fileId = listener.dataResponse[@"id"];
    
    // making dictionary with file attributes
    NSDictionary *fileAttrs = @{@"title": fileTitle,
                                @"description": fileDescription,
                                @"data": fileData,
                                @"mimeType": fileMimeType,
                                @"id": fileId,
                                @"contentSize": fileSize
                                };
    
    return fileAttrs;
}

// Compare file attributes
- (void) compareFileAttributes:(NSDictionary *)actualFileAttrs expectedAttrs:(NSDictionary *)expectedFileAttrs {
    NSArray *keys = @[@"id", @"title", @"description", @"contentSize", @"mimeType"];
    
    for (id key in keys) {
        XCTAssertEqualObjects(actualFileAttrs[key], expectedFileAttrs[key], @"wrong %@", key);
    }
}

- (void)compareMultipleFileAttributes:(NSArray *)actualFileAttrsArray expected:(NSArray *)expectedFileAttrsArray
{
    // Order can't be guaranteed for files.  Cheat a little by matching IDs first.
    for (NSDictionary *expectedFile in expectedFileAttrsArray) {
        NSString *expectedId = expectedFile[@"id"];
        XCTAssertNotNil(expectedId, @"No value for file's expected ID.");
        BOOL foundMatchingId = NO;
        for (NSDictionary *actualFile in actualFileAttrsArray) {
            NSString *actualId = actualFile[@"id"];
            XCTAssertNotNil(actualId, @"No value for file's actual ID.");
            if ([expectedId isEqualToString:actualId]) {
                foundMatchingId = YES;
                [self compareFileAttributes:actualFile expectedAttrs:expectedFile];
                break;
            }
        }
        XCTAssertTrue(foundMatchingId, @"No actual file found matching expected ID '%@'.", expectedId);
    }
}

#pragma mark - testing refresh


// - sets an invalid accessToken
// - issue a valid REST request
// - make sure the SDK will:
//   - do a oauth token exchange to get a new valid accessToken
//   - reissue the REST request
// - make sure the query gets replayed properly (and succeed)
- (void)testInvalidAccessTokenWithValidGetRequest {
    // save invalid token
    NSString *invalidAccessToken = @"xyz";
    [self changeOauthTokens:invalidAccessToken refreshToken:nil];
     
    // request (valid)
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    [self log:SFLogLevelDebug format:@"latest access token: %@", _currentUser.credentials.accessToken];
    
    // let's make sure we have another access token
    NSString *newAccessToken = _currentUser.credentials.accessToken;
    XCTAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"access token wasn't refreshed");
}

- (void)testInvalidAccessTokenWithValidPostRequest {
    // save invalid token
    NSString *invalidAccessToken = @"xyz";
    [self changeOauthTokens:invalidAccessToken refreshToken:nil];
    
    // request (valid)
    NSDictionary *fields = @{@"FirstName": @"John",
                             @"LastName": [NSString stringWithFormat:@"Johnson%u", arc4random()]};
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:@"Contact" fields:fields];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSString *contactId = ((NSDictionary *)listener.dataResponse)[@"id"];
    XCTAssertNotNil(contactId, @"Contact create result should contain an ID value.");
    [self log:SFLogLevelDebug format:@"latest access token: %@", _currentUser.credentials.accessToken];
    
    // let's make sure we have another access token
    NSString *newAccessToken = _currentUser.credentials.accessToken;
    XCTAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"access token wasn't refreshed");
    
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"Contact" objectId:contactId];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// - sets an invalid accessToken
// - issue an invalid REST request
// - make sure the SDK will:
//   - do a oauth token exchange to get a new valid accessToken
//   - reissue the REST request
// - make sure the query gets replayed properly (and fail)
- (void)testInvalidAccessTokenWithInvalidRequest {
    // save invalid token
    NSString *invalidAccessToken = @"xyz";
    [self changeOauthTokens:invalidAccessToken refreshToken:nil];
    
    // request (invalid)
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:(NSString* _Nonnull)nil];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
    
    // let's make sure we have another access token
    NSString *newAccessToken = _currentUser.credentials.accessToken;
    XCTAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"access token wasn't refreshed");
}

// - sets an invalid accessToken
// - sets an invalid refreshToken
// - issue a valid REST request
// - ensure all requests are failed with the proper error
- (void)FIXMEtestInvalidAccessAndRefreshToken {
    // save valid tokens
    NSString *origAccessToken = _currentUser.credentials.accessToken;
    NSString *origRefreshToken = _currentUser.credentials.refreshToken;
    
    // set invalid tokens
    NSString *invalidAccessToken = @"xyz";
    NSString *invalidRefreshToken = @"xyz";
    [self changeOauthTokens:invalidAccessToken refreshToken:invalidRefreshToken];
    
    @try {
        // request (valid)
        SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources];
        SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request should have failed");
        XCTAssertEqualObjects(listener.lastError.domain, kSFOAuthErrorDomain, @"invalid domain");
        XCTAssertEqual(listener.lastError.code, kSFOAuthErrorInvalidGrant, @"invalid code");
        XCTAssertNotNil(listener.lastError.userInfo);
    }
    @finally {
        [self changeOauthTokens:origAccessToken refreshToken:origRefreshToken];
    }
}

// - set an invalid access token (simulate expired)
// - make multiple simultaneous requests
// - requests will fail in some arbitrary order
// - ensure that a new access token is retrieved using refresh token
// - ensure that all requests eventually succeed
//
-(void)testInvalidAccessToken_MultipleRequests {
    // save invalid token
    NSString *invalidAccessToken = @"xyz";
    [self changeOauthTokens:invalidAccessToken refreshToken:nil];
    
    // request (valid)
    SFRestRequest* request0 = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    SFNativeRestRequestListener *listener0 = [[SFNativeRestRequestListener alloc] initWithRequest:request0];
    
    SFRestRequest* request1 = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    SFNativeRestRequestListener *listener1 = [[SFNativeRestRequestListener alloc] initWithRequest:request1];
    
    SFRestRequest* request2 = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    SFNativeRestRequestListener *listener2 = [[SFNativeRestRequestListener alloc] initWithRequest:request2];
    
    SFRestRequest* request3 = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    SFNativeRestRequestListener *listener3 = [[SFNativeRestRequestListener alloc] initWithRequest:request3];
    
    SFRestRequest* request4 = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    SFNativeRestRequestListener *listener4 = [[SFNativeRestRequestListener alloc] initWithRequest:request4];
    
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
    
    XCTAssertEqualObjects(listener0.returnStatus, kTestRequestStatusDidLoad, @"request0 failed");
    XCTAssertEqualObjects(listener1.returnStatus, kTestRequestStatusDidLoad, @"request1 failed");
    XCTAssertEqualObjects(listener2.returnStatus, kTestRequestStatusDidLoad, @"request2 failed");
    XCTAssertEqualObjects(listener3.returnStatus, kTestRequestStatusDidLoad, @"request3 failed");
    XCTAssertEqualObjects(listener4.returnStatus, kTestRequestStatusDidLoad, @"request4 failed");
    
    // let's make sure we have a new access token
    NSString *newAccessToken = _currentUser.credentials.accessToken;
    XCTAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"access token wasn't refreshed");
}

// - sets an invalid accessToken
// - sets an invalid refreshToken
// - issue multiple valid requests
// - make sure the token exchange failed
// - ensure all requests are failed with the proper error code
- (void)FIXMEtestInvalidAccessAndRefreshToken_MultipleRequests {
    // save valid tokens
    NSString *origAccessToken = _currentUser.credentials.accessToken;
    NSString *origRefreshToken = _currentUser.credentials.refreshToken;
    
    // set invalid tokens
    NSString *invalidAccessToken = @"xyz";
    NSString *invalidRefreshToken = @"xyz";
    [self changeOauthTokens:invalidAccessToken refreshToken:invalidRefreshToken];

    @try {
        // request (valid)
        SFRestRequest* request0 = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
        SFNativeRestRequestListener *listener0 = [[SFNativeRestRequestListener alloc] initWithRequest:request0];
        
        SFRestRequest* request1 = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
        SFNativeRestRequestListener *listener1 = [[SFNativeRestRequestListener alloc] initWithRequest:request1];
        
        SFRestRequest* request2 = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
        SFNativeRestRequestListener *listener2 = [[SFNativeRestRequestListener alloc] initWithRequest:request2];
        
        SFRestRequest* request3 = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
        SFNativeRestRequestListener *listener3 = [[SFNativeRestRequestListener alloc] initWithRequest:request3];
        
        SFRestRequest* request4 = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
        SFNativeRestRequestListener *listener4 = [[SFNativeRestRequestListener alloc] initWithRequest:request4];
        
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
        
        XCTAssertEqualObjects(listener0.returnStatus, kTestRequestStatusDidFail, @"request0 should have failed");
        XCTAssertEqualObjects(listener0.lastError.domain, kSFOAuthErrorDomain, @"invalid error domain");
        XCTAssertEqual(listener0.lastError.code, kSFOAuthErrorInvalidGrant, @"invalid error code");
        XCTAssertNotNil(listener0.lastError.userInfo,@"userInfo should not be nil");
        
        XCTAssertEqualObjects(listener1.returnStatus, kTestRequestStatusDidFail, @"request1 should have failed");
        XCTAssertEqualObjects(listener1.lastError.domain, kSFOAuthErrorDomain, @"invalid  error domain");
        XCTAssertEqual(listener1.lastError.code, kSFOAuthErrorInvalidGrant, @"invalid error code");
        XCTAssertNotNil(listener1.lastError.userInfo,@"userInfo should not be nil");
        
        XCTAssertEqualObjects(listener2.returnStatus, kTestRequestStatusDidFail, @"request2 should have failed");
        XCTAssertEqualObjects(listener2.lastError.domain, kSFOAuthErrorDomain, @"invalid  error domain");
        XCTAssertEqual(listener2.lastError.code, kSFOAuthErrorInvalidGrant, @"invalid error code");
        XCTAssertNotNil(listener2.lastError.userInfo,@"userInfo should not be nil");
        
        XCTAssertEqualObjects(listener3.returnStatus, kTestRequestStatusDidFail, @"request3 should have failed");
        XCTAssertEqualObjects(listener3.lastError.domain, kSFOAuthErrorDomain, @"invalid  error domain");
        XCTAssertEqual(listener3.lastError.code, kSFOAuthErrorInvalidGrant, @"invalid error code");
        XCTAssertNotNil(listener3.lastError.userInfo,@"userInfo should not be nil");
        
        XCTAssertEqualObjects(listener4.returnStatus, kTestRequestStatusDidFail, @"request4 should have failed");
        XCTAssertEqualObjects(listener4.lastError.domain, kSFOAuthErrorDomain, @"invalid  error domain");
        XCTAssertEqual(listener4.lastError.code, kSFOAuthErrorInvalidGrant, @"invalid error code");
        XCTAssertNotNil(listener4.lastError.userInfo,@"userInfo should not be nil");
    }
    @finally {
        [self changeOauthTokens:origAccessToken refreshToken:origRefreshToken];
    }
}


#pragma mark - testing block functions

- (BOOL) waitForExpectation {
    [self log:SFLogLevelDebug format:@"Waiting for %@ to complete", self.currentExpectation.description];

    __block BOOL timedout;
    [self waitForExpectationsWithTimeout:15 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"%@ took too long to complete", self.currentExpectation.description);
            timedout = YES;
        }
        else {
            [self log:SFLogLevelDebug format:@"Completed %@", self.currentExpectation.description];
            timedout = NO;
        }
    }];
    return timedout;
}


// These block functions are just a category on SFRestAPI, so we verify here
// only that the proper blocks were called for each

- (void)testBlockUpdate {
    SFRestFailBlock failWithUnexpectedFail = ^(NSError *e) {
        XCTFail(@"Unexpected error %@", e);
        [self.currentExpectation fulfill];
    };
    
    SFRestDictionaryResponseBlock nilResponseSuccessBlock = ^(NSDictionary *d) {
        XCTAssertNil(d);
        [self.currentExpectation fulfill];
    };
    
    
    SFRestAPI *api = [SFRestAPI sharedInstance];
    
    NSString *lastName = [NSString stringWithFormat:@"Doe-BLOCK-%@", [NSDate date]];
    NSString *updatedLastName = [lastName stringByAppendingString:@"xyz"];
    NSMutableDictionary *fields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   @"John", @"FirstName",
                                   lastName, @"LastName",
                                   nil];
    __block NSString *recordId;
    
    self.currentExpectation = [self expectationWithDescription:@"performCreateWithObjectType-creating contact"];
    [api performCreateWithObjectType:@"Contact"
                              fields:fields
                           failBlock:failWithUnexpectedFail
                       completeBlock:^(NSDictionary *d) {
                           recordId = (NSString*) d[@"id"];
                           [self.currentExpectation fulfill];
                       }];
    [self waitForExpectation];
    
    
    self.currentExpectation = [self expectationWithDescription:@"performRetrieveWithObjectType-retrieving contact"];
    [api performRetrieveWithObjectType:@"Contact"
                              objectId:recordId
                             fieldList:@[@"LastName"]
                             failBlock:failWithUnexpectedFail
                         completeBlock:^(NSDictionary *d) {
                             XCTAssertEqualObjects(lastName, d[@"LastName"]);
                             [self.currentExpectation fulfill];
                         }];
    [self waitForExpectation];
    
    self.currentExpectation = [self expectationWithDescription:@"performUpdateWithObjectType-updating contact"];
    fields[@"LastName"] = updatedLastName;
    [api performUpdateWithObjectType:@"Contact"
                            objectId:recordId
                              fields:fields
                           failBlock:failWithUnexpectedFail
                       completeBlock:nilResponseSuccessBlock
     ];
    [self waitForExpectation];
    
    self.currentExpectation = [self expectationWithDescription:@"performRetrieveWithObjectType-retrieving contact"];
    [api performRetrieveWithObjectType:@"Contact"
                              objectId:recordId
                             fieldList:@[@"LastName"]
                             failBlock:failWithUnexpectedFail
                         completeBlock:^(NSDictionary *d) {
                             XCTAssertEqualObjects(updatedLastName, d[@"LastName"]);
                             [self.currentExpectation fulfill];
                         }];
    [self waitForExpectation];
    
    self.currentExpectation = [self expectationWithDescription:@"performUpsertWithObjectType-upserting contact"];
    fields[@"LastName"] = lastName;
    [api performUpsertWithObjectType:@"Contact"
                     externalIdField:@"Id"
                          externalId:recordId
                              fields:fields
                           failBlock:failWithUnexpectedFail
                       completeBlock:nilResponseSuccessBlock
     ];
    [self waitForExpectation];
    
    self.currentExpectation = [self expectationWithDescription:@"performRetrieveWithObjectType-retrieving contact"];
    [api performRetrieveWithObjectType:@"Contact"
                              objectId:recordId
                             fieldList:@[@"LastName"]
                             failBlock:failWithUnexpectedFail
                         completeBlock:^(NSDictionary *d) {
                             XCTAssertEqualObjects(lastName, d[@"LastName"]);
                             [self.currentExpectation fulfill];
                         }];
    [self waitForExpectation];
    
    self.currentExpectation = [self expectationWithDescription:@"performDeleteWithObjectType-deleting contact"];
    [api performDeleteWithObjectType:@"Contact"
                            objectId:recordId
                           failBlock:failWithUnexpectedFail
                       completeBlock:nilResponseSuccessBlock
     ];
    [self waitForExpectation];
}

- (void) testBlocks {
    SFRestAPI *api = [SFRestAPI sharedInstance];
    
    // A fail block that we expected to fail
    SFRestFailBlock failWithExpectedFail = ^(NSError *e) {
        [self.currentExpectation fulfill];
    };

    // A fail block that should not have failed
    SFRestFailBlock failWithUnexpectedFail = ^(NSError *e) {
        XCTFail(@"Unexpected error %@", e);
        [self.currentExpectation fulfill];
    };
    
    
    // A success block that should not have succeeded
    SFRestDictionaryResponseBlock successWithUnexpectedSuccessBlock = ^(NSDictionary *d) {
        XCTFail(@"Unexpected success %@", d);
        [self.currentExpectation fulfill];
    };
    
    // An success block that we expected to succeed
    SFRestDictionaryResponseBlock dictSuccessBlock = ^(NSDictionary *d) {
        [self.currentExpectation fulfill];
    };
    
    // An array success block that we expected to succeed
    SFRestArrayResponseBlock arraySuccessBlock = ^(NSArray *arr) {
        [self.currentExpectation fulfill];
    };
    
    // Class helper function that creates an error.
    NSString *errorStr = @"Sample error.";
    XCTAssertTrue( [errorStr isEqualToString:[[SFRestAPI errorWithDescription:errorStr] localizedDescription]],
                  @"Generated error should match description." );
    
    // Block functions that should always fail
    self.currentExpectation = [self expectationWithDescription:@"performDeleteWithObjectType-nil"];
    [api performDeleteWithObjectType:(NSString* _Nonnull) nil objectId:(NSString* _Nonnull)nil
                           failBlock:failWithExpectedFail
                       completeBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];
    
    self.currentExpectation = [self expectationWithDescription:@"performCreateWithObjectType-nil"];
    [api performCreateWithObjectType:(NSString* _Nonnull)nil fields:(NSDictionary<NSString*, id>* _Nonnull)nil
                           failBlock:failWithExpectedFail
                       completeBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];
    
    self.currentExpectation = [self expectationWithDescription:@"performMetadataWithObjectType-nil"];
    [api performMetadataWithObjectType:(NSString* _Nonnull)nil
                             failBlock:failWithExpectedFail
                         completeBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];
    
    self.currentExpectation = [self expectationWithDescription:@"performDescribeWithObjectType-nil"];
    [api performDescribeWithObjectType:(NSString* _Nonnull)nil
                             failBlock:failWithExpectedFail
                         completeBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];
    
    self.currentExpectation = [self expectationWithDescription:@"performRetrieveWithObjectType-nil"];
    [api performRetrieveWithObjectType:(NSString* _Nonnull)nil objectId:(NSString* _Nonnull)nil fieldList:(NSArray<NSString*>* _Nonnull)nil
                             failBlock:failWithExpectedFail
                         completeBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];
    
    self.currentExpectation = [self expectationWithDescription:@"performUpdateWithObjectType-nil"];
    [api performUpdateWithObjectType:(NSString* _Nonnull)nil objectId:(NSString* _Nonnull)nil fields:(NSDictionary<NSString*, id>* _Nonnull)nil
                           failBlock:failWithExpectedFail
                       completeBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];
    
    self.currentExpectation = [self expectationWithDescription:@"performUpsertWithObjectType-nil"];
    [api performUpsertWithObjectType:(NSString* _Nonnull)nil externalIdField:(NSString* _Nonnull)nil externalId:(NSString* _Nonnull)nil
                              fields:(NSDictionary<NSString*, id>* _Nonnull)nil
                           failBlock:failWithExpectedFail
                       completeBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];
    
    self.currentExpectation = [self expectationWithDescription:@"performSOQLQuery-nil"];
    [api performSOQLQuery:(NSString* _Nonnull)nil
                failBlock:failWithExpectedFail
            completeBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];
    
    self.currentExpectation = [self expectationWithDescription:@"performSOQLQueryAll-nil"];
    [api performSOQLQueryAll:(NSString* _Nonnull)nil
                   failBlock:failWithExpectedFail
               completeBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];

    // NB: sosl with nil used to fail but now returns the dict { layout = "/services/data/v36.0/search/layout" ... }
    //     as a result performSOSLSearch can't be used since it expects an array in the response
    
    // Block functions that should always succeed
    self.currentExpectation = [self expectationWithDescription:@"performRequestForResourcesWithFailBlock"];
    [api performRequestForResourcesWithFailBlock:failWithUnexpectedFail
                                   completeBlock:dictSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performRequestForVersionsWithFailBlock"];
    [api performRequestForVersionsWithFailBlock:failWithUnexpectedFail
                                  completeBlock:dictSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performDescribeGlobalWithFailBlock"];
    [api performDescribeGlobalWithFailBlock:failWithUnexpectedFail
                              completeBlock:dictSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performSOQLQuery-select id from user limit 10"];
    [api performSOQLQuery:@"select id from user limit 10"
                failBlock:failWithUnexpectedFail
            completeBlock:dictSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performSOQLQueryAll-select id from user limit 10"];
    [api performSOQLQueryAll:@"select id from user limit 10"
                   failBlock:failWithUnexpectedFail
               completeBlock:dictSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performSOSLSearch-find {batman}"];
    [api performSOSLSearch:@"find {batman}"
                 failBlock:failWithUnexpectedFail
             completeBlock:arraySuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performDescribeWithObjectType-Contact"];
    [api performDescribeWithObjectType:@"Contact"
                             failBlock:failWithUnexpectedFail
                         completeBlock:dictSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performMetadataWithObjectType-Contact"];
    [api performMetadataWithObjectType:@"Contact"
                             failBlock:failWithUnexpectedFail
                         completeBlock:dictSuccessBlock];
    [self waitForExpectation];
}


- (void)testBlocksCancel {
    self.currentExpectation = [self expectationWithDescription:@"performRequestForResourcesWithFailBlock-with-cancel"];
    SFRestAPI *api = [SFRestAPI sharedInstance];
    
    // A fail block that we expected to fail
    SFRestFailBlock failWithExpectedFail = ^(NSError *e) {
        [self.currentExpectation fulfill];
    };
    
    // A success block that should not have succeeded
    SFRestDictionaryResponseBlock successWithUnexpectedSuccessBlock = ^(NSDictionary *d) {
        XCTFail(@"Unexpected success %@", d);
        [self.currentExpectation fulfill];
    };
    
    [api performRequestForResourcesWithFailBlock:failWithExpectedFail
                                   completeBlock:successWithUnexpectedSuccessBlock];
    
    [api cancelAllRequests];
    
    BOOL completionTimedOut = [self waitForExpectation];
    XCTAssertTrue(!completionTimedOut);
}

- (void)testBlocksTimeout {
    self.currentExpectation = [self expectationWithDescription:@"performRequestForResourcesWithFailBlock-with-forced-timeout"];
    SFRestAPI *api = [SFRestAPI sharedInstance];
    
    // A fail block that we expected to fail
    SFRestFailBlock failWithExpectedFail = ^(NSError *e) {
        [self.currentExpectation fulfill];
    };
    
    // A success block that should not have succeeded
    SFRestDictionaryResponseBlock successWithUnexpectedSuccessBlock = ^(NSDictionary *d) {
        XCTFail("Unexpected success %@", d);
        [self.currentExpectation fulfill];
    };
    
    [api performRequestForResourcesWithFailBlock:failWithExpectedFail
                                   completeBlock:successWithUnexpectedSuccessBlock];
    
    BOOL found = [api forceTimeoutRequest:nil];
    XCTAssertTrue(found , @"Could not find request to force a timeout");

    BOOL completionTimedOut = [self waitForExpectation];
    XCTAssertTrue(!completionTimedOut); // when we force timeout the request, its error handler gets invoked right away, so the semaphore-wait should not time out
}

#pragma mark - SFRestAPI utility tests

- (void)testSFRestAPICoordinatorProperty
{
    // [SFRestAPI sharedInstance].coordinator tracks [SFAuthenticationManager sharedManager].coordinator by default.
    SFOAuthCoordinator *acctMgrCoord = [SFAuthenticationManager sharedManager].coordinator;
    SFOAuthCoordinator *restApiCoord = [SFRestAPI sharedInstance].coordinator;
    XCTAssertEqualObjects(acctMgrCoord, restApiCoord, @"Coordinator property on SFRestAPI should track the value in SFAccountManager.");
    
    // Updating [SFRestAPI sharedInstance].coordinator updates [SFAuthenticationManager sharedManager].coordinator as well.
    SFOAuthCredentials *creds = _currentUser.credentials;
    SFOAuthCoordinator *newRestApiCoord = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    XCTAssertFalse(newRestApiCoord == [SFAuthenticationManager sharedManager].coordinator, @"Object references shouldn't be equal with new object.");
    [SFRestAPI sharedInstance].coordinator = newRestApiCoord;
    acctMgrCoord = [SFAuthenticationManager sharedManager].coordinator;
    restApiCoord = [SFRestAPI sharedInstance].coordinator;
    XCTAssertEqualObjects(acctMgrCoord, restApiCoord, @"Updating SFRestAPI's coordinator property should update SFAccountManager as well.");
    
    // After updating [SFRestAPI sharedInstance].coordinator, REST calls still work.
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForVersions];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus,
                         kTestRequestStatusDidLoad,
                         @"Request failed with updated value for [SFRestAPI sharedInstance].coordinator");
}

#pragma mark - queryBuilder tests

- (void) testSOQL {

    XCTAssertNil( [SFRestAPI SOQLQueryWithFields:(NSArray<NSString*>* _Nonnull)nil sObject:(NSString* _Nonnull) nil whereClause:nil limit:0],
                @"Invalid query did not result in nil output.");
    
    XCTAssertNil( [SFRestAPI SOQLQueryWithFields:@[@"Id"] sObject:(NSString* _Nonnull)nil whereClause:nil limit:0],
                @"Invalid query did not result in nil output.");
    
    NSString *simpleQuery = @"select id from Lead where id<>null limit 10";
    NSString *complexQuery = @"select id,status from Lead where id<>null group by status limit 10";
    
    XCTAssertTrue( [simpleQuery isEqualToString:
                        [SFRestAPI SOQLQueryWithFields:@[@"id"]
                                               sObject:@"Lead"
                                                 whereClause:@"id<>null"
                                                 limit:10]],                 
                 @"Simple SOQL query does not match.");
    
    
    NSString *generatedComplexQuery = [SFRestAPI SOQLQueryWithFields:@[@"id", @"status"]
                                                             sObject:@"Lead"
                                                               whereClause:@"id<>null"
                                                             groupBy:@[@"status"]
                                                              having:nil
                                                             orderBy:nil
                                                               limit:10];
    
    XCTAssertTrue( [complexQuery isEqualToString:generatedComplexQuery],
                 @"Complex SOQL query does not match.");
}

- (void) testSOSL {
    
    XCTAssertNil( [SFRestAPI SOSLSearchWithSearchTerm:(NSString* _Nonnull)nil objectScope:nil],
                 @"Invalid search did not result in nil output.");
    
    BOOL searchLimitEnforced = [[SFRestAPI SOSLSearchWithSearchTerm:@"Test Term" fieldScope:nil objectScope:nil limit:kMaxSOSLSearchLimit + 1] 
                                hasSuffix:[NSString stringWithFormat:@"%li", (long) kMaxSOSLSearchLimit]];
    
    XCTAssertTrue( searchLimitEnforced,
                 @"SOSL search limit was not properly enforced.");
    
    NSString *simpleSearch = @"FIND {blah} IN NAME FIELDS RETURNING User";
    NSString *complexSearch = @"FIND {blah} IN NAME FIELDS RETURNING User (id, name order by lastname asc limit 5) LIMIT 200";
    
    XCTAssertTrue( [simpleSearch isEqualToString:[SFRestAPI SOSLSearchWithSearchTerm:@"blah"
                                                                        objectScope:[NSDictionary dictionaryWithObject:[NSNull null]
                                                                                                                forKey:@"User"]]],
                 @"Simple SOSL search does not match.");    
    
    XCTAssertTrue( [complexSearch isEqualToString:[SFRestAPI SOSLSearchWithSearchTerm:@"blah"
                                                                          fieldScope:nil
                                                                         objectScope:[NSDictionary dictionaryWithObject:@"id, name order by lastname asc limit 5"
                                                                                                                 forKey:@"User"]
                                                                               limit:200]],
                 @"Complex SOSL search does not match.");
}

// - create a contact (requestForCreateWithObjectType)
// - get ID of the created contact
// - form 'IN' clause for SOQL
// - run long SOQL query
// - ensure query works
// - delete the contact (requestForDeleteWithObjectType)
- (void)testReallyLongSOQL {

    // Creates a contact.
    NSString *lastName = [NSString stringWithFormat:@"Silver-%@", [NSDate date]];
    NSDictionary *fields = @{@"FirstName": @"LongJohn", @"LastName": lastName};
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:@"Contact" fields:fields];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // Ensures we get an ID back.
    NSString *contactId = ((NSDictionary *)listener.dataResponse)[@"id"];
    XCTAssertNotNil(contactId, @"id not present");
    [self log:SFLogLevelDebug format:@"## contact created with id: %@", contactId];

    // Creates a long SOQL query.
    NSMutableString *queryString = [[NSMutableString alloc] init];
    [queryString appendString:@"SELECT Id, FirstName, LastName FROM Contact WHERE Id IN ('"];
    for (int i = 0; i < 100; i++) {
        [queryString appendString:contactId];
        [queryString appendString:@"', '"];
    }
    [queryString appendString:@"')"];
    [self log:SFLogLevelDebug format:@"## length of query: %d", [queryString length]];

    // Runs the query.
    @try {
        request = [[SFRestAPI sharedInstance] requestForQuery:queryString];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSArray *records = ((NSDictionary *)listener.dataResponse)[@"records"];
        XCTAssertEqual((int)[records count], 1, @"expected 1 record");
    }
    @finally {

        // Deletes the contact we created.
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"Contact" objectId:contactId];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    }
}

@end
