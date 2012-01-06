/*
 * Copyright, 2008, salesforce.com
 * All Rights Reserved
 * Company Confidential
 */

#import "FMDbException.h"
#import "FMDatabase.h"

@implementation FMDbException

@synthesize resultCode=rc, sql, binds, dbFile;

-(id)initWithResultCode:(int)theRc msg:(NSString *)msg sql:(NSString *)s binds:(NSArray *)b dbFile:(NSString *)file {
	self = [super initWithName:@"DatabaseException" reason:msg userInfo:nil];
	rc = theRc;
	sql = [s retain];
	binds = [b retain];
	dbFile = [file retain];
	return self;
}

-(void)dealloc {
	[sql release];
	[binds release];
	[dbFile release];
	[super dealloc];
}

+(id)exceptionForResultCode:(int)rc database:(FMDatabase *)db stmt:(sqlite3_stmt *)stmt sql:(NSString *)sql binds:(NSArray *)binds {
	sqlite3_reset(stmt);
	NSString *msg = [NSString stringWithFormat:@"%s (%d)", sqlite3_errmsg([db sqliteHandle]), rc];
	return [[[FMDbException alloc] initWithResultCode:rc msg:msg sql:sql binds:binds dbFile:[db databaseFile]] autorelease];
}

-(NSString *)description {
	return [NSString stringWithFormat:@"%@ : %@\ndbFile : %@\nsql    : %@\nbinds  : %@", [self name], [self reason], dbFile, sql, binds];
}

@end
