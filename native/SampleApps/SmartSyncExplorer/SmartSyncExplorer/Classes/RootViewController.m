/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "RootViewController.h"
#import "SObjectDataManager.h"
#import "ContactSObjectDataSpec.h"
#import "ContactSObjectData.h"

@interface RootViewController ()

// View / UI properties
@property (nonatomic, copy) NSString *sobjectTitle;
@property (nonatomic, strong) UILabel *navBarLabel;
@property (nonatomic, strong) UIView *searchHeader;
@property (nonatomic, strong) UIImageView *syncIconView;
@property (nonatomic, strong) UITextField *searchTextField;
@property (nonatomic, strong) UIView *searchTextFieldLeftView;
@property (nonatomic, strong) UIImageView *searchIconView;
@property (nonatomic, strong) UILabel *searchTextFieldLabel;

// Data properties
@property (nonatomic, strong) SObjectDataManager *dataMgr;

@end

@implementation RootViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.sobjectTitle = @"Contacts";
        SObjectDataSpec *dataSpec = [[ContactSObjectDataSpec alloc] init];
        self.dataMgr = [[SObjectDataManager alloc] initWithViewController:self dataSpec:dataSpec];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.dataMgr refreshData];
}

- (void)loadView {
    [super loadView];
    self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:(241.0 / 255.0) green:0.0 blue:0.0 alpha:0.0];
    
    // Nav bar label
    self.navBarLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.navBarLabel.text = self.sobjectTitle;
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
    self.searchTextField.font = [UIFont systemFontOfSize:14.0];
    self.searchTextField.layer.cornerRadius = 10.0f;
    
    self.searchTextFieldLeftView = [[UIView alloc] initWithFrame:CGRectZero];
    self.searchTextFieldLeftView.backgroundColor = [UIColor clearColor];
    UIImage *searchIcon = [UIImage imageNamed:@"search"];
    self.searchIconView = [[UIImageView alloc] initWithImage:searchIcon];
    [self.searchTextFieldLeftView addSubview:self.searchIconView];
    self.searchTextFieldLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.searchTextFieldLabel.text = @"Search";
    self.searchTextFieldLabel.textColor = [UIColor colorWithRed:(150.0 / 255.0) green:(150.0 / 255.0) blue:(150.0 / 255.0) alpha:1.0];
    self.searchTextFieldLabel.font = [UIFont systemFontOfSize:14.0];
    [self.searchTextFieldLeftView addSubview:self.searchTextFieldLabel];
    
    self.searchTextField.leftView = self.searchTextFieldLeftView;
    self.searchTextField.leftViewMode = UITextFieldViewModeUnlessEditing;
    
    
    [self.searchHeader addSubview:self.searchTextField];
    
    self.tableView.tableHeaderView = self.searchHeader;
}

- (void)viewWillLayoutSubviews {
    // TODO: Clean up, split out into methods.
    // TODO: Coordinates cleanup.
    self.navBarLabel.frame = self.navigationController.navigationBar.frame;
    self.searchHeader.frame = CGRectMake(0, 0, self.navigationController.navigationBar.frame.size.width, 50);
    self.syncIconView.frame = CGRectMake(5, CGRectGetMidY(self.searchHeader.frame) - (self.syncIconView.image.size.height / 2.0), self.syncIconView.image.size.width, self.syncIconView.image.size.height);
    self.searchTextField.frame = CGRectMake(5 + self.syncIconView.frame.size.width + 5, CGRectGetMidY(self.searchHeader.frame) - (35.0 / 2.0), self.searchHeader.frame.size.width - 15 - 5 - 5 - self.syncIconView.frame.size.width, 35);
    
    // Determine search text field left view size.
    CGSize searchLabelTextSize = [self.searchTextFieldLabel.text sizeWithAttributes:@{ NSFontAttributeName:self.searchTextFieldLabel.font }];
    CGFloat viewWidth = self.searchIconView.image.size.width + 5 + searchLabelTextSize.width;
    CGFloat viewHeight = MAX(self.searchIconView.image.size.height, searchLabelTextSize.height);
    self.searchTextFieldLeftView.frame = CGRectMake(5, 0, viewWidth, viewHeight);
    self.searchIconView.frame = CGRectMake(0, CGRectGetMidY(self.searchTextFieldLeftView.frame) - (self.searchIconView.image.size.height / 2.0), self.searchIconView.image.size.width, self.searchIconView.image.size.height);
    self.searchTextFieldLabel.frame = CGRectMake(self.searchIconView.frame.size.width + 5, CGRectGetMidY(self.searchTextFieldLeftView.frame) - (searchLabelTextSize.height / 2.0), searchLabelTextSize.width, searchLabelTextSize.height);
}

- (void)viewWillAppear:(BOOL)animated {
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableViewDataSource methods

- (UITableViewCell *)tableView:(UITableView *)tableView_ cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"CellIdentifier";
    
    UITableViewCell *cell = [tableView_ dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    // TODO: Circle
    UIImage *image = [UIImage imageNamed:@"icon.png"];
    cell.imageView.image = image;
    
    ContactSObjectData *obj = [self.dataMgr.dataRows objectAtIndex:indexPath.row];
    cell.textLabel.text = [self formatNameWithFirstName:obj.firstName lastName:obj.lastName];
    cell.detailTextLabel.text = [self formatTitle:obj.title];
    
    //this adds the arrow to the right hand side.
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.dataMgr.dataRows count];
}

#pragma mark - Private methods

- (NSString *)formatNameWithFirstName:(NSString *)firstName lastName:(NSString *)lastName {
    firstName = [firstName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    lastName = [lastName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (firstName == nil && lastName == nil) {
        return @"";
    } else if (firstName == nil && lastName != nil) {
        return lastName;
    } else if (firstName != nil && lastName == nil) {
        return firstName;
    } else {
        return [NSString stringWithFormat:@"%@ %@", firstName, lastName];
    }
}

- (NSString *)formatTitle:(NSString *)title {
    title = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return (title != nil ? title : @"");
}

@end
