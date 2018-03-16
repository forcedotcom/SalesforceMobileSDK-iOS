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
#import "SalesforceSDKCoreDefines.h"
#import "SalesforceSDKManager.h"
#import "SFOAuthCoordinator.h"
#import "SFSDKOAuthClient.h"
#import "SFSDKWindowManager.h"
#import "SFOAuthCredentials.h"
#import "SFSDKOAuthClientConfig.h"
#import "SFSDKAuthPreferences.h"
#import "SalesforceSDKCore.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFSDKOAuthClientCache.h"
@class SFSDKTestOAuthClient;

@interface SFSDKTestOAuthClient : SFSDKOAuthClient
@property (nonatomic,assign) BOOL isIDPClient;
@property (nonatomic,assign) BOOL isAdvancedAuthClient;
@property (nonatomic,assign) BOOL isOAuthClient;
@property (nonatomic,assign) BOOL isTestingForErrorCallback;
@end


@interface TestUserSelectionNavViewController : UINavigationController <SFSDKUserSelectionView>
@property (nonatomic,weak) id<SFSDKUserSelectionViewDelegate> userSelectionDelegate;
@property (nonatomic,strong) NSDictionary *spAppOptions;
@end

@implementation TestUserSelectionNavViewController
@dynamic userSelectionDelegate;
@dynamic spAppOptions;
- (id <SFSDKUserSelectionViewDelegate>)userSelectionDelegate {
    return nil;
}

- (void)setUserSelectionDelegate:(id <SFSDKUserSelectionViewDelegate>)userSelectionDelegate {

}

- (NSDictionary *)spAppOptions {
    return nil;
}

- (void)setSpAppOptions:(NSDictionary *)spAppOptions {

}
@end


@interface TestIDPLoginNavViewController : UINavigationController <SFSDKLoginFlowSelectionView>
@property (weak,nonatomic) id <SFSDKLoginFlowSelectionViewDelegate> selectionFlowDelegate;
@end

@implementation TestIDPLoginNavViewController
@dynamic selectionFlowDelegate;
@synthesize appOptions;

@end


@interface SFSDKAuthClientTests : XCTestCase

@end

@interface SFSDKTestOAuthClientProvider : NSObject<SFSDKOAuthClientProvider>
@end

@implementation SFSDKTestOAuthClientProvider

+ (SFSDKOAuthClient *)idpAuthInstance:(SFSDKOAuthClientConfig *)config {
    SFSDKTestOAuthClient *client = [[SFSDKTestOAuthClient alloc] initWithConfig:config];
    client.isIDPClient = YES;
     return client;
}

+ (SFSDKOAuthClient *)nativeBrowserAuthInstance:(SFSDKOAuthClientConfig *)config {
    SFSDKTestOAuthClient *client = [[SFSDKTestOAuthClient alloc] initWithConfig:config];
    client.isAdvancedAuthClient = YES;
    return client;
}

+ (SFSDKOAuthClient *)webviewAuthInstance:(SFSDKOAuthClientConfig *)config {
    SFSDKTestOAuthClient *client = [[SFSDKTestOAuthClient alloc] initWithConfig:config];
    client.isOAuthClient = YES;
    return client;
}
@end


@implementation SFSDKTestOAuthClient
@dynamic coordinator;
@dynamic idCoordinator;
- (instancetype)initWithConfig:(SFSDKOAuthClientConfig *)config {
    self = [super initWithConfig:config];
    return self;
}

- (void)revokeRefreshToken:(SFOAuthCredentials *)credentials
{
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
}

@end


@interface SFSDKAuthClientTests()<SFSDKOAuthClientDelegate,SFSDKOAuthClientSafariViewDelegate,SFOAuthCoordinatorFlow>{
    Class<SFSDKOAuthClientProvider> _originalProvider;
    SFSDKTestOAuthClient *_currentClient;
    XCTestExpectation *_willBeginExpectation;
    XCTestExpectation *_didFinishExpectation;
    XCTestExpectation *_errorExpectation;
    XCTestExpectation *_refreshFlowExpectation;
    XCTestExpectation *_willRevokeExpectation;
    XCTestExpectation *_didRevokeExpectation;
}
@end


@implementation SFSDKAuthClientTests

