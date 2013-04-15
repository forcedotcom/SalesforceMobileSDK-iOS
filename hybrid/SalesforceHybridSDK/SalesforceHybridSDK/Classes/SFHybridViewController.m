/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 Author: Kevin Hawkins
 
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

#import "SFHybridViewController.h"
#import "SalesforceSDKConstants.h"
#import "SFContainerAppDelegate.h"
#import "NSURL+SFStringUtils.h"
#import "NSURL+SFAdditions.h"
#import "SFContainerAppDelegate.h"
#import "SFAccountManager.h"
#import "SFAuthenticationManager.h"
#import "SFLogger.h"
#import "SFHybridViewConfig.h"
#import "SFSDKWebUtils.h"
#import "CDVCommandDelegateImpl.h"
#import "CDVConnection.h"

// Public constants
NSString * const kSFMobileSDKHybridDesignator = @"Hybrid";
NSString * const kAppHomeUrlPropKey = @"AppHomeUrl";

NSString * const kAccessTokenCredentialsDictKey = @"accessToken";
NSString * const kRefreshTokenCredentialsDictKey = @"refreshToken";
NSString * const kClientIdCredentialsDictKey = @"clientId";
NSString * const kUserIdCredentialsDictKey = @"userId";
NSString * const kOrgIdCredentialsDictKey = @"orgId";
NSString * const kLoginUrlCredentialsDictKey = @"loginUrl";
NSString * const kInstanceUrlCredentialsDictKey = @"instanceUrl";
NSString * const kUserAgentCredentialsDictKey = @"userAgentString";

@interface SFHybridViewController()
{
    BOOL _foundHomeUrl;
    SFHybridViewConfig *_hybridViewConfig;
    BOOL _appLoadComplete;
}

/**
 * Whether or not the input URL is one of the reserved URLs in the login flow, for consideration
 * in determining the app's ultimate home page.
 * @param url The URL to test.
 * @return YES if the value is one of the reserved URLs, NO otherwise.
 */
- (BOOL)isReservedUrlValue:(NSURL *)url;

- (void)validateHybridViewConfig;
- (BOOL)isOffline;

/**
 * The file URL string for the start page, as it will be reported in webViewDidFinishLoad:
 */
- (NSString *)startPageUrlString;

/**
 * Method called after re-authentication completes (after session timeout).
 * @param originalUrl The original URL being called before the session timed out.
 */
- (void)authenticationCompletion:(NSURL *)originalUrl authInfo:(SFOAuthInfo *)authInfo;

/**
 This method is called when the hidden UIWebView has finished loading
 the ping page.
 */
- (void)postVFPingPageLoad;

/**
 Converts the OAuth properties JSON input string into an object, and populates
 the OAuth properties of the plug-in with the values.
 @param propsDict The NSDictionary containing the OAuth properties.
 */
- (void)populateOAuthProperties:(NSDictionary *)propsDict;

/**
 Hidden UIWebView used to load the VF ping page.
 */
@property (nonatomic, strong) UIWebView *vfPingPageHiddenWebView;

@end

@implementation SFHybridViewController

#pragma mark - Init / dealloc / etc.

- (id)init
{
    return [self initWithConfig:nil];
}

- (id)initWithConfig:(SFHybridViewConfig *)viewConfig
{
    self = [super init];
    if (self) {
        _hybridViewConfig = (viewConfig == nil ? [SFHybridViewConfig fromDefaultConfigFile] : viewConfig);
        
        // There are a number of required values from the config file.
        [self validateHybridViewConfig];
        
        [SFAccountManager setClientId:_hybridViewConfig.remoteAccessConsumerKey];
        [SFAccountManager setRedirectUri:_hybridViewConfig.oauthRedirectURI];
        [SFAccountManager setScopes:_hybridViewConfig.oauthScopes];
        self.startPage = _hybridViewConfig.startPage;
    }
    return self;
}

- (void)viewDidLoad
{
    if ([self isOffline] && (!_hybridViewConfig.isLocal || _hybridViewConfig.shouldAuthenticate)) {
        if (_hybridViewConfig.attemptOfflineLoad) {
            NSString *urlString = [self.appHomeUrl absoluteString];
            if ([urlString length] == 0) {
                // TODO: Offline error.
                [self loadErrorPage];
            } else {
                // Try to load offline page.
                self.startPage = urlString;
                [super viewDidLoad];
            }
        }
    } else {
        if (_hybridViewConfig.shouldAuthenticate) {
            [SFSDKWebUtils configureUserAgent:[[self class] sfHybridViewUserAgentString]];
            [[SFAuthenticationManager sharedManager] loginWithCompletion:^(SFOAuthInfo *authInfo) {
                [self authenticationCompletion:nil authInfo:authInfo];
                [super viewDidLoad];
            } failure:^(SFOAuthInfo *authInfo, NSError *error) {
                [self log:SFLogLevelError msg:@"Initial authentication failed.  Logging out."];
                [[SFAuthenticationManager sharedManager] logout];
            }];
        } else {
            // Start page already set.  Just try to load through Cordova.
            [super viewDidLoad];
        }
    }
}

