/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#import "SFPasscodeViewController.h"
#import <SalesforceSecurity/SFPasscodeManager.h>
#import "SFSDKResourceUtils.h"

// Private view layout constants

static CGFloat      const kPaddingTop                       = 25.0f;
static NSString *   const kPasscodeTextFontName             = @"HelveticaNeue-Bold";
static CGFloat      const kPasscodeTextFontSize             = 29.0f;
static NSString *   const kPasscodeHelperTextFontName       = @"HelveticaNeue";
static CGFloat      const kPasscodeHelperTextFontSize       = 13.0f;
static NSUInteger   const kMaxPasscodeLength                = 8;
static CGFloat      const kControlPadding                   = 5.0f;
static CGFloat      const kTextFieldWidthPadding            = 40.0f;
static CGFloat      const kErrorLabelHeight                 = 35.0f;
static CGFloat      const kInstructionsLabelHeight          = 50.0f;
static CGFloat      const kLabelPadding                     = 10.0f;
static CGFloat      const kForgotPasscodeButtonWidth        = 150.0f;
static CGFloat      const kForgotPasscodeButtonHeight       = 40.0f;
static NSUInteger   const kPasscodeDialogTag                = 111;

@interface SFPasscodeViewController() {
    BOOL _firstPasscodeValidated;
}

/**
 * The passcode text field.
 */
@property (nonatomic, strong) UITextField *passcodeField;

/**
 * The error label displayed if something goes wrong.
 */
@property (nonatomic, strong) UILabel *errorLabel;

/**
 * The label displaying instructions for a given section of the workflow.
 */
@property (nonatomic, strong) UILabel *instructionsLabel;

/**
 * The 'Forgot Passcode' button.
 */
@property (nonatomic, strong) UIButton *forgotPasscodeButton;

/**
 * Keeps a copy of the initial passcode of the passcode creation process.
 */
@property (nonatomic, copy) NSString *initialPasscode;

/**
 * Initializes the object with the given mode and minimum passcode length.
 * @param mode The passcode mode of the controller (create, verify).
 * @param minPasscodeLength For creation, the minimum passcode length required for the passcode.
 */
- (id)initWithMode:(SFPasscodeControllerMode)mode minPasscodeLength:(NSInteger)minPasscodeLength;

/**
 * Utility method to return a random string with the given length, for text field sizing.
 */
+ (NSString *)stringWithLength:(NSUInteger)length;

/**
 * Called during creation when the first passcode has been entered.
 */
- (void)finishedInitialPasscode;

/**
 * Called during creation when the confirming passcode has been entered.
 */
- (void)finishedConfirmPasscode;

/**
 * Called during verification after the passcode to validate against the actual has been entered.
 */
- (void)finishedValidatePasscode;

/**
 * Lays out all of the view's subviews properly on the screen.
 */
- (void)layoutSubviews;

/**
 * Lays out the passcode field on the screen.
 */
- (void)layoutPasscodeField;

/**
 * Lays out the error label on the screen.
 */
- (void)layoutErrorLabel;

/**
 * Lays out the instructions label on the screen.
 */
- (void)layoutInstructionsLabel;

/**
 * Lays out the 'Forgot Passcode' button on the screen.
 */
- (void)layoutForgotPasscodeButton;

/**
 * Updates the instructions label with a new value.
 * @param newLabel The new text to be used for the instructions label.
 */
- (void)updateInstructionsLabel:(NSString *)newLabel;

/**
 * Updates the error label with new text.
 * @param newLabel The new text to be used for the error label.
 */
- (void)updateErrorLabel:(NSString *)newLabel;

/**
 * In passcode creation mode, resets the view back to its original, initial state.
 */
- (void)resetInitialCreateView;

/**
 * Sets up the navigation bar for the initial passcode creation screen.
 */
- (void)addPasscodeCreationNav;

/**
 * Sets up the navigation bar for the passcode confirmation screen of passcode creation.
 */
- (void)addPasscodeConfirmNav;

/**
 * Sets up the navigation bar for the passcode verification flow.
 */
- (void)addPasscodeVerificationNav;

/**
 * Action performed when the 'Forgot Passcode' button is clicked.
 */
- (void)forgotPassAction;

