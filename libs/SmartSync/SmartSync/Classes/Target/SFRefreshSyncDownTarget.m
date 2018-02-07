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

#import "SFRefreshSyncDownTarget.h"
#import "SFSmartSyncSyncManager.h"
#import <SalesforceSDKCore/SFSDKSoqlBuilder.h>
#import "SFSmartSyncConstants.h"
#import "SFSmartSyncNetworkUtils.h"
#import "SFSmartSyncObjectUtils.h"
#import <SmartStore/SFQuerySpec.h>
#import <SmartStore/SFSmartStore.h>


static NSString * const kSFSyncTargetRefreshSoupName = @"soupName";
static NSString * const kSFSyncTargetRefreshObjectType = @"sobjectType";
static NSString * const kSFSyncTargetRefreshFieldlist = @"fieldlist";
static NSString * const kSFSyncTargetRefreshCountIdsPerSoql = @"coundIdsPerSoql";
static NSUInteger const kSFSyncTargetRefreshDefaultCountIdsPerSoql = 500;


@interface SFRefreshSyncDownTarget ()

@property (nonatomic, strong, readwrite) NSString* soupName;
@property (nonatomic, strong, readwrite) NSString* objectType;
@property (nonatomic, strong, readwrite) NSArray*  fieldlist;
@property (nonatomic, assign, readwrite) NSUInteger countIdsPerSoql;

// NB: For each sync run - a fresh sync down target is created (by deserializing it from smartstore)
// The following members are specific to a run
// page will change during a run as we call start/continueFetch
@property (nonatomic, assign, readwrite) BOOL isResync;
@property (nonatomic, assign, readwrite) NSUInteger page;

@end

@implementation SFRefreshSyncDownTarget

- (instancetype)initWithDict:(NSDictionary *)dict {
    self = [super initWithDict:dict];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeRefresh;
        self.soupName = dict[kSFSyncTargetRefreshSoupName];
        self.objectType = dict[kSFSyncTargetRefreshObjectType];
        self.fieldlist = dict[kSFSyncTargetRefreshFieldlist];
        NSNumber* idsPerSoqlInDict = dict[kSFSyncTargetRefreshCountIdsPerSoql];
        self.countIdsPerSoql = idsPerSoqlInDict == nil ? kSFSyncTargetRefreshDefaultCountIdsPerSoql : [idsPerSoqlInDict unsignedIntegerValue];
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.queryType = SFSyncDownTargetQueryTypeRefresh;
    }
    return self;
}

#pragma mark - Factory methods

+ (SFRefreshSyncDownTarget*) newSyncTarget:(NSString*)soupName objectType:(NSString*)objectType fieldlist:(NSArray*)fieldlist {
    SFRefreshSyncDownTarget* syncTarget = [[SFRefreshSyncDownTarget alloc] init];
    syncTarget.queryType = SFSyncDownTargetQueryTypeRefresh;
    syncTarget.soupName = soupName;
    syncTarget.objectType = objectType;
    syncTarget.fieldlist = fieldlist;
    syncTarget.countIdsPerSoql = kSFSyncTargetRefreshDefaultCountIdsPerSoql;
    return syncTarget;
}

#pragma mark - To dictionary

- (NSMutableDictionary*) asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFSyncTargetRefreshSoupName] = self.soupName;
    dict[kSFSyncTargetRefreshObjectType] = self.objectType;
    dict[kSFSyncTargetRefreshFieldlist] = self.fieldlist;
    dict[kSFSyncTargetRefreshCountIdsPerSoql] = [NSNumber numberWithUnsignedInteger:self.countIdsPerSoql];
    return dict;
}

# pragma mark - Data fetching

- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
         errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {

    // During reSync, we can't make use of the maxTimeStamp that was captured during last refresh
    // since we expect records to have been fetched from the server and written to the soup directly outside a sync down operation
    // Instead during a reSync, we compute maxTimeStamp from the records in the soup
    self.isResync = maxTimeStamp > 0;
    [self getIdsFromSmartStoreAndFetchFromServer:syncManager
                                      errorBlock:errorBlock
                                   completeBlock:completeBlock];
}

- (void) continueFetch:(SFSmartSyncSyncManager*)syncManager
            errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
         completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    if (self.page > 0) {
        [self getIdsFromSmartStoreAndFetchFromServer:syncManager
                                          errorBlock:errorBlock
                                       completeBlock:completeBlock];
    }
    else {
        completeBlock(nil);
    }
}

