/*
 SFWKWebViewEngine.m
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

#import "SFWKWebViewEngine.h"
#import "SFWKWebViewDelegate.h"
#import "SFWKWebViewNavigationDelegate.h"
#import <Cordova/NSDictionary+CordovaPreferences.h>
#import <objc/message.h>

@interface SFWKWebViewEngine ()

@property (nonatomic, strong, readwrite) UIView *engineWebView;
@property (nonatomic, strong, readwrite) id<WKNavigationDelegate> wkWebViewDelegate;
@property (nonatomic, strong, readwrite) SFWKWebViewNavigationDelegate *navWebViewDelegate;

@end

@implementation SFWKWebViewEngine

@synthesize engineWebView = _engineWebView;

- (instancetype) initWithFrame:(CGRect) frame {
    self = [super init];
    if (self) {
        self.engineWebView = [[WKWebView alloc] initWithFrame:frame];
    }
    return self;
}

- (void) pluginInitialize {
    WKWebView *wkWebView = (WKWebView *) _engineWebView;
    if ([self.viewController conformsToProtocol:@protocol(WKNavigationDelegate)]) {
        self.wkWebViewDelegate = [[SFWKWebViewDelegate alloc] initWithDelegate:(id<WKNavigationDelegate>) self.viewController];
        wkWebView.navigationDelegate = self.wkWebViewDelegate;
    } else {
        self.navWebViewDelegate = [[SFWKWebViewNavigationDelegate alloc] initWithEnginePlugin:self];
        self.wkWebViewDelegate = [[SFWKWebViewDelegate alloc] initWithDelegate:self.navWebViewDelegate];
        wkWebView.navigationDelegate = self.wkWebViewDelegate;
    }
    [self updateSettings:self.commandDelegate.settings];
}

- (void) evaluateJavaScript:(NSString *) javaScriptString completionHandler:(void (^)(id, NSError *)) completionHandler {
    [(WKWebView*) _engineWebView evaluateJavaScript:javaScriptString completionHandler:^(id result, NSError *error) {
        if (completionHandler) {
            completionHandler(result, error);
        }
    }];
}

- (id) loadRequest:(NSURLRequest *) request {
    [(WKWebView *) _engineWebView loadRequest:request];
    return nil;
}

- (id) loadHTMLString:(NSString *) string baseURL:(NSURL *) baseURL {
    [(WKWebView *) _engineWebView loadHTMLString:string baseURL:baseURL];
    return nil;
}

- (NSURL *) URL {
    return [(WKWebView *) _engineWebView URL];
}

- (BOOL) canLoadRequest:(NSURLRequest *) request {
    return (request != nil);
}

- (void) updateSettings:(NSDictionary *) settings {
    WKWebView *wkWebView = (WKWebView *) _engineWebView;
    wkWebView.configuration.allowsInlineMediaPlayback = [settings cordovaBoolSettingForKey:@"AllowInlineMediaPlayback" defaultValue:NO];
    wkWebView.configuration.requiresUserActionForMediaPlayback = [settings cordovaBoolSettingForKey:@"MediaPlaybackRequiresUserAction" defaultValue:YES];
    wkWebView.configuration.allowsAirPlayForMediaPlayback = [settings cordovaBoolSettingForKey:@"MediaPlaybackAllowsAirPlay" defaultValue:YES];
    wkWebView.configuration.suppressesIncrementalRendering = [settings cordovaBoolSettingForKey:@"SuppressesIncrementalRendering" defaultValue:NO];
    id prefObj = nil;

    // By default, 'DisallowOverscroll' is false (bounce is allowed).
    BOOL bounceAllowed = !([settings cordovaBoolSettingForKey:@"DisallowOverscroll" defaultValue:NO]);

    // Prevent WebView from bouncing.
    if (!bounceAllowed) {
        if ([wkWebView respondsToSelector:@selector(scrollView)]) {
            ((UIScrollView *) [wkWebView scrollView]).bounces = NO;
        } else {
            for (id subview in self.webView.subviews) {
                if ([[subview class] isSubclassOfClass:[UIScrollView class]]) {
                    ((UIScrollView *) subview).bounces = NO;
                }
            }
        }
    }
    NSString *decelerationSetting = [settings cordovaSettingForKey:@"UIWebViewDecelerationSpeed"];
    if (![@"fast" isEqualToString:decelerationSetting]) {
        [wkWebView.scrollView setDecelerationRate:UIScrollViewDecelerationRateNormal];
    }
    NSInteger paginationBreakingMode = 0;
    prefObj = [settings cordovaSettingForKey:@"PaginationBreakingMode"];
    if (prefObj != nil) {
        NSArray *validValues = @[@"page", @"column"];
        NSString *prefValue = [validValues objectAtIndex:0];
        if ([prefObj isKindOfClass:[NSString class]]) {
            prefValue = prefObj;
        }
        paginationBreakingMode = [validValues indexOfObject:[prefValue lowercaseString]];
        if (paginationBreakingMode == NSNotFound) {
            paginationBreakingMode = 0;
        }
    }
}

- (void) updateWithInfo:(NSDictionary *) info {
    WKWebView *wkWebView = (WKWebView *) _engineWebView;
    id <WKNavigationDelegate> wkWebViewDelegate = [info objectForKey:kCDVWebViewEngineWKNavigationDelegate];
    NSDictionary *settings = [info objectForKey:kCDVWebViewEngineWebViewPreferences];
    if (wkWebViewDelegate &&
        [wkWebViewDelegate conformsToProtocol:@protocol(WKNavigationDelegate)]) {
        self.wkWebViewDelegate = [[SFWKWebViewDelegate alloc] initWithDelegate:(id<WKNavigationDelegate>) self.viewController];
        wkWebView.navigationDelegate = self.wkWebViewDelegate;
    }
    if (settings && [settings isKindOfClass:[NSDictionary class]]) {
        [self updateSettings:settings];
    }
}

- (id) forwardingTargetForSelector:(SEL) aSelector {
    return _engineWebView;
}

- (UIView *) webView {
    return self.engineWebView;
}

@end
