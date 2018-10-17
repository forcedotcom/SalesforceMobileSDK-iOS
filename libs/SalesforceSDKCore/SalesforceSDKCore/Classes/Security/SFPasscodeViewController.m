/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFPasscodeViewController.h"
#import "SFPasscodeManager.h"
#import "SFSDKResourceUtils.h"
#import "UIColor+SFSDKPasscodeView.h"
#import "SFSDKPasscodeTextField.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "SFKeychainItemWrapper.h"
#import "SFSDKWindowManager.h"

// Private view layout constants
static NSUInteger   const kMaxPasscodeLength                 = 8;
static CGFloat      const kDefaultPadding                    = 20.0f;
static CGFloat      const kIconCircleDiameter                = 80.0f;
static CGFloat      const kTopPadding                        = 64.5f;
static CGFloat      const kFaceIdIconWidth                   = 36.0f;
static CGFloat      const kTouchIdIconWidth                  = 42.0f;
static CGFloat      const kTouchIconPadding                  = 19.0f;
static CGFloat      const kFaceIconPadding                   = 22.0f;
static CGFloat      const kTitleTextLabelHeight              = 20.0f;
static NSString *   const kTitleLabelFontName                = @"SFUIText-Bold";
static NSString *   const kButtonFontName                    = @"SFUIText-Bold";
static CGFloat      const kTitleTextLabelFontSize            = 18.0f;
static CGFloat      const kButtonLabelFontSize               = 14.0f;
static CGFloat      const kPassInstructionTextLabelHeight    = 20.0f;
static CGFloat      const kBioInstructionTextLabelHeight     = 40.0f;
static NSString *   const kInstructionLabelFontName          = @"SFUIText-Medium";
static CGFloat      const kInstructionTextLabelFontSize      = 14.0f;
static CGFloat      const kButtonCornerRadius                = 4.0f;
static CGFloat      const kBiometricInstructionsLabelHeight  = 36.0f;
static CGFloat      const kButtonHeight                      = 47.0f;
static CGFloat      const kVerifyButtonWidth                 = 143.0f;
static CGFloat      const kSetupViewHeight                   = 173.0f;
static CGFloat      const kPasscodeViewHeight                = 48.0;
static CGFloat      const kPasscodeCircleDiameter            = 24.f;
static CGFloat      const kPasscodeCircleSpacing             = 16.f;
//static CGFloat      const kInstructionLabelHeight            = 18.f;
static CGFloat      const kInstructionLabelHeight            = 40.f;
static CGFloat      const kInstructionFieldFontSize          = 14.f;

@interface SFPasscodeViewController() <UITextFieldDelegate> {
    BOOL _firstPasscodeValidated;
    BOOL _PasscodeFallback;
}

/**
 * Passcode Text Field for custom UI.
 */
@property (strong, nonatomic) IBOutlet SFSDKPasscodeTextField *passcodeTextView;

/**
 * Known length of the user's passcode.  Zero if unknown.
 */
@property (nonatomic) int passcodeLength;

/**
 * Whether the device has biometric and the org allows it.
 */
@property (nonatomic) BOOL biometricAllowed;

/**
 * Image for Touch Id enrollment.
 */
@property (nonatomic, strong) UIImageView *touchIdImage;

/**
 * Image for Face Id enrollment.
 */
@property (nonatomic, strong) UIImageView *faceIdImage;

/**
 * Icon view for biometric enrollment.
 */
@property (nonatomic, strong) UIView *iconView;

/**
 * View for biometric enrollment.
 */
@property (nonatomic, strong) UIView *setUpBiometricView;

/**
 * The label title for biometric enrollment.
 */
@property (nonatomic, strong) UILabel *biometricSetupTitle;

/**
 * The 'Verify Pin Code' button.
 * Button used for user to submit passcode if length is unknown.
 */
@property (nonatomic, strong) UIButton *verifyPasscodeButton;

/**
 * The label displaying instructions for a given passcode section of the workflow.
 */
