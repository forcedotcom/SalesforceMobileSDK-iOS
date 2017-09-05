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

#import "SFSmartStoreLoadTests.h"
#import "SFSmartStore+Internal.h"
#import "SFSoupIndex.h"
#import "SFQuerySpec.h"
#import <SalesforceSDKCore/SFJsonUtils.h>
#import "FMDatabaseQueue.h"
#import "FMDatabase.h"

@interface SFSmartStoreLoadTests ()

@property (nonatomic, strong) SFUserAccount *smartStoreUser;
@property (nonatomic, strong) SFSmartStore *store;

@end

@implementation SFSmartStoreLoadTests

#define NUMBER_ENTRIES           1000//0
#define NUMBER_ENTRIES_PER_BATCH 100
#define MS_IN_S                  1000
#define TEST_SMARTSTORE          @"testSmartStore"
#define TEST_SOUP                @"testSoup"

#pragma mark - setup and teardown


- (void) setUp
{
    [super setUp];
    [SFSDKSmartStoreLogger setLogLevel:DDLogLevelDebug];
    self.smartStoreUser = [self setUpSmartStoreUser];
    self.store = [SFSmartStore sharedStoreWithName:TEST_SMARTSTORE];
}

- (void) tearDown
{
    [SFSmartStore removeSharedStoreWithName:TEST_SMARTSTORE];
    [self tearDownSmartStoreUser:self.smartStoreUser];
    [super tearDown];
    self.smartStoreUser = nil;
    self.store = nil;
}

#pragma mark - tests

-(void) testUpsertQuery1StringIndex1field20characters
{
    [self tryUpsertQuery:kSoupIndexTypeString numberEntries:NUMBER_ENTRIES numberFieldsPerEntry:1 numberCharactersPerField:20 numberIndexes:1];
}

-(void) testUpsertQuery1StringIndex1field1000characters
{
    [self tryUpsertQuery:kSoupIndexTypeString numberEntries:NUMBER_ENTRIES numberFieldsPerEntry:1 numberCharactersPerField:1000 numberIndexes:1];
}

-(void) testUpsertQuery1StringIndex10fields20characters
{
    [self tryUpsertQuery:kSoupIndexTypeString numberEntries:NUMBER_ENTRIES numberFieldsPerEntry:10 numberCharactersPerField:20 numberIndexes:1];
}

-(void) testUpsertQuery10StringIndexes10fields20characters
{
    [self tryUpsertQuery:kSoupIndexTypeString numberEntries:NUMBER_ENTRIES numberFieldsPerEntry:10 numberCharactersPerField:20 numberIndexes:10];
}

-(void) testUpsertQuery1JSON1Index1field20characters
{
    [self tryUpsertQuery:kSoupIndexTypeJSON1 numberEntries:NUMBER_ENTRIES numberFieldsPerEntry:1 numberCharactersPerField:20 numberIndexes:1];
}

-(void) testUpsertQuery1JSON1Index1field1000characters
{
    [self tryUpsertQuery:kSoupIndexTypeJSON1 numberEntries:NUMBER_ENTRIES numberFieldsPerEntry:1 numberCharactersPerField:1000 numberIndexes:1];
}

-(void) testUpsertQuery1JSON1Index10fields20characters
{
    [self tryUpsertQuery:kSoupIndexTypeJSON1 numberEntries:NUMBER_ENTRIES numberFieldsPerEntry:10 numberCharactersPerField:20 numberIndexes:1];
}

-(void)testUpsertQuery10JSON1Indexes10fields20characters
{
    [self tryUpsertQuery:kSoupIndexTypeJSON1 numberEntries:NUMBER_ENTRIES numberFieldsPerEntry:10 numberCharactersPerField:20 numberIndexes:10];
}

-(void) testAlterSoupClassicIndexing
{
    [self tryAlterSoup:kSoupIndexTypeString];
}
     
-(void) testAlterSoupJSON1Indexing
{
    [self tryAlterSoup:kSoupIndexTypeJSON1];
}

    
#pragma mark - helper methods


-(void) tryUpsertQuery:(NSString*)indexType
         numberEntries:(NSUInteger)numberEntries
  numberFieldsPerEntry:(NSUInteger)numberFieldsPerEntry
numberCharactersPerField:(NSUInteger)numberCharactersPerField
         numberIndexes:(NSUInteger)numberIndexes
{
    [self setupSoup:TEST_SOUP numberIndexes:numberIndexes indexType:indexType];
    [self upsertEntries:numberEntries / NUMBER_ENTRIES_PER_BATCH numberEntriesPerBatch:NUMBER_ENTRIES_PER_BATCH numberFieldsPerEntry:numberFieldsPerEntry numberCharactersPerField:numberCharactersPerField];
    [self queryEntries];
}
    
