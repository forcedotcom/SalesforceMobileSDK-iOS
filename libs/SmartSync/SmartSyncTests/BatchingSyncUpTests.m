/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFBatchingSyncUpTarget.h"
#import "SFSmartSyncObjectUtils.h"
#import "SFSyncUpdateCallbackQueue.h"
#import "SFSmartSyncConstants.h"

@interface BatchingSyncUpTests : SyncManagerTestCase {
}

@end

@implementation BatchingSyncUpTests

#pragma mark - setUp/tearDown

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

#pragma mark - Tests

- (void) testMaxBatchSizeExceeding25 {
    SFBatchingSyncUpTarget* target = [SFBatchingSyncUpTarget newSyncTargetWithCreateFieldlist:nil updateFieldlist:nil maxBatchSize:@26];
    XCTAssertEqual(target.maxBatchSize, 25, @"Max batch size should be 25");
}

- (void) testMaxBatchSizeExceeding25InDict {
    NSDictionary* targetDict = @{kSFSyncTargetiOSImplKey: @"SFBatchingSyncUpTarget", @"maxBatchSize": @26};
    SFBatchingSyncUpTarget* target = [SFBatchingSyncUpTarget newFromDict:targetDict];
    XCTAssertEqual(target.maxBatchSize, 25, @"Max batch size should be 25");
}

- (void) testFactoryMethod {
    SFBatchingSyncUpTarget* target = [SFBatchingSyncUpTarget newSyncTargetWithCreateFieldlist:@[@"Name"] updateFieldlist:@[@"Name", @"Description"] maxBatchSize:@12];

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
                                 kSFSyncTargetiOSImplKey: @"SFBatchingSyncUpTarget"};
    SFBatchingSyncUpTarget* target = [SFBatchingSyncUpTarget newFromDict:targetDict];

    XCTAssertEqual(target.createFieldlist.count, 1, @"Wrong createFieldlist");
    XCTAssertEqualObjects(target.createFieldlist[0], @"Name", @"Wrong createFieldlist");
    XCTAssertEqual(target.updateFieldlist.count, 2, @"Wrong updateFieldlist");
    XCTAssertEqualObjects(target.updateFieldlist[0], @"Name", @"Wrong updateFieldlist");
    XCTAssertEqualObjects(target.updateFieldlist[1], @"Description", @"Wrong updateFieldlist");
    XCTAssertEqual(target.maxBatchSize, 12, @"Max batch size should be 12");
}

- (void) testFactoryMethodWithDictWithOptionalFields {
    NSDictionary* targetDict = @{kSFSyncTargetiOSImplKey: @"SFBatchingSyncUpTarget"};
    SFBatchingSyncUpTarget* target = [SFBatchingSyncUpTarget newFromDict:targetDict];
    
    XCTAssertNil(target.createFieldlist, @"Wrong createFieldlist");
    XCTAssertNil(target.updateFieldlist, @"Wrong createFieldlist");
    XCTAssertEqual(target.maxBatchSize, 25, @"Max batch size should be 25");
}


- (void) testAsDict {
    SFBatchingSyncUpTarget* target = [SFBatchingSyncUpTarget newSyncTargetWithCreateFieldlist:@[@"Name"] updateFieldlist:@[@"Name", @"Description"] maxBatchSize:@12];
    NSDictionary* actualTargetDict = [target asDict];


    XCTAssertEqualObjects(actualTargetDict[kSFSyncTargetiOSImplKey], @"SFBatchingSyncUpTarget", @"Wrong ios impl");
    XCTAssertEqualObjects(actualTargetDict[kSFSyncTargetIdFieldNameKey], kId, @"Wrong id field name");
    XCTAssertEqualObjects(actualTargetDict[kSFSyncTargetModificationDateFieldNameKey], kLastModifiedDate, @"Wrong id field name");
    XCTAssertEqual([actualTargetDict[@"createFieldlist"] count], 1, @"Wrong createFieldlist");
    XCTAssertEqualObjects(actualTargetDict[@"createFieldlist"][0], @"Name", @"Wrong createFieldlist");
    XCTAssertEqual([actualTargetDict[@"updateFieldlist"] count], 2, @"Wrong updateFieldlist");
    XCTAssertEqualObjects(actualTargetDict[@"updateFieldlist"][0], @"Name", @"Wrong updateFieldlist");
    XCTAssertEqualObjects(actualTargetDict[@"updateFieldlist"][1], @"Description", @"Wrong updateFieldlist");
    XCTAssertEqualObjects(actualTargetDict[@"maxBatchSize"], @12, @"Wrong max batch size");

}

@end
