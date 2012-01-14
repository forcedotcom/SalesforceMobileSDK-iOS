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

#import "AppDelegate.h"

#import "SalesforceHybridSDK/SalesforceOAuthPlugin.h"
#import "SalesforceHybridSDK/SFJsonUtils.h"


// Private constants
static NSString * const kOAuthPluginName = @"com.salesforce.oauth";


@implementation AppDelegate

#pragma mark - App lifecycle



+ (SFOAuthCredentials*)readCredentialsConfigFile {
    NSString *tokenPath = [[NSBundle bundleForClass:self] pathForResource:@"test_credentials" ofType:@"json"];
    NSAssert(nil != tokenPath,@"Test config file not found!");
    
    NSData *tokenJson = [[NSFileManager defaultManager] contentsAtPath:tokenPath];
    id jsonResponse = [SFJsonUtils objectFromJSONData:tokenJson];
    
    NSDictionary *dictResponse = (NSDictionary *)jsonResponse;
    NSString *accessToken = [dictResponse objectForKey:@"access_token"];
    NSString *refreshToken = [dictResponse objectForKey:@"refresh_token"];
    NSString *instanceUrl = [dictResponse objectForKey:@"instance_url"];
    
    //The following items MUST match the Remote Access object configuration from your sandbox test org
    NSString *clientID = [dictResponse objectForKey:@"test_client_id"];
    NSString *redirectUri = [dictResponse objectForKey:@"test_redirect_uri"];
    NSString *loginDomain = [dictResponse objectForKey:@"test_login_domain"];
    
    NSAssert1(nil != refreshToken &&
              nil != clientID &&
              nil != redirectUri &&
              nil != loginDomain &&
              nil != instanceUrl, @"config credentials are missing! %@",
              dictResponse);
    
    //check whether the test config file has never been edited
    NSAssert(![refreshToken isEqualToString:@"__INSERT_TOKEN_HERE__"],
             @"You need to obtain credentials for your test org and replace test_credentials.json");
    
    SFOAuthCredentials *credentials =
    [[SFOAuthCredentials alloc] initWithIdentifier:@"SalesforceSDKTests-DefaultAccount" clientId:clientID ];     
    credentials.domain = loginDomain;
    credentials.redirectUri = redirectUri; 
    credentials.instanceUrl = [NSURL URLWithString:instanceUrl];
    credentials.accessToken = accessToken;
    credentials.refreshToken = refreshToken;
    
    return [credentials autorelease];

}



- (void)applicationDidBecomeActive:(UIApplication *)application {
    _oauthPlugin = (SalesforceOAuthPlugin *)[[self getCommandInstance:kOAuthPluginName] retain];
    SFOAuthCredentials *creds = [[self class] readCredentialsConfigFile];
    
    //need to set this since bootconfig.js hasn't been loaded yet and
    //oauthplugin blows up if we subsequently set creds without it
    _oauthPlugin.remoteAccessConsumerKey = creds.clientId;
    
    [_oauthPlugin.coordinator setCredentials:creds];
    
    [super applicationDidBecomeActive:application];
    
    [self performSelectorOnMainThread:@selector(kickOffAllTests) withObject:nil waitUntilDone:NO];
}


- (NSString *)evalJS:(NSString*)js {
    SFContainerAppDelegate *myApp = [SFContainerAppDelegate sharedInstance];
    NSString *jsResult = [(UIWebView*)myApp.webView stringByEvaluatingJavaScriptFromString:js];
    return jsResult;
}

- (BOOL)areTestsFinishedRunning {    
    NSString *jsResult = [self evalJS:@"gTestsFinishedRunning === true"];
    return [jsResult isEqualToString:@"true"];
}

- (BOOL)waitForAllTestCompletions {
    NSDate *startTime = [NSDate date] ;
    BOOL completionTimedOut = NO;
    while (![self areTestsFinishedRunning]) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        if (elapsed > 30.0) {
            NSLog(@"request took too long (%f) to complete",elapsed);
            completionTimedOut = YES;
            break;
        }
        
        NSLog(@"## sleeping...");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
    }
    
    return completionTimedOut;
}

- (void)kickOffAllTests {
    BOOL timedOut = [self waitForAllTestCompletions];
    if (timedOut) 
        NSLog(@"timedOut ? : %d",timedOut);
    

    NSLog(@"Total Tests: %@  Passed: %@ Failed: %@",
          [self evalJS:@"gTestSuiteSmartStore.numTestsFinished"],
          [self evalJS:@"gTestSuiteSmartStore.numPassedTests"],
          [self evalJS:@"gTestSuiteSmartStore.this.numFailedTests"]
          );
          
    NSString *jsonify = [self evalJS:@"gTestSuiteSmartStore"];
    NSLog(@"json val: %@",jsonify);
    
    exit(0);
}

@end
