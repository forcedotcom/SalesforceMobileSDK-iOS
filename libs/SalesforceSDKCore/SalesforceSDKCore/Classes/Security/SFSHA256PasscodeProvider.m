/*
 Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSHA256PasscodeProvider.h"
#import "SFKeychainItemWrapper.h"
#import "NSString+SFAdditions.h"
#import "NSData+SFAdditions.h"


static NSString * const kKeychainIdentifierPasscode = @"com.salesforce.security.passcode";
static NSString * const kKeychainIdentifierPasscodeLength = @"com.salesforce.security.passcodeLength";

@implementation SFSHA256PasscodeProvider
@synthesize passcodeLength;
@synthesize providerName = _providerName;

#pragma mark - SFPasscodeProvider

- (instancetype)initWithProviderName:(SFPasscodeProviderId)providerName
{
    self = [super init];
    if (self) {
        NSAssert(providerName != nil, @"providerName cannot be nil.");
        _providerName = [providerName copy];
    }
    
    return self;
}

- (SFKeychainItemWrapper*) passcodeWrapper {
    return [SFKeychainItemWrapper itemWithIdentifier:kKeychainIdentifierPasscode account:nil];
}

- (SFKeychainItemWrapper*) passcodeLengthWrapper {
    return [SFKeychainItemWrapper itemWithIdentifier:kKeychainIdentifierPasscodeLength account:nil];
}

- (void)resetPasscodeData
{
    [[self passcodeWrapper] resetKeychainItem];
}

- (BOOL)verifyPasscode:(NSString *)passcode
{
    NSString *strBaseEncode = [[passcode sha256] base64Encode];
    NSString *passcodeString = [self hashedVerificationPasscode];
    
    if (!passcodeString) {
        [SFSDKCoreLogger e:[self class] format:@"cannot verify password: passcode from keychain is nil"];
    }
    
    BOOL matches = [passcodeString isEqualToString:strBaseEncode];
    if (!matches) {
        [SFSDKCoreLogger d:[self class] format:@"Passcode does not match!"];
    }
    return matches;
}

- (NSString *)hashedVerificationPasscode
{
    return [[self passcodeWrapper] valueString];
}

- (void)setVerificationPasscode:(NSString *)newPasscode
{
    NSString *strBaseEncode = [[newPasscode sha256] base64Encode];
    [[self passcodeWrapper] setValueString:strBaseEncode];
}

- (NSUInteger)passcodeLength
{
    return  [[[self passcodeLengthWrapper] valueString] intValue];
}

- (void)setPascodeLength:(int)length
{
    [[self passcodeLengthWrapper] setValueString:[NSString stringWithFormat:@"%lu",(unsigned long)length]];
}

- (NSString *)generateEncryptionKey:(NSString *)passcode
{
    if ([self hashedVerificationPasscode] == nil) {
        [SFSDKCoreLogger e:[self class] format:@"Verification passcode is not set.  Set the verificationPasscode property before calling this method."];
        return nil;
    }
    
    if (![self verifyPasscode:passcode]) {
        [SFSDKCoreLogger e:[self class] format:@"Passcode does not pass verification."];
        return nil;
    }
    
    return [self hashedVerificationPasscode];
    
}

@end
