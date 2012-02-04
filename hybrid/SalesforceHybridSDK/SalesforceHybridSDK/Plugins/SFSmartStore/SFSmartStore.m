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
#import "SFSmartStore.h"
#import "SFSoup.h"
#import "SFSoupCursor.h"
#import "SFSoupIndex.h"



static NSMutableDictionary *_allSharedStores;



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


/**
 @param storeName The name of the store (excluding paths)
 @return Does this store already exist in persitent storage (ignoring cache) ?
 */
+ (BOOL)persistentStoreExists:(NSString*)storeName;

- (id) initWithName:(NSString*)name;

/**
 Everything needed to setup the store db file when it doesn't yet exist.
 */
- (void)firstTimeStoreDatabaseSetup;

/**
 Simply open the db file.
 */
- (void)openStoreDatabase;

/**
 Create soup index map table to keep track of soups' index specs. 
 */
- (void)createMetaTable;

@end


@implementation SFSmartStore


@synthesize storeDb = _storeDb;
@synthesize storeName = _storeName;

- (id) initWithName:(NSString*)name {
    self = [super init];
    
    if (nil != self)  {
        NSLog(@"SFSmartStore initWithStoreName: %@",name);
        
        self.storeName = name;
        //Setup listening for data protection available / unavailable
        _dataProtectionKnownAvailable = NO;
        _dataProtectAvailObserverToken = [[NSNotificationCenter defaultCenter] 
                                          addObserverForName:UIApplicationProtectedDataDidBecomeAvailable 
                                          object:nil
                                          queue:nil 
                                          usingBlock:^(NSNotification *note) {
                                              _dataProtectionKnownAvailable = YES;
                                          }];
        
        _dataProtectUnavailObserverToken = [[NSNotificationCenter defaultCenter] 
                                            addObserverForName:UIApplicationProtectedDataWillBecomeUnavailable 
                                            object:nil
                                            queue:nil 
                                            usingBlock:^(NSNotification *note) {
                                                _dataProtectionKnownAvailable = NO;
                                            }];
        
        
        _soupCache = [[NSMutableDictionary alloc] init];
        
        if (![self.class persistentStoreExists:name]) {
            [self firstTimeStoreDatabaseSetup];
        } else {
            [self openStoreDatabase];
        }

    }
    return self;
}


- (void)dealloc {
    [_soupCache release]; _soupCache = nil;
    
    [self.storeDb close]; self.storeDb = nil;
    
    //remove data protection observer
    [[NSNotificationCenter defaultCenter] removeObserver:_dataProtectAvailObserverToken];
    _dataProtectAvailObserverToken = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:_dataProtectUnavailObserverToken];
    _dataProtectUnavailObserverToken = nil;
    
    [super dealloc];
}


- (void)firstTimeStoreDatabaseSetup {
    [self openStoreDatabase];
    [self createMetaTable];
}

- (void)openStoreDatabase {
    NSString *storePath = [self.class storePathForStoreName:self.storeName];
    FMDatabase *db = [FMDatabase databaseWithPath:storePath ];
    [db setLogsErrors:YES];
    [db setCrashOnErrors:YES];
    [db open];
    self.storeDb = db;
}

#pragma mark - Store methods


+ (BOOL)persistentStoreExists:(NSString*)storeName {
    NSString *storeDir = [self storePathForStoreName:storeName];
    BOOL result = [[NSFileManager defaultManager] fileExistsAtPath:storeDir];    
    return result;
}

