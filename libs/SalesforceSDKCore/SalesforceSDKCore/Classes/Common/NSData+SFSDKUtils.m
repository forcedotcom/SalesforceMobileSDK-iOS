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

#import "NSData+SFSDKUtils_Internal.h"
#import <CommonCrypto/CommonCrypto.h>

@implementation NSData (SFSDKUtils)

- (NSString *)msdkBase64UrlString {
    NSString *base64String = [self base64EncodedStringWithOptions:0];
    return [[self class] replaceBase64CharsForBase64UrlString:base64String];
}

- (NSData *)msdkSha256Data {
    NSMutableData *sha256Data = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(self.bytes, (CC_LONG)self.length,  sha256Data.mutableBytes);
    return sha256Data;
}

#pragma mark - Internal methods

+ (NSString *)replaceBase64CharsForBase64UrlString:(NSString *)base64String {
    if (base64String == nil) return nil;
    
    NSMutableString *base64UrlString = [NSMutableString stringWithString:base64String];
    [base64UrlString replaceOccurrencesOfString:@"/" withString:@"_" options:NSLiteralSearch range:NSMakeRange(0, [base64UrlString length])];
    [base64UrlString replaceOccurrencesOfString:@"+" withString:@"-" options:NSLiteralSearch range:NSMakeRange(0, [base64UrlString length])];
    
    NSUInteger lastEqualsIndex = [base64UrlString length];
    while (lastEqualsIndex > 0 && [base64UrlString characterAtIndex:(lastEqualsIndex - 1)] == '=') {
        lastEqualsIndex--;
    }
    if (lastEqualsIndex < [base64UrlString length]) {
        [base64UrlString deleteCharactersInRange:NSMakeRange(lastEqualsIndex, ([base64UrlString length] - lastEqualsIndex))];
    }
    return base64UrlString;
}

@end