@property (nonatomic, strong) UILabel *passcodeInstructionsLabel;

/**
 * The label displaying instructions for a given passcode section of the workflow.
 */
@property (nonatomic, strong) UILabel *biometricInstructionsLabel;

/**
 * The 'Enable' button for Biometric prompt.
 */
@property (nonatomic, strong) UIButton *enableBiometricButton;

/**
 * The 'Not Now' button.
 */
@property (nonatomic, strong) UIButton *cancelBiometricButton;

/**
 * Keeps a copy of the initial passcode of the passcode creation process.
 */
@property (nonatomic, copy) NSString *initialPasscode;

- (void)showVerifyPasscode;

/**
 * The 'Log out' button
 */
@property (nonatomic, strong) UIBarButtonItem *logoutButton;

@end

@implementation SFPasscodeViewController

- (id)initForPasscodeVerification
{
    return [self initWithMode:SFPasscodeControllerModeVerify passcodeConfig:SFPasscodeConfigurationDataNull];
}

- (id)initForPasscodeCreation:(SFPasscodeConfigurationData)configData
{
    return [self initWithMode:SFPasscodeControllerModeCreate passcodeConfig:configData];
}

- (id)initForPasscodeChange:(SFPasscodeConfigurationData)configData
{
    return [self initWithMode:SFPasscodeControllerModeChange passcodeConfig:configData];
}

- (id)initForBiometricVerification
{
    return [self initWithMode:SFBiometricControllerModeVerify passcodeConfig:SFPasscodeConfigurationDataNull];
}

- (id)initForBiometricEnablement
{
    return [self initWithMode:SFBiometricControllerModeEnable passcodeConfig:SFPasscodeConfigurationDataNull];
}


