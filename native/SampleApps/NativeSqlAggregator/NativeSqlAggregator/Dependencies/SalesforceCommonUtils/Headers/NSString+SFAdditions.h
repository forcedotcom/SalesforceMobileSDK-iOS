//
//  NSString+SFAdditions.h
//  SalesforceCommonUtils
//
//  Created by Amol Prabhu on 1/9/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

/**Extension to NSString object
 */
@interface NSString (SFAdditions)

/** 
 @return A hex string representation of the supplied data; or `nil` if `data` is `nil` or empty.
 @param data NSData to be represented as a base 16 string.
 */
+ (NSString *)stringWithHexData:(NSData *)data;

/** Returns an SHA 256 hash of the current string
 */
- (NSData *)sha256;

/** Escape XML entities
 
 @param value String value to escape. If nil is passed, this method will return nil back
 */
+ (NSString *)escapeXMLCharacter:(NSString *)value;

/** unescape XML entities
 
@param value String value to unescape. If nil is passed, this method will return nil back
 */
+ (NSString *)unescapeXMLCharacter:(NSString *)value;

/** Trim string by taking out beginning and ending space*/
- (NSString *)trim;

/** Return YES of string is nil or length is 0 or with white space only
 
 @param string String to check
 */
+ (BOOL)isEmpty:(NSString *)string;

/** Get common user agent string*/
+ (NSString *)userAgentString;

/** Returns a string after taking out any space
 */
- (NSString *)removeWhitespaces;

/**
 @return A string with all non-legal URL characters (per RFC 3986) escaped.
 */
- (NSString *)stringByURLEncoding;

/** Strips any HTML markup from the source string.
 */
- (NSString *)stringByStrippingHTML;

/** Returns an uppercase title character for the string without accents or other diacritic marks.
 Intended for use with UI index titles.
 */
- (NSString*)stringWithTitleCharacter;

/** Returns a dictionary of query string components for the string object.
 */
- (NSDictionary *)queryStringComponents;

/** Returns YES if the string is empty of contains only whitespance or newline characters.
 */
- (BOOL)isEmptyOrWhitespaceAndNewlines;

@end
