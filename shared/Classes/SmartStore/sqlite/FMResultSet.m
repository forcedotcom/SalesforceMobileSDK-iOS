/*
 Copyright (c) 2008 Flying Meat Inc.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "FMResultSet.h"
#import "FMDatabase.h"
#import "FMDbException.h"
#include <unistd.h>

@interface FMResultSet ()
- (void)setColumnNameToIndexMap:(NSMutableDictionary *)value;
@end

@implementation FMResultSet

-(id)initWithStatement:(sqlite3_stmt *)stmt query:(NSString *)aQuery binds:(NSArray *)b parentDatabase:(FMDatabase *)db {
	self = [super init];
    [self setColumnNameToIndexMap:[NSMutableDictionary dictionary]];
	defaultColumnValues = NO;
    pStmt = stmt;
	parentDB = [db retain];
	query = [aQuery retain];
	binds = [b retain];
	return self;
}

+(id)resultSetWithStatement:(sqlite3_stmt *)stmt query:(NSString *)query binds:(NSArray *)binds parentDb:(FMDatabase*)aDB; {
    FMResultSet *rs = [[FMResultSet alloc] initWithStatement:stmt query:query binds:binds parentDatabase:aDB];
    return [rs autorelease];
}

-(void)dealloc {
    [self close];
    [query release];
    [columnNameToIndexMap release];
    [parentDB release];
	[binds release];
	[super dealloc];
}

-(void)close {
#ifdef SINGLE_RESULTSET_MODE    
    [parentDB setInUse:NO]; 
#endif    
    if (!pStmt) 
        return;
    
	@synchronized (parentDB) {
		/* Finalize the virtual machine. This releases all memory and other
		 ** resources allocated by the sqlite3_prepare() call above.
		 */
		int rc = sqlite3_finalize(pStmt);
		if (rc != SQLITE_OK) {
//			[self log:Error format:@"error %d finalizing for query: %@", rc, [self query]];
		}
    }
    pStmt = nil;
}

- (void) setupColumnNames {
    @synchronized(parentDB) {
		columnCount = sqlite3_column_count(pStmt);
		int columnIdx = 0;
		for (columnIdx = 0; columnIdx < columnCount; columnIdx++) {
			[columnNameToIndexMap setObject:[NSNumber numberWithInt:columnIdx]
									 forKey:[[NSString stringWithUTF8String:sqlite3_column_name(pStmt, columnIdx)] lowercaseString]];
		}
	}
}

- (NSArray *)originalColumnNames {
	NSMutableArray *colNames = [NSMutableArray array];
    @synchronized(parentDB) {
		columnCount = sqlite3_column_count(pStmt);
		int columnIdx = 0;
		for (columnIdx = 0; columnIdx < columnCount; columnIdx++) {
			[colNames addObject:[NSString stringWithUTF8String:sqlite3_column_name(pStmt, columnIdx)]];
		}
	}
	return colNames;
}

- (void) kvcMagic:(id)object {
    @synchronized(parentDB) {
		columnCount = sqlite3_column_count(pStmt);
		for (int columnIdx = 0; columnIdx < columnCount; columnIdx++) {
			const char *c = (const char *)sqlite3_column_text(pStmt, columnIdx);
			// check for a null row
			if (c) {
				NSString *s = [NSString stringWithUTF8String:c];
				[object setValue:s forKey:[NSString stringWithUTF8String:sqlite3_column_name(pStmt, columnIdx)]];
			}
		}
	}
}

