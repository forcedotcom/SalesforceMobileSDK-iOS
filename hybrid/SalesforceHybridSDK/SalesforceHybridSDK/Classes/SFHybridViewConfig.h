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

@interface SFHybridViewConfig : NSObject

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
 * Whether or not the start page for this application is local, vs. remote.
 */
@property (nonatomic, assign) BOOL isLocal;

/**
 * The start page associated with this app.
 */
@property (nonatomic, copy) NSString *startPage;

/**
 * The error page to navigate to, in the event of an error during the app load process.
 */
@property (nonatomic, copy) NSString *errorPage;

/**
 * Whether or not this app should authenticate when it first starts.
 */
@property (nonatomic, assign) BOOL shouldAuthenticate;

/**
 * Whether or not to attempt to load an offline version of the app, if there is no network
 * connectivity.
 */
@property (nonatomic, assign) BOOL attemptOfflineLoad;

/**
 * Initializer with a given JSON-based configuration dictionary.
 * @param configDict The dictionary containing the configuration.
 */
- (id)initWithDict:(NSDictionary *)configDict;

/**
 * @return The hybrid view config from the default configuration file location (/www/bootconfig.json).
 */
+ (SFHybridViewConfig *)fromDefaultConfigFile;

/**
 * Create a hybrid view config from the config file at the specified file path.
 * @param configFilePath The file path to the configuration file, relative to the resources root path.
 * @return The hybrid view config from the given file path.
 */
+ (SFHybridViewConfig *)fromConfigFile:(NSString *)configFilePath;

@end
