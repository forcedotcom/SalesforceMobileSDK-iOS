//
//  NSUserDefaults+SFAdditions.m
//  SalesforceSDKCore
//
//  Created by Raj Rao on 8/10/16.
//  Copyright © 2016 salesforce.com. All rights reserved.
//

#import "NSUserDefaults+SFAdditions.h"
#import "SFSDKDatasharingHelper.h"

@implementation NSUserDefaults (SFAdditions)

+ (NSUserDefaults *)msdkUserDefaults {
    NSUserDefaults *sharedDefaults = nil;
    if ([SFSDKDatasharingHelper sharedInstance].appGroupEnabled) {
        sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:[SFSDKDatasharingHelper sharedInstance].appGroupName];
    } else {
        sharedDefaults = [NSUserDefaults standardUserDefaults];
    }
    return sharedDefaults;
}
@end
