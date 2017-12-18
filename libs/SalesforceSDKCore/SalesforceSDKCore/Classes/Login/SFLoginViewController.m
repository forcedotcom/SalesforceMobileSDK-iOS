/*
 SFLoginViewController.m
 SalesforceSDKCore
 
 Created by Kunal Chitalia on 1/22/16.
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

@import UIKit;
#import "SFLoginViewController.h"
#import "SFManagedPreferences.h"
#import "SFSDKLoginHostListViewController.h"
#import "SFSDKLoginHostDelegate.h"
#import "UIColor+SFColors.h"
#import "SFSDKResourceUtils.h"
#import "SFUserAccountManager.h"
#import "SFAuthenticationManager.h"
#import "SFSDKLoginViewControllerConfig.h"
#import "SFOAuthInfo.h"
#import "SFSDKWindowManager.h"

SFSDK_USE_DEPRECATED_BEGIN

@interface SFLoginViewController () <SFSDKLoginHostDelegate, SFUserAccountManagerDelegate>

SFSDK_USE_DEPRECATED_END
@property (nonatomic, strong) UINavigationBar *navBar;

// Reference to the login host list view controller
@property (nonatomic, strong) SFSDKLoginHostListViewController *loginHostListViewController;

// Reference to previous user account
@property (nonatomic, strong) SFUserAccount *previousUserAccount;


@end

@implementation SFLoginViewController
@synthesize config = _config;
@synthesize oauthView = _oauthView;

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static SFLoginViewController *loginViewController = nil;
    dispatch_once(&onceToken, ^{
        loginViewController = [[self alloc] initWithNibName:nil bundle:nil];
    });
    return loginViewController;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _config = [[SFSDKLoginViewControllerConfig  alloc] init];
        [[SFUserAccountManager sharedInstance] addDelegate:self];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // as this view is not part of navigation controller stack, needs to set the proper view background so that status bar has the
    // right background color
    self.view.backgroundColor = self.navBarColor;
    if(self.showNavbar){
        [self setupNavigationBar];
    };
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutViews];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.showNavbar) {
        [self styleNavigationBar:self.navBar];
    }
    [self setupBackButton];
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

- (UIFont *)navBarFont {
    return self.config.navBarFont;
}

- (void)setNavBarFont:(UIFont *)navBarFont {
    self.config.navBarFont = navBarFont;
}

- (UIColor *)navBarTextColor {
    return self.config.navBarTextColor;
}

- (void)setNavBarTextColor:(UIColor *)color {
    self.config.navBarTextColor = color;
}

- (UIColor *)navBarColor {
    return self.config.navBarColor;
}

- (void)setNavBarColor:(UIColor *)navBarColor {
    self.config.navBarColor = navBarColor;
}

- (BOOL)showNavbar {
    return self.config.showNavbar;
}

- (void)setShowNavbar:(BOOL)showNavbar {
    self.config.showNavbar = showNavbar;
}

- (BOOL)showSettingsIcon {
    return self.config.showSettingsIcon;
}

- (void)setShowSettingsIcon:(BOOL)showSettingsIcon {
    self.config.showSettingsIcon = showSettingsIcon;
}

- (SFSDKLoginViewControllerConfig *)config {
    return _config;
}

- (void)setConfig:(SFSDKLoginViewControllerConfig *)config {
    if (_config!=config) {
        _config = config;
    }
}

#pragma mark - Setup Navigation bar

- (void)setupNavigationBar {
    self.navBar = [[UINavigationBar alloc] initWithFrame:CGRectZero];
    NSString *title = [SFSDKResourceUtils localizedString:@"TITLE_LOGIN"];

    // Setup top item.
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:title];
    self.navBar.items = @[item];

    // Hides the gear icon if there are no hosts to switch to.
    SFManagedPreferences *managedPreferences = [SFManagedPreferences sharedPreferences];
    if (managedPreferences.onlyShowAuthorizedHosts && managedPreferences.loginHosts.count == 0) {
        self.config.showSettingsIcon = NO;
    }
    if(self.showSettingsIcon) {

        // Setup right bar button.
        UIImage *image = [[SFSDKResourceUtils imageNamed:@"login-window-gear"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(showLoginHost:)];
        rightButton.accessibilityLabel = [SFSDKResourceUtils localizedString:@"LOGIN_CHOOSE_SERVER"];
        self.navBar.topItem.rightBarButtonItem = rightButton;
    }
    [self styleNavigationBar:self.navBar];
    [self.view addSubview:self.navBar];
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)setupBackButton {
    // setup left bar button
    if ([self shouldShowBackButton]) {
        UIImage *image = [[SFSDKResourceUtils imageNamed:@"globalheader-back-arrow"]  imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.navBar.topItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(backToPreviousHost:)];
    } else {
        self.navBar.topItem.leftBarButtonItem = nil;
    }
}

- (BOOL)shouldShowBackButton {
    if ([SFUserAccountManager sharedInstance].idpEnabled) {
        return YES;
    }
    NSInteger totalAccounts = [SFUserAccountManager sharedInstance].allUserAccounts.count;
    return  (totalAccounts > 0 && [SFUserAccountManager sharedInstance].currentUser);
}

#pragma mark - Action Methods

- (IBAction)showLoginHost:(id)sender {
    [self showHostListView];
}

- (IBAction)backToPreviousHost:(id)sender {
    if (![SFUserAccountManager sharedInstance].idpEnabled) {
        [[SFSDKWindowManager sharedManager].authWindow dismissWindow];
    }else {
        [[SFSDKWindowManager sharedManager].authWindow.viewController dismissViewControllerAnimated:NO completion:nil];
    }
}

#pragma mark - Accessor Methods

- (SFSDKLoginHostListViewController *)loginHostListViewController {
    if (!_loginHostListViewController) {
        _loginHostListViewController = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
        _loginHostListViewController.delegate = self;
    }
    return _loginHostListViewController;
}

#pragma mark - Properties

- (void)setOauthView:(UIView *)oauthView {
    if (![oauthView isEqual:_oauthView]) {
        [_oauthView removeFromSuperview];
        _oauthView = oauthView;
        if (nil != _oauthView) {
            [self.view addSubview:_oauthView];
            [self layoutViews];
        }
    }
}

#pragma mark - Layout Methods

- (void)layoutViews {

    // Let navBar tell us what height it would prefer at the current orientation
    CGFloat navBarHeight = [self.navBar sizeThatFits:self.view.bounds.size].height;

    // Resize navBar
    self.navBar.frame = CGRectMake(0, self.topLayoutGuide.length, self.view.bounds.size.width, navBarHeight);

    // resize oAuth view
    if (_oauthView) {
        _oauthView.frame = CGRectMake(0, CGRectGetMaxY(self.navBar.frame), self.view.bounds.size.width, self.view.bounds.size.height - CGRectGetMaxY(self.navBar.frame));
    }
}

#pragma mark - Styling Methods for Nav bar

- (void) styleNavigationBar:(UINavigationBar *)navigationBar {
    if (!navigationBar) {
        return;
    }
    if (self.navBarColor) {
        UIImage *backgroundImage = [self headerBackgroundImage];
        [navigationBar setBackgroundImage:backgroundImage forBarMetrics:UIBarMetricsDefault];
    }
    if (self.navBarTextColor) {
        navigationBar.tintColor = self.navBarTextColor;
        [navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName: self.navBarTextColor}];
    } else {
        // default color
        navigationBar.tintColor = [UIColor whiteColor];
    }
    
    if (self.navBarFont && self.navBarTextColor) {
        [navigationBar setTitleTextAttributes:@{ NSForegroundColorAttributeName: self.navBarTextColor,
                                                 NSFontAttributeName: self.navBarFont}];
    }
}

#pragma mark - SFSDKLoginHostDelegate Methods

- (void)hostListViewControllerDidAddLoginHost:(SFSDKLoginHostListViewController *)hostListViewController {
    [self hideHostListView:NO];
}

- (void)hostListViewControllerDidSelectLoginHost:(SFSDKLoginHostListViewController *)hostListViewController {
    // Hide the popover
    [self hideHostListView:NO];
}

- (void)hostListViewControllerDidCancelLoginHost:(SFSDKLoginHostListViewController *)hostListViewController {
    [self hideHostListView:YES];
}

- (void)hostListViewController:(SFSDKLoginHostListViewController *)hostListViewController didChangeLoginHost:(SFSDKLoginHost *)newLoginHost {
    if ([self.delegate respondsToSelector:@selector(loginViewController:didChangeLoginHost:)]) {
        [self.delegate loginViewController:self didChangeLoginHost:newLoginHost];
    }
}

#pragma mark - Login Host

- (void)showHostListView {
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self.loginHostListViewController];
    navController.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)hideHostListView:(BOOL)animated {
    [self dismissViewControllerAnimated:animated completion:nil];
}

#pragma mark - SFUserAccountManagerDelegate

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
        willSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser {
        self.previousUserAccount = fromUser;
}

- ( UIImage * _Nonnull )headerBackgroundImage {
    UIImage *backgroundImage = [[self class] imageFromColor:self.navBarColor];
    return backgroundImage;
}

+ (UIImage *)imageFromColor:(UIColor *)color {
    CGRect rect = CGRectMake(0, 0, 1, 1);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end

