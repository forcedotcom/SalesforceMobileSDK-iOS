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
#import <SalesforceSDKCore/NSURL+SFStringUtils.h>
#import <SalesforceCommonUtils/NSURL+SFAdditions.h>
#import <SalesforceSDKCore/SFAccountManager.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFAuthErrorHandlerList.h>
#import <SalesforceSDKCore/SFSDKWebUtils.h>
#import <SalesforceSDKCore/SFSDKResourceUtils.h>
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
NSString * const kUserAgentCredentialsDictKey = @"userAgent";

// Error page constants
static NSString * const kErrorCodeParameterName = @"errorCode";
static NSString * const kErrorDescriptionParameterName = @"errorDescription";
static NSString * const kErrorContextParameterName = @"errorContext";
static NSInteger  const kErrorCodeNetworkOffline = 1;
static NSString * const kErrorContextAppLoading = @"AppLoading";
static NSString * const kErrorContextAuthExpiredSessionRefresh = @"AuthRefreshExpiredSession";

static NSString * const kVFPingPageUrl = @"/apexpages/utils/ping.apexp";

@interface SFHybridViewController()
{
    BOOL _foundHomeUrl;
    SFHybridViewConfig *_hybridViewConfig;
}

/**
 Hidden UIWebView used to load the VF ping page.
 */
@property (nonatomic, strong) UIWebView *vfPingPageHiddenWebView;

/**
 UIWebView for processing the error page, in the event of a fatal error during bootstrap.
 */
@property (nonatomic, strong) UIWebView *errorPageWebView;

/**
 * Whether or not the input URL is one of the reserved URLs in the login flow, for consideration
 * in determining the app's ultimate home page.
 * @param url The URL to test.
 * @return YES if the value is one of the reserved URLs, NO otherwise.
 */
- (BOOL)isReservedUrlValue:(NSURL *)url;

/**
 Makes sure the values in the hybrid view config are sufficient configuration.
 */
- (void)validateHybridViewConfig;

/**
 Reports whether the device is offline.
 @return YES if the device is offline, NO otherwise.
 */
- (BOOL)isOffline;

/**
 Determines whether the error is due to invalid credentials, and if so, whether the
 app should be logged out as a result.
 @param error The error to check against an invalid credentials error.
 @return YES if the error is due to invalid credentials and logout should occur, NO
 otherwise.
 */
- (BOOL)logoutOnInvalidCredentials:(NSError *)error;

/**
 Gets the file URL for the full path to the given page.
 @param page The relative page to create the path from.
 @return NSURL representing the file URL for the page path.
 */
- (NSURL *)fullFileUrlForPage:(NSString *)page;

/**
 Appends the error contents as querystring parameters to the input URL.
 @param rootUrl The base URL to use.
 @param errorCode The numeric error code associated with the error.
 @param errorDescription The error description associated with the error.
 @param errorContext The error context associated with the error.
 @return NSURL containing the base URL and the error parameter.
 */
- (NSURL *)createErrorPageUrl:(NSURL *)rootUrl code:(NSInteger)errorCode description:(NSString *)errorDescription context:(NSString *)errorContext;

/**
 Creates a default in-memory error page, in the event that a user-defined error page does not exist.
 @param errorCode The numeric error code associated with the error.
 @param errorDescription The error description associated with the error.
 @param errorContext The context associated with the error.
 @return An NSString containing the HTML content for the error page.
 */
- (NSString *)createDefaultErrorPageContentWithCode:(NSInteger)errorCode description:(NSString *)errorDescription context:(NSString *)errorContext;

/**
 Sets up the actual start page URL, which will be different depending on whether the app is
 local vs. remote.
 */
- (void)configureStartPage;

/**
 * Method called after re-authentication completes (after session timeout).
 * @param originalUrl The original URL being called before the session timed out.
 */
- (void)authenticationCompletion:(NSURL *)originalUrl authInfo:(SFOAuthInfo *)authInfo;

/**
 Loads the VF ping page in an invisible UIWebView and sets session cookies
 for the VF domain.
 */
- (void)loadVFPingPage;

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
        NSAssert(_hybridViewConfig != nil, @"_hybridViewConfig was not properly initialized.  See output log for errors.");
        
        // There are a number of required values from the config file.
        [self validateHybridViewConfig];
        
        [SFAccountManager setClientId:_hybridViewConfig.remoteAccessConsumerKey];
        [SFAccountManager setRedirectUri:_hybridViewConfig.oauthRedirectURI];
        [SFAccountManager setScopes:_hybridViewConfig.oauthScopes];
        self.startPage = _hybridViewConfig.startPage;
    }
    return self;
}

- (void)dealloc
{
    self.vfPingPageHiddenWebView.delegate = nil;
    SFRelease(_vfPingPageHiddenWebView);
    self.errorPageWebView.delegate = nil;
    SFRelease(_errorPageWebView);
}

