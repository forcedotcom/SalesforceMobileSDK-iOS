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

#import "SFSmartStoreTestCase.h"
#import "SFSoupIndex.h"
#import <SalesforceSDKCore/SFJsonUtils.h>
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
    if (expectedCount == actualCount) {
        for (int i=0; i<expectedCount; i++) {
            [self assertSameJSONWithExpected:expected[i] actual:actual[i] message:message];
        }
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

- (NSDictionary*) createJSON1IndexSpec:(NSString*) path
{
    return [self createSimpleIndexSpec:path withType:kSoupIndexTypeJSON1];
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

- (void) checkExplainQueryPlan:(NSString*) soupName index:(NSUInteger)index covering:(BOOL) covering dbOperation:(NSString*)dbOperation store:(SFSmartStore*)store
{
    NSString* soupTableName = [self getSoupTableName:soupName store:store];
    NSString* indexName = [NSString stringWithFormat:@"%@_%lu_idx", soupTableName, (unsigned long)index];
    NSString* expectedDetailPrefix = [NSString stringWithFormat:@"%@ TABLE %@ USING %@INDEX %@", dbOperation, soupTableName, (covering ? @"COVERING " : @""), indexName];
    NSString* actualDetail = ((NSArray*)store.lastExplainQueryPlan[EXPLAIN_ROWS])[0][@"detail"];
    XCTAssertTrue([actualDetail hasPrefix:expectedDetailPrefix], "Wrong explain plan actual: %@", actualDetail);
}

- (void) checkColumns:(NSString*)tableName expectedColumns:(NSArray*)expectedColumns store:(SFSmartStore*)store {
    __block NSMutableArray* actualColumns = [NSMutableArray new];
    [store.storeQueue inDatabase:^(FMDatabase* db) {
        NSString* sql = [NSString stringWithFormat:@"PRAGMA table_info(%@)", tableName];
        FMResultSet *frs = [db executeQuery:sql];
        
        while ([frs next]) {
            [actualColumns addObject:[frs stringForColumnIndex:1]];
        }
        [frs close];
    }];
    NSString* message = [NSString stringWithFormat:@"Wrong columns actual: %@", [actualColumns componentsJoinedByString:@","]];
    [self assertSameJSONArrayWithExpected:expectedColumns actual:actualColumns message:message];
}

- (void) checkDatabaseIndexes:(NSString*)tableName expectedSqlStatements:(NSArray*)expectedSqlStatements store:(SFSmartStore*)store {
    __block NSMutableArray* actualSqlStatements = [NSMutableArray new];
    [store.storeQueue inDatabase:^(FMDatabase* db) {
        FMResultSet *frs = [db executeQuery:@"SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name=? ORDER BY name", tableName];
        
        while ([frs next]) {
            [actualSqlStatements addObject:[frs stringForColumnIndex:0]];
        }
        [frs close];
    }];
    NSString* message = [NSString stringWithFormat:@"Wrong indexes actual:%@", [actualSqlStatements componentsJoinedByString:@","]];
    [self assertSameJSONArrayWithExpected:expectedSqlStatements actual:actualSqlStatements message:message];
}

- (void) checkCreateTableStatment:(NSString*)tableName expectedSqlStatementPrefix:(NSString*)expectedSqlStatementPrefix store:(SFSmartStore*)store {
    __block NSString* actualSqlStatement;
    [store.storeQueue inDatabase:^(FMDatabase* db) {
        FMResultSet *frs = [db executeQuery:@"SELECT sql FROM sqlite_master WHERE type='table' AND tbl_name=?", tableName];
        [frs next];
        actualSqlStatement = [frs stringForColumnIndex:0];
        [frs close];
    }];
    XCTAssert([actualSqlStatement containsString:expectedSqlStatementPrefix], @"Wrong statement actual:%@", actualSqlStatement);
}


- (void) checkSoupIndex:(SFSoupIndex*)indexSpec expectedPath:(NSString*)expectedPath expectedType:(NSString*)expectedType expectedColumnName:(NSString*)expectedColumnName {
    XCTAssertEqualObjects(expectedPath, indexSpec.path, @"Wrong path");
    XCTAssertEqualObjects(expectedType, indexSpec.indexType, @"Wrong type");
    XCTAssertEqualObjects(expectedColumnName, indexSpec.columnName, @"Wrong column name");    
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
        if (kValueExtractedToColumn(soupIndex)) {
            NSString* actualValue = [frs stringForColumn:soupIndex.columnName];
            NSString* expectedValue = [SFJsonUtils projectIntoJson:expectedEntry path:soupIndex.path];
            XCTAssertEqualObjects(actualValue, expectedValue, @"Wrong value in index column for %@", soupIndex.path);
        }
    }
    
    // Check soup column if there is one
    if ([frs columnIndexForName:SOUP_COL] >= 0) {
        XCTAssertEqualObjects([frs stringForColumn:SOUP_COL], [SFJsonUtils JSONRepresentation:expectedEntry], @"Wrong value in soup column");
    }
}

- (void) checkFtsRow:(FMResultSet*) frs withExpectedEntry:(NSDictionary*)expectedEntry withSoupIndexes:(NSArray*)arraySoupIndexes
{
    XCTAssertTrue([frs next], @"Expected rows to be returned");
    
    // Check rowid
    XCTAssertEqualObjects(@([frs longForColumn:ROWID_COL]), expectedEntry[SOUP_ENTRY_ID], @"Wrong id");

    // Check indexed columns
    for (SFSoupIndex* soupIndex in arraySoupIndexes)
    {
        if (kValueExtractedToFtsColumn(soupIndex)) {
            NSString* actualValue = [frs stringForColumn:soupIndex.columnName];
            NSString* expectedValue = [SFJsonUtils projectIntoJson:expectedEntry path:soupIndex.path];
            XCTAssertEqualObjects(actualValue, expectedValue, @"Wrong value in index column for %@", soupIndex.path);
        }
    }
}

-(void) checkSoupTable:(NSArray*)expectedEntries shouldExist:(BOOL)shouldExist store:(SFSmartStore*)store soupName:(NSString*)soupName
{
    // Getting ids of expected entries and building id to entry map
    NSMutableArray* expectedEntriesIds = [NSMutableArray new];
    NSMutableDictionary* idToExpectedEntries = [NSMutableDictionary new];
    
    for (NSDictionary* expectedEntry in expectedEntries) {
        NSNumber* soupEntryId = expectedEntry[SOUP_ENTRY_ID];
        [expectedEntriesIds addObject:soupEntryId];
        idToExpectedEntries[soupEntryId] = expectedEntry;
    }
    
    // Getting soup table name and storage type
    __block NSString *soupTableName;
    __block BOOL soupUsesExternalStorage;
    [store.storeQueue inDatabase:^(FMDatabase *db) {
        soupTableName = [store tableNameForSoup:soupName withDb:db];
        SFSoupSpec *soupSpec = [store attributesForSoup:soupName withDb:db];
        soupUsesExternalStorage = [soupSpec.features containsObject:kSoupFeatureExternalStorage];
    }];
    
    // Getting soup indexes
    NSArray* soupIndexes = [store indicesForSoup:soupName];
    
    // Getting data from soup table
    [store.storeQueue inDatabase:^(FMDatabase* db) {
        NSString *pred = [NSString stringWithFormat:@"%@ IN (%@) ", ID_COL, [expectedEntriesIds componentsJoinedByString:@","]];
        
        FMResultSet *frs = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@", soupTableName, pred]];
        
        // If entries are supposed to exist, make sure we actually find them in the database
        if (shouldExist) {
            NSMutableArray* actualRows = [NSMutableArray new];
            
            while([frs next]) {
                NSDictionary* actualRow = [frs resultDictionary];
                [actualRows addObject:actualRow];
            }
            
            XCTAssertEqual([actualRows count], [expectedEntries count], @"Wrong number of entries found");
            
            for (NSDictionary* actualRow in actualRows) {
                NSNumber* soupEntryId = actualRow[ID_COL];
                NSDictionary* expectedEntry = idToExpectedEntries[soupEntryId];
                
                for (SFSoupIndex* soupIndex in soupIndexes) {
                    if (![soupIndex.indexType isEqualToString:kSoupIndexTypeJSON1]) {
                        XCTAssertEqualObjects(actualRow[soupIndex.columnName], expectedEntry[soupIndex.path], @"Mismatching values for path %@ for entry %@", soupIndex.path, soupEntryId);
                    }
                    if (!soupUsesExternalStorage) {
                        NSDictionary* actualEntry = [SFJsonUtils objectFromJSONString:actualRow[SOUP_COL]];
                        [self assertSameJSONWithExpected:expectedEntry actual:actualEntry message:[NSString stringWithFormat:@"Mismatching json for entry %@", soupEntryId]];
                    }
                }
                
            }
        }
        // Otherwise, make sure we don't find them in the database
        else {
            XCTAssertFalse([frs next], @"None of the entries should have been found");
        }
    }];
}


-(void) checkFileSystem:(NSArray*)expectedEntries shouldExist:(BOOL)shouldExist store:(SFSmartStore*)store soupName:(NSString*)soupName
{
    __block NSString *soupTableName;
    [store.storeQueue inDatabase:^(FMDatabase *db) {
        soupTableName = [store tableNameForSoup:soupName withDb:db];
    }];
    
    for (NSDictionary* expectedEntry in expectedEntries) {
        NSNumber* soupEntryId = expectedEntry[SOUP_ENTRY_ID];
        NSString *externalEntryFilePath = [store
                                           externalStorageSoupFilePath:soupEntryId                                                               soupTableName:soupTableName];
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:externalEntryFilePath];
        if (shouldExist) {
            XCTAssertTrue(fileExists, @"External file for %@ should exist", soupEntryId);
            NSDictionary* actualEntry = [store loadExternalSoupEntry:soupEntryId soupTableName:soupTableName];
            [self assertSameJSONWithExpected:expectedEntry actual:actualEntry message:@"Wrong json"];
        }
        else {
            XCTAssertFalse(fileExists, @"External file for %@ should not exist", soupEntryId);
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
