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
#import "SFQuerySpec.h"
#import "SFJsonUtils.h"

@interface SFSmartSqlTests ()
- (NSDictionary*) createStringIndexSpec:(NSString*) path;
- (NSDictionary*) createIntegerIndexSpec:(NSString*) path;
- (NSDictionary*) createFloatingIndexSpec:(NSString*) path;
- (NSDictionary*) createSimpleIndexSpec:(NSString*) path withType:(NSString*) pathType;
@end

@implementation SFSmartSqlTests

NSString* const kTestStore            = @"testSmartSqlStore";
NSString* const kEmployeesSoup        = @"employees";
NSString* const kDepartmentsSoup      = @"departments";
NSString* const kFirstName            = @"firstName";
NSString* const kLastName             = @"lastName";
NSString* const kDeptCode             = @"deptCode";
NSString* const kEmployeeId           = @"employeeId";
NSString* const kManagerId            = @"managerId";
NSString* const kSalary               = @"salary";
NSString* const kBudget               = @"budget";
NSString* const kName                 = @"name";

#pragma mark - setup and teardown

- (void) setUp
{
    [super setUp];
    _store = [SFSmartStore sharedStoreWithName:kTestStore];
    
    // Employees soup
    [_store registerSoup:kEmployeesSoup                              // should be TABLE_1
          withIndexSpecs:[NSArray arrayWithObjects:
                                  [self createStringIndexSpec:kFirstName],  
                                  [self createStringIndexSpec:kLastName],    // should be TABLE_1_0
                                  [self createStringIndexSpec:kDeptCode],    // should be TABLE_1_1
                                  [self createStringIndexSpec:kEmployeeId],  // should be TABLE_1_2
                                  [self createStringIndexSpec:kManagerId],   // should be TABLE_1_3
                                  [self createFloatingIndexSpec:kSalary],    // should be TABLE_1_4
                                  nil]];

    // Departments soup
    [_store registerSoup:kDepartmentsSoup                            // should be TABLE_2
          withIndexSpecs:[NSArray arrayWithObjects:
                                  [self createStringIndexSpec:kDeptCode],    // should be TABLE_2_0
                                  [self createStringIndexSpec:kName],        // should be TABLE_2_1
                                  [self createIntegerIndexSpec:kBudget],     // should be TABLE_2_2
                                  nil]];
}

- (void) tearDown
{
    _store = nil;
    [SFSmartStore removeSharedStoreWithName:kTestStore];
    [super tearDown];
}


#pragma mark - tests
// All code under test must be linked into the Unit Test bundle

- (void) testSharedInstance
{
    SFSmartSqlHelper* instance1 = [SFSmartSqlHelper sharedInstance];
    SFSmartSqlHelper* instance2 = [SFSmartSqlHelper sharedInstance];
    STAssertEqualObjects(instance1, instance2, @"There should be only one instance");
}

- (void) testConvertSmartSqlWithInsertUpdateDelete
{
    STAssertNil([_store convertSmartSql:@"insert into {employees}"], @"Should have returned nil for a insert query");
    STAssertNil([_store convertSmartSql:@"update {employees}"], @"Should have returned nil for a update query");
    STAssertNil([_store convertSmartSql:@"delete from {employees}"], @"Should have returned nil for a delete query");
    STAssertNotNil([_store convertSmartSql:@"select * from {employees}"], @"Should not have returned nil for a proper query");
}

- (void) testSimpleConvertSmartSql
{
    STAssertEqualObjects(@"select TABLE_1_0, TABLE_1_1 from TABLE_1 order by TABLE_1_1",
                         [_store convertSmartSql:@"select {employees:firstName}, {employees:lastName} from {employees} order by {employees:lastName}"],
                         @"Bad conversion");

    STAssertEqualObjects(@"select TABLE_2_1 from TABLE_2 order by TABLE_2_0",
                         [_store convertSmartSql:@"select {departments:name} from {departments} order by {departments:deptCode}"],
                         @"Bad conversion");
}


