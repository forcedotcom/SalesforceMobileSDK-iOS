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
        _navBarColor = [UIColor colorWithRed:22.0/255.0 green:87.0/255.0 blue:205/255.0 alpha:1.0];
        _navBarFont = nil;
        _navBarTextColor = [UIColor whiteColor];
    }
    return self;
}

#pragma mark - Styling Methods

- (void)styleNavigationBar:(UINavigationBar *)navigationBar {
    if (!navigationBar) {
        return;
    }
    if (self.navBarColor) {
        UIImage *backgroundImage = [self headerBackgroundImage];
        [navigationBar setBackgroundImage:backgroundImage forBarMetrics:UIBarMetricsDefault];
    }
    if (self.navBarTextColor) {
        [navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName: self.navBarTextColor}];
    }
    
    if (self.navBarFont && self.navBarTextColor) {
        [navigationBar setTitleTextAttributes:@{ NSForegroundColorAttributeName: self.navBarTextColor,
                                                 NSFontAttributeName: self.navBarFont}];
    }
}

- ( UIImage * _Nonnull )headerBackgroundImage {
    UIImage *backgroundImage = [[self class] imageFromColor:self.navBarColor];
    return backgroundImage;
}

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

