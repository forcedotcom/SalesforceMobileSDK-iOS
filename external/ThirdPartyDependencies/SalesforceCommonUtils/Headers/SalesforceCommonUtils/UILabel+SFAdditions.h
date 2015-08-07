//
//  UILabel+SFAdditions.h
//  SalesforceCommonUtils
//
//  Created by Amol Prabhu on 1/17/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

/**Extension to UILabel class with main focus around calculating label size with a specified constraints 
 */
@interface UILabel (SFAdditions)

/**Returns font with the correct size that is contrained to the passed in size height
 
 @param size Size to constraint the label to. 
 @param mode Line break mode this label should use for its text
 */
- (UIFont *)fontConstrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)mode; 

/** Returns the size that fits a certain width and a maximum number of lines.
 @param width Max width for the label frame
 @param maxLines Maximum number of lines label text should have
 */
- (CGSize)sizeThatFitsWidth:(CGFloat)width maximumNumberOfLines:(NSUInteger)maxLines;

@end
