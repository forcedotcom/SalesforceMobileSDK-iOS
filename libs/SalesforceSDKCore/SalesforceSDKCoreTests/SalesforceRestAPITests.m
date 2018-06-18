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
#import "SFRestRequest+Internal.h"
#import "SFNativeRestRequestListener.h"
#import "SFUserAccount+Internal.h"
 
 // Constants only used in the tests below
#define ENTITY_PREFIX_NAME @"RestClientTestsiOS"
#define ACCOUNT @"Account"
#define CONTACT @"Contact"
#define FIRST_NAME @"FirstName"
#define NAME @"Name"
#define LID @"id"
#define LAST_NAME @"LastName"
#define ID @"Id"
#define SEARCH_RECORDS @"searchRecords"
#define TYPE @"type"
#define RECORDS @"records"
#define ACCOUNT_ID @"AccountId"
#define RESULT @"result"
#define RESULTS @"results"
#define STATUS_CODE @"statusCode"
#define BODY @"body"
#define COMPOSITE_RESPONSE @"compositeResponse"
#define HAS_ERRORS @"hasErrors"
#define ATTRIBUTES @"attributes"
#define HTTP_STATUS_CODE @"httpStatusCode"

 @interface SalesforceRestAPITests ()
{
    SFUserAccount *_currentUser;
}
@property (nonatomic, strong) XCTestExpectation *currentExpectation;

@end

static NSException *authException = nil;

 @class exception;

 @implementation SalesforceRestAPITests

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
    _currentUser = [SFUserAccountManager sharedInstance].currentUser;
    [super setUp];
}

- (void)tearDown
{
    // Tear-down code here.
    [self cleanup];
    [[SFRestAPI sharedInstance] cleanup];
    [NSThread sleepForTimeInterval:0.1];  // Some test runs were failing, saying the run didn't complete.  This seems to fix that.
    [super tearDown];
}



#pragma mark - helper methods

// Helper method to delete any entities created by one of the test
- (void) cleanup {
    SFRestRequest* searchRequest = [[SFRestAPI sharedInstance] requestForSearch:[NSString stringWithFormat:@"find {%@}", ENTITY_PREFIX_NAME]];
    SFNativeRestRequestListener* listener = [self sendSyncRequest:searchRequest];
    NSArray* results = ((NSDictionary*) listener.dataResponse)[SEARCH_RECORDS];
    NSMutableArray* requests = [NSMutableArray new];
    for (NSDictionary* result in results) {
        NSString *objectType = result[ATTRIBUTES][TYPE];
        NSString *objectId = result[ID];
        SFRestRequest *deleteRequest = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:objectType objectId:objectId];
        [requests addObject:deleteRequest];
        if (requests.count == 25) {
            [self sendSyncRequest:[[SFRestAPI sharedInstance] batchRequest:requests haltOnError:NO]];
            [requests removeAllObjects];
        }
    }
    if (requests.count > 0) {
        [self sendSyncRequest:[[SFRestAPI sharedInstance] batchRequest:requests haltOnError:NO]];
    }
}

// Generate a name that uses a known prefix
// During tear down all records using that prefix in their name are deleted
- (NSString*) generateRecordName {
    NSTimeInterval timecode = [NSDate timeIntervalSinceReferenceDate];
    return [NSString stringWithFormat:@"%@%f", ENTITY_PREFIX_NAME, timecode];
}

- (SFNativeRestRequestListener *)sendSyncRequest:(SFRestRequest *)request {
    SFNativeRestRequestListener *listener = [[SFNativeRestRequestListener alloc] initWithRequest:request];
    [[SFRestAPI sharedInstance] send:request delegate:listener];
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
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"request.path: %@", request.path];
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

// simple: just invoke requestForUserInfo
- (void)testGetUserInfo {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForUserInfo];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
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
    [[SFRestAPI sharedInstance] send:request delegate:listener];
    [[SFRestAPI sharedInstance] cancelAllRequests];
    [listener waitForCompletion];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidCancel, @"request should have been cancelled");

}

// simple: just invoke requestForDescribeGlobal, force a timeout
- (void)testGetDescribeGlobal_Timeout {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    SFNativeRestRequestListener *listener = [[SFNativeRestRequestListener alloc] initWithRequest:request];
    [[SFRestAPI sharedInstance] send:request delegate:listener];
    
    BOOL found = [[SFRestAPI sharedInstance] forceTimeoutRequest:request];
    XCTAssertTrue(found , @"Could not find request to force a timeout");
    
    [listener waitForCompletion];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidTimeout, @"request should have timed out");
 }

