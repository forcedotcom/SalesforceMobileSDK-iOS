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
#import "SFSDKAuthErrorManager.h"
#import "SFOAuthInfo.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFUserAccountManager+Internal.h"
#import "SFOAuthCredentials+Internal.h"
#import "TestSetupUtils.h"
#import "SFSDKAuthRequest.h"
@interface SFSDKErrorManagerTests : XCTestCase {
    SFUserAccount *_origCurrentUser;
}
@end

@implementation SFSDKErrorManagerTests
- (void)setUp {
    [super setUp];
    _origCurrentUser =  [SFUserAccountManager sharedInstance].currentUser;
}

- (void)tearDown {
    [super tearDown];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:_origCurrentUser];
}

- (void)testNetworkError {
    SFSDKAuthErrorManager *errorManager = [[SFSDKAuthErrorManager alloc] init];
    
    SFOAuthCredentials *credentials = [TestSetupUtils newClientCredentials];
    credentials.accessToken = @"__ACCESS_TOKEN__";
    credentials.refreshToken = @"__REFRESH_TOKEN__";
    credentials.userId = @"USER123";
    credentials.organizationId = @"ORG123";
   
    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:credentials];
    [[SFUserAccountManager sharedInstance] saveAccountForUser:account error:nil];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:account];
    SFSDKAuthRequest *request = [[SFSDKAuthRequest alloc] init];
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:credentials spAppCredentials:nil];
    session.oauthCoordinator.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeRefresh];
       
    XCTAssertNotNil(errorManager);
    XCTestExpectation *networkErrorExpectation =  [self expectationWithDescription:@"networkErrorExpectation"];
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:userInfo];
    
    errorManager.networkErrorHandlerBlock = ^(NSError * error, SFSDKAuthSession * authSession, NSDictionary *options) {
        [networkErrorExpectation fulfill];
    };
    
    XCTAssertNotNil(errorManager.networkErrorHandlerBlock);
    BOOL handled = [errorManager processAuthError:error authContext:session options:userInfo];
    XCTAssertTrue(handled,@"Network Error Should have been handled by the ErrorManager");
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:account error:nil];
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testAuthError {
    
    SFSDKAuthErrorManager *errorManager = [[SFSDKAuthErrorManager alloc] init];
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] init];
    XCTAssertNotNil(errorManager);
    XCTestExpectation *errorExpectation =  [self expectationWithDescription:@"authErrorExpectation"];
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain code:kSFOAuthErrorInvalidGrant userInfo:userInfo];
    
    errorManager.invalidAuthCredentialsErrorHandlerBlock = ^(NSError * error, SFSDKAuthSession * authSession, NSDictionary *options) {
        [errorExpectation fulfill];
    };
    XCTAssertNotNil(errorManager.invalidAuthCredentialsErrorHandlerBlock);
    BOOL handled = [errorManager processAuthError:error authContext:authSession  options:userInfo];
    XCTAssertTrue(handled,@"Invalid grant auth error Should have been handled by the ErrorManager");
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testAuthErrorConvenienceClassMethod {
    
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain code:kSFOAuthErrorInvalidGrant userInfo:userInfo];
    XCTAssertTrue([SFSDKAuthErrorManager errorIsInvalidAuthCredentials:error],@"Should be a valid auth error  handled by the ErrorManager");
}

- (void)testConnectedAppVersionMismatchError {
    
    SFSDKAuthErrorManager *errorManager = [[SFSDKAuthErrorManager alloc] init];
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] init];
    XCTAssertNotNil(errorManager);
    XCTestExpectation *errorExpectation =  [self expectationWithDescription:@"connectedAppVersionMismatchErrorExpectation"];
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain code:kSFOAuthErrorWrongVersion userInfo:userInfo];
    
    errorManager.connectedAppVersionMismatchErrorHandlerBlock  = ^(NSError * error, SFSDKAuthSession *authSession, NSDictionary *options) {
        [errorExpectation fulfill];
    };
    XCTAssertNotNil(errorManager.connectedAppVersionMismatchErrorHandlerBlock);
    BOOL handled = [errorManager processAuthError:error authContext:authSession options:userInfo];
    XCTAssertTrue(handled,@"Connected app version mismatch should have been handled by the ErrorManager");
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testGenericError {
    SFSDKAuthErrorManager *errorManager = [[SFSDKAuthErrorManager alloc] init];
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] init];
    XCTAssertNotNil(errorManager);
    XCTestExpectation *errorExpectation =  [self expectationWithDescription:@"genericErrorExpectation"];
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    NSError *error = [NSError errorWithDomain:@"someError" code:-999 userInfo:userInfo];

    errorManager.genericErrorHandlerBlock  = ^(NSError * error, SFSDKAuthSession *authSession, NSDictionary *options) {
        [errorExpectation fulfill];
    };

    XCTAssertNotNil(errorManager.genericErrorHandlerBlock);
    BOOL handled = [errorManager processAuthError:error authContext:authSession options:userInfo];
    XCTAssertTrue(handled,@"Generic Error should have been handled by the ErrorManager");
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

