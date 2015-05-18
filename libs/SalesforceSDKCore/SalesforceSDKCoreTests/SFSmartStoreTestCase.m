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

#import "SFSmartStoreTestCase.h"
#import "SFSoupIndex.h"
#import "SFJsonUtils.h"
#import "SFSmartStore+Internal.h"
#import "FMDatabaseQueue.h"
#import "FMDatabase.h"

@implementation SFSmartStoreTestCase

#pragma mark - helper methods for comparing json

- (void) assertSameJSONWithExpected:(id)expected actual:(id) actual message:(NSString*) message
{
    // At least one nil
    if (expected == nil || actual == nil) {
        // Both nil
        if (expected == nil && actual == nil) {
            return;
        }
        else {
           XCTFail(@"%@", message);
        }
    }
    // Both arrays
    else if ([expected isKindOfClass:[NSArray class]] && [actual isKindOfClass:[NSArray class]]) {
        [self assertSameJSONArrayWithExpected:(NSArray*) expected actual:(NSArray*) actual message:message];
    }
    // Both maps
    else if ([expected isKindOfClass:[NSDictionary class]] && [actual isKindOfClass:[NSDictionary class]]) {
        [self assertSameJSONMapWithExpected:(NSDictionary*) expected actual:(NSDictionary*) actual message:message];        
    }
    // Strings/numbers/booleans
    else {
        XCTAssertEqualObjects(expected, actual, @"%@", message);
    }
    
}

- (void) assertSameJSONArrayWithExpected:(NSArray*)expected actual:(NSArray*) actual message:(NSString*) message
{
    // First compare length
    NSUInteger expectedCount = [expected count];
    NSUInteger actualCount = [actual count];

    XCTAssertEqual(expectedCount, actualCount, @"%@", message);
 
    // Compare values in array
    for (int i=0; i<expectedCount; i++) {
        [self assertSameJSONWithExpected:expected[i] actual:actual[i] message:message];
    }
}

- (void) assertSameJSONMapWithExpected:(NSDictionary*)expected actual:(NSDictionary*) actual message:(NSString*) message
{
    // First compare length
    NSUInteger expectedCount = [expected count];
    NSUInteger actualCount = [actual count];
    XCTAssertEqual(expectedCount, actualCount, @"%@", message);
    
    // Compare values in array
    NSEnumerator* enumator = [expected keyEnumerator];
    id key;
    while (key = [enumator nextObject]) {
        [self assertSameJSONWithExpected:expected[key] actual:actual[key] message:message];
    }
}

- (NSDictionary*) createIntegerIndexSpec:(NSString*) path
{
    return [self createSimpleIndexSpec:path withType:kSoupIndexTypeInteger];
}

- (NSDictionary*) createFloatingIndexSpec:(NSString*) path
{
    return [self createSimpleIndexSpec:path withType:kSoupIndexTypeFloating];
}

- (NSDictionary*) createFullTextIndexSpec:(NSString*) path
{
    return [self createSimpleIndexSpec:path withType:kSoupIndexTypeFullText];
}

- (NSDictionary*) createStringIndexSpec:(NSString*) path
{
    return [self createSimpleIndexSpec:path withType:kSoupIndexTypeString];
}

- (NSDictionary*) createSimpleIndexSpec:(NSString*) path withType:(NSString*) pathType
{
    return @{@"path": path, @"type": pathType};
}

- (BOOL) hasTable:(NSString*)tableName store:(SFSmartStore*)store
{
    __block NSInteger result = NSNotFound;
    [store.storeQueue inDatabase:^(FMDatabase* db) {
        FMResultSet *frs = [db executeQuery:@"select count(1) from sqlite_master where type = ? and name = ?" withArgumentsInArray:@[@"table", tableName]];
        
        if ([frs next]) {
            result = [frs intForColumnIndex:0];
        }
        [frs close];
    }];
    
    return result == 1;
}

- (NSString*) getSoupTableName:(NSString*)soupName store:(SFSmartStore*)store
{
    __block NSString* result;
    [store.storeQueue inDatabase:^(FMDatabase* db) {
        result = [store tableNameForSoup:soupName withDb:db];
    }];
    
    return result;
    
}

- (void) checkSoupRow:(FMResultSet*) frs withExpectedEntry:(NSDictionary*)expectedEntry withSoupIndexes:(NSArray*)arraySoupIndexes
{
    XCTAssertTrue([frs next], @"Expected rows to be returned");
    // Check id
    XCTAssertEqualObjects(@([frs longForColumn:ID_COL]), expectedEntry[SOUP_ENTRY_ID], @"Wrong id");
    
    /*
     // FIXME value coming back is an int - needs to be investigated and fixed in 2.2
     STAssertEqualObjects([NSNumber numberWithLong:[frs longForColumn:LAST_MODIFIED_COL]], expectedEntry[SOUP_LAST_MODIFIED_DATE], @"Wrong last modified date");
     */
    
    // Check indexed columns
    for (SFSoupIndex* soupIndex in arraySoupIndexes)
    {
        NSString* actualValue = [frs stringForColumn:soupIndex.columnName];
        NSString* expectedValue = [SFJsonUtils projectIntoJson:expectedEntry path:soupIndex.path];
        XCTAssertEqualObjects(actualValue, expectedValue, @"Wrong value in index column for %@", soupIndex.path);
    }
    
    // Check soup column
    XCTAssertEqualObjects([frs stringForColumn:SOUP_COL], [SFJsonUtils JSONRepresentation:expectedEntry], @"Wrong value in soup column");
}

- (void) checkFtsRow:(FMResultSet*) frs withExpectedEntry:(NSDictionary*)expectedEntry withSoupIndexes:(NSArray*)arraySoupIndexes
{
    XCTAssertTrue([frs next], @"Expected rows to be returned");
    
    // Check docid
    XCTAssertEqualObjects(@([frs longForColumn:DOCID_COL]), expectedEntry[SOUP_ENTRY_ID], @"Wrong id");

    // Check indexed columns
    for (SFSoupIndex* soupIndex in arraySoupIndexes)
    {
        if ([soupIndex.indexType isEqualToString:kSoupIndexTypeFullText]) {
            NSString* actualValue = [frs stringForColumn:soupIndex.columnName];
            NSString* expectedValue = [SFJsonUtils projectIntoJson:expectedEntry path:soupIndex.path];
            XCTAssertEqualObjects(actualValue, expectedValue, @"Wrong value in index column for %@", soupIndex.path);
        }
    }
}

- (SFUserAccount*)setUpSmartStoreUser
{
    u_int32_t userIdentifier = arc4random();
    SFUserAccount *user = [[SFUserAccount alloc] initWithIdentifier:[NSString stringWithFormat:@"identifier-%u", userIdentifier]];
    NSString *userId = [NSString stringWithFormat:@"user_%u", userIdentifier];
    NSString *orgId = [NSString stringWithFormat:@"org_%u", userIdentifier];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://login.salesforce.com/id/%@/%@", orgId, userId]];
    
    [[SFUserAccountManager sharedInstance] addAccount:user];
    [SFUserAccountManager sharedInstance].currentUser = user;
    
    return user;
}

- (void)tearDownSmartStoreUser:(SFUserAccount*)user
{
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:user error:nil];
    [SFUserAccountManager sharedInstance].currentUser = nil;
}


@end
