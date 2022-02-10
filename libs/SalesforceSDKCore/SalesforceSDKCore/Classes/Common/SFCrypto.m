/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFCrypto.h"
#import "NSString+SFAdditions.h"
#import "NSData+SFAdditions.h"
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import <SalesforceSDKCommon/SalesforceSDKCommon-Swift.h>

NSString * const kKeychainIdentifierBaseAppId = @"com.salesforce.security.baseappid";
static NSString * const kKeychainIdentifierSimulatorBaseAppId = @"com.salesforce.security.baseappid.sim";


@implementation SFCrypto

+ (BOOL)baseAppIdentifierIsConfigured {
    return [[NSUserDefaults msdkUserDefaults] boolForKey:kKeychainIdentifierBaseAppId];
}

+ (void)setBaseAppIdentifierIsConfigured:(BOOL)isConfigured {
    [[NSUserDefaults msdkUserDefaults] setBool:isConfigured forKey:kKeychainIdentifierBaseAppId];
    [[NSUserDefaults msdkUserDefaults] synchronize];
}

static BOOL sBaseAppIdConfiguredThisLaunch = NO;
+ (BOOL)baseAppIdentifierConfiguredThisLaunch {
    return sBaseAppIdConfiguredThisLaunch;
}
+ (void)setBaseAppIdentifierConfiguredThisLaunch:(BOOL)configuredThisLaunch {
    sBaseAppIdConfiguredThisLaunch = configuredThisLaunch;
}

+ (NSString *)baseAppIdentifier {
#if TARGET_IPHONE_SIMULATOR
    return [self simulatorBaseAppIdentifier];
#else
    return [self deviceBaseAppIdentifier];
#endif
}

+ (BOOL)setBaseAppIdentifier:(NSString *)appId {
#if TARGET_IPHONE_SIMULATOR
    return [self setSimulatorBaseAppIdentifier:appId];
#else
    return [self setDeviceBaseAppIdentifier:appId];
#endif
}

+ (NSString *)simulatorBaseAppIdentifier {
    NSString *baseAppId = nil;
    BOOL hasBaseAppId = [self baseAppIdentifierIsConfigured];
    if (!hasBaseAppId) {
        baseAppId = [[NSUUID UUID] UUIDString];
        [self setSimulatorBaseAppIdentifier:baseAppId];
        [self setBaseAppIdentifierIsConfigured:YES];
        [self setBaseAppIdentifierConfiguredThisLaunch:YES];
    } else {
        baseAppId = [[NSUserDefaults standardUserDefaults] objectForKey:kKeychainIdentifierSimulatorBaseAppId];
    }
    return baseAppId;
}

+ (BOOL)setSimulatorBaseAppIdentifier:(NSString *)appId {
    [[NSUserDefaults standardUserDefaults] setObject:appId forKey:kKeychainIdentifierSimulatorBaseAppId];
    return [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)deviceBaseAppIdentifier {
    static NSString *baseAppId = nil;
    
    @synchronized (self) {
        BOOL hasBaseAppId = [self baseAppIdentifierIsConfigured];
        if (!hasBaseAppId) {
            // Value hasn't yet been (successfully) persisted to the keychain.
            [SFSDKCoreLogger i:[self class] format:@"Base app identifier not configured.  Creating a new value."];
            if (baseAppId == nil)
                baseAppId = [[NSUUID UUID] UUIDString];
            BOOL creationSuccess = [self setDeviceBaseAppIdentifier:baseAppId];
            if (!creationSuccess) {
                [SFSDKCoreLogger e:[self class] format:@"Could not persist the base app identifier.  Returning in-memory value."];
            } else {
                [self setBaseAppIdentifierIsConfigured:YES];
                [self setBaseAppIdentifierConfiguredThisLaunch:YES];
            }
        } else {
            SFSDKKeychainResult *result =  [SFSDKKeychainHelper readWithService:kKeychainIdentifierBaseAppId account:nil];
            NSData *keychainAppIdData = result.data;
            NSString *keychainAppId = [[NSString alloc] initWithData:keychainAppIdData encoding:NSUTF8StringEncoding];
            if (result.error || keychainAppIdData == nil || keychainAppId == nil) {
                // Something went wrong either storing or retrieving the value from the keychain.  Try to rewrite the value.
                [SFSDKCoreLogger e:[self class] format:@"App id keychain data missing or corrupted.  Attempting to reset."];
                [self setBaseAppIdentifierIsConfigured:NO];
                [self setBaseAppIdentifierConfiguredThisLaunch:NO];
                if (baseAppId == nil)
                    baseAppId = [[NSUUID UUID] UUIDString];
                BOOL creationSuccess = [self setDeviceBaseAppIdentifier:baseAppId];
                if (!creationSuccess) {
                    [SFSDKCoreLogger e:[self class] format:@"Could not persist the base app identifier.  Returning in-memory value."];
                } else {
                    [self setBaseAppIdentifierIsConfigured:YES];
                    [self setBaseAppIdentifierConfiguredThisLaunch:YES];
                }
            } else {
                // Successfully retrieved the value.  Set the baseAppId accordingly.
                baseAppId = keychainAppId;
            }
        }
        
        return baseAppId;
    }
}

+ (BOOL)setDeviceBaseAppIdentifier:(NSString *)appId {
    static NSUInteger maxRetries = 3;
    
    // Store the app ID value in the keychain.
    NSError *error = nil;
    [SFSDKCoreLogger i:[self class] format:@"Saving the new base app identifier to the keychain."];
    SFSDKKeychainResult *result = [SFSDKKeychainHelper createIfNotPresentWithService:kKeychainIdentifierBaseAppId account:nil];
    NSData *appIdData = result.data;
    NSUInteger currentRetries = 0;
    OSStatus keychainResult = -1;
    while (currentRetries < maxRetries && keychainResult != noErr) {
        result = [SFSDKKeychainHelper writeWithService:kKeychainIdentifierBaseAppId data:appIdData account:nil];
        keychainResult  = result.status;
        if (!result.success) {
            [SFSDKCoreLogger w:[self class] format:@"Could not save the base app identifier to the keychain (result: %@).  Retrying.", [error localizedDescription]];
        }
        currentRetries++;
    }
    if (keychainResult != noErr) {
        [SFSDKCoreLogger e:[self class] format:@"Giving up on saving the base app identifier to the keychain (result: %@).", [error localizedDescription]];
        return NO;
    }
    
    [SFSDKCoreLogger i:[self class] format:@"Successfully created a new base app identifier and stored it in the keychain."];
    return YES;
}

@end
