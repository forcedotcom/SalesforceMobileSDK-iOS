/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
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
#import "SFHybridConnectionMonitor.h"
#import "SalesforceHybridSDKManager.h"
#import <SalesforceSDKCore/SFSDKAppFeatureMarkers.h>
#import <SalesforceSDKCore/SalesforceSDKManager.h>
#import <SalesforceSDKCore/NSURL+SFStringUtils.h>
#import <SalesforceSDKCore/NSURL+SFAdditions.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFAuthErrorHandlerList.h>
#import <SalesforceSDKCore/SFSDKWebUtils.h>
#import <SalesforceSDKCore/SFSDKResourceUtils.h>
#import <SalesforceSDKCore/SFSDKEventBuilderHelper.h>
#import <SalesforceSDKCore/NSString+SFAdditions.h>
#import <SalesforceSDKCore/SFSDKWebViewStateManager.h>
#import <SalesforceSDKCore/SFRestAPI+Blocks.h>
#import <Cordova/NSDictionary+CordovaPreferences.h>
#import <Cordova/CDVUserAgentUtil.h>
#import <objc/message.h>

// Public constants.
NSString * const kAppHomeUrlPropKey = @"AppHomeUrl";
NSString * const kAccessTokenCredentialsDictKey = @"accessToken";
NSString * const kRefreshTokenCredentialsDictKey = @"refreshToken";
NSString * const kClientIdCredentialsDictKey = @"clientId";
NSString * const kUserIdCredentialsDictKey = @"userId";
NSString * const kOrgIdCredentialsDictKey = @"orgId";
NSString * const kLoginUrlCredentialsDictKey = @"loginUrl";
NSString * const kInstanceUrlCredentialsDictKey = @"instanceUrl";
NSString * const kUserAgentCredentialsDictKey = @"userAgent";

// Error page constants.
static NSString * const kErrorCodeParameterName = @"errorCode";
static NSString * const kErrorDescriptionParameterName = @"errorDescription";
static NSString * const kErrorContextParameterName = @"errorContext";
static NSInteger  const kErrorCodeNetworkOffline = 1;
static NSInteger  const kErrorCodeNoCredentials = 2;
static NSString * const kErrorContextAppLoading = @"AppLoading";
static NSString * const kErrorContextAuthExpiredSessionRefresh = @"AuthRefreshExpiredSession";
static NSString * const kVFPingPageUrl = @"/apexpages/utils/ping.apexp";

// App feature constant.
static NSString * const kSFAppFeatureUsesUIWebView = @"WV";
SFSDK_USE_DEPRECATED_BEGIN
@interface SFHybridViewController()
{
    BOOL _foundHomeUrl;
    SFHybridViewConfig *_hybridViewConfig;
}

@property (nonatomic, readwrite, assign) BOOL useUIWebView;

/**
 * Hidden WKWebView used to load the VF ping page.
 */
@property (nonatomic, strong) WKWebView *vfPingPageHiddenWKWebView;

/**
 * Hidden UIWebView used to load the VF ping page.
 */
@property (nonatomic, strong) UIWebView *vfPingPageHiddenUIWebView;

/**
 * WKWebView for processing the error page, in the event of a fatal error during bootstrap.
 */
@property (nonatomic, strong) WKWebView *errorPageWKWebView;

/**
 * UIWebView for processing the error page, in the event of a fatal error during bootstrap.
 */
@property (nonatomic, strong) UIWebView *errorPageUIWebView;

/**
 * Whether or not the input URL is one of the reserved URLs in the login flow, for consideration
 * in determining the app's ultimate home page.
 *
 * @param url The URL to test.
 * @return YES - if the value is one of the reserved URLs, NO - otherwise.
 */
- (BOOL)isReservedUrlValue:(NSURL *)url;

/**
 * Reports whether the device is offline.
 *
 * @return YES - if the device is offline, NO - otherwise.
 */
- (BOOL)isOffline;

/**
 * Determines whether the error is due to invalid credentials, and if so, whether the
 * app should be logged out as a result.
 *
 * @param error The error to check against an invalid credentials error.
 * @return YES - if the error is due to invalid credentials and logout should occur, NO - otherwise.
 */
- (BOOL)logoutOnInvalidCredentials:(NSError *)error;

/**
 * Gets the file URL for the full path to the given page.
 *
 * @param page The relative page to create the path from.
 * @return NSURL representing the file URL for the page path.
 */
- (NSURL *)fullFileUrlForPage:(NSString *)page;

/**
 * Appends the error contents as querystring parameters to the input URL.
 *
 * @param rootUrl The base URL to use.
 * @param errorCode The numeric error code associated with the error.
 * @param errorDescription The error description associated with the error.
 * @param errorContext The error context associated with the error.
 * @return NSURL containing the base URL and the error parameter.
 */
