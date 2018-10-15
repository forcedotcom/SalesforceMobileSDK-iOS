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
#import "UIColor+SFColors.h"
#import "PasscodeTextField.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "SFKeychainItemWrapper.h"

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
static CGFloat      const kInstructionLabelHeight            = 18.f;
static CGFloat      const kInstructionFieldFontSize          = 14.f;

@interface SFPasscodeViewController() <UITextFieldDelegate, MDeleteProtocol> {
    BOOL _firstPasscodeValidated;
    BOOL _PasscodeFallback;
}

/**
 * Passcode Text Field for custom UI.
 */
@property (strong, nonatomic) IBOutlet PasscodeTextField *passcodeTextView;

/**
 * String containing the passcode as the user types.
 */
@property (strong,nonatomic) NSMutableString *passcodeInput;

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

@end

@implementation SFPasscodeViewController

/**
 *       DELETE THIS
 */
- (UIColor*)backgroundColor {
    return [UIColor colorWithRed:245.0f/255.0f green:246.0f/255.0f blue:250.0f/255.0f alpha:1.0f];
}

- (UIColor*)titleTextColor {
    return [UIColor colorWithRed:62.0f/255.0f green:62.0f/255.0f blue:60.0f/255.0f alpha:1.0f];
}

- (UIColor*)instructionTextColor {
    return [UIColor colorWithRed:62.0f/255.0f green:62.0f/255.0f blue:60.0f/255.0f alpha:1.0f];
}

- (UIColor*)blueColor {
    return [UIColor colorWithRed:0.0f/255.0f green:112.0f/255.0f blue:210.0f/255.0f alpha:1.0f];
}

