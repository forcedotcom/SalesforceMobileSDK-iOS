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

#import "SFSDKDatasharingHelper.h"

NSString * const kAppGroupEnabled = @"kAccessGroupEnabled";
NSString * const kKeychainSharingEnabled = @"kKeyChainSharingEnabled";

NSString * const KAppGroupName = @"KAppGroupName";
NSString * const KKeychainGroupName = @"KKeychainGroupName";

@implementation SFSDKDatasharingHelper

+ (instancetype)sharedInstance {
    static dispatch_once_t pred;
    static SFSDKDatasharingHelper *dataSharingHelper = nil;
    dispatch_once(&pred, ^{
        dataSharingHelper = [[self alloc] init];
    });
    return dataSharingHelper;
}


- (NSString *)appGroupName {
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    return [standardDefaults stringForKey:KAppGroupName];
}

- (void)setAppGroupName:(NSString *)appGroupName {
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    [standardDefaults setObject:appGroupName forKey:KAppGroupName];
    [standardDefaults synchronize];
}

- (NSString *)keychainGroupName {
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    return [standardDefaults stringForKey:KKeychainGroupName];
}

- (void)setKeychainGroupName:(NSString *)keychainGroupName{
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    [standardDefaults setObject:keychainGroupName forKey:KKeychainGroupName];
    [standardDefaults synchronize];
}

- (void)setAppGroupEnabled:(BOOL)appGroupEnabled {
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.appGroupName];
    [sharedDefaults setBool:appGroupEnabled forKey:kAppGroupEnabled];
    [sharedDefaults synchronize];
}

- (BOOL)appGroupEnabled {
     NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.appGroupName];
     return [sharedDefaults boolForKey:kAppGroupEnabled];
}

- (void)setKeychainSharingEnabled:(BOOL)keychainSharingEnabled {
     NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.keychainGroupName];
    [sharedDefaults setBool:keychainSharingEnabled forKey:kKeychainSharingEnabled];
    [sharedDefaults synchronize];
}

- (BOOL)keychainSharingEnabled {
#if TARGET_IPHONE_SIMULATOR
    //From Apple
    // Ignore the access group if running on the iPhone simulator.
    // Apps that are built for the simulator aren't signed, so there's no keychain access group
    // for the simulator to check. This means that all apps can see all keychain items when run
    // on the simulator.
    //
    // If a SecItem contains an access group attribute, SecItemAdd and SecItemUpdate on the
    // simulator will return -25243 (errSecNoAccessForItem).
    return NO;
#else
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.keychainGroupName];
    return [sharedDefaults boolForKey:kKeychainSharingEnabled];
#endif
}

@end
