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
#import "SFJsonUtils.h"

@interface SFHybridViewConfig ()

/*
 * Reads the contents of bootconfig.js into an NSDictionary.
 */
+ (NSDictionary*) readBootConfigFile;

/*
 * Parses the boot config JSON and sets properties.
 */
+ (SFHybridViewConfig*) parseBootConfig : (NSDictionary*) jsonData;

@end

@implementation SFHybridViewConfig

@synthesize remoteAccessConsumerKey = _remoteAccessConsumerKey;
@synthesize oauthRedirectURI = _oauthRedirectURI;
@synthesize oauthScopes = _oauthScopes;
@synthesize isLocal = _isLocal;
@synthesize startPage = _startPage;
@synthesize errorPage = _errorPage;
@synthesize shouldAuthenticate = _shouldAuthenticate;
@synthesize attemptOfflineLoad = _attemptOfflineLoad;

// Keys used in bootconfig.json.
static NSString* const kRemoteAccessConsumerKey = @"remoteAccessConsumerKey";
static NSString* const kOauthRedirectURI = @"oauthRedirectURI";
static NSString* const kOauthScopes = @"oauthScopes";
static NSString* const kIsLocal = @"isLocal";
static NSString* const kStartPage = @"startPage";
static NSString* const kErrorPage = @"errorPage";
static NSString* const kShouldAuthenticate = @"shouldAuthenticate";
static NSString* const kAttemptOfflineLoad = @"attemptOfflineLoad";

// Path to bootconfig.json on the filesystem.
static NSString* const kBootConfigFilePath = @"/www/bootconfig.json";

// Default values for optional configs.
static BOOL const kDefaultShouldAuthenticate = YES;
static BOOL const kDefaultAttemptOfflineLoad = YES;

+ (SFHybridViewConfig*)readViewConfigFromJSON {
    SFHybridViewConfig *hybridViewConfig = nil;
    NSDictionary *fields = [SFHybridViewConfig readBootConfigFile];
    if (nil != fields) {
        hybridViewConfig = [SFHybridViewConfig parseBootConfig:fields];
    }
    return hybridViewConfig;
}

+ (NSDictionary*)readBootConfigFile {
    NSDictionary *jsonDict = nil;
    NSString *appFolderPath = [[NSBundle mainBundle] resourcePath];
    NSMutableString *fullPath = [[NSMutableString alloc] initWithString:appFolderPath];
    [fullPath appendString:kBootConfigFilePath];
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath];
    if (fileExists) {
        NSData *fileContents = [[NSFileManager defaultManager] contentsAtPath:fullPath];
        jsonDict = (NSDictionary*)[SFJsonUtils objectFromJSONData:fileContents];
    }
    return jsonDict;
}

+ (SFHybridViewConfig*)parseBootConfig:fields {
    SFHybridViewConfig *viewConfig = [[SFHybridViewConfig alloc] init];
    viewConfig.remoteAccessConsumerKey = [fields objectForKey:kRemoteAccessConsumerKey];
    viewConfig.oauthRedirectURI = [fields objectForKey:kOauthRedirectURI];
    viewConfig.oauthScopes = [fields objectForKey:kOauthScopes];
    viewConfig.isLocal = (BOOL) [fields objectForKey:kIsLocal];
    viewConfig.startPage = [fields objectForKey:kStartPage];
    viewConfig.errorPage = [fields objectForKey:kErrorPage];
    NSObject *shouldAuth = [fields objectForKey:kShouldAuthenticate];
    viewConfig.shouldAuthenticate = kDefaultShouldAuthenticate;
    if (nil != shouldAuth) {
        viewConfig.shouldAuthenticate = (BOOL) shouldAuth;
    }
    NSObject *offlineLoad = [fields objectForKey:kAttemptOfflineLoad];
    viewConfig.attemptOfflineLoad = kDefaultAttemptOfflineLoad;
    if (nil != offlineLoad) {
        viewConfig.attemptOfflineLoad = (BOOL) offlineLoad;
    }
    return viewConfig;
}

@end