- (UIColor*)borderColor {
    return [UIColor colorWithRed:217.0f/255.0f green:221.0f/255.0f blue:230.0f/255.0f alpha:1.0f];
}

 


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
    self = [super initWithMode:mode passcodeConfig:configData];
    
    if (configData.passcodeLength != SFPasscodeConfigurationDataNull.passcodeLength) {
        self.passcodeLength = (int)configData.passcodeLength;
        self.biometricAllowed = configData.biometricUnlockAllowed;
    } else {
        self.passcodeLength = [[SFPasscodeManager sharedManager] passcodeLength];
        self.biometricAllowed = [SFSecurityLockout biometricUnlockAllowed];
    }
    
    self.passcodeInput = [NSMutableString stringWithString:@""];
    _PasscodeFallback = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layoutVerifyButton:) name:UIKeyboardDidShowNotification object:nil];
    
    /// change this to if.  use config for crate and keychain for verify
    
    /*
    if (self) {
        switch (mode) {
            case SFPasscodeControllerModeCreate:
            case SFPasscodeControllerModeChange:
                _firstPasscodeValidated = NO;
                //[self addPasscodeCreationNav];
                //[self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"createPasscodeNavTitle"]];
                break;
            case SFPasscodeControllerModeVerify:
                //[self addPasscodeVerificationNav];
                //[self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"verifyPasscodeNavTitle"]];
                break;
            case SFBiometricControllerModeEnable:
                //[self addBiometricEnableNav];
                break;
            case SFBiometricControllerModeVerify:
                //Do something
            default:
                break;
        }
    }*/
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
    self.passcodeInput = [NSMutableString stringWithString:@""]; // don't reset this???
    self.passcodeTextView = [[PasscodeTextField alloc] initWithFrame:CGRectZero];
    self.passcodeTextView.delegate = self;
    self.passcodeTextView.deleteDelegate = self;
    self.passcodeTextView.keyboardType = UIKeyboardTypeNumberPad;
    self.passcodeTextView.backgroundColor = [UIColor whiteColor];
    self.passcodeTextView.tintColor = [UIColor clearColor];
    self.passcodeTextView.borderStyle = UITextBorderStyleNone;
    self.passcodeTextView.layer.borderColor = [self borderColor].CGColor;
    self.passcodeTextView.layer.borderWidth = 1.0f;
    [self.view addSubview:self.passcodeTextView];
    
    self.passcodeInstructionsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    [self.passcodeInstructionsLabel setBackgroundColor:[UIColor clearColor]];
    self.passcodeInstructionsLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.passcodeInstructionsLabel.numberOfLines = 0;
    self.passcodeInstructionsLabel.textColor = [self instructionTextColor];
    self.passcodeInstructionsLabel.textAlignment = NSTextAlignmentCenter;
    self.passcodeInstructionsLabel.font = [UIFont fontWithName:kInstructionLabelFontName size:kInstructionTextLabelFontSize];
    [self.view addSubview:self.passcodeInstructionsLabel];
    //self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    //self.view.autoresizesSubviews = YES;
    
    self.verifyPasscodeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.verifyPasscodeButton setTitle:@"Verify Pin Code" forState:UIControlStateNormal];
    self.verifyPasscodeButton.backgroundColor = [self blueColor];
    [self.verifyPasscodeButton.titleLabel setTextAlignment:NSTextAlignmentCenter];
    [self.verifyPasscodeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.verifyPasscodeButton addTarget:self action:@selector(verifyPasscode:) forControlEvents:UIControlEventTouchUpInside];
    self.verifyPasscodeButton.accessibilityLabel = @"verify pin code"; //[SFSDKResourceUtils localizedString:@"useTouchIdTitle"];
    self.verifyPasscodeButton.titleLabel.font = [UIFont fontWithName:kButtonFontName size:kButtonLabelFontSize];
    self.verifyPasscodeButton.layer.cornerRadius = kButtonCornerRadius;
    [self.view addSubview:self.verifyPasscodeButton];
    
    // Biometric Setup View
    self.iconView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kIconCircleDiameter, kIconCircleDiameter)];
    self.iconView.backgroundColor = [UIColor clearColor];
    
    CAShapeLayer *iconCircle = [CAShapeLayer layer];
    [iconCircle setPath:[UIBezierPath bezierPathWithRoundedRect:self.iconView.bounds cornerRadius:kIconCircleDiameter].CGPath];
    [iconCircle setStrokeColor:[self borderColor].CGColor];
    [iconCircle setFillColor:[[UIColor whiteColor] CGColor]];
    iconCircle.borderColor = [self borderColor].CGColor;
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
    self.setUpBiometricView.layer.borderColor = [self borderColor].CGColor;
    self.setUpBiometricView.layer.borderWidth = 1.0f;
    [self.view addSubview:self.setUpBiometricView];
    
    // Biometric Instructions
    self.biometricSetupTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    self.biometricSetupTitle.backgroundColor = [UIColor clearColor];
    self.biometricSetupTitle.textColor = [self titleTextColor];
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
    self.biometricInstructionsLabel.textColor = [self instructionTextColor];
    self.biometricInstructionsLabel.textAlignment = NSTextAlignmentLeft;
    //self.biometricInstructionsLabel.font = [UIFont fontWithName:kInstructionLabelFontName size:kInstructionTextLabelFontSize];
    //self.biometricInstructionsLabel.font = salesforceSansRegular;
    self.biometricInstructionsLabel.font = [UIFont systemFontOfSize:kInstructionFieldFontSize];
    [self.setUpBiometricView addSubview:self.biometricInstructionsLabel];
    
    // Biometric enable buttons
    self.enableBiometricButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.enableBiometricButton setTitle:@"Enable" forState:UIControlStateNormal];
    self.enableBiometricButton.backgroundColor = [self blueColor];
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
    [self.cancelBiometricButton setTitleColor:[self blueColor] forState:UIControlStateNormal];
    [self.cancelBiometricButton addTarget:self action:@selector(userDenyBiometricEnablement) forControlEvents:UIControlEventTouchUpInside];
    self.cancelBiometricButton.accessibilityLabel = @"useBiometricTitle"; //[SFSDKResourceUtils localizedString:@"useTouchIdTitle"];
    self.cancelBiometricButton.titleLabel.font = [UIFont fontWithName:kButtonFontName size:kButtonLabelFontSize];
    //self.cancelBiometricButton.titleLabel.font = salesforceSansBold;
    self.cancelBiometricButton.layer.cornerRadius = kButtonCornerRadius;
    self.cancelBiometricButton.layer.borderColor = [self borderColor].CGColor;
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
    [self.view setBackgroundColor:[self backgroundColor]];
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
    [self.navigationItem setLeftBarButtonItem:nil];
    [self.navigationItem setRightBarButtonItem:nil];
}

