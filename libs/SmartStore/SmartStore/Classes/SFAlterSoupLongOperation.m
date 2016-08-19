/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFAlterSoupLongOperation.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "SFSmartStore+Internal.h"
#import "SFSoupSpec.h"
#import "SFSoupIndex.h"
#import <SalesforceSDKCore/SFJsonUtils.h>

@interface SFAlterSoupLongOperation ()

@property (nonatomic, readwrite, strong) NSString *soupName;
@property (nonatomic, readwrite, strong) NSString *soupTableName;
@property (nonatomic, readwrite, assign) SFAlterSoupStep afterStep;
@property (nonatomic, readwrite, strong) SFSoupSpec *soupSpec;
@property (nonatomic, readwrite, strong) SFSoupSpec *oldSoupSpec;
@property (nonatomic, readwrite, strong) NSArray *indexSpecs;
@property (nonatomic, readwrite, strong) NSArray *oldIndexSpecs;
@property (nonatomic, readwrite, assign) BOOL  reIndexData;
@property (nonatomic, readwrite, strong) SFSmartStore *store;
@property (nonatomic, readwrite, strong) FMDatabaseQueue *queue;
@property (nonatomic, readwrite, assign) long long rowId;

@end

@implementation SFAlterSoupLongOperation

- (id) initWithStore:(SFSmartStore*)store soupName:(NSString*)soupName newIndexSpecs:(NSArray*)newIndexSpecs reIndexData:(BOOL)reIndexData
{
    return [self initWithStore:store soupName:soupName newSoupSpec:nil newIndexSpecs:newIndexSpecs reIndexData:reIndexData];
}

- (id) initWithStore:(SFSmartStore*)store soupName:(NSString*)soupName newSoupSpec:(SFSoupSpec*)newSoupSpec newIndexSpecs:(NSArray*)newIndexSpecs reIndexData:(BOOL)reIndexData
{
    self = [super init];
    if (nil != self) {
        _store = store;
        _queue = store.storeQueue;
        _soupName = soupName;
        _soupSpec = newSoupSpec;
        _indexSpecs = [SFSoupIndex asArraySoupIndexes:newIndexSpecs];
        _oldIndexSpecs = [store indicesForSoup:soupName];
        _reIndexData = reIndexData;
        _afterStep = SFAlterSoupStepStarting;
        [store.storeQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            self->_soupTableName = [store tableNameForSoup:soupName withDb:db];
            self->_oldSoupSpec = [store attributesForSoup:soupName withDb:db];
            self->_rowId = [self createLongOperationDbRowWithDb:db];
        }];
    }
    return self;
}

- (id) initWithStore:(SFSmartStore*) store rowId:(long) rowId details:(NSDictionary*)details status:(SFAlterSoupStep)status
{
    self = [super init];
    if (nil != self) {
        _store = store;
        _queue = store.storeQueue;
        _rowId = rowId;
        _soupName = details[SOUP_NAME];
        _soupTableName = details[SOUP_TABLE_NAME];
        _soupSpec = [SFSoupSpec newSoupSpecWithDictionary:details[NEW_SOUP_SPEC]];
        _oldSoupSpec = [SFSoupSpec newSoupSpecWithDictionary:details[OLD_SOUP_SPEC]];
        _indexSpecs = [SFSoupIndex asArraySoupIndexes:details[NEW_INDEX_SPECS]];
        _oldIndexSpecs = [SFSoupIndex asArraySoupIndexes:details[OLD_INDEX_SPECS]];
        _reIndexData = [details[RE_INDEX_DATA] boolValue];
        _afterStep = status;
        
        // No old soup spec? Means SmartStore was updated,
        // from a version that didn't support SFSoupSpec,
        // and there was an incomplete long operation.
        if (!_oldSoupSpec) {
            // Use a default SFSoupSpec that represents a soup without any features.
            _oldSoupSpec = [SFSoupSpec newSoupSpec:_soupName withFeatures:nil];
        }
    }
    return self;
}

