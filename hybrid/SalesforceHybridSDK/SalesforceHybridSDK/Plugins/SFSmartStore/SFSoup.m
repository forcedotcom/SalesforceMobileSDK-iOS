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

#import "SFSoup.h"

#import "SFSmartStore.h"
#import "SFSoupCursor.h"

#import "FMDatabase.h"
//#import "SBJson.h"
#import "SFSoupIndex.h"
#import "SFJsonUtils.h"


@interface SFSoup () {
    FMDatabase *_soupDb;
    NSMutableArray *_soupIndices;
}

@property (nonatomic, retain) FMDatabase *soupDb;

@property (nonatomic, retain) NSMutableArray *soupIndices;


@end


@implementation SFSoup

@synthesize name = _name;
@synthesize soupDb = _soupDb;
@synthesize soupIndices = _soupIndices;

static NSString * const kSoupTableFileName = @"mainTable.sqlite";
static NSString * const kMasterSoupTableName = @"_soupMaster";

static NSString * const kColNameEntryId = @"_soupEntryId";
static NSString * const kColNameModDate = @"_soupLastModifiedDate";
static NSString * const kColNameExtFileRef = @"_file_ref";
static NSString * const kColNameRawJson = @"_raw_json";



//create new soup on disk
- (id)initWithName:(NSString *)name indexes:(NSArray*)indexes atPath:(NSString*)path
{
    self = [super init];
    
    if (nil != self) {
        _name = [name copy];
        _soupPath = [path copy];
        _indexTablePath = [[_soupPath stringByAppendingPathComponent:kSoupTableFileName] retain];
        self.soupIndices = [NSMutableArray array];
        
        //process the desired indexes
        NSMutableString *sb = [[NSMutableString alloc] init];
        for (NSUInteger i = 0; i < [indexes count]; i++) {
            NSDictionary *indexSpec = [indexes objectAtIndex:i];
            SFSoupIndex *idx = [[SFSoupIndex alloc] initWithIndexSpec:indexSpec];
            
            if (i > 0) {
                [sb appendString:@", "];
            }
            
            
            if ([idx.indexType isEqualToString:kSoupIndexTypeString]) {
                [sb appendFormat:@"%@ TEXT",idx.indexedColumnName];
            } else if ([idx.indexType isEqualToString:kSoupIndexTypeDate]) {
                [sb appendFormat:@"%@ REAL",idx.indexedColumnName];
            }
            
            [self.soupIndices addObject:idx];
            [idx release];
        }
        
        
        //TODO any need to check whether this db already exists?
        FMDatabase *db = [FMDatabase databaseWithPath:_indexTablePath ];
        [db setLogsErrors:YES];
        [db setCrashOnErrors:YES];
        [db open];
        
        NSString *createStr = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ ( %@ INTEGER PRIMARY KEY AUTOINCREMENT, %@ REAL, %@, %@ TEXT, %@ TEXT)",
                               kMasterSoupTableName,kColNameEntryId,kColNameModDate,sb,kColNameExtFileRef,kColNameRawJson];
        [sb release];
        
        NSLog(@"soup create str: %@",createStr);
        BOOL runOk =[db executeUpdate:createStr];
        if (!runOk) {
            NSLog(@"error creating index  %d %@", [db lastErrorCode], [db lastErrorMessage] );
        }
        
        //add indices
        for (SFSoupIndex *idx in self.soupIndices) {
            NSString *ixSql = [idx createSqlWithTableName:kMasterSoupTableName];
            
            runOk = [db executeUpdate:ixSql];
            if (!runOk) {
                NSLog(@"error creating index  %d %@", [db lastErrorCode], [db lastErrorMessage] );
            }
        }
        [db close]; //need to close before setting encryption
            

        //setup the sqlite file with encryption        
        NSError *error = nil;
        NSDictionary *attr = [NSDictionary dictionaryWithObject:NSFileProtectionComplete forKey:NSFileProtectionKey];
        if (![[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:_indexTablePath error:&error]) {
            NSLog(@"Couldn't create soup: %@",error);
            [self release];
            self = nil;
        } 
        
        if (nil != self) {
            self.soupDb = [FMDatabase databaseWithPath:_indexTablePath];
            [self.soupDb setLogsErrors:YES];
            [self.soupDb setCrashOnErrors:YES];
            [self.soupDb open];
        }
    }
    
    return self;
}