-(void) setupSoup:(NSString*)soupName numberIndexes:(NSUInteger)numberIndexes indexType:(NSString*)indexType
{
    NSMutableArray* indexSpecs = [NSMutableArray new];
    for (NSUInteger indexNumber=0; indexNumber<numberIndexes; indexNumber++) {
        indexSpecs[indexNumber] = @{kSoupIndexPath:[NSString stringWithFormat:@"k_%tu", indexNumber], kSoupIndexType:indexType};
    }
    NSError* error = nil;
    [self.store registerSoup:TEST_SOUP withIndexSpecs:[SFSoupIndex asArraySoupIndexes:indexSpecs] error:&error];
    XCTAssertNil(error, @"There should be no errors.");
    [SFSDKSmartStoreLogger d:[self class] format:@"Creating table with %u %@ indexes", numberIndexes, indexType];
}
    
-(void) upsertEntries:(NSUInteger)numberBatches numberEntriesPerBatch:(NSUInteger)numberEntriesPerBatch numberFieldsPerEntry:(NSUInteger)numberFieldsPerEntry numberCharactersPerField:(NSUInteger)numberCharactersPerField
{
    NSMutableArray* times = [NSMutableArray new];
    for (NSUInteger batchNumber=0; batchNumber<numberBatches; batchNumber++) {
        NSDate* start = [NSDate date];
        NSMutableArray* entries = [NSMutableArray arrayWithCapacity:numberEntriesPerBatch];
        for (NSUInteger entryNumber=0; entryNumber<numberEntriesPerBatch; entryNumber++) {
            NSMutableDictionary* entry = [NSMutableDictionary new];
            for (NSUInteger fieldNumber=0; fieldNumber<numberFieldsPerEntry; fieldNumber++) {
                NSString* value = [self pad:[NSString stringWithFormat:@"v_%lu_%lu_%lu_", (unsigned long)batchNumber, (unsigned long)entryNumber, (unsigned long)fieldNumber] numberCharacters:numberCharactersPerField];
                entry[[NSString stringWithFormat:@"k_%lu", (unsigned long)fieldNumber]] = value;
            }
            [entries addObject:entry];
        }
        [self.store upsertEntries:entries toSoup:TEST_SOUP];
        NSDate* end = [NSDate date];
        [times addObject:[NSNumber numberWithDouble:[end timeIntervalSinceDate:start]*MS_IN_S]];
    }
    double avgMilliseconds = [self average:times];
    [SFSDKSmartStoreLogger d:[self class] format:@"Upserting %u entries with %u per batch with %u fields with %u characters: average time per batch --> %.3f ms",
        numberBatches * numberEntriesPerBatch, numberEntriesPerBatch, numberFieldsPerEntry, numberCharactersPerField, avgMilliseconds];
}
    
-(void) queryEntries
{
    // Should find all
//    [self queryEntries:[SFQuerySpec newAllQuerySpec:TEST_SOUP withOrderPath:nil withOrder:kSFSoupQuerySortOrderAscending withPageSize:1]];
    [self queryEntries:[SFQuerySpec newAllQuerySpec:TEST_SOUP withOrderPath:nil withOrder:kSFSoupQuerySortOrderAscending withPageSize:10]];
    [self queryEntries:[SFQuerySpec newAllQuerySpec:TEST_SOUP withOrderPath:nil withOrder:kSFSoupQuerySortOrderAscending withPageSize:100]];

    // Should find 100
    [self queryEntries:[SFQuerySpec newLikeQuerySpec:TEST_SOUP withPath:@"k_0" withLikeKey:@"v_0_%" withOrderPath:nil withOrder:kSFSoupQuerySortOrderAscending withPageSize:1]];
    [self queryEntries:[SFQuerySpec newLikeQuerySpec:TEST_SOUP withPath:@"k_0" withLikeKey:@"v_0_%" withOrderPath:nil withOrder:kSFSoupQuerySortOrderAscending withPageSize:10]];
    [self queryEntries:[SFQuerySpec newLikeQuerySpec:TEST_SOUP withPath:@"k_0" withLikeKey:@"v_0_%" withOrderPath:nil withOrder:kSFSoupQuerySortOrderAscending withPageSize:100]];
    
    // Should find 10
    [self queryEntries:[SFQuerySpec newLikeQuerySpec:TEST_SOUP withPath:@"k_0" withLikeKey:@"v_0_0_%" withOrderPath:nil withOrder:kSFSoupQuerySortOrderAscending withPageSize:1]];
    [self queryEntries:[SFQuerySpec newLikeQuerySpec:TEST_SOUP withPath:@"k_0" withLikeKey:@"v_0_0_%" withOrderPath:nil withOrder:kSFSoupQuerySortOrderAscending withPageSize:10]];

    // Should find none
    [self queryEntries:[SFQuerySpec newExactQuerySpec:TEST_SOUP withPath:@"k_0" withMatchKey:@"missing" withOrderPath:nil withOrder:kSFSoupQuerySortOrderAscending withPageSize:1]];
}
    
    
-(void) queryEntries:(SFQuerySpec*) querySpec
{
    NSMutableArray* times = [NSMutableArray new];
    NSUInteger countMatches = 0;
    BOOL hasMore = YES;
    for (NSUInteger pageIndex = 0; hasMore; pageIndex++) {
        NSDate* start = [NSDate date];
        
        NSError* error = nil;
        NSArray* results = [self.store queryWithQuerySpec:querySpec pageIndex:pageIndex error:&error];
        XCTAssertNil(error, @"There should be no errors.");

        NSDate* end = [NSDate date];
        [times addObject:[NSNumber numberWithDouble:[end timeIntervalSinceDate:start]*MS_IN_S]];
        hasMore = (results.count == querySpec.pageSize);
        countMatches += results.count;
    }
    double avgMilliseconds = [self average:times];
    [SFSDKSmartStoreLogger d:[self class] format:@"Querying with %@ query matching %u entries and %u page size: average time per page --> %.3f ms",
        [querySpec asDictionary][kQuerySpecParamQueryType], countMatches, querySpec.pageSize, avgMilliseconds];
}
    
