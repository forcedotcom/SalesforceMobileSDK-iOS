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

@interface SFSmartSqlHelperTests ()
@end

@implementation SFSmartSqlHelperTests


#pragma mark - setup and teardown


- (void) setUp
{
    [super setUp];
}

- (void) tearDown
{
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
    SFSmartSqlHelper* helper = [SFSmartSqlHelper sharedInstance];
    STAssertNil([helper convertSmartSql:@"insert into {employees}" withDb:nil], @"Should have returned nil for a insert query");
    STAssertNil([helper convertSmartSql:@"update {employees}" withDb:nil], @"Should have returned nil for a update query");
    STAssertNil([helper convertSmartSql:@"delete from {employees}" withDb:nil], @"Should have returned nil for a delete query");
    STAssertNotNil([helper convertSmartSql:@"select * from {employees}" withDb:nil], @"Should not have returned nil for a proper query");
}

@end
