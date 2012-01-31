/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
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

#import <Foundation/Foundation.h>
#import <PhoneGap/PluginResult.h>

#import "SFContainerAppDelegate.h"
#import "SFSmartStore.h"
#import "SFSoup.h"
#import "SFSoupCursor.h"


static NSString *const kSoupsDirectory = @"soups";

@interface SFSmartStore ()


@property (nonatomic, retain) NSMutableDictionary *cursorCache; 

- (void)writeSuccessResultToJsRealm:(PluginResult*)result callbackId:(NSString*)callbackId;
- (void)writeErrorResultToJsRealm:(PluginResult*)result callbackId:(NSString*)callbackId;

- (void)writeSuccessDictToJsRealm:(NSDictionary*)dict callbackId:(NSString*)callbackId;
- (void)writeSuccessArrayToJsRealm:(NSArray*)array callbackId:(NSString*)callbackId;

- (SFSoup*)soupByName:(NSString *)soupName;


@end


@implementation SFSmartStore


@synthesize callbackID = _callbackID;
@synthesize cursorCache = _cursorCache;


#pragma mark - Utility methods

- (BOOL)isFileDataProtectionActive {
    return [_appDelegate isFileDataProtectionAvailable];
}



#pragma mark - Soup maniupulation methods





- (PGPlugin*) initWithWebView:(UIWebView*)theWebView 
{
    self = [super initWithWebView:theWebView];
    
    if (nil != self)  {
        NSLog(@"SmartStore initWithWebView");
        _appDelegate = (SFContainerAppDelegate *)[self appDelegate];
        _soupCache = [[NSMutableDictionary alloc] init];
        _cursorCache = [[NSMutableDictionary alloc] init];
    }
    return self;
}


- (void)dealloc {
    [_soupCache release]; _soupCache = nil;
    [super dealloc];
}


+ (NSString *)soupDirectoryFromSoupName:(NSString *)soupName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *soupsDir = [documentsDirectory stringByAppendingPathComponent:kSoupsDirectory];
    NSString *soupDir = [soupsDir stringByAppendingPathComponent:soupName];

    return soupDir;
}


- (SFSoup*)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs
{
    NSLog(@"SmartStore registerSoup: %@", soupName);

    SFSoup *result = [_soupCache objectForKey:soupName];
    if (nil == result) {
        
        //check whether data protection is active:
        BOOL dataProtectionActive = [self isFileDataProtectionActive];
        if (!dataProtectionActive) {
            //TODO something more aggressive? prevent soup creation?
            //note that data protection is NEVER active on simulator
            NSLog(@"WARNING: File data protection inactive!");
        }
        
        //we don't have this soup cached in memory, but it might already be persisted
        NSString *soupDir = [[self  class] soupDirectoryFromSoupName:soupName];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:soupDir]) {
            if ([indexSpecs count] > 0) {
                //this soup has not yet been created: create it
                NSError *createErr = nil;
                [[NSFileManager defaultManager] createDirectoryAtPath:soupDir 
                                          withIntermediateDirectories:YES attributes:nil error:&createErr];
                if (nil != createErr) {
                    NSLog(@"createDirectoryAtPath err: %@",createErr);
                }
                result = [[SFSoup alloc] initWithName:soupName indexes:indexSpecs atPath:soupDir];
            }
        } else {
            NSLog(@"Soup %@ exists",soupName);
            result = [[SFSoup alloc] initWithName:soupName fromPath:soupDir];
        }
        
        if (nil == result) {
            NSLog(@"Unable to mount soup: %@",soupName);
            //ensure that the entire directory is blown away if we weren't able to load the soup
            [[NSFileManager defaultManager] removeItemAtPath:soupDir error:nil];
        } else {
            [_soupCache setObject:result forKey:soupName];
            [result autorelease];
        }
    }
    
    return result;
}

- (void)removeSoup:(NSString*)soupName {

    NSString *soupDir = [[self  class] soupDirectoryFromSoupName:soupName];
    NSFileManager *fileMgr = [NSFileManager defaultManager] ;
    BOOL isDir = YES;
    if ([fileMgr fileExistsAtPath:soupDir isDirectory:&isDir] ) {
        NSError *removeErr = nil;
        NSLog(@"Removing soupDir '%@'",soupDir);
        [[NSFileManager defaultManager] removeItemAtPath:soupDir error:&removeErr];
        if (nil != removeErr) {
            NSLog(@"Error removing %@ : %@",soupDir,removeErr);
        }
    } else {
        NSLog(@"Ignoring removeSoup for unregistered soup: %@",soupName);
    }
    
    [_soupCache removeObjectForKey:soupName];
}

