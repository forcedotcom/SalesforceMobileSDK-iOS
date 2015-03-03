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

#import "SFSmartStoreReactBridge.h"

#import <ReactKit/RCTAssert.h>
#import <ReactKit/RCTLog.h>
#import <ReactKit/RCTUtils.h>
#import <SalesforceSDKCore/SFSmartStoreInspectorViewController.h>
#import <SalesforceCommonUtils/NSDictionary+SFAdditions.h>
#import <SalesforceSDKCore/SFStoreCursor.h>
#import <SalesforceSDKCore/SFSmartStore.h>
#import <SalesforceSDKCore/SFQuerySpec.h>
#import <SalesforceSDKCore/SFSoupIndex.h>
#import <SalesforceSDKCore/SFSmartStoreInspectorViewController.h>

// Private constants
NSString * const kSoupNameArg         = @"soupName";
NSString * const kEntryIdsArg         = @"entryIds";
NSString * const kCursorIdArg         = @"cursorId";
NSString * const kIndexArg            = @"index";
NSString * const kIndexesArg          = @"indexes";
NSString * const kQuerySpecArg        = @"querySpec";
NSString * const kEntriesArg          = @"entries";
NSString * const kExternalIdPathArg   = @"externalIdPath";
NSString * const kPathsArg            = @"paths";
NSString * const kReIndexDataArg      = @"reIndexData";

@interface SFSmartStoreReactBridge()

@property (nonatomic, strong) NSMutableDictionary *cursorCache;

@end


@implementation SFSmartStoreReactBridge

#pragma mark - Bridged methods

- (void)showInspector:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();

    [SFSmartStoreInspectorViewController present];
    callback( @[ @"OK" ]);
}


- (void)soupExists:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSString *soupName = [args nonNullObjectForKey:kSoupNameArg];
    [self log:SFLogLevelDebug format:@"soupExists with soup name '%@'.", soupName];
    
    BOOL exists = [self.store soupExists:soupName];
    callback( @[ exists ? @YES : @NO ] );
}

- (void)registerSoup:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSString *soupName = [args nonNullObjectForKey:kSoupNameArg];
    NSArray *indexSpecs = [SFSoupIndex asArraySoupIndexes:[args nonNullObjectForKey:kIndexesArg]];
    [self log:SFLogLevelDebug format:@"registerSoup with name: %@, indexSpecs: %@", soupName, indexSpecs];
    
    BOOL regOk = [self.store registerSoup:soupName withIndexSpecs:indexSpecs];
    if (regOk) {
        callback( @[ soupName ] );
    } else {
        callbackErr( @[ ] );
    }
}

- (void)removeSoup:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSString *soupName = [args nonNullObjectForKey:kSoupNameArg];
    [self log:SFLogLevelDebug format:@"removeSoup with name: %@", soupName];
    
    [self.store removeSoup:soupName];
    callback( @[ @"OK" ]);
}

- (void)querySoup:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSString *soupName = args[kSoupNameArg];
    NSDictionary *querySpecDict = [args nonNullObjectForKey:kQuerySpecArg];
    SFQuerySpec* querySpec = [[SFQuerySpec alloc] initWithDictionary:querySpecDict withSoupName:soupName];
    [self log:SFLogLevelDebug format:@"querySoup with name: %@, querySpec: %@", soupName, querySpecDict];
    
    NSError* error;
    SFStoreCursor* cursor = [self runQuery:querySpec error:&error];
    if (cursor) {
        [self storeCursor:cursor];
        callback( @[ [cursor asDictionary] ]);
    }
    else {
        [self log:SFLogLevelError format:@"no cursor for query: %@", querySpec];
        callbackErr( @[ [error localizedDescription] ] );
    }
}

- (void)runSmartQuery:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    [self querySoup:args callback:callback callbackErr:callbackErr];
}

- (void)retrieveSoupEntries:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSString *soupName = [args nonNullObjectForKey:kSoupNameArg];
    NSArray *rawIds = [args nonNullObjectForKey:kEntryIdsArg];
    [self log:SFLogLevelDebug format:@"retrieveSoupEntries with soup name: %@", soupName];
        
    NSArray *entries = [self.store retrieveEntries:rawIds fromSoup:soupName];
    callback( @[ entries ]);
}

- (void)UpsertSoupEntries:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSString *soupName = [args nonNullObjectForKey:kSoupNameArg];
    NSArray *entries = [args nonNullObjectForKey:kEntriesArg];
    NSString *externalIdPath = [args nonNullObjectForKey:kExternalIdPathArg];
    [self log:SFLogLevelDebug format:@"upsertSoupEntries with soup name: %@, external ID path: %@", soupName, externalIdPath];
        
    NSError *error = nil;
    NSArray *resultEntries = [self.store upsertEntries:entries toSoup:soupName withExternalIdPath:externalIdPath error:&error];
    if (nil != resultEntries) {
        callback( @[ resultEntries ]);
    } else {
        callbackErr( @[ [error localizedDescription] ] );
    }
}

- (void)removeFromSoup:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSString *soupName = [args nonNullObjectForKey:kSoupNameArg];
    NSArray *entryIds = [args nonNullObjectForKey:kEntryIdsArg];
    [self log:SFLogLevelDebug format:@"removeFromSoup with soup name: %@", soupName];
        
    [self.store removeEntries:entryIds fromSoup:soupName];
    callback( @[ @"OK" ]);
}