- (void)viewDidLoad
{
    if (self.useSplashScreen) {
        [self showSplashScreen];
    }
    
    [SFSDKWebUtils configureUserAgent:[[self class] sfHybridViewUserAgentString]];
    if ([self isOffline] && (!_hybridViewConfig.isLocal || _hybridViewConfig.shouldAuthenticate)) {
        // Device is offline, and we have to try to load cached content.
        if (_hybridViewConfig.attemptOfflineLoad) {
            NSString *urlString = [self.appHomeUrl absoluteString];
            if ([urlString length] == 0) {
                NSString *offlineErrorDescription = [SFSDKResourceUtils localizedString:@"hybridBootstrapDeviceOffline"];
                [self loadErrorPageWithCode:kErrorCodeNetworkOffline description:offlineErrorDescription context:kErrorContextAppLoading];
            } else {
                // Try to load offline page.
                self.startPage = urlString;
                [super viewDidLoad];
            }
        }
    } else {
        // Device is online.
        if (_hybridViewConfig.shouldAuthenticate) {
            [[SFAuthenticationManager sharedManager] loginWithCompletion:^(SFOAuthInfo *authInfo) {
                [self authenticationCompletion:nil authInfo:authInfo];
                [self configureStartPage];
                [super viewDidLoad];
            } failure:^(SFOAuthInfo *authInfo, NSError *error) {
                if ([self logoutOnInvalidCredentials:error]) {
                    [self log:SFLogLevelError msg:@"Initial authentication failed.  Logging out."];
                    [[SFAuthenticationManager sharedManager] logout];
                } else {
                    // Error is not invalid credentials, or developer otherwise wants to handle it.
                    [self loadErrorPageWithCode:error.code description:error.localizedDescription context:kErrorContextAppLoading];
                }
            }];
        } else {
            // Start page already set.  Just try to load through Cordova.
            [super viewDidLoad];
        }
    }
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

#pragma mark - Property implementations

- (NSString *)remoteAccessConsumerKey
{
    return _hybridViewConfig.remoteAccessConsumerKey;
}

- (NSString *)oauthRedirectURI
{
    return _hybridViewConfig.oauthRedirectURI;
}

- (NSSet *)oauthScopes
{
    return _hybridViewConfig.oauthScopes;
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

#pragma mark - Public methods

- (void)authenticateWithCompletionBlock:(SFOAuthPluginAuthSuccessBlock)completionBlock failureBlock:(SFOAuthFlowFailureCallbackBlock)failureBlock
{
    // Re-configure user agent.  Basically this ensures that Cordova whitelisting won't apply to the
    // UIWebView that hosts the login screen (important for SSO outside of Salesforce domains).
    [SFSDKWebUtils configureUserAgent:[[self class] sfHybridViewUserAgentString]];
    [[SFAuthenticationManager sharedManager] loginWithCompletion:^(SFOAuthInfo *authInfo) {
        [self authenticationCompletion:nil authInfo:authInfo];
        if (authInfo.authType == SFOAuthTypeRefresh) {
            [self loadVFPingPage];
        }
        if (completionBlock != NULL) {
            NSDictionary *authDict = [[self class] credentialsAsDictionary];
            completionBlock(authInfo, authDict);
        }
    } failure:^(SFOAuthInfo *authInfo, NSError *error) {
        if ([self logoutOnInvalidCredentials:error]) {
            [self log:SFLogLevelError msg:@"OAuth plugin authentication request failed.  Logging out."];
            [[SFAuthenticationManager sharedManager] logout];
        } else if (failureBlock != NULL) {
            failureBlock(authInfo, error);
        }
    }];
}

- (void)getAuthCredentialsWithCompletionBlock:(SFOAuthPluginAuthSuccessBlock)completionBlock failureBlock:(SFOAuthFlowFailureCallbackBlock)failureBlock
{
    // If authDict does not contain an access token, authenticate first. Otherwise, send current credentials.
    NSDictionary *authDict = [[self class] credentialsAsDictionary];
    if ([[authDict objectForKey:kAccessTokenCredentialsDictKey] length] == 0) {
        [self authenticateWithCompletionBlock:completionBlock failureBlock:failureBlock];
    } else {
        if (completionBlock != NULL) {
            completionBlock(nil, authDict);
        }
    }
}

- (void)loadErrorPageWithCode:(NSInteger)errorCode description:(NSString *)errorDescription context:(NSString *)errorContext
{
    NSString *errorPage = _hybridViewConfig.errorPage;
    NSURL *errorPageUrl = [self fullFileUrlForPage:errorPage];
    self.errorPageWebView = [[UIWebView alloc] initWithFrame:self.view.frame];
    self.errorPageWebView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.errorPageWebView.delegate = self;
    [self.view addSubview:self.errorPageWebView];
    if (errorPageUrl != nil) {
        NSURL *errorPageUrlWithError = [self createErrorPageUrl:errorPageUrl code:errorCode description:errorDescription context:errorContext];
        NSURLRequest *errorRequest = [NSURLRequest requestWithURL:errorPageUrlWithError];
        [self.errorPageWebView loadRequest:errorRequest];
    } else {
        // Error page does not exist.  Generate a generic page with the error.
        NSString *errorContent = [self createDefaultErrorPageContentWithCode:errorCode description:errorDescription context:errorContext];
        [self.errorPageWebView loadHTMLString:errorContent baseURL:nil];
    }
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
                                    SALESFORCE_SDK_VERSION,
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

#pragma mark - Private methods

- (BOOL)isOffline
{
    CDVConnection *connection = [self getCommandInstance:@"NetworkStatus"];
    NSString *connectionType = [[connection.connectionType stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    return (connectionType == nil || [connectionType length] == 0 || [connectionType isEqualToString:@"unknown"] || [connectionType isEqualToString:@"none"]);
}

- (BOOL)logoutOnInvalidCredentials:(NSError *)error
{
    return ([SFAuthenticationManager errorIsInvalidAuthCredentials:error]
            && [[SFAuthenticationManager sharedManager].authErrorHandlerList authErrorHandlerInList:[SFAuthenticationManager sharedManager].invalidCredentialsAuthErrorHandler]);
}

- (NSURL *)fullFileUrlForPage:(NSString *)page
{
    NSString *fullPath = [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:self.wwwFolderName] stringByAppendingPathComponent:page];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
        return nil;
    }
    
    NSURL *fileUrl = [NSURL fileURLWithPath:fullPath];
    return fileUrl;
}

- (NSURL *)createErrorPageUrl:(NSURL *)rootUrl code:(NSInteger)errorCode description:(NSString *)errorDescription context:(NSString *)errorContext
{
    NSMutableString *errorPageUrlString = [NSMutableString stringWithString:[rootUrl absoluteString]];
    [rootUrl query] == nil ? [errorPageUrlString appendString:@"?"] : [errorPageUrlString appendString:@"&"];
    [errorPageUrlString appendFormat:@"%@=%d", kErrorCodeParameterName, errorCode];
    [errorPageUrlString appendFormat:@"&%@=%@",
     kErrorDescriptionParameterName,
     [errorDescription stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [errorPageUrlString appendFormat:@"&%@=%@",
     kErrorContextParameterName,
     [errorContext stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    return [NSURL URLWithString:errorPageUrlString];
}

- (NSString *)createDefaultErrorPageContentWithCode:(NSInteger)errorCode description:(NSString *)errorDescription context:(NSString *)errorContext
{
    NSString *htmlContent = [NSString stringWithFormat:
                             @"<html>\
                             <head>\
                               <title>Bootstrap Error Page</title>\
                             </head>\
                             <body>\
                               <h1>Bootstrap Error Page</h1>\
                               <p>Error code: %d</p>\
                               <p>Error description: %@</p>\
                               <p>Error context: %@</p>\
                             </body>\
                             </html>", errorCode, errorDescription, errorContext];
    return htmlContent;
}

- (void)configureStartPage
{
    // Note: You only want this to ever run once in the view controller's lifetime.
    static BOOL startPageConfigured = NO;
    
    // If the start page is local, Cordova knows how to parse the start page.  Just leave it for the parent.
    if (!_hybridViewConfig.isLocal) {
        self.startPage = [[SFAuthenticationManager frontDoorUrlWithReturnUrl:self.startPage returnUrlIsEncoded:NO] absoluteString];
    }
    
    startPageConfigured = YES;
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

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    [self log:SFLogLevelDebug format:@"webView:shouldStartLoadWithRequest: Loading URL '%@'",
     [request.URL redactedAbsoluteString:[NSArray arrayWithObject:@"sid"]]];
    
    // Hidden ping page load.
    if ([webView isEqual:self.vfPingPageHiddenWebView]) {
        [self log:SFLogLevelDebug msg:@"Setting up VF web state after plugin-based refresh."];
        return YES;
    }
    
    // Local error page load.
    if ([webView isEqual:self.errorPageWebView]) {
        [self log:SFLogLevelDebug format:@"Local error page ('%@') is loading.", request.URL.absoluteString];
        return YES;
    }
    
    // Cordova web view load.
    if ([webView isEqual:self.webView]) {
        // If the request is attempting to refresh an invalid session, take over the refresh process via the
        // OAuth refresh flow in the container.
        if ([SFAuthenticationManager isLoginRedirectUrl:request.URL]) {
            [self log:SFLogLevelWarning msg:@"Caught login redirect from session timeout.  Re-authenticating."];
            // Re-configure user agent.  Basically this ensures that Cordova whitelisting won't apply to the
            // UIWebView that hosts the login screen (important for SSO outside of Salesforce domains).
            [SFSDKWebUtils configureUserAgent:[[self class] sfHybridViewUserAgentString]];
            [[SFAuthenticationManager sharedManager]
             loginWithCompletion:^(SFOAuthInfo *authInfo) {
                 // Reset the user agent back to Cordova.
                 [self authenticationCompletion:request.URL authInfo:authInfo];
             }
             failure:^(SFOAuthInfo *authInfo, NSError *error) {
                 if ([self logoutOnInvalidCredentials:error]) {
                     [self log:SFLogLevelError msg:@"Could not refresh expired session.  Logging out."];
                     [[SFAuthenticationManager sharedManager] logout];
                 } else {
                     // Error is not invalid credentials, or developer otherwise wants to handle it.
                     [self loadErrorPageWithCode:error.code description:error.localizedDescription context:kErrorContextAuthExpiredSessionRefresh];
                 }
             }];
            
            return NO;
        }
    }
    
    return [super webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
}

- (void)webViewDidFinishLoad:(UIWebView *)theWebView
{
    NSURL *requestUrl = theWebView.request.URL;
    NSArray *redactParams = [NSArray arrayWithObjects:@"sid", nil];
    NSString *redactedUrl = [requestUrl redactedAbsoluteString:redactParams];
    [self log:SFLogLevelDebug format:@"webViewDidFinishLoad: Loaded %@", redactedUrl];
    
    if ([theWebView isEqual:self.vfPingPageHiddenWebView]) {
        [self log:SFLogLevelDebug format:@"Finished loading VF ping page '%@'.", redactedUrl];
        return;
    }
    
    if ([theWebView isEqual:self.webView]) {
        // The first URL that's loaded that's not considered a 'reserved' URL (i.e. one that Salesforce or
        // this app's infrastructure is responsible for) will be considered the "app home URL", which can
        // be loaded directly in the event that the app is offline.
        if (_foundHomeUrl == NO) {
            [self log:SFLogLevelInfo format:@"Checking %@ as a 'home page' URL candidate for this app.", redactedUrl];
            if (![self isReservedUrlValue:requestUrl]) {
                [self log:SFLogLevelInfo format:@"Setting %@ as the 'home page' URL for this app.", redactedUrl];
                self.appHomeUrl = requestUrl;
                _foundHomeUrl = YES;
            }
        }
    }
    
    [super webViewDidFinishLoad:theWebView];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self log:SFLogLevelDebug msg:@"Started loading web page."];
    [super webViewDidStartLoad:webView];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [self log:SFLogLevelError format:@"Error while attempting to load web page: %@", error];
    [super webView:webView didFailLoadWithError:error];
}

#pragma mark - URL evaluation helpers

- (BOOL)isReservedUrlValue:(NSURL *)url
{
    static NSArray *reservedUrlStrings = nil;
    if (reservedUrlStrings == nil) {
        reservedUrlStrings = [NSArray arrayWithObjects:
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

#pragma mark - OAuth flow helpers

- (void)authenticationCompletion:(NSURL *)originalUrl authInfo:(SFOAuthInfo *)authInfo
{
    [self log:SFLogLevelDebug msg:@"authenticationCompletion:authInfo: - Initiating post-auth configuration."];
    [SFAuthenticationManager resetSessionCookie];
    
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

- (void)loadVFPingPage
{
    SFOAuthCredentials *creds = [SFAccountManager sharedInstance].coordinator.credentials;
    NSString *instanceUrlString = creds.instanceUrl.absoluteString;
    if (nil != instanceUrlString) {
        NSMutableString *instanceUrl = [[NSMutableString alloc] initWithString:instanceUrlString];
        NSString *encodedPingUrlParam = [kVFPingPageUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [instanceUrl appendFormat:@"/visualforce/session?url=%@&autoPrefixVFDomain=true", encodedPingUrlParam];
        self.vfPingPageHiddenWebView = [[UIWebView alloc] initWithFrame:CGRectZero];
        self.vfPingPageHiddenWebView.delegate = self;
        NSURL *pingURL = [[NSURL alloc] initWithString:instanceUrl];
        NSURLRequest *pingRequest = [[NSURLRequest alloc] initWithURL:pingURL];
        [self.vfPingPageHiddenWebView loadRequest:pingRequest];
    }
}

#pragma mark - Cordova overrides

+ (NSString *)originalUserAgent
{
    // Overriding Cordova's method because we don't want the chance of our user agent not being
    // configured first, and thus overwritten with a bad value.
    return [self sfHybridViewUserAgentString];
}

@end
