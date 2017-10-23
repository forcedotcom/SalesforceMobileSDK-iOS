/*
 SFSDKUserSelectionTableViewControllerDelegate.m
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

#import "SFSDKUserSelectionTableViewController.h"
#import "SFSDKIDPConstants.h"
#import "SFUserAccountManager.h"
#import "UIColor+SFColors.h"
#import "SFIdentityData.h"
@interface SFSDKUserSelectionTableViewController ()<UITableViewDelegate,UITableViewDataSource>{
    NSArray *_userAccountList;
}

@property (nonatomic,strong) IBOutlet UITableView *tableView;
@property (nonatomic,strong) IBOutlet UIStackView *stackView;
@end

@implementation SFSDKUserSelectionTableViewController
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
   
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self reloadUsers];
    [self setupViews];
    [self.tableView reloadData];
}

- (void)setupViews {
    
    UIView *topStackViewInner = [[UIView alloc] initWithFrame:CGRectMake(5, 10, self.view.frame.size.width-5, self.view.frame.size.height*0.10f)];
    
    UITextView *infoLabel = [[UITextView alloc] initWithFrame:topStackViewInner.frame];
    infoLabel.editable = FALSE;
    
   // infoLabel = 5;
    UIFont *font = [UIFont boldSystemFontOfSize:18.0];
    UIFont *normalFont = [UIFont systemFontOfSize:18.0];
    NSString *appName = [self.options objectForKey:kSFAppNameParam];
    
    if (!appName) {
        appName = kSFAppNameDefault;
    }
    
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:appName  attributes:@{ NSFontAttributeName : font, NSForegroundColorAttributeName : [UIColor redColor] }];
    
    NSMutableAttributedString *attributedNormalText = [[NSMutableAttributedString alloc] initWithString:@" is requesting access to users credentials. Select a user from the list" attributes:@{NSFontAttributeName : normalFont , NSForegroundColorAttributeName : [UIColor grayColor] }];
    
    [attributedText appendAttributedString:attributedNormalText];
    infoLabel.attributedText = attributedText;
    [topStackViewInner addSubview:infoLabel];
    
    _tableView =  [[UITableView alloc] initWithFrame:CGRectMake(5, topStackViewInner.frame.size.height+20, self.view.frame.size.width, self.view.frame.size.height*(0.90f)) style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;

    topStackViewInner.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:topStackViewInner];
    [self.view addSubview:_tableView];
   
    self.view.backgroundColor = [UIColor whiteColor];
    UIImage *backgroundImage = [[self class] imageFromColor:[UIColor salesforceBlueColor]];
    [self.navigationController.navigationBar setBackgroundImage:backgroundImage forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.tintColor= [UIColor whiteColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{
                                                                      NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont systemFontOfSize:20]}];
    self.navigationItem.title = @"Select User";
    UIBarButtonItem *newUserItem = [[UIBarButtonItem alloc] initWithTitle:@"New User" style:UIBarButtonItemStylePlain target:self action:@selector(createNewUser)];
    self.navigationItem.rightBarButtonItem = newUserItem;
    UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.navigationItem.leftBarButtonItem = cancelItem;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - Private methods
- (void)createNewUser
{
    [self.listViewDelegate createNewuser:self.options];
}

- (void)cancel
{
    [self.listViewDelegate cancel:self.options];
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)theTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
    self.selectedAccount =_userAccountList[indexPath.row];
    [self.listViewDelegate selectedUser:self.selectedAccount options:self.options];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)theTableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)theTableView numberOfRowsInSection:(NSInteger)section
{
    
    return [_userAccountList count];
    
}

- (UITableViewCell *)tableView:(UITableView *)theTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"CellIdentifier";
    
    // Dequeue or create a cell of the appropriate type.
    UITableViewCell *cell = [theTableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell to show the data.
    SFUserAccount *displayUser =_userAccountList[indexPath.row];
    
    cell.textLabel.text = displayUser.fullName ;
   

    cell.detailTextLabel.text = displayUser.credentials.domain;
    
    
    return cell;
}

- (void)reloadUsers {
    NSString *loginHost = [self.options objectForKey:kSFLoginHostParam];
    if (loginHost) {
        _userAccountList = [[SFUserAccountManager sharedInstance] userAccountsForDomain:loginHost];
    } else {
        _userAccountList = [SFUserAccountManager sharedInstance].allUserAccounts;
    }
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
