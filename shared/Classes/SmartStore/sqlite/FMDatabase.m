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

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMDbException.h"
#import "SqliteAdditions.h"
#include <unistd.h>

#define SINGLE_RESULTSET_MODE 0
static NSString *encryptionAlgorithm = @"aes128"; // valid options are : aes256, aes128, rc4 (or nil)

@interface FMDatabase() 
- (id) executeQueryImpl:(NSString*)objs argList:(va_list)argList binds:(NSArray *)bindValues;
@end

@implementation FMDatabase

@synthesize delegate, deleteOnClose;

+ (id)databaseWithPath:(NSString*)aPath {
    return [[[FMDatabase alloc] initWithPath:aPath] autorelease];
}

- (id)initWithPath:(NSString*)aPath {
    self = [super init];	
    if (self) {
        databasePath        = [aPath copy];
        db                  = 0x00;
        logsErrors          = 0x00;
        crashOnErrors       = 0x00;
		deleteOnClose		= NO;
        busyRetryTimeout    = 0x00;
		delegate			= nil;
    }	
	return self;
}

- (void)dealloc {
	[self close];
	[databasePath release];
	[super dealloc];
}

+ (NSString*) sqliteLibVersion {
    return [NSString stringWithFormat:@"%s", sqlite3_libversion()];
}

-(NSString *)databaseFile {
	return [[databasePath retain] autorelease];
}

- (sqlite3*) sqliteHandle {
    return db;
}

-(BOOL) enableEncryption {
    return NO;
//	if (encryptionAlgorithm == nil) {
////		[self log:Debug format:@"No Encryption"];
//		return YES;
//	} else {
//		[self log:Finer format:@"Enabling encryption %@ for db file %@", encryptionAlgorithm, [databasePath lastPathComponent]];
//		NSData *key = [Crypto databaseKey];
//		[self log:Finer format:@"crypto key length = %d + preamble", [key length]];
//		return [self setKey:key algorithm:encryptionAlgorithm];
//	}
}

/*!
 Test if this database is readable with the current key
 @return YES if this database is readable, NO otherwise.
 */
-(BOOL) testDatabaseEncryption {
	@try {
		return ([self goodConnection] && [self lastErrorCode] != SQLITE_NOTADB);
	} @catch (NSException *e) {
//		[self log:Error format:@"cannot determine if database %@ is encrypted - assuming no (%@)", [self databaseFile], [e reason]];
	}
	return NO;
}

//-(void) recryptIfNecessary {
//	if (![self testDatabaseEncryption]) {
////		[self log:Info format:@"recrypting database %@ with %@", [self databaseFile], encryptionAlgorithm];
//		int err = sqlite3_close(db);
//		if (err != SQLITE_OK) {
//			[self log:Error format:@"cannot close database for recrypt. err=%d", err];
//		}
//		err = sqlite3_open([databasePath fileSystemRepresentation], &db);
////		if (err != SQLITE_OK) {
////			[self log:Error format:@"cannot reopen database for recrypt. err=%d", err];
////		}
////		[self setKey:nil algorithm:nil];
//		if (![self testDatabaseEncryption]) {
//			[NSException raise:@"FMDatabaseException" format:@"Cannot read file with empty key", [self databaseFile]];
//		}
//        //TODO
////		[self rekey:[Crypto databaseKey] algorithm:encryptionAlgorithm];
//	}
//}
			

- (BOOL) openWithEncryption:(BOOL)useEncryption {
	int err = sqlite3_open( [databasePath fileSystemRepresentation], &db );
	if(err != SQLITE_OK) {
//		[self log:Error format:@"error opening!: %d", err];
		return NO;
	}
	
#ifdef TARGET_STATIC_DEMO
//	[self log:Warning msg:@"skipping encryption in demo mode"];
#else
//	if (useEncryption) {
//		if (![self enableEncryption]) {
////			[self log:Error format:@"cannot setup encryption for file %@", databasePath];
//			return NO;
//		}
//		
//		[self recryptIfNecessary];
//	}
#endif
	
	err = sqlite3_create_function(db, "concat", -1, SQLITE_UTF8, NULL, concat, NULL, NULL);
	if(err != SQLITE_OK) {
//		[self log:Error format:@"error adding sqlite concat function!: %d", err];
		return NO;
	}	
	
	if ([delegate respondsToSelector:@selector(opened:)])
		[delegate opened:self];
	
	sqlite3_extended_result_codes(db, 1);
	
	// Preset the cache size to avoid freakishly huge memory consumption
	// Set as number of pages, where pages are roughly 1kB in size.
	if (SQLITE_OK != (err = sqlite3_exec(db, "PRAGMA CACHE_SIZE=100;", NULL, NULL, NULL) )) {
//		[self log:Info format:@"error setting cache size: %d", err];
	}
	
	
	return YES;
}

