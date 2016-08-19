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

#import "SFPasscodeProviderManager.h"
#import "SFPasscodeProviderManager+Internal.h"
#import "SFSHA256PasscodeProvider.h"
#import "SFPBKDF2PasscodeProvider.h"

// Public constants
SFPasscodeProviderId const kSFPasscodeProviderSHA256 = @"sha256";
SFPasscodeProviderId const kSFPasscodeProviderPBKDF2 = @"pbkdf2";

// Private constants
static NSString * const kSFCurrentPasscodeProviderUserDefaultsKey = @"com.salesforce.mobilesdk.currentPasscodeProvider";

static NSMutableDictionary *PasscodeProviderMap;

@implementation SFPasscodeProviderManager

+ (void)initialize
{
    SFSHA256PasscodeProvider *sha256Prov = [[SFSHA256PasscodeProvider alloc] initWithProviderName:kSFPasscodeProviderSHA256];
    SFPBKDF2PasscodeProvider *pbkdf2Prov = [[SFPBKDF2PasscodeProvider alloc] initWithProviderName:kSFPasscodeProviderPBKDF2];
    
    PasscodeProviderMap = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                           sha256Prov, kSFPasscodeProviderSHA256,
                           pbkdf2Prov, kSFPasscodeProviderPBKDF2,
                           nil];
}

+ (SFPasscodeProviderId)currentPasscodeProviderName
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *currentProviderName = [defs objectForKey:kSFCurrentPasscodeProviderUserDefaultsKey];
    
    // If never set, presume the version is SHA256.
    if (currentProviderName == nil) {
        currentProviderName = kSFPasscodeProviderSHA256;
        [defs setObject:currentProviderName forKey:kSFCurrentPasscodeProviderUserDefaultsKey];
        [defs synchronize];
    }
    
    return currentProviderName;
}

+ (void)setCurrentPasscodeProviderByName:(SFPasscodeProviderId)providerName
{
    id<SFPasscodeProvider> provider = [SFPasscodeProviderManager passcodeProviderForProviderName:providerName];
    if (provider == nil) {
        [SFLogger log:[SFPasscodeProviderManager class]
                level:SFLogLevelError
                  msg:[NSString stringWithFormat:@"No passcode provider exists for provider '%@'.  Use [SFPasscodeProviderManager addPasscodeProvider:] to configure a new provider.", providerName]];
    } else {
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setObject:providerName forKey:kSFCurrentPasscodeProviderUserDefaultsKey];
        [defs synchronize];
    }
}

+ (void)resetCurrentPasscodeProviderName
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs removeObjectForKey:kSFCurrentPasscodeProviderUserDefaultsKey];
    [defs synchronize];
}

+ (id<SFPasscodeProvider>)currentPasscodeProvider
{
    return [SFPasscodeProviderManager passcodeProviderForProviderName:[SFPasscodeProviderManager currentPasscodeProviderName]];
}

+ (id<SFPasscodeProvider>)passcodeProviderForProviderName:(SFPasscodeProviderId)providerName
{
    return (id<SFPasscodeProvider>)PasscodeProviderMap[providerName];
}

+ (void)addPasscodeProvider:(id<SFPasscodeProvider>)provider
{
    NSAssert(provider != nil, @"provider must not be nil.");
    NSString *newProviderName = provider.providerName;
    id<SFPasscodeProvider> existingProvider = PasscodeProviderMap[newProviderName];
    if (existingProvider != nil) {
        [SFLogger log:[SFPasscodeProviderManager class]
                level:SFLogLevelError
                  msg:[NSString stringWithFormat:@"A passcode provider is already configured for '%@'.  Will not overwrite the current provider.", newProviderName]];
    } else {
        PasscodeProviderMap[newProviderName] = provider;
    }
}

+ (void)removePasscodeProviderWithName:(NSString *)providerName
{
    NSAssert(providerName != nil, @"providerName must not be nil.");
    id<SFPasscodeProvider> existingProvider = [SFPasscodeProviderManager passcodeProviderForProviderName:providerName];
    if (existingProvider == nil) {
        [SFLogger log:[SFPasscodeProviderManager class]
                level:SFLogLevelWarning
                  msg:[NSString stringWithFormat:@"Passcode provider with name '%@' does not exist.  No action will be taken.", providerName]];
        return;
    }
    
    [PasscodeProviderMap removeObjectForKey:providerName];
    NSString *currentProviderName = [SFPasscodeProviderManager currentPasscodeProviderName];
    if ([currentProviderName isEqualToString:providerName]) {
        [SFLogger log:[SFPasscodeProviderManager class]
                level:SFLogLevelInfo
                  msg:[NSString stringWithFormat:@"Passcode provider with name '%@' was configured as the current provider.  Current provider will be reset to the default.", providerName]];
        [SFPasscodeProviderManager resetCurrentPasscodeProviderName];
    }
}

@end
