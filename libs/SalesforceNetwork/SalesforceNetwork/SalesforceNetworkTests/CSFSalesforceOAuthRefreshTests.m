//
//  CSFSalesforceOAuthRefreshTests.m
//  SalesforceNetwork
//
//  Created by Michael Nachbaur on 7/31/15.
//  Copyright (c) 2015 salesforce.com. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import <SalesforceNetwork/SalesforceNetwork.h>

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
