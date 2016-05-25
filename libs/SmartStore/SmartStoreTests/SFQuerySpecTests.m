/*
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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

#import "SFQuerySpecTests.h"
#import "SFQuerySpec.h"


@implementation SFQuerySpecTests


#pragma mark - setup and teardown

- (void) setUp
{
    [super setUp];
    [SFLogger setLogLevel:SFLogLevelDebug];
}


#pragma mark - tests
- (void) testAllQuerySmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newAllQuerySpec:@"employees" withOrderPath:@"lastName" withOrder:kSFSoupQuerySortOrderDescending withPageSize:1];
    XCTAssertEqualObjects(@"SELECT {employees:_soup} FROM {employees} ORDER BY {employees}.{employees:lastName} DESC ", querySpec.smartSql, @"Wrong smart sql for all query spec");
}

- (void) testAllQueryCountSmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newAllQuerySpec:@"employees" withOrderPath:@"lastName" withOrder:kSFSoupQuerySortOrderDescending withPageSize:1];
    XCTAssertEqualObjects(@"SELECT count(*) FROM {employees} ", querySpec.countSmartSql, @"Wrong count smart sql for all query spec");
}

- (void) testAllQueryIdsSmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newAllQuerySpec:@"employees" withOrderPath:@"lastName" withOrder:kSFSoupQuerySortOrderDescending withPageSize:1];
    XCTAssertEqualObjects(@"SELECT id FROM {employees} ORDER BY {employees}.{employees:lastName} DESC ", querySpec.idsSmartSql, @"Wrong ids smart sql for all query spec");
}

- (void) testRangeQuerySmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newRangeQuerySpec:@"employees" withPath:@"lastName" withBeginKey:@"Bond" withEndKey:@"Smith" withOrderPath:@"lastName" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    XCTAssertEqualObjects(@"SELECT {employees:_soup} FROM {employees} WHERE {employees:lastName} >= ? AND {employees:lastName} <= ? ORDER BY {employees}.{employees:lastName} ASC ", querySpec.smartSql, @"Wrong smart sql for range query spec");
}

- (void) testRangeQueryCountSmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newRangeQuerySpec:@"employees" withPath:@"lastName" withBeginKey:@"Bond" withEndKey:@"Smith" withOrderPath:@"lastName" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    XCTAssertEqualObjects(@"SELECT count(*) FROM {employees} WHERE {employees:lastName} >= ? AND {employees:lastName} <= ? ", querySpec.countSmartSql, @"Wrong count smart sql for range query spec");
}

- (void) testRangeQueryIdsSmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newRangeQuerySpec:@"employees" withPath:@"lastName" withBeginKey:@"Bond" withEndKey:@"Smith" withOrderPath:@"lastName" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    XCTAssertEqualObjects(@"SELECT id FROM {employees} WHERE {employees:lastName} >= ? AND {employees:lastName} <= ? ORDER BY {employees}.{employees:lastName} ASC ", querySpec.idsSmartSql, @"Wrong ids smart sql for range query spec");
}

- (void) testExactQuerySmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newExactQuerySpec:@"employees" withPath:@"lastName" withMatchKey:@"Bond" withOrderPath:@"lastName" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    XCTAssertEqualObjects(@"SELECT {employees:_soup} FROM {employees} WHERE {employees:lastName} = ? ORDER BY {employees}.{employees:lastName} ASC ", querySpec.smartSql, @"Wrong smart sql for exact query spec");
}

- (void) testExactQueryCountSmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newExactQuerySpec:@"employees" withPath:@"lastName" withMatchKey:@"Bond" withOrderPath:@"lastName" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    XCTAssertEqualObjects(@"SELECT count(*) FROM {employees} WHERE {employees:lastName} = ? ", querySpec.countSmartSql, @"Wrong count smart sql for exact query spec");
}

- (void) testExactQueryIdsSmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newExactQuerySpec:@"employees" withPath:@"lastName" withMatchKey:@"Bond" withOrderPath:@"lastName" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    XCTAssertEqualObjects(@"SELECT id FROM {employees} WHERE {employees:lastName} = ? ORDER BY {employees}.{employees:lastName} ASC ", querySpec.idsSmartSql, @"Wrong ids smart sql for exact query spec");
}

- (void) testMatchQuerySmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newMatchQuerySpec:@"employees" withPath:@"lastName" withMatchKey:@"Bond" withOrderPath:@"firstName" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    XCTAssertEqualObjects(@"SELECT {employees:_soup} FROM {employees}, {employees}_fts WHERE {employees}_fts.docid = {employees:_soupEntryId} AND {employees}_fts.{employees:lastName} MATCH 'Bond' ORDER BY {employees}.{employees:firstName} ASC ", querySpec.smartSql, @"Wrong smart sql for match query spec");
}

- (void) testMatchQueryCountSmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newMatchQuerySpec:@"employees" withPath:@"lastName" withMatchKey:@"Bond" withOrderPath:@"firstName" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    XCTAssertEqualObjects(@"SELECT count(*) FROM {employees}, {employees}_fts WHERE {employees}_fts.docid = {employees:_soupEntryId} AND {employees}_fts.{employees:lastName} MATCH 'Bond' ", querySpec.countSmartSql, @"Wrong count smart sql for match query spec");
}

- (void) testMatchQueryIdsSmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newMatchQuerySpec:@"employees" withPath:@"lastName" withMatchKey:@"Bond" withOrderPath:@"firstName" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    XCTAssertEqualObjects(@"SELECT id FROM {employees}, {employees}_fts WHERE {employees}_fts.docid = {employees:_soupEntryId} AND {employees}_fts.{employees:lastName} MATCH 'Bond' ORDER BY {employees}.{employees:firstName} ASC ", querySpec.idsSmartSql, @"Wrong ids smart sql for match query spec");
}



- (void) testLikeQuerySmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newLikeQuerySpec:@"employees" withPath:@"lastName" withLikeKey:@"Bon%" withOrderPath:@"lastName" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    XCTAssertEqualObjects(@"SELECT {employees:_soup} FROM {employees} WHERE {employees:lastName} LIKE ? ORDER BY {employees}.{employees:lastName} ASC ", querySpec.smartSql, @"Wrong smart sql for like query spec");
}

- (void) testLikeQueryCountSmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newLikeQuerySpec:@"employees" withPath:@"lastName" withLikeKey:@"Bon%" withOrderPath:@"lastName" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    XCTAssertEqualObjects(@"SELECT count(*) FROM {employees} WHERE {employees:lastName} LIKE ? ", querySpec.countSmartSql, @"Wrong count smart sql for like query spec");
}

- (void) testLikeQueryIdsSmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newLikeQuerySpec:@"employees" withPath:@"lastName" withLikeKey:@"Bon%" withOrderPath:@"lastName" withOrder:kSFSoupQuerySortOrderAscending withPageSize:1];
    XCTAssertEqualObjects(@"SELECT id FROM {employees} WHERE {employees:lastName} LIKE ? ORDER BY {employees}.{employees:lastName} ASC ", querySpec.idsSmartSql, @"Wrong ids smart sql for like query spec");
}

- (void) testSmartQueryCountSmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:salary} from {employees} where {employees:lastName} = 'Haas'" withPageSize:1];
    XCTAssertEqualObjects(@"SELECT count(*) FROM (select {employees:salary} from {employees} where {employees:lastName} = 'Haas')", querySpec.countSmartSql, @"Wrong count smart sql");
}

- (void) testSmartQueryIdsSmartSql
{
    SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:@"select {employees:salary} from {employees} where {employees:lastName} = 'Haas'" withPageSize:1];
    XCTAssertEqualObjects(@"SELECT id FROM (select {employees:salary} from {employees} where {employees:lastName} = 'Haas')", querySpec.idsSmartSql, @"Wrong ids smart sql");
}

@end
