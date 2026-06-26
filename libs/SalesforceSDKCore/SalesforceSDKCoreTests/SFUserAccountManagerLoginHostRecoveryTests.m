/*
 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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
#import "SFUserAccountManager.h"
#import "SFUserAccountManager+Internal.h"
#import "SFSDKLoginHostStorage.h"
#import "SFSDKLoginHost.h"
#import "SFSDKAuthSession.h"
#import "SFSDKAuthRequest.h"
#import "SFSDKAuthErrorManager.h"
#import "SFSDKAlertMessage.h"

static NSString * const kBogusHost = @"bogus.example.com";
static NSString * const kBogusLabel = @"Bogus Test Host";
static NSString * const kBuiltInProductionHost = @"login.salesforce.com";

@interface SFUserAccountManagerLoginHostRecoveryTests : XCTestCase
@end

@implementation SFUserAccountManagerLoginHostRecoveryTests {
    NSString *_origLoginHost;
    NSString *_origPreviousLoginHost;
    void (^_origAlertDisplayBlock)(SFSDKAlertMessage *, SFSDKWindowContainer *);
}

- (void)setUp {
    [super setUp];

    SFUserAccountManager *mgr = [SFUserAccountManager sharedInstance];
    _origLoginHost = [mgr.loginHost copy];
    _origPreviousLoginHost = [mgr.previousLoginHost copy];
    _origAlertDisplayBlock = [mgr.alertDisplayBlock copy];

    // Ensure fixture host is present and deletable for each test.
    SFSDKLoginHostStorage *storage = [SFSDKLoginHostStorage sharedInstance];
    if ([storage loginHostForHostAddress:kBogusHost] == nil) {
        [storage addLoginHost:[SFSDKLoginHost hostWithName:kBogusLabel host:kBogusHost deletable:YES]];
    }
}

- (void)tearDown {
    SFUserAccountManager *mgr = [SFUserAccountManager sharedInstance];
    mgr.loginHost = _origLoginHost;
    mgr.previousLoginHost = _origPreviousLoginHost;
    if (_origAlertDisplayBlock) {
        mgr.alertDisplayBlock = _origAlertDisplayBlock;
    }

    SFSDKLoginHostStorage *storage = [SFSDKLoginHostStorage sharedInstance];
    [self removeHostIfPresent:kBogusHost fromStorage:storage];

    [super tearDown];
}

#pragma mark - Helpers

- (void)removeHostIfPresent:(NSString *)hostAddress fromStorage:(SFSDKLoginHostStorage *)storage {
    for (NSUInteger i = 0; i < [storage numberOfLoginHosts]; i++) {
        if ([[storage loginHostAtIndex:i].host isEqualToString:hostAddress]) {
            [storage removeLoginHostAtIndex:i];
            return;
        }
    }
}

- (SFSDKAuthSession *)makeAuthSessionForLoginHost:(NSString *)loginHost {
    SFSDKAuthRequest *request = [[SFSDKAuthRequest alloc] init];
    request.loginHost = loginHost;
    request.oauthClientId = @"test-client-id";
    request.oauthCompletionUrl = @"test://callback";
    request.scopes = [NSSet setWithObject:@"api"];
    return [[SFSDKAuthSession alloc] initWith:request credentials:nil];
}

- (NSError *)makeHostConnectionError {
    return [NSError errorWithDomain:NSURLErrorDomain
                               code:-1001
                           userInfo:@{
        @"_kCFStreamErrorCodeKey": @(-2103),
        @"_kCFStreamErrorDomainKey": @(4)
    }];
}

/// Drives the error handler block and waits until the alert OK completion has run.
/// Replaces alertDisplayBlock with a fake that immediately fires actionOneCompletion,
/// so we never present a real alert and the recovery logic runs deterministically.
- (void)fireHandlerBlockForSession:(SFSDKAuthSession *)session {
    SFUserAccountManager *mgr = [SFUserAccountManager sharedInstance];
    XCTestExpectation *completionRan = [self expectationWithDescription:@"alertCompletionRan"];
    mgr.alertDisplayBlock = ^(SFSDKAlertMessage *message, SFSDKWindowContainer *window) {
        if (message.actionOneCompletion) {
            message.actionOneCompletion();
        }
        [completionRan fulfill];
    };
    mgr.errorManager.hostConnectionErrorHandlerBlock([self makeHostConnectionError], session, @{});
    [self waitForExpectations:@[completionRan] timeout:5.0];
}

#pragma mark - Tests

- (void)test_givenHostChange_when_didChangeLoginHostCalled_then_previousLoginHostIsPriorHost {
    SFUserAccountManager *mgr = [SFUserAccountManager sharedInstance];
    NSString *seedHost = @"seed.my.salesforce.com";
    mgr.loginHost = seedHost;
    mgr.previousLoginHost = nil;

    SFSDKLoginHost *newHost = [SFSDKLoginHost hostWithName:kBogusLabel host:kBogusHost deletable:YES];
    [mgr hostListViewController:nil didChangeLoginHost:newHost];

    XCTAssertEqualObjects(mgr.previousLoginHost, seedHost);
    XCTAssertEqualObjects(mgr.loginHost, kBogusHost);
}

- (void)test_givenPreviousHostInStorage_when_handlerCompletionRuns_then_loginHostRestoredToPrevious {
    SFUserAccountManager *mgr = [SFUserAccountManager sharedInstance];
    // Production host is built-in (deletable=NO) and always present in storage.
    mgr.previousLoginHost = kBuiltInProductionHost;
    mgr.loginHost = kBogusHost;

    SFSDKAuthSession *session = [self makeAuthSessionForLoginHost:kBogusHost];
    [self fireHandlerBlockForSession:session];

    XCTAssertEqualObjects(mgr.loginHost, kBuiltInProductionHost);
}

- (void)test_givenPreviousHostNil_when_handlerCompletionRuns_then_loginHostFallsBackToIndex0 {
    SFUserAccountManager *mgr = [SFUserAccountManager sharedInstance];
    mgr.previousLoginHost = nil;
    mgr.loginHost = kBogusHost;

    SFSDKAuthSession *session = [self makeAuthSessionForLoginHost:kBogusHost];
    NSString *expectedHost = [[SFSDKLoginHostStorage sharedInstance] loginHostAtIndex:0].host;
    [self fireHandlerBlockForSession:session];

    XCTAssertEqualObjects(mgr.loginHost, expectedHost);
}

- (void)test_givenPreviousHostNotInStorage_when_handlerCompletionRuns_then_loginHostFallsBackToIndex0 {
    SFUserAccountManager *mgr = [SFUserAccountManager sharedInstance];
    mgr.previousLoginHost = @"ghost.no.longer.in.storage.com";
    mgr.loginHost = kBogusHost;

    SFSDKAuthSession *session = [self makeAuthSessionForLoginHost:kBogusHost];
    NSString *expectedHost = [[SFSDKLoginHostStorage sharedInstance] loginHostAtIndex:0].host;
    [self fireHandlerBlockForSession:session];

    XCTAssertEqualObjects(mgr.loginHost, expectedHost);
}

- (void)test_givenDeletableFailingHost_when_handlerCompletionRuns_then_failingHostRemovedFromStorage {
    SFUserAccountManager *mgr = [SFUserAccountManager sharedInstance];
    mgr.previousLoginHost = kBuiltInProductionHost;
    mgr.loginHost = kBogusHost;

    SFSDKLoginHostStorage *storage = [SFSDKLoginHostStorage sharedInstance];
    XCTAssertNotNil([storage loginHostForHostAddress:kBogusHost],
                    @"Precondition: fixture deletable host should be in storage before firing the handler.");

    SFSDKAuthSession *session = [self makeAuthSessionForLoginHost:kBogusHost];
    [self fireHandlerBlockForSession:session];

    XCTAssertNil([storage loginHostForHostAddress:kBogusHost]);
}

- (void)test_givenNonDeletableFailingHost_when_handlerCompletionRuns_then_failingHostKeptInStorage {
    SFUserAccountManager *mgr = [SFUserAccountManager sharedInstance];
    // Failing host is the built-in production host, which is non-deletable.
    mgr.previousLoginHost = kBogusHost;
    mgr.loginHost = kBuiltInProductionHost;

    SFSDKLoginHostStorage *storage = [SFSDKLoginHostStorage sharedInstance];
    XCTAssertNotNil([storage loginHostForHostAddress:kBuiltInProductionHost],
                    @"Precondition: built-in production host should be in storage.");

    SFSDKAuthSession *session = [self makeAuthSessionForLoginHost:kBuiltInProductionHost];
    [self fireHandlerBlockForSession:session];

    XCTAssertNotNil([storage loginHostForHostAddress:kBuiltInProductionHost],
                    @"Non-deletable hosts must never be auto-removed by the handler.");
}

@end
