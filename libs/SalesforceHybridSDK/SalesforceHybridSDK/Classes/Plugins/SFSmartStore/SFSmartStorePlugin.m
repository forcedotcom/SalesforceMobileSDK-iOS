/*
 Copyright (c) 2012-14, salesforce.com, inc. All rights reserved.
 
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
#import <SalesforceCommonUtils/NSDictionary+SFAdditions.h>
#import <SalesforceSDKCore/SFStoreCursor.h>
#import <SalesforceSDKCore/SFSmartStore.h>
#import <SalesforceSDKCore/SFQuerySpec.h>
#import <SalesforceSDKCore/SFSoupIndex.h>
#import <SalesforceSDKCore/SFSmartStoreInspectorViewController.h>
#import "SFHybridViewController.h"
#import <Cordova/CDVPluginResult.h>
#import <Cordova/CDVInvokedUrlCommand.h>

//NOTE: must match value in Cordova's config.xml file
NSString * const kSmartStorePluginIdentifier = @"com.salesforce.smartstore";

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


@interface SFSmartStorePlugin() 

- (void)closeCursorWithId:(NSString *)cursorId;

@end





@implementation SFSmartStorePlugin


@synthesize cursorCache = _cursorCache;
@synthesize store = _store;


- (void)resetSharedStore
{
    [[self cursorCache] removeAllObjects];
}

- (SFSmartStore *)store
{
    return [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
}

- (CDVPlugin*) initWithWebView:(UIWebView*)theWebView 
{
    self = [super initWithWebView:theWebView];
    
    if (nil != self)  {
        [self log:SFLogLevelDebug msg:@"SFSmartStorePlugin initWithWebView"];
        _cursorCache = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void) dealloc
{
    SFRelease(_store);
}

#pragma mark - Object bridging helpers


- (SFStoreCursor*)cursorByCursorId:(NSString*)cursorId
{
    return _cursorCache[cursorId];
}


- (void)closeCursorWithId:(NSString *)cursorId
{
    SFStoreCursor *cursor = [self cursorByCursorId:cursorId];
    if (nil != cursor) {
        [cursor close];
        [self.cursorCache removeObjectForKey:cursorId];
    } 
}

#pragma mark - SmartStore plugin methods

- (void)pgSoupExists:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        [self log:SFLogLevelDebug format:@"pgSoupExists with soup name '%@'.", soupName];
        
        BOOL exists = [self.store soupExists:soupName];
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:exists];
    } command:command];
}

- (void)pgRegisterSoup:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        NSArray *indexSpecs = [SFSoupIndex asArraySoupIndexes:[argsDict nonNullObjectForKey:kIndexesArg]];
        [self log:SFLogLevelDebug format:@"pgRegisterSoup with name: %@, indexSpecs: %@", soupName, indexSpecs];
        
        BOOL regOk = [self.store registerSoup:soupName withIndexSpecs:indexSpecs];
        if (regOk) {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:soupName];
        } else {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR ];
        }
    } command:command];
}

- (void)pgRemoveSoup:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        [self log:SFLogLevelDebug format:@"pgRemoveSoup with name: %@", soupName];
        
        [self.store removeSoup:soupName];
        
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
        
        NSError* error;
        SFStoreCursor* cursor = [self runQuery:querySpec error:&error];
        if (cursor) {
            (self.cursorCache)[cursor.cursorId] = cursor;
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[cursor asDictionary]];
        }
        else {
            [self log:SFLogLevelError format:@"No cursor for query: %@", querySpec];
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
        }
    } command:command];
}

- (void)pgRunSmartQuery:(CDVInvokedUrlCommand *)command
{
    [self pgQuerySoup:command];
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

- (void)pgRetrieveSoupEntries:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        NSArray *rawIds = [argsDict nonNullObjectForKey:kEntryIdsArg];
        [self log:SFLogLevelDebug format:@"pgRetrieveSoupEntries with soup name: %@", soupName];
        
        NSArray *entries = [self.store retrieveEntries:rawIds fromSoup:soupName];
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
        NSArray *resultEntries = [self.store upsertEntries:entries toSoup:soupName withExternalIdPath:externalIdPath error:&error];
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
        [self log:SFLogLevelDebug format:@"pgRemoveFromSoup with soup name: %@", soupName];
        
        [self.store removeEntries:entryIds fromSoup:soupName];
        
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    } command:command];
}

- (void)pgCloseCursor:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *cursorId = [argsDict nonNullObjectForKey:kCursorIdArg];
        [self log:SFLogLevelDebug format:@"pgCloseCursor with cursor ID: %@", cursorId];
        
        [self closeCursorWithId:cursorId];
        
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    } command:command];
}

- (void)pgMoveCursorToPageIndex:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *cursorId = [argsDict nonNullObjectForKey:kCursorIdArg];
        NSNumber *newPageIndex = [argsDict nonNullObjectForKey:kIndexArg];
        [self log:SFLogLevelDebug format:@"pgMoveCursorToPageIndex with cursor ID: %@, page index: %@", cursorId, newPageIndex];
        
        SFStoreCursor *cursor = [self cursorByCursorId:cursorId];
        [cursor setCurrentPageIndex:newPageIndex];
        
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[cursor asDictionary]];
    } command:command];
}

- (void)pgClearSoup:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        [self log:SFLogLevelDebug format:@"pgClearSoup with name: %@", soupName];
        
        [self.store clearSoup:soupName];
        
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    } command:command];
}

- (void)pgGetDatabaseSize:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        long databaseSize = [self.store getDatabaseSize];
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:databaseSize]; // XXX cast to int will cause issues if database is more than 2GB
    } command:command];
}

- (void)pgAlterSoup:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        NSArray *indexSpecs = [SFSoupIndex asArraySoupIndexes:[argsDict nonNullObjectForKey:kIndexesArg]];
        BOOL reIndexData = [[argsDict nonNullObjectForKey:kReIndexDataArg] boolValue];
        [self log:SFLogLevelDebug format:@"pgAlterSoup with soup name: %@, indexSpecs: %@, reIndexData: %@", soupName, indexSpecs, reIndexData ? @"true" : @"false"];
        
        BOOL alterOk = [self.store alterSoup:soupName withIndexSpecs:indexSpecs reIndexData:reIndexData];
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

        BOOL regOk = [self.store reIndexSoup:soupName withIndexPaths:indexPaths];
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
        [SFSmartStoreInspectorViewController present];
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    } command:command];
}
    
- (void)pgGetSoupIndexSpecs:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
        [self log:SFLogLevelDebug format:@"pgGetSoupIndexSpecs with soup name: %@", soupName];
        
        NSArray *indexSpecsAsDicts = [SFSoupIndex asArrayOfDictionaries:[self.store indicesForSoup:soupName] withColumnName:NO];
        if ([indexSpecsAsDicts count] > 0) {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:indexSpecsAsDicts];
        } else {
            return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        }
    } command:command];
}

@end
