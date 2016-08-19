/*
 Copyright (c) 2013, salesforce.com, inc. All rights reserved.
 
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

@implementation SFSmartSqlHelper

+ (SFSmartSqlHelper*) sharedInstance
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [[super alloc] init];
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
    NSScanner* scanner = [NSScanner scannerWithString:smartSql];
    [scanner setCharactersToBeSkipped:nil];
    while(![scanner isAtEnd]) {
        NSMutableString* foundString = [NSMutableString string];
        if([scanner scanUpToString:@"{" intoString:&foundString]) {
            [sql appendString:foundString];
        }
        if(![scanner isAtEnd]) {
            NSUInteger position = [scanner scanLocation];
            [scanner scanString:@"{" intoString:nil];
            [scanner scanUpToString:@"}" intoString:&foundString];
            
            NSArray* parts = [foundString componentsSeparatedByString:@":"];
            NSString* soupName = parts[0];
            SFSoupSpec *soupSpec = [store attributesForSoup:soupName withDb:db];
            BOOL soupUsesExternalStorage = [soupSpec.features containsObject:kSoupFeatureExternalStorage];
            NSString* soupTableName = [store tableNameForSoup:soupName withDb:db];
            if (nil == soupTableName) {
                @throw [NSException exceptionWithName:@"convertSmartSql failed" reason:[NSString stringWithFormat:@"Invalid soup name:%@", soupName] userInfo:nil];
            }
            BOOL tableQualified = [smartSql characterAtIndex:position-1] == '.';
            NSString* tableQualifier = tableQualified ? @"" : [soupTableName stringByAppendingString:@"."];
            
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
                    NSString* columnName = [store columnNameForPath:path inSoup:soupName withDb:db];
                    if (nil == columnName) {
                        @throw [NSException exceptionWithName:@"convertSmartSql failed" reason:[NSString stringWithFormat:@"Invalid path:%@", path] userInfo:nil];
                    }
                    [sql appendString:columnName];
                }
            }
            else if ([parts count] > 2) {
                @throw [NSException exceptionWithName:@"convertSmartSql failed" reason:[NSString stringWithFormat:@"Invalid soup/path reference: %@ at character: %lu", foundString, (unsigned long)position] userInfo:nil];
            }
            
            
            [scanner scanString:@"}" intoString:nil];
        }
    }
    
    // With json1 support, the column name could be an expression of the form json_extract(soup, '$.x.y.z')
    // We can't have TABLE_x.json_extract(soup, ...) or table_alias.json_extract(soup, ...) in the sql query
    // Instead we should have json_extract(TABLE_x.soup, ...)
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"([^ ]+)\\.json_extract\\(soup" options:0 error:&error];
    [regex replaceMatchesInString:sql options:0 range:NSMakeRange(0, [sql length]) withTemplate:@"json_extract($1.soup"];
    
    return sql;
}

@end