+ (BOOL)storeExists:(NSString*)storeName {
    BOOL result = NO;
    SFSmartStore *store = [_allSharedStores objectForKey:storeName];
    if (nil == store) {
        result = [self persistentStoreExists:storeName];
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


- (void)createMetaTable {
    NSString *createMetaTableSql = [NSString stringWithFormat:
                                    @"CREATE TABLE %@ (%@ TEXT, %@ TEXT, %@ TEXT, %@ TEXT )",
                                    SOUP_INDEX_MAP_TABLE,
                                    SOUP_NAME_COL,
                                    PATH_COL,
                                    COLUMN_NAME_COL,
                                    COLUMN_TYPE_COL
                                    ];
    
    NSLog(@"createMetaTableSql: %@",createMetaTableSql);
                       
    BOOL runOk =[self.storeDb  executeUpdate:createMetaTableSql];
    if (!runOk) {
        NSLog(@"ERROR creating meta table  %d %@", 
              [self.storeDb lastErrorCode], 
              [self.storeDb lastErrorMessage] );
    }
}


#pragma mark - Utility methods


- (BOOL)isFileDataProtectionActive {
    return _dataProtectionKnownAvailable;
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
    
    
//    SFSoup *soup = [_soupCache objectForKey:soupName];
//    if (nil != soup) {
//        result = YES;
//    }
//    else {
//        NSString *soupDir = [[self  class] soupDirectoryFromSoupName:soupName];
//        if ([[NSFileManager defaultManager] fileExistsAtPath:soupDir]) {
//            result = YES;
//        }
//    }
        
    return result;
}


- (BOOL)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs
{
    BOOL result = NO;
    
    NSMutableArray *soupIndexMapInserts = [[NSMutableArray alloc] init ];
    NSMutableArray *createIndexStmts = [[NSMutableArray alloc] init ];
    NSMutableString *createTableStmts = [[NSMutableString alloc] init];
    [createTableStmt appendFormat:@"CREATE TABLE %@ (",soupName];
    [createTableStmt appendFormat:@"%@ INTEGER PRIMARY KEY AUTOINCREMENT",ID_COL];
    [createTableStmt appendFormat:@", %@ TEXT",SOUP_COL]; //this is the column where the raw json is stored
    [createTableStmt appendFormat:@", %@ INTEGER",CREATED_COL]; //TODO make these dates floats (NSTimeInterval) ?
    [createTableStmt appendFormat:@", %@ INTEGER",LAST_MODIFIED_COL];

    
    for (NSUInteger i = 0; i < [indexSpecs count]; i++) {
        NSDictionary *rawIndexSpec = [indexSpecs objectAtIndex:i];
        SFSoupIndex *indexSpec = [[SFSoupIndex alloc] initWithIndexSpec:rawIndexSpec];
        
        // for creating the soup table itself in the store db
        NSString *columnName = [NSString stringWithFormat:@"%@_%d",soupName,i];
        NSString * columnType = [indexSpec columnType];
        [createTableStmt appendFormat:@", %@ %@ ",columnName,columnType];
        
        // for inserting into meta mapping table
        NSMutableDictionary *values = [[NSMutableDictionary alloc] init ];
        [values setObject:soupName forKey:SOUP_NAME_COL];
        [values setObject:indexSpec.path forKey:PATH_COL]; //TODO make path safe?
        [values setObject:columnName forKey:COLUMN_NAME_COL];
        [values setObject:indexSpec.type forKey:COLUMN_TYPE_COL];
        [soupIndexMapInserts addObject:values];
        [values release];
        
        // for creating an index on the soup table
        NSString *indexName = [NSString stringWithFormat:@"%@_%d_idx",soupName,i];
        [createIndexStmts addObject:
         [NSString stringWithFormat:@"CREATE INDEX %@ ON %@ ( %@ )",indexName, soupName, columnName]
         ];
         
    }
    
    [createTableStmt appendString:@")"];
    NSLog(@"createTableStmt: %@",createTableStmt);

    // create the main soup table
    BOOL runOk = [self.storeDb  executeUpdate:createTableStmt];
    if (!runOk) {
        NSLog(@"ERROR creating soup table  %d %@ ", 
              [self.storeDb lastErrorCode], 
              [self.storeDb lastErrorMessage],
              createTableStmt);
    } else {
        // create indices for this soup
        for (NSString *createIndexStmt in createIndexStmts) {
            runOk = [self.storeDb  executeUpdate:createIndexStmt];
            if (!runOk) {
                NSLog(@"ERROR creating soup index  %d %@", 
                      [self.storeDb lastErrorCode], 
                      [self.storeDb lastErrorMessage] );
                NSLog(@"createIndexStmt: %@",createIndexStmt);
            }
        }
        
        // update the mapping table for this soup's columns
        
        if ([self.storeDb beginTransaction]) {
            
            for (NSDictionary *values in soupIndexMapInserts) {
                //TODO map all of the columns and values from soupIndexMapInserts
                //TODO WRONNNNGGGGG
                NSString *insertSql = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@ (%@) VALUES (%@)", SOUP_INDEX_MAP_TABLE, fieldNames, fieldVals];
                [self.storeDb executeUpdate:insertSql];
            }
                 
//            for (ContentValues values : soupIndexMapInserts) {
//                db.insert(SOUP_INDEX_MAP_TABLE, values);
//            }
            
            [self.storeDb endTransaction:YES];
            result = YES;
        }

        
    }
    
    
    return  result;

                                    
//    StringBuilder createTableStmt = new StringBuilder();          // to create new soup table
//    List<String> createIndexStmts = new ArrayList<String>();      // to create indices on new soup table
//    List<ContentValues> soupIndexMapInserts = new ArrayList<ContentValues>();  // to be inserted in soup index map table
//    
//    createTableStmt.append("CREATE TABLE ").append(soupName).append(" (")
//    .append(ID_COL).append(" INTEGER PRIMARY KEY AUTOINCREMENT")
//    .append(", ").append(SOUP_COL).append(" TEXT")
//    .append(", ").append(CREATED_COL).append(" INTEGER")
//    .append(", ").append(LAST_MODIFIED_COL).append(" INTEGER");
//    
//    int i = 0;
//    for (IndexSpec indexSpec : indexSpecs) {
//        // for create table
//        String columnName = soupName + "_" + i;
//        String columnType = indexSpec.type.getColumnType();
//        createTableStmt.append(", ").append(columnName).append(" ").append(columnType);
//        
//        // for insert
//        ContentValues values = new ContentValues();
//        values.put(SOUP_NAME_COL, soupName);
//        values.put(PATH_COL, indexSpec.path);
//        values.put(COLUMN_NAME_COL, columnName);
//        values.put(COLUMN_TYPE_COL, indexSpec.type.toString());
//        soupIndexMapInserts.add(values);
//        
//        // for create index
//        String indexName = soupName + "_" + i + "_idx";
//        createIndexStmts.add(String.format("CREATE INDEX %s on %s ( %s )", indexName, soupName, columnName));;
//        
//        i++;
//    }
//    createTableStmt.append(")");
//    
    
//    db.execSQL(createTableStmt.toString());
//    for (String createIndexStmt : createIndexStmts) {
//        db.execSQL(createIndexStmt.toString());
//    }
//    
//    try {
//        db.beginTransaction();
//        for (ContentValues values : soupIndexMapInserts) {
//            db.insert(SOUP_INDEX_MAP_TABLE, values);
//        }
//        db.setTransactionSuccessful();
//    }
//    finally {
//        db.endTransaction();
//    }
}


- (SFSoup*)oldRegisterSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs
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
