/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <CommonCrypto/CommonDigest.h>
#import "NSString+SFAdditions.h"

static inline BOOL IsValidEntityId(NSString *string) {
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // entity ID's can only consist of ASCII 0-9, A-Z, a-z
        regex = [NSRegularExpression regularExpressionWithPattern:@"[A-Za-z0-9]{15,18}"
                                                          options:NSRegularExpressionCaseInsensitive
                                                            error:nil];
    });
    
    NSRange range = NSMakeRange(0, string.length);
    return ((string.length == SFEntityIdLength15 || string.length == SFEntityIdLength18) &&
            [regex rangeOfFirstMatchInString:string options:NSMatchingAnchored range:range].length == string.length);
}

@implementation NSString (SFAdditions)

+ (BOOL)isEmpty:(NSString *)string {
    if (nil == string){
        return YES;
    }
    string = [string trim];
    if (string.length == 0) {
        return YES;
    }
    return NO;
}

+ (NSString *)stringWithHexData:(NSData *)data {
    if (![data length]) return nil;
    NSMutableString *stringBuffer = [NSMutableString stringWithCapacity:([data length] * 2)];
	const unsigned char *dataBuffer = [data bytes];
	for (NSUInteger i = 0; i < [data length]; ++i) {
		[stringBuffer appendFormat:@"%02lx", (unsigned long)dataBuffer[ i ]];
    }
    return [NSString stringWithString:stringBuffer];
}

- (NSData *)sha256 {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH] = {0};
    CC_SHA256([self UTF8String], (CC_LONG)[self lengthOfBytesUsingEncoding:NSUTF8StringEncoding], digest);
    return [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
}

- (NSString *)trim {
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSString*)redacted {
    return [self redactedWithPrefix:0];
}

- (NSString*)redactedWithPrefix:(NSUInteger)prefixLength {
#ifdef DEBUG
    return self;
#else
    NSMutableString *ms = [NSMutableString stringWithString:[self substringToIndex:MIN(self.length, prefixLength)]];
    for (NSUInteger index=prefixLength; index<self.length; index++) {
        [ms appendString:@"-"];
    }
    return ms;
#endif
}

