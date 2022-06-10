/*
 Copyright (c) 2022-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSyncUpdateCallbackQueue.h"
#import "SyncUpTargetTests.h"
#import "TestSyncUpTarget.h"

@interface CollectionSyncUpTargetTests : SyncUpTargetTests {
}

@end

@implementation CollectionSyncUpTargetTests

#pragma mark - Tests

- (void) testMaxBatchSizeExceedingLimit {
    SFCollectionSyncUpTarget* target = [[SFCollectionSyncUpTarget alloc] initWithCreateFieldlist:nil updateFieldlist:nil maxBatchSize:@201];
    XCTAssertEqual(target.maxBatchSize, 200, @"Max batch size should be 200");
}

- (void) testMaxBatchSizeExceedingLimitInDict {
    NSDictionary* targetDict = @{kSFSyncTargetiOSImplKey: @"SFCollectionSyncUpTarget", @"maxBatchSize": @201};
    SFCollectionSyncUpTarget* target = [SFCollectionSyncUpTarget newFromDict:targetDict];
    XCTAssertEqual(target.maxBatchSize, 200, @"Max batch size should be 200");
}

- (void) testConstructors {
    SFCollectionSyncUpTarget* target = [[SFCollectionSyncUpTarget alloc] init];
    XCTAssertNil(target.createFieldlist, @"Wrong createFieldlist");
    XCTAssertNil(target.updateFieldlist, @"Wrong updateFieldlist");
    XCTAssertEqual(target.maxBatchSize, 200, @"Max batch size should be 200");

    target = [[SFCollectionSyncUpTarget alloc] initWithCreateFieldlist:@[@"Name"] updateFieldlist:@[@"Name", @"Description"]];
    XCTAssertEqual(target.createFieldlist.count, 1, @"Wrong createFieldlist");
    XCTAssertEqualObjects(target.createFieldlist[0], @"Name", @"Wrong createFieldlist");
    XCTAssertEqual(target.updateFieldlist.count, 2, @"Wrong updateFieldlist");
    XCTAssertEqualObjects(target.updateFieldlist[0], @"Name", @"Wrong updateFieldlist");
    XCTAssertEqualObjects(target.updateFieldlist[1], @"Description", @"Wrong updateFieldlist");
    XCTAssertEqual(target.maxBatchSize, 200, @"Max batch size should be 200");

    target = [[SFCollectionSyncUpTarget alloc] initWithCreateFieldlist:@[@"Name"] updateFieldlist:@[@"Name", @"Description"] maxBatchSize:@12];
    XCTAssertEqual(target.createFieldlist.count, 1, @"Wrong createFieldlist");
    XCTAssertEqualObjects(target.createFieldlist[0], @"Name", @"Wrong createFieldlist");
    XCTAssertEqual(target.updateFieldlist.count, 2, @"Wrong updateFieldlist");
    XCTAssertEqualObjects(target.updateFieldlist[0], @"Name", @"Wrong updateFieldlist");
    XCTAssertEqualObjects(target.updateFieldlist[1], @"Description", @"Wrong updateFieldlist");
    XCTAssertEqual(target.maxBatchSize, 12, @"Max batch size should be 12");
}


- (void) testFactoryMethodWithDict {
    NSDictionary* targetDict = @{@"createFieldlist": @[@"Name"],
                                 @"updateFieldlist": @[@"Name", @"Description"],
                                 @"maxBatchSize": @12,
                                 kSFSyncTargetiOSImplKey: @"SFCollectionSyncUpTarget"};
    SFCollectionSyncUpTarget* target = [SFCollectionSyncUpTarget newFromDict:targetDict];

    XCTAssertEqual(target.createFieldlist.count, 1, @"Wrong createFieldlist");
    XCTAssertEqualObjects(target.createFieldlist[0], @"Name", @"Wrong createFieldlist");
    XCTAssertEqual(target.updateFieldlist.count, 2, @"Wrong updateFieldlist");
    XCTAssertEqualObjects(target.updateFieldlist[0], @"Name", @"Wrong updateFieldlist");
    XCTAssertEqualObjects(target.updateFieldlist[1], @"Description", @"Wrong updateFieldlist");
    XCTAssertEqual(target.maxBatchSize, 12, @"Max batch size should be 12");
}

- (void) testFactoryMethodWithDictWithOptionalFields {
    NSDictionary* targetDict = @{kSFSyncTargetiOSImplKey: @"SFCollectionSyncUpTarget"};
    SFCollectionSyncUpTarget* target = [SFCollectionSyncUpTarget newFromDict:targetDict];
    
    XCTAssertNil(target.createFieldlist, @"Wrong createFieldlist");
    XCTAssertNil(target.updateFieldlist, @"Wrong createFieldlist");
    XCTAssertEqual(target.maxBatchSize, 200, @"Max batch size should be 200");
}


- (void) testAsDict {
    SFCollectionSyncUpTarget* target = [[SFCollectionSyncUpTarget alloc] initWithCreateFieldlist:@[@"Name"] updateFieldlist:@[@"Name", @"Description"] maxBatchSize:@12];
    NSDictionary* actualTargetDict = [target asDict];


    XCTAssertEqualObjects(actualTargetDict[kSFSyncTargetiOSImplKey], @"SFCollectionSyncUpTarget", @"Wrong ios impl");
    XCTAssertEqualObjects(actualTargetDict[kSFSyncTargetIdFieldNameKey], kId, @"Wrong id field name");
    XCTAssertEqualObjects(actualTargetDict[kSFSyncTargetModificationDateFieldNameKey], kLastModifiedDate, @"Wrong id field name");
    XCTAssertEqual([actualTargetDict[@"createFieldlist"] count], 1, @"Wrong createFieldlist");
    XCTAssertEqualObjects(actualTargetDict[@"createFieldlist"][0], @"Name", @"Wrong createFieldlist");
    XCTAssertEqual([actualTargetDict[@"updateFieldlist"] count], 2, @"Wrong updateFieldlist");
    XCTAssertEqualObjects(actualTargetDict[@"updateFieldlist"][0], @"Name", @"Wrong updateFieldlist");
    XCTAssertEqualObjects(actualTargetDict[@"updateFieldlist"][1], @"Description", @"Wrong updateFieldlist");
    XCTAssertEqualObjects(actualTargetDict[@"maxBatchSize"], @12, @"Wrong max batch size");

}

/**
 * Test serialization and deserialization of SFSyncUpTargets to and from NSDictionary objects.
 */