// simple: just invoke requestForMetadataWithObjectType:@"Contact"
- (void)testGetMetadataWithObjectType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForMetadataWithObjectType:CONTACT];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForDescribeWithObjectType:@"Contact"
- (void)testGetDescribeWithObjectType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeWithObjectType:CONTACT];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForLayoutWithObjectType:@"Contact" without layoutType.
- (void)testGetLayoutWithObjectTypeWithoutLayoutType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForLayoutWithObjectType:CONTACT layoutType:nil];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForLayoutWithObjectType:@"Contact" with layoutType:@"Compact".
- (void)testGetLayoutWithObjectTypeWithLayoutType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForLayoutWithObjectType:CONTACT layoutType:@"Compact"];
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
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForSearchResultLayout:ACCOUNT];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// attempt to create a Contact with none of the required fields (should fail)
- (void)testCreateBogusContact {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:CONTACT fields:nil];
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
    //use a SOSL-safe format here to avoid problems with escaping characters for SOSL
    NSString *lastName = [self generateRecordName];
    //We updated lastName so that it's already SOSL-safe: if you change lastName, you may need to escape SOSL-unsafe characters!
    
    NSDictionary *fields = @{FIRST_NAME: @"John", 
                             LAST_NAME: lastName};

    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:CONTACT fields:fields];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // make sure we got an id
    NSString *contactId = ((NSDictionary *)listener.dataResponse)[LID];
    XCTAssertNotNil(contactId, @"id not present");
    
    @try {
        // try to retrieve object with id
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:CONTACT objectId:contactId fieldList:nil];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        XCTAssertEqualObjects(lastName, ((NSDictionary *)listener.dataResponse)[LAST_NAME], @"invalid last name");
        XCTAssertEqualObjects(@"John", ((NSDictionary *)listener.dataResponse)[FIRST_NAME], @"invalid first name");
        
        // try to retrieve again, passing a list of fields
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:CONTACT objectId:contactId fieldList:@"LastName, FirstName"];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        XCTAssertEqualObjects(lastName, ((NSDictionary *)listener.dataResponse)[LAST_NAME], @"invalid last name");
        XCTAssertEqualObjects(@"John", ((NSDictionary *)listener.dataResponse)[FIRST_NAME], @"invalid first name");
        
        // Raw data will not be converted to JSON if that's what's returned.
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:CONTACT objectId:contactId fieldList:nil];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        XCTAssertTrue([listener.dataResponse isKindOfClass:[NSDictionary class]], @"Should be parsed JSON for JSON response.");

        // Raw data will be converted to JSON if that's what's returned, when JSON parsing is successful.
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:CONTACT objectId:contactId fieldList:nil];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        XCTAssertTrue([listener.dataResponse isKindOfClass:[NSDictionary class]], @"Should be parsed JSON for JSON response.");
        NSDictionary *responseAsJson = listener.dataResponse;
        XCTAssertEqualObjects(lastName, responseAsJson[LAST_NAME], @"invalid last name");
        XCTAssertEqualObjects(@"John", responseAsJson[FIRST_NAME], @"invalid first name");
        
        // now query object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSArray *records = ((NSDictionary *)listener.dataResponse)[RECORDS];
        XCTAssertEqual((int)[records count], 1, @"expected just one query result");
        
        // now search object
        // Record is not available for search right away - so waiting a bit to prevent the test from flapping
        [NSThread sleepForTimeInterval:5.0f];
        request = [[SFRestAPI sharedInstance] requestForSearch:[NSString stringWithFormat:@"Find {%@}", lastName]];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        records = ((NSDictionary *)listener.dataResponse)[SEARCH_RECORDS];
    }
    @finally {
        // now delete object
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:CONTACT objectId:contactId];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    }
    
    // well, let's do another query just to be sure
    request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSArray *records = ((NSDictionary *)listener.dataResponse)[RECORDS];
    XCTAssertEqual((int)[records count], 0, @"expected no result");
    
    // check the deleted object is here
    request = [[SFRestAPI sharedInstance] requestForQueryAll:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSArray* records2 = ((NSDictionary *)listener.dataResponse)[RECORDS];
    XCTAssertEqual((int)[records2 count], 1, @"expected just one query result");

    // now search object
    request = [[SFRestAPI sharedInstance] requestForSearch:[NSString stringWithFormat:@"Find {%@}", lastName]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    records = ((NSDictionary *)listener.dataResponse)[SEARCH_RECORDS];
    
    XCTAssertEqual((int)[records count], 0, @"expected no result");
}

// Runs a SOQL query which contains +
// Make sure it succeeds
-(void) testEscapingWithSOQLQuery {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:@"Select Name from Account where LastModifiedDate > 2017-03-21T12:11:06.000+0000"];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
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
    NSString *lastName = [self generateRecordName];
    NSString *updatedLastName = [lastName stringByAppendingString:@"_updated"];
    
    NSDictionary *fields = @{FIRST_NAME: @"John", 
                            LAST_NAME: lastName};
    
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:CONTACT fields:fields];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // make sure we got an id
    NSString *contactId = ((NSDictionary *)listener.dataResponse)[LID];
    XCTAssertNotNil(contactId, @"id not present");
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"## contact created with id: %@", contactId];
    
    @try {
        // now query object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSArray *records = ((NSDictionary *)listener.dataResponse)[RECORDS];
        XCTAssertEqual((int)[records count], 1, @"expected just one query result");
        
        // modify object
        NSDictionary *updatedFields = @{LAST_NAME: updatedLastName};
        request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:CONTACT objectId:contactId fields:updatedFields];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        
        // query updated object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", updatedLastName]]; 
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        records = ((NSDictionary *)listener.dataResponse)[RECORDS];
        XCTAssertEqual((int)[records count], 1, @"expected just one query result");

        // let's make sure the old object is not there anymore
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName]]; 
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        records = ((NSDictionary *)listener.dataResponse)[RECORDS];
        XCTAssertEqual((int)[records count], 0, @"expected no result");
    }
    @finally {
        // now delete object
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:CONTACT objectId:contactId];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    }
    
    // well, let's do another query just to be sure
    request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", updatedLastName]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSArray *records = ((NSDictionary *)listener.dataResponse)[RECORDS];
    XCTAssertEqual((int)[records count], 0, @"expected no result");
}


 // Testing update calls to the server with if-unmodified-since.
 // - create new account,
 // - then update it with created date for unmodified since date (should update)
 // - then update it again with created date for unmodified since date (should not update)
 - (void)testUpdateWithIfUnmodifiedSince {
     NSDate *pastDate = [NSDate dateWithTimeIntervalSinceNow:-3600];

     // Create
     NSString *accountName = [self generateRecordName];
     NSDictionary *fields = @{NAME: accountName};
     SFRestRequest *createRequest = [[SFRestAPI sharedInstance]
             requestForCreateWithObjectType:ACCOUNT
                                     fields:fields
     ];
     SFNativeRestRequestListener *listener = [self sendSyncRequest:createRequest];
     XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request should have succeeded");
     NSString *accountId = ((NSDictionary *) listener.dataResponse)[LID];

     // Retrieve to get last modified date - expect updated name
     SFRestRequest *firstRetrieveRequest = [[SFRestAPI sharedInstance]
             requestForRetrieveWithObjectType:ACCOUNT objectId:accountId fieldList:@"Name,LastModifiedDate"];
     listener = [self sendSyncRequest:firstRetrieveRequest];
     NSString *retrievedName = ((NSDictionary *) listener.dataResponse)[NAME];
     XCTAssertEqualObjects(retrievedName, accountName, "wrong name retrieved");
     NSString *lastModifiedDateStr = ((NSDictionary *) listener.dataResponse)[@"LastModifiedDate"];
     NSDateFormatter *httpDateFormatter = [NSDateFormatter new];
     httpDateFormatter.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'";
     NSDate *createdDate = [httpDateFormatter dateFromString:lastModifiedDateStr];

     // Wait a bit
     [NSThread sleepForTimeInterval:1.0f];

     // Update with if-unmodified-since with createdDate - should update
     NSString *accountNameUpdated = [accountName stringByAppendingString:@"_updated"];
     NSDictionary *fieldsUpdated = @{NAME: accountNameUpdated};
     SFRestRequest *updateRequest = [[SFRestAPI sharedInstance]
             requestForUpdateWithObjectType:ACCOUNT
                                   objectId:accountId
                                     fields:fieldsUpdated
                      ifUnmodifiedSinceDate:createdDate];
     listener = [self sendSyncRequest:updateRequest];
     XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request should have succeeded");

     // Retrieve - expect updated name
     SFRestRequest *secondRetrieveRequest = [[SFRestAPI sharedInstance]
             requestForRetrieveWithObjectType:ACCOUNT objectId:accountId fieldList:NAME];
     listener = [self sendSyncRequest:secondRetrieveRequest];
     NSString *secondRetrievedName = ((NSDictionary *) listener.dataResponse)[NAME];
     XCTAssertEqualObjects(secondRetrievedName, accountNameUpdated, "wrong name retrieved");

     // Second update with if-unmodified-since with created date - should not update
     NSString *blockedUpdatedName = [accountNameUpdated stringByAppendingString:@"_updated_again"];
     NSDictionary *blockedFieldsUpdated = @{NAME: blockedUpdatedName};
     SFRestRequest *blockedUpdateRequest = [[SFRestAPI sharedInstance]
             requestForUpdateWithObjectType:ACCOUNT
                                   objectId:accountId
                                     fields:blockedFieldsUpdated
                      ifUnmodifiedSinceDate:pastDate];
     listener = [self sendSyncRequest:blockedUpdateRequest];
     XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request should failed");
     XCTAssertEqual(listener.lastError.code, 412, @"request should have returned a 412");

     // Retrieve - expect name from first update
     SFRestRequest *thirdRetrieveRequest = [[SFRestAPI sharedInstance]
             requestForRetrieveWithObjectType:ACCOUNT objectId:accountId fieldList:NAME];
     listener = [self sendSyncRequest:thirdRetrieveRequest];
     NSString *thirdRetrievedName = ((NSDictionary *) listener.dataResponse)[NAME];
     XCTAssertEqualObjects(thirdRetrievedName, accountNameUpdated, "wrong name retrieved");
}

 //exercise upsert on an externalIdField that does not exist
