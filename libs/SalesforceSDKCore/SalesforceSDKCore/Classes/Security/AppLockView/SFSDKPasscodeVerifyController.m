/*
 SFSDKPasscodeVerifyController.m
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

#import "SFSDKPasscodeVerifyController.h"
#import "SFSecurityLockout.h"
#import "SFSDKPasscodeTextField.h"
#import "SFSDKResourceUtils.h"
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import "SFSecurityLockout+Internal.h"

// Private view layout constants
static NSUInteger   const kSFMaxPasscodeLength                 = 8;
static CGFloat      const kSFDefaultPadding                    = 20.0f;
static CGFloat      const kSFTopPadding                        = 64.5f;
static CGFloat      const kSFButtonCornerRadius                = 4.0f;
static CGFloat      const kSFButtonHeight                      = 47.0f;
static CGFloat      const kSFVerifyButtonWidth                 = 143.0f;
static CGFloat      const kSFPasscodeViewHeight                = 48.0f;
static CGFloat      const kSFViewBorderWidth                   = 0.5f;
// Public constants
NSString * const kSFRemainingAttemptsKey = @"remainingAttempts";
NSUInteger const kSFMaxNumberofAttempts = 10;

@interface SFSDKPasscodeVerifyController ()<UITextFieldDelegate>

/**
 * The 'Verify Passcode' button.
 * Button used for user to submit passcode if length is unknown.
 */
@property (nonatomic, strong) UIButton *verifyPasscodeButton;

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
 * The 'Log out' button
 */
@property (nonatomic, strong) UIBarButtonItem *logoutButton;

/**
 * Passcode Text Field for custom UI.
 */
@property (strong, nonatomic) IBOutlet SFSDKPasscodeTextField *passcodeTextView;

/**
 * Keeps a copy of the initial passcode of the passcode creation process.
 */
@property (nonatomic, copy) NSString *initialPasscode;

@end

@implementation SFSDKPasscodeVerifyController
@synthesize viewConfig = _viewConfig;

- (instancetype)initWithViewConfig:(SFSDKAppLockViewConfig *)config
{
    self = [super init];
    if (self) {
        _viewConfig = config;
        
        if (self.remainingAttempts == 0) {
            [self resetRemainingAttempts];
        }
        self.passcodeLengthKnown = ([SFSecurityLockout passcodeLength] != 0);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layoutVerifyButton:) name:UIKeyboardDidShowNotification object:nil];
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
    self.passcodeTextView.layer.borderWidth = kSFViewBorderWidth;
    self.passcodeTextView.accessibilityIdentifier = @"passcodeTextField";
    self.passcodeTextView.accessibilityLabel = [SFSDKResourceUtils localizedString:@"accessibilityPasscodeFieldLabel"];
    self.passcodeTextView.secureTextEntry = YES;
    self.passcodeTextView.isAccessibilityElement = YES;
    if (self.passcodeLengthKnown) {
        self.passcodeTextView.accessibilityHint = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"accessibilityPasscodeLengthHint"], [SFSecurityLockout passcodeLength]];
    }
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
    
    self.verifyPasscodeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.verifyPasscodeButton setTitle:[SFSDKResourceUtils localizedString:@"verifyPasscodeButtontext"] forState:UIControlStateNormal];
    [self.verifyPasscodeButton.titleLabel setTextAlignment:NSTextAlignmentCenter];
    self.verifyPasscodeButton.titleLabel.font = self.viewConfig.buttonFont;
    self.verifyPasscodeButton.backgroundColor = self.viewConfig.primaryColor;
    [self.verifyPasscodeButton setTitleColor:self.viewConfig.secondaryColor forState:UIControlStateNormal];
    [self.verifyPasscodeButton addTarget:self action:@selector(verifyPasscode) forControlEvents:UIControlEventTouchUpInside];
    self.verifyPasscodeButton.accessibilityIdentifier = @"verifyPasscodeButton";
    self.verifyPasscodeButton.layer.cornerRadius = kSFButtonCornerRadius;
    [self.view addSubview:self.verifyPasscodeButton];
    
    self.logoutButton = [[UIBarButtonItem alloc] initWithTitle:[SFSDKResourceUtils localizedString:@"logoutButtonTitle"] style:UIBarButtonItemStylePlain target:self action:@selector(validatePasscodeFailed)];
    self.logoutButton.tintColor = [UIColor clearColor];
    self.logoutButton.accessibilityLabel = [SFSDKResourceUtils localizedString:@"logoutButtonTitle"];
    self.logoutButton.accessibilityIdentifier = @"logoutButton";
    [self.logoutButton setEnabled:NO];
    [self.navigationItem.leftBarButtonItem setTintColor:[UIColor clearColor]];
    [self.navigationItem setLeftBarButtonItem:self.logoutButton];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = self.viewConfig.backgroundColor;
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        [self setEdgesForExtendedLayout:UIRectEdgeNone];
    }
    
    [self layoutSubviews];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"verifyPasscodeNavTitle"]];
    [self.passcodeInstructionsLabel setFont:self.viewConfig.instructionFont];
    [self accessibilityAnnounce:[self.passcodeInstructionsLabel text]];
    [self layoutSubviews];
    [self.passcodeTextView refreshView];
}