- (id)initWithMode:(SFPasscodeControllerMode)mode passcodeConfig:(SFPasscodeConfigurationData)configData
{
    // if verify (or bio verify) then read passcode from keychain - but configData will be nil anyway
    // if create - take config value
    // if change - take config value - should have already considered length upgrade comparison in security lockout
    self = [super initWithMode:mode passcodeConfig:configData];
    
    if (configData.passcodeLength != SFPasscodeConfigurationDataNull.passcodeLength) {
        self.passcodeLength = (int)configData.passcodeLength;
        self.biometricAllowed = configData.biometricUnlockAllowed;
    } else {
        self.passcodeLength = (int)[SFSecurityLockout passcodeLength];
        self.biometricAllowed = [SFSecurityLockout biometricUnlockAllowed];
    }
    
    [self.passcodeTextView clearPasscode];
    _PasscodeFallback = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layoutVerifyButton:) name:UIKeyboardDidShowNotification object:nil];
    
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
    
    // Passcode Circles
    self.passcodeTextView = [[SFSDKPasscodeTextField alloc] initWithFrame:CGRectZero andLength:self.passcodeLength];
    self.passcodeTextView.delegate = self;
    [self.passcodeTextView clearPasscode]; // don't reset this???
    [self.view addSubview:self.passcodeTextView];
    self.passcodeInstructionsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    [self.passcodeInstructionsLabel setBackgroundColor:[UIColor clearColor]];
    self.passcodeInstructionsLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.passcodeInstructionsLabel.numberOfLines = 0;
    self.passcodeInstructionsLabel.textColor = [UIColor instructionTextColor];
    self.passcodeInstructionsLabel.textAlignment = NSTextAlignmentCenter;
    self.passcodeInstructionsLabel.font = [UIFont fontWithName:kInstructionLabelFontName size:kInstructionTextLabelFontSize];
    [self.view addSubview:self.passcodeInstructionsLabel];
    //self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    //self.view.autoresizesSubviews = YES;
    
    self.verifyPasscodeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.verifyPasscodeButton setTitle:@"Verify Pin Code" forState:UIControlStateNormal];
    self.verifyPasscodeButton.backgroundColor = [UIColor blueColor];
    [self.verifyPasscodeButton.titleLabel setTextAlignment:NSTextAlignmentCenter];
    [self.verifyPasscodeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.verifyPasscodeButton addTarget:self action:@selector(verifyPasscode) forControlEvents:UIControlEventTouchUpInside];
    self.verifyPasscodeButton.accessibilityLabel = @"verify pin code"; //[SFSDKResourceUtils localizedString:@"useTouchIdTitle"];
    self.verifyPasscodeButton.titleLabel.font = [UIFont fontWithName:kButtonFontName size:kButtonLabelFontSize];
    self.verifyPasscodeButton.layer.cornerRadius = kButtonCornerRadius;
    [self.view addSubview:self.verifyPasscodeButton];
    
    self.logoutButton = [[UIBarButtonItem alloc] initWithTitle:[SFSDKResourceUtils localizedString:@"logoutButtonTitle"] style:UIBarButtonItemStylePlain target:self action:@selector(validatePasscodeFailed)];
    [self.logoutButton setEnabled:NO];
    [self.logoutButton setTintColor:[UIColor clearColor]];
    [self.navigationItem setLeftBarButtonItem:self.logoutButton];
    
    // Biometric Setup View
    self.iconView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kIconCircleDiameter, kIconCircleDiameter)];
    self.iconView.backgroundColor = [UIColor clearColor];
    
    CAShapeLayer *iconCircle = [CAShapeLayer layer];
    [iconCircle setPath:[UIBezierPath bezierPathWithRoundedRect:self.iconView.bounds cornerRadius:kIconCircleDiameter].CGPath];
    [iconCircle setStrokeColor:[UIColor borderColor].CGColor];
    [iconCircle setFillColor:[[UIColor whiteColor] CGColor]];
    iconCircle.borderColor = [UIColor borderColor].CGColor;
    iconCircle.borderWidth = 2.0f;
    [[self.iconView layer]  addSublayer:iconCircle];

    UIImage *touchIdImageTmp = [[SFSDKResourceUtils imageNamed:@"touchId"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    self.touchIdImage = [[UIImageView alloc] initWithImage:touchIdImageTmp];
    UIImage *faceIdImageTmp = [[SFSDKResourceUtils imageNamed:@"faceId"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    self.faceIdImage = [[UIImageView alloc] initWithImage:faceIdImageTmp];
    [self.iconView addSubview:self.touchIdImage];
    [self.iconView addSubview:self.faceIdImage];
    [self.view addSubview:self.iconView];
    
    self.setUpBiometricView = [[UIView alloc] initWithFrame:CGRectZero];
    self.setUpBiometricView.backgroundColor = [UIColor whiteColor];
    self.setUpBiometricView.layer.borderColor = [UIColor borderColor].CGColor;
    self.setUpBiometricView.layer.borderWidth = 1.0f;
    [self.view addSubview:self.setUpBiometricView];
    
    // Biometric Instructions
    self.biometricSetupTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    self.biometricSetupTitle.backgroundColor = [UIColor clearColor];
    self.biometricSetupTitle.textColor = [UIColor titleTextColor];
    self.biometricSetupTitle.textAlignment = NSTextAlignmentLeft;
    //self.biometricSetupTitle.font = [UIFont fontWithName:kTitleLabelFontName size:kTitleTextLabelFontSize];
    self.biometricSetupTitle.font = [UIFont boldSystemFontOfSize:kTitleTextLabelFontSize];
    //self.biometricSetupTitle.font = salesforceSansBold;
    self.biometricSetupTitle.hidden = YES;
    [self.setUpBiometricView addSubview:self.biometricSetupTitle];
    
    self.biometricInstructionsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    [self.biometricInstructionsLabel setBackgroundColor:[UIColor clearColor]];
    self.biometricInstructionsLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.biometricInstructionsLabel.numberOfLines = 3;
    self.biometricInstructionsLabel.textColor = [UIColor instructionTextColor];
    self.biometricInstructionsLabel.textAlignment = NSTextAlignmentLeft;
    //self.biometricInstructionsLabel.font = [UIFont fontWithName:kInstructionLabelFontName size:kInstructionTextLabelFontSize];
    //self.biometricInstructionsLabel.font = salesforceSansRegular;
    self.biometricInstructionsLabel.font = [UIFont systemFontOfSize:kInstructionFieldFontSize];
    [self.setUpBiometricView addSubview:self.biometricInstructionsLabel];
    
    // Biometric enable buttons
    self.enableBiometricButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.enableBiometricButton setTitle:@"Enable" forState:UIControlStateNormal];
    self.enableBiometricButton.backgroundColor = [UIColor blueColor];
    [self.enableBiometricButton.titleLabel setTextAlignment:NSTextAlignmentCenter];
    [self.enableBiometricButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.enableBiometricButton addTarget:self action:@selector(showBiometric) forControlEvents:UIControlEventTouchUpInside];
    self.enableBiometricButton.accessibilityLabel = @"useBiometricTitle"; //[SFSDKResourceUtils localizedString:@"useTouchIdTitle"];
    self.enableBiometricButton.titleLabel.font = [UIFont fontWithName:kButtonFontName size:kButtonLabelFontSize];
    //self.enableBiometricButton.titleLabel.font = salesforceSansBold;
    self.enableBiometricButton.layer.cornerRadius = kButtonCornerRadius;
    [self.setUpBiometricView addSubview:self.enableBiometricButton];
    
    self.cancelBiometricButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.cancelBiometricButton setTitle:@"Not Now" forState:UIControlStateNormal];
    self.cancelBiometricButton.backgroundColor = [UIColor whiteColor];
    [self.cancelBiometricButton.titleLabel setTextAlignment:NSTextAlignmentCenter];
    [self.cancelBiometricButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.cancelBiometricButton addTarget:self action:@selector(userDenyBiometricEnablement) forControlEvents:UIControlEventTouchUpInside];
    self.cancelBiometricButton.accessibilityLabel = @"useBiometricTitle"; //[SFSDKResourceUtils localizedString:@"useTouchIdTitle"];
    self.cancelBiometricButton.titleLabel.font = [UIFont fontWithName:kButtonFontName size:kButtonLabelFontSize];
    //self.cancelBiometricButton.titleLabel.font = salesforceSansBold;
    self.cancelBiometricButton.layer.cornerRadius = kButtonCornerRadius;
    self.cancelBiometricButton.layer.borderColor = [UIColor borderColor].CGColor;
    self.cancelBiometricButton.layer.borderWidth = 1.0f;
    [self.setUpBiometricView addSubview:self.cancelBiometricButton];
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self hideAll];
    self.navigationController.navigationBar.backgroundColor = [UIColor whiteColor];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.translucent = NO;
    [self.view setBackgroundColor:[UIColor backgroundColor]];
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        [self setEdgesForExtendedLayout:UIRectEdgeNone];
    }
    
    [self layoutSubviews];
    
}

