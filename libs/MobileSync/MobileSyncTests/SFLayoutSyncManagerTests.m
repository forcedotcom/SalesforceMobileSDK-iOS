/*
 SFLayoutSyncManagerTests.m
 MobileSync
 
 Created by Bharath Hariharan on 5/22/18.
 
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
#import "SFLayoutSyncManager.h"
#import "SFMobileSyncSyncManager.h"
#import <SmartStore/SFQuerySpec.h>

static NSString * const kMedium = @"Medium";
static NSString * const kCompact = @"Compact";
static NSString * const kEdit = @"Edit";
static NSString * const kSoupName = @"sfdcLayouts";
static NSString * const kQuery = @"SELECT {%@:_soup} FROM {%@} WHERE {%@:Id} = '%@-%@-%@-%@-%@'";

@interface SFLayoutSyncManagerTests : SyncManagerTestCase

@property (nonatomic, strong, readwrite) SFLayoutSyncManager *layoutSyncManager;

@end

@implementation SFLayoutSyncManagerTests

- (void)setUp {
    [super setUp];
    self.layoutSyncManager = [SFLayoutSyncManager sharedInstance];
}

- (void)tearDown {
    [SFMobileSyncSyncManager removeSharedInstances];
    [self.layoutSyncManager.smartStore removeAllSoups];
    [SFLayoutSyncManager reset];
    [super tearDown];
}

/**
 * Test for fetching layout in SFSDKFetchModeCacheOnly mode.
 */
