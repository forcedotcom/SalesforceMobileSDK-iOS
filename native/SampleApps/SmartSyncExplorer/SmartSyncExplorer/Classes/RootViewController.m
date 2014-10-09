//
//  RootViewController.m
//  SmartSyncExplorer
//
//  Created by Kevin Hawkins on 10/8/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "RootViewController.h"

static NSString * const kSObjectType = @"Contact";
static NSString * const kSObjectTitle = @"Contacts";

@interface RootViewController ()

@property (nonatomic, strong) UILabel *navBarLabel;
@property (nonatomic, strong) UIView *searchHeader;
@property (nonatomic, strong) UIImageView *syncIconView;
@property (nonatomic, strong) UITextField *searchTextField;
@property (nonatomic, strong) UIView *searchTextFieldLeftView;
@property (nonatomic, strong) UIImageView *searchIconView;
@property (nonatomic, strong) UILabel *searchTextFieldLabel;

@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];[UINavigationBar appearance];
}

- (void)loadView {
    [super loadView];
    self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:(241.0 / 255.0) green:0.0 blue:0.0 alpha:0.0];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    
    // Nav bar label
    self.navBarLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.navBarLabel.text = kSObjectTitle;
    self.navBarLabel.textAlignment = NSTextAlignmentLeft;
    self.navBarLabel.textColor = [UIColor whiteColor];
    self.navBarLabel.backgroundColor = [UIColor clearColor];
    self.navBarLabel.font = [UIFont systemFontOfSize:20.0];
    self.navigationItem.titleView = self.navBarLabel;
    
    // Search header
    self.searchHeader = [[UIView alloc] initWithFrame:CGRectZero];
    self.searchHeader.backgroundColor = [UIColor colorWithRed:(175.0 / 255.0) green:(182.0 / 255.0) blue:(187.0 / 255.0) alpha:1.0];
    
    UIImage *syncIcon = [UIImage imageNamed:@"sync"];
    self.syncIconView = [[UIImageView alloc] initWithImage:syncIcon];
    [self.searchHeader addSubview:self.syncIconView];
    
    self.searchTextField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.searchTextField.backgroundColor = [UIColor colorWithRed:(224.0 / 255.0) green:(221.0 / 255.0) blue:(221.0 / 255.0) alpha:1.0];
    self.searchTextField.layer.cornerRadius = 10.0f;
    
    self.searchTextFieldLeftView = [[UIView alloc] initWithFrame:CGRectZero];
    UIImage *searchIcon = [UIImage imageNamed:@"search"];
    self.searchIconView = [[UIImageView alloc] initWithImage:searchIcon];
    [self.searchTextFieldLeftView addSubview:self.searchIconView];
    self.searchTextFieldLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.searchTextFieldLabel.text = @"Search";
    self.searchTextFieldLabel.textColor = [UIColor colorWithRed:(150.0 / 255.0) green:(150.0 / 255.0) blue:(150.0 / 255.0) alpha:1.0];
    self.searchTextFieldLabel.font = [UIFont systemFontOfSize:10.0];
    [self.searchTextFieldLeftView addSubview:self.searchTextFieldLabel];
    
    self.searchTextField.leftView = self.searchTextFieldLeftView;
    self.searchTextField.leftViewMode = UITextFieldViewModeUnlessEditing;
    
    
    [self.searchHeader addSubview:self.searchTextField];
    
    self.tableView.tableHeaderView = self.searchHeader;
}

- (void)viewWillLayoutSubviews {
    self.navBarLabel.frame = self.navigationController.navigationBar.frame;
    self.searchHeader.frame = CGRectMake(0, 0, self.navigationController.navigationBar.frame.size.width, 50);
    NSLog(@"searchHeader.frame: %@", NSStringFromCGRect(self.searchHeader.frame));
    NSLog(@"Screen size: %@", NSStringFromCGRect([UIScreen mainScreen].bounds));
    self.syncIconView.frame = CGRectMake(5, CGRectGetMidY(self.searchHeader.frame) - (self.syncIconView.image.size.height / 2.0), self.syncIconView.image.size.width, self.syncIconView.image.size.height);
    self.searchTextField.frame = CGRectMake(5 + self.syncIconView.frame.size.width + 5, CGRectGetMidY(self.searchHeader.frame) - (35.0 / 2.0), self.searchHeader.frame.size.width - 15 - 5 - 5 - self.syncIconView.frame.size.width, 35);
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end