- (void)closeCursor:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSString *cursorId = [args nonNullObjectForKey:kCursorIdArg];
    [self log:SFLogLevelDebug format:@"closeCursor with cursor ID: %@", cursorId];
        
    [self closeCursorWithId:cursorId];
    callback( @[ @"OK" ]);}

- (void)moveCursorToPageIndex:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSString *cursorId = [args nonNullObjectForKey:kCursorIdArg];
    NSNumber *newPageIndex = [args nonNullObjectForKey:kIndexArg];
    [self log:SFLogLevelDebug format:@"moveCursorToPageIndex with cursor ID: %@, page index: %@", cursorId, newPageIndex];
        
    SFStoreCursor *cursor = [self cursorByCursorId:cursorId];
    [cursor setCurrentPageIndex:newPageIndex];
    callback( @[ [cursor asDictionary] ]);
}

- (void)clearSoup:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSString *soupName = [args nonNullObjectForKey:kSoupNameArg];
    [self log:SFLogLevelDebug format:@"clearSoup with name: %@", soupName];
        
    [self.store clearSoup:soupName];
    callback( @[ @"OK" ]);
}

- (void)getDatabaseSize:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    unsigned long long databaseSize = [self.store getDatabaseSize];
    if (databaseSize > INT_MAX) {
        // This is the best we can do. Cordova can't return an "unsigned long long" (or anything close).
        // TODO: Change this once https://issues.apache.org/jira/browse/CB-8365 has been completed.
        databaseSize = INT_MAX;
    }

    callback( @[ [NSNumber numberWithLongLong:databaseSize] ]);
}

- (void)alterSoup:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSString *soupName = [args nonNullObjectForKey:kSoupNameArg];
    NSArray *indexSpecs = [SFSoupIndex asArraySoupIndexes:[args nonNullObjectForKey:kIndexesArg]];
    BOOL reIndexData = [[args nonNullObjectForKey:kReIndexDataArg] boolValue];
    [self log:SFLogLevelDebug format:@"alterSoup with soup name: %@, indexSpecs: %@, reIndexData: %@", soupName, indexSpecs, reIndexData ? @"true" : @"false"];
        
    BOOL alterOk = [self.store alterSoup:soupName withIndexSpecs:indexSpecs reIndexData:reIndexData];
    if (alterOk) {
        callback( @[ soupName ] );
    } else {
        callbackErr( @[ ] );
    }
}

- (void)reIndexSoup:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSString *soupName = [args nonNullObjectForKey:kSoupNameArg];
    NSArray *indexPaths = [args nonNullObjectForKey:kPathsArg];
    [self log:SFLogLevelDebug format:@"reIndexSoup with soup name: %@, indexPaths: %@", soupName, indexPaths];
        
    BOOL regOk = [self.store reIndexSoup:soupName withIndexPaths:indexPaths];
    if (regOk) {
        callback( @[ soupName ] );
    } else {
        callbackErr( @[ ] );
    }
}

- (void)getSoupIndexSpecs:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    NSString *soupName = [args nonNullObjectForKey:kSoupNameArg];
    [self log:SFLogLevelDebug format:@"getSoupIndexSpecs with soup name: %@", soupName];
        
    NSArray *indexSpecsAsDicts = [SFSoupIndex asArrayOfDictionaries:[self.store indicesForSoup:soupName] withColumnName:NO];
    if ([indexSpecsAsDicts count] > 0) {
        callback( @[ indexSpecsAsDicts ] );
    } else {
        callbackErr( @[ ] );
    }
}

#pragma mark - Cursor cache

- (void)storeCursor:(SFStoreCursor*)cursor
{
    @synchronized(self) {
        if (nil == self.cursorCache) {
            self.cursorCache = [[NSMutableDictionary alloc] init];
        }
    }
    self.cursorCache[cursor.cursorId] = cursor;
}

- (SFStoreCursor*)cursorByCursorId:(NSString*)cursorId
{
    return self.cursorCache[cursorId];
}


- (void)closeCursorWithId:(NSString *)cursorId
{
    SFStoreCursor *cursor = [self cursorByCursorId:cursorId];
    if (nil != cursor) {
        [cursor close];
        [self.cursorCache removeObjectForKey:cursorId];
    }
}

- (void)resetSharedStore
{
    [[self cursorCache] removeAllObjects];
}

#pragma mark - Other helper methods

- (SFSmartStore *)store
{
    return [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
}

- (SFStoreCursor*) runQuery:(SFQuerySpec*)querySpec error:(NSError**)error
{
    if (!querySpec) {
        // XXX we could populate error
        return nil;
    }
    
    NSUInteger totalEntries = [self.store countWithQuerySpec:querySpec error:error];
    if (*error) {
        return nil;
    }
    
    NSArray* firstPageEntries = (totalEntries > 0
                                 ? [self.store queryWithQuerySpec:querySpec pageIndex:0 error:error]
                                 : @[]);
    
    return [[SFStoreCursor alloc] initWithStore:self.store querySpec:querySpec totalEntries:totalEntries firstPageEntries:firstPageEntries];
}


@end