- (void)layoutSubviews
{
    
    [self layoutPasscodeVerifyView];
    [self layoutSetupBiometric];
}

- (void)forgotPassAction
{
    __weak typeof(self) weakSelf = self;
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:[SFSDKResourceUtils localizedString:@"forgotPasscodeTitle"]
                                                                   message:[SFSDKResourceUtils localizedString:@"logoutAlertViewTitle"]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction
                               actionWithTitle:[SFSDKResourceUtils localizedString:@"logoutYes"]
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action)
                               {
                                   __strong typeof(weakSelf) strongSelf = weakSelf;
                                   [SFSDKCoreLogger d:[strongSelf class] format:@"User pressed Yes"];
                                   [strongSelf validatePasscodeFailed];
                               }];
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:[SFSDKResourceUtils localizedString:@"logoutNo"]
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action)
                                   {
                                       [SFSDKCoreLogger d:[weakSelf class] format:@"User pressed No"];
                                   }];
    [alert addAction:okAction];
    [alert addAction:cancelAction];
    [SFSDKCoreLogger d:[self class] format:@"SFPasscodeViewController forgotPassAction"];
    [self presentViewController:alert animated:YES completion:nil];
}

/*
- (void)viewWillLayoutSubviews
{
    [self layoutSubviews];
    [super viewWillLayoutSubviews];
}

- (void)layoutSubviews
{
    [self layoutPasscodeField];
    [self layoutErrorLabel];
    [self layoutInstructionsLabel];
    [self layoutForgotPasscodeButton];
    [self layoutEnableBiometricButton];
    [self layoutCancelBiometricButton];
}
*/

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    switch (self.mode) {
        case SFPasscodeControllerModeCreate:
        case SFPasscodeControllerModeChange:
            [self showCreateOrChangePasscode];
            break;
        case SFBiometricControllerModeVerify:
            [self showVerifyPasscode];
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

+ (NSString *)stringWithLength:(NSUInteger)length
{
    NSMutableString *s = [NSMutableString string];
    for (int i = 0; i < length; i++) {
        [s appendString:@"a"];
    }
    return s;
}

- (void)finishedInitialPasscode
{
    /*if (self.passcodeField.text.length < self.minPasscodeLength) {
        self.errorLabel.text = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"minPasscodeLengthError"], self.minPasscodeLength];
    } else {
        self.initialPasscode = self.passcodeField.text;
        [self.passcodeField resignFirstResponder];
        self.passcodeField.text = @"";
        [self updateErrorLabel:@""];
        [self updateInstructionsLabel:[SFSDKResourceUtils localizedString:@"passcodeConfirmInstructions"]];
        _firstPasscodeValidated = YES;
        [self addPasscodeConfirmNav];
    }*/
}

- (void)finishedConfirmPasscode
{
    /*if (self.passcodeField.text.length < self.minPasscodeLength) {
        self.errorLabel.text = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"minPasscodeLengthError"], self.minPasscodeLength];
    } else if (![self.passcodeField.text isEqualToString:self.initialPasscode]) {
        [self resetInitialCreateView];
        [self updateErrorLabel:[SFSDKResourceUtils localizedString:@"passcodesDoNotMatchError"]];
    } else {
        [self.passcodeField resignFirstResponder];
        if ([self canShowBiometricEnrollmentScreen]) {
            [self addBiometricEnableNav];
        } else {
            [self createPasscodeConfirmed:self.passcodeField.text];
        }
    }*/
}

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

/*- (void)showBiometric {
    LAContext *context = [[LAContext alloc] init];
    NSError *authError = nil;
    
    context.localizedCancelTitle = @"Use Passcode";
    
    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&authError]) {
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:@"Login yo"
                          reply:^(BOOL success, NSError *error) {
                              if (success) {
                                  NSLog(@"Success!!!");
                              } else {
                                  NSLog(@"Cancelled");
                              }
                          }];
    } else {
        NSLog(@"Could not evaluate policy.");
    }
}*/

- (void)finishedValidatePasscode
{
    /*[self.view endEditing:YES];
    NSString *checkPasscode = [self.passcodeField text];
    if ([[SFPasscodeManager sharedManager] verifyPasscode:checkPasscode]) {
        [self.passcodeField resignFirstResponder];
        if ([self canShowBiometricEnrollmentScreen]) {
            [self addBiometricEnableNav];
        } else {
            [self validatePasscodeConfirmed:checkPasscode];
        }
    } else {
        if ([self decrementPasscodeAttempts]) {
            self.passcodeField.text = @"";
            [self updateErrorLabel:[SFSDKResourceUtils localizedString:@"passcodeInvalidError"]];
        }
    }*/
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
        }
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:[SFSDKResourceUtils localizedString:@"biometricReason"] reply:^(BOOL success, NSError *authenticationError) {
            if (success) {
                success = YES;
                [SFSecurityLockout setBiometricUnlockEnabled:YES];
                [self dismissBiometricScreen];
            } else {
                if ([SFSecurityLockout biometricUnlockEnabled]) {
                    [self showVerifyPasscode];
                } else {
                    [self dismissBiometricScreen];
                }
            }
        }];
    }
    
    return success;
}