-(NSString*) pad:(NSString*)s numberCharacters:(NSUInteger)numberCharacters
{
    NSMutableString* result = [NSMutableString stringWithCapacity:numberCharacters];
    [result appendString:s];
    for (NSUInteger i=s.length; i<numberCharacters; i++) {
        [result appendString:@"x"];
    }
    return result;
}
    
-(double) average:(NSArray*)times
{
    double avg = 0;
    for (NSUInteger i=0; i<times.count; i++) {
        avg += ((NSNumber*)times[i]).doubleValue;
    }
    return avg/times.count;
}
    
-(void) tryAlterSoup:(NSString*)indexType
{
    [SFSDKSmartStoreLogger d:[self class] format:@"Initial database size: %u bytes", [self.store getDatabaseSize]];
    [self setupSoup:TEST_SOUP numberIndexes:1 indexType:indexType];
    [self upsertEntries:NUMBER_ENTRIES / NUMBER_ENTRIES_PER_BATCH numberEntriesPerBatch:NUMBER_ENTRIES_PER_BATCH numberFieldsPerEntry:10 numberCharactersPerField:20];
    [SFSDKSmartStoreLogger d:[self class] format:@"Database size after: %u bytes", [self.store getDatabaseSize]];
    
    // Without indexing for new index specs
    [self alterSoup:@"Adding one index / no re-indexing" reIndexData:NO indexSpecs:[SFSoupIndex asArraySoupIndexes:@[ @{kSoupIndexPath:@"k_0", kSoupIndexType:indexType}, @{kSoupIndexPath:@"k_1", kSoupIndexType:indexType} ]]];
    [self alterSoup:@"Adding one index / dropping one index / no re-indexing" reIndexData:NO indexSpecs:[SFSoupIndex asArraySoupIndexes:@[ @{kSoupIndexPath:@"k_0", kSoupIndexType:indexType}, @{kSoupIndexPath:@"k_2", kSoupIndexType:indexType} ]]];
    [self alterSoup:@"Dropping one index / no re-indexing" reIndexData:NO indexSpecs:[SFSoupIndex asArraySoupIndexes:@[ @{kSoupIndexPath:@"k_0", kSoupIndexType:indexType}]]];
        
    // With indexing for new index specs
    [self alterSoup:@"Adding one index / with re-indexing" reIndexData:YES indexSpecs:[SFSoupIndex asArraySoupIndexes:@[ @{kSoupIndexPath:@"k_0", kSoupIndexType:indexType}, @{kSoupIndexPath:@"k_1", kSoupIndexType:indexType} ]]];
    [self alterSoup:@"Adding one index / dropping one index / with re-indexing" reIndexData:YES indexSpecs:[SFSoupIndex asArraySoupIndexes:@[ @{kSoupIndexPath:@"k_0", kSoupIndexType:indexType}, @{kSoupIndexPath:@"k_2", kSoupIndexType:indexType} ]]];
    [self alterSoup:@"Dropping one index / with re-indexing" reIndexData:YES indexSpecs:[SFSoupIndex asArraySoupIndexes:@[ @{kSoupIndexPath:@"k_0", kSoupIndexType:indexType}]]];
}
    
-(void) alterSoup:(NSString*)msg reIndexData:(BOOL)reIndexData indexSpecs:(NSArray*)indexSpecs
{
    NSDate* start = [NSDate date];
    [self.store alterSoup:TEST_SOUP withIndexSpecs:indexSpecs reIndexData:reIndexData];
    NSDate* end = [NSDate date];
    double duration = [end timeIntervalSinceDate:start] * MS_IN_S;
    [SFSDKSmartStoreLogger d:[self class] format:@"%@ completed in: %.3f ms", msg, duration];
}

@end
