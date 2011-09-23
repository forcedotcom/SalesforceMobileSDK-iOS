/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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

//TODO use builtin framework if available
#import "SBJSON.h"
#import "SBJsonParser.h"

#import "SFOAuthCoordinator.h"
#import "SFOAuthCredentials.h"
#import "SFRestAPI+Internal.h"

@implementation TestSetupUtils


+ (void)ensureCredentialsLoaded {
    if (nil == [[SFRestAPI sharedInstance] coordinator]) {
        [self readCredentialsConfigFile];
    }
}

/**
 Forces a reload of authorization credentials from the configuration file.
 Normally you'd call ensureCredentialsLoaded unless you wish to force a reload.
 @see ensureCredentialsLoaded
 */
+ (void)readCredentialsConfigFile {
    NSString *tokenPath = [[NSBundle bundleForClass:self] pathForResource:@"test_credentials" ofType:@"json"];
    NSData *tokenJson = [[NSFileManager defaultManager] contentsAtPath:tokenPath];
    
    SBJsonParser *parser = [[SBJsonParser alloc] init];
    id jsonResponse = [parser objectWithData:tokenJson];
    [parser release];
    
    NSDictionary *dictResponse = (NSDictionary *)jsonResponse;
    NSString *accessToken = [dictResponse objectForKey:@"access_token"];
    NSString *refreshToken = [dictResponse objectForKey:@"refresh_token"];
    NSString *instanceUrl = [dictResponse objectForKey:@"instance_url"];
    
    //The following two items MUST match the Remote Access object configuration from your sandbox test org
    NSString *clientID = [dictResponse objectForKey:@"test_client_id"];
    NSString *redirectUri = [dictResponse objectForKey:@"test_redirect_uri"];
    
    NSAssert1(nil != refreshToken &&
              nil != clientID &&
              nil != redirectUri &&
              nil != instanceUrl, @"config credentials are missing! %@",
              dictResponse);

    NSURL *fullInstanceUrl = [NSURL URLWithString:instanceUrl];
    
    SFOAuthCredentials *credentials =
    [[SFOAuthCredentials alloc] initWithIdentifier:clientID];
    credentials.domain = [fullInstanceUrl host];
    credentials.redirectUri = redirectUri; 
    credentials.instanceUrl = [NSURL URLWithString:instanceUrl];
    credentials.accessToken = accessToken;
    credentials.refreshToken = refreshToken;
    
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:credentials];
    [credentials release];
    
    [[SFRestAPI sharedInstance] setCoordinator:coordinator];
    [coordinator release];
}

@end
