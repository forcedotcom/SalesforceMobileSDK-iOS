/*
 Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SFSmartSqlHelper.h"
#import "SFSmartStore+Internal.h"
#import "SFSoupSpec.h"

static SFSmartSqlHelper *sharedInstance = nil;

static NSString* const kSmartSqlHelperNoStringsOrFullStrings = @"^([^']|'[^']*')*";
//  ^           # the start of the string, then
//  ([^']       # either not a quote character
//  |'[^']*'    # or a fully quoted string
//  )*          # as many times as you want

static NSRegularExpression* insideQuotedStringRegexp;

static NSRegularExpression* insideQuotedStringForFTSMatchPredicateRegexp;

static NSString* const kTableDotJsonExtract = @"(\\w+)\\.json_extract\\(soup";

static NSRegularExpression* tableDotJsonExtractRegexp;

static NSString* const kSoupPathPattern = @"\\{([^}]+)\\}";

static NSRegularExpression* soupPathRegexp;

@implementation SFSmartSqlHelper

+ (SFSmartSqlHelper*) sharedInstance
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [[super alloc] init];
        
        insideQuotedStringRegexp = [[NSRegularExpression alloc]
                                    initWithPattern:[kSmartSqlHelperNoStringsOrFullStrings stringByAppendingString:@"'[^']*"]
                                    options:0 error:nil];
        insideQuotedStringForFTSMatchPredicateRegexp = [[NSRegularExpression alloc]
                                                        initWithPattern:[kSmartSqlHelperNoStringsOrFullStrings stringByAppendingString:@"MATCH[ ]+'[^']*"]
                                                        options:0 error:nil];
        
        tableDotJsonExtractRegexp = [NSRegularExpression regularExpressionWithPattern:kTableDotJsonExtract options:0 error:nil];
        
        soupPathRegexp = [NSRegularExpression regularExpressionWithPattern:kSoupPathPattern options:0 error:nil];
    });
    
    return sharedInstance;
}

- (NSString*) convertSmartSql:(NSString*)smartSql withStore:(SFSmartStore*) store withDb:(FMDatabase *)db
{
    // Select's only
    NSString* smartSqlLowerCase = [[smartSql lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([smartSqlLowerCase hasPrefix:@"insert"]
        || [smartSqlLowerCase hasPrefix:@"update"]
        || [smartSqlLowerCase hasPrefix:@"delete"]) {

        @throw [NSException exceptionWithName:@"convertSmartSql failed" reason:@"Only SELECT are supported" userInfo:nil];
    }
    
    // Replacing {soupName} and {soupName:path}
    NSMutableString* sql = [NSMutableString string];
    
    NSArray *matches = [soupPathRegexp matchesInString:smartSql
                                              options:0
                                                range:NSMakeRange(0, [smartSql length])];

    NSUInteger lastPosition = 0;
    for (NSTextCheckingResult* matchResult in matches) {
        NSRange matchRange = [matchResult range];
        NSString* fullMatch = [smartSql substringWithRange:matchRange];
        NSString* match = [smartSql substringWithRange:[matchResult rangeAtIndex:1]];
        NSUInteger position = matchRange.location;

        NSString* beforeStr = [smartSql substringToIndex:position];
        NSRange searchedRange = NSMakeRange(0, [beforeStr length]);

        BOOL isInsideQuotedString = NSEqualRanges(searchedRange,
                                                  [insideQuotedStringRegexp
                                                   rangeOfFirstMatchInString:beforeStr
                                                   options:0
                                                   range:searchedRange]);
        BOOL isInsideQuotedStringForFTSMatchPredicate = NSEqualRanges(searchedRange,
                                                                      [insideQuotedStringForFTSMatchPredicateRegexp
                                                                       rangeOfFirstMatchInString:beforeStr
                                                                       options:0
                                                                       range:searchedRange]);

        if (isInsideQuotedString && !isInsideQuotedStringForFTSMatchPredicate) {
            continue;
        }

        NSArray* parts = [match componentsSeparatedByString:@":"];
        NSString* soupName = parts[0];
        SFSoupSpec *soupSpec = [store attributesForSoup:soupName withDb:db];
        BOOL soupUsesExternalStorage = [soupSpec.features containsObject:kSoupFeatureExternalStorage];
        NSString* soupTableName = [store tableNameForSoup:soupName withDb:db];
        if (nil == soupTableName) {
            @throw [NSException exceptionWithName:@"convertSmartSql failed" reason:[NSString stringWithFormat:@"Invalid soup name:%@", soupName] userInfo:nil];
        }
        BOOL tableQualified = [smartSql characterAtIndex:position-1] == '.';
        NSString* tableQualifier = tableQualified ? @"" : [soupTableName stringByAppendingString:@"."];

        // Appending the part before we have not used
        [sql appendString:[smartSql substringWithRange:NSMakeRange(lastPosition, position-lastPosition)]];
        lastPosition = position + matchRange.length;
        
        // {soupName}
        if ([parts count] == 1) {
            [sql appendString:soupTableName];
        }
        else if ([parts count] == 2) {
            NSString* path = parts[1];
            // {soupName:_soup}
            if ([path isEqualToString:@"_soup"]) {
                if (soupUsesExternalStorage) {
                    [sql appendFormat:@"'%@' as '%@'", soupTableName, kSoupFeatureExternalStorage];
                    [sql appendFormat:@", %@.%@ as '%@'", soupTableName, ID_COL, SOUP_ENTRY_ID];
                } else {
                    [sql appendString:tableQualifier];
                    [sql appendString:@"soup"];
                }
            }
            // {soupName:_soupEntryId}
            else if ([path isEqualToString:@"_soupEntryId"]) {
                [sql appendString:tableQualifier];
                [sql appendString:@"id"];
            }
            // {soupName:_soupCreatedDate}
            else if ([path isEqualToString:@"_soupCreatedDate"]) {
                [sql appendString:tableQualifier];
                [sql appendString:@"created"];
            }
            // {soupName:_soupLastModifiedDate}
            else if ([path isEqualToString:@"_soupLastModifiedDate"]) {
                [sql appendString:tableQualifier];
                [sql appendString:@"lastModified"];
            }
            // {soupName:path}
            else {
                NSString* columnName = nil;
                BOOL indexed = [store hasIndexForPath:path inSoup:soupName withDb:db];
                if (!indexed && !soupUsesExternalStorage) {
                    // Thanks to the json1 extension we can query the data even if it is not indexed (as long as the data is stored in the database)
                    columnName = [NSString stringWithFormat:@"json_extract(soup, '$.%@')", path];
                } else {
                    columnName = [store columnNameForPath:path inSoup:soupName withDb:db];
                    if (nil == columnName) {
                        @throw [NSException exceptionWithName:@"convertSmartSql failed" reason:[NSString stringWithFormat:@"Invalid path:%@", path] userInfo:nil];
                    }
                }
                [sql appendString:columnName];
            }
        }
        else if ([parts count] > 2) {
            @throw [NSException exceptionWithName:@"convertSmartSql failed" reason:[NSString stringWithFormat:@"Invalid soup/path reference: %@ at character: %lu", fullMatch, (unsigned long)position] userInfo:nil];
        }
    }
    
    // Appending the tail
    [sql appendString:[smartSql substringFromIndex:lastPosition]];

    
    // With json1 support, the column name could be an expression of the form json_extract(soup, '$.x.y.z')
    // We can't have TABLE_x.json_extract(soup, ...) or table_alias.json_extract(soup, ...) in the sql query
    // Instead we should have json_extract(TABLE_x.soup, ...)
    [tableDotJsonExtractRegexp replaceMatchesInString:sql options:0 range:NSMakeRange(0, [sql length]) withTemplate:@"json_extract($1.soup"];
    
    return sql;
}

@end
