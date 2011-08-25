//
//  RestAPIExplorerAppDelegate.h
//  RestAPIExplorer
//
//  Created by Didier Prophete on 7/14/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SFOAuthCoordinator.h"
#import "RestKit.h"

@interface RestAPIExplorerAppDelegate : NSObject <UIApplicationDelegate, SFOAuthCoordinatorDelegate, UIAlertViewDelegate> {
    SFOAuthCoordinator *_coordinator;
}

@property (nonatomic, retain) SFOAuthCoordinator *coordinator;
@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UIViewController *viewController;

@end
