//
//  SFRootViewManager.h
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 3/26/13.
//  Copyright (c) 2013 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SFRootViewManager : NSObject

@property (nonatomic, readonly) BOOL newViewIsDisplayed;

- (id)initWithRootViewController:(UIViewController *)viewController;
- (void)showNewView;
- (void)restorePreviousView;

@end
