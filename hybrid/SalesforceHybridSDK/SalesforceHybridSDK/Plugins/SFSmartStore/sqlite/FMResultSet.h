#import <Foundation/Foundation.h>
#import "sqlite3.h"

@class FMDatabase;

@interface FMResultSet : NSObject {
    FMDatabase			*parentDB;
    sqlite3_stmt		*pStmt;
    NSString			*query;
	NSArray				*binds;
    NSMutableDictionary *columnNameToIndexMap;
    BOOL				columnNamesSetup;
	BOOL				defaultColumnValues;
	int					columnCount;
}

+ (id) resultSetWithStatement:(sqlite3_stmt *)stmt query:(NSString *)sql binds:(NSArray *)binds parentDb:(FMDatabase*)aDB;

- (void) close;
- (BOOL) next;

- (NSString *)query;

- (int) intForColumn:(NSString*)columnName;
- (int) intForColumnIndex:(int)columnIdx;

- (long) longForColumn:(NSString*)columnName;
- (long) longForColumnIndex:(int)columnIdx;

- (BOOL) boolForColumn:(NSString*)columnName;
- (BOOL) boolForColumnIndex:(int)columnIdx;

- (double) doubleForColumn:(NSString*)columnName;
- (double) doubleForColumnIndex:(int)columnIdx;

- (NSNumber *) nsnumberForColumn:(NSString *)columnName;

- (NSString*) stringForColumn:(NSString*)columnName;
- (NSString*) stringForColumnIndex:(int)columnIdx;

- (NSDate*) dateForColumn:(NSString*)columnName;
- (NSDate*) dateForColumnIndex:(int)columnIdx;

- (NSData*) dataForColumn:(NSString*)columnName;
- (NSData*) dataForColumnIndex:(int)columnIdx;

- (void) kvcMagic:(id)object;
- (NSArray *)originalColumnNames;

- (int) columnIndexForName:(NSString*)columnName;

@end
