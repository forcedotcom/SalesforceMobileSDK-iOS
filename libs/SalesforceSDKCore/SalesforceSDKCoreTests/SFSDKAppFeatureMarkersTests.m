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
#import "SFUserAccount.h"
#import "SFOAuthCredentials.h"
#import "SFOAuthCredentials+Internal.h"

@interface SFSDKAppFeatureMarkersTests : XCTestCase

@property (nonatomic, strong) NSMutableSet<NSString *> *existingMarkers;
@property (nonatomic, strong) SFUserAccount *userA;
@property (nonatomic, strong) SFUserAccount *userB;

@end

@implementation SFSDKAppFeatureMarkersTests

- (void)setUp {
    [super setUp];
    self.existingMarkers = [NSMutableSet set];
    [self persistExistingMarkers];
    [self clearExistingMarkers];
    self.userA = [self fakeUserWithOrgId:@"org1" userId:@"user1" credentialsIdentifier:@"test-creds-A"];
    self.userB = [self fakeUserWithOrgId:@"org2" userId:@"user2" credentialsIdentifier:@"test-creds-B"];
}

- (void)tearDown {
    [SFSDKAppFeatureMarkers unregisterAppFeature:@"XY" forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:@"XY" forUser:self.userB];
    [SFSDKAppFeatureMarkers unregisterAppFeature:@"GL" forUser:nil];
    [SFSDKAppFeatureMarkers unregisterAppFeature:@"PU" forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:@"NL" forUser:nil];
    [SFSDKAppFeatureMarkers unregisterAppFeature:@"RM" forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:@"HY" forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:@"PS" forUser:self.userA];
    self.userA = nil;
    self.userB = nil;
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

#pragma mark - Per-user feature flag tests

- (void)test_givenTwoUsers_whenRegisterFeatureForUserA_thenOnlyUserAHasFlag {
    [SFSDKAppFeatureMarkers registerAppFeature:@"XY" forUser:self.userA];

    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:@"XY"],
                  @"userA should have feature XY");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userB] containsObject:@"XY"],
                   @"userB should NOT have feature XY");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:@"XY"],
                   @"Global set should NOT contain per-user feature XY");
}

- (void)test_givenGlobalAndPerUserFlags_whenAppFeaturesForUser_thenUnionReturned {
    [SFSDKAppFeatureMarkers registerAppFeature:@"GL"];
    [SFSDKAppFeatureMarkers registerAppFeature:@"PU" forUser:self.userA];

    NSSet<NSString *> *featuresForA = [SFSDKAppFeatureMarkers appFeaturesForUser:self.userA];
    XCTAssertTrue([featuresForA containsObject:@"GL"],
                  @"appFeaturesForUser:userA should include global feature GL");
    XCTAssertTrue([featuresForA containsObject:@"PU"],
                  @"appFeaturesForUser:userA should include per-user feature PU");

    NSSet<NSString *> *featuresForB = [SFSDKAppFeatureMarkers appFeaturesForUser:self.userB];
    XCTAssertTrue([featuresForB containsObject:@"GL"],
                  @"appFeaturesForUser:userB should include global feature GL");
    XCTAssertFalse([featuresForB containsObject:@"PU"],
                   @"appFeaturesForUser:userB should NOT include userA's per-user feature PU");
}

- (void)test_givenNilUser_whenRegisterForUser_thenFlagGoesToGlobalSet {
    [SFSDKAppFeatureMarkers registerAppFeature:@"NL" forUser:nil];

    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeatures] containsObject:@"NL"],
                  @"Registering with nil user should fall back to global set");
}

- (void)test_givenUserWithFlag_whenUnregisterForUser_thenFlagRemovedFromUser {
    // Register RM only per-user for userA; do not add to global set
    [SFSDKAppFeatureMarkers registerAppFeature:@"RM" forUser:self.userA];
    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:@"RM"],
                  @"Feature RM should be present for userA before unregister");

    [SFSDKAppFeatureMarkers unregisterAppFeature:@"RM" forUser:self.userA];

    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:@"RM"],
                   @"Feature RM should be removed from userA after per-user unregister");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:@"RM"],
                  @"Global set should not contain RM (it was never registered globally)");
}

- (void)test_givenLoadPersistedFeatures_whenAppFeaturesForUser_thenFlagsPresent {
    [SFSDKAppFeatureMarkers loadPersistedFeatures:[NSSet setWithObject:@"HY"] forUser:self.userA];

    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:@"HY"],
                  @"Hydrated feature HY should be visible via appFeaturesForUser:");
    XCTAssertFalse([self.userA.persistedFeatureFlags containsObject:@"HY"],
                   @"loadPersistedFeatures: should NOT write back to persistedFeatureFlags");
}

- (void)test_givenPersistedFlagsOnUser_whenRegisterForUser_thenPersistedFlagsUpdated {
    [SFSDKAppFeatureMarkers registerAppFeature:@"PS" forUser:self.userA];

    XCTAssertTrue([self.userA.persistedFeatureFlags containsObject:@"PS"],
                  @"registerAppFeature:forUser: should save PS to user.persistedFeatureFlags");
}

- (void)test_givenNilUser_whenAppFeaturesForUser_thenReturnsGlobalSet {
    [SFSDKAppFeatureMarkers registerAppFeature:@"GL"];
    [SFSDKAppFeatureMarkers registerAppFeature:@"PU" forUser:self.userA];

    NSSet<NSString *> *forNil = [SFSDKAppFeatureMarkers appFeaturesForUser:nil];
    NSSet<NSString *> *global = [SFSDKAppFeatureMarkers appFeatures];

    XCTAssertEqualObjects(forNil, global,
                          @"appFeaturesForUser:nil should be identical to appFeatures");
    XCTAssertFalse([forNil containsObject:@"PU"],
                   @"appFeaturesForUser:nil should not include per-user features");
}

- (void)test_givenPersistedFlagsOnUser_whenUnregisterForUser_thenPersistedFlagsUpdated {
    [SFSDKAppFeatureMarkers registerAppFeature:@"RM" forUser:self.userA];
    XCTAssertTrue([self.userA.persistedFeatureFlags containsObject:@"RM"],
                  @"Precondition: RM should be in persistedFeatureFlags after register");

    [SFSDKAppFeatureMarkers unregisterAppFeature:@"RM" forUser:self.userA];

    XCTAssertFalse([self.userA.persistedFeatureFlags containsObject:@"RM"],
                   @"unregisterAppFeature:forUser: should remove RM from user.persistedFeatureFlags");
}

#pragma mark - Private helpers

- (SFUserAccount *)fakeUserWithOrgId:(NSString *)orgId userId:(NSString *)userId credentialsIdentifier:(NSString *)identifier {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:identifier
                                                                             clientId:@"fakeClientIdForTesting"
                                                                            encrypted:NO];
    credentials.organizationId = orgId;
    credentials.userId = userId;
    SFUserAccount *user = [[SFUserAccount alloc] initWithCredentials:credentials];
    return user;
}

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
