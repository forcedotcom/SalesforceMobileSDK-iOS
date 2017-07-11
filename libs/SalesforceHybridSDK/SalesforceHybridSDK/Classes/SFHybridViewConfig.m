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
#import <SalesforceAnalytics/SFSDKLogger.h>
#import <SalesforceSDKCore/SFJsonUtils.h>

@interface SFHybridViewConfig ()

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
static NSString* const kIsLocal = @"isLocal";
static NSString* const kStartPage = @"startPage";
static NSString* const kErrorPage = @"errorPage";
static NSString* const kAttemptOfflineLoad = @"attemptOfflineLoad";

// Default path to bootconfig.json on the filesystem.
static NSString* const kDefaultHybridViewConfigFilePath = @"/www/bootconfig.json";

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

+ (SFHybridViewConfig *)fromDefaultConfigFile
{
    return [SFHybridViewConfig fromConfigFile:kDefaultHybridViewConfigFilePath];
}

+ (SFHybridViewConfig *)fromConfigFile:(NSString *)configFilePath
{
    NSDictionary *hybridConfigDict = [SFHybridViewConfig loadConfigFromFile:configFilePath];
    if (nil == hybridConfigDict) {
        [SFSDKHybridLogger i:[SFHybridViewConfig class] format:[NSString stringWithFormat:@"Hybrid view config at specified path '%@' not found, or data could not be parsed.", configFilePath]];
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
        [SFSDKHybridLogger i:[SFHybridViewConfig class] format:[NSString stringWithFormat:@"Hybrid view config at specified path '%@' could not be read: %@", configFilePath, fileReadError]];
        return nil;
    }
    NSDictionary *jsonDict = [SFJsonUtils objectFromJSONData:fileContents];
    return jsonDict;
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