- (BOOL) nextImpl {
    int rc, prc;
    BOOL retry;
    int numberOfRetries = 0;
    do {
        retry = NO;
        
        rc = sqlite3_step(pStmt);
        prc = (rc & 0xFF);
        if (SQLITE_BUSY == prc) {
            // this will happen if the db is locked, like if we are doing an update or insert.
            // in that case, retry the step... and maybe wait just 10 milliseconds.
            retry = YES;
            usleep(100);
            
            if ([parentDB busyRetryTimeout] && (numberOfRetries++ > [parentDB busyRetryTimeout])) {
                [NSException raise:@"FMDatabaseException" format:@"Database too busy."];
            }
            
        }
        else if (SQLITE_DONE == prc || SQLITE_ROW == prc) {
            // all is well, let's return.
        }
        else  if(SQLITE_CORRUPT == prc) {
			//database is corrupt. erase everything
//			[self log:Error format:@"db is corrupt when querying: '%@'. erasing & quitting!", query];
			//TODO [DbFile resetDataStores];
			exit(1);
		}
		else {
			FMDbException *ex = [FMDbException exceptionForResultCode:rc database:parentDB stmt:pStmt sql:query binds:binds];
//			[self log:Error msg:[ex description]];
			[ex raise];
        }
        
    } while (retry);
    
    if (!columnNamesSetup) {
        [self setupColumnNames];
    }
    
    if (prc != SQLITE_ROW) {
        [self close];
    }
    
    return (prc == SQLITE_ROW);
}

-(BOOL)next {
	BOOL more;
	@synchronized (parentDB) {
		more = [self nextImpl];
	}
	return more;
}

- (int) columnIndexForName:(NSString*)columnName {
    columnName = [columnName lowercaseString];
    NSNumber *n = [columnNameToIndexMap objectForKey:columnName];
    if (n) 
        return [n intValue];
    
//    [self log:Warning format:@"I could not find the column named '%@'.", columnName];
    return -1;
}

- (void) raiseExceptionForMissingColumn:(NSString *) columnName {
	[NSException raise:@"FMDatabaseException" format:@"column '%@' does not exist in ResultSet", columnName];
}

- (void) raiseExceptionForMissingColumnIdx:(int) columnIdx {
	[NSException raise:@"FMDatabaseException" format:@"column '%d' does not exist in ResultSet", columnIdx];
}

- (int) intForColumn:(NSString*)columnName; {
    int columnIdx = [self columnIndexForName:columnName];
    if (columnIdx == -1) {
		if (defaultColumnValues) {
			return 0;
		} else {
			[self raiseExceptionForMissingColumn:columnName];
		}
    }   
	@synchronized(parentDB) {
		return sqlite3_column_int(pStmt, columnIdx);
	}
	return 0; // compiler suckage
}

- (int)intForColumnIndex:(int)columnIdx; {
	if(columnIdx > columnCount) 
		[self raiseExceptionForMissingColumnIdx:columnIdx];
	
	@synchronized(parentDB) {
		return sqlite3_column_int(pStmt, columnIdx);
	}
	return 0; // compiler suckage
}

- (long) longForColumn:(NSString*)columnName; {
    int columnIdx = [self columnIndexForName:columnName];
    if (columnIdx == -1) {
        if (defaultColumnValues) {
			return 0;
		} else {
			[self raiseExceptionForMissingColumn:columnName];
		}
    }
	@synchronized(parentDB) {
		return sqlite3_column_int64(pStmt, columnIdx);
	}
	return 0L; // compiler suckage
}

- (long) longForColumnIndex:(int)columnIdx; {
	if(columnIdx > columnCount) 
		[self raiseExceptionForMissingColumnIdx:columnIdx];
	
	@synchronized(parentDB) {
		return sqlite3_column_int64(pStmt, columnIdx);
	}
	return 0L; // compiler sockage
}

- (BOOL) boolForColumn:(NSString*)columnName; {
    return ([self intForColumn:columnName] != 0);
}

- (BOOL) boolForColumnIndex:(int)columnIdx; {
    return ([self intForColumnIndex:columnIdx] != 0);
}

- (double) doubleForColumn:(NSString*)columnName; {
    int columnIdx = [self columnIndexForName:columnName];
    if (columnIdx == -1) {
        if (defaultColumnValues) {
			return 0;
		} else {
			[self raiseExceptionForMissingColumn:columnName];
		}
    }
    @synchronized (parentDB) {
		return sqlite3_column_double(pStmt, columnIdx);
	}
	return 0.0; // compiler suckage
}