- (void) testConvertSmartSqlWithJoin
{
    STAssertEqualObjects(@"select TABLE_2_1, TABLE_1_0 || ' ' || TABLE_1_1 "
                         "from TABLE_1, TABLE_2 "
                         "where TABLE_2_0 = TABLE_1_2 "
                         "order by TABLE_2_1, TABLE_1_1",
                         [_store convertSmartSql:@"select {departments:name}, {employees:firstName} || ' ' || {employees:lastName} "
                                 "from {employees}, {departments} "
                             "where {departments:deptCode} = {employees:deptCode} "
                                 "order by {departments:name}, {employees:lastName}"],
                         @"Bad conversion");
}

- (void) testConvertSmartSqlWithSelfJoin
{
    STAssertEqualObjects(@"select mgr.TABLE_1_1, e.TABLE_1_1 "
                         "from TABLE_1 as mgr, TABLE_1 as e "
                         "where mgr.TABLE_1_3 = e.TABLE_1_4",
                         [_store convertSmartSql:@"select mgr.{employees:lastName}, e.{employees:lastName} "
                                 "from {employees} as mgr, {employees} as e "
                           "where mgr.{employees:employeeId} = e.{employees:managerId}"],
                         @"Bad conversion");
}

- (void) testConvertSmartSqlWithSpecialColumns
{
    STAssertEqualObjects(@"select TABLE_1.id, TABLE_1.lastModified, TABLE_1.soup from TABLE_1", 
                         [_store convertSmartSql:@"select {employees:_soupEntryId}, {employees:_soupLastModifiedDate}, {employees:_soup} from {employees}"], @"Bad conversion");
}
	
- (void) testConvertSmartSqlWithSpecialColumnsAndJoin
{
    STAssertEqualObjects(@"select TABLE_1.id, TABLE_2.id from TABLE_1, TABLE_2", 
                         [_store convertSmartSql:@"select {employees:_soupEntryId}, {departments:_soupEntryId} from {employees}, {departments}"], @"Bad conversion");
}

- (void) testConvertSmartSqlWithSpecialColumnsAndSelfJoin
{
    STAssertEqualObjects(@"select mgr.id, e.id from TABLE_1 as mgr, TABLE_1 as e", 
                         [_store convertSmartSql:@"select mgr.{employees:_soupEntryId}, e.{employees:_soupEntryId} from {employees} as mgr, {employees} as e"], @"Bad conversion");
}

- (void) testSmartQueryDoingCount 
{
    [self loadData];
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select count(*) from {employees}" withPageSize:1];
    NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:0];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[7]]"] actual:result message:@"Wrong result"];
}
	
- (void) testSmartQueryDoingSum 
{
    [self loadData];
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select sum({departments:budget}) from {departments}" withPageSize:1];
    NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:0];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[3000000]]"] actual:result message:@"Wrong result"];
}

- (void) testSmartQueryReturningOneRowWithOneInteger 
{
    [self loadData];
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:salary} from {employees} where {employees:lastName} = 'Haas'" withPageSize:1];
    NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:0];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[200000.10]]"] actual:result message:@"Wrong result"];
}
	
- (void) testSmartQueryReturningOneRowWithTwoIntegers 
{
    [self loadData];
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select mgr.{employees:salary}, e.{employees:salary} from {employees} as mgr, {employees} as e where e.{employees:lastName} = 'Thompson'" withPageSize:1];
    NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:0];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[200000.10,120000.10]]"] actual:result message:@"Wrong result"];
}

- (void) testSmartQueryReturningTwoRowsWithOneIntegerEach 
{
    [self loadData];
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:salary} from {employees} where {employees:managerId} = '00010' order by {employees:firstName}" withPageSize:2];
    NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:0];
    [self assertSameJSONArrayWithExpected:[SFJsonUtils objectFromJSONString:@"[[120000.10],[100000.10]]"] actual:result message:@"Wrong result"];
}

- (void) testSmartQueryReturningSoupStringAndInteger 
{
    [self loadData];
    SFQuerySpec* exactQuerySpec = [SFQuerySpec newExactQuerySpec:kEmployeesSoup withPath:@"employeeId" withMatchKey:@"00010" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    NSDictionary* christineJson = [[_store queryWithQuerySpec:exactQuerySpec pageIndex:0] objectAtIndex:0];
    STAssertEqualObjects(@"Christine", [christineJson objectForKey:kFirstName], @"Wrong elt");
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:_soup}, {employees:firstName}, {employees:salary} from {employees} where {employees:lastName} = 'Haas'" withPageSize:1];
    NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:0];
    STAssertTrue(1 == [result count], @"Expected one row");
    [self assertSameJSONWithExpected:christineJson actual:[[result objectAtIndex:0] objectAtIndex:0] message:@"Wrong soup"];
    STAssertEqualObjects(@"Christine", [[result objectAtIndex:0] objectAtIndex:1], @"Wrong first name");
    NSNumber* dubNum = [[result objectAtIndex:0] objectAtIndex:2];
    STAssertEquals(200000.10, [dubNum doubleValue], @"Wrong salary");
}
	
