/*
  Copyright (c) 2013, salesforce.com, inc. All rights reserved.
 
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
#import "SFSmartStore+Internal.h"
#import "SFSoupIndex.h"
#import "SFQuerySpec.h"
#import <SalesforceSDKCore/SFJsonUtils.h>
#import "SFSoupSpec.h"

@interface SFSmartSqlTests ()

@property (nonatomic, strong) SFSmartStore *store;

@end

@implementation SFSmartSqlTests

#define kTestStore            @"testSmartSqlStore"
#define kEmployeesSoup        @"employees"
#define kDepartmentsSoup      @"departments"
#define kFirstName            @"firstName"
#define kLastName             @"lastName"
#define kDeptCode             @"deptCode"
#define kEmployeeId           @"employeeId"
#define kManagerId            @"managerId"
#define kSalary               @"salary"
#define kBudget               @"budget"
#define kName                 @"name"
#define kEducation            @"education"
#define kBuilding             @"building"

typedef NS_ENUM(NSUInteger, SFSmartSqlTestsIteration) {
    SFSmartSqlTestsIterationDefault = 0,
    SFSmartSqlTestsIterationWithExternalStorage
};

#pragma mark - setup and teardown

- (NSUInteger) numberOfIterationsPerTest {
    return 2;
}

- (void) executeTest:(void(^)(NSInteger i))testBlock {
    NSInteger iteration = 0;
    while (iteration < [self numberOfIterationsPerTest]) {
        [self setUpForIteration:iteration];
        testBlock(iteration);
        [self tearDownForIteration:iteration];
        ++iteration;
    }
}

- (void) setUpForIteration:(NSInteger)iteration {
    NSArray *useFeatures = nil;
    if (iteration == SFSmartSqlTestsIterationWithExternalStorage) {
        useFeatures = @[kSoupFeatureExternalStorage];
    }
	[SFUserAccountManager sharedInstance].currentUser = [self createUserAccount];
 	self.store = [SFSmartStore sharedStoreWithName:kTestStore user:[SFUserAccountManager sharedInstance].currentUser];
       
    // Employees soup
    [_store registerSoupWithSpec:[SFSoupSpec newSoupSpec:kEmployeesSoup withFeatures:useFeatures]  // should be TABLE_1
                  withIndexSpecs:[SFSoupIndex asArraySoupIndexes:
                                  @[[self createStringIndexSpec:kFirstName],
                                    [self createStringIndexSpec:kLastName],    // should be TABLE_1_0
                                    [self createStringIndexSpec:kDeptCode],    // should be TABLE_1_1
                                    [self createStringIndexSpec:kEmployeeId],  // should be TABLE_1_2
                                    [self createStringIndexSpec:kManagerId],   // should be TABLE_1_3
                                    [self createFloatingIndexSpec:kSalary],
									[self createJSON1IndexSpec:kEducation]]]     // should be json_extract(soup, '$.education')
                           error:nil];
    
    // Departments soup
    [_store registerSoupWithSpec:[SFSoupSpec newSoupSpec:kDepartmentsSoup withFeatures:useFeatures] // should be TABLE_2
                  withIndexSpecs:[SFSoupIndex asArraySoupIndexes:
                                  @[[self createStringIndexSpec:kDeptCode],     // should be TABLE_2_0
                                    [self createStringIndexSpec:kName],         // should be TABLE_2_1
                                    [self createIntegerIndexSpec:kBudget],
									[self createJSON1IndexSpec:kBuilding]]]
                           error:nil];
}

- (void) tearDownForIteration:(NSInteger)iteration {
    _store = nil;
    [SFSmartStore removeSharedStoreWithName:kTestStore forUser:[SFUserAccountManager sharedInstance].currentUser];
}

- (SFUserAccount *)createUserAccount
{
    u_int32_t userIdentifier = arc4random();
    SFUserAccount *user = [[SFUserAccount alloc] initWithIdentifier:[NSString stringWithFormat:@"identifier-%u", userIdentifier]];
    NSString *userId = [NSString stringWithFormat:@"user_%u", userIdentifier];
    NSString *orgId = [NSString stringWithFormat:@"org_%u", userIdentifier];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://test.salesforce.com/id/%@/%@", orgId, userId]];
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
    [self executeTest:^(NSInteger i) {
        XCTAssertNil([_store convertSmartSql:@"insert into {employees}"], @"Should have returned nil for a insert query");
        XCTAssertNil([_store convertSmartSql:@"update {employees}"], @"Should have returned nil for a update query");
        XCTAssertNil([_store convertSmartSql:@"delete from {employees}"], @"Should have returned nil for a delete query");
        XCTAssertNotNil([_store convertSmartSql:@"select * from {employees}"], @"Should not have returned nil for a proper query");
    }];
}

- (void) testSimpleConvertSmartSql
{
    [self executeTest:^(NSInteger i) {
        XCTAssertEqualObjects(@"select TABLE_1_0, TABLE_1_1 from TABLE_1 order by TABLE_1_1",
                              [_store convertSmartSql:@"select {employees:firstName}, {employees:lastName} from {employees} order by {employees:lastName}"],
                              @"Bad conversion");
        
        XCTAssertEqualObjects(@"select TABLE_2_1 from TABLE_2 order by TABLE_2_0",
                              [_store convertSmartSql:@"select {departments:name} from {departments} order by {departments:deptCode}"],
                              @"Bad conversion");
    }];
}

- (void) testConvertSmartSqlWithJoin
{
    [self executeTest:^(NSInteger i) {
        XCTAssertEqualObjects(@"select TABLE_2_1, TABLE_1_0 || ' ' || TABLE_1_1 "
                              "from TABLE_1, TABLE_2 "
                              "where TABLE_2_0 = TABLE_1_2 "
                              "order by TABLE_2_1, TABLE_1_1",
                              [_store convertSmartSql:@"select {departments:name}, {employees:firstName} || ' ' || {employees:lastName} "
                               "from {employees}, {departments} "
                               "where {departments:deptCode} = {employees:deptCode} "
                               "order by {departments:name}, {employees:lastName}"],
                              @"Bad conversion");
    }];
}

- (void) testConvertSmartSqlWithSelfJoin
{
    [self executeTest:^(NSInteger i) {
        XCTAssertEqualObjects(@"select mgr.TABLE_1_1, e.TABLE_1_1 "
                              "from TABLE_1 as mgr, TABLE_1 as e "
                              "where mgr.TABLE_1_3 = e.TABLE_1_4",
                              [_store convertSmartSql:@"select mgr.{employees:lastName}, e.{employees:lastName} "
                               "from {employees} as mgr, {employees} as e "
                               "where mgr.{employees:employeeId} = e.{employees:managerId}"],
                              @"Bad conversion");
    }];
}

- (void) testConvertSmartSqlWithSpecialColumns
{
    [self executeTest:^(NSInteger i) {
        if (i == SFSmartSqlTestsIterationDefault) {
            XCTAssertEqualObjects(@"select TABLE_1.id, TABLE_1.lastModified, TABLE_1.soup from TABLE_1",
                                  [_store convertSmartSql:@"select {employees:_soupEntryId}, {employees:_soupLastModifiedDate}, {employees:_soup} from {employees}"], @"Bad conversion");
        }
        else if (i == SFSmartSqlTestsIterationWithExternalStorage) {
            NSString *expected = [NSString stringWithFormat:
                                  @"select TABLE_1.id, TABLE_1.lastModified, 'TABLE_1' as '%@', TABLE_1.id as '_soupEntryId' from TABLE_1", kSoupFeatureExternalStorage];
            NSString *result = [_store convertSmartSql:@"select {employees:_soupEntryId}, {employees:_soupLastModifiedDate}, {employees:_soup} from {employees}"];
            XCTAssertEqualObjects(expected, result, @"Bad conversion");
        }
    }];
}
	
- (void) testConvertSmartSqlWithSpecialColumnsAndJoin
{
    [self executeTest:^(NSInteger i) {
        XCTAssertEqualObjects(@"select TABLE_1.id, TABLE_2.id from TABLE_1, TABLE_2",
                              [_store convertSmartSql:@"select {employees:_soupEntryId}, {departments:_soupEntryId} from {employees}, {departments}"], @"Bad conversion");
    }];
}

- (void) testConvertSmartSqlWithSpecialColumnsAndSelfJoin
{
    [self executeTest:^(NSInteger i) {
        XCTAssertEqualObjects(@"select mgr.id, e.id from TABLE_1 as mgr, TABLE_1 as e",
                              [_store convertSmartSql:@"select mgr.{employees:_soupEntryId}, e.{employees:_soupEntryId} from {employees} as mgr, {employees} as e"], @"Bad conversion");
    }];
}

- (void) testConvertSmartSqlWithJSON1
{
    XCTAssertEqualObjects(@"select TABLE_1_1, json_extract(soup, '$.education') from TABLE_1 where json_extract(soup, '$.education') = 'MIT'",
                          [self.store convertSmartSql:@"select {employees:lastName}, {employees:education} from {employees} where {employees:education} = 'MIT'"], @"Bad conversion");
}

- (void) testConvertSmartSqlWithJSON1AndTableQualifiedColumn
{
    XCTAssertEqualObjects(@"select json_extract(TABLE_1.soup, '$.education') from TABLE_1 order by json_extract(TABLE_1.soup, '$.education')",
                          [self.store convertSmartSql:@"select {employees}.{employees:education} from {employees} order by {employees}.{employees:education}"], @"Bad conversion");
}

- (void) testConvertSmartSqlWithJSON1AndTableAliases
{
    XCTAssertEqualObjects(@"select json_extract(e.soup, '$.education'), json_extract(soup, '$.building') from TABLE_1 as e, TABLE_2",
                          [self.store convertSmartSql:@"select e.{employees:education}, {departments:building} from {employees} as e, {departments}"], @"Bad conversion");
    
    // XXX join query with json1 will only run if all the json1 columns are qualified by table or alias
}


- (void) testSmartQueryDoingCount 
{
    [self executeTest:^(NSInteger i) {
        [self loadData];
        SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select count(*) from {employees}" withPageSize:1];
        NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
        [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[7]]"] actual:result message:@"Wrong result"];
    }];
}
	
- (void) testSmartQueryDoingSum 
{
    [self executeTest:^(NSInteger i) {
        [self loadData];
        SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select sum({departments:budget}) from {departments}" withPageSize:1];
        NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
        [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[3000000]]"] actual:result message:@"Wrong result"];
    }];
}

- (void) testSmartQueryReturningOneRowWithOneInteger 
{
    [self executeTest:^(NSInteger i) {
        [self loadData];
        SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:salary} from {employees} where {employees:lastName} = 'Haas'" withPageSize:1];
        NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
        [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[200000.10]]"] actual:result message:@"Wrong result"];
    }];
}
	
- (void) testSmartQueryReturningOneRowWithTwoIntegers 
{
    [self executeTest:^(NSInteger i) {
        [self loadData];
        SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select mgr.{employees:salary}, e.{employees:salary} from {employees} as mgr, {employees} as e where e.{employees:lastName} = 'Thompson' and mgr.{employees:employeeId} = e.{employees:managerId}" withPageSize:1];
        NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
        [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[200000.10,120000.10]]"] actual:result message:@"Wrong result"];
    }];
}

- (void) testSmartQueryReturningTwoRowsWithOneIntegerEach 
{
    [self executeTest:^(NSInteger i) {
        [self loadData];
        SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:salary} from {employees} where {employees:managerId} = '00010' order by {employees:firstName}" withPageSize:2];
        NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
        [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[120000.10],[100000.10]]"] actual:result message:@"Wrong result"];
    }];
}

- (void) testSmartQueryReturningSoupStringAndInteger 
{
    [self executeTest:^(NSInteger i) {
        [self loadData];
        SFQuerySpec* exactQuerySpec = [SFQuerySpec newExactQuerySpec:kEmployeesSoup withPath:@"employeeId" withMatchKey:@"00010" withOrderPath:nil withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
        NSDictionary* christineJson = [_store queryWithQuerySpec:exactQuerySpec pageIndex:0  error:nil][0];
        XCTAssertEqualObjects(@"Christine", christineJson[kFirstName], @"Wrong elt");
        SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:_soup}, {employees:firstName}, {employees:salary} from {employees} where {employees:lastName} = 'Haas'" withPageSize:1];
        NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
        XCTAssertTrue(1 == [result count], @"Expected one row");
        [self assertSameJSONWithExpected:christineJson actual:result[0][0] message:@"Wrong soup"];
        XCTAssertEqualObjects(@"Christine", result[0][1], @"Wrong first name");
        NSNumber* dubNum = result[0][2];
        XCTAssertEqual(200000.10, [dubNum doubleValue], @"Wrong salary");
    }];
}
	
- (void) testSmartQueryWithPaging 
{
    [self executeTest:^(NSInteger i) {
        [self loadData];
        SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:firstName} from {employees} order by {employees:firstName}" withPageSize:1];
        XCTAssertTrue(7 ==[_store countWithQuerySpec:querySpec  error:nil], @"Expected 7 employees");
        NSArray* expectedResults = @[@"Christine", @"Eileen", @"Eva", @"Irving", @"John", @"Michael", @"Sally"];
        for (int i=0; i<7; i++) {
            NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:i  error:nil];
            NSArray* expectedResult = @[@[expectedResults[i]]];
            NSString* message = [NSString stringWithFormat:@"Wrong result at page %d", i];
            [self assertSameJSONArrayWithExpected:expectedResult actual:result message:message];
        }
    }];
}
    
- (void) testSmartQueryWithSpecialFields 
{
    [self executeTest:^(NSInteger i) {
        [self loadData];
        SFQuerySpec* exactQuerySpec = [SFQuerySpec newExactQuerySpec:kEmployeesSoup withPath:@"employeeId" withMatchKey:@"00010" withOrderPath:nil withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
        NSDictionary* christineJson = [_store queryWithQuerySpec:exactQuerySpec pageIndex:0  error:nil][0];
        XCTAssertEqualObjects(@"Christine", christineJson[kFirstName], @"Wrong elt");
        SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:_soup}, {employees:_soupEntryId}, {employees:_soupLastModifiedDate} from {employees} where {employees:lastName} = 'Haas'" withPageSize:1];
        NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:0  error:nil];
        XCTAssertTrue(1 == [result count], @"Expected one row");
        [self assertSameJSONWithExpected:christineJson actual:result[0][0] message:@"Wrong soup"];
        XCTAssertEqualObjects(christineJson[@"_soupEntryId"], result[0][1], @"Wrong soupEntryId");
        XCTAssertEqualObjects(christineJson[@"_soupLastModifiedDate"], result[0][2], @"Wrong soupLastModifiedDate");
    }];
}

#pragma mark - helper methods
- (void) loadData
{
    // Employees
    [self createEmployeeWithFirstName:@"Christine" withLastName:@"Haas" withDeptCode:@"A00" withEmployeeId:@"00010" withManagerId:@"" withSalary:200000.10];
    [self createEmployeeWithFirstName:@"Michael" withLastName:@"Thompson" withDeptCode:@"A00" withEmployeeId:@"00020" withManagerId:@"00010" withSalary:120000.10];
    [self createEmployeeWithFirstName:@"Sally" withLastName:@"Kwan" withDeptCode:@"A00" withEmployeeId:@"00310" withManagerId:@"00010" withSalary:100000.10];
    [self createEmployeeWithFirstName:@"John" withLastName:@"Geyer" withDeptCode:@"B00" withEmployeeId:@"00040" withManagerId:@"" withSalary:102000.10];
    [self createEmployeeWithFirstName:@"Irving" withLastName:@"Stern" withDeptCode:@"B00" withEmployeeId:@"00050" withManagerId:@"00040" withSalary:100000.10];
    [self createEmployeeWithFirstName:@"Eva" withLastName:@"Pulaski" withDeptCode:@"B00" withEmployeeId:@"00060" withManagerId:@"00050" withSalary:80000.10];
    [self createEmployeeWithFirstName:@"Eileen" withLastName:@"Henderson" withDeptCode:@"B00" withEmployeeId:@"00070" withManagerId:@"00050" withSalary:70000.10];
		
    // Departments
    [self createDepartmentWithCode:@"A00" withName:@"Sales" withBudget:1000000];
    [self createDepartmentWithCode:@"B00" withName:@"R&D" withBudget:2000000];
}

- (void) createEmployeeWithFirstName:(NSString*)firstName withLastName:(NSString*)lastName withDeptCode:(NSString*)deptCode withEmployeeId:(NSString*)employeeId withManagerId:(NSString*)managerId withSalary:(double)salary
{
    NSDictionary* employee = @{kFirstName: firstName, kLastName: lastName, kDeptCode: deptCode, kEmployeeId: employeeId, kManagerId: managerId, kSalary: @(salary)};
    [self.store upsertEntries:@[employee] toSoup:kEmployeesSoup];
}
	
- (void) createDepartmentWithCode:(NSString*) deptCode withName:(NSString*)name withBudget:(NSUInteger) budget
{
    NSDictionary* department = @{kDeptCode: deptCode, kName: name, kBudget: @(budget)};
    [self.store upsertEntries:@[department] toSoup:kDepartmentsSoup];
}

@end
