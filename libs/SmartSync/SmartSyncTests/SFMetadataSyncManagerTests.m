/*
 SFMetadataSyncManagerTests.m
 SmartSync
 
 Created by Bharath Hariharan on 5/24/18.
 
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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

#import "SyncManagerTestCase.h"
#import "SFMetadataSyncManager.h"
#import "SFSmartSyncSyncManager.h"
#import <SmartStore/SFQuerySpec.h>

static NSString * const kAccountKeyPrefix = @"001";
static NSString * const kSoupName = @"sfdcMetadata";
static NSString * const kQuery = @"SELECT {%@:_soup} FROM {%@} WHERE {%@:Id} = '%@'";

@interface SFMetadataSyncManagerTests : SyncManagerTestCase

@property (nonatomic, strong, readwrite) SFMetadataSyncManager *metadataSyncManager;

@end

@implementation SFMetadataSyncManagerTests

- (void)setUp {
    [super setUp];
    self.metadataSyncManager = [SFMetadataSyncManager sharedInstance];
}

- (void)tearDown {
    [SFSmartSyncSyncManager removeSharedInstances];
    [self.metadataSyncManager.smartStore removeAllSoups];
    [SFMetadataSyncManager reset];
    [super tearDown];
}

/**
 * Test for fetching metadata in SFSDKFetchModeCacheOnly mode.
 */
- (void)testFetchMetadataInCacheOnlyMode {
    XCTestExpectation *fetchMetadataServerFirst = [self expectationWithDescription:@"fetchMetadataServerFirst"];
    [self.metadataSyncManager fetchMetadataForObject:kAccount mode:SFSDKFetchModeServerFirst completionBlock:^(SFMetadata *metadata) {
        [fetchMetadataServerFirst fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    __block SFMetadata *metadataResult = nil;
    XCTestExpectation *fetchMetadataCacheOnly = [self expectationWithDescription:@"fetchMetadataCacheOnly"];
    [self.metadataSyncManager fetchMetadataForObject:kAccount mode:SFSDKFetchModeCacheOnly completionBlock:^(SFMetadata *metadata) {
        metadataResult = metadata;
        [fetchMetadataCacheOnly fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self validateResult:metadataResult];
}

/**
 * Test for fetching metadata in SFSDKFetchModeCacheFirst mode with a hydrated cache.
 */
- (void)testFetchMetadataInCacheFirstModeWithCacheData {
    XCTestExpectation *fetchMetadataServerFirst = [self expectationWithDescription:@"fetchMetadataServerFirst"];
    [self.metadataSyncManager fetchMetadataForObject:kAccount mode:SFSDKFetchModeServerFirst completionBlock:^(SFMetadata *metadata) {
        [fetchMetadataServerFirst fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    __block SFMetadata *metadataResult = nil;
    XCTestExpectation *fetchMetadataCacheFirst = [self expectationWithDescription:@"fetchMetadataCacheFirst"];
    [self.metadataSyncManager fetchMetadataForObject:kAccount mode:SFSDKFetchModeCacheFirst completionBlock:^(SFMetadata *metadata) {
        metadataResult = metadata;
        [fetchMetadataCacheFirst fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self validateResult:metadataResult];
}

/**
 * Test for fetching metadata in SFSDKFetchModeCacheFirst mode with an empty cache.
 */
- (void)testFetchMetadataInCacheFirstModeWithoutCacheData {
    __block SFMetadata *metadataResult = nil;
    XCTestExpectation *fetchMetadataCacheFirst = [self expectationWithDescription:@"fetchMetadataCacheFirst"];
    [self.metadataSyncManager fetchMetadataForObject:kAccount mode:SFSDKFetchModeCacheFirst completionBlock:^(SFMetadata *metadata) {
        metadataResult = metadata;
        [fetchMetadataCacheFirst fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self validateResult:metadataResult];
}

/**
 * Test for fetching metadata in SFSDKFetchModeServerFirst mode.
 */
- (void)testFetchMetadataInServerFirstMode {
    __block SFMetadata *metadataResult = nil;
    XCTestExpectation *fetchMetadataServerFirst = [self expectationWithDescription:@"fetchMetadataServerFirst"];
    [self.metadataSyncManager fetchMetadataForObject:kAccount mode:SFSDKFetchModeServerFirst completionBlock:^(SFMetadata *metadata) {
        metadataResult = metadata;
        [fetchMetadataServerFirst fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self validateResult:metadataResult];
}

/**
 * Test for fetching metadata multiple times and ensuring only 1 row is created.
 */
- (void)testFetchMetadataMultipleTimes {
    __block SFMetadata *metadataResult = nil;
    XCTestExpectation *fetchMetadataOne = [self expectationWithDescription:@"fetchMetadataOne"];
    [self.metadataSyncManager fetchMetadataForObject:kAccount mode:SFSDKFetchModeServerFirst completionBlock:^(SFMetadata *metadata) {
        metadataResult = metadata;
        [fetchMetadataOne fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self validateResult:metadataResult];
    XCTestExpectation *fetchMetadataTwo = [self expectationWithDescription:@"fetchMetadataTwo"];
    [self.metadataSyncManager fetchMetadataForObject:kAccount mode:SFSDKFetchModeServerFirst completionBlock:^(SFMetadata *metadata) {
        metadataResult = metadata;
        [fetchMetadataTwo fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self validateResult:metadataResult];
    SFQuerySpec *querySpec = [SFQuerySpec newSmartQuerySpec:[NSString stringWithFormat:kQuery, kSoupName, kSoupName, kSoupName, kAccount] withPageSize:2];
    long numRows = [self.metadataSyncManager.smartStore countWithQuerySpec:querySpec error:nil];
    XCTAssertEqual(numRows, 1, "Number of rows should be 1");
}

- (void)validateResult:(SFMetadata *)metadata {
    XCTAssertNotEqualObjects(metadata, nil, @"Metadata should not be nil");
    XCTAssertEqualObjects(metadata.name, kAccount, @"Object types should match");
    XCTAssertNotEqualObjects(metadata.rawData, nil, @"Metadata raw data should not be nil");
    XCTAssertTrue(metadata.compactLayoutable, @"Object should be compact layoutable");
    XCTAssertTrue(metadata.createable, @"Object should be createable");
    XCTAssertNotEqualObjects(metadata.childRelationships, nil, @"Child relationships should not be nil");
    XCTAssertNotEqualObjects(metadata.fields, nil, @"Fields should not be nil");
    XCTAssertNotEqualObjects(metadata.urls, nil, @"URLs should not be nil");
    XCTAssertTrue(metadata.searchable, @"Object should be searchable");
    XCTAssertEqualObjects(metadata.keyPrefix, kAccountKeyPrefix, @"Object key prefixes should match");
    XCTAssertEqualObjects(metadata.label, kAccount, @"Object labels should match");
}

@end
