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
 
 
 /** 
 * This category assists with creating SOQL and SOSL queries. 
 * 
 * Example SOQL usage:
 * 
 * NSString *soqlQuery = 
 * [SFRestAPI SOQLQueryWithFields:[NSArray arrayWithObjects:@"Id", @"Name", @"Company", @"Status", nil]
 *                             sObject:@"Lead"
 *                               whereClause:nil
 *                               limit:10];
 *   							   
 *   							   
 * Example SOSL usage:
 * 
 * NSString *soslQuery = 
 * [SFRestAPI SOSLSearchWithSearchTerm:@"all of these will be escaped:~{]"
 *							  objectScope:[NSDictionary dictionaryWithObject:@"WHERE isactive=true ORDER BY lastname asc limit 5"
 *								 									  forKey:@"User"]];
 *
 */

#import <Foundation/Foundation.h>
#import "SFRestAPI.h"

NS_ASSUME_NONNULL_BEGIN

// Reserved characters that must be escaped in SOSL search terms
extern NSString * const kSOSLReservedCharacters;
extern NSString * const kSOSLEscapeCharacter;

// Maximum number of records returned via SOSL search
extern NSInteger const kMaxSOSLSearchLimit;

@interface SFRestAPI (QueryBuilder)

/**
 @param searchTerm The search term to be sanitized.
 @return SOSL-safe version of search term
 */
+ (NSString *) sanitizeSOSLSearchTerm:(NSString *)searchTerm;

#pragma mark - Generating searches

/**
 * Generate a SOSL search.
 * @param term - the search term. This is sanitized for proper characters
 * @param objectScope - nil to search all searchable objects, or a dictionary where each key is an sObject name
 * and each value is a string with the fieldlist and (optional) where, order by, and limit clause for that object.
 * or NSNull to not specify any fields/clauses for that object
 * @returns query or nil if a query could not be generated
 */
+ (nullable NSString *) SOSLSearchWithSearchTerm:(NSString *)term
                            objectScope:(nullable NSDictionary<NSString*, NSString*> *)objectScope;

/**
 * Generate a SOSL search.
 * @param term - the search term. This is sanitized for proper characters
 * @param fieldScope - nil OR the SOSL scope, e.g. "IN ALL FIELDS". if nil, defaults to "IN NAME FIELDS"
 * @param objectScope - nil to search all searchable objects, or a dictionary where each key is an sObject name
 * and each value is a string with the fieldlist and (optional) where, order by, and limit clause for that object.
 * or NSNull to not specify any fields/clauses for that object
 * @param limit - overall search limit (max 200)
 * @returns query or nil if a query could not be generated
 */
+ (nullable NSString *) SOSLSearchWithSearchTerm:(NSString *)term
                             fieldScope:(nullable NSString *)fieldScope
                            objectScope:(nullable NSDictionary<NSString*, NSString*> *)objectScope
                                  limit:(NSInteger)limit;

/**
 * Generate a SOQL query.
 * @param fields - NSArray of fields to select
 * @param sObject - object to query
 * @param whereClause - nil OR where clause
 * @param limit - limit count, or 0 for no limit (for use with query locators)
 * @returns query or nil if a query could not be generated
 */
+ (nullable NSString *) SOQLQueryWithFields:(NSArray<NSString*> *)fields
                           sObject:(NSString *)sObject 
                             whereClause:(nullable NSString *)whereClause
                             limit:(NSInteger)limit;

/**
 * Generate a SOQL query.
 * @param fields - NSArray of fields to select
 * @param sObject - object to query
 * @param whereClause - nil OR where clause
 * @param groupBy - nil OR NSArray of strings, each string is an individual group by clause
 * @param having - nil OR having clause
 * @param orderBy - nil OR NSArray of strings, each string is an individual order by clause
 * @param limit - limit count, or 0 for no limit (for use with query locators)
 * @returns query or nil if a query could not be generated
 */
+ (nullable NSString *) SOQLQueryWithFields:(NSArray<NSString*> *)fields
                           sObject:(NSString *)sObject 
                             whereClause:(nullable NSString *)whereClause
                           groupBy:(nullable NSArray<NSString*> *)groupBy
                            having:(nullable NSString *)having
                           orderBy:(nullable NSArray<NSString*> *)orderBy
                             limit:(NSInteger)limit;

@end

NS_ASSUME_NONNULL_END
