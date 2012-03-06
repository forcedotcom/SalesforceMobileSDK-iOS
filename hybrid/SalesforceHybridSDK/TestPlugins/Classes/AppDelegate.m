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

#import "SFTestRunnerPlugin.h"

//redeclare functions required for code coverage
FILE *fopen$UNIX2003(const char *filename, const char *mode);
size_t fwrite$UNIX2003(const void *a, size_t b, size_t c, FILE *d);


@interface AppDelegate (Private)

/// Was the app started in Test mode? 
- (BOOL) isRunningOctest;



@end

@implementation AppDelegate

#pragma mark - App lifecycle



+ (SFOAuthCredentials*)readCredentialsConfigFile {
    NSString *tokenPath = [[NSBundle bundleForClass:self] pathForResource:@"test_credentials" ofType:@"json"];
    if (nil == tokenPath) {
        NSLog(@"Unable to read credentials file '%@'.  See unit testing instructions.",tokenPath);
        NSAssert(nil != tokenPath,@"test_credentials.json config file not found!");
    }
    
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
    [[SFOAuthCredentials alloc] initWithIdentifier:@"SalesforceSDKTests-DefaultAccount"
                                          clientId:clientID
                                         encrypted:YES
                            
     ];     

    credentials.domain = loginDomain;
    credentials.redirectUri = redirectUri; 
    credentials.instanceUrl = [NSURL URLWithString:instanceUrl];
    credentials.accessToken = accessToken;
    credentials.refreshToken = refreshToken;
    
    return [credentials autorelease];

}


- (BOOL) isRunningOctest
{
    BOOL result = NO;
    NSDictionary *processEnv = [[NSProcessInfo processInfo] environment];
    NSString *injectBundle = [processEnv valueForKey:@"XCInjectBundle"];
    NSLog(@"XCInjectBundle: %@", injectBundle);

    if (nil != injectBundle) {
        NSRange found = [injectBundle rangeOfString:@".octest"];
        if (NSNotFound != found.location) {
            result = YES;
        }
    }
    
    return result;
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    _oauthPlugin = (SalesforceOAuthPlugin *)[[self getCommandInstance:kSFOAuthPluginName] retain];
    SFOAuthCredentials *creds = [[self class] readCredentialsConfigFile];
    
    //need to set this since bootconfig.js hasn't been loaded yet and
    //oauthplugin blows up if we subsequently set creds without it
    _oauthPlugin.remoteAccessConsumerKey = creds.clientId;
    
    [_oauthPlugin.coordinator setCredentials:creds];
    

    [super applicationDidBecomeActive:application];
    
    SFTestRunnerPlugin *runner =  (SFTestRunnerPlugin*)[[SFContainerAppDelegate sharedInstance] getCommandInstance:kSFTestRunnerPluginName];
    NSLog(@"runner: %@",runner);
    
    BOOL runningOctest = [self isRunningOctest];
    NSLog(@"octest running: %d",runningOctest);
    
}


- (NSString *)evalJS:(NSString*)js {
    SFContainerAppDelegate *myApp = [SFContainerAppDelegate sharedInstance];
    NSString *jsResult = [(UIWebView*)myApp.webView stringByEvaluatingJavaScriptFromString:js];
    return jsResult;
}


@end


//The following are required for code coverage to work:
FILE *fopen$UNIX2003(const char *filename, const char *mode) {
    NSString *covFile = [NSString stringWithCString:filename encoding:NSUTF8StringEncoding];
    NSLog(@"saving coverage file: %@",covFile);
    return fopen(filename, mode);
}

size_t fwrite$UNIX2003(const void *a, size_t b, size_t c, FILE *d) {
    return fwrite(a, b, c, d);
}
