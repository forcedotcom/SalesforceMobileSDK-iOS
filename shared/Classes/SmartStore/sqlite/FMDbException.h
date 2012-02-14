/*
 * Copyright, 2008, salesforce.com
 * All Rights Reserved
 * Company Confidential
 */

#import <UIKit/UIKit.h>
#import "sqlite3.h"

@class FMDatabase;

@interface FMDbException : NSException {
	int		 rc;
	NSString *sql;
	NSArray  *binds;
	NSString *dbFile;
}

+(id)exceptionForResultCode:(int)rc database:(FMDatabase *)db stmt:(sqlite3_stmt *)stmt sql:(NSString *)sql binds:(NSArray *)binds;

@property (readonly) int resultCode;
@property (readonly) NSString *sql;
@property (readonly) NSArray *binds;
@property (readonly) NSString *dbFile;

@end