- (void)setUp {
    [super setUp];
    _originalProvider = SFSDKOAuthClient.clientProvider;
    [SFSDKOAuthClient setClientProvider:SFSDKTestOAuthClientProvider.class];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [SFSDKOAuthClient setClientProvider:_originalProvider];
    [SFUserAccountManager sharedInstance].idpAppURIScheme = nil;
    [SFUserAccountManager sharedInstance].isIdentityProvider = NO;
    [SFUserAccountManager sharedInstance].advancedAuthConfiguration = SFOAuthTypeUserAgent;
    [super tearDown];
}

- (void)testFactoryMethodIDP {
    
   SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    credentials.accessToken = nil;
    credentials.refreshToken = nil;

    
   SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig * config) {
       config.idpAppURIScheme = @"idpApp";
   }];
    
   XCTAssertNotNil(client);
   XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
   XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
   
   SFSDKTestOAuthClient *testClient = (SFSDKTestOAuthClient *)client;
   XCTAssertTrue(testClient.isIDPClient,@"Client should be an instance of idp auth");
    
}

- (void)testFactoryMethodAdv {
    
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    credentials.accessToken = nil;
    credentials.refreshToken = nil;

    
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig *config) {
        config.advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    }];
    
    XCTAssertNotNil(client);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    
    SFSDKTestOAuthClient *testClient = (SFSDKTestOAuthClient *)client;
    XCTAssertTrue(testClient.isAdvancedAuthClient,@"Client should be an instance of idp auth");
    
}

- (void)testFactoryMethod {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    credentials.accessToken = nil;
    credentials.refreshToken = nil;

    
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig * config) {
    }];
    
    XCTAssertNotNil(client);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    
    SFSDKTestOAuthClient *testClient = (SFSDKTestOAuthClient *)client;
    XCTAssertTrue(testClient.isOAuthClient,@"Client should be a regular auth client");
    
}

- (void)testOAuthCordinatorCreated {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    credentials.accessToken = nil;
    credentials.refreshToken = nil;

    
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig * config) {
    }];
    
    XCTAssertNotNil(client);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    SFSDKTestOAuthClient *testClient = (SFSDKTestOAuthClient *)client;
    XCTAssertNotNil(testClient.coordinator,@"coordinator should not be null");
    XCTAssertNotNil(testClient.idCoordinator,@"idCoordinator should not be null");
    XCTAssertNotNil(testClient.config,@"Config should not be null");

    XCTAssertNotNil(testClient.context,@"Context should not be null");
    XCTAssertNotNil(testClient.context.credentials,@"Credentials should not be null");
}


- (void)testPreferencesIDP {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    credentials.accessToken = nil;
    credentials.refreshToken = nil;

    SFSDKAuthPreferences *prefs = [[SFSDKAuthPreferences alloc] init];
    [SalesforceSDKManager sharedManager].idpAppURIScheme = @"idpApp";
    [SalesforceSDKManager sharedManager].isIdentityProvider = NO;
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig * config) {
         config.idpAppURIScheme = prefs.idpAppURIScheme;
    }];
    XCTAssertNotNil(client);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    SFSDKTestOAuthClient *testClient = (SFSDKTestOAuthClient *)client;
    XCTAssertTrue(testClient.isIDPClient,@"Client should be a an IDP client when enabled through SDKManager");
}

- (void)testPreferencesProvider {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    SFSDKAuthPreferences *prefs = [[SFSDKAuthPreferences alloc] init];
    credentials.accessToken = nil;
    credentials.refreshToken = nil;

    [SalesforceSDKManager sharedManager].isIdentityProvider = YES;
    [SalesforceSDKManager sharedManager].idpAppURIScheme = @"idpApp";
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig * config) {
        config.isIdentityProvider = prefs.isIdentityProvider;
    }];

    XCTAssertNotNil(client);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    SFSDKTestOAuthClient *testClient = (SFSDKTestOAuthClient *)client;
    XCTAssertTrue(testClient.isIDPClient,@"Client should be a an IDP client when enabled through SDKManager");
    prefs.isIdentityProvider = NO;
    XCTAssertFalse(prefs.isIdentityProvider,@"Preferences for isIdentityProvider should be set to false");
}