- (NSURL *)createErrorPageUrl:(NSURL *)rootUrl code:(NSInteger)errorCode description:(NSString *)errorDescription context:(NSString *)errorContext;

/**
 * Creates a default in-memory error page, in the event that a user-defined error page does not exist.
 *
 * @param errorCode The numeric error code associated with the error.
 * @param errorDescription The error description associated with the error.
 * @param errorContext The context associated with the error.
 * @return An NSString containing the HTML content for the error page.
 */
- (NSString *)createDefaultErrorPageContentWithCode:(NSInteger)errorCode description:(NSString *)errorDescription context:(NSString *)errorContext;

/**
 * Method called after re-authentication completes (after session timeout).
 *
 * @param originalUrl The original URL being called before the session timed out.
 */
- (void)authenticationCompletion:(NSString *)originalUrl authInfo:(SFOAuthInfo *)authInfo;

/**
 * Loads the VF ping page in an invisible WKWebView and sets session cookies for the VF domain.
 */
- (void)loadVFPingPage;

@end

@implementation SFHybridViewController

- (id) init
{
    return [self initWithConfig:nil];
}

- (id) initWithConfig:(SFHybridViewConfig *) viewConfig
{
    return [self initWithConfig:viewConfig useUIWebView:NO];
}

- (id) initWithConfig:(SFHybridViewConfig *) viewConfig useUIWebView:(BOOL) useUIWebView
{
    self = [super init];
    if (self) {
        self.useUIWebView = useUIWebView;
        if (useUIWebView) {
            [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureUsesUIWebView];
        }
        _hybridViewConfig = (viewConfig == nil ? [SFHybridViewConfig fromDefaultConfigFile] : viewConfig);
        NSAssert(_hybridViewConfig != nil, @"_hybridViewConfig was not properly initialized. See output log for errors.");
        self.startPage = _hybridViewConfig.startPage;
        
        // Setup global stores and syncs defined in static configs
        [[SalesforceHybridSDKManager sharedManager] setupGlobalStoreFromDefaultConfig];
        [[SalesforceHybridSDKManager sharedManager] setupGlobalSyncsFromDefaultConfig];
    }
    return self;
}

- (UIView *)newCordovaViewWithFrame:(CGRect)bounds
{
    return [self newCordovaViewWithFrameAndEngine:bounds webViewEngine:self.useUIWebView ? @"CDVUIWebViewEngine" : @"CDVWKWebViewEngine"];
}

- (UIView *)newCordovaViewWithFrameAndEngine:(CGRect)bounds webViewEngine:(NSString *)webViewEngine
{
    [self.settings setCordovaSetting:webViewEngine forKey:@"CordovaWebViewEngine"];
    return [super newCordovaViewWithFrame:bounds];
}

- (void)dealloc
{
    self.vfPingPageHiddenWKWebView.navigationDelegate = nil;
    SFRelease(_vfPingPageHiddenWKWebView);
    self.vfPingPageHiddenUIWebView.delegate = nil;
    SFRelease(_vfPingPageHiddenUIWebView);
    self.errorPageWKWebView.navigationDelegate = nil;
    SFRelease(_errorPageWKWebView);
    self.errorPageUIWebView.delegate = nil;
    SFRelease(_errorPageUIWebView);
}