@end

@implementation SFPasscodeViewController

@synthesize passcodeField = _passcodeField;
@synthesize errorLabel = _errorLabel;
@synthesize instructionsLabel = _instructionsLabel;
@synthesize initialPasscode = _initialPasscode;
@synthesize forgotPasscodeButton = _forgotPasscodeButton;

- (id)initForPasscodeVerification
{
    return [self initWithMode:SFPasscodeControllerModeVerify minPasscodeLength:-1];
}

- (id)initForPasscodeCreation:(NSInteger)minPasscodeLength
{
    return [self initWithMode:SFPasscodeControllerModeCreate minPasscodeLength:minPasscodeLength];
}

- (id)initForPasscodeChange:(NSInteger)minPasscodeLength
{
    return [self initWithMode:SFPasscodeControllerModeChange minPasscodeLength:minPasscodeLength];
}

- (id)initWithMode:(SFPasscodeControllerMode)mode minPasscodeLength:(NSInteger)minPasscodeLength
{
    self = [super initWithMode:mode minPasscodeLength:minPasscodeLength];
    if (self) {
        if (mode == SFPasscodeControllerModeCreate || mode == SFPasscodeControllerModeChange) {
            _firstPasscodeValidated = NO;
            [self addPasscodeCreationNav];
        } else {
            [self addPasscodeVerificationNav];
        }
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)loadView
{
    [super loadView];

    // Passcode
    self.passcodeField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.passcodeField.secureTextEntry = YES;
    self.passcodeField.borderStyle = UITextBorderStyleRoundedRect;
    self.passcodeField.textColor = [UIColor blackColor];
    self.passcodeField.font = [UIFont fontWithName:kPasscodeTextFontName size:kPasscodeTextFontSize];
    [self.passcodeField setKeyboardType:UIKeyboardTypeNumberPad];
    self.passcodeField.text = @"";
    self.passcodeField.accessibilityLabel = @"Passcode";
    self.passcodeField.delegate = self;
    [self.view addSubview:self.passcodeField];

    // Error label
    self.errorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    [self.errorLabel setBackgroundColor:[UIColor clearColor]];
    self.errorLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.textColor = [UIColor redColor];
    self.errorLabel.font = [UIFont fontWithName:kPasscodeHelperTextFontName size:kPasscodeHelperTextFontSize];
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.accessibilityLabel = @"Error";
    [self.view addSubview:self.errorLabel];

    // Instructions label
    self.instructionsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    [self.instructionsLabel setBackgroundColor:[UIColor clearColor]];
    self.instructionsLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.instructionsLabel.numberOfLines = 0;
    self.instructionsLabel.textColor = [UIColor whiteColor];
    self.instructionsLabel.font = [UIFont fontWithName:kPasscodeHelperTextFontName size:kPasscodeHelperTextFontSize];
    self.instructionsLabel.textAlignment = NSTextAlignmentCenter;
    self.instructionsLabel.accessibilityLabel = @"Instructions";
    [self.view addSubview:self.instructionsLabel];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.autoresizesSubviews = YES;

    // 'Forgot Passcode' button
    self.forgotPasscodeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.forgotPasscodeButton setTitle:[SFSDKResourceUtils localizedString:@"forgotPasscodeTitle"] forState:UIControlStateNormal];
    self.forgotPasscodeButton.backgroundColor = [UIColor whiteColor];
    [self.forgotPasscodeButton.titleLabel setTextAlignment:NSTextAlignmentCenter];
    [self.forgotPasscodeButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.forgotPasscodeButton addTarget:self action:@selector(forgotPassAction) forControlEvents:UIControlEventTouchUpInside];
    self.forgotPasscodeButton.accessibilityLabel = @"Forgot Passcode?";
    self.forgotPasscodeButton.titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:15.0];
    [self.forgotPasscodeButton setHidden:YES];
    [self.view addSubview:self.forgotPasscodeButton];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self log:SFLogLevelDebug msg:@"SFPasscodeViewController viewDidLoad"];
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        [self setEdgesForExtendedLayout:UIRectEdgeNone];
    }
    [self layoutSubviews];
    if (self.mode == SFPasscodeControllerModeCreate) {
        [self updateInstructionsLabel:[SFSDKResourceUtils localizedString:@"passcodeCreateInstructions"]];
    } else if (self.mode == SFPasscodeControllerModeChange) {
        [self updateInstructionsLabel:[SFSDKResourceUtils localizedString:@"passcodeChangeInstructions"]];
    } else {
        [self updateInstructionsLabel:[SFSDKResourceUtils localizedString:@"passcodeVerifyInstructions"]];
        [self.forgotPasscodeButton setHidden:NO];
    }
}

