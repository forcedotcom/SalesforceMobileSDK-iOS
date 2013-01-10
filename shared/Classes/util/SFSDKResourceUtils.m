//
//  SFSDKLocalizationUtils.m
//  SalesforceHybridSDK
//
//  Created by Kevin Hawkins on 1/9/13.
//  Copyright (c) 2013 Salesforce.com. All rights reserved.
//

#import "SFSDKResourceUtils.h"

@implementation SFSDKResourceUtils

+ (NSBundle *)mainSdkBundle
{
    // One instance.  This won't change during the lifetime of the app process.
    static NSBundle *sdkBundle = nil;
    if (sdkBundle == nil) {
        NSString *sdkBundlePath = [[NSBundle mainBundle] pathForResource:@"SalesforceSDKResources" ofType:@"bundle"];
        sdkBundle = [NSBundle bundleWithPath:sdkBundlePath];
    }
    
    return sdkBundle;
}

+ (NSString *)localizedString:(NSString *)localizationKey
{
    NSAssert(localizationKey != nil, @"localizationKey must contain a value.");
    NSBundle *sdkBundle = [SFSDKResourceUtils mainSdkBundle];
    return NSLocalizedStringFromTableInBundle(localizationKey, @"Localizable", sdkBundle, nil);
}

@end
