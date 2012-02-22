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

#import "NSDictionary+NullHandling.h"

#import "SFContainerAppDelegate.h"
#import "SFSoupCursor.h"
#import "SFSmartStore.h"

//NOTE: must match value in PhoneGap.plist file
NSString * const kSmartStorePluginIdentifier = @"com.salesforce.smartstore";





@interface SFSmartStorePlugin() 

- (void)writeSuccessResultToJsRealm:(PluginResult*)result callbackId:(NSString*)callbackId;
- (void)writeErrorResultToJsRealm:(PluginResult*)result callbackId:(NSString*)callbackId;

- (void)writeSuccessDictToJsRealm:(NSDictionary*)dict callbackId:(NSString*)callbackId;
- (void)writeSuccessArrayToJsRealm:(NSArray*)array callbackId:(NSString*)callbackId;

- (void)closeCursorWithId:(NSString *)cursorId;

@end





@implementation SFSmartStorePlugin


@synthesize cursorCache = _cursorCache;
@synthesize store = _store;


+ (void)resetSharedStore {
    SFContainerAppDelegate *myApp = (SFContainerAppDelegate*)[[UIApplication sharedApplication] delegate];
    SFSmartStorePlugin *myInstance = (SFSmartStorePlugin*)[myApp getCommandInstance:kSmartStorePluginIdentifier];
    [[myInstance cursorCache] removeAllObjects];
    myInstance.store = nil; 
    myInstance.store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
}

- (PGPlugin*) initWithWebView:(UIWebView*)theWebView 
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

#pragma mark - PhoneGap plugin support

- (void)writeSuccessArrayToJsRealm:(NSArray*)array callbackId:(NSString*)callbackId
{
    PluginResult* result = [PluginResult resultWithStatus:PGCommandStatus_OK messageAsArray:array];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
}


- (void)writeSuccessDictToJsRealm:(NSDictionary*)dict callbackId:(NSString*)callbackId
{
    PluginResult* result = [PluginResult resultWithStatus:PGCommandStatus_OK messageAsDictionary:dict];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
}

- (void)writeSuccessResultToJsRealm:(PluginResult*)result callbackId:(NSString*)callbackId
{    
    NSString *jsString = [result toSuccessCallbackString:callbackId];
    
	if (jsString){
		[self writeJavascript:jsString];
    }
}

- (void)writeErrorResultToJsRealm:(PluginResult*)result callbackId:(NSString*)callbackId
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
    NSString *soupName = [options nonNullObjectForKey:@"soupName"];
    
    BOOL exists = [self.store soupExists:soupName];
    PluginResult* result = [PluginResult resultWithStatus:PGCommandStatus_OK messageAsBool:exists];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    
//    NSLog(@"pgSoupExists took: %f", [startTime timeIntervalSinceNow]);
}

- (void)pgRegisterSoup:(NSArray*)arguments withDict:(NSDictionary*)options
{
//    NSDate *startTime = [NSDate date];
    NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options nonNullObjectForKey:@"soupName"];
    NSArray *indexes = [options nonNullObjectForKey:@"indexes"];
    
    BOOL regOk = [self.store registerSoup:soupName withIndexSpecs:indexes];
    if (regOk) {
        PluginResult* result = [PluginResult resultWithStatus:PGCommandStatus_OK messageAsString:soupName];
        [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    } else {
        PluginResult *result = [PluginResult resultWithStatus:PGCommandStatus_ERROR ];
        [self writeErrorResultToJsRealm:result callbackId:callbackId];
    }
    
//    NSLog(@"pgRegisterSoup took: %f", [startTime timeIntervalSinceNow]);
}

- (void)pgRemoveSoup:(NSArray*)arguments withDict:(NSDictionary*)options
{
//    NSDate *startTime = [NSDate date];
    NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options nonNullObjectForKey:@"soupName"];
    
    [self.store removeSoup:soupName];
    
    PluginResult *result = [PluginResult resultWithStatus:PGCommandStatus_OK ];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    
//    NSLog(@"pgRemoveSoup took: %f", [startTime timeIntervalSinceNow]);
}