- (double) doubleForColumnIndex:(int)columnIdx; {
	if(columnIdx > columnCount) 
		[self raiseExceptionForMissingColumnIdx:columnIdx];

	@synchronized (parentDB) {
		return sqlite3_column_double(pStmt, columnIdx);
	}
	return 0.0; // compiler suckage
}

-(NSNumber *) nsnumberForColumn:(NSString *)columnName {
	int columnIdx = [self columnIndexForName:columnName];
    if (columnIdx == -1) {
        if (defaultColumnValues) {
			return nil;
		} else {
			[self raiseExceptionForMissingColumn:columnName];
		}
    }
    @synchronized (parentDB) {
		int dataType = sqlite3_column_type(pStmt, columnIdx);
		switch(dataType) {
				case SQLITE_INTEGER : return [NSNumber numberWithInt:sqlite3_column_int(pStmt, columnIdx)];
				case SQLITE_FLOAT : return [NSNumber numberWithDouble:sqlite3_column_double(pStmt, columnIdx)];
				case SQLITE_NULL : return nil;
		}
	}
	return nil; // compiler suckage
}
#pragma mark string functions

- (NSString*)stringForColumnIndex:(int)columnIdx; {
    if(columnIdx > columnCount) 
		[self raiseExceptionForMissingColumnIdx:columnIdx];
	
	const char *c;
	@synchronized(parentDB) {
		c = (const char *)sqlite3_column_text(pStmt, columnIdx);
	}
    if (!c) 
        return nil;
    
    return [NSString stringWithUTF8String:c];
}

- (NSString*) stringForColumn:(NSString*)columnName; {
    int columnIdx = [self columnIndexForName:columnName];
    if (columnIdx == -1) {
        if (defaultColumnValues) {
			return nil;
		} else {
			[self raiseExceptionForMissingColumn:columnName];
		}
    }
    
    return [self stringForColumnIndex:columnIdx];
}

- (NSDate*)dateForColumn:(NSString*)columnName; {
	int columnIdx = [self columnIndexForName:columnName];
    if (columnIdx == -1) {
        if (defaultColumnValues) {
			return nil;
		} else {
			[self raiseExceptionForMissingColumn:columnName];
		}
    }
    return [self dateForColumnIndex:columnIdx];
}

- (NSDate*) dateForColumnIndex:(int)columnIdx; {
	if(columnIdx > columnCount) {
		[self raiseExceptionForMissingColumnIdx:columnIdx];
	}
	@synchronized(parentDB) {
		int dataType = sqlite3_column_type(pStmt, columnIdx);
		if(dataType == SQLITE_NULL) return nil;
		return [NSDate dateWithTimeIntervalSince1970:sqlite3_column_double(pStmt, columnIdx)];
	}
	return nil;
}

-(NSData *)dataForColumn:(NSString*)columnName; {
    int columnIdx = [self columnIndexForName:columnName];
    if (columnIdx == -1) {
		if (defaultColumnValues) {
			return nil;
		} else {
			[self raiseExceptionForMissingColumn:columnName];
		}
    }
    return [self dataForColumnIndex:columnIdx];
}

-(NSData *)dataForColumnIndex:(int)columnIdx; {
    if(columnIdx > columnCount) 
		[self raiseExceptionForMissingColumnIdx:columnIdx];
	
	@synchronized (parentDB) {
		int dataSize = sqlite3_column_bytes(pStmt, columnIdx); 
		NSMutableData *data = [NSMutableData dataWithLength:dataSize];
		memcpy([data mutableBytes], sqlite3_column_blob(pStmt, columnIdx), dataSize);
		return data;
	}
	return nil; // compiler suckage
}

-(NSString *)query {
    return query;
}

-(void)setColumnNameToIndexMap:(NSMutableDictionary *)value {
    [value retain];
    [columnNameToIndexMap release];
    columnNameToIndexMap = value;
}


@end
