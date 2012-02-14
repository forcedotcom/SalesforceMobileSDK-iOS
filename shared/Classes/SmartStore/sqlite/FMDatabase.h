#import <Foundation/Foundation.h>
#import "sqlite3.h"
#import "FMResultSet.h"

@protocol FMDatabaseDelegate
@optional
-(void)opened:(FMDatabase *)db;
-(void)closed:(FMDatabase *)db;
@end

@interface FMDatabase : NSObject 
{
	sqlite3*    db;
	NSString*   databasePath;
    BOOL        logsErrors;
    BOOL        crashOnErrors;
    BOOL        inUse;
    BOOL        inTransaction;
    BOOL        traceExecution;
    BOOL        checkedOut;
	BOOL		deleteOnClose;
    int         busyRetryTimeout;
	NSObject<FMDatabaseDelegate>	*delegate;
}

+ (id)databaseWithPath:(NSString*)inPath;
- (id)initWithPath:(NSString*)inPath;

- (BOOL) open;
- (void) close;

//- (BOOL) setKey:(NSData *)key algorithm:(NSString *)algorithm;
//- (BOOL) rekey:(NSData *)key algorithm:(NSString *)algorithm;

- (BOOL) goodConnection;

- (NSString*) lastErrorMessage;
- (int) lastErrorCode;
- (BOOL) hadError;
- (sqlite_int64) lastInsertRowId;
@property (readonly) int lastRowsChangeCount;

- (sqlite3*) sqliteHandle;

- (BOOL) executeUpdate:(NSString *)objs, ...;
- (BOOL) executeUpdate:(NSString *)objs withParams:(NSArray*)bindValues;
- (id) executeQuery:(NSString *)obj, ...;
- (id) executeQuery:(NSString *)sql withParams:(NSArray *)bindValues;

- (id) executeQuery:(NSString*)objs argList:(va_list)argList binds:(NSArray *)bindValues;

- (BOOL) rollback;
- (BOOL) commit;
- (BOOL) beginTransaction;
- (BOOL) endTransaction:(BOOL)performCommit;
- (BOOL) beginDeferredTransaction;
/*!
 End any transaction currently in progress with a rollback.
 
 This method does not require the database to be in a transaction.
 @return YES if the database was already in a transaction, NO otherwise
 */
- (BOOL) safelyEndTransaction;
@property (assign) BOOL logsErrors;
@property (assign) BOOL crashOnErrors;
@property (assign) BOOL inUse;
@property (assign) BOOL inTransaction;
@property (assign) BOOL traceExecution;
@property (assign) BOOL checkedOut;
@property (assign) BOOL deleteOnClose;
@property (assign) int busyRetryTimeout;
@property (readonly) NSString *databaseFile;

+ (NSString*) sqliteLibVersion;

@property (readwrite, assign) NSObject<FMDatabaseDelegate> *delegate;


@end
