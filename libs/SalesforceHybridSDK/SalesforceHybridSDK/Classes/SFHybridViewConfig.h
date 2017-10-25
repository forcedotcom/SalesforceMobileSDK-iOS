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

#import <SalesforceSDKCore/SFSDKAppConfig.h>

typedef NS_ENUM(NSInteger, SFSDKHybridAppConfigErrorCode) {
    SFSDKHybridAppConfigErrorCodeNoStartPage = 1066,
    SFSDKHybridAppConfigErrorCodeStartPageAbsoluteURL,
    SFSDKHybridAppConfigErrorCodeUnauthenticatedStartPageNotAbsoluteURL,
    SFSDKHybridAppConfigErrorCodeNoUnauthenticatedStartPage,
    SFSDKHybridAppConfigErrorCodeAbsoluteURLNoAuth,
    SFSDKHybridAppConfigErrorCodeRelativeURLAuth
};

NS_ASSUME_NONNULL_BEGIN

// Default path to bootconfig.json on the filesystem.
static NSString *const SFSDKDefaultHybridAppConfigFilePath = @"/www/bootconfig.json";

@interface SFHybridViewConfig : SFSDKAppConfig

/**
 * Whether or not the start page for this application is local, vs. remote.
 */
@property (nonatomic, assign) BOOL isLocal;

/**
 * The start page associated with this app.
 */
@property (nonatomic, copy) NSString *startPage;

/**
 * In a deferred authentication configuration for remote apps, the page/URL that should
 * be loaded in an unauthenticated context.
 */
@property (nullable, nonatomic, copy) NSString *unauthenticatedStartPage;

/**
 * The error page to navigate to, in the event of an error during the app load process.
 */
@property (nonatomic, copy) NSString *errorPage;

/**
 * Whether or not to attempt to load an offline version of the app, if there is no network
 * connectivity.
 */
@property (nonatomic, assign) BOOL attemptOfflineLoad;

/**
 * Determines whether an input URL string is an absolute URL or not.
 * @param urlString The URL string to evaluate.
 * @return YES if the URL string is absolute, no otherwise.
 */
+ (BOOL)urlStringIsAbsolute:(nonnull NSString *)urlString;

@end

NS_ASSUME_NONNULL_END
