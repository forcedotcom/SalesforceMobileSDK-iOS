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
#import "UIColor+SFSDKIDP.m"
#import "UIFont+SFSDKIDP.h"
#import "SFSDKUITableViewCell.h"
#import "SFUserAccountManager.h"
#import "SFIdentityData.h"
#import "SFSDKResourceUtils.h"
static CGFloat kVerticalSpace = 16;
static CGFloat kHorizontalSpace = 12;

@protocol UIFooterViewDelegate
- (void)createUser;
@end

@interface UIHeaderView : UIView
@property UIImageView *logoView;
@property UILabel *descriptionLabel;
@property UILabel *appNameLabel;
@property NSString *appName;
- (instancetype) initWithFrame:(CGRect)frame andAppName:(NSString *)appName;
@end

@interface UIFooterView : UIView
@property (nonatomic,strong) UIButton *addButton;
@property (nonatomic,strong) UILabel *descriptionLabel;
@property (nonatomic,weak)   id<UIFooterViewDelegate> footerDelegate;
@end

@interface SFSDKUserSelectionTableViewController ()<UIFooterViewDelegate>
@property (nonatomic,strong) NSArray *userData;
+(UIImage *) resizeImage:(UIImage *)orginalImage resizeSize:(CGSize)size;
@end

@implementation UIHeaderView

- (instancetype) initWithFrame:(CGRect)frame andAppName:(NSString *)appName {
    self = [super initWithFrame:frame];
    if (self) {
        self.appName = appName;
    }
    return self;
}

- (void)layoutSubviews
{
    UIImage *logotmp = [[SFSDKResourceUtils imageNamed:@"salesforce-logo"]  imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    
    UIImage *logo  = [SFSDKUserSelectionTableViewController  resizeImage:logotmp resizeSize:CGSizeMake(150,120)];
    self.logoView = [[UIImageView alloc]initWithImage:logo];
    self.logoView.contentMode = UIViewContentModeScaleToFill;
    self.backgroundColor = [UIColor backgroundcolor];
    self.descriptionLabel = [[UILabel alloc] init];
    self.appNameLabel = [[UILabel alloc] init];
    self.descriptionLabel.text = [SFSDKResourceUtils localizedString:@"idpSelectUserLabel"];
    self.appNameLabel.text = self.appName;
    self.descriptionLabel.font = [UIFont textRegular:16.0];
    self.descriptionLabel.textColor = [UIColor altTextColor];
    self.appNameLabel.font = [UIFont textRegular:16.0];
    self.appNameLabel.textColor = [UIColor altTextColor];
    [self.superview addSubview:self.logoView];
    [self.superview addSubview:self.descriptionLabel];
    [self.superview addSubview:self.appNameLabel];
    
    self.logoView.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.appNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    //add constraints
    [self.logoView.topAnchor constraintEqualToAnchor:self.topAnchor constant:kVerticalSpace].active = YES;
    [self.logoView.centerXAnchor  constraintEqualToAnchor:self.centerXAnchor].active = YES;
    [self.descriptionLabel.topAnchor   constraintEqualToAnchor:self.logoView.bottomAnchor constant:kVerticalSpace].active = YES;
    [self.descriptionLabel.centerXAnchor    constraintEqualToAnchor:self.logoView.centerXAnchor].active = YES;
    [self.appNameLabel.topAnchor   constraintEqualToAnchor:self.descriptionLabel.bottomAnchor constant:kHorizontalSpace].active = YES;
    [self.appNameLabel.centerXAnchor constraintEqualToAnchor:self.descriptionLabel.centerXAnchor].active = YES;
}
@end

@implementation UIFooterView

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.backgroundColor = [UIColor backgroundcolor];
    UIImage *addAccountImageTmp = [[SFSDKResourceUtils imageNamed:@"account-add"]  imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    UIImage *addAccountImage  = [SFSDKUserSelectionTableViewController  resizeImage:addAccountImageTmp resizeSize:CGSizeMake(18,18)];
    self.addButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.addButton setBackgroundImage:addAccountImage forState:UIControlStateNormal];
    self.descriptionLabel = [[UILabel alloc] init];
    self.descriptionLabel.text = [SFSDKResourceUtils localizedString:@"idpAddNewAccountLabel"];
    self.descriptionLabel.font = [UIFont textRegular:16];
    self.descriptionLabel.textColor = [UIColor defaultTextColor];
    self.addButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.superview addSubview:self.addButton];
    [self.superview addSubview:self.descriptionLabel];
    [self.addButton addTarget:self action:@selector(createUser) forControlEvents:UIControlEventTouchDown];
    
    [self.addButton.leftAnchor  constraintEqualToAnchor:self.leftAnchor constant:kHorizontalSpace *3].active = YES;
    [self.addButton.topAnchor  constraintEqualToAnchor:self.topAnchor constant:kVerticalSpace].active = YES;
    [self.descriptionLabel.leftAnchor   constraintEqualToAnchor:self.addButton.rightAnchor constant:kHorizontalSpace].active = YES;
    [self.descriptionLabel.topAnchor  constraintEqualToAnchor:self.topAnchor constant:kVerticalSpace].active = YES;
}

