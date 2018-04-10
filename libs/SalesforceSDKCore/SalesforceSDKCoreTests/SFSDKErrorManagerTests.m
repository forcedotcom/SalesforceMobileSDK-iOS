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
#import "SFOAuthCoordinator.h"
#import "SFUserAccountManager+Internal.h"
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
    [SFUserAccountManager sharedInstance].currentUser = _origCurrentUser;
}

- (void)testNetworkError {
    SFSDKAuthErrorManager *errorManager = [[SFSDKAuthErrorManager alloc] init];
   
    SFOAuthCredentials *credentials = [[SFUserAccountManager sharedInstance] newClientCredentials];
    credentials.accessToken = @"__ACCESS_TOKEN__";
    credentials.refreshToken = @"__REFRESH_TOKEN__";
    credentials.userId = @"USER123";
    credentials.organizationId = @"ORG123";
    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:credentials];
    [[SFUserAccountManager sharedInstance] saveAccountForUser:account error:nil];
    
    [SFUserAccountManager sharedInstance].currentUser = account;
    XCTAssertNotNil(errorManager);
    XCTestExpectation *networkErrorExpectation =  [self expectationWithDescription:@"networkErrorExpectation"];
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:userInfo];
    
    errorManager.networkErrorHandlerBlock = ^(NSError * error, SFOAuthInfo * authInfo, NSDictionary *options) {
        [networkErrorExpectation fulfill];
    };
    
    SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeRefresh];
    XCTAssertNotNil(errorManager.networkErrorHandlerBlock);
    BOOL handled = [errorManager processAuthError:error authInfo:authInfo options:userInfo];
    XCTAssertTrue(handled,@"Network Error Should have been handled by the ErrorManager");
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:account error:nil];
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testAuthError {
    
    SFSDKAuthErrorManager *errorManager = [[SFSDKAuthErrorManager alloc] init];
    XCTAssertNotNil(errorManager);
    XCTestExpectation *errorExpectation =  [self expectationWithDescription:@"authErrorExpectation"];
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain code:kSFOAuthErrorInvalidGrant userInfo:userInfo];
    
    errorManager.invalidAuthCredentialsErrorHandlerBlock = ^(NSError * error, SFOAuthInfo * authInfo, NSDictionary *options) {
        [errorExpectation fulfill];
    };
    SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent];
    XCTAssertNotNil(errorManager.invalidAuthCredentialsErrorHandlerBlock);
    BOOL handled = [errorManager processAuthError:error authInfo:authInfo options:userInfo];
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
    XCTAssertNotNil(errorManager);
    XCTestExpectation *errorExpectation =  [self expectationWithDescription:@"connectedAppVersionMismatchErrorExpectation"];
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain code:kSFOAuthErrorWrongVersion userInfo:userInfo];
    
    errorManager.connectedAppVersionMismatchErrorHandlerBlock  = ^(NSError * error, SFOAuthInfo * authInfo, NSDictionary *options) {
        [errorExpectation fulfill];
    };
    SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent];
    XCTAssertNotNil(errorManager.connectedAppVersionMismatchErrorHandlerBlock);
    BOOL handled = [errorManager processAuthError:error authInfo:authInfo options:userInfo];
    XCTAssertTrue(handled,@"Connected app version mismatch should have been handled by the ErrorManager");
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testGenericError {
    SFSDKAuthErrorManager *errorManager = [[SFSDKAuthErrorManager alloc] init];
    XCTAssertNotNil(errorManager);
    XCTestExpectation *errorExpectation =  [self expectationWithDescription:@"genericErrorExpectation"];
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    NSError *error = [NSError errorWithDomain:@"someError" code:-999 userInfo:userInfo];
    
    errorManager.genericErrorHandlerBlock  = ^(NSError * error, SFOAuthInfo * authInfo, NSDictionary *options) {
        [errorExpectation fulfill];
    };
    
    SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent];
    XCTAssertNotNil(errorManager.genericErrorHandlerBlock);
    BOOL handled = [errorManager processAuthError:error authInfo:authInfo options:userInfo];
    XCTAssertTrue(handled,@"Generic Error should have been handled by the ErrorManager");
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

@end
