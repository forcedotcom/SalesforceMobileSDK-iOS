/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFEncryptionKey.h"

// NSCoding constants
static NSString * const kEncryptionKeyCodingValue = @"com.salesforce.encryption.key.data";
static NSString * const kInitializationVectorCodingValue = @"com.salesforce.encryption.key.iv";

@implementation SFEncryptionKey

@synthesize key = _key;
@synthesize initializationVector = _initializationVector;

- (id)initWithData:(NSData *)key initializationVector:(NSData *)iv
{
    self = [super init];
    if (self) {
        self.key = key;
        self.initializationVector = iv;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.key = [aDecoder decodeObjectForKey:kEncryptionKeyCodingValue];
        self.initializationVector = [aDecoder decodeObjectForKey:kInitializationVectorCodingValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.key forKey:kEncryptionKeyCodingValue];
    [aCoder encodeObject:self.initializationVector forKey:kInitializationVectorCodingValue];
}

- (id)copyWithZone:(NSZone *)zone
{
    SFEncryptionKey *keyCopy = [[[self class] allocWithZone:zone] init];
    keyCopy.key = [NSData dataWithData:self.key];
    keyCopy.initializationVector = [NSData dataWithData:self.initializationVector];
    return keyCopy;
}

- (NSString *)keyAsString
{
    if (!self.key) return nil;
    return [self.key base64EncodedStringWithOptions: 0];
}

- (NSString *)initializationVectorAsString
{
    if (!self.initializationVector) return nil;
    return [self.initializationVector base64EncodedStringWithOptions: 0];
}

- (BOOL)isEqual:(id)object
{
    if (object == self) return YES;
    if (object == nil || ![object isKindOfClass:[SFEncryptionKey class]]) return NO;
    
    SFEncryptionKey *objectAsKey = (SFEncryptionKey *)object;
    return ([self.key isEqualToData:objectAsKey.key] && [self.initializationVector isEqualToData:objectAsKey.initializationVector]);
}

- (NSUInteger)hash
{
    NSUInteger result = 43;
    result = 43 * result + [_key hash];
    result = 43 * result + [_initializationVector hash];
    return result;
}

@end
