//
//  SFSmartStorePlugin.m
//  SalesforceHybridSDK
//
//  Created by Todd Stellanova on 2/3/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import "SFSmartStorePlugin.h"

#import "SFSoupCursor.h"
#import "SFSmartStore.h"
#import "SFSoup.h"

@interface SFSmartStorePlugin() 

- (void)writeSuccessResultToJsRealm:(PluginResult*)result callbackId:(NSString*)callbackId;
- (void)writeErrorResultToJsRealm:(PluginResult*)result callbackId:(NSString*)callbackId;

- (void)writeSuccessDictToJsRealm:(NSDictionary*)dict callbackId:(NSString*)callbackId;
- (void)writeSuccessArrayToJsRealm:(NSArray*)array callbackId:(NSString*)callbackId;

@end

@implementation SFSmartStorePlugin


@synthesize cursorCache = _cursorCache;
@synthesize store = _store;
@synthesize callbackID = _callbackID;


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
    SFSoupCursor *theCursor = [_cursorCache objectForKey:cursorId];
    if (nil == theCursor) {
        NSLog(@"Could not find cursor for: %@", cursorId);
    }
    return theCursor;
}


- (void)closeCursorWithId:(NSString *)cursorId
{
    SFSoupCursor *theCursor = [self cursorByCursorId:cursorId];
    if (nil != theCursor) {
        [theCursor close];
        [self.cursorCache removeObjectForKey:cursorId];
    } else {
        NSLog(@"WARNING could not find cursor with ID %@ for closing",cursorId);
    }
}

#pragma mark - SmartStore plugin methods

- (void)pgSoupExists:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSDate *startTime = [NSDate date];
    NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options objectForKey:@"soupName"];
    
    BOOL exists = [self.store soupExists:soupName];
    PluginResult* result = [PluginResult resultWithStatus:PGCommandStatus_OK messageAsInt:exists];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    
    NSLog(@"pgSoupExists took: %f", [startTime timeIntervalSinceNow]);
}

- (void)pgRegisterSoup:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSDate *startTime = [NSDate date];
    NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options objectForKey:@"soupName"];
    NSArray *indexes = [options objectForKey:@"indexes"];
    
    BOOL regOk = [self.store registerSoup:soupName withIndexSpecs:indexes];
    if (regOk) {
        NSDictionary *returnVals = [NSDictionary dictionaryWithObjectsAndKeys:soupName, @"registeredSoup",nil];
        [self writeSuccessDictToJsRealm:returnVals callbackId:callbackId];
    } else {
        PluginResult *result = [PluginResult resultWithStatus:PGCommandStatus_ERROR ];
        [self writeErrorResultToJsRealm:result callbackId:callbackId];
    }
    
    NSLog(@"pgRegisterSoup took: %f", [startTime timeIntervalSinceNow]);
}

- (void)pgRemoveSoup:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSDate *startTime = [NSDate date];
    NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options objectForKey:@"soupName"];
    
    [self.store removeSoup:soupName];
    
    PluginResult *result = [PluginResult resultWithStatus:PGCommandStatus_OK ];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    
    NSLog(@"pgRemoveSoup took: %f", [startTime timeIntervalSinceNow]);
}

- (void)pgQuerySoup:(NSArray*)arguments withDict:(NSMutableDictionary*)options
{
    NSDate *startTime = [NSDate date];
	NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options objectForKey:@"soupName"];
    NSDictionary *querySpec = [options objectForKey:@"querySpec"];
    
    SFSoupCursor *cursor =  [self.store querySoup:soupName withQuerySpec:querySpec];    
    if (nil != cursor) {
        //cache this cursor for later paging
        [self.cursorCache setObject:cursor forKey:cursor.cursorId];
    } else {
        NSLog(@"No cursor for query: %@", querySpec);
    }
    
    [self writeSuccessDictToJsRealm:[cursor asDictionary] callbackId:callbackId];//TODO other error handling?
    
    NSLog(@"pgQuerySoup retrieved %d pages in %f",[cursor.totalPages integerValue], [startTime timeIntervalSinceNow]);
}

- (void)pgRetrieveSoupEntries:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSDate *startTime = [NSDate date];
	NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options objectForKey:@"soupName"];
    NSArray *rawIds = [options objectForKey:@"entryIds"];
    //make entry Ids unique
    NSSet *entryIdSet = [NSSet setWithArray:rawIds];
    NSArray *entryIds = [entryIdSet allObjects];
    
    NSArray *entries = [self.store retrieveEntries:entryIds fromSoup:soupName];
    [self writeSuccessArrayToJsRealm:entries callbackId:callbackId];
    
    NSLog(@"pgRetrieveSoupEntries in %f", [startTime timeIntervalSinceNow]);
}

- (void)pgUpsertSoupEntries:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSDate *startTime = [NSDate date];
	NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options objectForKey:@"soupName"];
    NSArray *entries = [options objectForKey:@"entries"];
    
    NSArray *resultEntries = [self.store upsertEntries:entries toSoup:soupName];
    PluginResult *result;
    if (nil != resultEntries) {
        //resultEntries
        [self writeSuccessArrayToJsRealm:resultEntries callbackId:callbackId];
    } else {
        result = [PluginResult resultWithStatus:PGCommandStatus_ERROR ];
        [self writeErrorResultToJsRealm:result callbackId:callbackId];
    }
    
    NSLog(@"pgUpsertSoupEntries upserted %d entries in %f",[entries count], [startTime timeIntervalSinceNow]);
}

- (void)pgRemoveFromSoup:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSDate *startTime = [NSDate date];
	NSString* callbackId = [arguments objectAtIndex:0];
    
    NSString *soupName = [options objectForKey:@"soupName"];
    NSArray *entryIds = [options objectForKey:@"entryIds"];
    
    [self.store removeEntries:entryIds fromSoup:soupName];
    
    PluginResult *result = [PluginResult resultWithStatus:PGCommandStatus_OK ];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    
    NSLog(@"pgRemoveFromSoup took: %f", [startTime timeIntervalSinceNow]);
    
}

- (void)pgCloseCursor:(NSArray*)arguments withDict:(NSDictionary*)options
{
	NSString* callbackId = [arguments objectAtIndex:0];
    NSString *cursorId = [options objectForKey:@"cursorId"];
    
    SFSoupCursor *cursor = [self cursorByCursorId:cursorId];
    [cursor close];
    //[self.store closeCursorWithId:cursorId];
    
    PluginResult *result = [PluginResult resultWithStatus:PGCommandStatus_OK ];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
}

- (void)pgMoveCursorToPageIndex:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSDate *startTime = [NSDate date];
	NSString* callbackId = [arguments objectAtIndex:0];
    
    NSString *cursorId = [options objectForKey:@"cursorId"];
    NSNumber *newPageIndex = [options objectForKey:@"index"];
    NSLog(@"pgMoveCursorToPageIndex: %@ [%d]",cursorId,[newPageIndex integerValue]);
    
    SFSoupCursor *cursor = [self cursorByCursorId:cursorId];
    [cursor setCurrentPageIndex:newPageIndex];
    
    [self writeSuccessDictToJsRealm:[cursor asDictionary] callbackId:callbackId];    
    
    NSLog(@"pgMoveCursorToPageIndex took: %f", [startTime timeIntervalSinceNow]);
}



@end