- (void)createUser {
    [self.footerDelegate createUser];
}
@end

@implementation SFSDKUserSelectionTableViewController
@synthesize spAppOptions;
@synthesize listViewDelegate;

- (void)loadView {
    [super loadView];
   
    self.tableView = [self createTableView];
    self.view.backgroundColor = [UIColor backgroundcolor];
    self.title = [SFSDKResourceUtils localizedString:@"idpSelectUserTitleLabel"];
    UIView *headerView = [self createHeaderView];
    UIView *footerView = [self createFooterView];
    self.tableView = [self createTableView];
    
    self.tableView.tableFooterView = footerView;
    [self.tableView.tableFooterView.bottomAnchor constraintEqualToAnchor:self.tableView.bottomAnchor].active = YES;
    [self.tableView.heightAnchor constraintEqualToConstant:(self.view.bounds.size.height * 3)/4].active = YES;
    [self.tableView.widthAnchor constraintEqualToConstant:self.view.bounds.size.width].active = YES;
    
    UIStackView *stack = [[UIStackView alloc] initWithFrame:CGRectZero];
    stack.backgroundColor =  [UIColor backgroundcolor];
    stack.distribution = UIStackViewDistributionEqualSpacing;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.spacing = 0;
    
    [stack setAxis:UILayoutConstraintAxisVertical];
    [stack addArrangedSubview:headerView];
    [stack addArrangedSubview:self.tableView];
    [self.view addSubview:stack];
    [stack.topAnchor constraintEqualToAnchor:self.view.topAnchor].active = YES;
    [stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initData];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _userData.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [SFSDKUITableViewCell cellHeight];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SFSDKUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[SFSDKUITableViewCell reuseCellIdentifier] forIndexPath:indexPath];
    
    SFUserAccount *userAccount = self.userData[indexPath.row];
    cell.userName  = [NSString stringWithFormat:@"%@ %@",userAccount.idData.firstName, userAccount.idData.lastName];
    cell.hostName = [NSString stringWithFormat:@"%@",userAccount.credentials.domain];
    
    NSURL *url = userAccount.idData.profileUrl;
    cell.imageURL = url;
    if (userAccount.photo) {
        cell.profileImage = userAccount.photo;
    }
    return cell;
}

- (void)tableView:(UITableView *)theTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
    [self.listViewDelegate selectedUser:_userData[indexPath.row]  options:self.spAppOptions];
}

- (void)createUser
{
    [self.listViewDelegate createNewuser:self.spAppOptions];
}

- (void)initData {
    NSString *loginHost = [self.spAppOptions objectForKey:kSFLoginHostParam];
    self.userData = [self filterUsersByHost:loginHost data:[SFUserAccountManager sharedInstance].allUserAccounts];
}

- (NSArray *)filterUsersByHost:(NSString *)host data:(NSArray *)accounts {
    NSPredicate *hostPredicate = [NSPredicate predicateWithFormat:@"credentials.domain==%@",host];
    NSArray<SFUserAccount *> *array  = [accounts filteredArrayUsingPredicate:hostPredicate];
    return array;
}

#pragma mark - Factory Methods

- (UIView *)createFooterView{
    UIFooterView *footerView = [[UIFooterView alloc] init];
    footerView.footerDelegate = self;
    return footerView;
}

- (UITableView *)createTableView {
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.backgroundColor = [UIColor backgroundcolor];
    [tableView registerClass:[SFSDKUITableViewCell class] forCellReuseIdentifier:[SFSDKUITableViewCell reuseCellIdentifier]];
    return tableView;
}

- (UIView *)createHeaderView{
    NSString *appName = [self.spAppOptions objectForKey:kSFAppNameParam];
    if (!appName) {
        appName = @"Application";
    }
    UIView *headerView = [[UIHeaderView alloc] initWithFrame:CGRectZero andAppName:appName];
    [headerView.heightAnchor constraintEqualToConstant:(self.view.bounds.size.height/4) + 20].active = YES;
    [headerView.widthAnchor constraintEqualToConstant:self.view.bounds.size.width].active = YES;
    return headerView;
}

+ (UIImage *)resizeImage:(UIImage *)orginalImage resizeSize:(CGSize)size
{
    CGFloat actualHeight = orginalImage.size.height;
    CGFloat actualWidth = orginalImage.size.width;
    
    float oldRatio = actualWidth/actualHeight;
    float newRatio = size.width/size.height;
    if(oldRatio < newRatio)
    {
        oldRatio = size.height/actualHeight;
        actualWidth = oldRatio * actualWidth;
        actualHeight = size.height;
    }
    else
    {
        oldRatio = size.width/actualWidth;
        actualHeight = oldRatio * actualHeight;
        actualWidth = size.width;
    }
    CGRect rect = CGRectMake(0.0,0.0,actualWidth,actualHeight);
    UIGraphicsBeginImageContext(rect.size);
    [orginalImage drawInRect:rect];
    orginalImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return orginalImage;
}

@end
