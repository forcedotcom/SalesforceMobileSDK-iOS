//
//  SFPickListViewController.h
//  SalesforceCommonUtils
//
//  Created by Qingqing Liu on 4/27/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SFPickListViewController;

/**Delegate class that will be called back when user either selected a value or dismiss the picker 
 */
@protocol SFPickListViewDelegate <NSObject>
@required
- (void)valuePickCanceled:(SFPickListViewController *)picklist;
- (void)valuePicked:(NSString *)value pickList:(SFPickListViewController *)picklist;
@end

/**Utility view controller that provides a simple choice list for user to pick a value from.
 
 This class is extended by `SFPadPickListViewController` to be used on iPad and by `SFPhonePickListViewController` to be used on iPhone
 */
@interface SFPickListViewController : UIViewController

/**Unique tag for this pick list*/
@property (assign, nonatomic) NSInteger tag;

/**List of choices to be presented*/
@property (strong, nonatomic) NSArray *choices;
/**Currently selected value*/
@property (strong, nonatomic) NSString *selectedValue;
@property (weak, nonatomic) id <SFPickListViewDelegate> delegate;


/**Initialize pick list with an array of choices and selected value
 
 @param choices A list of possible choices
 @param selectedValue Currently selected value, must be a value from the choices list
 */
- (id)initWithChoices:(NSArray *)choices selectedValue:(NSString *)selectedValue;

/**Create an ew SFPickListViewController based on current user's device type
 
If iPad, an instance of `SFPadPickListViewController` will be created. 
If iPhone, an instance of `SFPhonePickListViewController` will be created
 */
+ (SFPickListViewController *)createPickListViewController:(NSArray *)choices selectedValue:(NSString *)selectedValue;
@end