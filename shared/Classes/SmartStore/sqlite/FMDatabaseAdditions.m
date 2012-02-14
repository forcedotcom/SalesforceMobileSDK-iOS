//
//  FMDatabaseAdditions.m
//  fmkit
//
//  Created by August Mueller on 10/30/05.
//  Copyright 2005 Flying Meat Inc.. All rights reserved.
//

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@implementation FMDatabase (FMDatabaseAdditions)

- (NSString*) stringForQuery:(NSString*)objs, ...; {
    va_list argsList;
	va_start(argsList, objs);
    FMResultSet *rs = [self executeQuery:objs argList:argsList binds:nil];
    if (![rs next]) {
		[rs close];
        return nil;
	}
    NSString *ret = [rs stringForColumnIndex:0];
    [rs close];
    return ret;
}

- (int) intForQuery:(NSString*)objs, ...; {
    va_list argsList;
	va_start(argsList, objs);
    FMResultSet *rs = [self executeQuery:objs argList:argsList binds:nil];
    if (![rs next]) {
		[rs close];
        return 0;
    }
    int ret = [rs intForColumnIndex:0];
    [rs close];
    return ret;
}

- (long) longForQuery:(NSString*)objs, ...; {
    va_list argsList;
	va_start(argsList, objs);
    FMResultSet *rs = [self executeQuery:objs argList:argsList binds:nil];
    if (![rs next]) {
		[rs close];
        return 0;
    }
    long ret = [rs longForColumnIndex:0];
    [rs close];
    return ret;
}

- (BOOL) boolForQuery:(NSString*)objs, ...; {
    va_list argsList;
	va_start(argsList, objs);
    FMResultSet *rs = [self executeQuery:objs argList:argsList binds:nil];
    if (![rs next]) {
		[rs close];
        return NO;
    }
    BOOL ret = [rs boolForColumnIndex:0];
    [rs close];
    return ret;
}

- (double) doubleForQuery:(NSString*)objs, ...; {
    va_list argsList;
	va_start(argsList, objs);
    FMResultSet *rs = [self executeQuery:objs argList:argsList binds:nil];
    if (![rs next]) {
		[rs close];
        return 0;
    }
    double ret = [rs doubleForColumnIndex:0];
    [rs close];
    return ret;
}

- (NSData*) dataForQuery:(NSString*)objs, ...; {
    va_list argsList;
	va_start(argsList, objs);
    FMResultSet *rs = [self executeQuery:objs argList:argsList binds:nil];
    if (![rs next]) {
		[rs close];
        return nil;
    }
    NSData *data = [rs dataForColumnIndex:0];
    [rs close];
    return data;
}

- (NSDate*) dateForQuery:(NSString*)objs, ...; {
    va_list argsList;
	va_start(argsList, objs);
    FMResultSet *rs = [self executeQuery:objs argList:argsList binds:nil];
    if (![rs next]) {
		[rs close];
        return nil;
    }
    NSDate *date = [rs dateForColumnIndex:0];
    [rs close];
    return date;
}
@end

@implementation FMDatabase (Schema)	

-(BOOL)tableExists:(NSString *)tableName {
	return [self intForQuery:@"select count(name) from sqlite_master where type='table' and name=?", tableName] > 0;
}

@end
