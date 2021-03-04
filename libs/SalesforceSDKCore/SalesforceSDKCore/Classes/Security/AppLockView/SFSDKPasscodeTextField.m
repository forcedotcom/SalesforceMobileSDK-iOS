/*
 SFSDKPasscodeTextField.m
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

#import "SFSDKPasscodeTextField.h"
#import "SFSecurityLockout+Internal.h"
#import "UIColor+SFColors.h"

static CGFloat      const kDefaultLineWidth                  = 1;
static NSUInteger   const kMaxPasscodeLength                 = 8;
static CGFloat      const kDefaultPadding                    = 20.f;
static CGFloat      const kPasscodeCircleSpacing             = 16.f;
// Because of the outline weight, a value of 22 is need to make a circle with diameter 24.
static CGFloat      const kPasscodeCircleDiameter            = 22.f;

@interface SFSDKPasscodeTextField()
@property (nonatomic, strong) UIColor * fillColor;
@property (nonatomic,strong) NSMutableArray *subLayerRefs;
@property (nonatomic, strong) SFSDKAppLockViewConfig *viewConfig;
@end

@implementation SFSDKPasscodeTextField

- (instancetype)init
{
    return [super init];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame andViewConfig:[SFSDKAppLockViewConfig createDefaultConfig]];
}

- (instancetype)initWithFrame:(CGRect)frame andViewConfig:(SFSDKAppLockViewConfig *)config
{
    if (self = [super initWithFrame:frame]) {
        _subLayerRefs = [[NSMutableArray alloc] init];
        _passcodeLength = [SFSecurityLockout passcodeLength];
        _passcodeLengthKnown = ([SFSecurityLockout passcodeLength] != 0);
        _viewConfig = config;
        self.keyboardType = UIKeyboardTypeNumberPad;
        self.backgroundColor = config.secondaryBackgroundColor;
        self.tintColor = [UIColor clearColor];
        self.borderStyle = UITextBorderStyleNone;
        self.fillColor = config.primaryColor;
        self.textColor = config.secondaryColor;
        [self updateLayerColor];
    }
    return self;
}

- (void)updateLayerColor {
    self.layer.borderColor = self.viewConfig.borderColor.CGColor;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self updateLayerColor];
    }
}

- (void)clearPasscode {
    self.passcodeInput = [NSMutableString stringWithString:@""];
}

- (void)deleteBackward
{
    if (self.passcodeInput.length < 1) {
        return;
    }
    [self.passcodeInput deleteCharactersInRange:NSMakeRange([self.passcodeInput length]-1, 1)];
    [self refreshView];
    if (self.deleteDelegate) {
        [self.deleteDelegate deleteBackward];
    }
}

- (void)refreshView
{
    [self resetLayers];
    [self.subLayerRefs removeAllObjects];
    int diameter = kPasscodeCircleDiameter;
    int horizontalSpacing = kPasscodeCircleSpacing;
    int openCircleSpacingX = 0;
    int filledCircleSpacingX = 0;
    NSUInteger lengthForSpacing = (self.passcodeLengthKnown) ? self.passcodeLength : kMaxPasscodeLength;
    int positionY = -1 * ((diameter + (kDefaultLineWidth * 2)) / 2);  // Have to add outline line width to diameter
    int startX = (self.bounds.size.width - (diameter * lengthForSpacing) - (horizontalSpacing * (lengthForSpacing - 1))) / 2;
    
    if (self.passcodeLengthKnown) {
        // Draw open cirlces
        for (int count=0 ; count < self.passcodeLength; count++) {
            CAShapeLayer *openCircle = [CAShapeLayer layer];
            // Make a circular shape
            openCircle.path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, positionY, diameter, diameter)cornerRadius:diameter].CGPath;
            // Center the shape in self.view
            openCircle.position = CGPointMake(startX + openCircleSpacingX, diameter + (kDefaultLineWidth * 4));
            openCircle.fillColor = [UIColor clearColor].CGColor;
            openCircle.strokeColor = self.fillColor.CGColor;
            openCircle.lineWidth = kDefaultLineWidth * 2;
            openCircle.zPosition = 5;
            openCircleSpacingX += (diameter + horizontalSpacing);
            [self.subLayerRefs addObject:openCircle];
            [self.layer addSublayer:openCircle];
        }
    } else {
        startX = (startX > kDefaultPadding) ? kDefaultPadding : startX;
    }
    
    // Draw typed circles
    NSUInteger noOfChars = [self.passcodeInput length];
    for (int count=0 ; count < noOfChars; count++) {
        CAShapeLayer *filledCircle = [CAShapeLayer layer];
        // Make a circular shape
        filledCircle.path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, positionY, diameter, diameter)cornerRadius:diameter].CGPath;
        
        // Center the shape in self.view
        filledCircle.position = CGPointMake(startX + filledCircleSpacingX, diameter + (kDefaultLineWidth * 4));
        filledCircle.fillColor = self.fillColor.CGColor;
        filledCircle.strokeColor = self.fillColor.CGColor;
        filledCircle.lineWidth = kDefaultLineWidth;
        filledCircle.zPosition = 5;
        filledCircleSpacingX += (diameter + horizontalSpacing);
        [self.subLayerRefs addObject:filledCircle];
        [self.layer addSublayer:filledCircle];
    }
   
    [self.layer setNeedsLayout];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self isFirstResponder]) {
            [self becomeFirstResponder];
        }
    });
}

// Disable paste or other interactions
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    return NO;
}

- (void)resetLayers {
    [self.subLayerRefs enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        CALayer* sublayer = (CALayer*) obj;
        [sublayer removeFromSuperlayer];
    }];
}

- (NSMutableArray *)subLayerRefs {
    if (_subLayerRefs==nil) {
        _subLayerRefs = [[NSMutableArray alloc] init];
    }
    return _subLayerRefs;
}

- (void)accessibilityElementDidBecomeFocused {
    [self setText:self.passcodeInput];
}

@end
