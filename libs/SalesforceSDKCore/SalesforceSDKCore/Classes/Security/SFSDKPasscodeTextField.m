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
#import "UIColor+SFSDKPasscodeView.h"
#import "SFSDKPasscodeViewConfig.h"

static NSUInteger   const kMaxPasscodeLength                 = 8;
static CGFloat      const kDefaultPadding                    = 20.0f;
static CGFloat      const kPasscodeCircleDiameter            = 24.f;
static CGFloat      const kPasscodeCircleSpacing             = 16.f;

@interface SFSDKPasscodeTextField()

@property (nonatomic, strong) UIColor * fillColor;

@end
@implementation SFSDKPasscodeTextField

- (instancetype)init {
    if (self = [super init]) {
        
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame andLength:(NSUInteger)length{
    if (self = [super initWithFrame:frame]) {
        SFSDKPasscodeViewConfig *config = [SFSDKPasscodeViewConfig createDefaultConfig];
        
        _passcodeLength = length;
        _passcodeLengthKnown = (length != 0);
        self.keyboardType = UIKeyboardTypeNumberPad;
        self.backgroundColor = config.secondaryColor;
        self.tintColor = [UIColor clearColor];
        self.borderStyle = UITextBorderStyleNone;
        self.layer.borderColor = config.borderColor.CGColor;
        self.fillColor = config.primaryColor;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame andLength:(NSUInteger)length andViewConfig:(SFSDKPasscodeViewConfig *)config{
    if (self = [super initWithFrame:frame]) {
        _passcodeLength = length;
        _passcodeLengthKnown = (length != 0);
        self.keyboardType = UIKeyboardTypeNumberPad;
        self.backgroundColor = config.secondaryColor;
        self.tintColor = [UIColor clearColor];
        self.borderStyle = UITextBorderStyleNone;
        self.layer.borderColor = config.borderColor.CGColor;
        self.fillColor = config.primaryColor;
    }
    return self;
}

- (void)clearPasscode {
    self.passcodeInput = [NSMutableString stringWithString:@""];
    //[self updatePasscode];
}

- (void)deleteBackward {
    if (self.passcodeInput.length < 1) {
        return;
    }
    [self.passcodeInput deleteCharactersInRange:NSMakeRange([self.passcodeInput length]-1, 1)];
    [self refreshView];
    if (self.deleteDelegate) {
        [self.deleteDelegate deleteBackward];
    }
}

- (void)refreshViewWithCompletion:(void (^) (void))completionBlock {
    [self refreshView];
   
}

- (void)refreshView {
    self.layer.sublayers = nil;
    int diameter = kPasscodeCircleDiameter;
    int horizontalSpacing = kPasscodeCircleSpacing;
    int OpenCircleSpacingX = 0;
    int filledCircleSpacingX = 0;
    NSUInteger lengthForSpacing = (self.passcodeLengthKnown) ? self.passcodeLength : kMaxPasscodeLength;
    int startX = (self.bounds.size.width - (diameter * lengthForSpacing) - (horizontalSpacing * (lengthForSpacing - 1))) / 2;
    
    if (self.passcodeLengthKnown) {
        // Draw open cirlces
        for (int count=0 ; count < self.passcodeLength; count++) {
            CAShapeLayer *openCircle = [CAShapeLayer layer];
            // Make a circular shape
            openCircle.path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, -12, diameter, diameter)cornerRadius:diameter].CGPath;
            // Center the shape in self.view
            openCircle.position = CGPointMake(startX + OpenCircleSpacingX, diameter);
            openCircle.fillColor = [UIColor clearColor].CGColor;
            openCircle.strokeColor = self.fillColor.CGColor;
            openCircle.lineWidth = 2;
            openCircle.zPosition = 5;
            OpenCircleSpacingX += (diameter + horizontalSpacing);
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
        filledCircle.path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, -12, diameter, diameter)cornerRadius:diameter].CGPath;
        
        // Center the shape in self.view
        filledCircle.position = CGPointMake(startX + filledCircleSpacingX, diameter);
        filledCircle.fillColor = self.fillColor.CGColor;
        filledCircle.strokeColor = self.fillColor.CGColor;
        filledCircle.lineWidth = 1;
        filledCircle.zPosition = 5;
        filledCircleSpacingX += (diameter + horizontalSpacing);
        [self.layer addSublayer:filledCircle];
    }
    [self setNeedsLayout];
}

// Disable paste or other interactions
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    return NO;
}

@end
