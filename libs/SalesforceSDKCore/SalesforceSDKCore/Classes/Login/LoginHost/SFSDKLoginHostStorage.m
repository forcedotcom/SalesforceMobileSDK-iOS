/*
 SFSDKLoginHostStorage.m
 SalesforceSDKCore
 
 Created by Kunal Chitalia on 1/22/16.
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKLoginHostStorage.h"
#import "SFSDKLoginHost.h"
#import "SFManagedPreferences.h"
#import "SFSDKResourceUtils.h"

@interface SFSDKLoginHostStorage ()

@property (nonatomic, strong) NSMutableArray *loginHostList;

@end

// Key under which the list of login hosts will be stored in the user defaults.
static NSString * const SFSDKLoginHostList = @"SalesforceLoginHostListPrefs";

// Key for the host.
static NSString * const SFSDKLoginHostKey = @"SalesforceLoginHostKey";

// Key for the name.
static NSString * const SFSDKLoginHostNameKey = @"SalesforceLoginHostNameKey";

@implementation SFSDKLoginHostStorage

@synthesize loginHostList = _loginHostList;

+ (SFSDKLoginHostStorage *)sharedInstance {
    static SFSDKLoginHostStorage *instance = nil;
    if (!instance) {
        instance = [[self alloc] init];
    }
    return instance;
}

- (id)init {
    self = [super init];
    if (self) {
        self.loginHostList = [NSMutableArray array];
        SFManagedPreferences *managedPreferences = [SFManagedPreferences sharedPreferences];

        // Add the Production and Sandbox login hosts, unless an MDM policy explicitly forbids this.
        if (!(managedPreferences.hasManagedPreferences && managedPreferences.onlyShowAuthorizedHosts)) {
            [self.loginHostList addObject:[SFSDKLoginHost hostWithName:[SFSDKResourceUtils localizedString:@"LOGIN_SERVER_PRODUCTION"] host:@"login.salesforce.com" deletable:NO]];
            [self.loginHostList addObject:[SFSDKLoginHost hostWithName:[SFSDKResourceUtils localizedString:@"LOGIN_SERVER_SANDBOX"] host:@"test.salesforce.com" deletable:NO]];
        }

        // Load from managed preferences (e.g. MDM).
        if (managedPreferences.hasManagedPreferences) {

            /*
             * If there are any existing login hosts, remove them as MDM should take
             * highest priority and only the hosts enforced by MDM should be in the list.
             */
            if([self.loginHostList count] > 0) {
                [self removeAllLoginHosts];
            }
            NSArray *hostLabels = managedPreferences.loginHostLabels;
            [managedPreferences.loginHosts enumerateObjectsUsingBlock:^(NSString *loginHost, NSUInteger idx, BOOL *stop) {
                NSString *hostLabel = hostLabels.count > idx ? hostLabels[idx] : loginHost;
                [self.loginHostList addObject:[SFSDKLoginHost hostWithName:hostLabel host:loginHost deletable:NO]];
            }];
            
            if(managedPreferences.onlyShowAuthorizedHosts)
                return self;
        }
        
        // Load from info.plist.
        if([[NSBundle mainBundle] objectForInfoDictionaryKey:@"SFDCOAuthLoginHost"]) {
            NSString *customHost = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SFDCOAuthLoginHost"];

            // Add the login host from info.plist only if it is not already added.
            if(![self loginHostForHostAddress:customHost]) {
                [self.loginHostList addObject:[SFSDKLoginHost hostWithName:customHost host:customHost deletable:NO]];
            }
        }

        // Load from the user defaults.
        NSArray *persistedList = [[NSUserDefaults standardUserDefaults] objectForKey:SFSDKLoginHostList];
        if (persistedList) {
            for (NSDictionary *dic in persistedList) {
                [self.loginHostList addObject:[SFSDKLoginHost hostWithName:[dic objectForKey:SFSDKLoginHostNameKey]
                                                                      host:[dic objectForKey:SFSDKLoginHostKey]
                                                                 deletable:YES]];
            }
        }
    }
    return self;
}

- (void)save {
    NSMutableArray *persistedList = [NSMutableArray arrayWithCapacity:10];
    for (SFSDKLoginHost *host in self.loginHostList) {
        if (host.isDeletable) {
            NSMutableDictionary *dic = [NSMutableDictionary dictionary];
            NSString *hostName = host.name ? : @"";
            NSString *hostAddress = host.host ? : hostName;
            [dic setObject:hostName forKey:SFSDKLoginHostNameKey];
            [dic setObject:hostAddress forKey:SFSDKLoginHostKey];
            [persistedList addObject:dic];
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:persistedList forKey:SFSDKLoginHostList];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)addLoginHost:(SFSDKLoginHost *)loginHost {
    [self.loginHostList addObject:loginHost];
    [self save];
}

- (void)removeLoginHostAtIndex:(NSUInteger)index {
    [self.loginHostList removeObjectAtIndex:index];
    [self save];
}

- (NSUInteger)indexOfLoginHost:(SFSDKLoginHost *)host{
    if ([self.loginHostList containsObject:host]) {
        return [self.loginHostList indexOfObject:host];
    }
    return NSNotFound;
}

- (SFSDKLoginHost *)loginHostAtIndex:(NSUInteger)index {
    return [self.loginHostList objectAtIndex:index];
}

- (SFSDKLoginHost *)loginHostForHostAddress:(NSString *)hostAddress {
    for (SFSDKLoginHost *host in self.loginHostList) {
        if ([host.host isEqualToString:hostAddress]) {
            return host;
        }
    }
    return nil;
}

- (void)removeAllLoginHosts {
    SFManagedPreferences *managedPreferences = [SFManagedPreferences sharedPreferences];
    NSUInteger startingIndex = 2;

    /*
     * If MDM policy is set to hide hosts, 'Production' and 'Sandbox' won't be on the list.
     */
    if (managedPreferences.hasManagedPreferences && managedPreferences.onlyShowAuthorizedHosts) {
        startingIndex = 0;
    }
    [self.loginHostList removeObjectsInRange:NSMakeRange(startingIndex, [self.loginHostList count] - 2)];
}

- (NSUInteger)numberOfLoginHosts {
    return [self.loginHostList count];
}

@end

