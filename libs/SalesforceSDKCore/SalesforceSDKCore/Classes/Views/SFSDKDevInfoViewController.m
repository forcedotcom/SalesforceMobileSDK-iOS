/*
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


#import "SFSDKDevInfoViewController.h"
#import "SalesforceSDKManager.h"
#import "SFSDKResourceUtils.h"
#import "UIColor+SFColors.h"

// Nav bar
static CGFloat      const kStatusBarHeight       = 20.0;
static CGFloat      const kNavBarHeight          = 44.0;
static CGFloat      const kNavBarTitleFontSize   = 18.0;
// Resource keys
static NSString * const kDevInfoTitleKey = @"devInfoTitle";
static NSString * const kDevInfoBackButtonTitleKey = @"devInfoBackButtonTitle";
static NSString * const kDevInfoOKKey = @"devInfoOKKey";

@interface SFSDKDevInfoViewController () <UINavigationBarDelegate>

@property (nonatomic, strong) UINavigationBar *navBar;
@property (nonatomic, strong) UITableView *infoTable;
@property (nonatomic, strong) NSArray *infoData;


@end

@implementation SFSDKDevInfoViewController

#pragma mark - Constructor

- (instancetype) init
{
    self = [super init];
    if (self) {
        self.infoData = [[SalesforceSDKManager sharedManager] getDevSupportInfos];
    }
    return self;
}

#pragma mark - View lifecycle

#pragma mark - Actions handlers

- (void) backButtonClicked
{
    [self.presentingViewController dismissViewControllerAnimated:NO completion:NULL];
}

- (void) showAlert:(NSString*)message title:(NSString*)title
{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];


    UIAlertAction *okAction = [UIAlertAction
            actionWithTitle:[SFSDKResourceUtils localizedString:kDevInfoOKKey]
                      style:UIAlertActionStyleDefault
                    handler:nil];

    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - View layout

- (void)loadView
{
    [super loadView];

    // Background color
    self.view.backgroundColor = [UIColor salesforceBlueColor];

    // Nav bar
    self.navBar = [self createNavBar];

    // Table view
    self.infoTable = [self createTableView];

}

- (UINavigationBar*) createNavBar
{
    UINavigationBar* navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, kNavBarHeight)];
    navBar.delegate = self;
    UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:[SFSDKResourceUtils localizedString:kDevInfoTitleKey]];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:[SFSDKResourceUtils localizedString:kDevInfoBackButtonTitleKey] style:UIBarButtonItemStylePlain target:self action:@selector(backButtonClicked)];
    [navItem setLeftBarButtonItem:backItem];
    [navBar setItems:@[navItem] animated:YES];
    navBar.translucent = NO;
    navBar.barTintColor = [UIColor salesforceBlueColor];
    navBar.tintColor = [UIColor whiteColor];
    navBar.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName:[UIFont systemFontOfSize:kNavBarTitleFontSize]};
    [self.view addSubview:navBar];
    return navBar;
}

- (UITableView*) createTableView
{
    UITableView *infoTable = [[UITableView alloc] initWithFrame:CGRectZero];
    infoTable.backgroundColor = [UIColor lightGrayColor];
    [infoTable setDataSource:self];
    [infoTable setDelegate:self];
    [self.view addSubview:infoTable];
    return infoTable;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self layoutSubviews];
}

- (void)viewWillLayoutSubviews
{
    [self layoutSubviews];
    [super viewWillLayoutSubviews];
}

- (void)layoutSubviews
{
    [self layoutNavBar];
    [self layoutTableView];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (CGFloat) belowFrame:(CGRect) frame {
    return frame.origin.y + frame.size.height;
}

- (void) layoutNavBar
{
    CGFloat x = 0;
    CGFloat y = kStatusBarHeight;
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = kNavBarHeight;
    self.navBar.frame = CGRectMake(x, y, w, h);
}

- (void) layoutTableView
{
    CGFloat x = 0;
    CGFloat y = [self belowFrame:self.navBar.frame];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height - y;
    self.infoTable.frame = CGRectMake(x, y, w, h);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.infoData.count / 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }

    cell.textLabel.text = self.infoData[indexPath.row * 2];
    cell.detailTextLabel.text = self.infoData[indexPath.row * 2 + 1];
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self showAlert:self.infoData[indexPath.row * 2 + 1] title:nil];
}


@end
