//
//  NSString+Additions.m
//  ChatterSDK
//
//  Created by Amol Prabhu on 1/9/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import "NSString+SFAdditions.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (SFAdditions)

+ (NSString *)stringWithHexData:(NSData *)data {
    if (nil == data) return nil;
    NSMutableString *stringBuffer = [NSMutableString stringWithCapacity:([data length] * 2)];
	const unsigned char *dataBuffer = [data bytes];
	for (int i = 0; i < [data length]; ++i) {
		[stringBuffer appendFormat:@"%02x", (unsigned long)dataBuffer[ i ]];
    }
    return [NSString stringWithString:stringBuffer];
}

- (NSData *)sha256 {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH] = {0};
    CC_SHA256([self UTF8String], [self lengthOfBytesUsingEncoding:NSUTF8StringEncoding], digest);
    return [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
}


- (NSString *)removeWhitespaces {
    NSArray* words = [self componentsSeparatedByCharactersInSet :[NSCharacterSet whitespaceCharacterSet]];
    return [words componentsJoinedByString:@""];
}
@end
