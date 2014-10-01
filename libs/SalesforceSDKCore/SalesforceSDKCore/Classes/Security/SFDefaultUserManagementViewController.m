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

#import "SFDefaultUserManagementViewController+Internal.h"
#import "SFDefaultUserManagementListViewController.h"
#import "SFAuthenticationManager.h"

@implementation SFDefaultUserManagementViewController

- (id)initWithCompletionBlock:(SFUserManagementCompletionBlock)completionBlock
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.completionBlock = completionBlock;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	SFDefaultUserManagementListViewController *rvc = [[SFDefaultUserManagementListViewController alloc] initWithStyle:UITableViewStylePlain];
    [self pushViewController:rvc animated:NO];
}

// Don't take action before the user inteface is cleared.  Allow the consumer to drive the
// flow of the app, avoid async state issues, etc.
- (void)viewDidDisappear:(BOOL)animated
{
    switch (self.action) {
        case SFUserManagementActionLogoutUser:
            // If it's in this controller, it's logging out the current user.
            [self actionLogout];
            break;
        case SFUserManagementActionSwitchUser:
            [self actionSwitchUser:self.actionAccount];
            break;
        case SFUserManagementActionCreateNewUser:
            [self actionCreateNewUser];
            break;
        case SFUserManagementActionCancel:
        default:
            break;
    }
    [super viewDidDisappear:animated];
}

- (void)actionLogout
{
    // If we got here, logging out the current user is implied.
    [[SFAuthenticationManager sharedManager] logout];
}

- (void)actionSwitchUser:(SFUserAccount *)user
{
    [[SFUserAccountManager sharedInstance] switchToUser:user];
}

- (void)actionCreateNewUser
{
    [[SFUserAccountManager sharedInstance] switchToNewUser];
}

- (void)execCompletionBlock:(SFUserManagementAction)action account:(SFUserAccount *)actionAccount
{
    self.action = action;
    self.actionAccount = actionAccount;
    if (self.completionBlock) {
        self.completionBlock(action);
    }
}

@end