- (void)hideAll
{
    [self.passcodeTextView setHidden:YES];
    [self.verifyPasscodeButton setHidden:YES];
    [self.passcodeInstructionsLabel setHidden:YES];
    [self.biometricSetupTitle setHidden:YES];
    [self.biometricInstructionsLabel setHidden:YES];
    [self.cancelBiometricButton setHidden:YES];
    [self.enableBiometricButton setHidden:YES];
    [self.setUpBiometricView setHidden:YES];
    [self.iconView setHidden:YES];
    [self.faceIdImage setHidden:YES];
    [self.touchIdImage setHidden:YES];
    [self.navigationItem setTitle:nil];
    [self.navigationItem setRightBarButtonItem:nil];
    [self.navigationItem.leftBarButtonItem setEnabled:NO];
    [self.navigationItem.leftBarButtonItem setTintColor:[UIColor clearColor]];
}

- (void)layoutSubviews
{
    
    [self layoutPasscodeVerifyView];
    [self layoutSetupBiometric];
}

- (void)viewWillLayoutSubviews
{
    [self layoutSubviews];
    [super viewWillLayoutSubviews];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    switch (self.mode) {
        case SFPasscodeControllerModeCreate:
        case SFPasscodeControllerModeChange:
            [self showCreateOrChangePasscode];
            break;
        case SFBiometricControllerModeVerify:
            [self showBiometric];
            break;
        case SFBiometricControllerModeEnable:
            [self showBiometricSetup];
            break;
        case SFPasscodeControllerModeVerify:
            [self showVerifyPasscode];
    }
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

-(BOOL) shouldAutorotate {
    return NO;
}



#pragma mark - Private methods

/*+ (NSString *)stringWithLength:(NSUInteger)length
{
    NSMutableString *s = [NSMutableString string];
    for (int i = 0; i < length; i++) {
        [s appendString:@"a"];
    }
    return s;
}*/

- (void)layoutSetupBiometric
{
    CGFloat xIcon = (self.view.bounds.size.width - kIconCircleDiameter) / 2;
    self.iconView.frame = CGRectMake(xIcon, kTopPadding, kIconCircleDiameter, kIconCircleDiameter);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.touchIdImage.frame = CGRectMake(kTouchIconPadding, kTouchIconPadding, kTouchIdIconWidth, kTouchIdIconWidth);
        self.faceIdImage.frame = CGRectMake(kFaceIconPadding, kFaceIconPadding, kFaceIdIconWidth, kFaceIdIconWidth);
    });
         
    CGFloat ySetup = (kTopPadding * 2) + kIconCircleDiameter;
    self.setUpBiometricView.frame = CGRectMake(0, ySetup, self.view.bounds.size.width, kSetupViewHeight);
    
    CGFloat wTitle = self.view.bounds.size.width - (2 * kDefaultPadding);
    CGFloat hTitle = kTitleTextLabelHeight;
    CGFloat xTitle = CGRectGetMinX(self.setUpBiometricView.bounds) + kDefaultPadding;// - (w / 2.0);
    CGFloat yTitle = CGRectGetMinY(self.setUpBiometricView.bounds) + kDefaultPadding;// - kLabelPadding;
    self.biometricSetupTitle.frame = CGRectMake(xTitle, yTitle, wTitle, hTitle);
    
    CGFloat wIns = self.view.bounds.size.width - (2 * kDefaultPadding);
    CGFloat hIns = kBiometricInstructionsLabelHeight;
    CGFloat xIns = CGRectGetMinX(self.setUpBiometricView.bounds) + kDefaultPadding;//- (wIns / 2.0);
    CGFloat yIns = CGRectGetMinY(self.setUpBiometricView.bounds) + kDefaultPadding + hTitle + (kDefaultPadding / 2.0);// + (kLabelPadding / 2.0);//(hIns / 2.0) - kLabelPadding;
    self.biometricInstructionsLabel.frame = CGRectMake(xIns, yIns, wIns, hIns);
    
    CGFloat wCancelButton = (self.view.bounds.size.width - (3 * kDefaultPadding)) / 2;
    CGFloat hCancelButton = kButtonHeight;
    CGFloat xCancelButton = CGRectGetMinX(self.setUpBiometricView.bounds) + kDefaultPadding;
    CGFloat yCancelButton = CGRectGetMinY(self.setUpBiometricView.bounds) + hTitle + hIns + (kDefaultPadding * 2.5);//(hIns / 2.0) - kLabelPadding;
    self.cancelBiometricButton.frame = CGRectMake(xCancelButton, yCancelButton, wCancelButton, hCancelButton);
    
    CGFloat wEnableButton = (self.view.bounds.size.width - (3 * kDefaultPadding)) / 2;
    CGFloat hEnableButton = kButtonHeight;
    CGFloat xEnableButton = CGRectGetMinX(self.setUpBiometricView.bounds) + (kDefaultPadding * 2) + wCancelButton;
    CGFloat yEnableButton = CGRectGetMinY(self.setUpBiometricView.bounds) + hTitle + hIns + (kDefaultPadding * 2.5);
    self.enableBiometricButton.frame = CGRectMake(xEnableButton, yEnableButton, wEnableButton, hEnableButton);
}

