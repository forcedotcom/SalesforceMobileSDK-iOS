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
