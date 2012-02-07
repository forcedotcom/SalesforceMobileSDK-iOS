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
#import "FMDatabaseAdditions.h"
#import "SFJsonUtils.h"
#import "SFSmartStore.h"
#import "SFSoupCursor.h"
#import "SFSoupIndex.h"



static NSMutableDictionary *_allSharedStores;



NSString *const kDefaultSmartStoreName = @"defaultStore";


static NSString *const kStoresDirectory = @"stores";
static NSString * const kStoreDbFileName = @"store.sqlite";


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
 @return full filesystem path for the store db file
 */
+ (NSString*)fullDbFilePathForStoreName:(NSString*)storeName;

/**
 @param storeName The name of the store (excluding paths)
 @return Does this store already exist in persitent storage (ignoring cache) ?
 */
+ (BOOL)persistentStoreExists:(NSString*)storeName;

- (id) initWithName:(NSString*)name;



/**
 Everything needed to setup the store db file when it doesn't yet exist.
 
 @return Success ?
 */
- (BOOL)firstTimeStoreDatabaseSetup;


/**

 @param soupIndexMapInserts array of NSDictionary of columns and values to be inserted
 @return Insert a new set of indices into the soupe index map.
 */
- (BOOL)insertIntoSoupIndexMap:(NSArray*)soupIndexMapInserts;


    
/**
 Simply open the db file.
 
 @return YES if we were able to open the db file
 */
- (BOOL)openStoreDatabase;

/**
 Create soup index map table to keep track of soups' index specs. 
 
 @return YES if we were able to create the meta table OK
 */
- (BOOL)createMetaTable;


- (id)projectIntoJson:(NSDictionary *)jsonObj path:(NSString *)path;
- (BOOL)upsertIntoTable:(NSString*)tableName values:(NSDictionary*)map ;

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
        
                
        _indexSpecsBySoup = [[NSMutableDictionary alloc] init];

        if (![self.class persistentStoreExists:name]) {
            if (![self firstTimeStoreDatabaseSetup]) {
                [self release];
                self = nil;
            }
        } else {
            if (![self openStoreDatabase]) {
                [self release];
                self = nil;
            }
        }
        

    }
    return self;
}


- (void)dealloc {    
    [self.storeDb close]; self.storeDb = nil;
    [_indexSpecsBySoup release] ; _indexSpecsBySoup = nil;
    
    //remove data protection observer
    [[NSNotificationCenter defaultCenter] removeObserver:_dataProtectAvailObserverToken];
    _dataProtectAvailObserverToken = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:_dataProtectUnavailObserverToken];
    _dataProtectUnavailObserverToken = nil;
    
    [super dealloc];
}


- (BOOL)firstTimeStoreDatabaseSetup {
    BOOL result = NO;
    NSError *createErr = nil, *protectErr = nil;

    //ensure that the store directory exists
    NSString *storeDir = [self.class storeDirectoryForStoreName:self.storeName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:storeDir]) {
        //this store has not yet been created: create it
        [[NSFileManager defaultManager] createDirectoryAtPath:storeDir 
                                  withIntermediateDirectories:YES attributes:nil error:&createErr];
        if (nil != createErr) {
            NSLog(@"Couldn't create store dir at %@ error: %@",storeDir, createErr);
        }
    } 
    
    if (nil == createErr) {
        //need to create the db file itself before we can encrypt it
        if ([self openStoreDatabase]) {
            if ([self createMetaTable]) {
                [self.storeDb close]; self.storeDb = nil; //need to close before setting encryption
                
                NSString *dbFilePath = [self.class fullDbFilePathForStoreName:self.storeName];
                //setup the sqlite file with encryption        
                NSDictionary *attr = [NSDictionary dictionaryWithObject:NSFileProtectionComplete forKey:NSFileProtectionKey];
                if (![[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:dbFilePath error:&protectErr]) {
                    NSLog(@"Couldn't protect store: %@",protectErr);
                } else {
                    //reopen the storeDb now that it's protected
                    [self openStoreDatabase];
                    result = YES;
                }
            }
        }
    }
    
    if (!result) {
        NSLog(@"Deleting store dir since we can't set it up properly: %@",self.storeName);
        [[NSFileManager defaultManager] removeItemAtPath:storeDir error:nil];
    }
    return result;
}


+ (NSString*)fullDbFilePathForStoreName:(NSString*)storeName {
    NSString *storePath = [self storeDirectoryForStoreName:storeName];
    NSString *fullDbFilePath = [storePath stringByAppendingPathComponent:kStoreDbFileName];
    return fullDbFilePath;
}

