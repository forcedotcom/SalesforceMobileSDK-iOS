//
//  SFPasscodeViewController.m
//  CustomViews
//
//  Created by Kevin Hawkins on 5/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SFPasscodeViewController.h"

static CGFloat      const kPaddingTop                       = 75.0f;
static NSString *   const kPasscodeTextFontName             = @"HelveticaNeue-Bold";
static CGFloat      const kPasscodeTextFontSize             = 29.0f;
static NSString *   const kPasscodeHelperTextFontName       = @"HelveticaNeue";
static CGFloat      const kPasscodeHelperTextFontSize       = 13.0f;
static NSUInteger   const kMaxPasscodeLength                = 8;
static CGFloat      const kControlPadding                   = 5.0f;
static CGFloat      const kTextFieldWidthPadding            = 40.0f;
static CGFloat      const kSquareButtonSize                 = 40.0f;
static CGFloat      const kErrorLabelHeight                 = 35.0f;
static CGFloat      const kInstructionsLabelHeight          = 75.0f;
static CGFloat      const kLabelPadding                     = 10.0f;

// In SFSecurityLockout.h
static NSUInteger   const kMaxNumberofAttempts              = 10;
static NSString *   const kRemainingAttemptsKey             = @"remainingAttempts"; 

// TODO: Localization
static NSString *         nextScreenNavButtonTitle          = @"Next";
static NSString *         prevScreenNavButtonTitle          = @"Back";
static NSString *         createPasscodeNavTitle            = @"Create Passcode";
static NSString *         confirmPasscodeNavTitle           = @"Confirm Passcode";
static NSString *         verifyPasscodeNavTitle            = @"Verify Passcode";
static NSString *         passcodeCreateInstructions        = @"For increased security, please create a passcode that you will use to access Salesforce when the session has timed out due to inactivity.";
static NSString *         passcodeConfirmInstructions       = @"Confirm the passcode you just entered.";
static NSString *         passcodeVerifyInstructions        = @"Please enter your security passcode.";
static NSString *         minPasscodeLengthError            = @"Your passcode must be at least %d characters long.";
static NSString *         passcodesDoNotMatchError          = @"Passcodes do not match!";
static NSString *         passcodeInvalidError              = @"The passcode you entered was invalid.";

@interface SFPasscodeViewController() {
    BOOL _firstPasscodeValidated;
    NSInteger _attempts;
}

@property (nonatomic, retain) UILabel *headerLabel;
@property (nonatomic, retain) UITextField *passcodeField;
@property (nonatomic, retain) UILabel *errorLabel;
@property (nonatomic, retain) UIButton *continueButton;
@property (nonatomic, retain) UILabel *instructionsLabel;
@property (nonatomic, copy) NSString *initialPasscode;

+ (NSString *)stringWithLength:(NSUInteger)length;
- (void)finishedInitialPasscode;
- (void)finishedConfirmPasscode;
- (void)finishedValidatePasscode;
- (void)layoutSubviews;
- (void)layoutPasscodeField;
- (void)layoutErrorLabel;
- (void)layoutInstructionsLabel;
- (void)updateInstructionsLabel:(NSString *)newLabel;
- (void)updateErrorLabel:(NSString *)newLabel;
- (void)resetInitialCreateView;
- (NSInteger)remainingAttempts;
- (void)setRemainingAttempts:(NSUInteger)remainingAttempts;
- (void)addPasscodeCreationNav;
- (void)addPasscodeConfirmNav;
- (void)addPasscodeVerificationNav;

@end

@implementation SFPasscodeViewController

@synthesize mode = _mode;
@synthesize minPasscodeLength = _minPasscodeLength;
@synthesize headerLabel = _headerLabel;
@synthesize passcodeField = _passcodeField;
@synthesize errorLabel = _errorLabel;
@synthesize continueButton = _continueButton;
@synthesize instructionsLabel = _instructionsLabel;
@synthesize initialPasscode = _initialPasscode;

- (id)initWithMode:(SFPasscodeControllerMode)mode
{
    NSAssert(mode != SFPasscodeControllerModeCreate, @"You must specify a pin code length when creating a pin code.");
    return [self initWithMode:mode minPasscodeLength:-1];
}

