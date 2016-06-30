/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 Author: Kevin Hawkins
 
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

#import "SFSDKResourceUtils.h"

@implementation SFSDKResourceUtils

+ (NSBundle *)mainSdkBundle
{
    // One instance.  This won't change during the lifetime of the app process.
    static NSBundle *sdkBundle = nil;
    if (sdkBundle == nil) {
        NSString *sdkBundlePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"SalesforceSDKResources" ofType:@"bundle"];
        sdkBundle = [NSBundle bundleWithPath:sdkBundlePath];
    }
    
    return sdkBundle;
}

+ (NSString *)localizedString:(NSString *)localizationKey
{
    NSAssert(localizationKey != nil, @"localizationKey must contain a value.");
    
    NSString *value = NSLocalizedString(localizationKey, localizationKey);
    if (value && ![value isEqualToString:localizationKey]) {
        // get from main bundle first to allow customer to override
        return value;
    }
    
    NSBundle *sdkBundle = [SFSDKResourceUtils mainSdkBundle];
    if (!sdkBundle) {
        sdkBundle = [NSBundle mainBundle];
    }
    
    return NSLocalizedStringFromTableInBundle(localizationKey, @"Localizable", sdkBundle, nil);
}

+ (UIImage *)imageNamed:(NSString *)name {
    NSAssert(name != nil, @"name must contain a value.");
    NSBundle *bundle = [NSBundle mainBundle];
    UIImage *image = [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
    if (image) {
        // get from main bundle first to allow customer to override
        return image;
    }
    
    bundle = [NSBundle bundleForClass:[self class]];
    image = [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
    return image;
}

@end