- (BOOL)openStoreDatabase {
    NSString *fullDbFilePath = [self.class fullDbFilePathForStoreName:self.storeName];

    FMDatabase *db = [FMDatabase databaseWithPath:fullDbFilePath ];
    [db setLogsErrors:YES];
    [db setCrashOnErrors:YES];
    if ([db open]) {
        self.storeDb = db;
    } else {
        NSLog(@"Couldn't open store db at: %@ error: %@",fullDbFilePath,[db lastErrorMessage] );
    }
    
    return YES;
}

#pragma mark - Store methods


+ (BOOL)persistentStoreExists:(NSString*)storeName {
    NSString *fullDbFilePath = [self.class fullDbFilePathForStoreName:storeName];
    BOOL result = [[NSFileManager defaultManager] fileExistsAtPath:fullDbFilePath];    
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

+ (NSString *)storeDirectoryForStoreName:(NSString *)storeName {
    //TODO is this the right parent directory from a security & backups standpoint?
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *storesDir = [documentsDirectory stringByAppendingPathComponent:kStoresDirectory];
    NSString *result = [storesDir stringByAppendingPathComponent:storeName];
    
    return result;
}


- (BOOL)createMetaTable {
    NSString *createMetaTableSql = [NSString stringWithFormat:
                                    @"CREATE TABLE IF NOT EXISTS %@ (%@ TEXT, %@ TEXT, %@ TEXT, %@ TEXT )",
                                    SOUP_INDEX_MAP_TABLE,
                                    SOUP_NAME_COL,
                                    PATH_COL,
                                    COLUMN_NAME_COL,
                                    COLUMN_TYPE_COL
                                    ];
    
    NSLog(@"createMetaTableSql: %@",createMetaTableSql);
            
    BOOL result = NO;
    
    @try {
        result =[self.storeDb  executeUpdate:createMetaTableSql];
    }
    @catch (NSException *exception) {
        NSLog(@"Exception creating meta table: %@", exception);
    }
    @finally {
        if (!result) {
            NSLog(@"ERROR %d creating meta table: '%@'", 
            [self.storeDb lastErrorCode], 
            [self.storeDb lastErrorMessage] );
        }
    }
    
    
    return result;
}


#pragma mark - Utility methods


- (BOOL)isFileDataProtectionActive {
    return _dataProtectionKnownAvailable;
}


- (BOOL)upsertIntoTable:(NSString*)tableName values:(NSDictionary*)map  {
    BOOL result = NO;
    
    // map all of the columns and values from soupIndexMapInserts
    __block NSMutableString *fieldNames = [[NSMutableString alloc] init];
    __block NSMutableString *fieldValues = [[NSMutableString alloc] init];
    __block NSUInteger fieldCount = 0;
    
    [map enumerateKeysAndObjectsUsingBlock:
     ^(id key, id obj, BOOL *stop) {
         if (fieldCount > 0) {
             [fieldNames appendFormat:@",%@",key];
             [fieldValues appendFormat:@",\"%@\"",obj];
         } else {
             [fieldNames appendString:key];
             [fieldValues appendFormat:@"\"%@\"",obj];
         }
         fieldCount++;
     }];
    
    
    NSString *upsertSql = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@ (%@) VALUES (%@)", 
                           tableName, fieldNames, fieldValues];
    NSLog(@"upsertSql: %@",upsertSql);
    [fieldNames release]; [fieldValues release];
    result = [self.storeDb executeUpdate:upsertSql];
    
    return result;
    
}



/**
 Reach into JSON object and pull out the value at the path given
 */
- (id)projectIntoJson:(NSDictionary *)jsonObj path:(NSString *)path {
    id result = nil;
    
    if ((nil != jsonObj) && [path length] > 0) {
        id o = jsonObj;
        NSArray *pathElements = [path componentsSeparatedByString:@"."];
        for (NSString *pathElement in pathElements) {
            if ([o isKindOfClass:[NSDictionary class]]) {
                o = [(NSDictionary*)o objectForKey:pathElement];
            } else  {
                NSLog(@"unexpected object in compound path (%@): %@",pathElement, o);
                o = nil;
                break;
            }
        }
        result = o;
    }
    
    return result;
}




#pragma mark - Soup maniupulation methods