//load existing soup
- (id)initWithName:(NSString *)name fromPath:(NSString *)path {
    self = [super init];
    
    if (nil != self) {
        _name = [name copy];
        _soupPath = [path copy];
        _indexTablePath = [[_soupPath stringByAppendingPathComponent:kSoupTableFileName] retain];

    
        // open db file
        FMDatabase *db = [FMDatabase databaseWithPath:_indexTablePath ];
        [db setLogsErrors:YES];
        [db setCrashOnErrors:YES];
        [db open];
        
        //SELECT name FROM sqlite_master WHERE type='index' ORDER BY name 
        //table_name is the name for the table to which the index belongs
        
        //Load indices from db file, translate to objects
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM sqlite_master WHERE type='index' ORDER BY name"];
        FMResultSet *frs = [db executeQuery:sql];
        
        while([frs next]) {
//            NSString *nameCol = [frs stringForColumn:@"name"];
//            NSString *typeCol = [frs stringForColumn:@"type"];
//            NSString *tblNameCol = [frs stringForColumn:@"tbl_name"];
//            NSLog(@"index: name %@ type %@ tbl_name %@ sql %@",nameCol,typeCol,tblNameCol,sqlCol);

            NSString *sqlCol = [frs stringForColumn:@"sql"];
            SFSoupIndex *idx = [[SFSoupIndex alloc] initWithSql:sqlCol];
            [self.soupIndices addObject:idx];
            [idx release];
            
        }
        [frs close];
        
        self.soupDb = db;
    
    }
    
    return self;
}


- (void)dealloc {
    [self.soupDb close];
    self.soupDb = nil;
    [_name release]; _name = nil;
    [_soupPath release]; _soupPath = nil;
    [_indexTablePath release]; _indexTablePath = nil;
    [super dealloc];
}





- (SFSoupCursor*)query:(NSDictionary*)querySpec {
    NSMutableArray *resultEntries = [NSMutableArray array];
    
    id indexPath = [querySpec valueForKey:@"indexPath"];
    id matchKey = [querySpec valueForKey:@"matchKey"];
    
//    NSString *beginKey = [querySpec objectForKey:@"beginKey"];
//    NSString *endKey = [querySpec objectForKey:@"endKey"];
//    NSString *beginKeyExcl = [querySpec objectForKey:@"beginKeyExcl"];
//    NSString *endKeyExcl = [querySpec objectForKey:@"endKeyExcl"];

                                                        
    NSString *querySql;
    if ((matchKey != [NSNull null]) && (indexPath != [NSNull null])) {
        NSString *columnPath = [SFSoupIndex indexColumnNameForKeyPath:indexPath];
        querySql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@='%@\'",kMasterSoupTableName,columnPath, matchKey];
    } 
    //TODO handle begin/end keys
    else {
        querySql = [NSString stringWithFormat:@"SELECT * FROM %@ ",kMasterSoupTableName];
    }
    NSLog(@"querySql:\n %@",querySql);
    
    FMResultSet *frs = [self.soupDb executeQuery:querySql];
    while([frs next]) {
        NSString *rawJson = [frs stringForColumn:kColNameRawJson];
        NSDictionary *entry = (NSDictionary *)[SFJsonUtils objectFromJSONString:rawJson];
        if (nil != entry) {
            [resultEntries addObject:entry];
        }
    }
    [frs close];
    
    SFSoupCursor *result = [[SFSoupCursor alloc] initWithSoupName:self.name querySpec:querySpec entries:resultEntries];
    
    return [result autorelease];
}

- (NSDictionary*)retrieveEntry:(NSString*)soupEntryId
{
    NSDictionary *entry = nil;
    NSString *querySql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@='%@\'",kMasterSoupTableName,kColNameEntryId, soupEntryId];

    NSLog(@"querySql:\n %@",querySql);
    
    FMResultSet *frs = [self.soupDb executeQuery:querySql];
    while([frs next]) {
        NSString *rawJson = [frs stringForColumn:kColNameRawJson];
        entry = [SFJsonUtils objectFromJSONString:rawJson];
    }
    [frs close];
    
    return entry;
}

- (NSArray*)retrieveEntries:(NSArray*)entryIds {
    NSMutableArray *result = [NSMutableArray array];

    for (id soupEntryId in entryIds) {
        if ([soupEntryId isKindOfClass:[NSNumber class]]) {
            soupEntryId = [(NSNumber*)soupEntryId stringValue];
        }
        NSDictionary *entry = [self retrieveEntry:soupEntryId];
        if (nil != entry) {
            [result addObject:entry];
        }
    }
    
    return result;
}


