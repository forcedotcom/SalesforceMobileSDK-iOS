/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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

#import <SalesforceSDKCore/SalesforceSDKCore.h>

#import "CSFSalesforceOAuthRefresh.h"
#import "CSFAuthRefresh+Internal.h"
#import "CSFNetwork+Internal.h"

@interface RevokedTokenAuthRefresh : CSFSalesforceOAuthRefresh
@end
@implementation RevokedTokenAuthRefresh

- (void)refreshAuth {
    NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain
                                         code:kSFOAuthErrorInvalidGrant
                                     userInfo:@{ @"error": @"invalid_grant",
                                                 NSLocalizedDescriptionKey: @"expired access/refresh token" }];
    [self finishWithOutput:nil error:error];
}

@end

@interface TestRevokedTokenAction : CSFSalesforceAction
@end

@implementation TestRevokedTokenAction

- (BOOL)overrideRequest:(NSURLRequest *)request withResponseData:(NSData *__autoreleasing *)data andHTTPResponse:(NSHTTPURLResponse *__autoreleasing *)response {
    
    *data = [@"{\"message\":\"Session expired or invalid\",\"errorCode\":\"INVALID_SESSION_ID\"}" dataUsingEncoding:NSUTF8StringEncoding];
    *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                            statusCode:401
                                           HTTPVersion:@"1.1"
                                          headerFields:@{ @"Cache-Control": @"no-cache, no-store, no-cache, no-store",
                                                          @"Content-Type": @"application/json;charset=UTF-8",
                                                          @"Date": @"Fri, 31 Jul 2015 18:05:11 GMT, Fri, 31 Jul 2015 18:05:11 GMT",
                                                          @"Expires": @"Thu, 01 Jan 1970 00:00:00 GMT, Thu, 01 Jan 1970 00:00:00 GMT",
                                                          @"Pragma": @"no-cache, no-cache",
                                                          @"Set-Cookie": @"BrowserId=ZP_5ZOj8TC-vVic5Ca4LZw;Path=/;Domain=.salesforce.com;Expires=Tue, 29-Sep-2015 18:05:11 GMT, BrowserId=sJbAc1anRcqVwmAU6OmdlA;Path=/;Domain=.salesforce.com;Expires=Tue, 29-Sep-2015 18:05:11 GMT",
                                                          @"Transfer-Encoding": @"Identity" }];
    return YES;
}

@end

@interface CSFSalesforceOAuthRefreshTests : XCTestCase
@end

@implementation CSFSalesforceOAuthRefreshTests

- (void)testRevokedToken {
    SFUserAccount *user = [SFUserAccount new];
    user.credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"the-identifier"
                                                             clientId:@"the-client"
                                                            encrypted:NO
                                                          storageType:SFOAuthCredentialsStorageTypeNone];
    user.credentials.accessToken = @"AccessToken";
    user.credentials.refreshToken = @"RefreshToken";
    user.credentials.instanceUrl = [NSURL URLWithString:@"http://example.org"];
    user.credentials.identityUrl = [NSURL URLWithString:@"https://example.org/id/orgID/userID"];

    __block BOOL userLogoutNotificationReceived = NO;
    id handler = [[NSNotificationCenter defaultCenter] addObserverForName:kSFUserWillLogoutNotification
                                                                   object:nil
                                                                    queue:[NSOperationQueue currentQueue]
                                                               usingBlock:^(NSNotification *note) {
                                                                   userLogoutNotificationReceived = YES;
                                                               }];
    XCTestExpectation *revokedExpectation = [self expectationWithDescription:@"action revoked"];
    CSFNetwork *network = [[CSFNetwork alloc] initWithUserAccount:user];
    TestRevokedTokenAction *action = [[TestRevokedTokenAction alloc] initWithResponseBlock:^(CSFAction *action, NSError *error) {
        [revokedExpectation fulfill];
    }];
    action.url = [NSURL URLWithString:@"http://example.org/path/to/request"];
    action.authRefreshClass = [RevokedTokenAuthRefresh class];
    [network executeAction:action];
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        XCTAssertNil(error);
        
        XCTAssertTrue(userLogoutNotificationReceived);
        
        XCTAssertTrue([user isUserDeleted]);
        [[NSNotificationCenter defaultCenter] removeObserver:handler];
    }];
}

@end