- (NSString*) description
{
    NSString *soupSpecDescription = @"";
    if (self.soupSpec) {
        soupSpecDescription = [NSString stringWithFormat:@"oldSoupSpec=%@ newSoupSpec=%@",
                               [SFJsonUtils JSONRepresentation:[self.oldSoupSpec asDictionary]],
                               [SFJsonUtils JSONRepresentation:[self.soupSpec asDictionary]]
                               ];
    }
    
    return [NSString stringWithFormat:@"AlterSoupOperation = {rowId=%lld soupName=%@ soupTableName=%@ afterStep=%lu reIndexData=%@ %@ oldIndexSpecs=%@ newIndexSpecs=%@}\n",
            self.rowId,
            self.soupName,
            self.soupTableName,
            (unsigned long)self.afterStep,
            self.reIndexData ? @"YES" : @"NO",
            soupSpecDescription,
            [SFJsonUtils JSONRepresentation:[SFSoupIndex asArrayOfDictionaries:self.oldIndexSpecs withColumnName:YES]],
            [SFJsonUtils JSONRepresentation:[SFSoupIndex asArrayOfDictionaries:self.indexSpecs  withColumnName:YES]]
            ];
}

- (void) run
{
    [self runToStep:kLastStep];
}

- (void) runToStep:(SFAlterSoupStep) toStep
{
    // NB: if failure happens in a middle of a step before status row is updated (e.g. in steps that do ddl steps)
    //     it should be safe to re-play that step
    switch(self.afterStep) {
		case SFAlterSoupStepStarting:
			[self renameOldSoupTable];
			if (toStep == SFAlterSoupStepRenameOldSoupTable) break;
		case SFAlterSoupStepRenameOldSoupTable:
            [self dropOldIndexes];
			if (toStep == SFAlterSoupStepDropOldIndexes) break;
		case SFAlterSoupStepDropOldIndexes:
			[self registerSoupUsingTableName];
			if (toStep == SFAlterSoupStepRegisterSoupUsingTableName) break;
		case SFAlterSoupStepRegisterSoupUsingTableName:
			[self copyTable];
			if (toStep == SFAlterSoupStepCopyTable) break;
		case SFAlterSoupStepCopyTable:
			// Re-index soup (if requested)
			if (self.reIndexData)
				[self reIndexSoup];
			if (toStep == SFAlterSoupStepReIndexSoup) break;
		case SFAlterSoupStepReIndexSoup:
			[self dropOldTable];
			if (toStep == SFAlterSoupStepDropOldTable) break;
		case SFAlterSoupStepDropOldTable:
            [self cleanup];
            if (toStep == SFAlterSoupStepCleanup) break;
        case SFAlterSoupStepCleanup:
			// Nothing left to do
			break;
    }
}

/**
 Step 1: rename old table
 */
- (void) renameOldSoupTable
{
    [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        //TODO if app crashed after alter and before status row update, the re-play would fail
        //     we should only do the alter table if the x_old table is not found
        // Rename backing table for soup
        NSString* sql = [NSString stringWithFormat:@"ALTER TABLE %@ RENAME TO %@_old", self.soupTableName, self.soupTableName];
        [self executeUpdate:db sql:sql context:@"renameOldSoupTable"];
        
        // Renaming fts table if any
        if ([SFSoupIndex hasFts:self.oldIndexSpecs]) {
            NSString* sql = [NSString stringWithFormat:@"ALTER TABLE %@_fts RENAME TO %@_fts_old", self.soupTableName, self.soupTableName];
            [self executeUpdate:db sql:sql context:@"renameOldSoupTable-fts"];
        }
        
        // Update row in alter status table
        [self updateLongOperationDbRow:SFAlterSoupStepRenameOldSoupTable withDb:db];
    }];
}


/**
 Step 2: drop old indexes / remove entries in soup_index_map / cleanup cache
 */
- (void) dropOldIndexes
{
    [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        // Removing db indexes on table (otherwise registerSoup will fail to create indexes with the same name)
        NSMutableArray* dropIndexStatements = [NSMutableArray new];
        NSString* dropIndexFormat = @"DROP INDEX IF EXISTS %@_%@_idx";
        for (NSString* col in @[CREATED_COL, LAST_MODIFIED_COL]) {
            [dropIndexStatements addObject:[NSString stringWithFormat:dropIndexFormat, self.soupTableName, col]];
        }
        for (int i=0; i<[self.oldIndexSpecs count]; i++) {
            [dropIndexStatements addObject:[NSString stringWithFormat:dropIndexFormat, self.soupTableName, [NSString stringWithFormat:@"%d", i]]];
        }
        for (NSString* dropIndexStatement in dropIndexStatements) {
            [self executeUpdate:db sql:dropIndexStatement context:@"dropOldIndexes"];
        }
        
        // Removing row from soup index map table
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=\"%@\"",
                         SOUP_INDEX_MAP_TABLE, SOUP_NAME_COL, self.soupName];
        [self executeUpdate:db sql:sql context:@"dropOldIndexes"];
        
        // Update row in alter status table
        [self updateLongOperationDbRow:SFAlterSoupStepDropOldIndexes withDb:db];
        
        // Remove soup from cache
        [self.store removeFromCache:self.soupName];
    }];
}


