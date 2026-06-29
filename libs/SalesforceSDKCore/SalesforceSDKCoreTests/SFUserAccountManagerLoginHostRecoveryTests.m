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
#import <objc/runtime.h>
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
// Stand-in implementation swapped into restartAuthentication: for the lifetime of each test.
// Mirrors the SFSDKLogoutBlocker pattern (libs/.../SFSDKLogoutBlocker.m) but scoped to this file
// so we don't disturb other test classes that rely on the real OAuth restart path.
- (void)dummy_restartAuthentication:(SFSDKAuthSession *)session;
@end

// File-static counter so the swizzled instance method (which runs as if on SFUserAccountManager,
// not on the test case) can record that it was hit. Reset in setUp.
static NSUInteger gRestartAuthenticationCallCount = 0;

@implementation SFUserAccountManagerLoginHostRecoveryTests {
    NSString *_origLoginHost;
    NSString *_origPreviousLoginHost;
    void (^_origAlertDisplayBlock)(SFSDKAlertMessage *, SFSDKWindowContainer *);
}

// Isolate the host-recovery decision logic from the real OAuth restart pipeline.
//
// The error-handler block under test ends with `[strongSelf restartAuthentication:session]`,
// which calls `stopAuthentication`, dismisses any presented auth view controller asynchronously,
// then re-enters `authenticateWithRequest:`. With a minimal stub SFSDKAuthRequest, none of that
// has a real coordinator/view controller to act on, but it still mutates global SFUserAccountManager
// state (authSessions[...]isAuthenticating, etc.) on a background dispatch — which can race the
// `loginHost`/storage assertions these tests make right after `actionOneCompletion` fires.
//
// To make the recovery tests assert *only* on the synchronous decision (which host to fall back
// to, whether the failing host was removed), we exchange `restartAuthentication:` with a no-op
// for the duration of each test and restore it in tearDown. The handler still runs end-to-end
// (recovery + storage cleanup), but the OAuth restart side-effect becomes a deterministic no-op.
- (void)swapRestartAuthentication {
    Method original = class_getInstanceMethod([SFUserAccountManager class], @selector(restartAuthentication:));
    Method replacement = class_getInstanceMethod([self class], @selector(dummy_restartAuthentication:));
    method_exchangeImplementations(original, replacement);
}

- (void)dummy_restartAuthentication:(SFSDKAuthSession *)session {
    // Intentional no-op except for counting invocations. See -swapRestartAuthentication for rationale.
    // Counted via a file-static so tests can assert whether the recovery branch fired.
    gRestartAuthenticationCallCount++;
}

- (void)setUp {
    [super setUp];

    SFUserAccountManager *mgr = [SFUserAccountManager sharedInstance];
    _origLoginHost = [mgr.loginHost copy];
    _origPreviousLoginHost = [mgr.previousLoginHost copy];
    _origAlertDisplayBlock = [mgr.alertDisplayBlock copy];

    [self swapRestartAuthentication];
    gRestartAuthenticationCallCount = 0;

    // Ensure fixture host is present and deletable for each test.
    SFSDKLoginHostStorage *storage = [SFSDKLoginHostStorage sharedInstance];
    if ([storage loginHostForHostAddress:kBogusHost] == nil) {
        [storage addLoginHost:[SFSDKLoginHost hostWithName:kBogusLabel host:kBogusHost deletable:YES]];
    }
}

