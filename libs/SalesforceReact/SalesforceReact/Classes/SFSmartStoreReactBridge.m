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

#import "SFSmartStoreReactBridge.h"
#import <React/RCTUtils.h>
#import <SalesforceSDKCore/NSDictionary+SFAdditions.h>
#import <SmartStore/SFStoreCursor.h>
#import <SmartStore/SFSmartStore.h>
#import <SmartStore/SFQuerySpec.h>
#import <SmartStore/SFSoupIndex.h>
#import <SmartStore/SFSoupSpec.h>
#import <SmartStore/SFSmartStoreInspectorViewController.h>

// Private constants
NSString * const kSoupNameArg         = @"soupName";
NSString * const kSoupSpecArg         = @"soupSpec";
NSString * const kEntryIdsArg         = @"entryIds";
NSString * const kCursorIdArg         = @"cursorId";
NSString * const kIndexArg            = @"index";
NSString * const kIndexesArg          = @"indexes";
NSString * const kQuerySpecArg        = @"querySpec";
NSString * const kEntriesArg          = @"entries";
NSString * const kExternalIdPathArg   = @"externalIdPath";
NSString * const kPathsArg            = @"paths";
NSString * const kReIndexDataArg      = @"reIndexData";
NSString * const kIsGlobalStoreArg    = @"isGlobalStore";
NSString * const kStoreName           = @"storeName";

@interface SFSmartStoreReactBridge() {
     dispatch_queue_t _dispatchQueue;
}

@property (nonatomic, strong) NSMutableDictionary *cursorCache;
@end

@implementation SFSmartStoreReactBridge

