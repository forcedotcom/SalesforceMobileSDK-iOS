/*
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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

#import <XCTest/XCTest.h>
#import "SFSmartStoreTests.h"
#import "SFSoupSpec.h"
#import "SFSoupIndex.h"
#import "SFSmartStore+Internal.h"
#import "SFQuerySpec.h"
#import "FMDatabaseQueue.h"
#import <SalesforceSDKCore/SFEncryptionKey.h>
#import <SalesforceSDKCore/SFJSONUtils.h>

NSString * const kSSExternalStorage_TestSoupName = @"SSExternalStorage_TestSoupName";
NSString * const kSSAlphabets = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXZY0123456789";

static NSInteger const kSSMegaBytePayloadSize = 1024 * 1024;

@interface SFSmartStoreWithExternalStorageTests : SFSmartStoreTests

@end

@implementation SFSmartStoreWithExternalStorageTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testRegisterSoupWithExternalStorage {
    NSUInteger const iterations = 10;
    SFSoupSpec *soupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:@[kSoupFeatureExternalStorage]];
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        for (NSUInteger i = 0; i < iterations; i++) {
            // Before
            XCTAssertFalse([store soupExists:kSSExternalStorage_TestSoupName], @"Soup should not exist before registration.");
            
            // Register
            NSDictionary* soupIndex = @{@"path": @"name", @"type": @"string"};
            NSError* error = nil;
            [store registerSoupWithSpec:soupSpec withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]] error:&error];
            BOOL testSoupExists = [store soupExists:kSSExternalStorage_TestSoupName];
            XCTAssertTrue(testSoupExists, @"Soup should exist after registration.");
            XCTAssertNil(error, @"There should be no errors.");
            
            // Check attributes
            SFSoupSpec *registeredSpecs = [store attributesForSoup:kSSExternalStorage_TestSoupName];
            XCTAssertTrue([registeredSpecs.features containsObject:kSoupFeatureExternalStorage], @"Soup did not register features.");
            
            // Check if external dir was created
            __block NSString *soupTableName;
            [store.storeQueue inDatabase:^(FMDatabase *db) {
                soupTableName = [store tableNameForSoup:kSSExternalStorage_TestSoupName withDb:db];
            }];
            NSString *externalSoupDir = [store externalStorageSoupDirectory:soupTableName];
            BOOL isDir;
            BOOL dirExists = [[NSFileManager defaultManager] fileExistsAtPath:externalSoupDir isDirectory:&isDir];
            XCTAssertTrue(dirExists && isDir, @"External diretory was not created correctly.");
            
            // Remove soup
            [store removeSoup:kSSExternalStorage_TestSoupName];
            testSoupExists = [store soupExists:kSSExternalStorage_TestSoupName];
            XCTAssertFalse(testSoupExists, @"Soup should no longer exist after dropping.");
            
            // Check if external dir was removed
            dirExists = [[NSFileManager defaultManager] fileExistsAtPath:externalSoupDir];
            XCTAssertFalse(dirExists, @"External directory was not deleted.");
        }
    }
}

- (void)testInsertEntryWithExternalStorage {
    NSUInteger const iterations = 10;
    SFSoupSpec *soupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:@[kSoupFeatureExternalStorage]];
    NSDictionary* soupIndex = @{@"path": @"name", @"type": @"string"};
    
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        [store registerSoupWithSpec:soupSpec withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]] error:nil];
        __block NSString *soupTableName;
        [store.storeQueue inDatabase:^(FMDatabase *db) {
            soupTableName = [store tableNameForSoup:kSSExternalStorage_TestSoupName withDb:db];
        }];
        
        // Insert entries
        for (NSUInteger i = 0; i < iterations; i++) {
            NSDictionary *entry = @{@"name": [NSString stringWithFormat:@"somebody_%lu", (unsigned long) i]};
            [store upsertEntries:@[entry] toSoup:kSSExternalStorage_TestSoupName];
        }
        
        // Check if entries are in DB
        SFQuerySpec *query = [SFQuerySpec newAllQuerySpec:kSSExternalStorage_TestSoupName
                                                 withOrderPath:nil
                                                withOrder:kSFSoupQuerySortOrderAscending
                                             withPageSize:iterations];
        NSArray *entriesInserted = [store queryWithQuerySpec:query
                                                   pageIndex:0
                                                       error:nil];
        XCTAssertEqual(entriesInserted.count, iterations, @"Did not insert all entries.");
        
        // Check if external files exist
        for (NSDictionary *savedEntry in entriesInserted) {
            NSString *externalEntryFilePath = [store externalStorageSoupFilePath:savedEntry[SOUP_ENTRY_ID]
                                                                   soupTableName:soupTableName];
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:externalEntryFilePath];
            XCTAssertTrue(fileExists, @"External file of a saved entry does not exists.");
        }
    }
}

- (void)testUpdateEntryWithExternalStorage {
    NSUInteger const iterations = 10;
    SFSoupSpec *soupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:@[kSoupFeatureExternalStorage]];
    NSDictionary* soupIndex = @{@"path": @"name", @"type": @"string"};
    
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        [store registerSoupWithSpec:soupSpec withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]] error:nil];
        __block NSString *soupTableName;
        [store.storeQueue inDatabase:^(FMDatabase *db) {
            soupTableName = [store tableNameForSoup:kSSExternalStorage_TestSoupName withDb:db];
        }];
        NSDictionary *entry = @{@"name": @"somebody"};
        NSArray *savedEntries = [store upsertEntries:@[entry] toSoup:kSSExternalStorage_TestSoupName];
        NSMutableDictionary *savedEntry = [savedEntries[0] mutableCopy];
        
        // Update
        for (NSUInteger i = 0; i < iterations; i++) {
            savedEntry[@"name"] = [NSString stringWithFormat:@"somebody_%lu", (unsigned long) i];
            [store upsertEntries:@[savedEntry] toSoup:kSSExternalStorage_TestSoupName];
        }
        
        // Check update
        SFQuerySpec *query = [SFQuerySpec newAllQuerySpec:kSSExternalStorage_TestSoupName
                                                 withOrderPath:nil
                                                withOrder:kSFSoupQuerySortOrderAscending
                                             withPageSize:iterations];
        NSArray *entriesInDb = [store queryWithQuerySpec:query
                                               pageIndex:0
                                                   error:nil];
        NSDictionary *finalEntry = entriesInDb[0];
        XCTAssertEqual(entriesInDb.count, 1, @"There should only be one entry.");
        XCTAssertEqualObjects(savedEntry[@"name"], finalEntry[@"name"], @"Final entry in database is not the same last upserted.");
        
        // Check if only one external file exists
        NSString *externalSoupDir = [store externalStorageSoupDirectory:soupTableName];
        NSArray *contentsOfDir = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:externalSoupDir error:nil];
        XCTAssertEqual(contentsOfDir.count, 1, @"There should be only 1 external soup file saved.");
    }
}

- (void)testRetrieveEntriesWithExternalStorage {
    NSUInteger const numberOfEntries = 10;
    SFSoupSpec *soupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:@[kSoupFeatureExternalStorage]];
    NSDictionary* soupIndex = @{@"path": @"name", @"type": @"string"};
    
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        [store registerSoupWithSpec:soupSpec withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]] error:nil];
        
        // Insert entries
        NSMutableArray *entriesToInsert = [[NSMutableArray alloc] initWithCapacity:numberOfEntries];
        for (NSUInteger i = 0; i < numberOfEntries; i++) {
            NSDictionary *entry = @{@"name": [NSString stringWithFormat:@"somebody_%lu", (unsigned long) i]};
            [entriesToInsert addObject:entry];
        }
        NSArray *savedEntries = [store upsertEntries:entriesToInsert toSoup:kSSExternalStorage_TestSoupName];
        XCTAssertEqual(savedEntries.count, numberOfEntries, @"Upsert failed.");
        
        // Retrieve
        NSArray *retrievedEntries = [store retrieveEntries:[self entriesIdFromEntries:savedEntries]
                                                  fromSoup:kSSExternalStorage_TestSoupName];
        XCTAssertEqualObjects(retrievedEntries, savedEntries, @"Retrieve entries failed.");
    }
}

- (void)testRemoveEntryWithExternalStorage {
    NSUInteger const iterations = 10;
    SFSoupSpec *soupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:@[kSoupFeatureExternalStorage]];
    NSDictionary* soupIndex = @{@"path": @"name", @"type": @"string"};
    
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        [store registerSoupWithSpec:soupSpec withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]] error:nil];
        __block NSString *soupTableName;
        [store.storeQueue inDatabase:^(FMDatabase *db) {
            soupTableName = [store tableNameForSoup:kSSExternalStorage_TestSoupName withDb:db];
        }];
        
        for (NSUInteger i = 0; i < iterations; i++) {
            // Insert
            NSDictionary *entry = @{@"name": [NSString stringWithFormat:@"somebody_%lu", (unsigned long) i]};
            NSArray *savedEntries = [store upsertEntries:@[entry] toSoup:kSSExternalStorage_TestSoupName];
            XCTAssertEqual(savedEntries.count, 1, @"Upsert failed");
            NSDictionary *savedEntry = savedEntries[0];
            
            // Delete
            [store removeEntries:@[savedEntry[SOUP_ENTRY_ID]] fromSoup:kSSExternalStorage_TestSoupName];
            XCTAssertEqual([store retrieveEntries:savedEntries fromSoup:kSSExternalStorage_TestSoupName].count, 0, @"Did not clear entries");
            
            // Check if external file was deleted
            NSString *externalEntryFilePath = [store externalStorageSoupFilePath:savedEntry[SOUP_ENTRY_ID]
                                                                   soupTableName:soupTableName];
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:externalEntryFilePath];
            XCTAssertFalse(fileExists, @"External file of a deleted entry still exists.");
        }
    }
}

- (void)testClearSoupWithExternalStorage {
    NSUInteger const entriesToInsert = 10;
    SFSoupSpec *soupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:@[kSoupFeatureExternalStorage]];
    NSDictionary* soupIndex = @{@"path": @"name", @"type": @"string"};
    
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        [store registerSoupWithSpec:soupSpec withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]] error:nil];
        __block NSString *soupTableName;
        [store.storeQueue inDatabase:^(FMDatabase *db) {
            soupTableName = [store tableNameForSoup:kSSExternalStorage_TestSoupName withDb:db];
        }];
        
        // Insert
        for (NSUInteger i = 0; i < entriesToInsert; ++i) {
            NSDictionary *entry = @{@"name": [NSString stringWithFormat:@"somebody_%lu", (unsigned long) i]};
            [store upsertEntries:@[entry] toSoup:kSSExternalStorage_TestSoupName];
        }
        
        // Verify entries are inserted
        SFQuerySpec *query = [SFQuerySpec newAllQuerySpec:kSSExternalStorage_TestSoupName
                                            withOrderPath:nil
                                                withOrder:kSFSoupQuerySortOrderAscending
                                             withPageSize:entriesToInsert];
        NSArray *entriesInDb = [store queryWithQuerySpec:query
                                               pageIndex:0
                                                   error:nil];
        XCTAssertEqual(entriesInDb.count, entriesToInsert, @"Did not insert all entries.");
        
        // Clear soup
        [store clearSoup:kSSExternalStorage_TestSoupName];
        
        // Verify db is cleared
        entriesInDb = [store queryWithQuerySpec:query
                                      pageIndex:0
                                          error:nil];
        XCTAssertEqual(entriesInDb.count, 0, @"Did not clear all entries.");
        
        // Verify external soup dir is cleared
        NSString *externalSoupDir = [store externalStorageSoupDirectory:soupTableName];
        NSArray *contentsOfDir = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:externalSoupDir error:nil];
        XCTAssertEqual(contentsOfDir.count, 0, @"External soup dir did not delete all external soup files.");
    }
}

- (void)testAlterSoupInternalExternalConversion {
    NSUInteger const numberOfEntries = 10;
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // Internal storage first
        SFSoupSpec *internalStorageSoupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:nil];
        NSDictionary* nameIndex = @{@"path": @"name", @"type": @"string"};
        [store registerSoupWithSpec:internalStorageSoupSpec withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[nameIndex]] error:nil];
        __block NSString *soupTableName;
        [store.storeQueue inDatabase:^(FMDatabase *db) {
            soupTableName = [store tableNameForSoup:kSSExternalStorage_TestSoupName withDb:db];
        }];
        
        // Insert a few entries
        NSMutableArray *entriesToInsert = [[NSMutableArray alloc] initWithCapacity:numberOfEntries];
        for (NSUInteger i = 0; i < numberOfEntries; ++i) {
            NSDictionary *entry = @{@"name": [NSString stringWithFormat:@"somebody_%lu", (unsigned long) i],
                                    @"age": @(i)};
            [entriesToInsert addObject:entry];
        }
        NSArray *savedEntries = [store upsertEntries:entriesToInsert toSoup:kSSExternalStorage_TestSoupName];
        
        // Get current indices
        NSArray *indicesBefore = [store indicesForSoup:kSSExternalStorage_TestSoupName];
        XCTAssertEqual(indicesBefore.count, 1, @"Number of indices initially is not correct.");
        SFSoupIndex *firstIndex = indicesBefore[0];
        XCTAssertEqualObjects(firstIndex.path, nameIndex[@"path"]);
        XCTAssertEqualObjects(firstIndex.indexType, nameIndex[@"type"]);
        
        // Alter and Re-index
        SFSoupSpec *externalStorageSoupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:@[kSoupFeatureExternalStorage]];
        NSDictionary *ageIndex = @{@"path": @"age", @"type": @"integer"};
        [store alterSoup:kSSExternalStorage_TestSoupName
            withSoupSpec:externalStorageSoupSpec
          withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[nameIndex, ageIndex]]
             reIndexData:YES];
        
        // Verify external files are there
        NSString *externalSoupDir = [store externalStorageSoupDirectory:soupTableName];
        NSArray *contentsOfDir = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:externalSoupDir error:nil];
        XCTAssertEqual(contentsOfDir.count, numberOfEntries, @"Not all entries were saved externaly when converting from internal to external storage.");
        
        // Verify entries can be retrieved and are equal
        NSArray *entriesAfterAlterSoup = [store retrieveEntries:[self entriesIdFromEntries:savedEntries]
                                                       fromSoup:kSSExternalStorage_TestSoupName];
        XCTAssertEqualObjects(savedEntries, entriesAfterAlterSoup, @"Entries after alter soup are not the equal to prior alter soup.");
        
        // Get new indices and check
        NSArray *indicesAfter = [store indicesForSoup:kSSExternalStorage_TestSoupName];
        XCTAssertEqual(indicesAfter.count, 2, @"Number of indices after alter soup is not correct.");
        for (SFSoupIndex *index in indicesAfter) {
            if ([index.path isEqualToString:nameIndex[@"path"]]) {
                XCTAssertEqualObjects(index.path, nameIndex[@"path"]);
                XCTAssertEqualObjects(index.indexType, nameIndex[@"type"]);
            }
            else if ([index.path isEqualToString:ageIndex[@"path"]]) {
                XCTAssertEqualObjects(index.path, ageIndex[@"path"]);
                XCTAssertEqualObjects(index.indexType, ageIndex[@"type"]);
            }
        }
        
        XCTAssertNotEqualObjects(indicesBefore, indicesAfter, @"Alter and/or re-index failed!");
    }
}

- (void)testAlterSoupExternalInternalConversion {
    NSUInteger const numberOfEntries = 10;
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        // External storage first
        SFSoupSpec *externalStorageSoupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:@[kSoupFeatureExternalStorage]];
        NSDictionary* nameIndex = @{@"path": @"name", @"type": @"string"};
        [store registerSoupWithSpec:externalStorageSoupSpec withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[nameIndex]] error:nil];
        __block NSString *soupTableName;
        [store.storeQueue inDatabase:^(FMDatabase *db) {
            soupTableName = [store tableNameForSoup:kSSExternalStorage_TestSoupName withDb:db];
        }];
        
        // Insert a few entries
        NSMutableArray *entriesToInsert = [[NSMutableArray alloc] initWithCapacity:numberOfEntries];
        for (NSUInteger i = 0; i < numberOfEntries; ++i) {
            NSDictionary *entry = @{@"name": [NSString stringWithFormat:@"somebody_%lu", (unsigned long) i],
                                    @"age": @(i)};
            [entriesToInsert addObject:entry];
        }
        NSArray *savedEntries = [store upsertEntries:entriesToInsert toSoup:kSSExternalStorage_TestSoupName];
        
        // Get current indices
        NSArray *indicesBefore = [store indicesForSoup:kSSExternalStorage_TestSoupName];
        XCTAssertEqual(indicesBefore.count, 1, @"Number of indices initially is not correct.");
        SFSoupIndex *firstIndex = indicesBefore[0];
        XCTAssertEqualObjects(firstIndex.path, nameIndex[@"path"]);
        XCTAssertEqualObjects(firstIndex.indexType, nameIndex[@"type"]);
        
        // Alter and Re-index
        SFSoupSpec *internalStorageSoupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:nil];
        NSDictionary *ageIndex = @{@"path": @"age", @"type": @"integer"};
        [store alterSoup:kSSExternalStorage_TestSoupName
            withSoupSpec:internalStorageSoupSpec
          withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[nameIndex, ageIndex]]
             reIndexData:YES];
        
        // Verify external files are not there anymore
        NSString *externalSoupDir = [store externalStorageSoupDirectory:soupTableName];
        NSArray *contentsOfDir = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:externalSoupDir error:nil];
        XCTAssertEqual(contentsOfDir.count, 0, @"External files were not cleaned up on conversion from external to internal storage.");
        
        // Verify entries can be retrieved and are equal
        NSArray *entriesAfterAlterSoup = [store retrieveEntries:[self entriesIdFromEntries:savedEntries]
                                                       fromSoup:kSSExternalStorage_TestSoupName];
        XCTAssertEqualObjects(savedEntries, entriesAfterAlterSoup, @"Entries after alter soup are not the equal to prior alter soup.");
        
        // Get new indices and check
        NSArray *indicesAfter = [store indicesForSoup:kSSExternalStorage_TestSoupName];
        XCTAssertEqual(indicesAfter.count, 2, @"Number of indices after alter soup is not correct.");
        for (SFSoupIndex *index in indicesAfter) {
            if ([index.path isEqualToString:nameIndex[@"path"]]) {
                XCTAssertEqualObjects(index.path, nameIndex[@"path"]);
                XCTAssertEqualObjects(index.indexType, nameIndex[@"type"]);
            }
            else if ([index.path isEqualToString:ageIndex[@"path"]]) {
                XCTAssertEqualObjects(index.path, ageIndex[@"path"]);
                XCTAssertEqualObjects(index.indexType, ageIndex[@"type"]);
            }
        }
        
        XCTAssertNotEqualObjects(indicesBefore, indicesAfter, @"Alter and/or re-index failed!");
    }
}

- (void)testExternalStorageIsEncryptedWhenDbIsEncrypted {
    // Define a key
    NSString *secretKey = @"secretKey";
    SFEncryptionKey *key = [[SFEncryptionKey alloc] initWithData:[secretKey dataUsingEncoding:NSUTF8StringEncoding]
                                            initializationVector:nil];
    [SFSmartStore setEncryptionKeyBlock:^SFEncryptionKey *{
        return key;
    }];
    NSString * const superSecret = @"super secret";
    NSData * const superSecretAsData = [superSecret dataUsingEncoding:NSUTF8StringEncoding];
    
    SFSoupSpec *soupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:@[kSoupFeatureExternalStorage]];
    NSDictionary* nameIndex = @{@"path": @"name", @"type": @"string"};
    
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        [store registerSoupWithSpec:soupSpec withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[nameIndex]] error:nil];
        __block NSString *soupTableName;
        [store.storeQueue inDatabase:^(FMDatabase *db) {
            soupTableName = [store tableNameForSoup:kSSExternalStorage_TestSoupName withDb:db];
        }];
        
        // Insert
        NSDictionary *entry = @{@"name": superSecret};
        NSArray *insertedEntries = [store upsertEntries:@[entry] toSoup:kSSExternalStorage_TestSoupName];
        NSDictionary *savedEntry = insertedEntries[0];
        
        // Load external file as string
        NSString *filePath = [store externalStorageSoupFilePath:savedEntry[SOUP_ENTRY_ID] soupTableName:soupTableName];
        NSData *fileData = [NSData dataWithContentsOfFile:filePath];
        XCTAssertGreaterThan(fileData.length, 0, @"Contents of file may not have loaded correctly.");
        
        // Assert
        NSRange foundRange = [fileData rangeOfData:superSecretAsData
                                           options:0
                                             range:NSMakeRange(0, fileData.length)];
        XCTAssertEqual(foundRange.location, NSNotFound, @"File contains plain text? Enryption failed?");
    }
}

- (void)testExternalStorageIsNotEncryptedWhenDbIsNotEncrypted {
    // Unset encrytpion
    [SFSmartStore setEncryptionKeyBlock:nil];
    NSString * const notReallyASecret = @"there are no secrets";
    NSData * const notReallyASecretAsData = [notReallyASecret dataUsingEncoding:NSUTF8StringEncoding];
    
    SFSoupSpec *soupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:@[kSoupFeatureExternalStorage]];
    NSDictionary* nameIndex = @{@"path": @"name", @"type": @"string"};
    
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        [store registerSoupWithSpec:soupSpec withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[nameIndex]] error:nil];
        __block NSString *soupTableName;
        [store.storeQueue inDatabase:^(FMDatabase *db) {
            soupTableName = [store tableNameForSoup:kSSExternalStorage_TestSoupName withDb:db];
        }];
        
        // Insert
        NSDictionary *entry = @{@"name": notReallyASecret};
        NSArray *insertedEntries = [store upsertEntries:@[entry] toSoup:kSSExternalStorage_TestSoupName];
        NSDictionary *savedEntry = insertedEntries[0];
        
        // Load external file as string
        NSString *filePath = [store externalStorageSoupFilePath:savedEntry[SOUP_ENTRY_ID] soupTableName:soupTableName];
        NSData *fileData = [NSData dataWithContentsOfFile:filePath];
        XCTAssertGreaterThan(fileData.length, 0, @"Contents of file may not have loaded correctly.");
        
        // Assert
        NSRange foundRange = [fileData rangeOfData:notReallyASecretAsData
                                           options:0
                                             range:NSMakeRange(0, fileData.length)];
        XCTAssertNotEqual(foundRange.location, NSNotFound, @"External file should contain plain text, store is not encrypted, neither should be external files.");
    }
}

- (void)testExternalStorageUpsertWithOneMBSizePayloadInRegression {
    NSInteger numberOfIterations = 500;
    SFSoupSpec *soupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:@[kSoupFeatureExternalStorage]];
    NSDictionary* soupIndex = @{@"path": @"name", @"type": @"string"};
    
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        [store registerSoupWithSpec:soupSpec withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]] error:nil];
        __block NSString *soupTableName;
        [store.storeQueue inDatabase:^(FMDatabase *db) {
            soupTableName = [store tableNameForSoup:kSSExternalStorage_TestSoupName withDb:db];
        }];
        
        //create 1 mega byte random payload string
        NSUInteger oneMegaByte = kSSMegaBytePayloadSize * 1;
        NSString *payloadString = [self createRandomPayloadStringOfSize:oneMegaByte];
        
        for (NSUInteger i = 0; i < numberOfIterations; ++i) {
            // Insert
            NSDictionary *entry = @{@"name": payloadString};
            NSArray *insertedEntries = [store upsertEntries:@[entry] toSoup:kSSExternalStorage_TestSoupName];
            NSDictionary *savedEntry = insertedEntries[0];
            
            // Load payload string from external saved file
            NSString *filePath = [store externalStorageSoupFilePath:savedEntry[SOUP_ENTRY_ID] soupTableName:soupTableName];
            NSData *fileData = [NSData dataWithContentsOfFile:filePath];
            NSDictionary* savedEntryDict = [SFJsonUtils objectFromJSONData:fileData];
            NSString *savedPayloadString = [savedEntryDict objectForKey:@"name"];
            
            XCTAssertEqualObjects(savedPayloadString, payloadString, @"Contents of file may not have saved correctly.");
        }
    }
}

- (void)testExternalStorageUpsertWithFiveMBSizePayloadInRegression {
    NSInteger numberOfIterations = 100;
    SFSoupSpec *soupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:@[kSoupFeatureExternalStorage]];
    NSDictionary* soupIndex = @{@"path": @"name", @"type": @"string"};
    
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        [store registerSoupWithSpec:soupSpec withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]] error:nil];
        __block NSString *soupTableName;
        [store.storeQueue inDatabase:^(FMDatabase *db) {
            soupTableName = [store tableNameForSoup:kSSExternalStorage_TestSoupName withDb:db];
        }];
        
        //create 1 mega byte random payload string
        NSUInteger fiveMegaBytes = kSSMegaBytePayloadSize * 5;
        NSString *payloadString = [self createRandomPayloadStringOfSize:fiveMegaBytes];
        
        for (NSUInteger i = 0; i < numberOfIterations; ++i) {
            // Insert
            NSDictionary *entry = @{@"name": payloadString};
            NSArray *insertedEntries = [store upsertEntries:@[entry] toSoup:kSSExternalStorage_TestSoupName];
            NSDictionary *savedEntry = insertedEntries[0];
            
            // Load payload string from external saved file
            NSString *filePath = [store externalStorageSoupFilePath:savedEntry[SOUP_ENTRY_ID] soupTableName:soupTableName];
            NSData *fileData = [NSData dataWithContentsOfFile:filePath];
            NSDictionary* savedEntryDict = [SFJsonUtils objectFromJSONData:fileData];
            NSString *savedPayloadString = [savedEntryDict objectForKey:@"name"];
            
            XCTAssertEqualObjects(savedPayloadString, payloadString, @"Contents of file may not have saved correctly.");
        }
    }
}

- (void)testExternalStorageUpsertWithPayloadSizeIncreasedIncrementally {
    NSInteger numberOfIterations = 25;
    SFSoupSpec *soupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:@[kSoupFeatureExternalStorage]];
    NSDictionary* soupIndex = @{@"path": @"name", @"type": @"string"};
    
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        [store registerSoupWithSpec:soupSpec withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]] error:nil];
        __block NSString *soupTableName;
        [store.storeQueue inDatabase:^(FMDatabase *db) {
            soupTableName = [store tableNameForSoup:kSSExternalStorage_TestSoupName withDb:db];
        }];
        
        for (NSUInteger i = 0; i < numberOfIterations; ++i) {
            NSUInteger megaBytes = kSSMegaBytePayloadSize * (i+1);
            NSString *payloadString = [self createRandomPayloadStringOfSize:megaBytes];
            
            // Insert
            NSDictionary *entry = @{@"name": payloadString};
            NSArray *insertedEntries = [store upsertEntries:@[entry] toSoup:kSSExternalStorage_TestSoupName];
            NSDictionary *savedEntry = insertedEntries[0];
            
            // Load payload string from external saved file
            NSString *filePath = [store externalStorageSoupFilePath:savedEntry[SOUP_ENTRY_ID] soupTableName:soupTableName];
            NSData *fileData = [NSData dataWithContentsOfFile:filePath];
            NSDictionary* savedEntryDict = [SFJsonUtils objectFromJSONData:fileData];
            NSString *savedPayloadString = [savedEntryDict objectForKey:@"name"];
            
            XCTAssertEqualObjects(savedPayloadString, payloadString, @"Contents of file may not have saved correctly.");
        }
    }
}

- (void) testGetExternalFileStorageSizeForSoup {
    NSInteger numberOfIterations = 25;
    SFSoupSpec *soupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:@[kSoupFeatureExternalStorage]];
    NSDictionary* soupIndex = @{@"path": @"name", @"type": @"string"};

    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        [store registerSoupWithSpec:soupSpec withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]] error:nil];
        __block NSString *soupTableName;
        [store.storeQueue inDatabase:^(FMDatabase *db) {
            soupTableName = [store tableNameForSoup:kSSExternalStorage_TestSoupName withDb:db];
        }];
        
        //create 1 mega byte random payload string
        NSUInteger oneMegaByte = kSSMegaBytePayloadSize * 1;
        NSString *payloadString = [self createRandomPayloadStringOfSize:oneMegaByte];
        
        for (NSUInteger i = 0; i < numberOfIterations; ++i) {
            // Insert
            NSDictionary *entry = @{@"name": payloadString};
            [store upsertEntries:@[entry] toSoup:kSSExternalStorage_TestSoupName];
        }
        
        XCTAssertGreaterThanOrEqual([store getExternalFileStorageSizeForSoup:kSSExternalStorage_TestSoupName], kSSMegaBytePayloadSize * numberOfIterations, @"Invalid external file size count returned.");
    }
}

- (void) testGetExternalFilesCountForSoup {
    NSInteger numberOfIterations = 25;
    SFSoupSpec *soupSpec = [SFSoupSpec newSoupSpec:kSSExternalStorage_TestSoupName withFeatures:@[kSoupFeatureExternalStorage]];
    NSDictionary* soupIndex = @{@"path": @"name", @"type": @"string"};
    
    for (SFSmartStore *store in @[ self.store, self.globalStore ]) {
        [store registerSoupWithSpec:soupSpec withIndexSpecs:[SFSoupIndex asArraySoupIndexes:@[soupIndex]] error:nil];
        __block NSString *soupTableName;
        [store.storeQueue inDatabase:^(FMDatabase *db) {
            soupTableName = [store tableNameForSoup:kSSExternalStorage_TestSoupName withDb:db];
        }];
        
        //create 1 mega byte random payload string
        NSUInteger oneMegaByte = kSSMegaBytePayloadSize * 1;
        NSString *payloadString = [self createRandomPayloadStringOfSize:oneMegaByte];
        
        for (NSUInteger i = 0; i < numberOfIterations; ++i) {
            // Insert
            NSDictionary *entry = @{@"name": payloadString};
            [store upsertEntries:@[entry] toSoup:kSSExternalStorage_TestSoupName];
        }
        
        XCTAssertEqual(numberOfIterations, [store getExternalFilesCountForSoup:kSSExternalStorage_TestSoupName], @"Invalid external file size count returned.");
    }
}


#pragma mark - Helpers

- (NSArray *)entriesIdFromEntries:(NSArray *)soupEntries {
    NSMutableArray *ids = [[NSMutableArray alloc] initWithCapacity:soupEntries.count];
    for (NSDictionary *entry in soupEntries) {
        [ids addObject:entry[SOUP_ENTRY_ID]];
    }
    return ids;
}

- (NSString *)createRandomPayloadStringOfSize: (NSInteger) size {
    NSMutableString *payloadString = [NSMutableString stringWithCapacity:size];
    NSInteger alphabetCount = [kSSAlphabets length];
    
    for (NSUInteger i = 0; i < size; i++) {
        u_int32_t r = arc4random() % alphabetCount;
        unichar c = [kSSAlphabets characterAtIndex:r];
        [payloadString appendFormat:@"%C", c];
    }
    
    return payloadString;
}

@end
