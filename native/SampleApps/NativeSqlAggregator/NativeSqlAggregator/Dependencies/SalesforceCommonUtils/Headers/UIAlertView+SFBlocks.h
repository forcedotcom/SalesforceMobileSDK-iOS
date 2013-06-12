//
//  UIAlertView+SBlocks.h
//  SalesforceCommonUtils
//
//  Created by Jean Bovet on 11/29/11.
//  Copyright (c) 2011-2012 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

// The block being called when the alert is dismissed
typedef void (^SFAlertViewDismissBlock) (UIAlertView *alertView, NSInteger buttonIndex);

/**
 Class extension to allow the use of blocks
 */
@interface UIAlertView (SFBlocks)

/**Create an alert view that allows block to be called when alert view is dismissed. Caller does not have to implement UIActionSheetDelegate
 @param title  Alert title
 @param message  Alert message
 @param cancelTitle  Alert cancel title
 @param otherTitles  Other titles of alert view
 @param dismissBlock blocks that will be called when user clicks on an alert view button
 */

+ (UIAlertView*)alertViewWithTitle:(NSString*)title
                           message:(NSString*)message
                 cancelButtonTitle:(NSString*)cancelTitle
                 otherButtonTitles:(NSArray*)otherTitles
                   didDismissBlock:(SFAlertViewDismissBlock)dismissBlock;
@end
