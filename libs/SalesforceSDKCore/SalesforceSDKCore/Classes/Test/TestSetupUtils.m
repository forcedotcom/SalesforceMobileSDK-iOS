/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

#import "TestSetupUtils.h"

#import "SFJsonUtils.h"

#import <SalesforceOAuth/SFOAuthCoordinator.h>
#import <SalesforceOAuth/SFOAuthCredentials.h>
#import "SFAuthenticationManager.h"
#import "SFUserAccountManager.h"
#import "SFUserAccount.h"
#import "SFSDKTestRequestListener.h"
#import "SFSDKTestCredentialsData.h"

static BOOL sPopulatedAuthCredentials = NO;

@implementation TestSetupUtils

+ (SFSDKTestCredentialsData *)populateAuthCredentialsFromConfigFile
{
    NSString *tokenPath = [[NSBundle bundleForClass:self] pathForResource:@"test_credentials" ofType:@"json"];
    NSAssert(nil != tokenPath, @"Test config file not found!");
    
    NSData *tokenJson = [[NSFileManager defaultManager] contentsAtPath:tokenPath];
    id jsonResponse = [SFJsonUtils objectFromJSONData:tokenJson];
    NSAssert(jsonResponse != nil, @"Error parsing JSON from config file: %@", [SFJsonUtils lastError]);
    
    NSDictionary *dictResponse = (NSDictionary *)jsonResponse;
    SFSDKTestCredentialsData *credsData = [[SFSDKTestCredentialsData alloc] initWithDict:dictResponse];
    NSAssert1(nil != credsData.refreshToken &&
              nil != credsData.clientId &&
              nil != credsData.redirectUri &&
              nil != credsData.loginHost &&
              nil != credsData.instanceUrl, @"config credentials are missing! %@",
              dictResponse);

    //check whether the test config file has never been edited
    NSAssert(![credsData.refreshToken isEqualToString:@"__INSERT_TOKEN_HERE__"],
             @"You need to obtain credentials for your test org and replace test_credentials.json");
    
    [SFUserAccountManager sharedInstance].oauthClientId = credsData.clientId;
    [SFUserAccountManager sharedInstance].oauthCompletionUrl = credsData.redirectUri;
    [SFUserAccountManager sharedInstance].scopes = [NSSet setWithObjects:@"web", @"api", nil];
    [SFUserAccountManager sharedInstance].loginHost = credsData.loginHost;
    
    SFUserAccountManager *accountMgr = [SFUserAccountManager sharedInstance];
    SFUserAccount *account = [accountMgr createUserAccount];
    accountMgr.currentUser = account;
    SFOAuthCredentials *credentials = accountMgr.currentUser.credentials;
    credentials.instanceUrl = [NSURL URLWithString:credsData.instanceUrl];
    credentials.accessToken = credsData.accessToken;
    credentials.refreshToken = credsData.refreshToken;
    
    sPopulatedAuthCredentials = YES;
    return credsData;
}

+ (void)synchronousAuthRefresh
{
    // All of the setup and validation of prerequisite auth state is done in populateAuthCredentialsFromConfigFile.
    // Make sure that method has run before this one.
    NSAssert(sPopulatedAuthCredentials, @"You must call populateAuthCredentialsFromConfigFile before synchronousAuthRefresh");
    
    __block SFSDKTestRequestListener *authListener = [[SFSDKTestRequestListener alloc] init];
    [[SFAuthenticationManager sharedManager] loginWithCompletion:^(SFOAuthInfo *authInfo) {
        authListener.returnStatus = kTestRequestStatusDidLoad;
    } failure:^(SFOAuthInfo *authInfo, NSError *error) {
        authListener.lastError = error;
        authListener.returnStatus = kTestRequestStatusDidFail;
    }];
    [authListener waitForCompletion];
    NSAssert([authListener.returnStatus isEqualToString:kTestRequestStatusDidLoad], @"After auth attempt, expected status '%@', got '%@'",
              kTestRequestStatusDidLoad,
              authListener.returnStatus);
}

@end
