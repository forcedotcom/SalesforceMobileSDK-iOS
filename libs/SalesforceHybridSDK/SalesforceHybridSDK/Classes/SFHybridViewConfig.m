/*
 Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.
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
#import <SalesforceSDKCore/SFSDKResourceUtils.h>

@interface SFHybridViewConfig ()

/**
 * Sets the default properties in the configuration, for properties that haven't otherwise
 * been specified after initialization.
 */
- (void)setConfigDefaults;

@end

// Keys used in bootconfig.json.
static NSString* const kIsLocal = @"isLocal";
static NSString* const kStartPage = @"startPage";
static NSString* const kUnauthenticatedStartPage = @"unauthenticatedStartPage";
static NSString* const kErrorPage = @"errorPage";
static NSString* const kAttemptOfflineLoad = @"attemptOfflineLoad";

// Default values for optional configs.
static BOOL const kDefaultAttemptOfflineLoad = YES;
static NSString* const kDefaultStartPage = @"index.html";
static NSString* const kDefaultErrorPage = @"error.html";


@implementation SFHybridViewConfig

#pragma mark - Init / dealloc / overrides

- (id)initWithDict:(NSDictionary *)configDict
{
    self = [super initWithDict:configDict];
    if (self) {

        // Set defaults for non-existent values.
        [self setConfigDefaults];
    }
    return self;
}

#pragma mark - Properties

- (BOOL)isLocal
{
    return [(self.configDict)[kIsLocal] boolValue];
}

- (void)setIsLocal:(BOOL)isLocal
{
    NSNumber *isLocalNum = @(isLocal);
    self.configDict[kIsLocal] = isLocalNum;
}

- (NSString *)startPage
{
    return (self.configDict)[kStartPage];
}

- (void)setStartPage:(NSString *)startPage
{
    self.configDict[kStartPage] = [startPage copy];
}

- (NSString *)unauthenticatedStartPage
{
    return (self.configDict)[kUnauthenticatedStartPage];
}

- (void)setUnauthenticatedStartPage:(NSString *)unauthenticatedStartPage
{
    self.configDict[kUnauthenticatedStartPage] = [unauthenticatedStartPage copy];
}

- (NSString *)errorPage
{
    return (self.configDict)[kErrorPage];
}

- (void)setErrorPage:(NSString *)errorPage
{
    self.configDict[kErrorPage] = [errorPage copy];
}

- (BOOL)attemptOfflineLoad
{
    return [(self.configDict)[kAttemptOfflineLoad] boolValue];
}

- (void)setAttemptOfflineLoad:(BOOL)attemptOfflineLoad
{
    NSNumber *attemptOfflineLoadNum = @(attemptOfflineLoad);
    self.configDict[kAttemptOfflineLoad] = attemptOfflineLoadNum;
}

#pragma mark - Configuration helpers

- (BOOL)validate:(NSError **)error {
    BOOL baseResult = [super validate:error];
    if (!baseResult) {
        return baseResult;
    }
    
    if (self.startPage.length == 0) {
        [SFSDKAppConfig createError:error withCode:SFSDKHybridAppConfigErrorCodeNoStartPage message:[SFSDKResourceUtils localizedString:@"appConfigValidationErrorNoStartPage"]];
        return NO;
    }
    
    // startPage must be a relative URL.
    if ([SFHybridViewConfig urlStringIsAbsolute:self.startPage]) {
        [SFSDKAppConfig createError:error withCode:SFSDKHybridAppConfigErrorCodeStartPageAbsoluteURL message:[SFSDKResourceUtils localizedString:@"appConfigValidationErrorStartPageAbsoluteURL"]];
        return NO;
    }
    
    // unauthenticatedStartPage doesn't make sense in a local setup.  Warn accordingly.
    if (self.isLocal && self.unauthenticatedStartPage.length > 0) {
        [SFSDKHybridLogger w:[self class] format:@"%@ %@ set for local app, but it will never be used.", NSStringFromSelector(_cmd), kUnauthenticatedStartPage];
    }
    
    // unauthenticatedStartPage doesn't make sense in a remote setup with authentication.  Warn accordingly.
    if (!self.isLocal && self.shouldAuthenticate && self.unauthenticatedStartPage.length > 0) {
        [SFSDKHybridLogger w:[self class] format:@"%@ %@ set for remote app with authentication, but it will never be used.", NSStringFromSelector(_cmd), kUnauthenticatedStartPage];
    }
    
    // Lack of unauthenticatedStartPage with remote deferred authentication is an error.
    if (!self.isLocal && !self.shouldAuthenticate && self.unauthenticatedStartPage.length == 0) {
        [SFSDKAppConfig createError:error withCode:SFSDKHybridAppConfigErrorCodeNoUnauthenticatedStartPage message:[SFSDKResourceUtils localizedString:@"appConfigValidationErrorNoUnauthenticatedStartPage"]];
        return NO;
    }
    
    // unauthenticatedStartPage, if present, must be an absolute URL.
    if (self.unauthenticatedStartPage.length > 0 && ![SFHybridViewConfig urlStringIsAbsolute:self.unauthenticatedStartPage]) {
        [SFSDKAppConfig createError:error withCode:SFSDKHybridAppConfigErrorCodeUnauthenticatedStartPageNotAbsoluteURL message:[SFSDKResourceUtils localizedString:@"appConfigValidationErrorUnauthenticatedStartPageNotAbsoluteURL"]];
        return NO;
    }
    
    return YES;
}

+ (instancetype)fromDefaultConfigFile
{
    return [self fromConfigFile:SFSDKDefaultHybridAppConfigFilePath];
}

+ (instancetype)fromConfigFile:(NSString *)configFilePath
{
    NSDictionary *hybridConfigDict = [SFSDKResourceUtils loadConfigFromFile:configFilePath];
    if (nil == hybridConfigDict) {
        [SFSDKHybridLogger i:[SFHybridViewConfig class] format:@"Hybrid view config at specified path '%@' not found, or data could not be parsed.", configFilePath];
        return nil;
    }
    SFHybridViewConfig *hybridViewConfig = [[SFHybridViewConfig alloc] initWithDict:hybridConfigDict];
    return hybridViewConfig;
}

+ (BOOL)urlStringIsAbsolute:(NSString *)urlString
{
    NSAssert(urlString.length > 0, @"urlString parameter is required.");
    return ([urlString hasPrefix:@"http://"] || [urlString hasPrefix:@"https://"]);
}

- (void)setConfigDefaults
{

    // Any default values that would not be the implicit defaults of nil values, should be set here.
    if ((self.configDict)[kAttemptOfflineLoad] == nil) {
        self.attemptOfflineLoad = kDefaultAttemptOfflineLoad;
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