- (void)viewDidLoad
{
    NSString *hybridViewUserAgentString = [self sfHybridViewUserAgentString];
    [SFSDKWebUtils configureUserAgent:hybridViewUserAgentString];
    self.baseUserAgent = hybridViewUserAgentString;

    // If this app requires authentication at startup, and authentication hasn't happened, that's an error.
    NSString *accessToken = [SFUserAccountManager sharedInstance].currentUser.credentials.accessToken;
    if (_hybridViewConfig.shouldAuthenticate && [accessToken length] == 0) {
        NSString *noCredentials = [SFSDKResourceUtils localizedString:@"hybridBootstrapNoCredentialsAtStartup"];
        [self loadErrorPageWithCode:kErrorCodeNoCredentials description:noCredentials context:kErrorContextAppLoading];
        return;
    }
    
    // Setup user stores and syncs defined in static configs
    if ([SFUserAccountManager sharedInstance].currentUser) {
        [[SalesforceHybridSDKManager sharedManager] setupUserStoreFromDefaultConfig];
        [[SalesforceHybridSDKManager sharedManager] setupUserSyncsFromDefaultConfig];
    }

    // If the app is local, we should just be able to load it.
    if (_hybridViewConfig.isLocal) {
        [super viewDidLoad];
        return;
    }

    // Remote app. If the device is offline, we should attempt to load cached content.
    if ([self isOffline]) {

        // Device is offline, and we have to try to load cached content.
        NSString *urlString = [self.appHomeUrl absoluteString];
        if (_hybridViewConfig.attemptOfflineLoad && [urlString length] > 0) {

            // Try to load offline page.
            self.startPage = urlString;
            [super viewDidLoad];
        } else {
            NSString *offlineErrorDescription = [SFSDKResourceUtils localizedString:@"hybridBootstrapDeviceOffline"];
            [self loadErrorPageWithCode:kErrorCodeNetworkOffline description:offlineErrorDescription context:kErrorContextAppLoading];
        }
        return;
    }

    // Remote app. Device is online.
    if ([self userIsAuthenticated]) {
        [SFSDKHybridLogger i:[self class] format:@"[%@ %@]: Initiating web state cleanup strategy before loading start page.", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
        [self webStateCleanupStrategy];
    }
    [self configureRemoteStartPage];
    [super viewDidLoad];
}

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

- (SFHybridViewConfig *)hybridViewConfig
{
    return _hybridViewConfig;
}

- (void)authenticateWithCompletionBlock:(SFOAuthPluginAuthSuccessBlock)completionBlock failureBlock:(SFOAuthFlowFailureCallbackBlock)failureBlock
{

    /*
     * Reconfigure user agent. Basically this ensures that Cordova whitelisting won't apply to the
     * WKWebView that hosts the login screen (important for SSO outside of Salesforce domains).
     */
    [SFSDKWebUtils configureUserAgent:[self sfHybridViewUserAgentString]];
    __weak __typeof(self) weakSelf = self;
    SFOAuthFlowSuccessCallbackBlock authCompletionBlock = ^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [SFUserAccountManager sharedInstance].currentUser = userAccount;
        [strongSelf authenticationCompletion:nil authInfo:authInfo];
        if (authInfo.authType == SFOAuthTypeRefresh) {
            [strongSelf loadVFPingPage];
        }
        if (completionBlock != NULL) {
            NSDictionary *authDict = [self credentialsAsDictionary];
            completionBlock(authInfo, authDict);
        }
    };
    SFOAuthFlowFailureCallbackBlock authFailureBlock = ^(SFOAuthInfo *authInfo, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if ([strongSelf logoutOnInvalidCredentials:error]) {
            [SFSDKHybridLogger d:[strongSelf class] message:@"OAuth plugin authentication request failed. Logging out."];
            NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
            attributes[@"errorCode"] = [NSNumber numberWithInteger:error.code];
            attributes[@"errorDescription"] = error.localizedDescription;
            [SFSDKEventBuilderHelper createAndStoreEvent:@"userLogout" userAccount:nil className:NSStringFromClass([self class]) attributes:attributes];
            [strongSelf logout];
        } else if (failureBlock != NULL) {
            failureBlock(authInfo, error);
        }
    };
    if (![SFUserAccountManager sharedInstance].currentUser) {
        [self loginWithCompletion:authCompletionBlock failure:authFailureBlock];
    } else {
        [self refreshCredentials:[SFUserAccountManager sharedInstance].currentUser.credentials
                                                         completion:authCompletionBlock
                                                            failure:authFailureBlock];
    }
}

- (void)loadErrorPageWithCode:(NSInteger)errorCode description:(NSString *)errorDescription context:(NSString *)errorContext
{
    NSString *errorPage = _hybridViewConfig.errorPage;
    NSURL *errorPageUrl = [self fullFileUrlForPage:errorPage];
    if (self.useUIWebView) {
        self.errorPageUIWebView = [[UIWebView alloc] initWithFrame:self.view.frame];
        self.errorPageUIWebView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        self.errorPageUIWebView.delegate = self;
        [self.view addSubview:self.errorPageUIWebView];
    } else {
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        config.processPool = SFSDKWebViewStateManager.sharedProcessPool;
        self.errorPageWKWebView = [[WKWebView alloc] initWithFrame:self.view.frame configuration:config];
        self.errorPageWKWebView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        self.errorPageWKWebView.navigationDelegate = self;
        [self.view addSubview:self.errorPageWKWebView];
    }
    if (errorPageUrl != nil) {
        NSURL *errorPageUrlWithError = [self createErrorPageUrl:errorPageUrl code:errorCode description:errorDescription context:errorContext];
        NSURLRequest *errorRequest = [NSURLRequest requestWithURL:errorPageUrlWithError];
        if (self.useUIWebView) {
            [self.errorPageUIWebView loadRequest:errorRequest];
        } else {
            [self.errorPageWKWebView loadRequest:errorRequest];
        }
    } else {

        // Error page does not exist. Generate a generic page with the error.
        NSString *errorContent = [self createDefaultErrorPageContentWithCode:errorCode description:errorDescription context:errorContext];
        if (self.useUIWebView) {
            [self.errorPageUIWebView loadHTMLString:errorContent baseURL:nil];
        } else {
            [self.errorPageWKWebView loadHTMLString:errorContent baseURL:nil];
        }
    }
}

