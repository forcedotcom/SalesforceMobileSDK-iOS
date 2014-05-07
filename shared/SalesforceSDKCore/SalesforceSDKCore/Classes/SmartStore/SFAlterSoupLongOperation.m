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
#import "SFSmartStore+Internal.h"
#import "SFSoupIndex.h"

@implementation SFAlterSoupLongOperation

@synthesize store = _store;
@synthesize db = _db;
@synthesize soupName = _soupName;
@synthesize soupTableName = _soupTableName;
@synthesize reIndexData = _reIndexData;
@synthesize rowId = _rowId;
@synthesize indexSpecs = _indexSpecs;
@synthesize oldIndexSpecs = _oldIndexSpecs;
@synthesize afterStep = _afterStep;


- (id) init:(SFSmartStore*)store withSoupName:(NSString*)soupName withNewIndexSpecs:(NSArray*)newIndexSpecs withReIndexData:(BOOL)reIndexData
{
    self = [super init];
    if (nil != self) {
        _store = store;
        _db = store.storeDb;
        _soupName = soupName;
        _soupTableName = [store tableNameForSoup:soupName];
        _indexSpecs = newIndexSpecs;
        _oldIndexSpecs = [store indicesForSoup:soupName];
        _reIndexData = reIndexData;
    }
    return self;
}

- (id) init:(SFSmartStore*) store withRowId:(long) rowId withDetails:(NSDictionary*)details withStatus:(int)status
{
    self = [super init];
    if (nil != self) {
        _store = store;
        _db = store.storeDb;
        _soupName = details[SOUP_NAME];
        _soupTableName = details[SOUP_TABLE_NAME];
        _indexSpecs = details[NEW_INDEX_SPECS];
        _oldIndexSpecs = details[OLD_INDEX_SPECS];
        _reIndexData = details[RE_INDEX_DATA];
        _afterStep = status;
    }
    return self;
}

- (void) run
{
    [self run:kLastStep];
}

- (void) run:(SFAlterSoupStep) toStep
{
    switch(self.afterStep) {
		case STARTING:
			[self renameOldSoupTable];
			if (toStep == RENAME_OLD_SOUP_TABLE) break;
		case RENAME_OLD_SOUP_TABLE:
            [self dropOldIndexes];
			if (toStep == DROP_OLD_INDEXES) break;
		case DROP_OLD_INDEXES:
			[self registerSoupUsingTableName];
			if (toStep == REGISTER_SOUP_USING_TABLE_NAME) break;
		case REGISTER_SOUP_USING_TABLE_NAME:
			[self copyTable];
			if (toStep == COPY_TABLE) break;
		case COPY_TABLE:
			// Re-index soup (if requested)
			if (self.reIndexData)
				[self reIndexSoup];
			if (toStep == RE_INDEX_SOUP) break;
		case RE_INDEX_SOUP:
			[self dropOldTable];
			if (toStep == DROP_OLD_TABLE) break;
		case DROP_OLD_TABLE:
			// Nothing left to do
			break;
    }
}

/**
 Step 1: rename old table
 */
- (void) renameOldSoupTable
{
    // Rename backing table for soup
    NSString* sql = [NSString stringWithFormat:@"ALTER TABLE %@ RENAME TO %@_old", self.soupTableName, self.soupTableName];
    [self.db executeUpdate:sql];
    
    // Update row in alter status table - auto commit
    [self updateLongOperationDbRow:RENAME_OLD_SOUP_TABLE];
}


/**
 Step 2: drop old indexes / remove entries in soup_index_map / cleaanup cache
 */
- (void) dropOldIndexes
{
    // Removing db indexes on table (otherwise registerSoup will fail to create indexes with the same name)
    for (int i=0; i<[self.oldIndexSpecs count]; i++) {
        NSString* sql = [NSString stringWithFormat:@"DROP INDEX %@_%d_idx", self.soupTableName, i];
        [self.db executeUpdate:sql];
    }
	
    [self.db beginTransaction];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=\"%@\"",
                                SOUP_INDEX_MAP_TABLE, SOUP_NAME_COL, self.soupName];
    [self.db executeUpdate:sql];
    
    // Update row in alter status table - auto commit
    [self updateLongOperationDbRow:DROP_OLD_INDEXES];

    // Remove soup from cache
    [self.store removeFromCache:self.soupName];
    
    [self.db commit];
}


