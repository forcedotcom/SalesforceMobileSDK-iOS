/*
 SFSDKPasscodeCreateController.m
 SalesforceSDKCore
 
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKPasscodeCreateController.h"
#import "SFSDKAppLockViewConfig.h"
#import "SFSecurityLockout.h"
#import "SFSDKPasscodeTextField.h"
#import "SFSDKResourceUtils.h"
#import "SFPasscodeManager+Internal.h"
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>

// Private view layout constants
static CGFloat      const kSFDefaultPadding                    = 20.0f;
static CGFloat      const kSFTopPadding                        = 64.5f;
static CGFloat      const kSFPasscodeViewHeight                = 48.0f;
static CGFloat      const kSFViewBoarderWidth                  = 1.0f;

@interface SFSDKPasscodeCreateController ()<UITextFieldDelegate>

/**
 * The State for a given passcode section of the workflow.
 */
@property (nonatomic) BOOL firstPasscodeValidated;

/**
 * The label displaying instructions for a given passcode section of the workflow.
 */
@property (nonatomic, strong) UILabel *passcodeInstructionsLabel;

/**
 * View for biometric enrollment.
 */
@property (nonatomic, strong) UIView *setUpBiometricView;

/**
 * The label title for biometric enrollment.
 */
@property (nonatomic, strong) UILabel *biometricSetupTitle;

/**
 * Passcode Text Field for custom UI.
 */
@property (strong, nonatomic) IBOutlet SFSDKPasscodeTextField *passcodeTextView;

/**
 * Keeps a copy of the initial passcode of the passcode creation process.
 */
@property (nonatomic, copy) NSString *initialPasscode;

@end

@implementation SFSDKPasscodeCreateController
@synthesize viewConfig = _viewConfig;

- (instancetype)initWithViewConfig:(SFSDKAppLockViewConfig *)config
{
    self = [super init];
    if (self) {
        _viewConfig = config;
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - View lifecycle

- (void)loadView
{
    [super loadView];
    self.passcodeTextView = [[SFSDKPasscodeTextField alloc] initWithFrame:CGRectZero andViewConfig:self.viewConfig];
    self.passcodeTextView.delegate = self;
    self.passcodeTextView.layer.borderWidth = kSFViewBoarderWidth;
    self.passcodeTextView.accessibilityIdentifier = @"passcodeTextField";
    self.passcodeTextView.accessibilityLabel = [SFSDKResourceUtils localizedString:@"accessibilityPasscodeFieldLabel"];
    self.passcodeTextView.accessibilityHint = [[NSString alloc] initWithFormat:[SFSDKResourceUtils localizedString:@"accessibilityPasscodeLengthHint"], self.viewConfig.passcodeLength];
    self.passcodeTextView.secureTextEntry = YES;
    self.passcodeTextView.isAccessibilityElement = YES;
    [self.passcodeTextView clearPasscode];
    [self.view addSubview:self.passcodeTextView];
    
    self.passcodeInstructionsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.passcodeInstructionsLabel.backgroundColor = [UIColor clearColor];
    self.passcodeInstructionsLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.passcodeInstructionsLabel.numberOfLines = 0;
    self.passcodeInstructionsLabel.textColor = self.viewConfig.instructionTextColor;
    self.passcodeInstructionsLabel.textAlignment = NSTextAlignmentCenter;
    self.passcodeInstructionsLabel.font = self.viewConfig.instructionFont;
    self.passcodeInstructionsLabel.accessibilityIdentifier = @"instructionLabel";
    [self.view addSubview:self.passcodeInstructionsLabel];
}

- (void)setupNavigationBar {
    self.navigationController.navigationBar.backgroundColor = self.viewConfig.navBarColor;
    self.navigationController.navigationBar.tintColor = self.viewConfig.navBarColor;
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.navigationBar.titleTextAttributes =
        @{NSForegroundColorAttributeName : self.viewConfig.navBarTextColor,
                     NSFontAttributeName : self.viewConfig.navBarFont};
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = self.viewConfig.backgroundColor;
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        [self setEdgesForExtendedLayout:UIRectEdgeNone];
    }
    
    [self layoutSubviews];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSString *instructions = self.updateMode ? @"passcodeChangeInstructions" : @"passcodeCreateInstructions";
    self.passcodeInstructionsLabel.text = [SFSDKResourceUtils localizedString:instructions];
    [self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"createPasscodeNavTitle"]];
    [self.passcodeInstructionsLabel setFont:self.viewConfig.instructionFont];
    if (UIAccessibilityIsVoiceOverRunning()) {
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.passcodeInstructionsLabel);
    }
    [self.passcodeTextView refreshView];
}

