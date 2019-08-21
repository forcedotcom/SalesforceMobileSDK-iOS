//
//  SFNetworkTests.m
//  SalesforceSDKCoreTests
//
//  Created by Brianna Birman on 8/1/19.
//  Copyright © 2019 salesforce.com. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SalesforceSDKCore/SFNetwork.h"

@interface SFNetworkTests : XCTestCase <SFNetworkSessionManaging>

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wprotocol"

@implementation SFNetworkTests

#pragma clang diagnostic pop
- (void)tearDown {
    [SFNetwork setSessionManager:(id<SFNetworkSessionManaging> _Nonnull)nil];
}

- (void)testSessionSharing {
    
    // Default ephemeral session
    {
        SFNetwork *network = [[SFNetwork alloc] initWithSessionConfigurationIdentifier:kSFNetworkEphemeralSessionIdentifier sessionConfiguration:nil useSharedSession:YES];
        XCTAssertNotNil(network.activeSession);
        NSDictionary *sessions = SFNetwork.sharedSessions;
        XCTAssertEqual(sessions.count, 1);
        XCTAssertNotNil(SFNetwork.sharedSessions[kSFNetworkEphemeralSessionIdentifier]);
    }
    
    // Add default background session
    {
        SFNetwork *network = [[SFNetwork alloc] initWithSessionConfigurationIdentifier:kSFNetworkBackgroundSessionIdentifier sessionConfiguration:nil useSharedSession:YES];
        XCTAssertNotNil(network.activeSession);
        XCTAssertEqual(network.activeSession.configuration.identifier, kSFNetworkBackgroundSessionIdentifier);
        NSDictionary *sessions = SFNetwork.sharedSessions;
        XCTAssertEqual(sessions.count, 2);
        XCTAssertNotNil(SFNetwork.sharedSessions[kSFNetworkEphemeralSessionIdentifier]);
        XCTAssertNotNil(SFNetwork.sharedSessions[kSFNetworkBackgroundSessionIdentifier]);
        
    }
    
    // Another ephemeral session, should be reused from the first one
    {
        SFNetwork *network = [[SFNetwork alloc] initWithSessionConfigurationIdentifier:kSFNetworkEphemeralSessionIdentifier sessionConfiguration:nil useSharedSession:YES];
        XCTAssertNotNil(network.activeSession);
        NSDictionary *sessions = SFNetwork.sharedSessions;
        XCTAssertEqual(sessions.count, 2);
        XCTAssertNotNil(SFNetwork.sharedSessions[kSFNetworkEphemeralSessionIdentifier]);
    }
    
    // Clear all
    {
        [SFNetwork removeAllSharedSessions];
        NSDictionary *sessions = SFNetwork.sharedSessions;
        XCTAssertEqual(sessions.count, 0);
    }
    
    // New custom session after reset
    {
        NSURLSessionConfiguration *customConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        customConfig.allowsCellularAccess = NO;
        SFNetwork *network = [[SFNetwork alloc] initWithSessionConfigurationIdentifier:@"sessionWithCustomConfig" sessionConfiguration:customConfig useSharedSession:YES];
        XCTAssertNotNil(network.activeSession);
        NSDictionary *sessions = SFNetwork.sharedSessions;
        XCTAssertEqual(sessions.count, 1);
        
        NSURLSession *cachedSession = SFNetwork.sharedSessions[@"sessionWithCustomConfig"];
        XCTAssertNotNil(cachedSession);
        XCTAssertFalse(cachedSession.configuration.allowsCellularAccess);
        
    }
    
    // Custom identifier but no configuration
    {
        SFNetwork *network = [[SFNetwork alloc] initWithSessionConfigurationIdentifier:@"sessionWithNoConfig" sessionConfiguration:nil useSharedSession:YES];
        XCTAssertNotNil(network.activeSession);
        NSDictionary *sessions = SFNetwork.sharedSessions;
        XCTAssertEqual(sessions.count, 2);
        
        NSURLSession *cachedSession = SFNetwork.sharedSessions[@"sessionWithNoConfig"];
        XCTAssertNotNil(cachedSession);
        XCTAssertTrue(cachedSession.configuration.allowsCellularAccess);
    }
    
    // Remove single item
    {
        [SFNetwork removeSharedSessionForConfigurationIdentifier:@"sessionWithNoConfig"];
        XCTAssertEqual(SFNetwork.sharedSessions.count, 1);
        XCTAssertNil(SFNetwork.sharedSessions[@"sessionWithNoConfig"]);
    }
}

- (void)testNewEphemeralSession {
    SFNetwork *network = [[SFNetwork alloc] initWithSessionConfigurationIdentifier:kSFNetworkEphemeralSessionIdentifier sessionConfiguration:nil useSharedSession:NO];
    XCTAssertNotNil(network.activeSession);
    NSDictionary *sessions = SFNetwork.sharedSessions;
    XCTAssertEqual(sessions.count, 0);
}

- (void)testNewBackgroundSession {
    SFNetwork *network = [[SFNetwork alloc] initWithSessionConfigurationIdentifier:kSFNetworkBackgroundSessionIdentifier sessionConfiguration:nil useSharedSession:NO];
    XCTAssertNotNil(network.activeSession);
    NSDictionary *sessions = SFNetwork.sharedSessions;
    XCTAssertEqual(sessions.count, 0);
}

- (void)testSessionManager {
    [SFNetwork setSessionManager:self];
    SFNetwork *network = [[SFNetwork alloc] initWithSessionConfigurationIdentifier:@"sessionWithManager" sessionConfiguration:nil useSharedSession:NO];

    NSURLSession *session = network.activeSession;
    XCTAssertNotNil(session);
    XCTAssertEqual(network.activeSession.configuration.identifier, @"SessionFromManager");
}

# pragma mark - SFNetworkSessionManaging

- (nonnull NSURLSession *)sessionWithConfigurationIdentifier:(nonnull NSString *)identifier sessionConfiguration:(nullable NSURLSessionConfiguration *)configuration useSharedSession:(BOOL)useSharedSession {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"SessionFromManager"];
    return [NSURLSession sessionWithConfiguration:config];
}

@end
