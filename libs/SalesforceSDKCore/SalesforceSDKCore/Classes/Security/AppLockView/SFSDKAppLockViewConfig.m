/*
 SFSDKAppLockViewConfig.m
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

#import "SFSDKAppLockViewConfig.h"
#import "UIColor+SFColors.h"
#import "SFSDKResourceUtils.h"
#import "SFSecurityLockout+Internal.h"

@implementation SFSDKAppLockViewConfig

-(instancetype) init {
    
    if(self = [super init]) {
        self.navBarColor = [UIColor passcodeViewNavBarColor];
        self.navBarTintColor = [UIColor passcodeViewNavBarColor];
        self.navBarTitleColor = [UIColor passcodeViewTextColor];
        self.navBarFont = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
        _maxNumberOfAttempts = (NSUInteger)10;
        _primaryColor = [UIColor salesforceBlueColor];
        _secondaryColor = [UIColor whiteColor];
        _backgroundColor = [UIColor passcodeViewBackgroundColor];
        _secondaryBackgroundColor = [UIColor passcodeViewSecondaryBackgroundColor];
        _borderColor = [UIColor passcodeViewBorderColor];
        _instructionTextColor = [UIColor passcodeViewTextColor];
        _titleTextColor = [UIColor passcodeViewTextColor];
        _logoutButtonColor = _primaryColor;
        _instructionFont = [UIFont systemFontOfSize:14];
        _titleFont = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        _buttonFont = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        _touchIdImage = [SFSDKResourceUtils imageNamed:@"touchId"];
        _faceIdImage = [SFSDKResourceUtils imageNamed:@"faceId"];
    }
    return self;
}

+ (instancetype)createDefaultConfig {
    return [[self alloc] init];
}

@end