- (NSDictionary *)credentialsAsDictionary
{
    NSDictionary *credentialsDict = nil;
    SFOAuthCredentials *creds = [SFUserAccountManager sharedInstance].currentUser.credentials;
    if (nil != creds) {
        NSString *instanceUrl = creds.instanceUrl.absoluteString;
        NSString *loginUrl = [NSString stringWithFormat:@"%@://%@", creds.protocol, creds.domain];
        NSString *uaString = [self sfHybridViewUserAgentString];
        credentialsDict = @{kAccessTokenCredentialsDictKey: creds.accessToken,
                           kRefreshTokenCredentialsDictKey: creds.refreshToken,
                           kClientIdCredentialsDictKey: creds.clientId,
                           kUserIdCredentialsDictKey: creds.userId,
                           kOrgIdCredentialsDictKey: creds.organizationId,
                           kLoginUrlCredentialsDictKey: loginUrl,
                           kInstanceUrlCredentialsDictKey: instanceUrl,
                           kUserAgentCredentialsDictKey: uaString};
    }
    return credentialsDict;
}

- (NSString *)sfHybridViewUserAgentString
{
    NSString *userAgentString = @"";
    if ([SalesforceSDKManager sharedManager].userAgentString != NULL) {
        if (_hybridViewConfig.isLocal) {
            userAgentString = [SalesforceSDKManager sharedManager].userAgentString(@"Local");
        } else {
            userAgentString = [SalesforceSDKManager sharedManager].userAgentString(@"Remote");
        }
    }
    return userAgentString;
}

- (NSURL *)frontDoorUrlWithReturnUrl:(NSString *)returnUrlString returnUrlIsEncoded:(BOOL)isEncoded createAbsUrl:(BOOL)createAbsUrl
{

    // Special case: if returnUrlString itself is a frontdoor.jsp URL, parse its parameters and rebuild.
    if ([returnUrlString containsString:@"frontdoor.jsp"]) {
        return [self parseFrontDoorReturnUrlString:returnUrlString encoded:isEncoded];
    }
    SFOAuthCredentials *creds = [SFUserAccountManager sharedInstance].currentUser.credentials;
    NSURL *instUrl = creds.apiUrl;
    NSString *fullReturnUrlString = returnUrlString;

    /*
     * We need to use the absolute URL in some cases and relative URL in some
     * other cases, because of differences between instance URL and community URL.
     */
    if (createAbsUrl && ![returnUrlString hasPrefix:@"http"]) {
        NSURLComponents *retUrlComponents = [NSURLComponents componentsWithURL:instUrl resolvingAgainstBaseURL:NO];
        retUrlComponents.path = [retUrlComponents.path stringByAppendingPathComponent:returnUrlString];
        fullReturnUrlString = retUrlComponents.string;
    }

    // Create frontDoor path based on credentials API URL.
    NSURLComponents *frontDoorUrlComponents = [NSURLComponents componentsWithURL:instUrl resolvingAgainstBaseURL:NO];
    frontDoorUrlComponents.path = [frontDoorUrlComponents.path stringByAppendingPathComponent:@"/secur/frontdoor.jsp"];

    // NB: We're not using NSURLComponents.queryItems here, because it unsufficiently encodes query params.
    NSMutableString *frontDoorUrlString = [NSMutableString stringWithString:frontDoorUrlComponents.string];
    NSString *encodedRetUrlValue = (isEncoded ? fullReturnUrlString : [fullReturnUrlString stringByURLEncoding]);
    NSString *encodedSidValue = [creds.accessToken stringByURLEncoding];
    [frontDoorUrlString appendFormat:@"?sid=%@&retURL=%@&display=touch", encodedSidValue, encodedRetUrlValue];
    return [NSURL URLWithString:frontDoorUrlString];
}

- (NSURL *)parseFrontDoorReturnUrlString:(NSString *)frontDoorUrlString encoded:(BOOL)encoded {
    NSRange r1 = [frontDoorUrlString rangeOfString: encoded ? @"retURL%3D" : @"retURL="];
    NSRange r2 = [frontDoorUrlString rangeOfString: encoded ? @"%26display" : @"&display"];
    NSRange range = NSMakeRange(r1.location + r1.length, r2.location - r1.location - r1.length);
    NSString *returnUrlString = [frontDoorUrlString substringWithRange: range];
    if (encoded) {
        returnUrlString = [returnUrlString stringByRemovingPercentEncoding];
    }
    [SFSDKHybridLogger d:[self class] format:@"%@ Extracted return URL string '%@' from original frontDoor URL '%@'", NSStringFromSelector(_cmd), returnUrlString, frontDoorUrlString];
    return [self frontDoorUrlWithReturnUrl:returnUrlString returnUrlIsEncoded:YES createAbsUrl:NO];
}

