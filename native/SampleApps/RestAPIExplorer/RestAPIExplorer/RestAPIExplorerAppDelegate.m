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

#import "RestAPIExplorerAppDelegate.h"

#import <MobileCoreServices/UTCoreTypes.h>

#import "RestAPIExplorerViewController.h"

#import "SBJson.h"
#import "SFOAuthCredentials.h"
#import "SFRestAPI.h"
#import "UnauthorizedViewController.h"


/*
 NOTE These values are provided as usable examples to get you started with OAuth login;
 however, when you create your own app you must create your own Remote Access object
 in your Salesforce org. 
 (When you are logged in as an org administrator, go to Setup -> Develop -> Remote Access -> New )
 */

// For unit testing purposes with SalesforceSDKTests, the following values should match
// the values stored in test_credentials.json

//For SalesforceSDKTests, this should match test_client_id in test_credentials.json 
#warning This value should be overwritten with the Consumer Key from your own Remote Access object
static NSString *const remoteAccessConsumerKey =
    @"3MVG9Iu66FKeHhINkB1l7xt7kR8czFcCTUhgoA8Ol2Ltf1eYHOU4SqQRSEitYFDUpqRWcoQ2.dBv_a1Dyu5xa";


//For SalesforceSDKTests, this should match test_redirect_uri in test_credentials.json 
#warning This value should be overwritten with the Callback URL from your own Remote Access object
static NSString *const OAuthRedirectURI = 
    @"testsfdc:///mobilesdk/detect/oauth/done";

//For SalesforceSDKTests, this should match test_login_domain in test_credentials.json 
#warning This value must match the org instance with which you're testing 
static NSString *const OAuthLoginDomain =  
    @"test.salesforce.com"; //Sandbox:  use login.salesforce.com if you're sure you want to test with Production


@interface RestAPIExplorerAppDelegate (private)
- (void)login;
- (void)loggedIn;
@end

@implementation RestAPIExplorerAppDelegate


@synthesize window=_window;
@synthesize viewController=_viewController;
@synthesize coordinator=_coordinator;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
         
    UnauthorizedViewController *bgVC = [[UnauthorizedViewController alloc] initWithNibName:@"UnauthorizedViewController" bundle:nil];
    self.viewController = bgVC;
    self.window.rootViewController = self.viewController;
    [bgVC release];
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
    [self login];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

- (void)dealloc
{
    [_window release];
    [_viewController release];
    self.coordinator = nil;
    [super dealloc];
}


#pragma mark - Salesforce.com login helpers

- (void)login {
    SFOAuthCredentials *credentials = [[[SFOAuthCredentials alloc] initWithIdentifier:remoteAccessConsumerKey] autorelease];
    credentials.domain = OAuthLoginDomain;
    credentials.redirectUri = OAuthRedirectURI;
    
    self.coordinator = [[[SFOAuthCoordinator alloc] initWithCredentials:credentials] autorelease];
    self.coordinator.delegate = self;
//    [self.coordinator revokeAuthentication];
    [self.coordinator authenticate];
}

- (void)logout {
    [self.coordinator revokeAuthentication];
    [self.coordinator authenticate];
}

- (void)loggedIn {
    [[SFRestAPI sharedInstance] setCoordinator:self.coordinator];

    // now show the true app view controller if it's not already shown
    if (![self.viewController isKindOfClass:RestAPIExplorerViewController.class]) {
        self.viewController = [[[RestAPIExplorerViewController alloc] initWithNibName:nil bundle:nil] autorelease];
        self.window.rootViewController = self.viewController;
    }
}

#pragma mark - Unit test helpers

- (void)exportTestingCredentials {
    //collect credentials and copy to pasteboard 
    SFOAuthCredentials *creds = [SFRestAPI sharedInstance].coordinator.credentials;
    NSDictionary *configDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                remoteAccessConsumerKey, @"test_client_id", 
                                OAuthLoginDomain, @"test_login_domain", 
                                OAuthRedirectURI, @"test_redirect_uri", 
                                creds.refreshToken,@"refresh_token",
                                [creds.instanceUrl absoluteString] , @"instance_url", 
                                @"__NOT_REQUIRED__",@"access_token",
                                nil];

    NSString *configJSON = [configDict JSONRepresentation];
    UIPasteboard *gpBoard = [UIPasteboard generalPasteboard];
    [gpBoard setValue:configJSON forPasteboardType:(NSString*)kUTTypeUTF8PlainText];

}

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:willBeginAuthenticationWithView");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:didBeginAuthenticationWithView");
    
    if ([self.viewController isKindOfClass:[UnauthorizedViewController class]]) {
        [(UnauthorizedViewController*)self.viewController setOauthView:view];
    } else {
        [self.viewController.view addSubview:view];
    }

}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator {
    NSLog(@"oauthCoordinatorDidAuthenticate with userId: %@", coordinator.credentials.userId);
    [coordinator.view removeFromSuperview];
    [self loggedIn];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error {
    NSLog(@"oauthCoordinator:didFailWithError: %@", error);
    [coordinator.view removeFromSuperview];
    
    // show alert and retry
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Salesforce Error" 
                                                    message:[NSString stringWithFormat:@"Can't connect to salesforce: %@", error]
                                                   delegate:self
                                          cancelButtonTitle:@"Retry"
                                          otherButtonTitles: nil];
    [alert show];	
    [alert release];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    [self.coordinator authenticate];
}
@end
