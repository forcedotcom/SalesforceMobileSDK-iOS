/*
 SFWKWebViewDelegate.m
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

#import "SFWKWebViewDelegate.h"

typedef enum {
    STATE_IDLE = 0,
    STATE_WAITING_FOR_LOAD_START = 1,
    STATE_WAITING_FOR_LOAD_FINISH = 2,
    STATE_IOS5_POLLING_FOR_LOAD_START = 3,
    STATE_IOS5_POLLING_FOR_LOAD_FINISH = 4,
    STATE_CANCELLED = 5
} State;

static NSString* stripFragment(NSString *url) {
    NSRange r = [url rangeOfString:@"#"];
    if (r.location == NSNotFound) {
        return url;
    }
    return [url substringToIndex:r.location];
}

@implementation SFWKWebViewDelegate

- (id) initWithDelegate:(NSObject<WKNavigationDelegate> *) delegate {
    self = [super init];
    if (self != nil) {
        _delegate = delegate;
        _loadCount = -1;
        _state = STATE_IDLE;
    }
    return self;
}

- (BOOL) request:(NSURLRequest *) newRequest isEqualToRequestAfterStrippingFragments:(NSURLRequest *) originalRequest {
    if (originalRequest.URL && newRequest.URL) {
        NSString *originalRequestUrl = [originalRequest.URL absoluteString];
        NSString *newRequestUrl = [newRequest.URL absoluteString];
        NSString *baseOriginalRequestUrl = stripFragment(originalRequestUrl);
        NSString *baseNewRequestUrl = stripFragment(newRequestUrl);
        return [baseOriginalRequestUrl isEqualToString:baseNewRequestUrl];
    }
    return NO;
}

- (BOOL) isPageLoaded:(WKWebView *) webView {
    NSString *readyState = [self stringByEvaluatingJavaScriptFromString:@"document.readyState" webView:webView];
    return [readyState isEqualToString:@"loaded"] || [readyState isEqualToString:@"complete"];
}

- (BOOL) isJsLoadTokenSet:(WKWebView *) webView {
    NSString *loadToken = [self stringByEvaluatingJavaScriptFromString:@"window.__cordovaLoadToken" webView:webView];
    return [[NSString stringWithFormat:@"%ld", (long) _curLoadToken] isEqualToString:loadToken];
}

- (void) setLoadToken:(WKWebView *) webView {
    _curLoadToken += 1;
    [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.__cordovaLoadToken=%ld", (long) _curLoadToken] webView:webView];
}

- (void) pollForPageLoadStart:(WKWebView *) webView {
    if (_state != STATE_IOS5_POLLING_FOR_LOAD_START) {
        return;
    }
    if (![self isJsLoadTokenSet:webView]) {
        [self log:SFLogLevelVerbose format:@"Polled for page load start. Result = YES!"];
        _state = STATE_IOS5_POLLING_FOR_LOAD_FINISH;
        [self setLoadToken:webView];
        if ([_delegate respondsToSelector:@selector(webView:didStartProvisionalNavigation:)]) {
            [_delegate webView:webView didStartProvisionalNavigation:nil];
        }
        [self pollForPageLoadFinish:webView];
    } else {
        [self log:SFLogLevelVerbose format:@"Polled for page load start. Result = NO!"];

        // Poll only for 1 second, and then fall back on checking only when delegate methods are called.
        ++_loadStartPollCount;
        if (_loadStartPollCount < (1000 * .05)) {
            [self performSelector:@selector(pollForPageLoadStart:) withObject:webView afterDelay:.05];
        }
    }
}

- (void) pollForPageLoadFinish:(WKWebView *) webView {
    if (_state != STATE_IOS5_POLLING_FOR_LOAD_FINISH) {
        return;
    }
    if ([self isPageLoaded:webView]) {
        [self log:SFLogLevelVerbose format:@"Polled for page load finish. Result = YES!"];
        _state = STATE_IDLE;
        if ([_delegate respondsToSelector:@selector(webView:didFinishNavigation:)]) {
            [_delegate webView:webView didFinishNavigation:nil];
        }
    } else {
        [self log:SFLogLevelVerbose format:@"Polled for page load finish. Result = NO!"];
        [self performSelector:@selector(pollForPageLoadFinish:) withObject:webView afterDelay:.05];
    }
}

- (BOOL) shouldLoadRequest:(NSURLRequest *) request {
    NSString* scheme = [[request URL] scheme];
    NSArray* allowedSchemes = [NSArray arrayWithObjects:@"mailto", @"tel", @"blob", @"sms", @"data", nil];
    if ([allowedSchemes containsObject:scheme]) {
        return YES;
    } else {
        return [NSURLConnection canHandleRequest:request];
    }
}

- (void) webView:(WKWebView *) webView decidePolicyForNavigationAction:(WKNavigationAction *) navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy)) decisionHandler {
    __block BOOL shouldLoad = YES;
    if ([_delegate respondsToSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)]) {
        [_delegate webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:^void(WKNavigationActionPolicy policy) {
            if (policy == WKNavigationActionPolicyAllow) {
                shouldLoad = YES;
            } else {
                shouldLoad = NO;
            }
        }];
    }
    if (shouldLoad) {
        NSURLRequest *request = navigationAction.request;
        BOOL isTopLevelNavigation = [request.URL isEqual:[request mainDocumentURL]];
        if (isTopLevelNavigation) {
            switch (_state) {
                case STATE_WAITING_FOR_LOAD_FINISH:
                    if (_loadCount != 1) {
                        [self log:SFLogLevelDebug format:@"Detected redirect when loadCount=%ld", (long) _loadCount];
                    }
                    break;
                case STATE_IDLE:
                case STATE_IOS5_POLLING_FOR_LOAD_START:
                case STATE_CANCELLED:
                    _loadCount = 0;
                    _state = STATE_WAITING_FOR_LOAD_START;
                    break;
                default:
                {
                    NSString* description = [NSString stringWithFormat:@"Navigation started when state=%ld", (long) _state];
                    [self log:SFLogLevelDebug format:description];
                    _loadCount = 0;
                    _state = STATE_WAITING_FOR_LOAD_START;
                    if ([_delegate respondsToSelector:@selector(webView:didFailNavigation:withError:)]) {
                        NSDictionary *errorDictionary = @{NSLocalizedDescriptionKey : description};
                        NSError *error = [[NSError alloc] initWithDomain:@"SFWKWebViewDelegate" code:1 userInfo:errorDictionary];
                        [_delegate webView:webView didFailNavigation:nil withError:error];
                    }
                }
            }
        } else {
            shouldLoad = shouldLoad && [self shouldLoadRequest:request];
        }
    }
    if (shouldLoad) {
        decisionHandler(WKNavigationActionPolicyAllow);
    } else {
        decisionHandler(WKNavigationActionPolicyCancel);
    }
}

- (void) webView:(WKWebView *) webView didCommitNavigation:(WKNavigation *) navigation {
    [self webView:webView didStartProvisionalNavigation:navigation];
}

- (void) webView:(WKWebView *) webView didStartProvisionalNavigation:(WKNavigation *) navigation {
    BOOL fireCallback = NO;
    switch (_state) {
        case STATE_IDLE:
            break;
        case STATE_CANCELLED:
            fireCallback = YES;
            _state = STATE_WAITING_FOR_LOAD_FINISH;
            _loadCount += 1;
            break;
        case STATE_WAITING_FOR_LOAD_START:
            fireCallback = YES;
            _state = STATE_WAITING_FOR_LOAD_FINISH;
            _loadCount = 1;
            break;
        case STATE_WAITING_FOR_LOAD_FINISH:
            _loadCount += 1;
            break;
        case STATE_IOS5_POLLING_FOR_LOAD_START:
            [self pollForPageLoadStart:webView];
            break;
        case STATE_IOS5_POLLING_FOR_LOAD_FINISH:
            [self pollForPageLoadFinish:webView];
            break;
        default:
            [self log:SFLogLevelDebug format:@"Unexpected didStart with state=%ld loadCount=%ld", (long) _state, (long) _loadCount];
    }
    if (fireCallback && [_delegate respondsToSelector:@selector(webView:didStartProvisionalNavigation:)]) {
        [_delegate webView:webView didStartProvisionalNavigation:navigation];
    }
}

- (void) webView:(WKWebView *) webView didFinishNavigation:(WKNavigation *) navigation {
    BOOL fireCallback = NO;
    switch (_state) {
        case STATE_IDLE:
            break;
        case STATE_WAITING_FOR_LOAD_START:
            break;
        case STATE_WAITING_FOR_LOAD_FINISH:
            if (_loadCount == 1) {
                fireCallback = YES;
                _state = STATE_IDLE;
            }
            _loadCount -= 1;
            break;
        case STATE_IOS5_POLLING_FOR_LOAD_START:
            [self pollForPageLoadStart:webView];
            break;
        case STATE_IOS5_POLLING_FOR_LOAD_FINISH:
            [self pollForPageLoadFinish:webView];
            break;
    }
    if (fireCallback && [_delegate respondsToSelector:@selector(webView:didFinishNavigation:)]) {
        [_delegate webView:webView didFinishNavigation:navigation];
    }
}

- (void) webView:(WKWebView *) webView didFailNavigation:(WKNavigation *) navigation withError:(NSError *) error {
    BOOL fireCallback = NO;
    switch (_state) {
        case STATE_IDLE:
            break;
        case STATE_WAITING_FOR_LOAD_START:
            if ([error code] == NSURLErrorCancelled) {
                _state = STATE_CANCELLED;
            } else {
                _state = STATE_IDLE;
            }
            fireCallback = YES;
            break;
        case STATE_WAITING_FOR_LOAD_FINISH:
            if ([error code] != NSURLErrorCancelled) {
                if (_loadCount == 1) {
                    _state = STATE_IDLE;
                    fireCallback = YES;
                }
                _loadCount = -1;
            } else {
                fireCallback = YES;
                _state = STATE_CANCELLED;
                _loadCount -= 1;
            }
            break;
        case STATE_IOS5_POLLING_FOR_LOAD_START:
            [self pollForPageLoadStart:webView];
            break;
        case STATE_IOS5_POLLING_FOR_LOAD_FINISH:
            [self pollForPageLoadFinish:webView];
            break;
    }
    if (fireCallback && [_delegate respondsToSelector:@selector(webView:didFailNavigation:withError:)]) {
        [_delegate webView:webView didFailNavigation:navigation withError:error];
    }
}

- (NSString *) stringByEvaluatingJavaScriptFromString:(NSString *) script webView:(WKWebView *) webView {
    __block NSString *resultString = nil;
    __block BOOL finished = NO;
    [webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error == nil) {
            if (result != nil) {
                resultString = [NSString stringWithFormat:@"%@", result];
            }
        } else {
            [self log:SFLogLevelDebug format:@"evaluateJavaScript error : %@", error.localizedDescription];
        }
        finished = YES;
    }];
    while (!finished) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    return resultString;
}

@end