- (NSString *)isLoginRedirectUrl:(NSURL *)url
{
    if (url == nil || [url absoluteString] == nil || [[url absoluteString] length] == 0) {
        return nil;
    }
    if ([[[url scheme] lowercaseString] hasPrefix:@"http"]
        && [url query] != nil) {
        NSString *startUrlValue = [url valueForParameterName:@"startURL"];
        NSString *ecValue = [url valueForParameterName:@"ec"];
        BOOL foundStartURL = (startUrlValue != nil);
        BOOL foundValidEcValue = ([ecValue isEqualToString:@"301"] || [ecValue isEqualToString:@"302"]);
        if (foundStartURL && foundValidEcValue) {
            return startUrlValue;
        }
    }
    return nil;
}

- (BOOL)isOffline
{
    SFHybridConnectionMonitor *connection = [SFHybridConnectionMonitor sharedInstance];
    NSString *connectionType = [[connection.connectionType stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    return (connectionType == nil || [connectionType length] == 0 || [connectionType isEqualToString:@"unknown"] || [connectionType isEqualToString:@"none"]);
}

- (BOOL)logoutOnInvalidCredentials:(NSError *)error
{
    if ([SFUserAccountManager sharedInstance].useLegacyAuthenticationManager) {
        return ([SFAuthenticationManager errorIsInvalidAuthCredentials:error]
                && [[SFAuthenticationManager sharedManager].authErrorHandlerList authErrorHandlerInList:[SFAuthenticationManager sharedManager].invalidCredentialsAuthErrorHandler]);
    } else {
       return [SFUserAccountManager errorIsInvalidAuthCredentials:error];
   }
}

- (NSURL *)fullFileUrlForPage:(NSString *)page
{
    NSString *fullPath = [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:self.wwwFolderName] stringByAppendingPathComponent:page];
    NSFileManager *manager = [[NSFileManager alloc] init];
    if (![manager fileExistsAtPath:fullPath]) {
        return nil;
    }
    NSURL *fileUrl = [NSURL fileURLWithPath:fullPath];
    return fileUrl;
}

- (NSURL *)createErrorPageUrl:(NSURL *)rootUrl code:(NSInteger)errorCode description:(NSString *)errorDescription context:(NSString *)errorContext
{
    NSMutableString *errorPageUrlString = [NSMutableString stringWithString:[rootUrl absoluteString]];
    [rootUrl query] == nil ? [errorPageUrlString appendString:@"?"] : [errorPageUrlString appendString:@"&"];
    [errorPageUrlString appendFormat:@"%@=%ld", kErrorCodeParameterName, (long)errorCode];
    [errorPageUrlString appendFormat:@"&%@=%@", kErrorDescriptionParameterName, [errorDescription stringByURLEncoding]];
    [errorPageUrlString appendFormat:@"&%@=%@", kErrorContextParameterName, [errorContext stringByURLEncoding]];
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
                               <p>Error code: %ld</p>\
                               <p>Error description: %@</p>\
                               <p>Error context: %@</p>\
                             </body>\
                             </html>", (long)errorCode, errorDescription, errorContext];
    return htmlContent;
}

- (void)configureRemoteStartPage
{
    
    // Note: You only want this to ever run once in the view controller's lifetime.
    static BOOL startPageConfigured = NO;
    if ([self userIsAuthenticated]) {
        self.startPage = [[self frontDoorUrlWithReturnUrl:_hybridViewConfig.startPage returnUrlIsEncoded:NO createAbsUrl:YES] absoluteString];
    } else {
        self.startPage = _hybridViewConfig.unauthenticatedStartPage;
    }
    startPageConfigured = YES;
}

- (void)webStateCleanupStrategy
{
    [SFSDKHybridLogger i:[self class] format:@"[%@ %@]: resetting session cookies.", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    [SFSDKWebViewStateManager resetSessionCookie];
}

- (BOOL)userIsAuthenticated
{
    return ([SFUserAccountManager sharedInstance].currentUser.credentials.accessToken.length > 0);
}

- (void) webView:(WKWebView *) webView didStartProvisionalNavigation:(WKNavigation *) navigation
{
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPluginResetNotification object:webView]];
}

- (void) webViewDidStartLoad:(UIWebView *) webView
{
    [self.commandQueue resetRequestId];
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPluginResetNotification object:self.webView]];
}

