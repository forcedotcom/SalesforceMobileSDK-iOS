/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKStoreConfigTests.h"
#import <XCTest/XCTest.h>

@interface SFSDKStoreConfigTests ()

@property (nonatomic, strong) SFUserAccount *smartStoreUser;
@property (nonatomic, strong) SFSmartStore *store;
@property (nonatomic, strong) SFSmartStore *globalStore;
@property (nonatomic, strong) SmartStoreSDKManager* sdkManager;

@end

@implementation SFSDKStoreConfigTests

#pragma mark - setup and teardown

- (void) setUp
{
    [super setUp];
    [SFSDKSmartStoreLogger setLogLevel:DDLogLevelDebug];
    self.sdkManager = [[SmartStoreSDKManager alloc] init];
    self.smartStoreUser = [self setUpSmartStoreUser];
    self.store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
    self.globalStore = [SFSmartStore sharedGlobalStoreWithName:kDefaultSmartStoreName];
}

- (void) tearDown
{
    [SFSmartStore removeSharedStoreWithName:kDefaultSmartStoreName];
    [SFSmartStore removeSharedGlobalStoreWithName:kDefaultSmartStoreName];
    [self tearDownSmartStoreUser:self.smartStoreUser];
    [super tearDown];
    
    self.smartStoreUser = nil;
    self.store = nil;
    self.globalStore = nil;
    self.sdkManager = nil;
}

#pragma mark - tests

- (void) testSetupGlobalStoreFromDefaultConfig  {

    XCTAssertFalse([self.globalStore soupExists:@"globalSoup1"]);
    XCTAssertFalse([self.globalStore soupExists:@"globalSoup2"]);

    // Setting up soup
    [self.sdkManager setupGlobalStoreFromDefaultConfig];

    // Checking smartstore
    XCTAssertTrue([self.globalStore soupExists:@"globalSoup1"]);
    XCTAssertTrue([self.globalStore soupExists:@"globalSoup2"]);
    
    NSArray* actualSoupNames = [self.globalStore allSoupNames];
    XCTAssertEqual(actualSoupNames.count, 2);
    XCTAssertTrue([actualSoupNames containsObject:@"globalSoup1"]);
    XCTAssertTrue([actualSoupNames containsObject:@"globalSoup2"]);

    // Checking first soup in details
    NSArray* indexSpecs = [self.globalStore indicesForSoup:@"globalSoup1"];
    XCTAssertEqual(indexSpecs.count, 5);
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[0] expectedPath:@"stringField1" expectedType:kSoupIndexTypeString expectedColumnName:@"TABLE_1_0"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[1] expectedPath:@"integerField1" expectedType:kSoupIndexTypeInteger expectedColumnName:@"TABLE_1_1"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[2] expectedPath:@"floatingField1" expectedType:kSoupIndexTypeFloating expectedColumnName:@"TABLE_1_2"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[3] expectedPath:@"json1Field1" expectedType:kSoupIndexTypeJSON1 expectedColumnName:@"json_extract(soup, '$.json1Field1')"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[4] expectedPath:@"ftsField1" expectedType:kSoupIndexTypeFullText expectedColumnName:@"TABLE_1_4"];
    
    // Checking second soup in details
    indexSpecs = [self.globalStore indicesForSoup:@"globalSoup2"];
    XCTAssertEqual(indexSpecs.count, 5);
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[0] expectedPath:@"stringField2" expectedType:kSoupIndexTypeString expectedColumnName:@"TABLE_2_0"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[1] expectedPath:@"integerField2" expectedType:kSoupIndexTypeInteger expectedColumnName:@"TABLE_2_1"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[2] expectedPath:@"floatingField2" expectedType:kSoupIndexTypeFloating expectedColumnName:@"TABLE_2_2"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[3] expectedPath:@"json1Field2" expectedType:kSoupIndexTypeJSON1 expectedColumnName:@"json_extract(soup, '$.json1Field2')"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[4] expectedPath:@"ftsField2" expectedType:kSoupIndexTypeFullText expectedColumnName:@"TABLE_2_4"];
}

- (void) testSetupUserStoreFromDefaultConfig {
    XCTAssertFalse([self.store soupExists:@"userSoup1"]);
    XCTAssertFalse([self.store soupExists:@"userSoup2"]);
    
    // Setting up soup
    [self.sdkManager setupUserStoreFromDefaultConfig];
    
    // Checking smartstore
    XCTAssertTrue([self.store soupExists:@"userSoup1"]);
    XCTAssertTrue([self.store soupExists:@"userSoup2"]);

    NSArray* actualSoupNames = [self.store allSoupNames];
    XCTAssertEqual(actualSoupNames.count, 2);
    XCTAssertTrue([actualSoupNames containsObject:@"userSoup1"]);
    XCTAssertTrue([actualSoupNames containsObject:@"userSoup2"]);
    
    // Checking first soup in details
    NSArray* indexSpecs = [self.store indicesForSoup:@"userSoup1"];
    XCTAssertEqual(indexSpecs.count, 5);
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[0] expectedPath:@"stringField1" expectedType:kSoupIndexTypeString expectedColumnName:@"TABLE_1_0"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[1] expectedPath:@"integerField1" expectedType:kSoupIndexTypeInteger expectedColumnName:@"TABLE_1_1"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[2] expectedPath:@"floatingField1" expectedType:kSoupIndexTypeFloating expectedColumnName:@"TABLE_1_2"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[3] expectedPath:@"json1Field1" expectedType:kSoupIndexTypeJSON1 expectedColumnName:@"json_extract(soup, '$.json1Field1')"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[4] expectedPath:@"ftsField1" expectedType:kSoupIndexTypeFullText expectedColumnName:@"TABLE_1_4"];
    
    // Checking second soup in details
    indexSpecs = [self.store indicesForSoup:@"userSoup2"];
    XCTAssertEqual(indexSpecs.count, 5);
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[0] expectedPath:@"stringField2" expectedType:kSoupIndexTypeString expectedColumnName:@"TABLE_2_0"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[1] expectedPath:@"integerField2" expectedType:kSoupIndexTypeInteger expectedColumnName:@"TABLE_2_1"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[2] expectedPath:@"floatingField2" expectedType:kSoupIndexTypeFloating expectedColumnName:@"TABLE_2_2"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[3] expectedPath:@"json1Field2" expectedType:kSoupIndexTypeJSON1 expectedColumnName:@"json_extract(soup, '$.json1Field2')"];
    [self checkSoupIndex:(SFSoupIndex*)indexSpecs[4] expectedPath:@"ftsField2" expectedType:kSoupIndexTypeFullText expectedColumnName:@"TABLE_2_4"];
}

@end