/**
 Step 3: register soup with new (optional) soup spec, and new indexes
 */
- (void) registerSoupUsingTableName
{
    [_queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        // Use new specs if possible, otherwise just use old specs.
        SFSoupSpec *specToRegister = self.soupSpec ?: self.oldSoupSpec;
        [self.store registerSoupWithSpec:specToRegister withIndexSpecs:self.indexSpecs withSoupTableName:self.soupTableName withDb:db];
        
        // Update row in alter status table -auto commit
        [self updateLongOperationDbRow:SFAlterSoupStepRegisterSoupUsingTableName withDb:db];
    }];
}


/**
 Step 4: copy data from old soup table to new soup table
 */
- (void) copyTable
{
    [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        // We need column names in the index specs
        self->_indexSpecs = [self.store indicesForSoup:self.soupName withDb:db];
		
        // Move data (core columns + indexed paths that we are still indexing)
        NSDictionary* mapOldSpecs = [SFSoupIndex mapForSoupIndexes:self.oldIndexSpecs];
        NSDictionary* mapNewSpecs = [SFSoupIndex mapForSoupIndexes:self.indexSpecs];
        
        // Figuring out paths we are keeping
        NSSet* oldPaths = [NSSet setWithArray:[mapOldSpecs allKeys]];
        NSMutableSet* keptPaths = [NSMutableSet setWithArray:[mapNewSpecs allKeys]];
        [keptPaths intersectSet:oldPaths];
        
        // Compute list of columns to copy from / list of columns to copy into
        NSMutableArray* oldColumns = [NSMutableArray arrayWithObjects:ID_COL, CREATED_COL, LAST_MODIFIED_COL, nil];
        NSMutableArray* newColumns = [NSMutableArray arrayWithObjects:ID_COL, CREATED_COL, LAST_MODIFIED_COL, nil];
        
        BOOL oldSoupUsesExternalStorage = [self.oldSoupSpec.features containsObject:kSoupFeatureExternalStorage];
        BOOL newSoupUsesExternalStorage = [self.soupSpec.features containsObject:kSoupFeatureExternalStorage];
        // Old specs uses internal storage, and
        // no new specs or new specs still uses internal storage
        if (!oldSoupUsesExternalStorage && !newSoupUsesExternalStorage) {
            [oldColumns addObject:SOUP_COL];
            [newColumns addObject:SOUP_COL];
        }
        
        // Adding indexed path columns that we are keeping
        for (NSString* keptPath in keptPaths) {
            SFSoupIndex* oldIndexSpec = mapOldSpecs[keptPath];
            SFSoupIndex* newIndexSpec = mapNewSpecs[keptPath];
            
            if (newIndexSpec.columnType == nil) {
                // we are now using json1, there is no column to populate
                continue;
            }
            
            if ([oldIndexSpec.columnType isEqualToString:newIndexSpec.columnType]) {
                [oldColumns addObject:oldIndexSpec.columnName];
                [newColumns addObject:newIndexSpec.columnName];
            }
        }
        
        // Compute copy statement
        NSString* copySql = [NSString stringWithFormat:@"INSERT INTO %@ (%@) SELECT %@ FROM %@_old",
                             self.soupTableName,
                             [newColumns componentsJoinedByString:@","],
                             [oldColumns componentsJoinedByString:@","],
                             self.soupTableName
                             ];
        [self executeUpdate:db sql:copySql context:@"copyTable"];
        
        // Fts
        if ([SFSoupIndex hasFts:self.indexSpecs]) {
            NSMutableArray* oldColumnsFts = [NSMutableArray arrayWithObjects:ID_COL, nil];
            NSMutableArray* newColumnsFts = [NSMutableArray arrayWithObjects:ROWID_COL, nil];

            // Adding indexed path columns that we are keeping
            for (NSString* keptPath in keptPaths) {
                SFSoupIndex* oldIndexSpec = mapOldSpecs[keptPath];
                SFSoupIndex* newIndexSpec = mapNewSpecs[keptPath];
                if ([oldIndexSpec.columnType isEqualToString:newIndexSpec.columnType]
                    && [newIndexSpec.indexType isEqualToString:kSoupIndexTypeFullText]) {
                    [oldColumnsFts addObject:oldIndexSpec.columnName];
                    [newColumnsFts addObject:newIndexSpec.columnName];
                }
            }

            // Compute copy statement for fts table
            NSString* copyFtsSql = [NSString stringWithFormat:@"INSERT INTO %@_fts (%@) SELECT %@ FROM %@_old",
                                    self.soupTableName,
                                    [newColumnsFts componentsJoinedByString:@","],
                                    [oldColumnsFts componentsJoinedByString:@","],
                                    self.soupTableName
                                    ];
            [self executeUpdate:db sql:copyFtsSql context:@"copyTable-fts"];
        }
 
 		// Exchange internal<->external storage
        if (self.soupSpec) {
            BOOL oldSoupUsesExternalStorage = [self.oldSoupSpec.features containsObject:kSoupFeatureExternalStorage];
            BOOL newSoupUsesExternalStorage = [self.soupSpec.features containsObject:kSoupFeatureExternalStorage];
            
            // Internal -> External
            if (!oldSoupUsesExternalStorage && newSoupUsesExternalStorage) {
                NSString *selectIdSoupSql = [NSString stringWithFormat:@"SELECT %@, %@ FROM %@_old", ID_COL, SOUP_COL, self.soupTableName];
                FMResultSet *resultSet = [db executeQuery:selectIdSoupSql];
                while ([resultSet next]) {
                    @autoreleasepool {
                        NSNumber *soupEntryId = @([resultSet longForColumn:ID_COL]);
                        NSString *rawJson = [resultSet stringForColumn:SOUP_COL];
                        NSDictionary *entry = [SFJsonUtils objectFromJSONString:rawJson];
                        BOOL didSave = [self.store saveSoupEntryExternally:entry
                                                               soupEntryId:soupEntryId
                                                             soupTableName:self.soupTableName];
                        if (!didSave) {
                            @throw [NSException exceptionWithName:@"Failed to save external soup file in alter soup."
                                                           reason:nil
                                                         userInfo:nil];
                        }
                    }
                }
                [resultSet close];
            }
            // External -> Internal
            else if (oldSoupUsesExternalStorage && !newSoupUsesExternalStorage) {
                NSString *selectIdSql = [NSString stringWithFormat:@"SELECT %@ FROM %@_old", ID_COL, self.soupTableName];
                FMResultSet *resultSet = [db executeQuery:selectIdSql];
                while ([resultSet next]) {
                    @autoreleasepool {
                        NSNumber *soupEntryId = @([resultSet longForColumn:ID_COL]);
                        id entry = [self.store loadExternalSoupEntry:soupEntryId soupTableName:self.soupTableName];
                        if (!entry) {
                            @throw [NSException exceptionWithName:@"Failed to load external soup file in alter soup."
                                                           reason:nil
                                                         userInfo:nil];
                        }
                        NSString *rawJson = [SFJsonUtils JSONRepresentation:entry];
                        [self.store updateTable:self.soupTableName
                                         values:@{SOUP_COL: rawJson}
                                        entryId:soupEntryId
                                          idCol:ID_COL
                                         withDb:db];
                    }
                }
                [resultSet close];
                // External files delete: they will only get deleted when the whole long operation completes with success.
            }
        }
        // Update row in alter status table
        [self updateLongOperationDbRow:SFAlterSoupStepCopyTable withDb:db];
    }];
}