- (void)testUpsertWithBogusExternalIdField {

    //create an account name
    NSString *acctName = [self generateRecordName];
    NSDictionary *fields = @{NAME: acctName};
    
    //create a unique account number
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef uuidStr = CFUUIDCreateString(kCFAllocatorDefault, uuid);
    SFRestRequest *request = [[SFRestAPI sharedInstance]
                              requestForUpsertWithObjectType:ACCOUNT
                              externalIdField:@"bogusField__c" //this field shouldn't be defined in the test org
                              externalId: (__bridge NSString*)uuidStr
                              fields:fields
                              ];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request should have failed");
    XCTAssertEqual(404, listener.lastError.code, @"error code should have been 404");
}

// Testing upsert calls to the server.
// - create new account using a first upsert call then update it with a second upsert call then get it back
 - (void)testUpsert {

     // Create with upsert call
     NSString *accountName = [self generateRecordName];
     NSDictionary *fields = @{NAME: accountName};

     SFRestRequest *firstUpsertRequest = [[SFRestAPI sharedInstance]
             requestForUpsertWithObjectType:ACCOUNT
                            externalIdField:ID
                                 externalId:nil
                                     fields:fields
     ];

     SFNativeRestRequestListener *listener = [self sendSyncRequest:firstUpsertRequest];
     XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request should have succeeded");
     NSString *accountId = ((NSDictionary *) listener.dataResponse)[LID];

     // Retrieve - expect updated name
     SFRestRequest *firstRetrieveRequest = [[SFRestAPI sharedInstance]
             requestForRetrieveWithObjectType:ACCOUNT objectId:accountId fieldList:NAME];
     listener = [self sendSyncRequest:firstRetrieveRequest];
     NSString *retrievedName = ((NSDictionary *) listener.dataResponse)[NAME];
     XCTAssertEqualObjects(retrievedName, accountName, "wrong name retrieved");

     // Update with upsert call
     NSString *accountNameUpdated = [accountName stringByAppendingString:@"_updated"];
     NSDictionary *fieldsUpdated = @{NAME: accountNameUpdated};

     SFRestRequest *secondUpsertRequest = [[SFRestAPI sharedInstance]
             requestForUpsertWithObjectType:ACCOUNT
                            externalIdField:ID
                                 externalId:accountId
                                     fields:fieldsUpdated
     ];
     listener = [self sendSyncRequest:secondUpsertRequest];
     XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request should have succeeded");

     // Retrieve - expect updated name
     SFRestRequest *secondRetrieveRequest = [[SFRestAPI sharedInstance]
             requestForRetrieveWithObjectType:ACCOUNT objectId:accountId fieldList:NAME];
     listener = [self sendSyncRequest:secondRetrieveRequest];
     NSString *secondRetrievedName = ((NSDictionary *) listener.dataResponse)[NAME];
     XCTAssertEqualObjects(secondRetrievedName, accountNameUpdated, "wrong name retrieved");
 }

// issue invalid SOQL and test for errors
- (void)testSOQLError {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:(NSString* _Nonnull)nil];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail , @"request was supposed to fail");
    XCTAssertEqual(listener.lastError.code, 400, @"invalid code");
}