- (instancetype)init
{
    self = [super init];
    if( self ) {
        _dispatchQueue = dispatch_queue_create([@"SFSmartStoreReactBridge CursorCache Queue" UTF8String], DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

RCT_EXPORT_MODULE();

#pragma mark - Bridged methods

RCT_EXPORT_METHOD(soupExists:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    [SFSDKReactLogger d:[self class] format:[NSString stringWithFormat:@"soupExists with soup name '%@'.", soupName]];
    BOOL exists = [[self getStoreInst:argsDict] soupExists:soupName];
    callback(@[[NSNull null],  exists ? @YES : @NO]);
}

RCT_EXPORT_METHOD(registerSoup:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    SFSmartStore *smartStore = [self getStoreInst:argsDict];
    NSDictionary *soupSpecDict = [argsDict nonNullObjectForKey:kSoupSpecArg];
    SFSoupSpec *soupSpec = nil;
    if (soupSpecDict) {
        soupSpec = [SFSoupSpec newSoupSpecWithDictionary:soupSpecDict];
    } else {
        NSString* soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        soupSpec = [SFSoupSpec newSoupSpec:soupName withFeatures:nil];
    }
    NSArray *indexSpecs = [SFSoupIndex asArraySoupIndexes:[argsDict nonNullObjectForKey:kIndexesArg]];
    [SFSDKReactLogger d:[self class] format:[NSString stringWithFormat:@"registerSoup with name: %@, soup features: %@, indexSpecs: %@", soupSpec.soupName, soupSpec.features, indexSpecs]];
    if (smartStore) {
        NSError *error = nil;
        BOOL result = [smartStore registerSoupWithSpec:soupSpec withIndexSpecs:indexSpecs error:&error];
        if (result) {
            callback(@[[NSNull null], soupSpec.soupName]);
        } else {
            callback(@[RCTMakeError(@"registerSoup failed", error, nil)]);
        }
    } else {
        callback(@[RCTMakeError(@"registerSoup failed", nil, nil)]);
    }
}

RCT_EXPORT_METHOD(removeSoup:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    [SFSDKReactLogger d:[self class] format:[NSString stringWithFormat:@"removeSoup with name: %@", soupName]];
    [[self getStoreInst:argsDict] removeSoup:soupName];
    callback(@[[NSNull null], @"OK"]);
}

RCT_EXPORT_METHOD(querySoup:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = argsDict[kSoupNameArg];
    NSDictionary *querySpecDict = [argsDict nonNullObjectForKey:kQuerySpecArg];
    SFQuerySpec* querySpec = [[SFQuerySpec alloc] initWithDictionary:querySpecDict withSoupName:soupName];
    [SFSDKReactLogger d:[self class] format:[NSString stringWithFormat:@"querySoup with name: %@, querySpec: %@", soupName, querySpecDict]];
    NSError* error = nil;
    SFStoreCursor* cursor = [self runQuery:querySpec error:&error argsDict:argsDict];
    if (cursor.cursorId) {
        NSString *internalCursorId = [self internalCursorId:cursor.cursorId withArgs:argsDict];
        dispatch_sync(self->_dispatchQueue, ^{
            self.cursorCache[internalCursorId] = cursor;
        });
        callback(@[[NSNull null], [cursor asDictionary]]);
    } else {
        [SFSDKReactLogger e:[self class] format:[NSString stringWithFormat:@"No cursor for query: %@", querySpec]];
        callback(@[RCTMakeError(@"No cursor for query", error, nil)]);
    }
}

RCT_EXPORT_METHOD(runSmartQuery:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    [self querySoup:argsDict callback:callback];
}

RCT_EXPORT_METHOD(retrieveSoupEntries:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    NSArray *rawIds = [argsDict nonNullObjectForKey:kEntryIdsArg];
    [SFSDKReactLogger d:[self class] format:[NSString stringWithFormat:@"retrieveSoupEntries with soup name: %@", soupName]];
    NSArray *entries = [[self getStoreInst:argsDict] retrieveEntries:rawIds fromSoup:soupName];
    callback(@[[NSNull null], entries]);
}

RCT_EXPORT_METHOD(upsertSoupEntries:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    NSArray *entries = [argsDict nonNullObjectForKey:kEntriesArg];
    NSString *externalIdPath = [argsDict nonNullObjectForKey:kExternalIdPathArg];
    [SFSDKReactLogger d:[self class] format:[NSString stringWithFormat:@"upsertSoupEntries with soup name: %@, external ID path: %@", soupName, externalIdPath]];
    NSError *error = nil;
    NSArray *resultEntries = [[self getStoreInst:argsDict] upsertEntries:entries toSoup:soupName withExternalIdPath:externalIdPath error:&error];
    if (nil != resultEntries) {
        callback(@[[NSNull null],  resultEntries]);
    } else {
        callback(@[RCTMakeError(@"upsertSoupEntries failed", error, nil)]);
    }
}

RCT_EXPORT_METHOD(removeFromSoup:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    NSArray *entryIds = [argsDict nonNullObjectForKey:kEntryIdsArg];
    NSDictionary *querySpecDict = [argsDict nonNullObjectForKey:kQuerySpecArg];
    [SFSDKReactLogger d:[self class] format:[NSString stringWithFormat:@"removeFromSoup with soup name: %@", soupName]];
    NSError* error = nil;
    if (entryIds) {
        [[self getStoreInst:argsDict] removeEntries:entryIds fromSoup:soupName error:&error];
    } else {
        SFQuerySpec* querySpec = [[SFQuerySpec alloc] initWithDictionary:querySpecDict withSoupName:soupName];
        [[self getStoreInst:argsDict] removeEntriesByQuery:querySpec fromSoup:soupName error:&error];
    }
    if (error == nil) {
        callback(@[[NSNull null], @"OK"]);
    } else {
        callback(@[RCTMakeError(@"removeFromSoup failed", error, nil)]);
    }
}

RCT_EXPORT_METHOD(closeCursor:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *cursorId = [argsDict nonNullObjectForKey:kCursorIdArg];
    [SFSDKReactLogger d:[self class] format:[NSString stringWithFormat:@"closeCursor with cursor ID: %@", cursorId]];
    [self closeCursorWithId:cursorId andArgs:argsDict];
    callback(@[[NSNull null], @"OK"]);}

RCT_EXPORT_METHOD(moveCursorToPageIndex:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *cursorId = [argsDict nonNullObjectForKey:kCursorIdArg];
    NSNumber *newPageIndex = [argsDict nonNullObjectForKey:kIndexArg];
    [SFSDKReactLogger d:[self class] format:[NSString stringWithFormat:@"moveCursorToPageIndex with cursor ID: %@, page index: %@", cursorId, newPageIndex]];
    SFStoreCursor *cursor = [self cursorByCursorId:cursorId andArgs:argsDict];
    [cursor setCurrentPageIndex:newPageIndex];
    callback(@[[NSNull null],  [cursor asDictionary]]);
}

RCT_EXPORT_METHOD(clearSoup:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    [SFSDKReactLogger d:[self class] format:[NSString stringWithFormat:@"clearSoup with name: %@", soupName]];
    [[self getStoreInst:argsDict] clearSoup:soupName];
    callback(@[[NSNull null], @"OK"]);
}

RCT_EXPORT_METHOD(getDatabaseSize:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    unsigned long long databaseSize = [[self getStoreInst:argsDict] getDatabaseSize];
    callback(@[[NSNull null],  [NSNumber numberWithLongLong:databaseSize]]);
}

RCT_EXPORT_METHOD(alterSoup:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString* soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    NSDictionary *soupSpecDict = [argsDict nonNullObjectForKey:kSoupSpecArg];
    SFSoupSpec *soupSpec = nil;
    if (soupSpecDict) {
        soupSpec = [SFSoupSpec newSoupSpecWithDictionary:soupSpecDict];
    } else {
        soupSpec = [SFSoupSpec newSoupSpec:soupName withFeatures:nil];
    }
    NSArray *indexSpecs = [SFSoupIndex asArraySoupIndexes:[argsDict nonNullObjectForKey:kIndexesArg]];
    BOOL reIndexData = [[argsDict nonNullObjectForKey:kReIndexDataArg] boolValue];
    [SFSDKReactLogger d:[self class] format:[NSString stringWithFormat:@"alterSoup with name: %@, soup features: %@, indexSpecs: %@, reIndexData: %@", soupName, soupSpec.features, indexSpecs, reIndexData ? @"true" : @"false"]];
    BOOL alterOk = [[self getStoreInst:argsDict] alterSoup:soupName withSoupSpec:soupSpec withIndexSpecs:indexSpecs reIndexData:reIndexData];
    if (alterOk) {
        callback(@[[NSNull null], soupName]);
    } else {
        callback(@[RCTMakeError(@"alterSoup failed", nil, nil)]);
    }
}

RCT_EXPORT_METHOD(reIndexSoup:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    NSArray *indexPaths = [argsDict nonNullObjectForKey:kPathsArg];
    [SFSDKReactLogger d:[self class] format:[NSString stringWithFormat:@"reIndexSoup with soup name: %@, indexPaths: %@", soupName, indexPaths]];
    BOOL regOk = [[self getStoreInst:argsDict] reIndexSoup:soupName withIndexPaths:indexPaths];
    if (regOk) {
        callback(@[[NSNull null], soupName]);
    } else {
        callback(@[RCTMakeError(@"reIndexSoup failed", nil, nil)]);
    }
}

RCT_EXPORT_METHOD(getSoupIndexSpecs:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    [SFSDKReactLogger d:[self class] format:[NSString stringWithFormat:@"getSoupIndexSpecs with soup name: %@", soupName]];
    NSArray *indexSpecsAsDicts = [SFSoupIndex asArrayOfDictionaries:[[self getStoreInst:argsDict] indicesForSoup:soupName] withColumnName:NO];
    if ([indexSpecsAsDicts count] > 0) {
        callback(@[[NSNull null], indexSpecsAsDicts]);
    } else {
        callback(@[RCTMakeError(@"getSoupIndexSpecs failed", nil, nil)]);
    }
}

RCT_EXPORT_METHOD(getSoupSpec:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    [SFSDKReactLogger d:[self class] format:[NSString stringWithFormat:@"getSoupSpec with soup name: %@", soupName]];
    SFSmartStore *store = [self getStoreInst:argsDict];
    SFSoupSpec *soupSpec = [store attributesForSoup:soupName];
    if (soupSpec) {
        callback(@[[NSNull null], [soupSpec asDictionary]]);
    } else {
        callback(@[RCTMakeError(@"getSoupSpec failed", nil, nil)]);
    }
}

RCT_EXPORT_METHOD(getAllGlobalStores:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSArray *allStoreNames = [SFSmartStore allGlobalStoreNames];
    NSMutableArray *result = [NSMutableArray array];
    if (allStoreNames.count >0 ) {
        for(NSString *storeName in allStoreNames) {
            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
            dictionary[kStoreName] = storeName;
            dictionary[kIsGlobalStoreArg] = @YES;
            [result addObject:dictionary];
        }
    }
    callback(@[[NSNull null], result]);
}

RCT_EXPORT_METHOD(getAllStores:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSArray *allStoreNames = [SFSmartStore allStoreNames];
    NSMutableArray *result = [NSMutableArray array];
    if (allStoreNames.count >0 ) {
        for(NSString *storeName in allStoreNames) {
            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
            dictionary[kStoreName] = storeName;
            dictionary[kIsGlobalStoreArg] = @NO;
            [result addObject:dictionary];
        }
    }
    callback(@[[NSNull null], result]);
}

RCT_EXPORT_METHOD(removeStore:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    BOOL isGlobal = [self isGlobal:argsDict];
    NSString *storeName = [self storeName:argsDict];
    if (isGlobal) {
        [SFSmartStore removeSharedGlobalStoreWithName:storeName];
    }else {
        [SFSmartStore removeSharedStoreWithName:storeName];
    }
    callback(@[[NSNull null], @"OK"]);
}

RCT_EXPORT_METHOD(removeAllGlobalStores:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    [SFSmartStore removeAllGlobalStores];
    callback(@[[NSNull null], @"OK"]);
}

RCT_EXPORT_METHOD(removeAllStores:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    [SFSmartStore removeAllStores];
    callback(@[[NSNull null], @"OK"]);
}

#pragma mark - Helper methods

- (SFStoreCursor*)cursorByCursorId:(NSString*)cursorId andArgs:(NSDictionary *) args
{
    __block SFStoreCursor *cursor = nil;
    dispatch_sync(_dispatchQueue, ^{
        if (nil == self.cursorCache) {
            self.cursorCache = [[NSMutableDictionary alloc] init];
        }
        NSString *internalCursorId = [self internalCursorId:cursorId withArgs:args];
        cursor = self.cursorCache[internalCursorId];
    });
    return cursor;
}

- (void)closeCursorWithId:(NSString *)cursorId andArgs:(NSDictionary *) args
{
    SFStoreCursor *cursor = [self cursorByCursorId:cursorId andArgs:args];
    dispatch_sync(_dispatchQueue, ^{
         if (nil != cursor) {
             [cursor close];
             [self.cursorCache removeObjectForKey:cursorId];
         }
     });
}

- (void)resetCursorCaches
{
    dispatch_sync(_dispatchQueue, ^{
        [self.cursorCache removeAllObjects];
    });
}

- (SFSmartStore *)getStoreInst:(NSDictionary *)args
{
    NSString *storeName = [self storeName:args];
    BOOL isGlobal = [self isGlobal:args];
    SFSmartStore *storeInst = [self storeWithName:storeName isGlobal:isGlobal];
    return storeInst;
}

- (SFSmartStore *)storeWithName:(NSString *)storeName isGlobal:(BOOL) isGlobal
{
    SFSmartStore *store = isGlobal?[SFSmartStore sharedGlobalStoreWithName:storeName]:
                                   [SFSmartStore sharedStoreWithName:storeName];
    return store;
}

- (BOOL)isGlobal:(NSDictionary *)args
{
    return args[kIsGlobalStoreArg] != nil && [args[kIsGlobalStoreArg] boolValue];
}

- (NSString *)storeName:(NSDictionary *)args
{
    NSString *storeName = [args nonNullObjectForKey:kStoreName];
    if(storeName==nil) {
        storeName = kDefaultSmartStoreName;
    }
    return storeName;
}

- (SFStoreCursor*) runQuery:(SFQuerySpec*)querySpec error:(NSError**)error argsDict:(NSDictionary*)argsDict
{
    if (!querySpec) {
        // XXX we could populate error
        return nil;
    }
    NSUInteger totalEntries = [[self getStoreInst:argsDict] countWithQuerySpec:querySpec error:error];
    if (*error) {
        return nil;
    }
    NSArray* firstPageEntries = (totalEntries > 0
                                 ? [[self getStoreInst:argsDict] queryWithQuerySpec:querySpec pageIndex:0 error:error]
                                 : @[]);
    return [[SFStoreCursor alloc] initWithStore:[self getStoreInst:argsDict] querySpec:querySpec totalEntries:totalEntries firstPageEntries:firstPageEntries];
}

- (NSString *)internalCursorId:(NSString *) cursorId withArgs:(NSDictionary *) argsDict {
    NSString *storeName = [self storeName:argsDict];
    BOOL isGlobal = [self isGlobal:argsDict];
    return [self internalCursorId:cursorId withGlobal:isGlobal andStoreName:storeName];
}

- (NSString *)internalCursorId:(NSString *) cursorId withGlobal:(BOOL) isGlobal andStoreName:(NSString *) storeName{
    if(storeName==nil)
        storeName = kDefaultSmartStoreName;
    NSString *internalCursorId = [NSString stringWithFormat:@"%@_%@_%d",storeName,cursorId,isGlobal];
    return internalCursorId;
}

@end
