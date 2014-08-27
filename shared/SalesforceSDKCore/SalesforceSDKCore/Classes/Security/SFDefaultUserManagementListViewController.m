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

#import "SFDefaultUserManagementListViewController.h"
#import "SFDefaultUserManagementViewController+Internal.h"
#import "SFDefaultUserManagementDetailViewController.h"
#import "SFUserAccountManager.h"
#import "SFUserAccount.h"

@interface SFDefaultUserManagementListViewController ()
{
    NSArray *_userAccountList;
    BOOL _hasCurrentUser;
}

- (NSArray *)accountListMinusCurrentUser:(NSArray *)originalAccountList;
- (void)createNewUser;
- (void)cancel;

@end

@implementation SFDefaultUserManagementListViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.navigationItem.title = @"User List";
    
    UIBarButtonItem *newUserItem = [[UIBarButtonItem alloc] initWithTitle:@"New User" style:UIBarButtonItemStylePlain target:self action:@selector(createNewUser)];
    self.navigationItem.rightBarButtonItem = newUserItem;
    UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.navigationItem.leftBarButtonItem = cancelItem;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // The account list is going to be easier to manage as a data source without the current user, since
    // the current user, if present, will be separated from the other users in the table view.
    _userAccountList = [self accountListMinusCurrentUser:[SFUserAccountManager sharedInstance].allUserAccounts];
    _hasCurrentUser = ([SFUserAccountManager sharedInstance].currentUser != nil);
    [self.tableView reloadData];
}

#pragma mark - Private methods

- (NSArray *)accountListMinusCurrentUser:(NSArray *)originalAccountList
{
    NSMutableArray *updatedAccountList = [NSMutableArray array];
    for (SFUserAccount *account in originalAccountList) {
        if (![account isEqual:[SFUserAccountManager sharedInstance].currentUser]) {
            [updatedAccountList addObject:account];
        }
    }
    
    return [updatedAccountList mutableCopy];
}

- (void)createNewUser
{
    SFDefaultUserManagementViewController *mainController = (SFDefaultUserManagementViewController *)self.navigationController;
    [mainController execCompletionBlock:SFUserManagementActionCreateNewUser account:nil];
}

- (void)cancel
{
    SFDefaultUserManagementViewController *mainController = (SFDefaultUserManagementViewController *)self.navigationController;
    [mainController execCompletionBlock:SFUserManagementActionCancel account:nil];
}

#pragma mark - Table view delegate

- (UIView *)tableView:(UITableView *)theTableView viewForHeaderInSection:(NSInteger)section
{
    static NSString *HeaderIdentifier = @"HeaderIdentifier";
    
    UITableViewHeaderFooterView *headerView = [theTableView dequeueReusableHeaderFooterViewWithIdentifier:HeaderIdentifier];
    if (headerView == nil) {
        headerView = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:HeaderIdentifier];
    }
    if (section == 0) {
        headerView.textLabel.text = @"Current User";
    } else {
        headerView.textLabel.text = @"Other Users";
    }
    return headerView;
}

- (void)tableView:(UITableView *)theTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
    SFUserAccount *selectedUser = (indexPath.section == 0 ?
                                  [SFUserAccountManager sharedInstance].currentUser :
                                  _userAccountList[indexPath.row]);
    SFDefaultUserManagementDetailViewController *dvc = [[SFDefaultUserManagementDetailViewController alloc] initWithUser:selectedUser];
    [self.navigationController pushViewController:dvc animated:YES];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)theTableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)theTableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return (_hasCurrentUser ? 1 : 0);
    } else {
        return [_userAccountList count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)theTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"CellIdentifier";
    
    // Dequeue or create a cell of the appropriate type.
    UITableViewCell *cell = [theTableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
	// Configure the cell to show the data.
    SFUserAccount *displayUser = (indexPath.section == 0 ?
                                  [SFUserAccountManager sharedInstance].currentUser :
                                  _userAccountList[indexPath.row]);
    cell.textLabel.text = displayUser.fullName;
    cell.detailTextLabel.text = displayUser.userName;
    
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
	return cell;
}

@end