- (void)forgotPassAction
{
    UIAlertView *logoutAlert = [[UIAlertView alloc] initWithTitle:[SFSDKResourceUtils localizedString:@"forgotPasscodeTitle"]
                                                          message:[SFSDKResourceUtils localizedString:@"logoutAlertViewTitle"]
                                                         delegate:self
                                                cancelButtonTitle:[SFSDKResourceUtils localizedString:@"logoutNo"]
                                                otherButtonTitles:[SFSDKResourceUtils localizedString:@"logoutYes"], nil];
    logoutAlert.tag = kPasscodeDialogTag;
    [self log:SFLogLevelDebug msg:@"SFPasscodeViewController forgotPassAction"];
    [logoutAlert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == kPasscodeDialogTag) {
        if (buttonIndex == 0) {
            [self log:SFLogLevelDebug msg:@"User pressed No"];
        } else {
            [self log:SFLogLevelDebug msg:@"User pressed Yes"];
            [self validatePasscodeFailed];
        }
    }
}

- (void)viewWillLayoutSubviews
{
    [self layoutSubviews];
    [super viewWillLayoutSubviews];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)layoutSubviews
{
    [self layoutPasscodeField];
    [self layoutErrorLabel];
    [self layoutInstructionsLabel];
    [self layoutForgotPasscodeButton];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    //    return (interfaceOrientation == UIInterfaceOrientationPortrait);
    return YES;
}

- (void)layoutPasscodeField
{
    NSString *maxText = [[self class] stringWithLength:kMaxPasscodeLength];
    CGSize passcodeFieldSize = [maxText sizeWithFont:self.passcodeField.font constrainedToSize:self.view.bounds.size];
    passcodeFieldSize.width += kTextFieldWidthPadding;
    
    CGFloat x = CGRectGetMidX(self.view.frame) - (passcodeFieldSize.width / 2.0);
    CGFloat y = kPaddingTop;
    CGRect passRect = CGRectMake(x, y, passcodeFieldSize.width, passcodeFieldSize.height);
    self.passcodeField.frame = passRect;
}

- (void)layoutForgotPasscodeButton
{
    CGFloat w = kForgotPasscodeButtonWidth;
    CGFloat h = kForgotPasscodeButtonHeight;
    CGFloat x = CGRectGetMidX(self.view.frame) - (self.forgotPasscodeButton.frame.size.width / 2.0);
    CGFloat y = CGRectGetMaxY(self.instructionsLabel.frame) + kControlPadding;
    self.forgotPasscodeButton.frame = CGRectMake(x, y, w, h);
    self.forgotPasscodeButton.layer.cornerRadius = 10;
    self.forgotPasscodeButton.clipsToBounds = YES;
}

- (void)layoutErrorLabel
{
    CGFloat w = self.view.bounds.size.width - (2 * kLabelPadding);
    CGFloat h = kErrorLabelHeight;
    CGFloat x = CGRectGetMidX(self.view.frame) - (w / 2.0);
    CGFloat y = CGRectGetMaxY(self.passcodeField.frame) + kControlPadding;
    self.errorLabel.frame = CGRectMake(x, y, w, h);
}

- (void)layoutInstructionsLabel
{
    CGFloat w = self.view.bounds.size.width - (2 * kLabelPadding);
    CGFloat h = kInstructionsLabelHeight;
    CGFloat x = CGRectGetMidX(self.view.frame) - (w / 2.0);
    CGFloat y = CGRectGetMaxY(self.errorLabel.frame) + kControlPadding;
    self.instructionsLabel.frame = CGRectMake(x, y, w, h);
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
    if (self.passcodeField.text.length < self.minPasscodeLength) {
        self.errorLabel.text = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"minPasscodeLengthError"], self.minPasscodeLength];
    } else {
        self.initialPasscode = self.passcodeField.text;
        [self.passcodeField resignFirstResponder];
        self.passcodeField.text = @"";
        [self updateErrorLabel:@""];
        [self updateInstructionsLabel:[SFSDKResourceUtils localizedString:@"passcodeConfirmInstructions"]];
        _firstPasscodeValidated = YES;
        [self addPasscodeConfirmNav];
    }
}

