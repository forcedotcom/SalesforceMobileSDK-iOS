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

#import "NSDictionary+SFAdditions.h"

#import "SFContainerAppDelegate.h"
#import "SFSoupCursor.h"
#import "SFSmartStore.h"
#import "SFHybridViewController.h"
#import <Cordova/CDVPluginResult.h>

//NOTE: must match value in Cordova.plist file
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

- (void)writeSuccessResultToJsRealm:(CDVPluginResult*)result callbackId:(NSString*)callbackId;
- (void)writeErrorResultToJsRealm:(CDVPluginResult*)result callbackId:(NSString*)callbackId;

- (void)writeSuccessDictToJsRealm:(NSDictionary*)dict callbackId:(NSString*)callbackId;
- (void)writeSuccessArrayToJsRealm:(NSArray*)array callbackId:(NSString*)callbackId;

- (void)closeCursorWithId:(NSString *)cursorId;

@end





@implementation SFSmartStorePlugin


@synthesize cursorCache = _cursorCache;
@synthesize store = _store;


+ (void)resetSharedStore {
    SFContainerAppDelegate *myApp = (SFContainerAppDelegate*)[[UIApplication sharedApplication] delegate];
    SFSmartStorePlugin *myInstance = (SFSmartStorePlugin*)[myApp.viewController.commandDelegate getCommandInstance:kSmartStorePluginIdentifier];
    [[myInstance cursorCache] removeAllObjects];
    myInstance.store = nil; 
    myInstance.store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
}

- (CDVPlugin*) initWithWebView:(UIWebView*)theWebView 
{
    self = [super initWithWebView:theWebView];
    
    if (nil != self)  {
        NSLog(@"SFSmartStorePlugin initWithWebView");
        _appDelegate = (SFContainerAppDelegate *)[self appDelegate];
        _cursorCache = [[NSMutableDictionary alloc] init];
        self.store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
    }
    return self;
}


- (void)dealloc {
    self.store = nil;
    [super dealloc];
}

#pragma mark - Cordova plugin support

- (void)writeSuccessArrayToJsRealm:(NSArray*)array callbackId:(NSString*)callbackId
{
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:array];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
}


- (void)writeSuccessDictToJsRealm:(NSDictionary*)dict callbackId:(NSString*)callbackId
{
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
}

- (void)writeSuccessResultToJsRealm:(CDVPluginResult*)result callbackId:(NSString*)callbackId
{    
    NSString *jsString = [result toSuccessCallbackString:callbackId];
    
	if (jsString){
		[self writeJavascript:jsString];
    }
}

- (void)writeErrorResultToJsRealm:(CDVPluginResult*)result callbackId:(NSString*)callbackId
{
    NSString *jsString = [result toErrorCallbackString:callbackId];
	if (jsString){
		[self writeJavascript:jsString];
    }
}


#pragma mark - Object bridging helpers


- (SFSoupCursor*)cursorByCursorId:(NSString*)cursorId
{
    return [_cursorCache objectForKey:cursorId];
}


- (void)closeCursorWithId:(NSString *)cursorId
{
    SFSoupCursor *cursor = [self cursorByCursorId:cursorId];
    if (nil != cursor) {
        [cursor close];
        [self.cursorCache removeObjectForKey:cursorId];
    } 
}

#pragma mark - SmartStore plugin methods

- (void)pgSoupExists:(NSArray*)arguments withDict:(NSDictionary*)options
{
//    NSDate *startTime = [NSDate date];
    NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options nonNullObjectForKey:kSoupNameArg];
    
    BOOL exists = [self.store soupExists:soupName];
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:exists];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    
//    NSLog(@"pgSoupExists took: %f", [startTime timeIntervalSinceNow]);
}

- (void)pgRegisterSoup:(NSArray*)arguments withDict:(NSDictionary*)options
{
//    NSDate *startTime = [NSDate date];
    NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options nonNullObjectForKey:kSoupNameArg];
    NSArray *indexes = [options nonNullObjectForKey:kIndexesArg];
    
    BOOL regOk = [self.store registerSoup:soupName withIndexSpecs:indexes];
    if (regOk) {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:soupName];
        [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR ];
        [self writeErrorResultToJsRealm:result callbackId:callbackId];
    }
    
//    NSLog(@"pgRegisterSoup took: %f", [startTime timeIntervalSinceNow]);
}

