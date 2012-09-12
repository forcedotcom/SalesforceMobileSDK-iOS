/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 Author: Amol Prabhu
 
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

#import "SFOAuth_NSString+Additions.h"
#import <CommonCrypto/CommonDigest.h>


#ifndef FIX_CATEGORY_BUG
#define FIX_CATEGORY_BUG(name) @interface FIXCATEGORYBUG ## name @end @implementation FIXCATEGORYBUG ## name @end 
#endif


FIX_CATEGORY_BUG(NSString_CryptoAdditions);

@implementation NSString (CryptoAdditions)

+ (NSString *)stringWithHexData:(NSData *)data {
    if (nil == data) return nil;
    NSMutableString *stringBuffer = [NSMutableString stringWithCapacity:([data length] * 2)];
	const unsigned char *dataBuffer = [data bytes];
	for (int i = 0; i < [data length]; ++i) {
		[stringBuffer appendFormat:@"%02lx", (unsigned long)dataBuffer[ i ]];
    }
    return [NSString stringWithString:stringBuffer];
}

- (NSData *)sha256 {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH] = {0};
    CC_SHA256([self UTF8String], [self lengthOfBytesUsingEncoding:NSUTF8StringEncoding], digest);
    return [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
}

@end