// issue invalid retrieve and test for errors
- (void)testRetrieveError {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:CONTACT objectId:@"bogus_contact_id" fieldList:nil];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
    XCTAssertEqual(listener.lastError.code, 404, @"invalid code");
    request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:CONTACT objectId:@"bogus_contact_id" fieldList:nil];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
    XCTAssertEqual(listener.lastError.code, 404, @"invalid code");
}

 // Test for batch request
 //
 // Run a batch request that:
 // - creates an account,
 // - creates a contact,
 // - run a query that should return newly created account
 // - run a query that should return newly created contact
 -(void) testBatchRequest {
     NSDictionary *fields;

     // Create account
     NSString *accountName = [self generateRecordName];
     fields = @{NAME: accountName};
     SFRestRequest *createAccountRequest = [[SFRestAPI sharedInstance]
             requestForCreateWithObjectType:ACCOUNT
                                     fields:fields
     ];

     // Create contact
     NSString *contactName = [self generateRecordName];
     fields = @{LAST_NAME: contactName};
     SFRestRequest *createContactRequest = [[SFRestAPI sharedInstance]
             requestForCreateWithObjectType:CONTACT
                                     fields:fields
     ];

     // Query for account
     SFRestRequest *queryForAccount = [[SFRestAPI sharedInstance]
             requestForQuery:[NSString stringWithFormat:@"select Id from Account where Name = '%@'", accountName]
     ];

     // Query for contact
     SFRestRequest *queryForContact = [[SFRestAPI sharedInstance]
             requestForQuery:[NSString stringWithFormat:@"select Id from Contact where Name = '%@'", contactName]
     ];

     // Build batch request
     SFRestRequest *batchRequest = [[SFRestAPI sharedInstance]
             batchRequest:@[createAccountRequest, createContactRequest, queryForAccount, queryForContact]
              haltOnError:YES
     ];

     // Send request
     SFNativeRestRequestListener *listener = [self sendSyncRequest:batchRequest];

     // Checking response
     NSDictionary * response = listener.dataResponse;
     XCTAssertEqual(response[HAS_ERRORS], @NO, @"No errors expected");
     NSArray<NSDictionary *>* results = response[RESULTS];
     XCTAssertEqual(results.count, 4, @"Wrong number of results");
     XCTAssertEqual([results[0][STATUS_CODE] intValue], 201, @"Wrong status for first request");
     XCTAssertEqual([results[1][STATUS_CODE] intValue], 201, @"Wrong status for second request");
     XCTAssertEqual([results[2][STATUS_CODE] intValue], 200, @"Wrong status for third request");
     XCTAssertEqual([results[3][STATUS_CODE] intValue], 200, @"Wrong status for fourth request");

     // Queries should have returned ids of newly created account and contact
     NSString* accountId = ((NSDictionary *) results[0][RESULT])[LID];
     NSString* contactId = ((NSDictionary *) results[1][RESULT])[LID];
     NSString* idFromFirstQuery = ((NSDictionary *) results[2][RESULT])[RECORDS][0][ID];
     NSString* idFromSecondQuery = ((NSDictionary *) results[3][RESULT])[RECORDS][0][ID];
     XCTAssertEqualObjects(accountId, idFromFirstQuery, @"Account id not returned by query");
     XCTAssertEqualObjects(contactId, idFromSecondQuery, @"Contact id not returned by query");
 }

 // Test for composite request
 // Run a composite request that:
 // - creates an account,
 // - creates a contact (with newly created account as parent),
 // - run a query that should return newly created account and contact
 - (void) testCompositeRequest {
     NSDictionary *fields;

     // Create account
     NSString *accountName = [self generateRecordName];
     fields = @{NAME: accountName};
     SFRestRequest *createAccountRequest = [[SFRestAPI sharedInstance]
             requestForCreateWithObjectType:ACCOUNT
                                     fields:fields
     ];

     // Create contact
     NSString *contactName = [self generateRecordName];
     fields = @{LAST_NAME: contactName, ACCOUNT_ID: @"@{refAccount.id}"};
     SFRestRequest *createContactRequest = [[SFRestAPI sharedInstance]
             requestForCreateWithObjectType:CONTACT
                                     fields:fields
     ];

     // Query for account and contact
     SFRestRequest *queryForContact = [[SFRestAPI sharedInstance]
             requestForQuery:[NSString stringWithFormat:@"select Id, AccountId from Contact where LastName = '%@'", contactName]
     ];

     // Build composite request
     SFRestRequest *batchRequest = [[SFRestAPI sharedInstance]
             compositeRequest:@[createAccountRequest, createContactRequest, queryForContact]
                       refIds:@[@"refAccount", @"refContact", @"refQuery"]
                    allOrNone:YES
     ];

     // Send request
     SFNativeRestRequestListener *listener = [self sendSyncRequest:batchRequest];

     // Checking response
     NSDictionary * response = listener.dataResponse;
     NSArray<NSDictionary *>* results = response[COMPOSITE_RESPONSE];
     XCTAssertEqual(3, results.count, "Wrong number of results");
     XCTAssertEqual([results[0][HTTP_STATUS_CODE] intValue], 201, @"Wrong status for first request");
     XCTAssertEqual([results[1][HTTP_STATUS_CODE] intValue], 201, @"Wrong status for second request");
     XCTAssertEqual([results[2][HTTP_STATUS_CODE] intValue], 200, @"Wrong status for third request");
     
     // Query should have returned ids of newly created account and contact
     NSString* accountId = ((NSDictionary *) results[0][BODY])[LID];
     NSString* contactId = ((NSDictionary *) results[1][BODY])[LID];
     NSArray<NSDictionary *>* queryRecords = results[2][BODY][RECORDS];
     XCTAssertEqual(1, queryRecords.count, "Wrong number of results for query request");
     XCTAssertEqualObjects(accountId, queryRecords[0][ACCOUNT_ID], "Account id not returned by query");
     XCTAssertEqualObjects(contactId, queryRecords[0][ID], "Contact id not returned by query");
 }

 // Test for sobject tree request
 // Run a sobject tree request that:
 // - creates an account,
 // - creates two children contacts
 // Then run queries that should return newly created account and contacts
 - (void) testSObjectTreeRequest {
     // Prepare sobject tree
     NSString *const accountName = [self generateRecordName];
     NSDictionary * accountFields = @{NAME: accountName};
     NSString *const contactName = [self generateRecordName];
     NSDictionary * contactFields = @{LAST_NAME: contactName};
     NSString *const otherContactName = [self generateRecordName];
     NSDictionary * otherContactFields = @{LAST_NAME: otherContactName};

     SFSObjectTree *contactTree = [[SFSObjectTree alloc] initWithObjectType:CONTACT
                                                           objectTypePlural:@"Contacts"
                                                                referenceId:@"refContact"
                                                                     fields:contactFields
                                                              childrenTrees:nil];

     SFSObjectTree *otherContactTree = [[SFSObjectTree alloc] initWithObjectType:CONTACT
                                                                objectTypePlural:@"Contacts"
                                                                     referenceId:@"refOtherContact"
                                                                          fields:otherContactFields
                                                                   childrenTrees:nil];


     SFSObjectTree *accountTree = [[SFSObjectTree alloc] initWithObjectType:ACCOUNT
                                                           objectTypePlural:nil
                                                                referenceId:@"refAccount"
                                                                     fields:accountFields
                                                              childrenTrees:@[contactTree, otherContactTree]];
     // Build request
     SFRestRequest *treeRequest = [[SFRestAPI sharedInstance] requestForSObjectTree:ACCOUNT objectTrees:@[accountTree]];

     // Send request
     SFNativeRestRequestListener *listener = [self sendSyncRequest:treeRequest];

     // Checking response
     NSDictionary * response = listener.dataResponse;
     XCTAssertEqual(response[HAS_ERRORS], @NO, @"No errors expected");
     NSArray<NSDictionary *>* results = response[RESULTS];
     XCTAssertEqual(3, results.count, "Wrong number of results");
     NSString* accountId = results[0][LID];
     NSString* contactId = results[1][LID];
     NSString* otherContactId = results[2][LID];

     // Running query that should match first contact and its parent
     SFRestRequest *queryRequest = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, AccountId from Contact where LastName = '%@'", contactName]];
     listener = [self sendSyncRequest:queryRequest];
     NSDictionary * queryResponse = listener.dataResponse;
     NSArray<NSDictionary *>* queryRecords = queryResponse[RECORDS];
     XCTAssertEqual(1, queryRecords.count, "Wrong number of results");
     XCTAssertEqualObjects(accountId, queryRecords[0][ACCOUNT_ID], "Account id not returned by query");
     XCTAssertEqualObjects(contactId, queryRecords[0][ID], "Contact id not returned by query");

     // Running other query that should match other contact and its parent
     SFRestRequest *otherQueryRequest = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, AccountId from Contact where LastName = '%@'", otherContactName]];
     listener = [self sendSyncRequest:otherQueryRequest];
     NSDictionary * otherQueryResponse = listener.dataResponse;
     NSArray<NSDictionary *>* otherQueryRecords = otherQueryResponse[RECORDS];
     XCTAssertEqual(1, otherQueryRecords.count, "Wrong number of results");
     XCTAssertEqualObjects(accountId, otherQueryRecords[0][ACCOUNT_ID], "Account id not returned by query");
     XCTAssertEqualObjects(otherContactId, otherQueryRecords[0][ID], "Contact id not returned by query");
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
- (void)testUploadDownloadDeleteFile {

    // upload file
    NSDictionary *fileAttrs = [self uploadFile];

    // download content
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForFileContents:fileAttrs[LID] version:nil];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqualObjects(listener.dataResponse, fileAttrs[@"data"], @"wrong content");

    // download rendition (expect 200/success)
    request = [[SFRestAPI sharedInstance] requestForFileRendition:fileAttrs[LID] version:nil renditionType:@"PDF" page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // delete
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[LID]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // download content again (expect 404)
    request = [[SFRestAPI sharedInstance] requestForFileContents:fileAttrs[LID] version:nil];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
    XCTAssertEqual(listener.lastError.code, 404, @"invalid code");
}

// Upload file / get details / delete file / get details again (expect 404)
- (void)testUploadDetailsDeleteFile {

    // upload file
    NSDictionary *fileAttrs = [self uploadFile];

    // get details
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForFileDetails:fileAttrs[LID] forVersion:nil];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    [self compareFileAttributes:listener.dataResponse expectedAttrs:fileAttrs];
   
    // delete
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[LID]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // get details again (expect 404)
    request = [[SFRestAPI sharedInstance] requestForFileDetails:fileAttrs[LID] forVersion:nil];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
    XCTAssertEqual(listener.lastError.code, 404, @"invalid code");
}

