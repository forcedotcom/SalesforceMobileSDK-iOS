/*
 SFSDKLoginHostListViewController.h
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

#import <UIKit/UIKit.h>
#import "SFSDKLoginHostDelegate.h"

@class SFSDKLoginHost;

/**
 * View controller that displays a list of hosts that can be used for login.
 * The user can either add a new host or select an existing host to reload the login web page.
 */
@interface SFSDKLoginHostListViewController : UITableViewController

/**
 * The object that acts as the delegate of the host list view controller.
 */
@property (nonatomic, weak) id<SFSDKLoginHostDelegate> delegate;

/**
 * Adds a new login host.
 * This method updates the underlying storage and refreshes the list of login hosts.
 * @param host The login host to be added.
 * @see showAddLoginHost for presenting a UI for the user to enter a new login host.
 */
- (void)addLoginHost:(SFSDKLoginHost *)host;

/**
 * Use this method to display a view for adding a new login host.
 * If you have used a navigation controller to present this view controller, an add button is automatically added to the right bar button item.
 * @see addLoginHost: for adding a login host programmatically without showing the UI.
 */
- (void)showAddLoginHost;

@end
