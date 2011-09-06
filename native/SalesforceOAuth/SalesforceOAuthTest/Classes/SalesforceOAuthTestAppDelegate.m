//
//  SalesforceOAuthTestAppDelegate.h
//  SalesforceOAuthTest
//
//  Created by Steve Holly on 20/06/2011.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import "SFOAuthCredentials.h"
#import "SalesforceOAuthTestAppDelegate.h"
#import "SalesforceOAuthTestViewController.h"

@implementation SalesforceOAuthTestAppDelegate

NSString * const kOAuthClientId                      = @"SfdcMobileChatteriPad";

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
    
    SalesforceOAuthTestViewController *vc = [[SalesforceOAuthTestViewController alloc] initWithNibName:@"SalesforceOAuthTestViewController" 
                                                                                                bundle:nil];
    self.viewController = vc;
    [vc release];
    self.viewController.oauthCoordinator.credentials = [[self class] unarchiveCredentials];
    
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
        creds = [[[SFOAuthCredentials alloc] initWithIdentifier:kOAuthClientId] autorelease];
        creds.protocol    = kOAuthProtocol;
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
