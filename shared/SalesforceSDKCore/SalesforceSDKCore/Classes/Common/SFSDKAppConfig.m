//
//  SFSDKAppConfig.m
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 9/26/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

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
