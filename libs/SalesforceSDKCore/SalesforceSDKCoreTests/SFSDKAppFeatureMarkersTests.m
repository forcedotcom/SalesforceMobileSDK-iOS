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
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureSafariBrowserForLogin forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureWelcomeDiscovery forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureQrCodeLogin forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureRTR forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureDPoP forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation forUser:self.userA];
    NSArray<NSString *> *allAMarkers = @[kSFAppFeatureAuthTypeWebServerNonHybrid,
                                          kSFAppFeatureAuthTypeWebServerHybrid,
                                          kSFAppFeatureAuthTypeUserAgentNonHybrid,
                                          kSFAppFeatureAuthTypeUserAgentHybrid,
                                          kSFAppFeatureAuthTypeNative];
    for (NSString *marker in allAMarkers) {
        [SFSDKAppFeatureMarkers unregisterAppFeature:marker forUser:self.userA];
        [SFSDKAppFeatureMarkers unregisterAppFeature:marker];
    }
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureTokenMigration forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureTokenFormatJwt forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureTokenFormatOpaque forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureBeacon forUser:self.userA];
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

#pragma mark - Auth-completion promotion pattern tests

- (void)test_givenAdvancedBrowserAuth_whenPromoteBW_thenUserHasBWAndGlobalCleared {
    // Simulates: authType == SFOAuthTypeAdvancedBrowser path in auth completion
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureSafariBrowserForLogin];

    // Promotion sequence from auth completion
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureSafariBrowserForLogin forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureSafariBrowserForLogin];

    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureSafariBrowserForLogin],
                  @"BW should be registered per-user after advanced browser auth");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureSafariBrowserForLogin],
                   @"BW should be cleared from global set after promotion");
}

- (void)test_givenNonAdvancedBrowserAuth_whenPromoteBW_thenUserLacksBWAndGlobalCleared {
    // Simulates: authType != SFOAuthTypeAdvancedBrowser path in auth completion
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureSafariBrowserForLogin];

    // Promotion sequence from auth completion (non-advanced path)
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureSafariBrowserForLogin forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureSafariBrowserForLogin];

    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureSafariBrowserForLogin],
                   @"BW should NOT be registered per-user after non-advanced auth");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureSafariBrowserForLogin],
                   @"BW should be cleared from global set regardless of auth type");
}

- (void)test_givenGlobalWDSet_whenPromoteWD_thenUserHasWDAndGlobalCleared {
    // Simulates: WelcomeDiscovery was used globally, authType != refresh
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureWelcomeDiscovery];

    // Promotion sequence from auth completion
    BOOL usedWelcomeDiscovery = [[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureWelcomeDiscovery];
    XCTAssertTrue(usedWelcomeDiscovery, @"Precondition: global WD should be set");

    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureWelcomeDiscovery forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureWelcomeDiscovery];

    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureWelcomeDiscovery],
                  @"WD should be promoted to per-user when global WD was set");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureWelcomeDiscovery],
                   @"WD should be cleared from global set after promotion");
}

- (void)test_givenGlobalWDNotSet_whenPromoteWD_thenUserLacksWDAndGlobalCleared {
    // Simulates: WelcomeDiscovery was NOT used globally, authType != refresh
    // Do NOT register WD globally

    // Promotion sequence from auth completion
    BOOL usedWelcomeDiscovery = [[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureWelcomeDiscovery];
    XCTAssertFalse(usedWelcomeDiscovery, @"Precondition: global WD should NOT be set");

    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureWelcomeDiscovery forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureWelcomeDiscovery];

    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureWelcomeDiscovery],
                   @"WD should NOT be per-user when global WD was not set");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureWelcomeDiscovery],
                   @"Global WD should remain absent");
}

- (void)test_givenGlobalQRSet_whenPromoteQR_thenUserHasQRAndGlobalCleared {
    // Simulates: QR login was used globally, authType != refresh
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureQrCodeLogin];

    // Promotion sequence from auth completion
    BOOL usedQrLogin = [[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureQrCodeLogin];
    XCTAssertTrue(usedQrLogin, @"Precondition: global QR should be set");

    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureQrCodeLogin forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureQrCodeLogin];

    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureQrCodeLogin],
                  @"QR should be promoted to per-user when global QR was set");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureQrCodeLogin],
                   @"QR should be cleared from global set after promotion");
}

- (void)test_givenGlobalQRNotSet_whenPromoteQR_thenUserLacksQR {
    // Simulates: QR login was NOT used globally, authType != refresh
    // Do NOT register QR globally

    // Promotion sequence from auth completion
    BOOL usedQrLogin = [[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureQrCodeLogin];
    XCTAssertFalse(usedQrLogin, @"Precondition: global QR should NOT be set");

    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureQrCodeLogin forUser:self.userA];

    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureQrCodeLogin],
                   @"QR should NOT be per-user when global QR was not set");
}

#pragma mark - Refresh Token Rotation (RTR) flag tests