- (void)userDenyBiometricEnablement
{
    [SFSecurityLockout setUserDeclinedBiometricUnlock:YES];
    [self dismissBiometricScreen];
}

- (void) dismissBiometricScreen
{
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (self.mode) {
            case SFPasscodeControllerModeCreate:
            case SFPasscodeControllerModeChange:
                [super createPasscodeConfirmed:self.passcodeInput];
                break;
            case SFPasscodeControllerModeVerify:
                [self validatePasscodeConfirmed:self.passcodeInput];
                break;
            case SFBiometricControllerModeEnable:
                // dismiss view controller?
            default:
                [SFSecurityLockout setupTimer];
                [SFSecurityLockout unlock:YES action:SFSecurityLockoutActionBiometricVerified passcodeConfig:SFPasscodeConfigurationDataNull];
                break;
        }
    });
}

// USE THIS??
- (void)updateInstructionsLabel:(NSString *)newLabel
{
    /*self.instructionsLabel.text = newLabel;
    self.instructionsLabel.accessibilityLabel = newLabel;
    [self.instructionsLabel setNeedsDisplay];*/
}

// NEEDED?
- (void)resetInitialCreateView
{
    /*_firstPasscodeValidated = NO;
    self.initialPasscode = nil;
    self.passcodeField.text = @"";
    [self.passcodeField resignFirstResponder];
    [self updateInstructionsLabel:[SFSDKResourceUtils localizedString:@"passcodeCreateInstructions"]];
    [self updateErrorLabel:@""];
    [self addPasscodeCreationNav];*/
}

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
    [self.passcodeTextView becomeFirstResponder];
    [self drawPasscodeCircles];
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
    [self.passcodeTextView becomeFirstResponder];
    
    if (self.passcodeLength == 0) {
        [self.verifyPasscodeButton setHidden:NO];
    }
    
    [self drawPasscodeCircles];
    [self.passcodeTextView becomeFirstResponder];
}

