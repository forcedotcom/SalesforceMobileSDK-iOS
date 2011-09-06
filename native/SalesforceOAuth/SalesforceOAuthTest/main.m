//
//  main.m
//  SalesforceOAuth
//
//  Created by Steve Holly on 20/06/2011.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SalesforceOAuthTestAppDelegate.h"

int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int retVal = UIApplicationMain(argc, argv, nil, NSStringFromClass([SalesforceOAuthTestAppDelegate class]));
    [pool release];
    return retVal;
}
