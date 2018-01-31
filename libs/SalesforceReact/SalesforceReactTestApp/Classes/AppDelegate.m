/*
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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
#import <React/RCTRootView.h>
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import <SalesforceReact/SalesforceReact.h>

@implementation AppDelegate

- (id)init
{
    self = [super init];
    [SalesforceSDKManager setInstanceClass:[SalesforceReactSDKManager class]];
    if (self != nil) {
        // [SFSDKLogger log:[self class] level:DDLogLevelDebug message:@"Setting up auth credentials."];
        [SalesforceSDKManager sharedManager].appConfig = [self stageTestCredentials];
    }
    return self;
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
// XXX    SFTestRunnerPlugin *runner =  (SFTestRunnerPlugin*)[self.viewController.commandDelegate getCommandInstance:kSFTestRunnerPluginName];
//    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"runner: %@", runner];
    BOOL runningOctest = [self isRunningOctest];
    // [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"octest running: %d", runningOctest];
}

#pragma mark - Private methods


- (SFSDKAppConfig *)stageTestCredentials {
    SFSDKTestCredentialsData *credsData = [TestSetupUtils populateAuthCredentialsFromConfigFileForClass:[self class]];
    SFSDKAppConfig *appConfig = [[SFSDKAppConfig alloc] init];
    appConfig.remoteAccessConsumerKey = credsData.clientId;
    appConfig.oauthRedirectURI = credsData.redirectUri;
    appConfig.oauthScopes = [NSSet setWithObjects:@"web", @"api", nil];
    return appConfig;
}


- (BOOL) isRunningOctest
{
    BOOL result = NO;
    NSDictionary *processEnv = [[NSProcessInfo processInfo] environment];
    NSString *injectBundle = [processEnv valueForKey:@"XCInjectBundle"];
    // [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"XCInjectBundle: %@", injectBundle];
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

    // Setup root view controller
    NSURL* jsCodeLocation = [NSURL URLWithString:@"http://localhost:8081/index.bundle?platform=ios"];
    RCTRootView *rootView = [[RCTRootView alloc] initWithBundleURL:jsCodeLocation
                                                        moduleName:@"SalesforceReactTestApp"
                                                 initialProperties:nil
                                                     launchOptions:nil];
    
    UIViewController *rootViewController = [[UIViewController alloc] init];
    rootViewController.view = rootView;
    self.window.rootViewController = rootViewController;
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