- (void)verifyPasscode
{
    if ([[SFPasscodeManager sharedManager] verifyPasscode:self.passcodeInput]) {
        [self.passcodeTextView resignFirstResponder];
        if ([self canShowBiometricEnrollmentScreen]) {
            [self showBiometricSetup];
        } else {
            [self validatePasscodeConfirmed:self.passcodeInput];
        }
    } else {
        if ([self decrementPasscodeAttempts]) {
            [self.passcodeInput setString:@""];
            [self.passcodeInstructionsLabel setText:[SFSDKResourceUtils localizedString:@"passcodeInvalidError"]];
            if (self.navigationItem.leftBarButtonItem == nil) {
                UIBarButtonItem *logoutButton = [[UIBarButtonItem alloc] initWithTitle:[SFSDKResourceUtils localizedString:@"logoutButtonTitle"] style:UIBarButtonItemStylePlain target:self action:@selector(validatePasscodeFailed)];
                [self.navigationItem setLeftBarButtonItem:logoutButton];
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
    [self.passcodeInput appendString:rString];
    
    if (passcodeLengthKnown && [self.passcodeInput length] == length) {
        switch (self.mode) {
            case SFPasscodeControllerModeCreate:
            case SFPasscodeControllerModeChange:
                if (_firstPasscodeValidated) {
                    if ([self.passcodeInput isEqualToString:self.initialPasscode] ) {
                        [self createPasscodeConfirmed:self.passcodeInput];
                    } else {
                        [self.passcodeInput setString:@""];
                        [self drawPasscodeCircles];
                        [self.passcodeInstructionsLabel setText:[SFSDKResourceUtils localizedString:@"passcodesDoNotMatchError"]];
                        // TODO: extra credit
                        // add back button here
                        // back button must reset _firstPasscodeValidated, initialPasscode and change instruction label
                    }
                } else {
                    self.initialPasscode = [[NSString alloc] initWithString:self.passcodeInput];
                    [self.passcodeInput setString:@""];
                    //[self drawPasscodeCircles];
                    //[self.passcodeInstructionsLabel setText:[SFSDKResourceUtils localizedString:@"passcodeVerifyInstructions"]];
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
    } else if ([self.passcodeInput length] < length) {
        [self drawPasscodeCircles];
    }
    
    return NO;
}

- (void)drawPasscodeCircles
{
    self.passcodeTextView.layer.sublayers = nil;
    int diameter = kPasscodeCircleDiameter;
    int horizontalSpacing = kPasscodeCircleSpacing;
    int OpenCircleSpacingX = 0;
    int filledCircleSpacingX = 0;
    int lengthForSpacing = (self.passcodeLength == 0) ? kMaxPasscodeLength : self.passcodeLength;
    int startX = (self.view.bounds.size.width - (diameter * lengthForSpacing) - (horizontalSpacing * (lengthForSpacing - 1))) / 2;
    
    if (self.passcodeLength == 0) {
        startX = (startX > kDefaultPadding) ? kDefaultPadding : startX;
    } else {
        // Draw open cirlces
        for (int count=0 ; count < self.passcodeLength; count++) {
            CAShapeLayer *openCircle = [CAShapeLayer layer];
            
            // Make a circular shape
            openCircle.path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, -12, diameter, diameter)cornerRadius:diameter].CGPath;
            
            // Center the shape in self.view
            openCircle.position = CGPointMake(startX + OpenCircleSpacingX, diameter);
            openCircle.fillColor = [UIColor clearColor].CGColor;
            openCircle.strokeColor = [self blueColor].CGColor;
            openCircle.lineWidth = 2;
            openCircle.zPosition = 5;
            OpenCircleSpacingX += (diameter + horizontalSpacing);
            [self.passcodeTextView.layer addSublayer:openCircle];
        }
    }
    
    // Draw typed circles
    NSUInteger noOfChars = [self.passcodeInput length];
    for (int count=0 ; count < noOfChars; count++) {
        CAShapeLayer *filledCircle = [CAShapeLayer layer];
        
        // Make a circular shape
        filledCircle.path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, -12, diameter, diameter)cornerRadius:diameter].CGPath;
        
        // Center the shape in self.view
        filledCircle.position = CGPointMake(startX + filledCircleSpacingX, diameter);
        filledCircle.fillColor = [self blueColor].CGColor;
        filledCircle.strokeColor = [self blueColor].CGColor;
        filledCircle.lineWidth = 1;
        filledCircle.zPosition = 5;
        filledCircleSpacingX += (diameter + horizontalSpacing);
        [self.passcodeTextView.layer addSublayer:filledCircle];
    }
}

- (void)deleteBackward {
    
    if ([self.passcodeInput length] < 1) {
        return;
    }
    
    if (self.passcodeInput.length > 0) {
        [self.passcodeInput deleteCharactersInRange:NSMakeRange([self.passcodeInput length]-1, 1)];
    }
    
    [self drawPasscodeCircles];
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