- (void)testFetchLayoutInCacheOnlyMode {
    XCTestExpectation *fetchLayoutServerFirst = [self expectationWithDescription:@"fetchLayoutServerFirst"];
    [self.layoutSyncManager fetchLayoutForObjectAPIName:kAccount formFactor:kMedium layoutType:kCompact mode:kEdit recordTypeId:nil syncMode:SFSDKFetchModeServerFirst completionBlock:^(NSString *objectAPIName, NSString *formFactor, NSString *layoutType, NSString *mode, NSString *recordTypeId, SFLayout *layout) {
        [fetchLayoutServerFirst fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    __block NSString *objectAPINameBlock = nil;
    __block NSString *formFactorBlock = nil;
    __block NSString *layoutTypeBlock = nil;
    __block NSString *modeBlock = nil;
    __block NSString *recordTypeIdBlock = nil;
    __block SFLayout *layoutBlock = nil;
    XCTestExpectation *fetchLayoutCacheOnly = [self expectationWithDescription:@"fetchLayoutCacheOnly"];
    [self.layoutSyncManager fetchLayoutForObjectAPIName:kAccount formFactor:kMedium layoutType:kCompact mode:kEdit recordTypeId:nil syncMode:SFSDKFetchModeCacheOnly completionBlock:^(NSString *objectAPIName, NSString *formFactor, NSString *layoutType, NSString *mode, NSString *recordTypeId, SFLayout *layout) {
        objectAPINameBlock = objectAPIName;
        formFactorBlock = formFactor;
        layoutTypeBlock = layoutType;
        modeBlock = mode;
        recordTypeIdBlock = recordTypeId;
        layoutBlock = layout;
        [fetchLayoutCacheOnly fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self validateResult:objectAPINameBlock formFactor:formFactorBlock layoutType:layoutTypeBlock mode:modeBlock recordTypeId:recordTypeIdBlock layout:layoutBlock];
}

/**
 * Test for fetching layout in SFSDKFetchModeCacheFirst mode with a hydrated cache.
 */
- (void)testFetchLayoutInCacheFirstModeWithCacheData {
    XCTestExpectation *fetchLayoutServerFirst = [self expectationWithDescription:@"fetchLayoutServerFirst"];
    [self.layoutSyncManager fetchLayoutForObjectAPIName:kAccount formFactor:kMedium layoutType:kCompact mode:kEdit recordTypeId:nil syncMode:SFSDKFetchModeServerFirst completionBlock:^(NSString *objectAPIName, NSString *formFactor, NSString *layoutType, NSString *mode, NSString *recordTypeId, SFLayout *layout) {
        [fetchLayoutServerFirst fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    __block NSString *objectAPINameBlock = nil;
    __block NSString *formFactorBlock = nil;
    __block NSString *layoutTypeBlock = nil;
    __block NSString *modeBlock = nil;
    __block NSString *recordTypeIdBlock = nil;
    __block SFLayout *layoutBlock = nil;
    XCTestExpectation *fetchLayoutCacheFirst = [self expectationWithDescription:@"fetchLayoutCacheFirst"];
    [self.layoutSyncManager fetchLayoutForObjectAPIName:kAccount formFactor:kMedium layoutType:kCompact mode:kEdit recordTypeId:nil syncMode:SFSDKFetchModeCacheFirst completionBlock:^(NSString *objectAPIName, NSString *formFactor, NSString *layoutType, NSString *mode, NSString *recordTypeId, SFLayout *layout) {
        objectAPINameBlock = objectAPIName;
        formFactorBlock = formFactor;
        layoutTypeBlock = layoutType;
        modeBlock = mode;
        recordTypeIdBlock = recordTypeId;
        layoutBlock = layout;
        [fetchLayoutCacheFirst fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self validateResult:objectAPINameBlock formFactor:formFactorBlock layoutType:layoutTypeBlock mode:modeBlock recordTypeId:recordTypeIdBlock layout:layoutBlock];
}

/**
 * Test for fetching layout in SFSDKFetchModeCacheFirst mode with an empty cache.
 */
- (void)testFetchLayoutInCacheFirstModeWithoutCacheData {
    __block NSString *objectAPINameBlock = nil;
    __block NSString *formFactorBlock = nil;
    __block NSString *layoutTypeBlock = nil;
    __block NSString *modeBlock = nil;
    __block NSString *recordTypeIdBlock = nil;
    __block SFLayout *layoutBlock = nil;
    XCTestExpectation *fetchLayoutCacheFirst = [self expectationWithDescription:@"fetchLayoutCacheFirst"];
    [self.layoutSyncManager fetchLayoutForObjectAPIName:kAccount formFactor:kMedium layoutType:kCompact mode:kEdit recordTypeId:nil syncMode:SFSDKFetchModeCacheFirst completionBlock:^(NSString *objectAPIName, NSString *formFactor, NSString *layoutType, NSString *mode, NSString *recordTypeId, SFLayout *layout) {
        objectAPINameBlock = objectAPIName;
        formFactorBlock = formFactor;
        layoutTypeBlock = layoutType;
        modeBlock = mode;
        recordTypeIdBlock = recordTypeId;
        layoutBlock = layout;
        [fetchLayoutCacheFirst fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self validateResult:objectAPINameBlock formFactor:formFactorBlock layoutType:layoutTypeBlock mode:modeBlock recordTypeId:recordTypeIdBlock layout:layoutBlock];
}

/**
 * Test for fetching layout in SFSDKFetchModeServerFirst mode.
 */
- (void)testFetchLayoutInServerFirstMode {
    __block NSString *objectAPINameBlock = nil;
    __block NSString *formFactorBlock = nil;
    __block NSString *layoutTypeBlock = nil;
    __block NSString *modeBlock = nil;
    __block NSString *recordTypeIdBlock = nil;
    __block SFLayout *layoutBlock = nil;
    XCTestExpectation *fetchLayoutServerFirst = [self expectationWithDescription:@"fetchLayoutServerFirst"];
    [self.layoutSyncManager fetchLayoutForObjectAPIName:kAccount formFactor:kMedium layoutType:kCompact mode:kEdit recordTypeId:nil syncMode:SFSDKFetchModeServerFirst completionBlock:^(NSString *objectAPIName, NSString *formFactor, NSString *layoutType, NSString *mode, NSString *recordTypeId, SFLayout *layout) {
        objectAPINameBlock = objectAPIName;
        formFactorBlock = formFactor;
        layoutTypeBlock = layoutType;
        modeBlock = mode;
        recordTypeIdBlock = recordTypeId;
        layoutBlock = layout;
        [fetchLayoutServerFirst fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self validateResult:objectAPINameBlock formFactor:formFactorBlock layoutType:layoutTypeBlock mode:modeBlock recordTypeId:recordTypeIdBlock layout:layoutBlock];
}

/**
 * Test for fetching layout multiple times and ensuring only 1 row is created.
 */
- (void)testFetchLayoutMultipleTimes {
    __block NSString *objectAPINameBlock = nil;
    __block NSString *formFactorBlock = nil;
    __block NSString *layoutTypeBlock = nil;
    __block NSString *modeBlock = nil;
    __block NSString *recordTypeIdBlock = nil;
    __block SFLayout *layoutBlock = nil;
    XCTestExpectation *fetchLayoutOne = [self expectationWithDescription:@"fetchLayoutOne"];
    [self.layoutSyncManager fetchLayoutForObjectAPIName:kAccount formFactor:kMedium layoutType:kCompact mode:kEdit recordTypeId:nil syncMode:SFSDKFetchModeServerFirst completionBlock:^(NSString *objectAPIName, NSString *formFactor, NSString *layoutType, NSString *mode, NSString *recordTypeId, SFLayout *layout) {
        objectAPINameBlock = objectAPIName;
        formFactorBlock = formFactor;
        layoutTypeBlock = layoutType;
        modeBlock = mode;
        recordTypeIdBlock = recordTypeId;
        layoutBlock = layout;
        [fetchLayoutOne fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self validateResult:objectAPINameBlock formFactor:formFactorBlock layoutType:layoutTypeBlock mode:modeBlock recordTypeId:recordTypeIdBlock layout:layoutBlock];
    XCTestExpectation *fetchLayoutTwo = [self expectationWithDescription:@"fetchLayoutTwo"];
    [self.layoutSyncManager fetchLayoutForObjectAPIName:kAccount formFactor:kMedium layoutType:kCompact mode:kEdit recordTypeId:nil syncMode:SFSDKFetchModeServerFirst completionBlock:^(NSString *objectAPIName, NSString *formFactor, NSString *layoutType, NSString *mode, NSString *recordTypeId, SFLayout *layout) {
        objectAPINameBlock = objectAPIName;
        formFactorBlock = formFactor;
        layoutTypeBlock = layoutType;
        modeBlock = mode;
        recordTypeIdBlock = recordTypeId;
        layoutBlock = layout;
        [fetchLayoutTwo fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    [self validateResult:objectAPINameBlock formFactor:formFactorBlock layoutType:layoutTypeBlock mode:modeBlock recordTypeId:recordTypeIdBlock layout:layoutBlock];
    SFQuerySpec *querySpec = [SFQuerySpec newSmartQuerySpec:[NSString stringWithFormat:kQuery, kSoupName, kSoupName, kSoupName, kAccount, kMedium, kCompact, kEdit, nil] withPageSize:2];
    long numRows = [[self.layoutSyncManager.smartStore countWithQuerySpec:querySpec error:nil] longValue];
    XCTAssertEqual(numRows, 1, "Number of rows should be 1");
}

- (void)validateResult:(NSString *)objectAPIName
            formFactor:(NSString *)formFactor
            layoutType:(NSString *)layoutType
                  mode:(NSString *)mode
          recordTypeId:(NSString *)recordTypeId
                layout:(SFLayout *)layout {
    XCTAssertEqual(objectAPIName, kAccount, @"Object types should match");
    XCTAssertEqualObjects(formFactor, kMedium, @"Form factors should match");
    XCTAssertNotEqualObjects(layout, nil, @"Layout data should not be nil");
    XCTAssertEqualObjects(layout.layoutType, kCompact, @"Layout types should match");
    XCTAssertEqualObjects(mode, kEdit, @"Modes should match");
    XCTAssertNotEqualObjects(layout.rawData, nil, @"Layout raw data should not be nil");
    XCTAssertNotEqualObjects(layout.sections, nil, @"Layout sections should not be nil");
    XCTAssertTrue(layout.sections.count > 0, @"Number of layout sections should be 1 or more");
    XCTAssertNotEqualObjects(layout.sections[0].layoutRows, nil, @"Layout rows for a section should not be nil");
    XCTAssertTrue(layout.sections[0].layoutRows.count > 0, @"Number of layout rows for a section should be 1 or more");
    XCTAssertNotEqualObjects(layout.sections[0].layoutRows[0].layoutItems, nil, @"Layout items for a row should not be nil");
    XCTAssertTrue(layout.sections[0].layoutRows[0].layoutItems.count > 0, @"Number of layout items for a row should be 1 or more");
    SFItem *layoutItem = layout.sections[0].layoutRows[0].layoutItems[0];
    XCTAssertFalse(layoutItem.sortable, @"Sortable should be false");
    XCTAssertTrue(layoutItem.editableForNew, @"Editable should be true");
    XCTAssert(layoutItem.layoutComponents.count > 0, "Number of layout components for an item should be 1 or more");
    XCTAssert(layoutItem.layoutComponents[0].allKeys.count > 1, "Layout component fields should be 2 or more");
}

@end
