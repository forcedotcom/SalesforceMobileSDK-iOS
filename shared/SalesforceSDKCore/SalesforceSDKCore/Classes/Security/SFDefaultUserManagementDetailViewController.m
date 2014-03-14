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

#import "SFDefaultUserManagementDetailViewController.h"
#import "SFDefaultUserManagementViewController+Internal.h"
#import "SFUserAccountManager.h"
#import "SFUserAccount.h"
#import "SFAuthenticationManager.h"

static CGFloat const kButtonWidth = 150.0f;
static CGFloat const kButtonHeight = 40.0f;
static CGFloat const kButtonPadding = 10.0f;
static CGFloat const kControlVerticalPadding = 5.0f;

@interface SFDefaultUserManagementDetailViewController ()
{
    SFUserAccount *_user;
}

@property (nonatomic, strong) UILabel *fullNameLabel;
@property (nonatomic, strong) UILabel *userNameLabel;
@property (nonatomic, strong) UIButton *switchToUserButton;
@property (nonatomic, strong) UIButton *logoutUserButton;

- (void)layoutSubviews;
- (IBAction)switchUserButtonClicked:(id)sender;
- (IBAction)logoutUserButtonClicked:(id)sender;

@end

@implementation SFDefaultUserManagementDetailViewController

- (id)initWithUser:(SFUserAccount *)user
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _user = user;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    self.navigationItem.title = @"User Detail";
    self.view.backgroundColor = [UIColor whiteColor];
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
        [self setEdgesForExtendedLayout:UIRectEdgeNone];
    
    // fullName label
    self.fullNameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.fullNameLabel.text = _user.fullName;
    self.fullNameLabel.textAlignment = NSTextAlignmentCenter;
    self.fullNameLabel.font = [UIFont systemFontOfSize:20.0];
    [self.view addSubview:self.fullNameLabel];
    
    // userName label
    self.userNameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.userNameLabel.text = _user.userName;
    self.userNameLabel.textAlignment = NSTextAlignmentCenter;
    self.userNameLabel.font = [UIFont systemFontOfSize:16.0];
    [self.view addSubview:self.userNameLabel];
    
    // Switch to user button
    self.switchToUserButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.switchToUserButton setTitle:@"Switch to User" forState:UIControlStateNormal];
    self.switchToUserButton.enabled = ![_user isEqual:[SFUserAccountManager sharedInstance].currentUser];
    [self.switchToUserButton addTarget:self action:@selector(switchUserButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.switchToUserButton];
    
    // Logout user button
    self.logoutUserButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.logoutUserButton setTitle:@"Logout User" forState:UIControlStateNormal];
    [self.logoutUserButton addTarget:self action:@selector(logoutUserButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.logoutUserButton];
    
    [self layoutSubviews];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self layoutSubviews];
}

- (void)layoutSubviews
{
    // fullNameLabel
    [self.fullNameLabel sizeToFit];
    CGRect fullNameFrame = self.fullNameLabel.frame;
    CGFloat fullNameLabelX = CGRectGetMidX(self.view.bounds) - (self.fullNameLabel.frame.size.width / 2.0f);
    self.fullNameLabel.frame = CGRectMake(fullNameLabelX, self.view.bounds.origin.y + kControlVerticalPadding, fullNameFrame.size.width, fullNameFrame.size.height);
    
    // userNameLabel
    [self.userNameLabel sizeToFit];
    CGRect userNameFrame = self.userNameLabel.frame;
    CGFloat userNameLabelX = CGRectGetMidX(self.view.bounds) - (self.userNameLabel.frame.size.width / 2.0f);
    self.userNameLabel.frame = CGRectMake(userNameLabelX,
                                          CGRectGetMaxY(self.fullNameLabel.frame) + kControlVerticalPadding,
                                          userNameFrame.size.width,
                                          userNameFrame.size.height);
    
    // switchToUserButton
    CGFloat switchToUserWidth = kButtonWidth;
    CGFloat switchToUserHeight = kButtonHeight;
    CGFloat totalButtonX = 2.0f * kButtonWidth + kButtonPadding;
    CGFloat switchToUserX = CGRectGetMidX(self.view.bounds) - (totalButtonX / 2.0f);
    CGFloat switchToUserY = CGRectGetMaxY(self.userNameLabel.frame) + kControlVerticalPadding;
    CGRect switchToUserRect = CGRectMake(switchToUserX, switchToUserY, switchToUserWidth, switchToUserHeight);
    self.switchToUserButton.frame = switchToUserRect;
    
    // logoutUserButton
    CGFloat logoutUserWidth = kButtonWidth;
    CGFloat logoutUserHeight = kButtonHeight;
    CGFloat logoutUserX = CGRectGetMaxX(self.switchToUserButton.frame) + kButtonPadding;
    CGFloat logoutUserY = CGRectGetMaxY(self.userNameLabel.frame) + kControlVerticalPadding;
    CGRect logoutUserRect = CGRectMake(logoutUserX, logoutUserY, logoutUserWidth, logoutUserHeight);
    self.logoutUserButton.frame = logoutUserRect;
}

- (IBAction)switchUserButtonClicked:(id)sender
{
    SFDefaultUserManagementViewController *mainController = (SFDefaultUserManagementViewController *)self.navigationController;
    [mainController execCompletionBlock:SFUserManagementActionSwitchUser account:_user];
}

- (IBAction)logoutUserButtonClicked:(id)sender
{
    if ([_user isEqual:[SFUserAccountManager sharedInstance].currentUser]) {
        // Current user is a full logout and app state change.
        SFDefaultUserManagementViewController *mainController = (SFDefaultUserManagementViewController *)self.navigationController;
        [mainController execCompletionBlock:SFUserManagementActionLogoutUser account:nil];
    } else {
        // Logging out a different user than the current user.  Clear the account state and go
        // back to the user list.
        [[SFAuthenticationManager sharedManager] logoutUser:_user];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end
