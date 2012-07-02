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

#import "SFContainerAppDelegate.h"
#import <PhoneGap/PhoneGapViewController.h>
#import "SalesforceSDKConstants.h"
#import "SalesforceOAuthPlugin.h"
#import "SFAccountManager.h"
#import "SFSecurityLockout.h"
#import "NSURL+SFStringUtils.h"
#import "SFInactivityTimerCenter.h"
#import "SFSmartStore.h"

// Public constants
NSString * const kSFMobileSDKVersion = @"1.2.3";
NSString * const kUserAgentPropKey = @"UserAgent";
NSString * const kAppHomeUrlPropKey = @"AppHomeUrl";
NSString * const kSFMobileSDKHybridDesignator = @"Hybrid";

// Private constants
NSString * const kSFOAuthPluginName = @"com.salesforce.oauth";
NSString * const kSFSmartStorePluginName = @"com.salesforce.smartstore";

// The default logging level of the app.
#if defined(DEBUG)
static SFLogLevel const kAppLogLevel = Debug;
#else
static SFLogLevel const kAppLogLevel = Info;
#endif

@interface SFContainerAppDelegate ()

/**
 * The file URL string for the start page, as it will be reported in webViewDidFinishLoad:
 */
+ (NSString *)startPageUrlString;

/**
 * Whether or not the input URL is one of the reserved URLs in the login flow, for consideration
 * in determining the app's ultimate home page.
 * @param url The URL to test.
 * @return YES if the value is one of the reserved URLs, NO otherwise.
 */
+ (BOOL)isReservedUrlValue:(NSURL *)url;

/**
 * Removes any cookies from the cookie store.  All app cookies are reset with
 * new authentication.
 */
+ (void)removeCookies;

/**
 * Tasks to run when the app is backgrounding or terminating.
 */
- (void)prepareToShutDown;

@end

@implementation SFContainerAppDelegate

@synthesize invokeString;
@synthesize appLogLevel = _appLogLevel;

#pragma mark - init/dealloc

- (id) init
{
    /** If you need to do any extra app-specific initialization, you can do it here
	 *  -jm
	 **/
    self = [super init];
    if (nil != self) {
        
        // Replace the app-wide HTTP User-Agent before the first UIWebView is created.  NOTE: You *must* use the
        // registerDefaults method to create this value.  Simply adding the key to the existing defaults will
        // not work.
        NSString *uaString = [self userAgentString];
        NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:uaString, kUserAgentPropKey, nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
        [dictionary release];
        
        _foundHomeUrl = NO;
        _isAppStartup = YES;
        self.appLogLevel = kAppLogLevel;
    }
    return self;
}

- (void)dealloc
{
    SFRelease(_oauthPlugin);
    SFRelease(invokeString);
    
	[ super dealloc ];
}

#pragma mark - App lifecycle

/**
 * This is main kick off after the app inits, the views and Settings are setup here. (preferred - iOS4 and up)
 */
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	NSArray *keyArray = [launchOptions allKeys];
	if ([launchOptions objectForKey:[keyArray objectAtIndex:0]]!=nil) 
	{
		NSURL *url = [launchOptions objectForKey:[keyArray objectAtIndex:0]];
		self.invokeString = [url absoluteString];
		NSLog(@"app launchOptions = %@",url);
	}
    
    [SFLogger setLogLevel:self.appLogLevel];
    
    // Reset app state if necessary (login settings have changed).  We have to do this in
    // both didFinishLaunchedWithOptions and applicationDidBecomeActive, because the latter
    // will conflict with PhoneGap's page launch process when the app starts.
    BOOL shouldLogout = [SFAccountManager logoutSettingEnabled];
    BOOL loginHostChanged = [SFAccountManager updateLoginHost];
    if (shouldLogout) {
        [self clearAppState:NO];
    } else if (loginHostChanged) {
        [[SFAccountManager sharedInstance] clearAccountState:NO];
    }
    
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