- (void)testSettingOfUserSelectionBlock {
    
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    SFSDKAuthPreferences *prefs = [[SFSDKAuthPreferences alloc] init];
    credentials.accessToken = nil;
    credentials.refreshToken = nil;

    [SalesforceSDKManager sharedManager].isIdentityProvider = YES;
    [SalesforceSDKManager sharedManager].idpAppURIScheme = @"idpApp";
    
    [SalesforceSDKManager sharedManager].idpUserSelectionBlock = ^UIViewController<SFSDKUserSelectionView> * {
         TestUserSelectionNavViewController *userSelectionNavViewController = [[TestUserSelectionNavViewController alloc] init];
         return userSelectionNavViewController;
    };
    
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig * config) {
        config.isIdentityProvider = prefs.isIdentityProvider;
        config.idpUserSelectionBlock = [SFUserAccountManager sharedInstance].idpUserSelectionAction;
    }];
    
    XCTAssertNotNil(client);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    SFSDKTestOAuthClient *testClient = (SFSDKTestOAuthClient *)client;
    XCTAssertTrue(testClient.isIDPClient,@"Client should be a an IDP client when enabled through SDKManager");

    XCTAssertNotNil(testClient.config.idpUserSelectionBlock,@"User Selectio nblock should not be nil");
    
    UIViewController *ctrl = testClient.config.idpUserSelectionBlock();
    
    XCTAssertTrue([ctrl isKindOfClass:[TestUserSelectionNavViewController class]],@"User Selection block shouldhave been customized");

    prefs.isIdentityProvider = NO;
    XCTAssertFalse(prefs.isIdentityProvider,@"Preferences for isIdentityProvider should be set to false");
}

- (void)testSettingOfLoginFlowSelectionBlock {
    
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    SFSDKAuthPreferences *prefs = [[SFSDKAuthPreferences alloc] init];
    credentials.accessToken = nil;
    credentials.refreshToken = nil;

    [SalesforceSDKManager sharedManager].isIdentityProvider = YES;
    [SalesforceSDKManager sharedManager].idpAppURIScheme = @"idpApp";

    [SalesforceSDKManager sharedManager].idpLoginFlowSelectionBlock = ^UIViewController<SFSDKLoginFlowSelectionView> * {
        TestIDPLoginNavViewController *idpLoginViewController = [[TestIDPLoginNavViewController alloc] init];
        return idpLoginViewController;
    };

    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig * config) {
        config.isIdentityProvider = prefs.isIdentityProvider;
        config.idpLoginFlowSelectionBlock = [SFUserAccountManager sharedInstance].idpLoginFlowSelectionAction;
    }];
    
    XCTAssertNotNil(client);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    SFSDKTestOAuthClient *testClient = (SFSDKTestOAuthClient *)client;
    XCTAssertTrue(testClient.isIDPClient,@"Client should be a an IDP client when enabled through SDKManager");
    prefs.isIdentityProvider = NO;
    XCTAssertFalse(prefs.isIdentityProvider,@"Preferences for isIdentityProvider should be set to false");
}

- (void)testOAuthClientDidBeginCallback {
    
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    credentials.accessToken = nil;
    credentials.refreshToken = nil;

    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig * config) {
        config.delegate = self;
    }];
    
    XCTAssertNotNil(client);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    
    SFSDKTestOAuthClient *testClient = (SFSDKTestOAuthClient *)client;
   
    [testClient.coordinator setOauthCoordinatorFlow:self];
    _willBeginExpectation = [self expectationWithDescription:@"willStartAuth"];
    [testClient refreshCredentials];
    [self waitForExpectationsWithTimeout:20.0 handler:nil];

}