- (void)layoutPasscodeVerifyView
{
    CGFloat wIns = self.view.bounds.size.width - (2 * kDefaultPadding);
    CGFloat hIns = kInstructionLabelHeight;
    CGFloat xIns = CGRectGetMinX(self.view.bounds) + kDefaultPadding;
    CGFloat yIns = CGRectGetMinY(self.view.bounds) + kTopPadding;
    self.passcodeInstructionsLabel.frame = CGRectMake(xIns, yIns, wIns, hIns);
    
    CGFloat wView = self.view.bounds.size.width;
    CGFloat hView = kPasscodeViewHeight;
    CGFloat xView = CGRectGetMinX(self.view.bounds);
    CGFloat yView = CGRectGetMinY(self.view.bounds) + kTopPadding + kInstructionLabelHeight + (kDefaultPadding / 2.0);
    self.passcodeTextView.frame = CGRectMake(xView, yView, wView, hView);
    self.passcodeTextView.layer.frame = CGRectMake(xView, yView, wView, hView);
}

- (BOOL)canShowBiometricEnrollmentScreen
{
    BOOL canShow = NO;
    if (self.biometricAllowed && ![SFSecurityLockout biometricUnlockEnabled]) {
        // If the user declines biometric once, don't ever prompt again upon unlock.
        if (![SFSecurityLockout userDeclinedBiometricUnlock]) {
            canShow = YES;
            // Allow app to prompt when we aren't in passcode flow.
        } else if (self.mode == SFBiometricControllerModeEnable) {
            canShow = YES;
        }
    }
    
    return canShow;
}