-(BOOL) open {
	return [self openWithEncryption:YES];
}

- (void) close {
	if (!db) 
        return;
    
    int  rc;
    BOOL retry;
    int numberOfRetries = 0;
    do {
        retry   = NO;
        rc      = sqlite3_close(db);
        if (SQLITE_BUSY == (rc & 0xFF)) {
            retry = YES;
            usleep(100);
            if (busyRetryTimeout && (numberOfRetries++ > busyRetryTimeout)) {
                [NSException raise:@"FMDatabaseException" format:@"Database too busy."];
            }
        }
        else if (SQLITE_OK != rc) {
//            [self log:Error format:@"error closing!: %d", rc];
        }
    }
    while (retry);
    
	if ([delegate respondsToSelector:@selector(closed:)])
		[delegate closed:self];
	
	if (deleteOnClose)
		[[NSFileManager defaultManager] removeItemAtPath:databasePath error:nil];
	
	db = nil;
}

//- (BOOL) rekey:(NSData*)key algorithm:(NSString *)algorithm {
//	int rc;
//	if (key != nil) {
//		NSMutableData *concatKey = [[NSMutableData alloc] init];
//		if (algorithm != nil) {
//			[concatKey appendData:[algorithm dataUsingEncoding:NSASCIIStringEncoding]];
//			[concatKey appendBytes:":" length:1];
//		}
//		[concatKey appendData:key];
////		[self log:Debug format:@"sqlite3_rekey() %@", concatKey];
//		rc = sqlite3_rekey(db, [concatKey bytes], [concatKey length]);
//		[concatKey release];
//	} else {
//		rc = sqlite3_rekey(db, 0, 0);
//	}
////    if (rc != SQLITE_OK) {
////        [self log:Error format:@"error on rekey: %d", rc];
////        [self log:Error msg:[self lastErrorMessage]];
////    }
//    
//    return (rc == SQLITE_OK);
//}
//
//- (BOOL) setKey:(NSData *)key algorithm:(NSString *)algorithm {
//	int rc;
//	if (key != nil && algorithm != nil) {
//		NSMutableData *concatKey = [[NSMutableData alloc] init];
//		if (algorithm != nil) {
//			[concatKey appendData:[algorithm dataUsingEncoding:NSASCIIStringEncoding]];
//			[concatKey appendBytes:":" length:1];
//		}
//		[concatKey appendData:key];
////		[self log:Finer format:@"sqlite3_key() %@", concatKey];
//		rc = sqlite3_key(db, [concatKey bytes], [concatKey length]);
//
//		[concatKey release];
//	} else {
//		rc = sqlite3_key(db, 0, 0);
//	}
//    
//    return (rc == SQLITE_OK);
//}

- (BOOL) goodConnection {
    
    if (!db) {
        return NO;
    }
    
    FMResultSet *rs = [self executeQuery:@"select name from sqlite_master where type='table'"];
    
    if (rs) {
        [rs close];
        return YES;
    }
    
    return NO;
}

- (void) compainAboutInUse {
//    [self log:Info format:@"The FMDatabase %@ is currently in use.", self];
    
    if (crashOnErrors) {
        [NSException raise:@"FMDatabase in use" format:@"The FMDatabase %@ is currently in use.", self];
    }
    
}

- (NSString*) lastErrorMessage {
    return [NSString stringWithUTF8String:sqlite3_errmsg(db)];
}

- (BOOL) hadError {
    return ([self lastErrorCode] != SQLITE_OK);
}

- (int) lastErrorCode {
    return sqlite3_errcode(db);
}

- (sqlite_int64) lastInsertRowId {
    
    if (inUse) {
        [self compainAboutInUse];
        return NO;
    }
    [self setInUse:YES];
    
    sqlite_int64 ret = sqlite3_last_insert_rowid(db);
    
    [self setInUse:NO];
    
    return ret;
}