- (void) testSmartQueryWithPaging 
{
    [self loadData];
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:firstName} from {employees} order by {employees:firstName}" withPageSize:1];
    STAssertTrue(7 ==[_store countWithQuerySpec:querySpec], @"Expected 7 employees");
    NSArray* expectedResults = [NSArray arrayWithObjects:@"Christine", @"Eileen", @"Eva", @"Irving", @"John", @"Michael", @"Sally", nil];
    for (int i=0; i<7; i++) {
        NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:i];
        NSArray* expectedResult = [NSArray arrayWithObject:[NSArray arrayWithObject:[expectedResults objectAtIndex:i]]];
        NSString* message = [NSString stringWithFormat:@"Wrong result at page %d", i];
        [self assertSameJSONArrayWithExpected:expectedResult actual:result message:message];
    }
}
    
- (void) testSmartQueryWithSpecialFields 
{
    [self loadData];
    SFQuerySpec* exactQuerySpec = [SFQuerySpec newExactQuerySpec:kEmployeesSoup withPath:@"employeeId" withMatchKey:@"00010" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    NSDictionary* christineJson = [[_store queryWithQuerySpec:exactQuerySpec pageIndex:0] objectAtIndex:0];
    STAssertEqualObjects(@"Christine", [christineJson objectForKey:kFirstName], @"Wrong elt");
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:_soup}, {employees:_soupEntryId}, {employees:_soupLastModifiedDate} from {employees} where {employees:lastName} = 'Haas'" withPageSize:1];
    NSArray* result = [_store queryWithQuerySpec:querySpec pageIndex:0];
    STAssertTrue(1 == [result count], @"Expected one row");
    [self assertSameJSONWithExpected:christineJson actual:[[result objectAtIndex:0] objectAtIndex:0] message:@"Wrong soup"];
    STAssertEqualObjects([christineJson objectForKey:@"_soupEntryId"], [[result objectAtIndex:0] objectAtIndex:1], @"Wrong soupEntryId");
    STAssertEqualObjects([christineJson objectForKey:@"_soupLastModifiedDate"], [[result objectAtIndex:0] objectAtIndex:2], @"Wrong soupLastModifiedDate");
}

#pragma mark - helper methods
- (NSDictionary*) createIntegerIndexSpec:(NSString*) path
{
    return [self createSimpleIndexSpec:path withType:@"integer"];
}

- (NSDictionary*) createFloatingIndexSpec:(NSString*) path
{
    return [self createSimpleIndexSpec:path withType:@"floating"];
}

- (NSDictionary*) createStringIndexSpec:(NSString*) path
{
    return [self createSimpleIndexSpec:path withType:@"string"];
}

- (NSDictionary*) createSimpleIndexSpec:(NSString*) path withType:(NSString*) pathType
{
    return [NSDictionary dictionaryWithObjectsAndKeys:path, @"path", pathType, @"type", nil];
}

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
    NSDictionary* employee = [NSDictionary  dictionaryWithObjectsAndKeys:firstName, kFirstName, lastName, kLastName, deptCode, kDeptCode, employeeId, kEmployeeId, managerId, kManagerId, [NSNumber numberWithDouble:salary], kSalary, nil];
    [_store upsertEntries:[NSArray arrayWithObject:employee] toSoup:kEmployeesSoup];
}
	
- (void) createDepartmentWithCode:(NSString*) deptCode withName:(NSString*)name withBudget:(NSUInteger) budget
{
    NSDictionary* department = [NSDictionary dictionaryWithObjectsAndKeys:deptCode, kDeptCode, name, kName, [NSNumber numberWithUnsignedInteger:budget], kBudget, nil];
    [_store upsertEntries:[NSArray arrayWithObject:department] toSoup:kDepartmentsSoup];
}

@end