// this happens while we are running ( in the background, or from within our own app )
// only valid if App.plist specifies a protocol to handle
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url 
{
    // must call super so all plugins will get the notification, and their handlers will be called 
	// super also calls into javascript global function 'handleOpenURL'
    return [super application:application handleOpenURL:url];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {   
    
    // These actions only need to be taken when the app is coming back to the foreground, i.e. not when the app is first starting,
    // which has a separate bootstrapping process.
    if (!_isAppStartup) {
        SalesforceOAuthPlugin *oauthPlugin = (SalesforceOAuthPlugin *)[self getCommandInstance:kSFOAuthPluginName];
        [oauthPlugin clearPeriodicRefreshState];
        BOOL shouldLogout = [SFAccountManager logoutSettingEnabled];
        BOOL loginHostChanged = [SFAccountManager updateLoginHost];
        if (shouldLogout) {
            [self clearAppState:YES];
        } else if (loginHostChanged) {
            [[SFAccountManager sharedInstance] clearAccountState:NO];
            [self loadStartPageIntoWebView];
        } else {
            [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
                [self clearAppState:YES];
            }];
            [SFSecurityLockout setLockScreenSuccessCallbackBlock:^{
                [oauthPlugin autoRefresh];
                [self getCommandInstance:kSFSmartStorePluginName];
                [super applicationDidBecomeActive:application];
            }];
            [SFSecurityLockout validateTimer];
        }
    } else {
        // Actions to take place exclusively when the app starts up.
        [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
            [self clearAppState:YES];
        }];
        [SFSecurityLockout setLockScreenSuccessCallbackBlock:^{
            [super applicationDidBecomeActive:application];
        }];
        [SFSecurityLockout lock];
    }
    
    _isAppStartup = NO;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [self prepareToShutDown];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [self prepareToShutDown];
}

#pragma mark - PhoneGap helpers

/**
 We override startPage to load the bootstrap.html page, which will handle
 the app bootstrapping process from client code.
 */
+ (NSString *)startPage {
    return @"bootstrap.html";
}

-(id) getCommandInstance:(NSString*)className
{
	/** You can catch your own commands here, if you wanted to extend the gap: protocol, or add your
	 *  own app specific protocol to it. -jm
	 **/
	return [super getCommandInstance:className];
}

- (BOOL) execute:(InvokedUrlCommand*)command
{
	return [ super execute:command];
}

+ (BOOL) isIPad {
#ifdef UI_USER_INTERFACE_IDIOM
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
#else
    return NO;
#endif
}

+ (NSString *)startPageUrlString
{
    NSString *startPageFilePath = [self pathForResource:[self startPage]];
    NSURL *startPageFileUrl = [NSURL fileURLWithPath:startPageFilePath];
    NSString *urlString = [[startPageFileUrl absoluteString] stringByReplacingOccurrencesOfString:@"file://localhost/"
                                                                                       withString:@"file:///"];
    return urlString;
}

+ (BOOL)isReservedUrlValue:(NSURL *)url
{
    static NSArray *reservedUrlStrings = nil;
    if (reservedUrlStrings == nil) {
        reservedUrlStrings = [[NSArray arrayWithObjects:
                              [[self class] startPageUrlString],
                              @"/secur/frontdoor.jsp",
                              @"/secur/contentDoor",
                              nil] retain];
    }
    
    if (url == nil || [url absoluteString] == nil || [[url absoluteString] length] == 0)
        return NO;
    
    NSString *inputUrlString = [url absoluteString];
    for (int i = 0; i < [reservedUrlStrings count]; i++) {
        NSString *reservedString = [reservedUrlStrings objectAtIndex:i];
        NSRange range = [[inputUrlString lowercaseString] rangeOfString:[reservedString lowercaseString]];
        if (range.location != NSNotFound)
            return YES;
    }
    
    return NO;
}


#pragma mark - UIWebViewDelegate

/**
 Called when the webview finishes loading.  This stops the activity view and closes the imageview
 */