- (void)test_givenRTRDetected_whenRTFlagRegistered_thenFlagAppearsInPerUserFeaturesNotGlobal {
    // Arrange: use userA as the account that experienced token rotation

    // Act: simulate RTR detection registering the flag
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureRTR forUser:self.userA];

    // Assert: RT in per-user features (union with global)
    NSSet *features = [SFSDKAppFeatureMarkers appFeaturesForUser:self.userA];
    XCTAssertTrue([features containsObject:kSFAppFeatureRTR],
                  @"RT flag should appear in per-user feature set after rotation");

    // Assert: RT NOT in global-only set
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureRTR],
                   @"RT flag should not bleed into global feature set");

    // Cleanup
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureRTR forUser:self.userA];
}

#pragma mark - DPoP feature flag tests

- (void)test_givenDPoPTokenType_whenDPFlagRegistered_thenFlagAppearsInPerUserFeaturesNotGlobal {
    // Arrange: userA is the account whose session was DPoP-bound.

    // Act: simulate finalizeAuthCompletion: registering DP on tokenType match.
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureDPoP forUser:self.userA];

    // Assert: DP in per-user features (union with global).
    NSSet *features = [SFSDKAppFeatureMarkers appFeaturesForUser:self.userA];
    XCTAssertTrue([features containsObject:kSFAppFeatureDPoP],
                  @"DP flag should appear in per-user feature set for DPoP-bound sessions");

    // Assert: DP NOT in global-only set.
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureDPoP],
                   @"DP flag should not bleed into global feature set");

    // Assert: per-user isolation — userB (no DPoP session) does not gain DP.
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userB] containsObject:kSFAppFeatureDPoP],
                   @"userB should not have DP if only userA had a DPoP session");

    // Cleanup handled in tearDown.
}

#pragma mark - App Attestation (AA) flag tests

- (void)test_givenAttestationUsed_whenPerUserFlagRegistered_thenFlagAppearsInPerUserFeaturesNotGlobal {
    // Act: simulate finalizeAuthCompletion persisting per-user and clearing global
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureAppAttestation forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation];

    // Assert: AA in per-user features
    NSSet *features = [SFSDKAppFeatureMarkers appFeaturesForUser:self.userA];
    XCTAssertTrue([features containsObject:kSFAppFeatureAppAttestation],
                  @"AA flag should appear in per-user feature set after attestation");

    // Assert: AA NOT in global-only set
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureAppAttestation],
                   @"AA flag should not remain in global feature set after finalization");

    // Cleanup
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation forUser:self.userA];
}

- (void)test_givenAAFlagPersistedOnUser_whenTokenRefreshCompletes_thenAAFlagPreserved {
    // Regression: before the fix, the AA promotion block ran on every auth completion
    // including token refresh, causing the per-user AA flag to be cleared.
    //
    // Simulates: user logged in with app attestation → AA is persisted per-user.
    // Then a silent token refresh fires (completedAuthType == SFOAuthTypeRefresh).
    // The refresh path must NOT touch the per-user AA flag.
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureAppAttestation forUser:self.userA];

    // Simulate the refresh path: global AA is absent (was never set for refresh),
    // and the promotion block is skipped entirely. The global clear still fires.
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation]; // always-clear of transient global

    // Per-user flag must be intact — refresh must not have unregistered it
    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureAppAttestation],
                  @"AA flag on user should survive a token refresh (regression check)");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureAppAttestation],
                   @"Global AA should be absent after the always-clear step");
}

- (void)test_givenAARegisteredGlobally_whenNonRefreshLoginCompletes_thenAAPromotedToUserAndGlobalCleared {
    // Simulates: app attestation fired during browser login flow (sets global AA),
    // then finalizeAuthCompletion: runs for a non-refresh login.
    // Expected: global AA promoted per-user and global copy cleared.
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureAppAttestation]; // early global set by SFOAuthCoordinator

    // Simulate promotion block (non-refresh path in finalizeAuthCompletion:)
    BOOL usedAppAttestation = [[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureAppAttestation];
    XCTAssertTrue(usedAppAttestation, @"Precondition: global AA should be set");
    if (usedAppAttestation) {
        [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureAppAttestation forUser:self.userA];
    } else {
        [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation forUser:self.userA];
    }
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation]; // always-clear

    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureAppAttestation],
                  @"AA should be promoted to per-user on non-refresh login when attestation was used");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureAppAttestation],
                   @"Global AA should be cleared after non-refresh promotion");
}

#pragma mark - A-marker (auth type) tests

