//
//  UIImage+SFAdditions.h
//  SalesforceCommonUtils
//
//  Created by Amol Prabhu on 5/15/15.
//  Copyright (c) 2015 Salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (SFAdditions)

+ (UIImage *)imageWithColor:(UIColor *)color;
+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;
+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size cornerRadius:(CGFloat)radius;
- (UIImage *)scaleImageToSize:(CGSize)newSize adjustForScreenScale:(BOOL)adjust;
- (UIImage *)scaleImageToSize:(CGSize)newSize;
- (UIImage *)roundImage;

+ (UIImage*)imageWithBorderEdge:(CGRectEdge)edge
                      imageSize:(CGSize)size
                    borderColor:(UIColor*)borderColor
                     borderSize:(CGFloat)borderSize
                backgroundColor:(UIColor*)background;

/**
 *  Produces an image of the given size, color, and corners.  Usually used to overlay other images over it.
 *
 *  @param color        Background color to use
 *  @param borderColor  Border color to use, or `nil` if no border is needed
 *  @param size         Size of the resulting image
 *  @param cornerRadius Corner radius to use
 *  @param rectCorner   Corners to apply the corner radius to
 *
 *  @return Styled image, or `nil` if an error occurred.
 */
+ (UIImage *)imageWith:(UIColor *)color borderColor:(UIColor *)borderColor size:(CGSize)size cornerRadius:(CGFloat)cornerRadius rectCorner:(UIRectCorner)rectCorner;

/**
 Returns a cropped image to the specified rect
 */
- (UIImage*)croppedImageToRect:(CGRect)rect;

@end