// Upload files / get batch details / delete files / get batch details again (expect 404)
- (void)testUploadBatchDetailsDeleteFiles {

    // upload first file
    NSDictionary *fileAttrs = [self uploadFile];
    
    // upload second file
    NSDictionary *fileAttrs2 = [self uploadFile];
    
    // get batch details
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForBatchFileDetails:@[fileAttrs[LID], fileAttrs2[LID]]];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual([listener.dataResponse[RESULTS][0][STATUS_CODE] intValue], 200, @"expected 200");
    [self compareFileAttributes:listener.dataResponse[RESULTS][0][RESULT] expectedAttrs:fileAttrs];
    XCTAssertEqual([listener.dataResponse[RESULTS][1][STATUS_CODE] intValue], 200, @"expected 200");
    [self compareFileAttributes:listener.dataResponse[RESULTS][1][RESULT] expectedAttrs:fileAttrs2];
    
    // delete first file
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[LID]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // get batch details (expect 404 for first file)
    request = [[SFRestAPI sharedInstance] requestForBatchFileDetails:@[fileAttrs[LID], fileAttrs2[LID]]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual([listener.dataResponse[RESULTS][0][STATUS_CODE] intValue], 404, @"expected 404");
    XCTAssertEqual([listener.dataResponse[RESULTS][1][STATUS_CODE] intValue], 200, @"expected 200");
    [self compareFileAttributes:listener.dataResponse[RESULTS][1][RESULT] expectedAttrs:fileAttrs2];
    
    // delete second file
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs2[LID]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // get batch details (expect 404 for both files)
    request = [[SFRestAPI sharedInstance] requestForBatchFileDetails:@[fileAttrs[LID], fileAttrs2[LID]]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual([listener.dataResponse[RESULTS][0][STATUS_CODE] intValue], 404, @"expected 404");
    XCTAssertEqual([listener.dataResponse[RESULTS][1][STATUS_CODE] intValue], 404, @"expected 404");
}

// Upload files / get owned files / delete files / get owned files again
- (void)testUploadOwnedFilesDelete {

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
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs2[LID]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // get owned files
    request = [[SFRestAPI sharedInstance] requestForOwnedFilesList:nil page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    [self compareFileAttributes:listener.dataResponse[@"files"][0] expectedAttrs:fileAttrs];
    
    // delete first file
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[LID]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// Upload file / share file / get file shares and shared files / unshare file / get file shares and shared files / delete file
- (void)testUploadShareFileSharesSharedFilesUnshareDelete {

    // upload file
    NSDictionary *fileAttrs = [self uploadFile];
    
    // get id of other user
    NSString *otherUserId = [self getOtherUser];
    
    // get file shares
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForFileShares:fileAttrs[LID] page:0];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual((int)[listener.dataResponse[@"shares"] count], 1, @"expected one share");
    XCTAssertEqualObjects([listener.dataResponse[@"shares"][0][@"entity"][LID] substringToIndex:15], _currentUser.credentials.userId, @"expected share with current user");
    XCTAssertEqualObjects(listener.dataResponse[@"shares"][0][@"sharingType"], @"I", @"wrong sharing type");

    // get count files shared with other user
    request = [[SFRestAPI sharedInstance] requestForFilesSharedWithUser:otherUserId page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    int countFilesSharedWithOtherUser = (int)[listener.dataResponse[@"files"] count];
    
    // share file with other user
    request = [[SFRestAPI sharedInstance] requestForAddFileShare:fileAttrs[LID] entityId:otherUserId shareType:@"V"];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSString *shareId = listener.dataResponse[LID];
    
    // get file shares again
    request = [[SFRestAPI sharedInstance] requestForFileShares:fileAttrs[LID] page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSMutableDictionary* actualUserIdToType = [NSMutableDictionary new];
    for (int i=0; i < [listener.dataResponse[@"shares"] count]; i++) {
        NSDictionary* share = listener.dataResponse[@"shares"][i];
        NSString* shareEntityId = [(NSString*) share[@"entity"][LID] substringToIndex:15];
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
    request = [[SFRestAPI sharedInstance] requestForFileShares:fileAttrs[LID] page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual((int)[listener.dataResponse[@"shares"] count], 1, @"expected one share");
    XCTAssertEqualObjects([listener.dataResponse[@"shares"][0][@"entity"][LID] substringToIndex:15], _currentUser.credentials.userId, @"expected share with current user");
    XCTAssertEqualObjects(listener.dataResponse[@"shares"][0][@"sharingType"], @"I", @"wrong sharing type");
    
    // get count files shared with other user
    request = [[SFRestAPI sharedInstance] requestForFilesSharedWithUser:otherUserId page:0];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual((int)[listener.dataResponse[@"files"] count], countFilesSharedWithOtherUser, @"expected one less file shared with other user");
    
    // delete file
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[LID]];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
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
    return listener.dataResponse[RECORDS][0][ID];
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
    XCTAssertEqual([listener.dataResponse[@"contentSize"] intValue], [fileSize intValue], @"wrong content size");
    XCTAssertEqualObjects(listener.dataResponse[@"mimeType"], fileMimeType, @"wrong mime type");
    
    // get id
    NSString *fileId = listener.dataResponse[LID];
    
    // making dictionary with file attributes
    NSDictionary *fileAttrs = @{@"title": fileTitle,
                                @"data": fileData,
                                @"mimeType": fileMimeType,
                                LID: fileId,
                                @"contentSize": fileSize
                                };
    return fileAttrs;
}

// Compare file attributes
- (void) compareFileAttributes:(NSDictionary *)actualFileAttrs expectedAttrs:(NSDictionary *)expectedFileAttrs {
    NSArray *keys = @[LID, @"title", @"contentSize", @"mimeType"];
    for (id key in keys) {
        XCTAssertEqualObjects(actualFileAttrs[key], expectedFileAttrs[key], @"wrong %@", key);
    }
}

- (void)compareMultipleFileAttributes:(NSArray *)actualFileAttrsArray expected:(NSArray *)expectedFileAttrsArray
{

    // Order can't be guaranteed for files.  Cheat a little by matching IDs first.
    for (NSDictionary *expectedFile in expectedFileAttrsArray) {
        NSString *expectedId = expectedFile[LID];
        XCTAssertNotNil(expectedId, @"No value for file's expected ID.");
        BOOL foundMatchingId = NO;
        for (NSDictionary *actualFile in actualFileAttrsArray) {
            NSString *actualId = actualFile[LID];
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
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"latest access token: %@", _currentUser.credentials.accessToken];
    
    // let's make sure we have another access token
    NSString *newAccessToken = _currentUser.credentials.accessToken;
    XCTAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"access token wasn't refreshed");
}

- (void)testInvalidAccessTokenWithValidPostRequest {

    // save invalid token
    NSString *invalidAccessToken = @"xyz";
    [self changeOauthTokens:invalidAccessToken refreshToken:nil];
    
    // request (valid)
    NSDictionary *fields = @{FIRST_NAME: @"John",
                             LAST_NAME: [self generateRecordName]};
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:CONTACT fields:fields];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSString *contactId = ((NSDictionary *)listener.dataResponse)[LID];
    XCTAssertNotNil(contactId, @"Contact create result should contain an ID value.");
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"latest access token: %@", _currentUser.credentials.accessToken];
    
    // let's make sure we have another access token
    NSString *newAccessToken = _currentUser.credentials.accessToken;
    XCTAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"access token wasn't refreshed");
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:CONTACT objectId:contactId];
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

- (void)testFailedRequestRemovedFromQueue {
    
    // Send a request that should fail before getting to the service.
    NSURL *origInstanceUrl = _currentUser.credentials.instanceUrl;
    _currentUser.credentials.instanceUrl = [NSURL URLWithString:@"https://some.non-existent-domain-blafhsdfh"];
    self.currentExpectation = [self expectationWithDescription:@"performRequestToFail"];
    SFRestFailBlock failWithExpectedFail = ^(NSError *e, NSURLResponse *rawResponse) {
        [self.currentExpectation fulfill];
    };
    SFRestDictionaryResponseBlock successWithUnexpectedSuccessBlock = ^(NSDictionary *d, NSURLResponse *rawResponse) {
        XCTFail(@"Request should not have succeeded.");
        [self.currentExpectation fulfill];
    };
    [[SFRestAPI sharedInstance] performRequestForResourcesWithFailBlock:failWithExpectedFail
                                   completeBlock:successWithUnexpectedSuccessBlock];
    
    BOOL completionTimedOut = [self waitForExpectation];
    XCTAssertFalse(completionTimedOut);
    XCTAssertEqual(0, [SFRestAPI sharedInstance].activeRequests.count, @"Active requests queue should be empty.");
    _currentUser.credentials.instanceUrl = origInstanceUrl;
}

// - sets an invalid accessToken
// - sets an invalid refreshToken
// - issue a valid REST request
// - ensure all requests are failed with the proper error
- (void)testInvalidAccessAndRefreshToken {

    // save valid tokens and current user
    NSString *origAccessToken = _currentUser.credentials.accessToken;
    NSString *origRefreshToken = _currentUser.credentials.refreshToken;
    SFOAuthCredentials *origCreds = [_currentUser.credentials copy];
    
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
        origCreds.accessToken = origAccessToken;
        origCreds.refreshToken = origRefreshToken;
        _currentUser.credentials = origCreds;
        [_currentUser transitionToLoginState:SFUserAccountLoginStateLoggedIn];
        [[SFUserAccountManager sharedInstance] saveAccountForUser:_currentUser error:nil];
        [SFUserAccountManager sharedInstance].currentUser = _currentUser;
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
    [[SFRestAPI sharedInstance] send:request0 delegate:listener0];
    [[SFRestAPI sharedInstance] send:request1 delegate:listener1];
    [[SFRestAPI sharedInstance] send:request2 delegate:listener2];
    [[SFRestAPI sharedInstance] send:request3 delegate:listener3];
    [[SFRestAPI sharedInstance] send:request4 delegate:listener4];
    
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

// - set an invalid access token (simulate expired)
// - make multiple simultaneous requests (some not requiring authentication)
// - requests not requiring authentication should succeed and only be sent once
// - other requests will fail in some arbitrary order
// - ensure that a new access token is retrieved using refresh token
// - ensure that all requests eventually succeed
//
-(void)testInvalidAccessToken_UnAuthAndAuthRequests {
    
    // save invalid token
    NSString *invalidAccessToken = @"xyz";
    [self changeOauthTokens:invalidAccessToken refreshToken:nil];

    // create requests (some that require authentications and some that don't)
    SFRestRequest* unauthenticatedRequest1 = [[SFRestAPI sharedInstance] requestForVersions];
    SFRestRequest* unauthenticatedRequest2 = [[SFRestAPI sharedInstance] requestForVersions];
    SFRestRequest* authenticatedRequest1 = [[SFRestAPI sharedInstance] requestForUserInfo];
    SFRestRequest* authenticatedRequest2 = [[SFRestAPI sharedInstance] requestForUserInfo];

    SFNativeRestRequestListener* unauthenticatedListener1 = [[SFNativeRestRequestListener alloc] initWithRequest:unauthenticatedRequest1];
    unauthenticatedListener1.sleepDuringLoad = 0.5;
    SFNativeRestRequestListener* unauthenticatedListener2 = [[SFNativeRestRequestListener alloc] initWithRequest:unauthenticatedRequest2];
    unauthenticatedListener2.sleepDuringLoad = 0.5;
    SFNativeRestRequestListener* authenticatedListener1 = [[SFNativeRestRequestListener alloc] initWithRequest:authenticatedRequest1];
    SFNativeRestRequestListener* authenticatedListener2 = [[SFNativeRestRequestListener alloc] initWithRequest:authenticatedRequest2];
    
    NSArray<SFNativeRestRequestListener*>* listeners = @[unauthenticatedListener1, authenticatedListener1, unauthenticatedListener2, authenticatedListener2];
    
    // send requests
    for (SFNativeRestRequestListener* listener in listeners) {
        [[SFRestAPI sharedInstance] send:listener.request delegate:listener];
    }
    
    // wait for requests to complete
    for (SFNativeRestRequestListener* listener in listeners) {
        [listener waitForCompletion];
    }
    
    // make sure they all succeeded
    for (SFNativeRestRequestListener* listener in listeners) {
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"a request failed");
    }

    // make sure unauthenticated requests don't complete a second time
    for (SFNativeRestRequestListener* listener in @[unauthenticatedListener1, unauthenticatedListener2]) {
        // reset listener return status and lower max wait time
        listener.returnStatus = kTestRequestStatusWaiting;
        listener.maxWaitTime = 2.0;
        XCTAssertEqualObjects([listener waitForCompletion], kTestRequestStatusDidTimeout, @"Unauthenticated user should not have completed a second time");
    }

    // let's make sure we have a new access token
    NSString *newAccessToken = _currentUser.credentials.accessToken;
    XCTAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"access token wasn't refreshed");
}

// - sets an invalid accessToken
// - sets an invalid refreshToken
// - issue multiple valid requests
// - make sure the token exchange failed
// - ensure all requests are failed with the proper error code
- (void)testInvalidAccessAndRefreshToken_MultipleRequests {

    // save valid tokens and current user
    NSString *origAccessToken = _currentUser.credentials.accessToken;
    NSString *origRefreshToken = _currentUser.credentials.refreshToken;
    SFOAuthCredentials *origCreds = [_currentUser.credentials copy];
    
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
        [[SFRestAPI sharedInstance] send:request0 delegate:listener0];
        [[SFRestAPI sharedInstance] send:request1 delegate:listener1];
        [[SFRestAPI sharedInstance] send:request2 delegate:listener2];
        [[SFRestAPI sharedInstance] send:request3 delegate:listener3];
        [[SFRestAPI sharedInstance] send:request4 delegate:listener4];
        
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
        origCreds.accessToken = origAccessToken;
        origCreds.refreshToken = origRefreshToken;
        _currentUser.credentials = origCreds;
        [_currentUser transitionToLoginState:SFUserAccountLoginStateLoggedIn];
        [[SFUserAccountManager sharedInstance] saveAccountForUser:_currentUser error:nil];
        [SFUserAccountManager sharedInstance].currentUser = _currentUser;
    }
}

