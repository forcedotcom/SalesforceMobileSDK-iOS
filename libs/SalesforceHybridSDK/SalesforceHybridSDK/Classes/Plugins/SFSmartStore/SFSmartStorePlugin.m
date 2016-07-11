/*
 Copyright (c) 2012-2015, salesforce.com, inc. All rights reserved.
 
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

#import "SFSmartStorePlugin.h"
#import "CDVPlugin+SFAdditions.h"
#import <SalesforceSDKCore/NSDictionary+SFAdditions.h>
#import <SmartStore/SFSoupSpec.h>
#import <SmartStore/SFStoreCursor.h>
#import <SmartStore/SFSmartStore.h>
#import <SmartStore/SFQuerySpec.h>
#import <SmartStore/SFSoupIndex.h>
#import <SmartStore/SFSmartStoreInspectorViewController.h>
#import "SFHybridViewController.h"
#import <Cordova/CDVPluginResult.h>
#import <Cordova/CDVInvokedUrlCommand.h>

// NOTE: must match value in Cordova's config.xml file
NSString * const kSmartStorePluginIdentifier = @"com.salesforce.smartstore";

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

@interface SFSmartStorePlugin() 

@property (nonatomic, strong) SFSmartStoreInspectorViewController *inspector;
@property (nonatomic, strong) SFSmartStoreInspectorViewController *globalInspector;
@property (nonatomic, strong) SFSmartStore *store;
@property (nonatomic, strong) SFSmartStore *globalStore;
@property (nonatomic, strong) NSMutableDictionary *userCursorCache;
@property (nonatomic, strong) NSMutableDictionary *globalCursorCache;

@end

@implementation SFSmartStorePlugin

- (void)resetSharedStore
{
    [[self userCursorCache] removeAllObjects];
}

- (SFSmartStore *)store
{
    return [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
}

- (SFSmartStore *)globalStore
{
    return [SFSmartStore sharedGlobalStoreWithName:kDefaultSmartStoreName];
}

- (void)pluginInitialize
{
    [self log:SFLogLevelDebug msg:@"SFSmartStorePlugin pluginInitialize"];
    self.userCursorCache = [[NSMutableDictionary alloc] init];
    self.globalCursorCache = [[NSMutableDictionary alloc] init];
    self.inspector = [[SFSmartStoreInspectorViewController alloc] initWithStore:self.store];
    self.globalInspector = [[SFSmartStoreInspectorViewController alloc] initWithStore:self.globalStore];
}

#pragma mark - Object bridging helpers

- (SFStoreCursor*)cursorByCursorId:(NSString*)cursorId isGlobal:(BOOL)isGlobal
{
    return (isGlobal ? self.globalCursorCache[cursorId] : self.userCursorCache[cursorId]);
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

#pragma mark - SmartStore plugin methods

- (void)pgSoupExists:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        [self log:SFLogLevelDebug format:@"pgSoupExists with soup name '%@'.", soupName];
        BOOL exists = [[self getStoreInst:argsDict] soupExists:soupName];
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:exists];
    } command:command];
}

- (void)pgRegisterSoup:(CDVInvokedUrlCommand *)command
{
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    SFSmartStore *smartStore = [self getStoreInst:argsDict];

    [self runCommand:^(NSDictionary* argsDict) {
        NSDictionary *soupSpecDict = [argsDict nonNullObjectForKey:kSoupSpecArg];
        SFSoupSpec *soupSpec = nil;
        if (soupSpecDict) {
            soupSpec = [SFSoupSpec newSoupSpecWithDictionary:soupSpecDict];
        } else {
            NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
            soupSpec = [SFSoupSpec newSoupSpec:soupName withFeatures:nil];
        }
        NSArray *indexSpecs = [SFSoupIndex asArraySoupIndexes:[argsDict nonNullObjectForKey:kIndexesArg]];
        
        [self log:SFLogLevelDebug format:@"pgRegisterSoup with soup name: %@, soup features: %@, indexSpecs: %@", soupSpec.soupName, soupSpec.features, indexSpecs];
        if (smartStore) {
            NSError *error = nil;
            BOOL result = [smartStore registerSoupWithSpec:soupSpec withIndexSpecs:indexSpecs error:&error];
            if (result) {
                return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:soupSpec.soupName];
            } else {
                NSString *errorMessage = [NSString stringWithFormat:@"Register soup with spec '%@' failed, error: %@, `argsDict`: %@.", soupSpec, error, argsDict];
                return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
            }
        } else {
            NSString *errorMessage = [NSString stringWithFormat:@"Register soup with spec '%@' failed, the smart store instance is nil, `argsDict`: %@.", soupSpec, argsDict];
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        }
    } command:command];
}

- (void)pgRemoveSoup:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        [self log:SFLogLevelDebug format:@"pgRemoveSoup with name: %@", soupName];
        [[self getStoreInst:argsDict] removeSoup:soupName];
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    } command:command];
}

- (void)pgQuerySoup:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = argsDict[kSoupNameArg];
        NSDictionary *querySpecDict = [argsDict nonNullObjectForKey:kQuerySpecArg];
        SFQuerySpec* querySpec = [[SFQuerySpec alloc] initWithDictionary:querySpecDict withSoupName:soupName];
        [self log:SFLogLevelDebug format:@"pgQuerySoup with name: %@, querySpec: %@", soupName, querySpecDict];
        NSError* error = nil;
        SFStoreCursor* cursor = [self runQuery:querySpec error:&error argsDict:argsDict];
        if (cursor.cursorId) {
            if ([self isGlobal:argsDict] && self.globalCursorCache) {
                (self.globalCursorCache)[cursor.cursorId] = cursor;
            } else if (self.userCursorCache) {
                (self.userCursorCache)[cursor.cursorId] = cursor;
            }
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[cursor asDictionary]];
        } else {
            [self log:SFLogLevelError format:@"No cursor for query: %@", querySpec];
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
        }
    } command:command];
}

- (void)pgRunSmartQuery:(CDVInvokedUrlCommand *)command
{
    [self pgQuerySoup:command];
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

- (void)pgRetrieveSoupEntries:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        NSArray *rawIds = [argsDict nonNullObjectForKey:kEntryIdsArg];
        [self log:SFLogLevelDebug format:@"pgRetrieveSoupEntries with soup name: %@", soupName];
        NSArray *entries = [[self getStoreInst:argsDict] retrieveEntries:rawIds fromSoup:soupName];
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:entries];
    } command:command];
}

- (void)pgUpsertSoupEntries:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        NSArray *entries = [argsDict nonNullObjectForKey:kEntriesArg];
        NSString *externalIdPath = [argsDict nonNullObjectForKey:kExternalIdPathArg];
        [self log:SFLogLevelDebug format:@"pgUpsertSoupEntries with soup name: %@, external ID path: %@", soupName, externalIdPath];
        NSError *error = nil;
        NSArray *resultEntries = [[self getStoreInst:argsDict] upsertEntries:entries toSoup:soupName withExternalIdPath:externalIdPath error:&error];
        if (nil != resultEntries) {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:resultEntries];
        } else {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
        }
    } command:command];
}

- (void)pgRemoveFromSoup:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        NSArray *entryIds = [argsDict nonNullObjectForKey:kEntryIdsArg];
        NSDictionary *querySpecDict = [argsDict nonNullObjectForKey:kQuerySpecArg];

        [self log:SFLogLevelDebug format:@"pgRemoveFromSoup with soup name: %@", soupName];
        NSError *error = nil;
        if (entryIds) {
            [[self getStoreInst:argsDict] removeEntries:entryIds fromSoup:soupName error:&error];
        }
        else {
            SFQuerySpec* querySpec = [[SFQuerySpec alloc] initWithDictionary:querySpecDict withSoupName:soupName];
            [[self getStoreInst:argsDict] removeEntriesByQuery:querySpec fromSoup:soupName error:&error];
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
        }

        if (error == nil) {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
        }
        else {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
        }
        
    } command:command];
}

- (void)pgCloseCursor:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *cursorId = [argsDict nonNullObjectForKey:kCursorIdArg];
        [self log:SFLogLevelDebug format:@"pgCloseCursor with cursor ID: %@", cursorId];
        [self closeCursorWithId:cursorId isGlobal:[self isGlobal:argsDict]];
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    } command:command];
}

- (void)pgMoveCursorToPageIndex:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *cursorId = [argsDict nonNullObjectForKey:kCursorIdArg];
        NSNumber *newPageIndex = [argsDict nonNullObjectForKey:kIndexArg];
        [self log:SFLogLevelDebug format:@"pgMoveCursorToPageIndex with cursor ID: %@, page index: %@", cursorId, newPageIndex];
        SFStoreCursor *cursor = [self cursorByCursorId:cursorId isGlobal:[self isGlobal:argsDict]];
        [cursor setCurrentPageIndex:newPageIndex];
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[cursor asDictionary]];
    } command:command];
}

- (void)pgClearSoup:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        [self log:SFLogLevelDebug format:@"pgClearSoup with name: %@", soupName];
        [[self getStoreInst:argsDict] clearSoup:soupName];
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    } command:command];
}

- (void)pgGetDatabaseSize:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        unsigned long long databaseSize = [[self getStoreInst:argsDict] getDatabaseSize];
        if (databaseSize > INT_MAX) {
            // This is the best we can do. Cordova can't return an "unsigned long long" (or anything close).
            // TODO: Change this once https://issues.apache.org/jira/browse/CB-8365 has been completed.
            databaseSize = INT_MAX;
        }
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:(int)databaseSize];
    } command:command];
}

- (void)pgAlterSoup:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        NSArray *indexSpecs = [SFSoupIndex asArraySoupIndexes:[argsDict nonNullObjectForKey:kIndexesArg]];
        BOOL reIndexData = [[argsDict nonNullObjectForKey:kReIndexDataArg] boolValue];
        [self log:SFLogLevelDebug format:@"pgAlterSoup with soup name: %@, indexSpecs: %@, reIndexData: %@", soupName, indexSpecs, reIndexData ? @"true" : @"false"];
        BOOL alterOk = [[self getStoreInst:argsDict] alterSoup:soupName withIndexSpecs:indexSpecs reIndexData:reIndexData];
        if (alterOk) {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:soupName];
        } else {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        }
    } command:command];
}

- (void)pgReIndexSoup:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        NSArray *indexPaths = [argsDict nonNullObjectForKey:kPathsArg];
        [self log:SFLogLevelDebug format:@"pgReIndexSoup with soup name: %@, indexPaths: %@", soupName, indexPaths];
        BOOL regOk = [[self getStoreInst:argsDict] reIndexSoup:soupName withIndexPaths:indexPaths];
        if (regOk) {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:soupName];
        } else {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        }
    } command:command];
}

- (void)pgShowInspector:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        BOOL isGlobal = [self isGlobal:argsDict];
        SFSmartStoreInspectorViewController* inspector = isGlobal ? self.globalInspector : self.inspector;
        [inspector present:self.viewController];
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    } command:command];
}
    
- (void)pgGetSoupIndexSpecs:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        [self log:SFLogLevelDebug format:@"pgGetSoupIndexSpecs with soup name: %@", soupName];
        NSArray *indexSpecsAsDicts = [SFSoupIndex asArrayOfDictionaries:[[self getStoreInst:argsDict] indicesForSoup:soupName] withColumnName:NO];
        if ([indexSpecsAsDicts count] > 0) {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:indexSpecsAsDicts];
        } else {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        }
    } command:command];
}

- (void)pgGetSoupSpec:(CDVInvokedUrlCommand *)command {
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    SFSmartStore *store = [self getStoreInst:argsDict];
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        [self log:SFLogLevelDebug format:@"pgGetSoupSpec with soup name: %@", soupName];
        SFSoupSpec *soupSpec = [store attributesForSoup:soupName];
        if (soupSpec) {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[soupSpec asDictionary]];
        } else {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Couldn't fetch SoupSpec for the given soup"];
        }
    } command:command];
}

- (SFSmartStore *)getStoreInst:(NSDictionary *)args
{
    return ([self isGlobal:args] ? self.globalStore : self.store);
}

- (BOOL)isGlobal:(NSDictionary *)args
{
    return args[kIsGlobalStoreArg] != nil && [args[kIsGlobalStoreArg] boolValue];
}

@end