/**
 Step 5: re-index soup for new indexes (optional step)
 */
- (void) reIndexSoup
{
    [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        NSMutableSet* oldPathTypeSet = [NSMutableSet set];
        // Putting path--type of old index specs in a set
        for(SFSoupIndex* oldIndexSpec in self.oldIndexSpecs) {
            [oldPathTypeSet addObject:[oldIndexSpec getPathType]];
        }
        
        // Filtering out the ones that do not have their path--type in oldPathTypeSet
        NSMutableArray * indexPaths = [NSMutableArray array];
        for (SFSoupIndex* indexSpec in self.indexSpecs) {
            if (![oldPathTypeSet containsObject:[indexSpec getPathType]]) {
                [indexPaths addObject:indexSpec.path];
            }
        }
        
        // Re-index soup
        [self.store reIndexSoup:self.soupName withIndexPaths:indexPaths withDb:db];
        
        // Update row in alter status table
        [self updateLongOperationDbRow:SFAlterSoupStepReIndexSoup withDb:db];
         
    }];
}


/**
 Step 6: drop old soup table
 */
- (void) dropOldTable
{
    [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        // Drop old table
        NSString* sql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@_old", self.soupTableName];
        [self executeUpdate:db sql:sql context:@"dropOldTable"];
        
        // Dropping fts table if any
        if ([SFSoupIndex hasFts:self.oldIndexSpecs]) {
            NSString* sql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@_fts_old", self.soupTableName];
            [self executeUpdate:db sql:sql context:@"dropOldTable-fts"];
        }
        
        // Update status row - auto commit
        [self updateLongOperationDbRow:SFAlterSoupStepDropOldTable withDb:db];
    }];
}


