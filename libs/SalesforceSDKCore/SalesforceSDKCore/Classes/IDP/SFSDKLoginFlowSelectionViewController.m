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

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static SFSDKLoginFlowSelectionViewController *loginFlowSelectionViewController = nil;
    dispatch_once(&onceToken, ^{
        loginFlowSelectionViewController = [[self alloc] initWithNibName:nil bundle:nil];
    });
    return loginFlowSelectionViewController;
}

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
    [self setupViews];
    
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutViews];
}


- (void)layoutViews {
    
    // Let navBar tell us what height it would prefer at the current orientation
    CGFloat navBarHeight = [self.navBar sizeThatFits:self.view.bounds.size].height;
    // Resize navBar
    self.navBar.frame = CGRectMake(0, self.topLayoutGuide.length, self.view.bounds.size.width, navBarHeight);

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
    self.navBar = [[UINavigationBar alloc] initWithFrame:CGRectZero];
    NSString *title = @"Login";
    
    // Setup top item.
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:title];
    self.navBar.items = @[item];
    [self styleNavigationBar:self.navBar];
    [self.view addSubview:self.navBar];
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

- (void)setupViews {
    
    UILabel *infoLabel = [[UILabel alloc] init];
    infoLabel.text = @"Select the flow to use for login";
    infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    infoLabel.numberOfLines = 1;
    [infoLabel setFont:[UIFont systemFontOfSize:20]];
    [infoLabel setTextColor:[UIColor salesforceBlueColor]];

    UILabel *descLabel = [[UILabel alloc]init];
    descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    descLabel.text = [NSString stringWithFormat:@"Local - Host App will be used for authentication \n IDP -  %@ will be launched for authentication",[[SFSDKAuthPreferences alloc] init].idpAppURIScheme];
    [descLabel setFont:[UIFont systemFontOfSize:15]];
    [descLabel setTextColor:[UIColor grayColor]];
    
    
    UILabel *descLabel2 = [[UILabel alloc]init];
    descLabel2.numberOfLines = 3;
    descLabel2.translatesAutoresizingMaskIntoConstraints = NO;
    descLabel2.text = [NSString stringWithFormat:@"IDP -  IDP App will be launched for authentication"];
    [descLabel2 setFont:[UIFont systemFontOfSize:15]];
    [descLabel2 setTextColor:[UIColor grayColor]];
    
    
    UIButton *idpButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [idpButton setTitle:@"IDP Login" forState:UIControlStateNormal];
    idpButton.translatesAutoresizingMaskIntoConstraints = NO;
    [idpButton.titleLabel setFont:[UIFont systemFontOfSize:20]];
    [idpButton addTarget:self action:@selector(useIDPAction:) forControlEvents:UIControlEventTouchUpInside];
    
    
    UIButton *localButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [localButton setTitle:@"Local Login" forState:UIControlStateNormal];
    localButton.translatesAutoresizingMaskIntoConstraints = NO;
    [localButton.titleLabel setFont:[UIFont systemFontOfSize:20]];
    [localButton addTarget:self action:@selector(useLocalAction:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:infoLabel];
    [self.view addSubview:descLabel];
    [self.view addSubview:descLabel2];
    [self.view addSubview:idpButton];
    [self.view addSubview:localButton];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:infoLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.navBar attribute:NSLayoutAttributeBottom multiplier:1.0 constant:20.0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:infoLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.navBar attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:descLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:infoLabel attribute:NSLayoutAttributeBottom multiplier:1.0 constant:10.0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:descLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.navBar attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:descLabel2 attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:descLabel attribute:NSLayoutAttributeBottom multiplier:1.0 constant:5.0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:descLabel2 attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:descLabel attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0.0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:idpButton attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:descLabel2 attribute:NSLayoutAttributeBottom multiplier:1.0 constant:55.0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:idpButton attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:infoLabel attribute:NSLayoutAttributeLeft multiplier:1.0 constant:20.0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:localButton attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:descLabel2 attribute:NSLayoutAttributeBottom multiplier:1.0 constant:55.0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:localButton attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:idpButton attribute:NSLayoutAttributeRight multiplier:1.0 constant:20.0]];
  
}

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

- ( UIImage * _Nonnull )headerBackgroundImage {
    UIImage *backgroundImage = [[self class] imageFromColor:self.navBarColor];
    return backgroundImage;
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
    [SFUserAccountManager sharedInstance].loginHost = newLoginHost.host;
    [[SFUserAccountManager sharedInstance] switchToNewUser];
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
