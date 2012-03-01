//
//  NSString+Additions.h
//  ChatterSDK
//
//  Created by Amol Prabhu on 1/9/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Additions)

/**
 Returns a string representation of the supplied hex data. Returns nil if data is nil.
 */
+ (NSString *)stringWithHexData:(NSData *)data;

/**
 Returns an SHA 256 hash of the current string
 */
- (NSData *)sha256;


@end
