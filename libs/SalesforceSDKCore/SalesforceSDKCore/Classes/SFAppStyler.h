/*
 SFAppStyler.h
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, SFAppStylerFontStyle)  {
    SFAppStylerFontStyleRegular = 0,
    SFAppStylerFontStyleBold
};

/** Class responsible for app to set overall app style. All UI classes from SFFoundationSDK uses this class
 to style relevant UI elementes
 */
@interface SFAppStyler : NSObject

/** Get a shared singleton of `SFAppStyler` class
 */
+(nonnull instancetype)sharedInstance;

/** Specify the font to use for navigation bar header text
 
 If header font is not specified, font size of 16.0 of bold font will be used. You can use `[setFontName:forStyle]` method to override the font to use for bold text
 */
@property (nonatomic, strong, nullable) UIFont * headerFont;

/** Specify the text color to use for navigation bar header text */
@property (nonatomic, strong, nullable) UIColor * headerTextColor;

/** Specify primary app color. This color will be used by
 - login view header
 - setting screen theme color
 */
@property (nonatomic, strong, nullable) UIColor *primaryAppColor;

/** Specify the color to use for the title */
@property (nonatomic, strong, nullable) UIColor *titleColor;

/** Specify the font to use for the primary text font
 
 If header font is not specified, font size of 14.0 of regular font will be used. You can use `[setFontName:forStyle]` method to override the font to use for regular text
 */
@property (nonatomic, strong, nullable) UIFont *primaryTextFont;

/** Specify the color to use for the primary text */
@property (nonatomic, strong, nullable) UIColor *primaryTextColor;

/** Specify the font to use for the toolbar text
 
 If toolbarTextFont is not specified, font size of 14.0 of regular font will be used. You can use `[setFontName:forStyle]` method to override the font to use for regular text
 */
@property (nonatomic, strong, nullable) UIFont *toolbarTextFont;

/** Specify the color to use for the toolbar text */
@property (nonatomic, strong, nullable) UIColor *toolbarTextColor;

/** Specify the font to use for the actionable text
 
 If actionableFont is not specified, font size of 14.0 of regular font will be used. You can use `[setFontName:forStyle]` method to override the font to use for regular text
 */
@property (nonatomic, strong, nullable) UIFont *actionableFont;

/** Specify the color to use for the actionable text */
@property (nonatomic, strong, nullable) UIColor *actionableTextColor;

/** Return image to use for header bar. this image will be generated from the `primaryAppColor` */
- (nonnull UIImage *)headerBackgroundImage;

/** Apply style to navigation bar */
- (void)styleNavigationBar:(nullable UINavigationBar *)navigationBar;

/** Apply style to bar button items
 
 @param barItems array of `UIBarButtonItem` to apply style to
 */
- (void)styleBarButtonItems:(nullable NSArray<UIBarButtonItem *> *)barItems;

/** Apply actionable label
 
 @param label UILabel object to apply style to
 */
- (void)styleActionableLabel:(nullable UILabel *)label;

/** Apply actionable button
 
 @param button UIButton object to apply style to
 */
- (void)styleActionableButton:(nullable UIButton *)button;

/** Set the font name to use for a given font style
 
 @param fontName Name of the font to use
 @param style Style to apply font to
 */
- (void)setFontName:(nullable NSString *)fontName forStyle:(SFAppStylerFontStyle)style;

/** Returns font for a given size using the primary font name
 
 @param fontSize Size of the font
 @param style font style to use
 */
- ( UIFont * _Nonnull )fontWithSize:(CGFloat)fontSize style:(SFAppStylerFontStyle)style;

/**
 * Return a simple view used for a TableView footer which will contain a UILabel with the specified text and custom styling.
 * @param text The text to be displayed in the view.
 * @param textColor The text color. Pass in nil to use the default color.
 * @param maxSize The max size allowed for the view.
 */
- (UIView * _Nonnull)customFooterViewWithText:(NSString * _Nullable)text textColor:(UIColor * _Nullable)textColor limitedToSize:(CGSize)maxSize;

/**
 * Return a simple view used for a TableView header which will contain a UILabel with the specified text and custom styling.
 * @param text      The text to be displayed in the view.
 * @param textColor The text color. Pass in nil to use the default color.
 * @param maxSize   The max size allowed for the view.
 */
- (UIView * _Nonnull)customHeaderViewWithText:(NSString * _Nullable)text textColor:(UIColor * _Nullable)textColor limitedToSize:(CGSize)maxSize;
@end

