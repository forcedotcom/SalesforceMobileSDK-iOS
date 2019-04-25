/*
 SFSDKBiometricViewController.m
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

#import "SFSDKBiometricViewController+Internal.h"
#import "SFSDKAppLockViewConfig.h"
#import "SFSDKResourceUtils.h"
#import "SFSDKWindowManager.h"
#import <LocalAuthentication/LocalAuthentication.h>

static CGFloat      const kSFFaceIdIconWidth                   = 36.0f;
static CGFloat      const kSFTouchIdIconWidth                  = 42.0f;
static CGFloat      const kSFIconCircleDiameter                = 80.0f;
static CGFloat      const kSFFaceIconPadding                   = 22.0f;
static CGFloat      const kSFTouchIconPadding                  = 19.0f;
static CGFloat      const kSFTitleTextLabelHeight              = 20.0f;
static CGFloat      const kSFButtonCornerRadius                = 4.0f;
static CGFloat      const kSFViewBoarderWidth                  = 1.0f;
static CGFloat      const kSFTopPadding                        = 64.5f;
static CGFloat      const kSFBioDefaultPadding                 = 20.0f;
static CGFloat      const kSFBioButtonHeight                   = 47.0f;
static CGFloat      const kSFBioTopPadding                     = 64.5f;
static CGFloat      const kSFBioViewBorderWidth                = 1.0f;

@implementation SFSDKBiometricViewController

- (instancetype)initWithViewConfig:(SFSDKAppLockViewConfig *)config {
    
    self = [super init];
    if (self) {
        _viewConfig = config;
    }
    return self;
}

- (void)loadView {
    [super loadView];
    // Biometric Setup View
    self.iconView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kSFIconCircleDiameter, kSFIconCircleDiameter)];
    self.iconView.backgroundColor = [UIColor clearColor];
    self.iconView.accessibilityIdentifier = @"iconView";
    
    CAShapeLayer *iconCircle = [CAShapeLayer layer];
    [iconCircle setPath:[UIBezierPath bezierPathWithRoundedRect:self.iconView.bounds cornerRadius:kSFIconCircleDiameter].CGPath];
    iconCircle.strokeColor = self.viewConfig.borderColor.CGColor;
    iconCircle.borderColor = self.viewConfig.borderColor.CGColor;
    iconCircle.fillColor = self.viewConfig.secondaryColor.CGColor;
    iconCircle.borderWidth = 2.0f;
    [[self.iconView layer]  addSublayer:iconCircle];
    
    UIImage *touchIdImageTmp = self.viewConfig.touchIdImage;
    self.touchIdImage = [[UIImageView alloc] initWithImage:touchIdImageTmp];
    UIImage *faceIdImageTmp = self.viewConfig.faceIdImage;
    self.faceIdImage = [[UIImageView alloc] initWithImage:faceIdImageTmp];
    self.touchIdImage.accessibilityIdentifier = @"touchIdImage";
    self.faceIdImage.accessibilityIdentifier = @"faceIdImage";
    [self.touchIdImage setHidden:YES];
    [self.faceIdImage setHidden:YES];
    [self.iconView addSubview:self.touchIdImage];
    [self.iconView addSubview:self.faceIdImage];
    [self.view addSubview:self.iconView];
    
    self.setUpBiometricView = [[UIView alloc] initWithFrame:CGRectZero];
    self.setUpBiometricView.backgroundColor = self.viewConfig.secondaryColor;
    self.setUpBiometricView.layer.borderColor = self.viewConfig.borderColor.CGColor;
    self.setUpBiometricView.layer.borderWidth = kSFViewBoarderWidth;
    self.setUpBiometricView.accessibilityIdentifier = @"biometricSetupView";
    [self.view addSubview:self.setUpBiometricView];
    
    // Biometric Instructions
    self.biometricSetupTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    self.biometricSetupTitle.backgroundColor = [UIColor clearColor];
    self.biometricSetupTitle.textColor = self.viewConfig.titleTextColor;
    self.biometricSetupTitle.textAlignment = NSTextAlignmentLeft;
    self.biometricSetupTitle.font = self.viewConfig.titleFont;
    self.biometricSetupTitle.accessibilityIdentifier = @"biometricSetupTitle";
    [self.setUpBiometricView addSubview:self.biometricSetupTitle];
    
    self.biometricInstructionsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    [self.biometricInstructionsLabel setBackgroundColor:[UIColor clearColor]];
    self.biometricInstructionsLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.biometricInstructionsLabel.numberOfLines = 0;
    self.biometricInstructionsLabel.textColor = self.viewConfig.instructionTextColor;
    self.biometricInstructionsLabel.textAlignment = NSTextAlignmentLeft;
    self.biometricInstructionsLabel.font = self.viewConfig.instructionFont;
    self.biometricInstructionsLabel.accessibilityIdentifier = @"biometricSetupInstructions";
    [self.setUpBiometricView addSubview:self.biometricInstructionsLabel];
    
    // Biometric enable buttons
    self.enableBiometricButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.enableBiometricButton setTitle:[SFSDKResourceUtils localizedString:@"biometricEnableButtonText"] forState:UIControlStateNormal];
    self.enableBiometricButton.backgroundColor = self.viewConfig.primaryColor;
    self.enableBiometricButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.enableBiometricButton.titleLabel.font = self.viewConfig.buttonFont;
    [self.enableBiometricButton setTitleColor:self.viewConfig.secondaryColor forState:UIControlStateNormal];
    [self.enableBiometricButton addTarget:self action:@selector(showBiometric) forControlEvents:UIControlEventTouchUpInside];
    self.enableBiometricButton.layer.cornerRadius = kSFButtonCornerRadius;
    self.enableBiometricButton.accessibilityLabel = [SFSDKResourceUtils localizedString:@"biometricEnableButtonText"];
    self.enableBiometricButton.accessibilityIdentifier = @"enableBiometricButton";
    [self.setUpBiometricView addSubview:self.enableBiometricButton];
    
    self.cancelBiometricButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.cancelBiometricButton setTitle:[SFSDKResourceUtils localizedString:@"biometricCancelButtonText"] forState:UIControlStateNormal];
    self.cancelBiometricButton.backgroundColor = self.viewConfig.secondaryColor;
    self.cancelBiometricButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.cancelBiometricButton.titleLabel.font = self.viewConfig.buttonFont;
    [self.cancelBiometricButton setTitleColor:self.viewConfig.primaryColor forState:UIControlStateNormal];
    [self.cancelBiometricButton addTarget:self action:@selector(userDenyBiometricEnablement) forControlEvents:UIControlEventTouchUpInside];
    self.cancelBiometricButton.layer.borderColor = self.viewConfig.borderColor.CGColor;
    self.cancelBiometricButton.layer.borderWidth = 1.0f;
    self.cancelBiometricButton.layer.cornerRadius = kSFButtonCornerRadius;
    self.cancelBiometricButton.accessibilityLabel = [SFSDKResourceUtils localizedString:@"biometricCancelButtonText"];
    self.cancelBiometricButton.accessibilityIdentifier = @"cancelBiometricButton";
    [self.setUpBiometricView addSubview:self.cancelBiometricButton];
}

- (void)viewWillLayoutSubviews
{
    [self layoutSetupBiometric];
    [super viewWillLayoutSubviews];
}

- (void)layoutSetupBiometric
{
    CGFloat xIcon = (self.view.bounds.size.width - kSFIconCircleDiameter) / 2;
    self.iconView.frame = CGRectMake(xIcon, kSFTopPadding, kSFIconCircleDiameter, kSFIconCircleDiameter);
    self.touchIdImage.frame = CGRectMake(kSFTouchIconPadding, kSFTouchIconPadding, kSFTouchIdIconWidth, kSFTouchIdIconWidth);
    self.faceIdImage.frame = CGRectMake(kSFFaceIconPadding, kSFFaceIconPadding, kSFFaceIdIconWidth, kSFFaceIdIconWidth);
    
    CGFloat xTitle = CGRectGetMinX(self.setUpBiometricView.bounds) + kSFBioDefaultPadding;
    CGFloat yTitle = CGRectGetMinY(self.setUpBiometricView.bounds) + kSFBioDefaultPadding;
    CGFloat wTitle = self.view.bounds.size.width - (2 * kSFBioDefaultPadding);
    CGFloat hTitle = kSFTitleTextLabelHeight;
    self.biometricSetupTitle.frame = CGRectMake(xTitle, yTitle, wTitle, hTitle);
    
    [self.biometricInstructionsLabel sizeToFit];
    CGFloat xIns = CGRectGetMinX(self.setUpBiometricView.bounds) + kSFBioDefaultPadding;
    CGFloat yIns = CGRectGetMinY(self.setUpBiometricView.bounds) + kSFBioDefaultPadding + hTitle + (kSFBioDefaultPadding / 2.0);
    CGFloat wIns = self.view.bounds.size.width - (2 * kSFBioDefaultPadding);
    CGFloat hIns = self.biometricInstructionsLabel.bounds.size.height;
    self.biometricInstructionsLabel.frame = CGRectMake(xIns, yIns, wIns, hIns);
    
    CGFloat xCancelButton = CGRectGetMinX(self.setUpBiometricView.bounds) + kSFBioDefaultPadding;
    CGFloat yCancelButton = CGRectGetMinY(self.setUpBiometricView.bounds) + hTitle + hIns + (kSFBioDefaultPadding * 2.5);
    CGFloat wCancelButton = (self.view.bounds.size.width - (3 * kSFBioDefaultPadding)) / 2;
    CGFloat hCancelButton = kSFBioButtonHeight;
    self.cancelBiometricButton.frame = CGRectMake(xCancelButton, yCancelButton, wCancelButton, hCancelButton);
    
    CGFloat xEnableButton = CGRectGetMinX(self.setUpBiometricView.bounds) + (kSFBioDefaultPadding * 2) + wCancelButton;
    CGFloat yEnableButton = CGRectGetMinY(self.setUpBiometricView.bounds) + hTitle + hIns + (kSFBioDefaultPadding * 2.5);
    CGFloat wEnableButton = (self.view.bounds.size.width - (3 * kSFBioDefaultPadding)) / 2;
    CGFloat hEnableButton = kSFBioButtonHeight;
    self.enableBiometricButton.frame = CGRectMake(xEnableButton, yEnableButton, wEnableButton, hEnableButton);
    
    CGFloat xSetup = (0 - kSFViewBoarderWidth);
    CGFloat ySetup = (kSFBioTopPadding * 2) + kSFIconCircleDiameter;
    CGFloat wSetup = self.view.bounds.size.width + (kSFBioViewBorderWidth * 2);
    CGFloat hSetup = (kSFBioDefaultPadding * 3.5) + hTitle + hIns + hCancelButton;
    self.setUpBiometricView.frame = CGRectMake(xSetup, ySetup, wSetup, hSetup);
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = self.viewConfig.backgroundColor;
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        [self setEdgesForExtendedLayout:UIRectEdgeNone];
    }
    [self layoutSetupBiometric];
    self.navigationItem.hidesBackButton = YES;
    
    if (self.verificationMode) {
         [self showBiometric];
    } else {
        [self showBiometricSetup];
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.biometricSetupTitle);
    }
}

// private methods
- (void)showBiometric
{
    LAContext *context = [[LAContext alloc] init];
    __weak typeof (self) weakSelf = self;
    
    if (self.verificationMode) {
        [context setLocalizedCancelTitle:[SFSDKResourceUtils localizedString:@"biometricFallbackActionLabel"]];
        [self hideAll];
    }
    
    [context setLocalizedFallbackTitle:@""];
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:[SFSDKResourceUtils localizedString:@"biometricReason"] reply:^(BOOL success, NSError *authenticationError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __weak typeof (weakSelf) strongSelf = weakSelf;
            if (success) {
                [strongSelf.biometricResponseDelgate biometricUnlockSucceeded:strongSelf.verificationMode];
            } else {
                [strongSelf.biometricResponseDelgate biometricUnlockFailed:strongSelf.verificationMode];
            }
        });
    }];
}

- (void)userDenyBiometricEnablement
{
    [self.biometricResponseDelgate biometricUnlockFailed:self.verificationMode];
}

- (void)showBiometricSetup
{
    LAContext *context = [[LAContext alloc] init];
    // Need to evaluate context to for biometricType to be populated
    [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil];
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    NSString *bioInstructions = nil;
    
    switch ([context biometryType]) {
        case LABiometryTypeFaceID:
            [self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"biometricEnableFaceIdNavTitle"]];
            [self.biometricSetupTitle setText:[SFSDKResourceUtils localizedString:@"biometricEnableTitleFaceId"]];
            bioInstructions = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"biometricEnableInstructionsFaceId"], appName];
            [self.biometricInstructionsLabel setText:bioInstructions];
            [self.faceIdImage setHidden:NO];
            break;
        case LABiometryTypeTouchID:
            [self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"biometricEnableTouchIdNavTitle"]];
            [self.biometricSetupTitle setText:[SFSDKResourceUtils localizedString:@"biometricEnableTitleTouchId"]];
            bioInstructions = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"biometricEnableInstructionsTouchId"], appName];
            [self.biometricInstructionsLabel setText:bioInstructions];
            [self.touchIdImage setHidden:NO];
            break;
        case LABiometryTypeNone:
            [SFSDKCoreLogger d:[self class] format:@"Biometric View should never show with LABiometricTypeNone.  Device does not have biometric enabled."];
            break;
    }
}

- (void)hideAll {
    [self.biometricSetupTitle setHidden:YES];
    [self.biometricInstructionsLabel setHidden:YES];
    [self.cancelBiometricButton setHidden:YES];
    [self.enableBiometricButton setHidden:YES];
    [self.setUpBiometricView setHidden:YES];
    [self.iconView setHidden:YES];
    [self.faceIdImage setHidden:YES];
    [self.touchIdImage setHidden:YES];
}
@end