- (void)pgQuerySoup:(NSArray*)arguments withDict:(NSMutableDictionary*)options
{
    NSDate *startTime = [NSDate date];
	NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options nonNullObjectForKey:@"soupName"];
    NSDictionary *querySpec = [options nonNullObjectForKey:@"querySpec"];
    
    SFSoupCursor *cursor =  [self.store querySoup:soupName withQuerySpec:querySpec];    
    NSLog(@"pgQuerySoup returning: %@",cursor);

    if (nil != cursor) {
        //cache this cursor for later paging
        [self.cursorCache setObject:cursor forKey:cursor.cursorId];
        [self writeSuccessDictToJsRealm:[cursor asDictionary] callbackId:callbackId];//TODO other error handling?
        NSLog(@"pgQuerySoup retrieved %d pages in %f",[cursor.totalPages integerValue], [startTime timeIntervalSinceNow]);
    } else {
        NSLog(@"No cursor for query: %@", querySpec);
        PluginResult *result = [PluginResult resultWithStatus:PGCommandStatus_ERROR ];
        [self writeErrorResultToJsRealm:result callbackId:callbackId];
    }
}

- (void)pgRetrieveSoupEntries:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSDate *startTime = [NSDate date];
	NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options nonNullObjectForKey:@"soupName"];
    NSArray *rawIds = [options nonNullObjectForKey:@"entryIds"];
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
    NSString *soupName = [options nonNullObjectForKey:@"soupName"];
    NSArray *entries = [options nonNullObjectForKey:@"entries"];
    
    NSArray *resultEntries = [self.store upsertEntries:entries toSoup:soupName];
    PluginResult *result;
    if (nil != resultEntries) {
        //resultEntries
        [self writeSuccessArrayToJsRealm:resultEntries callbackId:callbackId];
    } else {
        result = [PluginResult resultWithStatus:PGCommandStatus_ERROR ];
        [self writeErrorResultToJsRealm:result callbackId:callbackId];
    }
    
//    NSLog(@"pgUpsertSoupEntries upserted %d entries in %f",[entries count], [startTime timeIntervalSinceNow]);
}

- (void)pgRemoveFromSoup:(NSArray*)arguments withDict:(NSDictionary*)options
{
//    NSDate *startTime = [NSDate date];
	NSString* callbackId = [arguments objectAtIndex:0];
    
    NSString *soupName = [options nonNullObjectForKey:@"soupName"];
    NSArray *entryIds = [options nonNullObjectForKey:@"entryIds"];
    
    [self.store removeEntries:entryIds fromSoup:soupName];
    
    PluginResult *result = [PluginResult resultWithStatus:PGCommandStatus_OK ];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    
//    NSLog(@"pgRemoveFromSoup took: %f", [startTime timeIntervalSinceNow]);
    
}

- (void)pgCloseCursor:(NSArray*)arguments withDict:(NSDictionary*)options
{
	NSString* callbackId = [arguments objectAtIndex:0];
    NSString *cursorId = [options nonNullObjectForKey:@"cursorId"];
    
    [self closeCursorWithId:cursorId];
    
    PluginResult *result = [PluginResult resultWithStatus:PGCommandStatus_OK ];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
}

- (void)pgMoveCursorToPageIndex:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSDate *startTime = [NSDate date];
	NSString* callbackId = [arguments objectAtIndex:0];
    
    NSString *cursorId = [options nonNullObjectForKey:@"cursorId"];
    NSNumber *newPageIndex = [options nonNullObjectForKey:@"index"];
    NSLog(@"pgMoveCursorToPageIndex: %@ [%d]",cursorId,[newPageIndex integerValue]);
    
    SFSoupCursor *cursor = [self cursorByCursorId:cursorId];
    [cursor setCurrentPageIndex:newPageIndex];
    
    [self writeSuccessDictToJsRealm:[cursor asDictionary] callbackId:callbackId];    
    
    NSLog(@"pgMoveCursorToPageIndex took: %f", [startTime timeIntervalSinceNow]);
}



@end
