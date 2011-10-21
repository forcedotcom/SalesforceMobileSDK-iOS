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
#import "UnauthorizedViewController.h"

#ifdef PHONEGAP_FRAMEWORK
	#import <PhoneGap/PhoneGapViewController.h>
#else
	#import "PhoneGapViewController.h"
#endif

/*
 NOTE These values are provided as usable examples to get you started with OAuth login;
 however, when you create your own app you must create your own Remote Access object
 in your Salesforce org. 
 (When you are logged in as an org administrator, go to Setup -> Develop -> Remote Access -> New )
 */

#warning This value should be overwritten with the Consumer Key from your own Remote Access object
static NSString *const RemoteAccessConsumerKey =
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
@synthesize authViewController=_authViewController;

/**
 * This method will return the URL that PhoneGap will use to initialize the application.
 * For demonstration purposes, this simply points to https://instance_host_name/apex/BasicVFPage
 * Change this to reference your VisualForce landing page.
 */
+ (NSString *)startPage {
    AppDelegate *me = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    SFOAuthCredentials *creds = me.coordinator.credentials;
    NSString *instanceHost = [creds.instanceUrl host];
    NSString *startPageString = [NSString stringWithFormat:@"https://%@/apex/BasicVFPage",instanceHost ]; 
    NSLog(@"startPageString value: %@", startPageString);
    return startPageString;
}

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
    self.authViewController = nil;
	[ super dealloc ];
}

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
		NSLog(@"VisualForceConnector launchOptions = %@",url);
	}
	
    CGRect screenBounds = [ [ UIScreen mainScreen ] bounds ];
    UIWindow *rootWindow = [[UIWindow alloc] initWithFrame:screenBounds];
	self.window = rootWindow;
    [rootWindow release];
    
	// Set up a view controller for the authentication process.
    UnauthorizedViewController *authVc = [[UnauthorizedViewController alloc] initWithNibName:@"UnauthorizedViewController" bundle:nil];
    self.authViewController = authVc;
    self.window.rootViewController = self.authViewController;
    self.window.autoresizesSubviews = YES;
    [authVc release];
    
    // We will allow PhoneGap's initialization to continue after we complete authentication.
    // See the loggedIn method.
    
    [self.window makeKeyAndVisible];
    return YES;
    
}

// this happens while we are running ( in the background, or from within our own app )
// only valid if VisualForceConnector.plist specifies a protocol to handle
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
    
	// In our case, we'll refresh the auth session.
	[self login];
}

-(id) getCommandInstance:(NSString*)className
{
	/** You can catch your own commands here, if you wanted to extend the gap: protocol, or add your
	 *  own app specific protocol to it. -jm
	 **/
	return [super getCommandInstance:className];
}

/**
 Called when the webview finishes loading.  This stops the activity view and closes the imageview
 */
- (void)webViewDidFinishLoad:(UIWebView *)theWebView 
{
	// only valid if VisualForceConnector.plist specifies a protocol to handle
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


- (BOOL) execute:(InvokedUrlCommand*)command
{
	return [ super execute:command];
}

#pragma mark - Salesforce.com login helpers

/**
 * This method will initiate the authentication process.
 */
- (void)login {
    
    if (nil == self.coordinator) {
        SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] 
                                           initWithIdentifier:@"VFConnector-DefaultAccount"  
                                           clientId:RemoteAccessConsumerKey];
        credentials.domain = OAuthLoginDomain;
        credentials.redirectUri = OAuthRedirectURI;
        
        SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:credentials];
        //we ask for both visualforce and api scope here in case we decide to use the REST API later
        coordinator.scopes = [NSSet setWithObjects:@"visualforce",@"api", nil];
        self.coordinator = coordinator;
        self.coordinator.delegate = self;
        self.coordinator.credentials = credentials;
        
        [credentials release];
        [coordinator release];
    }
    
    [self.coordinator authenticate];
}

/**
 * This method will be called once the authentication process has completed.
 */
- (void)loggedIn {
    NSURL *instanceUrl = self.coordinator.credentials.instanceUrl;
    NSString *domain = [instanceUrl host]; 
    
    // Set the session ID cookie to be used by the web view.
    NSURL *hostURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", domain]];
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *cookies = [cookieStorage cookiesForURL:hostURL];
    NSHTTPCookie *sidCookie = [NSHTTPCookie cookieWithProperties:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                  domain, NSHTTPCookieDomain,
                                                                  @"/", NSHTTPCookiePath,
                                                                  self.coordinator.credentials.accessToken, NSHTTPCookieValue,
                                                                  @"sid", NSHTTPCookieName,
                                                                  @"TRUE", NSHTTPCookieDiscard,
                                                                  @"TRUE", NSHTTPCookieSecure,
                                                                  nil]];
    NSMutableArray *newCookies = [NSMutableArray arrayWithArray:cookies];
    [newCookies addObject:sidCookie];
    [cookieStorage setCookies:newCookies forURL:hostURL mainDocumentURL:nil];
    
    // If we have the UnauthorizedViewController, we're in the initialization of the app.
    // Remove this view controller, and let PhoneGap continue its initialization with the
    // standard view controller.
    if (self.authViewController) {
        self.window.rootViewController = nil;
        self.authViewController = nil;
        self.window = nil;
        [super application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil];
    }
    else {
        // This is just a re-auth event in the running app.  Send the login event to JS.
        [self sendJavascriptLoginEvent:self.webView];
    }
}

/**
 * This method will raise a Javascript event, informing the application that the
 * authentication process has completed.  The consuming web app can respond to the
 * 'saleforce_oauth_login' event, and utilize the credentials passed back.
 */
- (void)sendJavascriptLoginEvent:(UIWebView *)webView {
    NSString *accessToken = self.coordinator.credentials.accessToken;
    NSString *refreshToken = self.coordinator.credentials.refreshToken;
    NSString *clientId = self.coordinator.credentials.clientId;
    NSString *instanceUrl = self.coordinator.credentials.instanceUrl.absoluteString;
    NSString *loginUrl = [NSString stringWithFormat:@"%@://%@", self.coordinator.credentials.protocol,
                          self.coordinator.credentials.domain];
    
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
                          "  };"
                          "  document.dispatchEvent(e);"
                          "})()",
                          accessToken,
                          refreshToken,
                          clientId,
                          loginUrl,
                          instanceUrl];
    [webView stringByEvaluatingJavaScriptFromString:jsString];
}

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:willBeginAuthenticationWithView");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:didBeginAuthenticationWithView");
    
    if (self.authViewController) {
        // We're in the initialization of the app.  Make sure the auth view is in the foreground.
        [self.window bringSubviewToFront:self.authViewController.view];
        [self.authViewController setOauthView:view];
    }
    else
        [self.viewController.view addSubview:view];
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator {
    NSLog(@"oauthCoordinatorDidAuthenticate for userId: %@", coordinator.credentials.userId);
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