- (void)viewWillLayoutSubviews
{
    [self layoutSubviews];
    [super viewWillLayoutSubviews];
}

- (void)layoutSubviews
{
    [self layoutPasscodeVerifyView];
}

- (void)layoutPasscodeVerifyView
{
    [self.passcodeInstructionsLabel sizeToFit];
    CGFloat xIns = CGRectGetMinX(self.view.bounds) + kSFDefaultPadding;
    CGFloat yIns = CGRectGetMinY(self.view.bounds) + kSFTopPadding;
    CGFloat wIns = self.view.bounds.size.width - (2 * kSFDefaultPadding);
    CGFloat hIns = self.passcodeInstructionsLabel.bounds.size.height;
    self.passcodeInstructionsLabel.frame = CGRectMake(xIns, yIns, wIns, hIns);
    
    CGFloat xView = (0 - kSFViewBorderWidth);
    CGFloat yView = yIns + hIns + (kSFDefaultPadding / 2.0);
    CGFloat wView = self.view.bounds.size.width + (kSFViewBorderWidth * 2);
    CGFloat hView = kSFPasscodeViewHeight + (kSFViewBorderWidth * 2);
    self.passcodeTextView.frame = CGRectMake(xView, yView, wView, hView);
    self.passcodeTextView.layer.frame = CGRectMake(xView, yView, wView, hView);
    [self.passcodeTextView refreshView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self showVerifyPasscode];
    [self.passcodeTextView refreshView];
}

- (void)showVerifyPasscode
{
    [self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"verifyPasscodeNavTitle"]];
    [self.passcodeInstructionsLabel setText:[SFSDKResourceUtils localizedString:@"passcodeVerifyInstructions"]];
    [self.passcodeInstructionsLabel setFont:self.viewConfig.instructionFont];
    [self.passcodeInstructionsLabel setHidden:NO];
    [self layoutSubviews];
    [self.passcodeTextView setHidden:NO];
    [self.verifyPasscodeButton setHidden:self.passcodeLengthKnown];
    [self.passcodeTextView refreshView];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)rString
{
    NSUInteger length = (self.passcodeLengthKnown) ? [SFSecurityLockout passcodeLength] : kSFMaxPasscodeLength;
    
    // This fixes deleting if VoiceOver is on.
    if (UIAccessibilityIsVoiceOverRunning() && [rString isEqualToString:@""]) {
        [self.passcodeTextView deleteBackward];
    }
    // Check if input is an actual int
    if (rString.intValue == 0 && ![rString isEqualToString:@"0"]) {
        return NO;
    }
    
    // This prevents too many characters from being entered
    if (self.passcodeTextView.passcodeInput.length < length) {
        [self.passcodeTextView.passcodeInput appendString:rString];
    }
    
    if (self.passcodeLengthKnown && [self.passcodeTextView.passcodeInput length] == length) {
        NSInteger beforeAttemps = [self remainingAttempts];
        [self verifyPasscode];
        // For accessibility: Check for success or failure of verify passcode and return accordingly.
        // Return value determines the success or failure typing tone placed for voiceover.
        return [self remainingAttempts] >= beforeAttemps;
    } else {
        [self.passcodeTextView refreshView];
    }
    
    return UIAccessibilityIsVoiceOverRunning();
}

