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

typedef void (^SFOAuthFlowCallbackBlock)(void);

@interface SFOAuthFlowManager : NSObject <SFOAuthCoordinatorDelegate, SFIdentityCoordinatorDelegate>

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
 */
- (void)login:(UIViewController *)presentingViewController
   completion:(SFOAuthFlowCallbackBlock)completionBlock
      failure:(SFOAuthFlowCallbackBlock)failureBlock;

@end
