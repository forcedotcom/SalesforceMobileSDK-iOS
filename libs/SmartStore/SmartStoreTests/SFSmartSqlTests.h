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

//  Logic unit tests contain unit test code that is designed to be linked into an independent test executable.
//  See Also: http://developer.apple.com/iphone/library/documentation/Xcode/Conceptual/iphone_development/135-Unit_Testing_Applications/unit_testing_applications.html

#import "SFSmartStoreTestCase.h"

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
#define kIsManager            @"isManager"

@interface SFSmartSqlTests : SFSmartStoreTestCase
- (SFUserAccount*) createUserAccount;
- (void) testSharedInstance;
- (void) testConvertSmartSqlWithInsertUpdateDelete;
- (void) testSimpleConvertSmartSql;
- (void) testConvertSmartSqlWithJoin;
- (void) testConvertSmartSqlWithSelfJoin;
- (void) testConvertSmartSqlWithSpecialColumns;
- (void) testConvertSmartSqlWithSpecialColumnsAndJoin;
- (void) testConvertSmartSqlWithSpecialColumnsAndSelfJoin;
- (void) testConvertSmartSqlWithJSON1;
- (void) testConvertSmartSqlWithJSON1AndTableQualifiedColumn;
- (void) testConvertSmartSqlWithJSON1AndTableAliases;
- (void) testSmartQueryDoingCount;
- (void) testSmartQueryDoingSum;
- (void) testSmartQueryReturningOneRowWithOneInteger;
- (void) testSmartQueryReturningOneRowWithTwoIntegers;
- (void) testSmartQueryReturningTwoRowsWithOneIntegerEach;
- (void) testSmartQueryReturningSoupStringAndInteger;
- (void) testSmartQueryWithPaging;
- (void) testSmartQueryWithSpecialFields;
- (void) testSmartQueryMatchingNullField;
@end
