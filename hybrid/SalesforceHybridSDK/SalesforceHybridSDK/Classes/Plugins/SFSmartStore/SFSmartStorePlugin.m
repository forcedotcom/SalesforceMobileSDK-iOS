/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 Author: Todd Stellanova
 
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
#import <Cordova/CDVCommandDelegateImpl.h>
#import <SalesforceSDKCore/SFStoreCursor.h>
#import <SalesforceSDKCore/SFSmartStore.h>
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



@interface SFSmartStorePlugin() 

- (void)closeCursorWithId:(NSString *)cursorId;

@end





@implementation SFSmartStorePlugin


@synthesize cursorCache = _cursorCache;
@synthesize store = _store;


- (void)resetSharedStore
{
    [[self cursorCache] removeAllObjects];
    self.store = nil;
    self.store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
}

- (CDVPlugin*) initWithWebView:(UIWebView*)theWebView 
{
    self = [super initWithWebView:theWebView];
    
    if (nil != self)  {
        NSLog(@"SFSmartStorePlugin initWithWebView");
        _cursorCache = [[NSMutableDictionary alloc] init];
        self.store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
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
    return [_cursorCache objectForKey:cursorId];
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
    //    NSDate *startTime = [NSDate date];
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"pgSoupExists" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    
    BOOL exists = [self.store soupExists:soupName];
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:exists];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    
//    NSLog(@"pgSoupExists took: %f seconds", -[startTime timeIntervalSinceNow]);
}

- (void)pgRegisterSoup:(CDVInvokedUrlCommand *)command
{
    //    NSDate *startTime = [NSDate date];
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"pgRegisterSoup" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    NSArray *indexes = [argsDict nonNullObjectForKey:kIndexesArg];
    
    BOOL regOk = [self.store registerSoup:soupName withIndexSpecs:indexes];
    if (regOk) {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:soupName];
        [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR ];
        [self writeErrorResultToJsRealm:result callbackId:callbackId];
    }
    
//    NSLog(@"pgRegisterSoup took: %f seconds", -[startTime timeIntervalSinceNow]);
}

- (void)pgRemoveSoup:(CDVInvokedUrlCommand *)command
{
//    NSDate *startTime = [NSDate date];
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"pgRemoveSoup" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    
    [self.store removeSoup:soupName];
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK ];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    
//    NSLog(@"pgRemoveSoup took: %f seconds", -[startTime timeIntervalSinceNow]);
}

- (void)pgQuerySoup:(CDVInvokedUrlCommand *)command
{
    NSDate *startTime = [NSDate date];
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"pgQuerySoup" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    NSDictionary *querySpec = [argsDict nonNullObjectForKey:kQuerySpecArg];
    
    SFStoreCursor *cursor =  [self.store queryWithQuerySpec:querySpec withSoupName:soupName];
    NSLog(@"pgQuerySoup returning: %@",cursor);

    if (nil != cursor) {
        //cache this cursor for later paging
        [self.cursorCache setObject:cursor forKey:cursor.cursorId];
        [self writeSuccessDictToJsRealm:[cursor asDictionary] callbackId:callbackId];//TODO other error handling?
        NSLog(@"pgQuerySoup retrieved %d pages in %f seconds",[cursor.totalPages integerValue], -[startTime timeIntervalSinceNow]);
    } else {
        NSLog(@"No cursor for query: %@", querySpec);
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR ];
        [self writeErrorResultToJsRealm:result callbackId:callbackId];
    }
}

- (void)pgRunSmartQuery:(CDVInvokedUrlCommand *)command
{
    NSDate *startTime = [NSDate date];
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"pgRunSmartQuery" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    NSDictionary *querySpec = [argsDict nonNullObjectForKey:kQuerySpecArg];
    
    SFStoreCursor *cursor =  [self.store queryWithQuerySpec:querySpec withSoupName:nil];
    NSLog(@"pgRunSmartQuery returning: %@",cursor);
    
    if (nil != cursor) {
        //cache this cursor for later paging
        [self.cursorCache setObject:cursor forKey:cursor.cursorId];
        [self writeSuccessDictToJsRealm:[cursor asDictionary] callbackId:callbackId];//TODO other error handling?
        NSLog(@"pgRunSmartQuery retrieved %d pages in %f seconds",[cursor.totalPages integerValue], -[startTime timeIntervalSinceNow]);
    } else {
        NSLog(@"No cursor for query: %@", querySpec);
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR ];
        [self writeErrorResultToJsRealm:result callbackId:callbackId];
    }
}


