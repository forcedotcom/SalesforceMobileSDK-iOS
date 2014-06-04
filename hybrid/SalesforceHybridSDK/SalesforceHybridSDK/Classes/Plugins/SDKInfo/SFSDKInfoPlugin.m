/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKInfoPlugin.h"
#import <Cordova/CDVViewController.h>
#import "CDVPlugin+SFAdditions.h"
#import <Cordova/CDVInvokedUrlCommand.h>

// Keys in sdk info map
NSString * const kSDKVersionKey = @"sdkVersion";
NSString * const kAppNameKey = @"appName";
NSString * const kAppVersionKey = @"appVersion";
NSString * const kForcePluginsAvailableKey = @"forcePluginsAvailable";

// Other constants
NSString * const kForcePluginPrefix = @"com.salesforce.";

@interface SFSDKInfoPlugin ()

@property (strong, nonatomic, readonly) NSArray *forcePlugins;

- (NSArray *)getForcePluginsFromCordova;

@end

@implementation SFSDKInfoPlugin

@synthesize forcePlugins = _forcePlugins;

/**
 This is Cordova's default initializer for plugins.
 */
- (CDVPlugin*) initWithWebView:(UIWebView*)theWebView
{
    self = [super initWithWebView:theWebView];
    if (self) {
        
    }
    return self;
}

- (void)dealloc
{
    SFRelease(_forcePlugins);
}

#pragma mark - Methods to get force plugins

- (NSArray *)forcePlugins
{
    if (_forcePlugins == nil) {
        _forcePlugins = [self getForcePluginsFromCordova];
    }
    
    return _forcePlugins;
}

- (NSArray *)getForcePluginsFromCordova
{
    NSMutableArray* services = [NSMutableArray array];
    if ([self.viewController isKindOfClass:[CDVViewController class]]) {
        CDVViewController *vc = (CDVViewController *)self.viewController;
        NSDictionary *pluginsMap = vc.pluginsMap;
        for (__strong NSString *key in [pluginsMap allKeys]) {
            key = [key lowercaseString];
            [self log:SFLogLevelDebug format:@"key=%@", key];
            if ([key hasPrefix:kForcePluginPrefix]) {
                [services addObject:key];
            }
        }
        return services;
    } else {
        [self log:SFLogLevelError
           format:@"??? Expected CDVViewController class for plugin's view controller. Got '%@'.",
         NSStringFromClass([self.viewController class])];
        return nil;
    }
}

#pragma mark - Plugin methods called from js

- (void)getInfo:(CDVInvokedUrlCommand *)command
{
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"getInfo" withArguments:command.arguments];
    
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
    
    NSDictionary *sdkInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
                              SALESFORCE_SDK_VERSION, kSDKVersionKey,
                              appName, kAppNameKey,
                              appVersion, kAppVersionKey,
                              self.forcePlugins, kForcePluginsAvailableKey,
                              nil];
    
    [self writeSuccessDictToJsRealm:sdkInfo callbackId:callbackId];
}



@end
