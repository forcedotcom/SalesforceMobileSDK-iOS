/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSmartStoreFullTextSearchSpeedTests.h"
#import "SFSmartStore+Internal.h"
#import "SFSoupIndex.h"
#import "SFQuerySpec.h"
#import <SalesforceSDKCore/SFJsonUtils.h>
#import "FMDatabaseQueue.h"
#import "FMDatabase.h"

@interface SFSmartStore ()
- (NSArray*)upsertEntries:(NSArray*)entries toSoup:(NSString*)soupName withExternalIdPath:(NSString *)externalIdPath error:(NSError **)error withDb:(FMDatabase*)db;
@end

@interface SFSmartStoreFullTextSearchSpeedTests ()

@property (nonatomic, strong) SFSmartStore *store;
@property (nonatomic, strong) NSArray* animals;

@end

@implementation SFSmartStoreFullTextSearchSpeedTests

#define kTestStore   @"testSmartStore"
#define kAnimalsSoup @"animals"
#define kText        @"text"

#pragma mark - setup and teardown

- (void) setUp
{
    [super setUp];
    self.store = [SFSmartStore sharedGlobalStoreWithName:kTestStore];
    self.animals = @[@"alligator", @"ant", @"bear", @"bee", @"bird", @"camel", @"cat",
                     @"cheetah", @"chicken", @"chimpanzee", @"cow", @"crocodile", @"deer", @"dog", @"dolphin",
                     @"duck", @"eagle", @"elephant", @"fish", @"fly", @"fox", @"frog", @"giraffe", @"goat",
                     @"goldfish", @"hamster", @"hippopotamus", @"horse", @"iguana", @"impala", @"jaguar", @"jellyfish", @"kangaroo", @"kitten", @"lion",
                     @"lobster", @"monkey", @"nightingale", @"octopus", @"owl", @"panda", @"pig", @"puppy", @"quail", @"rabbit", @"rat",
                     @"scorpion", @"seal", @"shark", @"sheep", @"snail", @"snake", @"spider", @"squirrel",
                     @"tiger", @"turtle", @"umbrellabird", @"vulture", @"wolf", @"xantus", @"xerus", @"yak"];
}

- (void) tearDown
{
    [self.store removeAllSoups];
    [SFSmartStore removeSharedGlobalStoreWithName:kTestStore];
    [super tearDown];
    self.store = nil;
    self.animals = nil;
}

#pragma mark - Tests

- (void) testSearch1000RowsOneMatch
{
    [self trySearch:40 matchingRowsPerAnimal:1];
}

- (void) testSearch1000RowsManyMatches
{
    [self trySearch:40 matchingRowsPerAnimal:40];
}


// Slow - uncomment when collecting performance data
/*
- (void) testSearch10000RowsOneMatch
{
    [self trySearch:400 matchingRowsPerAnimal:1];
}

- (void) testSearch10000RowsManyMatches
{
    [self trySearch:400 matchingRowsPerAnimal:400];
}

- (void) testSearch100000RowsManyMatches
{
    [self trySearch:4000 matchingRowsPerAnimal:1];
}
*/
 
#pragma mark - Helper methods

- (void) trySearch:(int)rowsPerAnimal matchingRowsPerAnimal:(int)matchingRowsPerAnimal
{
    double totalInsertTimeString = [self setupData:kSoupIndexTypeString rowsPerAnimal:rowsPerAnimal matchingRowsPerAnimal:matchingRowsPerAnimal];
    double avgQueryTimeString = [self queryData:kSoupIndexTypeString rowsPerAnimal:rowsPerAnimal matchingRowsPerAnimal:matchingRowsPerAnimal];
    [self.store removeAllSoups];
    double totalInsertTimeFullText = [self setupData:kSoupIndexTypeFullText rowsPerAnimal:rowsPerAnimal matchingRowsPerAnimal:matchingRowsPerAnimal];
    double avgQueryTimeFullText = [self queryData:kSoupIndexTypeFullText rowsPerAnimal:rowsPerAnimal matchingRowsPerAnimal:matchingRowsPerAnimal];
    [self.store removeAllSoups];
    
    NSLog(@"Search rows=%d matchingRows=%d avgQueryTimeString=%.4fs avgQueryTimeFullText=%.4fs (%.2f%%) totalInsertTimeString=%.3fs totalInsertTimeFullText=%.3fs (%.2f%%)",
          rowsPerAnimal * 25,
          matchingRowsPerAnimal,
          avgQueryTimeString,
          avgQueryTimeFullText,
          100*avgQueryTimeFullText / avgQueryTimeString,
          totalInsertTimeString,
          totalInsertTimeFullText,
          100*totalInsertTimeFullText / totalInsertTimeString);
}