- (void)pgRetrieveSoupEntries:(CDVInvokedUrlCommand *)command
{
    NSDate *startTime = [NSDate date];
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"pgRetrieveSoupEntries" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    NSArray *rawIds = [argsDict nonNullObjectForKey:kEntryIdsArg];
    //make entry Ids unique
    NSSet *entryIdSet = [NSSet setWithArray:rawIds];
    NSArray *entryIds = [entryIdSet allObjects];
    
    NSArray *entries = [self.store retrieveEntries:entryIds fromSoup:soupName];
    [self writeSuccessArrayToJsRealm:entries callbackId:callbackId];
    
    NSLog(@"pgRetrieveSoupEntries in %f seconds", -[startTime timeIntervalSinceNow]);
}

- (void)pgUpsertSoupEntries:(CDVInvokedUrlCommand *)command
{
//    NSDate *startTime = [NSDate date];
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"pgUpsertSoupEntries" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    NSArray *entries = [argsDict nonNullObjectForKey:kEntriesArg];
    NSString *externalIdPath = [argsDict nonNullObjectForKey:kExternalIdPathArg];
    
    NSError *error = nil;
    NSArray *resultEntries = [self.store upsertEntries:entries toSoup:soupName withExternalIdPath:externalIdPath error:&error];
    CDVPluginResult *result;
    if (nil != resultEntries) {
        //resultEntries
        [self writeSuccessArrayToJsRealm:resultEntries callbackId:callbackId];
    } else {
        if (error == nil) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR ];
        } else {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
        }
        [self writeErrorResultToJsRealm:result callbackId:callbackId];
    }
    
//    NSLog(@"pgUpsertSoupEntries upserted %d entries in %f seconds",[entries count], -[startTime timeIntervalSinceNow]);
}

- (void)pgRemoveFromSoup:(CDVInvokedUrlCommand *)command
{
//    NSDate *startTime = [NSDate date];
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"pgRemoveFromSoup" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    NSString *soupName = [argsDict nonNullObjectForKey:kSoupNameArg];
    NSArray *entryIds = [argsDict nonNullObjectForKey:kEntryIdsArg];
    
    [self.store removeEntries:entryIds fromSoup:soupName];
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK ];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    
//    NSLog(@"pgRemoveFromSoup took: %f seconds", -[startTime timeIntervalSinceNow]);
    
}

- (void)pgCloseCursor:(CDVInvokedUrlCommand *)command
{
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"pgCloseCursor" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    NSString *cursorId = [argsDict nonNullObjectForKey:kCursorIdArg];
    
    [self closeCursorWithId:cursorId];
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK ];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
}

- (void)pgMoveCursorToPageIndex:(CDVInvokedUrlCommand *)command
{
    NSDate *startTime = [NSDate date];
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"pgMoveCursorToPageIndex" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    NSString *cursorId = [argsDict nonNullObjectForKey:kCursorIdArg];
    NSNumber *newPageIndex = [argsDict nonNullObjectForKey:kIndexArg];
    NSLog(@"pgMoveCursorToPageIndex: %@ [%d]",cursorId,[newPageIndex integerValue]);
    
    SFStoreCursor *cursor = [self cursorByCursorId:cursorId];
    [cursor setCurrentPageIndex:newPageIndex];
    
    [self writeSuccessDictToJsRealm:[cursor asDictionary] callbackId:callbackId];    
    
    NSLog(@"pgMoveCursorToPageIndex took: %f seconds", -[startTime timeIntervalSinceNow]);
}



@end