- (void) bindObject:(id)obj toColumn:(int)idx inStatement:(sqlite3_stmt*)pStmt; {
    
    // FIXME - someday check the return codes on these binds.
	if (obj == [NSNull null] || obj == nil) {
		sqlite3_bind_null(pStmt, idx);
    } else if ([obj isKindOfClass:[NSData class]]) {
        sqlite3_bind_blob(pStmt, idx, [obj bytes], [obj length], SQLITE_STATIC);
    }
    else if ([obj isKindOfClass:[NSDate class]]) {
        sqlite3_bind_double(pStmt, idx, [obj timeIntervalSince1970]);
    }
    else if ([obj isKindOfClass:[NSNumber class]]) {
        
        if (strcmp([obj objCType], @encode(BOOL)) == 0) {
            sqlite3_bind_int(pStmt, idx, ([obj boolValue] ? 1 : 0));
        }
        else if (strcmp([obj objCType], @encode(int)) == 0) {
            sqlite3_bind_int64(pStmt, idx, [obj longValue]);
        }
        else if (strcmp([obj objCType], @encode(float)) == 0) {
            sqlite3_bind_double(pStmt, idx, [obj floatValue]);
        }
        else if (strcmp([obj objCType], @encode(double)) == 0) {
            sqlite3_bind_double(pStmt, idx, [obj doubleValue]);
        }
        else {
            sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
        }
    }
    else {
        sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
    }
}

-(id)executeQuery:(NSString*)objs argList:(va_list)argList binds:(NSArray *)bindValues {	
	id result = nil;
	@synchronized(self) {
		result = [self executeQueryImpl:objs argList:argList binds:bindValues];
	}
	return result;
}

-(id)executeQueryImpl:(NSString*)objs argList:(va_list)argList binds:(NSArray *)bindValues {
#if SINGLE_RESULTSET_MODE
    if (inUse) {
        [self compainAboutInUse];
        return nil;
    }
    [self setInUse:YES];
#endif
    
    FMResultSet *rs = nil;
    NSString *sql = objs;
    int rc;
    sqlite3_stmt *pStmt;
    
//    if (traceExecution && sql) 
//        [self log:Fine format:@"%@ executeQuery: %@", self, sql];
    
    int numberOfRetries = 0;
    BOOL retry;
    do {
        retry   = NO;
        rc      = sqlite3_prepare_v2(db, [sql UTF8String], -1, &pStmt, 0);
        
        if (SQLITE_BUSY == (rc & 0xFF)) {
            retry = YES;
            usleep(100);
            
            if (busyRetryTimeout && (numberOfRetries++ > busyRetryTimeout)) {
                [NSException raise:@"FMDatabaseException" format:@"Database too busy."];
            }
        }
        else if (SQLITE_OK != rc) {
			sqlite3_finalize(pStmt);
			if(SQLITE_CORRUPT == rc) {
				//database is corrupt. erase everything
//				[self log:Error format:@"db is corrupt when updating: '%@'. erasing & quitting!", sql];
				//TODO [DbFile resetDataStores];
				exit(1);
			}
            
            if (logsErrors) {
//                [self log:Error format:@"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]];
//                [self log:Error format:@"DB Query: %@", sql];
                if (crashOnErrors) //&& [[self lastErrorMessage] rangeOfString:FN_ISALLDAYEVENT].location == NSNotFound) 
                {
                    [NSException raise:@"FMDatabaseException" format:@"(%d) \"%@\"", [self lastErrorCode], [self lastErrorMessage]];
#ifdef __BIG_ENDIAN__
                    asm{ trap };
#endif
                }
            }
#if SINGLE_RESULTSET_MODE
            [self setInUse:NO];
#endif
            return nil;
        }
    }
    while (retry);
    
    id obj;
    int idx = 0;
    int queryCount = sqlite3_bind_parameter_count(pStmt); // pointed out by Dominic Yu (thanks!)
    if (bindValues == nil) {
		NSMutableArray *bv = [NSMutableArray array];
		while (idx < queryCount) {
			obj = va_arg(argList, id);
			if (!obj) break;
			[self bindObject:obj toColumn:++idx inStatement:pStmt];
			[bv addObject:obj];
		}
		va_end(argList);
		bindValues = bv;
    } else {
		for (obj in bindValues)
			[self bindObject:obj toColumn:++idx inStatement:pStmt];
	}
    
    if (idx != queryCount) {
//        [self log:Error format:@"The bind count is not correct for the # of variables, expected %d, got %d (executeQuery:%@)", queryCount, idx, sql];
		NSAssert((idx == queryCount), @"incorrect number of bind values passed to executeQueryImpl");

        sqlite3_finalize(pStmt);
#if SINGLE_RESULTSET_MODE		
        [self setInUse:NO];
#endif
        return nil;
    }
    
    // the statement gets close in rs's dealloc or [rs close];
    rs = [FMResultSet resultSetWithStatement:pStmt query:sql binds:bindValues parentDb:self];
    return rs;
}