- (BOOL)showBiometric
{
    BOOL success = NO;
    if ([self canShowBiometric]) {
        LAContext *context = [[LAContext alloc] init];
        if ([SFSecurityLockout biometricUnlockEnabled]) {
            [context setLocalizedCancelTitle:[SFSDKResourceUtils localizedString:@"biometricFallbackActionLabel"]];
            [context setLocalizedFallbackTitle:@""];
        }
        
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:[SFSDKResourceUtils localizedString:@"biometricReason"] reply:^(BOOL success, NSError *authenticationError) {
            __block BOOL succeeded = success;
            dispatch_async(dispatch_get_main_queue(), ^{
                
                // Launched as a standalone window
                if (self.mode == SFBiometricControllerModeEnable) {
                if (succeeded) {
                        [SFSecurityLockout setBiometricUnlockEnabled:YES];
                    }
                    [self dismissStandaloneBiometricSetup];
                } else {
                    // Passcode flow
                    if (succeeded) {
                        [SFSecurityLockout setBiometricUnlockEnabled:YES];
                        [self dismissBiometricScreen];
                    } else {
                        if ([SFSecurityLockout biometricUnlockEnabled]) {
                            [self showVerifyPasscode];
                        } else {
                            [self dismissBiometricScreen];
                        }
                    }
                }
            });
        }];
    }
    
    return success;
}

- (void)dismissStandaloneBiometricSetup
{
    [[[SFSDKWindowManager sharedManager] passcodeWindow].viewController dismissViewControllerAnimated:NO completion:^{
        [[SFSDKWindowManager sharedManager].passcodeWindow  dismissWindowAnimated:NO withCompletion:^{
        }];
    }];
}

- (void)userDenyBiometricEnablement
{
    // Launched as a standalone window
    if (self.mode == SFBiometricControllerModeEnable) {
        [self dismissStandaloneBiometricSetup];
    } else {
        [SFSecurityLockout setUserDeclinedBiometricUnlock:YES];
        [self dismissBiometricScreen];
    }
}

