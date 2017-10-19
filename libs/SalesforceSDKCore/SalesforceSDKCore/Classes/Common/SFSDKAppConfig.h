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

#import <Foundation/Foundation.h>

extern NSString * _Nonnull const SFSDKAppConfigErrorDomain;

typedef NS_ENUM(NSInteger, SFSDKAppConfigErrorCode) {
    SFSDKAppConfigErrorCodeNoConsumerKey = 966,
    SFSDKAppConfigErrorCodeNoRedirectURI,
    SFSDKAppConfigErrorCodeNoOAuthScopes
};

NS_ASSUME_NONNULL_BEGIN

static NSString *const SFSDKDefaultNativeAppConfigFilePath = @"/bootconfig.plist";

/** Contains this app's OAuth configuration as defined in the developer's Salesforce connected app.
 */
@interface SFSDKAppConfig : NSObject

/**
 * The Connected App key associated with this application.
 */
@property (nonatomic, copy) NSString *remoteAccessConsumerKey;

/**
 * The OAuth Redirect URI associated with the configured Connected Application.
 */
@property (nonatomic, copy) NSString *oauthRedirectURI;

/**
 * The OAuth Scopes being requested for this app.
 */
@property (nonatomic, strong) NSSet *oauthScopes;

/**
 * Whether or not this app should authenticate when it first starts.
 */
@property (nonatomic, assign) BOOL shouldAuthenticate;

/**
 * The config as a dictionary
 */
@property (nonatomic, strong) NSMutableDictionary *configDict;

/**
 * Initializer with a given JSON-based configuration dictionary.
 * @param configDict The dictionary containing the configuration.
 */
- (nullable instancetype)initWithDict:(nullable NSDictionary *)configDict;

/**
 * Validate the app config inputs.
 * @param error The error associated with validation, if an error occurs.
 * @return YES if validation was successful, NO otherwise.
 */
- (BOOL)validate:(NSError * _Nullable * _Nullable)error;

/**
 * @return The app config from the default configuration file location.
 */
+ (nullable instancetype)fromDefaultConfigFile;

/**
 * Create an app config from the config file at the specified file path.
 * @param configFilePath The file path to the configuration file, relative to the resources root path.
 * @return The app config from the given file path.
 */
+ (nullable instancetype)fromConfigFile:(NSString *)configFilePath;

+ (void)createError:(NSError * _Nullable * _Nullable)error withCode:(NSInteger)errorCode message:(nonnull NSString *)message;

@end

NS_ASSUME_NONNULL_END

