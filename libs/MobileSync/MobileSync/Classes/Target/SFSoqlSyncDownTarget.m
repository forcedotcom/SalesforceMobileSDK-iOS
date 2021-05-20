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

#import "SFSoqlSyncDownTarget.h"
#import "SFMobileSyncSyncManager.h"
#import "SFMobileSyncConstants.h"
#import "SFMobileSyncObjectUtils.h"
#import "SFMobileSyncNetworkUtils.h"
#import "SFSDKSoqlMutator.h"

static NSString * const kSFSoqlSyncTargetQuery = @"query";
static NSString * const kSFSoqlSyncTargetMaxBatchSize = @"maxBatchSize";

@interface SFSoqlSyncDownTarget ()

@property (nonatomic, strong, readwrite) NSString* nextRecordsUrl;

@end

@implementation SFSoqlSyncDownTarget

- (instancetype)initWithDict:(NSDictionary *)dict {
    self = [super initWithDict:dict];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeSoql;
        self.query = dict[kSFSoqlSyncTargetQuery];
        NSNumber* maxBatchSize = dict[kSFSoqlSyncTargetMaxBatchSize];
        self.maxBatchSize = maxBatchSize != nil ? [maxBatchSize integerValue] : kSFRestSOQLDefaultBatchSize;
        [self modifyQueryIfNeeded];
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeSoql;
    }
    return self;
}

- (void) modifyQueryIfNeeded {
    if (self.query) {
        BOOL mutated = NO;
        SFSDKSoqlMutator* mutator = [SFSDKSoqlMutator withSoql:self.query];
        // Inserts the mandatory 'LastModifiedDate' field if it doesn't exist.
        if (![mutator isSelectingField:self.modificationDateFieldName]) {
            mutated = YES;
            [mutator addSelectFields:self.modificationDateFieldName];
        }
        
        // Inserts the mandatory 'Id' field if it doesn't exist.
        if (![mutator isSelectingField:self.idFieldName]) {
            mutated = YES;
            [mutator addSelectFields:self.idFieldName];
        }
        
        // Order by 'LastModifiedDate' field if no order by specified
        if (![mutator hasOrderBy]) {
            mutated = YES;
            [mutator replaceOrderBy:self.modificationDateFieldName];
        }

        if (mutated) {
            self.query = [[mutator asBuilder] build];
        }
    }
}

#pragma mark - Factory methods

+ (SFSoqlSyncDownTarget*) newSyncTarget:(NSString*)query {
    return [SFSoqlSyncDownTarget newSyncTarget:query maxBatchSize:kSFRestSOQLDefaultBatchSize];
}

+ (SFSoqlSyncDownTarget*) newSyncTarget:(NSString*)query maxBatchSize:(NSInteger)maxBatchSize {
    SFSoqlSyncDownTarget* syncTarget = [[SFSoqlSyncDownTarget alloc] init];
    syncTarget.queryType = SFSyncDownTargetQueryTypeSoql;
    syncTarget.query = query;
    syncTarget.maxBatchSize = maxBatchSize;
    [syncTarget modifyQueryIfNeeded];
    return syncTarget;
}

#pragma mark - From/to dictionary

- (NSMutableDictionary*) asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFSoqlSyncTargetQuery] = self.query;
    dict[kSFSoqlSyncTargetMaxBatchSize] = [NSNumber numberWithInteger: self.maxBatchSize];
    return dict;
}

# pragma mark - Data fetching

- (void) startFetch:(SFMobileSyncSyncManager*)syncManager
        maxTimeStamp:(long long)maxTimeStamp
        errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
        completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock
{
    [self startFetch:syncManager
          queryToRun:[self getQueryToRun:maxTimeStamp]
          errorBlock:errorBlock
       completeBlock:completeBlock];
}

- (void) startFetch:(SFMobileSyncSyncManager*)syncManager
        queryToRun:(NSString *)queryToRun
        errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    __weak typeof(self) weakSelf = self;
    
    SFRestRequest* request = [self buildRequest:queryToRun];
    [SFMobileSyncNetworkUtils sendRequestWithMobileSyncUserAgent:request failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
        errorBlock(e);
    } successBlock:^(NSDictionary *responseJson, NSURLResponse *rawResponse) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.totalSize = [responseJson[kResponseTotalSize] integerValue];
        strongSelf.nextRecordsUrl = responseJson[kResponseNextRecordsUrl];
        completeBlock([strongSelf getRecordsFromResponse:responseJson]);
    }];
}

- (SFRestRequest*) buildRequest:(NSString *)queryToRun {
    return [[SFRestAPI sharedInstance] requestForQuery:queryToRun apiVersion:nil batchSize:self.maxBatchSize];
}

