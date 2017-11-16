//
//  SFSDKLoginViewControllerConfig.m
//  SalesforceSDKCore
//
//  Created by Raj Rao on 11/15/17.
//  Copyright © 2017 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFSDKLoginViewControllerConfig.h"
#import "UIColor+SFColors.h"
@implementation SFSDKLoginViewControllerConfig

- (instancetype)init {

    self = [super init];
    if (self) {
        _navBarColor = [UIColor salesforceBlueColor];
        _navBarFont = nil;
        _navBarTextColor = [UIColor whiteColor];
        _showNavbar = YES;
        _showSettingsIcon = YES;
    }
    return self;
}

@end
