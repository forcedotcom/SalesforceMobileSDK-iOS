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
    UIImage *syncIcon = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"sync" ofType:@"png"]];
    self.syncIconView = [[UIImageView alloc] initWithImage:syncIcon];
    [self.searchHeader addSubview:self.syncIconView];
    self.tableView.tableHeaderView = self.searchHeader;
}

- (void)viewWillLayoutSubviews {
    self.navBarLabel.frame = self.navigationController.navigationBar.frame;
    self.searchHeader.frame = CGRectMake(0, 0, self.navigationController.navigationBar.frame.size.width, 44);
    NSLog(@"searchHeader.frame: %@", NSStringFromCGRect(self.searchHeader.frame));
    NSLog(@"Screen size: %@", NSStringFromCGRect([UIScreen mainScreen].bounds));
    self.syncIconView.frame = CGRectMake(5, CGRectGetMidY(self.searchHeader.frame) - (self.syncIconView.image.size.height / 2.0), self.syncIconView.image.size.width, self.syncIconView.image.size.height);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end
