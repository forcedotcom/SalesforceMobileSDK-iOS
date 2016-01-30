/*
 SFAppStyler.m
 SalesforceSDKCore
 
 Created by Kunal Chitalia on 1/22/16.
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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

#import "SFAppStyler.h"

@interface SFAppStyler ()

@property (nonatomic, strong) NSMutableDictionary *fontMap;

@end

@implementation SFAppStyler

+(instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static SFAppStyler *styler = nil;
    dispatch_once(&onceToken, ^{
        styler = [[self alloc] init];
    });
    return styler;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _fontMap = [[NSMutableDictionary alloc] init];
        
        // default values
        _titleColor = [UIColor colorWithRed:0.024 green:0.110 blue:0.245 alpha:1.0];
        _primaryAppColor = [UIColor colorWithRed:22.0/255.0 green:87.0/255.0 blue:205/255.0 alpha:1.0];
        _actionableTextColor = [UIColor colorWithRed:0.333 green:0.525 blue:0.937 alpha:1.0];
        _headerTextColor = [UIColor whiteColor];
        _primaryTextColor = [UIColor blackColor];
        _toolbarTextColor = nil;
        _toolbarTextFont = nil;
        [self updateDefaultSize];
    }
    return self;
}

- (void)updateDefaultSize {
    self.headerFont =  [self fontWithSize:16.0 style:SFAppStylerFontStyleBold];
    self.primaryTextFont = [self fontWithSize:14.0 style:SFAppStylerFontStyleRegular];
    self.actionableFont = [self fontWithSize:14.0 style:SFAppStylerFontStyleRegular];
}

- (void)setFontName:(NSString * _Nullable)fontName forStyle:(SFAppStylerFontStyle)style {
    if (fontName) {
        self.fontMap[@(style)] = fontName;
    } else {
        [self.fontMap removeObjectForKey:@(style)];
    }
    [self updateDefaultSize];
}

- ( UIFont * _Nonnull )fontWithSize:(CGFloat)fontSize style:(SFAppStylerFontStyle)style {
    NSString *fontToUse = self.fontMap[@(style)];
    if (fontToUse) {
        return [UIFont fontWithName:fontToUse size:fontSize];
    } else {
        switch (style) {
            case SFAppStylerFontStyleBold:
                return [UIFont boldSystemFontOfSize:fontSize];
                break;
            default:
                return [UIFont systemFontOfSize:fontSize];
                break;
        }
    }
}

#pragma mark - Styling Methods

- (nonnull UIImage *)headerBackgroundImage {
    UIImage *backgroundImage = [[self class] imageFromColor:self.primaryAppColor];
    return backgroundImage;
}

- (void)styleNavigationBar:(UINavigationBar *)navigationBar {
    if (!navigationBar) {
        return;
    }
    if (self.headerTextColor) {
        navigationBar.tintColor = self.headerTextColor;
    }
    if (self.primaryAppColor) {
        UIImage *backgroundImage = [self headerBackgroundImage];
        [navigationBar setBackgroundImage:backgroundImage forBarMetrics:UIBarMetricsDefault];
    }
    if (self.headerTextColor && self.headerFont) {
        [navigationBar setTitleTextAttributes:@{ NSForegroundColorAttributeName: self.headerTextColor,
                                                 NSFontAttributeName: self.headerFont}];
    }
}

- (void)styleBarButtonItems:(nullable NSArray<UIBarButtonItem *> *)barItems {
    if (!barItems) {
        return;
    }
    if (self.toolbarTextColor && self.toolbarTextFont) {
        NSDictionary *textAttributes = @{ NSForegroundColorAttributeName: self.toolbarTextColor,
                                          NSFontAttributeName: self.toolbarTextFont};
        for (UIBarButtonItem *buttonItem in barItems) {
            [buttonItem setTitleTextAttributes:textAttributes forState:UIControlStateNormal];
        }
    }
}

- (void)styleActionableLabel:(UILabel *)label {
    if (self.actionableFont && self.actionableTextColor) {
        label.font = self.actionableFont;
        label.textColor = self.actionableTextColor;
        label.textAlignment = NSTextAlignmentCenter;
    }
}

- (void)styleActionableButton:(UIButton *)button {
    if (self.actionableFont && self.actionableTextColor) {
        [self styleActionableLabel:button.titleLabel];
    }
}

#pragma mark - Table Header Methods

- (UIView *)customFooterViewWithText:(NSString *)text textColor:(UIColor *)textColor limitedToSize:(CGSize)maxSize {
    static UIEdgeInsets const kFooterViewEdgeInsets = {5.0, 17.0, 10.0, 17.0};
    return [self customHeaderFooterViewWithText:text textColor:(UIColor *)textColor font:nil limitedToSize:maxSize withEdgeInsets:kFooterViewEdgeInsets];
}

- (UIView *)customHeaderViewWithText:(NSString *)text textColor:(UIColor *)textColor limitedToSize:(CGSize)maxSize {
    return [self customHeaderViewWithText:text textColor:textColor font:nil limitedToSize:maxSize];
}

- (UIView *)customHeaderViewWithText:(NSString *)text textColor:(UIColor *)textColor font:(UIFont *)font limitedToSize:(CGSize)maxSize {
    static UIEdgeInsets const kHeaderViewEdgeInsets = {20.0, 17.0, 5.0, 17.0};
    return [self customHeaderFooterViewWithText:text textColor:textColor font:font limitedToSize:maxSize withEdgeInsets:kHeaderViewEdgeInsets];
}

- (UIView *)customHeaderFooterViewWithText:(NSString * _Nullable)text textColor:(UIColor * _Nullable)textColor font:(UIFont * _Nullable)font limitedToSize:(CGSize)maxSize withEdgeInsets:(UIEdgeInsets)edgeInsets {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(edgeInsets.left, edgeInsets.top, maxSize.width - (edgeInsets.left + edgeInsets.right), maxSize.height)];
    label.text = text;
    label.font = [self fontWithSize:14.0 style:SFAppStylerFontStyleRegular];
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.numberOfLines = 0;
    label.textColor = [self primaryTextColor];
    
    if (textColor) {
        label.textColor = textColor;
    }
    if (font) {
        label.font = font;
    }
    [label sizeToFit];
    
    CGFloat height = label.frame.size.height + edgeInsets.top + edgeInsets.bottom;
    if (height > maxSize.height && edgeInsets.top > edgeInsets.bottom) {
        // If label won't fit with the given max height, move it up as much as necessary (only applicable for header).
        CGFloat difference = height - maxSize.height;
        CGRect frame = label.frame;
        frame.origin.y -= difference;
        label.frame = frame;
    }
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, maxSize.width, MIN(height, maxSize.height))];
    [view addSubview:label];
    
    return view;
}


#pragma mark - Private Helper Methods

+ (UIImage *)imageFromColor:(UIColor *)color {
    CGRect rect = CGRectMake(0, 0, 1, 1);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end