- (void)layoutVerifyButton:(NSNotification *)notification
{
    CGSize keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    CGFloat xButton = CGRectGetMaxX(self.view.bounds) - kSFVerifyButtonWidth - kSFDefaultPadding;
    CGFloat yButton = CGRectGetMaxY(self.view.bounds) - keyboardSize.height - kSFButtonHeight - kSFDefaultPadding;
    self.verifyPasscodeButton.frame = CGRectMake(xButton, yButton, kSFVerifyButtonWidth, kSFButtonHeight);
}

- (NSInteger)remainingAttempts
{
    return [[NSUserDefaults msdkUserDefaults] integerForKey:kSFRemainingAttemptsKey];
}

- (void)setRemainingAttempts:(NSInteger)remainingAttempts
{
    [[NSUserDefaults msdkUserDefaults] setInteger:remainingAttempts forKey:kSFRemainingAttemptsKey];
    [[NSUserDefaults msdkUserDefaults] synchronize];
}

- (void)resetRemainingAttempts
{
    [self setRemainingAttempts:(_viewConfig.maxNumberOfAttempts) ? _viewConfig.maxNumberOfAttempts : kSFMaxNumberofAttempts];
}

- (void)verifyPasscode
{
    if ([SFSecurityLockout verifyPasscode:self.passcodeTextView.passcodeInput]) {
        if ([self.passcodeTextView isFirstResponder]) {
            [self.passcodeTextView resignFirstResponder];
        }
        [self validatePasscodeConfirmed:self.passcodeTextView.passcodeInput];
    } else {
        if ([self decrementPasscodeAttempts]) {
            [self.passcodeTextView clearPasscode];
            [self.passcodeTextView refreshView];
            
            NSString *passcodeFailedString = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"passcodeInvalidError"], self.remainingAttempts];
            [self.passcodeInstructionsLabel setText:passcodeFailedString];
            [self accessibilityAnnounce:passcodeFailedString];
            [self layoutSubviews];
            
            if (![self.navigationItem.leftBarButtonItem isEnabled]) {
                [self.navigationItem.leftBarButtonItem setEnabled:YES];
                [self.navigationItem.leftBarButtonItem setTintColor:self.viewConfig.logoutButtonColor];
            }
            [self.view setNeedsDisplay];
        }
    }
}
- (BOOL)decrementPasscodeAttempts
{
    [self setRemainingAttempts:(self.remainingAttempts - 1)];
    BOOL morePasscodeAttempts = (self.remainingAttempts > 0);
    if (!morePasscodeAttempts) {
        [self validatePasscodeFailed];
    }
    
    return morePasscodeAttempts;
}

- (void)validatePasscodeConfirmed:(NSString *)validPasscode
{
    [self resetRemainingAttempts];
    [self.verifyDelegate passcodeVerified];
    [self accessibilityAnnounce:[SFSDKResourceUtils localizedString:@"accessibilityUnlockAnnouncement"]] ;
}

- (void)validatePasscodeFailed
{
    [self resetRemainingAttempts];
    [self.verifyDelegate passcodeFailed];
    [self accessibilityAnnounce:[SFSDKResourceUtils localizedString:@"accessibilityLoggedOutAnnouncement"]] ;
}

- (void)accessibilityAnnounce:(NSString *)text
{
    if (UIAccessibilityIsVoiceOverRunning()) {
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, text);
    }
}
@end
