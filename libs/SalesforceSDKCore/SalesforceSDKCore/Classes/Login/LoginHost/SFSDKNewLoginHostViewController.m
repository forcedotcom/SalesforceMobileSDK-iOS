/*
 SFSDKNewLoginHostViewController.m
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

#import "SFSDKNewLoginHostViewController.h"
#import "SFSDKLoginHostListViewController.h"
#import "SFSDKLoginHost.h"
#import "SFSDKTextFieldTableViewCell.h"
#import "SFSDKResourceUtils.h"

@implementation SFSDKNewLoginHostViewController

static NSString * const SFSDKNewLoginHostCellIdentifier = @"SFSDKNewLoginHostCellIdentifier";

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setEdgesForExtendedLayout:UIRectEdgeNone];
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.tableView.bounds.size.width, 0.01f)];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.tableView.bounds.size.width, 0.01f)];

    // Disable the scroll because there is enough space
    // on both the iPhone and iPad to display the two editing rows.
    self.tableView.scrollEnabled = NO;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self action:@selector(addNewServer:)];
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.title = [SFSDKResourceUtils localizedString:@"LOGIN_ADD_SERVER"];
    [self.tableView registerClass:[SFSDKTextFieldTableViewCell class] forCellReuseIdentifier:SFSDKNewLoginHostCellIdentifier];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Set the size of this view so any popover controller will resize to fit
    CGRect r = [self.tableView rectForSection:0];
    
    CGSize size = CGSizeMake(380, r.size.height);
    self.preferredContentSize = size;
    self.loginHostListViewController.preferredContentSize = size;
    
    self.preferredContentSize = size;
    
    // Make sure to also set the content size of the other view controller, otherwise the popover won't
    // resize if this view is smaller than the previous view.
    self.loginHostListViewController.preferredContentSize = size;
}

#pragma mark - Actions

/**
 * Invoked when the user taps on the done button to add the login host to the list of hosts.
 */
- (void)addNewServer:(id)sender {
    [self.loginHostListViewController addLoginHost:[SFSDKLoginHost hostWithName:self.name.text host:self.server.text deletable:YES]];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;   // One row for the host and one for the name
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SFSDKTextFieldTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SFSDKNewLoginHostCellIdentifier forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    cell.textField.delegate = self;
    cell.textField.tag = indexPath.row;

    // Create the text field for each specific row.
    if (0 == indexPath.row) {
        cell.textField.placeholder = [SFSDKResourceUtils localizedString:@"LOGIN_SERVER_URL"];
        cell.textField.keyboardType = UIKeyboardTypeURL;
        cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.server = cell.textField;
        
        [cell.textField becomeFirstResponder];
    } else {
        cell.textField.placeholder = [SFSDKResourceUtils localizedString:@"LOGIN_SERVER_NAME"];
        cell.textField.keyboardType = UIKeyboardTypeDefault;
        self.name = cell.textField;
    }
    return cell;
}

#pragma mark - Text field delegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {

    // Enable the Done button only if there is something in the URL field
    if (textField == self.server) {
        NSString *resultingString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        self.navigationItem.rightBarButtonItem.enabled = [resultingString length] > 0;
    }
    return YES;
}

@end