- (void)pgRemoveSoup:(NSArray*)arguments withDict:(NSDictionary*)options
{
//    NSDate *startTime = [NSDate date];
    NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options nonNullObjectForKey:kSoupNameArg];
    
    [self.store removeSoup:soupName];
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK ];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    
//    NSLog(@"pgRemoveSoup took: %f", [startTime timeIntervalSinceNow]);
}

- (void)pgQuerySoup:(NSArray*)arguments withDict:(NSMutableDictionary*)options
{
    NSDate *startTime = [NSDate date];
	NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options nonNullObjectForKey:kSoupNameArg];
    NSDictionary *querySpec = [options nonNullObjectForKey:kQuerySpecArg];
    
    SFSoupCursor *cursor =  [self.store querySoup:soupName withQuerySpec:querySpec];    
    NSLog(@"pgQuerySoup returning: %@",cursor);

    if (nil != cursor) {
        //cache this cursor for later paging
        [self.cursorCache setObject:cursor forKey:cursor.cursorId];
        [self writeSuccessDictToJsRealm:[cursor asDictionary] callbackId:callbackId];//TODO other error handling?
        NSLog(@"pgQuerySoup retrieved %d pages in %f",[cursor.totalPages integerValue], [startTime timeIntervalSinceNow]);
    } else {
        NSLog(@"No cursor for query: %@", querySpec);
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR ];
        [self writeErrorResultToJsRealm:result callbackId:callbackId];
    }
}

- (void)pgRetrieveSoupEntries:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSDate *startTime = [NSDate date];
	NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options nonNullObjectForKey:kSoupNameArg];
    NSArray *rawIds = [options nonNullObjectForKey:kEntryIdsArg];
    //make entry Ids unique
    NSSet *entryIdSet = [NSSet setWithArray:rawIds];
    NSArray *entryIds = [entryIdSet allObjects];
    
    NSArray *entries = [self.store retrieveEntries:entryIds fromSoup:soupName];
    [self writeSuccessArrayToJsRealm:entries callbackId:callbackId];
    
    NSLog(@"pgRetrieveSoupEntries in %f", [startTime timeIntervalSinceNow]);
}

- (void)pgUpsertSoupEntries:(NSArray*)arguments withDict:(NSDictionary*)options
{
//    NSDate *startTime = [NSDate date];
	NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options nonNullObjectForKey:kSoupNameArg];
    NSArray *entries = [options nonNullObjectForKey:kEntriesArg];
    NSString *externalIdPath = [options nonNullObjectForKey:kExternalIdPathArg];
    
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
    
//    NSLog(@"pgUpsertSoupEntries upserted %d entries in %f",[entries count], [startTime timeIntervalSinceNow]);
}

- (void)pgRemoveFromSoup:(NSArray*)arguments withDict:(NSDictionary*)options
{
//    NSDate *startTime = [NSDate date];
	NSString* callbackId = [arguments objectAtIndex:0];
    
    NSString *soupName = [options nonNullObjectForKey:kSoupNameArg];
    NSArray *entryIds = [options nonNullObjectForKey:kEntryIdsArg];
    
    [self.store removeEntries:entryIds fromSoup:soupName];
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK ];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    
//    NSLog(@"pgRemoveFromSoup took: %f", [startTime timeIntervalSinceNow]);
    
}

- (void)pgCloseCursor:(NSArray*)arguments withDict:(NSDictionary*)options
{
	NSString* callbackId = [arguments objectAtIndex:0];
    NSString *cursorId = [options nonNullObjectForKey:kCursorIdArg];
    
    [self closeCursorWithId:cursorId];
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK ];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
}

- (void)pgMoveCursorToPageIndex:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSDate *startTime = [NSDate date];
	NSString* callbackId = [arguments objectAtIndex:0];
    
    NSString *cursorId = [options nonNullObjectForKey:kCursorIdArg];
    NSNumber *newPageIndex = [options nonNullObjectForKey:kIndexArg];
    NSLog(@"pgMoveCursorToPageIndex: %@ [%d]",cursorId,[newPageIndex integerValue]);
    
    SFSoupCursor *cursor = [self cursorByCursorId:cursorId];
    [cursor setCurrentPageIndex:newPageIndex];
    
    [self writeSuccessDictToJsRealm:[cursor asDictionary] callbackId:callbackId];    
    
    NSLog(@"pgMoveCursorToPageIndex took: %f", [startTime timeIntervalSinceNow]);
}



@end
