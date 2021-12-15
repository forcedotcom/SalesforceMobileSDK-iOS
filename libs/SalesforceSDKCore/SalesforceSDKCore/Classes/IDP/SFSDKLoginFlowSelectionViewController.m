/*
 SFSDKLoginFlowSelectionViewController.m
 SalesforceSDKCore
 
 Created by Raj Rao on 8/28/17.
 
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKLoginFlowSelectionViewController.h"
#import "UIColor+SFColors.h"
#import "SFSDKResourceUtils.h"
#import "SFSDKAuthPreferences.h"
#import "SFSDKLoginHostListViewController.h"
#import "SFUserAccountManager.h"
#import "SFSDKLoginHost.h"
#import "SFManagedPreferences.h"
#import "SFUserAccountManager.h"
#import "SFSDKViewUtils.h"
#import "SFSDKIDPConstants.h"

@interface SFSDKLoginFlowSelectionViewController ()<SFSDKLoginHostDelegate>

@property (nonatomic, strong) UINavigationBar *navBar;

/** Specify the font to use for navigation bar header text.*/
@property (nonatomic, strong, nullable) UIFont * navBarFont;

/** Specify the text color to use for navigation bar header text. */
@property (nonatomic, strong, nullable) UIColor * navBarTextColor;

/** Specify navigation bar color. This color will be used by the login view header.
 */
@property (nonatomic, strong, nullable) UIColor *navBarColor;

/** Specify visibility of nav bar. This property will be used to hide/show the nav bar*/
@property (nonatomic) BOOL showNavbar;

@property (nonatomic, strong) SFSDKLoginHostListViewController *loginHostListViewController;

/** Applies the view's style attributes to the given navigation bar.
 @param navigationBar The navigation bar that the style is applied to.
 */
- (void)styleNavigationBar:(nullable UINavigationBar *)navigationBar;
- (IBAction)useIDPAction:(id)sender;
- (IBAction)useLocalAction:(id)sender;
@end

@implementation SFSDKLoginFlowSelectionViewController


- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _navBarColor = [UIColor salesforceBlueColor];
        _navBarFont = nil;
        _navBarTextColor = [UIColor whiteColor];
        _showNavbar = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // as this view is not part of navigation controller stack, needs to set the proper view background so that status bar has the
    // right background color
    self.view.backgroundColor = [UIColor whiteColor];
    if(self.showNavbar){
        [self setupNavigationBar];
    };
    [self setupContent];
    
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.showNavbar) {
        [self styleNavigationBar:self.navBar];
    }
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

- (void)setupNavigationBar {
    self.navBar =self.navigationController.navigationBar;
    NSString *title = [SFSDKResourceUtils localizedString:@"TITLE_LOGIN"];
    if ( !title ) {
        title = @"Log In";
    }
    // Setup top item.
    UILabel *item = [[UILabel alloc] initWithFrame:CGRectZero];
    item.text = title;
    [item sizeToFit];
    
    self.navBar.topItem.titleView = item;
    [self showSettingsIcon];
    [self setNeedsStatusBarAppearanceUpdate];
}

