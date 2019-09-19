/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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

#import "TestSyncDownTarget.h"

static NSString * const kTestSyncDownTargetPrefix = @"prefix";
static NSString * const kTestSyncDownTargetNumberOfRecords = @"numberOfRecords";
static NSString * const kTestSyncDownTargetNumberOfRecordsPerPage = @"numberOfRecordsPerPage";
static NSString * const kTestSyncDownTargetSleepPerFetch = @"sleepPerFetch";

@interface TestSyncDownTarget ()

@property (nonatomic, strong) NSString* prefix;
@property (nonatomic) NSUInteger numberOfRecords;
@property (nonatomic) NSUInteger numberOfRecordsPerPage;
@property (nonatomic) NSTimeInterval sleepPerFetch;
@property (nonatomic, strong) NSArray* records;
@property (nonatomic) NSUInteger position;

@end

@implementation TestSyncDownTarget

- (instancetype)initWithDict:(NSDictionary *)dict {
    return [self initWithPrefix:dict[kTestSyncDownTargetPrefix]
             numberOfRecords:[((NSNumber*) dict[kTestSyncDownTargetNumberOfRecords]) intValue]
      numberOfRecordsPerPage:[((NSNumber*) dict[kTestSyncDownTargetNumberOfRecordsPerPage]) intValue]
               sleepPerFetch:[((NSNumber*) dict[kTestSyncDownTargetSleepPerFetch]) doubleValue]];
}

- (instancetype) initWithPrefix:(NSString*)prefix
         numberOfRecords:(NSUInteger)numberOfRecords
  numberOfRecordsPerPage:(NSUInteger)numberOfRecordsPerPage
           sleepPerFetch:(NSTimeInterval)sleepPerFetch
{
    self = [super init];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeCustom;
        self.prefix = prefix;
        self.numberOfRecords = numberOfRecords;
        self.numberOfRecordsPerPage = numberOfRecordsPerPage;
        self.sleepPerFetch = sleepPerFetch;
        self.records = [self createRecords:numberOfRecords];
    }
    return self;
}

- (NSMutableDictionary*) asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kTestSyncDownTargetPrefix] = self.prefix;
    dict[kTestSyncDownTargetNumberOfRecords] = @(self.numberOfRecords);
    dict[kTestSyncDownTargetNumberOfRecordsPerPage] = @(self.numberOfRecordsPerPage);
    dict[kTestSyncDownTargetSleepPerFetch] = @(self.sleepPerFetch);
    return dict;
}

- (NSArray*) createRecords:(NSUInteger)numberOfRecords {
    NSMutableArray* records = [NSMutableArray new];
    for (int i=0; i<numberOfRecords; i++) {
        NSMutableDictionary* record = [NSMutableDictionary new];
        record[kId] = [self idForPosition:i];
        record[kLastModifiedDate] = [SFMobileSyncObjectUtils getIsoStringFromMillis:[self dateForPositionAsMillis:i]];
        [records addObject:record];
    }
    return records;
}


- (NSArray*) recordsFromPosition {
    if (self.position >= self.numberOfRecords) {
        return nil;
    }
    
    NSMutableArray* arrayForPage = [NSMutableArray new];
    NSUInteger i = self.position;
    NSUInteger limit = self.position + self.numberOfRecordsPerPage;
    if (limit > self.numberOfRecords) limit = self.numberOfRecords;
    
    do {
        [arrayForPage addObject:self.records[i]];
        i++;
    } while (i < limit);
    self.position = i;
    return arrayForPage;
}

- (BOOL) isSyncDownSortedByLatestModification {
    return YES;
}

- (void) startFetch:(SFMobileSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock
{
    self.position = [self positionForDate:maxTimeStamp];
    self.totalSize = self.numberOfRecords - self.position;
    [self sleepIfNeeded];
    completeBlock([self recordsFromPosition]);
}

- (void) sleepIfNeeded {
    if (self.sleepPerFetch > 0) {
        [NSThread sleepForTimeInterval:self.sleepPerFetch];
    }
}

- (void) continueFetch:(SFMobileSyncSyncManager *)syncManager
            errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
         completeBlock:(nullable SFSyncDownTargetFetchCompleteBlock)completeBlock {
    [self sleepIfNeeded];
    completeBlock([self recordsFromPosition]);
}

- (void)getRemoteIds:(SFMobileSyncSyncManager *)syncManager
            localIds:(NSArray *)localIds
          errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
       completeBlock:(nullable SFSyncDownTargetFetchCompleteBlock)completeBlock {

    NSMutableArray* remoteIds = [NSMutableArray new];
    for (NSDictionary* record in self.records) {
        [remoteIds addObject:record[kId]];
    }
    completeBlock(remoteIds);
}

- (NSString*) idForPosition:(NSUInteger)i {
    return [NSString stringWithFormat:@"%@_%@", self.prefix, @(1000+i)];
}

- (long long) dateForPositionAsMillis:(NSUInteger)i {
    NSCalendar* calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    [comps setYear:2019];
    [comps setMonth:3];
    [comps setDay:1];
    [comps setHour:12];
    [comps setMinute:i/60];
    [comps setSecond:i%60];
    NSDate* date = [calendar dateFromComponents:comps];
    long long millis = date.timeIntervalSince1970 * 1000;
    return millis;
}

- (NSUInteger) positionForDate:(long long) millis {
    for (NSUInteger i=0; i<self.records.count; i++) {
        if ([self dateForPositionAsMillis:i] > millis) {
            return i;
        }
    }
    return self.records.count;
}

@end
