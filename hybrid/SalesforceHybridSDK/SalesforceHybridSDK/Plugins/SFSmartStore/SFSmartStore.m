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


#import "FMDatabase.h"
#import "SFContainerAppDelegate.h"
#import "SFSmartStore.h"
#import "SFSoup.h"
#import "SFSoupCursor.h"




NSString *const kDefaultSmartStoreName = @"defaultStore";


static NSString *const kSoupsDirectory = @"soups";
static NSString *const kStoresDirectory = @"stores";


// Table to keep track of soup's index specs
static NSString *const SOUP_INDEX_MAP_TABLE = @"soup_index_map";

// Columns of the soup index map table
static NSString *const SOUP_NAME_COL = @"soupName";
static NSString *const PATH_COL = @"path";
static NSString *const COLUMN_NAME_COL = @"columnName";
static NSString *const COLUMN_TYPE_COL = @"columnType";

// Columns of a soup table
static NSString *const ID_COL = @"id";
static NSString *const CREATED_COL = @"created";
static NSString *const LAST_MODIFIED_COL = @"lastModified";
static NSString *const SOUP_COL = @"soup";

// JSON fields added to soup element on insert/update 
static NSString *const SOUP_ENTRY_ID = @"_soupEntryId";
static NSString *const SOUP_LAST_MODIFIED_DATE = @"_soupLastModifiedDate";



@interface SFSmartStore () {
    FMDatabase *_storeDb;
}


static NSMutableDictionary *_allSharedStores;


/**
 Create soup index map table to keep track of soups' index specs. Called when the database is first created
 */
- (void)createMetaTable;


- (id) initWithName:(NSString*)name;

- (SFSoup*)soupByName:(NSString *)soupName;


@end


@implementation SFSmartStore


@synthesize storeDb = _storeDb;


- (id) initWithName:(NSString*)name {
    self = [super init];
    
    if (nil != self)  {
        NSLog(@"SFSmartStore initWithStoreName: %@",name);
        _appDelegate = (SFContainerAppDelegate *)[self appDelegate];
        _soupCache = [[NSMutableDictionary alloc] init];
        if (![self.class storeExists:name]) {
            //there is no persistent store with this name -- setup persistent db
            
        }
    }
    return self;
}


- (void)dealloc {
    [_soupCache release]; _soupCache = nil;
    
    [self.storeDb close] self.storeDb = nil;
    
    [super dealloc];
}



#pragma mark - Store methods


+ (BOOL)storeExists:(NSString*)storeName {
    BOOL result = NO;
    SFSmartStore *store = [_allSharedStores objectForKey:storeName];
    if (nil == store) {
        NSString *storeDir = [self storePathForStoreName:storeName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:storeDir]) {
            result = YES;
        }
    }
    
    return result;
}


+ (id)sharedStoreWithName:(NSString*)storeName {
    if (nil == _allSharedStores) {
        _allSharedStores = [NSMutableDictionary dictionary];
    }
    
    id store = [_allSharedStores objectForKey:storeName];
    if (nil == store) {
        store = [[[SFSmartStore alloc] initWithName:storeName] autorelease];
        [_allSharedStores setObject:store forKey:storeName];
    }
    
    return store;
}

+ (NSString *)storePathForStoreName:(NSString *)storeName {
    //TODO is this the right parent directory from a security & backups standpoint?
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *storesDir = [documentsDirectory stringByAppendingPathComponent:kStoresDirectory];
    NSString *result = [storesDir stringByAppendingPathComponent:storeName];
    
    return result;
}

- (void)setupStoreDatabase {
    if (nil == _storeDb) {
        
    }
}



- (void)createMetaTable {
    NSString *createMetaTableSql = [NSString stringWithFormat:@"CREATE TABLE %@ (%@ TEXT, %@ TEXT, %@ TEXT, %@ TEXT )",
                                SOUP_INDEX_MAP_TABLE,
                                SOUP_NAME_COL,
                                PATH_COL,
                                COLUMN_NAME_COL,
                                COLUMN_TYPE_COL
                                ];
                                
    NSLog(@"createMetaTableSql: %@",createMetaTableSql);
                                
    //TODO insert in FMDatabase
//    db.execSQL(sb.toString());
}


#pragma mark - Utility methods

- (BOOL)isFileDataProtectionActive {
    return [_appDelegate isFileDataProtectionAvailable];
}



#pragma mark - Soup maniupulation methods




+ (NSString *)soupDirectoryFromSoupName:(NSString *)soupName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *soupsDir = [documentsDirectory stringByAppendingPathComponent:kSoupsDirectory];
    NSString *soupDir = [soupsDir stringByAppendingPathComponent:soupName];

    return soupDir;
}





- (BOOL)soupExists:(NSString*)soupName 
{
    //TODO check existence of table etc
    BOOL result = NO;
    SFSoup *soup = [_soupCache objectForKey:soupName];
    if (nil != soup) {
        result = YES;
    }
    else {
        NSString *soupDir = [[self  class] soupDirectoryFromSoupName:soupName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:soupDir]) {
            result = YES;
        }
    }
        
    return result;
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





@end
