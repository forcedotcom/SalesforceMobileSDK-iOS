/*
 Copyright (c) 2011-2013, salesforce.com, inc. All rights reserved.
 
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
#import "SFHybridViewConfig.h"
#import <SalesforceSDKCore/SFJsonUtils.h>
#import "SFTestRunnerPlugin.h"
#import <SalesforceSDKCore/TestSetupUtils.h>
#import <SalesforceSDKCore/SFSDKTestCredentialsData.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>

@interface AppDelegate () <SFAuthenticationManagerDelegate, SFUserAccountManagerDelegate>

@property (nonatomic, strong) SFHybridViewConfig *testAppHybridViewConfig;

/// Was the app started in Test mode? 
- (BOOL) isRunningOctest;
- (SFHybridViewConfig *)stageTestCredentials;
- (void)initializeAppViewState;

@end

@implementation AppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;
@synthesize testAppHybridViewConfig = _testAppHybridViewConfig;

- (id)init
{
    self = [super init];
    if (self != nil) {
        [SFLogger setLogLevel:SFLogLevelDebug];
        [self log:SFLogLevelDebug msg:@"Setting up auth credentials."];
        self.testAppHybridViewConfig = [self stageTestCredentials];
        
        // Logout and login host change handlers.
        [[SFAuthenticationManager sharedManager] addDelegate:self];
        [[SFUserAccountManager sharedInstance] addDelegate:self];
    }
    
    return self;
}

- (void)dealloc
{
    [[SFAuthenticationManager sharedManager] removeDelegate:self];
    [[SFUserAccountManager sharedInstance] removeDelegate:self];
}

#pragma mark - App lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.autoresizesSubviews = YES;
    [self initializeAppViewState];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    SFTestRunnerPlugin *runner =  (SFTestRunnerPlugin*)[self.viewController.commandDelegate getCommandInstance:kSFTestRunnerPluginName];
    NSLog(@"runner: %@",runner);
    
    BOOL runningOctest = [self isRunningOctest];
    NSLog(@"octest running: %d",runningOctest);
}


- (NSString *)evalJS:(NSString*)js {
    NSString *jsResult = [self.viewController.webView stringByEvaluatingJavaScriptFromString:js];
    return jsResult;
}

#pragma mark - SFAuthenticationManagerDelegate

- (void)authManagerDidLogout:(SFAuthenticationManager *)manager
{
    [self log:SFLogLevelDebug msg:@"Logout notification received.  Resetting app."];
    self.viewController.appHomeUrl = nil;
    
    // If there are one or more existing accounts after logout, try to authenticate one of those.
    // Alternatively, you could just go straight to re-initializing your app state, if you know
    // your app does not support multiple accounts.  The logic below will work either way.
    if ([[SFUserAccountManager sharedInstance].allUserAccounts count] > 0) {
        [SFUserAccountManager sharedInstance].currentUser = [[SFUserAccountManager sharedInstance].allUserAccounts objectAtIndex:0];
    }
    
    [self initializeAppViewState];
}

#pragma mark - SFUserAccountManagerDelegate

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         didSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser
{
    [self log:SFLogLevelDebug format:@"SFUserAccountManager changed from user %@ to %@.  Resetting app.",
     fromUser.userName, toUser.userName];
    [self initializeAppViewState];
}

#pragma mark - Private methods

- (SFHybridViewConfig *)stageTestCredentials {
    SFSDKTestCredentialsData *credsData = [TestSetupUtils populateAuthCredentialsFromConfigFile];
    SFHybridViewConfig *hybridConfig = [[SFHybridViewConfig alloc] init];
    hybridConfig.remoteAccessConsumerKey = credsData.clientId;
    hybridConfig.oauthRedirectURI = credsData.redirectUri;
    hybridConfig.oauthScopes = [NSSet setWithObjects:@"web", @"api", nil];
    hybridConfig.isLocal = YES;
    hybridConfig.startPage = @"index.html";
    hybridConfig.shouldAuthenticate = YES;
    hybridConfig.attemptOfflineLoad = NO;
    
    return hybridConfig;
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

- (void)initializeAppViewState
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self initializeAppViewState];
        });
        return;
    }
    
    self.viewController = [[SFHybridViewController alloc] initWithConfig:self.testAppHybridViewConfig];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
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
