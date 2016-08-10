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
#import "RCTUtils.h"
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

@interface SFSmartStoreReactBridge()

@property (nonatomic, strong) SFSmartStoreInspectorViewController *inspector;
@property (nonatomic, strong) SFSmartStoreInspectorViewController *globalInspector;
@property (nonatomic, strong) SFSmartStore *store;
@property (nonatomic, strong) SFSmartStore *globalStore;
@property (nonatomic, strong) NSMutableDictionary *userCursorCache;
@property (nonatomic, strong) NSMutableDictionary *globalCursorCache;

@end

@implementation SFSmartStoreReactBridge

RCT_EXPORT_MODULE();

#pragma mark - Bridged methods

RCT_EXPORT_METHOD(soupExists:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    [self log:SFLogLevelDebug format:@"soupExists with soup name '%@'.", soupName];
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
    [self log:SFLogLevelDebug format:@"registerSoup with name: %@, soup features: %@, indexSpecs: %@", soupSpec.soupName, soupSpec.features, indexSpecs];
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
    [self log:SFLogLevelDebug format:@"removeSoup with name: %@", soupName];
    [[self getStoreInst:argsDict] removeSoup:soupName];
    callback(@[[NSNull null], @"OK"]);
}

RCT_EXPORT_METHOD(querySoup:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = argsDict[kSoupNameArg];
    NSDictionary *querySpecDict = [argsDict nonNullObjectForKey:kQuerySpecArg];
    SFQuerySpec* querySpec = [[SFQuerySpec alloc] initWithDictionary:querySpecDict withSoupName:soupName];
    [self log:SFLogLevelDebug format:@"querySoup with name: %@, querySpec: %@", soupName, querySpecDict];
    NSError* error = nil;
    SFStoreCursor* cursor = [self runQuery:querySpec error:&error argsDict:argsDict];
    if (cursor.cursorId) {
        if ([self isGlobal:argsDict] && self.globalCursorCache) {
            (self.globalCursorCache)[cursor.cursorId] = cursor;
        } else if (self.userCursorCache) {
            (self.userCursorCache)[cursor.cursorId] = cursor;
        }
        callback(@[[NSNull null], [cursor asDictionary]]);
    } else {
        [self log:SFLogLevelError format:@"No cursor for query: %@", querySpec];
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
    [self log:SFLogLevelDebug format:@"retrieveSoupEntries with soup name: %@", soupName];
    NSArray *entries = [[self getStoreInst:argsDict] retrieveEntries:rawIds fromSoup:soupName];
    callback(@[[NSNull null], entries]);
}

RCT_EXPORT_METHOD(upsertSoupEntries:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    NSArray *entries = [argsDict nonNullObjectForKey:kEntriesArg];
    NSString *externalIdPath = [argsDict nonNullObjectForKey:kExternalIdPathArg];
    [self log:SFLogLevelDebug format:@"upsertSoupEntries with soup name: %@, external ID path: %@", soupName, externalIdPath];
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
    [self log:SFLogLevelDebug format:@"removeFromSoup with soup name: %@", soupName];
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
    [self log:SFLogLevelDebug format:@"closeCursor with cursor ID: %@", cursorId];
    [self closeCursorWithId:cursorId];
    callback(@[[NSNull null], @"OK"]);}

RCT_EXPORT_METHOD(moveCursorToPageIndex:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *cursorId = [argsDict nonNullObjectForKey:kCursorIdArg];
    NSNumber *newPageIndex = [argsDict nonNullObjectForKey:kIndexArg];
    [self log:SFLogLevelDebug format:@"moveCursorToPageIndex with cursor ID: %@, page index: %@", cursorId, newPageIndex];
    SFStoreCursor *cursor = [self cursorByCursorId:cursorId];
    [cursor setCurrentPageIndex:newPageIndex];
    callback(@[[NSNull null],  [cursor asDictionary]]);
}

RCT_EXPORT_METHOD(clearSoup:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    [self log:SFLogLevelDebug format:@"clearSoup with name: %@", soupName];
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
    [self log:SFLogLevelDebug format:@"alterSoup with name: %@, soup features: %@, indexSpecs: %@, reIndexData: %@", soupName, soupSpec.features, indexSpecs, reIndexData ? @"true" : @"false"];
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
    [self log:SFLogLevelDebug format:@"reIndexSoup with soup name: %@, indexPaths: %@", soupName, indexPaths];
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
    [self log:SFLogLevelDebug format:@"getSoupIndexSpecs with soup name: %@", soupName];
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
    [self log:SFLogLevelDebug format:@"getSoupSpec with soup name: %@", soupName];
    SFSmartStore *store = [self getStoreInst:argsDict];
    SFSoupSpec *soupSpec = [store attributesForSoup:soupName];
    if (soupSpec) {
        callback(@[[NSNull null], [soupSpec asDictionary]]);
    } else {
        callback(@[RCTMakeError(@"getSoupSpec failed", nil, nil)]);
    }
}

#pragma mark - Helper methods

- (void)storeCursor:(SFStoreCursor*)cursor
{
    @synchronized(self) {
        if (nil == self.userCursorCache) {
            self.userCursorCache = [[NSMutableDictionary alloc] init];
        }
    }
    self.userCursorCache[cursor.cursorId] = cursor;
}

- (SFStoreCursor*)cursorByCursorId:(NSString*)cursorId
{
    return self.userCursorCache[cursorId];
}


- (void)closeCursorWithId:(NSString *)cursorId
{
    SFStoreCursor *cursor = [self cursorByCursorId:cursorId];
    if (nil != cursor) {
        [cursor close];
        [self.userCursorCache removeObjectForKey:cursorId];
    }
}

- (void)resetSharedStore
{
    [[self userCursorCache] removeAllObjects];
}

- (SFSmartStoreInspectorViewController*)inspector {
    @synchronized(self) {
        if (nil == _inspector) {
            _inspector = [[SFSmartStoreInspectorViewController alloc] initWithStore:self.store];
        }
    }
    return _inspector;
}

- (SFSmartStoreInspectorViewController*)globalInspector {
    @synchronized(self) {
        if (nil == _globalInspector) {
            _globalInspector = [[SFSmartStoreInspectorViewController alloc] initWithStore:self.globalStore];
        }
    }
    return _globalInspector;
}

- (SFSmartStore *)store
{
    return [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
}

- (SFSmartStore *)globalStore
{
    return [SFSmartStore sharedGlobalStoreWithName:kDefaultSmartStoreName];
}

- (SFSmartStore *)getStoreInst:(NSDictionary *)argsDict
{
    return ([self isGlobal:argsDict] ? self.globalStore : self.store);
}

- (BOOL)isGlobal:(NSDictionary *)argsDict
{
    return argsDict[kIsGlobalStoreArg] != nil && [argsDict[kIsGlobalStoreArg] boolValue];
}

- (SFStoreCursor*)cursorByCursorId:(NSString*)cursorId isGlobal:(BOOL)isGlobal
{
    return (isGlobal ? _globalCursorCache[cursorId] : _userCursorCache[cursorId]);
}

- (void)closeCursorWithId:(NSString *)cursorId isGlobal:(BOOL)isGlobal
{
    SFStoreCursor *cursor = [self cursorByCursorId:cursorId isGlobal:isGlobal];
    if (nil != cursor) {
        [cursor close];
        if (isGlobal) {
            [self.globalCursorCache removeObjectForKey:cursorId];
        } else {
            [self.userCursorCache removeObjectForKey:cursorId];
        }
    } 
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

@end