#pragma mark - testing block functions

- (BOOL) waitForExpectation {
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"Waiting for %@ to complete", self.currentExpectation.description];
    __block BOOL timedout;
    [self waitForExpectationsWithTimeout:15 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"%@ took too long to complete", self.currentExpectation.description);
            timedout = YES;
        } else {
            [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"Completed %@", self.currentExpectation.description];
            timedout = NO;
        }
    }];
    return timedout;
}

// These block functions are just a category on SFRestAPI, so we verify here
// only that the proper blocks were called for each
- (void)testBlockUpdate {
    SFRestFailBlock failWithUnexpectedFail = ^(NSError *e, NSURLResponse *rawResponse) {
        XCTFail(@"Unexpected error %@", e);
        [self.currentExpectation fulfill];
    };
    SFRestDictionaryResponseBlock responseSuccessBlock = ^(NSDictionary *d, NSURLResponse *rawResponse) {
        [self.currentExpectation fulfill];
    };
    SFRestAPI *api = [SFRestAPI sharedInstance];
    NSString *lastName = [self generateRecordName];
    NSString *updatedLastName = [lastName stringByAppendingString:@"_updated"];
    NSMutableDictionary *fields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   @"John", FIRST_NAME,
                                   lastName, LAST_NAME,
                                   nil];
    __block NSString *recordId;
    self.currentExpectation = [self expectationWithDescription:@"performCreateWithObjectType-creating contact"];
    [api performCreateWithObjectType:CONTACT
                              fields:fields
                           failBlock:failWithUnexpectedFail
                       completeBlock:^(NSDictionary *d, NSURLResponse *rawResponse) {
                           recordId = (NSString*) d[LID];
                           [self.currentExpectation fulfill];
                       }];
    [self waitForExpectation];
    self.currentExpectation = [self expectationWithDescription:@"performRetrieveWithObjectType-retrieving contact"];
    [api performRetrieveWithObjectType:CONTACT
                              objectId:recordId
                             fieldList:@[LAST_NAME]
                             failBlock:failWithUnexpectedFail
                         completeBlock:^(NSDictionary *d, NSURLResponse *rawResponse) {
                             XCTAssertEqualObjects(lastName, d[LAST_NAME]);
                             [self.currentExpectation fulfill];
                         }];
    [self waitForExpectation];
    self.currentExpectation = [self expectationWithDescription:@"performUpdateWithObjectType-updating contact"];
    fields[LAST_NAME] = updatedLastName;
    [api performUpdateWithObjectType:CONTACT
                            objectId:recordId
                              fields:fields
                           failBlock:failWithUnexpectedFail
                       completeBlock:responseSuccessBlock];
    [self waitForExpectation];
    self.currentExpectation = [self expectationWithDescription:@"performRetrieveWithObjectType-retrieving contact"];
    [api performRetrieveWithObjectType:CONTACT
                              objectId:recordId
                             fieldList:@[LAST_NAME]
                             failBlock:failWithUnexpectedFail
                         completeBlock:^(NSDictionary *d, NSURLResponse *rawResponse) {
                             XCTAssertEqualObjects(updatedLastName, d[LAST_NAME]);
                             [self.currentExpectation fulfill];
                         }];
    [self waitForExpectation];
    self.currentExpectation = [self expectationWithDescription:@"performDeleteWithObjectType-deleting contact"];
    [api performDeleteWithObjectType:CONTACT
                            objectId:recordId
                           failBlock:failWithUnexpectedFail
                       completeBlock:responseSuccessBlock];
    [self waitForExpectation];
}

