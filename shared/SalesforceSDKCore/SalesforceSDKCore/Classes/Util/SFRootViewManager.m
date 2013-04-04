//
//  SFRootViewManager.m
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 3/26/13.
//  Copyright (c) 2013 salesforce.com. All rights reserved.
//

#import "SFRootViewManager.h"

@interface SFRootViewManager ()
{
    
}

@property (nonatomic, strong) UIViewController *viewController;
@property (nonatomic, strong) UIWindow *origKeyWindow;
@property (nonatomic, strong) UIWindow *surrogateKeyWindow;
@property (nonatomic, strong) UIViewController *origRootViewController;

@end

@implementation SFRootViewManager

@synthesize viewController = _viewController;
@synthesize origKeyWindow = _origKeyWindow;
@synthesize surrogateKeyWindow = _surrogateKeyWindow;
@synthesize origRootViewController = _origRootViewController;
@synthesize newViewIsDisplayed = _newViewIsDisplayed;

- (id)initWithRootViewController:(UIViewController *)viewController
{
    self = [super init];
    if (self) {
        NSAssert(viewController != nil, @"viewController argument cannot be nil.");
        self.viewController = viewController;
        _newViewIsDisplayed = NO;
    }
    
    return self;
}

- (void)dealloc
{
    self.viewController = nil;
    self.origKeyWindow = nil;
    self.surrogateKeyWindow = nil;
    self.origRootViewController = nil;
}

- (void)showNewView
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showNewView];
        });
        return;
    }
    
    if (_newViewIsDisplayed) {
        [self log:SFLogLevelWarning msg:@"Alternate view is already being displayed.  No action taken."];
        return;
    }
    
    // We're not sure what the UI state of the app is, as this is a self-contained component.  Take
    // over the screen as necessary.
    UIWindow *currentKeyWindow = [[UIApplication sharedApplication] keyWindow];
    if (currentKeyWindow == nil) {
        // No key window.  Create the UI stack.
        [self log:SFLogLevelDebug msg:@"No key window.  Creating a surrogate."];
        self.surrogateKeyWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.surrogateKeyWindow.rootViewController = self.viewController;
        [self log:SFLogLevelDebug format:@"Displaying alternate root view controller (%@).", NSStringFromClass([self.viewController class])];
        [self.surrogateKeyWindow makeKeyAndVisible];
    } else {
        // There's already a key window.  Temporarily replace its root view controller.
        self.origKeyWindow = currentKeyWindow;
        self.origRootViewController = currentKeyWindow.rootViewController;
        NSString *origRvcClassName = (self.origRootViewController == nil ? @"NONE" : NSStringFromClass([self.origRootViewController class]));
        [self log:SFLogLevelDebug format:@"Key window already exists.  Replacing root view controller (%@) with alternate (%@).", origRvcClassName, NSStringFromClass([self.viewController class])];
        currentKeyWindow.rootViewController = self.viewController;
    }
    
    _newViewIsDisplayed = YES;
}

- (void)restorePreviousView
{
    if (!_newViewIsDisplayed) {
        [self log:SFLogLevelWarning msg:@"No alternate view was established in the first place.  No action taken."];
        return;
    }
    
    if (self.origKeyWindow != nil) {
        NSString *origRvcClassName = (self.origRootViewController == nil ? @"NONE" : NSStringFromClass([self.origRootViewController class]));
        [self log:SFLogLevelDebug format:@"Restoring original root view controller (%@).", origRvcClassName];
        self.origKeyWindow.rootViewController = self.origRootViewController;
    }
    self.origKeyWindow = nil;
    self.surrogateKeyWindow = nil;
    self.origRootViewController = nil;
    _newViewIsDisplayed = NO;
}

@end