- (void)finishedConfirmPasscode
{
    if (self.passcodeField.text.length < self.minPasscodeLength) {
        self.errorLabel.text = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"minPasscodeLengthError"], self.minPasscodeLength];
    } else if (![self.passcodeField.text isEqualToString:self.initialPasscode]) {
        [self resetInitialCreateView];
        [self updateErrorLabel:[SFSDKResourceUtils localizedString:@"passcodesDoNotMatchError"]];
    } else {
        // Set new passcode.
        [self.passcodeField resignFirstResponder];
        [self createPasscodeConfirmed:self.passcodeField.text];
    }
}

- (void)finishedValidatePasscode
{
    NSString *checkPasscode = [self.passcodeField text];
    if ([[SFPasscodeManager sharedManager] verifyPasscode:checkPasscode]) {
        [self validatePasscodeConfirmed:checkPasscode];
    } else {
        if ([self decrementPasscodeAttempts]) {
            self.passcodeField.text = @"";
            [self updateErrorLabel:[SFSDKResourceUtils localizedString:@"passcodeInvalidError"]];
        }
    }
}

- (void)updateInstructionsLabel:(NSString *)newLabel
{
    self.instructionsLabel.text = newLabel;
    [self.instructionsLabel setNeedsDisplay];
}

- (void)updateErrorLabel:(NSString *)newLabel
{
    self.errorLabel.text = newLabel;
    [self.errorLabel setNeedsDisplay];
}

- (void)resetInitialCreateView
{
    _firstPasscodeValidated = NO;
    self.initialPasscode = nil;
    self.passcodeField.text = @"";
    [self.passcodeField resignFirstResponder];
    [self updateInstructionsLabel:[SFSDKResourceUtils localizedString:@"passcodeCreateInstructions"]];
    [self updateErrorLabel:@""];
    [self addPasscodeCreationNav];
}

- (void)addPasscodeCreationNav
{
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithTitle:[SFSDKResourceUtils localizedString:@"nextScreenNavButtonTitle"]
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:@selector(finishedInitialPasscode)];
    [self.navigationItem setRightBarButtonItem:bbi];
    [self.navigationItem setLeftBarButtonItem:nil];
    [self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"createPasscodeNavTitle"]];
}

- (void)addPasscodeConfirmNav
{
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                         target:self
                                                                         action:@selector(finishedConfirmPasscode)];
    [self.navigationItem setRightBarButtonItem:bbi];
    
    bbi = [[UIBarButtonItem alloc] initWithTitle:[SFSDKResourceUtils localizedString:@"prevScreenNavButtonTitle"]
                                           style:UIBarButtonItemStylePlain
                                          target:self
                                          action:@selector(resetInitialCreateView)];
    [self.navigationItem setLeftBarButtonItem:bbi];
    [self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"confirmPasscodeNavTitle"]];
}

- (void)addPasscodeVerificationNav
{
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                         target:self
                                                                         action:@selector(finishedValidatePasscode)];
    [self.navigationItem setRightBarButtonItem:bbi];
    [self.navigationItem setLeftBarButtonItem:nil];
    [self.navigationItem setTitle:[SFSDKResourceUtils localizedString:@"verifyPasscodeNavTitle"]];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.passcodeField) {
        if (self.mode == SFPasscodeControllerModeCreate) {
            if (!_firstPasscodeValidated) {
                [self finishedInitialPasscode];
            } else {
                [self finishedConfirmPasscode];
            }
        } else {
            [self finishedValidatePasscode];
        }
        return NO;
    }
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (textField == self.passcodeField) {
        NSUInteger newLength = [textField.text length] + [string length] - range.length;
        return (newLength > kMaxPasscodeLength) ? NO : YES;
    }
    
    return YES;
}


@end