#pragma mark - Host connection classifier tests

// Shared helper: assert that the host connection handler claims a bare NSError
// (no CFStream keys) constructed with the given domain and code, when the
// session is not a Refresh-with-existing-token flow.
- (void)assertHostConnectionClaimsDomain:(NSString *)domain code:(NSInteger)code description:(NSString *)description {
    SFSDKAuthErrorManager *errorManager = [[SFSDKAuthErrorManager alloc] init];
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] init];
    XCTAssertNotNil(errorManager);
    XCTestExpectation *expectation = [self expectationWithDescription:description];
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    NSError *error = [NSError errorWithDomain:domain code:code userInfo:userInfo];

    errorManager.hostConnectionErrorHandlerBlock = ^(NSError *e, SFSDKAuthSession *s, NSDictionary *o) {
        [expectation fulfill];
    };
    XCTAssertNotNil(errorManager.hostConnectionErrorHandlerBlock);
    BOOL handled = [errorManager processAuthError:error authContext:authSession options:userInfo];
    XCTAssertTrue(handled, @"Host connection error should have been handled by the ErrorManager");
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

// NSURLErrorDomain host-connection codes with NO CFStream keys claim the host handler.
// This is the iOS 26 shape — DNS resolution moved to Network.framework, so the legacy
// _kCFStreamError* keys are absent from top-level userInfo.
- (void)testHostConnectionError_NSURLErrorCannotFindHost {
    [self assertHostConnectionClaimsDomain:NSURLErrorDomain
                                      code:NSURLErrorCannotFindHost
                               description:@"hostConnectionExpectation_CannotFindHost"];
}

- (void)testHostConnectionError_NSURLErrorDNSLookupFailed {
    [self assertHostConnectionClaimsDomain:NSURLErrorDomain
                                      code:NSURLErrorDNSLookupFailed
                               description:@"hostConnectionExpectation_DNSLookupFailed"];
}

- (void)testHostConnectionError_NSURLErrorCannotConnectToHost {
    [self assertHostConnectionClaimsDomain:NSURLErrorDomain
                                      code:NSURLErrorCannotConnectToHost
                               description:@"hostConnectionExpectation_CannotConnectToHost"];
}

- (void)testHostConnectionError_NSURLErrorTimedOut {
    [self assertHostConnectionClaimsDomain:NSURLErrorDomain
                                      code:NSURLErrorTimedOut
                               description:@"hostConnectionExpectation_TimedOut"];
}

- (void)testHostConnectionError_NSURLErrorNotConnectedToInternet {
    [self assertHostConnectionClaimsDomain:NSURLErrorDomain
                                      code:NSURLErrorNotConnectedToInternet
                               description:@"hostConnectionExpectation_NotConnectedToInternet"];
}

- (void)testHostConnectionError_NSURLErrorNetworkConnectionLost {
    [self assertHostConnectionClaimsDomain:NSURLErrorDomain
                                      code:NSURLErrorNetworkConnectionLost
                               description:@"hostConnectionExpectation_NetworkConnectionLost"];
}

// Legacy iOS <= 18 shape — NSURLErrorDomain / -1003 with CFStream keys in userInfo — still claimed.
- (void)testHostConnectionError_LegacyCFStreamKeys {
    SFSDKAuthErrorManager *errorManager = [[SFSDKAuthErrorManager alloc] init];
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] init];
    XCTAssertNotNil(errorManager);
    XCTestExpectation *expectation = [self expectationWithDescription:@"hostConnectionExpectation_LegacyCFStreamKeys"];
    NSDictionary *userInfo = @{ @"_kCFStreamErrorCodeKey": @8,
                                @"_kCFStreamErrorDomainKey": @12 };
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotFindHost userInfo:userInfo];

    errorManager.hostConnectionErrorHandlerBlock = ^(NSError *e, SFSDKAuthSession *s, NSDictionary *o) {
        [expectation fulfill];
    };
    XCTAssertNotNil(errorManager.hostConnectionErrorHandlerBlock);
    BOOL handled = [errorManager processAuthError:error authContext:authSession options:userInfo];
    XCTAssertTrue(handled, @"Legacy CFStream-shaped host connection error should have been handled by the ErrorManager");
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

// kSFOAuthErrorInvalidURL still claimed by the host handler.
- (void)testHostConnectionError_SFOAuthInvalidURL {
    SFSDKAuthErrorManager *errorManager = [[SFSDKAuthErrorManager alloc] init];
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] init];
    XCTAssertNotNil(errorManager);
    XCTestExpectation *expectation = [self expectationWithDescription:@"hostConnectionExpectation_SFOAuthInvalidURL"];
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain code:kSFOAuthErrorInvalidURL userInfo:userInfo];

    errorManager.hostConnectionErrorHandlerBlock = ^(NSError *e, SFSDKAuthSession *s, NSDictionary *o) {
        [expectation fulfill];
    };
    XCTAssertNotNil(errorManager.hostConnectionErrorHandlerBlock);
    BOOL handled = [errorManager processAuthError:error authContext:authSession options:userInfo];
    XCTAssertTrue(handled, @"kSFOAuthErrorInvalidURL should have been handled by the ErrorManager host connection handler");
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