- (void) webView:(WKWebView *) webView decidePolicyForNavigationAction:(WKNavigationAction *) navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy)) decisionHandler
{
    [SFSDKHybridLogger d:[self class] format:@"webView:decidePolicyForNavigationAction:decisionHandler: Loading URL '%@'",
             [navigationAction.request.URL redactedAbsoluteString:@[@"sid"]]];
    BOOL shouldAllowRequest = YES;
    if ([webView isEqual:self.vfPingPageHiddenWKWebView]) { // Hidden ping page load.
        [SFSDKHybridLogger d:[self class] message:@"Setting up VF web state after plugin-based refresh."];
    } else if ([webView isEqual:self.errorPageWKWebView]) { // Local error page load.
        [SFSDKHybridLogger d:[self class] format:@"Local error page ('%@') is loading.", navigationAction.request.URL.absoluteString];
    } else if ([webView isEqual:self.webView]) { // Cordova web view load.

        /*
         * If the request is attempting to refresh an invalid session, take over
         * the refresh process via the OAuth refresh flow in the container.
         */
        NSString *refreshUrl = [self isLoginRedirectUrl:navigationAction.request.URL];
        if (refreshUrl != nil) {
            [SFSDKHybridLogger w:[self class] message:@"Caught login redirect from session timeout. Reauthenticating."];
            
            /*
             * Reconfigure user agent. Basically this ensures that Cordova whitelisting won't apply to the
             * WKWebView that hosts the login screen (important for SSO outside of Salesforce domains).
             */
            __weak typeof(self) weakSelf = self;
            [SFSDKWebUtils configureUserAgent:[self sfHybridViewUserAgentString]];
            [self refreshCredentials:[SFUserAccountManager sharedInstance].currentUser.credentials
             completion:^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
                 [SFUserAccountManager sharedInstance].currentUser = userAccount;

                 // Reset the user agent back to Cordova.
                 [weakSelf authenticationCompletion:refreshUrl authInfo:authInfo];
             } failure:^(SFOAuthInfo *authInfo, NSError *error) {
                 __strong typeof(weakSelf) strongSelf = weakSelf;
                 if ([strongSelf logoutOnInvalidCredentials:error]) {
                     [SFSDKHybridLogger e:[strongSelf class] message:@"Could not refresh expired session. Logging out."];
                     NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
                     attributes[@"errorCode"] = [NSNumber numberWithInteger:error.code];
                     attributes[@"errorDescription"] = error.localizedDescription;
                     [SFSDKEventBuilderHelper createAndStoreEvent:@"userLogout" userAccount:nil className:NSStringFromClass([strongSelf class]) attributes:attributes];
                     [strongSelf logout];
                 } else {
                     
                     // Error is not invalid credentials, or developer otherwise wants to handle it.
                     [strongSelf loadErrorPageWithCode:error.code description:error.localizedDescription context:kErrorContextAuthExpiredSessionRefresh];
                 }
             }];
            shouldAllowRequest = NO;
        } else {
            [self defaultWKNavigationHandling:webView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
            return;
        }
    }
    if (shouldAllowRequest) {
        decisionHandler(WKNavigationActionPolicyAllow);
    } else {
        decisionHandler(WKNavigationActionPolicyCancel);
    }
}

- (void) defaultWKNavigationHandling:(WKWebView *) webView decidePolicyForNavigationAction:(WKNavigationAction *) navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy)) decisionHandler {
    NSURL *url = [navigationAction.request URL];

    /*
     * Execute any commands queued with cordova.exec() on the JS side.
     * The part of the URL after gap:// is irrelevant.
     */
    if ([[url scheme] isEqualToString:@"gap"]) {
        [self.commandQueue fetchCommandsFromJs];
        
        /*
         * The delegate is called asynchronously in this case, so we don't have to use
         * flushCommandQueueWithDelayedJs (setTimeout(0)) as we do with hash changes.
         */
        [self.commandQueue executePending];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    } else {
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPluginHandleOpenURLNotification object:url]];
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
}

