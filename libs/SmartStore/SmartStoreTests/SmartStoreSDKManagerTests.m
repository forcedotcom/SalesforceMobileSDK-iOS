/*
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
 
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
#import "SmartStoreSDKManager.h"
#import "SFSmartStore.h"
#import <SalesforceSDKCore/SalesforceSDKManager.h>

@interface SmartStoreSDKManagerTests : SFSmartStoreTestCase

@end

@implementation SmartStoreSDKManagerTests

- (void)testGetDevSupportInfosContainsSmartStoreSection {
    SmartStoreSDKManager *manager = [[SmartStoreSDKManager alloc] init];
    
    NSArray *devInfos = [manager getDevSupportInfos];
    
    BOOL foundSmartStoreSection = NO;
    for (id item in devInfos) {
        if ([item isKindOfClass:[NSString class]] && [item isEqualToString:@"section:SmartStore"]) {
            foundSmartStoreSection = YES;
            break;
        }
    }
    
    XCTAssertTrue(foundSmartStoreSection, @"Dev support infos should contain 'section:SmartStore'");
}

- (void)testGetDevSupportInfosContainsSQLCipherVersion {
    SmartStoreSDKManager *manager = [[SmartStoreSDKManager alloc] init];
    
    NSArray *devInfos = [manager getDevSupportInfos];
    
    BOOL foundVersionLabel = NO;
    BOOL foundVersionValue = NO;
    
    for (NSUInteger i = 0; i < devInfos.count - 1; i++) {
        if ([devInfos[i] isEqualToString:@"SQLCipher version"]) {
            foundVersionLabel = YES;
            // The next item should be the version value
            if (i + 1 < devInfos.count && [devInfos[i + 1] isKindOfClass:[NSString class]]) {
                NSString *version = devInfos[i + 1];
                foundVersionValue = (version.length > 0);
            }
            break;
        }
    }
    
    XCTAssertTrue(foundVersionLabel, @"Dev support infos should contain 'SQLCipher version' label");
    XCTAssertTrue(foundVersionValue, @"Dev support infos should contain SQLCipher version value");
}

- (void)testGetDevSupportInfosContainsCompileOptions {
    SmartStoreSDKManager *manager = [[SmartStoreSDKManager alloc] init];
    
    NSArray *devInfos = [manager getDevSupportInfos];
    
    BOOL foundCompileOptions = NO;
    
    for (NSUInteger i = 0; i < devInfos.count - 1; i++) {
        if ([devInfos[i] isEqualToString:@"SQLCipher Compile Options"]) {
            foundCompileOptions = YES;
            // The next item should be the compile options (may be empty string)
            XCTAssertTrue(i + 1 < devInfos.count, @"Compile options label should be followed by a value");
            XCTAssertTrue([devInfos[i + 1] isKindOfClass:[NSString class]], @"Compile options value should be a string");
            break;
        }
    }
    
    XCTAssertTrue(foundCompileOptions, @"Dev support infos should contain 'SQLCipher Compile Options'");
}

- (void)testGetDevSupportInfosContainsRuntimeSettings {
    SmartStoreSDKManager *manager = [[SmartStoreSDKManager alloc] init];
    
    NSArray *devInfos = [manager getDevSupportInfos];
    
    BOOL foundRuntimeSettings = NO;
    
    for (NSUInteger i = 0; i < devInfos.count - 1; i++) {
        if ([devInfos[i] isEqualToString:@"SQLCipher Runtime Settings"]) {
            foundRuntimeSettings = YES;
            // The next item should be the runtime settings
            XCTAssertTrue(i + 1 < devInfos.count, @"Runtime settings label should be followed by a value");
            XCTAssertTrue([devInfos[i + 1] isKindOfClass:[NSString class]], @"Runtime settings value should be a string");
            break;
        }
    }
    
    XCTAssertTrue(foundRuntimeSettings, @"Dev support infos should contain 'SQLCipher Runtime Settings'");
}

- (void)testGetDevSupportInfosWithGlobalStores {
    SmartStoreSDKManager *manager = [[SmartStoreSDKManager alloc] init];
    
    // Create a global store to ensure we have something to report
    SFSmartStore *globalStore = [SFSmartStore sharedGlobalStoreWithName:@"testGlobalStore"];
    XCTAssertNotNil(globalStore, @"Should be able to create global store");
    
    NSArray *devInfos = [manager getDevSupportInfos];
    
    // Find the Global SmartStores entry
    BOOL foundGlobalStores = NO;
    NSString *globalStoresValue = nil;
    
    for (NSUInteger i = 0; i < devInfos.count - 1; i++) {
        if ([devInfos[i] isEqualToString:@"Global SmartStores"]) {
            foundGlobalStores = YES;
            globalStoresValue = devInfos[i + 1];
            break;
        }
    }
    
    XCTAssertTrue(foundGlobalStores, @"Should find Global SmartStores entry");
    XCTAssertNotNil(globalStoresValue, @"Global SmartStores value should not be nil");
    XCTAssertTrue([globalStoresValue containsString:@"testGlobalStore"], 
                 @"Global SmartStores should include our test store (found: %@)", globalStoresValue);
    
    // Clean up
    [SFSmartStore removeSharedGlobalStoreWithName:@"testGlobalStore"];
}

- (void)testGetDevSupportInfosWithUserStore {
    SmartStoreSDKManager *manager = [[SmartStoreSDKManager alloc] init];
    
    // Set up a test user
    SFUserAccount *testUser = [self setUpSmartStoreUser];
    
    // Create a user store
    SFSmartStore *userStore = [SFSmartStore sharedStoreWithName:@"testUserStore" user:testUser];
    XCTAssertNotNil(userStore, @"Should be able to create user store");
    
    NSArray *devInfos = [manager getDevSupportInfos];
    
    // Find the User SmartStores entry
    BOOL foundUserStores = NO;
    NSString *userStoresValue = nil;
    
    for (NSUInteger i = 0; i < devInfos.count - 1; i++) {
        if ([devInfos[i] isEqualToString:@"User SmartStores"]) {
            foundUserStores = YES;
            userStoresValue = devInfos[i + 1];
            break;
        }
    }
    
    XCTAssertTrue(foundUserStores, @"Should find User SmartStores entry");
    XCTAssertNotNil(userStoresValue, @"User SmartStores value should not be nil");
    
    // Clean up
    [SFSmartStore removeSharedStoreWithName:@"testUserStore" forUser:testUser];
    [self tearDownSmartStoreUser:testUser];
}

- (void)testGetDevActionsIncludesInspectSmartStore {
    SmartStoreSDKManager *manager = [[SmartStoreSDKManager alloc] init];
    UIViewController *vc = [[UIViewController alloc] init];
    
    NSArray *devActions = [manager getDevActions:vc];
    
    BOOL foundInspectAction = NO;
    for (id action in devActions) {
        if ([action isKindOfClass:[SFSDKDevAction class]]) {
            SFSDKDevAction *devAction = (SFSDKDevAction *)action;
            if ([devAction.name isEqualToString:@"Inspect SmartStore"]) {
                foundInspectAction = YES;
                break;
            }
        }
    }
    
    XCTAssertTrue(foundInspectAction, @"Dev actions should include 'Inspect SmartStore' action");
}

@end

