//
//  QueryListViewController.h
//  RestAPIExplorer
//
//  Created by Didier Prophete on 7/22/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RestAPIExplorerViewController;

@interface QueryListViewController : UITableViewController {
    NSArray *_actions;
    RestAPIExplorerViewController *_appViewController;
}

@property (nonatomic, retain) NSArray *actions;
@property (nonatomic, retain) RestAPIExplorerViewController *appViewController;

- (id)initWithAppViewController:(RestAPIExplorerViewController *)appViewController;

@end
