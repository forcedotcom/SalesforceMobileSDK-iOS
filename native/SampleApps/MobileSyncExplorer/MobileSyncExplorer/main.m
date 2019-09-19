//
//  main.m
//  SmartSyncExplorer
//
//  Created by Kevin Hawkins on 10/8/14.
//  Copyright (c) 2014-present, salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AppDelegate.h"
#import <SalesforceSDKCore/SFApplication.h>

int main(int argc, char * argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, NSStringFromClass([SFApplication class]), NSStringFromClass([AppDelegate class]));
    }
}