- (void)viewWillLayoutSubviews
{
    [self layoutSubviews];
    [super viewWillLayoutSubviews];
}

- (void)layoutSubviews {
    [self layoutPasscodeCreateView];
}

- (void)layoutPasscodeCreateView
{
    [self.passcodeInstructionsLabel sizeToFit];
    CGFloat xIns = CGRectGetMinX(self.view.bounds) + kSFDefaultPadding;
    CGFloat yIns = CGRectGetMinY(self.view.bounds) + kSFTopPadding;
    CGFloat wIns = self.view.bounds.size.width - (2 * kSFDefaultPadding);
    CGFloat hIns = self.passcodeInstructionsLabel.bounds.size.height;
    self.passcodeInstructionsLabel.frame = CGRectMake(xIns, yIns, wIns, hIns);
    
    CGFloat xView = (0 - kSFViewBoarderWidth);
    CGFloat yView = yIns + hIns + (kSFDefaultPadding / 2.0);
    CGFloat wView = self.view.bounds.size.width + (kSFViewBoarderWidth * 2);
    CGFloat hView = kSFPasscodeViewHeight + (kSFViewBoarderWidth * 2);
    self.passcodeTextView.frame = CGRectMake(xView, yView, wView, hView);
    self.passcodeTextView.layer.frame = CGRectMake(xView, yView, wView, hView);
    [self.passcodeTextView refreshView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.updateMode) {
       self.passcodeInstructionsLabel.text = [SFSDKResourceUtils localizedString:@"passcodeCreateInstructions"];
    } else {
       self.passcodeInstructionsLabel.text = [SFSDKResourceUtils localizedString:@"passcodeChangeInstructions"];
    }
    [self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"createPasscodeNavTitle"]];
    [self.passcodeInstructionsLabel setFont:self.viewConfig.instructionFont];
    [self.passcodeInstructionsLabel setHidden:NO];
    [self.passcodeTextView setHidden:NO];
    [self.passcodeTextView refreshView];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)rString
{
    // This fixes deleting if VoiceOver is on.
    if (UIAccessibilityIsVoiceOverRunning() && [rString isEqualToString:@""]) {
        [self.passcodeTextView deleteBackward];
    }
    // Check if input is an actual int
    if (rString.intValue == 0 && ![rString isEqualToString:@"0"]) {
        return NO;
    }
    
   if (self.passcodeTextView.passcodeInput.length < self.viewConfig.passcodeLength) {
        [self.passcodeTextView.passcodeInput appendString:rString];
    }
    
    if ([self.passcodeTextView.passcodeInput length] == self.viewConfig.passcodeLength) {
        if (self.firstPasscodeValidated) {
            if ([self.passcodeTextView.passcodeInput isEqualToString:self.initialPasscode] ) {
                if ([self.passcodeTextView isFirstResponder]) {
                    [self.passcodeTextView resignFirstResponder];
                }
                [self.createDelegate passcodeCreated:self.passcodeTextView.passcodeInput updateMode:self.updateMode];
            } else {
                [self.passcodeTextView clearPasscode];
                [self.passcodeTextView refreshView];
                [self.passcodeInstructionsLabel setText:[SFSDKResourceUtils localizedString:@"passcodesDoNotMatchError"]];
                if (UIAccessibilityIsVoiceOverRunning()) {
                    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.passcodeInstructionsLabel.text);
                }
                self.firstPasscodeValidated = NO;
                return NO; // return no for accessibility keyboard noise
            }
        } else {
            self.initialPasscode = [[NSString alloc] initWithString:self.passcodeTextView.passcodeInput];
            [self.passcodeTextView clearPasscode];
            [self.passcodeTextView refreshView];
            self.firstPasscodeValidated = YES;
            
            //Change labels for confirm passcode
            [self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"verifyPasscodeNavTitle"]];
            [self.passcodeInstructionsLabel setText:[SFSDKResourceUtils localizedString:@"passcodeConfirmInstructions"]];
            if (UIAccessibilityIsVoiceOverRunning()) {
                UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.passcodeInstructionsLabel.text);
            }
            [self.passcodeInstructionsLabel setFont:self.viewConfig.instructionFont];
            [self layoutSubviews];
        }
    } else {
        [self.passcodeTextView refreshView];
    }
    
    return UIAccessibilityIsVoiceOverRunning();
}

@end
