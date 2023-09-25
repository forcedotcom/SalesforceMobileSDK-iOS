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
#import "SFSDKLogoutBlocker.h"
#import "SalesforceRestAPITests.h"
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import <SalesforceSDKCommon/SFJsonUtils.h>
#import "SFRestAPI+Internal.h"
#import "SFRestRequest+Internal.h"
#import "SFNativeRestRequestListener.h"
#import "SFUserAccount+Internal.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFUserAccountManager+Internal.h"
#import "SFSDKBatchRequest.h"
#import "TestSetupUtils.h"
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
@property (assign) BOOL dataCleanupRequired;

@end

static NSException *authException = nil;

 @class exception;

@interface RestApiAssertionCheckHandler : NSAssertionHandler
@property (assign) BOOL assertionRaised;
@property (strong,nonatomic,readonly) XCTestExpectation *expectation;
- (instancetype)initWithExpectation:(XCTestExpectation *) expectation;
@end

@implementation RestApiAssertionCheckHandler

- (instancetype)initWithExpectation:(XCTestExpectation *)expectation {
    self = [super init];
    if (self) {
        _expectation = expectation;
    }
    return self;
}

- (void)handleFailureInMethod:(SEL)selector
                       object:(id)object
                         file:(NSString *)fileName
                   lineNumber:(NSInteger)line
                  description:(NSString *)format, ...
{    
    [self.expectation fulfill];
}

- (void)handleFailureInFunction:(NSString *)functionName
                           file:(NSString *)fileName
                     lineNumber:(NSInteger)line
                    description:(NSString *)format, ...
{
    [self.expectation fulfill];
}

@end

 @implementation SalesforceRestAPITests

+ (void)setUp
{
    @try {
        [SFSDKLogoutBlocker block];
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
    _dataCleanupRequired = YES;
    // Set-up code here.
    _currentUser = [SFUserAccountManager sharedInstance].currentUser;
    [super setUp];
}

- (void)tearDown
{
    // Tear-down code here.
    if (self.dataCleanupRequired) {
        [self cleanup];
    }
    [[SFRestAPI sharedGlobalInstance] cleanup];
    [[SFRestAPI sharedInstance] cleanup];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:_currentUser];
    [NSThread sleepForTimeInterval:0.1];  // Some test runs were failing, saying the run didn't complete.  This seems to fix that.
    [super tearDown];
}



#pragma mark - helper methods

// Helper method to delete any entities created by one of the test
- (void) cleanup {
    SFRestRequest* searchRequest = [[SFRestAPI sharedInstance] requestForSearch:[NSString stringWithFormat:@"find {%@}", ENTITY_PREFIX_NAME] apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener* listener = [self sendSyncRequest:searchRequest];
    NSArray* results = ((NSDictionary*) listener.dataResponse)[SEARCH_RECORDS];
    NSMutableArray* requests = [NSMutableArray new];
    for (NSDictionary* result in results) {
        NSString *objectType = result[ATTRIBUTES][TYPE];
        NSString *objectId = result[ID];
        SFRestRequest *deleteRequest = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:objectType objectId:objectId apiVersion:kSFRestDefaultAPIVersion];
        [requests addObject:deleteRequest];
        if (requests.count == 25) {
            [self sendSyncRequest:[[SFRestAPI sharedInstance] batchRequest:requests haltOnError:NO apiVersion:kSFRestDefaultAPIVersion]];
            [requests removeAllObjects];
        }
    }
    if (requests.count > 0) {
        [self sendSyncRequest:[[SFRestAPI sharedInstance] batchRequest:requests haltOnError:NO apiVersion:kSFRestDefaultAPIVersion]];
    }
}

// Generate a name that uses a known prefix
// During tear down all records using that prefix in their name are deleted
- (NSString*) generateRecordName {
    NSTimeInterval timecode = [NSDate timeIntervalSinceReferenceDate];
    return [NSString stringWithFormat:@"%@%f", ENTITY_PREFIX_NAME, timecode];
}

- (SFNativeRestRequestListener *)sendSyncRequest:(SFRestRequest *)request{
    return [self sendSyncRequest:request usingInstance:[SFRestAPI sharedInstance]];
}

- (SFNativeRestRequestListener *)sendSyncRequest:(SFRestRequest *)request usingInstance:(SFRestAPI *) instance {
    SFNativeRestRequestListener *listener = [[SFNativeRestRequestListener alloc] initWithRequest:request];
    [instance send:request requestDelegate:listener];
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
    self.dataCleanupRequired = NO;
}

// Using an unauthenticated client to make authenicated requests should result in an assertin failure.
- (void)testAssertionForUnauthenticatedClient {
    XCTestExpectation *assertExpectation = [[XCTestExpectation alloc] initWithDescription:@"Assert Expectation"];
    RestApiAssertionCheckHandler *assertionHandler = [[RestApiAssertionCheckHandler alloc] initWithExpectation:assertExpectation];
    [[[NSThread currentThread] threadDictionary] setValue:assertionHandler
                                                   forKey:NSAssertionHandlerKey];
    SFRestRequest* request = [[SFRestAPI sharedGlobalInstance] requestForResources:kSFRestDefaultAPIVersion];
    @try {
        [[SFRestAPI sharedGlobalInstance] sendRequest:request failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
            
        } successBlock:^(id response, NSURLResponse *rawResponse) {
            
        }];
    }
    @catch(NSException *ignored) {
        
    }
    [self waitForExpectations:@[assertExpectation] timeout:30];
    [[[NSThread currentThread] threadDictionary] setValue:nil
                                                   forKey:NSAssertionHandlerKey];
    self.dataCleanupRequired = NO;
   
}

- (void)testGetVersion_SetDelegate {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForVersions];
    SFNativeRestRequestListener *listener = [[SFNativeRestRequestListener alloc] initWithRequest:request];
    
    //exercises overwriting the delegate at send time
    [[SFRestAPI sharedInstance] send:request requestDelegate:listener];
    [listener waitForCompletion];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

// simple: make sure fully-defined paths in the request are honored too.
- (void)testFullRequestPath {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources:kSFRestDefaultAPIVersion];
    request.path = [NSString stringWithFormat:@"%@%@", kSFDefaultRestEndpoint, request.path];
    [SFLogger log:[self class] level:SFLogLevelDebug format:@"request.path: %@", request.path];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

// simple: make sure that user-defined endpoints are respected
- (void)testUserDefinedEndpoint {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources:kSFRestDefaultAPIVersion];
    [request setEndpoint:@"/my/custom/endpoint"];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request should have failed");
    self.dataCleanupRequired = NO;
}

// simple: just invoke requestForUserInfo
- (void)testGetUserInfo {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForUserInfo];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

