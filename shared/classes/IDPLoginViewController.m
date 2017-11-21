/*
 IDPLoginViewController.m
 SalesforceSDKCore
 
 Created by Raj Rao on 9/28/17.
 
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
#import "IDPLoginViewController.h"
#import <SalesforceSDKCore/SFSDKLoginHostListViewController.h>
#import <SalesforceSDKCore/SFSDKResourceUtils.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFSDKLoginHost.h>
@interface IDPLoginViewController ()<SFSDKLoginHostDelegate>
- (IBAction)loginIDPAction:(id)sender;
- (IBAction)loginLocalAction:(id)sender;
// Reference to the login host list view controller
@property (nonatomic, strong) SFSDKLoginHostListViewController *loginHostListViewController;
@end

@implementation IDPLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self setTitle:@"Log In"];
    
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName:[UIColor whiteColor]};
    self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:0 green:0.439 blue:0.824 alpha:1.0];
    [self showSettingsIcon];
}

- (void)showSettingsIcon {
    
    UIImage *image = [[SFSDKResourceUtils imageNamed:@"login-window-gear"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(showLoginHost:)];
    
    rightButton.accessibilityLabel = [SFSDKResourceUtils localizedString:@"LOGIN_CHOOSE_SERVER"];
    self.navigationController.navigationBar.topItem.rightBarButtonItem = rightButton;
    self.navigationController.navigationBar.topItem.rightBarButtonItem.tintColor = [UIColor  whiteColor];
    
}

- (SFSDKLoginHostListViewController *)loginHostListViewController {
    if (!_loginHostListViewController) {
        _loginHostListViewController = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
        _loginHostListViewController.delegate = self;
    }
    return _loginHostListViewController;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)loginIDPAction:(id)sender {
    if ([self.loginSelectionDelegate respondsToSelector:@selector(loginUsingIDP)]) {
        [self.loginSelectionDelegate loginUsingIDP];
    }
}

- (IBAction)loginLocalAction:(id)sender {
    if ([self.loginSelectionDelegate respondsToSelector:@selector(loginUsingApp)]) {
        [self.loginSelectionDelegate loginUsingApp];
    }
}


- (IBAction)showLoginHost:(id)sender {
    [self showHostListView];
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


@end