- (void)webViewDidFinishLoad:(UIWebView *)theWebView 
{
    NSURL *requestUrl = theWebView.request.URL;
    NSArray *redactParams = [NSArray arrayWithObjects:@"sid", nil];
    NSString *redactedUrl = [requestUrl redactedAbsoluteString:redactParams];
    NSLog(@"webViewDidFinishLoad: Loaded %@", redactedUrl);
    
    // The first URL that's loaded that's not considered a 'reserved' URL (i.e. one that Salesforce or
    // this app's infrastructure is responsible for) will be considered the "app home URL", which can
    // be loaded directly in the event that the app is offline.
    if (_foundHomeUrl == NO) {
        NSLog(@"Checking %@ as a 'home page' URL candidate for this app.", redactedUrl);
        if (![[self class] isReservedUrlValue:requestUrl]) {
            NSLog(@"Setting %@ as the 'home page' URL for this app.", redactedUrl);
            [[NSUserDefaults standardUserDefaults] setURL:requestUrl forKey:kAppHomeUrlPropKey];
            _foundHomeUrl = YES;
        }
    }
    
	// only valid if App.plist specifies a protocol to handle
	if(self.invokeString)
	{
		// this is passed before the deviceready event is fired, so you can access it in js when you receive deviceready
		NSString* jsString = [NSString stringWithFormat:@"var invokeString = \"%@\";", self.invokeString];
		[theWebView stringByEvaluatingJavaScriptFromString:jsString];
	}
    
    return [ super webViewDidFinishLoad:theWebView ];
}

- (void)webViewDidStartLoad:(UIWebView *)theWebView 
{
	return [ super webViewDidStartLoad:theWebView ];
}

/**
 * Fail Loading With Error
 * Error - If the webpage failed to load display an error with the reason.
 */
- (void)webView:(UIWebView *)theWebView didFailLoadWithError:(NSError *)error 
{
	return [ super webView:theWebView didFailLoadWithError:error ];
}

/**
 * Start Loading Request
 * This is where most of the magic happens... We take the request(s) and process the response.
 * From here we can re direct links and other protocalls to different internal methods.
 */
- (BOOL)webView:(UIWebView *)theWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	return [ super webView:theWebView shouldStartLoadWithRequest:request navigationType:navigationType ];
}


#pragma mark - Salesforce.com helpers

/**
 * Append a user agent string to the current one, based on device, application, and SDK
 * version information.
 * We are building a user agent of the form:
 *   SalesforceMobileSDK/1.0 iPhone OS/3.2.0 (iPad) appName/appVersion Hybrid [Current User Agent]
 */
- (NSString *)userAgentString {
    
    // Get the current user agent.  Yes, this is hack-ish.  Alternatives are more hackish.  UIWebView
    // really doesn't want you to know about its HTTP headers.
    UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    NSString *currentUserAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
    [webView release];
    
    UIDevice *curDevice = [UIDevice currentDevice];
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
    
    NSString *myUserAgent = [NSString stringWithFormat:
                             @"SalesforceMobileSDK/%@ %@/%@ (%@) %@/%@ %@ %@",
                             kSFMobileSDKVersion,
                             [curDevice systemName],
                             [curDevice systemVersion],
                             [curDevice model],
                             appName,
                             appVersion,
                             kSFMobileSDKHybridDesignator,
                             currentUserAgent
                             ];
    
    return myUserAgent;
}


- (void)addOAuthViewToMainView:(UIView*)oauthView {
    UIView *containerView = self.viewController.view;
    [oauthView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    
    //ensure that oauthView fills the whole view
    [oauthView setFrame:containerView.bounds];
    [containerView addSubview:oauthView];

}

+ (SFContainerAppDelegate*)sharedInstance 
{
    return (SFContainerAppDelegate*)[[UIApplication sharedApplication] delegate];
}

- (void)logout
{
    [self clearAppState:YES];
}

- (void)clearAppState:(BOOL)restartAuthentication
{
    // Clear any cookies set by the app.
    [[self class] removeCookies];
    
    // Revoke all stored OAuth authentication.
    [[SFAccountManager sharedInstance] clearAccountState:YES];
    
    // Clear the home URL since we are no longer authenticated.
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setURL:nil forKey:kAppHomeUrlPropKey];
    [defs synchronize];

    // Clear smartstore
    [[SFSmartStore sharedStoreWithName:kDefaultSmartStoreName] removeAllSoups];
    
    if (restartAuthentication)
        [self loadStartPageIntoWebView];
}

+ (void)removeCookies
{
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *fullCookieList = [NSArray arrayWithArray:[cookieStorage cookies]];
    for (NSHTTPCookie *cookie in fullCookieList) {
        [cookieStorage deleteCookie:cookie];
    }
}

- (void)prepareToShutDown {
    [SFSecurityLockout removeTimer];
    if ([SFAccountManager sharedInstance].credentials != nil) {
		[SFInactivityTimerCenter saveActivityTimestamp];
	}
}


@end