- (void)test_givenWebServerNonHybrid_whenAuthCompletes_thenA1RegisteredPerUserAndGlobalCleared {
    // Simulate: A1 set globally before auth completion
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureAuthTypeWebServerNonHybrid];

    // Promotion logic
    NSArray<NSString *> *allAMarkers = @[kSFAppFeatureAuthTypeWebServerNonHybrid,
                                          kSFAppFeatureAuthTypeWebServerHybrid,
                                          kSFAppFeatureAuthTypeUserAgentNonHybrid,
                                          kSFAppFeatureAuthTypeUserAgentHybrid,
                                          kSFAppFeatureAuthTypeNative];
    NSString *aMarker = nil;
    for (NSString *marker in allAMarkers) {
        if ([[SFSDKAppFeatureMarkers appFeatures] containsObject:marker]) {
            aMarker = marker;
            break;
        }
    }
    for (NSString *marker in allAMarkers) {
        if ([marker isEqualToString:aMarker]) {
            [SFSDKAppFeatureMarkers registerAppFeature:marker forUser:self.userA];
        } else {
            [SFSDKAppFeatureMarkers unregisterAppFeature:marker forUser:self.userA];
        }
    }
    for (NSString *marker in allAMarkers) {
        [SFSDKAppFeatureMarkers unregisterAppFeature:marker];
    }

    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureAuthTypeWebServerNonHybrid],
                  @"A1 should be registered per-user after web-server non-hybrid auth");
    for (NSString *marker in allAMarkers) {
        if (![marker isEqualToString:kSFAppFeatureAuthTypeWebServerNonHybrid]) {
            XCTAssertFalse([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:marker],
                           @"Only A1 should be set; found unexpected marker %@", marker);
        }
        XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:marker],
                       @"A-marker %@ should be cleared from global set after promotion", marker);
    }
}

- (void)test_givenWebServerHybrid_whenAuthCompletes_thenA2RegisteredPerUserAndGlobalCleared {
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureAuthTypeWebServerHybrid];

    NSArray<NSString *> *allAMarkers = @[kSFAppFeatureAuthTypeWebServerNonHybrid,
                                          kSFAppFeatureAuthTypeWebServerHybrid,
                                          kSFAppFeatureAuthTypeUserAgentNonHybrid,
                                          kSFAppFeatureAuthTypeUserAgentHybrid,
                                          kSFAppFeatureAuthTypeNative];
    NSString *aMarker = nil;
    for (NSString *marker in allAMarkers) {
        if ([[SFSDKAppFeatureMarkers appFeatures] containsObject:marker]) {
            aMarker = marker;
            break;
        }
    }
    for (NSString *marker in allAMarkers) {
        if ([marker isEqualToString:aMarker]) {
            [SFSDKAppFeatureMarkers registerAppFeature:marker forUser:self.userA];
        } else {
            [SFSDKAppFeatureMarkers unregisterAppFeature:marker forUser:self.userA];
        }
    }
    for (NSString *marker in allAMarkers) {
        [SFSDKAppFeatureMarkers unregisterAppFeature:marker];
    }

    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureAuthTypeWebServerHybrid],
                  @"A2 should be registered per-user after web-server hybrid auth");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureAuthTypeWebServerHybrid],
                   @"A2 should be cleared from global set after promotion");
}

- (void)test_givenTokenMigration_whenAuthCompletes_thenTMRegisteredAndAMarkerPreserved {
    // Precondition: userA already has A2 from a previous login
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureAuthTypeWebServerHybrid forUser:self.userA];

    // Simulate migration completion: TM registered, A-marker NOT touched
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureTokenMigration forUser:self.userA];

    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureTokenMigration],
                  @"TM should be registered per-user after token migration");
    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureAuthTypeWebServerHybrid],
                  @"A2 should be preserved after migration (auth method unchanged)");
}

#pragma mark - JT/OT (token format) tests

- (void)test_givenJwtTokenFormat_whenAuthCompletes_thenJTRegisteredAndOTCleared {
    // Simulate: jwt token format
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureTokenFormatJwt forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureTokenFormatOpaque forUser:self.userA];

    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureTokenFormatJwt],
                  @"JT should be registered per-user for JWT token format");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureTokenFormatOpaque],
                   @"OT should NOT be present when token format is jwt");
}

- (void)test_givenOpaqueTokenFormat_whenAuthCompletes_thenOTRegisteredAndJTCleared {
    // Simulate: opaque token format
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureTokenFormatOpaque forUser:self.userA];
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureTokenFormatJwt forUser:self.userA];

    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureTokenFormatOpaque],
                  @"OT should be registered per-user for opaque token format");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureTokenFormatJwt],
                   @"JT should NOT be present when token format is opaque");
}

#pragma mark - BN (beacon) tests

- (void)test_givenBeaconConsumerKey_whenAuthCompletes_thenBNRegistered {
    // Simulate: beacon child consumer key present
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureBeacon forUser:self.userA];

    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureBeacon],
                  @"BN should be registered per-user when beacon child consumer key is present");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureBeacon],
                   @"BN should not be in global set");
}

- (void)test_givenNoBeaconConsumerKey_whenAuthCompletes_thenBNUnregistered {
    // Simulate: no beacon child consumer key
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureBeacon forUser:self.userA];

    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeaturesForUser:self.userA] containsObject:kSFAppFeatureBeacon],
                   @"BN should NOT be registered per-user when no beacon child consumer key");
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
