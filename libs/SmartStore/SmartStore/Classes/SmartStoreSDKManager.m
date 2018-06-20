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

#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import "SFSmartStore.h"
#import "SmartStoreSDKManager.h"
#import "SFSDKStoreConfig.h"
#import "SFSmartStoreInspectorViewController.h"

SFSDK_USE_DEPRECATED_BEGIN
@interface SalesforceSDKManager()<SFAuthenticationManagerDelegate>
@end

@implementation SmartStoreSDKManager

-(instancetype)init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUserWillLogout:)  name:kSFNotificationUserWillLogout object:nil];
    }
    return self;
}


- (void)authManager:(SFAuthenticationManager *)manager willLogoutUser:(SFUserAccount *)user
{
    [super authManager:manager willLogoutUser:user];
    [SFSmartStore removeAllStoresForUser:user];
}


- (void)handleUserWillLogout:(NSNotification *)notification {
    SFUserAccount *user = notification.userInfo[kSFNotificationUserInfoAccountKey];
    [SFSmartStore removeAllStoresForUser:user];
}

- (void) setupGlobalStoreFromDefaultConfig {
    NSString *configPath = [self pathForGlobalStoreConfig];
    [SFSDKSmartStoreLogger d:[self class] format:@"Setting up global store using config found in %@", configPath];
    SFSDKStoreConfig* storeConfig = [[SFSDKStoreConfig alloc] initWithResourceAtPath:configPath];
    if ([storeConfig hasSoups]) {
        [storeConfig registerSoups:[SFSmartStore sharedGlobalStoreWithName:kDefaultSmartStoreName]];
    }
}

- (void) setupUserStoreFromDefaultConfig {
    NSString *configPath = [self pathForUserStoreConfig];
    [SFSDKSmartStoreLogger d:[self class] format:@"Setting up user store using config found in %@", configPath];
    SFSDKStoreConfig* storeConfig = [[SFSDKStoreConfig alloc] initWithResourceAtPath:configPath];
    if ([storeConfig hasSoups]) {
        [storeConfig registerSoups:[SFSmartStore sharedStoreWithName:kDefaultSmartStoreName]];
    }
}

- (NSString*) pathForGlobalStoreConfig {
    return @"globalstore.json";
}

- (NSString*) pathForUserStoreConfig {
    return @"userstore.json";
}


#pragma mark - Dev support methods

-(NSArray*) getDevActions:(UIViewController *)presentedViewController
{
    NSMutableArray * devActions = [NSMutableArray arrayWithArray:[super getDevActions:presentedViewController]];
    [devActions addObjectsFromArray:@[
            @"Inspect SmartStore", ^{
                SFSmartStoreInspectorViewController *devInfo = [[SFSmartStoreInspectorViewController alloc] init];
                [presentedViewController presentViewController:devInfo animated:NO completion:nil];
            }
    ]];
    return devActions;
}

- (NSArray*) getDevSupportInfos
{
    SFSmartStore *store = [SFSmartStore sharedGlobalStoreWithName:kDefaultSmartStoreName];
    NSMutableArray * devInfos = [NSMutableArray arrayWithArray:[super getDevSupportInfos]];
    [devInfos addObjectsFromArray:@[
            @"SQLCipher version", [store getSQLCipherVersion],
            @"SQLCipher Compile Options", [[store getCompileOptions] componentsJoinedByString:@", "],
            @"User Stores", [self safeJoin:[SFSmartStore allStoreNames] separator:@", "],
            @"Global Stores", [self safeJoin:[SFSmartStore allGlobalStoreNames] separator:@", "]
    ]];
    return devInfos;
}

- (NSString*) safeJoin:(NSArray*)array separator:(NSString*)separator {
    return array ? [array componentsJoinedByString:separator] : @"";
}


@end
SFSDK_USE_DEPRECATED_END
