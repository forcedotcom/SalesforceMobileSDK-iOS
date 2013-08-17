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

#import "SFSDKWebUtils.h"
#import "SFLogger.h"
#import "SFApplication.h"

// Public constants
NSString * const kUserAgentPropKey = @"UserAgent";

static NSString *gAppUserAgent = nil;

@interface SFSDKWebUtils ()

+ (void)retrieveUserAgentValueForApp;

@end

@implementation SFSDKWebUtils

+ (void)initialize
{
    [self retrieveUserAgentValueForApp];
}

+ (void)configureUserAgent:(NSString *)userAgentString
{
    if (userAgentString != nil) {
        NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:userAgentString, kUserAgentPropKey, nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
    }
}

+ (NSString *)currentUserAgentForApp
{
    return gAppUserAgent;
}

+ (void)retrieveUserAgentValueForApp
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self retrieveUserAgentValueForApp];
        });
        
        // Give it a slice or two, if we're not on the main thread, to give gAppUserAgent time to be set first.
        [NSThread sleepForTimeInterval:0.1];
        
        return;
    }
    
    // Get the current user agent.  Yes, this is hack-ish.  Alternatives are more hackish.  UIWebView
    // really doesn't want you to know about its HTTP headers.
    UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    gAppUserAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
}

@end