- (void) testBlocks {
    SFRestAPI *api = [SFRestAPI sharedInstance];

    // A fail block that we expected to fail
    SFRestFailBlock failWithExpectedFail = ^(NSError *e, NSURLResponse *rawResponse) {
        [self.currentExpectation fulfill];
    };

    // A fail block that should not have failed
    SFRestFailBlock failWithUnexpectedFail = ^(NSError *e, NSURLResponse *rawResponse) {
        XCTFail(@"Unexpected error %@", e);
        [self.currentExpectation fulfill];
    };

    // A success block that should not have succeeded
    SFRestDictionaryResponseBlock successWithUnexpectedSuccessBlock = ^(NSDictionary *d, NSURLResponse *rawResponse) {
        XCTFail(@"Unexpected success %@", d);
        [self.currentExpectation fulfill];
    };

    // An success block that we expected to succeed
    SFRestDictionaryResponseBlock dictSuccessBlock = ^(NSDictionary *d, NSURLResponse *rawResponse) {
        XCTAssertTrue([d isKindOfClass:[NSDictionary class]], @"Response should be a dictionary");
        [self.currentExpectation fulfill];
    };

    // An success block that we expected to succeed
    SFRestArrayResponseBlock arraySuccessBlock = ^(NSArray *a, NSURLResponse *rawResponse) {
        XCTAssertTrue([a isKindOfClass:[NSArray class]], @"Response should be an array");
        [self.currentExpectation fulfill];
    };

    
    // Class helper function that creates an error.
    NSString *errorStr = @"Sample error.";
    XCTAssertTrue([errorStr isEqualToString:[[SFRestAPI errorWithDescription:errorStr] localizedDescription]],
                  @"Generated error should match description.");
    
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
    
    // Block functions that should always succeed
    self.currentExpectation = [self expectationWithDescription:@"performRequestForResourcesWithFailBlock"];
    [api performRequestForResourcesWithFailBlock:failWithUnexpectedFail
                                   completeBlock:dictSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performRequestForVersionsWithFailBlock"];
    [api performRequestForVersionsWithFailBlock:failWithUnexpectedFail
                                  completeBlock:arraySuccessBlock];
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
             completeBlock:dictSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performDescribeWithObjectType-Contact"];
    [api performDescribeWithObjectType:CONTACT
                             failBlock:failWithUnexpectedFail
                         completeBlock:dictSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performMetadataWithObjectType-Contact"];
    [api performMetadataWithObjectType:CONTACT
                             failBlock:failWithUnexpectedFail
                         completeBlock:dictSuccessBlock];
    [self waitForExpectation];
}

- (void)testBlocksCancel {
    self.currentExpectation = [self expectationWithDescription:@"performRequestForResourcesWithFailBlock-with-cancel"];
    SFRestAPI *api = [SFRestAPI sharedInstance];
    
    // A fail block that we expected to fail
    SFRestFailBlock failWithExpectedFail = ^(NSError *e, NSURLResponse *rawResponse) {
        [self.currentExpectation fulfill];
    };
    
    // A success block that should not have succeeded
    SFRestDictionaryResponseBlock successWithUnexpectedSuccessBlock = ^(NSDictionary *d, NSURLResponse *rawResponse) {
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
    SFRestFailBlock failWithExpectedFail = ^(NSError *e, NSURLResponse *rawResponse) {
        [self.currentExpectation fulfill];
    };
    
    // A success block that should not have succeeded
    SFRestDictionaryResponseBlock successWithUnexpectedSuccessBlock = ^(NSDictionary *d, NSURLResponse *rawResponse) {
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

#pragma mark - queryBuilder tests

- (void) testSOQL {

    XCTAssertNil( [SFRestAPI SOQLQueryWithFields:(NSArray<NSString*>* _Nonnull)nil sObject:(NSString* _Nonnull) nil whereClause:nil limit:0],
                @"Invalid query did not result in nil output.");
    
    XCTAssertNil( [SFRestAPI SOQLQueryWithFields:@[ID] sObject:(NSString* _Nonnull)nil whereClause:nil limit:0],
                @"Invalid query did not result in nil output.");
    
    NSString *simpleQuery = @"select id from Lead where id<>null limit 10";
    NSString *complexQuery = @"select id,status from Lead where id<>null group by status limit 10";
    
    XCTAssertTrue( [simpleQuery isEqualToString:
                        [SFRestAPI SOQLQueryWithFields:@[LID]
                                               sObject:@"Lead"
                                                 whereClause:@"id<>null"
                                                 limit:10]],                 
                 @"Simple SOQL query does not match.");
    
    
    NSString *generatedComplexQuery = [SFRestAPI SOQLQueryWithFields:@[LID, @"status"]
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
    NSDictionary *fields = @{FIRST_NAME: @"LongJohn", LAST_NAME: lastName};
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:CONTACT fields:fields];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // Ensures we get an ID back.
    NSString *contactId = ((NSDictionary *)listener.dataResponse)[LID];
    XCTAssertNotNil(contactId, @"id not present");
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"## contact created with id: %@", contactId];

    // Creates a long SOQL query.
    NSMutableString *queryString = [[NSMutableString alloc] init];
    [queryString appendString:@"SELECT Id, FirstName, LastName FROM Contact WHERE Id IN ('"];
    for (int i = 0; i < 100; i++) {
        [queryString appendString:contactId];
        [queryString appendString:@"', '"];
    }
    [queryString appendString:@"')"];
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"## length of query: %d", [queryString length]];

    // Runs the query.
    @try {
        request = [[SFRestAPI sharedInstance] requestForQuery:queryString];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSArray *records = ((NSDictionary *)listener.dataResponse)[RECORDS];
        XCTAssertEqual((int)[records count], 1, @"expected 1 record");
    }
    @finally {

        // Deletes the contact we created.
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:CONTACT objectId:contactId];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    }
}

// Tests that stock Mobile SDK user agent is set on the request.
- (void)testRequestUserAgent {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForSearchResultLayout:ACCOUNT];
    [self sendSyncRequest:request];
    NSString *userAgent = request.request.allHTTPHeaderFields[@"User-Agent"];
    XCTAssertEqualObjects(userAgent, [SFRestAPI userAgentString], @"Incorrect user agent");
}

// Tests that overridden user agent is set on the request.
- (void)testRequestUserAgentWithOverride {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForSearchResultLayout:ACCOUNT];
    [request setHeaderValue:[SFRestAPI userAgentString:@"SmartSync"] forHeaderName:@"User-Agent"];
    [self sendSyncRequest:request];
    NSString *userAgent = request.request.allHTTPHeaderFields[@"User-Agent"];
    XCTAssertEqualObjects(userAgent, [SFRestAPI userAgentString:@"SmartSync"], @"Incorrect user agent");
}

