/*
 SFSDKOAuthClientCache.m
 SalesforceSDKCore

 Created by Raj Rao on 9/27/17.

 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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

#import "SFSDKOAuthClientCache.h"
#import "SFSDKOAuthClient.h"
#import "SFSDKSafeMutableDictionary.h"
#import "SFSDKOAuthClientConfig.h"
#import "SFSDKAuthPreferences.h"

static NSString *const kSFBasicSuffix = @"BASIC";
static NSString *const kSFIDPSuffix = @"IDP";
static NSString *const kSFAdvancedSuffix = @"ADVANCED";

@interface SFSDKOAuthClientCache()
@property (nonatomic,strong) SFSDKSafeMutableDictionary * _Nonnull oauthClientInstances;
@end

@implementation SFSDKOAuthClientCache

- (instancetype)init {
    if (self = [super init]) {
        _oauthClientInstances = [[SFSDKSafeMutableDictionary alloc] init];
    }
    return  self;
}

- (SFSDKOAuthClient *)clientForKey:(NSString *)key {
    return [self.oauthClientInstances objectForKey:key];
}

- (void)addClient:(SFSDKOAuthClient *)client{
    NSString *key = [[self class] keyFromClient:client];
    [self.oauthClientInstances setObject:client forKey:key];
}

- (void)addClient:(SFSDKOAuthClient *)client forKey:(NSString *)key {
    [self.oauthClientInstances setObject:client forKey:key];
}

- (void)removeClient:(SFSDKOAuthClient *)client {
    NSString *key = [[self class] keyFromClient:client];
    [self.oauthClientInstances removeObject:key];
}

- (void)removeClientForKey:(NSString *)key {
    [self.oauthClientInstances removeObject:key];
}

- (void)removeAllClients {
    [self.oauthClientInstances removeAllObjects];
}

+ (NSString *)keyFromCredentials:(SFOAuthCredentials *)credentials {
    SFSDKAuthPreferences *preferences = [[SFSDKAuthPreferences alloc] init];
    SFOAuthClientKeyType clientType =  SFOAuthClientKeyTypeBasic;
    if (preferences.isIdentityProvider || preferences.idpEnabled) {
        clientType = SFOAuthClientKeyTypeIDP;
    }else if (preferences.advancedAuthConfiguration == SFOAuthAdvancedAuthConfigurationRequire) {
        clientType = SFOAuthClientKeyTypeAdvanced;
    }
    return [self keyFromCredentials:credentials type:clientType];
    
}
+ (NSString *)keyFromCredentials:(SFOAuthCredentials *)credentials type:(SFOAuthClientKeyType)clientType {
    return [NSString stringWithFormat:@"%@-%lu", credentials.identifier,(unsigned long)clientType];
}

+ (NSString *)keyFromIdentifierPrefixWithType:(NSString *)prefix type:(SFOAuthClientKeyType)clientType {
    return [NSString stringWithFormat:@"%@-%lu", prefix,(unsigned long)clientType];
}


+ (NSString *)keyFromClient:(SFSDKOAuthClient *)client{

    SFOAuthClientKeyType clientType = SFOAuthClientKeyTypeBasic;

    if (client.config.idpEnabled)
        clientType = SFOAuthClientKeyTypeIDP;
    else if (client.config.advancedAuthConfiguration == SFOAuthAdvancedAuthConfigurationRequire)
        clientType = SFOAuthClientKeyTypeAdvanced;

    return [NSString stringWithFormat:@"%@-%lu", client.credentials.identifier, (unsigned long)clientType];
}

+ (SFSDKOAuthClientCache *)sharedInstance {
    static SFSDKOAuthClientCache *_instance = nil;

    @synchronized (self) {
        if (_instance == nil) {
            _instance = [[self alloc] init];
        }
    }

    return _instance;
}
@end
