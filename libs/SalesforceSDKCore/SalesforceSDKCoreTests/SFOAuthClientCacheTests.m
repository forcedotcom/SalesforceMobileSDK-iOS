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
#import "SFOAuthCoordinator.h"
#import "SFSDKOAuthClientCache.h"
#import "SFSDKOAuthClient.h"
#import "SFOAuthCredentials.h"
#import "SFSDKOAuthClientConfig.h"
@interface SFOAuthClientCacheTests : XCTestCase

@end

@implementation SFOAuthClientCacheTests

- (void)setUp {
    [super setUp];
    [[SFSDKOAuthClientCache sharedInstance] removeAllClients];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[SFSDKOAuthClientCache sharedInstance] removeAllClients];
    [super tearDown];
}

- (void)testCache {
    
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
        config.advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    }];
    
    NSString *key = [SFSDKOAuthClientCache keyFromClient:client];
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client];

    XCTAssertNotNil([[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    
}

- (void)testCacheHitWithMultiple {
    
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
        config.advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    }];
    
    NSString *key = [SFSDKOAuthClientCache keyFromClient:client];
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client];
    
    SFSDKOAuthClient *client2 = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
        config.advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    }];
    
    NSString *key2 = [SFSDKOAuthClientCache keyFromClient:client2];
    
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    
}

- (void)testCacheRemove {
    
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
        config.advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    }];
    
    NSString *key = [SFSDKOAuthClientCache keyFromClient:client];
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client];
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    
    [[SFSDKOAuthClientCache sharedInstance] removeClientForKey:key];
    
    XCTAssertNil([[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    
}

- (void)testCacheMissWithMultipleTypes {
    
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
        config.advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    }];
    
    NSString *key = [SFSDKOAuthClientCache keyFromClient:client];
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client];
    
    SFSDKOAuthClient *client2 = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
    }];
    
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    NSString *key2 = [SFSDKOAuthClientCache keyFromClient:client2];
    
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client2];
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    
}

- (void)testCacheMissWithMultipleTypesAndIDP {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
        config.advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    }];
    
    NSString *key = [SFSDKOAuthClientCache keyFromClient:client];
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client];
    
    SFSDKOAuthClient *client2 = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
    }];
    
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    NSString *key2 = [SFSDKOAuthClientCache keyFromClient:client2];
    
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client2];
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    
    
    SFSDKOAuthClient *client3 = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
        config.idpAppURIScheme = @"idpApp";
    }];
    
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    NSString *key3 = [SFSDKOAuthClientCache keyFromClient:client3];
    
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key3]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client3];
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key3]);
}

- (void)testCacheRemoveWithMultipleTypesAndIDP {
    // Similar credentials differen types of Auth should result in multiple clients
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
        config.advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    }];
    
    NSString *key = [SFSDKOAuthClientCache keyFromClient:client];
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client];
    
    SFSDKOAuthClient *client2 = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
    }];
    
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    NSString *key2 = [SFSDKOAuthClientCache keyFromClient:client2];
    
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client2];
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    
    
    SFSDKOAuthClient *client3 = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
        config.idpAppURIScheme = @"idpApp";
    }];
    
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    NSString *key3 = [SFSDKOAuthClientCache keyFromClient:client3];
    
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key3]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client3];
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key3]);
    [[SFSDKOAuthClientCache sharedInstance] removeClient:client3];
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key3]);
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    
}

- (void)testCacheRemoveAll {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
        config.advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    }];
    
    NSString *key = [SFSDKOAuthClientCache keyFromClient:client];
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client];
    
    SFSDKOAuthClient *client2 = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
    }];
    
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    NSString *key2 = [SFSDKOAuthClientCache keyFromClient:client2];
    
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client2];
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    
    
    SFSDKOAuthClient *client3 = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
        config.idpAppURIScheme = @"idpApp";
    }];
    
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    NSString *key3 = [SFSDKOAuthClientCache keyFromClient:client3];
    
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key3]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client3];
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key3]);
    [[SFSDKOAuthClientCache sharedInstance] removeAllClients];
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key3]);
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    
}

- (void)testCacheMissWithMultipleDifferentCredentials {
    // Different credentials should result in multiple clients
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    
    SFOAuthCredentials *credentials2 = [[SFOAuthCredentials alloc] initWithIdentifier:@"test2Id" clientId:@"test2Id" encrypted:NO];
    
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
        config.advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    }];
    
    NSString *key = [SFSDKOAuthClientCache keyFromClient:client];
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client];
    
    SFSDKOAuthClient *client2 = [SFSDKOAuthClient clientWithCredentials:credentials2  configBlock:^(SFSDKOAuthClientConfig *config) {
        config.advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    }];
    
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key]);
    NSString *key2 = [SFSDKOAuthClientCache keyFromClient:client2];
    
    XCTAssertNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    [[SFSDKOAuthClientCache sharedInstance] addClient:client2];
    XCTAssertNotNil( [[SFSDKOAuthClientCache sharedInstance] clientForKey:key2]);
    
}

@end