- (void) continueFetch:(SFMobileSyncSyncManager *)syncManager
            errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
         completeBlock:(nullable SFSyncDownTargetFetchCompleteBlock)completeBlock {
    if (self.nextRecordsUrl) {
        __weak typeof(self) weakSelf = self;
        SFRestRequest* request = [SFRestRequest requestWithMethod:SFRestMethodGET path:self.nextRecordsUrl queryParams:nil];
        [SFMobileSyncNetworkUtils sendRequestWithMobileSyncUserAgent:request failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
            errorBlock(e);
        } successBlock:^(NSDictionary *responseJson, NSURLResponse *rawResponse) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            strongSelf.nextRecordsUrl = responseJson[kResponseNextRecordsUrl];
            completeBlock([strongSelf getRecordsFromResponse:responseJson]);
        }];
    } else {
        completeBlock(nil);
    }
}

- (NSArray<NSDictionary *> *)getRecordsFromResponse:(NSDictionary *)responseJson {
    return responseJson[kResponseRecords];
}

- (void)getRemoteIds:(SFMobileSyncSyncManager *)syncManager
            localIds:(NSArray *)localIds
          errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
       completeBlock:(nullable SFSyncDownTargetFetchCompleteBlock)completeBlock {
    if (localIds == nil) {
        completeBlock(nil);
        return;
    }
    NSString* soql = [self getSoqlForRemoteIds];
    __block NSMutableSet* remoteIds = [NSMutableSet new];
    NSString* idFieldName = self.idFieldName;
    __block SFSyncDownTargetFetchCompleteBlock fetchBlockRecurse = ^(NSArray *records) {};
    
    SFSyncDownTargetFetchErrorBlock fetchErrorBlock = ^(NSError *error) {
        fetchBlockRecurse = nil;
        errorBlock(error);
    };
    
    SFSyncDownTargetFetchCompleteBlock fetchBlock = ^(NSArray* records) {
        if (records == nil) {
            completeBlock([remoteIds allObjects]);
            fetchBlockRecurse = nil;
            return;
        }
        
        NSError* error = nil;
        if (![syncManager checkAcceptingSyncs:&error]) {
            errorBlock(error);
            return;
        }
        
        for (NSDictionary * record in records) {
            [remoteIds addObject:record[idFieldName]];
        }
        
        [self continueFetch:syncManager errorBlock:fetchErrorBlock completeBlock:fetchBlockRecurse];
    };
    fetchBlockRecurse = fetchBlock;
    [self startFetch:syncManager queryToRun:soql errorBlock:errorBlock completeBlock:fetchBlock];
}

-(BOOL) isSyncDownSortedByLatestModification {
    return [[SFSDKSoqlMutator withSoql:self.query] isOrderingBy:self.modificationDateFieldName];
}

#pragma mark - Utility methods

- (NSSet<NSString*>*) parseIdsFromResponse:(NSArray*)records {
    NSMutableSet<NSString*>* remoteIds = [NSMutableSet new];
    for (NSDictionary * record in records) {
        [remoteIds addObject:record[self.idFieldName]];
    }
    return remoteIds;
}

- (NSString *)getSoqlForRemoteIds {
    return [[[[[SFSDKSoqlMutator withSoql:self.query] replaceSelectFields:self.idFieldName] replaceOrderBy:@""] asBuilder] build];
}

- (NSString*) getQueryToRun {
    return [self getQueryToRun:0];
}

- (NSString*) getQueryToRun:(long long)maxTimeStamp {
    NSString* queryToRun = self.query;
    if (maxTimeStamp > 0) {
        queryToRun = [SFSoqlSyncDownTarget addFilterForReSync:self.query modDateFieldName:self.modificationDateFieldName maxTimeStamp:maxTimeStamp];
    }
    return queryToRun;
}

+ (NSString*) addFilterForReSync:(NSString*)query modDateFieldName:(NSString *)modDateFieldName maxTimeStamp:(long long)maxTimeStamp {
    NSString* queryToRun = query;
    if (maxTimeStamp > 0) {
        NSString* maxTimeStampStr = [SFMobileSyncObjectUtils getIsoStringFromMillis:maxTimeStamp];
        NSString* extraPredicate =  [@[modDateFieldName, @">", maxTimeStampStr] componentsJoinedByString:@" "];
        queryToRun = [[[[SFSDKSoqlMutator withSoql:query] addWherePredicates:extraPredicate] asBuilder] build];
    }
    return queryToRun;
}

+ (NSString*) appendToFirstOccurence:(NSString*)str pattern:(NSString*)pattern stringToAppend:(NSString*)stringToAppend {
    NSRegularExpression* regexp = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    NSRange rangeFirst = [regexp rangeOfFirstMatchInString:str options:0 range:NSMakeRange(0, [str length])];
    NSString* firstMatch = [str substringWithRange:rangeFirst];
    NSString* modifiedStr = [str stringByReplacingCharactersInRange:rangeFirst withString:[@[firstMatch, stringToAppend] componentsJoinedByString:@""]];
    return modifiedStr;
}

@end
