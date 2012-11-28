//
//  SFOAuthFlowManager.h
//  SalesforceHybridSDK
//
//  Created by Kevin Hawkins on 11/15/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFOAuthCoordinator.h"
#import "SFIdentityCoordinator.h"

@class SFAuthorizingViewController;

/**
 Callback block definition for OAuth completion/failure callbacks.
 */
typedef void (^SFOAuthFlowCallbackBlock)(void);

@interface SFOAuthFlowManager : NSObject <SFOAuthCoordinatorDelegate, SFIdentityCoordinatorDelegate>

/**
 The view controller that will be used to "host" an OAuth view, if necessary.
 */
@property (nonatomic, retain) UIViewController *viewController;

/**
 Alert view for displaying auth-related status messages.
 */
@property (nonatomic, retain) UIAlertView *statusAlert;

/**
 The view controller used to present the authentication dialog.
 */
@property (nonatomic, retain) SFAuthorizingViewController *authViewController;

/**
 Kick off the login process.
 @param presentingViewController The view controller that will be used to display an OAuth view, where
 required.
 @param completionBlock The block of code to execute when the OAuth process completes.
 @param failureBlock The block of code to execute when OAuth fails due to revoked/expired credentials.
 */
- (void)login:(UIViewController *)presentingViewController
   completion:(SFOAuthFlowCallbackBlock)completionBlock
      failure:(SFOAuthFlowCallbackBlock)failureBlock;

/**
 Sent whenever the user has been logged in using current settings.
 Be sure to call super if you override this.
 */
- (void)loggedIn;

@end
