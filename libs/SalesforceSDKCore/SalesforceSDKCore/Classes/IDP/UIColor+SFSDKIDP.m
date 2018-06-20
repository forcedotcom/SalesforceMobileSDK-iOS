/*
 SalesforceSDKCore
 
 Created by Raj Rao on 6/05/18.
 
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

#import "UIColor+SFSDKIDP.h"

@implementation UIColor (SFSDKIDP)

+ (UIColor *)backgroundcolor {
    return [UIColor colorWithRed:241.0/255.0 green:244.0/255.0 blue:247.0/255.0 alpha:1.0];
}

+ (UIColor *)backgroundRowSelectedColor {
    return [UIColor colorWithRed:240.0/255.0 green:248.0/255.0 blue:252.0/255.0 alpha:1.0];
}

+ (UIColor *)borderColor {
    return [UIColor colorWithRed:216.0/255.0 green:221.0/255.0 blue:230.0/255.0 alpha: 1.0];
}

+ (UIColor *)weakTextColor {
    return [UIColor colorWithRed: 84.0/255.0 green:105.0/255.0 blue: 141.0/255.0 alpha: 1.0];
}

+ (UIColor *)defaultTextColor{
    return [UIColor colorWithRed: 22.0/255.0 green:50.0/255.0 blue: 92.0/255.0 alpha: 1.0];
}

+ (UIColor *)altTextColor{
    return [UIColor colorWithRed: 24.0/255.0 green:52.0/255.0 blue: 95.0/255.0 alpha: 1.0];
}

+ (UIColor *)alt2BackgroundColor{
    return [UIColor colorWithRed: 224.0/255.0 green:229.0/255.0 blue: 238.0/255.0 alpha: 1.0];
}

+ (UIColor *)altBackgroundColor{
    return [UIColor whiteColor];
}

+ (UIColor *)tableCellBackgroundColor{
    return [UIColor colorWithRed: 245.0/255.0 green:246.0/255.0 blue: 250.0/255.0 alpha: 1.0];
}

@end
