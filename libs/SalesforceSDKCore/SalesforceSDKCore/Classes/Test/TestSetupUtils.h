/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

@class SFOAuthCoordinator;
@class SFSDKTestCredentialsData;

/**
 This class provides utilities useful to all unit tests based on the Salesforce SDK
 */
@interface TestSetupUtils : NSObject

/**
 Loads a set of auth credentials from the 'ui_test_credentials.json' file located in the bundle associated
 with the given class, and return a dictionary of login info
 @param testClass The class associated with the bundle where the test credentials file lives.
 @return a dictionary of login username, password, url
 */
+ (NSArray *)populateUILoginInfoFromConfigFileForClass:(Class)testClass;

/**
 Loads a set of auth credentials from the 'test_credentials.json' file located in the bundle associated
 with the given class, and configures SFUserAccountManager and the current account with the data from
 that file.
 @param testClass The class associated with the bundle where the test credentials file lives.
 @return The configuration data used to configure SFUserAccountManager (useful e.g. for hybrid
 apps which need the data to bootstrap SFHybridViewController).
 */
+ (SFSDKTestCredentialsData *)populateAuthCredentialsFromConfigFileForClass:(Class)testClass;

/**
 Performs a synchronous refresh of the OAuth credentials, which will stage the remaining auth
 data (access token, User ID, Org ID, etc.) in SFUserAccountManager.
 `populateAuthCredentialsFromConfigFile` is required to run once before this method will attempt
 to refresh authentication.
 */
+ (void)synchronousAuthRefresh;

@end
