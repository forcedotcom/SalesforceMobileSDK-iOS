//
//  UIColor+SFAdditions.h
//  SalesforceCommonUtils
//
//  Created by Riley Crebs on 6/15/15.
//  Copyright (c) 2015 Salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (SFAdditions)
/**
 Assumes input like "#00FF00" (#RRGGBB).
 */
+ (UIColor *)colorFromHexValue:(NSString *)hexString;

- (NSString *)hexStringFromColor;

@end