- (void)authenticateWithCompletionBlock:(SFOAuthPluginAuthSuccessBlock)completionBlock failureBlock:(SFOAuthFlowFailureCallbackBlock)failureBlock
{
    // Re-configure user agent.  Basically this ensures that Cordova whitelisting won't apply to the
    // UIWebView that hosts the login screen (important for SSO outside of Salesforce domains).
    [SFSDKWebUtils configureUserAgent:[[self class] sfHybridViewUserAgentString]];
    [[SFAuthenticationManager sharedManager] login:self completion:completionBlock failure:failureBlock];
}

- (void)getAuthCredentialsWithCompletionBlock:(SFOAuthPluginAuthSuccessBlock)completionBlock failureBlock:(SFOAuthFlowFailureCallbackBlock)failureBlock
{
    // If authDict does not contain an access token, authenticate first. Otherwise, send current credentials.
    NSDictionary *authDict = [[self class] credentialsAsDictionary];
    if (authDict == nil || [authDict objectForKey:kAccessTokenCredentialsDictKey] == nil
        || [[authDict objectForKey:kAccessTokenCredentialsDictKey] length] == 0) {
        [self authenticateWithCompletionBlock:completionBlock failureBlock:failureBlock];
    } else {
        completionBlock(nil, authDict);
    }
}