- (SFSoupCursor *)querySoup:(NSString*)soupName withQuerySpec:(NSDictionary *)querySpec
{
    SFSoup *theSoup = [self soupByName:soupName];
    SFSoupCursor *result =  [theSoup query:querySpec];
    if (nil != result) {
        //cache this cursor for later paging
        [_cursorCache setObject:result forKey:result.cursorId];
    } else {
        NSLog(@"No cursor for query: %@", querySpec);
    }
    return result;
}


- (NSArray *)retrieveEntries:(NSArray*)soupEntryIds fromSoup:(NSString*)soupName
{
    NSArray *result = [NSArray array]; //empty result array by default
    if ([soupEntryIds count] > 0) {
        SFSoup *theSoup = [self soupByName:soupName];
        result = [theSoup retrieveEntries:soupEntryIds];
    }
    return result;
}


- (NSArray*)upsertEntries:(NSArray*)entries toSoup:(NSString*)soupName
{
    NSArray *result = [NSArray array]; //empty result array by default
    if ([entries count] > 0) {
        SFSoup *theSoup = [self soupByName:soupName];
        result = [theSoup upsertEntries:entries]; 
    }
    return result;
}

- (void)removeEntries:(NSArray*)entryIds fromSoup:(NSString*)soupName
{
    if ([entryIds count] > 0) {
        SFSoup *theSoup = [self soupByName:soupName];
        [theSoup removeEntries:entryIds];
        //TODO any need to update other cursors pointing at this soup?
    }
}

- (void)closeCursorWithId:(NSString *)cursorId
{
    SFSoupCursor *theCursor = [self cursorByCursorId:cursorId];
    if (nil != theCursor) {
        [self.cursorCache removeObjectForKey:cursorId];
    }
    //else...could be a cursor passed in response to pgUpsertSoupEntries ?
}



- (SFSoup*)soupByName:(NSString *)soupName
{
    SFSoup *result =  [_soupCache objectForKey:soupName];
    if (nil == result) {
        //attempt to reregister the soup using just the name
        //this only works if the soup was previously created at the standard directory path
        result = [self registerSoup:soupName withIndexSpecs:nil];
    }
    return result;
}

- (SFSoupCursor*)cursorByCursorId:(NSString*)cursorId
{
    SFSoupCursor *theCursor = [_cursorCache objectForKey:cursorId];
    if (nil == theCursor) {
        NSLog(@"Could not find cursor for: %@", cursorId);
    }
    return theCursor;
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

- (void)pgRegisterSoup:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSDate *startTime = [NSDate date];
    NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options objectForKey:@"soupName"];
    NSArray *indexes = [options objectForKey:@"indexes"];
    
    SFSoup *theSoup = [self registerSoup:soupName withIndexSpecs:indexes];
    NSDictionary *returnVals = [NSDictionary dictionaryWithObjectsAndKeys:theSoup.name, @"registeredSoup",nil];
    
    [self writeSuccessDictToJsRealm:returnVals callbackId:callbackId];

    NSLog(@"pgRegisterSoup took: %f", [startTime timeIntervalSinceNow]);
}

- (void)pgRemoveSoup:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSDate *startTime = [NSDate date];
    NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options objectForKey:@"soupName"];

    [self removeSoup:soupName];
    
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
    
    SFSoupCursor *cursor =  [self querySoup:soupName withQuerySpec:querySpec];    
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
    
    NSArray *entries = [self retrieveEntries:entryIds fromSoup:soupName];
    [self writeSuccessArrayToJsRealm:entries callbackId:callbackId];
    
    NSLog(@"pgRetrieveSoupEntries in %f", [startTime timeIntervalSinceNow]);
}

- (void)pgUpsertSoupEntries:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSDate *startTime = [NSDate date];
	NSString* callbackId = [arguments objectAtIndex:0];
    NSString *soupName = [options objectForKey:@"soupName"];
    NSArray *entries = [options objectForKey:@"entries"];
    
    NSArray *resultEntries = [self upsertEntries:entries toSoup:soupName];
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

    [self removeEntries:entryIds fromSoup:soupName];
    
    PluginResult *result = [PluginResult resultWithStatus:PGCommandStatus_OK ];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
    
    NSLog(@"pgRemoveFromSoup took: %f", [startTime timeIntervalSinceNow]);

}

- (void)pgCloseCursor:(NSArray*)arguments withDict:(NSDictionary*)options
{
	NSString* callbackId = [arguments objectAtIndex:0];
    NSString *cursorId = [options objectForKey:@"cursorId"];

    [self closeCursorWithId:cursorId];
    
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