/**
 Step 3: register soup with new indexes
 */
- (void) registerSoupUsingTableName
{
    [self.store registerSoup:self.soupName withIndexSpecs:self.indexSpecs withSoupTableName:self.soupTableName];
    
    // Update row in alter status table -auto commit
    [self updateLongOperationDbRow:REGISTER_SOUP_USING_TABLE_NAME];
}


/**
 Step 4: copy data from old soup table to new soup table
 */
- (void) copyTable
{
    [self.db beginTransaction];
    // We need column names in the index specs
    _indexSpecs = [self.store indicesForSoup:self.soupName];
		
    // Move data (core columns + indexed paths that we are still indexing)
    NSString* copySql = [self computeCopyTableStatement];
    [self.db executeUpdate:copySql];
        
    // Update row in alter status table
    [self updateLongOperationDbRow:COPY_TABLE];

    // Commit
    [self.db commit];
}


/**
 Step 5: re-index soup for new indexes (optional step)
 */
- (void) reIndexSoup
{
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
    
    // Start transaction
    [self.db beginTransaction];
    
    // Re-index soup
    [self.store reIndexSoup:self.soupName withIndexPaths:indexPaths handleTx:FALSE];
    
    // Update row in alter status table
    [self updateLongOperationDbRow:RE_INDEX_SOUP];
    
     // Commit
    [self.db commit];
}


/**
 Step 6: drop old soup table
 */
- (void) dropOldTable
{
    // Drop old table
    NSString* sql = [NSString stringWithFormat:@"DROP TABLE %@_old", _soupTableName];
    [self.db executeUpdate:sql];
    
    // Update status row - auto commit
    [self updateLongOperationDbRow:DROP_OLD_TABLE];
}


/**
 Create row in long operations status table for a new alter soup operation
 @return row id
 */
- (long) createLongOperationDbRow
{
    return 0L;
    // TODO
}

- (NSDictionary*) getDetails
{
    return nil;
    // TODO
}

/**
 Update row in long operations status table for on-going alter soup operation
 Delete row if newStatus is AlterStatus.LAST
 @param newStatus
 */
- (void) updateLongOperationDbRow:(SFAlterSoupStep)newStatus
{
    // TODO
}

/**
 Helper method
 @return insert statement to copy data from soup old backing table to soup new backing table
 */
- (NSString*) computeCopyTableStatement
{
    NSDictionary* mapOldSpecs = [SFSoupIndex mapForSoupIndexes:self.oldIndexSpecs];
    NSDictionary* mapNewSpecs = [SFSoupIndex mapForSoupIndexes:self.indexSpecs];
    
    // Figuring out paths we are keeping
    NSSet* oldPaths = [NSSet setWithArray:[mapOldSpecs allKeys]];
    NSMutableSet* keptPaths = [NSMutableSet setWithArray:[mapNewSpecs allKeys]];
    [keptPaths intersectSet:oldPaths];
    
    // Compute list of columns to copy from / list of columns to copy into
    NSMutableArray* oldColumns = [NSMutableArray arrayWithObjects:ID_COL, SOUP_COL, CREATED_COL, LAST_MODIFIED_COL, nil];
    NSMutableArray* newColumns = [NSMutableArray arrayWithObjects:ID_COL, SOUP_COL, CREATED_COL, LAST_MODIFIED_COL, nil];
    
    // Adding indexed path columns that we are keeping
    for (NSString* keptPath in keptPaths) {
        SFSoupIndex* oldIndexSpec = mapOldSpecs[keptPath];
        SFSoupIndex* newIndexSpec = mapNewSpecs[keptPath];
        if ([oldIndexSpec.indexType isEqualToString:newIndexSpec.indexType]) {
            [oldColumns addObject:oldIndexSpec.columnName];
            [newColumns addObject:newIndexSpec.columnName];
        }
    }
    
    // Compute and return statement
    return [NSString stringWithFormat:@"INSERT INTO %@ (%@) SELECT %@ FROM %@_old",
            self.soupTableName,
            [newColumns componentsJoinedByString:@","],
            [oldColumns componentsJoinedByString:@","],
            self.soupTableName
            ];
}

@end
