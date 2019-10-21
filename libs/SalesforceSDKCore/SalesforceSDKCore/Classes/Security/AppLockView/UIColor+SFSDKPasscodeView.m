/*
 UIColor+SFSDKPasscodeView.m
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

#import "UIColor+SFSDKPasscodeView.h"

@implementation UIColor (SFSDKPasscodeView)

+ (UIColor *)passcodeViewBackgroundColor {
    UIColor *lightStyleColor = [UIColor colorWithRed:245.0f/255.0f green:246.0f/255.0f blue:250.0f/255.0f alpha:1.0f];
    if (@available(iOS 13.0, *)) {
        return [[UIColor alloc] initWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:8.0f/255.0f green:7.0f/255.0f blue:7.0f/255.0f alpha:1.0f];
            } else {
                return lightStyleColor;
            }
        }];
    }
    return lightStyleColor;
}

+ (UIColor *)passcodeViewSecondaryBackgroundColor {
    UIColor *lightStyleColor = [UIColor whiteColor];
    if (@available(iOS 13.0, *)) {
        return [[UIColor alloc] initWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:43.0f/255.0f green:40.0f/255.0f blue:38.0f/255.0f alpha:1.0f];
            } else {
                return lightStyleColor;
            }
        }];
    }
    return lightStyleColor;
}

+ (UIColor *)passcodeViewTextColor {
    UIColor *lightStyleColor = [UIColor colorWithRed:22.0f/255.0f green:50.0f/255.0f blue:92.0f/255.0f alpha:1.0f];
    if (@available(iOS 13.0, *)) {
        return [[UIColor alloc] initWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:240.0f/255.0f green:240.0f/255.0f blue:240.0f/255.0f alpha:1.0f];
            } else {
                return lightStyleColor;
            }
        }];
    }
    return lightStyleColor;
}

+ (UIColor *)passcodeViewBorderColor {
    UIColor *lightStyleColor = [UIColor colorWithRed:217.0f/255.0f green:221.0f/255.0f blue:230.0f/255.0f alpha:1.0f];
    if (@available(iOS 13.0, *)) {
        return [[UIColor alloc] initWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:62.0f/255.0f green:62.0f/255.0f blue:60.0f/255.0f alpha:1.0f];
            } else {
                return lightStyleColor;
            }
        }];
    }
    return lightStyleColor;
}

+ (UIColor *)passcodeViewNavBarColor {
    UIColor *lightStyleColor = [UIColor whiteColor];
    if (@available(iOS 13.0, *)) {
        return [[UIColor alloc] initWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:43.0f/255.0f green:40.0f/255.0f blue:38.0f/255.0f alpha:1.0f];
            } else {
                return lightStyleColor;
            }
        }];
    }
    return lightStyleColor;
}

@end

