/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

#import "SFSmartStoreFullTextSearchTests.h"
#import "SFSmartStore+Internal.h"
#import "SFSoupIndex.h"
#import "SFQuerySpec.h"
#import "SFJsonUtils.h"

@interface SFSmartStoreFullTextSearchTests ()

@property (nonatomic, strong) SFSmartStore *store;
@property (nonatomic, strong) NSNumber *christineHaasId;
@property (nonatomic, strong) NSNumber *michaelThompsonId;
@property (nonatomic, strong) NSNumber *aliHaasId;
@property (nonatomic, strong) NSNumber *johnGeyerId;
@property (nonatomic, strong) NSNumber *irvingSternId;
@property (nonatomic, strong) NSNumber *evaPulaskiId;
@property (nonatomic, strong) NSNumber *eileenEvaId;

@end

@implementation SFSmartStoreFullTextSearchTests

#define kTestStore            @"testSmartStoreFullTextSearchStore"
#define kEmployeesSoup        @"employees"
#define kFirstName            @"firstName"
#define kLastName             @"lastName"
#define kEmployeeId           @"employeeId"

#pragma mark - setup and teardown

- (void) setUp
{
    [super setUp];
    self.store = [SFSmartStore sharedStoreWithName:kTestStore];
    
    // Employees soup
    [self.store registerSoup:kEmployeesSoup                               // should be TABLE_1
          withIndexSpecs:[SFSoupIndex asArraySoupIndexes:
                          @[[self createFullTextIndexSpec:kFirstName],    // should be TABLE_1_0
                            [self createFullTextIndexSpec:kLastName],     // should be TABLE_1_1
                            [self createStringIndexSpec:kEmployeeId]]]];  // should be TABLE_1_2
}

- (void) tearDown
{
    self.store = nil;
    [SFSmartStore removeSharedStoreWithName:kTestStore];
    [super tearDown];
}

#pragma mark - Tests

/**
 * Test search on single field returning no results
 */
- (void) testSearchSingleFielNoResults
{
    [self loadData];
    
    // One field - full word - no results
    [self trySearch:@[] path:kFirstName matchKey:@"Christina" orderPath:nil];
    [self trySearch:@[] path:kLastName matchKey:@"Sternn" orderPath:nil];
    
    // One field - prefix - no results
    [self trySearch:@[] path:kFirstName matchKey:@"Christo*" orderPath:nil];
    [self trySearch:@[] path:kLastName matchKey:@"Stel*" orderPath:nil];

    // One field - set operation - no results
    [self trySearch:@[] path:kFirstName matchKey:@"Ei* -Eileen" orderPath:nil];
}

/**
 * Test search on single field returning a single result
 */
- (void) testSearchSingleFieldSingleResult
{
    [self loadData];
    
    // One field - full word - one result
    [self trySearch:@[self.christineHaasId] path:kFirstName matchKey:@"Christine" orderPath:nil];
    [self trySearch:@[self.irvingSternId] path:kLastName matchKey:@"Stern" orderPath:nil];
    
    // One field - prefix - one result
    [self trySearch:@[self.christineHaasId] path:kFirstName matchKey:@"Christ*" orderPath:nil];
    [self trySearch:@[self.irvingSternId] path:kLastName matchKey:@"Ste*" orderPath:nil];
    
    // One field - set operation - one result
    [self trySearch:@[self.eileenEvaId] path:kFirstName matchKey:@"E* -Eva" orderPath:nil];
}

#pragma mark - helper methods

- (void) trySearch:(NSArray*)expectedIds path:(NSString*)path matchKey:(NSString*)matchKey orderPath:(NSString*)orderPath
{
    SFQuerySpec* querySpec = [SFQuerySpec newMatchQuerySpec:kEmployeesSoup withPath:path withMatchKey:matchKey withOrderPath:orderPath withOrder:kSFSoupQuerySortOrderAscending withPageSize:25];
    NSArray* results = [self.store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
    XCTAssertEqual(expectedIds.count, results.count, @"Wrong number of results");
    for (int i=0; i<results.count; i++) {
        XCTAssertEqual(((NSNumber*)expectedIds[i]).longValue, ((NSNumber*)results[i][SOUP_ENTRY_ID]).longValue, @"Wrong result");
    }
}


- (void) loadData
{
    self.christineHaasId = [self createEmployeeWithFirstName:@"Christine" lastName:@"Haas" employeeId:@"00010"];
    self.michaelThompsonId = [self createEmployeeWithFirstName:@"Michael" lastName:@"Thompson" employeeId:@"00020"];
    self.aliHaasId = [self createEmployeeWithFirstName:@"Ali" lastName:@"Haas" employeeId:@"00030"];
    self.johnGeyerId = [self createEmployeeWithFirstName:@"John" lastName:@"Geyer" employeeId:@"00040"];
    self.irvingSternId = [self createEmployeeWithFirstName:@"Irving" lastName:@"Stern" employeeId:@"00050"];
    self.evaPulaskiId = [self createEmployeeWithFirstName:@"Eva" lastName:@"Pulaski" employeeId:@"00060"];
    self.eileenEvaId = [self createEmployeeWithFirstName:@"Eileen" lastName:@"Eva" employeeId:@"00070"];
}

- (NSNumber*) createEmployeeWithFirstName:(NSString*)firstName lastName:(NSString*)lastName employeeId:(NSString*)employeeId
{
    NSDictionary* employee = @{kFirstName: firstName, kLastName: lastName, kEmployeeId: employeeId};
    NSDictionary* employeeSaved = [_store upsertEntries:@[employee] toSoup:kEmployeesSoup][0];
    return employeeSaved[SOUP_ENTRY_ID];
}

@end