// simple: just invoke requestForLimits
- (void)testGetLimits {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForLimits:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

// simple: just invoke requestForResources
- (void)testGetResources {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

// simple: just invoke requestForDescribeGlobal
- (void)testGetDescribeGlobal {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeGlobal:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

// simple: just invoke requestForDescribeGlobal, force a cancel & timeout
- (void)testGetDescribeGlobal_Cancel {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeGlobal:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [[SFNativeRestRequestListener alloc] initWithRequest:request];
    [[SFRestAPI sharedInstance] send:request requestDelegate:listener];
    [[SFRestAPI sharedInstance] cancelAllRequests];
    [listener waitForCompletion];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request should have been cancelled");
    self.dataCleanupRequired = NO;

}

// simple: just invoke requestForDescribeGlobal, force a timeout
- (void)testGetDescribeGlobal_Timeout {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeGlobal:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [[SFNativeRestRequestListener alloc] initWithRequest:request];
    [[SFRestAPI sharedInstance] send:request requestDelegate:listener];
    BOOL found = [[SFRestAPI sharedInstance] forceTimeoutRequest:request];
    XCTAssertTrue(found , @"Could not find request to force a timeout");
    [listener waitForCompletion];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request should have timed out");
    self.dataCleanupRequired = NO;
 }

// simple: just invoke requestForMetadataWithObjectType:@"Contact"
- (void)testGetMetadataWithObjectType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForMetadataWithObjectType:CONTACT apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

// simple: just invoke requestForDescribeWithObjectType:@"Contact"
- (void)testGetDescribeWithObjectType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDescribeWithObjectType:CONTACT apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

// simple: just invoke requestForLayoutWithObjectType:@"Contact" without layoutType.
- (void)testGetLayoutWithObjectAPINameWithoutFormFactor {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForLayoutWithObjectAPIName:CONTACT formFactor:nil layoutType:nil mode:nil recordTypeId:nil apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

// simple: just invoke requestForLayoutWithObjectType:@"Contact" with formFactor:@"Medium".
- (void)testGetLayoutWithObjectAPINameWithFormFactor {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForLayoutWithObjectAPIName:CONTACT formFactor:@"Medium" layoutType:nil mode:nil recordTypeId:nil apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForLayoutWithObjectType:@"Contact" without layoutType.
- (void)testGetLayoutWithObjectAPINameWithoutLayoutType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForLayoutWithObjectAPIName:CONTACT formFactor:nil layoutType:nil mode:nil recordTypeId:nil apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

// simple: just invoke requestForLayoutWithObjectType:@"Contact" with layoutType:@"Compact".
- (void)testGetLayoutWithObjectAPINameWithLayoutType {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForLayoutWithObjectAPIName:CONTACT formFactor:nil layoutType:@"Compact" mode:nil recordTypeId:nil apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForLayoutWithObjectType:@"Contact" without mode.
- (void)testGetLayoutWithObjectAPINameWithoutMode {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForLayoutWithObjectAPIName:CONTACT formFactor:nil layoutType:nil mode:nil recordTypeId:nil apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

// simple: just invoke requestForLayoutWithObjectType:@"Contact" with mode:@"Edit".
- (void)testGetLayoutWithObjectAPINameWithMode {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForLayoutWithObjectAPIName:CONTACT formFactor:nil layoutType:nil mode:@"Edit" recordTypeId:nil apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// simple: just invoke requestForLayoutWithObjectType:@"Contact" without recordTypeId.
- (void)testGetLayoutWithObjectAPINameWithoutRecordTypeId {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForLayoutWithObjectAPIName:CONTACT formFactor:nil layoutType:nil mode:nil recordTypeId:nil apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

// simple: just invoke requestForSearchScopeAndOrder
- (void)testGetSearchScopeAndOrder {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForSearchScopeAndOrder:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

// simple: just invoke requestForSearchResultLayout:@"Account"
- (void)testGetSearchResultLayout {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForSearchResultLayout:ACCOUNT apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

// attempt to create a Contact with none of the required fields (should fail)
- (void)testCreateBogusContact {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:CONTACT fields:nil apiVersion:kSFRestDefaultAPIVersion];
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

    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:CONTACT fields:fields apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // make sure we got an id
    NSString *contactId = ((NSDictionary *)listener.dataResponse)[LID];
    XCTAssertNotNil(contactId, @"id not present");
    
    @try {
        // try to retrieve object with id
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:CONTACT objectId:contactId fieldList:nil apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        XCTAssertEqualObjects(lastName, ((NSDictionary *)listener.dataResponse)[LAST_NAME], @"invalid last name");
        XCTAssertEqualObjects(@"John", ((NSDictionary *)listener.dataResponse)[FIRST_NAME], @"invalid first name");
        
        // try to retrieve again, passing a list of fields
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:CONTACT objectId:contactId fieldList:@"LastName, FirstName" apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        XCTAssertEqualObjects(lastName, ((NSDictionary *)listener.dataResponse)[LAST_NAME], @"invalid last name");
        XCTAssertEqualObjects(@"John", ((NSDictionary *)listener.dataResponse)[FIRST_NAME], @"invalid first name");
        
        // Raw data will not be converted to JSON if that's what's returned.
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:CONTACT objectId:contactId fieldList:nil apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        XCTAssertTrue([listener.dataResponse isKindOfClass:[NSDictionary class]], @"Should be parsed JSON for JSON response.");

        // Raw data will be converted to JSON if that's what's returned, when JSON parsing is successful.
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:CONTACT objectId:contactId fieldList:nil apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        XCTAssertTrue([listener.dataResponse isKindOfClass:[NSDictionary class]], @"Should be parsed JSON for JSON response.");
        NSDictionary *responseAsJson = listener.dataResponse;
        XCTAssertEqualObjects(lastName, responseAsJson[LAST_NAME], @"invalid last name");
        XCTAssertEqualObjects(@"John", responseAsJson[FIRST_NAME], @"invalid first name");
        
        // now query object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName] apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSArray *records = ((NSDictionary *)listener.dataResponse)[RECORDS];
        XCTAssertEqual((int)[records count], 1, @"expected just one query result");
        
        // now search object
        // Record is not available for search right away - so waiting a bit to prevent the test from flapping
        [NSThread sleepForTimeInterval:5.0f];
        request = [[SFRestAPI sharedInstance] requestForSearch:[NSString stringWithFormat:@"Find {%@}", lastName] apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        records = ((NSDictionary *)listener.dataResponse)[SEARCH_RECORDS];
    }
    @finally {
        // now delete object
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:CONTACT objectId:contactId apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    }
    
    // well, let's do another query just to be sure
    request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSArray *records = ((NSDictionary *)listener.dataResponse)[RECORDS];
    XCTAssertEqual((int)[records count], 0, @"expected no result");
    
    // check the deleted object is here
    request = [[SFRestAPI sharedInstance] requestForQueryAll:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSArray* records2 = ((NSDictionary *)listener.dataResponse)[RECORDS];
    XCTAssertEqual((int)[records2 count], 1, @"expected just one query result");

    // now search object
    request = [[SFRestAPI sharedInstance] requestForSearch:[NSString stringWithFormat:@"Find {%@}", lastName] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    records = ((NSDictionary *)listener.dataResponse)[SEARCH_RECORDS];
    
    XCTAssertEqual((int)[records count], 0, @"expected no result");
}

// Runs a SOQL query which contains +
// Make sure it succeeds
-(void) testEscapingWithSOQLQuery {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:@"Select Name from Account where LastModifiedDate > 2017-03-21T12:11:06.000+0000" apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

// Runs a SOQL query which specifies a batch size
// Make sure it succeeds
-(void) testSOQLQueryWithBatchSize {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:@"Select Name from Account" apiVersion:kSFRestDefaultAPIVersion batchSize:250];
    XCTAssertEqualObjects(@"batchSize=250", request.customHeaders[@"Sforce-Query-Options"]);
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    listener = [self sendSyncRequest:request];
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
    
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:CONTACT fields:fields apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // make sure we got an id
    NSString *contactId = ((NSDictionary *)listener.dataResponse)[LID];
    XCTAssertNotNil(contactId, @"id not present");
    [SFLogger log:[self class] level:SFLogLevelDebug format:@"## contact created with id: %@", contactId];
    
    @try {
        // now query object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName] apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSArray *records = ((NSDictionary *)listener.dataResponse)[RECORDS];
        XCTAssertEqual((int)[records count], 1, @"expected just one query result");
        
        // modify object
        NSDictionary *updatedFields = @{LAST_NAME: updatedLastName};
        request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:CONTACT objectId:contactId fields:updatedFields apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        
        // query updated object
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", updatedLastName] apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        records = ((NSDictionary *)listener.dataResponse)[RECORDS];
        XCTAssertEqual((int)[records count], 1, @"expected just one query result");

        // let's make sure the old object is not there anymore
        request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", lastName] apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        records = ((NSDictionary *)listener.dataResponse)[RECORDS];
        XCTAssertEqual((int)[records count], 0, @"expected no result");
    }
    @finally {
        // now delete object
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:CONTACT objectId:contactId apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    }
    
    // well, let's do another query just to be sure
    request = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, FirstName from Contact where LastName='%@'", updatedLastName] apiVersion:kSFRestDefaultAPIVersion];
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
                                 apiVersion:kSFRestDefaultAPIVersion
     ];
     SFNativeRestRequestListener *listener = [self sendSyncRequest:createRequest];
     XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request should have succeeded");
     NSString *accountId = ((NSDictionary *) listener.dataResponse)[LID];

     // Retrieve to get last modified date - expect updated name
     SFRestRequest *firstRetrieveRequest = [[SFRestAPI sharedInstance]
             requestForRetrieveWithObjectType:ACCOUNT objectId:accountId fieldList:@"Name,LastModifiedDate" apiVersion:kSFRestDefaultAPIVersion];
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
                      ifUnmodifiedSinceDate:createdDate
                                 apiVersion:kSFRestDefaultAPIVersion];
     listener = [self sendSyncRequest:updateRequest];
     XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request should have succeeded");

     // Retrieve - expect updated name
     SFRestRequest *secondRetrieveRequest = [[SFRestAPI sharedInstance]
             requestForRetrieveWithObjectType:ACCOUNT objectId:accountId fieldList:NAME apiVersion:kSFRestDefaultAPIVersion];
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
                      ifUnmodifiedSinceDate:pastDate
                                 apiVersion:kSFRestDefaultAPIVersion];
     listener = [self sendSyncRequest:blockedUpdateRequest];
     XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request should failed");
     XCTAssertEqual(listener.lastError.code, 412, @"request should have returned a 412");

     // Retrieve - expect name from first update
     SFRestRequest *thirdRetrieveRequest = [[SFRestAPI sharedInstance]
             requestForRetrieveWithObjectType:ACCOUNT objectId:accountId fieldList:NAME apiVersion:kSFRestDefaultAPIVersion];
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
                          apiVersion:kSFRestDefaultAPIVersion
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
                                 apiVersion:kSFRestDefaultAPIVersion
     ];

     SFNativeRestRequestListener *listener = [self sendSyncRequest:firstUpsertRequest];
     XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request should have succeeded");
     NSString *accountId = ((NSDictionary *) listener.dataResponse)[LID];

     // Retrieve - expect updated name
     SFRestRequest *firstRetrieveRequest = [[SFRestAPI sharedInstance]
             requestForRetrieveWithObjectType:ACCOUNT objectId:accountId fieldList:NAME apiVersion:kSFRestDefaultAPIVersion];
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
                                 apiVersion:kSFRestDefaultAPIVersion
     ];
     listener = [self sendSyncRequest:secondUpsertRequest];
     XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request should have succeeded");

     // Retrieve - expect updated name
     SFRestRequest *secondRetrieveRequest = [[SFRestAPI sharedInstance]
             requestForRetrieveWithObjectType:ACCOUNT objectId:accountId fieldList:NAME apiVersion:kSFRestDefaultAPIVersion];
     listener = [self sendSyncRequest:secondRetrieveRequest];
     NSString *secondRetrievedName = ((NSDictionary *) listener.dataResponse)[NAME];
     XCTAssertEqualObjects(secondRetrievedName, accountNameUpdated, "wrong name retrieved");
 }

// issue invalid SOQL and test for errors
- (void)testSOQLError {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:(NSString* _Nonnull)nil apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail , @"request was supposed to fail");
    XCTAssertEqual(listener.lastError.code, 400, @"invalid code");
    self.dataCleanupRequired = NO;
}

// issue invalid retrieve and test for errors
- (void)testRetrieveError {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:CONTACT objectId:@"bogus_contact_id" fieldList:nil apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
    XCTAssertEqual(listener.lastError.code, 404, @"invalid code");
    request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:CONTACT objectId:@"bogus_contact_id" fieldList:nil apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
    XCTAssertEqual(listener.lastError.code, 404, @"invalid code");
    self.dataCleanupRequired = NO;
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
                                 apiVersion:kSFRestDefaultAPIVersion
     ];

     // Create contact
     NSString *contactName = [self generateRecordName];
     fields = @{LAST_NAME: contactName};
     SFRestRequest *createContactRequest = [[SFRestAPI sharedInstance]
             requestForCreateWithObjectType:CONTACT
                                     fields:fields
                                 apiVersion:kSFRestDefaultAPIVersion
     ];

     // Query for account
     SFRestRequest *queryForAccount = [[SFRestAPI sharedInstance]
             requestForQuery:[NSString stringWithFormat:@"select Id from Account where Name = '%@'", accountName] apiVersion:kSFRestDefaultAPIVersion
     ];

     // Query for contact
     SFRestRequest *queryForContact = [[SFRestAPI sharedInstance]
             requestForQuery:[NSString stringWithFormat:@"select Id from Contact where Name = '%@'", contactName] apiVersion:kSFRestDefaultAPIVersion
     ];

     // Build batch request
     SFRestRequest *batchRequest = [[SFRestAPI sharedInstance]
             batchRequest:@[createAccountRequest, createContactRequest, queryForAccount, queryForContact]
              haltOnError:YES
               apiVersion:kSFRestDefaultAPIVersion
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

 // Test for batch request
 //
 // Run a batch request that:
 // - creates an account,
 // - creates a contact,
 // - run a query that should return newly created account
 // - run a query that should return newly created contact
 -(void)testBatchWithBatchRequest {
     NSDictionary *fields;
     
     SFSDKBatchRequestBuilder *batchRequestBuiler = [[SFSDKBatchRequestBuilder alloc] init];
     // Create account
     NSString *accountName = [self generateRecordName];
     fields = @{NAME: accountName};
     SFRestRequest *createAccountRequest = [[SFRestAPI sharedInstance]
             requestForCreateWithObjectType:ACCOUNT
                                     fields:fields
                                 apiVersion:kSFRestDefaultAPIVersion
     ];
     [batchRequestBuiler addRequest:createAccountRequest];
     // Create contact
     NSString *contactName = [self generateRecordName];
     fields = @{LAST_NAME: contactName};
     SFRestRequest *createContactRequest = [[SFRestAPI sharedInstance]
             requestForCreateWithObjectType:CONTACT
                                     fields:fields
                                 apiVersion:kSFRestDefaultAPIVersion
     ];
     [batchRequestBuiler addRequest:createContactRequest];

     // Query for account
     SFRestRequest *queryForAccount = [[SFRestAPI sharedInstance]
             requestForQuery:[NSString stringWithFormat:@"select Id from Account where Name = '%@'", accountName] apiVersion:kSFRestDefaultAPIVersion
     ];
     [batchRequestBuiler addRequest:queryForAccount];

     // Query for contact
     SFRestRequest *queryForContact = [[SFRestAPI sharedInstance]
             requestForQuery:[NSString stringWithFormat:@"select Id from Contact where Name = '%@'", contactName] apiVersion:kSFRestDefaultAPIVersion
     ];
     [batchRequestBuiler addRequest:queryForContact];

     // Build batch request
     SFSDKBatchRequest *batchRequest = [batchRequestBuiler buildBatchRequest:kSFRestDefaultAPIVersion];
     
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

// Test for batch request
//
// Run a batch request that:
// - creates an account,
// - creates a contact,
// - run a query that should return newly created account
// - run a query that should return newly created contact
-(void)testBatchWithBatchRequestResponse {
    NSDictionary *fields;
    
    SFSDKBatchRequestBuilder *batchRequestBuiler = [[SFSDKBatchRequestBuilder alloc] init];
    // Create account
    NSString *accountName = [self generateRecordName];
    fields = @{NAME: accountName};
    SFRestRequest *createAccountRequest = [[SFRestAPI sharedInstance]
            requestForCreateWithObjectType:ACCOUNT
                                    fields:fields
                                apiVersion:kSFRestDefaultAPIVersion
    ];
    [batchRequestBuiler addRequest:createAccountRequest];
    // Create contact
    NSString *contactName = [self generateRecordName];
    fields = @{LAST_NAME: contactName};
    SFRestRequest *createContactRequest = [[SFRestAPI sharedInstance]
            requestForCreateWithObjectType:CONTACT
                                    fields:fields
                                apiVersion:kSFRestDefaultAPIVersion
    ];
    [batchRequestBuiler addRequest:createContactRequest];

    // Query for account
    SFRestRequest *queryForAccount = [[SFRestAPI sharedInstance]
            requestForQuery:[NSString stringWithFormat:@"select Id from Account where Name = '%@'", accountName] apiVersion:kSFRestDefaultAPIVersion
    ];
    [batchRequestBuiler addRequest:queryForAccount];

    // Query for contact
    SFRestRequest *queryForContact = [[SFRestAPI sharedInstance]
            requestForQuery:[NSString stringWithFormat:@"select Id from Contact where Name = '%@'", contactName] apiVersion:kSFRestDefaultAPIVersion
    ];
    [batchRequestBuiler addRequest:queryForContact];

    // Build batch request
    XCTestExpectation *expectation = [self expectationWithDescription:@"Batch Request"];
    SFSDKBatchRequest *batchRequest = [batchRequestBuiler buildBatchRequest:kSFRestDefaultAPIVersion];
    __block SFSDKBatchResponse *batchResponse = nil;
    __block NSError *error = nil;
    [[SFRestAPI sharedInstance] sendBatchRequest:batchRequest failureBlock:^(id response, NSError * err, NSURLResponse * rawResponse) {
        error = err;
        [expectation fulfill];
    } successBlock:^(SFSDKBatchResponse *response, NSURLResponse *rawResponse) {
        batchResponse = response;
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:30];
    XCTAssertNil(error, @"Error invoking batch api");
    XCTAssertNotNil(batchResponse, @"Batch Response should not be nil");
    XCTAssertFalse(batchResponse.hasErrors, @"Batch Response should not return with errors");
    XCTAssertNotNil(batchResponse.results, @"Batch Sub Responses should not be nil");
    XCTAssertEqual(4,batchResponse.results.count, "Wrong number of results");

    // Checking response
    NSArray<NSDictionary *>* results = batchResponse.results;
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
                                 apiVersion:kSFRestDefaultAPIVersion
     ];

     // Create contact
     NSString *contactName = [self generateRecordName];
     fields = @{LAST_NAME: contactName, ACCOUNT_ID: @"@{refAccount.id}"};
     SFRestRequest *createContactRequest = [[SFRestAPI sharedInstance]
             requestForCreateWithObjectType:CONTACT
                                     fields:fields
                                 apiVersion:kSFRestDefaultAPIVersion
     ];

     // Query for account and contact
     SFRestRequest *queryForContact = [[SFRestAPI sharedInstance]
             requestForQuery:[NSString stringWithFormat:@"select Id, AccountId from Contact where LastName = '%@'", contactName] apiVersion:kSFRestDefaultAPIVersion
     ];

     // Build composite request
     SFRestRequest *batchRequest = [[SFRestAPI sharedInstance]
             compositeRequest:@[createAccountRequest, createContactRequest, queryForContact]
                       refIds:@[@"refAccount", @"refContact", @"refQuery"]
                    allOrNone:YES
                   apiVersion:kSFRestDefaultAPIVersion
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


// Test for composite request
// Run a composite request that:
// - creates an account,
// - creates a contact (with newly created account as parent),
// - run a query that should return newly created account and contact
- (void) testRequestWithCompositeRequest {
    NSDictionary *fields;
    
    SFSDKCompositeRequestBuilder *requestBuilder = [[SFSDKCompositeRequestBuilder alloc] init];
    
    // Create account
    NSString *accountName = [self generateRecordName];
    fields = @{NAME: accountName};
    SFRestRequest *createAccountRequest = [[SFRestAPI sharedInstance]
            requestForCreateWithObjectType:ACCOUNT
                                    fields:fields
                                apiVersion:kSFRestDefaultAPIVersion
    ];
    [requestBuilder addRequest:createAccountRequest referenceId:@"refAccount"];
    // Create contact
    NSString *contactName = [self generateRecordName];
    fields = @{LAST_NAME: contactName, ACCOUNT_ID: @"@{refAccount.id}"};
    SFRestRequest *createContactRequest = [[SFRestAPI sharedInstance]
            requestForCreateWithObjectType:CONTACT
                                    fields:fields
                                apiVersion:kSFRestDefaultAPIVersion
    ];
    
    [requestBuilder addRequest:createContactRequest referenceId:@"refContact"];
    // Query for account and contact
    SFRestRequest *queryForContact = [[SFRestAPI sharedInstance]
            requestForQuery:[NSString stringWithFormat:@"select Id, AccountId from Contact where LastName = '%@'", contactName] apiVersion:kSFRestDefaultAPIVersion
    ];
    [requestBuilder addRequest:queryForContact referenceId:@"refQuery"];

    // Build composite request
    // Send request
    SFNativeRestRequestListener *listener = [self sendSyncRequest: [requestBuilder buildCompositeRequest:[SFRestAPI sharedInstance].apiVersion]];

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

// Test for composite request
// Run a composite request that:
// - creates an account,
// - creates a contact (with newly created account as parent),
// - run a query that should return newly created account and contact
- (void) testRequestWithCompositeRequestResponse {
    NSDictionary *fields;
    
    SFSDKCompositeRequestBuilder *requestBuilder = [[SFSDKCompositeRequestBuilder alloc] init];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Composite Request"];
    // Create account
    NSString *accountName = [self generateRecordName];
    fields = @{NAME: accountName};
    SFRestRequest *createAccountRequest = [[SFRestAPI sharedInstance]
            requestForCreateWithObjectType:ACCOUNT
                                    fields:fields
                                apiVersion:kSFRestDefaultAPIVersion
    ];
    [requestBuilder addRequest:createAccountRequest referenceId:@"refAccount"];
    // Create contact
    NSString *contactName = [self generateRecordName];
    fields = @{LAST_NAME: contactName, ACCOUNT_ID: @"@{refAccount.id}"};
    SFRestRequest *createContactRequest = [[SFRestAPI sharedInstance]
            requestForCreateWithObjectType:CONTACT
                                    fields:fields
                                apiVersion:kSFRestDefaultAPIVersion
    ];
    
    [requestBuilder addRequest:createContactRequest referenceId:@"refContact"];
    // Query for account and contact
    SFRestRequest *queryForContact = [[SFRestAPI sharedInstance]
            requestForQuery:[NSString stringWithFormat:@"select Id, AccountId from Contact where LastName = '%@'", contactName] apiVersion:kSFRestDefaultAPIVersion
    ];
    [requestBuilder addRequest:queryForContact referenceId:@"refQuery"];
    SFSDKCompositeRequest *compositeRequest = [requestBuilder buildCompositeRequest:[SFRestAPI sharedInstance].apiVersion];
    __block SFSDKCompositeResponse *compositeResponse = nil;
    __block NSError *error = nil;
    [[SFRestAPI sharedInstance] sendCompositeRequest:compositeRequest failureBlock:^(id response, NSError * err, NSURLResponse * rawResponse) {
        error = err;
        [expectation fulfill];
    } successBlock:^(SFSDKCompositeResponse *response, NSURLResponse *rawResponse) {
        compositeResponse = response;
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:30];
    XCTAssertNil(error, @"Error invoking composite api");
    XCTAssertNotNil(compositeResponse, @"Composite Response should not be nil");
    XCTAssertNotNil(compositeResponse.subResponses, @"Composite Sub Responses should not be nil");
    XCTAssertEqual(3, compositeResponse.subResponses.count, "Wrong number of results");
    
    // Checking response
    NSArray<SFSDKCompositeSubResponse *>* subResponses = compositeResponse.subResponses;
    XCTAssertEqual(subResponses[0].httpStatusCode, 201, @"Wrong status for first request");
    XCTAssertEqual(subResponses[1].httpStatusCode, 201, @"Wrong status for second request");
    XCTAssertEqual(subResponses[2].httpStatusCode, 200, @"Wrong status for third request");
    
    XCTAssertNotNil(subResponses[0].body, @"Subresponse must have a response body");
    XCTAssertNotNil(subResponses[1].body,@"Subresponse must have a response body");
    XCTAssertNotNil(subResponses[2].body, @"Subresponse must have a response body");
  
    NSString* accountId = ((NSDictionary *) subResponses[0].body)[LID];
    NSString* contactId = ((NSDictionary *) subResponses[1].body)[LID];
    NSArray<NSDictionary *>* queryRecords = ((NSDictionary *) subResponses[2].body)[RECORDS];
    
    // Query should have returned ids of newly created account and contact
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
     SFRestRequest *treeRequest = [[SFRestAPI sharedInstance] requestForSObjectTree:ACCOUNT objectTrees:@[accountTree] apiVersion:kSFRestDefaultAPIVersion];

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
     SFRestRequest *queryRequest = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, AccountId from Contact where LastName = '%@'", contactName] apiVersion:kSFRestDefaultAPIVersion];
     listener = [self sendSyncRequest:queryRequest];
     NSDictionary * queryResponse = listener.dataResponse;
     NSArray<NSDictionary *>* queryRecords = queryResponse[RECORDS];
     XCTAssertEqual(1, queryRecords.count, "Wrong number of results");
     XCTAssertEqualObjects(accountId, queryRecords[0][ACCOUNT_ID], "Account id not returned by query");
     XCTAssertEqualObjects(contactId, queryRecords[0][ID], "Contact id not returned by query");

     // Running other query that should match other contact and its parent
     SFRestRequest *otherQueryRequest = [[SFRestAPI sharedInstance] requestForQuery:[NSString stringWithFormat:@"select Id, AccountId from Contact where LastName = '%@'", otherContactName] apiVersion:kSFRestDefaultAPIVersion];
     listener = [self sendSyncRequest:otherQueryRequest];
     NSDictionary * otherQueryResponse = listener.dataResponse;
     NSArray<NSDictionary *>* otherQueryRecords = otherQueryResponse[RECORDS];
     XCTAssertEqual(1, otherQueryRecords.count, "Wrong number of results");
     XCTAssertEqualObjects(accountId, otherQueryRecords[0][ACCOUNT_ID], "Account id not returned by query");
     XCTAssertEqualObjects(otherContactId, otherQueryRecords[0][ID], "Contact id not returned by query");
}

// Test for priming records request
- (void) testGetPrimingRecords {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForPrimingRecords:nil changedAfterTimestamp:nil apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    NSDictionary* response = listener.dataResponse;
    XCTAssertNotNil(response[@"primingRecords"]);
    XCTAssertNotNil(response[@"relayToken"]);
    XCTAssertNotNil(response[@"ruleErrors"]);
    XCTAssertNotNil(response[@"stats"]);
}

// Test parsing priming records response going to server
- (void) testParsePrimingRecordsResponseFromServer {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForPrimingRecords:nil changedAfterTimestamp:nil apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    NSDictionary* response = listener.dataResponse;
    @try {
        SFSDKPrimingRecordsResponse* parsedResponse = [[SFSDKPrimingRecordsResponse alloc] initWith:response];
    }
    @catch (NSException *exception) {
        XCTFail(@"Unexpected error %@", exception);
    }
}

// Test parsing priming records response using hardcoded response
- (void) testParsePrimingRecordsResponse {
    NSDictionary* dict = [SFJsonUtils objectFromJSONString:@"{\"primingRecords\":{\"Account\":{\"012S00000009B8HIAU\":[{\"id\":\"001S000001QEDnzIAH\", \"systemModstamp\":\"2021-08-23T18:42:32.000Z\"}, {\"id\":\"001S000000va6rGIAQ\", \"systemModstamp\":\"2019-02-09T02:19:38.000Z\"}]}, \"Contact\":{\"012000000000000AAA\":[{\"id\":\"003S00000129813IAA\", \"systemModstamp\":\"2018-12-22T06:13:59.000Z\"}, {\"id\":\"003S0000012LUhRIAW\", \"systemModstamp\":\"2019-01-12T06:13:11.000Z\"}, {\"id\":\"003S0000012hWwRIAU\", \"systemModstamp\":\"2019-01-30T00:59:06.000Z\"}]}}, \"relayToken\":\"fake-token\", \"ruleErrors\":[{\"ruleId\":\"rule-1\"}, {\"ruleId\":\"rule-2\"}], \"stats\":{\"recordCountServed\":100, \"recordCountTotal\":200, \"ruleCountServed\":2, \"ruleCountTotal\":3}}"];
    
    SFSDKPrimingRecordsResponse* primingRecordsResponse = [[SFSDKPrimingRecordsResponse alloc] initWith:dict];

    // Checking priming records
    // We have accounts and contacts
    XCTAssertEqual(primingRecordsResponse.primingRecords.count, 2);
    // We have one record type for accounts and two accounts
    XCTAssertEqual(primingRecordsResponse.primingRecords[@"Account"].count, 1);
    XCTAssertEqual(primingRecordsResponse.primingRecords[@"Account"][@"012S00000009B8HIAU"].count, 2);
    XCTAssertEqualObjects(primingRecordsResponse.primingRecords[@"Account"][@"012S00000009B8HIAU"][0].objectId, @"001S000001QEDnzIAH");
    XCTAssertEqualObjects(primingRecordsResponse.primingRecords[@"Account"][@"012S00000009B8HIAU"][1].objectId, @"001S000000va6rGIAQ");
    XCTAssertEqual([primingRecordsResponse.primingRecords[@"Account"][@"012S00000009B8HIAU"][0].systemModstamp timeIntervalSince1970], 1629744152);
    // We have one record type for contacts and three contacts
    XCTAssertEqual(primingRecordsResponse.primingRecords[@"Contact"].count, 1);
    XCTAssertEqual(primingRecordsResponse.primingRecords[@"Contact"][@"012000000000000AAA"].count, 3);
    XCTAssertEqualObjects(primingRecordsResponse.primingRecords[@"Contact"][@"012000000000000AAA"][0].objectId, @"003S00000129813IAA");
    XCTAssertEqualObjects(primingRecordsResponse.primingRecords[@"Contact"][@"012000000000000AAA"][1].objectId, @"003S0000012LUhRIAW");
    XCTAssertEqualObjects(primingRecordsResponse.primingRecords[@"Contact"][@"012000000000000AAA"][2].objectId, @"003S0000012hWwRIAU");
    XCTAssertEqual([primingRecordsResponse.primingRecords[@"Contact"][@"012000000000000AAA"][0].systemModstamp timeIntervalSince1970], 1545459239);

    // Checking relay token
    XCTAssertEqualObjects(primingRecordsResponse.relayToken, @"fake-token");
    
    // Checking rule errors
    XCTAssertEqual(primingRecordsResponse.ruleErrors.count, 2);
    XCTAssertEqualObjects(primingRecordsResponse.ruleErrors[0].ruleId, @"rule-1");
    XCTAssertEqualObjects(primingRecordsResponse.ruleErrors[1].ruleId, @"rule-2");

    // Checking stats
    XCTAssertEqual(primingRecordsResponse.stats.recordCountServed, 100);
    XCTAssertEqual(primingRecordsResponse.stats.recordCountTotal, 200);
    XCTAssertEqual(primingRecordsResponse.stats.ruleCountServed, 2);
    XCTAssertEqual(primingRecordsResponse.stats.ruleCountTotal, 3);
}


#pragma mark - testing sobject collection calls

-(void) testCollectionCreate {
    NSString* firstAccountName = [NSString stringWithFormat:@"%@_account_1_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];
    NSString* secondAccountName = [NSString stringWithFormat:@"%@_account_2_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];
    NSString* contactName = [NSString stringWithFormat:@"%@_contact_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];

    NSArray<NSDictionary*>* records = [self makeRecords: @[
        @[@"Account", @"Name", firstAccountName],
        @[@"Account", @"Name", secondAccountName],
        @[@"Contact", @"LastName", contactName],

    ]];

    // Doing a collection create
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCollectionCreate:YES records:records apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    
    // Parsing response
    SFSDKCollectionResponse* parsedCreateResponse = [[SFSDKCollectionResponse alloc] initWith:listener.dataResponse];

    // Checking response
    XCTAssertEqual(parsedCreateResponse.subResponses.count, 3);
    XCTAssertTrue([parsedCreateResponse.subResponses[0].objectId hasPrefix:@"001"]);
    XCTAssertTrue(parsedCreateResponse.subResponses[0].success);
    XCTAssertEqual(parsedCreateResponse.subResponses[0].errors.count, 0);
    XCTAssertTrue([parsedCreateResponse.subResponses[1].objectId hasPrefix:@"001"]);
    XCTAssertTrue(parsedCreateResponse.subResponses[1].success);
    XCTAssertEqual(parsedCreateResponse.subResponses[1].errors.count, 0);
    XCTAssertTrue([parsedCreateResponse.subResponses[2].objectId hasPrefix:@"003"]);
    XCTAssertTrue(parsedCreateResponse.subResponses[2].success);
    XCTAssertEqual(parsedCreateResponse.subResponses[2].errors.count, 0);
}

- (void) testCollectionRetrieve {
    NSString* firstAccountName = [NSString stringWithFormat:@"%@_account_1_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];
    NSString* secondAccountName = [NSString stringWithFormat:@"%@_account_2_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];
    NSString* contactName = [NSString stringWithFormat:@"%@_contact_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];

    NSArray<NSDictionary*>* records = [self makeRecords: @[
        @[@"Account", @"Name", firstAccountName],
        @[@"Contact", @"LastName", contactName],
        @[@"Account", @"Name", secondAccountName]
    ]];

    // Doing a collection create
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCollectionCreate:YES records:records apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    
    // Parsing response
    SFSDKCollectionResponse* parsedCreateResponse = [[SFSDKCollectionResponse alloc] initWith:listener.dataResponse];
    NSString* firstAccountId = parsedCreateResponse.subResponses[0].objectId;
    NSString* contactId = parsedCreateResponse.subResponses[1].objectId;
    NSString* secondAccountId = parsedCreateResponse.subResponses[2].objectId;

    // Doing a collection retrieve for the accounts
    SFRestRequest* accountsRetrieveRequest = [[SFRestAPI sharedInstance] requestForCollectionRetrieve:@"Account" objectIds:@[firstAccountId, secondAccountId] fieldList:@[@"Id", @"Name"] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:accountsRetrieveRequest];
    NSArray<NSDictionary*>* accountsRetrieved = listener.dataResponse;

    // Checking response
    XCTAssertEqual(accountsRetrieved.count, 2);
    XCTAssertEqualObjects(accountsRetrieved[0][@"Name"], firstAccountName);
    XCTAssertEqualObjects(accountsRetrieved[1][@"Name"], secondAccountName);

    // Doing a collection retrieve for the contact
    SFRestRequest* contactsRetrievedRequest = [[SFRestAPI sharedInstance] requestForCollectionRetrieve:@"Contact" objectIds:@[contactId] fieldList:@[@"Id", @"LastName"] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:contactsRetrievedRequest];
    NSArray<NSDictionary*>* contactsRetrieved = listener.dataResponse;

    // Checking response
    XCTAssertEqual(contactsRetrieved.count, 1);
    XCTAssertEqualObjects(contactsRetrieved[0][@"LastName"], contactName);
}

 - (void) testCollectionUpsertNewRecords {
     NSString* firstAccountName = [NSString stringWithFormat:@"%@_account_1_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];
     NSString* secondAccountName = [NSString stringWithFormat:@"%@_account_2_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];

     NSArray<NSDictionary*>* records = [self makeRecords: @[
         @[@"Account", @"Name", firstAccountName],
         @[@"Account", @"Name", secondAccountName]
     ]];

     // Doing a collection upsert
     SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCollectionUpsert:YES objectType:@"Account" externalIdField:@"Id" records:records apiVersion:kSFRestDefaultAPIVersion];
     SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
     
     // Parsing response
     SFSDKCollectionResponse* parsedUpsertResponse = [[SFSDKCollectionResponse alloc] initWith:listener.dataResponse];

     // Checking response
     XCTAssertEqual(parsedUpsertResponse.subResponses.count, 2);
     XCTAssertTrue([parsedUpsertResponse.subResponses[0].objectId hasPrefix:@"001"]);
     XCTAssertTrue(parsedUpsertResponse.subResponses[0].success);
     XCTAssertEqual(0, parsedUpsertResponse.subResponses[0].errors.count);
     XCTAssertTrue([parsedUpsertResponse.subResponses[1].objectId hasPrefix:@"001"]);
     XCTAssertTrue(parsedUpsertResponse.subResponses[1].success);
     XCTAssertEqual(0, parsedUpsertResponse.subResponses[1].errors.count);
}
  

- (void) testCollectionUpsertExistingRecords {
    NSString* firstAccountName = [NSString stringWithFormat:@"%@_account_1_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];
    NSString* secondAccountName = [NSString stringWithFormat:@"%@_account_2_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];

    NSArray<NSDictionary*>* records = [self makeRecords: @[
        @[@"Account", @"Name", firstAccountName],
        @[@"Account", @"Name", secondAccountName]
    ]];
    
    // Doing a collection create
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCollectionCreate:YES records:records apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    
    // Parsing response
    SFSDKCollectionResponse* parsedCreateResponse = [[SFSDKCollectionResponse alloc] initWith:listener.dataResponse];
    NSString* firstAccountId = parsedCreateResponse.subResponses[0].objectId;
    NSString* secondAccountId = parsedCreateResponse.subResponses[1].objectId;

    // Doing a collection upsert to update the accounts
    NSString* firstAccountNameUpdated = [NSString stringWithFormat:@"%@%@", firstAccountName, @"_updated"];
    NSString* secondAccountNameUpdated = [NSString stringWithFormat:@"%@%@", secondAccountName, @"_updated"];
    NSArray<NSDictionary*>* updatedAccounts = [self makeRecords: @[
        @[@"Account", @"Name", firstAccountNameUpdated, @"Id", firstAccountId],
        @[@"Account", @"Name", secondAccountNameUpdated, @"Id", secondAccountId]
    ]];
    
    request = [[SFRestAPI sharedInstance] requestForCollectionUpsert:YES objectType:@"Account" externalIdField:@"Id" records:updatedAccounts apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    
    // Parsing response
    SFSDKCollectionResponse* parsedUpsertResponse = [[SFSDKCollectionResponse alloc] initWith:listener.dataResponse];

    // Checking response
    XCTAssertEqual(parsedUpsertResponse.subResponses.count, 2);
    XCTAssertTrue([parsedUpsertResponse.subResponses[0].objectId hasPrefix:@"001"]);
    XCTAssertTrue(parsedUpsertResponse.subResponses[0].success);
    XCTAssertEqual(parsedUpsertResponse.subResponses[0].errors.count, 0);
    XCTAssertTrue([parsedUpsertResponse.subResponses[1].objectId hasPrefix:@"001"]);
    XCTAssertTrue(parsedUpsertResponse.subResponses[1].success);
    XCTAssertEqual(parsedUpsertResponse.subResponses[1].errors.count, 0);
    
    // Checking accounts on server to make sure they were updated
    request = [[SFRestAPI sharedInstance] requestForCollectionRetrieve:@"Account" objectIds:@[firstAccountId, secondAccountId] fieldList:@[@"Id", @"Name"] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    NSArray<NSDictionary*>* accountsRetrieved = listener.dataResponse;

    // Checking response
    XCTAssertEqual(accountsRetrieved.count, 2);
    XCTAssertEqualObjects(accountsRetrieved[0][@"Name"], firstAccountNameUpdated);
    XCTAssertEqualObjects(accountsRetrieved[1][@"Name"], secondAccountNameUpdated);
}


- (void) testCollectionUpdate {
    NSString* firstAccountName = [NSString stringWithFormat:@"%@_account_1_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];
    NSString* secondAccountName = [NSString stringWithFormat:@"%@_account_2_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];
    NSString* contactName = [NSString stringWithFormat:@"%@_contact_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];

    NSArray<NSDictionary*>* records = [self makeRecords: @[
        @[@"Account", @"Name", firstAccountName],
        @[@"Contact", @"LastName", contactName],
        @[@"Account", @"Name", secondAccountName]
    ]];

    // Doing a collection create
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCollectionCreate:YES records:records apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    
    // Parsing response
    SFSDKCollectionResponse* parsedCreateResponse = [[SFSDKCollectionResponse alloc] initWith:listener.dataResponse];
    NSString* firstAccountId = parsedCreateResponse.subResponses[0].objectId;
    NSString* contactId = parsedCreateResponse.subResponses[1].objectId;
    NSString* secondAccountId = parsedCreateResponse.subResponses[2].objectId;
    
    // Doing a collection update for one contact and one account
    NSString* firstAccountNameUpdated = [NSString stringWithFormat:@"%@%@", firstAccountName, @"_updated"];
    NSString* contactNameUpdated = [NSString stringWithFormat:@"%@%@", contactName, @"_updated"];
    NSArray<NSDictionary*>* updatedRecords = [self makeRecords: @[
        @[@"Account", @"Name", firstAccountNameUpdated, @"Id", firstAccountId],
        @[@"Contact", @"LastName", contactNameUpdated, @"Id", contactId]
    ]];
    
    request = [[SFRestAPI sharedInstance] requestForCollectionUpdate:YES records:updatedRecords apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    
    // Parsing response
    SFSDKCollectionResponse* parsedUpdateResponse = [[SFSDKCollectionResponse alloc] initWith:listener.dataResponse];

    // Checking response
    XCTAssertEqual(parsedUpdateResponse.subResponses.count, 2);
    XCTAssertTrue([parsedUpdateResponse.subResponses[0].objectId hasPrefix:@"001"]);
    XCTAssertTrue(parsedUpdateResponse.subResponses[0].success);
    XCTAssertEqual(parsedUpdateResponse.subResponses[0].errors.count, 0);
    XCTAssertTrue([parsedUpdateResponse.subResponses[1].objectId hasPrefix:@"003"]);
    XCTAssertTrue(parsedUpdateResponse.subResponses[1].success);
    XCTAssertEqual(parsedUpdateResponse.subResponses[1].errors.count, 0);
    
    // Checking accounts on server
    request = [[SFRestAPI sharedInstance] requestForCollectionRetrieve:@"Account" objectIds:@[firstAccountId, secondAccountId] fieldList:@[@"Id", @"Name"] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    NSArray<NSDictionary*>* accountdsRetrieved = listener.dataResponse;
    XCTAssertEqual(accountdsRetrieved.count, 2);
    XCTAssertEqualObjects(accountdsRetrieved[0][@"Name"], firstAccountNameUpdated);
    XCTAssertEqualObjects(accountdsRetrieved[1][@"Name"], secondAccountName);

    // Checking contact on server
    request = [[SFRestAPI sharedInstance] requestForCollectionRetrieve:@"Contact" objectIds:@[contactId] fieldList:@[@"Id", @"LastName"] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    NSArray<NSDictionary*>* contactsRetrieved = listener.dataResponse;
    XCTAssertEqual(contactsRetrieved.count, 1);
    XCTAssertEqualObjects(contactsRetrieved[0][@"LastName"], contactNameUpdated);
}


- (void) testCollectionDelete {
    NSString* firstAccountName = [NSString stringWithFormat:@"%@_account_1_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];
    NSString* secondAccountName = [NSString stringWithFormat:@"%@_account_2_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];
    NSString* contactName = [NSString stringWithFormat:@"%@_contact_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];

    NSArray<NSDictionary*>* records = [self makeRecords: @[
        @[@"Account", @"Name", firstAccountName],
        @[@"Contact", @"LastName", contactName],
        @[@"Account", @"Name", secondAccountName]
    ]];

    // Doing a collection create
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCollectionCreate:YES records:records apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    
    // Parsing response
    SFSDKCollectionResponse* parsedCreateResponse = [[SFSDKCollectionResponse alloc] initWith:listener.dataResponse];
    NSString* firstAccountId = parsedCreateResponse.subResponses[0].objectId;
    NSString* contactId = parsedCreateResponse.subResponses[1].objectId;
    NSString* secondAccountId = parsedCreateResponse.subResponses[2].objectId;

    // Doing a collection delete for one account and the contact
    request = [[SFRestAPI sharedInstance] requestForCollectionDelete:YES objectIds:@[firstAccountId, contactId] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    
    // Parsing response
    SFSDKCollectionResponse* parsedDeleteResponse = [[SFSDKCollectionResponse alloc] initWith:listener.dataResponse];

    // Checking response
    XCTAssertEqual(parsedDeleteResponse.subResponses.count, 2);
    XCTAssertTrue([parsedDeleteResponse.subResponses[0].objectId hasPrefix:@"001"]);
    XCTAssertTrue(parsedDeleteResponse.subResponses[0].success);
    XCTAssertEqual(parsedDeleteResponse.subResponses[0].errors.count, 0);
    XCTAssertTrue([parsedDeleteResponse.subResponses[1].objectId hasPrefix:@"003"]);
    XCTAssertTrue(parsedDeleteResponse.subResponses[1].success);
    XCTAssertEqual(parsedDeleteResponse.subResponses[1].errors.count, 0);
    
    // Making sure deleted account is gone using retrieve
    request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Account" objectId:firstAccountId fieldList:@"Id,Name" apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqual(404, listener.lastError.code);

    // Making sure deleted account is gone using collection retrieve
    request = [[SFRestAPI sharedInstance] requestForCollectionRetrieve:@"Account" objectIds:@[firstAccountId, secondAccountId] fieldList:@[@"Id", @"Name"] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    NSArray<NSDictionary*>* accountdsRetrieved = listener.dataResponse;
    XCTAssertEqual(accountdsRetrieved.count, 2);
    XCTAssertEqualObjects(accountdsRetrieved[0], [NSNull null]);
    XCTAssertEqualObjects(accountdsRetrieved[1][@"Name"], secondAccountName);
    
    // Making sure deleted contact is gone using retrieve
    request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:@"Contact" objectId:contactId fieldList:@"Id,LastName" apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqual(404, listener.lastError.code);

    // Making sure deleted account is gone using collection retrieve
    request = [[SFRestAPI sharedInstance] requestForCollectionRetrieve:@"Contact" objectIds:@[contactId] fieldList:@[@"Id", @"LastName"] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    NSArray<NSDictionary*>* contactsRetrieved = listener.dataResponse;
    XCTAssertEqual(contactsRetrieved.count, 1);
    XCTAssertEqualObjects(contactsRetrieved[0], [NSNull null]);
}

- (void) testCollectionCreateWithBadRecordAndAllOrNoneFalse {
    NSString* accountName = [NSString stringWithFormat:@"%@_account_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];
    NSString* contactName = [NSString stringWithFormat:@"%@_contact_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];

    NSArray<NSDictionary*>* records = [self makeRecords: @[
        @[@"Account", @"BadField", accountName],
        @[@"Contact", @"LastName", contactName]
    ]];

    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCollectionCreate:NO records:records apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    SFSDKCollectionResponse* parsedCreateResponse = [[SFSDKCollectionResponse alloc] initWith:listener.dataResponse];

    // Checking response
    XCTAssertEqual(parsedCreateResponse.subResponses.count, 2);
    XCTAssertNil(parsedCreateResponse.subResponses[0].objectId);
    XCTAssertFalse(parsedCreateResponse.subResponses[0].success);
    XCTAssertEqual(parsedCreateResponse.subResponses[0].errors.count, 1);
    XCTAssertEqualObjects(parsedCreateResponse.subResponses[0].errors[0].statusCode, @"INVALID_FIELD");
    XCTAssertTrue([parsedCreateResponse.subResponses[1].objectId hasPrefix:@"003"]);
    XCTAssertTrue(parsedCreateResponse.subResponses[1].success);
    XCTAssertEqual(parsedCreateResponse.subResponses[1].errors.count, 0);
}

- (void) testCollectionCreateWithBadRecordAndAllOrNoneTrue {
    NSString* accountName = [NSString stringWithFormat:@"%@_account_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];
    NSString* contactName = [NSString stringWithFormat:@"%@_contact_%lf", ENTITY_PREFIX_NAME, CFAbsoluteTimeGetCurrent()];

    NSArray<NSDictionary*>* records = [self makeRecords: @[
        @[@"Account", @"BadField", accountName],
        @[@"Contact", @"LastName", contactName]
    ]];

    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCollectionCreate:YES records:records apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    SFSDKCollectionResponse* parsedCreateResponse = [[SFSDKCollectionResponse alloc] initWith:listener.dataResponse];

    // Checking response
    XCTAssertEqual(parsedCreateResponse.subResponses.count, 2);
    XCTAssertNil(parsedCreateResponse.subResponses[0].objectId);
    XCTAssertFalse(parsedCreateResponse.subResponses[0].success);
    XCTAssertEqual(parsedCreateResponse.subResponses[0].errors.count, 1);
    XCTAssertEqualObjects(parsedCreateResponse.subResponses[0].errors[0].statusCode, @"INVALID_FIELD");
    XCTAssertNil(parsedCreateResponse.subResponses[1].objectId);
    XCTAssertFalse(parsedCreateResponse.subResponses[1].success);
    XCTAssertEqual(parsedCreateResponse.subResponses[0].errors.count, 1);
    XCTAssertEqualObjects(parsedCreateResponse.subResponses[1].errors[0].statusCode, @"ALL_OR_NONE_OPERATION_ROLLED_BACK");
}

// Make array of dictionaries representing records with provided type an field
// @param typeFieldNameValues Array of arrays containing objectType, fieldName, otherFieldName, otherFieldValue etc
- (NSArray<NSDictionary*>*) makeRecords:(NSArray<NSArray*>*)typeFieldNameValues {
    NSMutableArray<NSDictionary*>* records = [NSMutableArray new];
    [typeFieldNameValues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSMutableDictionary* record = [NSMutableDictionary new];
        record[@"attributes"] = @{@"type": obj[0]};
        for (NSUInteger i = 1; i < ((NSArray*)obj).count; i +=2) {
            record[obj[i]] = obj[i+1];
        }
        if (obj)
        [records addObject:record];
     }];
    return records;
}

#pragma mark - testing files calls

// simple: just invoke requestForOwnedFilesList
- (void)testOwnedFilesList {
    // with nil for userId
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForOwnedFilesList:nil page:0 apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    // with actual user id
    request = [[SFRestAPI sharedInstance] requestForOwnedFilesList:_currentUser.credentials.userId page:0 apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

- (void)testOwnedFilesListWithCommunity {
    // with nil for userId
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"CLIENT ID"  clientId:@"CLIENT ID" encrypted:NO];
    creds.userId = @"USERID";
    creds.organizationId = @"ORGID";
    creds.communityId = @"COMMUNITYID";
    creds.instanceUrl = [NSURL URLWithString:@"https://sample.domain"];
    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:creds];
    [account setLoginState:SFUserAccountLoginStateLoggedIn];
    SFRestAPI *restAPI = [SFRestAPI sharedInstanceWithUser:account];
    XCTAssertNotNil(restAPI,@"RestApi instance for this user must exist");
    SFRestRequest *request = [restAPI requestForOwnedFilesList:creds.userId page:0 apiVersion:kSFRestDefaultAPIVersion];
    XCTAssertNotNil(request,@"Request should have been created");
    NSURLRequest *urlRequest = [request prepareRequestForSend:account];
    NSRange range = [[[urlRequest URL] absoluteString] rangeOfString:@"connect/communities/COMMUNITYID/"];
    XCTAssertTrue(range.location!= NSNotFound && range.length > 0 , "The URL must have communities path");
    self.dataCleanupRequired = NO;
}

- (void)testOwnedFilesListWithCommunityWithHeaders {
    // with nil for userId
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"CLIENT ID"  clientId:@"CLIENT ID" encrypted:NO];
    creds.userId = @"USERID";
    creds.organizationId = @"ORGID";
    creds.communityId = @"COMMUNITYID";
    creds.instanceUrl = [NSURL URLWithString:@"https://sample.domain"];
    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:creds];
    [account setLoginState:SFUserAccountLoginStateLoggedIn];
    SFRestAPI *restAPI = [SFRestAPI sharedInstanceWithUser:account];
    XCTAssertNotNil(restAPI,@"RestApi instance for this user must exist");
    SFRestRequest *request = [restAPI requestForOwnedFilesList:creds.userId page:0 apiVersion:kSFRestDefaultAPIVersion];
    NSString *simpleType = @"ASimpleType";
    NSString *simpleTypeLength = @"100000";
    [request setHeaderValue:simpleType forHeaderName:@"Content-type"];
    [request setHeaderValue:simpleTypeLength forHeaderName:@"Content-Length"];
    XCTAssertNotNil(request,@"Request should have been created");
    NSURLRequest *urlRequest = [request prepareRequestForSend:account];
    XCTAssertEqualObjects(simpleTypeLength,[urlRequest valueForHTTPHeaderField:@"Content-Length"]);
    XCTAssertEqualObjects(simpleType,[urlRequest valueForHTTPHeaderField:@"Content-Type"]);
    NSRange range = [[[urlRequest URL] absoluteString] rangeOfString:@"connect/communities/COMMUNITYID/"];
    XCTAssertTrue(range.location!= NSNotFound && range.length > 0 , "The URL must have communities path");
}

// simple: just invoke requestForFilesInUsersGroups
- (void)testFilesInUsersGroups {
    // with nil for userId
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForFilesInUsersGroups:nil page:0 apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    // with actual user id
    request = [[SFRestAPI sharedInstance] requestForFilesInUsersGroups:_currentUser.credentials.userId page:0 apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}

// test url for  testFilesInUsersGroupsWithCommunity
- (void)testFilesInUsersGroupsWithCommunity {
    // with nil for userId
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"CLIENT ID"  clientId:@"CLIENT ID" encrypted:NO];
    creds.userId = @"USERID";
    creds.organizationId = @"ORGID";
    creds.instanceUrl = [NSURL URLWithString:@"https://sample.domain"];
    creds.communityId = @"COMMUNITYID";
    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:creds];
    [account setLoginState:SFUserAccountLoginStateLoggedIn];
    SFRestAPI *restAPI = [SFRestAPI sharedInstanceWithUser:account];
    XCTAssertNotNil(restAPI,@"RestApi instance for this user must exist");
    SFRestRequest *request = [restAPI requestForFilesInUsersGroups:creds.userId page:0 apiVersion:kSFRestDefaultAPIVersion];
    XCTAssertNotNil(request,@"Request should have been created");
    NSURLRequest *urlRequest = [request prepareRequestForSend:account];
    NSRange range = [[[urlRequest URL] absoluteString] rangeOfString:@"connect/communities/COMMUNITYID/"];
    XCTAssertTrue(range.location!= NSNotFound && range.length > 0 , "The URL must have communities path");
    self.dataCleanupRequired = NO;
}

// simple: just invoke requestForFilesSharedWithUser
- (void)testFilesSharedWithUser {

    // with nil for userId
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForFilesSharedWithUser:nil page:0 apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    // with actual user id
    request = [[SFRestAPI sharedInstance] requestForFilesSharedWithUser:_currentUser.credentials.userId page:0 apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
}


// test url for  testFileSharesWithUserCommunity
- (void)testFileSharesWithUserCommunity {
    // with nil for userId
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"CLIENT ID"  clientId:@"CLIENT ID" encrypted:NO];
    creds.userId = @"USERID";
    creds.organizationId = @"ORGID";
    creds.communityId = @"COMMUNITYID";
    creds.instanceUrl = [NSURL URLWithString:@"https://sample.domain"];
    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:creds];
    [account setLoginState:SFUserAccountLoginStateLoggedIn];
    SFRestAPI *restAPI = [SFRestAPI sharedInstanceWithUser:account];
    XCTAssertNotNil(restAPI,@"RestApi instance for this user must exist");
    SFRestRequest* request = [restAPI requestForFilesSharedWithUser:@"someid" page:0 apiVersion:kSFRestDefaultAPIVersion];
    XCTAssertNotNil(request,@"Request should have been created");
    NSURLRequest *urlRequest = [request prepareRequestForSend:account];
    NSRange range = [[[urlRequest URL] absoluteString] rangeOfString:@"connect/communities/COMMUNITYID/"];
    XCTAssertTrue(range.location!= NSNotFound && range.length > 0 , "The URL must have communities path");
}


// Upload file / download content / download rendition (expect 403) / delete file / download again (expect 404)
- (void)testUploadDownloadDeleteFile {

    // upload file
    NSDictionary *fileAttrs = [self uploadFile];

    // download content
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForFileContents:fileAttrs[LID] version:nil apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqualObjects(listener.dataResponse, fileAttrs[@"data"], @"wrong content");

    // download rendition (expect 200/success)
    request = [[SFRestAPI sharedInstance] requestForFileRendition:fileAttrs[LID] version:nil renditionType:@"PDF" page:0 apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // delete
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[LID] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // download content again (expect 404)
    request = [[SFRestAPI sharedInstance] requestForFileContents:fileAttrs[LID] version:nil apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
    XCTAssertEqual(listener.lastError.code, 404, @"invalid code");
}

// test url for  testUploadDownloadDeleteFileWithCommunity
- (void)testUploadDownloadDeleteFileWithCommunity {
    // with nil for userId
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"CLIENT ID"  clientId:@"CLIENT ID" encrypted:NO];
    creds.userId = @"USERID";
    creds.organizationId = @"ORGID";
    creds.communityId = @"COMMUNITYID";
   
    creds.instanceUrl = [NSURL URLWithString:@"https://sample.domain"];
    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:creds];
    [account setLoginState:SFUserAccountLoginStateLoggedIn];
    
    NSDictionary *fileAttrs = [self uploadFile];
    SFRestAPI *restAPI = [SFRestAPI sharedInstanceWithUser:account];
    XCTAssertNotNil(restAPI,@"RestApi instance for this user must exist");
    SFRestRequest *request =  [restAPI requestForFileRendition:fileAttrs[LID] version:nil renditionType:@"PDF" page:0 apiVersion:kSFRestDefaultAPIVersion];
    XCTAssertNotNil(request,@"Request should have been created");
    NSURLRequest *urlRequest = [request prepareRequestForSend:account];
    NSRange range = [[[urlRequest URL] absoluteString] rangeOfString:@"connect/communities/COMMUNITYID/"];
    XCTAssertTrue(range.location!= NSNotFound && range.length > 0 , "The URL must have communities path");
    
    request = [restAPI requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[LID] apiVersion:kSFRestDefaultAPIVersion];
    urlRequest = [request prepareRequestForSend:account];
    XCTAssertTrue([[[urlRequest URL] absoluteString] rangeOfString:@"connect/communities/COMMUNITYID/"].location >= 0, "The URL must have communities pasth");
    
    request = [restAPI requestForFileContents:fileAttrs[LID] version:nil apiVersion:kSFRestDefaultAPIVersion];
    urlRequest = [request prepareRequestForSend:account];
    range = [[[urlRequest URL] absoluteString] rangeOfString:@"connect/communities/COMMUNITYID/"];
    XCTAssertTrue(range.location!= NSNotFound && range.length > 0 , "The URL must have communities path");
    
}

// Upload file / get details / delete file / get details again (expect 404)
- (void)testUploadDetailsDeleteFile {

    // upload file
    NSDictionary *fileAttrs = [self uploadFile];

    // get details
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForFileDetails:fileAttrs[LID] forVersion:nil apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    [self compareFileAttributes:listener.dataResponse expectedAttrs:fileAttrs];
   
    // delete
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[LID] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // get details again (expect 404)
    request = [[SFRestAPI sharedInstance] requestForFileDetails:fileAttrs[LID] forVersion:nil apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
    XCTAssertEqual(listener.lastError.code, 404, @"invalid code");
}

- (void)testUploadDetailsDeleteFileWithCommunity {
    // with nil for userId
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"CLIENT ID"  clientId:@"CLIENT ID" encrypted:NO];
    creds.userId = @"USERID";
    creds.organizationId = @"ORGID";
    creds.communityId = @"COMMUNITYID";
    creds.instanceUrl = [NSURL URLWithString:@"https://sample.domain"];
    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:creds];
    [account setLoginState:SFUserAccountLoginStateLoggedIn];
    
    NSDictionary *fileAttrs = [self uploadFile];
    SFRestAPI *restAPI = [SFRestAPI sharedInstanceWithUser:account];
    XCTAssertNotNil(restAPI,@"RestApi instance for this user must exist");
    SFRestRequest *request =  [restAPI requestForFileDetails:fileAttrs[LID] forVersion:nil apiVersion:kSFRestDefaultAPIVersion];
    XCTAssertNotNil(request,@"Request should have been created");
    NSURLRequest *urlRequest = [request prepareRequestForSend:account];
    NSRange range = [[[urlRequest URL] absoluteString] rangeOfString:@"connect/communities/COMMUNITYID/"];
    XCTAssertTrue(range.location!= NSNotFound && range.length > 0 , "The URL must have communities path");
    
}

// Upload files / get batch details / delete files / get batch details again (expect 404)
- (void)testUploadBatchDetailsDeleteFiles {

    // upload first file
    NSDictionary *fileAttrs = [self uploadFile];
    
    // upload second file
    NSDictionary *fileAttrs2 = [self uploadFile];
    
    // get batch details
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForBatchFileDetails:@[fileAttrs[LID], fileAttrs2[LID]] apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual([listener.dataResponse[RESULTS][0][STATUS_CODE] intValue], 200, @"expected 200");
    [self compareFileAttributes:listener.dataResponse[RESULTS][0][RESULT] expectedAttrs:fileAttrs];
    XCTAssertEqual([listener.dataResponse[RESULTS][1][STATUS_CODE] intValue], 200, @"expected 200");
    [self compareFileAttributes:listener.dataResponse[RESULTS][1][RESULT] expectedAttrs:fileAttrs2];
    
    // delete first file
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[LID] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // get batch details (expect 404 for first file)
    request = [[SFRestAPI sharedInstance] requestForBatchFileDetails:@[fileAttrs[LID], fileAttrs2[LID]] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual([listener.dataResponse[RESULTS][0][STATUS_CODE] intValue], 404, @"expected 404");
    XCTAssertEqual([listener.dataResponse[RESULTS][1][STATUS_CODE] intValue], 200, @"expected 200");
    [self compareFileAttributes:listener.dataResponse[RESULTS][1][RESULT] expectedAttrs:fileAttrs2];
    
    // delete second file
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs2[LID] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    
    // get batch details (expect 404 for both files)
    request = [[SFRestAPI sharedInstance] requestForBatchFileDetails:@[fileAttrs[LID], fileAttrs2[LID]] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual([listener.dataResponse[RESULTS][0][STATUS_CODE] intValue], 404, @"expected 404");
    XCTAssertEqual([listener.dataResponse[RESULTS][1][STATUS_CODE] intValue], 404, @"expected 404");
}

- (void)testUploadBatchDetailsDeleteFilesCommunity {
    
    // upload first file
    NSDictionary *fileAttrs = [self uploadFile];
    NSDictionary *fileAttrs2 = [self uploadFile];
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"CLIENT ID"  clientId:@"CLIENT ID" encrypted:NO];
    creds.userId = @"USERID";
    creds.organizationId = @"ORGID";
    creds.communityId = @"COMMUNITYID";
    creds.instanceUrl = [NSURL URLWithString:@"https://sample.domain"];
    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:creds];
    [account setLoginState:SFUserAccountLoginStateLoggedIn];
    
    SFRestAPI *restAPI = [SFRestAPI sharedInstanceWithUser:account];
    XCTAssertNotNil(restAPI,@"RestApi instance for this user must exist");
    SFRestRequest *request =  [restAPI  requestForBatchFileDetails:@[fileAttrs[LID], fileAttrs2[LID]] apiVersion:kSFRestDefaultAPIVersion];
    XCTAssertNotNil(request,@"Request should have been created");
    NSURLRequest *urlRequest = [request prepareRequestForSend:account];
    NSRange range = [[[urlRequest URL] absoluteString] rangeOfString:@"connect/communities/COMMUNITYID/"];
    XCTAssertTrue(range.location!= NSNotFound && range.length > 0 , "The URL must have communities path");
    
}
// Upload files / get owned files / delete files / get owned files again
- (void)testUploadOwnedFilesDelete {

    // upload first file
    NSDictionary *fileAttrs = [self uploadFile];
    // get owned files
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForOwnedFilesList:nil page:0 apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    [self compareFileAttributes:listener.dataResponse[@"files"][0] expectedAttrs:fileAttrs];
    
    // upload other file
    NSDictionary *fileAttrs2 = [self uploadFile];

    // get owned files
    request = [[SFRestAPI sharedInstance] requestForOwnedFilesList:nil page:0 apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    [self compareMultipleFileAttributes:@[ listener.dataResponse[@"files"][0], listener.dataResponse[@"files"][1] ]
                               expected:@[ fileAttrs, fileAttrs2 ]];

    // delete second file
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs2[LID] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // get owned files
    request = [[SFRestAPI sharedInstance] requestForOwnedFilesList:nil page:0 apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    [self compareFileAttributes:listener.dataResponse[@"files"][0] expectedAttrs:fileAttrs];
    
    // delete first file
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[LID] apiVersion:kSFRestDefaultAPIVersion];
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
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForFileShares:fileAttrs[LID] page:0 apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual((int)[listener.dataResponse[@"shares"] count], 1, @"expected one share");
    XCTAssertEqualObjects(listener.dataResponse[@"shares"][0][@"entity"][LID], _currentUser.credentials.userId, @"expected share with current user");
    XCTAssertEqualObjects(listener.dataResponse[@"shares"][0][@"sharingType"], @"I", @"wrong sharing type");

    // get count files shared with other user
    request = [[SFRestAPI sharedInstance] requestForFilesSharedWithUser:otherUserId page:0 apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    int countFilesSharedWithOtherUser = (int)[listener.dataResponse[@"files"] count];
    
    // share file with other user
    request = [[SFRestAPI sharedInstance] requestForAddFileShare:fileAttrs[LID] entityId:otherUserId shareType:@"V" apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSString *shareId = listener.dataResponse[LID];
    
    // get file shares again
    request = [[SFRestAPI sharedInstance] requestForFileShares:fileAttrs[LID] page:0 apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSMutableDictionary* actualUserIdToType = [NSMutableDictionary new];
    for (int i=0; i < [listener.dataResponse[@"shares"] count]; i++) {
        NSDictionary* share = listener.dataResponse[@"shares"][i];
        NSString* shareEntityId = share[@"entity"][LID];
        NSString* shareType = share[@"sharingType"];
        actualUserIdToType[shareEntityId] = shareType;
    }
    XCTAssertEqual([actualUserIdToType count], 2, @"expected two shares");
    XCTAssertTrue([[actualUserIdToType allKeys] containsObject:_currentUser.credentials.userId], @"expected share with current user");
    XCTAssertEqualObjects(actualUserIdToType[_currentUser.credentials.userId], @"I", @"wrong sharing type for current user");
    XCTAssertTrue([[actualUserIdToType allKeys] containsObject:otherUserId], @"expected shared with other user");
    XCTAssertEqualObjects(actualUserIdToType[otherUserId], @"V", @"wrong sharing type for other user");
    
    // get count files shared with other user
    request = [[SFRestAPI sharedInstance] requestForFilesSharedWithUser:otherUserId page:0 apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual((int)[listener.dataResponse[@"files"] count], countFilesSharedWithOtherUser + 1, @"expected one more file shared with other user");
    
    // unshare file from other user
    request = [[SFRestAPI sharedInstance] requestForDeleteFileShare:shareId apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // get files shares again
    request = [[SFRestAPI sharedInstance] requestForFileShares:fileAttrs[LID] page:0 apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual((int)[listener.dataResponse[@"shares"] count], 1, @"expected one share");
    XCTAssertEqualObjects(listener.dataResponse[@"shares"][0][@"entity"][LID], _currentUser.credentials.userId, @"expected share with current user");
    XCTAssertEqualObjects(listener.dataResponse[@"shares"][0][@"sharingType"], @"I", @"wrong sharing type");
    
    // get count files shared with other user
    request = [[SFRestAPI sharedInstance] requestForFilesSharedWithUser:otherUserId page:0 apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqual((int)[listener.dataResponse[@"files"] count], countFilesSharedWithOtherUser, @"expected one less file shared with other user");
    
    // delete file
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:@"ContentDocument" objectId:fileAttrs[LID] apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

- (void)testUploadProfilePhoto {
    // create file data
    NSTimeInterval timecode = [NSDate timeIntervalSinceReferenceDate];
    NSString *fileTitle = [NSString stringWithFormat:@"FileName%f.png", timecode];
    NSData *fileData = UIImagePNGRepresentation([SFSDKResourceUtils imageNamed:@"salesforce-logo"]);
    NSString *fileMimeType = @"application/octet-stream";

    // upload
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForProfilePhotoUpload:fileData fileName:fileTitle mimeType:fileMimeType userId:_currentUser.credentials.userId apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];

    // check response
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

- (void)testUploadProfilePhotoCommunity {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"CLIENT ID"  clientId:@"CLIENT ID" encrypted:NO];
    creds.userId = @"USERID";
    creds.organizationId = @"ORGID";
    creds.instanceUrl = [NSURL URLWithString:@"https://sample.domain"];
    creds.communityId = @"COMMUNITYID";
    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:creds];
    [account setLoginState:SFUserAccountLoginStateLoggedIn];
    SFRestAPI *restAPI = [SFRestAPI sharedInstanceWithUser:account];
    XCTAssertNotNil(restAPI, @"RestApi instance for this user must exist");

    NSTimeInterval timecode = [NSDate timeIntervalSinceReferenceDate];
    NSString *fileTitle = [NSString stringWithFormat:@"FileName%f.png", timecode];
    NSData *fileData = UIImagePNGRepresentation([SFSDKResourceUtils imageNamed:@"salesforce-logo"]);
    NSString *fileMimeType = @"application/octet-stream";
    SFRestRequest* request = [restAPI requestForProfilePhotoUpload:fileData fileName:fileTitle mimeType:fileMimeType userId:creds.userId apiVersion:kSFRestDefaultAPIVersion];

    XCTAssertNotNil(request, @"Request should have been created");
    NSURLRequest *urlRequest = [request prepareRequestForSend:account];
    NSRange range = [[[urlRequest URL] absoluteString] rangeOfString:@"connect/communities/COMMUNITYID/user-profiles/"];
    XCTAssertTrue(range.location != NSNotFound && range.length > 0, "The URL must have communities path");
}

#pragma mark - files tests helpers

// Return id of another user in org
- (NSString *) getOtherUser {
    NSString *soql = [NSString stringWithFormat:@"SELECT Id FROM User WHERE Id != '%@'", _currentUser.credentials.userId];
    
    // query
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:soql apiVersion:kSFRestDefaultAPIVersion];
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
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForUploadFile:fileData name:fileTitle description:fileDescription mimeType:fileMimeType apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    
    // check response
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    XCTAssertEqualObjects(listener.dataResponse[@"title"], fileTitle, @"wrong title");
    XCTAssertEqualObjects(listener.dataResponse[@"description"], fileDescription, @"wrong description");
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
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    [SFLogger log:[self class] level:SFLogLevelDebug format:@"latest access token: %@", _currentUser.credentials.accessToken];
    
    // let's make sure we have another access token
    NSString *newAccessToken = _currentUser.credentials.accessToken;
    XCTAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"access token wasn't refreshed");
    self.dataCleanupRequired = NO;
}

// - sets an invalid accessToken
// - issue a valid REST request
// - make sure the SDK will:
//   - do a oauth token exchange to get a new valid accessToken
//   - fire a notification
// - make sure the query gets replayed properly (and succeed)
- (void)testRefreshNotificationWithValidGetRequest {
    
    // save invalid token
    NSString *invalidAccessToken = @"xyz";
    [self changeOauthTokens:invalidAccessToken refreshToken:nil];
    
    [self expectationForNotification:kSFNotificationUserDidRefreshToken object:nil  handler:^BOOL(NSNotification * notification) {
        return notification.userInfo[kSFNotificationUserInfoAccountKey]!=nil;
    }];
    
    // request (valid)
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForResources:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    [SFLogger log:[self class] level:SFLogLevelDebug format:@"latest access token: %@", _currentUser.credentials.accessToken];
    
    // let's make sure we have another access token
    NSString *newAccessToken = _currentUser.credentials.accessToken;
    XCTAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"access token wasn't refreshed");
    self.dataCleanupRequired = NO;
    
}

- (void)testInvalidAccessTokenWithValidPostRequest {

    // save invalid token
    NSString *invalidAccessToken = @"xyz";
    [self changeOauthTokens:invalidAccessToken refreshToken:nil];
    
    // request (valid)
    NSDictionary *fields = @{FIRST_NAME: @"John",
                             LAST_NAME: [self generateRecordName]};
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:CONTACT fields:fields apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    NSString *contactId = ((NSDictionary *)listener.dataResponse)[LID];
    XCTAssertNotNil(contactId, @"Contact create result should contain an ID value.");
    [SFLogger log:[self class] level:SFLogLevelDebug format:@"latest access token: %@", _currentUser.credentials.accessToken];
    
    // let's make sure we have another access token
    NSString *newAccessToken = _currentUser.credentials.accessToken;
    XCTAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"access token wasn't refreshed");
    request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:CONTACT objectId:contactId apiVersion:kSFRestDefaultAPIVersion];
    listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    self.dataCleanupRequired = NO;
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
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:(NSString* _Nonnull)nil apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request was supposed to fail");
    
    // let's make sure we have another access token
    NSString *newAccessToken = _currentUser.credentials.accessToken;
    self.dataCleanupRequired = NO;
    XCTAssertFalse([newAccessToken isEqualToString:invalidAccessToken], @"access token wasn't refreshed");
}

- (void)testFailedRequestRemovedFromQueue {
    
    // Send a request that should fail before getting to the service.
    NSURL *origInstanceUrl = _currentUser.credentials.instanceUrl;
    _currentUser.credentials.instanceUrl = [NSURL URLWithString:@"https://some.non-existent-domain-blafhsdfh"];
    self.currentExpectation = [self expectationWithDescription:@"performRequestToFail"];
    SFRestRequestFailBlock failWithExpectedFail = ^(id response, NSError *e, NSURLResponse *rawResponse) {
        [self.currentExpectation fulfill];
    };
    SFRestDictionaryResponseBlock successWithUnexpectedSuccessBlock = ^(NSDictionary *d, NSURLResponse *rawResponse) {
        XCTFail(@"Request should not have succeeded.");
        [self.currentExpectation fulfill];
    };

    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForResources:kSFRestDefaultAPIVersion];
    [[SFRestAPI sharedInstance] sendRequest:request failureBlock:failWithExpectedFail successBlock:successWithUnexpectedSuccessBlock];
    BOOL completionTimedOut = [self waitForExpectation];
    XCTAssertFalse(completionTimedOut);
    XCTAssertEqual(0, [SFRestAPI sharedInstance].activeRequests.count, @"Active requests queue should be empty.");
    _currentUser.credentials.instanceUrl = origInstanceUrl;
    self.dataCleanupRequired = NO;
}

// - sets an invalid accessToken
// - sets an invalid refreshToken
// - issue a valid REST request
// - ensure all requests are failed with the proper error
- (void)testInvalidAccessAndRefreshToken {
    
    SFUserAccount *fakeUser = [self createNewUser];
    XCTAssertNotNil(fakeUser,"User should have been created");
    fakeUser.credentials.accessToken = @"xyz";
    fakeUser.credentials.refreshToken = @"xyz";
    
    SFRestAPI *restAPI = [SFRestAPI sharedInstanceWithUser:fakeUser];
    XCTAssertNotNil(restAPI,"SFRestAPI instance for fake user should have been created");
    
    @try {
        // request (valid)
        SFRestRequest* request = [restAPI requestForResources:kSFRestDefaultAPIVersion];
        SFNativeRestRequestListener *listener = [self sendSyncRequest:request usingInstance:restAPI];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidFail, @"request should have failed");
        XCTAssertEqualObjects(listener.lastError.domain, kSFOAuthErrorDomain, @"invalid domain");
        XCTAssertEqual(listener.lastError.code, kSFOAuthErrorInvalidGrant, @"invalid code");
        XCTAssertNotNil(listener.lastError.userInfo);
    }
    @finally {
        self.dataCleanupRequired = NO;
        XCTAssertTrue([self deleteUser:fakeUser],"Should have successfully deleted fake user");
    }
}

// - sets an invalid accessToken
// - sets an invalid refreshToken
// - issue multiple valid requests
// - make sure the token exchange failed
// - ensure all requests are failed with the proper error code
- (void)testInvalidAccessAndRefreshToken_MultipleRequests {
    
    SFUserAccount *fakeUser = [self createNewUser];
    XCTAssertNotNil(fakeUser,@"User should not be nil ");
    fakeUser.credentials.accessToken = @"xyz";
    fakeUser.credentials.refreshToken = @"xyz";
    @try {
        // request (valid)
        SFRestAPI *restAPI = [SFRestAPI sharedInstanceWithUser:fakeUser];
        XCTAssertNotNil(restAPI,@"SFRestAPI instance should not be nil");
        SFRestRequest* request0 = [restAPI requestForDescribeGlobal:kSFRestDefaultAPIVersion];
        XCTestExpectation *expectation0 = [self expectationWithDescription:@"request1"];
        XCTestExpectation *expectation1 = [self expectationWithDescription:@"request2"];
        XCTestExpectation *expectation2 = [self expectationWithDescription:@"request3"];
        XCTestExpectation *expectation3 = [self expectationWithDescription:@"request4"];
        XCTestExpectation *expectation4 = [self expectationWithDescription:@"request5"];
        
        SFRestRequest* request1 = [restAPI requestForDescribeGlobal:kSFRestDefaultAPIVersion];
        SFRestRequest* request2 = [restAPI requestForDescribeGlobal:kSFRestDefaultAPIVersion];
        SFRestRequest* request3 = [restAPI requestForDescribeGlobal:kSFRestDefaultAPIVersion];
        SFRestRequest* request4 = [restAPI requestForDescribeGlobal:kSFRestDefaultAPIVersion];
        
        [restAPI sendRequest:request0 failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
            [expectation0 fulfill];
            XCTAssertEqualObjects(e.domain, kSFOAuthErrorDomain, @"invalid error domain");
        } successBlock:^(id  response, NSURLResponse *rawResponse) {
            
        }];
        
        [restAPI sendRequest:request1 failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
            [expectation1 fulfill];
            XCTAssertEqualObjects(e.domain, kSFOAuthErrorDomain, @"invalid error domain");
        } successBlock:^(id response, NSURLResponse *rawResponse) {
            
        }];
        
        [restAPI sendRequest:request2 failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
            [expectation2 fulfill];
            XCTAssertEqualObjects(e.domain, kSFOAuthErrorDomain, @"invalid error domain");
        } successBlock:^(id response, NSURLResponse *rawResponse) {
            
        }];
        
        [restAPI sendRequest:request3 failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
            [expectation3 fulfill];
            XCTAssertEqualObjects(e.domain, kSFOAuthErrorDomain, @"invalid error domain");
        } successBlock:^(id response, NSURLResponse *rawResponse) {
            
        }];
        
        [restAPI sendRequest:request4 failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
            [expectation4 fulfill];
            XCTAssertEqualObjects(e.domain, kSFOAuthErrorDomain, @"invalid error domain");
        } successBlock:^(id response, NSURLResponse *rawResponse) {
            
        }];
        [self waitForExpectations:@[expectation0,expectation1,expectation2,expectation3,expectation4] timeout:10.0];
    }
    @finally {
        [self deleteUser:fakeUser];
        // no need for cleanup routine here since we dont create any records, adds unneccesary latency to the tests.
        self.dataCleanupRequired = NO;
    }
}

#pragma mark - testing block functions

- (BOOL) waitForExpectation {
    [SFLogger log:[self class] level:SFLogLevelDebug format:@"Waiting for %@ to complete", self.currentExpectation.description];
    __block BOOL timedout;
    [self waitForExpectationsWithTimeout:15 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"%@ took too long to complete", self.currentExpectation.description);
            timedout = YES;
        } else {
            [SFLogger log:[self class] level:SFLogLevelDebug format:@"Completed %@", self.currentExpectation.description];
            timedout = NO;
        }
    }];
    return timedout;
}

// These block functions are just a category on SFRestAPI, so we verify here
// only that the proper blocks were called for each
- (void)testBlockUpdate {
    SFRestRequestFailBlock failWithUnexpectedFail = ^(id response, NSError *e, NSURLResponse *rawResponse) {
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
    SFRestRequest *request = [api requestForCreateWithObjectType:CONTACT fields:fields apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithUnexpectedFail successBlock:^(NSDictionary *d, NSURLResponse *rawResponse) {
        recordId = (NSString*) d[LID];
        [self.currentExpectation fulfill];
    }];
    [self waitForExpectation];
    self.currentExpectation = [self expectationWithDescription:@"performRetrieveWithObjectType-retrieving contact"];
    request = [api requestForRetrieveWithObjectType:CONTACT objectId:recordId fieldList:LAST_NAME apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithUnexpectedFail successBlock:^(NSDictionary *d, NSURLResponse *rawResponse) {
        XCTAssertEqualObjects(lastName, d[LAST_NAME]);
        [self.currentExpectation fulfill];
    }];
    [self waitForExpectation];
    self.currentExpectation = [self expectationWithDescription:@"performUpdateWithObjectType-updating contact"];
    fields[LAST_NAME] = updatedLastName;
    request = [api requestForUpdateWithObjectType:CONTACT objectId:recordId fields:fields apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithUnexpectedFail successBlock:responseSuccessBlock];
    [self waitForExpectation];
    self.currentExpectation = [self expectationWithDescription:@"performRetrieveWithObjectType-retrieving contact"];
    request = [api requestForRetrieveWithObjectType:CONTACT objectId:recordId fieldList:LAST_NAME apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithUnexpectedFail successBlock:^(NSDictionary *d, NSURLResponse *rawResponse) {
        XCTAssertEqualObjects(updatedLastName, d[LAST_NAME]);
        [self.currentExpectation fulfill];
    }];
    [self waitForExpectation];
    self.currentExpectation = [self expectationWithDescription:@"performDeleteWithObjectType-deleting contact"];
    [api requestForDeleteWithObjectType:CONTACT objectId:recordId apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithUnexpectedFail successBlock:responseSuccessBlock];
    [self waitForExpectation];
}

- (void) testBlocks {
    SFRestAPI *api = [SFRestAPI sharedInstance];

    // A fail block that we expected to fail
    SFRestRequestFailBlock failWithExpectedFail = ^(id response, NSError *e, NSURLResponse *rawResponse) {
        [self.currentExpectation fulfill];
    };

    // A fail block that should not have failed
    SFRestRequestFailBlock failWithUnexpectedFail = ^(id response, NSError *e, NSURLResponse *rawResponse) {
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
    SFRestRequest *request = [api requestForDeleteWithObjectType:(NSString* _Nonnull)nil
                                                        objectId:(NSString* _Nonnull)nil
                                                      apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithExpectedFail successBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performCreateWithObjectType-nil"];
    request = [api requestForCreateWithObjectType:(NSString* _Nonnull)nil
                                           fields:(NSDictionary<NSString*, id>* _Nonnull)nil
                                       apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithExpectedFail successBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performMetadataWithObjectType-nil"];
    request = [api requestForMetadataWithObjectType:(NSString* _Nonnull)nil apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithExpectedFail successBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performDescribeWithObjectType-nil"];
    request = [api requestForDescribeWithObjectType:(NSString* _Nonnull)nil apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithExpectedFail successBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performRetrieveWithObjectType-nil"];
    request = [api requestForRetrieveWithObjectType:(NSString* _Nonnull)nil
                                           objectId:(NSString* _Nonnull)nil
                                          fieldList:(NSString* _Nonnull)nil
                                         apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithExpectedFail successBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performUpdateWithObjectType-nil"];
    request = [api requestForRetrieveWithObjectType:(NSString* _Nonnull)nil
                                           objectId:(NSString* _Nonnull)nil
                                          fieldList:(NSString* _Nonnull)nil
                                         apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithExpectedFail successBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performUpsertWithObjectType-nil"];
    request = [api requestForUpsertWithObjectType:(NSString* _Nonnull)nil
                                  externalIdField:(NSString* _Nonnull)nil
                                       externalId:(NSString* _Nonnull)nil
                                           fields:(NSDictionary<NSString*, id>* _Nonnull)nil
                                       apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithExpectedFail successBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performSOQLQuery-nil"];
    request = [api requestForQuery:(NSString* _Nonnull)nil apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithExpectedFail successBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performSOQLQueryAll-nil"];
    request = [api requestForQueryAll:(NSString* _Nonnull)nil apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithExpectedFail successBlock:successWithUnexpectedSuccessBlock];
    [self waitForExpectation];

    // Block functions that should always succeed
    self.currentExpectation = [self expectationWithDescription:@"performRequestForResourcesWithFailBlock"];
    request = [api requestForResources:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithUnexpectedFail successBlock:dictSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performRequestForVersionsWithFailBlock"];
    request = [api requestForVersions];
    [api sendRequest:request failureBlock:failWithUnexpectedFail successBlock:arraySuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performDescribeGlobalWithFailBlock"];
    request = [api requestForDescribeGlobal:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithUnexpectedFail successBlock:dictSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performSOQLQuery-select id from user limit 10"];
    request = [api requestForQuery:@"select id from user limit 10" apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithUnexpectedFail successBlock:dictSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performSOQLQueryAll-select id from user limit 10"];
    request = [api requestForQueryAll:@"select id from user limit 10" apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithUnexpectedFail successBlock:dictSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performSOSLSearch-find {batman}"];
    request = [api requestForSearch:@"find {batman}" apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithUnexpectedFail successBlock:dictSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performDescribeWithObjectType-Contact"];
    request = [api requestForDescribeWithObjectType:CONTACT apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithUnexpectedFail successBlock:dictSuccessBlock];
    [self waitForExpectation];

    self.currentExpectation = [self expectationWithDescription:@"performMetadataWithObjectType-Contact"];
    request = [api requestForMetadataWithObjectType:CONTACT apiVersion:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithUnexpectedFail successBlock:dictSuccessBlock];
    [self waitForExpectation];
}

- (void)testBlocksCancel {
    self.currentExpectation = [self expectationWithDescription:@"performRequestForResourcesWithFailBlock-with-cancel"];
    SFRestAPI *api = [SFRestAPI sharedInstance];
    
    // A fail block that we expected to fail
    SFRestRequestFailBlock failWithExpectedFail = ^(id response, NSError *e, NSURLResponse *rawResponse) {
        [self.currentExpectation fulfill];
    };
    
    // A success block that should not have succeeded
    SFRestDictionaryResponseBlock successWithUnexpectedSuccessBlock = ^(NSDictionary *d, NSURLResponse *rawResponse) {
        XCTFail(@"Unexpected success %@", d);
        [self.currentExpectation fulfill];
    };
    
    SFRestRequest *request = [api requestForResources:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithExpectedFail successBlock:successWithUnexpectedSuccessBlock];

    [api cancelAllRequests];
    
    BOOL completionTimedOut = [self waitForExpectation];
    XCTAssertTrue(!completionTimedOut);
}

- (void)testBlocksTimeout {
    self.currentExpectation = [self expectationWithDescription:@"performRequestForResourcesWithFailBlock-with-forced-timeout"];
    SFRestAPI *api = [SFRestAPI sharedInstance];
    
    // A fail block that we expected to fail
    SFRestRequestFailBlock failWithExpectedFail = ^(id response, NSError *e, NSURLResponse *rawResponse) {
        [self.currentExpectation fulfill];
    };
    
    // A success block that should not have succeeded
    SFRestDictionaryResponseBlock successWithUnexpectedSuccessBlock = ^(NSDictionary *d, NSURLResponse *rawResponse) {
        XCTFail("Unexpected success %@", d);
        [self.currentExpectation fulfill];
    };

    SFRestRequest *request = [api requestForResources:kSFRestDefaultAPIVersion];
    [api sendRequest:request failureBlock:failWithExpectedFail successBlock:successWithUnexpectedSuccessBlock];

    // Ignore null passed warning beceause it necessary for successWithUnexpectedSuccessBlock above
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wnonnull"
    BOOL found = [api forceTimeoutRequest:nil];
    #pragma clang diagnostic pop
    XCTAssertTrue(found , @"Request was not sent and should not be found.");
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
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:CONTACT fields:fields apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // Ensures we get an ID back.
    NSString *contactId = ((NSDictionary *)listener.dataResponse)[LID];
    XCTAssertNotNil(contactId, @"id not present");
    [SFLogger log:[self class] level:SFLogLevelDebug format:@"## contact created with id: %@", contactId];

    // Creates a long SOQL query.
    NSMutableString *queryString = [[NSMutableString alloc] init];
    [queryString appendString:@"SELECT Id, FirstName, LastName FROM Contact WHERE Id IN ('"];
    for (int i = 0; i < 100; i++) {
        [queryString appendString:contactId];
        [queryString appendString:@"', '"];
    }
    [queryString appendString:@"')"];
    [SFLogger log:[self class] level:SFLogLevelDebug format:@"## length of query: %d", [queryString length]];

    // Runs the query.
    @try {
        request = [[SFRestAPI sharedInstance] requestForQuery:queryString apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSArray *records = ((NSDictionary *)listener.dataResponse)[RECORDS];
        XCTAssertEqual((int)[records count], 1, @"expected 1 record");
    }
    @finally {

        // Deletes the contact we created.
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:CONTACT objectId:contactId apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    }
}


- (void) testSOQLWithNewLine {
    // Creates a contact.
    NSString *lastName = [NSString stringWithFormat:@"Silver-%@", [NSDate date]];
    NSDictionary *fields = @{FIRST_NAME: @"LongJohn", LAST_NAME: lastName};
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:CONTACT fields:fields apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");

    // Ensures we get an ID back.
    NSString *contactId = ((NSDictionary *)listener.dataResponse)[LID];
    XCTAssertNotNil(contactId, @"id not present");
    [SFLogger log:[self class] level:SFLogLevelDebug format:@"## contact created with id: %@", contactId];

    // Creates a SOQL query with new lines
    NSMutableString *queryString = [[NSMutableString alloc] init];
    [queryString appendString:[NSString stringWithFormat:@"SELECT Id,\n FirstName,\n LastName\n FROM Contact \nWHERE Id = '%@'", contactId]];

    // Runs the query.
    @try {
        request = [[SFRestAPI sharedInstance] requestForQuery:queryString apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
        NSArray *records = ((NSDictionary *)listener.dataResponse)[RECORDS];
        XCTAssertEqual((int)[records count], 1, @"expected 1 record");
    }
    @finally {
        // Deletes the contact we created.
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:CONTACT objectId:contactId apiVersion:kSFRestDefaultAPIVersion];
        listener = [self sendSyncRequest:request];
        XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
    }    
}

// Tests that stock Mobile SDK user agent is set on the request.
- (void)testRequestUserAgent {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForSearchResultLayout:ACCOUNT apiVersion:kSFRestDefaultAPIVersion];
    [self sendSyncRequest:request];
    NSString *userAgent = request.request.allHTTPHeaderFields[@"User-Agent"];
    XCTAssertEqualObjects(userAgent, [SFRestAPI userAgentString], @"Incorrect user agent");
}

// Tests that overridden user agent is set on the request.
- (void)testRequestUserAgentWithOverride {
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForSearchResultLayout:ACCOUNT apiVersion:kSFRestDefaultAPIVersion];
    [request setHeaderValue:[SFRestAPI userAgentString:@"MobileSync"] forHeaderName:@"User-Agent"];
    [self sendSyncRequest:request];
    NSString *userAgent = request.request.allHTTPHeaderFields[@"User-Agent"];
    XCTAssertEqualObjects(userAgent, [SFRestAPI userAgentString:@"MobileSync"], @"Incorrect user agent");
}

#pragma mark - custom rest requests

- (void)testCustomBaseURLRequest {
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodGET baseURL:@"http://www.apple.com" path:@"/test/testing" queryParams:nil];
    XCTAssertEqual(request.baseURL, @"http://www.apple.com", @"Base URL should match");
    NSURLRequest *finalRequest = [request prepareRequestForSend:_currentUser];
    NSString *expectedURL = [NSString stringWithFormat:@"http://www.apple.com%@%@", kSFDefaultRestEndpoint, @"/test/testing"];
    XCTAssertEqualObjects(finalRequest.URL.absoluteString, expectedURL, @"Final URL should utilize base URL that was passed in");
}

- (void)testCustomBaseURLRequestPOST {
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:@"https://www.apple.com/test/testing" queryParams:nil];
    [request setCustomRequestBodyData:[@"hello" dataUsingEncoding:NSUTF8StringEncoding] contentType:@"application/octet-stream"];
    NSURLRequest *finalRequest = [request prepareRequestForSend:_currentUser];
    XCTAssertEqualObjects(finalRequest.URL.absoluteString, @"https://www.apple.com/test/testing", @"Final URL should utilize base URL that was passed in");
    XCTAssertEqualObjects([finalRequest valueForHTTPHeaderField:@"Content-Type"], @"application/octet-stream");
    XCTAssertEqualObjects([finalRequest valueForHTTPHeaderField:@"Content-Length"], @"5");
    XCTAssertEqualObjects(finalRequest.HTTPMethod, @"POST");
    XCTAssertNotNil(finalRequest.HTTPBodyStream);
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

- (void)testRestUrlForNetworkServiceType {
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodGET baseURL:@"http://www.apple.com" path:@"/test/testing" queryParams:nil];
    
    request.networkServiceType = SFNetworkServiceTypeDefault;
    NSURLRequest *finalRequest = [request prepareRequestForSend:_currentUser];
    XCTAssertTrue(finalRequest.networkServiceType == NSURLNetworkServiceTypeDefault,  @"Network Service Type should have been set to NSURLNetworkServiceTypeDefault");
    
    request.networkServiceType = SFNetworkServiceTypeResponsiveData;
    finalRequest = [request prepareRequestForSend:_currentUser];
    
    XCTAssertTrue(finalRequest.networkServiceType == NSURLNetworkServiceTypeResponsiveData,  @"Network Service Type should have been set to NSURLNetworkServiceTypeResponsiveData");
   
    request.networkServiceType = SFNetworkServiceTypeBackground;
    finalRequest = [request prepareRequestForSend:_currentUser];
    XCTAssertTrue(finalRequest.networkServiceType == NSURLNetworkServiceTypeBackground,  @"Network Service Type should have been set to NSURLNetworkServiceTypeBackground");
}

#pragma mark Unauthenticated CLient tests

- (void)testRestApiGlobalInstance {
    
    SFRestAPI *sharedInstance  = [SFRestAPI sharedInstance];
    SFRestAPI *globalInstance = [SFRestAPI sharedGlobalInstance];
    XCTAssertNotNil(globalInstance, @"SFRestAPI should have a gloabl instance available");
    XCTAssertTrue(globalInstance != sharedInstance, @"SFRestAPI globalInstance and sharedInstance must be different");
}

- (void)testPublicApiCalls {
     XCTestExpectation *getExpectation = [self expectationWithDescription:@"Get"];
    __block NSError *error = nil;
    __block NSDictionary *response = nil;
    SFRestRequest *request = [SFRestRequest customUrlRequestWithMethod:SFRestMethodGET baseURL:@"https://api.github.com" path:@"/orgs/forcedotcom/repos" queryParams:nil];
    XCTAssertEqual(request.baseURL, @"https://api.github.com", @"Base URL should match");
    [[SFRestAPI sharedGlobalInstance] sendRequest:request failureBlock:^(id resp, NSError *e, NSURLResponse *rawResponse) {
        error = e;
        [getExpectation fulfill];
    } successBlock:^(id resp, NSURLResponse *rawResponse) {
        response = resp;
        [getExpectation fulfill];
    }];
    [self waitForExpectations:@[getExpectation] timeout:20];
    XCTAssertTrue(error == nil,@"RestApi call to a public api should not fail");
    XCTAssertFalse(response == nil,@"RestApi call to a public api should not have a nil response");
    XCTAssertTrue(response.count > 0 ,@"The response should have github/forcedotcom repos");
}

- (void)testCustomSalesforceEndpoint {
    NSString *endpoint = @"/custom/endpoint";
    NSString *path = @"/custom/endpoint";
    SFRestRequest *request =  [SFRestRequest customEndPointRequestWithMethod:SFRestMethodGET endPoint:endpoint path:path queryParams:nil];
    NSURLRequest *urlRequest = [request prepareRequestForSend:[SFUserAccountManager sharedInstance].currentUser];
    XCTAssertNotNil(urlRequest, @"UrlRequest URL should not be nil");
    NSRange range = [[[urlRequest URL] absoluteString] rangeOfString:endpoint];
    XCTAssertTrue(range.location!= NSNotFound && range.length > 0 , "The URL must have custom endpoint path");
    range = [[[urlRequest URL] absoluteString] rangeOfString:path];
    XCTAssertTrue(range.location!= NSNotFound && range.length > 0 , "The URL must have custom path");
}

/* NOTE: For backward compatibility purposes we allow for fullUrl in the Path component of SFRestRequest. This test should be removed once the handling of fullUrl in Path is removed.
 */
- (void)testSalesforceFullUrlPath {
    NSString *fullPathURL = @"https://some.custom.url/A/B/C";
    SFRestRequest *request =  [SFRestRequest requestWithMethod:SFRestMethodGET path:fullPathURL  queryParams:nil];
    NSURLRequest *urlRequest = [request prepareRequestForSend:[SFUserAccountManager sharedInstance].currentUser];
    XCTAssertNotNil(urlRequest, @"UrlRequest URL should not be nil");
    NSRange range = [[[urlRequest URL] absoluteString] rangeOfString:fullPathURL];
    XCTAssertTrue(range.location == 0 && range.length > 0 , "The URL must match the setting of full URL in path");
}

- (void)testNoTrailingQuestionMarkForEmptyParams {
    NSString *pathWithParams = @"/rest/endpoint?page=10";
    SFRestRequest * request = [SFRestRequest requestWithMethod:SFRestMethodGET path:pathWithParams queryParams:@{}];
    request.endpoint = @"/services/apex";
    NSURLRequest *urlRequest = [request prepareRequestForSend:[SFUserAccountManager sharedInstance].currentUser];
    XCTAssertTrue([urlRequest.URL.absoluteString hasSuffix:pathWithParams], @"Wrong URL");
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

- (void)testRedirect {
    // Create contact to fetch image for
    NSDictionary *fields = @{FIRST_NAME: @"John", LAST_NAME: [self generateRecordName]};
    SFRestRequest *contactRequest = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:CONTACT fields:fields apiVersion:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *contactListener = [self sendSyncRequest:contactRequest];
    NSString *contactId = ((NSDictionary *)contactListener.dataResponse)[LID];

    // Authenticated request for contact image, should automatically redirect
    NSString *path = [NSString stringWithFormat:@"/services/images/photo/%@", contactId];
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
    request.endpoint = @"";
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    NSInteger statusCode = [(NSHTTPURLResponse *)listener.rawResponse statusCode];
    XCTAssertEqual(statusCode, 200, @"Request did not return 200");
}

- (SFUserAccount *)createNewUser {
    SFOAuthCredentials *credentials = [TestSetupUtils newClientCredentials];
    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:credentials];
    [account transitionToLoginState:SFUserAccountLoginStateLoggedIn];
    NSString *userId = [self generateRandomId:18];
    NSString *orgId = [self generateRandomId:18];
    account.credentials.userId = userId;
    account.credentials.organizationId = orgId;
    
    credentials.instanceUrl = [SFUserAccountManager sharedInstance].currentUser.credentials.instanceUrl;
    NSError *error = nil;
    BOOL result = [[SFUserAccountManager sharedInstance] saveAccountForUser:account error:&error];
    return result?account:nil;
}

- (BOOL)deleteUser:(SFUserAccount *)user {
    NSError *error = nil;
    [SFRestAPI removeSharedInstanceWithUser:user];
    BOOL result = [[SFUserAccountManager sharedInstance] deleteAccountForUser:user error:&error];
    return result;
}

- (NSString *) generateRandomId:(NSInteger)len {
    NSString *alphabet  = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXZY0123456789";
    NSMutableString *s = [NSMutableString stringWithCapacity:20];
    for (NSUInteger i = 0U; i < len; i++) {
        u_int32_t r = arc4random() % [alphabet length];
        unichar c = [alphabet characterAtIndex:r];
        [s appendFormat:@"%C", c];
    }
    return s;
}

#pragma mark - Notification tests

- (void)testNotificationsStatus {
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForNotificationsStatus:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

- (void)testGetNotifications {
    SFSDKFetchNotificationsRequestBuilder *builder = [SFSDKFetchNotificationsRequestBuilder new];
    NSDate *yesterdayDate = [[NSDate date] dateByAddingTimeInterval:-1*60*60*24];
    [builder setAfter:yesterdayDate];
    [builder setSize:10];
    SFRestRequest* request = [builder buildFetchNotificationsRequest:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

- (void)testUpdateReadNotifications {
    SFSDKUpdateNotificationsRequestBuilder *builder = [SFSDKUpdateNotificationsRequestBuilder new];
    [builder setBefore:[NSDate date]];
    [builder setRead:NO];
    SFRestRequest* request = [builder buildUpdateNotificationsRequest:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

- (void)testUpdateSeenNotifications {
    SFSDKUpdateNotificationsRequestBuilder *builder = [SFSDKUpdateNotificationsRequestBuilder new];
    [builder setBefore:[NSDate date]];
    [builder setSeen:YES];
    SFRestRequest* request = [builder buildUpdateNotificationsRequest:kSFRestDefaultAPIVersion];
    SFNativeRestRequestListener *listener = [self sendSyncRequest:request];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

- (void)testGetNotificationRequestPath {
    NSString *notificationId = @"testID";
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForNotification:notificationId apiVersion:kSFRestDefaultAPIVersion];
    NSString *expectedPath = [NSString stringWithFormat:@"/connect/notifications/%@", notificationId];
    XCTAssert([request.path hasSuffix:expectedPath]);
}

- (void)testUpdateNotificationRequestPath {
    SFSDKUpdateNotificationsRequestBuilder *builder = [SFSDKUpdateNotificationsRequestBuilder new];
    NSString *notificationId = @"testID";
    [builder setNotificationId:notificationId];
    SFRestRequest *request = [builder buildUpdateNotificationsRequest:kSFRestDefaultAPIVersion];
    NSString *expectedPath = [NSString stringWithFormat:@"/connect/notifications/%@", notificationId];
    XCTAssert([request.path hasSuffix:expectedPath]);
}

- (void)testUpdateNotificationsRequestContent {
    SFSDKUpdateNotificationsRequestBuilder *builder = [SFSDKUpdateNotificationsRequestBuilder new];
    NSArray *notificationIds = @[@"testID1", @"testID2"];
    [builder setNotificationIds:notificationIds];
    SFRestRequest *request = [builder buildUpdateNotificationsRequest:kSFRestDefaultAPIVersion];
    XCTAssert([request.path hasSuffix:@"/connect/notifications"]);
    NSDictionary *requestBody = request.requestBodyAsDictionary;
    NSString *requestNotificationIds = requestBody[@"notificationIds"];
    XCTAssertEqualObjects(notificationIds, requestNotificationIds);
}

@end