- (void) getRemoteIds:(SFSmartSyncSyncManager*)syncManager
             localIds:(NSArray*)localIds
           errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
        completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {
    if (localIds == nil) {
        completeBlock(nil);
        return;
    }
    
    __block NSMutableArray* remoteIds = [NSMutableArray new];
    NSUInteger sliceSize = self.countIdsPerSoql;
    NSUInteger countSlices = ceil((float)localIds.count / sliceSize);
    __block NSUInteger slice = 0;
    NSString* idFieldName = self.idFieldName;
    __block SFSyncDownTargetFetchCompleteBlock fetchBlockRecurse = ^(NSArray *records) {};
    
    SFSyncDownTargetFetchErrorBlock fetchErrorBlock = ^(NSError *error) {
        fetchBlockRecurse = nil;
        errorBlock(error);
    };
    
    SFSyncDownTargetFetchCompleteBlock fetchBlock = ^(NSArray* records) {
        // NB with the recursive block, using weakSelf doesn't work (it goes to nil)
        //    are we leaking memory?

        for (NSDictionary * record in records) {
            [remoteIds addObject:record[idFieldName]];
        }

        if (slice < countSlices) {
            NSArray* idsToFetch = [localIds subarrayWithRange:NSMakeRange(slice*sliceSize, MIN(localIds.count, (slice+1)*sliceSize))];
            slice++;
            [self fetchFromServer:idsToFetch
                        fieldlist:@[idFieldName]
                     maxTimeStamp:0 /*all*/
                       errorBlock:fetchErrorBlock
                    completeBlock:fetchBlockRecurse];
        } else {
            fetchBlockRecurse = nil;
            completeBlock(remoteIds);
        }
    };
    fetchBlockRecurse = fetchBlock;
    // Let's get going
    fetchBlock([NSArray new]);
}

- (void) getIdsFromSmartStoreAndFetchFromServer:(SFSmartSyncSyncManager*)syncManager
                                     errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
                                  completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {

    // Read from smartstore
    SFQuerySpec* querySpec;
    NSMutableArray* idsInSmartStore = [NSMutableArray new];
    long long maxTimeStamp;
    
    if (self.isResync) {
        // Getting full records from SmartStore to compute maxTimeStamp
        // So doing more db work in the hope of doing less server work
        querySpec = [SFQuerySpec newAllQuerySpec:self.soupName withOrderPath:self.idFieldName withOrder:kSFSoupQuerySortOrderAscending withPageSize:self.countIdsPerSoql];
        NSError* error = nil;
        NSArray* recordsFromSmartStore = [syncManager.store queryWithQuerySpec:querySpec pageIndex:self.page error:&error];
        if (error != nil) {
            errorBlock(error);
            return;
        }
        
        // Compute max time stamp
        maxTimeStamp = [self getLatestModificationTimeStamp:recordsFromSmartStore];
        
        // Get ids
        for (NSUInteger i = 0; i<recordsFromSmartStore.count; i++) {
            [idsInSmartStore addObject:((NSDictionary*)recordsFromSmartStore[i])[self.idFieldName]];
        }
    }
    else {
        querySpec = [SFQuerySpec newSmartQuerySpec:[NSString stringWithFormat:@"SELECT {%1$@:%2$@} FROM {%1$@} ORDER BY {%1$@:%2$@} ASC", self.soupName, self.idFieldName] withPageSize:self.countIdsPerSoql];
        
        NSError* error = nil;
        NSArray* result = [syncManager.store queryWithQuerySpec:querySpec pageIndex:self.page error:&error];
        if (error != nil) {
            errorBlock(error);
            return;
        }
        
        // Not a resync
        maxTimeStamp = 0;
        
        // Get ids
        for (NSUInteger i = 0; i<result.count; i++) {
            [idsInSmartStore addObject:((NSArray*)result[i])[0]];
        }
        
    }
  
    // If fetch is starting, figuring out totalSize
    // NB: it might not be the correct value during resync
    //     since not all records will have changed
    if (self.page == 0) {
        NSError* error = nil;
        self.totalSize = [syncManager.store countWithQuerySpec:querySpec error:&error];
        if (error != nil) {
            errorBlock(error);
            return;
        }
    }
    // Get records from server that have changed after maxTimeStamp
    if (idsInSmartStore.count > 0) {
        [self fetchFromServer:idsInSmartStore fieldlist:self.fieldlist maxTimeStamp:maxTimeStamp errorBlock:errorBlock completeBlock:^(NSArray *records) {
            // Increment page if there is more to fetch
            BOOL done = self.countIdsPerSoql * (self.page + 1) >= self.totalSize;
            self.page = (done ? 0 : self.page+1);
            completeBlock(records);
        }];
    }
    else {
        completeBlock(nil);
    }
}

- (void) fetchFromServer:(NSArray*)ids fieldlist:(NSArray*)fieldlist
            maxTimeStamp:(long long)maxTimeStamp
              errorBlock:(SFSyncDownTargetFetchErrorBlock)errorBlock
           completeBlock:(SFSyncDownTargetFetchCompleteBlock)completeBlock {

    NSString* maxTimeStampStr = [SFSmartSyncObjectUtils getIsoStringFromMillis:maxTimeStamp];
    NSString* andClause = (maxTimeStamp > 0
                           ? [NSString stringWithFormat:@" AND %@ > %@", self.modificationDateFieldName, maxTimeStampStr]
                           : @"");
    NSString* whereClause = [NSString stringWithFormat:@"%@ IN ('%@')%@", self.idFieldName, [ids componentsJoinedByString:@"','"], andClause];
    NSString* soql = [[[[SFSDKSoqlBuilder withFieldsArray:fieldlist] from:self.objectType] whereClause:whereClause] build];
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:soql];
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request failBlock:^(NSError *e, NSURLResponse *rawResponse) {
        errorBlock(e);
    } completeBlock:^(NSDictionary *d, NSURLResponse *rawResponse) {
        completeBlock(d[kResponseRecords]);
    }];
}

@end
