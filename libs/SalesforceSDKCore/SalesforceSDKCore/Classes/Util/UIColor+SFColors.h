/*
 UIColor+SFColors.h
 SalesforceSDKCore
 
 Created by Kunal Chitalia on 3/28/16.
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
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

NS_ASSUME_NONNULL_BEGIN

@interface UIColor (SFColors)

/** Construct a color given hex color, like "#00FF00" (#RRGGBB).
 */
+ (nullable UIColor *)colorFromHexValue:(NSString *)hexString;

+ (UIColor *)colorForLightStyle:(UIColor *)lightStyleColor darkStyle:(UIColor *)darkStyleColor;

/** Returns a CSS hex color representation
 of this color
 */
- (NSString *)hexStringFromColor;

@property (class, nonatomic, readonly) UIColor *salesforceBlueColor;
@property (class, nonatomic, readonly) UIColor *salesforceSystemBackgroundColor;
@property (class, nonatomic, readonly) UIColor *salesforceLabelColor;
@property (class, nonatomic, readonly) UIColor *salesforceBackgroundRowSelectedColor;
@property (class, nonatomic, readonly) UIColor *salesforceBorderColor;
@property (class, nonatomic, readonly) UIColor *salesforceDefaultTextColor;
@property (class, nonatomic, readonly) UIColor *salesforceWeakTextColor;
@property (class, nonatomic, readonly) UIColor *salesforceAltTextColor;
@property (class, nonatomic, readonly) UIColor *salesforceAltBackgroundColor;
@property (class, nonatomic, readonly) UIColor *salesforceAlt2BackgroundColor;
@property (class, nonatomic, readonly) UIColor *salesforceTableCellBackgroundColor;

@end

NS_ASSUME_NONNULL_END
