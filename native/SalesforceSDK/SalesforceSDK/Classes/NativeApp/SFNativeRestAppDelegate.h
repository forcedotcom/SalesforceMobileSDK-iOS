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

#import <UIKit/UIKit.h>


#import "SFOAuthCoordinator.h"
#import "SFIdentityCoordinator.h"
#import "SFLogger.h"

@class SFAuthorizingViewController;
@class SFIdentityData;

/**
 
 Base class for Native-REST Salesforce Mobile SDK applications.
 
 */

@interface SFNativeRestAppDelegate : NSObject <UIApplicationDelegate, SFOAuthCoordinatorDelegate, SFIdentityCoordinatorDelegate, UIAlertViewDelegate> {
    SFAuthorizingViewController *_authViewController;
}

/**
 The root window of the native application.
 */
@property (nonatomic, retain) IBOutlet UIWindow *window;

/**
 The current view controller of the application.
 */
@property (nonatomic, retain) IBOutlet UIViewController *viewController;

/**
 View controller that gives the app some view state while authorizing.
 */
@property (nonatomic, retain) SFAuthorizingViewController *authViewController;

/**
 The log level assigned to the app.  Defaults to Debug for dev builds, and Info for release
 builds.
 */
@property (assign) SFLogLevel appLogLevel;

/**
 @return YES if this device is an iPad
 */
+ (BOOL) isIPad;


/**
 Override this method to change the scopes that should be used,
 default value is:
 [NSSet setWithObjects:@"api",nil]
 
 @return The set of oauth scopes that should be requested for this app.
 */
+ (NSSet *)oauthScopes;


/**
 Kickoff the login process.
 */
- (void)login;

/**
 Sent whenever the use has been logged in using current settings.
 Be sure to call super if you override this.
 */
- (void)loggedIn;

/**
 Forces a logout from the current account.
 This throws out the OAuth refresh token.
 */
- (void)logout;

/**
 This disposes of any current data.
 */
- (void)clearDataModel;


/**
 Your subclass MUST override this method
 @return NSString the Remote Access object consumer key
 */
- (NSString*)remoteAccessConsumerKey;

/**
 Your subclass MUST override this method
 @return NSString the Remote Access object redirect URI
 */
- (NSString*)oauthRedirectURI;

/**
By default this method obtains the login domain from Settings (see Settings.bundle)
 Your subclass MAY override this to lock logins to a particular domain.
 @return NSString the Remote Access object Login Domain
 */
- (NSString*)oauthLoginDomain;


/**
 Your subclass MAY override this method to provide an account identifier,
 such as the most-recently-used username.
 
 @return NSString An account identifier such as most recently used username.
 */
- (NSString*)userAccountIdentifier;


/**
 Your subclass MUST override this method to provide a root view controller.
 Create and return a new instance of your app's root view controlller.
 This should be the view controller loaded after login succeeds.
 @return UIViewController A view controller to be shown after login succeeds.
 */
- (UIViewController*)newRootViewController;

@end