- (NSArray*)upsertEntries:(NSArray*)entries {

    NSDate *startTime = [NSDate date];
    NSNumber *lastModTime = [NSNumber numberWithDouble:[startTime timeIntervalSinceReferenceDate]];

    NSMutableArray *resultEntries = [NSMutableArray array];
    
    
    if (![self.soupDb beginTransaction])
        return nil; 
    
    for (NSDictionary *entry in entries) {
        NSMutableArray *binds = [NSMutableArray array];
        NSMutableString *fieldNames = [NSMutableString string];
        NSMutableString *fieldVals = [NSMutableString string];
        
        NSString *existSoupId = [entry objectForKey:kColNameEntryId];

        // A soup entry row looks something like this:
        //_soupEntryId text primary key, 
        //_soupLastModifiedDate ,
        // [idx_foo values],
        // fileRef
        // raw_json
        
        
        //update the _soupLastModifiedDate
        [fieldNames appendString:kColNameModDate];
        [fieldVals appendString:@"?"];
        [binds addObject:lastModTime];
         
        //update all the indexed values (idx_foo)
        for (SFSoupIndex *idx  in self.soupIndices) {
            NSString *keyPath = idx.keyPath;
            NSObject *val = [entry valueForKeyPath:keyPath]; //TODO check compound paths
            //NSObject *val = [entry objectForKey:keyPath]; //TODO handle compound paths
            //not all indexed paths will have values in every entry
            if (nil != val) {
                [fieldNames appendFormat:@",%@", idx.indexedColumnName];
                [fieldVals appendString:@",?"];
                [binds addObject:val];
            }
        }
        
        NSString *rawJson = nil;
        //NOTE we do NOT insert the raw_json on an initial Insert..we wait until we
        //have the lastInsertRowId and then add it as _soupEntryId along with the raw_json
        //in a followup REPLACE / update
        
        if (nil != existSoupId) {
            //set the existing entry ID so that any field changes will replace the existing entry
            [fieldNames appendFormat:@",%@", kColNameEntryId];
            [fieldVals appendString:@",?"];
            [binds addObject:existSoupId];
            // append the raw json on an Update
            rawJson = [SFJsonUtils JSONRepresentation:entry];
            [fieldNames appendFormat:@",%@", kColNameRawJson];
            [fieldVals appendString:@",?"];
            [binds addObject:rawJson];
        }
        
        
        //TODO check whether the object is large and use fileRef instead?
        
        NSString *upsertSql = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@ (%@) VALUES (%@)", kMasterSoupTableName, fieldNames, fieldVals];
        //NSLog(@"upsertSql: %@",upsertSql);
        BOOL ok = [self.soupDb executeUpdate:upsertSql withParams:binds];
        if (!ok) {
            NSLog(@"error executing upsert %d %@", [self.soupDb lastErrorCode], [self.soupDb lastErrorMessage] );
        } else {        
            if (nil == existSoupId) {
                //this is an Insert
                //need to grab the _soupEntryId from the saved object, stuff it into the raw json
                
                NSMutableDictionary *mutableEntry = [entry mutableCopy];
                NSInteger lastInsertedRowId = [self.soupDb lastInsertRowId];
                NSNumber *newEntryId = [NSNumber numberWithInteger:lastInsertedRowId];
                
                //set the newly-calculated entry ID so that our next update will update this entry (and not create a new one)
                [fieldNames appendFormat:@",%@", kColNameEntryId];
                [fieldVals appendString:@",?"];
                [binds addObject:newEntryId];
                
                //insert _soupEntryId into the rawJson object
                [mutableEntry setValue:newEntryId forKey:kColNameEntryId];
                //It appears there's a bug in NSJSONSerialization that requires final dictionaries
                NSDictionary *finalEntry = [NSDictionary dictionaryWithDictionary:mutableEntry];
                [mutableEntry release];
                rawJson = [SFJsonUtils JSONRepresentation:finalEntry];

                [fieldNames appendFormat:@",%@", kColNameRawJson];
                [fieldVals appendString:@",?"];
                [binds addObject:rawJson];

                
                NSString *updateSql = [NSString stringWithFormat:@"REPLACE INTO %@ (%@) VALUES (%@)", kMasterSoupTableName, fieldNames, fieldVals];
                //NSLog(@"updateSql: %@",updateSql);

                ok = [self.soupDb executeUpdate:updateSql withParams:binds];
                if (!ok) {
                    NSLog(@"error executing update %d %@", [self.soupDb lastErrorCode], [self.soupDb lastErrorMessage] );
                } else {
                    [resultEntries addObject:finalEntry];
                }

            } else {
                //this is an Update
                [resultEntries addObject:entry];
            }
        }

    }
    [self.soupDb endTransaction:YES];

    
    NSTimeInterval elapsed = [startTime timeIntervalSinceNow];
    NSLog(@"upserting %d took %f",[resultEntries count],elapsed);

    return resultEntries ;

}


- (void)removeEntries:(NSArray*)entryIds
{
    NSDate *startTime = [NSDate date];
    
    if (![self.soupDb beginTransaction])
        return;
    
    for (NSString *entryId in entryIds) {
        NSString *deleteRowSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=%@", kMasterSoupTableName, kColNameEntryId, entryId];
        BOOL ok = [self.soupDb executeUpdate:deleteRowSql withParams:nil];
        if (!ok) {
            NSLog(@"Could not delete: %@",entryId); //TODO hand back error?
        }
    }

    [self.soupDb endTransaction:YES];
    NSTimeInterval elapsed = [startTime timeIntervalSinceNow];
    NSLog(@"removing %d took %f",[entryIds count],elapsed);

}


@end