- (void)testSyncUpTargetSerialization {
    
    // Basic sync up target should be the base class.
    SFSyncUpTarget *basicSyncUpTarget = [[SFSyncUpTarget alloc] init];
    XCTAssertEqual([basicSyncUpTarget class], [SFSyncUpTarget class], @"Class should be SFSyncUpTarget");
    XCTAssertEqual(basicSyncUpTarget.targetType, SFSyncUpTargetTypeRestStandard, @"Sync sync up target type is incorrect.");
    
    // Default sync up target should be the SFCollectionSyncUpTarget
    SFSyncUpTarget *defaultSyncUpTarget = [SFSyncUpTarget newFromDict:nil];
    XCTAssertEqual([defaultSyncUpTarget class], [SFCollectionSyncUpTarget class], @"Default class should be SFCollectionSyncUpTarget");
    XCTAssertEqual(defaultSyncUpTarget.targetType, SFSyncUpTargetTypeRestStandard, @"Sync sync up target type is incorrect.");
    
    // Another way of getting the default sync up target
    SFSyncOptions *options = [SFSyncOptions newSyncOptionsForSyncUp:@[NAME, DESCRIPTION] mergeMode:SFSyncStateMergeModeOverwrite];
    SFSyncState *syncUpState = [SFSyncState newSyncUpWithOptions:options soupName:ACCOUNTS_SOUP store:self.store];
    XCTAssertEqual([syncUpState.target class], [SFCollectionSyncUpTarget class], @"Default sync up target should be SFCollectionSyncUpTarget");
    
    // Explicit rest sync up target type creates base class.
    NSDictionary *restDict = @{ kSFSyncTargetTypeKey: @"rest" };
    SFSyncUpTarget *resttarget = [SFSyncUpTarget newFromDict:restDict];
    XCTAssertEqual([resttarget class], [SFCollectionSyncUpTarget class], @"Rest class should be SFCollectionSyncUpTarget");
    XCTAssertEqual(resttarget.targetType, SFSyncUpTargetTypeRestStandard, @"Sync sync up target type is incorrect.");
    
    // Custom sync up target
    TestSyncUpTarget *customTarget = [[TestSyncUpTarget alloc] init];
    NSDictionary *customDict = [customTarget asDict];
    XCTAssertEqualObjects(customDict[kSFSyncTargetiOSImplKey], NSStringFromClass([TestSyncUpTarget class]), @"Custom class is incorrect.");
    SFSyncUpTarget *customTargetFromDict = [SFSyncUpTarget newFromDict:customDict];
    XCTAssertEqual([customTargetFromDict class], [TestSyncUpTarget class], @"Custom class is incorrect.");
}


#pragma mark - THE methods responsible for building sync up targets used in all the tests

- (SFSyncUpTarget*) buildSyncUpTargetWithCreateFieldlist:(nullable NSArray*)createFieldlist updateFieldlist:(nullable NSArray*)updateFieldlist {
    return [[SFCollectionSyncUpTarget alloc] initWithCreateFieldlist:createFieldlist updateFieldlist:updateFieldlist];
}

@end