- (NSArray*)indicesForSoup:(NSString*)soupName
{
    //look in the cache first
    NSMutableArray *result = [_indexSpecsBySoup objectForKey:soupName];
    if (nil == result) {
        result = [NSMutableArray array];
        
        //no cached indices ...reload from SOUP_INDEX_MAP_TABLE
        NSString *querySql = [NSString stringWithFormat:@"SELECT %@,%@,%@ FROM %@ WHERE %@=\"%@\"",
                              PATH_COL, COLUMN_NAME_COL, COLUMN_TYPE_COL,
                              SOUP_INDEX_MAP_TABLE,
                              SOUP_NAME_COL, soupName];
        FMResultSet *frs = [self.storeDb executeQuery:querySql];
        while([frs next]) {
            NSString *path = [frs stringForColumn:PATH_COL];
            NSString *columnName = [frs stringForColumn:COLUMN_NAME_COL];
            NSString *type = [frs stringForColumn:COLUMN_TYPE_COL];
            
            SFSoupIndex *spec = [[SFSoupIndex alloc] initWithPath:path indexType:type columnName:columnName];
            [result addObject:spec];            
        }
        [frs close];
                              
        //update the cache
        [_indexSpecsBySoup setObject:result forKey:soupName];
    }
    
    return result;
}

- (BOOL)soupExists:(NSString*)soupName {
    BOOL result = [self.storeDb tableExists:soupName];
    return result;
}


- (BOOL)insertIntoSoupIndexMap:(NSArray*)soupIndexMapInserts {
    BOOL result = NO;
    
    // update the mapping table for this soup's columns
    if ([self.storeDb beginTransaction]) {
        for (NSDictionary *map in soupIndexMapInserts) {
            BOOL runOk = [self upsertIntoTable:SOUP_INDEX_MAP_TABLE values:map ];

            if (!runOk) {
                break;
            }
        }
                
        [self.storeDb endTransaction:YES];
        result = YES;
    }
    
    return result;
    
}

- (BOOL)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs
{
    BOOL result = NO;
    
    NSMutableArray *soupIndexMapInserts = [[NSMutableArray alloc] init ];
    NSMutableArray *createIndexStmts = [[NSMutableArray alloc] init ];
    NSMutableString *createTableStmt = [[NSMutableString alloc] init];
    [createTableStmt appendFormat:@"CREATE TABLE IF NOT EXISTS %@ (",soupName];
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
        [values setObject:indexSpec.indexType forKey:COLUMN_TYPE_COL];
        [soupIndexMapInserts addObject:values];
        [values release];
        
        // for creating an index on the soup table
        NSString *indexName = [NSString stringWithFormat:@"%@_%d_idx",soupName,i];
        [createIndexStmts addObject:
         [NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS %@ ON %@ ( %@ )",indexName, soupName, columnName]
         ];
    }
    
    [createTableStmt appendString:@")"];
    NSLog(@"createTableStmt: %@",createTableStmt);

    // create the main soup table
    BOOL runOk = [self.storeDb  executeUpdate:createTableStmt];
    if (!runOk) {
        NSLog(@"ERROR creating soup table  %d %@ stmt: %@", 
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
        result = [self insertIntoSoupIndexMap:soupIndexMapInserts];
        
        
    }
    
    
    return  result;


}




- (void)removeSoup:(NSString*)soupName {
    
    BOOL updatedOK = NO;
    
    @try {
        NSString *dropSql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@",soupName];
        [self.storeDb executeUpdate:dropSql];
        [self.storeDb beginTransaction];
        
        NSString *deleteRowSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=\"%@\"", SOUP_INDEX_MAP_TABLE, SOUP_NAME_COL, soupName];
        updatedOK = [self.storeDb executeUpdate:deleteRowSql withParams:nil];
        if (!updatedOK) {
            NSLog(@"Could not update: %@",deleteRowSql); 
        } else {
            [self.storeDb endTransaction:YES];
        }
    }
    @catch (NSException *exception) {
        NSLog(@"exception removing soup: %@", exception);
    }
    @finally {
        if (!updatedOK) {
            [self.storeDb endTransaction:NO];
        }
    }

}

- (SFSoupCursor *)querySoup:(NSString*)soupName withQuerySpec:(NSDictionary *)querySpec
{
    SFSoupCursor *result = nil;
    //tODO reimpl

    
    return result;
}


- (NSArray *)retrieveEntries:(NSArray*)soupEntryIds fromSoup:(NSString*)soupName
{
    NSArray *result = [NSArray array]; //empty result array by default
    //TODO reimpl

    return result;
}



