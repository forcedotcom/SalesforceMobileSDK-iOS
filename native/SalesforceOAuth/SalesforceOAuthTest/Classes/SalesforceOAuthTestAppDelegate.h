//
//  SalesforceOAuthTestAppDelegate.h
//  SalesforceOAuthTest
//
//  Created by Steve Holly on 20/06/2011.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SFOAuthCredentials;
@class SalesforceOAuthTestViewController;

@interface SalesforceOAuthTestAppDelegate : UIResponder <UIApplicationDelegate>

extern NSString * const kOAuthClientId;

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) SalesforceOAuthTestViewController *viewController;

+ (void)archiveCredentials:(SFOAuthCredentials *)creds;
+ (SFOAuthCredentials *)unarchiveCredentials;
+ (NSString *)archivePath;

@end
