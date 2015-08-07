//
//  NSMutableAttributedString+SFAdditions.h
//  SalesforceCommonUtils
//
//  Created by Amol Prabhu on 9/24/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableAttributedString (SFAdditions)

/**
 Adds an attribute with the given name and value to the characters in the range matching the first occurrence of `str`.
 The search for `str` is performed using the specified `options` and the current locale.
 
 @param attribute A string specifying the attribute name.
 @param value The attribute value associated with name.
 @param str The character string to search for and apply the supplied attributes.
 @param options Options used when performing the search for character string `str`. 0 for none.
 */
- (void)addAttribute:(NSString *)attribute value:(id)value forString:(NSString *)str options:(NSStringCompareOptions)options;

/**
 Adds the given collection of attributes to the characters in the range matching the first occurrence of `str`.
 The search for `str` is performed using the specified `options` and the current locale.
 
 @param attrs A dictionary containing the attributes to add to the characters matching `str`.
 @param str The character string to search for and apply the supplied attributes.
 @param options Options used when performing the search for character string `str`. 0 for none.
 */
- (void)addAttributes:(NSDictionary *)attrs forString:(NSString *)str options:(NSStringCompareOptions)options;

@end
