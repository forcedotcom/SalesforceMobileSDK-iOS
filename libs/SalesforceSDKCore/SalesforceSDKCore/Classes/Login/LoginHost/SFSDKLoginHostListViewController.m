/*
 SFSDKLoginHostListViewController.m
 SalesforceSDKCore
 
 Created by Kunal Chitalia on 1/22/16.
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKLoginHostListViewController.h"
#import "SFSDKNewLoginHostViewController.h"
#import "SFSDKLoginHostStorage.h"
#import "SFSDKLoginHost.h"
#import "SFAuthenticationManager.h"
#import "SFSDKResourceUtils.h"
#import "SFLoginViewController.h"

static NSString * const SFDCLoginHostListCellIdentifier = @"SFDCLoginHostListCellIdentifier";

@interface SFSDKLoginHostListViewController () <UINavigationControllerDelegate>

@end

@implementation SFSDKLoginHostListViewController

/**
 * Apply (that is, reload the web view) with the host at the specified index.
 */
- (void)applyLoginHostAtIndex:(NSUInteger)index {
    SFSDKLoginHost *loginHost = [[SFSDKLoginHostStorage sharedInstance] loginHostAtIndex:index];
    SFUserAccountManager *m = [SFUserAccountManager sharedInstance];
    
    // Change the login host and login again. Don't do any logout as we don't
    // want to remove anything at this point.
    m.loginHost = loginHost.host;
    [[SFAuthenticationManager sharedManager] cancelAuthentication];
    [[SFUserAccountManager sharedInstance] switchToNewUser];}

/**
 * Scroll the table to make sure the host at the specified index is visible.
 */
- (void)makeLoginHostVisibleAtIndex:(NSUInteger)index {
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]
                          atScrollPosition:UITableViewScrollPositionTop
                                  animated:NO];
}

/**
 * Returns the index of the current login host.
 */
- (NSUInteger)indexOfCurrentLoginHost {
    SFUserAccountManager *m = [SFUserAccountManager sharedInstance];
    NSString *currentLoginHost = [m loginHost];
    NSUInteger numberOfLoginHosts = [[SFSDKLoginHostStorage sharedInstance] numberOfLoginHosts];
    for (NSUInteger index = 0; index < numberOfLoginHosts; index++) {
        SFSDKLoginHost *loginHost = [[SFSDKLoginHostStorage sharedInstance] loginHostAtIndex:index];
        if ([loginHost.host isEqual:currentLoginHost]) {
            return index;
        }
    }
    return NSNotFound;
}

- (void)addLoginHost:(SFSDKLoginHost*)host {
    [[SFSDKLoginHostStorage sharedInstance] addLoginHost:host];
    NSUInteger hostIndex = [[SFSDKLoginHostStorage sharedInstance] indexOfLoginHost:host];
    if (hostIndex != NSNotFound) {

        // Apply the selected login host
        [self applyLoginHostAtIndex:hostIndex];

        // Notify the delegate that a new login host has been added.
        [self delegateDidAddLoginHost];
    }
}

- (void)showAddLoginHost {
    [self showAddLoginHost:nil];
}

/**
 * Invoked when the user presses the Add button. This method presents the new login host view.
 */
- (void)showAddLoginHost:(id)sender {
    SFSDKNewLoginHostViewController *detailViewController = [[SFSDKNewLoginHostViewController alloc] initWithStyle:UITableViewStyleGrouped];
    detailViewController.loginHostListViewController = self;
    
    if ([self.delegate respondsToSelector:@selector(hostListViewController:willPresentLoginHostViewController:)]) {
        [self.delegate hostListViewController:self willPresentLoginHostViewController:self];
    }
    
    if (self.navigationController) {
        self.navigationController.delegate = self;
        [self.navigationController pushViewController:detailViewController animated:YES];
    } else {
        [self presentViewController:detailViewController animated:YES completion:nil];
    }
}

#pragma mark - View lifecycle

/**
 * Set the proper size of the view so its popover controller will resize to fit neatly.
 */
- (void)resizeContentForPopover {
    CGRect r = [self.tableView rectForSection:0];
    
    CGSize size = CGSizeMake(380, r.size.height);
    self.preferredContentSize = size;
}

