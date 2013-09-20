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
#import <SalesforceSDKCore/SFAccountManager.h>
#import "CDVCommandDelegateImpl.h"
#import "SFTestRunnerPlugin.h"

NSString * const kHybridTestAccountIdentifier = @"SalesforceHybridSDKTests-DefaultAccount";

@interface AppDelegate ()

@property (nonatomic, strong) SFHybridViewConfig *testAppHybridViewConfig;

/// Was the app started in Test mode? 
- (BOOL) isRunningOctest;
- (void)populateAuthCredentialsFromConfigFile;
- (void)initializeAppViewState;

/**
 * Handles the notification from SFAuthenticationManager that a logout has been initiated.
 * @param notification The notification containing the details of the logout.
 */
- (void)logoutInitiated:(NSNotification *)notification;

/**
 * Handles the notification from SFAuthenticationManager that the login host has changed in
 * the Settings application for this app.
 * @param The notification whose userInfo dictionary contains:
 *        - kSFLoginHostChangedNotificationOriginalHostKey: The original host, prior to host change.
 *        - kSFLoginHostChangedNotificationUpdatedHostKey: The updated (new) login host.
 */
- (void)loginHostChanged:(NSNotification *)notification;

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
        [self populateAuthCredentialsFromConfigFile];
        
        // Logout and login host change handlers.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logoutInitiated:) name:kSFUserLogoutNotification object:[SFAuthenticationManager sharedManager]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginHostChanged:) name:kSFLoginHostChangedNotification object:[SFAuthenticationManager sharedManager]];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSFUserLogoutNotification object:[SFAuthenticationManager sharedManager]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSFLoginHostChangedNotification object:[SFAuthenticationManager sharedManager]];
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

#pragma mark - App Settings helpers

- (void)logoutInitiated:(NSNotification *)notification
{
    [self log:SFLogLevelDebug msg:@"Logout notification received.  Resetting app."];
    self.viewController.appHomeUrl = nil;
    [self initializeAppViewState];
}

- (void)loginHostChanged:(NSNotification *)notification
{
    [self log:SFLogLevelDebug msg:@"Login host changed notification received.  Resetting app."];
    [self initializeAppViewState];
}

#pragma mark - Private methods

- (void)populateAuthCredentialsFromConfigFile {
    NSString *tokenPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test_credentials" ofType:@"json"];
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
    if ([refreshToken isEqualToString:@"__INSERT_TOKEN_HERE__"]) {
        NSLog(@"You need to obtain credentials for your test org and replace test_credentials.json");
        NSAssert(NO, @"You need to obtain credentials for your test org and replace test_credentials.json");
    }
    
    self.testAppHybridViewConfig = [[SFHybridViewConfig alloc] init];
    self.testAppHybridViewConfig.remoteAccessConsumerKey = clientID;
    self.testAppHybridViewConfig.oauthRedirectURI = redirectUri;
    self.testAppHybridViewConfig.oauthScopes = [NSSet setWithObjects:@"web", @"api", nil];
    self.testAppHybridViewConfig.isLocal = YES;
    self.testAppHybridViewConfig.startPage = @"index.html";
    self.testAppHybridViewConfig.shouldAuthenticate = YES;
    self.testAppHybridViewConfig.attemptOfflineLoad = NO;
    
    [SFAccountManager setCurrentAccountIdentifier:kHybridTestAccountIdentifier];
    [SFAccountManager setLoginHost:loginDomain];
    SFAccountManager *accountMgr = [SFAccountManager sharedInstance];
    SFOAuthCredentials *credentials = accountMgr.credentials;
    credentials.instanceUrl = [NSURL URLWithString:instanceUrl];
    credentials.accessToken = accessToken;
    credentials.refreshToken = refreshToken;
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
    self.viewController.useSplashScreen = NO;
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