- (id) executeQuery:(NSString*)objs, ... {
	va_list argList;
	va_start(argList, objs);
	return [self executeQuery:objs argList:argList binds:nil];
}

- (id) executeQuery:(NSString *)sql withParams:(NSArray *)bindValues {
	return [self executeQuery:sql argList:nil binds:bindValues];
}


- (BOOL) executeUpdate:(NSString*)objs argList:(va_list)argList binds:(NSArray *)bindValues {
#if SINGLE_RESULTSET_MODE    
    if (inUse) {
        [self compainAboutInUse];
        return NO;
    }
    [self setInUse:YES];
#endif

    NSString *sql       = objs;
    int rc              = 0x00;
    sqlite3_stmt *pStmt = 0x00;
    
//    if (traceExecution && sql) {
//		[self log:Fine format:@"%@ executeUpdate: %@", self, sql];	
//    }
    
    int numberOfRetries = 0;
    BOOL retry;
    do {
        retry   = NO;
        rc      = sqlite3_prepare_v2(db, [sql UTF8String], -1, &pStmt, 0);
        if (SQLITE_BUSY == (rc & 0xFF)) {
            retry = YES;
            usleep(100);
            if (busyRetryTimeout && (numberOfRetries++ > busyRetryTimeout)) {
                [NSException raise:@"FMDatabaseException" format:@"Database too busy."];
            }
        }
        else if (SQLITE_OK != rc) {
			int ret = rc;
            rc = sqlite3_finalize(pStmt);
			if(SQLITE_CORRUPT == ret) {
				//database is corrupt. erase everything
//				[self log:Error format:@"db is corrupt when updating: '%@'. erasing & quitting!", sql];
				//TODO [DbFile resetDataStores];
				exit(1);
			}            
            if (logsErrors) {
//                [self log:Error format:@"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]];
//                [self log:Error format:@"DB Query: %@", sql];
				if (crashOnErrors) { // && [[self lastErrorMessage] rangeOfString:FN_ISALLDAYEVENT].location == NSNotFound) {
                    [NSException raise:@"FMDatabaseException" format:@"(%d) \"%@\"", [self lastErrorCode], [self lastErrorMessage]];
                    #ifdef __BIG_ENDIAN__
                    asm{ trap };
                    #endif
                }
            }
#if SINGLE_RESULTSET_MODE            
            [self setInUse:NO];
#endif
            return rc;
        }
    }
    while (retry);
    
    id obj;
    int idx = 0;
    int queryCount = sqlite3_bind_parameter_count(pStmt);
	if (bindValues == nil) {
		NSMutableArray *vaBinds = [NSMutableArray array];
		while (idx < queryCount) {
			obj = va_arg(argList, id);
			if (!obj) break;
			[self bindObject:obj toColumn:++idx inStatement:pStmt];
			[vaBinds addObject:obj];
		}
		va_end(argList);
		bindValues = vaBinds;
    } else {
		for (obj in bindValues)
			[self bindObject:obj toColumn:++idx inStatement:pStmt];
	}
    
    if (idx != queryCount) {
//        [self log:Error format:@"The bind count is not correct for the # of variables (%@) (executeUpdate)", sql];
		NSAssert((idx == queryCount), @"incorrect number of bind values passed to executeUpdate");

        sqlite3_finalize(pStmt);
#if SINGLE_RESULTSET_MODE		
        [self setInUse:NO];
#endif
        return NO;
    }
    
    /* Call sqlite3_step() to run the virtual machine. Since the SQL being
    ** executed is not a SELECT statement, we assume no data will be returned.
    */
    numberOfRetries = 0;
	int prc;
    do {
        rc      = sqlite3_step(pStmt);
        retry   = NO;
		prc = (rc & 0xFF);
        if (SQLITE_BUSY == prc) {
            // this will happen if the db is locked, like if we are doing an update or insert.
            // in that case, retry the step... and maybe wait just 10 milliseconds.
            retry = YES;
//			[self log:Warning format:@"db is busy...sleeping"];
            usleep(100);
            if (busyRetryTimeout && (numberOfRetries++ > busyRetryTimeout)) {
                [NSException raise:@"FMDatabaseException" format:@"Database too busy."];
            }
        }
        else if (SQLITE_DONE == prc || SQLITE_ROW == prc) {
            // all is well, let's return.
        }
        else if(SQLITE_CORRUPT == prc) {
			//database is corrupt. erase everything
//			[self log:Error format:@"db is corrupt when updating: '%@'. erasing & quitting!", sql];
			//TODO
            //[DbFile resetDataStores];
			exit(1);
		}
        else {
			FMDbException *ex = [FMDbException exceptionForResultCode:rc database:self stmt:pStmt sql:sql binds:bindValues];
//			[self log:Error msg:[ex description]];
			sqlite3_finalize(pStmt);

			[ex raise];
        }
        
    } while (retry);
    
    assert( rc!=SQLITE_ROW );
    
    /* Finalize the virtual machine. This releases all memory and other
    ** resources allocated by the sqlite3_prepare() call above.
    */
    rc = sqlite3_finalize(pStmt);
#if SINGLE_RESULTSET_MODE
    [self setInUse:NO];
#endif

    return (rc == SQLITE_OK);
}

