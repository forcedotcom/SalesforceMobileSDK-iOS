//
//  PadPickListViewController.h
//  SalesforceCommonUtils
//
//  Created by Qingqing Liu on 4/27/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SFPickListViewController.h"


/**Utility view controller that provides a simple choice list on iPad for user to pick a value from.
 
 This view controller is designed to be used in an iPad UIPopover
 */
@interface SFPadPickListViewController : SFPickListViewController <UITableViewDataSource, UITableViewDelegate>

/**Create a new PickListViewController
 
 @param choices A list of possible choices
 @param selectedValue Currently selected value, must be a value from the choices list
 @param rowHeight Table row height
 @param rowWidth Row width, this will decide the width of the popover if displayed as popover
 @param maxVisibleRows Maximum of visible rows to display. This will decide the height of the popover. If 0 is passed in, all rows will be visible
 */
- (id)initWithChoices:(NSArray *)choices selectedValue:(NSString *)selectedValue rowHeight:(NSInteger)rowHeight width:(NSInteger)rowWidth maxVisibleRows:(NSInteger)maxVisibleRows;

@end
