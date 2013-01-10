//
//  SFSDKLocalizationUtils.h
//  SalesforceHybridSDK
//
//  Created by Kevin Hawkins on 1/9/13.
//  Copyright (c) 2013 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFSDKResourceUtils : NSObject

+ (NSBundle *)mainSdkBundle;
+ (NSString *)localizedString:(NSString *)localizationKey;

@end