- (BOOL) executeUpdate:(NSString*)objs, ...  {
	va_list argList;
	va_start(argList, objs);
	@synchronized(self) {
		return [self executeUpdate:objs argList:argList binds:nil];
	}
	return NO; // compiler suckage
}

- (BOOL) executeUpdate:(NSString*)sql withParams:(NSArray*)bindValues {
	@synchronized(self) {
		return [self executeUpdate:sql argList:nil binds:bindValues];
	}
	return NO; // compiler suckage
}

-(int)lastRowsChangeCount {
	return sqlite3_changes(db);
}

- (BOOL) rollback {
    BOOL b = [self executeUpdate:@"ROLLBACK TRANSACTION;"];
    if (b) {
        inTransaction = NO;
    }
    return b;
}

- (BOOL) commit {
    BOOL b =  [self executeUpdate:@"COMMIT TRANSACTION;"];
    if (b) {
        inTransaction = NO;
    }
	return b;
}

- (BOOL) endTransaction:(BOOL)performCommit {
	if (performCommit) 
		return [self commit];
	return [self rollback];
}

- (BOOL) safelyEndTransaction {
	if ([self inTransaction]) {
//		[self log:Fine msg:@"database is in transaction. canceling existing transaction.."];
//		if (![self rollback]) {
//			[self log:Warning format:@"database transaction could not be rolled back. error=%d", [self lastErrorCode]];
//		}
		return YES;
	}
	return NO;
}

- (BOOL) beginDeferredTransaction {
    BOOL b =  [self executeUpdate:@"BEGIN DEFERRED TRANSACTION;"];
    if (b) {
        inTransaction = YES;
    }
    return b;
}

- (BOOL) beginTransaction {	
    BOOL b =  [self executeUpdate:@"BEGIN EXCLUSIVE TRANSACTION;"];
    if (b) {
        inTransaction = YES;
    }
    return b;
}

- (BOOL)logsErrors {
    return logsErrors;
}
- (void)setLogsErrors:(BOOL)flag {
    logsErrors = flag;
}

- (BOOL)crashOnErrors {
    return crashOnErrors;
}
- (void)setCrashOnErrors:(BOOL)flag {
    crashOnErrors = flag;
}

- (BOOL)inUse {
    return inUse || inTransaction;
}
- (void)setInUse:(BOOL)flag {
    
    inUse = flag;
}

- (BOOL)inTransaction {
    return inTransaction;
}
- (void)setInTransaction:(BOOL)flag {
    inTransaction = flag;
}

- (BOOL)traceExecution {
    return traceExecution;
}
- (void)setTraceExecution:(BOOL)flag {
    traceExecution = flag;
}

- (BOOL)checkedOut {
    return checkedOut;
}
- (void)setCheckedOut:(BOOL)flag {
    checkedOut = flag;
}


- (int)busyRetryTimeout {
    return busyRetryTimeout;
}
- (void)setBusyRetryTimeout:(int)newBusyRetryTimeout {
    busyRetryTimeout = newBusyRetryTimeout;
}

-(NSString *)description {
	return [NSString stringWithFormat:@"%@ : %@", [super description], [databasePath lastPathComponent]];
}

@end
