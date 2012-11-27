/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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
#import "RootViewController.h"
#import "SFPushNotification.h"

/*
 NOTE if you ever need to update these, you can obtain them from your Salesforce org,
 (When you are logged in as an org administrator, go to Setup -> Develop -> Remote Access -> New )
 */


// Fill these in when creating a new Remote Access client on Force.com 
static NSString *const RemoteAccessConsumerKey = @"Your Consumer Key Here";
static NSString *const OAuthRedirectURI = @"Put your callback url here";


@implementation AppDelegate


#pragma mark - Remote Access / OAuth configuration


- (NSString*)remoteAccessConsumerKey {
    return RemoteAccessConsumerKey;
}

- (NSString*)oauthRedirectURI {
    return OAuthRedirectURI;
}



#pragma mark - App lifecycle


//NOTE be sure to call all super methods you override.


- (UIViewController*)newRootViewController {
    RootViewController *rootVC = [[RootViewController alloc] initWithNibName:nil bundle:nil];
    UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:rootVC];
    [rootVC release];
    
    return navVC;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    //RestAPI version should be a minumum of v27.0
    [[SFRestAPI sharedInstance]setApiVersion:@"v27.0"];
    NSAssert([RemoteAccessConsumerKey compare:@"Your Consumer Key Here"] != NSOrderedSame, @"You should put your own consumer key here");
    NSAssert([OAuthRedirectURI compare:@"Put your callback url here"] != NSOrderedSame, @"You should put your OAuth RedirectURL here");
    [[SFPushNotification sharedInstance] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound)];
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken {
    return [super application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}
@end
