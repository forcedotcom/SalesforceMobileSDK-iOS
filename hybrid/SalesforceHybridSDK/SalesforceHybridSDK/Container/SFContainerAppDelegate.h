/*
 Copyright (c) 2011-2012, salesforce.com, inc. All rights reserved.
 Author: Todd Stellanova
 
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
#import "PhoneGapDelegate.h"


#import "SFOAuthCoordinator.h"
#import "SFLogger.h"

@class SalesforceOAuthPlugin;

/**
 
 Base class for hybrid Salesforce Mobile SDK applications.
 
 */

/*
 * The current version of the Salesforce Mobile SDK.
 */
extern NSString * const kSFMobileSDKVersion;

/*
 * The property key used to designate the user agent, in the app's default properties.
 */
extern NSString * const kUserAgentPropKey;

/*
 * The property key used to designate the "home" URL of the app, to be used if the app is
 * offline and supports HTML5 offline caching.
 */
extern NSString * const kAppHomeUrlPropKey;

/*
 * The designator used to signify that the app is a hybrid app.
 */
extern NSString * const kSFMobileSDKHybridDesignator;

/*
 * The string used to uniquely identify the Salesforce OAuth plugin.
 */
extern NSString * const kSFOAuthPluginName;

/*
 * The string used to uniquely identify the Salesforce SmartStore plugin.
 */
extern NSString * const kSFSmartStorePluginName;

@interface SFContainerAppDelegate : PhoneGapDelegate {
    
	NSString* invokeString;
    SalesforceOAuthPlugin *_oauthPlugin;
    BOOL _foundHomeUrl;
    BOOL _isAppStartup;
}


/**
 invoke string is passed to your app on launch, this is only valid if you 
 edit App.plist to add a protocol
 a simple tutorial can be found here : 
 http://iphonedevelopertips.com/cocoa/launching-your-own-application-via-a-custom-url-scheme.html
*/
@property (nonatomic, copy)  NSString *invokeString;

/**
 The User-Agent string presented by this application
 */
@property (nonatomic, readonly) NSString *userAgentString;

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
 * Adds the generated OAuth view to the main app view.
 * @param oauthView OAuth coordinator view to be added to main viewController's view during login. 
 */
- (void)addOAuthViewToMainView:(UIView*)oauthView;

/**
 * Clears all of the app state, including user credentials, from the app, and optionally restarts
 * the login process.
 * @param restartAuthentication Whether or not to restart authentication after the app is reset.
 */
- (void)clearAppState:(BOOL)restartAuthentication;

/**
 * Essentially a call to clearAppState:YES.  The pin code functionality requires a logout function
 * on the app, in the event of pin verification failure.
 */
- (void)logout;


/**
 The currently running app delegate
 */
+ (SFContainerAppDelegate*)sharedInstance;

@end

