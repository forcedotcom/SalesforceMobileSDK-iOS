//
//  UIViewController+SFAdditions.h
//  SalesforceCommonUtils
//
//  Created by Jonathan Arbogast on 6/8/15.
//  Copyright (c) 2015 Salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (SFAdditions)

- (BOOL)presentAlertController:(UIAlertController *)alertController;
- (BOOL)presentAlertController:(UIAlertController *)alertController withSourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect;
- (BOOL)presentAlertController:(UIAlertController *)alertController withBarButtonItem:(UIBarButtonItem *)barButtonItem;

@end