- (void)viewDidLoad {

    // Displays the 'Add Server' button only if the MDM policy allows us to.
    SFManagedPreferences *managedPreferences = [SFManagedPreferences sharedPreferences];
    if (!(managedPreferences.hasManagedPreferences && managedPreferences.onlyShowAuthorizedHosts)) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showAddLoginHost:)];
        [self.navigationItem.rightBarButtonItem setTintColor:[UIColor whiteColor]];
    }
    self.title = [SFSDKResourceUtils localizedString:@"LOGIN_CHOOSE_SERVER"];
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithTitle:@""
                                             style:UIBarButtonItemStylePlain
                                             target:nil
                                             action:nil];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelLoginPicker:)];

    // Make sure the current login host exists.
    NSUInteger index = [self indexOfCurrentLoginHost];
    if (NSNotFound == index) {
        index = 0; // revert to standard in case there is no current login host
        [self applyLoginHostAtIndex:index];
    }

    // Refresh the UI and make sure the size is correct.
    [self.tableView reloadData];
    [self makeLoginHostVisibleAtIndex:index];
    [self resizeContentForPopover];
    [super viewDidLoad];
    [self setEdgesForExtendedLayout:UIRectEdgeNone];
    
    // TODO: Remove the check once we move to iOS 9 as minimum.
    if ([self.tableView respondsToSelector:@selector(setCellLayoutMarginsFollowReadableWidth:)]) {
        self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    }
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:SFDCLoginHostListCellIdentifier];
}

- (void)viewWillAppear:(BOOL)animated {
    // We need to make sure the table is refreshed
    // and the size updated when we appear because
    // a new host could have been added by the user.
    
    [self.tableView reloadData];
    [self resizeContentForPopover];
    // style navigiation bar
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [[SFLoginViewController sharedInstance] styleNavigationBar:self.navigationController.navigationBar];
    
    [super viewWillAppear:animated];
}

#pragma mark - Action Methods
- (void)cancelLoginPicker:(id)sender {
    [self delegateDidCancelLoginHost];
}

#pragma mark - Delegate Wrapper Methods

- (void)delegateDidAddLoginHost {
    if ([self.delegate respondsToSelector:@selector(hostListViewControllerDidAddLoginHost:)]) {
        [self.delegate hostListViewControllerDidAddLoginHost:self];
    }
}

- (void)delegateDidSelectLoginHost {
    if ([self.delegate respondsToSelector:@selector(hostListViewControllerDidSelectLoginHost:)]) {
        [self.delegate hostListViewControllerDidSelectLoginHost:self];
    }
}

- (void)delegateDidCancelLoginHost {
    if ([self.delegate respondsToSelector:@selector(hostListViewControllerDidCancelLoginHost:)]) {
        [self.delegate hostListViewControllerDidCancelLoginHost:self];
    }
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[SFSDKLoginHostStorage sharedInstance] numberOfLoginHosts];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Allow the swipe and delete action to take place
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Remember if the item being deleted is the current host
        BOOL selectionDeleted = (indexPath.row == [self indexOfCurrentLoginHost]);
        
        // Delete the item
        [tableView beginUpdates];
        [[SFSDKLoginHostStorage sharedInstance] removeLoginHostAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
        [tableView endUpdates];
        
        // Update the current login host if it was deleted
        if (selectionDeleted) {
            [self applyLoginHostAtIndex:0];
            [self makeLoginHostVisibleAtIndex:0];
            [tableView reloadData];
        }
        
        // Update the size now that we've deleted an item
        [self resizeContentForPopover];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return [[[SFSDKLoginHostStorage sharedInstance] loginHostAtIndex:indexPath.row] isDeletable];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Set the checkmark when the current row is the current login host
    if ([self indexOfCurrentLoginHost] == indexPath.row) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SFDCLoginHostListCellIdentifier forIndexPath:indexPath];
    
    // Displays the name of the login host or the host itself it no name is specified
    SFSDKLoginHost *loginHost = [[SFSDKLoginHostStorage sharedInstance] loginHostAtIndex:indexPath.row];
    if ([loginHost.name length] > 0) {
        cell.textLabel.text = loginHost.name;
    } else {
        cell.textLabel.text = loginHost.host;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Apply the selected login host
    [self applyLoginHostAtIndex:indexPath.row];
    
    // Reload the table to show the correct row witih the checkmark.
    [tableView reloadData];
    
    // Notify the delegate.
    [self delegateDidSelectLoginHost];
}

#pragma mark - UINavigationControllerDelegate Methods

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if ([viewController isKindOfClass:[SFSDKLoginHostListViewController class]]) {
        [self.tableView reloadData];
        [self resizeContentForPopover];
    }
}

@end
