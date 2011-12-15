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

#import "SFContainerAppDelegate.h"
#import <PhoneGap/PhoneGapViewController.h>
#import "SalesforceOAuthPlugin.h"

// Public constants
NSString * const kSFMobileSDKVersion = @"1.0.1";
NSString * const kUserAgentPropKey = @"UserAgent";

// Private constants
static NSString * const kOAuthPluginName = @"com.salesforce.oauth";


@implementation SFContainerAppDelegate

@synthesize invokeString;

#pragma mark - init/dealloc

- (id) init
{
    /** If you need to do any extra app-specific initialization, you can do it here
	 *  -jm
	 **/
    self = [super init];
    if (nil != self) {
        //Replace the app-wide HTTP User-Agent before the first UIWebView is created
        NSString *uaString = [self userAgentString];
        NSDictionary *appUserAgent = [[NSDictionary alloc] initWithObjectsAndKeys:uaString, kUserAgentPropKey, nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:appUserAgent];
        [appUserAgent release];
    }
    return self;
}

- (void)dealloc
{
    [_oauthPlugin release]; _oauthPlugin = nil;
    [invokeString release]; invokeString = nil;
    
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
    if (nil == _oauthPlugin)
        _oauthPlugin = (SalesforceOAuthPlugin *)[[self getCommandInstance:kOAuthPluginName] retain];
    
    // If the app is in a state where it should be reset, re-initialize the app.
    if ([_oauthPlugin resetAppState]) {
        [_oauthPlugin release]; _oauthPlugin = nil;
        [self loadStartPageIntoWebView];
    }
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

#pragma mark - UIWebViewDelegate

/**
 Called when the webview finishes loading.  This stops the activity view and closes the imageview
 */
- (void)webViewDidFinishLoad:(UIWebView *)theWebView 
{
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
 Set a user agent string based on the mobile SDK version.
 We are building a user agent of the form:
   SalesforceMobileSDK/1.0 iPhone OS/3.2.0 (iPad) appName/appVersion
 */
- (NSString *)userAgentString {
    UIDevice *curDevice = [UIDevice currentDevice];
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
    
    NSString *myUserAgent = [NSString stringWithFormat:
                             @"SalesforceMobileSDK/%@ %@/%@ (%@) %@/%@",
                             kSFMobileSDKVersion,
                             [curDevice systemName],
                             [curDevice systemVersion],
                             [curDevice model],
                             appName,
                             appVersion
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

@end