- (void)testOAuthClientDidFinishCallback {

    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    credentials.accessToken = nil;
    credentials.refreshToken = nil;

    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig * config) {
        config.delegate = self;
    }];

    XCTAssertNotNil(client);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    SFSDKTestOAuthClient *testClient = (SFSDKTestOAuthClient *)client;
    _currentClient = testClient;
    [client.coordinator setOauthCoordinatorFlow:self];
    _willBeginExpectation = [self expectationWithDescription:@"willStartAuth"];
    _didFinishExpectation = [self expectationWithDescription:@"willFinish"];

    [client refreshCredentials];
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testOAuthClientErrorCallback {

    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    credentials.accessToken = nil;
    credentials.refreshToken = nil;
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig * config) {
        config.delegate = self;
    }];

    XCTAssertNotNil(client);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    SFSDKTestOAuthClient *testClient = (SFSDKTestOAuthClient *)client;
    _currentClient = testClient;
    _currentClient.isTestingForErrorCallback = YES;
    [client.coordinator setOauthCoordinatorFlow:self];
    _willBeginExpectation = [self expectationWithDescription:@"willStartAuth"];
    _errorExpectation = [self expectationWithDescription:@"error"];

    [client refreshCredentials];
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testOAuthClientRefreshFlowCallback {
    
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    credentials.accessToken = @"MY_ACCESS_TOKEN";
    credentials.refreshToken = @"MY_REFRESH_TOKEN";
    
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig * config) {
        config.delegate = self;
    }];
    
    XCTAssertNotNil(client);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    SFSDKTestOAuthClient *testClient = (SFSDKTestOAuthClient *)client;
    _currentClient = testClient;
    [client.coordinator setOauthCoordinatorFlow:self];
    _willBeginExpectation = [self expectationWithDescription:@"willStartAuth"];
    _refreshFlowExpectation = [self expectationWithDescription:@"willTrigerRefreshFlow"];
    
    [client refreshCredentials];
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testOAuthClientRevokeCallback {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    credentials.accessToken = @"MY_ACCESS_TOKEN";
    credentials.refreshToken = @"MY_REFRESH_TOKEN";
   
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig * config) {
        config.delegate = self;
    }];
    
    XCTAssertNotNil(client);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    SFSDKTestOAuthClient *testClient = (SFSDKTestOAuthClient *)client;
    _currentClient = testClient;
    [client.coordinator setOauthCoordinatorFlow:self];
    _willRevokeExpectation = [self expectationWithDescription:@"willTrigerRevokeFlow"];
    _didRevokeExpectation = [self expectationWithDescription:@"willTrigerRevokeFlow"];
    [client revokeCredentials];
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

- (void)testOAuthClientNativeBrowserCallback {
   
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testId" clientId:@"testId" encrypted:NO];
    credentials.accessToken = nil;
    credentials.refreshToken = nil;

    
    [SFUserAccountManager sharedInstance].advancedAuthConfiguration = SFOAuthAdvancedAuthConfigurationRequire;
    
    
    SFSDKOAuthClient *client = [SFSDKOAuthClient clientWithCredentials:credentials  configBlock:^(SFSDKOAuthClientConfig * config) {
        config.delegate = self;
        config.safariViewDelegate = self;
        config.advancedAuthConfiguration = [SFUserAccountManager sharedInstance].advancedAuthConfiguration;
    }];
   
    XCTAssertNotNil(client);
    XCTAssertTrue([client isKindOfClass:[SFSDKTestOAuthClient class]]);
    SFSDKTestOAuthClient *testClient = (SFSDKTestOAuthClient *)client;
    _currentClient = testClient;
    [client.coordinator setOauthCoordinatorFlow:self];
    
    _willBeginExpectation = [self expectationWithDescription:@"willStartAuth"];
    _didFinishExpectation = [self expectationWithDescription:@"finishedAuth"];
    
    [client refreshCredentials];
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
}

#pragma mark - SFSDKOAuthClientDelegate

- (void)authClientWillBeginAuthentication:(SFSDKOAuthClient *)client {
    [_willBeginExpectation fulfill];
}

- (void)authClientDidFail:(SFSDKOAuthClient *)client error:(NSError *_Nullable)error {
    if(_errorExpectation)
       [_errorExpectation fulfill];
}

- (BOOL)authClientIsNetworkAvailable:(SFSDKOAuthClient *)client {
    return YES;
}

- (void)authClientDidFinish:(SFSDKOAuthClient *)client {
   [_didFinishExpectation fulfill];
}

- (void)authClientWillRefreshCredentials:(SFSDKOAuthClient *)client {
   [_refreshFlowExpectation fulfill];
}


- (void)authClientWillRevokeCredentials:(SFSDKOAuthClient *)client {
    [_willRevokeExpectation fulfill];

}

- (void)authClientDidRevokeCredentials:(SFSDKOAuthClient *)client {
    [_didRevokeExpectation fulfill];

}

#pragma mark - SFSDKOAuthClientSafariViewDelegate

