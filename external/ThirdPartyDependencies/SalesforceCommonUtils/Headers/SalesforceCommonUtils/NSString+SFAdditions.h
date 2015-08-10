//
//  NSString+SFAdditions.h
//  SalesforceCommonUtils
//
//  Created by Amol Prabhu on 1/9/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    SFEntityIdLength15 = 15,
    SFEntityIdLength18 = 18,
    SFEntityIdLengthMin = SFEntityIdLength15,
    SFEntityIdLengthMax = SFEntityIdLength18
} SFEntityIdLength;

extern NSString * const SFUserAgentAppName;

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

/** Returns the string in debug build or a redacted version of it
 for production build
 */
- (NSString*)redacted;

/** Returns the string in debug build or a redacted version of it
 for production build. The prefix length is the number of character
 that won't be redacted from the beginning of the string.
 */
- (NSString*)redactedWithPrefix:(NSUInteger)prefixLength;

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

/**
 @return The 18 character case-insensitive entity ID representing the receiver.
 Returns `nil` if the receiver is not a valid Salesforce entity ID.
 */
- (NSString*)entityId18;

@end