- (id)initWithMode:(SFPasscodeControllerMode)mode minPasscodeLength:(NSInteger)minPasscodeLength
{
    self = [super init];
    if (self) {
        _mode = mode;
        _minPasscodeLength = minPasscodeLength;
        if (mode == SFPasscodeControllerModeCreate) {
            NSAssert(_minPasscodeLength > 0, @"You must specify a positive pin code length when creating a pin code.");
            
            _firstPasscodeValidated = NO;
            [self addPasscodeCreationNav];
        } else {
            _attempts = [self remainingAttempts];
            if (0 == _attempts) {
                _attempts = kMaxNumberofAttempts;
                [self setRemainingAttempts:_attempts];
            }
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
    self.passcodeField = [[[UITextField alloc] initWithFrame:CGRectZero] autorelease];
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
    self.errorLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    [self.errorLabel setBackgroundColor:[UIColor clearColor]];
    self.errorLabel.lineBreakMode = UILineBreakModeWordWrap;
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.textColor = [UIColor redColor];
    self.errorLabel.font = [UIFont fontWithName:kPasscodeHelperTextFontName size:kPasscodeHelperTextFontSize];
    self.errorLabel.textAlignment = UITextAlignmentCenter;
    self.errorLabel.accessibilityLabel = @"Error";
    [self.view addSubview:self.errorLabel];
    
    // Instructions label
    self.instructionsLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    [self.instructionsLabel setBackgroundColor:[UIColor clearColor]];
    self.instructionsLabel.lineBreakMode = UILineBreakModeWordWrap;
    self.instructionsLabel.numberOfLines = 0;
    self.instructionsLabel.textColor = [UIColor whiteColor];
    self.instructionsLabel.font = [UIFont fontWithName:kPasscodeHelperTextFontName size:kPasscodeHelperTextFontSize];
    self.instructionsLabel.textAlignment = UITextAlignmentCenter;
    self.instructionsLabel.accessibilityLabel = @"Instructions";
    [self.view addSubview:self.instructionsLabel];
    
    
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.autoresizesSubviews = YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"SFPasscodeViewController viewDidLoad");
    [self layoutSubviews];
    if (self.mode == SFPasscodeControllerModeCreate)
        [self updateInstructionsLabel:passcodeCreateInstructions];
    else
        [self updateInstructionsLabel:passcodeVerifyInstructions];
}

- (void)viewWillLayoutSubviews {
    [self layoutSubviews];
    [super viewWillLayoutSubviews];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)layoutSubviews {
    [self layoutPasscodeField];
    [self layoutErrorLabel];
    [self layoutInstructionsLabel];
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
        self.errorLabel.text = [NSString stringWithFormat:minPasscodeLengthError, self.minPasscodeLength];
    } else {
        self.initialPasscode = self.passcodeField.text;
        [self.passcodeField resignFirstResponder];
        self.passcodeField.text = @"";
        [self updateErrorLabel:@""];
        [self updateInstructionsLabel:passcodeConfirmInstructions];
        _firstPasscodeValidated = YES;
        [self addPasscodeConfirmNav];
    }
}

- (void)finishedConfirmPasscode
{
    if (self.passcodeField.text.length < self.minPasscodeLength) {
        self.errorLabel.text = [NSString stringWithFormat:minPasscodeLengthError, self.minPasscodeLength];
    } else if (![self.passcodeField.text isEqualToString:self.initialPasscode]) {
        [self resetInitialCreateView];
        [self updateErrorLabel:passcodesDoNotMatchError];
    } else {
        // Set new passcode.
    }
}

- (void)finishedValidatePasscode
{
    NSLog(@"Code to validate passcode goes here!");
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
    [self updateInstructionsLabel:passcodeCreateInstructions];
    [self updateErrorLabel:@""];
    [self addPasscodeCreationNav];
}

- (NSInteger)remainingAttempts {
    return [[NSUserDefaults standardUserDefaults] integerForKey:kRemainingAttemptsKey];
}

- (void)setRemainingAttempts:(NSUInteger)remainingAttempts {
    [[NSUserDefaults standardUserDefaults] setInteger:remainingAttempts forKey:kRemainingAttemptsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)addPasscodeCreationNav
{
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithTitle:nextScreenNavButtonTitle
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:@selector(finishedInitialPasscode)];
    [self.navigationItem setRightBarButtonItem:bbi];
    [bbi release];
    [self.navigationItem setLeftBarButtonItem:nil];
    [self.navigationItem setTitle:createPasscodeNavTitle];
}

- (void)addPasscodeConfirmNav
{
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                         target:self
                                                                         action:@selector(finishedConfirmPasscode)];
    [self.navigationItem setRightBarButtonItem:bbi];
    [bbi release];
    
    bbi = [[UIBarButtonItem alloc] initWithTitle:prevScreenNavButtonTitle
                                           style:UIBarButtonItemStylePlain
                                          target:self
                                          action:@selector(resetInitialCreateView)];
    [self.navigationItem setLeftBarButtonItem:bbi];
    [bbi release];
    [self.navigationItem setTitle:confirmPasscodeNavTitle];
}

- (void)addPasscodeVerificationNav
{
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                         target:self
                                                                         action:@selector(finishedValidatePasscode)];
    [self.navigationItem setRightBarButtonItem:bbi];
    [bbi release];
    [self.navigationItem setLeftBarButtonItem:nil];
    [self.navigationItem setTitle:verifyPasscodeNavTitle];
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
