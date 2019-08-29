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
        SFNetwork *network = [SFNetwork defaultEphemeralNetwork];
        XCTAssertNotNil(network.activeSession);
        NSDictionary *sessions = SFNetwork.sharedSessions;
        XCTAssertEqual(sessions.count, 1);
        XCTAssertNotNil(sessions[kSFNetworkEphemeralSessionIdentifier]);
    }
    
    // Add default background session
    {
        SFNetwork *network = [SFNetwork defaultBackgroundNetwork];
        XCTAssertNotNil(network.activeSession);
        XCTAssertTrue([network.activeSession.configuration.identifier isEqualToString:kSFNetworkBackgroundSessionIdentifier]);
        NSDictionary *sessions = SFNetwork.sharedSessions;
        XCTAssertEqual(sessions.count, 2);
        XCTAssertNotNil(sessions[kSFNetworkEphemeralSessionIdentifier]);
        XCTAssertNotNil(sessions[kSFNetworkBackgroundSessionIdentifier]);
        
    }
    
    // Another ephemeral session, should be reused from the first one
    {
        SFNetwork *network = [SFNetwork defaultEphemeralNetwork];
        XCTAssertNotNil(network.activeSession);
        NSDictionary *sessions = SFNetwork.sharedSessions;
        XCTAssertEqual(sessions.count, 2);
        XCTAssertNotNil(sessions[kSFNetworkEphemeralSessionIdentifier]);
    }
    
    // Remove ephemeral session with convenience wrapper
    {
        [SFNetwork removeSharedEphemeralSession];
        NSDictionary *sessions = SFNetwork.sharedSessions;
        XCTAssertEqual(sessions.count, 1);
        XCTAssertNil(sessions[kSFNetworkEphemeralSessionIdentifier]);
    }
    
    // New custom session
    {
        NSURLSessionConfiguration *customConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        customConfig.allowsCellularAccess = NO;
        SFNetwork *network = [SFNetwork networkWithSessionIdentifier:@"sessionWithCustomConfig" sessionConfiguration:customConfig];
        XCTAssertNotNil(network.activeSession);
        NSDictionary *sessions = SFNetwork.sharedSessions;
        XCTAssertEqual(sessions.count, 2);
        
        NSURLSession *sharedSession = sessions[@"sessionWithCustomConfig"];
        XCTAssertNotNil(sharedSession);
        XCTAssertFalse(sharedSession.configuration.allowsCellularAccess);
    }
    
    // Clear all
    {
        [SFNetwork removeAllSharedSessions];
        NSDictionary *sessions = SFNetwork.sharedSessions;
        XCTAssertEqual(sessions.count, 0);
    }
    
    // New custom session wth no config, then remove it
    {
        NSString *identifier = @"sessionWithNoConfig";
        SFNetwork *network = [SFNetwork networkWithSessionIdentifier:identifier sessionConfiguration:nil];
        XCTAssertNotNil(network.activeSession);
        NSDictionary *sessions = SFNetwork.sharedSessions;
        XCTAssertEqual(sessions.count, 1);
        NSURLSession *sharedSession = sessions[identifier];
        XCTAssertNotNil(sharedSession);

        [SFNetwork removeSharedSessionForIdentifier:identifier];
        XCTAssertEqual(SFNetwork.sharedSessions.count, 0);
        XCTAssertNil(SFNetwork.sharedSessions[identifier]);
    }
}

- (void)testSessionManager {
    [SFNetwork setSessionManager:self];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"SessionFromManager"];
    SFNetwork *network = [SFNetwork networkWithSessionIdentifier:@"sessionWithManager" sessionConfiguration:configuration];

    NSURLSession *session = network.activeSession;
    XCTAssertNotNil(session);
    XCTAssertEqual(network.activeSession.configuration.identifier, @"SessionFromManager");
}

# pragma mark - SFNetworkSessionManaging

- (nonnull NSURLSession *)sessionWithIdentifier:(nonnull NSString *)identifier sessionConfiguration:(nonnull NSURLSessionConfiguration *)configuration {
    return [NSURLSession sessionWithConfiguration:configuration];
}

@end