- (void) dismissBiometricScreen
{
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (self.mode) {
            case SFPasscodeControllerModeCreate:
            case SFPasscodeControllerModeChange:
                [super createPasscodeConfirmed:self.passcodeTextView.passcodeInput];
                break;
            case SFPasscodeControllerModeVerify:
                [self validatePasscodeConfirmed:self.passcodeTextView.passcodeInput];
                break;
            case SFBiometricControllerModeEnable:
            default:
                [SFSecurityLockout setupTimer];
                [SFSecurityLockout unlock:YES action:SFSecurityLockoutActionBiometricVerified passcodeConfig:SFPasscodeConfigurationDataNull];
                break;
        }
    });
}

// USE THIS??
/*- (void)updateInstructionsLabel:(NSString *)newLabel
{
    /elf.instructionsLabel.text = newLabel;
    self.instructionsLabel.accessibilityLabel = newLabel;
    [self.instructionsLabel setNeedsDisplay];
}*/

- (void)showBiometricSetup
{
    [self hideAll];
    LAContext *context = [[LAContext alloc] init];
    [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil];
    switch ([context biometryType]) {
        case LABiometryTypeFaceID:
            [self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"biometricEnableFaceIdNavTitle"]];
            [self.biometricSetupTitle setText:[SFSDKResourceUtils localizedString:@"biometricEnableTitleFaceId"]];
            [self.biometricInstructionsLabel setText:[SFSDKResourceUtils localizedString:@"biometricEnableInstructionsFaceId"]];
            [self.faceIdImage setHidden:NO];
            break;
        case LABiometryTypeTouchID:
            [self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"biometricEnableTouchIdNavTitle"]];
            [self.biometricSetupTitle setText:[SFSDKResourceUtils localizedString:@"biometricEnableTitleFaceId"]];
            [self.biometricInstructionsLabel setText:[SFSDKResourceUtils localizedString:@"biometricEnableInstructionsTouchId"]];
            [self.touchIdImage setHidden:NO];
            break;
        case LABiometryTypeNone:
            // TODO: Log error to console!
            // Dismiss screen with not now button action.
            NSLog(@"yoooo something went wrong! LABiometricTypeNone");
            break;
    }
    
    [self.iconView setHidden:NO];
    [self.setUpBiometricView setHidden:NO];
    [self.biometricSetupTitle setHidden:NO];
    [self.biometricInstructionsLabel setHidden:NO];
    [self.enableBiometricButton setHidden:NO];
    [self.cancelBiometricButton setHidden:NO];
    //[self.view setNeedsDisplay];
}


- (void)showCreateOrChangePasscode
{
    if (self.mode == SFPasscodeControllerModeCreate) {
        self.passcodeInstructionsLabel.text = [SFSDKResourceUtils localizedString:@"passcodeCreateInstructions"];
    } else {
        [self.passcodeInstructionsLabel setText:[SFSDKResourceUtils localizedString:@"passcodeChangeInstructions"]];
    }
    [self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"createPasscodeNavTitle"]];
    [self.passcodeInstructionsLabel setFont:[UIFont systemFontOfSize:kInstructionFieldFontSize]];
    [self.passcodeInstructionsLabel setHidden:NO];
    [self.passcodeTextView setHidden:NO];
   
    [self.passcodeTextView refreshView];
    [self.passcodeTextView becomeFirstResponder];
}

- (void)showVerifyPasscode
{
    [self hideAll];
    [self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"verifyPasscodeNavTitle"]];
    [self.passcodeInstructionsLabel setText:[SFSDKResourceUtils localizedString:@"passcodeVerifyInstructions"]];
    [self.passcodeInstructionsLabel setFont:[UIFont systemFontOfSize:kInstructionFieldFontSize]];
    [self.passcodeInstructionsLabel setHidden:NO];
    [self.passcodeTextView setHidden:NO];
    
    if (self.passcodeLength == 0) {
        [self.verifyPasscodeButton setHidden:NO];
    }
    [self.passcodeTextView refreshView];
    [self.passcodeTextView becomeFirstResponder];
}