- (BOOL) webView:(UIWebView *) webView shouldStartLoadWithRequest:(NSURLRequest *) request navigationType:(UIWebViewNavigationType) navigationType
{
    [SFSDKHybridLogger d:[self class] format:@"webView:shouldStartLoadWithRequest:navigationType: Loading URL '%@'", [request.URL redactedAbsoluteString:@[@"sid"]]];

    // Hidden ping page load.
    if ([webView isEqual:self.vfPingPageHiddenUIWebView]) {
        [SFSDKHybridLogger d:[self class] message:@"Setting up VF web state after plugin-based refresh."];
        return YES;
    }

    // Local error page load.
    if ([webView isEqual:self.errorPageUIWebView]) {
        [SFSDKHybridLogger d:[self class] format:@"Local error page ('%@') is loading.", request.URL.absoluteString];
        return YES;
    }

    // Cordova web view load.
    if ([webView isEqual:self.webView]) {

        /*
         * If the request is attempting to refresh an invalid session, take over
         * the refresh process via the OAuth refresh flow in the container.
         */
        NSString *refreshUrl = [self isLoginRedirectUrl:request.URL];
        if (refreshUrl != nil) {
            [SFSDKHybridLogger w:[self class] message:@"Caught login redirect from session timeout. Reauthenticating."];
            
            /*
             * Reconfigure user agent. Basically this ensures that Cordova whitelisting won't apply to the
             * UIWebView that hosts the login screen (important for SSO outside of Salesforce domains).
             */
            [SFSDKWebUtils configureUserAgent:[self sfHybridViewUserAgentString]];
            __weak typeof(self) weakSelf = self;
            [self refreshCredentials:[SFUserAccountManager sharedInstance].currentUser.credentials
             completion:^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
                 [SFUserAccountManager sharedInstance].currentUser = userAccount;

                 // Reset the user agent back to Cordova.
                 [weakSelf authenticationCompletion:refreshUrl authInfo:authInfo];
             } failure:^(SFOAuthInfo *authInfo, NSError *error) {
                 __strong typeof(weakSelf) strongSelf = weakSelf;
                 if ([strongSelf logoutOnInvalidCredentials:error]) {
                    [SFSDKHybridLogger e:[strongSelf class] message:@"Could not refresh expired session. Logging out."];
                     NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
                     attributes[@"errorCode"] = [NSNumber numberWithInteger:error.code];
                     attributes[@"errorDescription"] = error.localizedDescription;
                     [SFSDKEventBuilderHelper createAndStoreEvent:@"userLogout" userAccount:nil className:NSStringFromClass([strongSelf class]) attributes:attributes];
                     [strongSelf logout];
                 } else {
                     
                     // Error is not invalid credentials, or developer otherwise wants to handle it.
                     [strongSelf loadErrorPageWithCode:error.code description:error.localizedDescription context:kErrorContextAuthExpiredSessionRefresh];
                 }
             }];
            return NO;
        }
        NSURL* url = request.URL;

        /*
         * Execute any commands queued with cordova.exec() on the JS side.
         * The part of the URL after gap:// is irrelevant.
         */
        if ([[url scheme] isEqualToString:@"gap"]) {
            [self.commandQueue fetchCommandsFromJs];
            [self.commandQueue executePending];
            return NO;
        } else {
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPluginHandleOpenURLNotification object:url]];
        }
    }
    return YES;
}

- (void) webView:(WKWebView *) webView didFinishNavigation:(WKNavigation *) navigation
{
    [self finishLoadActions:webView navigation:navigation];
}

- (void) webViewDidFinishLoad:(UIWebView *) webView
{
    [self finishLoadActions:webView navigation:nil];
}

- (void) finishLoadActions:(UIView *) webView navigation:(WKNavigation *) navigation
{
    NSURL *requestUrl = nil;
    if (self.useUIWebView) {
        requestUrl = ((UIWebView *) webView).request.URL;
    } else {
        requestUrl = ((WKWebView *) webView).URL;
    }
    NSArray *redactParams = @[@"sid"];
    NSString *redactedUrl = [requestUrl redactedAbsoluteString:redactParams];
    [SFSDKHybridLogger d:[self class] format:@"finishLoadActions: Loaded %@", redactedUrl];
    if ([webView isEqual:self.vfPingPageHiddenUIWebView]) {
        [SFSDKHybridLogger d:[self class] format:@"Finished loading VF ping page '%@'.", redactedUrl];
        return;
    }
    if ([webView isEqual:self.webView]) {

        /*
         * The first URL that's loaded that's not considered a 'reserved' URL (i.e. one that Salesforce or
         * this app's infrastructure is responsible for) will be considered the "app home URL", which can
         * be loaded directly in the event that the app is offline.
         */
        if (_foundHomeUrl == NO) {
            [SFSDKHybridLogger i:[self class] format:@"Checking %@ as a 'home page' URL candidate for this app.", redactedUrl];
            if (![self isReservedUrlValue:requestUrl]) {
                [SFSDKHybridLogger i:[self class] format:@"Setting %@ as the 'home page' URL for this app.", redactedUrl];
                self.appHomeUrl = requestUrl;
                _foundHomeUrl = YES;
            }
        }
        [CDVUserAgentUtil releaseLock:self.userAgentLockToken];
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPageDidLoadNotification object:self.webView]];
    }
}

- (void) webView:(WKWebView *) webView didFailNavigation:(WKNavigation *) navigation withError:(NSError *) error
{
    if ([webView isEqual:self.webView]) {
        [self loadErrorPageWithError:error];
    }
}

- (void) webView:(UIWebView *) webView didFailLoadWithError:(NSError *) error
{
    if ([webView isEqual:self.webView]) {
        [self loadErrorPageWithError:error];
    }
}

- (void) loadErrorPageWithError:(NSError *) error
{
    [SFSDKHybridLogger e:[self class] format:@"Error while attempting to load web page: %@", error];
    if ([[self class] isFatalWebViewError:error]) {
        [self loadErrorPageWithCode:[error code] description:[error localizedDescription] context:kErrorContextAppLoading];
    }
}

+ (BOOL)isFatalWebViewError:(NSError *)error
{
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
        return NO;
    }
    return YES;
}

