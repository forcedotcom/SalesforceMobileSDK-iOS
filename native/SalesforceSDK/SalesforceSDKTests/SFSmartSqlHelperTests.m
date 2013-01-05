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


#import "SFSmartSqlHelperTests.h"
#import "SFSmartSqlHelper.h"
#import "SFSmartStore+Internal.h"

@interface SFSmartSqlHelperTests ()
- (NSDictionary*) createStringIndexSpec:(NSString*) path;
- (NSDictionary*) createIntegerIndexSpec:(NSString*) path;
- (NSDictionary*) createSimpleIndexSpec:(NSString*) path withType:(NSString*) pathType;
@end

@implementation SFSmartSqlHelperTests

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
    _store = [[SFSmartStore sharedStoreWithName:kTestStore] retain];
    
    // Employees soup
    [_store registerSoup:kEmployeesSoup                              // should be TABLE_1
          withIndexSpecs:[NSArray arrayWithObjects:
                          [self createStringIndexSpec:kFirstName],  
                          [self createStringIndexSpec:kLastName],    // should be TABLE_1_0
                          [self createStringIndexSpec:kDeptCode],    // should be TABLE_1_1
                          [self createStringIndexSpec:kEmployeeId],  // should be TABLE_1_2
                          [self createStringIndexSpec:kManagerId],   // should be TABLE_1_3
                          [self createIntegerIndexSpec:kSalary],     // should be TABLE_1_4
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
    [_store release]; // close underlying db
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


#pragma mark - helper methods
- (NSDictionary*) createIntegerIndexSpec:(NSString*) path
{
    return [self createSimpleIndexSpec:path withType:@"integer"];
}

- (NSDictionary*) createStringIndexSpec:(NSString*) path
{
    return [self createSimpleIndexSpec:path withType:@"string"];
}

- (NSDictionary*) createSimpleIndexSpec:(NSString*) path withType:(NSString*) pathType
{
    return [NSDictionary dictionaryWithObjectsAndKeys:path, @"path", pathType, @"type", nil];
}




@end
