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

#import "SFOAuthCredentials.h"
#import "SalesforceOAuthTestAppDelegate.h"
#import "SalesforceOAuthTestViewController.h"

@implementation SalesforceOAuthTestAppDelegate

NSString * const kIdentifier                         = @"com.salesforce.ios.oauth.test";
NSString * const kOAuthClientId                      = @"SfdcMobileChatteriOS";

static NSString * const kOAuthCredentialsArchivePath = @"SFOAuthCredentials";

static NSString * const kOAuthProtocol               = @"https";
static NSString * const kOAuthRedirectUri            = @"sfdc:///axm/detect/oauth/done";

@synthesize window         = _window;
@synthesize viewController = _viewController;

- (void)dealloc {
    [_window release];          _window = nil;
    [_viewController release];  _viewController = nil;
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    
    SalesforceOAuthTestViewController *vc = 
        [[SalesforceOAuthTestViewController alloc] initWithNibName:@"SalesforceOAuthTestViewController" bundle:nil];
    self.viewController = vc;
    [vc release];
    self.viewController.oauthCoordinator.credentials = [[self class] unarchiveCredentials];
    self.viewController.oauthCoordinator.credentials.logLevel = kSFOAuthLogLevelInfo;
    
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    /* Sent when the application is about to move from active to inactive state. */
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[self class] archiveCredentials:self.viewController.oauthCoordinator.credentials];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of the transition from the background to the inactive state; 
     here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. 
     If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [[self class] archiveCredentials:self.viewController.oauthCoordinator.credentials];
}

+ (void)archiveCredentials:(SFOAuthCredentials *)creds {
    BOOL result = [NSKeyedArchiver archiveRootObject:creds toFile:[self archivePath]];
    NSLog(@"%@:archiveCredentials: credentials archived=%@", @"SalesforceOAuthTestAppDelegate", (result ? @"YES" : @"NO"));
}

+ (SFOAuthCredentials *)unarchiveCredentials {
    NSString *path = [SalesforceOAuthTestAppDelegate archivePath];
    SFOAuthCredentials *creds = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    if (nil == creds) {
        // no existing credentials, create a new one
        creds = [[[SFOAuthCredentials alloc] initWithIdentifier:kIdentifier clientId:kOAuthClientId] autorelease];
        creds.redirectUri = kOAuthRedirectUri;
        // domain is set by the view from its UI field value
        
        NSLog(@"%@:unarchiveCredentials: no saved credentials, new credentials created: %@", @"SalesforceOAuthTestAppDelegate", creds);
    } else {
        NSLog(@"%@:unarchiveCredentials: using saved credentials: %@", @"SalesforceOAuthTestAppDelegate", creds);
    }
    return creds;
}

+ (NSString *)archivePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsPath = [paths objectAtIndex:0];
	return [documentsPath stringByAppendingPathComponent:kOAuthCredentialsArchivePath];
}

@end