- (BOOL)isOffline
{
    CDVConnection *connection = [self getCommandInstance:@"NetworkStatus"];
    NSString *connectionType = [[connection.connectionType stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    return (connectionType == nil || [connectionType length] == 0 || [connectionType isEqualToString:@"unknown"] || [connectionType isEqualToString:@"none"]);
}

- (NSURL *)appHomeUrl
{
    return [[NSUserDefaults standardUserDefaults] URLForKey:kAppHomeUrlPropKey];
}

- (void)setAppHomeUrl:(NSURL *)appHomeUrl
{
    [[NSUserDefaults standardUserDefaults] setURL:appHomeUrl forKey:kAppHomeUrlPropKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadLocalStartPage
{
    assert([_hybridViewConfig isLocal]);
    NSString *localStartPage = [_hybridViewConfig startPage];
    NSURL *localURL = [[NSURL alloc] initWithString:localStartPage];
    NSURLRequest *localPageRequest = [[NSURLRequest alloc] initWithURL:localURL];
    [self.vfPingPageHiddenWebView loadRequest:localPageRequest];
    _appLoadComplete = YES;
}

- (void)loadRemoteStartPage
{
    assert(![_hybridViewConfig isLocal]);
    NSString *remoteStartPage = [_hybridViewConfig startPage];
    NSURL *remoteURL = [[NSURL alloc] initWithString:[self getFrontDoorURL:remoteStartPage]];
    NSURLRequest *remotePageRequest = [[NSURLRequest alloc] initWithURL:remoteURL];
    [self.vfPingPageHiddenWebView loadRequest:remotePageRequest];
    _appLoadComplete = YES;
}

- (void)loadErrorPage
{
    NSString *errorPage = [_hybridViewConfig errorPage];
    _appLoadComplete = YES;
}

- (NSString *)getFrontDoorURL:(NSString *)remoteStartPage
{
    SFOAuthCredentials *creds = [SFAccountManager sharedInstance].coordinator.credentials;
    NSString *instanceURL = creds.instanceUrl.absoluteString;
    NSString *accessToken = creds.accessToken;
    NSMutableString *fullURL = [[NSMutableString alloc] initWithString:instanceURL];
    [fullURL appendString:@"/secur/frontdoor.jsp"];
    [fullURL appendString:@"?sid="];
    [fullURL appendString:accessToken];
    [fullURL appendString:@"&retURL="];
    [fullURL appendString:remoteStartPage];
    [fullURL appendString:@"&display=touch"];
    return fullURL;
}

- (void)validateHybridViewConfig
{
    NSAssert(_hybridViewConfig != nil, @"You must supply a valid hybrid view configuration.");
    NSString *trimmedConsumerKey = [_hybridViewConfig.remoteAccessConsumerKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *trimmedRedirectURI = [_hybridViewConfig.oauthRedirectURI stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSAssert([trimmedConsumerKey length] > 0, @"remoteAccessConsumerKey must have a value in the hybrid view configuration.");
    NSAssert([trimmedRedirectURI length] > 0, @"oauthRedirectURI must have a value in the hybrid view configuration.");
    NSAssert([_hybridViewConfig.oauthScopes count] > 0, @"You must provide at least one OAuth scope in the hybrid view configuration.");
}

+ (NSDictionary *)credentialsAsDictionary
{
    NSDictionary *credentialsDict = nil;
    SFOAuthCredentials *creds = [SFAccountManager sharedInstance].coordinator.credentials;
    if (nil != creds) {
        NSString *instanceUrl = creds.instanceUrl.absoluteString;
        NSString *loginUrl = [NSString stringWithFormat:@"%@://%@", creds.protocol, creds.domain];
        NSString *uaString = [self sfHybridViewUserAgentString];
        credentialsDict = [NSDictionary dictionaryWithObjectsAndKeys:
                           creds.accessToken, kAccessTokenCredentialsDictKey,
                           creds.refreshToken, kRefreshTokenCredentialsDictKey,
                           creds.clientId, kClientIdCredentialsDictKey,
                           creds.userId, kUserIdCredentialsDictKey,
                           creds.organizationId, kOrgIdCredentialsDictKey,
                           loginUrl, kLoginUrlCredentialsDictKey,
                           instanceUrl, kInstanceUrlCredentialsDictKey,
                           uaString, kUserAgentCredentialsDictKey,
                           nil];
    }
    return credentialsDict;
}

/**
 * Prepend a user agent string to the current one, based on device, application, and SDK
 * version information.
 * We are building a user agent of the form:
 *   SalesforceMobileSDK/1.0 iPhone OS/3.2.0 (iPad) appName/appVersion Hybrid [Current User Agent]
 */
+ (NSString *)sfHybridViewUserAgentString
{
    static NSString *singletonUserAgentString = nil;
    
    // Only calculate this once in the app process lifetime.
    if (singletonUserAgentString == nil) {
        NSString *currentUserAgent = [SFSDKWebUtils currentUserAgentForApp];
        
        UIDevice *curDevice = [UIDevice currentDevice];
        NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
        NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
        
        singletonUserAgentString = [NSString stringWithFormat:
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
    }
    
    return singletonUserAgentString;
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    [self log:SFLogLevelDebug format:@"webView:shouldStartLoadWithRequest: Loading URL '%@'",
     [request.URL redactedAbsoluteString:[NSArray arrayWithObject:@"sid"]]];
    
    if ([webView isEqual:self.vfPingPageHiddenWebView]) {
        [self log:SFLogLevelDebug msg:@"Setting up VF web state."];
        return YES;
    }
    
    if ([SFAuthenticationManager isLoginRedirectUrl:request.URL]) {
        [self log:SFLogLevelWarning msg:@"Caught login redirect from session timeout.  Re-authenticating."];
        // Re-configure user agent.  Basically this ensures that Cordova whitelisting won't apply to the
        // UIWebView that hosts the login screen (important for SSO outside of Salesforce domains).
        [SFSDKWebUtils configureUserAgent:[[self class] sfHybridViewUserAgentString]];
        [[SFAuthenticationManager sharedManager] login:self
            completion:^(SFOAuthInfo *authInfo) {
                // Reset the user agent back to Cordova.
                [SFSDKWebUtils configureUserAgent:self.userAgent];
                [self authenticationCompletion:request.URL authInfo:authInfo];
            }
            failure:^(SFOAuthInfo *authInfo, NSError *error) {
                [[SFAuthenticationManager sharedManager] logout];
            }
         ];
        return NO;
    }
    return [super webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
}

- (void)webViewDidFinishLoad:(UIWebView *)theWebView
{
    if ([theWebView isEqual:self.vfPingPageHiddenWebView]) {
        [self log:SFLogLevelDebug msg:@"SalesforceOAuthPlugin: Finished loading VF ping page."];
        [self postVFPingPageLoad];
        return;
    }
    NSURL *requestUrl = theWebView.request.URL;
    NSArray *redactParams = [NSArray arrayWithObjects:@"sid", nil];
    NSString *redactedUrl = [requestUrl redactedAbsoluteString:redactParams];
    [self log:SFLogLevelDebug format:@"webViewDidFinishLoad: Loaded %@", redactedUrl];
    
    // The first URL that's loaded that's not considered a 'reserved' URL (i.e. one that Salesforce or
    // this app's infrastructure is responsible for) will be considered the "app home URL", which can
    // be loaded directly in the event that the app is offline.
    if (_foundHomeUrl == NO) {
        [self log:SFLogLevelInfo format:@"Checking %@ as a 'home page' URL candidate for this app.", redactedUrl];
        if (![self isReservedUrlValue:requestUrl]) {
            [self log:SFLogLevelInfo format:@"Setting %@ as the 'home page' URL for this app.", redactedUrl];
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
    
    [super webViewDidFinishLoad:theWebView];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self log:SFLogLevelDebug msg:@"SalesforceOAuthPlugin: Started loading web page."];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"SalesforceOAuthPlugin: Error while attempting to load web page: %@", error);
}

#pragma mark - URL evaluation helpers

- (BOOL)isReservedUrlValue:(NSURL *)url
{
    static NSArray *reservedUrlStrings = nil;
    if (reservedUrlStrings == nil) {
        reservedUrlStrings = [NSArray arrayWithObjects:
                               [self startPageUrlString],
                               @"/secur/frontdoor.jsp",
                               @"/secur/contentDoor",
                               nil];
    }
    if (url == nil || [url absoluteString] == nil || [[url absoluteString] length] == 0) {
        return NO;    
    }
    NSString *inputUrlString = [url absoluteString];
    for (int i = 0; i < [reservedUrlStrings count]; i++) {
        NSString *reservedString = [reservedUrlStrings objectAtIndex:i];
        NSRange range = [[inputUrlString lowercaseString] rangeOfString:[reservedString lowercaseString]];
        if (range.location != NSNotFound)
            return YES;
    }
    return NO;
}

- (NSString *)startPageUrlString
{
    NSString *startPageFilePath = [self.commandDelegate pathForResource:self.startPage];
    NSURL *startPageFileUrl = [NSURL fileURLWithPath:startPageFilePath];
    NSString *urlString = [[startPageFileUrl absoluteString] stringByReplacingOccurrencesOfString:@"file://localhost/"
                                                                                       withString:@"file:///"];
    return urlString;
}

#pragma mark - OAuth flow helpers

- (void)authenticationCompletion:(NSURL *)originalUrl authInfo:(SFOAuthInfo *)authInfo
{
    [self log:SFLogLevelDebug msg:@"authenticationCompletion:authInfo: - Initiating post-auth configuration."];
    [SFAuthenticationManager resetSessionCookie];
    if (authInfo.authType == SFOAuthTypeRefresh) {
        [self loadVFPingPage];
    }
    
    // If there's an original URL, load it through frontdoor.
    if (originalUrl != nil) {
        NSString *encodedStartUrlValue = [originalUrl valueForParameterName:@"startURL"];
        [self log:SFLogLevelDebug format:@"Authentication complete.  Redirecting to '%@' through frontdoor.",
         [encodedStartUrlValue stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        NSURL *returnUrlAfterAuth = [SFAuthenticationManager frontDoorUrlWithReturnUrl:encodedStartUrlValue returnUrlIsEncoded:YES];
        NSURLRequest *newRequest = [NSURLRequest requestWithURL:returnUrlAfterAuth];
        [self.webView loadRequest:newRequest];
    }
}

#pragma mark - Cordova overrides

+ (NSString *)originalUserAgent
{
    // Overriding Cordova's method because we don't want the chance of our user agent not being
    // configured first, and thus overwritten with a bad value.
    return [self sfHybridViewUserAgentString];
}

- (void)loadVFPingPage
{
    SFOAuthCredentials *creds = [SFAccountManager sharedInstance].coordinator.credentials;
    NSString *instanceUrlString = creds.instanceUrl.absoluteString;
    if (nil != instanceUrlString) {
        NSMutableString *instanceUrl = [[NSMutableString alloc] initWithString:instanceUrlString];
        [instanceUrl appendString:@"/visualforce/session?url=/apexpages/utils/ping.apexp&autoPrefixVFDomain=true"];
        self.vfPingPageHiddenWebView = [[UIWebView alloc] initWithFrame:CGRectZero];
        [self.vfPingPageHiddenWebView setDelegate:self];
        NSURL *pingURL = [[NSURL alloc] initWithString:instanceUrl];
        NSURLRequest *pingRequest = [[NSURLRequest alloc] initWithURL:pingURL];
        [self.vfPingPageHiddenWebView loadRequest:pingRequest];
    }
}

- (void)postVFPingPageLoad
{
    [self.vfPingPageHiddenWebView setDelegate:nil];
    self.vfPingPageHiddenWebView = nil;
}


- (void)populateOAuthProperties:(NSDictionary *)propsDict
{
    if (nil != propsDict) {
        self.remoteAccessConsumerKey = [propsDict objectForKey:@"remoteAccessConsumerKey"];
        self.oauthRedirectURI = [propsDict objectForKey:@"oauthRedirectURI"];
        self.oauthScopes = [NSSet setWithArray:[propsDict objectForKey:@"oauthScopes"]];
    }
}

@end
