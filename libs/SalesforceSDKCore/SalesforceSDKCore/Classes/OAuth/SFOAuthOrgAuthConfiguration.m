/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFOAuthOrgAuthConfiguration.h"

static NSString * const kAuthConfigMobileSDKKey        = @"MobileSDK";
static NSString * const kAuthConfigUseNativeBrowserKey = @"UseiOSNativeBrowserForAuthentication";
static NSString * const kAuthConfigSamlProvidersKey    = @"SamlProviders";
static NSString * const kAuthConfigAuthProvidersKey    = @"AuthProviders";
static NSString * const kAuthConfigSSOUrlKey           = @"SsoUrl";
static NSString * const kAuthConfigLoginPageKey        = @"LoginPage";
static NSString * const kAuthConfigLoginPageUrlKey     = @"LoginPageUrl";

@interface SFOAuthOrgAuthConfiguration ()

@property (nonatomic, strong, readwrite) NSDictionary *authConfigDict;

@end

@implementation SFOAuthOrgAuthConfiguration

@synthesize authConfigDict = _authConfigDict;

- (id)initWithConfigDict:(NSDictionary *)authConfigDict {
    self = [super init];
    if (self) {
        self.authConfigDict = authConfigDict;
    }
    return self;
}

- (BOOL)useNativeBrowserForAuth {
    return [self.authConfigDict[kAuthConfigMobileSDKKey][kAuthConfigUseNativeBrowserKey] boolValue];
}

- (NSArray<NSString *> *)ssoUrls {
    NSMutableArray<NSString *> *ssoUrls = [[NSMutableArray alloc] init];

    // Parses SAML provider list and adds it to the list of SSO URLs.
    NSArray *samlProviders = self.authConfigDict[kAuthConfigSamlProvidersKey];
    if (samlProviders && samlProviders.count > 0) {
        for (int i = 0; i < samlProviders.count; i++) {
            NSDictionary *provider = samlProviders[i];
            if (provider) {
                ssoUrls[i] = provider[kAuthConfigSSOUrlKey];
            }
        }
    }

    // Parses auth provider list and adds it to the list of SSO URLs.
    NSUInteger curPos = samlProviders.count;
    NSArray *authProviders = self.authConfigDict[kAuthConfigAuthProvidersKey];
    if (authProviders && authProviders.count > 0) {
        for (int i = 0; i < authProviders.count; i++) {
            NSDictionary *provider = authProviders[i];
            if (provider) {
                ssoUrls[curPos + i] = provider[kAuthConfigSSOUrlKey];
            }
        }
    }
    return ssoUrls;
}

- (NSString *)loginPageUrl {
    NSString *loginPageUrl = nil;
    NSDictionary *loginPage = self.authConfigDict[kAuthConfigLoginPageKey];
    if (![loginPage isKindOfClass:[NSNull class]] && [loginPage count] > 0) {
        loginPageUrl = loginPage[kAuthConfigLoginPageUrlKey];
    }
    return loginPageUrl;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@:%p> authConfigDict: %@", NSStringFromClass([self class]), self, self.authConfigDict];
}

@end
