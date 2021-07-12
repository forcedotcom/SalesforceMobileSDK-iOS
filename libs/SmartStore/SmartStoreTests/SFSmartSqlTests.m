/*
  Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSmartSqlTests.h"
#import "SFSmartSqlHelper.h"
#import "SFSmartSqlCache.h"
#import "SFSmartStore+Internal.h"
#import "SFSoupIndex.h"
#import "SFQuerySpec.h"
#import <SalesforceSDKCommon/SFJsonUtils.h>

@interface SFOAuthCredentials ()
@property (nonatomic, readwrite, nullable) NSURL *identityUrl;

@end
@interface SFSmartSqlTests ()

@property (nonatomic, strong) SFSmartStore *store;

@end

@interface SFUserAccountManager()
- (void)setCurrentUserInternal:(SFUserAccount *)userAccount;
@end

@implementation SFSmartSqlTests

#pragma mark - setup and teardown

- (void) setUp
{
    [super setUp];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal: [self createUserAccount]];
    self.store = [SFSmartStore sharedStoreWithName:kTestStore user:[SFUserAccountManager sharedInstance].currentUser];
    
    // Employees soup
    [self.store registerSoup:kEmployeesSoup                               // should be TABLE_1
              withIndexSpecs:[SFSoupIndex asArraySoupIndexes:
                              @[[self createStringIndexSpec:kFirstName],   // should be TABLE_1_0
                                [self createStringIndexSpec:kLastName],    // should be TABLE_1_1
                                [self createStringIndexSpec:kDeptCode],    // should be TABLE_1_2
                                [self createStringIndexSpec:kEmployeeId],  // should be TABLE_1_3
                                [self createStringIndexSpec:kManagerId],   // should be TABLE_1_4
                                [self createFloatingIndexSpec:kSalary],    // should be TABLE_1_5
                                [self createJSON1IndexSpec:kEducation],    // should be json_extract(soup, '$.education')
                                [self createJSON1IndexSpec:kIsManager]     // should be json_extract(soup, '$.isManager')
                                ]]
                       error:nil];

    // Departments soup
    [self.store registerSoup:kDepartmentsSoup                              // should be TABLE_2
              withIndexSpecs:[SFSoupIndex asArraySoupIndexes:
                              @[[self createStringIndexSpec:kDeptCode],    // should be TABLE_2_0
                                [self createStringIndexSpec:kName],        // should be TABLE_2_1
                                [self createIntegerIndexSpec:kBudget],     // should be TABLE_2_2
                                [self createJSON1IndexSpec:kBuilding]      // should be json_extract(soup, '$.building')
                                ]]
                       error:nil];
}

- (void) tearDown
{
    [SFSmartStore removeSharedStoreWithName:kTestStore forUser:[SFUserAccountManager sharedInstance].currentUser];
    self.store = nil;
    [super tearDown];
}

- (SFUserAccount *)createUserAccount
{
    u_int32_t userIdentifier = arc4random();
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:[NSString stringWithFormat:@"identifier-%u", userIdentifier] clientId:[SFUserAccountManager sharedInstance].oauthClientId encrypted:YES];
    SFUserAccount *user =[[SFUserAccount alloc] initWithCredentials:credentials];
    NSString *userId = [NSString stringWithFormat:@"user_%u", userIdentifier];
    NSString *orgId = [NSString stringWithFormat:@"org_%u", userIdentifier];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://test.salesforce.com/id/%@/%@", orgId, userId]];
    [user transitionToLoginState:SFUserAccountLoginStateLoggedIn];
    NSError *error = nil;
    [user transitionToLoginState:SFUserAccountLoginStateLoggedIn];
    [[SFUserAccountManager sharedInstance] saveAccountForUser:user error:&error];
    XCTAssertNil(error);
   
    return user;
}


#pragma mark - tests
// All code under test must be linked into the Unit Test bundle

- (void) testSharedInstance
{
    SFSmartSqlHelper* instance1 = [SFSmartSqlHelper sharedInstance];
    SFSmartSqlHelper* instance2 = [SFSmartSqlHelper sharedInstance];
    XCTAssertEqualObjects(instance1, instance2, @"There should be only one instance");
}

- (void) testConvertSmartSqlWithInsertUpdateDelete
{
    XCTAssertNil([self.store convertSmartSql:@"insert into {employees}"], @"Should have returned nil for a insert query");
    XCTAssertNil([self.store convertSmartSql:@"update {employees}"], @"Should have returned nil for a update query");
    XCTAssertNil([self.store convertSmartSql:@"delete from {employees}"], @"Should have returned nil for a delete query");
    XCTAssertNotNil([self.store convertSmartSql:@"select * from {employees}"], @"Should not have returned nil for a proper query");
}

- (void) testSimpleConvertSmartSql
{
    XCTAssertEqualObjects(@"select TABLE_1_0, TABLE_1_1 from TABLE_1 order by TABLE_1_1",
                         [self.store convertSmartSql:@"select {employees:firstName}, {employees:lastName} from {employees} order by {employees:lastName}"],
                         @"Bad conversion");

    XCTAssertEqualObjects(@"select TABLE_2_1 from TABLE_2 order by TABLE_2_0",
                         [self.store convertSmartSql:@"select {departments:name} from {departments} order by {departments:deptCode}"],
                         @"Bad conversion");
}


- (void) testConvertSmartSqlWithJoin
{
    XCTAssertEqualObjects(@"select TABLE_2_1, TABLE_1_0 || ' ' || TABLE_1_1 "
                         "from TABLE_1, TABLE_2 "
                         "where TABLE_2_0 = TABLE_1_2 "
                         "order by TABLE_2_1, TABLE_1_1",
                         [self.store convertSmartSql:@"select {departments:name}, {employees:firstName} || ' ' || {employees:lastName} "
                                 "from {employees}, {departments} "
                             "where {departments:deptCode} = {employees:deptCode} "
                                 "order by {departments:name}, {employees:lastName}"],
                         @"Bad conversion");
}

- (void) testConvertSmartSqlWithSelfJoin
{
    XCTAssertEqualObjects(@"select mgr.TABLE_1_1, e.TABLE_1_1 "
                         "from TABLE_1 as mgr, TABLE_1 as e "
                         "where mgr.TABLE_1_3 = e.TABLE_1_4",
                         [self.store convertSmartSql:@"select mgr.{employees:lastName}, e.{employees:lastName} "
                                 "from {employees} as mgr, {employees} as e "
                           "where mgr.{employees:employeeId} = e.{employees:managerId}"],
                         @"Bad conversion");
}

- (void) testConvertSmartSqlWithSelfJoinAndJsonExtractedField {
    XCTAssertEqualObjects(@"select json_extract(mgr.soup, '$.education'), json_extract(e.soup, '$.education') "
                          "from TABLE_1 as mgr, TABLE_1 as e "
                          "where json_extract(mgr.soup, '$.education') = json_extract(e.soup, '$.education')",
                          [self.store convertSmartSql:@"select mgr.{employees:education}, e.{employees:education} "
                           "from {employees} as mgr, {employees} as e "
                           "where mgr.{employees:education} = e.{employees:education}"], @"Bad conversion");
}

- (void) testConvertSmartSqlWithSelfJoinAndJsonExtractedFieldNoLeadingSpaces {
    XCTAssertEqualObjects(@"select json_extract(mgr.soup, '$.education'),json_extract(e.soup, '$.education') "
                          "from TABLE_1 as mgr, TABLE_1 as e "
                          "where not (json_extract(mgr.soup, '$.education')=json_extract(e.soup, '$.education'))",
                          [self.store convertSmartSql:@"select mgr.{employees:education},e.{employees:education} "
                           "from {employees} as mgr, {employees} as e "
                           "where not (mgr.{employees:education}=e.{employees:education})"], @"Bad conversion");
}

- (void) testConvertSmartSqlWithSpecialColumns
{
    XCTAssertEqualObjects(@"select TABLE_1.id, TABLE_1.created, TABLE_1.lastModified, TABLE_1.soup from TABLE_1",
                         [self.store convertSmartSql:@"select {employees:_soupEntryId}, {employees:_soupCreatedDate}, {employees:_soupLastModifiedDate}, {employees:_soup} from {employees}"], @"Bad conversion");
}
	
- (void) testConvertSmartSqlWithSpecialColumnsAndJoin
{
    XCTAssertEqualObjects(@"select TABLE_1.id, TABLE_2.id from TABLE_1, TABLE_2", 
                         [self.store convertSmartSql:@"select {employees:_soupEntryId}, {departments:_soupEntryId} from {employees}, {departments}"], @"Bad conversion");
}

- (void) testConvertSmartSqlWithSpecialColumnsAndSelfJoin
{
    XCTAssertEqualObjects(@"select mgr.id, e.id from TABLE_1 as mgr, TABLE_1 as e", 
                         [self.store convertSmartSql:@"select mgr.{employees:_soupEntryId}, e.{employees:_soupEntryId} from {employees} as mgr, {employees} as e"], @"Bad conversion");
}

- (void) testConvertSmartSqlWithJSON1
{
    if ([[self.store attributesForSoup:kEmployeesSoup].features containsObject:kSoupFeatureExternalStorage]) {
        [SFSDKSmartStoreLogger i:[self class] format:@"Test Skipped for soup with external storage feature."];
        return;
    }
    XCTAssertEqualObjects(@"select TABLE_1_1, json_extract(soup, '$.education') from TABLE_1 where json_extract(soup, '$.education') = 'MIT'",
                          [self.store convertSmartSql:@"select {employees:lastName}, {employees:education} from {employees} where {employees:education} = 'MIT'"], @"Bad conversion");
}

- (void) testConvertSmartSqlWithJSON1AndTableQualifiedColumn
{
    if ([[self.store attributesForSoup:kEmployeesSoup].features containsObject:kSoupFeatureExternalStorage]) {
        [SFSDKSmartStoreLogger i:[self class] format:@"Test Skipped for soup with external storage feature."];
        return;
    }
    XCTAssertEqualObjects(@"select json_extract(TABLE_1.soup, '$.education') from TABLE_1 order by json_extract(TABLE_1.soup, '$.education')",
                          [self.store convertSmartSql:@"select {employees}.{employees:education} from {employees} order by {employees}.{employees:education}"], @"Bad conversion");
}

- (void) testConvertSmartSqlWithJSON1AndTableAliases
{
    if ([[self.store attributesForSoup:kEmployeesSoup].features containsObject:kSoupFeatureExternalStorage]) {
        [SFSDKSmartStoreLogger i:[self class] format:@"Test Skipped for soup with external storage feature."];
        return;
    }
    XCTAssertEqualObjects(@"select json_extract(e.soup, '$.education'), json_extract(soup, '$.building') from TABLE_1 as e, TABLE_2",
                          [self.store convertSmartSql:@"select e.{employees:education}, {departments:building} from {employees} as e, {departments}"], @"Bad conversion");
    
    // XXX join query with json1 will only run if all the json1 columns are qualified by table or alias
}

- (void) testConvertSmartSqlForNonIndexedColumns {
    XCTAssertEqualObjects(@"select json_extract(soup, '$.education'), json_extract(soup, '$.address.zipcode') from TABLE_1 where json_extract(soup, '$.address.city') = 'San Francisco'", [self.store convertSmartSql:@"select {employees:education}, {employees:address.zipcode} from {employees} where {employees:address.city} = 'San Francisco'"], @"Bad conversion");
}

- (void) testConvertSmartSqlWithQuotedCurlyBraces {
    XCTAssertEqualObjects(@"select json_extract(soup, '$.education') from TABLE_1 where json_extract(soup, '$.education') like 'Account(where: {Name: {eq: \"Jason\"}})'",
                        [self.store convertSmartSql:@"select {employees:education} from {employees} where {employees:education} like 'Account(where: {Name: {eq: \"Jason\"}})'"]);
}

- (void) testConvertSmartSqlWithMultipleQuotedCurlyBraces {
    XCTAssertEqualObjects(@"select json_extract(soup, '$.education'), '{a:b}', TABLE_1_0 from TABLE_1 where json_extract(soup, '$.address') = '{\"city\": \"San Francisco\"}' or TABLE_1_1 like 'B%'",
                          [self.store convertSmartSql:@"select {employees:education}, '{a:b}', {employees:firstName} from {employees} where {employees:address} = '{\"city\": \"San Francisco\"}' or {employees:lastName} like 'B%'"]);
}

- (void) testConvertSmartSqlWithQuotedUnbalancedCurlyBrace {
    XCTAssertEqualObjects(@"select json_extract(soup, '$.education') from TABLE_1 where json_extract(soup, '$.education') like ' { { { } } '",
                          [self.store convertSmartSql:@"select {employees:education} from {employees} where {employees:education} like ' { { { } } '"]);
}


- (void) testSmartQueryDoingCount 
{
    [self loadData];
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select count(*) from {employees}" withPageSize:1];
    NSArray* result = [self.store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[7]]"] actual:result message:@"Wrong result"];
}
	
- (void) testSmartQueryDoingSum 
{
    [self loadData];
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select sum({departments:budget}) from {departments}" withPageSize:1];
    NSArray* result = [self.store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[3000000]]"] actual:result message:@"Wrong result"];
}

- (void) testSmartQueryReturningOneRowWithOneInteger 
{
    [self loadData];
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:salary} from {employees} where {employees:lastName} = 'Haas'" withPageSize:1];
    NSArray* result = [self.store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[200000.10]]"] actual:result message:@"Wrong result"];
}
	
- (void) testSmartQueryReturningOneRowWithTwoIntegers 
{
    [self loadData];
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select mgr.{employees:salary}, e.{employees:salary} from {employees} as mgr, {employees} as e where mgr.{employees:employeeId} = e.{employees:managerId} and e.{employees:lastName} = 'Thompson'" withPageSize:1];
    NSArray* result = [self.store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[200000.10,120000.10]]"] actual:result message:@"Wrong result"];
}

- (void) testSmartQueryReturningTwoRowsWithOneIntegerEach 
{
    [self loadData];
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:salary} from {employees} where {employees:managerId} = '00010' order by {employees:firstName}" withPageSize:2];
    NSArray* result = [self.store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[120000.10],[100000.10]]"] actual:result message:@"Wrong result"];
}

- (void) testSmartQueryReturningSoupStringAndInteger 
{
    [self loadData];
    SFQuerySpec* exactQuerySpec = [SFQuerySpec newExactQuerySpec:kEmployeesSoup withPath:@"employeeId" withMatchKey:@"00010" withOrderPath:@"employeeId" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    NSDictionary* christineJson = [self.store queryWithQuerySpec:exactQuerySpec pageIndex:0  error:nil][0];
    XCTAssertEqualObjects(@"Christine", christineJson[kFirstName], @"Wrong elt");
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:_soup}, {employees:firstName}, {employees:salary} from {employees} where {employees:lastName} = 'Haas'" withPageSize:1];
    NSArray* result = [self.store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
    XCTAssertTrue(1 == [result count], @"Expected one row");
    [self assertSameJSONWithExpected:christineJson actual:result[0][0] message:@"Wrong soup"];
    XCTAssertEqualObjects(@"Christine", result[0][1], @"Wrong first name");
    NSNumber* dubNum = result[0][2];
    XCTAssertEqual(200000.10, [dubNum doubleValue], @"Wrong salary");
}
	
- (void) testSmartQueryWithPaging 
{
    [self loadData];
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:firstName} from {employees} order by {employees:firstName}" withPageSize:1];
    XCTAssertTrue(7 ==[[self.store countWithQuerySpec:querySpec  error:nil] unsignedIntegerValue], @"Expected 7 employees");
    NSArray* expectedResults = @[@"Christine", @"Eileen", @"Eva", @"Irving", @"John", @"Michael", @"Sally"];
    for (int i=0; i<7; i++) {
        NSArray* result = [self.store queryWithQuerySpec:querySpec pageIndex:i  error:nil];
        NSArray* expectedResult = @[@[expectedResults[i]]];
        NSString* message = [NSString stringWithFormat:@"Wrong result at page %d", i];
        [self assertSameJSONArrayWithExpected:expectedResult actual:result message:message];
    }
}
    
- (void) testSmartQueryWithSpecialFields 
{
    [self loadData];
    SFQuerySpec* exactQuerySpec = [SFQuerySpec newExactQuerySpec:kEmployeesSoup withPath:@"employeeId" withMatchKey:@"00010" withOrderPath:@"employeeId" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    NSDictionary* christineJson = [self.store queryWithQuerySpec:exactQuerySpec pageIndex:0  error:nil][0];
    XCTAssertEqualObjects(@"Christine", christineJson[kFirstName], @"Wrong elt");
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:_soup}, {employees:_soupEntryId}, {employees:_soupLastModifiedDate} from {employees} where {employees:lastName} = 'Haas'" withPageSize:1];
    NSArray* result = [self.store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
    XCTAssertTrue(1 == [result count], @"Expected one row");
    [self assertSameJSONWithExpected:christineJson actual:result[0][0] message:@"Wrong soup"];
    XCTAssertEqualObjects(christineJson[@"_soupEntryId"], result[0][1], @"Wrong soupEntryId");
    XCTAssertEqualObjects(christineJson[@"_soupLastModifiedDate"], result[0][2], @"Wrong soupLastModifiedDate");
}

- (void) testSmartQueryWithNullField
{
    NSDictionary* createdEmployee;
    
    // Employee with dept code
    createdEmployee = [self createEmployeeWithJsonString:@"{\"employeeId\":\"001\",\"deptCode\":\"xyz\"}"];
    XCTAssertEqualObjects(createdEmployee[@"deptCode"], @"xyz");
    
    // Employee with [NSNull null] dept code
    createdEmployee = [self createEmployeeWithJsonString:@"{\"employeeId\":\"002\",\"deptCode\":null}"];
    XCTAssertEqual(createdEmployee[@"deptCode"], [NSNull null]);
    
    // Employee with @"" dept code
    createdEmployee = [self createEmployeeWithJsonString:@"{\"employeeId\":\"003\",\"deptCode\":\"\"}"];
    XCTAssertEqualObjects(createdEmployee[@"deptCode"], @"");
    
    // Employee with no dept code
    createdEmployee = [self createEmployeeWithJsonString:@"{\"employeeId\":\"004\"}"];
    XCTAssertEqual(createdEmployee[@"deptCode"], nil);
    
    // Smart sql with is not null
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:employeeId} from {employees} where {employees:deptCode} is not null order by {employees:employeeId}" withPageSize:4];
    NSArray* result = [self.store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[\"001\"],[\"003\"]]"] actual:result message:@"Wrong result"];

    // Smart sql with is null
    querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:employeeId} from {employees} where {employees:deptCode} is null order by {employees:employeeId}" withPageSize:4];
    result = [self.store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[\"002\"],[\"004\"]]"] actual:result message:@"Wrong result"];
    
    // Smart sql looking for empty string
    querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:employeeId} from {employees} where {employees:deptCode} = \"\" order by {employees:employeeId}" withPageSize:4];
    result = [self.store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[\"003\"]]"] actual:result message:@"Wrong result"];
    
    // Smart sql returning null values
    querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:employeeId},{employees:deptCode},{employees:deptCode} from {employees} order by {employees:employeeId}" withPageSize:4];
    result = [self.store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[\"001\",\"xyz\",\"xyz\"],[\"002\",null,null],[\"003\",\"\",\"\"],[\"004\",null,null]]"] actual:result message:@"Wrong result"];
}

- (void) testSmartQueryMachingBooleanInJSON1Field
{
    NSDictionary* createdEmployee;
    
    // Storing booleans in a json1 field
    // NB: SQLite does not have a separate Boolean storage class. Instead, Boolean values are stored as integers 0 (false) and 1 (true).

    [self loadData];
    
    // Creating another employee from a json string with isManager true
    createdEmployee = [self createEmployeeWithJsonString:@"{\"employeeId\":\"101\",\"isManager\":true}"];
    XCTAssertEqual(createdEmployee[kIsManager], @YES);

    // Creating another employee from a json string with isManager false
    createdEmployee = [self createEmployeeWithJsonString:@"{\"employeeId\":\"102\",\"isManager\":false}"];
    XCTAssertEqual(createdEmployee[kIsManager], @NO);
    
    // Smart sql looking for isManager true
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:employeeId} from {employees} where {employees:isManager} = 1 order by {employees:employeeId}" withPageSize:10];
    NSArray* result = [self.store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[\"00010\"],[\"00040\"],[\"00050\"],[\"101\"]]"] actual:result message:@"Wrong result"];
    // Smart sql looking for isManager = false
    querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:employeeId} from {employees} where {employees:isManager} = 0 order by {employees:employeeId}" withPageSize:10];
    result = [self.store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[\"00020\"],[\"00060\"],[\"00070\"],[\"00310\"],[\"102\"]]"] actual:result message:@"Wrong result"];
}

- (void)testSmartQueryFilteringByNonIndexedField {
    [self createEmployeeWithJsonString:@"{\"employeeId\":\"101\",\"address\":{\"city\":\"San Francisco\", \"zipcode\":94105}}"];
    [self createEmployeeWithJsonString:@"{\"employeeId\":\"102\",\"address\":{\"city\":\"New York City\", \"zipcode\":10004}}"];
    [self createEmployeeWithJsonString:@"{\"employeeId\":\"103\",\"address\":{\"city\":\"San Francisco\", \"zipcode\":94106}}"];
    [self createEmployeeWithJsonString:@"{\"employeeId\":\"104\",\"address\":{\"city\":\"New York City\", \"zipcode\":10006}}"];

    SFQuerySpec *querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:employeeId} from {employees} where {employees:address.city} = 'San Francisco' order by {employees:employeeId}" withPageSize:10];
    NSArray *result = [self.store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[\"101\"],[\"103\"]]"] actual:result message:@"Wrong result"];
}

- (void)testSmartQueryReturningNonIndexedField {
    [self createEmployeeWithJsonString:@"{\"employeeId\":\"101\",\"address\":{\"city\":\"San Francisco\", \"zipcode\":94105}}"];
    [self createEmployeeWithJsonString:@"{\"employeeId\":\"102\",\"address\":{\"city\":\"New York City\", \"zipcode\":10004}}"];
    [self createEmployeeWithJsonString:@"{\"employeeId\":\"103\",\"address\":{\"city\":\"San Francisco\", \"zipcode\":94106}}"];
    [self createEmployeeWithJsonString:@"{\"employeeId\":\"104\",\"address\":{\"city\":\"New York City\", \"zipcode\":10006}}"];
    
    SFQuerySpec *querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:employeeId}, {employees:address.zipcode} from {employees} where {employees:address.city} = 'San Francisco' order by {employees:employeeId}" withPageSize:10];
    NSArray *result = [self.store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[\"101\", 94105],[\"103\", 94106]]"] actual:result message:@"Wrong result"];
}

// Making sure the "cleanup" regexp is a lot faster than the old cleanup regexp
// Testing a real-world query with 25k characters
- (void) testCleanupRegexpFaster {
    NSString* oldRegexp = @"([^ ]+)\\.json_extract\\(soup";
    NSString* newRegexp = @"(\\w+)\\.json_extract\\(soup";

    // At least 500 times faster than the old regexp
    XCTAssertTrue([self timeRegexpInMs:newRegexp] * 500 < [self timeRegexpInMs:oldRegexp]);
    // No more than 25ms
    XCTAssertTrue([self timeRegexpInMs:newRegexp] <  25);
}

#pragma mark - helper methods
-(double) timeRegexpInMs:(NSString*)pattern {
    NSString* q = @"SELECT {DEFAULT:LdsSoupKey}, {DEFAULT:LdsSoupValue}\nFROM {DEFAULT}\nWHERE {DEFAULT:LdsSoupKey}\nIN (\'UiApi::BatchRepresentation(childRelationships:undefined,fields:undefined,layoutTypes:undefined,modes:undefined,optionalFields:Account.AccountSource,Account.AnnualRevenue,Account.BillingAddress,Account.BillingCity,Account.BillingCountry,Account.BillingGeocodeAccuracy,Account.BillingLatitude,Account.BillingLongitude,Account.BillingPostalCode,Account.BillingState,Account.BillingStreet,Account.ChannelProgramLevelName,Account.ChannelProgramName,Account.CreatedById,Account.CreatedDate,Account.Description,Account.Fax,Account.Id,Account.Industry,Account.IsCustomerPortal,Account.IsDeleted,Account.IsLocked,Account.IsPartner,Account.Jigsaw,Account.JigsawCompanyId,Account.LastActivityDate,Account.LastModifiedById,Account.LastModifiedDate,Account.LastReferencedDate,Account.LastViewedDate,Account.MasterRecordId,Account.MayEdit,Account.Name,Account.NumberOfEmployees,Account.OperatingHoursId,Account.OwnerId,Account.ParentId,Account.Phone,Account.PhotoUrl,Account.ShippingAddress,Account.ShippingCity,Account.ShippingCountry,Account.ShippingGeocodeAccuracy,Account.ShippingLatitude,Account.ShippingLongitude,Account.ShippingPostalCode,Account.ShippingState,Account.ShippingStreet,Account.SicDesc,Account.SystemModstamp,Account.Type,Account.Website,Asset.AccountId,Asset.AssetProvidedById,Asset.AssetServicedById,Asset.ContactId,Asset.CreatedById,Asset.CreatedDate,Asset.Description,Asset.Id,Asset.InstallDate,Asset.IsCompetitorProduct,Asset.IsDeleted,Asset.IsLocked,Asset.LastModifiedById,Asset.LastModifiedDate,Asset.LastReferencedDate,Asset.LastViewedDate,Asset.MayEdit,Asset.Name,Asset.OwnerId,Asset.ParentId,Asset.Price,Asset.Product2Id,Asset.ProductCode,Asset.PurchaseDate,Asset.Quantity,Asset.RootAssetId,Asset.SerialNumber,Asset.Status,Asset.StockKeepingUnit,Asset.SystemModstamp,Asset.UsageEndDate,Location.CloseDate,Location.ConstructionEndDate,Location.ConstructionStartDate,Location.CreatedById,Location.CreatedDate,Location.Description,Location.DrivingDirections,Location.ExternalReference,Location.Id,Location.IsDeleted,Location.IsInventoryLocation,Location.IsLocked,Location.IsMobile,Location.LastModifiedById,Location.LastModifiedDate,Location.LastReferencedDate,Location.LastViewedDate,Location.Latitude,Location.Location,Location.LocationLevel,Location.LocationType,Location.LogoId,Location.Longitude,Location.MayEdit,Location.Name,Location.OpenDate,Location.OwnerId,Location.ParentLocationId,Location.PossessionDate,Location.RemodelEndDate,Location.RemodelStartDate,Location.RootLocationId,Location.SystemModstamp,Location.TimeZone,ServiceAppointment.AccountId,ServiceAppointment.ActualDuration,ServiceAppointment.ActualEndTime,ServiceAppointment.ActualStartTime,ServiceAppointment.Address,ServiceAppointment.AppointmentNumber,ServiceAppointment.ArrivalWindowEndTime,ServiceAppointment.ArrivalWindowStartTime,ServiceAppointment.City,ServiceAppointment.ContactId,ServiceAppointment.Country,ServiceAppointment.CreatedById,ServiceAppointment.CreatedDate,ServiceAppointment.Description,ServiceAppointment.DueDate,ServiceAppointment.Duration,ServiceAppointment.DurationInMinutes,ServiceAppointment.DurationType,ServiceAppointment.EarliestStartTime,ServiceAppointment.FSL__Appointment_Grade__c,ServiceAppointment.FSL__Auto_Schedule__c,ServiceAppointment.FSL__Emergency__c,ServiceAppointment.FSL__GanttColor__c,ServiceAppointment.FSL__GanttLabel__c,ServiceAppointment.FSL__InJeopardyReason__c,ServiceAppointment.FSL__InJeopardy__c,ServiceAppointment.FSL__InternalSLRGeolocation__Latitude__s,ServiceAppointment.FSL__InternalSLRGeolocation__Longitude__s,ServiceAppointment.FSL__InternalSLRGeolocation__c,ServiceAppointment.FSL__IsFillInCandidate__c,ServiceAppointment.FSL__IsMultiDay__c,ServiceAppointment.FSL__MDS_Calculated_length__c,ServiceAppointment.FSL__MDT_Operational_Time__c,ServiceAppointment.FSL__Pinned__c,ServiceAppointment.FSL__Prevent_Geocoding_For_Chatter_Actions__c,ServiceAppointment.FSL__Related_Service__c,ServiceAppointment.FSL__Same_Day__c,ServiceAppointment.FSL__Same_Resource__c,ServiceAppointment.FSL__Schedule_Mode__c,ServiceAppointment.FSL__Schedule_over_lower_priority_appointment__c,ServiceAppointment.FSL__Time_Dependency__c,ServiceAppointment.FSL__UpdatedByOptimization__c,ServiceAppointment.FSL__Virtual_Service_For_Chatter_Action__c,ServiceAppointment.GeocodeAccuracy,ServiceAppointment.Id,ServiceAppointment.Incomplete_Status_Count__c,ServiceAppointment.IsDeleted,ServiceAppointment.IsLocked,ServiceAppointment.LastModifiedById,ServiceAppointment.LastModifiedDate,ServiceAppointment.LastReferencedDate,ServiceAppointment.LastViewedDate,ServiceAppointment.Latitude,ServiceAppointment.Longitude,ServiceAppointment.MayEdit,ServiceAppointment.OwnerId,ServiceAppointment.ParentRecordId,ServiceAppointment.ParentRecordStatusCategory,ServiceAppointment.ParentRecordType,ServiceAppointment.PostalCode,ServiceAppointment.ProductId__c,ServiceAppointment.ResourceAbsenceId__c,ServiceAppointment.SACount__c,ServiceAppointment.SchedEndTime,ServiceAppointment.SchedStartTime,ServiceAppointment.ServiceResourceId__c,ServiceAppointment.ServiceTerritoryId,ServiceAppointment.State,ServiceAppointment.Status,ServiceAppointment.Street,ServiceAppointment.Subject,ServiceAppointment.SystemModstamp,ServiceAppointment.TimeSheetEntryId__c,ServiceAppointment.TimeSheetId__c,WorkOrder.AccountId,WorkOrder.Address,WorkOrder.AssetId,WorkOrder.AssetWarrantyId,WorkOrder.BusinessHoursId,WorkOrder.CaseId,WorkOrder.City,WorkOrder.ContactId,WorkOrder.Country,WorkOrder.CreatedById,WorkOrder.CreatedDate,WorkOrder.Description,WorkOrder.Discount,WorkOrder.DurationInMinutes,WorkOrder.DurationSource,WorkOrder.EndDate,WorkOrder.EntitlementId,WorkOrder.External_Id__c,WorkOrder.FSL__IsFillInCandidate__c,WorkOrder.FSL__Prevent_Geocoding_For_Chatter_Actions__c,WorkOrder.FSL__Scheduling_Priority__c,WorkOrder.FSL__VisitingHours__c,WorkOrder.GeocodeAccuracy,WorkOrder.GrandTotal,WorkOrder.Id,WorkOrder.IsClosed,WorkOrder.IsDeleted,WorkOrder.IsGeneratedFromMaintenancePlan,WorkOrder.IsLocked,WorkOrder.IsStopped,WorkOrder.LastModifiedById,WorkOrder.LastModifiedDate,WorkOrder.LastReferencedDate,WorkOrder.LastViewedDate,WorkOrder.Latitude,WorkOrder.LineItemCount,WorkOrder.LocationId,WorkOrder.Longitude,WorkOrder.MaintenancePlanId,WorkOrder.MaintenanceWorkRuleId,WorkOrder.MayEdit,WorkOrder.MilestoneStatus,WorkOrder.OwnerId,WorkOrder.ParentWorkOrderId,WorkOrder.PostalCode,WorkOrder.Pricebook2Id,WorkOrder.Priority,WorkOrder.ProductRequiredId__c,WorkOrder.ProductServiceCampaignId,WorkOrder.ProductServiceCampaignItemId,WorkOrder.RecordTypeId,WorkOrder.RootWorkOrderId,WorkOrder.ServiceContractId,WorkOrder.ServiceCrewId__c,WorkOrder.ServiceCrewMemberId__c,WorkOrder.ServiceReportLanguage,WorkOrder.ServiceReportTemplateId,WorkOrder.ServiceTerritoryId,WorkOrder.SlaExitDate,WorkOrder.SlaStartDate,WorkOrder.StartDate,WorkOrder.State,WorkOrder.Status,WorkOrder.StopStartDate,WorkOrder.Street,WorkOrder.Subject,WorkOrder.Subtotal,WorkOrder.SuggestedMaintenanceDate,WorkOrder.SystemModstamp,WorkOrder.Tax,WorkOrder.TimeSlotId__c,WorkOrder.TotalPrice,WorkOrder.WorkOrderNumber,WorkOrder.WorkTypeId,WorkOrder.Work_Order_Count__c,pageSize:undefined,updateMru:undefined,recordIds:02ix000000CG4h1AAD,02ix000000CG4kKAAT,02ix000000CG6gKAAT,02ix000000CG4rPAAT,02ix000000CG5uRAAT,02ix000000CG3oNAAT,02ix000000CG5yyAAD,02ix000000CG4PoAAL,02ix000000CG6VRAA1,02ix000000CG4KxAAL,02ix000000CG5FbAAL,02ix000000CG5bPAAT,02ix000000CG4q8AAD,02ix000000CG61vAAD,02ix000000CG5mRAAT,02ix000000CG6BdAAL,02ix000000CG6UpAAL,02ix00000006zCzAAI,02ix000000CG6e1AAD,02ix000000CG5MqAAL,02ix000000CG6ZIAA1,02ix000000CG6OgAAL,02ix000000CG5HQAA1,02ix000000CG4ihAAD,02ix000000CG4zKAAT,02ix000000CG4VaAAL,02ix000000CG56UAAT,02ix000000CG6IvAAL,02ix000000CG6ZJAA1,02ix000000CG6bQAAT,02ix000000CG62UAAT,02ix000000CG5iCAAT,02ix000000CG6NOAA1,02ix000000CG4jrAAD,02ix000000CG4C2AAL,02ix000000CG4t6AAD,02ix000000CG4c2AAD,02ix000000CG6MLAA1,02ix000000CG6IBAA1,02ix000000CG53UAAT,02ix000000CG5FAAA1,02ix000000CG5GvAAL,02ix000000CG5YmAAL,02ix000000CG5vcAAD,02ix000000CG4SFAA1,02ix000000CG5tFAAT,02ix000000CG6GfAAL,02ix000000CG5M3AAL,02ix000000CG5CMAA1,02ix000000CG4LsAAL,131x00000000khiAAA,131x00000000khSAAQ,131x00000000jMnAAI,131x00000000khYAAQ,131x00000000khNAAQ,131x00000000khXAAQ,131x00000000jMzAAI,131x00000000khMAAQ,131x00000000jMYAAY,131x00000000jMtAAI,131x00000000khcAAA,131x00000000jMeAAI,131x00000000khZAAQ,131x00000000khOAAQ,131x00000000jN0AAI,131x00000000khJAAQ,131x00000000kheAAA,131x00000000jMkAAI,131x00000000jMvAAI,131x00000000khIAAQ,131x00000000khdAAA,131x00000000khjAAA,131x00000000jMpAAI,131x00000000khTAAQ,131x00000000khDAAQ,131x00000000khlAAA,131x00000000khKAAQ,131x00000000khfAAA,131x00000000j75AAA,131x00000000khVAAQ,131x00000000khaAAA,131x00000000jMgAAI,131x00000000khkAAA,131x00000000khUAAQ,131x00000000jN2AAI,131x00000000jMlAAI,131x00000000khPAAQ,131x00000000jMmAAI,131x00000000khbAAA,131x00000000khhAAA,131x00000000jMWAAY,131x00000000khRAAQ,131x00000000jMrAAI,131x00000000jMbAAI,131x00000000khgAAA,131x00000000jMsAAI,131x00000000khQAAQ,131x00000000jMhAAI,131x00000000khWAAQ,131x00000000khLAAQ,001x0000004ckZXAAY,001x0000004ckZcAAI,001x0000004cka2AAA,001x0000004ckZnAAI,001x0000004ckZsAAI,001x0000004cka7AAA,001x0000004ckZhAAI,001x0000004ckZxAAI,001x0000004ckZRAAY,001x0000004cka8AAA,001x0000004ckZmAAI,001x0000004ckZbAAI,001x0000004ckZWAAY,001x0000004cka6AAA,001x0000004ckZzAAI,001x0000004ckZTAAY,001x0000004ckZYAAY,001x0000004ckZdAAI,001x0000004ckZoAAI,001x0000004ckZtAAI,001x0000004ckZiAAI,001x0000004ckZNAAY,001x0000004ckaAAAQ,001x0000004ckZyAAI,001x0000004ckZSAAY,001x0000004cka1AAA,001x0000004ckZvAAI,001x0000004ckZPAAY,001x0000004ckZkAAI,001x0000004ckZUAAY,001x0000004ckZeAAI,001x0000004ckZZAAY,001x0000004cka0AAA,001x0000004ckZpAAI,001x0000004cka5AAA,001x0000004ckZuAAI,001x0000004ckZOAAY,001x0000004ckZjAAI,001x0000004ckZrAAI,001x0000004ckZgAAI,001x0000004ckZwAAI,001x0000004ckZlAAI,001x0000004ckZQAAY,001x0000004cka3AAA,001x0000004ckZaAAI,001x0000004ckZVAAY,001x0000004cka4AAA,001x0000004cka9AAA,001x0000004ckZqAAI,001x0000004ckZfAAI,0WOx0000005kEBhGAM,0WOx0000005kEBXGA2,0WOx0000005kEAAGA2,0WOx0000005kEA6GAM,0WOx0000005kEAQGA2,0WOx0000005kEA0GAM,0WOx0000005kEBSGA2,0WOx0000005kEBcGAM,0WOx0000005kEAFGA2,0WOx0000005kEAGGA2,0WOx0000005kEA1GAM,0WOx0000005kEBRGA2,0WOx0000005kEBbGAM,0WOx0000005kEALGA2,0WOx0000005kEBTGA2,0WOx0000005kEBdGAM,0WOx0000005kEAMGA2,0WOx0000005kEARGA2,0WOx0000005kEA7GAM,0WOx0000005kEABGA2,0WOx0000005kE9zGAE,0WOx0000005kECjGAM,0WOx0000005kEASGA2,0WOx0000005kEA8GAM,0WOx0000005kEACGA2,0WOx0000005kE9yGAE,0WOx0000005kEAHGA2,0WOx0000005kEA2GAM,0WOx0000005kEBYGA2,0WOx0000005kEAIGA2,0WOx0000005kEA3GAM,0WOx0000005kEANGA2,0WOx0000005kEBZGA2,0WOx0000005kEAOGA2,0WOx0000005kEBUGA2,0WOx0000005kEA9GAM,0WOx0000005kE9xGAE,0WOx0000005kEADGA2,0WOx0000005kEBeGAM,0WOx0000005kEAEGA2,0WOx0000005kEBgGAM,0WOx0000005kEBWGA2,0WOx0000005kEA4GAM,0WOx0000005kEAJGA2,0WOx0000005kEBVGA2,0WOx0000005kEBfGAM,0WOx0000005kEAKGA2,0WOx0000005kEA5GAM,0WOx0000005kEAPGA2,0WOx0000005kEBaGAM,08px000000JaaADAAZ,08px000000JaaATAAZ,08px000000JaaAuAAJ,08px000000JaaA9AAJ,08px000000JaaAYAAZ,08px000000JaaAdAAJ,08px000000JaaAIAAZ,08px000000JaaAZAAZ,08px000000JaaAeAAJ,08px000000JaaAJAAZ,08px000000JaaAOAAZ,08px000000JaaAoAAJ,08px000000JaaAjAAJ,08px000000JaaAHAAZ,08px000000JaaAcAAJ,08px000000JaaAXAAZ,08px000000JaaA8AAJ,08px000000JaaAMAAZ,08px000000JaaAhAAJ,08px000000JaaAtAAJ,08px000000JaaANAAZ,08px000000JaaAiAAJ,08px000000JaaAsAAJ,08px000000JaaACAAZ,08px000000JaaAnAAJ,08px000000JaaASAAZ,08px000000JaaALAAZ,08px000000JaaAgAAJ,08px000000JaaAAAAZ,08px000000JaaAlAAJ,08px000000JaaAQAAZ,08px000000JaaABAAZ,08px000000JaaAmAAJ,08px000000JaaARAAZ,08px000000JaaAbAAJ,08px000000JaaAGAAZ,08px000000JaaAWAAZ,08px000000JaaArAAJ,08px000000JaaAPAAZ,08px000000JaaAkAAJ,08px000000JaaAqAAJ,08px000000JaaAEAAZ,08px000000JaaAUAAZ,08px000000JaaApAAJ,08px000000JaaAaAAJ,08px000000JaaAFAAZ,08px000000JaaAVAAZ,08px000000JaaAfAAJ,08px000000JaaAvAAJ,08px000000JaaAKAAZ)\',\'UiApi::RecordRepresentation:02ix000000CG4h1AAD\',\'UiApi::RecordRepresentation:02ix000000CG4kKAAT\',\'UiApi::RecordRepresentation:02ix000000CG6gKAAT\',\'UiApi::RecordRepresentation:02ix000000CG4rPAAT\',\'UiApi::RecordRepresentation:02ix000000CG5uRAAT\',\'UiApi::RecordRepresentation:02ix000000CG3oNAAT\',\'UiApi::RecordRepresentation:02ix000000CG5yyAAD\',\'UiApi::RecordRepresentation:02ix000000CG4PoAAL\',\'UiApi::RecordRepresentation:02ix000000CG6VRAA1\',\'UiApi::RecordRepresentation:02ix000000CG4KxAAL\',\'UiApi::RecordRepresentation:02ix000000CG5FbAAL\',\'UiApi::RecordRepresentation:02ix000000CG5bPAAT\',\'UiApi::RecordRepresentation:02ix000000CG4q8AAD\',\'UiApi::RecordRepresentation:02ix000000CG61vAAD\',\'UiApi::RecordRepresentation:02ix000000CG5mRAAT\',\'UiApi::RecordRepresentation:02ix000000CG6BdAAL\',\'UiApi::RecordRepresentation:02ix000000CG6UpAAL\',\'UiApi::RecordRepresentation:02ix00000006zCzAAI\',\'UiApi::RecordRepresentation:02ix000000CG6e1AAD\',\'UiApi::RecordRepresentation:02ix000000CG5MqAAL\',\'UiApi::RecordRepresentation:02ix000000CG6ZIAA1\',\'UiApi::RecordRepresentation:02ix000000CG6OgAAL\',\'UiApi::RecordRepresentation:02ix000000CG5HQAA1\',\'UiApi::RecordRepresentation:02ix000000CG4ihAAD\',\'UiApi::RecordRepresentation:02ix000000CG4zKAAT\',\'UiApi::RecordRepresentation:02ix000000CG4VaAAL\',\'UiApi::RecordRepresentation:02ix000000CG56UAAT\',\'UiApi::RecordRepresentation:02ix000000CG6IvAAL\',\'UiApi::RecordRepresentation:02ix000000CG6ZJAA1\',\'UiApi::RecordRepresentation:02ix000000CG6bQAAT\',\'UiApi::RecordRepresentation:02ix000000CG62UAAT\',\'UiApi::RecordRepresentation:02ix000000CG5iCAAT\',\'UiApi::RecordRepresentation:02ix000000CG6NOAA1\',\'UiApi::RecordRepresentation:02ix000000CG4jrAAD\',\'UiApi::RecordRepresentation:02ix000000CG4C2AAL\',\'UiApi::RecordRepresentation:02ix000000CG4t6AAD\',\'UiApi::RecordRepresentation:02ix000000CG4c2AAD\',\'UiApi::RecordRepresentation:02ix000000CG6MLAA1\',\'UiApi::RecordRepresentation:02ix000000CG6IBAA1\',\'UiApi::RecordRepresentation:02ix000000CG53UAAT\',\'UiApi::RecordRepresentation:02ix000000CG5FAAA1\',\'UiApi::RecordRepresentation:02ix000000CG5GvAAL\',\'UiApi::RecordRepresentation:02ix000000CG5YmAAL\',\'UiApi::RecordRepresentation:02ix000000CG5vcAAD\',\'UiApi::RecordRepresentation:02ix000000CG4SFAA1\',\'UiApi::RecordRepresentation:02ix000000CG5tFAAT\',\'UiApi::RecordRepresentation:02ix000000CG6GfAAL\',\'UiApi::RecordRepresentation:02ix000000CG5M3AAL\',\'UiApi::RecordRepresentation:02ix000000CG5CMAA1\',\'UiApi::RecordRepresentation:02ix000000CG4LsAAL\',\'UiApi::RecordRepresentation:131x00000000khiAAA\',\'UiApi::RecordRepresentation:131x00000000khSAAQ\',\'UiApi::RecordRepresentation:131x00000000jMnAAI\',\'UiApi::RecordRepresentation:131x00000000khYAAQ\',\'UiApi::RecordRepresentation:131x00000000khNAAQ\',\'UiApi::RecordRepresentation:131x00000000khXAAQ\',\'UiApi::RecordRepresentation:131x00000000jMzAAI\',\'UiApi::RecordRepresentation:131x00000000khMAAQ\',\'UiApi::RecordRepresentation:131x00000000jMYAAY\',\'UiApi::RecordRepresentation:131x00000000jMtAAI\',\'UiApi::RecordRepresentation:131x00000000khcAAA\',\'UiApi::RecordRepresentation:131x00000000jMeAAI\',\'UiApi::RecordRepresentation:131x00000000khZAAQ\',\'UiApi::RecordRepresentation:131x00000000khOAAQ\',\'UiApi::RecordRepresentation:131x00000000jN0AAI\',\'UiApi::RecordRepresentation:131x00000000khJAAQ\',\'UiApi::RecordRepresentation:131x00000000kheAAA\',\'UiApi::RecordRepresentation:131x00000000jMkAAI\',\'UiApi::RecordRepresentation:131x00000000jMvAAI\',\'UiApi::RecordRepresentation:131x00000000khIAAQ\',\'UiApi::RecordRepresentation:131x00000000khdAAA\',\'UiApi::RecordRepresentation:131x00000000khjAAA\',\'UiApi::RecordRepresentation:131x00000000jMpAAI\',\'UiApi::RecordRepresentation:131x00000000khTAAQ\',\'UiApi::RecordRepresentation:131x00000000khDAAQ\',\'UiApi::RecordRepresentation:131x00000000khlAAA\',\'UiApi::RecordRepresentation:131x00000000khKAAQ\',\'UiApi::RecordRepresentation:131x00000000khfAAA\',\'UiApi::RecordRepresentation:131x00000000j75AAA\',\'UiApi::RecordRepresentation:131x00000000khVAAQ\',\'UiApi::RecordRepresentation:131x00000000khaAAA\',\'UiApi::RecordRepresentation:131x00000000jMgAAI\',\'UiApi::RecordRepresentation:131x00000000khkAAA\',\'UiApi::RecordRepresentation:131x00000000khUAAQ\',\'UiApi::RecordRepresentation:131x00000000jN2AAI\',\'UiApi::RecordRepresentation:131x00000000jMlAAI\',\'UiApi::RecordRepresentation:131x00000000khPAAQ\',\'UiApi::RecordRepresentation:131x00000000jMmAAI\',\'UiApi::RecordRepresentation:131x00000000khbAAA\',\'UiApi::RecordRepresentation:131x00000000khhAAA\',\'UiApi::RecordRepresentation:131x00000000jMWAAY\',\'UiApi::RecordRepresentation:131x00000000khRAAQ\',\'UiApi::RecordRepresentation:131x00000000jMrAAI\',\'UiApi::RecordRepresentation:131x00000000jMbAAI\',\'UiApi::RecordRepresentation:131x00000000khgAAA\',\'UiApi::RecordRepresentation:131x00000000jMsAAI\',\'UiApi::RecordRepresentation:131x00000000khQAAQ\',\'UiApi::RecordRepresentation:131x00000000jMhAAI\',\'UiApi::RecordRepresentation:131x00000000khWAAQ\',\'UiApi::RecordRepresentation:131x00000000khLAAQ\',\'UiApi::RecordRepresentation:001x0000004ckZXAAY\',\'UiApi::RecordRepresentation:001x0000004ckZcAAI\',\'UiApi::RecordRepresentation:001x0000004cka2AAA\',\'UiApi::RecordRepresentation:001x0000004ckZnAAI\',\'UiApi::RecordRepresentation:001x0000004ckZsAAI\',\'UiApi::RecordRepresentation:001x0000004cka7AAA\',\'UiApi::RecordRepresentation:001x0000004ckZhAAI\',\'UiApi::RecordRepresentation:001x0000004ckZxAAI\',\'UiApi::RecordRepresentation:001x0000004ckZRAAY\',\'UiApi::RecordRepresentation:001x0000004cka8AAA\',\'UiApi::RecordRepresentation:001x0000004ckZmAAI\',\'UiApi::RecordRepresentation:001x0000004ckZbAAI\',\'UiApi::RecordRepresentation:001x0000004ckZWAAY\',\'UiApi::RecordRepresentation:001x0000004cka6AAA\',\'UiApi::RecordRepresentation:001x0000004ckZzAAI\',\'UiApi::RecordRepresentation:001x0000004ckZTAAY\',\'UiApi::RecordRepresentation:001x0000004ckZYAAY\',\'UiApi::RecordRepresentation:001x0000004ckZdAAI\',\'UiApi::RecordRepresentation:001x0000004ckZoAAI\',\'UiApi::RecordRepresentation:001x0000004ckZtAAI\',\'UiApi::RecordRepresentation:001x0000004ckZiAAI\',\'UiApi::RecordRepresentation:001x0000004ckZNAAY\',\'UiApi::RecordRepresentation:001x0000004ckaAAAQ\',\'UiApi::RecordRepresentation:001x0000004ckZyAAI\',\'UiApi::RecordRepresentation:001x0000004ckZSAAY\',\'UiApi::RecordRepresentation:001x0000004cka1AAA\',\'UiApi::RecordRepresentation:001x0000004ckZvAAI\',\'UiApi::RecordRepresentation:001x0000004ckZPAAY\',\'UiApi::RecordRepresentation:001x0000004ckZkAAI\',\'UiApi::RecordRepresentation:001x0000004ckZUAAY\',\'UiApi::RecordRepresentation:001x0000004ckZeAAI\',\'UiApi::RecordRepresentation:001x0000004ckZZAAY\',\'UiApi::RecordRepresentation:001x0000004cka0AAA\',\'UiApi::RecordRepresentation:001x0000004ckZpAAI\',\'UiApi::RecordRepresentation:001x0000004cka5AAA\',\'UiApi::RecordRepresentation:001x0000004ckZuAAI\',\'UiApi::RecordRepresentation:001x0000004ckZOAAY\',\'UiApi::RecordRepresentation:001x0000004ckZjAAI\',\'UiApi::RecordRepresentation:001x0000004ckZrAAI\',\'UiApi::RecordRepresentation:001x0000004ckZgAAI\',\'UiApi::RecordRepresentation:001x0000004ckZwAAI\',\'UiApi::RecordRepresentation:001x0000004ckZlAAI\',\'UiApi::RecordRepresentation:001x0000004ckZQAAY\',\'UiApi::RecordRepresentation:001x0000004cka3AAA\',\'UiApi::RecordRepresentation:001x0000004ckZaAAI\',\'UiApi::RecordRepresentation:001x0000004ckZVAAY\',\'UiApi::RecordRepresentation:001x0000004cka4AAA\',\'UiApi::RecordRepresentation:001x0000004cka9AAA\',\'UiApi::RecordRepresentation:001x0000004ckZqAAI\',\'UiApi::RecordRepresentation:001x0000004ckZfAAI\',\'UiApi::RecordRepresentation:0WOx0000005kEBhGAM\',\'UiApi::RecordRepresentation:0WOx0000005kEBXGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEAAGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEA6GAM\',\'UiApi::RecordRepresentation:0WOx0000005kEAQGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEA0GAM\',\'UiApi::RecordRepresentation:0WOx0000005kEBSGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEBcGAM\',\'UiApi::RecordRepresentation:0WOx0000005kEAFGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEAGGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEA1GAM\',\'UiApi::RecordRepresentation:0WOx0000005kEBRGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEBbGAM\',\'UiApi::RecordRepresentation:0WOx0000005kEALGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEBTGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEBdGAM\',\'UiApi::RecordRepresentation:0WOx0000005kEAMGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEARGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEA7GAM\',\'UiApi::RecordRepresentation:0WOx0000005kEABGA2\',\'UiApi::RecordRepresentation:0WOx0000005kE9zGAE\',\'UiApi::RecordRepresentation:0WOx0000005kECjGAM\',\'UiApi::RecordRepresentation:0WOx0000005kEASGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEA8GAM\',\'UiApi::RecordRepresentation:0WOx0000005kEACGA2\',\'UiApi::RecordRepresentation:0WOx0000005kE9yGAE\',\'UiApi::RecordRepresentation:0WOx0000005kEAHGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEA2GAM\',\'UiApi::RecordRepresentation:0WOx0000005kEBYGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEAIGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEA3GAM\',\'UiApi::RecordRepresentation:0WOx0000005kEANGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEBZGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEAOGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEBUGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEA9GAM\',\'UiApi::RecordRepresentation:0WOx0000005kE9xGAE\',\'UiApi::RecordRepresentation:0WOx0000005kEADGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEBeGAM\',\'UiApi::RecordRepresentation:0WOx0000005kEAEGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEBgGAM\',\'UiApi::RecordRepresentation:0WOx0000005kEBWGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEA4GAM\',\'UiApi::RecordRepresentation:0WOx0000005kEAJGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEBVGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEBfGAM\',\'UiApi::RecordRepresentation:0WOx0000005kEAKGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEA5GAM\',\'UiApi::RecordRepresentation:0WOx0000005kEAPGA2\',\'UiApi::RecordRepresentation:0WOx0000005kEBaGAM\',\'UiApi::RecordRepresentation:08px000000JaaADAAZ\',\'UiApi::RecordRepresentation:08px000000JaaATAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAuAAJ\',\'UiApi::RecordRepresentation:08px000000JaaA9AAJ\',\'UiApi::RecordRepresentation:08px000000JaaAYAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAdAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAIAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAZAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAeAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAJAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAOAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAoAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAjAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAHAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAcAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAXAAZ\',\'UiApi::RecordRepresentation:08px000000JaaA8AAJ\',\'UiApi::RecordRepresentation:08px000000JaaAMAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAhAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAtAAJ\',\'UiApi::RecordRepresentation:08px000000JaaANAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAiAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAsAAJ\',\'UiApi::RecordRepresentation:08px000000JaaACAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAnAAJ\',\'UiApi::RecordRepresentation:08px000000JaaASAAZ\',\'UiApi::RecordRepresentation:08px000000JaaALAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAgAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAAAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAlAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAQAAZ\',\'UiApi::RecordRepresentation:08px000000JaaABAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAmAAJ\',\'UiApi::RecordRepresentation:08px000000JaaARAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAbAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAGAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAWAAZ\',\'UiApi::RecordRepresentation:08px000000JaaArAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAPAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAkAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAqAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAEAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAUAAZ\',\'UiApi::RecordRepresentation:08px000000JaaApAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAaAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAFAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAVAAZ\',\'UiApi::RecordRepresentation:08px000000JaaAfAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAvAAJ\',\'UiApi::RecordRepresentation:08px000000JaaAKAAZ\')";
    NSRegularExpression* regexp = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSMutableString* sql = [NSMutableString stringWithString:q];
    CFTimeInterval startTime = CACurrentMediaTime();
    [regexp replaceMatchesInString:sql options:0 range:NSMakeRange(0, [sql length]) withTemplate:@"json_extract($1.soup"];
    CFTimeInterval elapsedTime = CACurrentMediaTime() - startTime;
    return elapsedTime * 1000.0;
}

- (void)loadData {
    // Employees
    [self createEmployeeWithFirstName:@"Christine" withLastName:@"Haas" withDeptCode:@"A00" withEmployeeId:@"00010" withManagerId:@"" withSalary:200000.10 withIsManager:YES];
    [self createEmployeeWithFirstName:@"Michael" withLastName:@"Thompson" withDeptCode:@"A00" withEmployeeId:@"00020" withManagerId:@"00010" withSalary:120000.10 withIsManager:NO];
    [self createEmployeeWithFirstName:@"Sally" withLastName:@"Kwan" withDeptCode:@"A00" withEmployeeId:@"00310" withManagerId:@"00010" withSalary:100000.10 withIsManager:NO];
    [self createEmployeeWithFirstName:@"John" withLastName:@"Geyer" withDeptCode:@"B00" withEmployeeId:@"00040" withManagerId:@"" withSalary:102000.10 withIsManager:YES];
    [self createEmployeeWithFirstName:@"Irving" withLastName:@"Stern" withDeptCode:@"B00" withEmployeeId:@"00050" withManagerId:@"00040" withSalary:100000.10 withIsManager:YES];
    [self createEmployeeWithFirstName:@"Eva" withLastName:@"Pulaski" withDeptCode:@"B00" withEmployeeId:@"00060" withManagerId:@"00050" withSalary:80000.10 withIsManager:NO];
    [self createEmployeeWithFirstName:@"Eileen" withLastName:@"Henderson" withDeptCode:@"B00" withEmployeeId:@"00070" withManagerId:@"00050" withSalary:70000.10 withIsManager:NO];
		
    // Departments
    [self createDepartmentWithCode:@"A00" withName:@"Sales" withBudget:1000000];
    [self createDepartmentWithCode:@"B00" withName:@"R&D" withBudget:2000000];
}

- (void)createEmployeeWithFirstName:(NSString *)firstName withLastName:(NSString *)lastName withDeptCode:(NSString *)deptCode withEmployeeId:(NSString *)employeeId withManagerId:(NSString *)managerId withSalary:(double)salary withIsManager:(BOOL)isManager {
    NSDictionary *employee = @{kFirstName: firstName, kLastName: lastName, kDeptCode: deptCode, kEmployeeId: employeeId, kManagerId: managerId, kSalary: @(salary), kIsManager: @(isManager)};
    [self.store upsertEntries:@[employee] toSoup:kEmployeesSoup];
}

- (NSDictionary *)createEmployeeWithJsonString:(NSString*)jsonString {
    NSDictionary *employee = [SFJsonUtils objectFromJSONString:jsonString];
    return [self.store upsertEntries:@[employee] toSoup:kEmployeesSoup][0];
}
	
- (void)createDepartmentWithCode:(NSString *)deptCode withName:(NSString *)name withBudget:(NSUInteger)budget {
    NSDictionary *department = @{kDeptCode: deptCode, kName: name, kBudget: @(budget)};
    [self.store upsertEntries:@[department] toSoup:kDepartmentsSoup];
}

@end
