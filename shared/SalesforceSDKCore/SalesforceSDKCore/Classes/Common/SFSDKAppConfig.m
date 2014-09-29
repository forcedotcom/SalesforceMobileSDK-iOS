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

#import "SFSDKAppConfig.h"

static NSString* const kRemoteAccessConsumerKey = @"remoteAccessConsumerKey";
static NSString* const kOauthRedirectURI = @"oauthRedirectURI";
static NSString* const kOauthScopes = @"oauthScopes";
static NSString* const kShouldAuthenticate = @"shouldAuthenticate";
static BOOL const kDefaultShouldAuthenticate = YES;

@implementation SFSDKAppConfig

- (instancetype)init
{
    return [self initWithDict:nil];
}

- (instancetype)initWithDict:(NSDictionary *)configDict
{
    self = [super init];
    if (self) {
        if (configDict == nil) {
            self.configDict = [NSMutableDictionary dictionary];
        } else {
            self.configDict = [NSMutableDictionary dictionaryWithDictionary:configDict];
        }
        
        if ((self.configDict)[kShouldAuthenticate] == nil) {
            self.shouldAuthenticate = kDefaultShouldAuthenticate;
        }
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@:%p data: %@>", NSStringFromClass([self class]), self, [self.configDict description]];
}

#pragma mark - Properties

- (NSString *)remoteAccessConsumerKey
{
    return (self.configDict)[kRemoteAccessConsumerKey];
}

- (void)setRemoteAccessConsumerKey:(NSString *)remoteAccessConsumerKey
{
    self.configDict[kRemoteAccessConsumerKey] = [remoteAccessConsumerKey copy];
}

- (NSString *)oauthRedirectURI
{
    return (self.configDict)[kOauthRedirectURI];
}

- (void)setOauthRedirectURI:(NSString *)oauthRedirectURI
{
    self.configDict[kOauthRedirectURI] = [oauthRedirectURI copy];
}

- (NSSet *)oauthScopes
{
    return [NSSet setWithArray:(self.configDict)[kOauthScopes]];
}

- (void)setOauthScopes:(NSSet *)oauthScopes
{
    self.configDict[kOauthScopes] = [oauthScopes allObjects];
}

- (BOOL)shouldAuthenticate
{
    return [(self.configDict)[kShouldAuthenticate] boolValue];
}

- (void)setShouldAuthenticate:(BOOL)shouldAuthenticate
{
    NSNumber *shouldAuthenticateNum = @(shouldAuthenticate);
    self.configDict[kShouldAuthenticate] = shouldAuthenticateNum;
}

@end
