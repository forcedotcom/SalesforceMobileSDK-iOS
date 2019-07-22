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

#import <XCTest/XCTest.h>
#import "SFSmartSqlCache.h"

@interface SFSmartSqlCacheTests : XCTestCase

@end

@implementation SFSmartSqlCacheTests

- (void) testReadWriteToCache {
    SFSmartSqlCache* cache = [[SFSmartSqlCache alloc] initWithCountLimit:10];
    // Caching one sql
    [cache setSql:@"select * from table_1" forSmartSql:@"select * from {employees}"];
    // Getting it back
    XCTAssertEqual(@"select * from table_1", [cache sqlForSmartSql:@"select * from {employees}"]);
    // Looking for something not in cache
    XCTAssertNil([cache sqlForSmartSql:@"select * from {departments}"]);
}

- (void) testWriteToCachePastCountLimit {
    SFSmartSqlCache* cache = [[SFSmartSqlCache alloc] initWithCountLimit:2];
    // Caching 3 sqls in cache allowing 2
    [cache setSql:@"select * from table_1" forSmartSql:@"select * from {employees}"];
    [cache setSql:@"select * from table_2" forSmartSql:@"select * from {departments}"];
    [cache setSql:@"select * from table_3" forSmartSql:@"select * from {regions}"];
    // Trying to get all 3 back (last 2 should be found only)
    XCTAssertNil([cache sqlForSmartSql:@"select * from {employees}"]);
    XCTAssertEqual(@"select * from table_2", [cache sqlForSmartSql:@"select * from {departments}"]);
    XCTAssertEqual(@"select * from table_3", [cache sqlForSmartSql:@"select * from {regions}"]);
    // Caching 1 more
    [cache setSql:@"select * from table_4" forSmartSql:@"select * from {countries}"];
    // Trying to get all 4 back (last 2 should be found only)
    XCTAssertNil([cache sqlForSmartSql:@"select * from {employees}"]);
    XCTAssertNil([cache sqlForSmartSql:@"select * from {departments}"]);
    XCTAssertEqual(@"select * from table_3", [cache sqlForSmartSql:@"select * from {regions}"]);
    XCTAssertEqual(@"select * from table_4", [cache sqlForSmartSql:@"select * from {countries}"]);
}

- (void) testRemoveEntriesForSoupFromCache {
    SFSmartSqlCache* cache = [[SFSmartSqlCache alloc] initWithCountLimit:5];
    // Caching sqls some of which involve employees soup
    [cache setSql:@"select * from table_1" forSmartSql:@"select * from {employees}"];
    [cache setSql:@"select * from table_2,table_1" forSmartSql:@"select * from {departments},{employees}"];
    [cache setSql:@"select * from table_3" forSmartSql:@"select * from {regions}"];
    // Make sure all sqls can be found
    XCTAssertEqual(@"select * from table_1", [cache sqlForSmartSql:@"select * from {employees}"]);
    XCTAssertEqual(@"select * from table_2,table_1", [cache sqlForSmartSql:@"select * from {departments},{employees}"]);
    XCTAssertEqual(@"select * from table_3", [cache sqlForSmartSql:@"select * from {regions}"]);
    // Removing sqls for employees soup
    [cache removeEntriesForSoup:@"employees"];
    // Make related sqls can no longer be found
    XCTAssertNil([cache sqlForSmartSql:@"select * from {employees}"]);
    XCTAssertNil([cache sqlForSmartSql:@"select * from {departments},{employees}"]);
    XCTAssertEqual(@"select * from table_3", [cache sqlForSmartSql:@"select * from {regions}"]);
}

@end
