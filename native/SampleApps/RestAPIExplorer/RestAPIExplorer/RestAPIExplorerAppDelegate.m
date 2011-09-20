//
//  RestAPIExplorerAppDelegate.m
//  RestAPIExplorer
//
//  Created by Didier Prophete on 7/14/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import "RestAPIExplorerAppDelegate.h"

#import "RestAPIExplorerViewController.h"
#import "SFOAuthCredentials.h"
#import "SFRestAPI.h"

static NSString *const remoteAccessConsumerKey = @"3MVG99OxTyEMCQ3jIW9bdxrL5aAIBz8a993UAC3dntUFefeCE.FJeLrZ.Tt.vcR4USTTa2_H3EGJ6Ajt4dFOw";
static NSString *const OAuthRedirectURI = @"https://login.salesforce.com/services/oauth2/success";
static NSString *const OAuthLoginDomain = @"login.salesforce.com";

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
     
    self.window.rootViewController = self.viewController;
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

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:willBeginAuthenticationWithView");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:didBeginAuthenticationWithView");
    [self.window addSubview:view];
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator {
    NSLog(@"oauthCoordinatorDidAuthenticate with sessionid: %@, userId: %@", coordinator.credentials.accessToken, coordinator.credentials.userId);
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
