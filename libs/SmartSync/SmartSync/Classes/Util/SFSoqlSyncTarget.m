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

#import "SFSoqlSyncTarget.h"
#import "SFSmartSyncSyncManager.h"
#import "SFSmartSyncConstants.h"
#import "SFSmartSyncObjectUtils.h"

NSString * const kSFSoqlSyncTargetQuery = @"query";

@interface SFSoqlSyncTarget ()

@property (nonatomic, strong, readwrite) NSString* query;
@property (nonatomic, strong, readwrite) NSString* nextRecordsUrl;

@end

@implementation SFSoqlSyncTarget

#pragma mark - Factory methods

+ (SFSoqlSyncTarget*) newSyncTarget:(NSString*)query {
    SFSoqlSyncTarget* syncTarget = [[SFSoqlSyncTarget alloc] init];
    syncTarget.queryType = SFSyncTargetQueryTypeSoql;
    syncTarget.query = query;
    syncTarget.isUndefined = NO;
    return syncTarget;
}


#pragma mark - From/to dictionary

+ (SFSoqlSyncTarget*) newFromDict:(NSDictionary*)dict {
    SFSoqlSyncTarget* syncTarget = [[SFSoqlSyncTarget alloc] init];
    if (syncTarget) {
        if (dict == nil || [dict count] == 0) {
            syncTarget.isUndefined = YES;
        }
        else {
            syncTarget.isUndefined = NO;
            syncTarget.queryType = SFSyncTargetQueryTypeSoql;
            syncTarget.query = dict[kSFSoqlSyncTargetQuery];
        }
    }
    
    return syncTarget;
}

- (NSDictionary*) asDict {
    NSDictionary* dict;

    if (self.isUndefined) {
        dict = @{};
    }
    else {
        dict = @{
        kSFSyncTargetQueryType: [SFSyncTarget queryTypeToString:self.queryType],
        kSFSoqlSyncTargetQuery: self.query
        };
    }

    return dict;
}

# pragma mark - Data fetching

- (void) startFetch:(SFSmartSyncSyncManager*)syncManager
       maxTimeStamp:(long long)maxTimeStamp
         errorBlock:(SFSyncTargetFetchErrorBlock)errorBlock
      completeBlock:(SFSyncTargetFetchCompleteBlock)completeBlock
{
    __weak SFSoqlSyncTarget* weakSelf = self;

    // Resync?
    NSString* queryToRun = self.query;
    if (maxTimeStamp > 0) {
        queryToRun = [SFSoqlSyncTarget addFilterForReSync:self.query maxTimeStamp:maxTimeStamp];
    }
    
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForQuery:queryToRun];
    [syncManager sendRequestWithSmartSyncUserAgent:request failBlock:errorBlock completeBlock:^(NSDictionary *d) {
        weakSelf.totalSize = [d[kResponseTotalSize] integerValue];
        weakSelf.nextRecordsUrl = d[kResponseNextRecordsUrl];
        completeBlock(d[kResponseRecords]);
    }];
}

- (void) continueFetch:(SFSmartSyncSyncManager *)syncManager
            errorBlock:(SFSyncTargetFetchErrorBlock)errorBlock
         completeBlock:(SFSyncTargetFetchCompleteBlock)completeBlock
{
    if (self.nextRecordsUrl) {
        __weak SFSoqlSyncTarget* weakSelf = self;
        SFRestRequest* request = [SFRestRequest requestWithMethod:SFRestMethodGET path:self.nextRecordsUrl queryParams:nil];
        [syncManager sendRequestWithSmartSyncUserAgent:request failBlock:errorBlock completeBlock:^(NSDictionary *d) {
            weakSelf.nextRecordsUrl = d[kResponseNextRecordsUrl];
            completeBlock(d[kResponseRecords]);
        }];
    }
    else {
        completeBlock(nil);
    }
}

+ (NSString*) addFilterForReSync:(NSString*)query maxTimeStamp:(long long)maxTimeStamp
{
    NSString* queryToRun = query;
    if (maxTimeStamp > 0) {
        NSString* maxTimeStampStr = [SFSmartSyncObjectUtils getIsoStringFromMillis:maxTimeStamp];
        NSString* extraPredicate =  [@[kLastModifiedDate, @">", maxTimeStampStr] componentsJoinedByString:@" "];
        if ([[query lowercaseString] rangeOfString:@" where "].location != NSNotFound) {
            queryToRun = [SFSoqlSyncTarget appendToFirstOccurence:query pattern:@" where " stringToAppend:[@[extraPredicate, @" and "] componentsJoinedByString:@""]];
        }
        else {
            queryToRun = [SFSoqlSyncTarget appendToFirstOccurence:query pattern:@" from[ ]+[^ ]*" stringToAppend:[@[@" where ", extraPredicate] componentsJoinedByString:@""]];
        }
    }
    return queryToRun;
}

+ (NSString*) appendToFirstOccurence:(NSString*)str pattern:(NSString*)pattern stringToAppend:(NSString*)stringToAppend
{
    NSRegularExpression* regexp = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    NSRange rangeFirst = [regexp rangeOfFirstMatchInString:str options:0 range:NSMakeRange(0, [str length])];
    NSString* firstMatch = [str substringWithRange:rangeFirst];
    NSString* modifiedStr = [str stringByReplacingCharactersInRange:rangeFirst withString:[@[firstMatch, stringToAppend] componentsJoinedByString:@""]];
    return modifiedStr;
}




@end
