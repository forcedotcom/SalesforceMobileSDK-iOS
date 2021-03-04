/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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

#import <SalesforceSDKCommon/SFJsonUtils.h>
#import "SalesforceSDKManager+Internal.h"
#import "SFUserAccountManager.h"
#import "TestSetupUtils.h"
#import "SFUserAccountManager+Internal.h"
#import "SFUserAccount.h"
#import "SFSDKTestRequestListener.h"
#import "SFSDKTestCredentialsData.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFSDKAppConfig.h"
static SFOAuthCredentials *credentials = nil;

@implementation TestSetupUtils

+ (NSArray *)populateUILoginInfoFromConfigFileForClass:(Class)testClass
{
    NSString *tokenPath = [[NSBundle bundleForClass:testClass] pathForResource:@"ui_test_credentials" ofType:@"json"];
    NSAssert(nil != tokenPath, @"UI test config file not found!");
    NSFileManager *fm = [NSFileManager defaultManager];
    NSData *jsonData = [fm contentsAtPath:tokenPath];
    NSArray *jsonDataArray = [[NSArray alloc] initWithArray:[SFJsonUtils objectFromJSONData:jsonData]];
    NSAssert(jsonDataArray != nil, @"Error parsing JSON from config file: %@", [SFJsonUtils lastError]);
    return jsonDataArray;
}

+ (SFSDKTestCredentialsData *)populateAuthCredentialsFromConfigFileForClass:(Class)testClass
{
    NSString *tokenPath = [[NSBundle bundleForClass:testClass] pathForResource:@"test_credentials" ofType:@"json"];
    NSAssert(nil != tokenPath, @"Test config file not found!");
    NSFileManager *fm = [NSFileManager defaultManager];
    NSData *tokenJson = [fm contentsAtPath:tokenPath];
    id jsonResponse = [SFJsonUtils objectFromJSONData:tokenJson];
    NSAssert(jsonResponse != nil, @"Error parsing JSON from config file: %@", [SFJsonUtils lastError]);
    NSDictionary *dictResponse = (NSDictionary *)jsonResponse;
    SFSDKTestCredentialsData *credsData = [[SFSDKTestCredentialsData alloc] initWithDict:dictResponse];
    NSAssert1(nil != credsData.refreshToken &&
              nil != credsData.clientId &&
              nil != credsData.redirectUri &&
              nil != credsData.loginHost &&
              nil != credsData.identityUrl &&
              nil != credsData.instanceUrl, @"config credentials are missing! %@",
              dictResponse);

    // check whether the test config file has never been edited
    NSAssert(![credsData.refreshToken isEqualToString:@"__INSERT_TOKEN_HERE__"],
             @"You need to obtain credentials for your test org and replace test_credentials.json");
    [SalesforceSDKManager initializeSDK];

    // Note: We need to fix this inconsistency for tests in the long run.There should be a clean way to refresh appConfigs for tests. The configs should apply across all components that need the  config.
    SFSDKAppConfig *appconfig  = [[SFSDKAppConfig alloc] init];
    appconfig.oauthRedirectURI = credsData.redirectUri;
    appconfig.remoteAccessConsumerKey = credsData.clientId;
    appconfig.oauthScopes = [NSSet setWithObjects:@"web", @"api", @"openid", nil];
    [SalesforceSDKManager sharedManager].appConfig = appconfig;
    [SFUserAccountManager sharedInstance].oauthClientId = credsData.clientId;
    [SFUserAccountManager sharedInstance].oauthCompletionUrl = credsData.redirectUri;
    [SFUserAccountManager sharedInstance].scopes = [NSSet setWithObjects:@"web", @"api", nil];
    [SFUserAccountManager sharedInstance].loginHost = credsData.loginHost;
    credentials = [self newClientCredentials];
    credentials.instanceUrl = [NSURL URLWithString:credsData.instanceUrl];
    credentials.identityUrl = [NSURL URLWithString:credsData.identityUrl];
    NSString *communityUrlString = credsData.communityUrl;
    if (communityUrlString.length > 0) {
        credentials.communityUrl = [NSURL URLWithString:communityUrlString];
    }
    credentials.accessToken = credsData.accessToken;
    credentials.refreshToken = credsData.refreshToken;
    [[SFUserAccountManager sharedInstance] currentUser].credentials = credentials;
    return credsData;
}

+ (void)synchronousAuthRefresh
{
    // All of the setup and validation of prerequisite auth state is done in populateAuthCredentialsFromConfigFile.
    // Make sure that method has run before this one.
    NSAssert(credentials!=nil, @"You must call populateAuthCredentialsFromConfigFileForClass before synchronousAuthRefresh");
    __block SFSDKTestRequestListener *authListener = [[SFSDKTestRequestListener alloc] init];
    __block SFUserAccount *user = nil;
    [[SFUserAccountManager sharedInstance]
     refreshCredentials:credentials
     completion:^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
         authListener.returnStatus = kTestRequestStatusDidLoad;
         user = userAccount;
         // Ensure tests don't change/corrupt the current user credentials.  
         if(user.credentials.refreshToken == nil) {
             user.credentials = credentials;
         }
     } failure:^(SFOAuthInfo *authInfo, NSError *error) {
         authListener.lastError = error;
         authListener.returnStatus = kTestRequestStatusDidFail;
     }];
    [authListener waitForCompletion];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:user];
    NSAssert([authListener.returnStatus isEqualToString:kTestRequestStatusDidLoad], @"After auth attempt, expected status '%@', got '%@'",
             kTestRequestStatusDidLoad,
             authListener.returnStatus);
}

+ (SFOAuthCredentials *)newClientCredentials {
    
    NSString *identifier = [[SFUserAccountManager sharedInstance]  uniqueUserAccountIdentifier:[SFUserAccountManager sharedInstance].oauthClientId];
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:identifier clientId:[SFUserAccountManager sharedInstance].oauthClientId encrypted:YES];
    creds.clientId = [SFUserAccountManager sharedInstance].oauthClientId;
    creds.redirectUri = [SFUserAccountManager sharedInstance].oauthCompletionUrl;
    creds.domain = [SFUserAccountManager sharedInstance].loginHost;
    creds.accessToken = nil;
    return creds;
}
@end
