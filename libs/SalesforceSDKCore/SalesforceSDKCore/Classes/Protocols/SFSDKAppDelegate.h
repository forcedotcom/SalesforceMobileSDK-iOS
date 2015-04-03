//
//  SFSDKAppDelegate.h
//  SalesforceSDKCore
//
//  Created by Michael Nachbaur on 2/26/15.
//  Copyright (c) 2015 salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * Protocol defining an SDK-based app delegate.
 */
@protocol SFSDKAppDelegate <UIApplicationDelegate>

/**
 The User-Agent string presented by this application
 */
@property (nonatomic, readonly) NSString *userAgentString;

/**
 * Forces a logout from the current account.
 * This throws out the OAuth refresh token.
 */
- (void)logout;

/**
 * Creates a snapshot view.
 */
- (UIView*)createSnapshotView;

@end
