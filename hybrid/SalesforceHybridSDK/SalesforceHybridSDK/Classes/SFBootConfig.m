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

#import "SFBootConfig.h"
#import "SFJsonUtils.h"

@interface SFBootConfig ()

@property (nonatomic, retain) NSString *remoteAccessConsumerKey;
@property (nonatomic, retain) NSString *oauthRedirectURI;
@property (nonatomic, retain) NSArray *oauthScopes;
@property (nonatomic, assign) BOOL isLocal;
@property (nonatomic, retain) NSString *startPage;
@property (nonatomic, retain) NSString *errorPage;
@property (nonatomic, assign) BOOL shouldAuthenticate;
@property (nonatomic, assign) BOOL attemptOfflineLoad;

/*
 * Reads the JSON data from bootconfig.js.
 */
- (void) readFromJSON;

/*
 * Reads the contents of bootconfig.js into an NSDictionary.
 */
- (NSDictionary*) readBootConfigFile;

/*
 * Parses the boot config JSON and sets properties.
 */
- (void) parseBootConfig : (NSDictionary*) jsonData;

@end

@implementation SFBootConfig

@synthesize remoteAccessConsumerKey = _remoteAccessConsumerKey;
@synthesize oauthRedirectURI = _oauthRedirectURI;
@synthesize oauthScopes = _oauthScopes;
@synthesize isLocal = _isLocal;
@synthesize startPage = _startPage;
@synthesize errorPage = _errorPage;
@synthesize shouldAuthenticate = _shouldAuthenticate;
@synthesize attemptOfflineLoad = _attemptOfflineLoad;

// Singleton instance.
static SFBootConfig *_instance;
static dispatch_once_t _sharedInstanceGuard;

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

+ (SFBootConfig *)sharedInstance {
    dispatch_once(&_sharedInstanceGuard,
        ^{
            _instance = [[SFBootConfig alloc] init];
            [_instance readFromJSON];
        });
    return _instance;
}

- (void)readFromJSON {
    NSDictionary *fields = [self readBootConfigFile];
    if (nil != fields) {
        [self parseBootConfig:fields];
    }
}

- (NSDictionary*)readBootConfigFile {
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

- (void)parseBootConfig:fields {
    self.remoteAccessConsumerKey = [fields objectForKey:kRemoteAccessConsumerKey];
    self.oauthRedirectURI = [fields objectForKey:kOauthRedirectURI];
    self.oauthScopes = [fields objectForKey:kOauthScopes];
    self.isLocal = (BOOL) [fields objectForKey:kIsLocal];
    self.startPage = [fields objectForKey:kStartPage];
    self.errorPage = [fields objectForKey:kErrorPage];
    NSObject *shouldAuth = [fields objectForKey:kShouldAuthenticate];
    self.shouldAuthenticate = kDefaultShouldAuthenticate;
    if (nil != shouldAuth) {
        self.shouldAuthenticate = (BOOL) shouldAuth;
    }
    NSObject *offlineLoad = [fields objectForKey:kAttemptOfflineLoad];
    self.attemptOfflineLoad = kDefaultAttemptOfflineLoad;
    if (nil != offlineLoad) {
        self.attemptOfflineLoad = (BOOL) offlineLoad;
    }
}

@end