+ (UIImage*)imageWithImage:(UIImage*)image
              scaledToSize:(CGSize)newSize
{
    UIGraphicsBeginImageContext( newSize );
    [image drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

- (void)setupContent {
    self.view.backgroundColor = [UIColor salesforceSystemBackgroundColor];
    UIColor *darkblue= [UIColor colorWithDisplayP3Red: 20.0/255.0 green:50.0/255.0 blue:92.0/255.0 alpha:1.0];
    self.navigationController.navigationBar.barTintColor = darkblue;
    [self.navigationController.navigationBar setTranslucent:NO];
    
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName:[UIColor whiteColor], NSFontAttributeName:[UIFont systemFontOfSize:20 weight:UIFontWeightRegular]};
    
    self.title = @"Log in";
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:container];
    [[container.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor] setActive:YES];
    [[container.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor] setActive:YES];
    [[container.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:1.0 constant:-100] setActive:YES];
    
    UILabel *selectLabel = [[UILabel alloc] init];
    selectLabel.translatesAutoresizingMaskIntoConstraints = NO;
    selectLabel.text = @"Select a login flow";
    selectLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    selectLabel.textAlignment = NSTextAlignmentCenter;
    selectLabel.textColor = [UIColor salesforceLabelColor];
    
    UILabel *idpLabel = [[UILabel alloc] init];
    idpLabel.translatesAutoresizingMaskIntoConstraints = NO;
    idpLabel.text = @"Use the IDP option if you prefer to share your credentials between multiple apps";
    idpLabel.numberOfLines = 2;
    idpLabel.lineBreakMode = NSLineBreakByWordWrapping;
    idpLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    idpLabel.textAlignment = NSTextAlignmentCenter;
    idpLabel.textColor = [UIColor salesforceLabelColor];
    
    UIButton *idpButton = [UIButton buttonWithType:UIButtonTypeCustom];
    idpButton.translatesAutoresizingMaskIntoConstraints = NO;
    [idpButton setTitle:@"Log in Using IDP Application" forState:UIControlStateNormal];
    [idpButton.titleLabel setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightRegular]];
    idpButton.backgroundColor = [UIColor colorWithDisplayP3Red: 0.0/255.0 green:112.0/255.0 blue:210.0/255.0 alpha:1.0];
    idpButton.layer.cornerRadius = 4.0;
    [idpButton addTarget:self action:@selector(useIDPAction:) forControlEvents:UIControlEventTouchUpInside];
    
    UILabel *appLabel = [[UILabel alloc] init];
    appLabel.translatesAutoresizingMaskIntoConstraints = NO;
    appLabel.text = @"Use this option if you prefer to use your credentials for this app only.";
    appLabel.lineBreakMode = NSLineBreakByWordWrapping;
    appLabel.numberOfLines = 2;
    appLabel.font =  [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    appLabel.textColor = [UIColor salesforceLabelColor];
    
    UIButton *appButton = [UIButton buttonWithType:UIButtonTypeCustom];
    appButton.translatesAutoresizingMaskIntoConstraints = NO;
    [appButton setTitle:@"Log in Using App" forState:UIControlStateNormal];
    [appButton.titleLabel setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightRegular]];
    appButton.backgroundColor = [UIColor colorWithDisplayP3Red: 0.0/255.0 green:112.0/255.0 blue:210.0/255.0 alpha:1.0];
    appButton.layer.cornerRadius = 4.0;
    [appButton addTarget:self action:@selector(useLocalAction:) forControlEvents:UIControlEventTouchUpInside];
    
    [container addSubview:selectLabel];
    [container addSubview:idpLabel];
    [container addSubview:idpButton];
    [container addSubview:appLabel];
    [container addSubview:appButton];
    
    [selectLabel.topAnchor constraintEqualToAnchor:container.topAnchor].active = YES;
    [selectLabel.centerXAnchor constraintEqualToAnchor:container.centerXAnchor].active = YES;
    
    [idpLabel.topAnchor constraintEqualToAnchor:selectLabel.bottomAnchor].active = YES;
    [idpLabel.leftAnchor constraintEqualToAnchor:container.leftAnchor].active = YES;
    [idpLabel.rightAnchor constraintEqualToAnchor:container.rightAnchor].active = YES;

    [idpButton.topAnchor constraintEqualToAnchor:idpLabel.bottomAnchor constant:14].active = YES;
    [idpButton.leftAnchor constraintEqualToAnchor:container.leftAnchor].active = YES;
    [idpButton.rightAnchor constraintEqualToAnchor:container.rightAnchor].active = YES;
    [idpButton.heightAnchor constraintEqualToConstant:50.0].active = YES;
    
    [appLabel.topAnchor constraintEqualToAnchor:idpButton.bottomAnchor constant:60].active = YES;
    [appLabel.leftAnchor constraintEqualToAnchor:container.leftAnchor].active = YES;
    [appLabel.rightAnchor constraintEqualToAnchor:container.rightAnchor].active = YES;
    
    [appButton.topAnchor constraintEqualToAnchor:appLabel.bottomAnchor constant:14].active = YES;
    [appButton.leftAnchor constraintEqualToAnchor:container.leftAnchor].active = YES;
    [appButton.rightAnchor constraintEqualToAnchor:container.rightAnchor].active = YES;
    [appButton.heightAnchor constraintEqualToConstant:50.0].active = YES;
    [appButton.bottomAnchor constraintEqualToAnchor:container.bottomAnchor].active = YES;
}

- (void)styleNavigationBar:(UINavigationBar *)navigationBar {
    if (!navigationBar) {
        return;
    }
    [SFSDKViewUtils styleNavigationBar:navigationBar config:[SFUserAccountManager sharedInstance].loginViewControllerConfig classes:@[[self.navigationController class]]];
}

- (void)showSettingsIcon {
    
    SFManagedPreferences *managedPreferences = [SFManagedPreferences sharedPreferences];
    if (!managedPreferences.onlyShowAuthorizedHosts && managedPreferences.loginHosts.count == 0) {
        UIImage *image = [[SFSDKResourceUtils imageNamed:@"login-window-gear"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(showLoginHost:)];
        rightButton.accessibilityLabel = [SFSDKResourceUtils localizedString:@"LOGIN_CHOOSE_SERVER"];
        self.navBar.topItem.rightBarButtonItem = rightButton;
        self.navBar.topItem.rightBarButtonItem.tintColor = [UIColor  whiteColor];
    }
    
}

- (SFSDKLoginHostListViewController *)loginHostListViewController {
    if (!_loginHostListViewController) {
        _loginHostListViewController = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
        _loginHostListViewController.delegate = self;
    }
    return _loginHostListViewController;
}


- (IBAction)showLoginHost:(id)sender {
    [self showHostListView];
}

- (IBAction)useIDPAction:(id)sender {
    [self.selectionFlowDelegate loginFlowSelectionIDPSelected:self options:self.appOptions];
}

- (IBAction)useLocalAction:(id)sender {
    [self.selectionFlowDelegate loginFlowSelectionLocalLoginSelected:self options:self.appOptions];
}


- (void)showHostListView {
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self.loginHostListViewController];
    navController.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)hideHostListView:(BOOL)animated {
    [self dismissViewControllerAnimated:animated completion:nil];
}

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
    self.appOptions[kSFLoginHostParam] = newLoginHost.host;
    [self.selectionFlowDelegate loginFlowSelectionIDPSelected:self options:self.appOptions];
}

@end
