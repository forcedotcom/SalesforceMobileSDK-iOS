/*
 Copyright (c) 2013, salesforce.com, inc. All rights reserved.
 Author: Bharath Hariharan
 
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

#import "SFHybridViewConfig.h"
#import <SalesforceSDKCore/SFJsonUtils.h>

@interface SFHybridViewConfig ()

/**
 * The backing dictionary containing the configuration properties.
 */
@property (nonatomic, strong) NSMutableDictionary *configDict;

/**
 * Reads the contents of a bootconfig.json file into an NSDictionary.
 * @return The NSDictionary of data, or nil if the data could not be read or parsed.
 */
+ (NSDictionary *)loadConfigFromFile:(NSString *)configFilePath;

/**
 * Sets the default properties in the configuration, for properties that haven't otherwise
 * been specified after initialization.
 */
- (void)setConfigDefaults;

@end

// Keys used in bootconfig.json.
static NSString* const kRemoteAccessConsumerKey = @"remoteAccessConsumerKey";
static NSString* const kOauthRedirectURI = @"oauthRedirectURI";
static NSString* const kOauthScopes = @"oauthScopes";
static NSString* const kIsLocal = @"isLocal";
static NSString* const kStartPage = @"startPage";
static NSString* const kErrorPage = @"errorPage";
static NSString* const kShouldAuthenticate = @"shouldAuthenticate";
static NSString* const kAttemptOfflineLoad = @"attemptOfflineLoad";

// Default path to bootconfig.json on the filesystem.
static NSString* const kDefaultHybridViewConfigFilePath = @"/www/bootconfig.json";

// Default values for optional configs.
static BOOL const kDefaultShouldAuthenticate = YES;
static BOOL const kDefaultAttemptOfflineLoad = YES;
static NSString* const kDefaultStartPage = @"index.html";
static NSString* const kDefaultErrorPage = @"error.html";


@implementation SFHybridViewConfig

@synthesize configDict = _configDict;

#pragma mark - Init / dealloc / overrides

- (id)init
{
    return [self initWithDict:nil];
}

- (id)initWithDict:(NSDictionary *)configDict
{
    self = [super init];
    if (self) {
        if (configDict == nil) {
            self.configDict = [NSMutableDictionary dictionary];
        } else {
            self.configDict = [NSMutableDictionary dictionaryWithDictionary:configDict];
        }
        
        // Set defaults for non-existent values.
        [self setConfigDefaults];
    }
    
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p data: %@>", NSStringFromClass([self class]), self, [self.configDict description]];
}

#pragma mark - Properties

- (NSString *)remoteAccessConsumerKey
{
    return [self.configDict objectForKey:kRemoteAccessConsumerKey];
}

- (void)setRemoteAccessConsumerKey:(NSString *)remoteAccessConsumerKey
{
    [self.configDict setObject:[remoteAccessConsumerKey copy] forKey:kRemoteAccessConsumerKey];
}

- (NSString *)oauthRedirectURI
{
    return [self.configDict objectForKey:kOauthRedirectURI];
}

- (void)setOauthRedirectURI:(NSString *)oauthRedirectURI
{
    [self.configDict setObject:[oauthRedirectURI copy] forKey:kOauthRedirectURI];
}

- (NSSet *)oauthScopes
{
    return [NSSet setWithArray:[self.configDict objectForKey:kOauthScopes]];
}

- (void)setOauthScopes:(NSSet *)oauthScopes
{
    [self.configDict setObject:[oauthScopes allObjects] forKey:kOauthScopes];
}

- (BOOL)isLocal
{
    return [[self.configDict objectForKey:kIsLocal] boolValue];
}

- (void)setIsLocal:(BOOL)isLocal
{
    NSNumber *isLocalNum = [NSNumber numberWithBool:isLocal];
    [self.configDict setObject:isLocalNum forKey:kIsLocal];
}

- (NSString *)startPage
{
    return [self.configDict objectForKey:kStartPage];
}

- (void)setStartPage:(NSString *)startPage
{
    [self.configDict setObject:[startPage copy] forKey:kStartPage];
}

- (NSString *)errorPage
{
    return [self.configDict objectForKey:kErrorPage];
}

- (void)setErrorPage:(NSString *)errorPage
{
    [self.configDict setObject:[errorPage copy] forKey:kErrorPage];
}

- (BOOL)shouldAuthenticate
{
    return [[self.configDict objectForKey:kShouldAuthenticate] boolValue];
}

- (void)setShouldAuthenticate:(BOOL)shouldAuthenticate
{
    NSNumber *shouldAuthenticateNum = [NSNumber numberWithBool:shouldAuthenticate];
    [self.configDict setObject:shouldAuthenticateNum forKey:kShouldAuthenticate];
}

- (BOOL)attemptOfflineLoad
{
    return [[self.configDict objectForKey:kAttemptOfflineLoad] boolValue];
}

- (void)setAttemptOfflineLoad:(BOOL)attemptOfflineLoad
{
    NSNumber *attemptOfflineLoadNum = [NSNumber numberWithBool:attemptOfflineLoad];
    [self.configDict setObject:attemptOfflineLoadNum forKey:kAttemptOfflineLoad];
}

#pragma mark - Configuration helpers

+ (SFHybridViewConfig *)fromDefaultConfigFile
{
    return [SFHybridViewConfig fromConfigFile:kDefaultHybridViewConfigFilePath];
}

+ (SFHybridViewConfig *)fromConfigFile:(NSString *)configFilePath
{
    NSDictionary *hybridConfigDict = [SFHybridViewConfig loadConfigFromFile:configFilePath];
    if (nil == hybridConfigDict) {
        [SFLogger log:[SFHybridViewConfig class] level:SFLogLevelWarning msg:[NSString stringWithFormat:@"Hybrid view config at specified path '%@' not found, or data could not be parsed.", configFilePath]];
        return nil;
    }
    
    SFHybridViewConfig *hybridViewConfig = [[SFHybridViewConfig alloc] initWithDict:hybridConfigDict];
    return hybridViewConfig;
}

+ (NSDictionary *)loadConfigFromFile:(NSString *)configFilePath
{
    NSString *fullPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:configFilePath];
    NSError *fileReadError = nil;
    NSData *fileContents = [NSData dataWithContentsOfFile:fullPath options:NSDataReadingUncached error:&fileReadError];
    if (fileContents == nil) {
        [SFLogger log:[SFHybridViewConfig class] level:SFLogLevelError msg:[NSString stringWithFormat:@"Hybrid view config at specified path '%@' could not be read: %@", configFilePath, fileReadError]];
        return nil;
    }
    
    NSDictionary *jsonDict = [SFJsonUtils objectFromJSONData:fileContents];
    return jsonDict;
}

- (void)setConfigDefaults
{
    // Any default values that would not be the implicit defaults of nil values, should be set here.
    
    if ([self.configDict objectForKey:kAttemptOfflineLoad] == nil) {
        self.attemptOfflineLoad = kDefaultAttemptOfflineLoad;
    }
    if ([self.configDict objectForKey:kShouldAuthenticate] == nil) {
        self.shouldAuthenticate = kDefaultShouldAuthenticate;
    }
    if (self.startPage == nil) {
        self.startPage = kDefaultStartPage;
        self.isLocal = YES;
    }
    if (self.errorPage == nil) {
        self.errorPage = kDefaultErrorPage;
    }
}

@end