- (void)verifyPasscode
{
    if ([[SFPasscodeManager sharedManager] verifyPasscode:self.passcodeTextView.passcodeInput]) {
        [self.passcodeTextView resignFirstResponder];
        if ([self canShowBiometricEnrollmentScreen]) {
            [self showBiometricSetup];
        } else {
            [self validatePasscodeConfirmed:self.passcodeTextView.passcodeInput];
        }
    } else {
        if ([self decrementPasscodeAttempts]) {
            [self.passcodeTextView clearPasscode];
            [self.passcodeTextView refreshView];
            NSString *passcodeFailedString = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"passcodeInvalidError"], self.remainingAttempts];
            [self.passcodeInstructionsLabel setText:passcodeFailedString];
            if (![self.navigationItem.leftBarButtonItem isEnabled]) {
                [self.navigationItem.leftBarButtonItem setEnabled:YES];
                [self.navigationItem.leftBarButtonItem setTintColor:[UIColor blueColor]];
            }
        }
    }
}

- (void)createPasscodeConfirmed:(NSString *)newPasscode
{
    if ([self canShowBiometricEnrollmentScreen]) {
        [self showBiometricSetup];
    } else {
        [super createPasscodeConfirmed:newPasscode];
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)rString {
    
    // Check if input is an actual int
    if (rString.intValue == 0 && ![rString isEqualToString:@"0"]) {
        return NO;
    }
    
    BOOL passcodeLengthKnown = (self.passcodeLength != 0);
    int length = (passcodeLengthKnown) ? self.passcodeLength : kMaxPasscodeLength;
    [self.passcodeTextView.passcodeInput appendString:rString];
    self.passcodeTextView.passcodeLength = length;
    
    if (passcodeLengthKnown && [self.passcodeTextView.passcodeInput length] == length) {
        switch (self.mode) {
            case SFPasscodeControllerModeCreate:
            case SFPasscodeControllerModeChange:
                if (_firstPasscodeValidated) {
                    if ([self.passcodeTextView.passcodeInput isEqualToString:self.initialPasscode] ) {
                        [self createPasscodeConfirmed:self.passcodeTextView.passcodeInput];
                    } else {
                        [self.passcodeTextView clearPasscode];
                        [self.passcodeTextView refreshView];
                        [self.passcodeInstructionsLabel setText:[SFSDKResourceUtils localizedString:@"passcodesDoNotMatchError"]];
                    }
                } else {
                    self.initialPasscode = [[NSString alloc] initWithString:self.passcodeTextView.passcodeInput];
                    [self.passcodeTextView clearPasscode];
                    [self.passcodeTextView refreshView];
                    [self.passcodeInstructionsLabel setText:[SFSDKResourceUtils localizedString:@"passcodeVerifyInstructions"]];
                    _firstPasscodeValidated = YES;
                    [self showVerifyPasscode];
                }
                break;
            case SFBiometricControllerModeVerify:
            case SFPasscodeControllerModeVerify:
                [self verifyPasscode];
                break;
            default:
                // error?
                break;
        }
    } else if ([self.passcodeTextView.passcodeInput length] < length) {
        [self.passcodeTextView refreshView];
    }
    
    return NO;
}

- (void)layoutVerifyButton:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        CGSize keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
        CGFloat wButton = kVerifyButtonWidth;
        CGFloat hButton = kButtonHeight;
        CGFloat xButton = CGRectGetMaxX(self.view.bounds) - wButton - kDefaultPadding;
        CGFloat yButton = CGRectGetMaxY(self.view.bounds) - keyboardSize.height - hButton - kDefaultPadding;
        self.verifyPasscodeButton.frame = CGRectMake(xButton, yButton, wButton, hButton);
    });
}


@end