- (void)authClientDidProceedWithBrowserFlow:(SFSDKOAuthClient *)client {
 [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
}

- (void)authClientDidCancelBrowserFlow:(SFSDKOAuthClient *)client {
 [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
}

- (void)authClient:(SFSDKOAuthClient *)client willDisplayAuthSafariViewController:(SFSafariViewController *_Nonnull)svc {
 [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
}

- (void)authClientDidCancelGenericFlow:(SFSDKOAuthClient *)client {
 [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
}

- (void)authClient:(SFSDKOAuthClient * _Nonnull)client displayMessage:(nonnull SFSDKAlertMessage *)message { 
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
}

#pragma mark SFOAuthCoordinatorFlow
- (void)beginUserAgentFlow {
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    if (!self->_currentClient.isTestingForErrorCallback) {
        [_currentClient.coordinator handleUserAgentResponse:[self userAgentSuccessUrl]];
    }else {
         [_currentClient.coordinator handleUserAgentResponse:[self userAgentErrorUrl]];
    }
        
}

- (void)beginTokenEndpointFlow:(SFOAuthTokenEndpointFlow)flowType {
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!self->_currentClient.isTestingForErrorCallback) {
                [self->_currentClient.coordinator handleTokenEndpointResponse:[self refreshTokenSuccessData]];
            }else {
                [self->_currentClient.coordinator handleTokenEndpointResponse:[self refreshTokenErrorData]];
            }
    });
}

- (void)beginJwtTokenExchangeFlow {
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
}

- (void)beginNativeBrowserFlow {
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self->_currentClient.isTestingForErrorCallback) {
            [self->_currentClient.coordinator handleTokenEndpointResponse:[self refreshTokenSuccessData]];
        }else {
            [self->_currentClient.coordinator handleTokenEndpointResponse:[self refreshTokenErrorData]];
        }
    });
}

- (void)handleTokenEndpointResponse:(NSMutableData *) data{
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"%@ called.", NSStringFromSelector(_cmd)];
  
}

# pragma private methods

- (NSURL *)userAgentSuccessUrl{
    NSString *successFormatString = @"%@#access_token=%@&issued_at=%@&instance_url=%@&id=%@";
    NSString *successUrl = [NSString stringWithFormat:successFormatString,
                            _currentClient.coordinator.credentials.redirectUri,
                            @"some_access_token_val",
                            @(1418945872705),
                            [@"https://na1.salesforce.com" stringByURLEncoding],
                            [@"https://login.salesforce.com/id/some_org_id/some_user_id" stringByURLEncoding]
                            ];
    return [NSURL URLWithString:successUrl];
}

- (NSURL *)userAgentErrorUrl{
    NSString *errorFormatString = @"%@#error=%@&error_description=%@";
    NSString *errorUrl = [NSString stringWithFormat:errorFormatString,
                          _currentClient.coordinator.credentials.redirectUri,
                          @"user_agent_flow_error_from_unit_test",
                          [@"User agent flow error from unit test" stringByURLEncoding]
                          ];
    return [NSURL URLWithString:errorUrl];
}

- (NSMutableData *)refreshTokenSuccessData  {
    NSString *successFormatString = @"{\"id\":\"%@\",\"issued_at\":\"%@\",\"instance_url\":\"%@\",\"access_token\":\"%@\"}";
    NSString *successDataString = [NSString stringWithFormat:successFormatString,
                                   _currentClient.coordinator.credentials.redirectUri,
                                   [@"https://login.salesforce.com/id/some_org_id/some_user_id" stringByURLEncoding],
                                   @(1418945872705),
                                   [@"https://na1.salesforce.com" stringByURLEncoding],
                                   @"some_access_token"];
    NSData *data = [successDataString dataUsingEncoding:NSUTF8StringEncoding];
    return [data mutableCopy];
}

- (NSMutableData *)refreshTokenErrorData {
    NSString *errorFormatString = @"{\"error\":\"%@\",\"error_description\":\"%@\"}";
    NSString *errorDataString = [NSString stringWithFormat:errorFormatString,
                                 _currentClient.coordinator.credentials.redirectUri,
                                 @"refresh_token_flow_error_from_unit_test",
                                 [@"Refresh token flow error from unit test" stringByURLEncoding]
                                 ];
    NSData *data = [errorDataString dataUsingEncoding:NSUTF8StringEncoding];
    return [data mutableCopy];
}


@end
