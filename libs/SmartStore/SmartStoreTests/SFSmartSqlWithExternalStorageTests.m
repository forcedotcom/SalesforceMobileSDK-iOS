/*
  Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSmartSqlWithExternalStorageTests.h"
#import "SFSmartSqlHelper.h"
#import "SFSmartStore+Internal.h"
#import "SFSoupIndex.h"
#import "SFQuerySpec.h"
#import <SalesforceSDKCore/SFJsonUtils.h>
#import "SFSoupSpec.h"

@interface SFSmartSqlWithExternalStorageTests ()

@property (nonatomic, strong) SFSmartStore *store;

@end

@implementation SFSmartSqlWithExternalStorageTests

- (void)setUp {
    NSArray *features = @[kSoupFeatureExternalStorage];
    [SFUserAccountManager sharedInstance].currentUser = [super createUserAccount];
    self.store = [SFSmartStore sharedStoreWithName:kTestStore user:[SFUserAccountManager sharedInstance].currentUser];
    
    // Employees soup
    [self.store registerSoupWithSpec:[SFSoupSpec newSoupSpec:kEmployeesSoup withFeatures:features]  // should be TABLE_1
                  withIndexSpecs:[SFSoupIndex asArraySoupIndexes:
                                  @[[self createStringIndexSpec:kFirstName],
                                    [self createStringIndexSpec:kLastName],    // should be TABLE_1_0
                                    [self createStringIndexSpec:kDeptCode],    // should be TABLE_1_1
                                    [self createStringIndexSpec:kEmployeeId],  // should be TABLE_1_2
                                    [self createStringIndexSpec:kManagerId],   // should be TABLE_1_3
                                    [self createFloatingIndexSpec:kSalary]]]
                           error:nil];
    
    // Departments soup
    [self.store registerSoupWithSpec:[SFSoupSpec newSoupSpec:kDepartmentsSoup withFeatures:features] // should be TABLE_2
                  withIndexSpecs:[SFSoupIndex asArraySoupIndexes:
                                  @[[self createStringIndexSpec:kDeptCode],     // should be TABLE_2_0
                                    [self createStringIndexSpec:kName],         // should be TABLE_2_1
                                    [self createIntegerIndexSpec:kBudget]]]
                           error:nil];
}


#pragma mark - tests
// All code under test must be linked into the Unit Test bundle

- (void) testSharedInstance
{
    [super testSharedInstance];
}

- (void) testConvertSmartSqlWithInsertUpdateDelete
{
    [super testConvertSmartSqlWithInsertUpdateDelete];
}

- (void) testSimpleConvertSmartSql
{
    [super testSimpleConvertSmartSql];
}

- (void) testConvertSmartSqlWithJoin
{
    [super testConvertSmartSqlWithJoin];
}

- (void) testConvertSmartSqlWithSelfJoin
{
    [super testConvertSmartSqlWithSelfJoin];
}

- (void) testConvertSmartSqlWithSpecialColumns
{
    NSString *expected = [NSString stringWithFormat:
                          @"select TABLE_1.id, TABLE_1.lastModified, 'TABLE_1' as '%@', TABLE_1.id as '_soupEntryId' from TABLE_1", kSoupFeatureExternalStorage];
    NSString *result = [_store convertSmartSql:@"select {employees:_soupEntryId}, {employees:_soupLastModifiedDate}, {employees:_soup} from {employees}"];
    XCTAssertEqualObjects(expected, result, @"Bad conversion");
}
	
- (void) testConvertSmartSqlWithSpecialColumnsAndJoin
{
    [super testConvertSmartSqlWithSpecialColumnsAndJoin];
}

- (void) testConvertSmartSqlWithSpecialColumnsAndSelfJoin
{
    [super testConvertSmartSqlWithSpecialColumnsAndSelfJoin];
}

- (void) testSmartQueryDoingCount 
{
    [super testSmartQueryDoingCount];
}
	
- (void) testSmartQueryDoingSum 
{
    [super testSmartQueryDoingSum];
}

- (void) testSmartQueryReturningOneRowWithOneInteger 
{
    [super testSmartQueryReturningOneRowWithOneInteger];
}
	
- (void) testSmartQueryReturningOneRowWithTwoIntegers 
{
    [super testSmartQueryReturningOneRowWithTwoIntegers];
}

- (void) testSmartQueryReturningTwoRowsWithOneIntegerEach 
{
    [super testSmartQueryReturningTwoRowsWithOneIntegerEach];
}

- (void) testSmartQueryReturningSoupStringAndInteger 
{
    [super testSmartQueryReturningSoupStringAndInteger];
}
	
- (void) testSmartQueryWithPaging 
{
    [super testSmartQueryWithPaging];
}
    
- (void) testSmartQueryWithSpecialFields 
{
    [super testSmartQueryWithSpecialFields];
}

- (void) testSmartQueryMatchingNullField
{
    [super testSmartQueryMatchingNullField];
}

- (void) testSmartQueryMachingBooleanInJSON1Field
{
    // Doesn't apply to external storage case
}

@end
