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

#import "AppDelegate.h"
#ifdef PHONEGAP_FRAMEWORK
	#import <PhoneGap/PhoneGapViewController.h>
#else
	#import "PhoneGapViewController.h"
#endif

#import "SFOAuthCredentials.h"
#import "SFRestAPI.h"


/*
 NOTE These values are provided as usable examples to get you started with OAuth login;
 however, when you create your own app you must create your own Remote Access object
 in your Salesforce org. 
 (When you are logged in as an org administrator, go to Setup -> Develop -> Remote Access -> New )
 */

#warning This value should be overwritten with the Consumer Key from your own Remote Access object
static NSString *const remoteAccessConsumerKey =
    @"3MVG9Iu66FKeHhINkB1l7xt7kR8czFcCTUhgoA8Ol2Ltf1eYHOU4SqQRSEitYFDUpqRWcoQ2.dBv_a1Dyu5xa";

#warning This value should be overwritten with the Callback URL from your own Remote Access object
static NSString *const OAuthRedirectURI = 
    @"testsfdc:///mobilesdk/detect/oauth/done";

#warning This value must match the org instance with which you're testing 
static NSString *const OAuthLoginDomain =  
    @"test.salesforce.com"; //Sandbox:  use login.salesforce.com if you're sure you want to test with Production


@interface AppDelegate (private)
- (void)login;
- (void)loggedIn;
- (void)sendJavascriptLoginEvent:(UIWebView *)webView;
@end

@implementation AppDelegate

@synthesize invokeString;
@synthesize coordinator=_coordinator;

#pragma mark - init/dealloc

- (id) init
{	
	/** If you need to do any extra app-specific initialization, you can do it here
	 *  -jm
	 **/
    return [super init];
}

- (void)dealloc
{
    self.coordinator = nil;
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
		NSLog(@"ContactExplorer launchOptions = %@",url);
	}

    // init window
	CGRect screenBounds = [ [ UIScreen mainScreen ] bounds ];
	self.window = [ [ [ UIWindow alloc ] initWithFrame:screenBounds ] autorelease ];
	self.window.autoresizesSubviews = YES;
    
    [self.window makeKeyAndVisible];
    return YES;
}

// this happens while we are running ( in the background, or from within our own app )
// only valid if ContactExplorer.plist specifies a protocol to handle
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url 
{
    // must call super so all plugins will get the notification, and their handlers will be called 
	// super also calls into javascript global function 'handleOpenURL'
    return [super application:application handleOpenURL:url];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
    
	// refresh session
	[self login];
}

#pragma mark - PhoneGap helpers

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
	// only valid if ContactExplorer.plist specifies a protocol to handle
	if(self.invokeString)
	{
		// this is passed before the deviceready event is fired, so you can access it in js when you receive deviceready
		NSString* jsString = [NSString stringWithFormat:@"var invokeString = \"%@\";", self.invokeString];
		[theWebView stringByEvaluatingJavaScriptFromString:jsString];
	}
    
    // let's notify the page we are logged in
    [self sendJavascriptLoginEvent:theWebView];

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

- (void)loggedIn {
    [[SFRestAPI sharedInstance] setCoordinator:self.coordinator];
    
    if (!self.viewController) {
        // let's kickstart phonegap
        [super application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil];
    }
    else {
        // otherwise, simply notify the webview that we have logged in
        [self sendJavascriptLoginEvent:self.webView];
    }
}

- (void)sendJavascriptLoginEvent:(UIWebView *)webView {
    NSString *accessToken = [SFRestAPI sharedInstance].coordinator.credentials.accessToken;
    NSString *refreshToken = [SFRestAPI sharedInstance].coordinator.credentials.refreshToken;
    NSString *clientId = [SFRestAPI sharedInstance].coordinator.credentials.clientId;
    NSString *instanceUrl = [SFRestAPI sharedInstance].coordinator.credentials.instanceUrl.absoluteString;
    NSString *loginUrl = [NSString stringWithFormat:@"%@://%@", [SFRestAPI sharedInstance].coordinator.credentials.protocol, [SFRestAPI sharedInstance].coordinator.credentials.domain];
    NSString *apiVersion = [SFRestAPI sharedInstance].apiVersion;

    NSString* jsString = [NSString stringWithFormat:@""
                          "(function() {"
                          "  var e = document.createEvent('Events');"
                          "  e.initEvent('salesforce_oauth_login');"
                          "  e.data = {"
                          "    accessToken: \"%@\","
                          "    refreshToken: \"%@\","
                          "    clientId: \"%@\","
                          "    loginUrl: \"%@\","
                          "    instanceUrl: \"%@\","
                          "    apiVersion: \"%@\""
                          "  };"
                          "  document.dispatchEvent(e);"
                          "})()",
                          accessToken,
                          refreshToken,
                          clientId,
                          loginUrl,
                          instanceUrl,
                          apiVersion];
    [webView stringByEvaluatingJavaScriptFromString:jsString];
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