+ (NSString *)escapeXMLCharacter:(NSString *)value {
    if ([NSString isEmpty:value]) {
        return @"";
    }
    NSString *returnValue = [value stringByReplacingOccurrencesOfString:@"'" withString:@"&#39;"];
    returnValue = [returnValue stringByReplacingOccurrencesOfString:@"&" withString:@"&#38;"];
    returnValue = [returnValue stringByReplacingOccurrencesOfString:@"\"" withString:@"&#34;"];
    returnValue = [returnValue stringByReplacingOccurrencesOfString:@"<" withString:@"&#60;"];
    returnValue = [returnValue stringByReplacingOccurrencesOfString:@">" withString:@"&#62;"];
    returnValue = [returnValue stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    returnValue = [returnValue stringByReplacingOccurrencesOfString:@"©" withString:@"&#169;"];
    returnValue = [returnValue stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
    return returnValue;
}

+ (NSString *)unescapeXMLCharacter:(NSString *)value {
    if ([NSString isEmpty:value]) {
        return @"";
    }
    NSString *returnValue = [value stringByReplacingOccurrencesOfString:@"&#39;" withString:@"'"];
    returnValue = [returnValue stringByReplacingOccurrencesOfString:@"&#38;" withString:@"&"];
    returnValue = [returnValue stringByReplacingOccurrencesOfString:@"&#34;" withString:@"\""];
    returnValue = [returnValue stringByReplacingOccurrencesOfString:@"&#60;" withString:@"<"];
    returnValue = [returnValue stringByReplacingOccurrencesOfString:@"&#62;" withString:@">"];
    returnValue = [returnValue stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
    returnValue = [returnValue stringByReplacingOccurrencesOfString:@"&#169;" withString:@"©"];
    returnValue = [returnValue stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
    return returnValue;
}

- (NSString *)removeWhitespaces {
    NSArray* words = [self componentsSeparatedByCharactersInSet :[NSCharacterSet whitespaceCharacterSet]];
    return [words componentsJoinedByString:@""];
}

- (NSDictionary *)queryStringComponents {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSArray *pairs = [self componentsSeparatedByString:@"&"];
    
    for (NSString *pair in pairs) {
        NSArray *elements = [pair componentsSeparatedByString:@"="];
        if ([elements count] == 2) {
            NSString *key = [[elements objectAtIndex:0] stringByRemovingPercentEncoding];
            NSString *val = [[elements objectAtIndex:1] stringByRemovingPercentEncoding];
            [dict setObject:val forKey:key];
        }
    }
    
    return [NSDictionary dictionaryWithDictionary:dict];
}

- (NSString *)stringByURLEncoding {
    CFStringRef cfStr = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)self, NULL, CFSTR("&:/=+"), kCFStringEncodingUTF8);
    NSString *result = [NSString stringWithFormat:@"%@", (__bridge NSString *) cfStr];
    CFRelease(cfStr);
    return result;
}

- (NSString *)stringByStrippingHTML {
    NSRange range;
    NSString *str = [self copy];
    while ((range = [str rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound) {
        str = [str stringByReplacingCharactersInRange:range withString:@""];
    }
    return str;
}

- (NSString*)stringWithTitleCharacter {
    NSString *result = nil;
    
    if (self.length == 0) {
        result = @"#";
    } else {
        NSString *unaccentedString = [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        unaccentedString = [unaccentedString stringByFoldingWithOptions:(NSDiacriticInsensitiveSearch |
                                                                         NSCaseInsensitiveSearch |
                                                                         NSWidthInsensitiveSearch)
                                                                 locale:[NSLocale currentLocale]];
        
        result = [[unaccentedString uppercaseString] substringWithRange:NSMakeRange(0, 1)];
        if (nil == result || NSNotFound != [result rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location)
            result = @"0-9";
    }
    
    return result;
}

- (BOOL)isEmptyOrWhitespaceAndNewlines {
    return !self.length ||
    ![self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length;
}

- (NSString*)entityId18 {
    
    // Look up table of characters which correspond to the bitmap value of uppercase characters for a
    // 5 character chunk of the entity ID (the 15 character entity ID is divided into 3 x 5 char chunks).
    static const unsigned char kChunkTable[32] = {
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
        'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '0', '1', '2', '3', '4', '5'
    };
    
    if (!IsValidEntityId(self)) return nil;
    if ([self length] == SFEntityIdLength18) return self;
    
    NSCharacterSet *capsCharSet = [NSCharacterSet uppercaseLetterCharacterSet];
    NSMutableString *suffix = [NSMutableString stringWithCapacity:3];
    NSString *selfString = [NSString stringWithString:self]; // defensive copy to iterate
    
    // Iterate the 15 char entity ID in 3 x 5 char chunks building a bitmap with on bits
    // representing upper case characters. Finally represent each chunk with a character
    // from the look up table corresponding to the map value.
    
    for (NSUInteger chunk = 0; chunk < 3; ++chunk) {
        uint8_t chunkMap = 0;
        for (NSUInteger i = 0; i < 5; ++i) {
            unichar c = [selfString characterAtIndex:(chunk * 5) + i];
            if ([capsCharSet characterIsMember:c]) {
                chunkMap |= 0x1F & (0x1 << i);
            }
        }
        [suffix appendFormat:@"%c", kChunkTable[chunkMap]];
    }
    return [NSString stringWithFormat:@"%@%@", selfString, suffix];
}

- (BOOL)isEqualToEntityId:(NSString*)entityId {
    if ([self caseInsensitiveCompare:entityId] == NSOrderedSame) return YES; // for entityId like `me`
    
    if (![entityId length]) return NO;
    if (!IsValidEntityId(self) || !IsValidEntityId(entityId)) return NO;
    
    NSString *id18self = ([self length] == SFEntityIdLength18) ? self : [self entityId18];
    NSString *id18other = ([entityId length] == SFEntityIdLength18) ? entityId : [entityId entityId18];
    if (nil == id18other) return NO; // because caseInsensitiveCompare doesn't allow a nil argument
    return ([id18self caseInsensitiveCompare:id18other] == NSOrderedSame);
}

@end