- (BOOL)isReservedUrlValue:(NSURL *)url
{
    static NSArray *reservedUrlStrings = nil;
    if (reservedUrlStrings == nil) {
        reservedUrlStrings = @[@"/secur/frontdoor.jsp",
                               @"/secur/contentDoor"];
    }
    if (url == nil || [url absoluteString] == nil || [[url absoluteString] length] == 0) {
        return NO;    
    }
    NSString *inputUrlString = [url absoluteString];
    for (int i = 0; i < [reservedUrlStrings count]; i++) {
        NSString *reservedString = reservedUrlStrings[i];
        NSRange range = [[inputUrlString lowercaseString] rangeOfString:[reservedString lowercaseString]];
        if (range.location != NSNotFound)
            return YES;
    }
    return NO;
}

- (void)authenticationCompletion:(NSString *)originalUrl authInfo:(SFOAuthInfo *)authInfo
{
    [SFSDKHybridLogger d:[self class] message:@"authenticationCompletion:authInfo: - Initiating post-auth configuration."];
    [self webStateCleanupStrategy];

    // If there's an original URL, load it through frontdoor.
    if (originalUrl != nil) {
        [SFSDKHybridLogger d:[self class] format:@"Authentication complete. Redirecting to '%@' through frontdoor.", [originalUrl stringByURLEncoding]];
        BOOL createAbsUrl = YES;
        if (authInfo.authType == SFOAuthTypeRefresh) {
            createAbsUrl = NO;
        }
        NSURL *returnUrlAfterAuth = [self frontDoorUrlWithReturnUrl:originalUrl returnUrlIsEncoded:YES createAbsUrl:createAbsUrl];
        NSURLRequest *newRequest = [NSURLRequest requestWithURL:returnUrlAfterAuth];
        if (self.useUIWebView) {
            [(UIWebView *)(self.webView) loadRequest:newRequest];
        } else {
            [(WKWebView *)(self.webView) loadRequest:newRequest];
        }
    }
}

- (void)loadVFPingPage
{
    SFOAuthCredentials *creds = [SFUserAccountManager sharedInstance].currentUser.credentials;
    if (nil != creds.apiUrl) {
        NSMutableString *instanceUrl = [[NSMutableString alloc] initWithString:creds.apiUrl.absoluteString];
        NSString *encodedPingUrlParam = [kVFPingPageUrl stringByURLEncoding];
        [instanceUrl appendFormat:@"/visualforce/session?url=%@&autoPrefixVFDomain=true", encodedPingUrlParam];
        NSURL *pingURL = [[NSURL alloc] initWithString:instanceUrl];
        NSURLRequest *pingRequest = [[NSURLRequest alloc] initWithURL:pingURL];
        if (self.useUIWebView) {
            self.vfPingPageHiddenUIWebView = [[UIWebView alloc] initWithFrame:CGRectZero];
            self.vfPingPageHiddenUIWebView.delegate = self;
            [self.vfPingPageHiddenUIWebView loadRequest:pingRequest];
        } else {
            WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
            config.processPool = SFSDKWebViewStateManager.sharedProcessPool;
            self.vfPingPageHiddenWKWebView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
            self.vfPingPageHiddenWKWebView.navigationDelegate = self;
            [self.vfPingPageHiddenWKWebView loadRequest:pingRequest];
        }
    }
}

- (void)refreshCredentials:(SFOAuthCredentials *)credentials
                 completion:(SFOAuthFlowSuccessCallbackBlock)completionBlock
                  failure:(SFOAuthFlowFailureCallbackBlock)failureBlock {

    /*
     * Performs a cheap REST call to refresh the access token if needed
     * instead of going through the entire OAuth dance all over again.
     */
    SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeRefresh];
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForUserInfo];
    [[SFRestAPI sharedInstance] sendRESTRequest:request failBlock:^(NSError *e, NSURLResponse *rawResponse) {
        dispatch_async(dispatch_get_main_queue(), ^{
            failureBlock(authInfo, e);
        });
    } completeBlock:^(id response, NSURLResponse *rawResponse) {
        SFUserAccount *currentAccount = [SFUserAccountManager sharedInstance].currentUser;
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(authInfo, currentAccount);
        });
    }];
}

- (void)loginWithCompletion:(SFOAuthFlowSuccessCallbackBlock)completionBlock
                  failure:(SFOAuthFlowFailureCallbackBlock)failureBlock {
    if ([SFUserAccountManager sharedInstance].useLegacyAuthenticationManager) {
        [[SFAuthenticationManager sharedManager] loginWithCompletion:completionBlock failure:failureBlock];
    } else {
        [[SFUserAccountManager sharedInstance] loginWithCompletion:completionBlock failure:failureBlock];
    }
}

- (void)logout {
     if ([SFUserAccountManager sharedInstance].useLegacyAuthenticationManager) {
         [[SFAuthenticationManager sharedManager] logout];
     } else {
         [[SFUserAccountManager sharedInstance] logout];
     }
}

@end
SFSDK_USE_DEPRECATED_END