/**
 Step 7: cleanup
 */
- (void) cleanup
{
    
    BOOL oldSoupUsesExternalStorage = [self.oldSoupSpec.features containsObject:kSoupFeatureExternalStorage];
    BOOL newSoupUsesExternalStorage = [self.soupSpec.features containsObject:kSoupFeatureExternalStorage];
    
    // Cleanup external soup files, if a External -> Internal conversion happened
    if (oldSoupUsesExternalStorage && !newSoupUsesExternalStorage) {
        [self.store deleteAllExternalEntries:self.soupTableName deleteDir:YES];
    }
    
    // Update status row
    [_queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [self updateLongOperationDbRow:SFAlterSoupStepCleanup withDb:db];
    }];
}


/**
 Create row in long operations status table for a new alter soup operation
 @return row id
 */
- (long long) createLongOperationDbRowWithDb:(FMDatabase*) db
{
    NSNumber* now = [self.store currentTimeInMilliseconds];
    NSMutableDictionary* values = [NSMutableDictionary dictionary];
    values[TYPE_COL] = @"AlterSoup";
    values[DETAILS_COL] = [SFJsonUtils JSONRepresentation:[self getDetails]];
    values[STATUS_COL] = @(SFAlterSoupStepStarting);
    values[CREATED_COL] = now;
    values[LAST_MODIFIED_COL] = now;
    [self.store insertIntoTable:LONG_OPERATIONS_STATUS_TABLE values:values withDb:db];
    return [db lastInsertRowId];
}

- (NSDictionary*) getDetails
{
    NSMutableDictionary* details = [NSMutableDictionary dictionary];
    details[SOUP_NAME] = self.soupName;
    details[SOUP_TABLE_NAME] = self.soupTableName;
    details[OLD_SOUP_SPEC] = [self.oldSoupSpec asDictionary];
    if (self.soupSpec) {
        details[NEW_SOUP_SPEC] = [self.soupSpec asDictionary];
    }
    details[OLD_INDEX_SPECS] = [SFSoupIndex asArrayOfDictionaries:self.oldIndexSpecs withColumnName:YES];
    details[NEW_INDEX_SPECS] = [SFSoupIndex asArrayOfDictionaries:self.indexSpecs withColumnName:YES];
    details[RE_INDEX_DATA] = @(self.reIndexData);
    return details;
}

/**
 Update row in long operations status table for on-going alter soup operation
 Delete row if newStatus is AlterStatus.LAST
 @param newStatus New status
 @param db Database
 */
- (void) updateLongOperationDbRow:(SFAlterSoupStep)newStatus withDb:(FMDatabase*)db
{
    if (newStatus == kLastStep) {
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = %lld",
                               LONG_OPERATIONS_STATUS_TABLE, ID_COL, self.rowId];
        [self.store executeUpdateThrows:sql withDb:db];
    }
    else {
        NSNumber* now = [self.store currentTimeInMilliseconds];
        NSMutableDictionary* values = [NSMutableDictionary dictionary];
        values[STATUS_COL] = [NSNumber numberWithUnsignedInteger:newStatus];
        values[LAST_MODIFIED_COL] = now;
        [self.store updateTable:LONG_OPERATIONS_STATUS_TABLE values:values entryId:@(self.rowId) idCol:ID_COL withDb:db];
    }
}

-(void)executeUpdate:(FMDatabase*)db sql:(NSString*)sql context:(NSString*)context
{
    [self log:SFLogLevelDebug format:@"%@: %@", context, sql];
    [self.store executeUpdateThrows:sql withDb:db];
}

@end
