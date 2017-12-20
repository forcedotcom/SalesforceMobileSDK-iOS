/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
 
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
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import <SalesforceHybridSDK/SalesforceHybridSDK.h>
#import "SFTestRunnerPlugin.h"
SFSDK_USE_DEPRECATED_BEGIN
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
    [SalesforceSDKManager setInstanceClass:[SalesforceHybridSDKManager class]];
    if (self != nil) {
        [SFSDKLogger log:[self class] level:DDLogLevelDebug message:@"Setting up auth credentials."];
        self.testAppHybridViewConfig = [self stageTestCredentials];

        // Logout and login host change handlers.
        [[SFAuthenticationManager sharedManager] addDelegate:self];
        [[SFUserAccountManager sharedInstance] addDelegate:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUserDidLogout:)  name:kSFNotificationUserDidLogout object:nil];
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
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"runner: %@", runner];
    BOOL runningOctest = [self isRunningOctest];
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"octest running: %d", runningOctest];
}

- (NSString *) evalJS:(NSString *) js {
    if (self.viewController.useUIWebView) {
        NSString *jsResult = [(UIWebView *)(self.viewController.webView) stringByEvaluatingJavaScriptFromString:js];
        return jsResult;
    } else {
        __block NSString *resultString = nil;
        __block BOOL finished = NO;
        [(WKWebView *)(self.viewController.webView) evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
            if (error == nil) {
                if (result != nil) {
                    resultString = [NSString stringWithFormat:@"%@", result];
                }
            } else {
                [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"evaluateJavaScript error : %@", error.localizedDescription];
            }
            finished = YES;
        }];
        while (!finished) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
        return resultString;
    }
}

#pragma mark - SFAuthenticationManagerDelegate

- (void)authManagerDidLogout:(SFAuthenticationManager *)manager
{
    [self userDidLogout];
}

- (void)userDidLogout {
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"Logout notification received. Resetting app."];
    self.viewController.appHomeUrl = nil;
    
    // Multi-user pattern:
    // - If there are two or more existing accounts after logout, let the user choose the account
    //   to switch to.
    // - If there is one existing account, automatically switch to that account.
    // - If there are no further authenticated accounts, present the login screen.
    //
    // Alternatively, you could just go straight to re-initializing your app state, if you know
    // your app does not support multiple accounts.  The logic below will work either way.
    NSArray *allAccounts = [SFUserAccountManager sharedInstance].allUserAccounts;
    if ([allAccounts count] > 1) {
        SFDefaultUserManagementViewController *userSwitchVc = [[SFDefaultUserManagementViewController alloc] initWithCompletionBlock:^(SFUserManagementAction action) {
            [self.viewController dismissViewControllerAnimated:YES completion:NULL];
        }];
        [self.viewController presentViewController:userSwitchVc animated:YES completion:NULL];
    } else if ([[SFUserAccountManager sharedInstance].allUserAccounts count] == 1) {
        [SFUserAccountManager sharedInstance].currentUser = ([SFUserAccountManager sharedInstance].allUserAccounts)[0];
        [self initializeAppViewState];
    } else {
        [self initializeAppViewState];
    }
}

- (void)handleUserDidLogout:(NSNotification *)notification {
    [self userDidLogout];
}
#pragma mark - SFUserAccountManagerDelegate

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         didSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser
{
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"SFUserAccountManager changed from user %@ to %@. Resetting app.",
     fromUser.userName, toUser.userName];
    [self initializeAppViewState];
}

#pragma mark - Private methods

- (SFHybridViewConfig *)stageTestCredentials {
    SFSDKTestCredentialsData *credsData = [TestSetupUtils populateAuthCredentialsFromConfigFileForClass:[self class]];
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
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"XCInjectBundle: %@", injectBundle];
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
    [TestSetupUtils synchronousAuthRefresh];
    self.viewController = [[SFHybridViewController alloc] initWithConfig:self.testAppHybridViewConfig];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
}

@end

//The following are required for code coverage to work:
FILE *fopen$UNIX2003(const char *filename, const char *mode) {
    return fopen(filename, mode);
}

size_t fwrite$UNIX2003(const void *a, size_t b, size_t c, FILE *d) {
    return fwrite(a, b, c, d);
}
SFSDK_USE_DEPRECATED_END