- (double) setupData:(NSString*)textFieldType rowsPerAnimal:(int)rowsPerAnimal matchingRowsPerAnimal:(int)matchingRowsPerAnimal
{
    NSArray* soupIndices = [SFSoupIndex asArraySoupIndexes:@[@{kSoupIndexPath:kText, kSoupIndexType:textFieldType}]];
    [self.store registerSoup:kAnimalsSoup withIndexSpecs:soupIndices error:nil];

    __block int rowCount = 0;
    __block double totalInsertTime = 0.0;
    for (int i=0; i < 25; i++) {
        __block int charToMatch = i + 'a';
        [self.store.storeQueue inDatabase:^(FMDatabase *db) {
            for (int j=0; j < rowsPerAnimal; j++) {
                NSString* prefix = [NSString stringWithFormat:@"%07d", j % (rowsPerAnimal / matchingRowsPerAnimal)];
                NSMutableString* text = [NSMutableString new];
                for (NSString* animal in self.animals) {
                    if ([animal characterAtIndex:0] == charToMatch) {
                        [text appendFormat:@"%@%@ ", prefix, animal];
                    }
                }
                NSDate *start = [NSDate date];
                [self.store upsertEntries:@[ @{kText: text} ] toSoup:kAnimalsSoup withExternalIdPath:nil error:nil withDb:db];
                rowCount++;
                if (rowCount % 100 == 0) { NSLog(@"Rows inserted %d", rowCount); }
                totalInsertTime += [[NSDate date] timeIntervalSinceDate:start];
            }
        }];
    }
    
    return totalInsertTime;
}

/**
 * @return avg query time in seconds
 */
- (double) queryData:(NSString*)textFieldType rowsPerAnimal:(int)rowsPerAnimal matchingRowsPerAnimal:(int)matchingRowsPerAnimal
{
    double totalQueryTime = 0.0;
    for (NSString* animal in self.animals) {
        NSString* prefix = [NSString stringWithFormat:@"%07d", arc4random_uniform(rowsPerAnimal/matchingRowsPerAnimal)];
        NSString* matchKey = [@[prefix, animal] componentsJoinedByString:@""];
        NSString* likeKey = [@[@"%", matchKey, @"%"] componentsJoinedByString:@""];
        SFQuerySpec* querySpec;
        if ([textFieldType isEqualToString:kSoupIndexTypeFullText]) {
            querySpec = [SFQuerySpec newMatchQuerySpec:kAnimalsSoup withPath:kText withMatchKey:matchKey withOrderPath:nil withOrder:kSFSoupQuerySortOrderAscending withPageSize:rowsPerAnimal];
        }
        else {
            querySpec = [SFQuerySpec newLikeQuerySpec:kAnimalsSoup withPath:kText withLikeKey:likeKey withOrderPath:nil withOrder:kSFSoupQuerySortOrderAscending withPageSize:rowsPerAnimal];
        }

        NSDate *start = [NSDate date];
        NSArray* results = [self.store queryWithQuerySpec:querySpec pageIndex:0 error:nil];
        totalQueryTime += [[NSDate date] timeIntervalSinceDate:start];
        [self validateResults:matchingRowsPerAnimal stringToMatch:matchKey results:results];
    }
    
    return totalQueryTime / self.animals.count;
}

- (void) validateResults:(int) expectedRows stringToMatch:(NSString*)stringToMatch results:(NSArray*)results
{
    XCTAssertEqual(results.count, expectedRows, @"Wrong number of results");
    for (NSDictionary* result in results) {
        NSString* text = result[kText];
        XCTAssertNotEqual([text rangeOfString:stringToMatch].location, NSNotFound, @"Invalid result");
    }
}

@end
