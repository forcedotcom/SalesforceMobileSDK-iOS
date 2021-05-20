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
#import "SalesforceSDKCore/SFRestAPI+Blocks.h"

@interface SFNetwork (Testing)

+ (NSDictionary *)sharedInstances;

@end

@interface SFNetworkTests : XCTestCase
@end

@implementation SFNetworkTests

- (void)testSessionSharing {
    // Default ephemeral instance
    {
        SFNetwork *network = [SFNetwork sharedEphemeralInstance];
        XCTAssertNotNil(network.activeSession);
        NSArray *identifiers = [SFNetwork sharedInstanceIdentifiers];
        XCTAssertEqual(identifiers.count, 1);
        XCTAssertTrue([identifiers containsObject:kSFNetworkEphemeralInstanceIdentifier]);
    }
    
    // Add default background instance
    {
        SFNetwork *network = [SFNetwork sharedBackgroundInstance];
        XCTAssertNotNil(network.activeSession);
        XCTAssertTrue([network.activeSession.configuration.identifier isEqualToString:kSFNetworkBackgroundInstanceIdentifier]);
        NSArray *identifiers = [SFNetwork sharedInstanceIdentifiers];
        XCTAssertEqual(identifiers.count, 2);
        XCTAssertTrue([identifiers containsObject:kSFNetworkEphemeralInstanceIdentifier]);
        XCTAssertTrue([identifiers containsObject:kSFNetworkBackgroundInstanceIdentifier]);
    }

    // Another ephemeral instance, should be reused from the first one
    {
        SFNetwork *network = [SFNetwork sharedEphemeralInstance];
        XCTAssertNotNil(network.activeSession);
        NSArray *identifiers = [SFNetwork sharedInstanceIdentifiers];
        XCTAssertEqual(identifiers.count, 2);
        XCTAssertTrue([identifiers containsObject:kSFNetworkEphemeralInstanceIdentifier]);
    }

    // Remove ephemeral instance with convenience wrapper
    {
        [SFNetwork removeSharedEphemeralInstance];
        NSArray *identifiers = [SFNetwork sharedInstanceIdentifiers];
        XCTAssertEqual(identifiers.count, 1);
        XCTAssertFalse([identifiers containsObject:kSFNetworkEphemeralInstanceIdentifier]);
    }

    // New custom instance
    {
        NSURLSessionConfiguration *customConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        customConfig.allowsCellularAccess = NO;
        SFNetwork *network = [SFNetwork sharedInstanceWithIdentifier:@"sessionWithCustomConfig" sessionConfiguration:customConfig];
        XCTAssertNotNil(network.activeSession);
        NSDictionary *instances = [SFNetwork sharedInstances];
        XCTAssertEqual(instances.count, 2);

        SFNetwork *sharedInstance = instances[@"sessionWithCustomConfig"];
        XCTAssertNotNil(sharedInstance);
        XCTAssertFalse(sharedInstance.activeSession.configuration.allowsCellularAccess);
    }

    // Clear all
    {
        [SFNetwork removeAllSharedInstances];
        NSArray *identifiers = [SFNetwork sharedInstanceIdentifiers];
        XCTAssertEqual(identifiers.count, 0);
    }

    // New custom session wth default config, then remove it
    {
        NSString *identifier = @"sessionWithDefaultConfig";

        SFNetwork *network = [SFNetwork sharedEphemeralInstanceWithIdentifier:identifier];
        XCTAssertNotNil(network.activeSession);
        NSArray *identifiers = [SFNetwork sharedInstanceIdentifiers];
        XCTAssertEqual(identifiers.count, 1);
        XCTAssertTrue([identifiers containsObject:identifier]);
 
        [SFNetwork removeSharedInstanceForIdentifier:identifier];
        identifiers = [SFNetwork sharedInstanceIdentifiers];
        XCTAssertEqual(identifiers.count, 0);
        XCTAssertFalse([identifiers containsObject:identifier]);
    }
}

- (void)testMetricsAction {
    [self addTeardownBlock:^{
        SFNetwork.metricsCollectedAction = nil;
    }];
    
    XCTestExpectation *getExpectation = [self expectationWithDescription:@"Get"];
    SFRestRequest *request = [SFRestRequest customUrlRequestWithMethod:SFRestMethodGET baseURL:@"https://api.github.com" path:@"/orgs/forcedotcom/repos" queryParams:nil];

    [[SFRestAPI sharedGlobalInstance] sendRequest:request failureBlock:^(id  _Nullable response, NSError * _Nullable e, NSURLResponse * _Nullable rawResponse) {
        XCTFail(@"Request failed");
    } successBlock:^(id  _Nullable response, NSURLResponse * _Nullable rawResponse) {
        [getExpectation fulfill];
    }];
    
    XCTestExpectation *metricsExpectation = [self expectationWithDescription:@"metricsExpectation"];
    SFNetwork.metricsCollectedAction = ^(NSURLSession * _Nonnull session, NSURLSessionTask * _Nonnull task, NSURLSessionTaskMetrics * _Nonnull metrics) {
        XCTAssertNotNil(session);
        XCTAssertNotNil(task);
        XCTAssertNotNil(metrics);
        [metricsExpectation fulfill];
    };
    
    [self waitForExpectations:@[getExpectation, metricsExpectation] timeout:20];
}

@end
