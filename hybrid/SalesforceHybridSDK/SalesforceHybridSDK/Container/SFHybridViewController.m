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

@interface SFHybridViewController()
{
    BOOL _foundHomeUrl;
}

/**
 * Whether or not the input URL is one of the reserved URLs in the login flow, for consideration
 * in determining the app's ultimate home page.
 * @param url The URL to test.
 * @return YES if the value is one of the reserved URLs, NO otherwise.
 */
- (BOOL)isReservedUrlValue:(NSURL *)url;

/**
 * The file URL string for the start page, as it will be reported in webViewDidFinishLoad:
 */
- (NSString *)startPageUrlString;

/**
 * Method called after re-authentication completes (after session timeout).
 * @param originalUrl The original URL being called before the session timed out.
 */
- (void)authenticationCompletion:(NSURL *)originalUrl;

@end

@implementation SFHybridViewController

#pragma mark - Init / dealloc / etc.

- (id)init
{
    self = [super init];
    if (self) {
        _foundHomeUrl = NO;
    }
    
    return self;
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    [self log:SFLogLevelDebug format:@"webView:shouldStartLoadWithRequest: Loading URL '%@'",
     [request.URL redactedAbsoluteString:[NSArray arrayWithObject:@"sid"]]];
    if ([SFAuthenticationManager isLoginRedirectUrl:request.URL]) {
        [self log:SFLogLevelWarning msg:@"Caught login redirect from session timeout.  Re-authenticating."];
        [[SFAuthenticationManager sharedManager] login:self
                                            completion:^{
                                                [self authenticationCompletion:request.URL];
                                            }
                                               failure:^{
                                                   [[SFAuthenticationManager sharedManager] logout];
                                               }
         ];
        return NO;
    }
    
    return [super webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
}

- (void)webViewDidFinishLoad:(UIWebView *)theWebView
{
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

#pragma mark - URL evaluation helpers

- (BOOL)isReservedUrlValue:(NSURL *)url
{
    static NSArray *reservedUrlStrings = nil;
    if (reservedUrlStrings == nil) {
        reservedUrlStrings = [[NSArray arrayWithObjects:
                               [self startPageUrlString],
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

- (NSString *)startPageUrlString
{
    NSString *startPageFilePath = [self.commandDelegate pathForResource:self.startPage];
    NSURL *startPageFileUrl = [NSURL fileURLWithPath:startPageFilePath];
    NSString *urlString = [[startPageFileUrl absoluteString] stringByReplacingOccurrencesOfString:@"file://localhost/"
                                                                                       withString:@"file:///"];
    return urlString;
}

#pragma mark - OAuth flow helpers

- (void)authenticationCompletion:(NSURL *)originalUrl
{
    [self log:SFLogLevelDebug msg:@"[SFHybridViewController authenticationCompletion]: Authentication flow succeeded after session timeout.  Initiating post-auth configuration."];
    
    [SFAuthenticationManager resetSessionCookie];
    NSString *encodedStartUrlValue = [originalUrl valueForParameterName:@"startURL"];
    NSURL *returnUrlAfterAuth = [SFAuthenticationManager frontDoorUrlWithReturnUrl:encodedStartUrlValue returnUrlIsEncoded:YES];
    NSURLRequest *newRequest = [NSURLRequest requestWithURL:returnUrlAfterAuth];
    [self.webView loadRequest:newRequest];
}

@end