- (void)tearDown {
    // method_exchangeImplementations is symmetric — calling it again restores the originals.
    [self swapRestartAuthentication];

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

/// Strong "host is unusable" signal — DNS NXDOMAIN. The new gate auto-removes on this.
- (NSError *)makeStrongBadHostError {
    return [NSError errorWithDomain:NSURLErrorDomain
                               code:NSURLErrorCannotFindHost
                           userInfo:@{
        @"_kCFStreamErrorCodeKey": @(-72000),
        @"_kCFStreamErrorDomainKey": @(12)
    }];
}

/// Ambiguous signal — timeout. Could be transient (flaky Wi-Fi). The new gate must NOT
/// auto-remove on this, even when the host is otherwise deletable.
- (NSError *)makeAmbiguousHostError {
    return [NSError errorWithDomain:NSURLErrorDomain
                               code:NSURLErrorTimedOut
                           userInfo:@{
        @"_kCFStreamErrorCodeKey": @(-2103),
        @"_kCFStreamErrorDomainKey": @(4)
    }];
}

/// Drives the error handler block and waits until the alert OK completion has run.
/// Replaces alertDisplayBlock with a fake that immediately fires actionOneCompletion,
/// so we never present a real alert and the recovery logic runs deterministically.
- (void)fireHandlerBlockForSession:(SFSDKAuthSession *)session withError:(NSError *)error {
    SFUserAccountManager *mgr = [SFUserAccountManager sharedInstance];
    XCTestExpectation *completionRan = [self expectationWithDescription:@"alertCompletionRan"];
    mgr.alertDisplayBlock = ^(SFSDKAlertMessage *message, SFSDKWindowContainer *window) {
        if (message.actionOneCompletion) {
            message.actionOneCompletion();
        }
        [completionRan fulfill];
    };
    mgr.errorManager.hostConnectionErrorHandlerBlock(error, session, @{});
    [self waitForExpectations:@[completionRan] timeout:5.0];
}

- (void)fireHandlerBlockForSession:(SFSDKAuthSession *)session {
    [self fireHandlerBlockForSession:session withError:[self makeStrongBadHostError]];
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

- (void)test_givenDeletableFailingHostAndStrongBadHostSignal_when_handlerCompletionRuns_then_failingHostRemovedFromStorage {
    SFUserAccountManager *mgr = [SFUserAccountManager sharedInstance];
    mgr.previousLoginHost = kBuiltInProductionHost;
    mgr.loginHost = kBogusHost;

    SFSDKLoginHostStorage *storage = [SFSDKLoginHostStorage sharedInstance];
    XCTAssertNotNil([storage loginHostForHostAddress:kBogusHost],
                    @"Precondition: fixture deletable host should be in storage before firing the handler.");

    SFSDKAuthSession *session = [self makeAuthSessionForLoginHost:kBogusHost];
    [self fireHandlerBlockForSession:session withError:[self makeStrongBadHostError]];

    XCTAssertNil([storage loginHostForHostAddress:kBogusHost]);
}

- (void)test_givenDeletableFailingHostAndAmbiguousSignal_when_handlerCompletionRuns_then_failingHostKeptInStorage {
    SFUserAccountManager *mgr = [SFUserAccountManager sharedInstance];
    mgr.previousLoginHost = kBuiltInProductionHost;
    mgr.loginHost = kBogusHost;

    SFSDKLoginHostStorage *storage = [SFSDKLoginHostStorage sharedInstance];
    XCTAssertNotNil([storage loginHostForHostAddress:kBogusHost],
                    @"Precondition: fixture deletable host should be in storage before firing the handler.");

    SFSDKAuthSession *session = [self makeAuthSessionForLoginHost:kBogusHost];
    [self fireHandlerBlockForSession:session withError:[self makeAmbiguousHostError]];

    XCTAssertNotNil([storage loginHostForHostAddress:kBogusHost],
                    @"Deletable hosts must not be auto-removed on ambiguous (likely transient) errors.");
    // Recovery should still happen.
    XCTAssertEqualObjects(mgr.loginHost, kBuiltInProductionHost);
}

// The recovery path explicitly guards against `numberOfLoginHosts == 0` before calling
// `loginHostAtIndex:0`. Without that guard, an empty storage list would raise NSRangeException.
// Empty storage is plausible in two real cases: (1) the only entry was the failing host and was
// just auto-removed by the strong-bad-host gate, or (2) MDM `onlyShowAuthorizedHosts` is enabled
// with an empty authorized list. This test drains storage and asserts the handler logs + bails
// rather than crashing, and leaves `loginHost` untouched (no recovery target available).
- (void)test_givenEmptyStorage_when_handlerCompletionRuns_then_noRangeExceptionAndNoHostAssignment {
    SFUserAccountManager *mgr = [SFUserAccountManager sharedInstance];
    mgr.previousLoginHost = nil; // Force the fallback path (else branch) into the storage lookup.
    mgr.loginHost = kBogusHost;

    SFSDKLoginHostStorage *storage = [SFSDKLoginHostStorage sharedInstance];

    // SFSDKLoginHostStorage's public API can't actually empty the list: -removeAllLoginHosts
    // intentionally preserves the built-in production/sandbox entries unless MDM
    // `onlyShowAuthorizedHosts` is set. To exercise the guard without standing up a fake
    // managed-preferences singleton, reach the private `loginHostList` NSMutableArray via KVC,
    // snapshot it, swap in an empty array for this test, and restore on the way out.
    NSMutableArray *originalList = [storage valueForKey:@"loginHostList"];
    NSMutableArray *snapshot = [originalList mutableCopy];
    [storage setValue:[NSMutableArray array] forKey:@"loginHostList"];
    XCTAssertEqual([storage numberOfLoginHosts], (NSUInteger)0, @"Precondition: storage must be empty.");

    SFSDKAuthSession *session = [self makeAuthSessionForLoginHost:kBogusHost];

    // Firing must NOT raise NSRangeException. XCTAssertNoThrow wraps the call so any uncaught
    // exception fails the test instead of aborting the run.
    XCTAssertNoThrow([self fireHandlerBlockForSession:session withError:[self makeStrongBadHostError]],
                     @"Empty-storage guard must prevent NSRangeException from loginHostAtIndex:0.");

    // With no recovery host available, the handler must hit the `else` branch and skip the
    // restart entirely. We can't usefully assert on mgr.loginHost here — its getter (in
    // SFSDKAuthPreferences -loginHost) re-validates against storage and synthesizes a fallback
    // when the persisted value isn't found, so a read can't distinguish "handler didn't assign"
    // from "getter resolved to bundle default". The reliable signal is whether
    // -restartAuthentication: was invoked: zero means the empty-storage guard bailed cleanly.
    XCTAssertEqual(gRestartAuthenticationCallCount, (NSUInteger)0,
                   @"With empty storage and no previousLoginHost, the handler must skip restartAuthentication: (recoveryHost stays nil).");

    // Restore the original list so subsequent tests (and the persisted singleton) are unaffected.
    [storage setValue:snapshot forKey:@"loginHostList"];
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
