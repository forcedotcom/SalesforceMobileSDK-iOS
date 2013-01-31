/*
 Copyright (c) 2013, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKCryptoUtils.h"

NSUInteger const kSFPBKDFDefaultNumberOfDerivationRounds = 4000;
NSUInteger const kSFPBKDFDefaultDerivedKeyByteLength = 128;

static NSUInteger NumPBKDFDerivationRounds = kSFPBKDFDefaultNumberOfDerivationRounds;
static NSUInteger PBKDFDerivedKeyByteLength = kSFPBKDFDefaultDerivedKeyByteLength;

@implementation SFSDKCryptoUtils

+ (NSUInteger)numPBKDFDerivationRounds
{
    return NumPBKDFDerivationRounds;
}

+ (void)setNumPBKDFDerivationRounds:(NSUInteger)numDerivationRounds
{
    NumPBKDFDerivationRounds = numDerivationRounds;
}

+ (NSUInteger)pbkdfDerivedKeyByteLength
{
    return PBKDFDerivedKeyByteLength;
}

+ (void)setPBKDFDerivedKeyByteLength:(NSUInteger)derivedKeyByteLength
{
    PBKDFDerivedKeyByteLength = derivedKeyByteLength;
}

+ (NSData *)randomByteDataWithLength:(NSUInteger)lengthInBytes
{
    unsigned char str[lengthInBytes];
    for (int i = 0; i < lengthInBytes; i++) {
        str[i] = (unsigned char)arc4random();
    }
    
    return [NSData dataWithBytes:str length:lengthInBytes];
}

+ (NSData *)pbkdf2DerivedKey:(NSString *)stringToHash salt:(NSData *)salt
{
    NSData *stringToHashAsData = [stringToHash dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger numDerivationRounds = [SFSDKCryptoUtils numPBKDFDerivationRounds];
    NSUInteger derivedKeyByteLength = [SFSDKCryptoUtils pbkdfDerivedKeyByteLength];
    unsigned char key[derivedKeyByteLength];
    int result = CCKeyDerivationPBKDF(kCCPBKDF2, [stringToHashAsData bytes], [stringToHashAsData length], [salt bytes], [salt length], kCCPRFHmacAlgSHA256, numDerivationRounds, key, derivedKeyByteLength);
    
    return (result == 0 ? [NSData dataWithBytes:key length:derivedKeyByteLength] : nil);
}


@end
