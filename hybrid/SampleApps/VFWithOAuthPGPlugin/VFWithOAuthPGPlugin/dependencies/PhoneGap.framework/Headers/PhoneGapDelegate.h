/*
 * PhoneGap is available under *either* the terms of the modified BSD license *or* the
 * MIT License (2008). See http://opensource.org/licenses/alphabetical for full text.
 * 
 * Copyright (c) 2005-2010, Nitobi Software Inc.
 * Copyright (c) 2010, IBM Corporation
 */

#import <UIKit/UIKit.h>
#import "JSONKit.h"

@class InvokedUrlCommand;
@class PhoneGapViewController;
@class Sound;
@class Contacts;
@class Console;
@class PGWhitelist;

@interface PhoneGapDelegate : NSObject <UIApplicationDelegate, UIWebViewDelegate>
{
}

@property (nonatomic, readwrite, retain) IBOutlet UIWindow *window;
@property (nonatomic, readwrite, retain) IBOutlet UIWebView *webView;
@property (nonatomic, readonly, retain) IBOutlet PhoneGapViewController *viewController;
@property (nonatomic, readonly, retain) IBOutlet UIActivityIndicatorView *activityView;
@property (nonatomic, readonly, retain) UIImageView *imageView;
@property (nonatomic, readonly, retain) NSMutableDictionary *pluginObjects;
@property (nonatomic, readonly, retain) NSDictionary *pluginsMap;
@property (nonatomic, readonly, retain) NSDictionary *settings;
@property (nonatomic, readonly, retain) PGWhitelist* whitelist; // readonly for public


#pragma mark - App settings 

+ (NSDictionary*)getBundlePlist:(NSString *)plistName;
+ (NSString*) wwwFolderName;
+ (NSString*) pathForResource:(NSString*)resourcepath;
+ (NSString*) phoneGapVersion;
+ (NSString*) applicationDocumentsDirectory;

/**
 @return URL string for the first page that should be loaded in the web view: defaults to www/index.html
 */
+ (NSString*) startPage;

/**
 @return NSString The first URL scheme supported by this app, if any registered with CFBundleURLSchemes in the app .plist
 */
- (NSString*) appURLScheme;

/**
 @return NSDictionary A set of device and app properties
 */
- (NSDictionary*) deviceProperties;


#pragma mark - Command Queue

- (int)executeQueuedCommands;
- (void)flushCommandQueue;
- (BOOL) execute:(InvokedUrlCommand*)command;

#pragma mark - Plugin Management

/**
 
 */
- (void)reinitializePlugins;

/**
 Get an instance of the named plugin.  This method creates a new instance if
 one does not already exist. If there is an existing instance, this method returns it.
 Thus, plugins are essentially singletons.
 
 @param pluginName Class name for plugin, eg "com.salesforce.com.foo"
 @return Singleton instance of the named plugin
 */
- (id) getCommandInstance:(NSString*)pluginName;


#pragma mark - Embedded UIWebView management

/**
Tear down the existing web view.
 @see reinitializeWebView
 */
- (void)teardownWebView;

/**
 (re)Initialize the embedded web view.
 @see teardownWebView
 */
- (void)reinitializeWebView;

/**
 Load the start page into the embedded web view.
 */
- (void)loadStartPageIntoWebView;


/**
 Configure the web view from self.settings.
 @param aWebView The web view to configure;
 */
- (void)configureWebViewFromSettings:(UIWebView*)aWebView;


#pragma mark - Application state transitions
- (void)applicationDidEnterBackground:(UIApplication *)application;
- (void)applicationWillEnterForeground:(UIApplication *)application;
- (void)applicationWillResignActive:(UIApplication *)application;
- (void)applicationWillTerminate:(UIApplication *)application;


#pragma mark - Public


/**
 Force a javascript alert to be shown in the embedded UIWebView
 @param text  Message to be shown in the web view in a javascript alert.
 */
- (void) javascriptAlert:(NSString*)text;




@end



@interface NSDictionary (LowercaseKeys)

- (NSDictionary*) dictionaryWithLowercaseKeys;

@end