- (NSDictionary *)insertOneEntry:(NSDictionary*)entry inSoup:(NSString*)soupName
{
    NSArray *indices = [self indicesForSoup:soupName];
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSNumber *nowVal = [NSNumber numberWithDouble:now];
    NSMutableDictionary *baseColumns = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                          @"", SOUP_COL,
                                          nowVal, CREATED_COL,
                                          nowVal, LAST_MODIFIED_COL,
                                          nil];
    
    //build up the set of index column values for this row
    for (SFSoupIndex *idx in indices) {
        NSString *indexColVal = [self projectIntoJson:entry path:[idx path]];
        if (nil != indexColVal) {
            NSString *colName = [idx columnName];
            //not every entry will have a value for each index column
            [baseColumns setObject:indexColVal forKey:colName];
        }
    }
    
    BOOL insertOk =[self upsertIntoTable:soupName values:baseColumns ];
    if (!insertOk) {
        return nil;
    }
          
    NSMutableDictionary *mutableEntry = [entry mutableCopy];
    //set the newly-calculated entry ID so that our next update will update this entry (and not create a new one)
    NSInteger lastInsertedRowId = [self.storeDb lastInsertRowId];
    NSNumber *newEntryId = [NSNumber numberWithInteger:lastInsertedRowId];
    [mutableEntry setValue:newEntryId forKey:SOUP_ENTRY_ID];
    [mutableEntry setValue:nowVal forKey:SOUP_LAST_MODIFIED_DATE];
             
    NSString *rawJson = [SFJsonUtils JSONRepresentation:mutableEntry];
    NSArray *binds = [NSArray arrayWithObjects:
                      newEntryId,
                      rawJson,
                      nil];
    NSString *updateSql = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@ (%@,%@) VALUES (?,?)", soupName, ID_COL, SOUP_COL];

    BOOL updateOk = [self.storeDb executeUpdate:updateSql withParams:binds];
    
    [mutableEntry autorelease];
    if (!updateOk) {
        mutableEntry = nil;
    }
    
    return mutableEntry;
}


- (NSDictionary *)updateOneEntry:(NSDictionary*)entry withEntryId:(NSString*)entryId inSoup:(NSString*)soupName
{
    NSDictionary *result = nil;
    
    NSArray *indices = [self indicesForSoup:soupName];
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSNumber *nowVal = [NSNumber numberWithDouble:now];
    
    NSMutableDictionary *mutableEntry = [entry mutableCopy];
    [mutableEntry setValue:nowVal forKey:SOUP_LAST_MODIFIED_DATE];


    
    //build up the set of index column values for this row
    for (SFSoupIndex *idx in indices) {
        NSString *indexColVal = [self projectIntoJson:entry path:[idx path]];
        if (nil != indexColVal) {
            NSString *colName = [idx columnName];
            //not every entry will have a value for each index column
            [baseColumns setObject:indexColVal forKey:colName];
        }
    }
    
    BOOL insertOk =[self upsertIntoTable:soupName values:baseColumns ];
    if (!insertOk) {
        return nil;
    }
        
    NSString *rawJson = [SFJsonUtils JSONRepresentation:mutableEntry];
    NSArray *binds = [NSArray arrayWithObjects:
                      entryId,
                      nowVal,
                      rawJson,
                      nil];
    NSString *updateSql = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@ (%@,%@,%@) VALUES (?,?,?)", soupName, ID_COL, LAST_MODIFIED_COL, SOUP_COL];
    BOOL updateOk = [self.storeDb executeUpdate:updateSql withParams:binds];
    
    [mutableEntry autorelease];
    if (!updateOk) {
        mutableEntry = nil;
    }
    
    return mutableEntry;
    
    
    return result; 
}


- (NSDictionary *)upsertOneEntry:(NSDictionary *)entry inSoup:(NSString*)soupName {
    NSDictionary *result = nil;
    
    NSString *soupEntryId = [entry objectForKey:SOUP_ENTRY_ID];
    if (nil != soupEntryId) {
        //entry already has an entry id: update
        result = [self updateOneEntry:entry withEntryId:soupEntryId inSoup:soupName];
    } else {
        //no entry id: insert
        result = [self insertOneEntry:entry inSoup:soupName];
    }
    
    return result;
}



- (NSArray*)upsertEntries:(NSArray*)entries toSoup:(NSString*)soupName
{
    NSMutableArray *result = [NSMutableArray array]; //empty result array by default
    
    [self.storeDb beginTransaction];
    
    for (NSDictionary *entry in entries) {
        NSDictionary *upsertedEntry = [self upsertOneEntry:entry inSoup:soupName];
        if (nil != upsertedEntry) {
            [result addObject:upsertedEntry];
        }
    }
    
    [self.storeDb endTransaction:YES];
    

    return result;
}

- (void)removeEntries:(NSArray*)entryIds fromSoup:(NSString*)soupName
{
    //TODO reimpl

    
}







@end