// Unrelated NSURLErrorDomain codes are not host-connectivity — fall through to generic.
- (void)testGenericError_Cancelled {
    SFSDKAuthErrorManager *errorManager = [[SFSDKAuthErrorManager alloc] init];
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] init];
    XCTAssertNotNil(errorManager);
    XCTestExpectation *expectation = [self expectationWithDescription:@"genericErrorExpectation_Cancelled"];
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:userInfo];

    errorManager.hostConnectionErrorHandlerBlock = ^(NSError *e, SFSDKAuthSession *s, NSDictionary *o) {
        XCTFail(@"Cancelled error must not be claimed by the host connection handler");
    };
    errorManager.genericErrorHandlerBlock = ^(NSError *e, SFSDKAuthSession *s, NSDictionary *o) {
        [expectation fulfill];
    };
    BOOL handled = [errorManager processAuthError:error authContext:authSession options:userInfo];
    XCTAssertTrue(handled, @"Cancelled error should have been handled by the generic handler");
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testGenericError_UserAuthRequired {
    SFSDKAuthErrorManager *errorManager = [[SFSDKAuthErrorManager alloc] init];
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] init];
    XCTAssertNotNil(errorManager);
    XCTestExpectation *expectation = [self expectationWithDescription:@"genericErrorExpectation_UserAuthRequired"];
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUserAuthenticationRequired userInfo:userInfo];

    errorManager.hostConnectionErrorHandlerBlock = ^(NSError *e, SFSDKAuthSession *s, NSDictionary *o) {
        XCTFail(@"UserAuthenticationRequired must not be claimed by the host connection handler");
    };
    errorManager.genericErrorHandlerBlock = ^(NSError *e, SFSDKAuthSession *s, NSDictionary *o) {
        [expectation fulfill];
    };
    BOOL handled = [errorManager processAuthError:error authContext:authSession options:userInfo];
    XCTAssertTrue(handled, @"UserAuthenticationRequired error should have been handled by the generic handler");
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

// kSFOAuthErrorInvalidGrant must not be claimed by the host connection handler.
- (void)testHostConnectionDoesNotClaim_SFOAuthInvalidGrant {
    SFSDKAuthErrorManager *errorManager = [[SFSDKAuthErrorManager alloc] init];
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] init];
    XCTAssertNotNil(errorManager);
    XCTestExpectation *expectation = [self expectationWithDescription:@"invalidGrantExpectation"];
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain code:kSFOAuthErrorInvalidGrant userInfo:userInfo];

    errorManager.hostConnectionErrorHandlerBlock = ^(NSError *e, SFSDKAuthSession *s, NSDictionary *o) {
        XCTFail(@"kSFOAuthErrorInvalidGrant must not be claimed by the host connection handler");
    };
    errorManager.invalidAuthCredentialsErrorHandlerBlock = ^(NSError *e, SFSDKAuthSession *s, NSDictionary *o) {
        [expectation fulfill];
    };
    BOOL handled = [errorManager processAuthError:error authContext:authSession options:userInfo];
    XCTAssertTrue(handled, @"kSFOAuthErrorInvalidGrant should have been handled by the invalid credentials handler");
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

// On a Refresh flow with an existing access token, the network handler still
// claims -1001 TimedOut before the host connection handler sees it.
- (void)testNetworkFailureClaimsFirst_RefreshWithToken {
    SFSDKAuthErrorManager *errorManager = [[SFSDKAuthErrorManager alloc] init];

    SFOAuthCredentials *credentials = [TestSetupUtils newClientCredentials];
    credentials.accessToken = @"__ACCESS_TOKEN__";
    credentials.refreshToken = @"__REFRESH_TOKEN__";
    credentials.userId = @"USER123";
    credentials.organizationId = @"ORG123";

    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:credentials];
    [[SFUserAccountManager sharedInstance] saveAccountForUser:account error:nil];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:account];
    SFSDKAuthRequest *request = [[SFSDKAuthRequest alloc] init];
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:credentials spAppCredentials:nil];
    session.oauthCoordinator.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeRefresh];

    XCTAssertNotNil(errorManager);
    XCTestExpectation *networkErrorExpectation = [self expectationWithDescription:@"networkErrorExpectation_RefreshWithToken"];
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:userInfo];

    errorManager.networkErrorHandlerBlock = ^(NSError *e, SFSDKAuthSession *s, NSDictionary *o) {
        [networkErrorExpectation fulfill];
    };
    errorManager.hostConnectionErrorHandlerBlock = ^(NSError *e, SFSDKAuthSession *s, NSDictionary *o) {
        XCTFail(@"Host connection handler must not claim network errors on Refresh-with-token flows");
    };

    XCTAssertNotNil(errorManager.networkErrorHandlerBlock);
    BOOL handled = [errorManager processAuthError:error authContext:session options:userInfo];
    XCTAssertTrue(handled, @"Network Error Should have been handled by the ErrorManager on Refresh flow");
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:account error:nil];
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

@end
