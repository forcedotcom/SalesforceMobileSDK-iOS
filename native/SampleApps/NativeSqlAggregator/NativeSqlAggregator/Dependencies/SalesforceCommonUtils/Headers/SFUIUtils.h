//
//  SFUIUtils.h
//  SalesforceCommonUtils
//
//  Created by Amol Prabhu on 9/24/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFUIUtils : NSObject

/**
 Applies the specified orientation to the specified view, for the duration indicated. The callback is invoked
 just before the animation is commited and can be used to setup any additional stuff after the view
 has been rotated.
 */
+ (void)applyRotation:(UIInterfaceOrientation)interfaceOrientation
               toView:(UIView*)view
             duration:(NSTimeInterval)duration
             callback:(void (^)(void))callback;

@end
