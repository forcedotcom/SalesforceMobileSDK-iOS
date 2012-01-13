//
//  FMDatabaseAdditions.h
//  fmkit
//
//  Created by August Mueller on 10/30/05.
//  Copyright 2005 Flying Meat Inc.. All rights reserved.
//

#import "FMDatabase.h"

@interface FMDatabase (FMDatabaseAdditions)

- (int) intForQuery:(NSString*)objs, ...;
- (long) longForQuery:(NSString*)objs, ...; 
- (BOOL) boolForQuery:(NSString*)objs, ...;
- (double) doubleForQuery:(NSString*)objs, ...;
- (NSData*) dataForQuery:(NSString*)objs, ...;
- (NSString*) stringForQuery:(NSString*)objs, ...; 
- (NSDate*) dateForQuery:(NSString*)objs, ...;
@end


@interface FMDatabase (Schema)
-(BOOL)tableExists:(NSString *)tableName;
@end