/*
 SFWKWebViewNavigationDelegate.m
 SalesforceHybridSDK
 
 Created by Bharath Hariharan on 7/15/16.
 
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFWKWebViewNavigationDelegate.h"
#import "SFHybridViewController.h"
#import <SalesforceSDKCore/SFApplicationHelper.h>
#import <SalesforceSDKCore/NSString+SFAdditions.h>
#import <Cordova/CDVCommandDelegateImpl.h>
#import <Cordova/CDVUserAgentUtil.h>
#import <objc/message.h>

@implementation SFWKWebViewNavigationDelegate

- (instancetype) initWithEnginePlugin:(CDVPlugin *) theEnginePlugin {
    self = [super init];
    if (self) {
        self.enginePlugin = theEnginePlugin;
    }
    return self;
}

- (void) webView:(WKWebView *) webView didStartProvisionalNavigation:(WKNavigation *) navigation {
    [self log:SFLogLevelDebug format:@"Resetting plugins due to page load."];
    SFHybridViewController *vc = (SFHybridViewController *) self.enginePlugin.viewController;
    [vc.commandQueue resetRequestId];
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPluginResetNotification object:self.enginePlugin.webView]];
}

- (void) webView:(WKWebView *) webView didFinishNavigation:(WKNavigation *) navigation {
    [self log:SFLogLevelDebug format:@"Finished load of: %@", webView.URL];
    SFHybridViewController* vc = (SFHybridViewController *) self.enginePlugin.viewController;

    // It's safe to release the lock even if this is just a sub-frame that's finished loading.
    [CDVUserAgentUtil releaseLock:vc.userAgentLockToken];

    // Hides the top activity throbber in the battery bar.
    [[SFApplicationHelper sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPageDidLoadNotification object:self.enginePlugin.webView]];
}

- (void) webView:(WKWebView *) webView didFailNavigation:(WKNavigation *) navigation withError:(NSError *) error {
    [self webView:webView didFailLoadWithError:error];
}

- (void) webView:(WKWebView *) webView didFailProvisionalNavigation:(WKNavigation *) navigation withError:(NSError *) error {
    [self webView:webView didFailLoadWithError:error];
}

- (void) webView:(WKWebView *) webView didFailLoadWithError:(NSError *) error {
    SFHybridViewController* vc = (SFHybridViewController *) self.enginePlugin.viewController;
    [CDVUserAgentUtil releaseLock:vc.userAgentLockToken];
    NSString* message = [NSString stringWithFormat:@"Failed to load webpage with error: %@", [error localizedDescription]];
    [self log:SFLogLevelDebug format:message];
    NSURL *errorUrl = vc.errorURL;
    if (errorUrl) {
        NSString *urlString = [NSString stringWithFormat:@"?error=%@", [message stringByURLEncoding]];
        errorUrl = [NSURL URLWithString:urlString relativeToURL:errorUrl];
        [self log:SFLogLevelDebug format:[errorUrl absoluteString]];
        [webView loadRequest:[NSURLRequest requestWithURL:errorUrl]];
    }
}

- (BOOL) defaultResourcePolicyForURL:(NSURL *) url {
    if ([url isFileURL]) {
        return YES;
    }
    return NO;
}

- (void) webView:(WKWebView *) webView decidePolicyForNavigationAction:(WKNavigationAction *) navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy)) decisionHandler {
    NSURL *url = [navigationAction.request URL];
    SFHybridViewController* vc = (SFHybridViewController *) self.enginePlugin.viewController;

    /*
     * Execute any commands queued with cordova.exec() on the JS side.
     * The part of the URL after gap:// is irrelevant.
     */
    if ([[url scheme] isEqualToString:@"gap"]) {
        [vc.commandQueue fetchCommandsFromJs];

        /*
         * The delegate is called asynchronously in this case, so we don't have to use
         * flushCommandQueueWithDelayedJs (setTimeout(0)) as we do with hash changes.
         */
        [vc.commandQueue executePending];
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        /*
         * Handle all other types of urls (tel:, sms:), and requests to load a URL in the main WebView.
         */
        BOOL shouldAllowNavigation = [self defaultResourcePolicyForURL:url];
        if (shouldAllowNavigation) {
            decisionHandler(WKNavigationActionPolicyAllow);
        } else {
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPluginHandleOpenURLNotification object:url]];
            decisionHandler(WKNavigationActionPolicyCancel);
        }
    }
}

@end
