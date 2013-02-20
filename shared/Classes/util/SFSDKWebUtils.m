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

@implementation SFSDKWebUtils

+ (NSString *)appDelegateUserAgentString
{
    id<UIApplicationDelegate> appDelegate = [[UIApplication sharedApplication] delegate];
    if (![appDelegate conformsToProtocol:@protocol(SFSDKAppDelegate)]) {
        [SFLogger log:[SFSDKWebUtils class]
                level:SFLogLevelWarning
                  msg:[NSString stringWithFormat:@"'%@' does not conform to SFSDKAppDelegate.  Cannot retrieve user agent.",
                       NSStringFromClass([appDelegate class])]];
        return nil;
    }
    
    id<SFSDKAppDelegate> sdkAppDelegate = (id<SFSDKAppDelegate>)appDelegate;
    return [sdkAppDelegate userAgentString];
}

+ (void)configureUserAgent
{
    [self configureUserAgent:[self appDelegateUserAgentString]];
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
    // Get the current user agent.  Yes, this is hack-ish.  Alternatives are more hackish.  UIWebView
    // really doesn't want you to know about its HTTP headers.
    UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    NSString *currentUserAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
    
    return currentUserAgent;
}

@end
