//
//  UIActionSheet+SFBlocks.h
//  SalesforceCommonUtils
//
//  Created by Jean Bovet on 3/13/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

// The block being called when the sheet is dismissed
typedef void (^SFActionSheetDismissBlock) (UIActionSheet *actionSheet, NSInteger buttonIndex);

/**
 Class extension to allow the use of blocks instead of implementing UIActionSheetDelegate to use UIActionSheet
 */
@interface UIActionSheet (SFBlocks)

/**Create an action sheet that allows block to be called when action sheet is dismissed. Caller does not have to implement UIActionSheetDelegate
@param title  Action sheet title
@param title  Action sheet cancel title
@param title  Action sheet destructive title
@param otherTitles  Other titles of action sheet
@param dismissBlock blocks that will be called when user clicks on an actionsheet button
*/
+ (UIActionSheet*)actionSheetWithTitle:(NSString*)title
                     cancelButtonTitle:(NSString*)cancelTitle
                destructiveButtonTitle:(NSString*)destructiveTitle
                     otherButtonTitles:(NSArray*)otherTitles
                       didDismissBlock:(SFActionSheetDismissBlock)dismissBlock;

@end
