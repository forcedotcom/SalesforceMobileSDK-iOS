/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

#import "SFPasscodeManager.h"
#import "SFPasscodeManager+Internal.h"
#import "SFPasscodeProviderManager.h"

static SFPasscodeManager *sharedInstance = nil;

@implementation SFPasscodeManager

@synthesize encryptionKey = _encryptionKey;
@synthesize preferredPasscodeProvider = _preferredPasscodeProvider;

#pragma mark - Singleton initialization / management

+ (SFPasscodeManager *)sharedManager
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedManager];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

#pragma mark - Passcode management

- (void)setEncryptionKeyForPasscode:(NSString *)passcode
{
    id<SFPasscodeProvider> currentProvider = [SFPasscodeProviderManager currentPasscodeProvider];
    if (currentProvider == nil) {
        [self log:SFLogLevelError msg:@"Current passcode provider is not set.  Cannot set encryption key."];
        return;
    }
    
    NSString *encryptionKey = [currentProvider generateEncryptionKey:passcode];
    [self setEncryptionKey:encryptionKey];
}

- (void)setEncryptionKey:(NSString *)newEncryptionKey
{
    _encryptionKey = [newEncryptionKey copy];
}

- (BOOL)passcodeIsSet
{
    id<SFPasscodeProvider> currentProvider = [SFPasscodeProviderManager currentPasscodeProvider];
    if (currentProvider == nil) {
        [self log:SFLogLevelWarning msg:@"Current passcode provider is not set.  Cannot determine passcode status."];
        return NO;
    }
    return ([currentProvider hashedVerificationPasscode] != nil);
}

- (void)resetPasscode
{
    [self log:SFLogLevelInfo msg:@"Resetting passcode upon logout."];
    id<SFPasscodeProvider> currentProvider = [SFPasscodeProviderManager currentPasscodeProvider];
    if (currentProvider == nil) {
        [self log:SFLogLevelWarning msg:@"Current passcode provider is not set.  No reset action taken."];
    } else {
        [currentProvider resetPasscodeData];
    }
    [self setEncryptionKey:nil];
}

- (BOOL)verifyPasscode:(NSString *)passcode
{
    id<SFPasscodeProvider> currentProvider = [SFPasscodeProviderManager currentPasscodeProvider];
    if (currentProvider == nil) {
        [self log:SFLogLevelWarning msg:@"Current passcode provider is not set.  Cannot verify passcode."];
        return NO;
    } else if (![self passcodeIsSet]) {
        [self log:SFLogLevelWarning msg:@"Verification passcode is not set.  Cannot verify passcode."];
        return NO;
    } else {
        return [currentProvider verifyPasscode:passcode];
    }
}

- (void)setPasscode:(NSString *)newPasscode
{
    id<SFPasscodeProvider> currentProvider = [SFPasscodeProviderManager currentPasscodeProvider];
    id<SFPasscodeProvider> preferredProvider = [SFPasscodeProviderManager passcodeProviderForProviderName:self.preferredPasscodeProvider];
    if (currentProvider == nil) {
        [self log:SFLogLevelError msg:@"Current passcode provider is not set.  Cannot set new passcode."];
        return;
    }
    
    if (preferredProvider == nil) {
        [self log:SFLogLevelWarning format:@"Could not load preferred passcode provider '%@'.  Defaulting to current provider ('%@') as the preferred provider.", preferredProvider.providerName, currentProvider.providerName];
        preferredProvider = currentProvider;
    }
    
    // If the current and preferred providers are not the same, we need to unconfigure the current, and
    // configure the preferred as the new current.
    if (![currentProvider isEqual:preferredProvider]) {
        [currentProvider resetPasscodeData];
        [SFPasscodeProviderManager setCurrentPasscodeProviderByName:preferredProvider.providerName];
        currentProvider = [SFPasscodeProviderManager currentPasscodeProvider];
    }
    
    [currentProvider setVerificationPasscode:newPasscode];
    NSString *encryptionKey = [currentProvider generateEncryptionKey:newPasscode];
    [self setEncryptionKey:encryptionKey];
}

@end