#pragma mark - custom rest requests

- (void)testCustomBaseURLRequest {
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodGET baseURL:@"http://www.apple.com" path:@"/test/testing" queryParams:nil];
    XCTAssertEqual(request.baseURL, @"http://www.apple.com", @"Base URL should match");
    NSURLRequest *finalRequest = [request prepareRequestForSend:_currentUser];
    NSString *expectedURL = [NSString stringWithFormat:@"http://www.apple.com%@%@", kSFDefaultRestEndpoint, @"/test/testing"];
    XCTAssertEqualObjects(finalRequest.URL.absoluteString, expectedURL, @"Final URL should utilize base URL that was passed in");
}

#pragma mark - miscellaneous tests

- (void)testRestUrlForBaseUrl {
    SFOAuthCredentials *creds = [self getTestCredentialsWithDomain:@"somedomain.example.com"
                                                       instanceUrl:[NSURL URLWithString:@"https://someinstance.example.com"]
                                                      communityUrl:[NSURL URLWithString:@"https://somecommunity.example.com/community"]];
    NSString *baseUrl = @"https://somebaseurl.example.com";
    NSString *restUrl = [SFRestRequest restUrlForBaseUrl:baseUrl serviceHostType:SFSDKRestServiceHostTypeInstance credentials:creds];
    XCTAssertEqualObjects(restUrl, baseUrl, @"Base URL should take precedence");
    
    restUrl = [SFRestRequest restUrlForBaseUrl:baseUrl serviceHostType:SFSDKRestServiceHostTypeLogin credentials:creds];
    XCTAssertEqualObjects(restUrl, baseUrl, @"Base URL should take precedence");
}

- (void)testRestUrlForCommunityUrl {
    SFOAuthCredentials *creds = [self getTestCredentialsWithDomain:@"somedomain.example.com"
                                                       instanceUrl:[NSURL URLWithString:@"https://someinstance.example.com"]
                                                      communityUrl:[NSURL URLWithString:@"https://somecommunity.example.com/community"]];
    NSString *restUrl = [SFRestRequest restUrlForBaseUrl:nil serviceHostType:SFSDKRestServiceHostTypeInstance credentials:creds];
    XCTAssertEqualObjects(restUrl, creds.communityUrl.absoluteString, @"Community URL should take precedence");
    
    restUrl = [SFRestRequest restUrlForBaseUrl:nil serviceHostType:SFSDKRestServiceHostTypeLogin credentials:creds];
    XCTAssertEqualObjects(restUrl, creds.communityUrl.absoluteString, @"Community URL should take precedence");
}

- (void)testRestUrlForLoginServiceHost {
    NSString *loginDomain = @"somedomain.example.com";
    SFOAuthCredentials *creds = [self getTestCredentialsWithDomain:loginDomain
                                                       instanceUrl:[NSURL URLWithString:@"https://someinstance.example.com"]
                                                      communityUrl:nil];
    NSString *restUrl = [SFRestRequest restUrlForBaseUrl:nil serviceHostType:SFSDKRestServiceHostTypeLogin credentials:creds];
    NSString *loginDomainUrl = [NSString stringWithFormat:@"https://%@", loginDomain];
    XCTAssertEqualObjects(restUrl, loginDomainUrl, @"Login URL should take precedence");
}

- (void)testRestUrlForInstanceServiceHost {
    NSURL *instanceUrl = [NSURL URLWithString:@"https://someinstance.example.com"];
    SFOAuthCredentials *creds = [self getTestCredentialsWithDomain:@"somdomain.example.com"
                                                       instanceUrl:instanceUrl
                                                      communityUrl:nil];
    NSString *restUrl = [SFRestRequest restUrlForBaseUrl:nil serviceHostType:SFSDKRestServiceHostTypeInstance credentials:creds];
    XCTAssertEqualObjects(restUrl, instanceUrl.absoluteString, @"Instance URL should take precedence");
}

- (SFOAuthCredentials *)getTestCredentialsWithDomain:(nonnull NSString *)domain
                                            instanceUrl:(nonnull NSURL *)instanceUrl
                                           communityUrl:(nullable NSURL *)communityUrl {
    NSString *credsId = [NSString stringWithFormat:@"testRestUrl_%u", arc4random()];
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:credsId clientId:@"TestClientID" encrypted:YES];
    creds.communityUrl = communityUrl;
    creds.domain = domain;
    creds.instanceUrl = instanceUrl;
    return creds;
}

@end
