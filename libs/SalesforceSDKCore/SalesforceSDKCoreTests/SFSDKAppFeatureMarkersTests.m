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

#import <XCTest/XCTest.h>
#import "SFSDKAppFeatureMarkers.h"

@interface SFSDKAppFeatureMarkersTests : XCTestCase

@property (nonatomic, strong) NSMutableSet<NSString *> *existingMarkers;

@end

@implementation SFSDKAppFeatureMarkersTests

- (void)setUp {
    [super setUp];
    self.existingMarkers = [NSMutableSet set];
    [self persistExistingMarkers];
    [self clearExistingMarkers];
}

- (void)tearDown {
    [self clearExistingMarkers];
    [self resetPreviousMarkers];
    self.existingMarkers = [NSMutableSet set];
    [super tearDown];
}

- (void)testNoDuplicates {
    NSString *someFeature = @"BlahNoDuplicates";
    [SFSDKAppFeatureMarkers registerAppFeature:someFeature];
    XCTAssert([SFSDKAppFeatureMarkers appFeatures].count == 1, @"Failed to add feature '%@'", someFeature);
    [SFSDKAppFeatureMarkers registerAppFeature:someFeature];
    XCTAssert([SFSDKAppFeatureMarkers appFeatures].count == 1, @"Feature '%@' should only exist once.", someFeature);
}

- (void)testAddAndRemove {
    NSString *someFeature = @"BlahAddAndRemove";
    [SFSDKAppFeatureMarkers registerAppFeature:someFeature];
    XCTAssert([SFSDKAppFeatureMarkers appFeatures].count == 1, @"Failed to add feature '%@'", someFeature);
    [SFSDKAppFeatureMarkers unregisterAppFeature:someFeature];
    XCTAssert([SFSDKAppFeatureMarkers appFeatures].count == 0, @"Failed to unregister feature '%@'", someFeature);
}

- (void)testUnregisterNonExistingNoError {
    NSString *someFeature = @"BlahUnregisterNonExistingNoError";
    [SFSDKAppFeatureMarkers unregisterAppFeature:someFeature];
}

#pragma mark - Private helpers

- (void)persistExistingMarkers {
    for (NSString *marker in [SFSDKAppFeatureMarkers appFeatures]) {
        [self.existingMarkers addObject:marker];
    }
}

- (void)resetPreviousMarkers {
    for (NSString *marker in self.existingMarkers) {
        [SFSDKAppFeatureMarkers registerAppFeature:marker];
    }
    XCTAssert([SFSDKAppFeatureMarkers appFeatures].count == self.existingMarkers.count, @"Failed to re-register previous markers.");
}

- (void)clearExistingMarkers {
    for (NSString *marker in [SFSDKAppFeatureMarkers appFeatures]) {
        [SFSDKAppFeatureMarkers unregisterAppFeature:marker];
    }
    XCTAssert([SFSDKAppFeatureMarkers appFeatures].count == 0, @"Failed to clear app feature markers.");
}

@end
