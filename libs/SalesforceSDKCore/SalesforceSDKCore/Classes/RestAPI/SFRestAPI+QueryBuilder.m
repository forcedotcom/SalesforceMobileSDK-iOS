/* 
 * Copyright (c) 2012, salesforce.com, inc.
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided 
 * that the following conditions are met:
 * 
 *    Redistributions of source code must retain the above copyright notice, this list of conditions and the 
 *    following disclaimer.
 *  
 *    Redistributions in binary form must reproduce the above copyright notice, this list of conditions and 
 *    the following disclaimer in the documentation and/or other materials provided with the distribution. 
 *    
 *    Neither the name of salesforce.com, inc. nor the names of its contributors may be used to endorse or 
 *    promote products derived from this software without specific prior written permission.
 *  
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED 
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR 
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import "SFRestAPI+QueryBuilder.h"


// Reserved characters that must be escaped in SOSL search terms
// backslash goes first!
NSString * const kSOSLReservedCharacters = @"\\?&|!{}[]()^~*:\"'+-";
NSString * const kSOSLEscapeCharacter    = @"\\";

// Maximum number of records returned via SOSL search
NSInteger const kMaxSOSLSearchLimit      = 200;

@implementation SFRestAPI (QueryBuilder)

+ (NSString *)sanitizeSOSLSearchTerm:(NSString *)searchTerm {
	// Escape every reserved character in this term
	for( int i = 0; i < [kSOSLReservedCharacters length]; i++ ) {
		NSString *ch = [kSOSLReservedCharacters substringWithRange:NSMakeRange(i, 1)];

		searchTerm = [searchTerm stringByReplacingOccurrencesOfString:ch
														   withString:[kSOSLEscapeCharacter stringByAppendingString:ch]];
	}

	return searchTerm;
}

+ (NSString *)SOSLSearchWithSearchTerm:(NSString *)term objectScope:(NSDictionary *)objectScope {
	return [self SOSLSearchWithSearchTerm:term
							   fieldScope:nil
							  objectScope:objectScope 
							   	    limit:0];
}

+ (NSString *)SOSLSearchWithSearchTerm:(NSString *)term fieldScope:(NSString *)fieldScope objectScope:(NSDictionary *)objectScope limit:(NSInteger)limit {
	if( !term || [term length] == 0 )
		return nil;

	if( !fieldScope || [fieldScope length] == 0 )
		fieldScope = @"IN NAME FIELDS";

	NSMutableString *query = [NSMutableString stringWithFormat:@"FIND {%@} %@",
								[self sanitizeSOSLSearchTerm:term],
								fieldScope];

	if( objectScope && [objectScope count] > 0 ) {
		NSMutableArray *scopes = [NSMutableArray array];

		for( NSString *sObject in [objectScope allKeys] ) {
            NSMutableString *scope = [NSMutableString stringWithString:sObject];
            
            if( [objectScope[sObject] isKindOfClass:[NSString class]] )
                [scope appendFormat:@" (%@)", objectScope[sObject]];
            
			[scopes addObject:scope];
        }

		[query appendString:[NSString stringWithFormat:@" RETURNING %@", [scopes componentsJoinedByString:@","]]];
	}

	if( limit > 0 )
		[query appendFormat:@" LIMIT %ld", (long)( limit > kMaxSOSLSearchLimit ? kMaxSOSLSearchLimit : limit )];

	return query;
}

+ (NSString *)SOQLQueryWithFields:(NSArray *)fields sObject:(NSString *)sObject whereClause:(NSString *)whereClause limit:(NSInteger)limit {
	return [self SOQLQueryWithFields:fields
							 sObject:sObject
							   whereClause:whereClause
							 groupBy:nil
							  having:nil
							 orderBy:nil
							   limit:limit];
}

+ (NSString *)SOQLQueryWithFields:(NSArray *)fields sObject:(NSString *)sObject whereClause:(NSString *)whereClause groupBy:(NSArray *)groupBy having:(NSString *)having orderBy:(NSArray *)orderBy limit:(NSInteger)limit {
	if( !fields || [fields count] == 0 )
		return nil;

	if( !sObject || [sObject length] == 0 )
		return nil;

	NSMutableString *query = [NSMutableString stringWithFormat:@"select %@ from %@",
							  [[[NSSet setWithArray:fields] allObjects] componentsJoinedByString:@","],
							  sObject];

	if( whereClause && [whereClause length] > 0 )
		[query appendFormat:@" where %@", whereClause];

	if( groupBy && [groupBy count] > 0 ) {
		[query appendFormat:@" group by %@", [groupBy componentsJoinedByString:@","]];

		if( having && [having length] > 0 )
			[query appendFormat:@" having %@", having];
	}

	if( orderBy && [orderBy count] > 0 )
		[query appendFormat:@" order by %@", [orderBy componentsJoinedByString:@","]];

	if( limit > 0 )
		[query appendFormat:@" limit %ld", (long)limit];

	return query;
}

@end
